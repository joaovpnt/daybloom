"""Gerenciador central das inferências do modelo de linguagem.

Um único modelo é compartilhado pelos oito moradores. As solicitações entram em
uma fila com prioridade (a conversa iniciada pela jogadora vem primeiro) e só
``max_concurrent`` inferências rodam ao mesmo tempo (padrão: 1, adequado a uma
GPU de 6 GB). O orquestrador:

- descarta pedidos repetidos (mesma ``dedup_key`` aguarda o mesmo resultado);
- substitui pedidos obsoletos (mesma ``supersede_key`` cancela o anterior);
- cancela pedidos a pedido do jogo;
- abandona pedidos que esperaram demais na fila (``max_wait_s``);
- limita o tamanho do contexto;
- registra latência, tokens, erros e estado da fila para o painel F3.

O resultado é sempre um ``AIResult``: ``ok=False`` significa que o jogo deve
usar o fallback (diálogos clássicos), nunca que algo aconteceu no mundo.
"""

from __future__ import annotations

import asyncio
import itertools
import logging
import time
from collections import deque
from dataclasses import dataclass, field
from typing import Any, Awaitable, Callable, Optional

from .ollama_client import ChatResult, OllamaError

log = logging.getLogger("daybloom.ai")

# Prioridades (menor = mais urgente).
PRIORIDADE = {
    "dialogo_jogadora": 0,
    "iniciativa": 1,
    "conversa_moradores": 2,
    "plano_objetivo": 3,
}
MAX_CONTEXT_CHARS = 7000

Runner = Callable[[list[dict[str, str]], Any, dict[str, Any]], Awaitable[ChatResult]]


@dataclass
class AIResult:
    ok: bool
    content: str = ""
    reason: str = ""
    latency_ms: int = 0
    queue_ms: int = 0
    prompt_tokens: int = 0
    output_tokens: int = 0
    request_id: str = ""


@dataclass
class AIRequest:
    request_id: str
    kind: str
    npc_id: str
    messages: list[dict[str, str]]
    fmt: Any
    options: dict[str, Any] = field(default_factory=dict)
    dedup_key: str = ""
    supersede_key: str = ""
    max_wait_s: float = 20.0
    created: float = field(default_factory=time.monotonic)
    priority: int = 9
    seq: int = 0
    status: str = "na_fila"  # na_fila | executando | concluida | cancelada | obsoleta | erro
    future: Optional[asyncio.Future] = None


def limitar_contexto(messages: list[dict[str, str]], max_chars: int = MAX_CONTEXT_CHARS) -> list[dict[str, str]]:
    """Corta o histórico mais antigo até caber no limite (mantém sistema e última mensagem)."""
    msgs = [dict(m) for m in messages]

    def total() -> int:
        return sum(len(m.get("content", "")) for m in msgs)

    while total() > max_chars and len(msgs) > 2:
        msgs.pop(1)
    if total() > max_chars and msgs:
        extra = total() - max_chars
        sys_msg = msgs[0]
        sys_msg["content"] = sys_msg["content"][: max(400, len(sys_msg["content"]) - extra)]
    return msgs


