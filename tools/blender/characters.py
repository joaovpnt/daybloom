"""Personagens do Daybloom: jogadora e oito moradores (modelagem, rig e animações).

Cada personagem é exportado como uma coleção com:
* `<Nome>_Rig` — armadura com ossos root, hips, spine, head, arm_L/R, leg_L/R,
  tail, ear_L/R;
* `Body` — malha principal com pele rígida por osso;
* expressões faciais em malhas separadas presas ao osso da cabeça:
  `Eyes_Open`, `Eyes_Happy`, `Eyes_Closed`, `Eyes_Sad`, `Mouth_Smile`,
  `Mouth_Open`, `Mouth_Frown` (o Godot alterna a visibilidade);
* animações em trilhas NLA: idle, walk, talk, happy, sad, surprised
  (moradores) e idle, walk, run, interact, talk, happy (jogadora).
"""

from __future__ import annotations

import math

from dbkit import BoneSpec, MeshBuilder, PALETTE, make_action, make_armature, mat, new_collection

# Ângulos usados nas animações (graus). O sinal de X inclina "para frente".
FWD = -1.0


def _bones(hips: float, neck: float, shoulder_x: float, shoulder_z: float, hip_x: float, tail=(0.0, 0.25, 0.40), ear_z=None, ear_x=0.12) -> list[BoneSpec]:
    ear_z = ear_z if ear_z is not None else neck + 0.45
    tx, ty, tz = tail
    return [
        BoneSpec("root", (0, 0, 0), (0, 0, 0.15)),
        BoneSpec("hips", (0, 0, hips), (0, 0, hips + 0.12), "root"),
        BoneSpec("spine", (0, 0, hips + 0.12), (0, 0, neck), "hips"),
        BoneSpec("head", (0, 0, neck), (0, 0, neck + 0.35), "spine"),
        BoneSpec("arm_L", (shoulder_x, 0, shoulder_z), (shoulder_x + 0.04, 0, shoulder_z - 0.28), "spine"),
        BoneSpec("arm_R", (-shoulder_x, 0, shoulder_z), (-shoulder_x - 0.04, 0, shoulder_z - 0.28), "spine"),
        BoneSpec("leg_L", (hip_x, 0, hips), (hip_x, 0, 0.03), "hips"),
        BoneSpec("leg_R", (-hip_x, 0, hips), (-hip_x, 0, 0.03), "hips"),
        BoneSpec("tail", (tx, ty, tz), (tx, ty + 0.2, tz + 0.15), "hips"),
        BoneSpec("ear_L", (ear_x, 0, ear_z), (ear_x + 0.02, 0, ear_z + 0.2), "head"),
        BoneSpec("ear_R", (-ear_x, 0, ear_z), (-ear_x - 0.02, 0, ear_z + 0.2), "head"),
    ]


# ---------------------------------------------------------------------------
# Rosto (expressões)
# ---------------------------------------------------------------------------

def _face(col, arm, head_c, head_r, eye_dx=0.11, eye_dz=0.03, mouth_dz=-0.11, eye_scale=1.0, eye_depth=0.90, style="round", mouth_depth=0.97):
    ink = mat("ink", roughness=0.4)
    shine = mat("white", roughness=0.2)
    blush = mat("blush")
    hx, hy, hz = head_c

    def surf(dx, dz, depth):
        if style == "frog" and dz > 0.1:
            return (hx + dx, hy - 0.19, hz + dz)
        # Ponto na superfície frontal da cabeça (frente = -Y).
        x = dx
        z = dz
        rr = max(head_r * head_r - x * x - z * z, 0.0001) ** 0.5
        return (hx + x, hy - rr * depth, hz + z)

    s = eye_scale
    # Olhos abertos
    eo = MeshBuilder("Eyes_Open")
    for side in (1, -1):
        p = surf(side * eye_dx, eye_dz, eye_depth)
        if style == "owl":
            eo.sphere(p, 0.085 * s, mat("cream", roughness=0.5), "head", scale=(1, 0.35, 1))
            eo.sphere((p[0], p[1] - 0.025, p[2]), 0.045 * s, ink, "head", scale=(1, 0.5, 1))
            eo.sphere((p[0] + 0.015, p[1] - 0.05, p[2] + 0.02), 0.014 * s, shine, "head")
        elif style == "frog":
            q = (hx + side * eye_dx, hy - 0.185, hz + 0.2)
            eo.sphere(q, 0.036 * s, ink, "head", scale=(1, 0.5, 1.25))
            eo.sphere((q[0] + 0.012, q[1] - 0.018, q[2] + 0.018), 0.012 * s, shine, "head")
        else:
            eo.sphere(p, 0.045 * s, ink, "head", scale=(0.85, 0.45, 1.15))
            eo.sphere((p[0] + 0.014, p[1] - 0.018, p[2] + 0.02), 0.013 * s, shine, "head")
    eo.build(col, armature=arm)
    # Olhos felizes (^ ^)
    eh = MeshBuilder("Eyes_Happy")
    for side in (1, -1):
        cx, cy, cz = surf(side * eye_dx, eye_dz, eye_depth)
        w = 0.045 * s
        eh.tube([(cx - w, cy, cz - 0.012), (cx, cy - 0.006, cz + 0.022), (cx + w, cy, cz - 0.012)], 0.011 * s, ink, "head", segments=8)
    eh.build(col, armature=arm)
    # Olhos fechados (dormindo / piscando)
    ec = MeshBuilder("Eyes_Closed")
    for side in (1, -1):
        cx, cy, cz = surf(side * eye_dx, eye_dz, eye_depth)
        w = 0.045 * s
        ec.tube([(cx - w, cy, cz + 0.005), (cx, cy - 0.006, cz - 0.018), (cx + w, cy, cz + 0.005)], 0.009 * s, ink, "head", segments=8)
    ec.build(col, armature=arm)
    # Olhos tristes (com sobrancelhas inclinadas)
    es = MeshBuilder("Eyes_Sad")
    for side in (1, -1):
        cx, cy, cz = surf(side * eye_dx, eye_dz, eye_depth)
        es.sphere((cx, cy, cz - 0.01), 0.036 * s, ink, "head", scale=(0.9, 0.45, 0.9))
        es.sphere((cx + 0.01, cy - 0.016, cz + 0.003), 0.01 * s, shine, "head")
        es.tube([(cx - side * 0.05 * s, cy - 0.004, cz + 0.06), (cx + side * 0.03 * s, cy - 0.004, cz + 0.085)], 0.008, ink, "head", segments=6)
    es.build(col, armature=arm)
    # Bocas
    mx, my, mz = surf(0.0, mouth_dz, mouth_depth)
    ms = MeshBuilder("Mouth_Smile")
    ms.tube([(mx - 0.035, my, mz + 0.012), (mx - 0.012, my - 0.004, mz - 0.008), (mx, my - 0.004, mz + 0.002), (mx + 0.012, my - 0.004, mz - 0.008), (mx + 0.035, my, mz + 0.012)], 0.0075, ink, "head", segments=6)
    ms.build(col, armature=arm)
    mo = MeshBuilder("Mouth_Open")
    mo.sphere((mx, my, mz - 0.005), 0.03, mat("mouth", (0.45, 0.16, 0.18), 0.6), "head", scale=(1.0, 0.35, 0.85))
    mo.sphere((mx, my - 0.006, mz - 0.015), 0.016, mat("tongue", (0.95, 0.5, 0.52)), "head", scale=(1.1, 0.4, 0.6))
    mo.build(col, armature=arm)
    mf = MeshBuilder("Mouth_Frown")
    mf.tube([(mx - 0.03, my, mz - 0.01), (mx, my - 0.004, mz + 0.008), (mx + 0.03, my, mz - 0.01)], 0.0075, ink, "head", segments=6)
    mf.build(col, armature=arm)
    return blush


