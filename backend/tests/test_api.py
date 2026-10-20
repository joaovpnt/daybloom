"""Testes da API FastAPI com repositório em memória."""

from __future__ import annotations

import socket
import unittest

try:
    from fastapi.testclient import TestClient
except ImportError:  # pragma: no cover - ambiente sem dependências
    TestClient = None

from app.config import Settings
from app.persistence.memory import MemorySaveRepository
from app.services.dialogue_service import DialogueService
from app.services.ollama_client import OllamaClient
from tests.factories import make_snapshot


def _closed_port() -> int:
    with socket.socket() as s:
        s.bind(("127.0.0.1", 0))
        return s.getsockname()[1]


@unittest.skipIf(TestClient is None, "FastAPI/httpx não instalados")
class ApiTests(unittest.TestCase):
    def setUp(self):
        from app.main import create_app

        self.repo = MemorySaveRepository()
        port = _closed_port()
        settings = Settings(ollama_url=f"http://127.0.0.1:{port}", ollama_timeout_s=1.0)
        dialogue = DialogueService(OllamaClient(settings.ollama_url, "qwen3:4b", 1.0), self.repo)
        self.client = TestClient(create_app(settings, repository=self.repo, dialogue_service=dialogue))

    def test_health(self):
        response = self.client.get("/health")
        self.assertEqual(response.status_code, 200)
        body = response.json()
        self.assertEqual(body["status"], "ok")
        self.assertTrue(body["mongo"]["ok"])
        self.assertFalse(body["ollama"]["reachable"])

    def test_health_com_banco_fora(self):
        self.repo.available = False
        body = self.client.get("/health").json()
        self.assertFalse(body["mongo"]["ok"])

    def test_save_inexistente(self):
        self.assertEqual(self.client.get("/api/v1/saves/slot1").status_code, 404)

    def test_criar_e_carregar(self):
        response = self.client.put("/api/v1/saves/slot1", json={"snapshot": make_snapshot()})
        self.assertEqual(response.status_code, 200, response.text)
        self.assertEqual(response.json()["revision"], 1)
        self.assertTrue(response.json()["persisted"])
        loaded = self.client.get("/api/v1/saves/slot1").json()
        self.assertEqual(loaded["revision"], 1)
        self.assertEqual(len(loaded["snapshot"]["npcs"]), 8)

    def test_conflito_de_revisao(self):
        self.client.put("/api/v1/saves/slot1", json={"snapshot": make_snapshot()})
        response = self.client.put("/api/v1/saves/slot1", json={"snapshot": make_snapshot()})
        self.assertEqual(response.status_code, 409)
        ok = self.client.put("/api/v1/saves/slot1", json={"snapshot": make_snapshot(), "expected_revision": 1})
        self.assertEqual(ok.status_code, 200)
        self.assertEqual(ok.json()["revision"], 2)

    def test_snapshot_invalido(self):
        snap = make_snapshot()
        snap["npcs"] = snap["npcs"][:7]
        response = self.client.put("/api/v1/saves/slot1", json={"snapshot": snap})
        self.assertEqual(response.status_code, 422)
        self.assertNotIn("slot1", self.repo.saves)

    def test_slot_invalido(self):
        response = self.client.get("/api/v1/saves/../etc")
        self.assertIn(response.status_code, (404, 422))

    def test_erro_de_banco_nao_finge_sucesso(self):
        self.repo.available = False
        response = self.client.put("/api/v1/saves/slot1", json={"snapshot": make_snapshot()})
        self.assertEqual(response.status_code, 503)
        self.assertNotIn("persisted", response.json())

    def test_dialogo_fallback(self):
        payload = {
            "exchange_id": "x1",
            "save_slot_id": "slot1",
            "island_id": "ilha_1",
            "player_id": "jogadora_1",
            "npc_id": "lila",
            "message": "Olá!",
            "context": {"npc": {"name": "Lila"}},
        }
        response = self.client.post("/api/v1/dialogue", json=payload)
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["source"], "fallback")


if __name__ == "__main__":
    unittest.main()
