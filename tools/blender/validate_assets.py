"""Valida os assets: .blend abrem, .glb têm geometria, materiais e (personagens) rig e animações.

Uso: blender --background --factory-startup --python tools/blender/validate_assets.py
Gera assets/validation_report.json e termina com código 1 se houver problemas.
"""

import glob
import json
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
MODELS = os.path.join(ROOT, "game", "assets", "models")
BLEND = os.path.join(ROOT, "assets", "blender")
REQUIRED_VILLAGER = {"idle", "walk", "talk", "happy", "sad", "surprised"}
REQUIRED_PLAYER = {"idle", "walk", "run", "interact", "talk"}
EXPRESSIONS = {"Eyes_Open", "Eyes_Happy", "Eyes_Closed", "Eyes_Sad", "Mouth_Smile", "Mouth_Open", "Mouth_Frown"}


def check_glb(path):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    before_actions = set(bpy.data.actions)
    bpy.ops.import_scene.gltf(filepath=path)
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    verts = sum(len(o.data.vertices) for o in meshes)
    mats = {m.name for o in meshes for m in o.data.materials if m}
    arms = [o for o in bpy.data.objects if o.type == "ARMATURE"]
    actions = {a.name.split("_")[0] if False else a.name for a in bpy.data.actions if a not in before_actions}
    names = {o.name.split(".")[0] for o in meshes}
    issues = []
    if verts == 0:
        issues.append("sem geometria")
    if not mats:
        issues.append("sem materiais")
    base = os.path.basename(path)
    if base.startswith("villager_") or base == "player.glb":
        if not arms:
            issues.append("sem armadura")
        else:
            bones = len(arms[0].data.bones)
            if bones < 9:
                issues.append(f"poucos ossos ({bones})")
        anims = {a.split("|")[-1].split("_")[0] if "|" in a else a for a in actions}
        required = REQUIRED_PLAYER if base == "player.glb" else REQUIRED_VILLAGER
        missing = {r for r in required if not any(r == a or a.startswith(r) for a in anims)}
        if missing:
            issues.append(f"animações ausentes: {sorted(missing)}")
        if not EXPRESSIONS.issubset(names):
            issues.append(f"expressões ausentes: {sorted(EXPRESSIONS - names)}")
    return {"file": os.path.relpath(path, ROOT), "verts": verts, "materials": len(mats), "actions": sorted(actions), "issues": issues}


def main():
    report = {"glb": [], "blend": []}
    for path in sorted(glob.glob(os.path.join(MODELS, "**", "*.glb"), recursive=True)):
        report["glb"].append(check_glb(path))
    for path in sorted(glob.glob(os.path.join(BLEND, "**", "*.blend"), recursive=True)):
        try:
            bpy.ops.wm.open_mainfile(filepath=path)
            report["blend"].append({"file": os.path.relpath(path, ROOT), "collections": len(bpy.data.collections), "objects": len(bpy.data.objects), "issues": [] if bpy.data.objects else ["vazio"]})
        except Exception as exc:  # pragma: no cover
            report["blend"].append({"file": os.path.relpath(path, ROOT), "issues": [str(exc)]})
    problems = [r for r in report["glb"] + report["blend"] if r["issues"]]
    report["summary"] = {"glb": len(report["glb"]), "blend": len(report["blend"]), "problems": len(problems)}
    with open(os.path.join(ROOT, "assets", "validation_report.json"), "w", encoding="utf-8") as fh:
        json.dump(report, fh, indent=2, ensure_ascii=False)
    print("VALIDATION", json.dumps(report["summary"]))
    for p in problems:
        print("PROBLEMA", p["file"], p["issues"])
    return 1 if problems else 0


if __name__ == "__main__":
    code = main()
    if bpy.app.background:
        sys.exit(code)
