"""Скелет человека для героя и его одежды: кости, веса вершин, привязка сеток.

Раньше руки и ноги героя были цельными кусками (ArmL, LegR…) с точкой вращения в суставе — без локтей и коленей.
Теперь у модели настоящий скелет (позвоночник, шея, голова, плечи, локти, кисти, бёдра, колени, стопы), сетки
привязаны к костям весами, а в .glb уходит Skeleton3D. Одежда (wear_*) привязана к такому же скелету с теми же
именами костей — в игре её сетки просто пересаживаются на скелет героя (Player.update_clothes).

Координаты — как во всех моделях: Z вверх, герой смотрит в +Y; левая сторона — x < 0.
Веса считаются по высоте вершины в позе покоя (руки опущены, ноги прямые): у локтя и колена — плавный переход.
"""
import bpy
from mathutils import Vector

import kit

# суставы героя (позу покоя задают модели: models_characters.player и одежда в models_ice / models_volcano)
HIP_Z = 0.45
KNEE_Z = 0.25
ANKLE_Z = 0.07
SHOULDER = (0.29, 0.0, 0.98)
ELBOW = (0.33, 0.01, 0.80)
WRIST = (0.34, 0.03, 0.62)
PALM = (0.345, 0.04, 0.56)


def human_bones():
    """[(имя, родитель, начало, конец)] — от корня к концам."""
    out = [
        ("Hips", None, (0, 0, HIP_Z), (0, 0, 0.60)),
        ("Spine", "Hips", (0, 0, 0.60), (0, 0, 0.78)),
        ("Chest", "Spine", (0, 0, 0.78), (0, 0, 1.02)),
        ("Neck", "Chest", (0, 0, 1.02), (0, 0, 1.12)),
        ("Skull", "Neck", (0, 0, 1.12), (0, 0, 1.45)),
    ]
    for sx, s in ((-1, "L"), (1, "R")):
        def m(p, sx=sx):
            return (p[0] * sx, p[1], p[2])
        out += [
            ("Shoulder" + s, "Chest", (sx * 0.1, 0, 0.95), m(SHOULDER)),
            ("UpperArm" + s, "Shoulder" + s, m(SHOULDER), m(ELBOW)),
            ("Forearm" + s, "UpperArm" + s, m(ELBOW), m(WRIST)),
            ("Hand" + s, "Forearm" + s, m(WRIST), m(PALM)),
            ("Thigh" + s, "Hips", (sx * 0.12, 0, HIP_Z), (sx * 0.12, 0, KNEE_Z)),
            ("Shin" + s, "Thigh" + s, (sx * 0.12, 0, KNEE_Z), (sx * 0.12, 0, ANKLE_Z)),
            ("Foot" + s, "Shin" + s, (sx * 0.12, 0, ANKLE_Z), (sx * 0.12, 0.14, 0.03)),
        ]
    return out


def armature(name="Armature"):
    data = bpy.data.armatures.new(name)
    ob = kit.link(bpy.data.objects.new(name, data))
    for o in bpy.context.scene.objects:
        o.select_set(False)
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.mode_set(mode="EDIT")
    for nm, parent, head, tail in human_bones():
        b = data.edit_bones.new(nm)
        b.head = head
        b.tail = tail
        b.roll = 0.0
        if parent:
            b.parent = data.edit_bones[parent]
            b.use_connect = False
    bpy.ops.object.mode_set(mode="OBJECT")
    return ob


def _sm(a, b, x):
    t = min(1.0, max(0.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


# ------------------------------------------------------------------ веса
def w_body(co):
    """Туловище: бёдра → поясница → грудь → шея. Изгиб спины плавный, пояс и шорты держатся за бёдра."""
    z = co.z
    a = _sm(0.52, 0.66, z)      # бёдра → поясница
    b = _sm(0.72, 0.86, z)      # поясница → грудь
    c = _sm(1.0, 1.07, z)       # грудь → шея
    return {"Hips": 1 - a, "Spine": a * (1 - b), "Chest": b * (1 - c), "Neck": c}


def w_head(co):
    return {"Skull": 1.0}   # кость головы зовётся Skull: имя Head занято сеткой головы


def w_arm(s):
    """Рука: плечо — локоть — кисть. Кисть (и рукавица) целиком на кости кисти."""
    def f(co):
        z = co.z
        up = _sm(ELBOW[2] - 0.05, ELBOW[2] + 0.05, z)
        hand = 1 - _sm(0.625, 0.655, z)
        fore = (1 - up) * (1 - hand)
        return {"UpperArm" + s: up, "Forearm" + s: fore, "Hand" + s: hand}
    return f


def w_leg(s):
    """Нога: бедро — колено — стопа. Ступня (и валенок ниже щиколотки) — на кости стопы."""
    def f(co):
        z = co.z
        up = _sm(KNEE_Z - 0.05, KNEE_Z + 0.05, z)
        foot = max(1 - _sm(0.075, 0.115, z), _sm(0.06, 0.1, co.y) * (1 - _sm(0.1, 0.14, z)))
        shin = (1 - up) * (1 - foot)
        return {"Thigh" + s: up, "Shin" + s: shin, "Foot" + s: foot}
    return f


# какая сетка к чему привязана: части героя и куски одежды
PARTS = {
    "Body": w_body, "Torso": w_body, "Head": w_head,
    "ArmL": w_arm("L"), "ArmR": w_arm("R"), "SleeveL": w_arm("L"), "SleeveR": w_arm("R"),
    "MittenL": w_arm("L"), "MittenR": w_arm("R"),
    "LegL": w_leg("L"), "LegR": w_leg("R"), "BootL": w_leg("L"), "BootR": w_leg("R"),
}


def skin(ob, arm, fn):
    """Привязать сетку к скелету: fn(co) -> {кость: вес}. Сетка остаётся в мировых координатах."""
    if ob.modifiers or ob.matrix_world != kit.Matrix.Identity(4):
        kit.bake(ob)
    groups = {}
    for v in ob.data.vertices:
        w = {k: x for k, x in fn(v.co).items() if x > 1e-3}
        tot = sum(w.values())
        for k, x in w.items():
            if k not in groups:
                groups[k] = ob.vertex_groups.new(name=k)
            groups[k].add([v.index], x / tot, "REPLACE")
    ob.parent = arm
    m = ob.modifiers.new("Armature", "ARMATURE")
    m.object = arm
    return ob


def dress():
    """Собрать скелет и привязать к нему все сетки сцены с известными именами (PARTS). Возвращает скелет."""
    arm = armature()
    for ob in list(bpy.context.scene.objects):
        if ob.type == "MESH" and ob.name in PARTS:
            skin(ob, arm, PARTS[ob.name])
    return arm


def resample(pts, radii, step=0.03):
    """Добавить на трубку круги через каждые step метров (по прямым между точками): чтобы рука гнулась в локте,
    а нога в колене, вершин вдоль них должно быть много. Форма не меняется."""
    P = [Vector(p) for p in pts]
    if not isinstance(radii, (list, tuple)):
        radii = [radii] * len(P)
    out_p, out_r = [], []
    for i in range(len(P) - 1):
        n = max(1, int(round((P[i + 1] - P[i]).length / step)))
        for j in range(n):
            t = j / n
            out_p.append(tuple(P[i].lerp(P[i + 1], t)))
            out_r.append(radii[i] + (radii[i + 1] - radii[i]) * t)
    out_p.append(tuple(P[-1]))
    out_r.append(radii[-1])
    return out_p, out_r