def _cheeks(b: MeshBuilder, head_c, head_r, dx=0.17, dz=-0.07, color="blush"):
    hx, hy, hz = head_c
    for side in (1, -1):
        x = side * dx
        rr = max(head_r * head_r - x * x - dz * dz, 0.0001) ** 0.5
        b.sphere((hx + x, hy - rr * 0.97, hz + dz), 0.04, mat(color), "head", scale=(1.0, 0.3, 0.6))


# ---------------------------------------------------------------------------
# Animações padrão
# ---------------------------------------------------------------------------

def _actions(arm, kind: str = "villager", bounce: float = 0.03, sway: float = 1.0, tail_wag: float = 15.0, ear_flex: float = 8.0):
    F = FWD
    idle = [
        (1, {"spine": {"rot": (0, 0, 0)}, "head": {"rot": (0, 0, 0)}, "tail": {"rot": (0, 0, -tail_wag * 0.5)}, "ear_L": {"rot": (0, 0, 0)}, "ear_R": {"rot": (0, 0, 0)}, "arm_L": {"rot": (0, 0, 4)}, "arm_R": {"rot": (0, 0, -4)}}),
        (24, {"spine": {"rot": (F * 2, 0, 0), "scale": (1.01, 0.985, 1.01)}, "head": {"rot": (F * -3, 0, 3 * sway)}, "tail": {"rot": (0, 0, tail_wag * 0.5)}, "ear_L": {"rot": (ear_flex * 0.5, 0, 0)}, "ear_R": {"rot": (ear_flex * 0.5, 0, 0)}, "arm_L": {"rot": (0, 0, 7)}, "arm_R": {"rot": (0, 0, -7)}}),
        (48, {"spine": {"rot": (0, 0, 0)}, "head": {"rot": (0, 0, 0)}, "tail": {"rot": (0, 0, -tail_wag * 0.5)}, "ear_L": {"rot": (0, 0, 0)}, "ear_R": {"rot": (0, 0, 0)}, "arm_L": {"rot": (0, 0, 4)}, "arm_R": {"rot": (0, 0, -4)}}),
    ]
    make_action(arm, "idle", idle)

    def gait(name, length, leg, arm_amp, lift, lean):
        h = length // 2
        q = length // 4
        keys = []
        for frame, phase in ((1, 1), (1 + q, 0), (1 + h, -1), (1 + h + q, 0), (1 + length, 1)):
            up = lift if phase == 0 else 0.0
            keys.append((frame, {
                "root": {"loc": (0, up, 0)},
                "spine": {"rot": (F * lean, 0, 4 * phase * sway)},
                "head": {"rot": (F * -lean * 0.6, 0, -3 * phase * sway)},
                "leg_L": {"rot": (leg * phase, 0, 0)},
                "leg_R": {"rot": (-leg * phase, 0, 0)},
                "arm_L": {"rot": (-arm_amp * phase, 0, 6)},
                "arm_R": {"rot": (arm_amp * phase, 0, -6)},
                "tail": {"rot": (0, 0, tail_wag * phase)},
                "ear_L": {"rot": (ear_flex * abs(phase), 0, 0)},
                "ear_R": {"rot": (ear_flex * abs(phase), 0, 0)},
            }))
        make_action(arm, name, keys)

    gait("walk", 24, 32, 30, bounce, 4)
    if kind == "player":
        gait("run", 16, 50, 55, bounce * 2.2, 12)

    talk = [
        (1, {"head": {"rot": (0, 0, 0)}, "arm_R": {"rot": (0, 0, -6)}, "arm_L": {"rot": (0, 0, 6)}}),
        (10, {"head": {"rot": (F * -6, 0, 4)}, "arm_R": {"rot": (F * 35, 0, -25)}, "arm_L": {"rot": (0, 0, 8)}}),
        (20, {"head": {"rot": (F * 3, 0, -3)}, "arm_R": {"rot": (F * 20, 0, -15)}, "arm_L": {"rot": (F * 10, 0, 12)}}),
        (30, {"head": {"rot": (F * -4, 0, -5)}, "arm_R": {"rot": (F * 40, 0, -30)}, "arm_L": {"rot": (0, 0, 6)}}),
        (40, {"head": {"rot": (0, 0, 0)}, "arm_R": {"rot": (0, 0, -6)}, "arm_L": {"rot": (0, 0, 6)}}),
    ]
    make_action(arm, "talk", talk)

    happy = [
        (1, {"root": {"loc": (0, 0, 0)}, "arm_L": {"rot": (0, 0, 6)}, "arm_R": {"rot": (0, 0, -6)}}),
        (6, {"root": {"loc": (0, -0.04, 0)}, "spine": {"scale": (1.06, 0.94, 1.06)}, "arm_L": {"rot": (0, 0, 20)}, "arm_R": {"rot": (0, 0, -20)}}),
        (12, {"root": {"loc": (0, 0.16, 0)}, "head": {"rot": (F * -8, 0, 0)}, "arm_L": {"rot": (0, 0, 140)}, "arm_R": {"rot": (0, 0, -140)}, "tail": {"rot": (0, 0, 25)}, "ear_L": {"rot": (-15, 0, 0)}, "ear_R": {"rot": (-15, 0, 0)}}),
        (18, {"root": {"loc": (0, 0, 0)}, "spine": {"scale": (1.05, 0.95, 1.05)}, "arm_L": {"rot": (0, 0, 60)}, "arm_R": {"rot": (0, 0, -60)}, "tail": {"rot": (0, 0, -25)}}),
        (24, {"root": {"loc": (0, 0.1, 0)}, "arm_L": {"rot": (0, 0, 120)}, "arm_R": {"rot": (0, 0, -120)}, "tail": {"rot": (0, 0, 25)}}),
        (32, {"root": {"loc": (0, 0, 0)}, "arm_L": {"rot": (0, 0, 6)}, "arm_R": {"rot": (0, 0, -6)}}),
    ]
    make_action(arm, "happy", happy, cyclic=False)

    if kind == "player":
        interact = [
            (1, {"spine": {"rot": (0, 0, 0)}, "arm_R": {"rot": (0, 0, -6)}}),
            (8, {"spine": {"rot": (F * 25, 0, 0)}, "head": {"rot": (F * 10, 0, 0)}, "arm_R": {"rot": (F * 70, 0, -10)}, "arm_L": {"rot": (F * 40, 0, 10)}, "leg_L": {"rot": (-10, 0, 0)}, "leg_R": {"rot": (10, 0, 0)}}),
            (14, {"spine": {"rot": (F * 28, 0, 0)}, "head": {"rot": (F * 12, 0, 0)}, "arm_R": {"rot": (F * 80, 0, -5)}, "arm_L": {"rot": (F * 45, 0, 5)}, "leg_L": {"rot": (-10, 0, 0)}, "leg_R": {"rot": (10, 0, 0)}}),
            (24, {"spine": {"rot": (0, 0, 0)}, "arm_R": {"rot": (0, 0, -6)}}),
        ]
        make_action(arm, "interact", interact, cyclic=False)
    else:
        sad = [
            (1, {"spine": {"rot": (F * 8, 0, 0)}, "head": {"rot": (F * 18, 0, 0)}, "arm_L": {"rot": (0, 0, 2)}, "arm_R": {"rot": (0, 0, -2)}, "ear_L": {"rot": (30, 0, -20)}, "ear_R": {"rot": (30, 0, 20)}, "tail": {"rot": (-20, 0, 0)}}),
            (30, {"spine": {"rot": (F * 10, 0, 0), "scale": (1.0, 0.98, 1.0)}, "head": {"rot": (F * 22, 0, 6)}, "arm_L": {"rot": (0, 0, 3)}, "arm_R": {"rot": (0, 0, -3)}, "ear_L": {"rot": (35, 0, -22)}, "ear_R": {"rot": (35, 0, 22)}, "tail": {"rot": (-25, 0, 0)}}),
            (60, {"spine": {"rot": (F * 8, 0, 0)}, "head": {"rot": (F * 18, 0, 0)}, "arm_L": {"rot": (0, 0, 2)}, "arm_R": {"rot": (0, 0, -2)}, "ear_L": {"rot": (30, 0, -20)}, "ear_R": {"rot": (30, 0, 20)}, "tail": {"rot": (-20, 0, 0)}}),
        ]
        make_action(arm, "sad", sad)
        surprised = [
            (1, {"root": {"loc": (0, 0, 0)}}),
            (5, {"root": {"loc": (0, 0.12, 0)}, "spine": {"rot": (F * -10, 0, 0), "scale": (0.95, 1.06, 0.95)}, "head": {"rot": (F * -10, 0, 0)}, "arm_L": {"rot": (0, 0, 70)}, "arm_R": {"rot": (0, 0, -70)}, "ear_L": {"rot": (-20, 0, 0)}, "ear_R": {"rot": (-20, 0, 0)}, "tail": {"rot": (30, 0, 0)}}),
            (12, {"root": {"loc": (0, 0, 0)}, "spine": {"rot": (F * -6, 0, 0)}, "arm_L": {"rot": (0, 0, 40)}, "arm_R": {"rot": (0, 0, -40)}}),
            (24, {"root": {"loc": (0, 0, 0)}}),
        ]
        make_action(arm, "surprised", surprised, cyclic=False)


