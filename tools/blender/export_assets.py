"""Reexporta os .glb a partir dos arquivos-fonte .blend (após edições manuais).

Uso: blender --background --factory-startup --python tools/blender/export_assets.py

Cada coleção de primeiro nível de cada .blend vira um .glb com o mesmo nome:
    assets/blender/characters/player/player.blend      -> game/assets/models/characters/player.glb
    assets/blender/characters/villagers/<id>.blend     -> game/assets/models/characters/villager_<id>.glb
    assets/blender/environment/vegetation/*.blend      -> game/assets/models/environment/<colecao>.glb
    assets/blender/environment/buildings/*.blend       -> game/assets/models/buildings/<colecao>.glb
    assets/blender/environment/props/*.blend           -> game/assets/models/props/<colecao>.glb
"""

import glob
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import bpy  # noqa: E402

import dbkit  # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
BLEND = os.path.join(ROOT, "assets", "blender")
MODELS = os.path.join(ROOT, "game", "assets", "models")
TARGETS = {
    os.path.join("characters", "player"): "characters",
    os.path.join("characters", "villagers"): "characters",
    os.path.join("environment", "vegetation"): "environment",
    os.path.join("environment", "buildings"): "buildings",
    os.path.join("environment", "props"): "props",
}


def main() -> int:
    count = 0
    for rel, sub in TARGETS.items():
        for path in sorted(glob.glob(os.path.join(BLEND, rel, "*.blend"))):
            bpy.ops.wm.open_mainfile(filepath=path)
            for col in bpy.context.scene.collection.children:
                animated = any(o.type == "ARMATURE" for o in col.all_objects)
                dbkit.export_collection(col, os.path.join(MODELS, sub, f"{col.name}.glb"), animations=animated)
                count += 1
                print(f"exportado: {sub}/{col.name}.glb")
    print(f"{count} modelos exportados")
    return 0


if __name__ == "__main__":
    code = main()
    if bpy.app.background:
        sys.exit(code)
