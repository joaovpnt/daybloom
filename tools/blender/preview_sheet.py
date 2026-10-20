"""Renderiza uma prancha de conferência com modelos .glb (uso interno de QA).

blender --background --factory-startup --python tools/blender/preview_sheet.py -- saida.png modelo1.glb modelo2.glb ... [--frame N] [--action nome]
"""
import math
import os
import sys

import bpy
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:]
out = args[0]
frame = 1
action = None
files = []
i = 1
while i < len(args):
    if args[i] == "--frame":
        frame = int(args[i + 1]); i += 2
    elif args[i] == "--action":
        action = args[i + 1]; i += 2
    elif args[i] == "--iso":
        iso = True; i += 1
    elif args[i] == "--rows":
        rows = int(args[i + 1]); i += 2
    elif args[i] == "--spacing":
        spacing = float(args[i + 1]); i += 2
    else:
        files.append(args[i]); i += 1
spacing = globals().get("spacing", 1.6)
iso = globals().get("iso", False)
rows = globals().get("rows", 1)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
for k, f in enumerate(files):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=f)
    new = [o for o in bpy.data.objects if o not in before]
    roots = [o for o in new if o.parent is None]
    per_row = (len(files) + rows - 1) // rows
    col_i, row_i = k % per_row, k // per_row
    for r in roots:
        r.location.x += (col_i - (per_row - 1) / 2) * spacing
        r.location.y += row_i * spacing * 1.1
    for o in new:
        if o.type == "ARMATURE" and o.animation_data and action:
            for t in o.animation_data.nla_tracks:
                t.mute = t.name != action
            act = bpy.data.actions.get(action)
for o in bpy.data.objects:
    if o.type == "MESH" and o.name.split(".")[0] in ("Eyes_Happy", "Eyes_Closed", "Eyes_Sad", "Mouth_Open", "Mouth_Frown"):
        o.hide_render = True
scene.frame_set(frame)
# chão
bpy.ops.mesh.primitive_plane_add(size=60)
ground = bpy.context.active_object
gm = bpy.data.materials.new("ground"); gm.diffuse_color = (0.55, 0.78, 0.45, 1)
try:
    gm.use_nodes = True
    gm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.55, 0.78, 0.45, 1)
except Exception:
    pass
ground.data.materials.append(gm)
width = max(4.0, ((len(files) + rows - 1) // rows) * spacing)
cam_data = bpy.data.cameras.new("cam")
cam = bpy.data.objects.new("cam", cam_data)
scene.collection.objects.link(cam)
cam_data.type = "ORTHO"
cam_data.ortho_scale = width * 1.05
if iso:
    cam.location = (0, -40 + (rows - 1) * spacing * 0.55, 26)
    cam.rotation_euler = (math.radians(58), 0, 0)
    cam_data.ortho_scale = width * 1.08
else:
    cam.location = (0, -12, 1.25)
    cam.rotation_euler = (math.radians(86), 0, 0)
scene.camera = cam
sun_data = bpy.data.lights.new("sun", "SUN"); sun_data.energy = 2.2
sun = bpy.data.objects.new("sun", sun_data); scene.collection.objects.link(sun)
sun.rotation_euler = (math.radians(50), math.radians(10), math.radians(-35))
world = bpy.data.worlds.new("w"); scene.world = world
try:
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]; bg.inputs[0].default_value = (0.75, 0.86, 0.95, 1); bg.inputs[1].default_value = 0.55
except Exception:
    world.color = (0.75, 0.86, 0.95)
for eng in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT", "BLENDER_WORKBENCH"):
    try:
        scene.render.engine = eng
        break
    except Exception:
        continue
scene.render.resolution_x = int(min(2400, 300 * max(len(files), 3)))
scene.render.resolution_y = 520 if not iso else int(520 * max(1, rows) * 1.25)
scene.render.filepath = out
try:
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.exposure = -0.3
except Exception:
    pass
bpy.ops.render.render(write_still=True)
print("PREVIEW_OK", out)
