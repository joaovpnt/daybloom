"""Cenário do Daybloom: casas, vegetação, objetos e itens coletáveis.

Cada asset é construído na origem dentro da sua própria coleção e exportado
como um `.glb` separado. Frente (porta, assento, face principal) voltada para -Y.
"""

from __future__ import annotations

import math
import os
import random

from dbkit import MeshBuilder, PALETTE, clear_scene, export_collection, mat, new_collection, save_blend

TAU = math.tau


def _export(col, model_dir, sub, name, out):
    out.append(export_collection(col, os.path.join(model_dir, sub, f"{name}.glb")))


# ===========================================================================
# Vegetação
# ===========================================================================

def tree_round(name, seed, leaf="leaf", height=2.4, spread=1.0, fruit=None):
    rng = random.Random(seed)
    col = new_collection(name)
    b = MeshBuilder(name)
    bark = mat("bark")
    # Tronco levemente curvo com raízes
    lean = rng.uniform(-0.15, 0.15)
    b.tube([(0, 0, -0.05), (lean * 0.3, 0, height * 0.35), (lean, 0.05, height * 0.7)], [0.24, 0.17, 0.12], bark, segments=10)
    for k in range(4):
        a = k * TAU / 4 + rng.uniform(-0.3, 0.3)
        b.tube([(math.cos(a) * 0.1, math.sin(a) * 0.1, 0.18), (math.cos(a) * 0.38, math.sin(a) * 0.38, 0.0)], [0.09, 0.04], bark, segments=6)
    # Galho lateral
    a = rng.uniform(0, TAU)
    b.tube([(lean * 0.6, 0, height * 0.55), (math.cos(a) * 0.5, math.sin(a) * 0.5, height * 0.78)], [0.07, 0.04], bark, segments=6)
    # Copa: aglomerado de blobs facetados com cores variadas
    tones = [mat(leaf), mat(leaf + "_light" if leaf + "_light" in PALETTE else "leaf_light"), mat(leaf + "_dark" if leaf + "_dark" in PALETTE else "leaf_dark")]
    cy = height + 0.35
    blobs = [(0, 0, cy, 1.05)]
    for k in range(6):
        a = k * TAU / 6 + rng.uniform(-0.4, 0.4)
        r = rng.uniform(0.55, 0.8) * spread
        blobs.append((math.cos(a) * r, math.sin(a) * r, cy + rng.uniform(-0.35, 0.25), rng.uniform(0.55, 0.78)))
    blobs.append((rng.uniform(-0.2, 0.2), rng.uniform(-0.2, 0.2), cy + 0.6, 0.7))
    for i, (x, y, z, r) in enumerate(blobs):
        b.ico((lean + x, y, z), r * spread, tones[i % 3], subdiv=2, jitter=0.12, seed=seed * 31 + i, scale=(1, 1, 0.85))
    if fruit:
        fm = mat(f"fruit_{fruit}", {"pessego": (1.0, 0.62, 0.45), "maca_verde": (0.55, 0.82, 0.32)}.get(fruit, (0.9, 0.3, 0.3)), 0.5)
        for k in range(9):
            a = k * TAU / 9 + rng.uniform(-0.2, 0.2)
            r = rng.uniform(0.85, 1.15) * spread
            b.sphere((lean + math.cos(a) * r, math.sin(a) * r, cy + rng.uniform(-0.45, 0.2)), 0.11, fm, segments=10, rings=6)
    b.build(col)
    return col


def tree_pine(name, seed, height=3.2):
    rng = random.Random(seed)
    col = new_collection(name)
    b = MeshBuilder(name)
    b.cylinder((0, 0, 0.35), 0.18, 0.13, 0.7, mat("bark"), segments=8)
    tiers = 4
    for k in range(tiers):
        t = k / tiers
        r = 1.25 * (1.0 - t * 0.72)
        z = 0.65 + t * height * 0.78
        tone = mat("pine") if k % 2 == 0 else mat("pine_light")
        b.cylinder((rng.uniform(-0.04, 0.04), rng.uniform(-0.04, 0.04), z + 0.42), r, r * 0.25, 0.95, tone, segments=9, smooth=False, rot=(0, 0, rng.uniform(0, 1)))
    b.cylinder((0, 0, 0.65 + height * 0.85), 0.32, 0.0, 0.6, mat("pine_light"), segments=8, smooth=False)
    b.build(col)
    return col


def bush(name, seed, flowers=None, size=1.0):
    rng = random.Random(seed)
    col = new_collection(name)
    b = MeshBuilder(name)
    for i in range(5):
        a = i * TAU / 5 + rng.uniform(-0.3, 0.3)
        r = rng.uniform(0.15, 0.35) * size
        b.ico((math.cos(a) * r, math.sin(a) * r, 0.35 * size + rng.uniform(-0.05, 0.1)), rng.uniform(0.32, 0.45) * size, mat("leaf_dark" if i % 2 else "leaf"), subdiv=2, jitter=0.1, seed=seed + i, scale=(1, 1, 0.8))
    if flowers:
        fm = mat(f"bloom_{flowers}", PALETTE.get(flowers, (1, 0.7, 0.8)), 0.6)
        for i in range(12):
            a = rng.uniform(0, TAU)
            z = rng.uniform(0.3, 0.7) * size
            r = (0.55 - abs(z - 0.45 * size)) * size
            b.sphere((math.cos(a) * r * 0.9, math.sin(a) * r * 0.9, z), 0.06 * size, fm, segments=8, rings=5)
    b.build(col)
    return col


FLOWER_SPECS = {
    "margarida": {"petal": (0.98, 0.97, 0.92), "center": (1.0, 0.82, 0.28), "petals": 9, "shape": "daisy"},
    "tulipa_coral": {"petal": (0.96, 0.47, 0.42), "center": (0.98, 0.7, 0.4), "petals": 5, "shape": "tulip"},
    "campanula": {"petal": (0.48, 0.58, 0.95), "center": (0.95, 0.95, 0.85), "petals": 5, "shape": "bell"},
    "girassol": {"petal": (1.0, 0.82, 0.22), "center": (0.45, 0.28, 0.15), "petals": 12, "shape": "daisy"},
}


def flower(name, item_id, seed=0, stems=1):
    spec = FLOWER_SPECS[item_id]
    rng = random.Random(seed)
    col = new_collection(name)
    b = MeshBuilder(name)
    petal = mat(f"petal_{item_id}", spec["petal"], 0.6)
    center = mat(f"center_{item_id}", spec["center"], 0.6)
    stem = mat("stem", (0.32, 0.6, 0.3))
    for s in range(stems):
        ox, oy = (0, 0) if s == 0 else (rng.uniform(-0.12, 0.12), rng.uniform(-0.12, 0.12))
        h = 0.42 if s == 0 else rng.uniform(0.28, 0.38)
        b.tube([(ox, oy, 0), (ox + 0.02, oy, h * 0.5), (ox, oy, h)], 0.015, stem, segments=5)
        b.sphere((ox + 0.06, oy, h * 0.3), 0.06, stem, scale=(1.2, 0.5, 0.25), rot=(0, -0.5, 0.3), segments=8, rings=4)
        if spec["shape"] == "daisy":
            n = spec["petals"]
            for i in range(n):
                a = i * TAU / n
                b.sphere((ox + math.cos(a) * 0.065, oy + math.sin(a) * 0.065, h), 0.045, petal, scale=(1.4, 0.6, 0.3), rot=(0, 0, a), segments=8, rings=4)
            b.sphere((ox, oy, h + 0.01), 0.035, center, scale=(1, 1, 0.6), segments=10, rings=6)
        elif spec["shape"] == "tulip":
            for i in range(3):
                a = i * TAU / 3
                b.sphere((ox + math.cos(a) * 0.03, oy + math.sin(a) * 0.03, h + 0.05), 0.055, petal, scale=(0.8, 0.8, 1.35), rot=(math.cos(a) * 0.25, math.sin(a) * 0.25, 0), segments=10, rings=6)
        else:
            for i in range(3):
                b.sphere((ox + 0.04 * (i - 1), oy, h - 0.02 * i), 0.045, petal, scale=(1, 1, 0.9), taper=-0.4, segments=10, rings=6)
    b.build(col)
    return col