class AIOrchestrator:
    def __init__(self, runner: Optional[Runner], max_concurrent: int = 1, enabled: bool = True) -> None:
        self.runner = runner
        self.enabled = enabled and runner is not None
        self.max_concurrent = max(1, int(max_concurrent))
        self._pending: list[AIRequest] = []
        self._active: dict[str, AIRequest] = {}
        self._by_id: dict[str, AIRequest] = {}
        self._by_dedup: dict[str, AIRequest] = {}
        self._seq = itertools.count()
        self._wakeup: Optional[asyncio.Event] = None
        self._workers: list[asyncio.Task] = []
        self.metrics: dict[str, Any] = {
            "total": 0,
            "concluidas": 0,
            "falhas": 0,
            "canceladas": 0,
            "obsoletas": 0,
            "deduplicadas": 0,
            "ultima_latencia_ms": None,
            "latencia_media_ms": None,
            "ultimos_tokens": None,
            "ultimo_tipo": None,
        }
        self.recent_errors: deque = deque(maxlen=8)
        self.max_active_seen = 0

    # --- ciclo de vida -------------------------------------------------------

    def _ensure_workers(self) -> None:
        loop = asyncio.get_running_loop()
        if getattr(self, "_loop", None) is not loop:
            # Novo laço de eventos (ex.: reinício do servidor ou testes): recomeça o estado.
            self._loop = loop
            self._wakeup = asyncio.Event()
            self._workers = []
            stale = [r for r in self._pending if r.future is None or r.future.get_loop() is not loop]
            for r in stale:
                self._pending.remove(r)
            self._active.clear()
        if self._wakeup is None:
            self._wakeup = asyncio.Event()
        self._workers = [w for w in self._workers if not w.done()]
        while len(self._workers) < self.max_concurrent:
            self._workers.append(asyncio.create_task(self._worker()))

    async def shutdown(self) -> None:
        for w in self._workers:
            w.cancel()
        self._workers.clear()

    # --- API pública ---------------------------------------------------------

    async def submit(self, req: AIRequest, overall_timeout_s: float = 60.0) -> AIResult:
        if not self.enabled:
            return AIResult(False, reason="ollama_desativado", request_id=req.request_id)
        loop = asyncio.get_running_loop()
        self.metrics["total"] += 1
        if req.dedup_key and req.dedup_key in self._by_dedup:
            original = self._by_dedup[req.dedup_key]
            if original.future is not None and not original.future.done() and original.future.get_loop() is loop:
                self.metrics["deduplicadas"] += 1
                result = await asyncio.shield(original.future)
                return AIResult(**{**result.__dict__, "request_id": req.request_id})
        if req.supersede_key:
            for old in list(self._pending):
                if old.supersede_key == req.supersede_key:
                    self._finish(old, "obsoleta", AIResult(False, reason="substituida", request_id=old.request_id))
        req.priority = PRIORIDADE.get(req.kind, 9)
        req.seq = next(self._seq)
        self._ensure_workers()
        req.future = loop.create_future()
        req.messages = limitar_contexto(req.messages)
        self._pending.append(req)
        self._by_id[req.request_id] = req
        if req.dedup_key:
            self._by_dedup[req.dedup_key] = req
        self._ensure_workers()
        self._wakeup.set()
        try:
            return await asyncio.wait_for(asyncio.shield(req.future), timeout=overall_timeout_s)
        except asyncio.TimeoutError:
            self.cancel(req.request_id, reason="timeout")
            return AIResult(False, reason="timeout", request_id=req.request_id)

    def cancel(self, request_id: str, reason: str = "cancelada") -> bool:
        req = self._by_id.get(request_id)
        if req is None or req.future is None or req.future.done():
            return False
        status = "cancelada" if reason == "cancelada" else "obsoleta"
        self._finish(req, status, AIResult(False, reason=reason, request_id=request_id))
        return True

    def status(self) -> dict[str, Any]:
        now = time.monotonic()
        return {
            "habilitado": self.enabled,
            "concorrencia_maxima": self.max_concurrent,
            "fila": [
                {"id": r.request_id, "tipo": r.kind, "morador": r.npc_id, "espera_ms": int((now - r.created) * 1000)}
                for r in sorted(self._pending, key=lambda r: (r.priority, r.seq))
            ],
            "em_andamento": [
                {"id": r.request_id, "tipo": r.kind, "morador": r.npc_id, "tempo_ms": int((now - r.created) * 1000)}
                for r in self._active.values()
            ],
            "metricas": dict(self.metrics),
            "erros_recentes": list(self.recent_errors),
        }

    # --- interno --------------------------------------------------------------

    def _finish(self, req: AIRequest, status: str, result: AIResult) -> None:
        req.status = status
        if req in self._pending:
            self._pending.remove(req)
        self._active.pop(req.request_id, None)
        if req.dedup_key and self._by_dedup.get(req.dedup_key) is req:
            del self._by_dedup[req.dedup_key]
        self._by_id.pop(req.request_id, None)
        if status == "cancelada":
            self.metrics["canceladas"] += 1
        elif status == "obsoleta":
            self.metrics["obsoletas"] += 1
        if req.future is not None and not req.future.done():
            req.future.set_result(result)

    def _next(self) -> Optional[AIRequest]:
        now = time.monotonic()
        for req in list(self._pending):
            if now - req.created > req.max_wait_s:
                self._finish(req, "obsoleta", AIResult(False, reason="obsoleta", request_id=req.request_id))
        if not self._pending:
            return None
        req = min(self._pending, key=lambda r: (r.priority, r.seq))
        self._pending.remove(req)
        return req

    async def _worker(self) -> None:
        assert self._wakeup is not None
        while True:
            req = self._next()
            if req is None:
                self._wakeup.clear()
                await self._wakeup.wait()
                continue
            req.status = "executando"
            self._active[req.request_id] = req
            self.max_active_seen = max(self.max_active_seen, len(self._active))
            queue_ms = int((time.monotonic() - req.created) * 1000)
            started = time.perf_counter()
            try:
                chat = await self.runner(req.messages, req.fmt, req.options)
                latency = int((time.perf_counter() - started) * 1000)
                result = AIResult(
                    True,
                    content=chat.content,
                    latency_ms=latency,
                    queue_ms=queue_ms,
                    prompt_tokens=chat.prompt_tokens,
                    output_tokens=chat.output_tokens,
                    request_id=req.request_id,
                )
                self.metrics["concluidas"] += 1
                self.metrics["ultima_latencia_ms"] = latency
                avg = self.metrics["latencia_media_ms"]
                self.metrics["latencia_media_ms"] = latency if avg is None else int(avg * 0.7 + latency * 0.3)
                self.metrics["ultimos_tokens"] = {"entrada": chat.prompt_tokens, "saida": chat.output_tokens}
                self.metrics["ultimo_tipo"] = req.kind
                status = "concluida"
            except OllamaError as exc:
                result = AIResult(False, reason=exc.reason, queue_ms=queue_ms, request_id=req.request_id,
                                  latency_ms=int((time.perf_counter() - started) * 1000))
                self.metrics["falhas"] += 1
                self.recent_errors.append({"tipo": req.kind, "motivo": exc.reason, "quando": time.strftime("%H:%M:%S")})
                status = "erro"
            except asyncio.CancelledError:
                raise
            except Exception as exc:  # nunca derrubar o trabalhador
                log.exception("falha inesperada na inferência")
                result = AIResult(False, reason="erro_interno", queue_ms=queue_ms, request_id=req.request_id)
                self.metrics["falhas"] += 1
                self.recent_errors.append({"tipo": req.kind, "motivo": f"erro_interno: {type(exc).__name__}",
                                           "quando": time.strftime("%H:%M:%S")})
                status = "erro"
            if req.future is not None and req.future.done():
                # Cancelada durante a inferência: o resultado é descartado.
                self._active.pop(req.request_id, None)
                continue
            self._finish(req, status, result)
