"""Repositório em memória com a mesma semântica do MongoDB (usado em testes)."""

from __future__ import annotations

import copy
import threading
from datetime import datetime, timezone
from typing import Any, Optional

from .base import PersistenceUnavailable, RevisionConflict, StoredSave


class MemorySaveRepository:
    def __init__(self) -> None:
        self._lock = threading.Lock()
        self.saves: dict[str, dict[str, Any]] = {}
        self.world_events: dict[str, dict[str, Any]] = {}
        self.dialogue_history: dict[str, dict[str, Any]] = {}
        self.available = True

    def _check(self) -> None:
        if not self.available:
            raise PersistenceUnavailable("repositório em memória marcado como indisponível")

    def ping(self) -> None:
        self._check()

    def get_save(self, slot_id: str) -> Optional[StoredSave]:
        self._check()
        doc = self.saves.get(slot_id)
        if doc is None:
            return None
        doc = copy.deepcopy(doc)
        return StoredSave(
            slot_id=slot_id,
            revision=doc["revision"],
            snapshot=doc["snapshot"],
            checksum=doc["checksum"],
            updated_at=doc["updated_at"],
            schema_version=doc["schema_version"],
        )

    def write_save(self, slot_id, document, expected_revision, overwrite) -> int:
        self._check()
        with self._lock:
            current = self.saves.get(slot_id)
            current_rev = current["revision"] if current else None
            if overwrite:
                new_rev = (current_rev or 0) + 1
            elif expected_revision is None:
                if current is not None:
                    raise RevisionConflict("o slot já existe", current_rev)
                new_rev = 1
            else:
                if current is None or current_rev != expected_revision:
                    raise RevisionConflict("revisão divergente", current_rev)
                new_rev = expected_revision + 1
            stored = copy.deepcopy(document)
            stored["revision"] = new_rev
            stored.setdefault("updated_at", datetime.now(timezone.utc))
            self.saves[slot_id] = stored
            return new_rev

    def record_world_events(self, island_id, slot_id, events) -> int:
        self._check()
        new = 0
        for event in events:
            key = f"{island_id}:{slot_id}:{event['event_id']}"
            if key not in self.world_events:
                self.world_events[key] = copy.deepcopy(event)
                new += 1
        return new

    def record_dialogue(self, entry) -> bool:
        self._check()
        key = entry["exchange_id"]
        if key in self.dialogue_history:
            return False
        self.dialogue_history[key] = copy.deepcopy(entry)
        return True
