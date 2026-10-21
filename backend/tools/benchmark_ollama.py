"""Benchmark do modelo local para os diálogos do Daybloom.

Uso (na pasta backend, com o venv ativo e o Ollama rodando):
    python -m tools.benchmark_ollama [--modelo qwen3:4b] [--n 12] [--saida resultado.json]

Mede, para conversas realistas (mesmo formato de contexto que o jogo envia):
- latência (primeira chamada, que carrega o modelo, e as seguintes);
- tokens de entrada e saída e velocidade de geração;
- taxa de respostas que passam na validação do contrato;
- memória de vídeo (via nvidia-smi, quando disponível).
"""

from __future__ import annotations

import argparse
import asyncio
import json
import statistics
import subprocess
import time

from app.schemas import DialogueRequest
from app.services.dialogue_service import DialogueService
from app.services.ollama_client import OllamaClient

PERGUNTAS = [
    ("lila", "Lila", "coelha", "florista", "extrovertida, carinhosa e otimista", "animada, usa diminutivos", "Oi Lila! Como está o jardim hoje?"),
    ("ravena", "Ravena", "raposa", "pintora", "independente, perfeccionista e franca", "direta, irônica e sincera", "O que você está pintando agora?"),
    ("otavio", "Otávio", "coruja", "astrônomo", "introvertido, sábio e curioso", "formal e pausada", "Qual estrela aparece primeiro à noite?"),
    ("pipa", "Pipa", "esquilo", "carteira", "agitada, curiosa e falante", "acelerada, emenda assuntos", "Tem alguma novidade na ilha?"),
    ("tobias", "Tobias", "urso", "padeiro", "calmo, generoso e paciente", "tranquila e acolhedora", "Que pão você fez hoje?"),
    ("marina", "Marina", "lontra", "guarda-praia", "aventureira e competitiva", "enérgica, gírias de praia", "Bora correr na praia?"),
    ("bento", "Bento", "sapo", "músico", "descontraído e sonhador", "relaxada e musical", "Pode tocar uma música pra mim?"),
    ("celeste", "Dona Celeste", "ovelha", "costureira", "maternal, paciente e gentil", "carinhosa, chama de querida", "A senhora está costurando o quê?"),
]


def contexto(npc_id, nome, especie, ocupacao, perso, fala) -> dict:
    return {
        "island_name": "Daybloom",
        "player_name": "Ana",
        "npc": {"id": npc_id, "name": nome, "species": especie, "occupation": ocupacao,
                "personality_summary": perso, "speech_style": fala, "current_activity": "passeando"},
        "emotion": {"mood": "alegre", "valence": 0.4},
        "time": {"day": 3, "label": "10:30", "period": "manhã"},
        "location": "praça central",
        "relationship": {"affinity": 18, "trust": 30, "label": "colegas", "interactions": 3},
        "memories": [{"ref": "m1", "id": f"mem_{npc_id}_1", "origin": "participacao", "day": 2,
                      "fact": "Conversou com Ana pela primeira vez.", "interpretation": "Gostou dela."}],
        "known_events": [{"fact": "Houve um encontro na praça ao entardecer.", "origin": "participacao", "day": 2}],
        "allowed": {"actions": ["registrar_promessa", "compartilhar_lembranca"], "items": [], "places": []},
    }


def vram_mb() -> int | None:
    try:
        out = subprocess.run(["nvidia-smi", "--query-gpu=memory.used", "--format=csv,noheader,nounits"],
                             capture_output=True, text=True, timeout=10).stdout.strip()
        return int(out.splitlines()[0])
    except Exception:
        return None


async def main(modelo: str, n: int, url: str) -> dict:
    client = OllamaClient(url, modelo, 60.0)
    svc = DialogueService(client, None)
    nomes = await client.list_models()
    resultado: dict = {"modelo": modelo, "instalado": client.model_installed(nomes), "vram_antes_mb": vram_mb(), "chamadas": []}
    if not resultado["instalado"]:
        return resultado
    for i in range(n):
        npc_id, nome, esp, ocup, perso, fala, pergunta = PERGUNTAS[i % len(PERGUNTAS)]
        req = DialogueRequest(exchange_id=f"bench_{i}", save_slot_id="bench", island_id="bench", player_id="ana",
                              npc_id=npc_id, message=pergunta, context=contexto(npc_id, nome, esp, ocup, perso, fala))
        t0 = time.perf_counter()
        resp = await svc.respond(req)
        total = int((time.perf_counter() - t0) * 1000)
        resultado["chamadas"].append({
            "morador": nome, "pergunta": pergunta, "fonte": resp.source, "motivo": resp.reason, "resposta": resp.reply,
            "emocao": resp.emotion, "ms": total, "tokens_entrada": resp.prompt_tokens, "tokens_saida": resp.output_tokens,
        })
        print(f"[{i + 1}/{n}] {nome}: {total} ms · {resp.source} · {resp.reply}")
    resultado["vram_depois_mb"] = vram_mb()
    ok = [c for c in resultado["chamadas"] if c["fonte"] == "ollama"]
    seguintes = [c["ms"] for c in resultado["chamadas"][1:] if c["fonte"] == "ollama"]
    resultado["resumo"] = {
        "validas": f"{len(ok)}/{n}",
        "primeira_ms": resultado["chamadas"][0]["ms"],
        "mediana_ms": int(statistics.median(seguintes)) if seguintes else None,
        "p90_ms": int(sorted(seguintes)[int(len(seguintes) * 0.9) - 1]) if len(seguintes) >= 2 else None,
        "max_ms": max(seguintes) if seguintes else None,
        "tokens_entrada_medio": int(statistics.mean(c["tokens_entrada"] for c in ok)) if ok else None,
        "tokens_saida_medio": int(statistics.mean(c["tokens_saida"] for c in ok)) if ok else None,
        "tokens_por_segundo": round(sum(c["tokens_saida"] for c in ok[1:]) / max(1e-6, sum(c["ms"] for c in ok[1:]) / 1000), 1) if len(ok) > 1 else None,
    }
    return resultado


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--modelo", default="qwen3:4b")
    ap.add_argument("--n", type=int, default=12)
    ap.add_argument("--url", default="http://127.0.0.1:11434")
    ap.add_argument("--saida", default="")
    args = ap.parse_args()
    res = asyncio.run(main(args.modelo, args.n, args.url))
    print(json.dumps(res.get("resumo", res), ensure_ascii=False, indent=2))
    if args.saida:
        with open(args.saida, "w", encoding="utf-8") as f:
            json.dump(res, f, ensure_ascii=False, indent=2)