def mushrooms(name, seed):
    rng = random.Random(seed)
    col = new_collection(name)
    b = MeshBuilder(name)
    red = mat("mushroom_red")
    for i in range(3):
        x, y = rng.uniform(-0.15, 0.15), rng.uniform(-0.15, 0.15)
        h = rng.uniform(0.1, 0.22)
        b.cylinder((x, y, h / 2), 0.03, 0.025, h, mat("cream"), segments=8)
        b.sphere((x, y, h), rng.uniform(0.06, 0.1), red if i != 1 else mat("mushroom_brown", (0.72, 0.5, 0.32)), scale=(1, 1, 0.6), flatten_bottom=0.1, segments=12, rings=8)
        for k in range(3):
            a = rng.uniform(0, TAU)
            b.sphere((x + math.cos(a) * 0.04, y + math.sin(a) * 0.04, h + 0.04), 0.012, mat("white"), segments=6, rings=4)
    b.build(col)
    return col


def rock(name, seed, size=1.0, color="stone"):
    col = new_collection(name)
    b = MeshBuilder(name)
    rng = random.Random(seed)
    b.ico((0, 0, 0.18 * size), 0.35 * size, mat(color), subdiv=1, jitter=0.22, seed=seed, scale=(1.2, 1.0, 0.7))
    if rng.random() < 0.6:
        b.ico((0.32 * size, 0.1 * size, 0.08 * size), 0.16 * size, mat(color), subdiv=1, jitter=0.2, seed=seed + 1)
    b.build(col)
    return col


def log_prop(name, seed, stump=False):
    col = new_collection(name)
    b = MeshBuilder(name)
    if stump:
        b.cylinder((0, 0, 0.18), 0.28, 0.24, 0.36, mat("bark"), segments=10)
        b.cylinder((0, 0, 0.365), 0.235, 0.235, 0.01, mat("wood_light"), segments=10)
        for k in range(4):
            a = k * TAU / 4 + 0.3
            b.tube([(math.cos(a) * 0.15, math.sin(a) * 0.15, 0.12), (math.cos(a) * 0.38, math.sin(a) * 0.38, 0.0)], [0.08, 0.03], mat("bark"), segments=6)
    else:
        b.cylinder((0, 0, 0.18), 0.18, 0.18, 1.4, mat("bark"), rot=(0, math.pi / 2, 0), segments=10)
        for x in (-0.705, 0.705):
            b.cylinder((x, 0, 0.18), 0.16, 0.16, 0.01, mat("wood_light"), rot=(0, math.pi / 2, 0), segments=10)
        b.sphere((0.2, 0.0, 0.36), 0.08, mat("leaf"), scale=(1.5, 1, 0.5))
    b.build(col)
    return col


def grass_tuft(name, seed, tall=False):
    rng = random.Random(seed)
    col = new_collection(name)
    b = MeshBuilder(name)
    for i in range(7):
        a = rng.uniform(0, TAU)
        r = rng.uniform(0.0, 0.12)
        h = rng.uniform(0.2, 0.35) * (1.8 if tall else 1.0)
        bx, by = math.cos(a) * r, math.sin(a) * r
        tip = (bx + math.cos(a) * 0.08, by + math.sin(a) * 0.08, h)
        b.tube([(bx, by, 0), (bx + math.cos(a) * 0.03, by + math.sin(a) * 0.03, h * 0.5), tip], [0.03, 0.022, 0.004], mat("grass_dark" if i % 2 else "grass"), segments=4, caps=False)
    b.build(col)
    return col


def fern(name, seed):
    rng = random.Random(seed)
    col = new_collection(name)
    b = MeshBuilder(name)
    for i in range(7):
        a = i * TAU / 7 + rng.uniform(-0.2, 0.2)
        pts = [(0, 0, 0.02), (math.cos(a) * 0.2, math.sin(a) * 0.2, 0.3), (math.cos(a) * 0.45, math.sin(a) * 0.45, 0.25)]
        b.tube(pts, [0.035, 0.03, 0.01], mat("leaf"), segments=4)
        for k in range(1, 4):
            t = k / 4
            px, py = math.cos(a) * 0.45 * t, math.sin(a) * 0.45 * t
            b.sphere((px, py, 0.18 + 0.12 * math.sin(t * math.pi)), 0.06 * (1.1 - t), mat("leaf_light"), scale=(1.4, 0.7, 0.3), rot=(0, 0, a + 1.57), segments=6, rings=4)
    b.build(col)
    return col


def reeds(name, seed):
    rng = random.Random(seed)
    col = new_collection(name)
    b = MeshBuilder(name)
    for i in range(6):
        x, y = rng.uniform(-0.18, 0.18), rng.uniform(-0.18, 0.18)
        h = rng.uniform(0.6, 1.0)
        b.tube([(x, y, 0), (x + rng.uniform(-0.05, 0.05), y, h)], [0.018, 0.012], mat("grass_dark"), segments=4)
        if i % 2 == 0:
            b.sphere((x, y, h - 0.05), 0.03, mat("bark"), scale=(1, 1, 3.5), segments=8, rings=5)
    b.build(col)
    return col


def lily_pad(name, seed):
    col = new_collection(name)
    b = MeshBuilder(name)
    b.cylinder((0, 0, 0.0), 0.35, 0.35, 0.02, mat("lily", (0.36, 0.68, 0.36)), segments=14)
    b.sphere((0.08, 0.05, 0.05), 0.07, mat("pink"), scale=(1, 1, 0.7), segments=10, rings=6)
    b.build(col)
    return col


def generate_vegetation(blend_dir, model_dir, log):
    clear_scene()
    out = []
    specs = []
    for i, (leaf, h, s) in enumerate((("leaf", 2.3, 1.0), ("leaf", 2.7, 1.1), ("leaf", 2.0, 0.85))):
        specs.append(("tree_round_%s" % "abc"[i], lambda i=i, leaf=leaf, h=h, s=s: tree_round("tree_round_%s" % "abc"[i], 10 + i, leaf, h, s)))
    specs.append(("tree_fruit_pessego", lambda: tree_round("tree_fruit_pessego", 21, "leaf", 2.0, 0.9, fruit="pessego")))
    specs.append(("tree_fruit_maca", lambda: tree_round("tree_fruit_maca", 22, "leaf", 2.1, 0.9, fruit="maca_verde")))
    specs.append(("tree_pine_a", lambda: tree_pine("tree_pine_a", 31, 3.0)))
    specs.append(("tree_pine_b", lambda: tree_pine("tree_pine_b", 32, 3.8)))
    specs.append(("bush_a", lambda: bush("bush_a", 41)))
    specs.append(("bush_b", lambda: bush("bush_b", 42, size=1.25)))
    specs.append(("bush_flower_pink", lambda: bush("bush_flower_pink", 43, flowers="pink")))
    specs.append(("bush_flower_yellow", lambda: bush("bush_flower_yellow", 44, flowers="yellow")))
    for k, item in enumerate(FLOWER_SPECS):
        specs.append((f"flower_{item}", lambda item=item, k=k: flower(f"flower_{item}", item, 50 + k, stems=1)))
        specs.append((f"flowers_{item}_cluster", lambda item=item, k=k: flower(f"flowers_{item}_cluster", item, 60 + k, stems=4)))
    specs.append(("mushrooms", lambda: mushrooms("mushrooms", 71)))
    specs.append(("rock_a", lambda: rock("rock_a", 81, 1.0)))
    specs.append(("rock_b", lambda: rock("rock_b", 82, 1.6)))
    specs.append(("rock_c", lambda: rock("rock_c", 83, 0.6, "stone_dark")))
    specs.append(("log", lambda: log_prop("log", 91)))
    specs.append(("stump", lambda: log_prop("stump", 92, stump=True)))
    specs.append(("grass_tuft_a", lambda: grass_tuft("grass_tuft_a", 101)))
    specs.append(("grass_tuft_b", lambda: grass_tuft("grass_tuft_b", 102, tall=True)))
    specs.append(("fern", lambda: fern("fern", 111)))
    specs.append(("reeds", lambda: reeds("reeds", 121)))
    specs.append(("lily_pad", lambda: lily_pad("lily_pad", 131)))
    for name, fn in specs:
        col = fn()
        _export(col, model_dir, "environment", name, out)
        log(f"vegetação: {name}")
    save_blend(os.path.join(blend_dir, "environment", "vegetation", "vegetation.blend"))
    return out