# ---------------------------------------------------------------------------
# Moradores
# ---------------------------------------------------------------------------

VILLAGERS = {
    "lila": dict(shape="coelho", primary=(0.97, 0.95, 0.92), secondary=(0.98, 0.74, 0.80), accent=(0.70, 0.60, 0.92), scale=0.95),
    "tobias": dict(shape="urso", primary=(0.58, 0.39, 0.26), secondary=(0.88, 0.74, 0.56), accent=(0.97, 0.97, 0.93), scale=1.12),
    "marina": dict(shape="lontra", primary=(0.47, 0.33, 0.23), secondary=(0.94, 0.85, 0.70), accent=(0.22, 0.66, 0.70), scale=1.0),
    "otavio": dict(shape="coruja", primary=(0.60, 0.50, 0.40), secondary=(0.93, 0.87, 0.74), accent=(0.22, 0.28, 0.52), scale=0.95),
    "pipa": dict(shape="esquilo", primary=(0.88, 0.47, 0.22), secondary=(0.99, 0.89, 0.72), accent=(0.98, 0.80, 0.28), scale=0.85),
    "bento": dict(shape="sapo", primary=(0.46, 0.76, 0.40), secondary=(0.97, 0.94, 0.66), accent=(0.86, 0.26, 0.26), scale=0.92),
    "ravena": dict(shape="raposa", primary=(0.94, 0.52, 0.22), secondary=(0.99, 0.96, 0.91), accent=(0.50, 0.26, 0.60), scale=1.0),
    "celeste": dict(shape="ovelha", primary=(0.98, 0.96, 0.92), secondary=(0.96, 0.82, 0.78), accent=(0.78, 0.62, 0.88), scale=0.95),
}


