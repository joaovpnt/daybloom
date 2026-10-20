"""dbkit — biblioteca de modelagem procedural do Daybloom para Blender (bpy).

Tudo é construído com bmesh (sem depender de contexto da interface), o que
permite rodar em `blender --background`. Convenções:

* 1 unidade = 1 metro; origem nos pés / no centro da base.
* Frente do modelo voltada para -Y no Blender (vira +Z no glTF/Godot).
* Materiais compartilhados por nome (prefixo `DB_`), Principled BSDF simples,
  compatíveis com a importação glTF do Godot.
* Peças de um mesmo personagem são unidas em uma malha com grupos de vértices
  rígidos por osso (skin simples, leve e estável).
"""

from __future__ import annotations

import math
import os
import random
from dataclasses import dataclass, field

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

# ---------------------------------------------------------------------------
# Paleta oficial (Cozy 3D / Pastel Nature)
# ---------------------------------------------------------------------------

PALETTE = {
    "grass": (0.47, 0.72, 0.36),
    "grass_dark": (0.33, 0.58, 0.30),
    "leaf": (0.42, 0.70, 0.36),
    "leaf_light": (0.56, 0.80, 0.42),
    "leaf_dark": (0.28, 0.52, 0.30),
    "pine": (0.24, 0.50, 0.36),
    "pine_light": (0.32, 0.60, 0.42),
    "bark": (0.45, 0.30, 0.20),
    "bark_light": (0.58, 0.40, 0.27),
    "wood": (0.66, 0.46, 0.30),
    "wood_light": (0.82, 0.64, 0.44),
    "wood_dark": (0.42, 0.27, 0.18),
    "stone": (0.72, 0.70, 0.66),
    "stone_dark": (0.52, 0.51, 0.50),
    "sand": (0.96, 0.87, 0.66),
    "cream": (0.99, 0.95, 0.86),
    "white": (0.97, 0.97, 0.95),
    "ink": (0.12, 0.09, 0.10),
    "blush": (0.98, 0.58, 0.60),
    "gold": (0.98, 0.78, 0.30),
    "red": (0.88, 0.32, 0.30),
    "coral": (0.96, 0.52, 0.45),
    "pink": (0.98, 0.70, 0.78),
    "lavender": (0.72, 0.62, 0.92),
    "sky": (0.48, 0.70, 0.92),
    "teal": (0.24, 0.66, 0.68),
    "orange": (0.96, 0.58, 0.24),
    "yellow": (1.0, 0.84, 0.30),
    "mint": (0.62, 0.86, 0.72),
    "glass": (0.62, 0.80, 0.92),
    "metal": (0.30, 0.31, 0.34),
    "mushroom_red": (0.86, 0.28, 0.26),
}

_MATERIALS: dict[str, bpy.types.Material] = {}


def mat(name: str, color=None, roughness: float = 0.82, emission: float = 0.0, metallic: float = 0.0) -> bpy.types.Material:
    """Material compartilhado. `name` vira `DB_<name>` no arquivo."""
    key = f"DB_{name}"
    if key in _MATERIALS and _MATERIALS[key].name in bpy.data.materials:
        return _MATERIALS[key]
    m = bpy.data.materials.get(key) or bpy.data.materials.new(key)
    rgb = color if color is not None else PALETTE.get(name, (0.8, 0.8, 0.8))
    try:
        m.use_nodes = True
    except Exception:
        pass
    m.diffuse_color = (*rgb, 1.0)
    nt = m.node_tree
    bsdf = None
    if nt is not None:
        for node in nt.nodes:
            if node.type == "BSDF_PRINCIPLED":
                bsdf = node
                break
        if bsdf is None:
            bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
            out = next((n for n in nt.nodes if n.type == "OUTPUT_MATERIAL"), None) or nt.nodes.new("ShaderNodeOutputMaterial")
            nt.links.new(bsdf.outputs[0], out.inputs[0])
        bsdf.inputs["Base Color"].default_value = (*rgb, 1.0)
        bsdf.inputs["Roughness"].default_value = roughness
        bsdf.inputs["Metallic"].default_value = metallic
        if emission > 0.0:
            for key_in in ("Emission Color", "Emission"):
                if key_in in bsdf.inputs:
                    bsdf.inputs[key_in].default_value = (*rgb, 1.0)
                    break
            if "Emission Strength" in bsdf.inputs:
                bsdf.inputs["Emission Strength"].default_value = emission
    m.roughness = roughness
    _MATERIALS[key] = m
    return m


