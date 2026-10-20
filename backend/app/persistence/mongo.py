"""Repositório MongoDB (PyMongo) para saves, eventos e histórico de diálogo."""

from __future__ import annotations

import logging
from datetime import datetime, timezone
from typing import Any, Optional

from pymongo import MongoClient, UpdateOne
from pymongo.errors import (
    BulkWriteError,
    ConnectionFailure,
    DuplicateKeyError,
    PyMongoError,
    ServerSelectionTimeoutError,
)
from pymongo.write_concern import WriteConcern

from .base import PersistenceError, PersistenceUnavailable, RevisionConflict, StoredSave

log = logging.getLogger("daybloom.mongo")

# Confirmação com journal: só respondemos "salvo" depois que o MongoDB
# registrou a escrita em disco.
DURABLE = WriteConcern(w=1, j=True)


class MongoSaveRepository:
    def __init__(self, uri: str, db_name: str, timeout_ms: int = 2500) -> None:
        self._client = MongoClient(
            uri,
            serverSelectionTimeoutMS=timeout_ms,
            connectTimeoutMS=timeout_ms,
            socketTimeoutMS=max(timeout_ms * 4, 10000),
            appname="daybloom-backend",
            tz_aware=True,
        )
        self._db = self._client[db_name]
        self.saves = self._db.get_collection("save_slots", write_concern=DURABLE)
        self.world_events = self._db.get_collection("world_events", write_concern=DURABLE)
        self.dialogue_history = self._db.get_collection("dialogue_history", write_concern=DURABLE)
        self._indexes_ready = False

    def close(self) -> None:
        self._client.close()

    def _ensure_indexes(self) -> None:
        if self._indexes_ready:
            return
        try:
            self.world_events.create_index([("island_id", 1), ("save_slot_id", 1), ("day", 1)])
            self.dialogue_history.create_index([("save_slot_id", 1), ("npc_id", 1), ("created_at", -1)])
            self._indexes_ready = True
        except (ConnectionFailure, ServerSelectionTimeoutError) as exc:
            raise PersistenceUnavailable(f"MongoDB indisponível: {exc}") from exc

    def ping(self) -> None:
        try:
            self._client.admin.command("ping")
        except (ConnectionFailure, ServerSelectionTimeoutError) as exc:
            raise PersistenceUnavailable(f"MongoDB indisponível: {exc}") from exc
        self._ensure_indexes()

    def get_save(self, slot_id: str) -> Optional[StoredSave]:
        try:
            doc = self.saves.find_one({"_id": slot_id})
        except (ConnectionFailure, ServerSelectionTimeoutError) as exc:
            raise PersistenceUnavailable(f"MongoDB indisponível: {exc}") from exc
        except PyMongoError as exc:
            raise PersistenceError(str(exc)) from exc
        if doc is None:
            return None
        return StoredSave(
            slot_id=slot_id,
            revision=int(doc["revision"]),
            snapshot=doc["snapshot"],
            checksum=doc["checksum"],
            updated_at=doc["updated_at"],
            schema_version=int(doc["schema_version"]),
        )

    def write_save(self, slot_id, document, expected_revision, overwrite) -> int:
        self.ping()
        doc = dict(document)
        doc["_id"] = slot_id
        doc["updated_at"] = datetime.now(timezone.utc)
        try:
            if overwrite:
                current = self.saves.find_one({"_id": slot_id}, {"revision": 1})
                new_rev = (int(current["revision"]) if current else 0) + 1
                doc["revision"] = new_rev
                flt: dict[str, Any] = {"_id": slot_id}
                if current is not None:
                    flt["revision"] = current["revision"]
                    result = self.saves.replace_one(flt, doc)
                    if result.matched_count != 1:
                        raise RevisionConflict("o save foi alterado durante a sobrescrita", None)
                else:
                    self.saves.insert_one(doc)
                return new_rev
            if expected_revision is None:
                doc["revision"] = 1
                self.saves.insert_one(doc)
                return 1
            doc["revision"] = expected_revision + 1
            # replace_one em um único documento é atômico no MongoDB: ou o
            # snapshot inteiro é trocado, ou nada muda.
            result = self.saves.replace_one({"_id": slot_id, "revision": expected_revision}, doc)
            if result.matched_count != 1:
                current = self.saves.find_one({"_id": slot_id}, {"revision": 1})
                raise RevisionConflict(
                    "revisão divergente", int(current["revision"]) if current else None
                )
            return expected_revision + 1
        except DuplicateKeyError as exc:
            current = self.saves.find_one({"_id": slot_id}, {"revision": 1})
            raise RevisionConflict("o slot já existe", int(current["revision"]) if current else None) from exc
        except (ConnectionFailure, ServerSelectionTimeoutError) as exc:
            raise PersistenceUnavailable(f"MongoDB indisponível: {exc}") from exc
        except PyMongoError as exc:
            raise PersistenceError(str(exc)) from exc

    def record_world_events(self, island_id, slot_id, events) -> int:
        if not events:
            return 0
        ops = []
        for event in events:
            data = dict(event)
            data.update({"island_id": island_id, "save_slot_id": slot_id})
            ops.append(
                UpdateOne(
                    {"_id": f"{island_id}:{slot_id}:{event['event_id']}"},
                    {"$setOnInsert": data},
                    upsert=True,
                )
            )
        try:
            result = self.world_events.bulk_write(ops, ordered=False)
            return int(result.upserted_count)
        except BulkWriteError as exc:
            return int(exc.details.get("nUpserted", 0))
        except (ConnectionFailure, ServerSelectionTimeoutError) as exc:
            raise PersistenceUnavailable(f"MongoDB indisponível: {exc}") from exc
        except PyMongoError as exc:
            raise PersistenceError(str(exc)) from exc

    def record_dialogue(self, entry) -> bool:
        data = dict(entry)
        data["_id"] = entry["exchange_id"]
        data.setdefault("created_at", datetime.now(timezone.utc))
        try:
            result = self.dialogue_history.update_one(
                {"_id": data["_id"]}, {"$setOnInsert": data}, upsert=True
            )
            return result.upserted_id is not None
        except (ConnectionFailure, ServerSelectionTimeoutError) as exc:
            raise PersistenceUnavailable(f"MongoDB indisponível: {exc}") from exc
        except PyMongoError as exc:
            raise PersistenceError(str(exc)) from exc
