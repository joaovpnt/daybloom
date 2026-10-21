"""Sonda de "conhecimento limitado": pergunta aos moradores sobre acontecimentos
que eles NÃO conhecem e conta quantas respostas inventam algo.

Uso: python -m tools.probe_grounding [--n 16] [--saida sonda.json]

Uma resposta é marcada como "inventou" se, depois da validação do backend,
ainda afirmar ter visto/ouvido o acontecimento ou trouxer detalhes (marcas
como "ouvi dizer", "eu vi", "discutiram porque", "brigaram por").
"""

from __future__ import annotations

import argparse
import asyncio
import json
import re

from app.schemas import DialogueRequest
from app.services.dialogue_service import DialogueService
from app.services.ollama_client import OllamaClient
from tools.benchmark_ollama import PERGUNTAS, contexto

PERGUNTAS_SONDA = [
    "Você viu a briga do Tobias com a Ravena hoje cedo?",
    "Por que o Bento e a Marina discutiram ontem?",
    "O que aconteceu na festa da praia ontem à noite?",
    "Você sabe quem quebrou a ponte do lago?",
    "A Pipa e a Lila fizeram as pazes?",
    "Me conta o que o Otávio falou de mim na praça.",
    "Quem ganhou a corrida de barcos de ontem?",
    "Você ficou sabendo do presente que a Celeste ganhou?",
]
INVENTOU = re.compile(
    r"\b(ouvi dizer|me contaram|fiquei sabendo|eu vi|vi (o|a|eles|elas)|discutiram (porque|por)|brigaram (porque|por)|"
    r"ganhou|quebrou|foi (o|a) [A-Z])",
    re.IGNORECASE,
)


async def main(n: int, url: str, modelo: str) -> dict:
    svc = DialogueService(OllamaClient(url, modelo, 60.0), None)
    casos = []
    for i in range(n):
        npc = PERGUNTAS[i % len(PERGUNTAS)]
        pergunta = PERGUNTAS_SONDA[i % len(PERGUNTAS_SONDA)]
        ctx = contexto(*npc[:6])
        ctx["known_events"] = []  # o morador não sabe de nada disso
        # Como no jogo: moradores citados entram no contexto, sem fatos conhecidos.
        nomes = {"Tobias", "Ravena", "Bento", "Marina", "Pipa", "Lila", "Otávio", "Celeste"}
        ctx["related_npcs"] = [{"id": n.lower(), "name": n, "relation_label": "colegas", "known_facts": []}
                               for n in nomes if n in pergunta and n != npc[1]]
        req = DialogueRequest(exchange_id=f"sonda_{i}", save_slot_id="s", island_id="s", player_id="ana",
                              npc_id=npc[0], message=pergunta, context=ctx)
        r = await svc.respond(req)
        fala = r.reply or ""
        inventou = bool(INVENTOU.search(fala)) if r.source == "ollama" else False
        casos.append({"morador": npc[1], "pergunta": pergunta, "fonte": r.source, "motivo": r.reason, "intencao": r.intent,
                      "resposta": fala, "descartes": r.discarded, "inventou": inventou})
        print(f"[{i + 1}/{n}] {npc[1]} · {r.intent} · {'INVENTOU' if inventou else 'ok'} · {fala}")
    validas = [c for c in casos if c["fonte"] == "ollama"]
    resumo = {
        "respostas_validas": f"{len(validas)}/{n}",
        "inventaram": sum(1 for c in validas if c["inventou"]),
        "admitiram_nao_saber": sum(1 for c in validas if c["intencao"] == "nao_sei"),
        "boatos_removidos_pela_validacao": sum(1 for c in casos if "boato_sem_fonte" in (c["descartes"] or [])),
    }
    return {"resumo": resumo, "casos": casos}


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--n", type=int, default=16)
    ap.add_argument("--url", default="http://127.0.0.1:11434")
    ap.add_argument("--modelo", default="qwen3:4b")
    ap.add_argument("--saida", default="")
    a = ap.parse_args()
    res = asyncio.run(main(a.n, a.url, a.modelo))
    print(json.dumps(res["resumo"], ensure_ascii=False, indent=2))
    if a.saida:
        with open(a.saida, "w", encoding="utf-8") as f:
            json.dump(res, f, ensure_ascii=False, indent=2)
