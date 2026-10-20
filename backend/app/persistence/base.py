"""Interface de persistência desacoplada.

O serviço de saves conversa apenas com ``SaveRepository``. Hoje existe a
implementação MongoDB (``mongo.py``) e uma implementação em memória usada nos
testes (``memory.py``). No futuro, uma implementação local embutida poderá ser
adicionada sem tocar na API nem no jogo.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from typing import Any, Optional, Protocol


class PersistenceError(Exception):
    """Erro genérico de persistência."""


class PersistenceUnavailable(PersistenceError):
    """O banco de dados não está acessível."""


class RevisionConflict(PersistenceError):
    """A revisão esperada não corresponde à revisão armazenada."""

    def __init__(self, message: str, current_revision: Optional[int]) -> None:
        super().__init__(message)
        self.current_revision = current_revision


@dataclass
class StoredSave:
    slot_id: str
    revision: int
    snapshot: dict[str, Any]
    checksum: str
    updated_at: datetime
    schema_version: int


class SaveRepository(Protocol):
    def ping(self) -> None:
        """Levanta PersistenceUnavailable se o banco não responder."""

    def get_save(self, slot_id: str) -> Optional[StoredSave]: ...

    def write_save(
        self,
        slot_id: str,
        document: dict[str, Any],
        expected_revision: Optional[int],
        overwrite: bool,
    ) -> int:
        """Grava atomicamente o documento principal e retorna a nova revisão."""

    def record_world_events(self, island_id: str, slot_id: str, events: list[dict[str, Any]]) -> int:
        """Grava eventos de forma idempotente e retorna quantos eram novos."""

    def record_dialogue(self, entry: dict[str, Any]) -> bool:
        """Grava uma troca de diálogo de forma idempotente."""
