"""Cliente mínimo do Ollama usando apenas a biblioteca padrão.

As chamadas HTTP bloqueantes rodam em uma thread separada (``asyncio.to_thread``)
e têm timeout duplo (socket + ``asyncio.wait_for``), para que o servidor nunca
fique preso esperando o modelo.
"""

from __future__ import annotations

import asyncio
import json
import socket
import urllib.error
import urllib.request
from dataclasses import dataclass
from typing import Any


class OllamaError(Exception):
    def __init__(self, reason: str, message: str = "") -> None:
        super().__init__(message or reason)
        self.reason = reason


@dataclass
class OllamaClient:
    base_url: str
    model: str
    timeout_s: float

    def _post_json(self, path: str, payload: dict[str, Any], timeout: float) -> dict[str, Any]:
        body = json.dumps(payload).encode("utf-8")
        request = urllib.request.Request(
            self.base_url + path,
            data=body,
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        # Ollama é local: ignorar proxies configurados no sistema.
        opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
        try:
            with opener.open(request, timeout=timeout) as response:
                return json.loads(response.read().decode("utf-8"))
        except urllib.error.HTTPError as exc:
            if exc.code == 404:
                raise OllamaError("modelo_indisponivel", f"modelo {self.model} não encontrado") from exc
            raise OllamaError("erro_http", f"Ollama respondeu HTTP {exc.code}") from exc
        except (socket.timeout, TimeoutError) as exc:
            raise OllamaError("timeout", "o modelo demorou demais para responder") from exc
        except urllib.error.URLError as exc:
            if isinstance(exc.reason, (socket.timeout, TimeoutError)):
                raise OllamaError("timeout", "o modelo demorou demais para responder") from exc
            raise OllamaError("indisponivel", f"Ollama inacessível: {exc.reason}") from exc
        except (ConnectionError, OSError) as exc:
            raise OllamaError("indisponivel", f"Ollama inacessível: {exc}") from exc
        except json.JSONDecodeError as exc:
            raise OllamaError("resposta_invalida", "resposta do Ollama não é JSON") from exc

    async def chat(self, messages: list[dict[str, str]]) -> str:
        payload = {
            "model": self.model,
            "messages": messages,
            "stream": False,
            "format": "json",
            "think": False,
            "keep_alive": "10m",
            "options": {"temperature": 0.7, "num_predict": 160, "num_ctx": 2048},
        }
        try:
            data = await asyncio.wait_for(
                asyncio.to_thread(self._post_json, "/api/chat", payload, self.timeout_s),
                timeout=self.timeout_s + 1.0,
            )
        except asyncio.TimeoutError as exc:
            raise OllamaError("timeout", "o modelo demorou demais para responder") from exc
        message = data.get("message") or {}
        content = message.get("content")
        if not isinstance(content, str) or not content.strip():
            raise OllamaError("resposta_vazia", "o modelo não retornou conteúdo")
        return content

    async def is_reachable(self, timeout: float = 0.8) -> bool:
        def _get() -> bool:
            opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
            try:
                with opener.open(self.base_url + "/api/tags", timeout=timeout) as response:
                    return response.status == 200
            except Exception:
                return False

        try:
            return await asyncio.wait_for(asyncio.to_thread(_get), timeout=timeout + 0.5)
        except asyncio.TimeoutError:
            return False