# ===========================================================================
# Construções
# ===========================================================================

HOUSES = {
    "casa_jogadora": dict(wall=(0.99, 0.93, 0.80), roof=(0.93, 0.48, 0.40), trim=(0.98, 0.98, 0.95), door=(0.55, 0.36, 0.24), w=3.9, d=3.5, h=2.3, roof_h=1.6, theme="jogadora"),
    "casa_lila": dict(wall=(0.99, 0.88, 0.91), roof=(0.70, 0.58, 0.88), trim=(1.0, 0.98, 0.98), door=(0.62, 0.78, 0.55), w=3.6, d=3.4, h=2.2, roof_h=1.7, theme="lila"),
    "casa_tobias": dict(wall=(0.97, 0.87, 0.70), roof=(0.66, 0.38, 0.26), trim=(0.98, 0.95, 0.88), door=(0.48, 0.30, 0.20), w=4.2, d=3.6, h=2.4, roof_h=1.4, theme="tobias"),
    "casa_otavio": dict(wall=(0.80, 0.83, 0.90), roof=(0.24, 0.30, 0.54), trim=(0.92, 0.92, 0.96), door=(0.30, 0.32, 0.50), w=3.2, d=3.2, h=3.0, roof_h=0.0, theme="otavio"),
    "casa_pipa": dict(wall=(1.0, 0.92, 0.72), roof=(0.95, 0.55, 0.22), trim=(0.98, 0.98, 0.94), door=(0.30, 0.48, 0.76), w=3.6, d=3.3, h=2.3, roof_h=1.8, theme="pipa"),
    "casa_marina": dict(wall=(0.86, 0.95, 0.97), roof=(0.22, 0.60, 0.66), trim=(0.98, 0.98, 1.0), door=(0.95, 0.65, 0.35), w=3.8, d=3.4, h=2.3, roof_h=1.2, theme="marina"),
    "casa_bento": dict(wall=(0.90, 0.97, 0.82), roof=(0.34, 0.60, 0.32), trim=(0.98, 0.98, 0.92), door=(0.86, 0.30, 0.28), w=3.7, d=3.4, h=2.2, roof_h=1.5, theme="bento"),
    "casa_ravena": dict(wall=(0.96, 0.88, 0.84), roof=(0.58, 0.24, 0.40), trim=(0.98, 0.96, 0.92), door=(0.30, 0.22, 0.30), w=3.6, d=3.4, h=2.5, roof_h=2.0, theme="ravena"),
    "casa_celeste": dict(wall=(0.99, 0.96, 0.99), roof=(0.80, 0.62, 0.84), trim=(1.0, 1.0, 1.0), door=(0.72, 0.55, 0.80), w=3.8, d=3.4, h=2.2, roof_h=1.5, theme="celeste"),
}


def _window(b, x, y, z, w, h, trim, glass, shutter=None, face="front", box_flowers=None):
    """Janela com moldura, cruz e venezianas. `face`: front (-Y) ou side (+-X)."""
    if face == "front":
        b.box((x, y - 0.04, z), (w + 0.14, 0.08, h + 0.14), trim, bevel=0.02)
        b.box((x, y - 0.07, z), (w, 0.04, h), glass)
        b.box((x, y - 0.1, z), (0.04, 0.03, h), trim)
        b.box((x, y - 0.1, z), (w, 0.03, 0.04), trim)
        b.box((x, y - 0.09, z - h / 2 - 0.08), (w + 0.24, 0.16, 0.05), trim, bevel=0.015)
        if shutter is not None:
            for s in (-1, 1):
                b.box((x + s * (w / 2 + 0.17), y - 0.06, z), (0.16, 0.05, h + 0.06), shutter, bevel=0.015)
        if box_flowers is not None:
            b.box((x, y - 0.17, z - h / 2 - 0.16), (w + 0.1, 0.18, 0.16), mat("wood"), bevel=0.02)
            for i in range(5):
                b.sphere((x - w / 2 + 0.1 + i * (w / 4.4), y - 0.18, z - h / 2 - 0.04), 0.06, box_flowers[i % len(box_flowers)], segments=8, rings=5)
    else:
        sgn = 1 if face == "right" else -1
        b.box((x + sgn * 0.04, y, z), (0.08, w + 0.14, h + 0.14), trim, bevel=0.02)
        b.box((x + sgn * 0.07, y, z), (0.04, w, h), glass)
        b.box((x + sgn * 0.1, y, z), (0.03, 0.04, h), trim)
        b.box((x + sgn * 0.1, y, z), (0.03, w, 0.04), trim)


def _door(b, x, y, z0, w, h, trim, door, round_top=False):
    b.box((x, y - 0.05, z0 + h / 2), (w + 0.2, 0.1, h + 0.12), trim, bevel=0.02)
    b.box((x, y - 0.09, z0 + h / 2 - 0.02), (w, 0.06, h - 0.04), door, bevel=0.02)
    if round_top:
        b.cylinder((x, y - 0.09, z0 + h - 0.02), w / 2, w / 2, 0.06, door, rot=(math.pi / 2, 0, 0), segments=16)
        b.cylinder((x, y - 0.05, z0 + h + 0.0), w / 2 + 0.1, w / 2 + 0.1, 0.1, trim, rot=(math.pi / 2, 0, 0), segments=16)
    for k in range(2):
        b.box((x, y - 0.125, z0 + h * (0.3 + k * 0.38)), (w - 0.14, 0.01, h * 0.28), mat("door_panel", tuple(min(1.0, c * 1.12) for c in door.diffuse_color[:3])), bevel=0.01)
    b.sphere((x + w * 0.32, y - 0.15, z0 + h * 0.48), 0.04, mat("gold", roughness=0.35, metallic=0.6), segments=10, rings=6)
    # Degraus
    b.box((x, y - 0.35, z0 - 0.08), (w + 0.6, 0.5, 0.16), mat("stone"), bevel=0.03)
    b.box((x, y - 0.62, z0 - 0.16), (w + 0.4, 0.3, 0.1), mat("stone_dark"), bevel=0.02)
    # Toldo
    b.box((x, y - 0.32, z0 + h + 0.22), (w + 0.5, 0.6, 0.06), trim, rot=(0.25, 0, 0), bevel=0.02)
    for s in (-1, 1):
        b.tube([(x + s * (w / 2 + 0.15), y - 0.05, z0 + h + 0.05), (x + s * (w / 2 + 0.15), y - 0.5, z0 + h + 0.15)], 0.025, trim, segments=6)


def _flower_pot(b, x, y, z=0.0, color="pink", size=1.0):
    b.cylinder((x, y, z + 0.16 * size), 0.17 * size, 0.13 * size, 0.32 * size, mat("terracotta", (0.82, 0.48, 0.34)), segments=12, bevel=0.0)
    b.ico((x, y, z + 0.38 * size), 0.17 * size, mat("leaf"), subdiv=1, jitter=0.1, seed=int((x + y) * 100))
    for k in range(4):
        a = k * TAU / 4 + x
        b.sphere((x + math.cos(a) * 0.1 * size, y + math.sin(a) * 0.1 * size, z + 0.47 * size), 0.05 * size, mat(color), segments=8, rings=5)


def _fence(b, x0, y0, x1, y1, color, posts=6):
    for i in range(posts):
        t = i / (posts - 1)
        x, y = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
        b.box((x, y, 0.32), (0.09, 0.09, 0.64), color, bevel=0.02)
        b.cylinder((x, y, 0.66), 0.0, 0.065, 0.1, color, segments=4, rot=(math.pi, 0, 0.78))
    ang = math.atan2(y1 - y0, x1 - x0)
    length = math.hypot(x1 - x0, y1 - y0)
    for z in (0.22, 0.48):
        b.box(((x0 + x1) / 2, (y0 + y1) / 2, z), (length, 0.05, 0.07), color, rot=(0, 0, ang), bevel=0.01)


