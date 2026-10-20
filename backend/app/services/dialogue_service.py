"""Conversas com moradores via Ollama (opcional).

O modelo de linguagem NÃO é fonte da verdade: ele apenas propõe uma fala e,
opcionalmente, uma ação de uma lista fechada. O jogo valida qualquer ação antes
de aplicá-la. Quando o Ollama não responde, devolvemos ``source="fallback"`` e o
jogo usa seu sistema de diálogos contextualizados.
"""

from __future__ import annotations

import json
import logging
import re
import time
from typing import Any, Optional

from ..persistence import PersistenceError, SaveRepository
from ..schemas import DialogueRequest, DialogueResponse
from .ollama_client import OllamaClient, OllamaError

log = logging.getLogger("daybloom.dialogue")

ALLOWED_ACTIONS = {"nenhuma", "sorrir", "ficar_triste", "lembrar_conversa"}
MAX_REPLY_CHARS = 360
_THINK_RE = re.compile(r"<think>.*?</think>", re.DOTALL | re.IGNORECASE)


def _clip(text: Any, limit: int) -> str:
    value = str(text or "").strip()
    return value if len(value) <= limit else value[: limit - 1].rstrip() + "…"


def build_messages(request: DialogueRequest) -> list[dict[str, str]]:
    """Monta um contexto limitado e estruturado para o modelo."""
    ctx = request.context
    npc = ctx.get("npc", {}) or {}
    emotion = ctx.get("emotion", {}) or {}
    relation = ctx.get("relationship", {}) or {}
    clock = ctx.get("time", {}) or {}
    memories = [_clip(m, 160) for m in (ctx.get("memories") or [])[:5]]
    facts = [_clip(f, 160) for f in (ctx.get("recent_facts") or [])[:5]]

    persona = (
        f"Você é {_clip(npc.get('name'), 30)}, um(a) morador(a) {_clip(npc.get('species'), 20)} "
        f"da ilha {_clip(ctx.get('island_name', 'Daybloom'), 30)}, que trabalha como "
        f"{_clip(npc.get('occupation'), 40)}. Personalidade: {_clip(npc.get('personality_summary'), 200)}. "
        f"Jeito de falar: {_clip(npc.get('speech_style'), 160)}. "
        f"Gosta de: {_clip(', '.join(npc.get('likes', [])), 120)}. "
        f"Não gosta de: {_clip(', '.join(npc.get('dislikes', [])), 120)}. "
        f"Objetivo pessoal: {_clip(npc.get('personal_goal'), 120)}."
    )
    situation = (
        f"Agora é dia {clock.get('day', 1)}, {_clip(clock.get('label', ''), 20)} ({_clip(clock.get('period', ''), 12)}). "
        f"Seu humor: {_clip(emotion.get('mood', 'neutro'), 20)}. "
        f"Relação com {_clip(ctx.get('player_name', 'a jogadora'), 24)}: {_clip(relation.get('label', 'conhecida'), 30)} "
        f"(afinidade {relation.get('affinity', 0)}, confiança {relation.get('trust', 0)})."
    )
    memory_block = "\n".join(f"- {m}" for m in memories) or "- (nenhuma lembrança relevante)"
    facts_block = "\n".join(f"- {f}" for f in facts) or "- (nada novo)"
    rules = (
        "Regras: responda SEMPRE em português brasileiro, em 1 a 3 frases curtas, de forma natural, "
        "aconchegante e coerente com sua personalidade. Use apenas os fatos fornecidos; não invente "
        "acontecimentos, itens, pessoas ou lugares. Você não pode dar itens, dinheiro nem mudar nada no "
        "mundo. Responda somente com JSON no formato "
        '{"fala": "sua resposta", "acao": "nenhuma|sorrir|ficar_triste|lembrar_conversa"}. '
        "Use lembrar_conversa apenas se a jogadora contar algo pessoal e importante."
    )
    system = (
        f"{persona}\n{situation}\nLembranças relevantes:\n{memory_block}\n"
        f"Fatos recentes confirmados:\n{facts_block}\n{rules}"
    )
    messages = [{"role": "system", "content": system}]
    for turn in request.history[-6:]:
        role = "user" if turn.role == "jogadora" else "assistant"
        messages.append({"role": role, "content": _clip(turn.text, 300)})
    messages.append({"role": "user", "content": _clip(request.message, 300)})
    return messages


def parse_model_output(raw: str) -> tuple[str, str]:
    """Extrai fala e ação da saída do modelo, sanitizando o resultado."""
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
    ) -> None:
        self.client = client
        self.repository = repository
        self.enabled = enabled and client is not None

    async def respond(self, request: DialogueRequest) -> DialogueResponse:
        started = time.perf_counter()
        if not self.enabled:
            return DialogueResponse(
                exchange_id=request.exchange_id, source="fallback", reason="ollama_desativado"
            )
        try:
            raw = await self.client.chat(build_messages(request))
            reply, action = parse_model_output(raw)
        except OllamaError as exc:
            log.info("fallback de diálogo (%s): %s", exc.reason, exc)
            return DialogueResponse(
                exchange_id=request.exchange_id,
                source="fallback",
                reason=exc.reason,
                latency_ms=int((time.perf_counter() - started) * 1000),
            )
        latency = int((time.perf_counter() - started) * 1000)
        if self.repository is not None:
            try:
                self.repository.record_dialogue(
                    {
                        "exchange_id": request.exchange_id,
                        "save_slot_id": request.save_slot_id,
                        "island_id": request.island_id,
                        "player_id": request.player_id,
                        "npc_id": request.npc_id,
                        "message": request.message,
                        "reply": reply,
                        "suggested_action": action,
                        "source": "ollama",
                        "day": (request.context.get("time") or {}).get("day"),
                    }
                )
            except PersistenceError as exc:
                log.warning("histórico de diálogo não gravado: %s", exc)
        return DialogueResponse(
            exchange_id=request.exchange_id,
            source="ollama",
            reply=reply,
            suggested_action=action,
            latency_ms=latency,
        )
