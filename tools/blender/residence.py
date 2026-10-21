"""Daybloom Residence (0.4): móveis, eletrodomésticos, peças do prédio e áreas comuns.

Mesmas convenções do resto do pipeline (ver dbkit):
* 1 unidade = 1 metro; origem no centro da base; frente voltada para -Y no
  Blender (vira +Z no Godot).
* Materiais compartilhados `DB_*`. Três materiais são recoloridos no Godot por
  morador/apartamento: `DB_accent`, `DB_accent2` e `DB_wood_theme`.
* Objetos com partes animadas ou controladas pelo jogo usam nomes fixos:
  - elevador: `Door_L`, `Door_R` (portas deslizantes), `Display` (painel);
  - estante do mercadinho: `Stock_1`…`Stock_8` (produtos visíveis conforme o estoque);
  - porta de apartamento: `Door_Leaf` (folha que abre);
  - TV: material `DB_screen` (tela acende quando ligada);
  - piscina: material `DB_pool_water` (substituído pelo shader de água).

Uso: blender --background --factory-startup --python tools/blender/generate_assets.py -- residence furniture
"""

from __future__ import annotations

import math
import os

from dbkit import MeshBuilder, clear_scene, export_collection, mat, new_collection, save_blend

TAU = math.tau

ACCENT = (0.96, 0.56, 0.52)
ACCENT2 = (0.98, 0.86, 0.66)
WOOD_THEME = (0.80, 0.62, 0.42)


def _a():
    return mat("accent", ACCENT, 0.85)


def _a2():
    return mat("accent2", ACCENT2, 0.85)


def _wt():
    return mat("wood_theme", WOOD_THEME, 0.8)


def _new(name):
    return new_collection(name), MeshBuilder(name)


def _done(items, col, b, extra=()):
    b.build(col)
    for e in extra:
        e.build(col)
    items.append(col)


# ===========================================================================
# Móveis e eletrodomésticos
# ===========================================================================