def build_house(house_id: str):
    s = HOUSES[house_id]
    col = new_collection(house_id)
    b = MeshBuilder(house_id)
    wall = mat(f"{house_id}_wall", s["wall"])
    roof = mat(f"{house_id}_roof", s["roof"], 0.7)
    trim = mat(f"{house_id}_trim", s["trim"])
    door = mat(f"{house_id}_door", s["door"])
    glass = mat("window", (0.62, 0.78, 0.92), 0.15)
    w, d, h, rh = s["w"], s["d"], s["h"], s["roof_h"]
    front = -d / 2
    theme = s["theme"]
    # Base de pedra e paredes
    b.box((0, 0, 0.15), (w + 0.3, d + 0.3, 0.3), mat("stone"), bevel=0.05)
    for i in range(int((w + 0.3) / 0.45)):
        b.box((-w / 2 - 0.15 + 0.22 + i * 0.45, front - 0.16, 0.15), (0.38, 0.03, 0.2), mat("stone_dark"), bevel=0.02)
    if theme == "otavio":
        # Torre-observatório: corpo cilíndrico com cúpula
        b.cylinder((0, 0, 0.3 + h / 2), w / 2, w / 2 - 0.08, h, wall, segments=24, smooth=True)
        b.cylinder((0, 0, 0.3 + h + 0.05), w / 2 + 0.15, w / 2 + 0.15, 0.12, trim, segments=24)
        b.sphere((0, 0, 0.3 + h + 0.1), w / 2 + 0.05, roof, scale=(1, 1, 0.9), flatten_bottom=0.0, segments=24, rings=14)
        b.box((0, -0.2, 0.3 + h + 0.9), (0.35, w * 0.6, 0.6), mat("metal"), rot=(0.45, 0, 0), bevel=0.04)
        # estrelas douradas na cúpula e cata-vento
        for k in range(6):
            a = k * TAU / 6
            b.sphere((math.cos(a) * w * 0.38, math.sin(a) * w * 0.38, 0.3 + h + w * 0.32), 0.07, mat("gold", roughness=0.35, emission=0.6), scale=(1, 1, 0.5), segments=8, rings=4)
        b.cylinder((0, 0, 0.3 + h + w / 2 + 0.45), 0.025, 0.025, 0.7, mat("metal"), segments=6)
        for k in range(5):
            a = k * TAU / 5
            b.tube([(0, 0, 0.3 + h + w / 2 + 0.85), (math.cos(a) * 0.18, 0, 0.3 + h + w / 2 + 0.85 + math.sin(a) * 0.18)], [0.03, 0.005], mat("gold", roughness=0.35, emission=0.8), segments=5)
        _door(b, 0, -w / 2 + 0.08, 0.3, 0.95, 1.75, trim, door, round_top=True)
        for a in (0.9, -0.9, 2.2):
            x, y = math.sin(a) * (w / 2 - 0.02), -math.cos(a) * (w / 2 - 0.02)
            b.cylinder((x * 1.02, y * 1.02, 0.3 + h * 0.68), 0.28, 0.28, 0.08, trim, rot=(math.pi / 2, 0, -a), segments=16)
            b.cylinder((x * 1.04, y * 1.04, 0.3 + h * 0.68), 0.22, 0.22, 0.08, glass, rot=(math.pi / 2, 0, -a), segments=16)
        # Telescópio na varanda lateral
        b.cylinder((1.55, -0.6, 0.55), 0.04, 0.04, 0.5, mat("metal"), segments=6)
        b.cylinder((1.55, -0.75, 0.95), 0.08, 0.11, 0.7, mat("gold", roughness=0.35, metallic=0.5), rot=(-0.9, 0, 0.3), segments=12)
    else:
        b.box((0, 0, 0.3 + h / 2), (w, d, h), wall, bevel=0.04)
        # Cantoneiras
        for sx in (-1, 1):
            for sy in (-1, 1):
                b.box((sx * (w / 2 - 0.02), sy * (d / 2 - 0.02), 0.3 + h / 2), (0.14, 0.14, h), trim, bevel=0.02)
        b.box((0, 0, 0.3 + h - 0.05), (w + 0.1, d + 0.1, 0.12), trim, bevel=0.02)
        if theme in ("tobias",):
            # Meia-parede de tijolinhos
            for row in range(4):
                for i in range(int(w / 0.34)):
                    off = 0.17 if row % 2 else 0.0
                    b.box((-w / 2 + 0.2 + i * 0.34 + off, front - 0.03, 0.42 + row * 0.16), (0.3, 0.04, 0.13), mat("brick", (0.80, 0.48, 0.38)), bevel=0.015)
        if theme in ("marina", "bento"):
            # Ripas horizontais de madeira
            for row in range(int(h / 0.24)):
                b.box((0, front - 0.025, 0.42 + row * 0.24), (w - 0.2, 0.03, 0.05), trim, bevel=0.01)
        # Empenas e telhado
        _gable_front_back(b, w, d, h + 0.3, rh, wall)
        _roof(b, w, d, 0.3 + h, rh, roof, trim, theme)
        # Chaminé
        if theme in ("jogadora", "tobias", "celeste", "pipa"):
            cx = w * 0.28 if theme != "tobias" else -w * 0.3
            ch = rh + 0.6 if theme == "tobias" else rh * 0.8 + 0.3
            b.box((cx, d * 0.15, 0.3 + h + ch / 2), (0.45, 0.45, ch), mat("brick", (0.80, 0.48, 0.38)), bevel=0.03)
            b.box((cx, d * 0.15, 0.3 + h + ch + 0.05), (0.55, 0.55, 0.12), mat("stone_dark"), bevel=0.02)
        # Porta e janelas
        door_x = 0.0 if theme not in ("ravena", "pipa") else -w * 0.18
        _door(b, door_x, front, 0.3, 0.9, 1.65, trim, door, round_top=theme in ("lila", "celeste", "jogadora"))
        shutters = mat(f"{house_id}_shutter", s["roof"])
        flowers = [mat("pink"), mat("yellow"), mat("white"), mat("lavender")] if theme in ("lila", "jogadora", "celeste") else None
        wx = w * 0.32
        if theme in ("ravena", "pipa"):
            _window(b, w * 0.2, front, 0.3 + h * 0.58, 0.75, 0.75, trim, glass, shutters, box_flowers=flowers)
        else:
            for sx in (-1, 1):
                _window(b, sx * wx, front, 0.3 + h * 0.58, 0.62, 0.66, trim, glass, shutters if theme != "marina" else None, box_flowers=flowers)
        for sx in (-1, 1):
            _window(b, sx * w / 2, 0.0, 0.3 + h * 0.58, 0.6, 0.62, trim, glass, face="right" if sx > 0 else "left")
        # Janela redonda no frontão
        if rh > 1.2:
            b.cylinder((0, front - 0.02, 0.3 + h + rh * 0.38), 0.24, 0.24, 0.08, trim, rot=(math.pi / 2, 0, 0), segments=16)
            b.cylinder((0, front - 0.05, 0.3 + h + rh * 0.38), 0.18, 0.18, 0.06, glass, rot=(math.pi / 2, 0, 0), segments=16)
    # Detalhes de personalidade (dentro de ~2,5 m do centro)
    _theme_props(b, theme, w, d, h, house_id, s)
    # Caixa de correio
    mx = -w / 2 - 0.25 if theme != "pipa" else w / 2 + 0.25
    b.cylinder((mx, front - 0.55, 0.45), 0.04, 0.04, 0.9, mat("wood"), segments=6)
    b.box((mx, front - 0.55, 0.98), (0.3, 0.42, 0.26), roof, bevel=0.06)
    b.box((mx + 0.17, front - 0.6, 1.05), (0.02, 0.05, 0.2), mat("red"))
    b.build(col)
    return col


def _gable_front_back(b, w, d, z, rh, wall):
    if rh <= 0:
        return
    for sy in (-1, 1):
        y = sy * (d / 2 - 0.01)
        b.gable((0, y, z), w, 0.02, rh, wall)


