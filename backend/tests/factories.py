"""Fábrica de snapshots válidos para os testes do backend."""

from __future__ import annotations

import copy

NPC_IDS = ["lila", "tobias", "marina", "otavio", "pipa", "bento", "ravena", "celeste"]


def make_snapshot(slot_id: str = "slot1") -> dict:
    npcs = []
    for index, npc_id in enumerate(NPC_IDS):
        relationships = {
            other: {
                "affinity": 10.0 + index,
                "trust": 30.0,
                "interactions": 0,
                "last_meeting": None,
                "history": [],
            }
            for other in NPC_IDS + ["jogadora_1"]
            if other != npc_id
        }
        npcs.append(
            {
                "id": npc_id,
                "name": npc_id.capitalize(),
                "species": "coelho",
                "personality": {
                    "sociabilidade": 0.1 * index,
                    "gentileza": 0.5,
                    "curiosidade": 0.4,
                    "coragem": 0.3,
                    "energia": 0.6,
                },
                "needs": {"energia": 80.0, "social": 60.0, "diversao": 50.0, "conforto": 70.0},
                "emotion": {"mood": "contente", "valence": 0.3},
                "state": "IDLE",
                "activity": "parado",
                "position": {"x": float(index), "y": 0.0, "z": 0.0},
                "relationships": relationships,
                "memories": [
                    {
                        "id": f"mem_{npc_id}_1",
                        "type": "community_event",
                        "participants": [npc_id],
                        "day": 1,
                        "minute": 480.0,
                        "description": "Chegou à ilha.",
                        "relevance": 0.7,
                        "consequences": [],
                        "event_ref": "evt_1",
                        "occurrences": 1,
                    }
                ],
                "cooldowns": {},
            }
        )
    return copy.deepcopy(
        {
            "schema_version": 1,
            "game_version": "0.1.0",
            "save_slot_id": slot_id,
            "player_id": "jogadora_1",
            "island_id": "ilha_1",
            "saved_at": "2026-10-19T21:00:00Z",
            "world": {
                "day": 1,
                "minute": 480.0,
                "island_name": "Daybloom",
                "event_seq": 1,
                "resources": [
                    {"id": "flor_1", "kind": "flower", "item_id": "margarida", "available": True, "respawn_day": 0}
                ],
            },
            "player": {
                "id": "jogadora_1",
                "name": "Jogadora",
                "position": {"x": 0.0, "y": 0.0, "z": 0.0},
                "rotation_y": 0.0,
                "inventory": [{"item_id": "margarida", "count": 2}],
            },
            "npcs": npcs,
            "journal": [
                {
                    "event_id": "evt_1",
                    "day": 1,
                    "minute": 480.0,
                    "kind": "community_event",
                    "participants": [],
                    "text": "Uma nova manhã começou na ilha.",
                }
            ],
        }
    )