def build_villager(npc_id: str, root_collection=None):
    cfg = VILLAGERS[npc_id]
    shape = cfg["shape"]
    col = new_collection(f"villager_{npc_id}", root_collection)
    mp = mat(f"{npc_id}_fur", cfg["primary"])
    ms = mat(f"{npc_id}_belly", cfg["secondary"])
    ma = mat(f"{npc_id}_cloth", cfg["accent"])
    ink = mat("ink", roughness=0.4)
    nose = mat("nose", (0.30, 0.18, 0.18), 0.5)

    # Proporções por espécie
    body_r = {"urso": 0.27, "ovelha": 0.26, "esquilo": 0.2, "coruja": 0.25, "sapo": 0.24, "lontra": 0.2}.get(shape, 0.22)
    body_h = {"lontra": 1.55, "raposa": 1.35, "coelho": 1.3, "esquilo": 1.25}.get(shape, 1.2)
    leg_len = {"lontra": 0.2, "sapo": 0.14, "coruja": 0.12, "urso": 0.2}.get(shape, 0.18)
    head_r = {"coruja": 0.33, "sapo": 0.31, "urso": 0.3, "esquilo": 0.27, "lontra": 0.26}.get(shape, 0.28)
    hips = leg_len + 0.05
    body_c = hips + body_r * body_h * 0.55
    neck = body_c + body_r * body_h * 0.8
    head_c = (0.0, 0.0, neck + head_r * 0.82)
    if shape == "coruja":
        head_c = (0.0, 0.0, neck + head_r * 0.7)
    shoulder_z = neck - 0.06
    shoulder_x = body_r * 0.95
    tail = (0.0, body_r * 0.9, hips + 0.1)
    arm = make_armature(f"villager_{npc_id}", col, _bones(hips, neck, shoulder_x, shoulder_z, body_r * 0.45, tail=tail, ear_z=head_c[2] + head_r * 0.7, ear_x=head_r * 0.45))

    b = MeshBuilder("Body")
    # Pernas e pés
    for side, g in ((1, "leg_L"), (-1, "leg_R")):
        x = side * body_r * 0.45
        if shape == "sapo":
            b.sphere((x * 1.3, -0.02, hips * 0.55), 0.09, mp, g, scale=(1.2, 1.4, 0.9))
            b.sphere((x * 1.4, -0.09, 0.03), 0.07, mp, g, scale=(1.3, 1.6, 0.5))
        elif shape == "coruja":
            b.cylinder((x, 0, hips * 0.5), 0.035, 0.035, hips, mat("beak", (0.95, 0.68, 0.25)), g)
            b.sphere((x, -0.05, 0.025), 0.05, mat("beak"), g, scale=(1.2, 1.6, 0.5))
        else:
            b.tube([(x, 0, hips + 0.02), (x, 0, 0.06)], [0.075, 0.07], mp, g)
            b.sphere((x, -0.035, 0.04), 0.07, ms if shape in ("coelho", "urso") else mp, g, scale=(1.0, 1.45, 0.65))
    # Corpo em forma de pera
    b.sphere((0, 0, body_c), body_r, mp, "spine", scale=(1.0, 0.92, body_h), taper=0.18, segments=24, rings=14)
    b.sphere((0, -body_r * 0.45, body_c - 0.02), body_r * 0.72, ms, "spine", scale=(0.95, 0.55, body_h * 0.92), taper=0.15)
    # Braços com mãozinhas
    for side, g in ((1, "arm_L"), (-1, "arm_R")):
        x0 = side * shoulder_x
        hand = (x0 + side * 0.07, -0.02, shoulder_z - 0.26)
        if shape == "coruja":
            b.sphere((x0 + side * 0.02, 0.02, shoulder_z - 0.14), 0.075, mp, g, scale=(0.45, 1.0, 1.6), rot=(0, side * 0.25, 0))
            b.sphere((x0 + side * 0.03, 0.03, shoulder_z - 0.2), 0.06, ms, g, scale=(0.4, 0.9, 1.3), rot=(0, side * 0.25, 0))
        else:
            b.tube([(x0, 0, shoulder_z), (x0 + side * 0.05, -0.01, shoulder_z - 0.14), hand], [0.055, 0.05, 0.048], mp, g)
            b.sphere(hand, 0.055, ms if shape in ("urso", "sapo") else mp, g, scale=(1, 1, 0.9))
    # Cabeça
    hx, hy, hz = head_c
    head_scale = {"sapo": (1.18, 1.0, 0.82), "coruja": (1.08, 1.0, 1.0), "lontra": (1.0, 1.05, 0.95)}.get(shape, (1.0, 1.0, 0.98))
    b.sphere(head_c, head_r, mp, "head", scale=head_scale, segments=28, rings=16)
    face_style = "round"
    eye_dz = 0.03
    eye_dx = 0.11
    mouth_dz = -0.11
    eye_depth = 0.9
    mouth_depth = {"coelho": 1.18, "urso": 1.3, "lontra": 1.28, "esquilo": 1.18, "raposa": 1.45}.get(shape, 0.97)
    if shape == "coelho":
        b.sphere((hx, hy - head_r * 0.82, hz - 0.08), 0.1, ms, "head", scale=(1.15, 0.55, 0.75))
        b.sphere((hx, hy - head_r * 0.98, hz - 0.045), 0.025, mat("nose_pink", (0.96, 0.55, 0.62)), "head", scale=(1.2, 0.8, 0.9))
        mouth_dz = -0.12
        for side, g in ((1, "ear_L"), (-1, "ear_R")):
            ex = side * head_r * 0.42
            base = hz + head_r * 0.72
            pts = [(ex, 0.02, base), (ex + side * 0.03, 0.03, base + 0.22), (ex + side * 0.07, 0.06, base + 0.42)]
            b.tube(pts, [0.075, 0.085, 0.045], mp, g)
            b.tube([(p[0], p[1] - 0.045, p[2]) for p in pts[:-1]] + [(pts[-1][0], pts[-1][1] - 0.03, pts[-1][2] - 0.04)], [0.04, 0.05, 0.02], ms, g)
        # Coroa de flores
        for i in range(7):
            a = -1.2 + i * 0.4
            px, pz = hx + math.sin(a) * head_r * 0.8, hz + math.cos(a) * head_r * 0.62
            b.sphere((px, hy - 0.05, pz + 0.05), 0.045, mat("flower_pink", (0.98, 0.56, 0.66)) if i % 2 else mat("flower_yellow", (1.0, 0.84, 0.32)), "head")
    elif shape == "urso":
        b.sphere((hx, hy - head_r * 0.8, hz - 0.07), 0.13, ms, "head", scale=(1.15, 0.7, 0.8))
        b.sphere((hx, hy - head_r * 1.02, hz - 0.03), 0.045, nose, "head", scale=(1.3, 0.8, 0.9))
        mouth_dz = -0.13
        for side, g in ((1, "ear_L"), (-1, "ear_R")):
            ex, ez = side * head_r * 0.72, hz + head_r * 0.68
            b.sphere((ex, 0.0, ez), 0.1, mp, g, scale=(1.0, 0.6, 0.95))
            b.sphere((ex, -0.04, ez), 0.06, ms, g, scale=(1.0, 0.4, 0.9))
        # Avental e chapéu de padeiro
        b.sphere((0, -body_r * 0.5, body_c - 0.04), body_r * 0.78, ma, "spine", scale=(1.0, 0.45, body_h * 0.95), taper=0.2)
        b.box((0, -body_r * 0.86, body_c - 0.05), (0.12, 0.02, 0.08), mat("wood_light"), "spine", bevel=0.01)
        b.cylinder((hx, hy + 0.02, hz + head_r * 0.92), 0.17, 0.2, 0.2, ma, "head")
        for i in range(5):
            a = i * 2 * math.pi / 5
            b.sphere((hx + math.cos(a) * 0.12, hy + 0.02 + math.sin(a) * 0.12, hz + head_r * 0.92 + 0.16), 0.12, ma, "head")
        b.sphere((hx, hy + 0.02, hz + head_r * 0.92 + 0.2), 0.13, ma, "head")
    elif shape == "lontra":
        b.sphere((hx, hy - head_r * 0.8, hz - 0.06), 0.12, ms, "head", scale=(1.3, 0.7, 0.75))
        b.sphere((hx, hy - head_r * 1.02, hz - 0.02), 0.04, nose, "head", scale=(1.4, 0.8, 0.9))
        for side in (1, -1):
            for k in range(2):
                b.tube([(hx + side * 0.07, hy - head_r * 0.98, hz - 0.05 - k * 0.025), (hx + side * 0.2, hy - head_r * 0.8, hz - 0.03 - k * 0.04)], 0.004, ink, "head", segments=4, caps=False)
        mouth_dz = -0.12
        for side, g in ((1, "ear_L"), (-1, "ear_R")):
            b.sphere((side * head_r * 0.85, 0.03, hz + head_r * 0.35), 0.055, mp, g, scale=(1, 0.6, 1))
        # Lenço de praia e boia
        b.tube([(math.cos(a) * body_r * 0.85, math.sin(a) * body_r * 0.8, neck - 0.02) for a in [i * 2 * math.pi / 12 for i in range(13)]], 0.045, ma, "spine", segments=8, caps=False)
        b.sphere((body_r * 0.4, -body_r * 0.9, neck - 0.1), 0.06, ma, "spine", scale=(1, 0.5, 1.3))
    elif shape == "coruja":
        face_style = "owl"
        eye_dx = 0.13
        eye_dz = 0.04
        eye_depth = 1.04
        b.sphere((hx, hy - head_r * 0.55, hz + 0.0), head_r * 0.82, ms, "head", scale=(1.1, 0.5, 0.82))
        b.cylinder((hx, hy - head_r * 1.0, hz - 0.06), 0.045, 0.0, 0.1, mat("beak", (0.95, 0.68, 0.25)), "head", rot=(math.radians(110), 0, 0), segments=10)
        mouth_dz = -0.17
        mouth_depth = 1.0
        for side, g in ((1, "ear_L"), (-1, "ear_R")):
            b.tube([(side * head_r * 0.6, 0.0, hz + head_r * 0.7), (side * head_r * 0.85, 0.02, hz + head_r * 1.1)], [0.07, 0.02], mp, g, segments=8)
        # Colete com estrelas e óculos de leitura sobre a testa
        b.sphere((0, 0, body_c), body_r * 1.02, ma, "spine", scale=(1.0, 0.95, body_h * 0.62), taper=0.15)
        for k, (sx, sz) in enumerate(((0.12, 0.05), (-0.1, -0.06), (0.05, -0.14))):
            b.sphere((sx, -body_r * 1.0, body_c + sz), 0.022, mat("gold", roughness=0.4, emission=0.4), "spine", scale=(1, 0.4, 1))
        for side in (1, -1):
            b.tube([(side * 0.13 + math.cos(a) * 0.06, hy - head_r * 0.92, hz + 0.2 + math.sin(a) * 0.06) for a in [i * 2 * math.pi / 12 for i in range(13)]], 0.008, mat("gold", roughness=0.4), "head", segments=6, caps=False)
    elif shape == "esquilo":
        b.sphere((hx, hy - head_r * 0.82, hz - 0.07), 0.1, ms, "head", scale=(1.25, 0.6, 0.75))
        b.sphere((hx, hy - head_r * 1.0, hz - 0.03), 0.03, nose, "head")
        for side in (1, -1):
            b.sphere((hx + side * 0.15, hy - head_r * 0.7, hz - 0.08), 0.08, ms, "head", scale=(1, 0.6, 0.8))
        mouth_dz = -0.12
        for side, g in ((1, "ear_L"), (-1, "ear_R")):
            ex, ez = side * head_r * 0.55, hz + head_r * 0.75
            b.cylinder((ex, 0.02, ez + 0.06), 0.06, 0.0, 0.16, mp, g, segments=10, rot=(0, side * -0.3, 0))
            b.tube([(ex + side * 0.02, 0.03, ez + 0.13), (ex + side * 0.03, 0.03, ez + 0.2)], [0.02, 0.005], mp, g, segments=6)
        # Bolsa de carteira com alça e boné
        b.tube([(body_r * 0.85, -body_r * 0.3, neck), (0.0, -body_r * 0.95, body_c + 0.05), (-body_r * 0.9, -body_r * 0.2, body_c - 0.08)], 0.018, mat("strap", (0.55, 0.32, 0.2)), "spine", segments=6)
        b.box((-body_r * 0.95, -body_r * 0.35, body_c - 0.12), (0.12, 0.2, 0.15), ma, "spine", bevel=0.025)
        b.box((-body_r * 1.0, -body_r * 0.45, body_c - 0.09), (0.03, 0.1, 0.06), mat("white"), "spine", bevel=0.005)
        b.sphere((hx, hy, hz + head_r * 0.62), head_r * 0.85, mat("cap_blue", (0.30, 0.48, 0.76)), "head", scale=(1.0, 1.0, 0.45), flatten_bottom=0.1)
        b.box((hx, hy - head_r * 0.85, hz + head_r * 0.55), (0.24, 0.14, 0.03), mat("cap_blue"), "head", bevel=0.01)
    elif shape == "sapo":
        face_style = "frog"
        eye_dx = 0.14
        eye_dz = 0.2
        eye_depth = 0.55
        mouth_dz = -0.06
        for side in (1, -1):
            b.sphere((hx + side * 0.14, hy - 0.08, hz + 0.19), 0.095, mp, "head")
            b.sphere((hx + side * 0.14, hy - 0.13, hz + 0.2), 0.07, mat("white"), "head", scale=(1, 0.8, 1))
        b.sphere((hx, hy - head_r * 0.4, hz - 0.08), head_r * 0.8, ms, "head", scale=(1.15, 0.8, 0.5))
        # Gravatinha e violãozinho nas costas
        for side in (1, -1):
            b.sphere((side * 0.06, -body_r * 0.85, neck - 0.04), 0.05, ma, "spine", scale=(1.2, 0.5, 0.8), rot=(0, side * 0.4, 0))
        b.sphere((0, -body_r * 0.9, neck - 0.04), 0.025, ma, "spine")
        b.sphere((0.04, body_r * 1.05, body_c - 0.05), 0.13, mat("wood_light"), "spine", scale=(1.0, 0.35, 1.2))
        b.sphere((0.04, body_r * 1.05, body_c + 0.12), 0.09, mat("wood_light"), "spine", scale=(1.0, 0.35, 1.0))
        b.cylinder((0.04, body_r * 1.05, body_c + 0.32), 0.02, 0.02, 0.32, mat("wood_dark"), "spine")
        b.cylinder((0.04, body_r * 0.99, body_c), 0.035, 0.035, 0.01, mat("ink"), "spine", rot=(math.radians(90), 0, 0))
    elif shape == "raposa":
        b.sphere((hx, hy - head_r * 0.85, hz - 0.06), 0.11, ms, "head", scale=(1.0, 1.25, 0.65), taper=0.0)
        b.sphere((hx, hy - head_r * 1.28, hz - 0.045), 0.032, nose, "head")
        for side in (1, -1):
            b.sphere((hx + side * 0.15, hy - head_r * 0.6, hz - 0.08), 0.1, ms, "head", scale=(1, 0.6, 0.7))
        mouth_dz = -0.13
        for side, g in ((1, "ear_L"), (-1, "ear_R")):
            ex, ez = side * head_r * 0.55, hz + head_r * 0.7
            b.cylinder((ex, 0.02, ez + 0.08), 0.1, 0.0, 0.24, mp, g, segments=10, rot=(0, side * -0.25, 0))
            b.cylinder((ex - side * 0.005, -0.02, ez + 0.06), 0.055, 0.0, 0.15, ms, g, segments=8, rot=(0, side * -0.25, 0))
        # Avental de artista com manchas de tinta e boina
        b.sphere((0, -body_r * 0.42, body_c - 0.03), body_r * 0.8, mat("smock", (0.95, 0.93, 0.86)), "spine", scale=(1.0, 0.5, body_h * 0.9), taper=0.2)
        for k, (sx, sz, c) in enumerate(((0.08, 0.05, "red"), (-0.07, -0.04, "sky"), (0.02, -0.12, "yellow"), (-0.1, 0.08, "mint"))):
            b.sphere((sx, -body_r * 0.85, body_c + sz), 0.03, mat(c), "spine", scale=(1, 0.3, 0.8))
        b.sphere((hx + 0.06, hy + 0.0, hz + head_r * 0.85), 0.2, ma, "head", scale=(1.1, 1.1, 0.35), rot=(0, 0.25, 0))
        b.sphere((hx + 0.06, hy, hz + head_r * 0.85 + 0.07), 0.03, ma, "head")
    elif shape == "ovelha":
        wool = mat("celeste_wool", (0.99, 0.97, 0.94))
        b.sphere((hx, hy - head_r * 0.25, hz - 0.03), head_r * 0.88, ms, "head", scale=(0.95, 1.0, 1.05))
        for i in range(9):
            a = -math.pi * 0.95 + i * math.pi * 0.95 / 4
            b.sphere((hx + math.cos(a) * head_r * 0.85, hy + 0.05, hz + abs(math.sin(a)) * head_r * 0.75 + 0.08), 0.12, wool, "head")
        n = 34
        for i in range(n):
            zz = 1 - 2 * (i + 0.5) / n
            rr = math.sqrt(max(0.0, 1 - zz * zz))
            a = i * 2.39996
            if zz < -0.75:
                continue
            b.sphere((math.cos(a) * rr * body_r * 0.95, math.sin(a) * rr * body_r * 0.88, body_c + zz * body_r * body_h * 0.85), 0.1 + 0.02 * ((i * 7) % 3), wool, "spine")
        mouth_dz = -0.13
        for side, g in ((1, "ear_L"), (-1, "ear_R")):
            b.sphere((side * head_r * 1.05, 0.02, hz + 0.05), 0.08, ms, g, scale=(1.4, 0.5, 0.6), rot=(0, side * -0.4, 0))
        # Xale, óculos e novelo de lã
        b.tube([(math.cos(a) * body_r * 1.15, math.sin(a) * body_r * 1.05, neck - 0.03 - abs(math.cos(a)) * 0.02) for a in [i * 2 * math.pi / 14 for i in range(15)]], 0.06, ma, "spine", segments=8, caps=False)
        for side in (1, -1):
            b.tube([(hx + side * 0.11 + math.cos(a) * 0.05, hy - head_r * 0.98, hz + 0.03 + math.sin(a) * 0.05) for a in [i * 2 * math.pi / 12 for i in range(13)]], 0.006, mat("gold", roughness=0.4), "head", segments=6, caps=False)
        b.sphere((0.13, -0.12, shoulder_z - 0.28), 0.06, mat("yarn", (0.62, 0.42, 0.82)), "arm_L")
        eye_dz = 0.0
        eye_depth = 1.1
        mouth_depth = 1.12
    # Cauda
    if shape == "coelho":
        b.sphere((0, body_r * 0.95, hips + 0.12), 0.08, mat("white"), "tail")
    elif shape == "urso":
        b.sphere((0, body_r * 0.95, hips + 0.1), 0.06, mp, "tail")
    elif shape == "lontra":
        b.tube([(0, body_r * 0.8, hips + 0.08), (0, body_r * 1.6, hips - 0.02), (0, body_r * 2.4, 0.05)], [0.08, 0.065, 0.03], mp, "tail")
    elif shape == "coruja":
        b.box((0, body_r * 0.9, hips + 0.03), (0.16, 0.12, 0.04), mp, "tail", rot=(-0.5, 0, 0), bevel=0.02)
    elif shape == "esquilo":
        b.tube([(0, body_r * 0.8, hips + 0.05), (0, body_r * 2.0, hips + 0.25), (0, body_r * 2.2, hips + 0.6), (0, body_r * 1.4, hips + 0.85)], [0.08, 0.15, 0.17, 0.12], mp, "tail", segments=14)
        b.tube([(0, body_r * 2.25, hips + 0.3), (0, body_r * 2.4, hips + 0.55)], [0.1, 0.1], ms, "tail", segments=10)
    elif shape == "raposa":
        b.tube([(0, body_r * 0.8, hips + 0.08), (0.03, body_r * 1.8, hips + 0.12), (0.08, body_r * 2.6, hips + 0.35)], [0.06, 0.13, 0.11], mp, "tail", segments=14)
        b.sphere((0.1, body_r * 2.9, hips + 0.45), 0.1, ms, "tail", scale=(1, 1.1, 1.1))
    elif shape == "ovelha":
        b.sphere((0, body_r * 1.0, hips + 0.12), 0.08, mat("celeste_wool"), "tail")
    _cheeks(b, head_c, head_r * head_scale[0], dx=0.17 if shape != "sapo" else 0.2, dz=-0.07 if shape != "sapo" else -0.02)
    body = b.build(col, armature=arm)
    _face(col, arm, head_c, head_r * (head_scale[1] if shape != "raposa" else 1.0), eye_dx=eye_dx, eye_dz=eye_dz, mouth_dz=mouth_dz, eye_depth=eye_depth, style=face_style, mouth_depth=mouth_depth)
    # Expressões fora da neutra ficam ocultas por padrão
    for o in col.objects:
        if o.name.split(".")[0] in ("Eyes_Happy", "Eyes_Closed", "Eyes_Sad", "Mouth_Open", "Mouth_Frown"):
            o.hide_render = False
    _actions(arm, "villager", tail_wag=25 if shape in ("raposa", "esquilo") else 12, ear_flex=14 if shape == "coelho" else 6)
    arm.scale = (cfg["scale"],) * 3
    return col, arm