def _roof(b, w, d, z, rh, roof, trim, theme):
    if rh <= 0:
        return
    over = 0.32
    # Placas inclinadas com espessura e beiral, cumeeira ao longo de Y (frente-trás)
    half = w / 2 + over
    slope = math.atan2(rh, w / 2)
    length = math.hypot(half, rh * half / (w / 2))
    for sx in (-1, 1):
        cx = sx * half / 2
        cz = z + rh - (rh * (half / 2) / (w / 2))
        b.box((cx, 0, cz + 0.04), (length, d + over * 2, 0.14), roof, rot=(0, sx * slope, 0), bevel=0.04)
        # Fiadas de telhas
        for k in range(1, 4):
            t = k / 4
            px = sx * half * t
            pz = z + rh - rh * (half * t) / (w / 2)
            b.box((px, 0, pz + 0.12), (0.06, d + over * 2 + 0.02, 0.04), mat(f"roof_line_{theme}", tuple(c * 0.85 for c in roof.diffuse_color[:3])), rot=(0, sx * slope, 0))
    b.cylinder((0, 0, z + rh + 0.1), 0.1, 0.1, d + over * 2 + 0.05, trim, rot=(math.pi / 2, 0, 0), segments=10)


def _theme_props(b, theme, w, d, h, house_id, s):
    front = -d / 2
    if theme == "jogadora":
        _flower_pot(b, -w / 2 + 0.3, front - 0.5, color="coral")
        _flower_pot(b, w / 2 - 0.3, front - 0.5, color="yellow")
        b.box((w / 2 + 0.45, 0.2, 0.42), (0.5, 1.4, 0.08), mat("wood_light"), bevel=0.02)
        for y in (-0.5, 0.9):
            b.box((w / 2 + 0.45, y, 0.2), (0.45, 0.08, 0.4), mat("wood"), bevel=0.02)
    elif theme == "lila":
        for i, c in enumerate(("pink", "yellow", "coral", "lavender", "white")):
            _flower_pot(b, -w / 2 - 0.25, front + 0.3 + i * 0.6, color=c, size=0.9 + 0.1 * (i % 2))
        # Treliça com trepadeira florida
        for sx in (-1, 1):
            b.box((sx * 0.75, front - 0.55, 1.1), (0.08, 0.08, 2.2), mat("white"), bevel=0.02)
        b.tube([(-0.75, front - 0.55, 2.15), (0, front - 0.55, 2.55), (0.75, front - 0.55, 2.15)], 0.05, mat("white"), segments=8)
        rng = random.Random(7)
        for i in range(16):
            t = i / 15
            x = -0.75 + 1.5 * t
            z = 2.15 + 0.4 * math.sin(t * math.pi)
            b.ico((x, front - 0.55, z), 0.13, mat("leaf"), subdiv=1, jitter=0.15, seed=i)
            b.sphere((x + rng.uniform(-0.1, 0.1), front - 0.66, z + rng.uniform(-0.1, 0.1)), 0.05, mat(("pink", "lavender", "white")[i % 3]), segments=8, rings=5)
    elif theme == "tobias":
        # Placa de pão e toldo listrado
        b.cylinder((w / 2 - 0.4, front - 0.25, h + 0.05), 0.32, 0.32, 0.06, mat("wood_light"), rot=(math.pi / 2, 0, 0), segments=18)
        b.sphere((w / 2 - 0.4, front - 0.3, h + 0.05), 0.2, mat("bread", (0.88, 0.6, 0.32)), scale=(1.3, 0.4, 0.75), segments=12, rings=8)
        for i in range(7):
            col = mat("coral") if i % 2 == 0 else mat("cream")
            b.box((-w / 2 + 0.6 + i * 0.22, front - 0.55, 2.0), (0.22, 0.75, 0.05), col, rot=(0.35, 0, 0))
        # Banco com cesta de pães
        b.box((-w / 2 + 0.6, front - 0.95, 0.42), (1.1, 0.4, 0.07), mat("wood"), bevel=0.02)
        for x in (-0.4, 0.4):
            b.box((-w / 2 + 0.6 + x, front - 0.95, 0.2), (0.08, 0.35, 0.4), mat("wood_dark"))
        b.cylinder((-w / 2 + 0.5, front - 0.95, 0.53), 0.18, 0.14, 0.16, mat("wood_light"), segments=12)
        for k in range(3):
            b.sphere((-w / 2 + 0.42 + k * 0.08, front - 0.95, 0.63), 0.07, mat("bread"), scale=(1.4, 0.8, 0.7), segments=8, rings=5)
        # Barril de farinha
        b.cylinder((w / 2 + 0.35, front + 0.4, 0.35), 0.25, 0.25, 0.7, mat("wood"), segments=12)
        for z in (0.15, 0.55):
            b.cylinder((w / 2 + 0.35, front + 0.4, z), 0.26, 0.26, 0.05, mat("metal"), segments=12)
    elif theme == "otavio":
        b.box((-1.6, 0.6, 0.25), (0.5, 0.5, 0.5), mat("wood"), bevel=0.03)
        for i in range(3):
            b.box((-1.6, 0.6, 0.55 + i * 0.07), (0.32, 0.22, 0.06), mat(("sky", "red", "mint")[i]), bevel=0.01)
        b.sphere((-1.25, -1.2, 0.35), 0.3, mat("leaf_dark"), segments=10, rings=6)
    elif theme == "pipa":
        # Painel de caixinhas de correio coloridas
        for r in range(2):
            for c in range(3):
                x = -w / 2 - 0.35
                b.box((x, front + 0.6 + c * 0.45, 0.8 + r * 0.38), (0.35, 0.38, 0.32), mat(("red", "sky", "yellow", "mint", "coral", "lavender")[r * 3 + c]), bevel=0.04)
        b.box((-w / 2 - 0.35, front + 1.05, 0.38), (0.12, 1.4, 0.76), mat("wood"))
        # Placa com carta
        b.box((w * 0.2, front - 0.08, h + 0.3), (0.7, 0.05, 0.42), mat("wood_light"), bevel=0.03)
        b.box((w * 0.2, front - 0.12, h + 0.3), (0.42, 0.02, 0.26), mat("white"))
        b.cylinder((w * 0.2, front - 0.14, h + 0.3), 0.05, 0.05, 0.02, mat("red"), rot=(math.pi / 2, 0, 0), segments=10)
        # Bolotas decorativas
        for i in range(3):
            b.sphere((w / 2 - 0.3 - i * 0.3, front - 0.5, 0.15), 0.12, mat("bark_light"), scale=(1, 1, 1.2), segments=10, rings=6)
            b.sphere((w / 2 - 0.3 - i * 0.3, front - 0.5, 0.28), 0.12, mat("bark"), scale=(1.05, 1.05, 0.5), segments=10, rings=6)
    elif theme == "marina":
        # Boia salva-vidas, prancha e conchas
        ring = [(w * 0.32 + math.cos(a) * 0.26, front - 0.1, 1.45 + math.sin(a) * 0.26) for a in [i * TAU / 16 for i in range(17)]]
        b.tube(ring, 0.07, mat("white"), segments=8, caps=False)
        for k in range(4):
            a = k * TAU / 4 + 0.4
            b.sphere((w * 0.32 + math.cos(a) * 0.26, front - 0.12, 1.45 + math.sin(a) * 0.26), 0.075, mat("red"), scale=(1, 1, 0.6), segments=8, rings=5)
        b.sphere((w / 2 + 0.25, -0.3, 0.95), 0.25, mat("teal"), scale=(0.25, 0.9, 3.6), rot=(0, -0.15, 0), segments=14, rings=8)
        b.box((w / 2 + 0.2, -0.3, 1.0), (0.02, 0.1, 1.6), mat("white"), rot=(0, -0.15, 0))
        for i in range(5):
            b.sphere((-w / 2 + 0.4 + i * 0.35, front - 0.9, 0.03), 0.07, mat("shell", (0.98, 0.78, 0.76)), scale=(1, 0.8, 0.5), segments=8, rings=5)
    elif theme == "bento":
        # Placa com nota musical, tambor e vitória-régia
        b.box((w * 0.32, front - 0.1, h + 0.25), (0.6, 0.05, 0.5), mat("wood_light"), bevel=0.03)
        b.sphere((w * 0.27, front - 0.14, h + 0.17), 0.07, mat("ink"), scale=(1.2, 0.4, 0.9), segments=8, rings=5)
        b.box((w * 0.32, front - 0.14, h + 0.3), (0.03, 0.02, 0.28), mat("ink"))
        b.box((w * 0.37, front - 0.14, h + 0.4), (0.12, 0.02, 0.05), mat("ink"))
        b.cylinder((-w / 2 - 0.3, front + 0.2, 0.3), 0.28, 0.28, 0.55, mat("red"), segments=16)
        b.cylinder((-w / 2 - 0.3, front + 0.2, 0.585), 0.27, 0.27, 0.03, mat("cream"), segments=16)
        for z in (0.08, 0.52):
            b.cylinder((-w / 2 - 0.3, front + 0.2, z), 0.29, 0.29, 0.04, mat("gold", roughness=0.4), segments=16)
        b.cylinder((w / 2 + 0.6, front + 0.6, 0.02), 0.55, 0.55, 0.03, mat("water_small", (0.45, 0.75, 0.88), 0.2), segments=18)
        b.cylinder((w / 2 + 0.55, front + 0.5, 0.05), 0.2, 0.2, 0.015, mat("lily", (0.36, 0.68, 0.36)), segments=12)
        for k in range(8):
            a = k * TAU / 8
            b.sphere((w / 2 + 0.6 + math.cos(a) * 0.6, front + 0.6 + math.sin(a) * 0.6, 0.05), 0.09, mat("stone"), scale=(1, 1, 0.6), segments=8, rings=4)
    elif theme == "ravena":
        # Cavalete com quadro e latas de tinta
        ex, ey = w / 2 + 0.25, front + 0.2
        for sx in (-1, 1):
            b.box((ex + sx * 0.25, ey, 0.75), (0.05, 0.05, 1.5), mat("wood"), rot=(0, sx * 0.12, 0))
        b.box((ex, ey + 0.25, 0.7), (0.05, 0.05, 1.4), mat("wood"), rot=(-0.3, 0, 0))
        b.box((ex, ey - 0.04, 1.05), (0.7, 0.04, 0.55), mat("white"))
        for i, (px, pz, c) in enumerate(((-0.15, 1.12, "sky"), (0.12, 0.98, "leaf_light"), (0.05, 1.18, "yellow"), (-0.18, 0.92, "coral"))):
            b.box((ex + px, ey - 0.07, pz), (0.22, 0.02, 0.14), mat(c))
        for i, c in enumerate(("red", "sky", "yellow")):
            x = -w / 2 - 0.2 + i * 0.32
            b.cylinder((x, front - 0.6, 0.12), 0.11, 0.11, 0.24, mat("metal"), segments=12)
            b.cylinder((x, front - 0.6, 0.245), 0.1, 0.1, 0.01, mat(c), segments=12)
            b.sphere((x + 0.08, front - 0.72, 0.005), 0.12, mat(c), scale=(1.3, 1, 0.05), segments=10, rings=4)
        for i, c in enumerate(("coral", "sky", "mint", "yellow")):
            b.sphere((-w * 0.3 + i * 0.45, front - 0.03, 0.55 + (i % 2) * 0.4), 0.08, mat(c), scale=(1.2, 0.2, 1), segments=8, rings=5)
    elif theme == "celeste":
        # Cadeira de balanço, cesta de lã e varal de retalhos
        cx, cy = w / 2 - 0.35, front - 0.75
        b.box((cx, cy, 0.42), (0.5, 0.45, 0.06), mat("wood_light"), bevel=0.02)
        b.box((cx, cy + 0.22, 0.75), (0.5, 0.06, 0.6), mat("wood_light"), rot=(-0.15, 0, 0), bevel=0.02)
        for sx in (-1, 1):
            b.tube([(cx + sx * 0.23, cy - 0.35, 0.02), (cx + sx * 0.23, cy, 0.0), (cx + sx * 0.23, cy + 0.35, 0.05)], 0.025, mat("wood"), segments=6)
            b.box((cx + sx * 0.22, cy, 0.22), (0.04, 0.04, 0.4), mat("wood"))
        b.cylinder((-w / 2 + 0.25, front - 0.6, 0.15), 0.2, 0.16, 0.28, mat("wood_light"), segments=12)
        for k, c in enumerate(("lavender", "pink", "sky")):
            b.sphere((-w / 2 + 0.18 + k * 0.08, front - 0.6, 0.32), 0.08, mat(f"yarn_{c}", PALETTE[c]), segments=10, rings=6)
        for sx in (-1, 1):
            b.cylinder((sx * 1.2, d / 2 + 0.8, 0.8), 0.04, 0.04, 1.6, mat("wood"), segments=6)
        b.tube([(-1.2, d / 2 + 0.8, 1.5), (0, d / 2 + 0.8, 1.42), (1.2, d / 2 + 0.8, 1.5)], 0.01, mat("white"), segments=4, caps=False)
        for i, c in enumerate(("pink", "lavender", "mint", "yellow", "sky")):
            b.box((-0.9 + i * 0.45, d / 2 + 0.8, 1.25), (0.32, 0.02, 0.36), mat(c))
    # Cerca lateral em todas as casas (não bloqueia a porta)
    fence = mat(f"{house_id}_fence", (0.98, 0.97, 0.92))
    if theme not in ("otavio",):
        _fence(b, -w / 2 - 0.5, d / 2 + 0.1, -w / 2 - 0.5, -0.2, fence, posts=4)


