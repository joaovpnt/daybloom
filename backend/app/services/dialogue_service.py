"""Camada cognitiva: conversas, iniciativas, falas entre moradores e planos.

O modelo de linguagem NÃO é fonte da verdade. Ele recebe só o que o morador
sabe (montado pelo ContextBuilder do jogo), responde em JSON estruturado e tudo
é validado (``ai_contracts``). Todas as chamadas passam pelo orquestrador
central (uma inferência por vez, com prioridade para a jogadora). Quando algo
falha, a resposta volta com ``source="fallback"`` e o jogo usa seus diálogos
clássicos — nada no mundo muda por causa disso.
"""

from __future__ import annotations

import json
import logging
import re
from typing import Any, Optional

from ..persistence import PersistenceError, SaveRepository
from ..schemas import (
    DialogueRequest,
    DialogueResponse,
    InitiativeRequest,
    NpcChatRequest,
    NpcChatResponse,
    PlanRequest,
    PlanResponse,
)
from . import ai_contracts as contracts
from . import prompt_builder as prompts
from .ai_orchestrator import AIOrchestrator, AIRequest
from .ollama_client import ChatResult, OllamaClient, OllamaError

log = logging.getLogger("daybloom.dialogue")

# Compatibilidade com a 0.2 (formato antigo {"fala", "acao"}).
ALLOWED_ACTIONS = {"nenhuma", "sorrir", "ficar_triste", "lembrar_conversa"}
MAX_REPLY_CHARS = 360
_THINK_RE = re.compile(r"<think>.*?</think>", re.DOTALL | re.IGNORECASE)
_EMOCAO_PARA_ACAO_LEGADA = {"alegre": "sorrir", "animada": "sorrir", "triste": "ficar_triste"}


def _clip(text: Any, limit: int) -> str:
    value = str(text or "").strip()
    return value if len(value) <= limit else value[: limit - 1].rstrip() + "…"


def build_messages(request: DialogueRequest) -> list[dict[str, str]]:
    return prompts.build_dialogue_messages(request.context, request.history, request.message)


def parse_model_output(raw: str) -> tuple[str, str]:
    """Formato legado da 0.2 (mantido para compatibilidade e testes)."""
    text = _THINK_RE.sub("", raw).strip()
    reply: Optional[str] = None
    action = "nenhuma"
    try:
        start, end = text.find("{"), text.rfind("}")
        data = json.loads(text[start : end + 1]) if start != -1 and end > start else None
    except json.JSONDecodeError:
        data = None
    if isinstance(data, dict):
        reply = data.get("fala") or data.get("resposta") or data.get("reply")
        candidate = str(data.get("acao") or data.get("ação") or "nenhuma").strip().lower()
        action = candidate if candidate in ALLOWED_ACTIONS else "nenhuma"
    if not reply:
        if data is None and text and not text.startswith("{"):
            reply = text
        else:
            raise OllamaError("resposta_invalida", "o modelo não forneceu uma fala")
    reply = re.sub(r"\s+", " ", str(reply)).strip().strip('"')
    if not reply:
        raise OllamaError("resposta_vazia", "fala vazia")
    return _clip(reply, MAX_REPLY_CHARS), action