def reset_materials_cache() -> None:
    _MATERIALS.clear()


# ---------------------------------------------------------------------------
# Construtor de malhas
# ---------------------------------------------------------------------------

def _xf(loc=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1)) -> Matrix:
    if isinstance(scale, (int, float)):
        scale = (scale, scale, scale)
    return Matrix.LocRotScale(Vector(loc), Euler(rot), Vector(scale))


class MeshBuilder:
    """Acumula primitivas em um único bmesh com materiais e grupos de vértices."""

    def __init__(self, name: str):
        self.name = name
        self.bm = bmesh.new()
        self.deform = self.bm.verts.layers.deform.verify()
        self.materials: list[bpy.types.Material] = []
        self.groups: list[str] = []

    # -- utilidades internas --
    def _mat_index(self, material) -> int:
        if material is None:
            material = mat("white")
        if material not in self.materials:
            self.materials.append(material)
        return self.materials.index(material)

    def _group_index(self, group: str | None) -> int | None:
        if group is None:
            return None
        if group not in self.groups:
            self.groups.append(group)
        return self.groups.index(group)

    def _absorb(self, tmp: bmesh.types.BMesh, matrix: Matrix, material, group, smooth: bool):
        bmesh.ops.transform(tmp, matrix=matrix, verts=tmp.verts)
        mi = self._mat_index(material)
        gi = self._group_index(group)
        vmap = {}
        for v in tmp.verts:
            nv = self.bm.verts.new(v.co)
            if gi is not None:
                nv[self.deform][gi] = 1.0
            vmap[v] = nv
        for f in tmp.faces:
            try:
                nf = self.bm.faces.new([vmap[v] for v in f.verts])
            except ValueError:
                continue
            nf.material_index = mi
            nf.smooth = smooth
        tmp.free()

    # -- primitivas --
    def sphere(self, loc, radius, material=None, group=None, scale=(1, 1, 1), rot=(0, 0, 0), segments=20, rings=12, smooth=True, taper=0.0, bulge=0.0, flatten_bottom=None):
        """Esfera deformável. `taper` afina para cima (>0) ou para baixo (<0)."""
        tmp = bmesh.new()
        bmesh.ops.create_uvsphere(tmp, u_segments=segments, v_segments=rings, radius=radius)
        if taper or bulge or flatten_bottom is not None:
            for v in tmp.verts:
                t = v.co.z / radius  # -1..1
                f = 1.0 - taper * t + bulge * (1.0 - t * t)
                v.co.x *= f
                v.co.y *= f
                if flatten_bottom is not None and v.co.z < -radius * flatten_bottom:
                    v.co.z = -radius * flatten_bottom
        self._absorb(tmp, _xf(loc, rot, scale), material, group, smooth)
        return self

    def ico(self, loc, radius, material=None, group=None, scale=(1, 1, 1), rot=(0, 0, 0), subdiv=2, smooth=False, jitter=0.0, seed=0):
        tmp = bmesh.new()
        bmesh.ops.create_icosphere(tmp, subdivisions=subdiv, radius=radius)
        if jitter:
            rng = random.Random(seed)
            for v in tmp.verts:
                v.co *= 1.0 + rng.uniform(-jitter, jitter)
        self._absorb(tmp, _xf(loc, rot, scale), material, group, smooth)
        return self

    def box(self, loc, size, material=None, group=None, rot=(0, 0, 0), bevel=0.0, segments=2, smooth=False):
        tmp = bmesh.new()
        bmesh.ops.create_cube(tmp, size=1.0)
        bmesh.ops.scale(tmp, vec=Vector(size), verts=tmp.verts)
        if bevel > 0:
            bmesh.ops.bevel(tmp, geom=list(tmp.edges), offset=bevel, segments=segments, affect="EDGES", profile=0.5)
        self._absorb(tmp, _xf(loc, rot), material, group, smooth)
        return self

    def cylinder(self, loc, r_bottom, r_top, depth, material=None, group=None, rot=(0, 0, 0), segments=16, smooth=True, caps=True, bevel=0.0):
        tmp = bmesh.new()
        bmesh.ops.create_cone(tmp, cap_ends=caps, cap_tris=False, segments=segments, radius1=r_bottom, radius2=r_top, depth=depth)
        if bevel > 0:
            rim = [e for e in tmp.edges if len(e.link_faces) == 2 and abs(e.calc_face_angle(0)) > 0.6]
            if rim:
                bmesh.ops.bevel(tmp, geom=rim, offset=bevel, segments=2, affect="EDGES", profile=0.5)
        self._absorb(tmp, _xf(loc, rot), material, group, smooth)
        return self

    def tube(self, points, radii, material=None, group=None, segments=12, smooth=True, caps=True):
        """Tubo suave ao longo de uma polilinha (rabos, membros, orelhas, cabelo)."""
        pts = [Vector(p) for p in points]
        if isinstance(radii, (int, float)):
            radii = [radii] * len(pts)
        tmp = bmesh.new()
        rings = []
        prev_n = None
        for i, p in enumerate(pts):
            if i == 0:
                d = (pts[1] - pts[0]).normalized()
            elif i == len(pts) - 1:
                d = (pts[-1] - pts[-2]).normalized()
            else:
                d = (pts[i + 1] - pts[i - 1]).normalized()
            if prev_n is None:
                helper = Vector((0, 0, 1)) if abs(d.z) < 0.9 else Vector((1, 0, 0))
                n = d.cross(helper).normalized()
            else:
                n = (prev_n - d * prev_n.dot(d)).normalized()
            b = d.cross(n).normalized()
            prev_n = n
            ring = []
            for s in range(segments):
                a = 2 * math.pi * s / segments
                ring.append(tmp.verts.new(p + (n * math.cos(a) + b * math.sin(a)) * radii[i]))
            rings.append(ring)
        for i in range(len(rings) - 1):
            for s in range(segments):
                s2 = (s + 1) % segments
                tmp.faces.new([rings[i][s], rings[i][s2], rings[i + 1][s2], rings[i + 1][s]])
        if caps:
            for idx, end in ((0, pts[0] - (pts[1] - pts[0]).normalized() * radii[0] * 0.6), (-1, pts[-1] + (pts[-1] - pts[-2]).normalized() * radii[-1] * 0.6)):
                c = tmp.verts.new(end)
                ring = rings[idx]
                for s in range(segments):
                    s2 = (s + 1) % segments
                    if idx == 0:
                        tmp.faces.new([ring[s2], ring[s], c])
                    else:
                        tmp.faces.new([ring[s], ring[s2], c])
        bmesh.ops.recalc_face_normals(tmp, faces=tmp.faces)
        self._absorb(tmp, Matrix.Identity(4), material, group, smooth)
        return self

    def prism_roof(self, loc, width, depth, height, thickness, overhang, material=None, group=None, rot=(0, 0, 0)):
        """Telhado de duas águas com espessura e beiral."""
        w = width / 2 + overhang
        d = depth / 2 + overhang
        h = height
        t = thickness
        tmp = bmesh.new()
        # Duas placas inclinadas
        for side in (-1, 1):
            outer_eave = Vector((side * w, 0, -overhang * h / max(width / 2, 0.01)))
            ridge = Vector((0, 0, h))
            nrm = Vector((side * h, 0, width / 2)).normalized()
            vs = []
            for y in (-d, d):
                for base in (outer_eave, ridge):
                    p = base + Vector((0, y, 0))
                    vs.append(tmp.verts.new(p))
                    vs.append(tmp.verts.new(p + nrm * t))
            # vs: [eave_y0, eave_y0_up, ridge_y0, ridge_y0_up, eave_y1, eave_y1_up, ridge_y1, ridge_y1_up]
            e0, e0u, r0, r0u, e1, e1u, r1, r1u = vs
            for quad in ((e0u, r0u, r1u, e1u), (e1, r1, r0, e0), (e0, e0u, e1u, e1), (r0, r1, r1u, r0u), (e0, r0, r0u, e0u), (e1u, r1u, r1, e1)):
                try:
                    tmp.faces.new(quad if side > 0 else quad[::-1])
                except ValueError:
                    pass
        bmesh.ops.recalc_face_normals(tmp, faces=tmp.faces)
        self._absorb(tmp, _xf(loc, rot), material, group, False)
        return self

    def gable(self, loc, width, depth, height, material=None, group=None, rot=(0, 0, 0)):
        """Empena triangular (parede sob o telhado)."""
        tmp = bmesh.new()
        w, d = width / 2, depth / 2
        a = [tmp.verts.new((-w, y, 0)) for y in (-d, d)]
        b = [tmp.verts.new((w, y, 0)) for y in (-d, d)]
        c = [tmp.verts.new((0, y, height)) for y in (-d, d)]
        tmp.faces.new((a[0], b[0], c[0]))
        tmp.faces.new((b[1], a[1], c[1]))
        tmp.faces.new((a[0], c[0], c[1], a[1]))
        tmp.faces.new((b[0], b[1], c[1], c[0]))
        tmp.faces.new((a[0], a[1], b[1], b[0]))
        bmesh.ops.recalc_face_normals(tmp, faces=tmp.faces)
        self._absorb(tmp, _xf(loc, rot), material, group, False)
        return self

    def disc(self, loc, radius, material=None, group=None, rot=(0, 0, 0), segments=24, thickness=0.02, smooth=True):
        return self.cylinder(loc, radius, radius, thickness, material, group, rot, segments, smooth)

    # -- finalização --
    def build(self, collection, parent=None, armature=None) -> bpy.types.Object:
        me = bpy.data.meshes.new(self.name)
        self.bm.normal_update()
        self.bm.to_mesh(me)
        self.bm.free()
        for m in self.materials:
            me.materials.append(m)
        obj = bpy.data.objects.new(self.name, me)
        collection.objects.link(obj)
        for g in self.groups:
            obj.vertex_groups.new(name=g)
        if parent is not None:
            obj.parent = parent
        if armature is not None:
            mod = obj.modifiers.new("Armature", "ARMATURE")
            mod.object = armature
            obj.parent = armature
        return obj