# ---------------------------------------------------------------------------
# Jogadora
# ---------------------------------------------------------------------------

def build_player(root_collection=None):
    col = new_collection("player", root_collection)
    skin = mat("player_skin", (0.99, 0.84, 0.72))
    hair = mat("player_hair", (0.40, 0.25, 0.18))
    sweater = mat("player_sweater", (0.98, 0.68, 0.55))
    overalls = mat("player_overalls", (0.40, 0.56, 0.78))
    shoes = mat("player_shoes", (0.98, 0.96, 0.92))
    sole = mat("player_sole", (0.55, 0.40, 0.32))
    hips = 0.5
    neck = 0.92
    head_c = (0.0, 0.0, 1.2)
    head_r = 0.3
    arm = make_armature("player", col, _bones(hips, neck, 0.2, 0.86, 0.1, tail=(0, 0.1, 0.6), ear_z=1.2, ear_x=0.28))
    b = MeshBuilder("Body")
    # Pernas com macacão e tênis
    for side, g in ((1, "leg_L"), (-1, "leg_R")):
        x = side * 0.1
        b.tube([(x, 0, hips), (x, 0, 0.12)], [0.085, 0.07], overalls, g)
        b.sphere((x, -0.035, 0.065), 0.085, shoes, g, scale=(0.95, 1.5, 0.75), flatten_bottom=0.6)
        b.sphere((x, -0.035, 0.03), 0.088, sole, g, scale=(0.97, 1.52, 0.3))
    # Tronco: suéter + macacão
    b.sphere((0, 0, 0.7), 0.22, sweater, "spine", scale=(1.0, 0.85, 1.25), taper=0.15)
    b.sphere((0, -0.02, 0.6), 0.215, overalls, "spine", scale=(1.02, 0.88, 0.75), taper=0.1)
    b.box((0, -0.19, 0.72), (0.2, 0.03, 0.16), overalls, "spine", bevel=0.02)
    for side in (1, -1):
        b.tube([(side * 0.08, -0.17, 0.8), (side * 0.12, -0.1, 0.9), (side * 0.1, 0.12, 0.88), (side * 0.07, 0.17, 0.72)], 0.018, overalls, "spine", segments=6)
        b.sphere((side * 0.08, -0.2, 0.79), 0.018, mat("gold", roughness=0.4), "spine")
    b.sphere((0, -0.21, 0.69), 0.03, mat("flower_pink", (0.98, 0.56, 0.66)), "spine", scale=(1, 0.4, 1))
    # Gola
    b.tube([(math.cos(a) * 0.13, math.sin(a) * 0.11 - 0.01, 0.9) for a in [i * 2 * math.pi / 14 for i in range(15)]], 0.03, mat("white"), "spine", segments=6, caps=False)
    # Braços com mãos e polegar
    for side, g in ((1, "arm_L"), (-1, "arm_R")):
        x0 = side * 0.2
        hand = (x0 + side * 0.06, -0.02, 0.56)
        b.tube([(x0, 0, 0.87), (x0 + side * 0.05, -0.01, 0.72), hand], [0.07, 0.06, 0.05], sweater, g)
        b.sphere(hand, 0.055, skin, g, scale=(0.85, 0.8, 1.0))
        b.sphere((hand[0] - side * 0.02, hand[1] - 0.04, hand[2] + 0.02), 0.022, skin, g)
    # Cabeça, orelhas e cabelo modelado
    b.sphere(head_c, head_r, skin, "head", scale=(1.0, 0.96, 0.98), segments=28, rings=16)
    for side in (1, -1):
        b.sphere((side * head_r * 0.97, 0.02, 1.17), 0.05, skin, "head", scale=(0.5, 0.8, 1.0))
    b.sphere((0, 0.04, 1.27), head_r * 1.06, hair, "head", scale=(1.0, 1.0, 0.92), flatten_bottom=0.05)
    for i, (dx, dz, r) in enumerate(((-0.17, 1.36, 0.11), (-0.06, 1.39, 0.12), (0.06, 1.39, 0.12), (0.17, 1.35, 0.1))):
        b.sphere((dx, -0.24, dz), r, hair, "head", scale=(1.1, 0.6, 0.85), rot=(0.3, 0, dx * 1.5))
    for side in (1, -1):
        b.tube([(side * 0.27, -0.12, 1.3), (side * 0.3, -0.12, 1.12), (side * 0.27, -0.08, 0.98)], [0.07, 0.065, 0.04], hair, "head", segments=10)
    # Rabo de cavalo com laço
    b.tube([(0, 0.27, 1.32), (0, 0.38, 1.22), (0, 0.4, 1.05), (0, 0.33, 0.95)], [0.08, 0.1, 0.08, 0.03], hair, "head", segments=12)
    b.sphere((0, 0.3, 1.33), 0.05, mat("coral"), "head", scale=(1.6, 0.8, 0.9))
    # Presilha de flor
    for i in range(5):
        a = i * 2 * math.pi / 5
        b.sphere((0.2 + math.cos(a) * 0.035, -0.2, 1.4 + math.sin(a) * 0.035), 0.025, mat("flower_yellow", (1.0, 0.84, 0.32)), "head")
    b.sphere((0.2, -0.21, 1.4), 0.02, mat("coral"), "head")
    _cheeks(b, head_c, head_r, dx=0.16, dz=-0.07)
    b.build(col, armature=arm)
    _face(col, arm, head_c, head_r, eye_dx=0.1, eye_dz=0.0, mouth_dz=-0.12, eye_scale=1.05)
    _actions(arm, "player", bounce=0.035, tail_wag=0, ear_flex=0)
    return col, arm
