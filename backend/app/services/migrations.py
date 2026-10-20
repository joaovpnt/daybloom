"""Migrações de snapshots de save entre versões de schema.

Cada função recebe um snapshot na versão N e devolve na versão N+1. Saves
antigos são sempre migrados antes da validação, garantindo compatibilidade
entre versões do jogo.
"""

from __future__ import annotations

import copy
from typing import Any, Callable

from ..schemas import CURRENT_SCHEMA_VERSION

Migration = Callable[[dict[str, Any]], dict[str, Any]]

# Exemplo para o futuro: MIGRATIONS[1] = _v1_para_v2
MIGRATIONS: dict[int, Migration] = {}


class MigrationError(ValueError):
    pass


def migrate_snapshot(snapshot: dict[str, Any]) -> dict[str, Any]:
    data = copy.deepcopy(snapshot)
    version = data.get("schema_version")
    if not isinstance(version, int) or version < 1:
        raise MigrationError("schema_version ausente ou inválido")
    if version > CURRENT_SCHEMA_VERSION:
        raise MigrationError(
            f"save criado por uma versão mais nova do jogo (schema {version}); atualize o backend"
        )
    while version < CURRENT_SCHEMA_VERSION:
        step = MIGRATIONS.get(version)
        if step is None:
            raise MigrationError(f"não existe migração do schema {version}")
        data = step(data)
        version += 1
        data["schema_version"] = version
    return data