# ---------------------------------------------------------------------------
# Coleções, rigs e animação
# ---------------------------------------------------------------------------

def new_collection(name: str, parent=None) -> bpy.types.Collection:
    col = bpy.data.collections.new(name)
    (parent or bpy.context.scene.collection).children.link(col)
    return col


def clear_scene() -> None:
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    for col in list(bpy.data.collections):
        bpy.data.collections.remove(col)
    for block in (bpy.data.meshes, bpy.data.armatures, bpy.data.actions, bpy.data.materials, bpy.data.cameras, bpy.data.lights, bpy.data.images):
        for item in list(block):
            if item.users == 0:
                block.remove(item)
    reset_materials_cache()


@dataclass
class BoneSpec:
    name: str
    head: tuple
    tail: tuple
    parent: str | None = None


def make_armature(name: str, collection, bones: list[BoneSpec]) -> bpy.types.Object:
    arm_data = bpy.data.armatures.new(name + "_Rig")
    arm = bpy.data.objects.new(name + "_Rig", arm_data)
    collection.objects.link(arm)
    view_layer = bpy.context.view_layer
    # Garante que o objeto esteja visível na view layer para entrar em modo de edição.
    view_layer.update()
    for o in view_layer.objects:
        o.select_set(False)
    view_layer.objects.active = arm
    arm.select_set(True)
    with bpy.context.temp_override(active_object=arm, object=arm, selected_objects=[arm], selected_editable_objects=[arm]):
        bpy.ops.object.mode_set(mode="EDIT")
        for spec in bones:
            eb = arm_data.edit_bones.new(spec.name)
            eb.head = spec.head
            eb.tail = spec.tail
            eb.roll = 0.0
        for spec in bones:
            if spec.parent:
                arm_data.edit_bones[spec.name].parent = arm_data.edit_bones[spec.parent]
        bpy.ops.object.mode_set(mode="OBJECT")
    for pb in arm.pose.bones:
        pb.rotation_mode = "XYZ"
    return arm


