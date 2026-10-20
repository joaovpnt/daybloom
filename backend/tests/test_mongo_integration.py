"""Integração real com o MongoDB local.

Usa o banco ``DAYBLOOM_TEST_MONGO_DB`` (padrão: ``daybloom_test``) para não
tocar nos saves reais do banco ``daybloom``. É ignorado, com aviso explícito,
quando o MongoDB não está acessível.
"""

from __future__ import annotations

import os
import unittest

from tests.factories import make_snapshot

try:
    from pymongo import MongoClient
    from pymongo.errors import PyMongoError
except ImportError:  # pragma: no cover
    MongoClient = None

MONGO_URI = os.environ.get("DAYBLOOM_MONGO_URI", "mongodb://127.0.0.1:27017")
TEST_DB = os.environ.get("DAYBLOOM_TEST_MONGO_DB", "daybloom_test")


def _mongo_ok() -> bool:
    if MongoClient is None:
        return False
    try:
        client = MongoClient(MONGO_URI, serverSelectionTimeoutMS=1500)
        client.admin.command("ping")
        client.close()
        return True
    except PyMongoError:
        return False


MONGO_AVAILABLE = _mongo_ok()


@unittest.skipUnless(MONGO_AVAILABLE, f"MongoDB inacessível em {MONGO_URI}")
class MongoIntegrationTests(unittest.TestCase):
    def setUp(self):
        from app.persistence.mongo import MongoSaveRepository
        from app.services.save_service import SaveService

        self.repo = MongoSaveRepository(MONGO_URI, TEST_DB, 2000)
        self.repo._client.drop_database(TEST_DB)
        self.service = SaveService(self.repo)

    def tearDown(self):
        self.repo._client.drop_database(TEST_DB)
        self.repo.close()

    def test_ciclo_completo(self):
        snap = make_snapshot()
        snap["player"]["inventory"] = [{"item_id": "concha", "count": 3}, {"item_id": "tulipa", "count": 1}]
        result = self.service.save("slot1", snap, None)
        self.assertEqual(result.revision, 1)
        self.assertEqual(result.events_recorded, 1)

        stored = self.service.load("slot1")
        self.assertEqual(stored.snapshot["player"]["inventory"], snap["player"]["inventory"])
        self.assertEqual(len(stored.snapshot["npcs"]), 8)
        self.assertEqual(
            stored.snapshot["npcs"][0]["relationships"]["jogadora_1"]["affinity"],
            snap["npcs"][0]["relationships"]["jogadora_1"]["affinity"],
        )

        # Salvar de novo o mesmo estado não duplica nada.
        second = self.service.save("slot1", stored.snapshot, stored.revision)
        self.assertEqual(second.revision, 2)
        self.assertEqual(second.events_recorded, 0)
        self.assertEqual(self.repo.saves.count_documents({}), 1)
        self.assertEqual(self.repo.world_events.count_documents({}), 1)

    def test_conflito(self):
        from app.persistence import RevisionConflict

        self.service.save("slot1", make_snapshot(), None)
        with self.assertRaises(RevisionConflict):
            self.service.save("slot1", make_snapshot(), 7)

    def test_dialogo_idempotente(self):
        entry = {"exchange_id": "e1", "npc_id": "lila", "message": "oi", "reply": "olá"}
        self.assertTrue(self.repo.record_dialogue(entry))
        self.assertFalse(self.repo.record_dialogue(entry))
        self.assertEqual(self.repo.dialogue_history.count_documents({}), 1)


class MongoUnavailableTests(unittest.TestCase):
    @unittest.skipIf(MongoClient is None, "PyMongo não instalado")
    def test_erro_quando_banco_inacessivel(self):
        from app.persistence import PersistenceUnavailable
        from app.persistence.mongo import MongoSaveRepository

        repo = MongoSaveRepository("mongodb://127.0.0.1:1", "daybloom_test", 300)
        with self.assertRaises(PersistenceUnavailable):
            repo.ping()
        repo.close()


if __name__ == "__main__":
    unittest.main()
