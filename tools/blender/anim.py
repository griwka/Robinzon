"""Движения героя: стоит, ходьба, бег, прыжок и приземление, плавание, сон, сбор руками, расчистка травы,
удары каждым инструментом, как несут инструмент. Всё выгружается в assets/models/hero_anims.glb (только скелет
и клипы) — в игре клипы смешивает AnimationTree (scripts/hero_anim.gd).

Позы не рисуются руками, а считаются: для каждого кадра задано, где бёдра и как повёрнуты спина и голова, куда
ставятся кисти и стопы (двухсуставный IK — тот же, что в игре в scripts/hero_rig.gd) и как лежит инструмент в руке
(кость ToolR). Поэтому локти и колени гнутся сами, а лезвие инструмента идёт по ходу удара.

Вся геометрия — в осях игры: +Y вверх, герой смотрит в −Z, левая сторона — x < 0 (в Blender это (x, −z, y)).
Время клипа t идёт от 0 до 1; игра сама ставит нужный момент (шаг — по фазе шага, удар — по времени удара).
"""
import math

import bmesh
import bpy
from mathutils import Matrix, Vector

import kit
import rig

PI = math.pi
C = Matrix(((1, 0, 0, 0), (0, 0, 1, 0), (0, -1, 0, 0), (0, 0, 0, 1)))   # Blender → оси игры: (x, y, z) → (x, z, −y)
ELBOW_BACK = Vector((0, 0, 1))
KNEE_FWD = Vector((0, 0, -1))
PALM = 0.06
FPS = 30


# ============================================================ математика
def eul(x, y, z):
    """Поворот как Basis.from_euler в Godot (порядок YXZ): x < 0 — наклон вперёд, y > 0 — влево, z > 0 — правый бок вверх."""
    return Matrix.Rotation(y, 3, "Y") @ Matrix.Rotation(x, 3, "X") @ Matrix.Rotation(z, 3, "Z")


def xf(b3, o):
    m = b3.to_4x4()
    m.translation = o
    return m


