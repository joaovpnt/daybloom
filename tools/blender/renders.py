"""Renderiza retratos dos personagens e ícones dos itens (PNG com fundo transparente)."""

from __future__ import annotations

import math
import os

import bpy
from mathutils import Vector

NEUTRAL_HIDE = ("Eyes_Happy", "Eyes_Closed", "Eyes_Sad", "Mouth_Open", "Mouth_Frown")
ITEM_MODELS = {
    "margarida": ("environment", "flower_margarida"),
    "tulipa_coral": ("environment", "flower_tulipa_coral"),
    "campanula": ("environment", "flower_campanula"),
    "girassol": ("environment", "flower_girassol"),
    "concha": ("props", "item_shell"),
    "estrela_do_mar": ("props", "item_starfish"),
    "galho": ("props", "item_branch"),
    "pedra_lisa": ("props", "item_stone"),
    "pessego": ("props", "item_pessego"),
    "maca_verde": ("props", "item_maca_verde"),
}


def _setup_scene(res: int):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    for eng in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT", "BLENDER_WORKBENCH"):
        try:
            scene.render.engine = eng
            break
        except Exception:
            continue
    scene.render.film_transparent = True
    scene.render.resolution_x = res
    scene.render.resolution_y = res
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    try:
        scene.view_settings.view_transform = "Standard"
    except Exception:
        pass
    world = bpy.data.worlds.new("w")
    scene.world = world
    try:
        world.use_nodes = True
        bg = world.node_tree.nodes["Background"]
        bg.inputs[0].default_value = (1.0, 0.97, 0.92, 1)
        bg.inputs[1].default_value = 0.7
    except Exception:
        pass
    for name, energy, rot in (("key", 2.2, (50, 0, -30)), ("fill", 1.0, (60, 0, 140))):
        ld = bpy.data.lights.new(name, "SUN")
        ld.energy = energy
        lo = bpy.data.objects.new(name, ld)
        scene.collection.objects.link(lo)
        lo.rotation_euler = tuple(math.radians(a) for a in rot)
    cam_data = bpy.data.cameras.new("cam")
    cam = bpy.data.objects.new("cam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    return scene, cam


def _import(path):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    new = [o for o in bpy.data.objects if o not in before]
    for o in new:
        if o.type == "MESH" and o.name.split(".")[0] in NEUTRAL_HIDE:
            o.hide_render = True
    return new


def _bbox(objs):
    bpy.context.view_layer.update()
    mn = Vector((1e9, 1e9, 1e9))
    mx = Vector((-1e9, -1e9, -1e9))
    for o in objs:
        if o.type != "MESH" or o.hide_render:
            continue
        for c in o.bound_box:
            w = o.matrix_world @ Vector(c)
            mn = Vector((min(mn.x, w.x), min(mn.y, w.y), min(mn.z, w.z)))
            mx = Vector((max(mx.x, w.x), max(mx.y, w.y), max(mx.z, w.z)))
    return mn, mx


def _look(cam, target: Vector, distance: float, elev_deg: float, lens: float = 60.0):
    cam.data.lens = lens
    e = math.radians(elev_deg)
    cam.location = target + Vector((0, -math.cos(e) * distance, math.sin(e) * distance))
    direction = target - cam.location
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


def generate(root: str, log) -> list[str]:
    out = []
    models = os.path.join(root, "game", "assets", "models")
    portraits = os.path.join(root, "game", "assets", "ui", "portraits")
    icons = os.path.join(root, "game", "assets", "ui", "icons")
    os.makedirs(portraits, exist_ok=True)
    os.makedirs(icons, exist_ok=True)
    chars = ["player"] + [f"villager_{n}" for n in ("lila", "tobias", "marina", "otavio", "pipa", "bento", "ravena", "celeste")]
    for name in chars:
        scene, cam = _setup_scene(384)
        objs = _import(os.path.join(models, "characters", f"{name}.glb"))
        mn, mx = _bbox(objs)
        height = mx.z - mn.z
        target = Vector(((mn.x + mx.x) / 2, (mn.y + mx.y) / 2, mn.z + height * 0.74))
        _look(cam, target, height * 1.05, 6, lens=70)
        path = os.path.join(portraits, f"{name.replace('villager_', '')}.png")
        scene.render.filepath = path
        bpy.ops.render.render(write_still=True)
        out.append(path)
        log(f"retrato: {name}")
    for item_id, (sub, model) in ITEM_MODELS.items():
        scene, cam = _setup_scene(192)
        objs = _import(os.path.join(models, sub, f"{model}.glb"))
        mn, mx = _bbox(objs)
        size = max(mx.x - mn.x, mx.y - mn.y, mx.z - mn.z)
        target = (mn + mx) / 2
        _look(cam, target, size * 2.6, 35, lens=60)
        path = os.path.join(icons, f"{item_id}.png")
        scene.render.filepath = path
        bpy.ops.render.render(write_still=True)
        out.append(path)
        log(f"ícone: {item_id}")
    return out
