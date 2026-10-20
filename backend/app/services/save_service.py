"""Regras de negócio de saves: validação, versão, checksum e gravação atômica."""

from __future__ import annotations

import hashlib
import json
import logging
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Any, Optional

from pydantic import ValidationError

from ..persistence import PersistenceError, SaveRepository, StoredSave
from ..schemas import SaveSnapshot
from .migrations import MigrationError, migrate_snapshot

log = logging.getLogger("daybloom.saves")


class SaveValidationError(ValueError):
    def __init__(self, message: str, details: Any = None) -> None:
        super().__init__(message)
        self.details = details


@dataclass
class SaveResult:
    slot_id: str
    revision: int
    checksum: str
    saved_at: str
    events_recorded: int
    events_error: Optional[str]


def canonical_json(data: Any) -> str:
    return json.dumps(data, sort_keys=True, ensure_ascii=False, separators=(",", ":"))


def checksum_of(snapshot: dict[str, Any]) -> str:
    return hashlib.sha256(canonical_json(snapshot).encode("utf-8")).hexdigest()


def validate_snapshot(snapshot: dict[str, Any], slot_id: Optional[str] = None) -> dict[str, Any]:
    """Migra e valida o snapshot, devolvendo a versão canônica (dict)."""
    try:
        migrated = migrate_snapshot(snapshot)
    except MigrationError as exc:
        raise SaveValidationError(str(exc)) from exc
    try:
        model = SaveSnapshot.model_validate(migrated)
    except ValidationError as exc:
        details = [
            {"campo": ".".join(str(p) for p in err["loc"]), "erro": err["msg"]}
            for err in exc.errors()
        ]
        raise SaveValidationError("snapshot de save inválido", details) from exc
    if slot_id is not None and model.save_slot_id != slot_id:
        raise SaveValidationError(
            f"save_slot_id do snapshot ({model.save_slot_id}) difere do slot da URL ({slot_id})"
        )
    return model.model_dump(mode="json")


class SaveService:
    def __init__(self, repository: SaveRepository) -> None:
        self.repository = repository

    def load(self, slot_id: str) -> Optional[StoredSave]:
        stored = self.repository.get_save(slot_id)
        if stored is None:
            return None
        if checksum_of(stored.snapshot) != stored.checksum:
            raise PersistenceError(
                f"o save {slot_id} está corrompido (checksum não confere); nada foi carregado"
            )
        stored.snapshot = validate_snapshot(stored.snapshot, slot_id)
        return stored

    def save(
        self,
        slot_id: str,
        snapshot: dict[str, Any],
        expected_revision: Optional[int],
        overwrite: bool = False,
    ) -> SaveResult:
        canonical = validate_snapshot(snapshot, slot_id)
        checksum = checksum_of(canonical)
        now = datetime.now(timezone.utc)
        document = {
            "slot_id": slot_id,
            "player_id": canonical["player_id"],
            "island_id": canonical["island_id"],
            "schema_version": canonical["schema_version"],
            "game_version": canonical["game_version"],
            "checksum": checksum,
            "snapshot": canonical,
            "updated_at": now,
        }
        revision = self.repository.write_save(slot_id, document, expected_revision, overwrite)

        # Eventos auxiliares: idempotentes e nunca usados para reconstruir a
        # partida. Uma falha aqui não invalida o save principal, mas é relatada.
        events_recorded = 0
        events_error = None
        try:
            events_recorded = self.repository.record_world_events(
                canonical["island_id"], slot_id, canonical.get("journal", [])
            )
        except PersistenceError as exc:
            events_error = str(exc)
            log.warning("falha ao registrar eventos do mundo: %s", exc)
        return SaveResult(
            slot_id=slot_id,
            revision=revision,
            checksum=checksum,
            saved_at=now.isoformat(),
            events_recorded=events_recorded,
            events_error=events_error,
        )