def generate_buildings(blend_dir, model_dir, log):
    clear_scene()
    out = []
    for house_id in HOUSES:
        col = build_house(house_id)
        _export(col, model_dir, "buildings", house_id, out)
        log(f"construção: {house_id}")
    save_blend(os.path.join(blend_dir, "environment", "buildings", "buildings.blend"))
    return out


# ===========================================================================
# Objetos e itens
# ===========================================================================

def prop(name):
    col = new_collection(name)
    return col, MeshBuilder(name)


def build_props():
    items = []
    # Banco de praça
    col, b = prop("bench")
    for i in range(3):
        b.box((0, -0.05 + i * 0.16, 0.44), (1.7, 0.13, 0.05), mat("wood_light"), bevel=0.02)
    for i in range(2):
        b.box((0, 0.3, 0.68 + i * 0.16), (1.7, 0.05, 0.12), mat("wood_light"), rot=(-0.15, 0, 0), bevel=0.02)
    for sx in (-1, 1):
        b.tube([(sx * 0.75, -0.2, 0), (sx * 0.75, -0.15, 0.42), (sx * 0.75, 0.25, 0.42), (sx * 0.75, 0.33, 0.95)], 0.035, mat("metal"), segments=8)
        b.tube([(sx * 0.75, 0.25, 0.42), (sx * 0.75, 0.3, 0.0)], 0.035, mat("metal"), segments=8)
    items.append(b.build(col) and col)
    # Poste de luz
    col, b = prop("lamp_post")
    b.cylinder((0, 0, 0.1), 0.18, 0.2, 0.2, mat("metal"), segments=10)
    b.cylinder((0, 0, 1.35), 0.05, 0.07, 2.5, mat("metal"), segments=10)
    b.tube([(0, 0, 2.5), (0.0, -0.25, 2.65), (0, -0.4, 2.55)], 0.03, mat("metal"), segments=6)
    b.cylinder((0, -0.4, 2.42), 0.14, 0.09, 0.28, mat("lamp_glass", (1.0, 0.92, 0.7), 0.3, emission=0.0), segments=10)
    b.cylinder((0, -0.4, 2.6), 0.0, 0.2, 0.12, mat("metal"), segments=10)
    items.append(b.build(col) and col)
    # Fonte da praça
    col, b = prop("fountain")
    b.cylinder((0, 0, 0.25), 1.75, 1.85, 0.5, mat("stone"), segments=28, bevel=0.04)
    b.cylinder((0, 0, 0.47), 1.55, 1.55, 0.06, mat("water_basin", (0.45, 0.76, 0.9), 0.15), segments=28)
    b.cylinder((0, 0, 0.9), 0.24, 0.32, 1.0, mat("stone"), segments=14)
    b.cylinder((0, 0, 1.45), 0.75, 0.5, 0.18, mat("stone"), segments=20, bevel=0.03)
    b.cylinder((0, 0, 1.54), 0.62, 0.62, 0.04, mat("water_basin"), segments=20)
    b.sphere((0, 0, 1.8), 0.2, mat("stone"), segments=14, rings=8)
    for k in range(8):
        a = k * TAU / 8
        b.sphere((math.cos(a) * 1.8, math.sin(a) * 1.8, 0.52), 0.12, mat("stone_dark"), scale=(1, 1, 0.5), segments=8, rings=4)
    items.append(b.build(col) and col)
    # Quiosque de pães
    col, b = prop("market_stall")
    b.box((0, 0, 0.5), (2.4, 0.9, 1.0), mat("wood_light"), bevel=0.04)
    for i in range(6):
        b.box((-1.0 + i * 0.4, -0.46, 0.5), (0.05, 0.02, 0.9), mat("wood"))
    for sx in (-1, 1):
        b.cylinder((sx * 1.1, 0.35, 1.2), 0.05, 0.05, 2.4, mat("wood"), segments=8)
    for i in range(8):
        b.box((-1.225 + i * 0.35, -0.05, 2.35), (0.35, 1.5, 0.06), mat("coral") if i % 2 == 0 else mat("cream"), rot=(0.25, 0, 0))
    b.box((0, -0.05, 2.52), (2.8, 0.1, 0.25), mat("wood_light"), bevel=0.02)
    for k in range(5):
        b.sphere((-0.8 + k * 0.4, -0.15, 1.08), 0.13, mat("bread", (0.88, 0.6, 0.32)), scale=(1.3, 0.9, 0.7), segments=10, rings=6)
    b.cylinder((0.9, 0.1, 1.1), 0.2, 0.16, 0.18, mat("wood"), segments=12)
    items.append(b.build(col) and col)
    # Mural de recados
    col, b = prop("notice_board")
    for sx in (-1, 1):
        b.box((sx * 0.75, 0, 0.9), (0.1, 0.1, 1.8), mat("wood"), bevel=0.02)
    b.box((0, 0, 1.3), (1.5, 0.08, 1.0), mat("cork", (0.78, 0.6, 0.42)), bevel=0.03)
    b.box((0, -0.02, 1.88), (1.75, 0.3, 0.08), mat("wood_dark"), rot=(0.2, 0, 0), bevel=0.02)
    for i, c in enumerate(("cream", "sky", "pink", "yellow", "mint")):
        b.box((-0.5 + i * 0.25, -0.05, 1.35 + (i % 2) * 0.18 - 0.08), (0.2, 0.01, 0.26), mat(c), rot=(0, (i - 2) * 0.1, 0))
        b.sphere((-0.5 + i * 0.25, -0.07, 1.5 + (i % 2) * 0.18 - 0.08), 0.02, mat("red"), segments=6, rings=4)
    items.append(b.build(col) and col)
    # Estante comunitária
    col, b = prop("bookshelf")
    b.box((0, 0, 0.9), (1.5, 0.5, 1.8), mat("wood"), bevel=0.03)
    b.box((0, 0.2, 0.9), (1.36, 0.06, 1.66), mat("wood_dark"))
    for row in range(3):
        b.box((0, -0.05, 0.35 + row * 0.55 - 0.22), (1.4, 0.44, 0.04), mat("wood"))
        x = -0.6
        k = 0
        while x < 0.6:
            wdt = 0.1 + 0.05 * ((row + k) % 3)
            b.box((x + wdt / 2, -0.1, 0.35 + row * 0.55), (wdt - 0.01, 0.3, 0.38 - 0.05 * (k % 2)), mat(("red", "sky", "yellow", "mint", "lavender", "coral")[(row * 2 + k) % 6]), bevel=0.01)
            x += wdt
            k += 1
    b.box((0, -0.05, 1.9), (1.8, 0.8, 0.08), mat("sky"), rot=(0.08, 0, 0), bevel=0.02)
    items.append(b.build(col) and col)
    # Coreto
    col, b = prop("gazebo")
    b.cylinder((0, 0, 0.1), 2.6, 2.7, 0.2, mat("cream"), segments=8, smooth=False)
    for k in range(8):
        a = k * TAU / 8 + TAU / 16
        if k == 6:
            continue
        x, y = math.cos(a) * 2.35, math.sin(a) * 2.35
        b.cylinder((x, y, 1.35), 0.08, 0.08, 2.3, mat("white"), segments=10)
    for k in range(8):
        a0, a1 = k * TAU / 8 + TAU / 16, (k + 1) * TAU / 8 + TAU / 16
        if k in (5, 6):
            continue
        b.tube([(math.cos(a0) * 2.35, math.sin(a0) * 2.35, 0.7), (math.cos(a1) * 2.35, math.sin(a1) * 2.35, 0.7)], 0.04, mat("white"), segments=6)
    b.cylinder((0, 0, 3.15), 3.0, 0.15, 1.3, mat("gazebo_roof", (0.36, 0.62, 0.34)), segments=8, smooth=False)
    b.cylinder((0, 0, 2.5), 3.0, 3.0, 0.1, mat("white"), segments=8, smooth=False)
    b.sphere((0, 0, 3.85), 0.15, mat("gold", roughness=0.35, metallic=0.5), segments=10, rings=6)
    items.append(b.build(col) and col)
    # Telescópio
    col, b = prop("telescope")
    for k in range(3):
        a = k * TAU / 3
        b.tube([(0, 0, 1.0), (math.cos(a) * 0.35, math.sin(a) * 0.35, 0)], 0.025, mat("metal"), segments=6)
    b.cylinder((0, -0.1, 1.3), 0.09, 0.13, 1.1, mat("gold", roughness=0.35, metallic=0.5), rot=(-1.0, 0, 0.2), segments=14)
    items.append(b.build(col) and col)
    # Cavalete
    col, b = prop("easel")
    for sx in (-1, 1):
        b.box((sx * 0.28, 0, 0.8), (0.05, 0.05, 1.6), mat("wood"), rot=(0, sx * 0.12, 0))
    b.box((0, 0.3, 0.75), (0.05, 0.05, 1.5), mat("wood"), rot=(-0.3, 0, 0))
    b.box((0, -0.05, 1.15), (0.85, 0.04, 0.65), mat("white"))
    for px, pz, c in ((-0.2, 1.25, "sky"), (0.1, 1.05, "leaf_light"), (0.2, 1.28, "yellow"), (-0.15, 1.0, "mint")):
        b.box((px, -0.08, pz), (0.3, 0.02, 0.2), mat(c))
    b.box((0, -0.05, 0.78), (0.8, 0.1, 0.04), mat("wood"))
    items.append(b.build(col) and col)
    # Fogueira
    col, b = prop("campfire")
    for k in range(8):
        a = k * TAU / 8
        b.ico((math.cos(a) * 0.55, math.sin(a) * 0.55, 0.08), 0.13, mat("stone_dark"), subdiv=1, jitter=0.2, seed=k)
    for k in range(4):
        a = k * TAU / 4 + 0.3
        b.cylinder((math.cos(a) * 0.15, math.sin(a) * 0.15, 0.2), 0.07, 0.07, 0.7, mat("bark"), rot=(math.cos(a) * 1.1, math.sin(a) * 1.1, 0), segments=8)
    b.cylinder((0, 0, 0.45), 0.3, 0.0, 0.7, mat("flame", (1.0, 0.55, 0.18), 0.5, emission=2.5), segments=8)
    b.cylinder((0.05, 0.03, 0.4), 0.18, 0.0, 0.45, mat("flame_core", (1.0, 0.86, 0.35), 0.5, emission=3.0), segments=8)
    items.append(b.build(col) and col)
    # Guarda-sol com toalha
    col, b = prop("beach_umbrella")
    b.cylinder((0, 0, 1.2), 0.035, 0.035, 2.4, mat("white"), segments=8)
    b.cylinder((0, 0, 2.25), 1.45, 0.06, 0.5, mat("teal"), segments=8, smooth=False)
    for k in range(4):
        a = k * TAU / 4
        b.box((math.cos(a) * 0.7, math.sin(a) * 0.7, 2.27), (1.35, 0.18, 0.02), mat("white"), rot=(0, 0.34, a))
    b.sphere((0, 0, 2.52), 0.07, mat("white"), segments=8, rings=5)
    b.box((1.0, -0.5, 0.02), (1.0, 1.8, 0.03), mat("coral"))
    for i in range(4):
        b.box((1.0, -1.25 + i * 0.5, 0.04), (1.0, 0.12, 0.01), mat("white"))
    items.append(b.build(col) and col)
    # Cerca
    col, b = prop("fence_segment")
    _fence(b, -1.0, 0, 1.0, 0, mat("fence_white", (0.98, 0.97, 0.92)), posts=4)
    items.append(b.build(col) and col)
    # Vaso de flores, barril, caixote, placa
    col, b = prop("flower_pot")
    _flower_pot(b, 0, 0, color="pink", size=1.2)
    items.append(b.build(col) and col)
    col, b = prop("barrel")
    b.cylinder((0, 0, 0.4), 0.3, 0.3, 0.8, mat("wood"), segments=14)
    b.sphere((0, 0, 0.4), 0.33, mat("wood"), scale=(1, 1, 1.15), segments=14, rings=8)
    for z in (0.12, 0.68):
        b.cylinder((0, 0, z), 0.32, 0.32, 0.05, mat("metal"), segments=14)
    items.append(b.build(col) and col)
    col, b = prop("crate")
    b.box((0, 0, 0.3), (0.6, 0.6, 0.6), mat("wood_light"), bevel=0.03)
    for sx in (-1, 1):
        b.box((sx * 0.27, -0.305, 0.3), (0.06, 0.02, 0.6), mat("wood"))
    b.box((0, -0.305, 0.3), (0.62, 0.02, 0.06), mat("wood"), rot=(0, 0.75, 0))
    items.append(b.build(col) and col)
    col, b = prop("signpost")
    b.box((0, 0, 0.7), (0.1, 0.1, 1.4), mat("wood"), bevel=0.02)
    b.box((0.25, -0.06, 1.15), (0.8, 0.06, 0.28), mat("wood_light"), bevel=0.03)
    b.box((-0.2, -0.06, 0.85), (0.7, 0.06, 0.24), mat("wood_light"), rot=(0, 0.05, 0), bevel=0.03)
    items.append(b.build(col) and col)
    # Píer
    col, b = prop("dock")
    for i in range(7):
        b.box((0, -i * 0.45, 0.18), (1.6, 0.4, 0.07), mat("wood_light"), rot=(0, (i % 2) * 0.02, 0), bevel=0.015)
    for i in (0, 3, 6):
        for sx in (-1, 1):
            b.cylinder((sx * 0.75, -i * 0.45, 0.05), 0.07, 0.07, 0.6, mat("wood"), segments=8)
    items.append(b.build(col) and col)
    # Mesa de piquenique e balanço (área de lazer)
    col, b = prop("picnic_table")
    b.box((0, 0, 0.75), (1.8, 0.8, 0.07), mat("wood_light"), bevel=0.02)
    for sy in (-1, 1):
        b.box((0, sy * 0.65, 0.45), (1.8, 0.3, 0.06), mat("wood_light"), bevel=0.02)
    for sx in (-1, 1):
        b.box((sx * 0.7, 0, 0.38), (0.08, 1.6, 0.06), mat("wood"), rot=(0, 0, 0))
        for sy in (-1, 1):
            b.box((sx * 0.7, sy * 0.3, 0.38), (0.07, 0.07, 0.8), mat("wood"), rot=(sy * 0.45, 0, 0))
    b.box((0, 0, 0.8), (0.5, 0.5, 0.02), mat("cloth_check", (0.95, 0.45, 0.42)))
    b.cylinder((0.3, 0.1, 0.86), 0.12, 0.1, 0.12, mat("wood"), segments=10)
    items.append(b.build(col) and col)
    col, b = prop("swing")
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.box((sx * 1.0, sy * 0.4, 1.0), (0.08, 0.08, 2.1), mat("wood"), rot=(sy * 0.2, 0, 0))
    b.cylinder((0, 0, 2.0), 0.06, 0.06, 2.1, mat("wood"), rot=(0, math.pi / 2, 0), segments=8)
    for sx in (-0.25, 0.25):
        b.cylinder((sx, 0, 1.3), 0.012, 0.012, 1.4, mat("rope", (0.85, 0.75, 0.55)), segments=4)
    b.box((0, 0, 0.6), (0.65, 0.3, 0.05), mat("coral"), bevel=0.02)
    items.append(b.build(col) and col)
    # Itens coletáveis
    col, b = prop("item_shell")
    for i in range(7):
        a = -0.9 + i * 0.3
        b.sphere((math.sin(a) * 0.05, -math.cos(a) * 0.05 + 0.05, 0.04), 0.06, mat("shell", (0.98, 0.76, 0.74)), scale=(0.45, 1.6, 0.5), rot=(0, 0, a), segments=8, rings=5)
    b.sphere((0, -0.05, 0.03), 0.06, mat("shell"), scale=(1.4, 0.8, 0.5), segments=10, rings=6)
    items.append(b.build(col) and col)
    col, b = prop("item_starfish")
    for k in range(5):
        a = k * TAU / 5
        b.tube([(0, 0, 0.03), (math.cos(a) * 0.17, math.sin(a) * 0.17, 0.02)], [0.05, 0.015], mat("starfish", (1.0, 0.58, 0.32)), segments=6)
    b.sphere((0, 0, 0.03), 0.06, mat("starfish"), scale=(1, 1, 0.5), segments=10, rings=6)
    items.append(b.build(col) and col)
    col, b = prop("item_branch")
    b.tube([(-0.35, 0, 0.04), (0, 0.04, 0.05), (0.35, -0.02, 0.04)], [0.04, 0.035, 0.025], mat("bark_light"), segments=6)
    b.tube([(0.05, 0.03, 0.05), (0.2, 0.18, 0.05)], [0.025, 0.012], mat("bark_light"), segments=5)
    b.sphere((0.22, 0.2, 0.06), 0.04, mat("leaf"), scale=(1.4, 0.8, 0.4), segments=6, rings=4)
    items.append(b.build(col) and col)
    col, b = prop("item_stone")
    b.sphere((0, 0, 0.06), 0.12, mat("smooth_stone", (0.62, 0.64, 0.68), 0.4), scale=(1.3, 1.0, 0.55), segments=14, rings=8)
    items.append(b.build(col) and col)
    for fruit, color in (("pessego", (1.0, 0.62, 0.45)), ("maca_verde", (0.55, 0.82, 0.32))):
        col, b = prop(f"item_{fruit}")
        b.sphere((0, 0, 0.13), 0.13, mat(f"fruit_{fruit}", color, 0.5), scale=(1, 1, 0.92), segments=16, rings=10)
        b.cylinder((0, 0, 0.27), 0.012, 0.015, 0.06, mat("bark"), segments=5)
        b.sphere((0.05, 0, 0.28), 0.04, mat("leaf"), scale=(1.4, 0.6, 0.3), rot=(0, -0.4, 0), segments=6, rings=4)
        items.append(b.build(col) and col)
    return items


def generate_props(blend_dir, model_dir, log):
    clear_scene()
    out = []
    for col in build_props():
        _export(col, model_dir, "props", col.name, out)
        log(f"objeto: {col.name}")
    save_blend(os.path.join(blend_dir, "environment", "props", "props.blend"))
    return out


def generate(kind, blend_dir, model_dir, log):
    if kind == "vegetation":
        return generate_vegetation(blend_dir, model_dir, log)
    if kind == "buildings":
        return generate_buildings(blend_dir, model_dir, log)
    if kind == "props":
        return generate_props(blend_dir, model_dir, log)
    raise ValueError(kind)