def build_furniture():
    items = []
    white = mat("white")
    cream = mat("cream")
    metal = mat("metal")
    steel = mat("steel", (0.78, 0.80, 0.82), 0.35, metallic=0.6)
    ink = mat("ink")
    glass = mat("glass", (0.70, 0.86, 0.95), 0.1)
    porcelain = mat("porcelain", (0.97, 0.97, 0.96), 0.25)

    # Cama de casal (cabeceira atrás, +Y)
    col, b = _new("cama")
    b.box((0, 0, 0.18), (1.6, 2.1, 0.26), _wt(), bevel=0.04)
    b.box((0, 0.02, 0.38), (1.52, 2.0, 0.2), mat("mattress", (0.98, 0.97, 0.94)), bevel=0.06)
    b.box((0, -0.25, 0.5), (1.56, 1.45, 0.08), _a(), bevel=0.04)
    b.box((0, -0.97, 0.36), (1.56, 0.06, 0.28), _a(), bevel=0.02)
    for sx in (-0.38, 0.38):
        b.box((sx, 0.72, 0.55), (0.6, 0.36, 0.14), white, bevel=0.06)
    b.box((0, 1.04, 0.62), (1.66, 0.1, 0.9), _wt(), bevel=0.04)
    for sx in (-0.76, 0.76):
        for sy in (-0.98, 0.98):
            b.box((sx, sy, 0.04), (0.08, 0.08, 0.08), mat("wood_dark"))
    _done(items, col, b)

    # Cama de solteiro (receita de fabricação)
    col, b = _new("cama_simples")
    b.box((0, 0, 0.17), (1.0, 2.0, 0.24), mat("wood_light"), bevel=0.03)
    b.box((0, 0.02, 0.36), (0.94, 1.9, 0.18), mat("mattress"), bevel=0.05)
    b.box((0, -0.25, 0.47), (0.98, 1.35, 0.07), _a2(), bevel=0.03)
    b.box((0, 0.7, 0.5), (0.6, 0.34, 0.13), white, bevel=0.05)
    b.box((0, 0.98, 0.55), (1.04, 0.08, 0.75), mat("wood_light"), bevel=0.03)
    _done(items, col, b)

    # Sofá de dois lugares
    col, b = _new("sofa")
    b.box((0, 0.05, 0.22), (2.0, 0.85, 0.3), _a(), bevel=0.06)
    for sx in (-0.47, 0.47):
        b.box((sx, -0.04, 0.44), (0.9, 0.7, 0.16), _a(), bevel=0.07)
    b.box((0, 0.38, 0.62), (1.9, 0.22, 0.6), _a(), bevel=0.08)
    for sx in (-0.98, 0.98):
        b.box((sx, 0.05, 0.42), (0.18, 0.85, 0.5), _a(), bevel=0.07)
    b.box((-0.55, 0.22, 0.62), (0.42, 0.14, 0.36), _a2(), rot=(-0.25, 0, 0.1), bevel=0.07)
    for sx in (-0.9, 0.9):
        for sy in (-0.3, 0.38):
            b.cylinder((sx, sy, 0.035), 0.03, 0.025, 0.07, mat("wood_dark"), segments=8)
    _done(items, col, b)

    # Poltrona
    col, b = _new("poltrona")
    b.box((0, 0.04, 0.22), (0.9, 0.82, 0.3), _a2(), bevel=0.06)
    b.box((0, -0.04, 0.44), (0.6, 0.66, 0.15), _a2(), bevel=0.07)
    b.box((0, 0.34, 0.66), (0.8, 0.2, 0.62), _a2(), bevel=0.08)
    for sx in (-0.4, 0.4):
        b.box((sx, 0.04, 0.42), (0.16, 0.8, 0.46), _a2(), bevel=0.07)
    _done(items, col, b)

    # Cadeira (sala de jantar)
    def chair(name, seat_mat, frame_mat, simple=False):
        col, b = _new(name)
        b.box((0, 0, 0.45), (0.46, 0.46, 0.06), seat_mat, bevel=0.02)
        for sx in (-0.19, 0.19):
            for sy in (-0.19, 0.19):
                b.box((sx, sy, 0.21), (0.05, 0.05, 0.42), frame_mat)
        for sx in (-0.19, 0.19):
            b.box((sx, 0.2, 0.7), (0.05, 0.05, 0.48), frame_mat)
        if simple:
            for z in (0.62, 0.82):
                b.box((0, 0.2, z), (0.42, 0.03, 0.08), frame_mat)
        else:
            b.box((0, 0.21, 0.78), (0.42, 0.04, 0.3), frame_mat, bevel=0.015)
        _done(items, col, b)

    chair("cadeira", _a(), _wt())
    chair("cadeira_simples", mat("wood_light"), mat("wood"), simple=True)

    # Mesas
    col, b = _new("mesa_jantar")
    b.box((0, 0, 0.73), (1.4, 0.9, 0.05), _wt(), bevel=0.02)
    for sx in (-0.62, 0.62):
        for sy in (-0.38, 0.38):
            b.box((sx, sy, 0.36), (0.06, 0.06, 0.7), _wt())
    b.box((0, 0, 0.765), (0.9, 0.3, 0.01), _a2())
    b.cylinder((0, 0, 0.83), 0.06, 0.05, 0.12, porcelain, segments=10)
    b.sphere((0, 0, 0.95), 0.08, mat("leaf"), segments=8, rings=5)
    _done(items, col, b)

    col, b = _new("mesa_pequena")
    b.box((0, 0, 0.72), (0.8, 0.8, 0.05), mat("wood_light"), bevel=0.02)
    for sx in (-0.33, 0.33):
        for sy in (-0.33, 0.33):
            b.box((sx, sy, 0.35), (0.05, 0.05, 0.7), mat("wood"))
    _done(items, col, b)

    col, b = _new("mesa_centro")
    b.box((0, 0, 0.38), (1.0, 0.6, 0.05), _wt(), bevel=0.02)
    b.box((0, 0, 0.14), (0.9, 0.5, 0.03), _wt())
    for sx in (-0.45, 0.45):
        for sy in (-0.25, 0.25):
            b.box((sx, sy, 0.2), (0.04, 0.04, 0.38), mat("wood_dark"))
    b.box((0.2, 0, 0.42), (0.25, 0.18, 0.03), _a())
    _done(items, col, b)

    # Cozinha
    col, b = _new("geladeira")
    b.box((0, 0, 0.9), (0.74, 0.68, 1.8), white, bevel=0.05)
    b.box((0, -0.345, 1.28), (0.7, 0.02, 0.98), cream, bevel=0.01)
    b.box((0, -0.345, 0.38), (0.7, 0.02, 0.7), cream, bevel=0.01)
    for z in (1.0, 0.62):
        b.box((0.28, -0.37, z), (0.04, 0.04, 0.32), steel, bevel=0.01)
    for k, c in enumerate(("coral", "sky", "yellow")):
        b.box((-0.18 + k * 0.12, -0.36, 1.45 - k * 0.07), (0.08, 0.01, 0.08), mat(c))
    _done(items, col, b)

    col, b = _new("fogao")
    b.box((0, 0, 0.44), (0.76, 0.66, 0.88), white, bevel=0.03)
    b.box((0, 0, 0.885), (0.76, 0.66, 0.02), ink)
    for sx in (-0.17, 0.17):
        for sy in (-0.13, 0.15):
            b.cylinder((sx, sy, 0.9), 0.09, 0.09, 0.02, metal, segments=14)
    b.box((0, -0.335, 0.4), (0.62, 0.02, 0.48), mat("oven_glass", (0.25, 0.22, 0.22), 0.2), bevel=0.01)
    b.box((0, -0.36, 0.68), (0.5, 0.03, 0.03), steel)
    for k in range(4):
        b.cylinder((-0.27 + k * 0.18, -0.34, 0.79), 0.025, 0.025, 0.03, ink, rot=(math.pi / 2, 0, 0), segments=8)
    b.box((0, 0.32, 1.0), (0.76, 0.04, 0.22), steel)
    _done(items, col, b)

    col, b = _new("pia_cozinha")
    b.box((0, 0, 0.43), (1.2, 0.64, 0.86), _wt(), bevel=0.02)
    b.box((0, 0, 0.88), (1.24, 0.68, 0.04), mat("counter", (0.92, 0.90, 0.86), 0.4))
    b.box((0.1, -0.02, 0.86), (0.56, 0.42, 0.06), steel)
    b.tube([(0.1, 0.22, 0.9), (0.1, 0.22, 1.12), (0.1, 0.05, 1.16), (0.1, 0.0, 1.08)], 0.018, steel, segments=8)
    for sx in (-0.3, 0.3):
        b.box((sx, -0.325, 0.48), (0.5, 0.02, 0.68), _a2(), bevel=0.01)
    _done(items, col, b)

    col, b = _new("balcao")
    b.box((0, 0, 0.43), (1.0, 0.64, 0.86), _wt(), bevel=0.02)
    b.box((0, 0, 0.88), (1.04, 0.68, 0.04), mat("counter"))
    b.box((0, -0.325, 0.48), (0.88, 0.02, 0.68), _a2(), bevel=0.01)
    b.cylinder((-0.28, 0.1, 0.98), 0.08, 0.07, 0.16, _a(), segments=10)
    b.box((0.25, 0.12, 0.93), (0.36, 0.24, 0.04), mat("wood_light"))
    _done(items, col, b)

    col, b = _new("forno_lenha")
    b.box((0, 0, 0.42), (1.0, 0.85, 0.84), mat("brick", (0.80, 0.44, 0.32)), bevel=0.04)
    b.sphere((0, 0.05, 0.84), 0.48, mat("brick"), scale=(1.0, 0.9, 0.7), segments=16, rings=8, flatten_bottom=0.0)
    b.box((0, -0.38, 0.98), (0.4, 0.12, 0.3), mat("oven_mouth", (0.18, 0.12, 0.10)), bevel=0.05)
    b.cylinder((0.25, 0.2, 1.45), 0.08, 0.08, 0.6, mat("brick"), segments=10)
    for k in range(3):
        b.sphere((-0.3 + k * 0.3, -0.38, 0.62), 0.07, mat("bread", (0.88, 0.6, 0.32)), scale=(1.4, 1, 0.7), segments=8, rings=5)
    _done(items, col, b)

    # Banheiro
    col, b = _new("chuveiro")
    b.box((0, 0, 0.05), (0.95, 0.95, 0.1), porcelain, bevel=0.02)
    b.box((0, 0.45, 1.1), (0.95, 0.05, 2.1), mat("tile", (0.80, 0.90, 0.92), 0.4))
    b.box((0.45, 0, 1.1), (0.05, 0.95, 2.1), mat("tile"))
    b.box((-0.47, 0, 1.05), (0.02, 0.9, 1.9), glass)
    b.tube([(0.2, 0.42, 1.0), (0.2, 0.42, 2.0), (0.2, 0.2, 2.05)], 0.02, steel, segments=8)
    b.cylinder((0.2, 0.15, 2.0), 0.1, 0.07, 0.04, steel, segments=12)
    b.cylinder((0.2, 0.4, 1.1), 0.04, 0.04, 0.05, steel, rot=(math.pi / 2, 0, 0), segments=8)
    _done(items, col, b)

    col, b = _new("vaso_sanitario")
    b.cylinder((0, -0.05, 0.2), 0.17, 0.2, 0.4, porcelain, segments=16)
    b.sphere((0, -0.1, 0.4), 0.21, porcelain, scale=(0.9, 1.15, 0.25), segments=16, rings=6)
    b.box((0, 0.24, 0.6), (0.42, 0.18, 0.42), porcelain, bevel=0.04)
    b.box((0, 0.24, 0.82), (0.44, 0.2, 0.04), porcelain, bevel=0.015)
    b.box((0.12, 0.17, 0.74), (0.06, 0.02, 0.03), steel)
    _done(items, col, b)

    col, b = _new("pia_banheiro")
    b.box((0, 0.02, 0.4), (0.6, 0.44, 0.8), _wt(), bevel=0.02)
    b.box((0, 0.0, 0.83), (0.62, 0.46, 0.06), porcelain, bevel=0.02)
    b.cylinder((0, -0.02, 0.85), 0.16, 0.13, 0.04, mat("basin", (0.85, 0.92, 0.95), 0.2), segments=16)
    b.tube([(0, 0.18, 0.86), (0, 0.18, 0.98), (0, 0.08, 1.0)], 0.014, steel, segments=8)
    b.box((0, 0.21, 1.45), (0.5, 0.03, 0.62), mat("mirror", (0.82, 0.90, 0.95), 0.05, metallic=0.4), bevel=0.02)
    b.box((0, 0.225, 1.45), (0.56, 0.02, 0.68), _wt())
    _done(items, col, b)

    # Quarto
    col, b = _new("guarda_roupa")
    b.box((0, 0, 1.0), (1.2, 0.6, 2.0), _wt(), bevel=0.03)
    for sx in (-0.3, 0.3):
        b.box((sx, -0.305, 1.02), (0.57, 0.02, 1.86), _a2(), bevel=0.01)
        b.box((sx * 0.18, -0.33, 1.05), (0.03, 0.03, 0.28), steel)
    b.box((0, 0, 2.03), (1.26, 0.64, 0.06), mat("wood_dark"))
    _done(items, col, b)

    col, b = _new("criado_mudo")
    b.box((0, 0, 0.28), (0.45, 0.4, 0.56), _wt(), bevel=0.02)
    b.box((0, -0.205, 0.38), (0.38, 0.02, 0.16), _a2())
    b.cylinder((0, 0.02, 0.6), 0.06, 0.07, 0.06, _a(), segments=10)
    b.cylinder((0, 0.02, 0.7), 0.025, 0.025, 0.16, metal, segments=8)
    b.cylinder((0, 0.02, 0.84), 0.13, 0.08, 0.14, mat("lamp_glass", (1.0, 0.92, 0.7), 0.3, emission=0.0), segments=12)
    _done(items, col, b)

    col, b = _new("luminaria")
    b.cylinder((0, 0, 0.02), 0.18, 0.18, 0.04, metal, segments=14)
    b.cylinder((0, 0, 0.8), 0.022, 0.022, 1.56, metal, segments=8)
    b.cylinder((0, 0, 1.58), 0.24, 0.15, 0.26, mat("lamp_glass"), segments=14)
    b.cylinder((0, 0, 1.72), 0.15, 0.15, 0.02, _a(), segments=14)
    _done(items, col, b)

    # Sala
    col, b = _new("tv")
    b.box((0, 0.05, 0.25), (1.3, 0.42, 0.5), _wt(), bevel=0.02)
    b.box((0, -0.16, 0.25), (1.2, 0.02, 0.36), _a2())
    b.box((0, 0.1, 0.55), (0.3, 0.12, 0.1), metal)
    b.box((0, 0.1, 0.92), (1.1, 0.06, 0.64), ink, bevel=0.02)
    b.box((0, 0.065, 0.92), (1.02, 0.01, 0.56), mat("screen", (0.10, 0.14, 0.20), 0.2, emission=0.0))
    _done(items, col, b)

    col, b = _new("estante")
    b.box((0, 0, 0.8), (1.0, 0.36, 1.6), mat("wood_light"), bevel=0.02)
    b.box((0, 0.12, 0.8), (0.9, 0.06, 1.5), mat("wood"))
    for row in range(3):
        z = 0.3 + row * 0.5
        b.box((0, -0.03, z - 0.18), (0.92, 0.3, 0.03), mat("wood_light"))
        x = -0.4
        k = 0
        while x < 0.38:
            w = 0.07 + 0.03 * ((row + k) % 3)
            b.box((x + w / 2, -0.04, z), (w - 0.01, 0.22, 0.3 - 0.04 * (k % 2)), mat(("coral", "sky", "yellow", "mint", "lavender")[(row + k) % 5]), bevel=0.008)
            x += w
            k += 1
    _done(items, col, b)

    col, b = _new("vaso_decorativo")
    b.cylinder((0, 0, 0.15), 0.12, 0.16, 0.3, mat("clay", (0.86, 0.54, 0.42)), segments=14, bevel=0.01)
    b.sphere((0, 0, 0.3), 0.15, mat("clay"), scale=(1, 1, 0.3), segments=14, rings=6)
    for k in range(5):
        a = k * TAU / 5
        b.tube([(0, 0, 0.3), (math.cos(a) * 0.08, math.sin(a) * 0.08, 0.5), (math.cos(a) * 0.16, math.sin(a) * 0.16, 0.6)], 0.012, mat("leaf"), segments=6)
        b.sphere((math.cos(a) * 0.16, math.sin(a) * 0.16, 0.62), 0.05, mat(("pink", "yellow", "lavender", "coral", "white")[k]), segments=8, rings=5)
    _done(items, col, b)

    col, b = _new("banco")
    b.box((0, 0, 0.44), (1.2, 0.38, 0.06), mat("wood_light"), bevel=0.02)
    for sx in (-0.5, 0.5):
        b.box((sx, 0, 0.21), (0.08, 0.32, 0.42), mat("wood"))
    b.box((0, 0, 0.12), (1.0, 0.05, 0.05), mat("wood"))
    _done(items, col, b)

    col, b = _new("tapete")
    b.box((0, 0, 0.01), (2.0, 1.4, 0.02), _a2(), bevel=0.005)
    b.box((0, 0, 0.021), (1.6, 1.0, 0.002), _a())
    b.box((0, 0, 0.022), (1.2, 0.6, 0.002), _a2())
    _done(items, col, b)

    col, b = _new("planta_grande")
    b.cylinder((0, 0, 0.2), 0.2, 0.25, 0.4, _a(), segments=14, bevel=0.01)
    b.cylinder((0, 0, 0.39), 0.22, 0.22, 0.02, mat("soil", (0.4, 0.28, 0.2)), segments=14)
    for k in range(7):
        a = k * TAU / 7
        r = 0.18 + 0.05 * (k % 2)
        b.tube([(0, 0, 0.38), (math.cos(a) * r * 0.5, math.sin(a) * r * 0.5, 0.8), (math.cos(a) * r, math.sin(a) * r, 1.1 + 0.1 * (k % 3))], 0.015, mat("bark"), segments=5)
        b.sphere((math.cos(a) * r, math.sin(a) * r, 1.12 + 0.1 * (k % 3)), 0.15, mat("leaf" if k % 2 else "leaf_dark"), scale=(1.4, 0.8, 0.5), rot=(0, 0, a), segments=8, rings=5)
    _done(items, col, b)

    # Hobbies e trabalho
    col, b = _new("bancada_trabalho")
    b.box((0, 0, 0.88), (1.4, 0.7, 0.06), mat("wood_light"), bevel=0.02)
    for sx in (-0.62, 0.62):
        for sy in (-0.28, 0.28):
            b.box((sx, sy, 0.43), (0.08, 0.08, 0.86), mat("wood"))
    b.box((0, 0, 0.25), (1.24, 0.56, 0.03), mat("wood"))
    b.box((0, 0.33, 1.3), (1.4, 0.04, 0.8), mat("pegboard", (0.76, 0.62, 0.44)))
    b.tube([(-0.4, 0.3, 1.5), (-0.4, 0.3, 1.2)], 0.02, metal, segments=6)
    b.box((-0.4, 0.29, 1.53), (0.16, 0.05, 0.06), mat("red"))
    b.tube([(0.2, 0.3, 1.55), (0.35, 0.3, 1.3)], 0.015, metal, segments=6)
    b.box((0.3, -0.05, 0.94), (0.4, 0.1, 0.06), mat("wood"))
    b.box((-0.2, -0.1, 0.93), (0.3, 0.2, 0.04), mat("plank", (0.84, 0.68, 0.48)))
    _done(items, col, b)

    col, b = _new("maquina_costura")
    b.box((0, 0, 0.74), (1.0, 0.55, 0.05), _wt(), bevel=0.02)
    for sx in (-0.44, 0.44):
        b.box((sx, 0, 0.36), (0.06, 0.48, 0.72), metal)
    b.box((0.05, 0.02, 0.86), (0.5, 0.2, 0.18), white, bevel=0.04)
    b.box((0.25, 0.02, 0.98), (0.12, 0.2, 0.3), white, bevel=0.03)
    b.box((-0.05, 0.02, 1.1), (0.55, 0.18, 0.1), white, bevel=0.04)
    b.cylinder((-0.28, 0.02, 0.96), 0.06, 0.06, 0.04, steel, rot=(math.pi / 2, 0, 0), segments=12)
    b.box((-0.25, -0.1, 0.78), (0.5, 0.3, 0.02), _a())
    b.cylinder((0.38, 0.1, 0.82), 0.04, 0.04, 0.12, mat("thread", (0.86, 0.3, 0.4)), segments=8)
    _done(items, col, b)

    col, b = _new("piano")
    b.box((0, 0.1, 0.6), (1.4, 0.5, 1.2), mat("piano", (0.20, 0.16, 0.14), 0.4), bevel=0.03)
    b.box((0, -0.2, 0.72), (1.36, 0.3, 0.06), mat("piano"))
    b.box((0, -0.22, 0.76), (1.24, 0.2, 0.02), white)
    for k in range(18):
        if k % 7 in (2, 6):
            continue
        b.box((-0.58 + k * 0.068, -0.17, 0.785), (0.03, 0.1, 0.02), ink)
    b.box((0, 0.1, 1.22), (1.44, 0.54, 0.04), mat("piano"))
    b.box((0.4, 0.15, 1.28), (0.2, 0.04, 0.12), mat("sheet", (0.98, 0.96, 0.9)), rot=(-0.3, 0, 0))
    _done(items, col, b)

    col, b = _new("violao_suporte")
    b.tube([(-0.12, 0.1, 0.0), (0, 0, 0.35), (0.12, 0.1, 0.0)], 0.015, metal, segments=6)
    b.sphere((0, -0.02, 0.32), 0.2, mat("guitar", (0.82, 0.52, 0.28)), scale=(1, 0.35, 1.0), rot=(-0.2, 0, 0), segments=16, rings=8)
    b.sphere((0, 0.02, 0.55), 0.15, mat("guitar"), scale=(1, 0.35, 0.95), rot=(-0.2, 0, 0), segments=16, rings=8)
    b.cylinder((0, -0.09, 0.4), 0.05, 0.05, 0.02, ink, rot=(1.37, 0, 0), segments=12)
    b.box((0, 0.1, 0.9), (0.06, 0.03, 0.55), mat("wood_dark"), rot=(-0.2, 0, 0))
    _done(items, col, b)

    col, b = _new("escrivaninha")
    b.box((0, 0, 0.74), (1.2, 0.6, 0.04), _wt(), bevel=0.015)
    b.box((0.4, 0, 0.36), (0.38, 0.56, 0.72), _wt(), bevel=0.02)
    b.box((0.4, -0.285, 0.5), (0.32, 0.02, 0.16), _a2())
    b.box((0.4, -0.285, 0.25), (0.32, 0.02, 0.16), _a2())
    b.box((-0.55, 0, 0.36), (0.05, 0.56, 0.72), _wt())
    b.box((-0.15, 0.05, 0.77), (0.4, 0.28, 0.02), white)
    b.cylinder((-0.45, 0.15, 0.78), 0.04, 0.04, 0.06, _a(), segments=10)
    _done(items, col, b)

    col, b = _new("organizador_cartas")
    b.box((0, 0, 0.6), (1.2, 0.4, 1.2), mat("wood_light"), bevel=0.02)
    for row in range(3):
        for c in range(5):
            x = -0.48 + c * 0.24
            z = 0.3 + row * 0.35
            b.box((x, -0.05, z), (0.22, 0.32, 0.3), mat("wood"))
            b.box((x, -0.16, z - 0.06), (0.17, 0.08, 0.12), mat(("cream", "sky", "pink", "yellow")[(row + c) % 4]))
    b.box((0, -0.05, 1.25), (0.5, 0.2, 0.1), mat("red"))
    b.box((-0.35, -0.25, 0.08), (0.3, 0.2, 0.16), mat("mailbag", (0.66, 0.46, 0.28)), bevel=0.04)
    _done(items, col, b)

    col, b = _new("prancha_surf")
    b.sphere((0, 0, 1.0), 0.28, mat("teal"), scale=(1, 0.12, 3.5), segments=16, rings=10)
    b.box((0, -0.035, 1.0), (0.06, 0.01, 1.8), white)
    b.cylinder((0.45, 0, 0.7), 0.22, 0.22, 0.08, mat("red"), rot=(math.pi / 2, 0, 0), segments=18)
    b.cylinder((0.45, 0, 0.7), 0.12, 0.12, 0.09, white, rot=(math.pi / 2, 0, 0), segments=18)
    _done(items, col, b)

    col, b = _new("quadro")
    b.box((0, 0, 0.0), (0.9, 0.05, 0.7), mat("frame", (0.6, 0.44, 0.28)), bevel=0.01)
    b.box((0, -0.03, 0.0), (0.8, 0.01, 0.6), mat("canvas", (0.98, 0.95, 0.88)))
    b.box((-0.15, -0.035, 0.1), (0.5, 0.005, 0.25), mat("sky"))
    b.sphere((0.22, -0.035, 0.12), 0.08, mat("orange"), scale=(1, 0.05, 1), segments=10, rings=6)
    b.box((0, -0.035, -0.16), (0.78, 0.005, 0.2), mat("mint"))
    _done(items, col, b)

    col, b = _new("cavalete_pintura")
    b.tube([(-0.3, 0.1, 0), (0, 0.0, 1.6)], 0.022, mat("wood"), segments=6)
    b.tube([(0.3, 0.1, 0), (0, 0.0, 1.6)], 0.022, mat("wood"), segments=6)
    b.tube([(0, 0.45, 0), (0, 0.05, 1.5)], 0.02, mat("wood"), segments=6)
    b.box((0, -0.03, 0.62), (0.7, 0.08, 0.04), mat("wood"))
    b.box((0, -0.02, 0.95), (0.62, 0.03, 0.62), mat("canvas"), rot=(-0.1, 0, 0))
    b.sphere((0.1, -0.05, 1.0), 0.1, mat("coral"), scale=(1.6, 0.05, 1), segments=10, rings=6)
    b.sphere((-0.12, -0.05, 0.85), 0.08, mat("lavender"), scale=(1.8, 0.05, 1), segments=10, rings=6)
    b.box((0.4, 0.0, 0.64), (0.2, 0.15, 0.02), mat("palette", (0.95, 0.88, 0.75)))
    _done(items, col, b)

    col, b = _new("rolos_tecido")
    for k, c in enumerate(("pink", "lavender", "mint", "yellow", "sky", "coral")):
        x = -0.36 + (k % 3) * 0.36
        z = 0.15 + (k // 3) * 0.3
        b.cylinder((x, 0, z), 0.15, 0.15, 0.5, mat(c), rot=(math.pi / 2, 0, 0), segments=14)
    b.box((0, 0, 0.0), (1.2, 0.6, 0.02), mat("wood"))
    _done(items, col, b)

    # Áreas comuns: cobertura
    col, b = _new("espreguicadeira")
    b.box((0, 0.2, 0.3), (0.66, 1.3, 0.06), white, bevel=0.02)
    b.box((0, -0.68, 0.5), (0.66, 0.55, 0.06), white, rot=(0.7, 0, 0), bevel=0.02)
    b.box((0, 0.2, 0.34), (0.6, 1.25, 0.04), _a())
    b.box((0, -0.68, 0.54), (0.6, 0.5, 0.04), _a(), rot=(0.7, 0, 0))
    for sx in (-0.3, 0.3):
        for sy in (-0.7, 0.8):
            b.box((sx, sy, 0.14), (0.04, 0.04, 0.28), white)
    _done(items, col, b)

    col, b = _new("churrasqueira")
    b.box((0, 0, 0.45), (1.5, 0.75, 0.9), mat("brick"), bevel=0.03)
    b.box((0, 0, 0.92), (1.56, 0.8, 0.06), mat("stone"))
    b.box((0, -0.05, 0.98), (0.9, 0.5, 0.06), ink)
    for k in range(7):
        b.box((-0.36 + k * 0.12, -0.05, 1.02), (0.02, 0.46, 0.02), steel)
    b.box((0, 0.3, 1.5), (1.2, 0.18, 1.1), mat("brick"), bevel=0.02)
    b.box((0, 0.3, 2.3), (0.5, 0.4, 0.6), mat("brick"), bevel=0.02)
    b.box((0, 0.3, 2.63), (0.6, 0.5, 0.06), mat("stone"))
    b.box((-0.55, -0.376, 0.5), (0.3, 0.02, 0.5), mat("wood_dark"))
    b.box((0.55, -0.376, 0.5), (0.3, 0.02, 0.5), mat("wood_dark"))
    b.box((0.58, -0.1, 0.97), (0.3, 0.4, 0.03), mat("wood_light"))
    _done(items, col, b)

    col, b = _new("mesa_redonda")
    b.cylinder((0, 0, 0.73), 0.55, 0.55, 0.05, white, segments=24, bevel=0.01)
    b.cylinder((0, 0, 0.37), 0.05, 0.05, 0.72, metal, segments=10)
    b.cylinder((0, 0, 0.02), 0.3, 0.3, 0.04, metal, segments=16)
    b.cylinder((0, 0, 1.3), 0.03, 0.03, 1.3, mat("wood"), segments=8)
    b.cylinder((0, 0, 1.98), 1.2, 0.02, 0.45, _a(), segments=12, smooth=False)
    _done(items, col, b)

    col, b = _new("cadeira_externa")
    b.box((0, 0, 0.44), (0.48, 0.48, 0.04), white, bevel=0.02)
    for sx in (-0.2, 0.2):
        for sy in (-0.2, 0.2):
            b.tube([(sx, sy, 0.0), (sx * 1.05, sy * 1.05, 0.44)], 0.018, white, segments=6)
    b.box((0, 0.22, 0.72), (0.46, 0.04, 0.4), white, rot=(-0.12, 0, 0), bevel=0.02)
    for k in range(3):
        b.box((0, 0.2, 0.62 + k * 0.1), (0.4, 0.045, 0.02), _a())
    _done(items, col, b)

    col, b = _new("piscina")
    w, d, depth = 6.0, 3.6, 0.6
    rim = mat("pool_rim", (0.94, 0.92, 0.88), 0.6)
    tile = mat("pool_tile", (0.42, 0.74, 0.88), 0.3)
    for sy in (-1, 1):
        b.box((0, sy * (d / 2 + 0.2), 0.08), (w + 0.8, 0.4, 0.16), rim, bevel=0.03)
    for sx in (-1, 1):
        b.box((sx * (w / 2 + 0.2), 0, 0.08), (0.4, d, 0.16), rim, bevel=0.03)
    b.box((0, 0, -depth / 2), (w, d, 0.04), tile)
    b.box((0, 0, -depth - 0.02), (w, d, 0.04), tile)
    for sy in (-1, 1):
        b.box((0, sy * d / 2, -depth / 2), (w, 0.04, depth), tile)
    for sx in (-1, 1):
        b.box((sx * w / 2, 0, -depth / 2), (0.04, d, depth), tile)
    b.box((0, 0, -0.06), (w, d, 0.02), mat("pool_water", (0.35, 0.74, 0.86), 0.1))
    for sx in (-0.22, 0.22):
        b.tube([(w / 2 - 0.6 + sx, -d / 2 - 0.25, 0.1), (w / 2 - 0.6 + sx, -d / 2 - 0.25, 0.75), (w / 2 - 0.6 + sx, -d / 2 + 0.1, 0.75), (w / 2 - 0.6 + sx, -d / 2 + 0.1, -0.4)], 0.025, steel, segments=8)
    _done(items, col, b)

    col, b = _new("pergolado")
    for sx in (-1.8, 1.8):
        for sy in (-1.3, 1.3):
            b.box((sx, sy, 1.25), (0.14, 0.14, 2.5), mat("wood"))
    for sy in (-1.3, 1.3):
        b.box((0, sy, 2.5), (4.0, 0.14, 0.16), mat("wood"))
    for k in range(9):
        b.box((-1.8 + k * 0.45, 0, 2.62), (0.08, 3.0, 0.1), mat("wood_light"))
    for k in range(10):
        b.sphere((-1.9 + k * 0.42, -1.3, 2.35), 0.05, mat("bulb", (1.0, 0.86, 0.5), 0.3, emission=0.0), segments=6, rings=4)
        b.sphere((-1.9 + k * 0.42, 1.3, 2.35), 0.05, mat("bulb"), segments=6, rings=4)
    for k in range(6):
        b.sphere((-1.7 + k * 0.7, 1.3, 2.75), 0.22, mat("leaf"), scale=(1.3, 1, 0.6), segments=8, rings=5)
    _done(items, col, b)

    col, b = _new("luzinhas")
    b.cylinder((0, 0, 1.3), 0.04, 0.05, 2.6, mat("wood_dark"), segments=8)
    b.cylinder((0, 0, 0.05), 0.2, 0.22, 0.1, mat("stone"), segments=10)
    for k in range(8):
        b.sphere((0.15 * math.cos(k), 0.15 * math.sin(k), 2.5 - k * 0.04), 0.05, mat("bulb"), segments=6, rings=4)
    _done(items, col, b)

    col, b = _new("canteiro_horta")
    b.box((0, 0, 0.25), (1.8, 0.9, 0.5), mat("wood"), bevel=0.02)
    b.box((0, 0, 0.47), (1.7, 0.8, 0.06), mat("soil"))
    for k in range(6):
        x = -0.65 + k * 0.26
        b.sphere((x, -0.18, 0.58), 0.1, mat("leaf_light" if k % 2 else "leaf"), scale=(1, 1, 0.7), segments=8, rings=5)
        b.sphere((x, 0.18, 0.56), 0.09, mat("leaf"), scale=(1, 1, 0.6), segments=8, rings=5)
        if k % 2 == 0:
            b.sphere((x + 0.04, -0.2, 0.6), 0.045, mat("red"), segments=8, rings=5)
    _done(items, col, b)

    # Academia e lavanderia
    col, b = _new("esteira")
    b.box((0, 0.05, 0.12), (0.75, 1.8, 0.2), metal, bevel=0.03)
    b.box((0, 0.05, 0.23), (0.6, 1.6, 0.02), ink)
    for sx in (-0.33, 0.33):
        b.box((sx, -0.75, 0.7), (0.05, 0.05, 1.1), metal)
    b.box((0, -0.78, 1.25), (0.75, 0.25, 0.1), metal, rot=(0.4, 0, 0), bevel=0.02)
    b.box((0, -0.8, 1.28), (0.4, 0.02, 0.08), mat("screen_small", (0.3, 0.8, 0.9), 0.3, emission=0.6), rot=(0.4, 0, 0))
    _done(items, col, b)

    col, b = _new("banco_supino")
    b.box((0, 0.1, 0.45), (0.32, 1.2, 0.08), _a(), bevel=0.03)
    for sy in (-0.35, 0.55):
        b.box((0, sy, 0.22), (0.06, 0.06, 0.44), metal)
    for sx in (-0.45, 0.45):
        b.box((sx, -0.35, 0.6), (0.05, 0.05, 1.2), metal)
    b.cylinder((0, -0.35, 1.1), 0.02, 0.02, 1.6, steel, rot=(0, math.pi / 2, 0), segments=8)
    for sx in (-0.7, 0.7):
        b.cylinder((sx, -0.35, 1.1), 0.18, 0.18, 0.06, ink, rot=(0, math.pi / 2, 0), segments=16)
    _done(items, col, b)

    col, b = _new("halteres")
    b.box((0, 0, 0.35), (1.0, 0.4, 0.06), metal)
    for sx in (-0.45, 0.45):
        b.box((sx, 0, 0.18), (0.05, 0.35, 0.36), metal)
    for k in range(4):
        x = -0.36 + k * 0.24
        b.cylinder((x, 0, 0.42), 0.015, 0.015, 0.22, steel, rot=(math.pi / 2, 0, 0), segments=6)
        for sy in (-0.1, 0.1):
            b.cylinder((x, sy, 0.42), 0.05 + k * 0.01, 0.05 + k * 0.01, 0.04, mat(("red", "teal", "yellow", "lavender")[k]), rot=(math.pi / 2, 0, 0), segments=10)
    _done(items, col, b)

    col, b = _new("maquina_lavar")
    b.box((0, 0, 0.43), (0.62, 0.62, 0.86), white, bevel=0.04)
    b.cylinder((0, -0.31, 0.42), 0.21, 0.21, 0.03, steel, rot=(math.pi / 2, 0, 0), segments=20)
    b.cylinder((0, -0.325, 0.42), 0.16, 0.16, 0.02, mat("wash_glass", (0.55, 0.72, 0.85), 0.1), rot=(math.pi / 2, 0, 0), segments=20)
    b.box((0, -0.3, 0.76), (0.56, 0.02, 0.12), _a2())
    b.cylinder((0.18, -0.32, 0.76), 0.03, 0.03, 0.03, ink, rot=(math.pi / 2, 0, 0), segments=10)
    _done(items, col, b)

    col, b = _new("varal")
    for sx in (-0.7, 0.7):
        b.tube([(sx, -0.25, 0.0), (sx, 0, 1.2), (sx, 0.25, 0.0)], 0.015, steel, segments=6)
    for k in range(4):
        b.cylinder((0, -0.15 + k * 0.1, 1.15), 0.01, 0.01, 1.4, steel, rot=(0, math.pi / 2, 0), segments=6)
    for k, c in enumerate(("sky", "pink", "white", "mint")):
        b.box((-0.45 + k * 0.3, -0.1 + (k % 2) * 0.1, 0.95), (0.24, 0.02, 0.36), mat(c))
    _done(items, col, b)

    # Mercadinho
    col, b = _new("estante_mercado")
    b.box((0, 0.18, 0.8), (1.8, 0.1, 1.6), mat("shelf_back", (0.88, 0.84, 0.76)))
    for sx in (-0.88, 0.88):
        b.box((sx, 0, 0.8), (0.05, 0.46, 1.6), metal)
    for k in range(4):
        b.box((0, 0, 0.12 + k * 0.45), (1.76, 0.44, 0.03), mat("shelf", (0.96, 0.95, 0.92)))
    b.box((0, -0.23, 0.12), (1.76, 0.02, 0.08), _a())
    b.build(col)
    colors = ("coral", "yellow", "sky", "mint", "lavender", "orange", "pink", "teal")
    for k in range(8):
        s = MeshBuilder(f"Stock_{k + 1}")
        row = k // 2
        x0 = -0.72 if k % 2 == 0 else 0.08
        for j in range(4):
            s.box((x0 + j * 0.17 + 0.08, -0.04, 0.24 + row * 0.45), (0.13, 0.26, 0.2 - 0.03 * (j % 2)), mat(colors[(k + j) % 8]), bevel=0.01)
        s.build(col)
    items.append(col)

    col, b = _new("caixa_mercado")
    b.box((0, 0, 0.48), (1.6, 0.7, 0.96), _a2(), bevel=0.03)
    b.box((0, 0, 0.98), (1.66, 0.76, 0.05), mat("counter"))
    b.box((0, -0.36, 0.5), (1.5, 0.02, 0.2), _a())
    b.box((0.45, 0.1, 1.12), (0.38, 0.3, 0.22), ink, bevel=0.02)
    b.box((0.45, 0.02, 1.32), (0.32, 0.06, 0.2), mat("screen_small"), rot=(-0.4, 0, 0))
    b.box((-0.4, -0.05, 1.03), (0.6, 0.4, 0.02), mat("belt", (0.25, 0.25, 0.27)))
    for k in range(3):
        b.box((-0.55 + k * 0.18, 0.15, 1.08), (0.12, 0.1, 0.1), mat(("coral", "sky", "yellow")[k]))
    _done(items, col, b)

    col, b = _new("freezer_mercado")
    b.box((0, 0, 0.95), (1.2, 0.7, 1.9), white, bevel=0.04)
    b.box((0, -0.35, 1.0), (1.1, 0.02, 1.5), glass)
    for k in range(3):
        for j in range(4):
            b.box((-0.4 + j * 0.27, -0.15, 0.45 + k * 0.48), (0.2, 0.3, 0.3), mat(("white", "sky", "yellow")[k]), bevel=0.02)
    b.box((0, -0.36, 1.82), (1.1, 0.03, 0.12), _a())
    _done(items, col, b)

    col, b = _new("recepcao")
    b.box((0, 0, 0.55), (2.2, 0.7, 1.1), _wt(), bevel=0.04)
    b.box((0, 0, 1.12), (2.3, 0.8, 0.05), mat("counter"))
    b.box((0, -0.36, 0.6), (2.1, 0.02, 0.5), _a())
    b.box((0.6, 0.15, 1.25), (0.4, 0.06, 0.26), ink, rot=(-0.2, 0, 0), bevel=0.02)
    b.cylinder((-0.7, 0.1, 1.2), 0.06, 0.05, 0.12, mat("clay"), segments=10)
    b.sphere((-0.7, 0.1, 1.32), 0.1, mat("leaf"), segments=8, rings=5)
    b.box((-0.1, 0.15, 1.16), (0.2, 0.14, 0.03), mat("cream"))
    _done(items, col, b)

    col, b = _new("mesa_cowork")
    b.box((0, 0, 0.74), (2.4, 0.9, 0.05), mat("wood_light"), bevel=0.02)
    for sx in (-1.1, 1.1):
        b.box((sx, 0, 0.36), (0.06, 0.8, 0.72), metal)
    b.box((0, 0, 0.9), (0.02, 0.8, 0.28), _a())
    for sx in (-0.6, 0.6):
        for sy in (-0.2, 0.2):
            b.box((sx, sy, 0.775), (0.36, 0.24, 0.015), ink)
            b.box((sx, sy + (0.12 if sy > 0 else -0.12), 0.88), (0.36, 0.015, 0.22), mat("screen_small"), rot=(0.15 if sy > 0 else -0.15, 0, 0))
    _done(items, col, b)

    col, b = _new("maquina_cafe")
    b.box((0, 0, 0.45), (1.0, 0.6, 0.9), _wt(), bevel=0.02)
    b.box((0, 0, 0.92), (1.04, 0.64, 0.04), mat("counter"))
    b.box((-0.15, 0.05, 1.15), (0.36, 0.34, 0.42), mat("red"), bevel=0.04)
    b.box((-0.15, -0.13, 1.08), (0.2, 0.04, 0.12), steel)
    for k in range(3):
        b.cylinder((0.25 + k * 0.1, -0.05, 0.98), 0.035, 0.03, 0.08, mat(("cream", "sky", "pink")[k]), segments=10)
    _done(items, col, b)

    col, b = _new("caixas_correio")
    b.box((0, 0.05, 1.0), (1.8, 0.3, 1.4), _wt(), bevel=0.02)
    for r in range(3):
        for c in range(3):
            x = -0.6 + c * 0.6
            z = 0.55 + r * 0.45
            b.box((x, -0.11, z), (0.52, 0.02, 0.38), mat("mail_door", (0.78, 0.66, 0.42), metallic=0.3))
            b.box((x, -0.125, z + 0.1), (0.24, 0.01, 0.03), ink)
    b.box((0, -0.1, 1.82), (1.4, 0.04, 0.2), _a())
    _done(items, col, b)

    col, b = _new("sofa_lounge")
    b.box((0, 0.05, 0.22), (2.8, 0.95, 0.3), _a(), bevel=0.06)
    for sx in (-0.92, 0, 0.92):
        b.box((sx, -0.04, 0.44), (0.88, 0.78, 0.16), _a(), bevel=0.07)
    b.box((0, 0.42, 0.62), (2.7, 0.22, 0.6), _a(), bevel=0.08)
    for sx in (-1.38, 1.38):
        b.box((sx, 0.05, 0.4), (0.18, 0.95, 0.46), _a(), bevel=0.07)
    for sx in (-1.0, 0.3, 1.0):
        b.box((sx, 0.25, 0.64), (0.42, 0.14, 0.36), _a2(), rot=(-0.25, 0, 0.1), bevel=0.07)
    _done(items, col, b)

    return items


# ===========================================================================
# Peças do prédio
# ===========================================================================

def build_residence():
    items = []
    white = mat("white")
    metal = mat("metal")
    steel = mat("steel", (0.78, 0.80, 0.82), 0.35, metallic=0.6)
    trim = mat("trim", (0.97, 0.94, 0.88), 0.7)
    stucco = mat("stucco", (0.98, 0.88, 0.76), 0.9)
    mat("clay", (0.86, 0.54, 0.42))
    mat("window", (0.62, 0.80, 0.92), 0.15)

    # Porta de apartamento (batente + folha; dobradiça no lado -X)
    col, b = _new("porta_apto")
    b.box((-0.62, 0, 1.1), (0.12, 0.2, 2.2), trim)
    b.box((0.62, 0, 1.1), (0.12, 0.2, 2.2), trim)
    b.box((0, 0, 2.25), (1.36, 0.2, 0.14), trim)
    b.build(col)
    leaf = MeshBuilder("Door_Leaf")
    leaf.box((0.56, 0, 1.06), (1.1, 0.06, 2.12), _a(), bevel=0.015)
    for z in (0.6, 1.5):
        leaf.box((0.56, -0.035, z), (0.8, 0.01, 0.6), _a2(), bevel=0.01)
    leaf.sphere((0.98, -0.07, 1.05), 0.04, mat("gold"), segments=8, rings=6)
    leaf.box((0.56, -0.035, 1.92), (0.3, 0.01, 0.1), mat("gold"))
    leaf.build(col)
    items.append(col)

    # Capacho e placa do apartamento
    col, b = _new("capacho")
    b.box((0, 0, 0.01), (1.0, 0.6, 0.02), mat("mat", (0.62, 0.46, 0.30)), bevel=0.01)
    b.box((0, 0, 0.021), (0.8, 0.4, 0.002), _a())
    _done(items, col, b)

    # Elevador: moldura, portas deslizantes e painel
    col, b = _new("elevador")
    b.box((0, 0.3, 1.3), (2.0, 0.6, 2.6), mat("elevator_frame", (0.70, 0.72, 0.74), 0.4, metallic=0.4))
    b.box((0, -0.02, 2.62), (2.1, 0.08, 0.2), trim)
    b.box((-0.9, -0.02, 1.25), (0.2, 0.08, 2.5), trim)
    b.box((0.9, -0.02, 1.25), (0.2, 0.08, 2.5), trim)
    b.box((0, 0.55, 1.2), (1.5, 0.05, 2.3), mat("cabin", (0.86, 0.80, 0.70)))
    b.box((0, 0.3, 0.02), (1.5, 0.5, 0.04), mat("cabin_floor", (0.55, 0.42, 0.32)))
    b.box((1.2, -0.03, 1.25), (0.16, 0.04, 0.4), metal, bevel=0.01)
    for z in (1.33, 1.17):
        b.cylinder((1.2, -0.06, z), 0.035, 0.035, 0.02, mat("button", (1.0, 0.85, 0.5), 0.3, emission=0.5), rot=(math.pi / 2, 0, 0), segments=10)
    b.build(col)
    for name, x in (("Door_L", -0.4), ("Door_R", 0.4)):
        d = MeshBuilder(name)
        d.box((x, 0.04, 1.15), (0.8, 0.04, 2.3), steel, bevel=0.005)
        d.box((x, 0.015, 1.15), (0.6, 0.01, 1.9), mat("steel_inset", (0.70, 0.72, 0.75), 0.4, metallic=0.5))
        d.build(col)
    disp = MeshBuilder("Display")
    disp.box((0, -0.04, 2.45), (0.5, 0.03, 0.14), mat("display", (0.95, 0.55, 0.30), 0.3, emission=1.2))
    disp.build(col)
    items.append(col)

    # Escadas (lance com corrimão, subindo para +Y)
    col, b = _new("escada")
    for k in range(9):
        b.box((0, -0.8 + k * 0.22, 0.09 + k * 0.17), (1.2, 0.28, 0.18), mat("stair", (0.85, 0.78, 0.68)), bevel=0.01)
    for sx in (-0.62, 0.62):
        b.tube([(sx, -0.9, 0.95), (sx, 1.1, 2.4)], 0.03, mat("wood_dark"), segments=8)
        for k in range(0, 9, 2):
            b.box((sx, -0.8 + k * 0.22, 0.6 + k * 0.17), (0.03, 0.03, 0.8), metal)
    b.box((0, 1.2, 1.5), (1.4, 0.1, 3.0), stucco)
    _done(items, col, b)

    # Janela interna (vidro DB_window acende à noite)
    col, b = _new("janela")
    b.box((0, 0, 0.0), (1.4, 0.16, 1.3), trim, bevel=0.02)
    b.box((0, -0.01, 0.0), (1.22, 0.1, 1.12), mat("window", (0.62, 0.80, 0.92), 0.15))
    b.box((0, -0.07, 0.0), (0.05, 0.04, 1.14), trim)
    b.box((0, -0.07, 0.0), (1.24, 0.04, 0.05), trim)
    b.box((0, -0.12, -0.68), (1.5, 0.22, 0.06), trim)
    for sx in (-0.82, 0.82):
        b.box((sx, -0.06, 0.0), (0.12, 0.04, 1.3), _a2())
    _done(items, col, b)

    # Fachada: módulo com janela e floreira (4 m x 3,2 m)
    def facade_window(name, balcony=False):
        col, b = _new(name)
        b.box((0, 0.1, 1.6), (4.0, 0.2, 3.2), stucco)
        b.box((0, 0.0, 0.08), (4.0, 0.12, 0.16), trim)
        b.box((0, -0.04, 3.12), (4.0, 0.2, 0.16), trim)
        if balcony:
            b.box((0, -0.06, 1.3), (1.5, 0.12, 2.3), trim)
            b.box((0, -0.08, 1.3), (1.3, 0.06, 2.1), mat("window"))
            b.box((0, -0.65, 0.12), (2.6, 1.2, 0.14), trim, bevel=0.02)
            for k in range(14):
                b.box((-1.25 + k * 0.192, -1.22, 0.62), (0.04, 0.04, 0.9), white)
            b.box((0, -1.22, 1.08), (2.6, 0.08, 0.06), white)
            for sx in (-1.25, 1.25):
                b.box((sx, -0.65, 1.08), (0.06, 1.2, 0.06), white)
            for sx in (-0.95, 0.95):
                b.cylinder((sx, -0.95, 0.38), 0.18, 0.22, 0.4, mat("clay"), segments=12)
                b.sphere((sx, -0.95, 0.68), 0.26, mat("leaf"), scale=(1, 1, 0.8), segments=10, rings=6)
                b.sphere((sx + 0.08, -1.1, 0.78), 0.06, _a(), segments=8, rings=5)
        else:
            for sx in (-0.95, 0.95):
                b.box((sx, -0.04, 1.55), (1.1, 0.12, 1.5), trim)
                b.box((sx, -0.06, 1.55), (0.94, 0.06, 1.32), mat("window"))
                b.box((sx, -0.09, 1.55), (0.04, 0.03, 1.34), trim)
                b.box((sx - 0.68, -0.08, 1.55), (0.24, 0.04, 1.4), _a2())
                b.box((sx + 0.68, -0.08, 1.55), (0.24, 0.04, 1.4), _a2())
                b.box((sx, -0.22, 0.72), (1.1, 0.3, 0.22), mat("wood"), bevel=0.02)
                for k in range(4):
                    b.sphere((sx - 0.38 + k * 0.25, -0.22, 0.9), 0.1, mat("leaf"), segments=8, rings=5)
                    b.sphere((sx - 0.38 + k * 0.25, -0.3, 0.95), 0.045, _a() if k % 2 else mat("yellow"), segments=6, rings=4)
        _done(items, col, b)

    facade_window("fachada_janela")
    facade_window("fachada_varanda", balcony=True)

    # Fachada do térreo: entrada com marquise e vitrines
    col, b = _new("fachada_entrada")
    b.box((0, 0.1, 1.75), (8.0, 0.2, 3.5), stucco)
    b.box((0, -0.02, 1.3), (2.4, 0.16, 2.6), trim)
    b.box((0, -0.04, 1.25), (2.1, 0.06, 2.45), mat("window"))
    b.box((0, -0.08, 1.25), (0.06, 0.04, 2.45), trim)
    for sx in (-2.8, 2.8):
        b.box((sx, -0.02, 1.6), (2.2, 0.14, 2.2), trim)
        b.box((sx, -0.04, 1.6), (2.0, 0.06, 2.0), mat("window"))
    b.box((0, -1.0, 3.0), (3.6, 2.0, 0.14), white, bevel=0.03)
    b.box((0, -1.95, 2.85), (3.6, 0.1, 0.3), mat("accent"), bevel=0.02)
    for sx in (-1.6, 1.6):
        b.cylinder((sx, -1.8, 1.5), 0.07, 0.07, 3.0, metal, segments=10)
    for sx in (-1.6, 1.6):
        b.cylinder((sx, -0.45, 0.3), 0.3, 0.36, 0.6, mat("clay"), segments=14)
        b.sphere((sx, -0.45, 0.85), 0.42, mat("leaf"), scale=(1, 1, 1.1), segments=10, rings=6)
    b.box((0, -0.12, 3.25), (3.2, 0.06, 0.34), mat("sign", (0.36, 0.22, 0.14)))
    _done(items, col, b)

    # Topo do prédio (cornija com platibanda)
    col, b = _new("fachada_topo")
    b.box((0, 0.0, 0.25), (4.0, 0.5, 0.5), trim, bevel=0.03)
    b.box((0, 0.1, 0.75), (4.0, 0.3, 0.5), stucco)
    b.box((0, 0.0, 1.03), (4.1, 0.42, 0.08), trim)
    for k in range(5):
        b.box((-1.6 + k * 0.8, -0.26, 0.12), (0.18, 0.06, 0.18), mat("accent2"))
    _done(items, col, b)

    # Placa "Daybloom Residence" (letras modeladas por blocos simples)
    col, b = _new("placa_residence")
    b.box((0, 0, 0.0), (3.0, 0.08, 0.5), mat("sign"), bevel=0.02)
    b.box((0, -0.05, 0.0), (2.8, 0.02, 0.38), mat("cream"))
    for k in range(11):
        h = 0.2 + 0.06 * (k % 3)
        b.box((-1.2 + k * 0.24, -0.07, 0.0), (0.14, 0.02, h), mat("accent"))
    b.sphere((1.32, -0.08, 0.1), 0.06, mat("yellow"), scale=(1, 0.3, 1), segments=10, rings=6)
    _done(items, col, b)

    # Parapeito / guarda-corpo modular (2 m)
    col, b = _new("guarda_corpo")
    b.box((0, 0, 0.06), (2.0, 0.24, 0.12), trim)
    b.box((0, 0, 1.0), (2.0, 0.1, 0.08), white)
    for k in range(11):
        b.box((-0.95 + k * 0.19, 0, 0.54), (0.04, 0.04, 0.9), white)
    _done(items, col, b)

    return items


# ===========================================================================
# Exportação
# ===========================================================================

def _export_all(items, model_dir, sub, blend_path, log):
    out = []
    for col in items:
        out.append(export_collection(col, os.path.join(model_dir, sub, f"{col.name}.glb")))
        log(f"{sub}: {col.name}")
    save_blend(blend_path)
    return out


def generate_furniture(blend_dir, model_dir, log):
    clear_scene()
    return _export_all(build_furniture(), model_dir, "furniture", os.path.join(blend_dir, "residence", "furniture.blend"), log)


def generate_residence(blend_dir, model_dir, log):
    clear_scene()
    return _export_all(build_residence(), model_dir, "residence", os.path.join(blend_dir, "residence", "building.blend"), log)
