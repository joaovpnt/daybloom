"""Modelos de validação do snapshot canônico de save e das requisições da API.

O snapshot é produzido pelo jogo (Godot) e validado aqui antes de qualquer
gravação. Campos desconhecidos são preservados (``extra="allow"``) para que
versões futuras do jogo não percam dados silenciosamente ao passar por um
backend mais antigo.
"""

from __future__ import annotations

import re
from typing import Any, Literal, Optional

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

CURRENT_SCHEMA_VERSION = 1
NPC_COUNT = 8
ID_PATTERN = re.compile(r"^[a-z0-9][a-z0-9_\-]{0,63}$")
SLOT_PATTERN = re.compile(r"^[a-z0-9][a-z0-9_\-]{0,31}$")

NPC_STATES = {
    "IDLE",
    "WALKING",
    "RESTING",
    "WORKING",
    "SOCIALIZING",
    "EXPLORING",
    "LEISURE",
}
MEMORY_TYPES = {
    "gift_received",
    "important_conversation",
    "npc_interaction",
    "relationship_change",
    "community_event",
}
NEED_KEYS = {"energia", "social", "diversao", "conforto"}
TRAIT_KEYS = {"sociabilidade", "gentileza", "curiosidade", "coragem", "energia"}


def _check_id(value: str, field: str) -> str:
    if not isinstance(value, str) or not ID_PATTERN.match(value):
        raise ValueError(f"{field} inválido: {value!r}")
    return value


class _Base(BaseModel):
    model_config = ConfigDict(extra="allow")


class Vec3(_Base):
    x: float
    y: float
    z: float


class GameTime(_Base):
    day: int = Field(ge=1)
    minute: float = Field(ge=0, lt=1440)


class InventorySlot(_Base):
    item_id: str
    count: int = Field(ge=1, le=999)

    @field_validator("item_id")
    @classmethod
    def _item(cls, v: str) -> str:
        return _check_id(v, "item_id")


class ResourceState(_Base):
    id: str
    kind: str
    item_id: str
    available: bool
    respawn_day: int = Field(ge=0)


class WorldState(_Base):
    day: int = Field(ge=1)
    minute: float = Field(ge=0, lt=1440)
    island_name: str = Field(min_length=1, max_length=40)
    event_seq: int = Field(ge=0)
    resources: list[ResourceState] = Field(default_factory=list)

    @model_validator(mode="after")
    def _unique_resources(self) -> "WorldState":
        ids = [r.id for r in self.resources]
        if len(ids) != len(set(ids)):
            raise ValueError("recursos do mundo com IDs duplicados")
        return self


class PlayerState(_Base):
    id: str
    name: str = Field(min_length=1, max_length=24)
    position: Vec3
    rotation_y: float = 0.0
    inventory: list[InventorySlot] = Field(default_factory=list)

    @model_validator(mode="after")
    def _unique_items(self) -> "PlayerState":
        ids = [s.item_id for s in self.inventory]
        if len(ids) != len(set(ids)):
            raise ValueError("inventário com itens duplicados (cada item deve ocupar uma única pilha)")
        return self


class RelationshipEvent(_Base):
    event_id: str
    kind: str
    day: int = Field(ge=1)
    minute: float = Field(ge=0, lt=1440)
    affinity_delta: float
    trust_delta: float


class Relationship(_Base):
    affinity: float = Field(ge=-100, le=100)
    trust: float = Field(ge=0, le=100)
    interactions: int = Field(ge=0)
    last_meeting: Optional[GameTime] = None
    history: list[RelationshipEvent] = Field(default_factory=list, max_length=40)


class Memory(_Base):
    id: str
    type: str
    participants: list[str]
    day: int = Field(ge=1)
    minute: float = Field(ge=0, lt=1440)
    description: str = Field(min_length=1, max_length=400)
    relevance: float = Field(ge=0, le=1)
    consequences: list[str] = Field(default_factory=list)
    event_ref: str
    occurrences: int = Field(default=1, ge=1)

    @field_validator("type")
    @classmethod
    def _type(cls, v: str) -> str:
        if v not in MEMORY_TYPES:
            raise ValueError(f"tipo de memória desconhecido: {v}")
        return v


class Emotion(_Base):
    mood: str
    valence: float = Field(ge=-1, le=1)