class DialogueService:
    def __init__(
        self,
        client: Optional[OllamaClient],
        repository: Optional[SaveRepository],
        enabled: bool = True,
        orchestrator: Optional[AIOrchestrator] = None,
        max_concurrent: int = 1,
    ) -> None:
        self.client = client
        self.repository = repository
        self.enabled = enabled and client is not None
        if orchestrator is None:
            orchestrator = AIOrchestrator(self._run if client is not None else None, max_concurrent, self.enabled)
        self.orchestrator = orchestrator

    async def _run(self, messages: list[dict[str, str]], fmt: Any, options: dict[str, Any]) -> ChatResult:
        assert self.client is not None
        return await self.client.generate(
            messages,
            fmt=fmt,
            num_predict=int(options.get("num_predict", 200)),
            temperature=float(options.get("temperature", 0.7)),
            num_ctx=int(options.get("num_ctx", 4096)),
        )

    # --- conversa com a jogadora ----------------------------------------------

    async def respond(self, request: DialogueRequest) -> DialogueResponse:
        if not self.enabled:
            return DialogueResponse(exchange_id=request.exchange_id, source="fallback", reason="ollama_desativado")
        perm = contracts.Permissoes.from_context(request.context)
        req = AIRequest(
            request_id=request.exchange_id,
            kind="dialogo_jogadora",
            npc_id=request.npc_id,
            messages=build_messages(request),
            fmt=contracts.json_schema_resposta(),
            options={"num_predict": 240, "temperature": 0.55},
            dedup_key=f"dialogo:{request.exchange_id}",
            supersede_key=f"dialogo:{request.npc_id}",
            max_wait_s=20.0,
        )
        timeout = (self.client.timeout_s if self.client else 25.0) + 25.0
        result = await self.orchestrator.submit(req, overall_timeout_s=timeout)
        base = {
            "exchange_id": request.exchange_id,
            "latency_ms": result.latency_ms,
            "queue_ms": result.queue_ms,
            "prompt_tokens": result.prompt_tokens,
            "output_tokens": result.output_tokens,
        }
        if not result.ok:
            log.info("fallback de diálogo (%s)", result.reason)
            return DialogueResponse(source="fallback", reason=result.reason, **base)
        try:
            valid = contracts.validar_resposta(result.content, perm)
        except contracts.RespostaInvalida as exc:
            log.info("resposta do modelo rejeitada (%s): %s", exc.reason, exc)
            self.orchestrator.recent_errors.append({"tipo": "dialogo_jogadora", "motivo": exc.reason, "quando": ""})
            return DialogueResponse(source="fallback", reason=exc.reason, **base)
        legacy = valid.acao or _EMOCAO_PARA_ACAO_LEGADA.get(valid.emocao, "nenhuma")
        self._record(request, valid, result.latency_ms)
        return DialogueResponse(
            source="ollama",
            reply=valid.fala,
            emotion=valid.emocao,
            intent=valid.intencao,
            memory_ids=valid.memoria_ids,
            action=valid.acao,
            action_params=valid.parametros,
            suggested_action=legacy,
            discarded=valid.descartes,
            **base,
        )

    def _record(self, request: DialogueRequest, valid: contracts.RespostaValidada, latency: int) -> None:
        if self.repository is None:
            return
        try:
            self.repository.record_dialogue(
                {
                    "exchange_id": request.exchange_id,
                    "save_slot_id": request.save_slot_id,
                    "island_id": request.island_id,
                    "player_id": request.player_id,
                    "npc_id": request.npc_id,
                    "message": request.message,
                    "reply": valid.fala,
                    "emotion": valid.emocao,
                    "intent": valid.intencao,
                    "memory_ids": valid.memoria_ids,
                    "suggested_action": valid.acao,
                    "action_params": valid.parametros,
                    "source": "ollama",
                    "latency_ms": latency,
                    "day": (request.context.get("time") or {}).get("day"),
                }
            )
        except PersistenceError as exc:
            log.warning("histórico de diálogo não gravado: %s", exc)

    # --- iniciativa do morador ---------------------------------------------------

    async def initiative(self, request: InitiativeRequest) -> DialogueResponse:
        if not self.enabled:
            return DialogueResponse(exchange_id=request.exchange_id, source="fallback", reason="ollama_desativado")
        perm = contracts.Permissoes.from_context(request.context)
        req = AIRequest(
            request_id=request.exchange_id,
            kind="iniciativa",
            npc_id=request.npc_id,
            messages=prompts.build_initiative_messages(request.context, request.reason, request.detail),
            fmt=contracts.json_schema_resposta(),
            options={"num_predict": 140, "temperature": 0.6},
            dedup_key=f"iniciativa:{request.npc_id}:{request.reason}:{request.detail[:40]}",
            supersede_key=f"iniciativa:{request.npc_id}",
            max_wait_s=12.0,
        )
        result = await self.orchestrator.submit(req, overall_timeout_s=40.0)
        base = {"exchange_id": request.exchange_id, "latency_ms": result.latency_ms, "queue_ms": result.queue_ms,
                "prompt_tokens": result.prompt_tokens, "output_tokens": result.output_tokens}
        if not result.ok:
            return DialogueResponse(source="fallback", reason=result.reason, **base)
        try:
            valid = contracts.validar_resposta(result.content, perm)
        except contracts.RespostaInvalida as exc:
            return DialogueResponse(source="fallback", reason=exc.reason, **base)
        return DialogueResponse(source="ollama", reply=valid.fala, emotion=valid.emocao, intent=valid.intencao,
                                memory_ids=valid.memoria_ids, action=valid.acao, action_params=valid.parametros,
                                discarded=valid.descartes, **base)

    # --- falas entre moradores ------------------------------------------------------

    async def npc_chat(self, request: NpcChatRequest) -> NpcChatResponse:
        if not self.enabled:
            return NpcChatResponse(request_id=request.request_id, source="fallback", reason="ollama_desativado")
        req = AIRequest(
            request_id=request.request_id,
            kind="conversa_moradores",
            npc_id=f"{request.context.get('a', {}).get('id', '')}+{request.context.get('b', {}).get('id', '')}",
            messages=prompts.build_npc_chat_messages(request.context),
            fmt=contracts.json_schema_falas_entre_moradores(
                str(request.context.get("a", {}).get("id", "a")), str(request.context.get("b", {}).get("id", "b"))
            ),
            options={"num_predict": 90, "temperature": 0.8},
            dedup_key=f"npc_chat:{request.request_id}",
            max_wait_s=8.0,
        )
        result = await self.orchestrator.submit(req, overall_timeout_s=30.0)
        if not result.ok:
            return NpcChatResponse(request_id=request.request_id, source="fallback", reason=result.reason)
        try:
            ctx = request.context
            a, b = contracts.validar_falas_entre_moradores(
                result.content,
                str(ctx.get("a", {}).get("id", "a")),
                str(ctx.get("b", {}).get("id", "b")),
                str(ctx.get("a", {}).get("name", "")),
                str(ctx.get("b", {}).get("name", "")),
            )
        except contracts.RespostaInvalida as exc:
            return NpcChatResponse(request_id=request.request_id, source="fallback", reason=exc.reason)
        return NpcChatResponse(request_id=request.request_id, source="ollama", line_a=a, line_b=b,
                               latency_ms=result.latency_ms)

    # --- planos de objetivos ---------------------------------------------------------

    async def plan(self, request: PlanRequest) -> PlanResponse:
        ids = [str(o.get("id")) for o in request.options if o.get("id")]
        if not self.enabled or not ids:
            return PlanResponse(request_id=request.request_id, source="fallback", reason="ollama_desativado")
        req = AIRequest(
            request_id=request.request_id,
            kind="plano_objetivo",
            npc_id=request.npc_id,
            messages=prompts.build_plan_messages(request.context, request.options),
            fmt=contracts.json_schema_plano(),
            options={"num_predict": 80, "temperature": 0.5},
            dedup_key=f"plano:{request.npc_id}:{','.join(ids)}",
            supersede_key=f"plano:{request.npc_id}",
            max_wait_s=30.0,
        )
        result = await self.orchestrator.submit(req, overall_timeout_s=60.0)
        if not result.ok:
            return PlanResponse(request_id=request.request_id, source="fallback", reason=result.reason)
        try:
            option, reason = contracts.validar_plano(result.content, ids)
        except contracts.RespostaInvalida as exc:
            return PlanResponse(request_id=request.request_id, source="fallback", reason=exc.reason)
        return PlanResponse(request_id=request.request_id, source="ollama", option=option, motive=reason,
                            latency_ms=result.latency_ms)
