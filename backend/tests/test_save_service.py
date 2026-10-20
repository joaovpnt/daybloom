"""Testes das regras de save (não dependem do FastAPI nem do MongoDB)."""

from __future__ import annotations

import json
import unittest
from pathlib import Path

from app.persistence import PersistenceError, RevisionConflict
from app.persistence.memory import MemorySaveRepository
from app.services.save_service import SaveService, SaveValidationError, checksum_of, validate_snapshot
from tests.factories import make_snapshot

FIXTURES = Path(__file__).parent / "fixtures"


class ValidationTests(unittest.TestCase):
    def test_snapshot_valido(self):
        data = validate_snapshot(make_snapshot())
        self.assertEqual(len(data["npcs"]), 8)

    def test_rejeita_quantidade_errada_de_moradores(self):
        snap = make_snapshot()
        snap["npcs"].pop()
        with self.assertRaises(SaveValidationError):
            validate_snapshot(snap)

    def test_rejeita_ids_duplicados(self):
        snap = make_snapshot()
        snap["npcs"][1]["id"] = snap["npcs"][0]["id"]
        with self.assertRaises(SaveValidationError):
            validate_snapshot(snap)

    def test_rejeita_schema_mais_novo(self):
        snap = make_snapshot()
        snap["schema_version"] = 99
        with self.assertRaises(SaveValidationError):
            validate_snapshot(snap)

    def test_rejeita_slot_divergente(self):
        with self.assertRaises(SaveValidationError):
            validate_snapshot(make_snapshot("slot1"), "slot2")

    def test_rejeita_inventario_duplicado(self):
        snap = make_snapshot()
        snap["player"]["inventory"].append({"item_id": "margarida", "count": 1})
        with self.assertRaises(SaveValidationError):
            validate_snapshot(snap)

    def test_rejeita_necessidade_fora_do_intervalo(self):
        snap = make_snapshot()
        snap["npcs"][0]["needs"]["energia"] = 150
        with self.assertRaises(SaveValidationError):
            validate_snapshot(snap)

    def test_campos_extras_sao_preservados(self):
        snap = make_snapshot()
        snap["world"]["campo_futuro"] = {"a": 1}
        data = validate_snapshot(snap)
        self.assertEqual(data["world"]["campo_futuro"], {"a": 1})

    def test_snapshot_exportado_pelo_godot(self):
        fixture = FIXTURES / "snapshot_godot.json"
        if not fixture.is_file():
            self.skipTest("fixture do Godot ainda não gerada (rode os testes do Godot)")
        data = json.loads(fixture.read_text(encoding="utf-8"))
        result = validate_snapshot(data, data["save_slot_id"])
        self.assertEqual(len(result["npcs"]), 8)


class SaveServiceTests(unittest.TestCase):
    def setUp(self):
        self.repo = MemorySaveRepository()
        self.service = SaveService(self.repo)

    def test_cria_e_restaura(self):
        snap = make_snapshot()
        result = self.service.save("slot1", snap, None)
        self.assertEqual(result.revision, 1)
        stored = self.service.load("slot1")
        self.assertEqual(stored.revision, 1)
        self.assertEqual(stored.snapshot["player"]["inventory"], [{"item_id": "margarida", "count": 2}])
        self.assertEqual(len(stored.snapshot["npcs"]), 8)

    def test_controle_de_revisao(self):
        snap = make_snapshot()
        self.service.save("slot1", snap, None)
        self.service.save("slot1", snap, 1)
        with self.assertRaises(RevisionConflict):
            self.service.save("slot1", snap, 1)
        with self.assertRaises(RevisionConflict):
            self.service.save("slot1", snap, None)

    def test_sobrescrita_explicita(self):
        snap = make_snapshot()
        self.service.save("slot1", snap, None)
        result = self.service.save("slot1", snap, None, overwrite=True)
        self.assertEqual(result.revision, 2)

    def test_eventos_idempotentes(self):
        snap = make_snapshot()
        first = self.service.save("slot1", snap, None)
        second = self.service.save("slot1", snap, 1)
        self.assertEqual(first.events_recorded, 1)
        self.assertEqual(second.events_recorded, 0)
        self.assertEqual(len(self.repo.world_events), 1)

    def test_save_invalido_nao_grava(self):
        snap = make_snapshot()
        snap["npcs"] = snap["npcs"][:3]
        with self.assertRaises(SaveValidationError):
            self.service.save("slot1", snap, None)
        self.assertNotIn("slot1", self.repo.saves)

    def test_detecta_corrupcao(self):
        self.service.save("slot1", make_snapshot(), None)
        self.repo.saves["slot1"]["snapshot"]["player"]["name"] = "Adulterado"
        with self.assertRaises(PersistenceError):
            self.service.load("slot1")

    def test_checksum_estavel(self):
        snap = validate_snapshot(make_snapshot())
        self.assertEqual(checksum_of(snap), checksum_of(json.loads(json.dumps(snap))))


if __name__ == "__main__":
    unittest.main()
