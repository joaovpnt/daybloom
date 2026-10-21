"""Testes do serviço de diálogo: Ollama real simulado por um servidor HTTP local."""

from __future__ import annotations

import asyncio
import json
import socket
import threading
import time
import unittest
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

from app.persistence.memory import MemorySaveRepository
from app.schemas import DialogueRequest
from app.services.dialogue_service import DialogueService, build_messages, parse_model_output
from app.services.ollama_client import OllamaClient, OllamaError


def _free_port() -> int:
    with socket.socket() as s:
        s.bind(("127.0.0.1", 0))
        return s.getsockname()[1]


class FakeOllama:
    """Servidor HTTP mínimo que imita o endpoint /api/chat do Ollama."""

    def __init__(self, content: str = "", delay: float = 0.0, status: int = 200) -> None:
        self.content = content
        self.delay = delay
        self.status = status
        self.requests: list[dict] = []
        outer = self

        class Handler(BaseHTTPRequestHandler):
            def log_message(self, *args):
                pass

            def do_GET(self):
                self.send_response(200)
                self.end_headers()
                self.wfile.write(b'{"models": []}')

            def do_POST(self):
                length = int(self.headers.get("Content-Length", 0))
                outer.requests.append(json.loads(self.rfile.read(length)))
                time.sleep(outer.delay)
                self.send_response(outer.status)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                body = {"message": {"role": "assistant", "content": outer.content}}
                try:
                    self.wfile.write(json.dumps(body).encode())
                except (BrokenPipeError, ConnectionResetError):
                    pass

        self.server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        self.server.daemon_threads = True
        self.url = f"http://127.0.0.1:{self.server.server_address[1]}"
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)

    def __enter__(self):
        self.thread.start()
        return self

    def __exit__(self, *exc):
        self.server.shutdown()
        self.server.server_close()


def make_request(message: str = "Oi! Como está seu dia?") -> DialogueRequest:
    return DialogueRequest(
        exchange_id="troca_1",
        save_slot_id="slot1",
        island_id="ilha_1",
        player_id="jogadora_1",
        npc_id="lila",
        message=message,
        context={
            "island_name": "Daybloom",
            "player_name": "Ana",
            "npc": {
                "name": "Lila",
                "species": "coelha",
                "occupation": "florista",
                "personality_summary": "muito sociável e gentil",
                "speech_style": "animada",
                "likes": ["flores"],
                "dislikes": ["galhos"],
                "personal_goal": "abrir uma floricultura",
            },
            "emotion": {"mood": "alegre", "valence": 0.6},
            "relationship": {"affinity": 25, "trust": 40, "label": "amiga"},
            "time": {"day": 2, "label": "09:30", "period": "manhã"},
            "memories": ["Ana deu uma margarida para Lila."] * 10,
            "recent_facts": ["Lila conversou com Bento na praça."],
        },
        history=[{"role": "jogadora", "text": "Bom dia!"}, {"role": "morador", "text": "Bom dia, Ana!"}],
    )


def run(coro):
    return asyncio.run(coro)


class ParseTests(unittest.TestCase):
    def test_json_valido(self):
        reply, action = parse_model_output('{"fala": "Que dia lindo!", "acao": "sorrir"}')
        self.assertEqual(reply, "Que dia lindo!")
        self.assertEqual(action, "sorrir")

    def test_acao_fora_da_lista_e_descartada(self):
        _, action = parse_model_output('{"fala": "Tome 1000 moedas!", "acao": "dar_dinheiro"}')
        self.assertEqual(action, "nenhuma")

    def test_remove_think(self):
        reply, _ = parse_model_output('<think>planejando</think>{"fala": "Olá!", "acao": "nenhuma"}')
        self.assertEqual(reply, "Olá!")

    def test_texto_puro_aceito(self):
        reply, action = parse_model_output("Olá, tudo bem?")
        self.assertEqual(reply, "Olá, tudo bem?")
        self.assertEqual(action, "nenhuma")

    def test_json_sem_fala_falha(self):
        with self.assertRaises(OllamaError):
            parse_model_output('{"acao": "sorrir"}')

    def test_resposta_longa_cortada(self):
        reply, _ = parse_model_output(json.dumps({"fala": "a" * 2000}))
        self.assertLessEqual(len(reply), 360)

    def test_contexto_limitado(self):
        messages = build_messages(make_request())
        system = messages[0]["content"]
        self.assertIn("Lila", system)
        self.assertIn("português do Brasil", system)
        self.assertLessEqual(system.count("Ana deu uma margarida"), 6)
        self.assertEqual(messages[-1]["content"], "Ana diz: «Oi! Como está seu dia?»")


class ServiceTests(unittest.TestCase):
    def test_resposta_do_modelo(self):
        with FakeOllama('{"fala": "Oi, Ana! Hoje regamos as tulipas.", "emocao": "alegre", "intencao": "conversar", "memoria_referenciada_ids": [], "acao_sugerida": null}') as fake:
            repo = MemorySaveRepository()
            service = DialogueService(OllamaClient(fake.url, "qwen3:4b", 5.0), repo)
            response = run(service.respond(make_request()))
        self.assertEqual(response.source, "ollama")
        self.assertEqual(response.suggested_action, "sorrir")
        self.assertIn("tulipas", response.reply)
        self.assertEqual(fake.requests[0]["model"], "qwen3:4b")
        self.assertFalse(fake.requests[0]["stream"])
        self.assertIn("troca_1", repo.dialogue_history)

    def test_fallback_sem_ollama(self):
        port = _free_port()  # ninguém escutando nesta porta
        service = DialogueService(OllamaClient(f"http://127.0.0.1:{port}", "qwen3:4b", 5.0), None)
        response = run(service.respond(make_request()))
        self.assertEqual(response.source, "fallback")
        # No Windows, uma porta fechada pode demorar a recusar a conexão.
        self.assertIn(response.reason, ("indisponivel", "timeout"))
        self.assertIsNone(response.reply)

    def test_timeout_do_modelo(self):
        with FakeOllama('{"fala": "tarde demais"}', delay=3.0) as fake:
            service = DialogueService(OllamaClient(fake.url, "qwen3:4b", 0.5), None)
            started = time.perf_counter()
            response = run(service.respond(make_request()))
            elapsed = time.perf_counter() - started
        self.assertEqual(response.source, "fallback")
        self.assertEqual(response.reason, "timeout")
        self.assertLess(elapsed, 2.5)

    def test_modelo_nao_instalado(self):
        with FakeOllama("", status=404) as fake:
            service = DialogueService(OllamaClient(fake.url, "qwen3:4b", 2.0), None)
            response = run(service.respond(make_request()))
        self.assertEqual(response.reason, "modelo_indisponivel")

    def test_desativado(self):
        service = DialogueService(OllamaClient("http://127.0.0.1:1", "x", 1.0), None, enabled=False)
        response = run(service.respond(make_request()))
        self.assertEqual(response.source, "fallback")
        self.assertEqual(response.reason, "ollama_desativado")


if __name__ == "__main__":
    unittest.main()