def key_pose(arm, frame: int, pose: dict) -> None:
    """pose = {bone: {"rot": (x,y,z) em graus, "loc": (x,y,z)}}; ossos ausentes voltam ao repouso."""
    for pb in arm.pose.bones:
        spec = pose.get(pb.name, {})
        r = spec.get("rot", (0, 0, 0))
        pb.rotation_euler = Euler((math.radians(r[0]), math.radians(r[1]), math.radians(r[2])))
        pb.location = Vector(spec.get("loc", (0, 0, 0)))
        sc = spec.get("scale", (1, 1, 1))
        pb.scale = Vector(sc if not isinstance(sc, (int, float)) else (sc, sc, sc))
        pb.keyframe_insert("rotation_euler", frame=frame)
        pb.keyframe_insert("location", frame=frame)
        pb.keyframe_insert("scale", frame=frame)


def make_action(arm, name: str, keys: list[tuple[int, dict]], cyclic: bool = True) -> bpy.types.Action:
    """Cria uma ação a partir de poses-chave e a guarda numa trilha NLA com o mesmo nome."""
    if arm.animation_data is None:
        arm.animation_data_create()
    action = bpy.data.actions.new(name)
    action.use_fake_user = True
    arm.animation_data.action = action
    for frame, pose in keys:
        key_pose(arm, frame, pose)
    # Interpolação suave
    try:
        fcurves = action.fcurves
    except AttributeError:
        fcurves = []
    for fc in _iter_fcurves(action):
        for kp in fc.keyframe_points:
            kp.interpolation = "BEZIER"
            kp.easing = "AUTO"
        if cyclic:
            try:
                fc.modifiers.new("CYCLES")
            except Exception:
                pass
    track = arm.animation_data.nla_tracks.new()
    track.name = name
    strip = track.strips.new(name, int(keys[0][0]), action)
    strip.name = name
    arm.animation_data.action = None
    return action