class NpcState(_Base):
    id: str
    name: str
    species: str
    personality: dict[str, float]
    needs: dict[str, float]
    emotion: Emotion
    state: str
    activity: str
    position: Vec3
    relationships: dict[str, Relationship]
    memories: list[Memory] = Field(default_factory=list, max_length=200)
    cooldowns: dict[str, float] = Field(default_factory=dict)

    @field_validator("id")
    @classmethod
    def _id(cls, v: str) -> str:
        return _check_id(v, "id do morador")

    @field_validator("state")
    @classmethod
    def _state(cls, v: str) -> str:
        if v not in NPC_STATES:
            raise ValueError(f"estado de morador inválido: {v}")
        return v

    @field_validator("needs")
    @classmethod
    def _needs(cls, v: dict[str, float]) -> dict[str, float]:
        missing = NEED_KEYS - set(v)
        if missing:
            raise ValueError(f"necessidades ausentes: {sorted(missing)}")
        for key, value in v.items():
            if not 0 <= value <= 100:
                raise ValueError(f"necessidade {key} fora do intervalo 0..100")
        return v

    @field_validator("personality")
    @classmethod
    def _traits(cls, v: dict[str, float]) -> dict[str, float]:
        missing = TRAIT_KEYS - set(v)
        if missing:
            raise ValueError(f"traços de personalidade ausentes: {sorted(missing)}")
        for key, value in v.items():
            if not 0 <= value <= 1:
                raise ValueError(f"traço {key} fora do intervalo 0..1")
        return v

    @model_validator(mode="after")
    def _unique_memories(self) -> "NpcState":
        ids = [m.id for m in self.memories]
        if len(ids) != len(set(ids)):
            raise ValueError(f"memórias duplicadas no morador {self.id}")
        return self


class JournalEntry(_Base):
    event_id: str
    day: int = Field(ge=1)
    minute: float = Field(ge=0, lt=1440)
    kind: str
    participants: list[str] = Field(default_factory=list)
    text: str = Field(min_length=1, max_length=400)


class SaveSnapshot(_Base):
    schema_version: int = Field(ge=1)
    game_version: str
    save_slot_id: str
    player_id: str
    island_id: str
    saved_at: str
    world: WorldState
    player: PlayerState
    npcs: list[NpcState]
    journal: list[JournalEntry] = Field(default_factory=list, max_length=300)

    @field_validator("save_slot_id")
    @classmethod
    def _slot(cls, v: str) -> str:
        if not SLOT_PATTERN.match(v):
            raise ValueError("save_slot_id inválido")
        return v

    @field_validator("player_id", "island_id")
    @classmethod
    def _ids(cls, v: str) -> str:
        return _check_id(v, "identificador")

    @model_validator(mode="after")
    def _consistency(self) -> "SaveSnapshot":
        if self.schema_version > CURRENT_SCHEMA_VERSION:
            raise ValueError(
                f"schema_version {self.schema_version} é mais novo que o suportado ({CURRENT_SCHEMA_VERSION})"
            )
        if self.player.id != self.player_id:
            raise ValueError("player.id difere de player_id")
        if len(self.npcs) != NPC_COUNT:
            raise ValueError(f"o save deve conter exatamente {NPC_COUNT} moradores, recebeu {len(self.npcs)}")
        npc_ids = [n.id for n in self.npcs]
        if len(set(npc_ids)) != len(npc_ids):
            raise ValueError("moradores com IDs duplicados")
        valid_targets = set(npc_ids) | {self.player_id}
        for npc in self.npcs:
            for other in npc.relationships:
                if other not in valid_targets or other == npc.id:
                    raise ValueError(f"relacionamento inválido de {npc.id} com {other}")
        journal_ids = [j.event_id for j in self.journal]
        if len(set(journal_ids)) != len(journal_ids):
            raise ValueError("Diário da Ilha com eventos duplicados")
        return self


class SaveWriteRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    snapshot: dict[str, Any]
    expected_revision: Optional[int] = Field(default=None, ge=0)
    overwrite: bool = False


class DialogueTurn(BaseModel):
    role: Literal["jogadora", "morador"]
    text: str = Field(max_length=500)


class DialogueRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    exchange_id: str = Field(min_length=1, max_length=80)
    save_slot_id: str = Field(min_length=1, max_length=32)
    island_id: str
    player_id: str
    npc_id: str
    message: str = Field(min_length=1, max_length=300)
    context: dict[str, Any]
    history: list[DialogueTurn] = Field(default_factory=list, max_length=8)


class DialogueResponse(BaseModel):
    exchange_id: str
    source: Literal["ollama", "fallback"]
    reply: Optional[str] = None
    suggested_action: Optional[str] = None
    reason: Optional[str] = None
    latency_ms: int = 0
