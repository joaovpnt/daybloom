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
from typing import Any, Optional


class OllamaError(Exception):
    def __init__(self, reason: str, message: str = "") -> None:
        super().__init__(message or reason)
        self.reason = reason


@dataclass
class ChatResult:
    content: str
    prompt_tokens: int = 0
    output_tokens: int = 0
    total_ms: int = 0
    load_ms: int = 0


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
        """Compatível com a 0.2: devolve só o conteúdo (JSON livre)."""
        result = await self.generate(messages, fmt="json")
        return result.content

    async def generate(
        self,
        messages: list[dict[str, str]],
        fmt: Any = "json",
        num_predict: int = 200,
        temperature: float = 0.7,
        num_ctx: int = 4096,
        timeout_s: Optional[float] = None,
    ) -> "ChatResult":
        """Chamada ao /api/chat com saída estruturada (``fmt`` pode ser um JSON Schema)."""
        timeout = float(timeout_s or self.timeout_s)
        payload = {
            "model": self.model,
            "messages": messages,
            "stream": False,
            "format": fmt,
            "think": False,
            "keep_alive": "30m",
            "options": {"temperature": temperature, "num_predict": num_predict, "num_ctx": num_ctx},
        }
        try:
            data = await asyncio.wait_for(
                asyncio.to_thread(self._post_json, "/api/chat", payload, timeout),
                timeout=timeout + 1.0,
            )
        except asyncio.TimeoutError as exc:
            raise OllamaError("timeout", "o modelo demorou demais para responder") from exc
        message = data.get("message") or {}
        content = message.get("content")
        if not isinstance(content, str) or not content.strip():
            raise OllamaError("resposta_vazia", "o modelo não retornou conteúdo")
        return ChatResult(
            content=content,
            prompt_tokens=int(data.get("prompt_eval_count") or 0),
            output_tokens=int(data.get("eval_count") or 0),
            total_ms=int((data.get("total_duration") or 0) / 1_000_000),
            load_ms=int((data.get("load_duration") or 0) / 1_000_000),
        )

    async def list_models(self, timeout: float = 1.5) -> Optional[list[str]]:
        """Modelos instalados no Ollama (``None`` se o Ollama não responder)."""

        def _get() -> Optional[list[str]]:
            opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
            try:
                with opener.open(self.base_url + "/api/tags", timeout=timeout) as response:
                    data = json.loads(response.read().decode("utf-8"))
                    return [str(m.get("name", "")) for m in data.get("models", [])]
            except Exception:
                return None

        try:
            return await asyncio.wait_for(asyncio.to_thread(_get), timeout=timeout + 0.5)
        except asyncio.TimeoutError:
            return None

    def model_installed(self, names: Optional[list[str]]) -> bool:
        if not names:
            return False
        want = self.model if ":" in self.model else self.model + ":latest"
        return any(n == want or n == self.model for n in names)

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