def sm(a, b, x):
    t = min(1.0, max(0.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


def keys(t, k):
    """Значение по ключам [(t, v), …] с мягкими переходами (как Player._keys)."""
    if t <= k[0][0]:
        return k[0][1]
    for i in range(1, len(k)):
        if t <= k[i][0]:
            f = sm(0.0, 1.0, (t - k[i - 1][0]) / max(k[i][0] - k[i - 1][0], 1e-4))
            return k[i - 1][1] + (k[i][1] - k[i - 1][1]) * f
    return k[-1][1]


def vkeys(t, k):
    """То же для точек: [(t, (x, y, z)), …]."""
    return Vector([keys(t, [(a, v[i]) for a, v in k]) for i in range(3)])


def frame(along, hint):
    y = along.normalized()
    x = hint - y * hint.dot(y)
    if x.length < 1e-4:
        x = y.cross(Vector((1, 0, 0))) if abs(y.x) < 0.9 else y.cross(Vector((0, 1, 0)))
    x.normalize()
    z = x.cross(y)
    return Matrix((x, y, z)).transposed()


class Rest:
    """Поза покоя скелета в осях игры."""
    def __init__(self, arm):
        self.order = [b.name for b in arm.data.bones]   # родители раньше детей
        self.parent = {b.name: (b.parent.name if b.parent else "") for b in arm.data.bones}
        self.rest = {b.name: C @ b.matrix_local for b in arm.data.bones}
        self.rest_local = {n: (self.rest[self.parent[n]].inverted() @ self.rest[n]) if self.parent[n] else self.rest[n]
                           for n in self.order}
        self.kids = {n: [] for n in self.order}
        for n in self.order:
            p = self.parent[n]
            while p:
                self.kids[p].append(n)
                p = self.parent[p]

    def o(self, bone):
        return self.rest[bone].translation.copy()


class Pose:
    """Поза одного кадра: что задано — стоит как задано, остальное идёт за родителем (как HeroRig в игре)."""
    def __init__(self, R):
        self.R = R
        self.m = {}

    def g(self, b):
        if b in self.m:
            return self.m[b]
        p = self.R.parent[b]
        t = self.R.rest_local[b].copy() if not p else self.g(p) @ self.R.rest_local[b]
        self.m[b] = t
        return t

    def put(self, b, t):
        self.m[b] = t
        for k in self.R.kids[b]:
            self.m.pop(k, None)

    def turn(self, b, e):
        """Повернуть кость вокруг её начала; углы — в осях модели, от того, как уже повёрнут родитель."""
        t = self.g(b)
        rb = self.R.rest[b].to_3x3()
        c = t.to_3x3() @ rb.inverted()
        self.put(b, xf(c @ eul(*e) @ rb, t.translation.copy()))

    def carried(self, b):
        """Как сейчас повёрнута кость относительно позы покоя (поворот в осях модели)."""
        return self.g(b).to_3x3() @ self.R.rest[b].to_3x3().inverted()

    def aim(self, b, tip_rest, a, to, hint, hint_rest):
        r = self.R.rest[b]
        d = to - a
        if d.length < 1e-5:
            d = tip_rest - r.translation
        self.put(b, xf(frame(d, hint) @ frame(tip_rest - r.translation, hint_rest).inverted() @ r.to_3x3(), a.copy()))

    def ik(self, upper, lower, end, target, pole, hint_rest, tip=0.0):
        a = self.g(upper).translation.copy()
        ru, rl, re = self.R.o(upper), self.R.o(lower), self.R.o(end)
        l1 = (rl - ru).length
        l2 = (re - rl).length + tip
        d = target - a
        dist = min(max(d.length, abs(l1 - l2) + 0.01), l1 + l2 - 0.003)
        dr = d.normalized() if d.length > 1e-5 else Vector((0, -1, 0))
        ca = min(1.0, max(-1.0, (l1 * l1 + dist * dist - l2 * l2) / (2 * l1 * dist)))
        pp = pole - dr * pole.dot(dr)
        if pp.length < 1e-4:
            pp = dr.cross(Vector((1, 0, 0)))
        pp.normalize()
        mid = a + dr * (l1 * ca) + pp * (l1 * math.sqrt(max(0.0, 1 - ca * ca)))
        self.aim(upper, rl, a, mid, pp, hint_rest)
        self.aim(lower, re, mid, a + dr * dist, pp, hint_rest)


# ============================================================ части тела
def sd(s):
    return -1.0 if s == "L" else 1.0


def body(p, pos=(0, 0, 0), rot=(0, 0, 0), spine=(0, 0, 0), chest=(0, 0, 0), neck=(0, 0, 0), head=(0, 0, 0)):
    r = p.R.rest["Hips"]
    p.put("Hips", xf(eul(*rot) @ r.to_3x3(), r.translation + Vector(pos)))
    for b, e in (("Spine", spine), ("Chest", chest), ("Neck", neck), ("Skull", head)):
        if any(e):
            p.turn(b, e)


def bend(p, lean=0.0, twist=0.0, roll=0.0, drop=0.0, shift=(0, 0, 0), look=0.0, turn_head=0.0):
    """Наклон и поворот тела, разложенные по бёдрам, пояснице и груди; голова частью возвращается — глаза смотрят
    на дело. lean < 0 — вперёд, twist > 0 — влево, drop — присесть."""
    body(p, pos=(shift[0], shift[1] - drop, shift[2] - lean * 0.08), rot=(lean * 0.45, twist * 0.35, roll * 0.4),
         spine=(lean * 0.3, twist * 0.3, roll * 0.3), chest=(lean * 0.25, twist * 0.35, roll * 0.3),
         neck=(-lean * 0.2 + look * 0.4, turn_head * 0.4 - twist * 0.2, 0), head=(-lean * 0.25 + look * 0.6, turn_head * 0.6 - twist * 0.2, 0))


def arm(p, s, hand, pole=None, tip=PALM):
    p.ik("UpperArm" + s, "Forearm" + s, "Hand" + s, Vector(hand), Vector(pole) if pole else Vector((0.5 * sd(s), -0.4, 0.8)),
         ELBOW_BACK, tip)


def swing(p, s, fwd, out=0.12, reach=0.37, pole=None):
    """Рука маятником от плеча: fwd > 0 — вперёд (PI — вверх), out > 0 — в сторону от тела; reach < 0.42 — локоть согнут."""
    c = p.carried("Chest")
    v = eul(fwd, 0, sd(s) * out) @ Vector((0.03 * sd(s), -reach, -0.03))
    arm(p, s, p.g("UpperArm" + s).translation + c @ v, c @ Vector(pole if pole else (0.45 * sd(s), -0.25, 1.0)))


def leg(p, s, ankle, knee=None, pitch=0.0, yaw=0.0):
    """Нога: щиколотка — в точку ankle, колено — в сторону knee; pitch < 0 — носок вниз, yaw — носок в сторону."""
    k = Vector(knee) if knee else Vector((0.25 * sd(s), 0.1, -1.0))
    p.ik("Thigh" + s, "Shin" + s, "Foot" + s, Vector(ankle), k, KNEE_FWD)
    p.put("Foot" + s, xf(eul(pitch, yaw, 0) @ p.R.rest["Foot" + s].to_3x3(), p.g("Foot" + s).translation.copy()))


def stand(p, wide=0.12, fwd=0.0):
    """Обе ступни на земле: левая чуть впереди на fwd."""
    leg(p, "L", (-wide, 0.07, -fwd))
    leg(p, "R", (wide, 0.07, fwd))


def relax_arm(p, s, sway=0.0):
    swing(p, s, 0.08 + sway, 0.1, 0.385)


# ---------------------------------------------------------------- инструмент в руке
CARRY_ANGLE = PI * 0.64      # куда смотрит головка, когда инструмент несут: 0 — вниз, PI/2 — вперёд, PI — вверх
CARRY_ROLL = 0.2
CARRY_FWD = 0.5              # рука чуть впереди бедра
CARRY_OUT = 0.18
GRIP_REACH = 0.375           # от плеча до хвата (рука чуть согнута)


def hold(p, grip, pitch, yaw=0.0, roll=0.0, dspin=0.0, pole=None):
    """Правая рука держит инструмент: хват — в точке grip; головка смотрит по (pitch, yaw) в осях модели, как раньше
    задавала игра. dspin — поворот инструмента вокруг своей оси относительно того, как его несут."""
    tb = eul(pitch, yaw, roll) @ Matrix.Rotation(dspin, 3, "Y")
    grip = Vector(grip)
    head_dir = tb @ Vector((0, -1, 0))                    # куда смотрит головка
    sh = p.g("UpperArmR").translation
    # запястье — чуть ближе к плечу, чем хват: кисть обхватывает рукоять
    to = grip - sh
    wrist = grip - to.normalized() * PALM if to.length > 1e-4 else grip
    p.ik("UpperArmR", "ForearmR", "HandR", wrist, Vector(pole) if pole else Vector((0.7, -0.5, 0.5)), ELBOW_BACK)
    wrist = p.g("HandR").translation.copy()               # куда рука дотянулась на самом деле
    fore = (wrist - p.g("ForearmR").translation).normalized()
    # кисть — продолжение предплечья, ладонью к рукояти; инструмент — точно в ладони
    r = p.R.rest["HandR"]
    p.put("HandR", xf(frame(fore, head_dir) @ frame(p.R.o("ToolR") - r.translation, Vector((0, 0, -1))).inverted() @ r.to_3x3(), wrist))
    p.put("ToolR", xf(tb, wrist + fore * PALM))


def grip_at(p, fwd, out, lean=0.0, twist=0.0, reach=GRIP_REACH):
    """Где хват, если руку отвести на fwd вперёд (PI — вверх) и на out в сторону; корпус наклонён и повёрнут."""
    v = eul(fwd, 0, out) @ Vector((0.05, -reach, -0.04))
    return p.g("UpperArmR").translation + eul(lean, twist, 0) @ v


def carry(p, pitch=CARRY_ANGLE, roll=CARRY_ROLL, sway=0.0):
    hold(p, grip_at(p, CARRY_FWD + sway, CARRY_OUT), pitch, 0.0, roll)


# ============================================================ клипы
def c_idle(p, t):
    br = math.sin(4 * PI * t)                      # два вдоха за клип
    sway = math.sin(2 * PI * t)
    body(p, pos=(0.006 * sway, -0.004 + 0.003 * br, 0), rot=(0, 0, 0.008 * sway), spine=(0.012 * br, 0, 0), chest=(0.018 * br, 0, 0),
         head=(-0.02 * br + 0.01, 0.07 * math.sin(2 * PI * t + 0.6), 0))
    stand(p)
    relax_arm(p, "L", 0.02 * br)
    relax_arm(p, "R", 0.02 * br)


def _foot(u, duty, half, lift):
    """Шаг: [вперёд-назад (z), высота, наклон стопы]. u = 0 — пятка встала впереди."""
    if u < duty:
        s = u / duty
        z = -half + 2 * half * s
        push = sm(0.62, 1.0, s)
        return z, 0.035 * push, 0.28 * (1 - sm(0.0, 0.18, s)) - 0.75 * push
    s = (u - duty) / (1 - duty)
    e = s * s * (3 - 2 * s)
    return half - 2 * half * e, lift * math.sin(PI * s) + 0.035 * (1 - s), -0.75 * (1 - sm(0.0, 0.45, s)) + 0.28 * sm(0.6, 1.0, s)


def _gait(p, t, duty, half, lift, drop, bob, lean, twist, arm_amp, reach, arm_bias, wide=0.11, bob_at=0.0):
    c = math.cos(2 * PI * t)       # 1 — левая нога впереди
    s = math.sin(2 * PI * t)
    y = -drop - bob * math.cos(4 * PI * (t - bob_at))
    body(p, pos=(-0.014 * s, y, 0), rot=(lean * 0.45, -twist * c, -0.035 * s),
         spine=(lean * 0.3, twist * 0.6 * c, 0.02 * s), chest=(lean * 0.25, twist * 1.1 * c, 0.03 * s),
         neck=(-lean * 0.3, -twist * 0.4 * c, 0), head=(-lean * 0.3 + 0.02 * math.cos(4 * PI * t), -twist * 0.3 * c, 0))
    for sname, off in (("L", 0.0), ("R", 0.5)):
        z, h, pitch = _foot((t + off) % 1.0, duty, half, lift)
        leg(p, sname, (sd(sname) * wide, 0.07 + h, z), pitch=pitch)
    # руки — крест-накрест с ногами
    swing(p, "L", arm_bias - arm_amp * c, 0.1, reach)
    swing(p, "R", arm_bias + arm_amp * c, 0.1, reach)


def c_walk(p, t):
    _gait(p, t, duty=0.6, half=0.15, lift=0.07, drop=0.03, bob=0.012, lean=-0.06, twist=0.1, arm_amp=0.55, reach=0.37, arm_bias=0.1)


def c_run(p, t):
    _gait(p, t, duty=0.36, half=0.2, lift=0.15, drop=0.05, bob=0.03, lean=-0.36, twist=0.17, arm_amp=0.95, reach=0.29,
          arm_bias=0.45, bob_at=0.09)


def c_air(p, t):
    """Прыжок: t = 0 — взлёт (ноги поджаты), t = 1 — падение (ноги тянутся к земле, руки вверх)."""
    f = sm(0.0, 1.0, t)
    bend(p, lean=-0.14 + 0.2 * f, look=-0.1 * f)
    leg(p, "L", (-0.12, 0.2 - 0.1 * f, -0.12 + 0.04 * f), pitch=-0.5 + 0.2 * f)
    leg(p, "R", (0.12, 0.26 - 0.15 * f, 0.1 - 0.12 * f), pitch=-0.6 + 0.3 * f)
    swing(p, "L", 1.1 + 0.9 * f, 0.75 - 0.2 * f, 0.34)
    swing(p, "R", 0.6 + 1.3 * f, 0.7 - 0.15 * f, 0.34)


def c_land(p, t):
    """Приземление: присел, спружинил, выпрямился."""
    k = keys(t, [(0.0, 0.55), (0.22, 1.0), (1.0, 0.0)])
    bend(p, lean=-0.3 * k, drop=0.13 * k)
    stand(p, 0.14)
    swing(p, "L", 0.5 * k + 0.08, 0.1 + 0.5 * k, 0.36)
    swing(p, "R", 0.5 * k + 0.08, 0.1 + 0.5 * k, 0.36)


def c_swim(p, t):
    """Плывёт: тело легло на воду, руки — брассом, ноги — толчком."""
    a = 2 * PI * t
    glide = math.sin(a)
    body(p, pos=(0, 0.05 + 0.02 * glide, 0), rot=(-1.05, 0, 0.03 * math.sin(a)), spine=(0.12, 0, 0), chest=(0.16, 0, 0),
         neck=(0.3, 0, 0), head=(0.42, 0, 0))
    for s in ("L", "R"):
        x = sd(s)
        hand = vkeys(t, [(0.0, (0.07 * x, 0.76, -0.78)), (0.3, (0.44 * x, 0.66, -0.56)), (0.55, (0.2 * x, 0.52, -0.3)),
                         (0.75, (0.1 * x, 0.6, -0.5)), (1.0, (0.07 * x, 0.76, -0.78))])
        arm(p, s, hand, (0.8 * x, -0.5, 0.3))
        kick = keys(t, [(0.0, 1.0), (0.45, 0.0), (0.7, 0.15), (1.0, 1.0)])      # 1 — ноги вытянуты
        leg(p, s, (x * (0.2 - 0.1 * kick), 0.34 + 0.05 * kick, 0.17 + 0.2 * kick), (0.9 * x, -0.2, -0.4), pitch=-1.9)


def c_float(p, t):
    """Держится на воде на месте: руки разводят воду, ноги перебирают."""
    a = 2 * PI * t
    bend(p, lean=-0.1 + 0.02 * math.sin(a), shift=(0, 0.015 * math.sin(a), 0))
    for s, ph in (("L", 0.0), ("R", PI)):
        x = sd(s)
        arm(p, s, (x * (0.36 + 0.07 * math.cos(a)), 0.86 + 0.02 * math.sin(a), -0.2 + 0.07 * math.sin(a)), (0.6 * x, -0.7, 0.4))
        leg(p, s, (x * 0.13, 0.13 + 0.05 * math.sin(a + ph), 0.06 * math.cos(a + ph)), pitch=-0.5)


def c_sleep(p, t):
    """Спит: лежит на спине, руки вдоль тела, грудь медленно дышит."""
    br = math.sin(2 * PI * t)
    body(p, pos=(0, -0.17, 0), rot=(1.5, 0, 0), spine=(-0.08, 0, 0), chest=(-0.12 + 0.03 * br, 0, 0), head=(-0.12, 0.25, 0))
    leg(p, "L", (-0.14, 0.11, -0.36), (-0.5, 1.0, -0.2), pitch=1.1, yaw=-0.4)
    leg(p, "R", (0.13, 0.1, -0.37), (0.4, 1.0, -0.2), pitch=1.1, yaw=0.4)
    arm(p, "L", (-0.4, 0.2, 0.3), (-0.6, 0.3, 0.6))
    arm(p, "R", (0.1, 0.56 + 0.012 * br, 0.24), (0.8, 0.5, 0.2))


def c_hands(p, t):
    """Собрать руками: наклониться, взять двумя руками и потянуть на себя."""
    lean = keys(t, [(0.0, 0.0), (0.35, -0.55), (0.6, -0.2), (1.0, 0.0)])
    drop = keys(t, [(0.0, 0.0), (0.35, 0.1), (0.7, 0.0), (1.0, 0.0)])
    bend(p, lean=lean, drop=drop)
    stand(p, 0.13, 0.04)
    swing(p, "R", keys(t, [(0.0, 0.08), (0.35, 1.15), (0.6, 0.6), (1.0, 0.08)]), 0.1, keys(t, [(0.0, 0.385), (0.35, 0.41), (0.6, 0.3), (1.0, 0.385)]))
    swing(p, "L", keys(t, [(0.0, 0.08), (0.38, 1.05), (0.62, 0.55), (1.0, 0.08)]), 0.1, keys(t, [(0.0, 0.385), (0.38, 0.41), (0.62, 0.3), (1.0, 0.385)]))


def c_weed(p, t):
    """Рвёт траву: присел, ухватил пучок у самой земли, выдернул."""
    k = keys(t, [(0.0, 0.0), (0.3, 1.0), (0.48, 1.0), (0.66, 0.35), (1.0, 0.0)])
    yank = keys(t, [(0.0, 0.0), (0.48, 0.0), (0.64, 1.0), (1.0, 0.0)])
    bend(p, lean=-0.75 * k + 0.25 * yank, drop=0.17 * k, twist=0.12 * yank)
    stand(p, 0.15, 0.03)
    for s in ("L", "R"):
        x = sd(s)
        rest_hand = p.g("UpperArm" + s).translation + Vector((0.04 * x, -0.385, -0.06))
        low = Vector((0.09 * x, 0.2, -0.36))
        up = Vector((0.13 * x, 0.62, -0.24))
        h = rest_hand.lerp(low, min(1.0, k * 1.2)).lerp(up, yank)
        arm(p, s, h, (0.8 * x, -0.3, 0.5))


def _stance(p, t, lean, twist, drop, look=0.0):
    bend(p, lean=lean, twist=twist, drop=drop + 0.02 * abs(lean), look=look)
    stand(p, 0.14, 0.05)


def strike(K):
    """Удар инструментом по ключам K: fwd / out — куда отведена правая рука, pitch / yaw / dspin — как смотрит инструмент,
    lean / twist / drop — корпус, two — вторая рука тянется к рукояти (0..1), pull — хват сведён к середине тела,
    left — свободная левая рука (вперёд)."""
    c = K.get("c", CARRY_ANGLE)

    def f(p, t):
        lean = keys(t, K.get("lean", [(0, 0)]))
        twist = keys(t, K.get("twist", [(0, 0)]))
        _stance(p, t, lean, twist, keys(t, K.get("drop", [(0, 0)])))
        blend = min(sm(0.0, 0.1, t), 1 - sm(0.9, 1.0, t))              # в начале и в конце — как несут
        pitch = keys(t, K["pitch"])
        yaw = keys(t, K.get("yaw", [(0, 0)]))
        roll = K.get("roll", CARRY_ROLL) * (1 - blend)
        grip = grip_at(p, keys(t, K["fwd"]), keys(t, K.get("out", [(0, CARRY_OUT)])), lean, twist,
                       keys(t, K.get("reach", [(0, GRIP_REACH)])))
        two = keys(t, K["two"]) if "two" in K else 0.0
        pull = keys(t, K["pull"]) if "pull" in K else 0.0
        if pull > 0:
            # двумя руками: хват — ближе к середине тела, чтобы вторая рука дотянулась до рукояти, но не ближе
            # clear метров к оси тела — иначе инструмент войдёт в живот
            x = grip.x + (0.15 - grip.x) * pull
            hz = p.g("Hips").translation.z
            z = grip.z
            cl = K.get("clear", 0.4)
            if math.hypot(x, z - hz) < cl:
                z = hz - math.sqrt(cl * cl - x * x)
            grip.x = x
            grip.z += (z - grip.z) * pull
        hold(p, grip, pitch, yaw, roll, keys(t, K["dspin"]) if "dspin" in K else 0.0)
        free = p.g("UpperArmL").translation + p.carried("Chest") @ (eul(keys(t, K.get("left", [(0, 0.08)])), 0, -0.14) @ Vector((-0.03, -0.37, -0.03)))
        if two > 0:
            tb = p.g("ToolR").to_3x3()
            on_handle = p.g("ToolR").translation + tb @ Vector((0, -K.get("apart", 0.15), 0))
            free = free.lerp(on_handle, two)
        arm(p, "L", free, (-0.7, -0.5, 0.5))
    return f


TWO = [(0.0, 0.0), (0.14, 1.0), (0.82, 1.0), (1.0, 0.0)]
PULL_HIT = [(0.0, 0.0), (0.38, 0.0), (0.52, 0.6), (0.8, 0.6), (1.0, 0.0)]   # замах — сбоку от головы, удар — перед собой
PULL_ALL = [(0.0, 0.0), (0.2, 0.9), (0.8, 0.9), (1.0, 0.0)]
c = CARRY_ANGLE
STRIKES = {
    # рубка: замах из-за правого плеча, удар сверху вниз двумя руками, корпус подаётся вперёд
    "axe": {"fwd": [(0, CARRY_FWD), (0.32, 2.95), (0.5, 1.0), (0.7, 0.85), (1, CARRY_FWD)],
            "out": [(0, CARRY_OUT), (0.32, 0.4), (0.5, 0.0), (1, CARRY_OUT)],
            "pitch": [(0, c), (0.32, PI * 1.28), (0.5, PI * 0.42), (0.7, PI * 0.36), (1, c)],
            "yaw": [(0, 0), (0.32, -0.35), (0.5, 0.05), (1, 0)],
            "lean": [(0, 0), (0.32, 0.16), (0.5, -0.36), (0.7, -0.26), (1, 0)],
            "twist": [(0, 0), (0.32, -0.3), (0.5, 0.12), (1, 0)], "drop": [(0, 0), (0.5, 0.07), (1, 0)], "two": TWO,
            "pull": PULL_HIT},
    # кирка тяжелее: долгий прямой замах над головой, удар отвесно вниз, глубокий наклон
    "pick": {"fwd": [(0, CARRY_FWD), (0.38, 3.05), (0.52, 0.85), (0.75, 0.7), (1, CARRY_FWD)],
             "pitch": [(0, c), (0.38, PI * 1.35), (0.52, PI * 0.36), (0.75, PI * 0.3), (1, c)],
             "lean": [(0, 0), (0.38, 0.22), (0.52, -0.46), (0.75, -0.36), (1, 0)],
             "drop": [(0, 0), (0.52, 0.11), (1, 0)], "two": TWO, "pull": PULL_HIT},
    # мачете: рука отводится вправо на уровне груди, клинок рубит поперёк справа налево
    "machete": {"fwd": [(0, CARRY_FWD), (0.3, 1.45), (0.5, 1.5), (0.75, 1.3), (1, CARRY_FWD)],
                "out": [(0, CARRY_OUT), (0.3, 1.2), (0.5, -0.05), (0.65, 0.08), (0.75, 0.12), (1, CARRY_OUT)],
                "pitch": [(0, c), (0.3, PI * 0.55), (0.5, PI * 0.5), (0.75, PI * 0.5), (1, c)],
                "yaw": [(0, 0), (0.3, -1.35), (0.5, 0.45), (0.75, 0.3), (1, 0)],
                "dspin": [(0, 0), (0.3, -PI / 2), (0.55, -PI / 2), (0.8, 0), (1, 0)],
                "twist": [(0, 0), (0.3, -0.5), (0.5, 0.4), (0.75, 0.28), (1, 0)], "lean": [(0, 0), (0.5, -0.14), (1, 0)],
                "left": [(0, 0.08), (0.3, 0.7), (0.5, -0.3), (1, 0.08)]},
    # лопата: вонзить вниз, нажать, поддеть и откинуть землю
    "shovel": {"fwd": [(0, CARRY_FWD), (0.25, 1.1), (0.45, 0.5), (0.7, 1.25), (1, CARRY_FWD)],
               "pitch": [(0, c), (0.25, PI * 0.3), (0.45, PI * 0.12), (0.7, PI * 0.55), (1, c)],
               "lean": [(0, 0), (0.25, -0.2), (0.45, -0.46), (0.7, -0.06), (1, 0)],
               "drop": [(0, 0), (0.45, 0.13), (0.7, 0.03), (1, 0)], "two": TWO, "pull": PULL_ALL, "apart": 0.22, "clear": 0.46},
    # лейка: поднять перед собой, наклонить носиком вниз, подержать, вернуть
    "can": {"c": 0.0, "roll": 0.0, "fwd": [(0, CARRY_FWD), (0.25, 1.25), (0.85, 1.2), (1, CARRY_FWD)],
            "out": [(0, CARRY_OUT), (0.25, -0.1), (1, CARRY_OUT)],
            "pitch": [(0, 0), (0.25, 0), (0.42, -0.85), (0.8, -0.85), (0.95, 0), (1, 0)],
            "lean": [(0, 0), (0.4, -0.16), (1, 0)], "left": [(0, 0.08), (0.3, -0.25), (1, 0.08)]},
    # сачок: широкий взмах дугой справа сверху вниз — «накрыть»
    "net": {"fwd": [(0, CARRY_FWD), (0.3, 2.7), (0.55, 1.25), (0.8, 1.05), (1, CARRY_FWD)],
            "out": [(0, CARRY_OUT), (0.3, 0.9), (0.55, 0.0), (1, CARRY_OUT)],
            "pitch": [(0, c), (0.3, PI * 1.12), (0.55, PI * 0.42), (0.8, PI * 0.36), (1, c)],
            "yaw": [(0, 0), (0.3, -0.6), (0.55, 0.2), (1, 0)],
            "twist": [(0, 0), (0.3, -0.35), (0.55, 0.35), (1, 0)], "lean": [(0, 0), (0.55, -0.24), (1, 0)],
            "left": [(0, 0.08), (0.3, 0.9), (0.55, -0.2), (1, 0.08)]},
    # удочка: удилище назад за плечо и резко вперёд
    "rod": {"fwd": [(0, CARRY_FWD), (0.35, 2.9), (0.5, 1.2), (0.7, 1.0), (1, CARRY_FWD)],
            "pitch": [(0, c), (0.35, PI * 1.22), (0.5, PI * 0.62), (0.75, PI * 0.58), (1, c)],
            "lean": [(0, 0), (0.35, 0.18), (0.5, -0.18), (1, 0)], "left": [(0, 0.08), (0.35, 0.8), (0.5, -0.2), (1, 0.08)]},
}


def c_drill(p, t):
    """Бур: стоит отвесно перед героем, обе руки — на концах Т-ручки и крутят её туда-сюда, корпус налегает сверху.
    (Ручка шириной 40 см: если крутить её полными оборотами, она проходит сквозь живот.)"""
    e = min(sm(0.0, 0.2, t), 1 - sm(0.8, 1.0, t))            # 0 — несёт, 1 — бурит
    crank = math.sin(6 * PI * t) * e
    bend(p, lean=-0.34 * e - 0.03 * abs(crank), drop=0.09 * e + 0.015 * abs(crank), twist=0.06 * crank)
    stand(p, 0.15, 0.03)
    at_carry = grip_at(p, CARRY_FWD, CARRY_OUT)
    hz = p.g("Hips").translation.z
    at = at_carry.lerp(Vector((0.0, 0.62, hz - 0.45)), e)
    at.z -= 0.12 * math.sin(PI * e)                           # переносит бур к середине по дуге — подальше от живота
    # когда бур несут, ручка смотрит вдоль шага; в работе — поперёк, и качается туда-сюда
    tb = eul(CARRY_ANGLE * (1 - e), 0, CARRY_ROLL * (1 - e)) @ Matrix.Rotation(PI / 2 * e + 0.55 * crank, 3, "Y")
    bar = tb @ Vector((0, 0, -1))                             # вдоль ручки (в игре бур ещё повёрнут на четверть оборота)
    if bar.x < 0:
        bar = -bar
    mid = at + tb @ Vector((0, 0.12, 0))                      # середина ручки
    p.ik("UpperArmR", "ForearmR", "HandR", at.lerp(mid + bar * 0.15, e), Vector((0.7, -0.5, 0.5)), ELBOW_BACK, PALM)
    p.put("ToolR", xf(tb, at))
    free = p.g("UpperArmL").translation + Vector((-0.04, -0.385, -0.06))
    arm(p, "L", free.lerp(mid - bar * 0.15, e), (-0.7, -0.5, 0.5))


def c_carry(p, t):
    c_idle(p, 0.0)
    carry(p)


def c_carry_can(p, t):
    c_idle(p, 0.0)
    carry(p, 0.0, 0.0)


# имя клипа → (функция позы, сколько кадров)
CLIPS = {
    "idle": (c_idle, 60), "walk": (c_walk, 32), "run": (c_run, 32), "air": (c_air, 10), "land": (c_land, 20),
    "swim": (c_swim, 32), "float": (c_float, 32), "sleep": (c_sleep, 30), "hands": (c_hands, 40), "weed": (c_weed, 40),
    "carry": (c_carry, 1), "carry_can": (c_carry_can, 1),
}
for _n, _k in STRIKES.items():
    CLIPS["hit_" + _n] = (strike(_k), 40)
CLIPS["hit_drill"] = (c_drill, 60)


# ============================================================ запись в Blender
def bake(arm, R, name, fn, frames):
    act = bpy.data.actions.new(name)
    ad = arm.animation_data_create()
    ad.action = act
    prev = {}
    for f in range(frames + 1):
        p = Pose(R)
        fn(p, f / frames)
        for b in R.order:
            par = R.parent[b]
            loc = R.rest_local[b].inverted() @ ((p.g(par).inverted() @ p.g(b)) if par else p.g(b))
            q = loc.to_quaternion()
            if b in prev and prev[b].dot(q) < 0:
                q.negate()
            prev[b] = q
            pb = arm.pose.bones[b]
            pb.rotation_mode = "QUATERNION"
            pb.rotation_quaternion = q
            pb.keyframe_insert("rotation_quaternion", frame=f)
            if b in ("Hips", "ToolR"):
                pb.location = loc.translation
                pb.keyframe_insert("location", frame=f)
    tr = ad.nla_tracks.new()
    tr.name = name
    tr.strips.new(name, 0, act)
    ad.action = None
    for pb in arm.pose.bones:
        pb.rotation_quaternion = (1, 0, 0, 0)
        pb.location = (0, 0, 0)


def hero_anims():
    """Скелет героя и все клипы. Сетка — один крошечный треугольник: без сетки с весами скелет в .glb не попадает."""
    bm = bmesh.new()
    for co in ((0, 0, 0.45), (0.001, 0, 0.45), (0, 0.001, 0.45)):
        bm.verts.new(co)
    bm.faces.new(bm.verts)
    dummy = kit.from_bm("AnimDummy", bm)
    kit.paint(dummy, (1, 1, 1), ao=0.0, noise_amt=0)
    arm = rig.armature()
    rig.skin(dummy, arm, lambda co: {"Hips": 1.0})
    bpy.context.scene.render.fps = FPS
    R = Rest(arm)
    for name, (fn, frames) in CLIPS.items():
        bake(arm, R, name, fn, frames)


BUILDERS = {"hero_anims": hero_anims}
