"""Gera todos os assets 3D do Daybloom a partir de código (fonte reproduzível).

Uso (Windows, na raiz do repositório):
    blender --background --factory-startup --python tools/blender/generate_assets.py -- [categorias]

Categorias: characters, vegetation, buildings, props, residence, furniture,
renders (padrão: todas).
Saídas:
    assets/blender/<categoria>/*.blend      fontes editáveis
    game/assets/models/<categoria>/*.glb    modelos usados pelo Godot
    game/assets/ui/portraits|icons/*.png    retratos e ícones renderizados
"""

from __future__ import annotations

import os
import sys
import time
import traceback

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import bpy  # noqa: E402

import dbkit  # noqa: E402
import importlib  # noqa: E402

for _m in ("dbkit", "characters", "environment", "renders", "residence"):
    if _m in sys.modules:
        importlib.reload(sys.modules[_m])

ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
BLEND_DIR = os.path.join(ROOT, "assets", "blender")
MODEL_DIR = os.path.join(ROOT, "game", "assets", "models")
LOG = []


def log(msg: str) -> None:
    line = f"[{time.strftime('%H:%M:%S')}] {msg}"
    print(line, flush=True)
    LOG.append(line)


def gen_characters() -> list[str]:
    import characters

    out = []
    dbkit.clear_scene()
    col, _arm = characters.build_player()
    out.append(dbkit.export_collection(col, os.path.join(MODEL_DIR, "characters", "player.glb"), animations=True))
    dbkit.save_blend(os.path.join(BLEND_DIR, "characters", "player", "player.blend"))
    log("jogadora exportada")
    for npc_id in characters.VILLAGERS:
        dbkit.clear_scene()
        col, _arm = characters.build_villager(npc_id)
        out.append(dbkit.export_collection(col, os.path.join(MODEL_DIR, "characters", f"villager_{npc_id}.glb"), animations=True))
        dbkit.save_blend(os.path.join(BLEND_DIR, "characters", "villagers", f"{npc_id}.blend"))
        log(f"morador {npc_id} exportado")
    return out


def gen_environment(kind: str) -> list[str]:
    import environment

    return environment.generate(kind, BLEND_DIR, MODEL_DIR, log)


def gen_residence(kind: str) -> list[str]:
    import residence

    if kind == "furniture":
        return residence.generate_furniture(BLEND_DIR, MODEL_DIR, log)
    return residence.generate_residence(BLEND_DIR, MODEL_DIR, log)


def gen_renders() -> list[str]:
    import renders

    return renders.generate(ROOT, log)


def main(argv: list[str]) -> int:
    cats = argv or ["characters", "vegetation", "buildings", "props", "residence", "furniture", "renders"]
    produced = []
    ok = True
    for cat in cats:
        try:
            log(f"== {cat} ==")
            if cat == "characters":
                produced += gen_characters()
            elif cat in ("vegetation", "buildings", "props"):
                produced += gen_environment(cat)
            elif cat in ("residence", "furniture"):
                produced += gen_residence(cat)
            elif cat == "renders":
                produced += gen_renders()
            else:
                log(f"categoria desconhecida: {cat}")
        except Exception:
            ok = False
            log(traceback.format_exc())
    log(f"{len(produced)} arquivos gerados; {'OK' if ok else 'COM ERROS'}")
    with open(os.path.join(ROOT, "assets", "generate_log.txt"), "w", encoding="utf-8") as fh:
        fh.write("\n".join(LOG))
    return 0 if ok else 1


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    code = main(args)
    if bpy.app.background:
        sys.exit(code)