def _iter_fcurves(action):
    # Blender 4.4+ usa ações em camadas (layers/strips/channelbags).
    if hasattr(action, "layers") and len(getattr(action, "layers", [])) > 0:
        for layer in action.layers:
            for strip in layer.strips:
                for bag in getattr(strip, "channelbags", []):
                    for fc in bag.fcurves:
                        yield fc
        return
    for fc in getattr(action, "fcurves", []):
        yield fc


# ---------------------------------------------------------------------------
# Exportação
# ---------------------------------------------------------------------------

def ensure_dir(path: str) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)


def _layer_collection(root, name):
    if root.name == name:
        return root
    for child in root.children:
        found = _layer_collection(child, name)
        if found:
            return found
    return None


def export_collection(collection, path: str, animations: bool = False) -> str:
    ensure_dir(path)
    view_layer = bpy.context.view_layer
    lc = _layer_collection(view_layer.layer_collection, collection.name)
    view_layer.active_layer_collection = lc
    kwargs = dict(
        filepath=path,
        export_format="GLB",
        use_active_collection=True,
        use_active_collection_with_nested=True,
        export_apply=True,
        export_yup=True,
        export_materials="EXPORT",
        export_skins=animations,
        export_animations=animations,
        export_extras=False,
    )
    if animations:
        kwargs.update(export_animation_mode="NLA_TRACKS", export_force_sampling=True, export_frame_range=False)
    try:
        bpy.ops.export_scene.gltf(**kwargs)
    except TypeError:
        # Versões sem algum parâmetro: tenta o conjunto mínimo.
        for k in ("use_active_collection_with_nested", "export_extras", "export_force_sampling", "export_frame_range"):
            kwargs.pop(k, None)
        bpy.ops.export_scene.gltf(**kwargs)
    return path


def save_blend(path: str) -> None:
    ensure_dir(path)
    bpy.ops.wm.save_as_mainfile(filepath=path, compress=True)


def rand(seed: int) -> random.Random:
    return random.Random(seed)
