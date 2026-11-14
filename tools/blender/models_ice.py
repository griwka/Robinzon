"""Глава 5 — Ледяной остров: штурман Ингрид, пингвин, морж Борис и кормушка пингвинов; ледник (обрыв,
зарубки для подъёма, замёрзший водопад, ледяной уступ), обсерватория с телескопом и звёздным кругом,
секстант, поленница; ледяные ларцы и жаровня; Холодное сердце (во льду и оттаявшее); припай, лунка, льдины;
растения тундры (мох, брусника, сосна), ледяная глыба и ледяная стена; печка и теплица; морошка на грядке;
тёплая одежда на герое (свитер, куртка, валенки, рукавицы); ледоруб и ледовый бур в руке.

Координаты: Blender (x, y, z) → Godot (x, z, −y). «Вперёд» в Godot (+Z) — это −Y в Blender."""
import math

import bmesh
from mathutils import Vector, noise

from kit import (box, cyl, displace, empty, from_bm, hexcol, ico, join, lathe, leaf, mix, paint, remesh, rnd,
                 set_origin, set_parent, shade, sphere, subsurf, tube)
from models_buildings import log, plank, stone

ICE = hexcol("9fd6ee")
ICE_D = hexcol("5fa8d2")
ICE_L = hexcol("dff3fb")
SNOW = hexcol("f7fbff")
SNOW_SH = hexcol("d3e3f4")
PINE = hexcol("3f6e4c")
BARK = hexcol("6b4a32")
BRASS = hexcol("d9a84a")
COPPER = hexcol("d9884a")
IRON = hexcol("4a4c52")
SKIN = hexcol("e8b896")
TULUP = hexcol("b88550")
FUR = hexcol("f2e8d2")
BRICK = hexcol("b8583a")
STONE_PALE = hexcol("c9d2dc")


def _ice_fn(base=ICE, snow_z=None, snow_n=0.55):
    """Узор льда: светлые грани, синие трещины-полосы, снег сверху (на гранях, смотрящих вверх, выше snow_z)."""
    def f(co, n):
        if snow_z is not None and co.z > snow_z and n.z > snow_n:
            return SNOW if math.sin(co.x * 9 + co.y * 7) < 0.8 else SNOW_SH
        if math.sin(co.z * 5.0 + math.sin(co.x * 1.7) * 1.5) > 0.86:
            return ICE_D
        if math.sin(co.x * 13 + co.z * 3 - co.y * 7) > 0.9:
            return ICE_L
        if n.z > 0.5:
            return shade(base, 1.12)
        return None
    return f


def _block(name, w, d, h, cuts=8, z0=0.0):
    """Брусок w×d×h (низ — на z0) с частой сеткой: его удобно гнуть и покрывать рельефом."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=cuts, use_grid_fill=True)
    for v in bm.verts:
        v.co.x *= w
        v.co.y *= d
        v.co.z = (v.co.z + 0.5) * h + z0
    return from_bm(name, bm, smooth=False)


def _icicles(parts, x0, x1, y, z, n, seed, ln=(0.3, 0.9), r=0.07):
    rr = rnd(seed)
    for k in range(n):
        x = x0 + (x1 - x0) * (k + rr.uniform(0.1, 0.9)) / n
        L = rr.uniform(*ln)
        ic = cyl("ic", (x, y, z - L), 0.0, r * rr.uniform(0.7, 1.2), L, segs=6)
        ic.rotation_euler = (0, 0, 0)
        paint(ic, ICE_L, ao=0.0, noise_amt=0, fn=lambda co, nn: ICE if co.z < z - L * 0.5 else None)
        parts.append(ic)


# ================================================================== штурман Ингрид
def ingrid():
    """Штурман Ингрид: около пятидесяти, высокая и прямая, в мужском тулупе с белым мехом, шерстяной шарф,
    седые волосы в тугом пучке, очки в железной оправе. Узлы Body и Head."""
    body = lathe("ib", [(0.0, 0.0), (0.33, 0.02), (0.34, 0.3), (0.31, 0.7), (0.29, 0.95), (0.2, 1.06), (0.0, 1.08)], 22)
    subsurf(body, 1)
    paint(body, TULUP, ao=0.0, noise_amt=0.08, nscale=6,
          fn=lambda co, n: (FUR if (co.z < 0.1 or (abs(co.x) < 0.05 and co.y > 0.2)) else
                            (shade(TULUP, 0.82) if math.sin(co.z * 22) > 0.85 else None)))
    parts = [body]
    # пояс и пуговицы
    belt = tube("bl", [(math.cos(a) * 0.32, math.sin(a) * 0.32, 0.55) for a in [i * math.pi / 12 for i in range(25)]], 0.03, 6, caps=False)
    paint(belt, hexcol("4a3020"), ao=0.0)
    parts.append(belt)
    for k in range(4):
        bt = sphere("bt", (0.07, 0.3, 0.62 + k * 0.1), 0.025, segs=8, rings=5)
        paint(bt, hexcol("3a2a1a"), ao=0.0, noise_amt=0)
        parts.append(bt)
    # шарф
    scarf = tube("sc", [(math.cos(a) * 0.19, math.sin(a) * 0.19, 1.04) for a in [i * math.pi / 10 for i in range(21)]], 0.065, 8, caps=False)
    paint(scarf, hexcol("3a5a7a"), ao=0.0, fn=lambda co, n: hexcol("e8e0d0") if int(math.atan2(co.y, co.x) * 4) % 2 else None)
    tail = tube("st", [(0.12, 0.17, 1.02), (0.16, 0.24, 0.85), (0.15, 0.25, 0.7)], [0.055, 0.05, 0.05], 8)
    paint(tail, hexcol("3a5a7a"), ao=0.0, fn=lambda co, n: hexcol("e8e0d0") if co.z < 0.75 else None)
    parts += [scarf, tail]
    for sx in (-1, 1):
        a = tube("ia", [(sx * 0.3, 0, 0.98), (sx * 0.38, 0.06, 0.74), (sx * 0.34, 0.14, 0.55)], [0.1, 0.09, 0.09], 10)
        paint(a, TULUP, ao=0.0)
        cuff = tube("cf", [(sx * 0.345, 0.135, 0.58), (sx * 0.34, 0.15, 0.52)], 0.1, 10)
        paint(cuff, FUR, ao=0.0, noise_amt=0.15, nscale=20)
        mit = sphere("mt", (sx * 0.34, 0.17, 0.47), 0.075, (0.9, 1.0, 1.15))
        paint(mit, hexcol("5a6a7a"), ao=0.0)
        boot = lathe("ibt", [(0.0, 0.0), (0.12, 0.0), (0.12, 0.2), (0.0, 0.21)], 10, loc=(sx * 0.13, 0.04, 0), scale=(1, 1.4, 1))
        paint(boot, hexcol("3a2a1a"), ao=0.0)
        parts += [a, cuff, mit, boot]
    b = join(parts, "Body")
    set_origin(b, (0, 0, 0))
    # голова: седой пучок, очки, строгие брови, тонкая полуулыбка
    hp = [sphere("hd", (0, 0, 1.37), 0.27, segs=26, rings=14)]
    paint(hp[0], SKIN, ao=0.0, fn=lambda co, n: shade(SKIN, 0.95) if co.z < 1.27 else None)
    hair = sphere("hr", (0, -0.03, 1.44), 0.28, (1.0, 1.02, 0.72))
    paint(hair, hexcol("d8d4cc"), ao=0.0, noise_amt=0.12, nscale=25, fn=lambda co, n: 0.88 if math.sin(math.atan2(co.y, co.x) * 14) > 0.5 else None, mat="hair")
    bun = sphere("bn", (0, -0.2, 1.55), 0.12, (1.0, 0.9, 0.9))
    paint(bun, hexcol("cfcac0"), ao=0.0, fn=lambda co, n: 0.85 if math.sin(co.x * 40 + co.z * 30) > 0.6 else None, mat="hair")
    hp += [hair, bun]
    for sx in (-1, 1):
        w = sphere("w", (sx * 0.1, 0.23, 1.39), 0.045, (1, 0.42, 0.9))
        paint(w, hexcol("ffffff"), ao=0.0, noise_amt=0)
        i = sphere("i", (sx * 0.1, 0.25, 1.385), 0.026, (1, 0.4, 0.9))
        paint(i, hexcol("3a6a9a"), ao=0.0, noise_amt=0)
        rim = tube("gr", [(sx * 0.1 + math.cos(a) * 0.065, 0.265, 1.39 + math.sin(a) * 0.055) for a in [k * math.pi / 8 for k in range(17)]],
                   0.008, 5, caps=False)
        paint(rim, hexcol("5a5e66"), ao=0.0, noise_amt=0)
        br = tube("br", [(sx * 0.04, 0.25, 1.47), (sx * 0.16, 0.23, 1.465)], 0.014, 6)
        paint(br, hexcol("9a948a"), ao=0.0)
        ear = sphere("er", (sx * 0.26, 0.0, 1.36), 0.055, (0.5, 0.8, 1.0))
        paint(ear, SKIN, ao=0.0)
        hp += [w, i, rim, br, ear]
    bridge = tube("gb", [(-0.035, 0.27, 1.395), (0.035, 0.27, 1.395)], 0.008, 5)
    paint(bridge, hexcol("5a5e66"), ao=0.0)
    nose = sphere("ns", (0, 0.27, 1.34), 0.04, (0.8, 1.0, 1.0))
    paint(nose, shade(SKIN, 0.94), ao=0.0)
    mouth = tube("mo", [(-0.05, 0.245, 1.255), (0.0, 0.25, 1.258), (0.05, 0.247, 1.262)], 0.011, 6)
    paint(mouth, hexcol("8a3a32"), ao=0.0)
    hp += [bridge, nose, mouth]
    h = join(hp, "Head")
    set_origin(h, (0, 0, 1.1))
    set_parent(h, b)


# ================================================================== пингвин
def penguin():
    """Пингвин: круглое чёрное тело, белое брюшко, оранжевые клюв и лапки. Узлы Body и Head."""
    body = sphere("pb", (0, 0, 0.27), 0.2, (0.95, 0.85, 1.35), segs=22, rings=14)
    paint(body, hexcol("23262e"), ao=0.0, noise_amt=0.04, fn=lambda co, n: hexcol("f6f6f2") if n.y > 0.25 and co.z < 0.48 else None)
    parts = [body]
    for sx in (-1, 1):
        w = sphere("pw", (sx * 0.18, -0.02, 0.3), 0.12, (0.28, 0.65, 1.0), (0, sx * 0.25, 0))
        paint(w, hexcol("1d2028"), ao=0.0)
        f = sphere("pf", (sx * 0.07, 0.08, 0.02), 0.06, (0.9, 1.4, 0.3))
        paint(f, hexcol("ff9a2a"), ao=0.0)
        parts += [w, f]
    tail = cyl("pt", (0, -0.17, 0.06), 0.06, 0.0, 0.12, (-2.3, 0, 0), 6)
    paint(tail, hexcol("1d2028"), ao=0.0)
    parts.append(tail)
    b = join(parts, "Body")
    set_origin(b, (0, 0, 0))
    hd = sphere("ph", (0, 0.01, 0.58), 0.13, (1.0, 0.95, 1.0))
    paint(hd, hexcol("23262e"), ao=0.0, fn=lambda co, n: hexcol("f6f6f2") if (n.y > 0.55 and co.z < 0.56) else None)
    beak = cyl("pk", (0, 0.1, 0.56), 0.035, 0.0, 0.11, (-math.pi / 2, 0, 0), 8)
    paint(beak, hexcol("ff8a1a"), ao=0.0)
    hp = [hd, beak]
    for sx in (-1, 1):
        e = sphere("pe", (sx * 0.06, 0.1, 0.61), 0.024)
        paint(e, hexcol("ffffff"), ao=0.0, noise_amt=0)
        p = sphere("pp", (sx * 0.062, 0.118, 0.61), 0.013)
        paint(p, hexcol("101010"), ao=0.0, noise_amt=0)
        ch = sphere("pc", (sx * 0.09, 0.085, 0.55), 0.02, (1, 0.5, 0.7))
        paint(ch, hexcol("ffb0a0"), ao=0.0, noise_amt=0)
        hp += [e, p, ch]
    h = join(hp, "Head")
    set_origin(h, (0, 0, 0.48))
    set_parent(h, b)


def penguin_feeder():
    """Кормушка пингвинов: низкий деревянный жёлоб с рыбой, рядом ведро и табличка с рыбкой."""
    parts = []
    for sx in (-1, 1):
        parts.append(plank("sd", (0, sx * 0.28, 0.16), (1.4, 0.06, 0.3), col=hexcol("9a6a3e"), seed=sx))
    for sx in (-1, 1):
        parts.append(plank("en", (sx * 0.7, 0, 0.16), (0.06, 0.6, 0.3), col=hexcol("9a6a3e")))
    bottom = plank("bt", (0, 0, 0.04), (1.4, 0.6, 0.06), col=hexcol("8a5a32"))
    parts.append(bottom)
    for k in range(3):   # рыба в жёлобе
        f = sphere("fs", (-0.35 + k * 0.32, 0.02 * k, 0.2), 0.12, (1.0, 0.38, 0.32), (0, 0, 0.3 * k))
        paint(f, hexcol("8fb0c8"), ao=0.0, fn=lambda co, n: hexcol("e8f0f8") if co.z < 0.19 else None)
        parts.append(f)
    snow = sphere("sn", (0.3, 0.1, 0.32), 0.18, (1.6, 0.9, 0.25))
    paint(snow, SNOW, ao=0.0)
    parts.append(snow)
    bucket = lathe("bk", [(0.0, 0.0), (0.15, 0.0), (0.18, 0.32), (0.0, 0.3)], 12, loc=(0.95, 0.25, 0))
    paint(bucket, hexcol("8a9aa8"), ao=0.0, fn=lambda co, n: IRON if abs(co.z - 0.25) < 0.025 else None)
    post = tube("ps", [(-0.95, -0.2, 0.0), (-0.95, -0.2, 0.9)], 0.035, 6)
    paint(post, hexcol("6b4a32"), ao=0.0)
    sign = box("sg", (-0.95, -0.22, 0.85), (0.4, 0.04, 0.26), bev=0.015)
    paint(sign, hexcol("d6b07a"), ao=0.0,
          fn=lambda co, n: hexcol("3a5a7a") if (n.y < -0.5 and ((co.x + 0.95) ** 2 * 6 + (co.z - 0.85) ** 2 * 30 < 0.06)) else None)
    parts += [bucket, post, sign]
    join(parts, "Feeder")


# ================================================================== морж Борис
def walrus():
    """Морж: огромная бурая туша лежит вдоль оси X (голова — к +X), бивни, щётка усов. Узлы Body и Head."""
    hide = hexcol("a8785e")
    body = sphere("wb", (-0.2, 0, 0.5), 0.55, (2.4, 1.2, 0.95), segs=26, rings=16)
    displace(body, 0.04, 0.6)
    paint(body, hide, ao=0.25, ao_h=0.3, noise_amt=0.12, nscale=5,
          fn=lambda co, n: (hexcol("c8987e") if n.z > 0.6 else (0.93 if math.sin(co.x * 9 + co.z * 4) > 0.88 else None)))
    parts = [body]
    for sy in (-1, 1):
        fl = sphere("wf", (0.35, sy * 0.62, 0.12), 0.22, (1.3, 0.55, 0.25), (0, 0, sy * 0.4))
        paint(fl, shade(hide, 0.8), ao=0.0)
        parts.append(fl)
    tail = sphere("wt", (-1.55, 0, 0.18), 0.3, (1.2, 1.4, 0.3))
    paint(tail, shade(hide, 0.8), ao=0.0)
    parts.append(tail)
    b = join(parts, "Body")
    set_origin(b, (0, 0, 0))
    hd = sphere("wh", (1.05, 0, 0.62), 0.36, (1.1, 1.0, 0.85), segs=22, rings=12)
    paint(hd, hide, ao=0.0, noise_amt=0.1)
    muzzle = sphere("wm", (1.35, 0, 0.52), 0.22, (0.8, 1.35, 0.75))
    paint(muzzle, hexcol("d0a888"), ao=0.0, fn=lambda co, n: hexcol("9a7058") if math.sin(co.y * 60) > 0.86 and n.x > 0.4 else None)
    hp = [hd, muzzle]
    for sy in (-1, 1):
        tusk = tube("tk", [(1.42, sy * 0.1, 0.42), (1.48, sy * 0.12, 0.2), (1.44, sy * 0.13, 0.02)], [0.04, 0.032, 0.008], 8)
        paint(tusk, hexcol("f4ecd8"), ao=0.0)
        eye = sphere("we", (1.22, sy * 0.24, 0.76), 0.035, (1.0, 1.0, 0.45))   # глаза закрыты — спит
        paint(eye, hexcol("3a2a22"), ao=0.0, noise_amt=0)
        hp += [tusk, eye]
        for k in range(5):
            wh = tube("ws", [(1.45, sy * (0.05 + k * 0.035), 0.5), (1.6, sy * (0.12 + k * 0.06), 0.46 - k * 0.02)], 0.006, 4)
            paint(wh, hexcol("f2e8d0"), ao=0.0)
            hp.append(wh)
    h = join(hp, "Head")
    set_origin(h, (0.8, 0, 0.5))
    set_parent(h, b)


# ================================================================== ледник
def glacier_wall():
    """Кусок ледяного обрыва: 3,7 м по дуге радиусом 8,6 м, 8 м в высоту (низ — z=0), лицом наружу (−Y Blender).
    Голубые слои льда, трещины, снежный бортик наверху и сосульки под ним."""
    R = 8.6
    wall = _block("gw", 3.9, 1.2, 8.0, cuts=12)
    me = wall.data
    for v in me.vertices:
        x, y, z = v.co
        # гнём по дуге: центр круга — в +Y на расстоянии R
        r = R + 0.55 - (y + 0.6)        # наружная грань (y=−0.6) — на радиусе R+0.55
        phi = x / R
        v.co.x = r * math.sin(phi)
        v.co.y = R - r * math.cos(phi)
        # лицо обрыва неровное: чуть наклонено внутрь кверху
        if y < 0:
            v.co.y += z * 0.03
    displace(wall, 0.28, 0.9, "VORONOI")
    paint(wall, ICE, ao=0.3, ao_h=1.5, noise_amt=0.1, nscale=1.5, fn=_ice_fn(ICE, snow_z=7.4, snow_n=0.4))
    parts = [wall]
    # снежный бортик
    lip = tube("lp", [(math.sin(a / R) * (R - 0.1), R - math.cos(a / R) * (R - 0.1), 8.05) for a in [-2.0 + k * 0.4 for k in range(11)]],
               0.42, 10, caps=True)
    lip.scale = (1.0, 1.0, 0.65)
    displace(lip, 0.1, 0.3)
    paint(lip, SNOW, ao=0.0, noise_amt=0.06, fn=lambda co, n: SNOW_SH if n.z < -0.2 else None)
    parts.append(lip)
    _icicles(parts, -1.7, 1.7, -0.4, 7.85, 9, 11, (0.4, 1.3), 0.08)
    join(parts, "GlacierWall")


def ice_steps():
    """Зарубки для подъёма по ледяной стене на 1 м высоты: выбитые ступеньки и вбитые костыли с верёвкой."""
    parts = []
    for k in range(2):
        z = 0.2 + k * 0.5
        x = -0.18 if k % 2 == 0 else 0.18
        st = box("st", (x, -0.02, z), (0.34, 0.2, 0.06), bev=0.02)
        paint(st, ICE_L, ao=0.0, fn=lambda co, n: SNOW if n.z > 0.5 else None)
        hole = box("hl", (x, 0.04, z + 0.06), (0.3, 0.08, 0.1), bev=0.02)
        paint(hole, ICE_D, ao=0.0)
        parts += [st, hole]
    peg = tube("pg", [(0.3, 0.05, 0.55), (0.3, -0.14, 0.6)], 0.02, 6)
    paint(peg, IRON, ao=0.0)
    rope = tube("rp", [(0.3, -0.13, 0.0), (0.31, -0.15, 0.5), (0.3, -0.14, 1.0)], 0.018, 6)
    paint(rope, hexcol("c9a467"), ao=0.0, fn=lambda co, n: 0.85 if int(co.z * 30) % 2 else None)
    parts += [peg, rope]
    join(parts, "IceSteps")


def frozen_waterfall():
    """Замёрзший водопад: 8 м застывших струй и сосулек по обрыву, внизу — ледяная наледь. Лицом в −Y."""
    r = rnd(41)
    jets = []
    for k in range(9):
        x = -1.4 + k * 0.35 + r.uniform(-0.1, 0.1)
        pts = [(x * 0.6, 0.3, 8.0), (x * 0.8, -0.2, 6.5), (x, -0.45 - r.uniform(0, 0.2), 3.5), (x * 1.1, -0.6, 1.0), (x * 1.2, -0.8, 0.2)]
        jets.append(tube("jt", pts, [0.18, 0.22, 0.26, 0.3, 0.38], 8))
    pool = sphere("pl", (0, -1.0, 0.0), 1.2, (1.8, 1.0, 0.35))
    jets.append(pool)
    w = join(jets, "Waterfall")
    remesh(w, 0.14, 3)
    paint(w, ICE_L, ao=0.2, ao_h=0.8, noise_amt=0.1, nscale=2,
          fn=lambda co, n: (ICE_D if math.sin(co.x * 11) > 0.75 else (ICE if math.sin(co.x * 5 + co.z * 0.7) > 0.4 else None)))
    parts = [w]
    _icicles(parts, -1.5, 1.5, -0.5, 4.0, 7, 23, (0.4, 1.0), 0.07)
    snow = sphere("sn", (0, -0.2, 8.0), 1.0, (2.0, 0.8, 0.35))
    paint(snow, SNOW, ao=0.0)
    parts.append(snow)
    join(parts, "FrozenWaterfall")


def ice_ledge():
    """Ледяной уступ 3,4 × 3,4 м, 4,2 м в высоту (низ — z=0): голубая глыба со снежной шапкой."""
    blk = _block("lg", 3.5, 3.5, 4.2, cuts=8)
    displace(blk, 0.22, 0.8, "VORONOI")
    paint(blk, ICE, ao=0.3, ao_h=1.0, noise_amt=0.1, fn=_ice_fn(ICE, snow_z=3.6, snow_n=0.45))
    parts = [blk]
    cap = sphere("cp", (0, 0, 4.15), 1.8, (1.05, 1.05, 0.18))
    displace(cap, 0.06, 0.3)
    paint(cap, SNOW, ao=0.0, fn=lambda co, n: SNOW_SH if n.z < 0.3 else None)
    parts.append(cap)
    _icicles(parts, -1.5, 1.5, -1.8, 4.0, 6, 5, (0.3, 0.8), 0.07)
    join(parts, "IceLedge")


# ================================================================== обсерватория
def observatory():
    """Обсерватория: купол из голубых ледяных блоков (как иглу) с медной щелью для телескопа,
    входной тамбур с деревянной дверью (−Y Blender → +Z Godot), железная труба печки, снег вокруг."""
    dome = lathe("dm", [(2.9, 0.0), (2.95, 0.6), (2.8, 1.6), (2.4, 2.6), (1.7, 3.4), (0.9, 3.85), (0.0, 4.0)], 28)
    subsurf(dome, 1)

    def blocks(co, n):
        ang = math.atan2(co.y, co.x)
        row = int(co.z / 0.55)
        col = int((ang + math.pi) * 6 + (row % 2) * 0.5)
        if (co.z / 0.55) % 1.0 < 0.08 or ((ang + math.pi) * 6 + (row % 2) * 0.5) % 1.0 < 0.06:
            return ICE_L
        if co.z > 3.3:
            return SNOW
        return shade(ICE, 0.92 + 0.12 * ((row * 7 + col * 3) % 5) / 4)
    paint(dome, ICE, ao=0.3, ao_h=1.2, noise_amt=0.05, fn=blocks)
    parts = [dome]
    # медная щель через верх
    for sx in (-1, 1):
        rib = tube("rb", [(sx * 0.35, math.cos(a) * 2.95 * 0 + 2.9 * math.cos(a), 0.3 + 3.75 * math.sin(a)) for a in
                          [math.pi * 0.08 + k * math.pi * 0.42 / 8 for k in range(9)]], 0.07, 6)
        paint(rib, COPPER, ao=0.0, fn=lambda co, n: hexcol("5fb39a") if math.sin(co.z * 9) > 0.8 else None)
        parts.append(rib)
    slit = box("sl", (0, 1.6, 3.55), (0.6, 2.0, 0.08), (0.75, 0, 0))
    paint(slit, hexcol("2a3a4a"), ao=0.0)
    parts.append(slit)
    tube_t = cyl("tt", (0, 1.4, 3.0), 0.14, 0.12, 1.6, (-0.75, 0, 0), 12)
    paint(tube_t, BRASS, ao=0.0, fn=lambda co, n: shade(BRASS, 0.8) if math.sin(co.z * 14) > 0.85 else None)
    parts.append(tube_t)
    # тамбур с дверью
    hall = lathe("hl", [(1.0, 0.0), (1.02, 0.8), (0.85, 1.6), (0.5, 2.0), (0.0, 2.1)], 18, loc=(0, -2.6, 0), scale=(1.0, 1.25, 1.0))
    paint(hall, ICE, ao=0.3, ao_h=0.8, fn=blocks)
    parts.append(hall)
    door = box("dr", (0, -3.82, 0.85), (0.9, 0.12, 1.7), bev=0.04)
    paint(door, hexcol("8a5a32"), ao=0.0, fn=lambda co, n: (hexcol("6b4524") if int(co.x * 9) % 3 == 0 else
                                                          (BRASS if (abs(co.x - 0.3) < 0.04 and abs(co.z - 0.9) < 0.05) else None)))
    frame = tube("fr", [(-0.5, -3.85, 0.0), (-0.5, -3.85, 1.75), (0.5, -3.85, 1.75), (0.5, -3.85, 0.0)], 0.06, 6)
    paint(frame, hexcol("6b4524"), ao=0.0)
    lamp = sphere("lm", (0.62, -3.95, 1.55), 0.09)
    paint(lamp, hexcol("ffd27a"), ao=0.0, noise_amt=0)
    parts += [door, frame, lamp]
    # труба печки
    pipe = tube("pp", [(1.7, 1.1, 2.6), (1.9, 1.2, 3.6), (1.9, 1.2, 4.6)], 0.11, 10)
    paint(pipe, IRON, ao=0.0)
    hat = cyl("ht", (1.9, 1.2, 4.6), 0.22, 0.05, 0.2, segs=10)
    paint(hat, IRON, ao=0.0)
    parts += [pipe, hat]
    # сугробы у основания
    r = rnd(12)
    for k in range(9):
        a = k * 0.7 + 0.3
        if abs(math.sin(a) + 1) < 0.25:
            continue
        sd = sphere("sd", (math.cos(a) * 3.0, math.sin(a) * 3.0, 0.05), r.uniform(0.5, 0.8), (1.4, 1.0, 0.45))
        paint(sd, SNOW, ao=0.0, fn=lambda co, n: SNOW_SH if n.z < 0.3 else None)
        parts.append(sd)
    join(parts, "Observatory")


def telescope():
    """Телескоп: длинная латунная труба на деревянной треноге, смотрит в небо."""
    parts = []
    for k in range(3):
        a = k * 2 * math.pi / 3
        leg = log("lg", (math.cos(a) * 0.55, math.sin(a) * 0.55, 0.0), (0, 0, 1.25), 0.045, col=hexcol("8a5a32"), rings=False)
        parts.append(leg)
    mount = sphere("mn", (0, 0, 1.3), 0.12)
    paint(mount, BRASS, ao=0.0)
    tube_t = lathe("tb", [(0.0, -0.9), (0.14, -0.9), (0.15, -0.6), (0.17, 0.4), (0.2, 1.3), (0.21, 1.45), (0.0, 1.45)], 16,
                   loc=(0, 0, 1.4), rot=(-0.85, 0, 0))
    paint(tube_t, BRASS, ao=0.0, fn=lambda co, n: (shade(BRASS, 0.75) if math.sin((co.y * 0.6 + co.z) * 7) > 0.9 else None))
    lens = sphere("ln", (0, 1.15, 2.4), 0.17, (1.0, 0.3, 1.0), (-0.85, 0, 0))
    paint(lens, hexcol("bfe8f0"), ao=0.0, noise_amt=0)
    eye = tube("ey", [(0, -0.55, 0.95), (0, -0.7, 0.85)], 0.05, 8)
    paint(eye, IRON, ao=0.0)
    parts += [mount, tube_t, lens, eye]
    join(parts, "Telescope")


def star_dial():
    """Звёздный круг: каменная тумба с медным диском, шесть делений (на первом — Полярная звезда)."""
    ped = lathe("pd2", [(0.3, 0.0), (0.34, 0.1), (0.24, 0.3), (0.22, 0.8), (0.32, 0.92), (0.0, 0.94)], 16)
    paint(ped, STONE_PALE, ao=0.2, ao_h=0.4, noise_amt=0.1)
    disk = cyl("dk", (0, 0, 0.94), 0.64, 0.62, 0.08, segs=36)
    paint(disk, hexcol("2a3a5a"), ao=0.0, noise_amt=0, fn=lambda co, n: COPPER if math.hypot(co.x, co.y) > 0.58 else None)
    parts = [ped, disk]
    for k in range(6):
        a = -math.pi / 2 - k * math.pi / 3     # деление k: по часовой, если смотреть сверху
        for j in range(k + 1):
            off = (j - k / 2) * 0.035
            d = sphere("tk", (math.cos(a) * 0.6 - math.sin(a) * off, math.sin(a) * 0.6 + math.cos(a) * off, 1.02), 0.016, segs=8, rings=4)
            paint(d, hexcol("ffe08a"), ao=0.0, noise_amt=0)
            parts.append(d)
    polar = sphere("pl", (0, -0.66, 1.0), 0.04, segs=10, rings=6)
    paint(polar, hexcol("fff6c0"), ao=0.0, noise_amt=0)
    parts.append(polar)
    snow = sphere("sn", (0.25, 0.2, 0.05), 0.35, (1.4, 1.2, 0.3))
    paint(snow, SNOW, ao=0.0)
    parts.append(snow)
    join(parts, "StarDial")


def _ring(r, w, symbol, seed):
    """Кольцо звёздного круга радиусом r; знак созвездия — в начале (−Y Blender), остальное — россыпь звёзд."""
    ring = lathe("rg", [(r - w, 0.0), (r, 0.0), (r, 0.025), (r - w, 0.025)], 40)
    paint(ring, hexcol("c9a050"), ao=0.0, noise_amt=0, fn=lambda co, n: shade(hexcol("c9a050"), 1.1) if n.z > 0.5 else None)
    parts = [ring]
    rr = rnd(seed)
    for k in range(10):
        a = rr.uniform(0.4, 2 * math.pi - 0.4) - math.pi / 2
        s = sphere("st", (math.cos(a) * (r - w / 2), math.sin(a) * (r - w / 2), 0.03), 0.01, segs=6, rings=4)
        paint(s, hexcol("ffffff"), ao=0.0, noise_amt=0)
        parts.append(s)
    y = -(r - w / 2)
    if symbol == "sail":
        bm = bmesh.new()
        v = [bm.verts.new(p) for p in ((-0.03, y + 0.02, 0.03), (0.03, y + 0.02, 0.03), (0.0, y - 0.05, 0.03))]
        bm.faces.new(v)
        tri = from_bm("sl", bm)
        tri.scale = (1.6, 1.6, 1.0)
        from kit import solidify
        solidify(tri, 0.02)
        paint(tri, hexcol("fff2b0"), ao=0.0, noise_amt=0)
        parts.append(tri)
    elif symbol == "fish":
        f = sphere("fs", (0, y, 0.035), 0.035, (1.6, 0.8, 0.4))
        paint(f, hexcol("9fd8ff"), ao=0.0, noise_amt=0)
        t = cyl("ft", (0.06, y, 0.035), 0.02, 0.0, 0.04, (0, math.pi / 2, 0), 4)
        paint(t, hexcol("9fd8ff"), ao=0.0, noise_amt=0)
        parts += [f, t]
    else:
        e = sphere("ey", (0, y, 0.035), 0.04, (1.5, 0.9, 0.35))
        paint(e, hexcol("ffffff"), ao=0.0, noise_amt=0)
        p = sphere("ep", (0, y, 0.05), 0.016, (1, 1, 0.5))
        paint(p, hexcol("3a6a9a"), ao=0.0, noise_amt=0)
        parts += [e, p]
    join(parts, "Ring")


def star_ring_1():
    _ring(0.56, 0.08, "sail", 1)


def star_ring_2():
    _ring(0.44, 0.08, "fish", 2)


def star_ring_3():
    _ring(0.32, 0.08, "eye", 3)


def _sextant(broken):
    """Секстант на столике: латунная дуга с делениями, подвижная рука, зеркальце и подзорная трубочка."""
    parts = []
    top = plank("tp", (0, 0, 0.82), (0.9, 0.6, 0.06), col=hexcol("9a6a3e"))
    parts.append(top)
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(plank("lg", (sx * 0.38, sy * 0.24, 0.4), (0.06, 0.06, 0.8), col=hexcol("7a4a2a")))
    cloth = box("cl", (0.05, 0.0, 0.855), (0.5, 0.4, 0.01))
    paint(cloth, hexcol("3a5a7a"), ao=0.0)
    parts.append(cloth)
    tilt = (0.0, 1.3, 0.3) if broken else (0.0, 0.0, 0.0)
    base_z = 0.9 if broken else 1.05
    arc = tube("ar", [(math.cos(a) * 0.22, 0.0, base_z + math.sin(a) * 0.22 - 0.2) for a in
                      [math.pi * 0.35 + k * math.pi * 0.3 / 8 for k in range(9)]], 0.012, 6, caps=False)
    paint(arc, BRASS, ao=0.0, fn=lambda co, n: shade(BRASS, 0.7) if int(math.atan2(co.z, co.x) * 60) % 3 == 0 else None)
    frame = tube("fm", [(-0.11, 0.0, base_z - 0.02), (0.0, 0.0, base_z + 0.02), (0.11, 0.0, base_z - 0.02)], 0.012, 6)
    paint(frame, BRASS, ao=0.0)
    arm = tube("am", [(0.0, -0.01, base_z + 0.02), (0.05 if not broken else 0.12, -0.01, base_z - 0.2)], 0.01, 6)
    paint(arm, BRASS, ao=0.0)
    mirror = box("mr", (0.0, -0.02, base_z + 0.05), (0.06, 0.01, 0.05))
    paint(mirror, hexcol("dff3fb") if not broken else hexcol("8aa0aa"), ao=0.0, noise_amt=0)
    scope = tube("sc", [(-0.1, 0.02, base_z - 0.05), (0.06, 0.02, base_z - 0.05)], 0.018, 8)
    paint(scope, BRASS, ao=0.0)
    s = join([arc, frame, arm, mirror, scope], "Sextant")
    if broken:
        s.rotation_euler = tilt
        s.location = (0.05, 0.0, -0.12)
        for k in range(3):   # винты и осколки
            sc = sphere("sw", (-0.25 + k * 0.08, 0.15, 0.865), 0.012, segs=6, rings=4)
            paint(sc, BRASS, ao=0.0)
            parts.append(sc)
        shard = box("sh", (0.25, -0.15, 0.858), (0.05, 0.04, 0.005), (0, 0, 0.6))
        paint(shard, hexcol("dff3fb"), ao=0.0)
        parts.append(shard)
    else:
        stand = tube("st", [(0.0, 0.0, 0.85), (0.0, 0.0, 0.84 + 0.13)], 0.02, 6)
        paint(stand, IRON, ao=0.0)
        parts.append(stand)
    parts.append(s)
    join(parts, "SextantTable")


def sextant_broken():
    _sextant(True)


def sextant():
    _sextant(False)


def woodpile():
    """Поленница под навесиком, присыпанная снегом."""
    parts = []
    for row in range(3):
        for k in range(5 - row):
            x = -0.55 + k * 0.27 + row * 0.13
            parts.append(log("lg", (x, -0.4, 0.13 + row * 0.23), (x, 0.4, 0.13 + row * 0.23), 0.12))
    snow = sphere("sn", (0.0, 0.0, 0.75), 0.75, (1.1, 0.75, 0.22))
    paint(snow, SNOW, ao=0.0)
    parts.append(snow)
    join(parts, "Woodpile")


# ================================================================== ларцы, жаровня
def ice_chest():
    """Ледяной ларец: сундук Лёвы, вмёрзший в глыбу льда. Узлы Chest (с Lid) и Ice — глыба тает, пока горит жаровня."""
    body = box("b", (0, 0, 0.22), (0.8, 0.5, 0.44), bev=0.04)
    paint(body, hexcol("7a5a3e"), ao=0.0, fn=lambda co, n: hexcol("9aa0a6") if (abs(co.x) > 0.34 or abs(co.z - 0.22) < 0.03) else None)
    lock = box("lk", (0, -0.27, 0.36), (0.12, 0.04, 0.14), bev=0.01)
    paint(lock, hexcol("c9d2dc"), ao=0.0)
    lid = lathe("ld", [(0.0, 0.0), (0.25, 0.0), (0.25, 0.05), (0.0, 0.26)], 12, rot=(0, math.pi / 2, 0), scale=(1, 1, 1.6), loc=(0, 0, 0.44))
    paint(lid, hexcol("8a6a4a"), ao=0.0, fn=lambda co, n: SNOW if n.z > 0.6 else None)
    b = join([body, lock], "Chest")
    l = join([lid], "Lid")
    set_origin(l, (0, 0.25, 0.44))
    set_parent(l, b)
    ice = _block("ic", 1.25, 0.95, 1.05, cuts=4, z0=-0.05)
    displace(ice, 0.1, 0.4, "VORONOI")
    paint(ice, ICE_L, ao=0.0, noise_amt=0.08, fn=_snow_fn(ICE_L, snow_z=0.85, snow_n=0.5))
    cap = sphere("cp", (0, 0, 1.0), 0.65, (1.0, 0.8, 0.2))
    paint(cap, SNOW, ao=0.0)
    parts = [ice, cap]
    _icicles(parts, -0.5, 0.5, -0.5, 0.95, 4, 3, (0.15, 0.35), 0.04)
    i = join(parts, "Ice")
    set_origin(i, (0, 0, 0))


def _scale_fn():
    """Окалина и нагар на чаше жаровни — пятнами по шуму (не полосами)."""
    from mathutils import noise

    def f(co, n):
        v = noise.noise(co * 6.0) + 0.4 * noise.noise(co * 19.0)
        return hexcol("6a4a3a") if v > 0.35 else None
    return f


def brazier():
    """Жаровня: железная чаша с углями на трёх ногах. FirePoint — над углями."""
    parts = []
    for k in range(3):
        a = k * 2 * math.pi / 3
        leg = tube("lg", [(math.cos(a) * 0.32, math.sin(a) * 0.32, 0.0), (math.cos(a) * 0.2, math.sin(a) * 0.2, 0.45),
                          (math.cos(a) * 0.26, math.sin(a) * 0.26, 0.62)], 0.025, 6)
        paint(leg, IRON, ao=0.0)
        parts.append(leg)
    bowl = lathe("bw", [(0.0, 0.5), (0.2, 0.5), (0.34, 0.66), (0.36, 0.72), (0.33, 0.7), (0.0, 0.62)], 18)
    paint(bowl, IRON, ao=0.0, fn=_scale_fn())
    parts.append(bowl)
    r = rnd(4)
    for k in range(8):
        a = r.uniform(0, 2 * math.pi)
        d = r.uniform(0, 0.2)
        c = ico("cl", (math.cos(a) * d, math.sin(a) * d, 0.68), 0.06, sub=1)
        paint(c, hexcol("3a2a22"), ao=0.0, fn=lambda co, n: hexcol("ff7a2a") if n.z > 0.6 else None)
        parts.append(c)
    b = join(parts, "Brazier")
    empty("FirePoint", (0, 0, 0.72), b)


# ================================================================== Холодное сердце
def _cold_heart(frozen):
    """Маяк Ледяного острова: башня из светлого камня с чашей; в чаше — голубой кристалл «сердце».
    Вмёрзшая — в толстой ледяной корке с сосульками; оттаявшая — чистая, с инеем на кладке."""
    parts = []
    tower = lathe("tw", [(1.8, 0.0), (1.7, 0.5), (1.45, 3.5), (1.25, 7.0), (1.05, 8.6), (1.35, 8.9), (1.35, 9.2), (0.0, 9.2)], 20)
    displace(tower, 0.07, 0.5, "VORONOI")
    paint(tower, STONE_PALE, ao=0.3, ao_h=1.2, noise_amt=0.1, nscale=3,
          fn=lambda co, n: (hexcol("8fa8c0") if (co.z * 1.6) % 1.0 < 0.07 else
                            (hexcol("6fb4d8") if (abs(math.atan2(co.y, co.x) + 1.57) < 0.1 and co.z > 2.5) else None)))
    parts.append(tower)
    door = box("dr", (0, -1.6, 0.9), (0.8, 0.4, 1.7), bev=0.05)
    paint(door, hexcol("2a3a4a"), ao=0.0)
    parts.append(door)
    for k in range(6):
        a = 2 * math.pi * k / 6 + 0.3
        parts.append(stone("bs", (math.cos(a) * 2.3, math.sin(a) * 2.3, 0.15), 0.4, k, STONE_PALE))
    t = join(parts, "ColdHeart")
    bowl = lathe("bw", [(0.0, 9.2), (0.6, 9.25), (0.9, 9.6), (0.8, 9.65), (0.0, 9.4)], 18)
    paint(bowl, hexcol("8fa0b0"), ao=0.0)
    set_parent(bowl, t)
    heart = ico("hr", (0, 0, 9.75), 0.35, (0.8, 0.8, 1.3), sub=1)
    paint(heart, hexcol("bfe8ff"), ao=0.0, noise_amt=0, fn=lambda co, n: hexcol("ffffff") if n.z > 0.5 else (ICE_D if n.z < -0.3 else None))
    set_parent(heart, t)
    if frozen:
        # гранёный ледяной панцирь до середины башни, ледяные шипы-кристаллы, снежная шапка на чаше
        r = rnd(17)
        shell = lathe("sh", [(2.6, 0.0), (2.5, 1.5), (2.2, 3.5), (1.9, 5.2), (1.6, 6.0), (1.2, 6.3)], 7)
        displace(shell, 0.35, 1.2, "VORONOI")
        paint(shell, ICE, ao=0.25, ao_h=1.5, noise_amt=0.08, fn=_ice_fn(ICE, snow_z=5.0, snow_n=0.5))
        parts2 = [shell]
        for k in range(9):
            a = k * 2 * math.pi / 9 + r.uniform(-0.2, 0.2)
            z = r.uniform(0.2, 2.5)
            ln = r.uniform(1.6, 3.2)
            tilt = r.uniform(0.35, 0.7)
            sp = cyl("sp", (math.cos(a) * 2.1, math.sin(a) * 2.1, z), 0.45, 0.0, ln,
                     (0, tilt, a), segs=5)
            paint(sp, ICE_L, ao=0.0, noise_amt=0.05, fn=lambda co, n: ICE if n.z < 0.0 else None)
            parts2.append(sp)
        cap = sphere("cp", (0, 0, 9.55), 1.0, (1.0, 1.0, 0.55))
        displace(cap, 0.08, 0.3)
        paint(cap, SNOW, ao=0.0, fn=lambda co, n: SNOW_SH if n.z < 0.2 else None)
        parts2.append(cap)
        _icicles(parts2, -1.2, 1.2, -1.35, 9.1, 7, 31, (0.5, 1.3), 0.09)
        for k in range(6):   # наледь на кладке выше панциря
            a = k * math.pi / 3 + 0.4
            fr = sphere("fr", (math.cos(a) * 1.2, math.sin(a) * 1.2, r.uniform(6.6, 8.4)), 0.35, (1.0, 1.0, 1.6))
            paint(fr, ICE_L, ao=0.0)
            parts2.append(fr)
        c = join(parts2, "Crust")
        set_parent(c, t)
    else:
        for k in range(8):   # иней и капель на кладке
            a = k * math.pi / 4
            fr = sphere("fr", (math.cos(a) * 1.4, math.sin(a) * 1.4, 8.95), 0.18, (1.6, 1.0, 0.35))
            paint(fr, SNOW, ao=0.0)
            set_parent(fr, t)
    empty("FirePoint", (0, 0, 9.5), t)


def ice_tower_frozen():
    _cold_heart(True)


def ice_tower():
    _cold_heart(False)


# ================================================================== припай, лунка, льдины
def ice_shelf():
    """Припай: плоская плита льда 8 × 4 м (верх — z=0.12), трещины и снежные пятна."""
    bm = bmesh.new()
    r = rnd(5)
    pts = []
    for k in range(28):
        a = 2 * math.pi * k / 28
        rad = 1.0 + r.uniform(-0.06, 0.06)
        pts.append((math.cos(a) * 4.0 * rad, math.sin(a) * 2.0 * rad))
    top = [bm.verts.new((x, y, 0.12)) for x, y in pts]
    bot = [bm.verts.new((x * 0.95, y * 0.95, -0.3)) for x, y in pts]
    bm.faces.new(top)
    bm.faces.new(bot[::-1])
    for k in range(len(pts)):
        bm.faces.new((top[k], bot[k], bot[(k + 1) % len(pts)], top[(k + 1) % len(pts)]))
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=3, use_grid_fill=True)
    slab = from_bm("sl", bm, smooth=False)
    # снежные пятна — по шуму (а не произведением синусов: в текстуре стали бы клетками); трещины, грани, пузырьки
    # рисует запекание (texbake_props, "ice")
    from mathutils import noise
    paint(slab, ICE_L, ao=0.0, noise_amt=0.08,
          fn=lambda co, n: (SNOW if (n.z > 0.5 and noise.noise(co * 0.45) + 0.3 * noise.noise(co * 1.7) > 0.12) else
                            (ICE if n.z < 0.3 else None)))
    join([slab], "IceShelf")


def ice_hole():
    """Лунка: кольцо льда вокруг тёмной воды. Узел Cap — снежная крышка (пока лунку не просверлили)."""
    ring = lathe("rg", [(0.3, 0.0), (0.55, 0.0), (0.6, 0.05), (0.42, 0.1), (0.3, 0.06)], 20)
    paint(ring, ICE_L, ao=0.0, fn=lambda co, n: SNOW if n.z > 0.6 and math.hypot(co.x, co.y) > 0.45 else None)
    water = cyl("wt", (0, 0, 0.01), 0.31, 0.31, 0.02, segs=20)
    paint(water, hexcol("1f4a6a"), ao=0.0, noise_amt=0)     # блики на воде — пятнами при запекании ("water")
    r = join([ring, water], "Hole")
    cap = sphere("cp", (0, 0, 0.06), 0.42, (1.0, 1.0, 0.22))
    paint(cap, SNOW, ao=0.0, fn=lambda co, n: SNOW_SH if n.z < 0.4 else None)
    c = join([cap], "Cap")
    set_parent(c, r)


def _floe(seed, sx, sy):
    r = rnd(seed)
    bm = bmesh.new()
    n = 10
    pts = []
    for k in range(n):
        a = 2 * math.pi * k / n
        rad = r.uniform(0.75, 1.1)
        pts.append((math.cos(a) * sx * rad, math.sin(a) * sy * rad))
    top = [bm.verts.new((x, y, 0.22)) for x, y in pts]
    bot = [bm.verts.new((x * 0.85, y * 0.85, -0.35)) for x, y in pts]
    bm.faces.new(top)
    bm.faces.new(bot[::-1])
    for k in range(n):
        bm.faces.new((top[k], bot[k], bot[(k + 1) % n], top[(k + 1) % n]))
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    fl = from_bm("fl", bm, smooth=False)
    paint(fl, ICE, ao=0.0, noise_amt=0.06, fn=lambda co, n: SNOW if n.z > 0.6 else (ICE_L if co.z > 0.0 else None))
    parts = [fl]
    hump = sphere("hm", (r.uniform(-0.3, 0.3) * sx, 0, 0.22), 0.6 * min(sx, sy), (1.4, 1.0, 0.35))
    paint(hump, SNOW, ao=0.0, fn=lambda co, n: SNOW_SH if n.z < 0.3 else None)
    parts.append(hump)
    join(parts, "Floe")


def ice_floe_a():
    _floe(3, 1.6, 1.1)


def ice_floe_b():
    _floe(9, 1.1, 0.9)


# ================================================================== тундра: мох, брусника, сосна
def _moss(seed):
    """Кочка мха: мягкий бугорок зелёно-рыжего мха с белыми звёздочками лишайника."""
    r = rnd(seed)
    bumps = []
    for k in range(7):
        a = k * 0.9 + r.uniform(0, 0.4)
        d = 0.0 if k == 0 else r.uniform(0.22, 0.4)
        bumps.append(sphere("mb", (math.cos(a) * d, math.sin(a) * d, 0.06), r.uniform(0.2, 0.3), (1.0, 1.0, 0.65)))
    m = join(bumps, "Moss")
    remesh(m, 0.05, 2)
    displace(m, 0.03, 0.06)
    # кочечки, рыжие пятна и звёздочки лишайника — texbake (mat="moss"), а не сеткой по sin
    paint(m, hexcol("9aa860"), ao=0.3, ao_h=0.2, noise_amt=0.3, nscale=14,
          fn=lambda co, n: hexcol("b89a58") if n.z < 0.3 else (hexcol("b8c070") if n.z > 0.85 else None), mat="moss")
    parts = [m]
    for k in range(6):   # стебельки с красными шапочками лишайника
        a = r.uniform(0, 2 * math.pi)
        d = r.uniform(0.05, 0.3)
        t = tube("tf", [(math.cos(a) * d, math.sin(a) * d, 0.18), (math.cos(a) * d, math.sin(a) * d, 0.3)], 0.012, 4)
        paint(t, hexcol("dcd8b8"), ao=0.0)
        cap = sphere("cp", (math.cos(a) * d, math.sin(a) * d, 0.31), 0.022, segs=6, rings=4)
        paint(cap, hexcol("d8443a"), ao=0.0, noise_amt=0)
        parts += [t, cap]
    join(parts, "Moss")


def moss_a():
    _moss(2)


def moss_b():
    _moss(13)


def lingonberry_bush():
    """Брусника: низкий кустик с тёмными глянцевыми листочками и гроздьями красных ягод."""
    r = rnd(19)
    leaves = []
    for k in range(5):
        a = k * 1.25
        leaves.append(sphere("bl", (math.cos(a) * 0.2, math.sin(a) * 0.2, 0.24 + r.uniform(-0.04, 0.05)), 0.24, (1.15, 1.0, 0.6)))
    c = join(leaves, "bush_leaf")
    remesh(c, 0.07, 2)
    displace(c, 0.04, 0.1)
    paint(c, hexcol("2f5a34"), ao=0.3, ao_h=0.25, noise_amt=0.18, nscale=12, fn=lambda co, n: hexcol("4a7a44") if n.z > 0.7 else None)
    parts = [c]
    for k in range(18):
        a = r.uniform(0, 2 * math.pi)
        d = r.uniform(0.18, 0.36)
        b = sphere("bb", (math.cos(a) * d, math.sin(a) * d, r.uniform(0.2, 0.38)), 0.04, segs=8, rings=5)
        paint(b, hexcol("d8343a"), ao=0.0, noise_amt=0, fn=lambda co, n: hexcol("ff8a8a") if n.z > 0.7 else None)
        parts.append(b)
    join(parts, "Lingonberry")


def _pine(seed, h):
    """Северная сосна-ёлочка: прямой ствол и ярусы хвои; сверху на каждом ярусе — снег."""
    r = rnd(seed)
    trunk = tube("tr", [(0, 0, -0.1), (0, 0, h * 0.85)], [0.17, 0.06], 10)
    paint(trunk, BARK, ao=0.2, noise_amt=0.15, nscale=8, mat="pinebark")
    tiers = []
    n = 5
    for k in range(n):
        z0 = h * (0.2 + 0.15 * k)
        rad = 1.35 * (1.0 - k / (n + 0.6)) + r.uniform(-0.08, 0.08)
        t = cyl("tp", (0, 0, z0), rad, 0.04, h * 0.3, (0, 0, r.uniform(0, 1)), segs=14)
        subsurf(t, 1)
        displace(t, 0.14, 0.3)
        tiers.append(t)
    crown = join(tiers, "crown_leaf")
    # снег сверху ярусов — неровными шапками по шуму (не полосами); хвою рисует texbake (mat="needle")
    paint(crown, PINE, ao=0.0, noise_amt=0.15, nscale=5,
          fn=lambda co, n: (SNOW if (n.z > 0.45 and noise.noise(co * 1.7 + Vector((3.1, 1.7, 0.4))) + 0.35 * noise.noise(co * 5.0) > -0.42) else
                            (shade(PINE, 0.8) if n.z < -0.2 else None)), mat="needle")
    t = join([trunk], "Trunk")
    set_parent(crown, t)


def pine_a():
    _pine(7, 5.0)


def pine_b():
    _pine(29, 4.2)


def _snow_fn(base=ICE, snow_z=0.0, snow_n=0.55):
    """Лёд для запекания (texbake_props, "ice"): снежная шапка с рваным краем, верх светлее. Трещины, пузырьки
    и иней рисует запекание — без полос sin(), которые в текстуре стали бы «зеброй» (как в _ice_fn)."""
    from mathutils import noise

    def f(co, n):
        v = n.z + 0.25 * noise.noise(co * 3.0) + 0.1 * noise.noise(co * 11.0)
        if co.z > snow_z + 0.12 * noise.noise(co * 2.0 + Vector((5.0, 0, 0))) and v > snow_n:
            return SNOW
        return shade(base, 1.1) if n.z > 0.5 else None
    return f


def ice_block():
    """Ледяная глыба: гранёный голубой обломок со снежной шапкой (из неё колют лёд)."""
    b = ico("ib", (0, 0, 0.45), 0.65, (1.2, 1.0, 0.95), sub=3)
    displace(b, 0.18, 0.6, "VORONOI")
    paint(b, ICE, ao=0.25, ao_h=0.4, noise_amt=0.08, fn=_snow_fn(ICE, snow_z=0.75, snow_n=0.6))
    join([b], "IceBlock")


def _ice_wall(seed):
    """Ледяная стена-преграда: 3,5 м вдоль X, 2,4 м высотой, гранёные пласты льда, снег сверху, сосульки."""
    r = rnd(seed)
    parts = []
    for k in range(4):
        x = -1.3 + k * 0.87 + r.uniform(-0.1, 0.1)
        hh = r.uniform(1.9, 2.5)
        b = box("wb", (x, r.uniform(-0.15, 0.15), hh / 2), (1.05, 1.2, hh), (r.uniform(-0.08, 0.08), r.uniform(-0.1, 0.1), r.uniform(-0.15, 0.15)))
        parts.append(b)
    w = join(parts, "IceWall")
    remesh(w, 0.15, 2)
    displace(w, 0.16, 0.5, "VORONOI")
    paint(w, ICE, ao=0.3, ao_h=0.8, noise_amt=0.08, fn=_snow_fn(ICE, snow_z=1.6, snow_n=0.55))
    ic = []
    _icicles(ic, -1.4, 1.4, -0.62, 1.9, 6, seed, (0.2, 0.6), 0.05)
    for p in ic:
        set_parent(p, w)


def ice_wall_a():
    _ice_wall(3)


def ice_wall_b():
    _ice_wall(8)


# ================================================================== печка и теплица
def stove():
    """Кирпичная печка: топка с чугунной дверцей спереди (−Y Blender), плита с чайником, труба. FirePoint — в топке."""
    body = _block("sb", 1.0, 0.8, 1.0, cuts=8)
    bevel_ok = body
    paint(bevel_ok, BRICK, ao=0.25, ao_h=0.3, noise_amt=0.1, mat="brick",
          fn=lambda co, n: (hexcol("e8d8c0") if ((co.z * 7) % 1.0 < 0.1 or ((co.x * 4 + int(co.z * 7) % 2 * 0.5 + (co.y * 4 if abs(n.x) > 0.5 else 0)) % 1.0 < 0.08)) else None))
    parts = [body]
    plate = box("pl", (0, 0, 1.03), (1.08, 0.88, 0.06), bev=0.02)
    paint(plate, IRON, ao=0.0)
    door = box("dr", (0, -0.41, 0.42), (0.42, 0.04, 0.34), bev=0.02)
    paint(door, hexcol("2a2a2e"), ao=0.0, fn=lambda co, n: hexcol("ff9a3a") if (abs(co.z - 0.42) < 0.05 and abs(co.x) < 0.15) else None)
    pipe = tube("pp", [(0.3, 0.2, 1.05), (0.3, 0.2, 2.6)], 0.09, 10)
    paint(pipe, IRON, ao=0.0)
    hat = cyl("ht", (0.3, 0.2, 2.6), 0.18, 0.04, 0.16, segs=10)
    paint(hat, IRON, ao=0.0)
    kettle = lathe("kt", [(0.0, 1.06), (0.15, 1.06), (0.17, 1.15), (0.13, 1.26), (0.04, 1.3), (0.0, 1.31)], 14, loc=(-0.22, 0.0, 0.0))
    paint(kettle, hexcol("4a7ab8"), ao=0.0, mat="plain", fn=lambda co, n: hexcol("f2f2f2") if math.sin(co.x * 40) * math.sin(co.y * 40) > 0.7 else None)
    spout = tube("sp", [(-0.1, 0.0, 1.14), (0.0, -0.02, 1.22)], [0.03, 0.015], 6)
    paint(spout, hexcol("4a7ab8"), ao=0.0)
    handle = tube("hd", [(-0.3, 0.0, 1.28), (-0.22, 0.0, 1.38), (-0.14, 0.0, 1.28)], 0.012, 6)
    paint(handle, IRON, ao=0.0)
    parts += [plate, door, pipe, hat, kettle, spout, handle]
    s = join(parts, "Stove")
    empty("FirePoint", (0, -0.36, 0.3), s)


def greenhouse():
    """Теплица 4,3 × 3,9 м: деревянный каркас, стеклянные стены и двускатная крыша, дверь спереди (−Y Blender),
    внутри — дорожка из гальки между грядками."""
    hx, hy = 2.15, 1.95
    parts = []
    frame = hexcol("f2ead8")
    glass = hexcol("cdeef8")
    sill = []
    for (a, b) in (((-hx, -hy), (hx, -hy)), ((hx, -hy), (hx, hy)), ((hx, hy), (-hx, hy)), ((-hx, hy), (-hx, -hy))):
        sill.append(tube("sl", [(a[0], a[1], 0.15), (b[0], b[1], 0.15)], 0.1, 4))
    s = join(sill, "sill")
    paint(s, hexcol("9a6a3e"), ao=0.0)
    parts.append(s)
    posts = []
    for x in (-hx, -hx / 2, 0, hx / 2, hx):
        for y in (-hy, hy):
            if y < 0 and abs(x) < 0.6:
                continue   # дверной проём
            posts.append(tube("ps", [(x, y, 0.15), (x, y, 1.9)], 0.045, 6))
    for x in (-0.55, 0.55):
        posts.append(tube("dp", [(x, -hy, 0.15), (x, -hy, 1.9)], 0.05, 6))
    for y in (-hy / 3, hy / 3):
        for x in (-hx, hx):
            posts.append(tube("ps", [(x, y, 0.15), (x, y, 1.9)], 0.045, 6))
    for x in (-hx, hx):
        posts.append(tube("rf", [(x, -hy, 1.9), (x, 0, 2.75), (x, hy, 1.9)], 0.05, 6))
    for xx in (-hx, -hx / 2, 0, hx / 2, hx):
        posts.append(tube("rb", [(xx, -hy, 1.9), (xx, 0, 2.75)], 0.035, 5))
        posts.append(tube("rb", [(xx, hy, 1.9), (xx, 0, 2.75)], 0.035, 5))
    posts.append(tube("rg", [(-hx, 0, 2.75), (hx, 0, 2.75)], 0.055, 6))
    for y in (-hy, hy):
        posts.append(tube("tp", [(-hx, y, 1.9), (hx, y, 1.9)], 0.045, 6))
    for x in (-hx, hx):
        posts.append(tube("tp", [(x, -hy, 1.9), (x, hy, 1.9)], 0.045, 6))
    fr = join(posts, "frame")
    paint(fr, frame, ao=0.0, mat="painted")
    parts.append(fr)

    def pane_fn(co, n):
        if math.sin(co.x * 1.8 + co.z * 2.5 + co.y * 1.8) > 0.93:
            return hexcol("ffffff")
        return shade(glass, 1.04) if co.z > 1.4 else None
    panes = []
    # боковые стены
    for x in (-hx, hx):
        panes.append(box("gx", (x, 0, 1.02), (0.02, hy * 2, 1.7)))
        bm = bmesh.new()
        v = [bm.verts.new(p) for p in ((x, -hy, 1.9), (x, hy, 1.9), (x, 0, 2.75))]
        bm.faces.new(v)
        panes.append(from_bm("gt", bm))
    # задняя стена и передняя с дверным проёмом
    panes.append(box("gb", (0, hy, 1.02), (hx * 2, 0.02, 1.7)))
    for sx in (-1, 1):
        w = hx - 0.55
        panes.append(box("gf", (sx * (0.55 + w / 2), -hy, 1.02), (w, 0.02, 1.7)))
    panes.append(box("gd", (0, -hy, 1.82), (1.1, 0.02, 0.16)))
    # крыша
    for sy in (-1, 1):
        ln = math.hypot(hy, 0.85)
        panes.append(box("gr", (0, sy * hy / 2, 2.33), (hx * 2, ln, 0.02), (-sy * math.atan2(0.85, hy), 0, 0)))
    g = join(panes, "glass")
    paint(g, glass, ao=0.0, noise_amt=0.0, fn=pane_fn)
    parts.append(g)
    # дорожка из гальки
    r = rnd(6)
    for k in range(14):
        p = sphere("pb", (r.uniform(-0.3, 0.3), -hy + 0.2 + k * 0.27, 0.02), r.uniform(0.07, 0.11), (1.2, 1.0, 0.4))
        paint(p, hexcol("b8b0a0"), ao=0.0)
        parts.append(p)
    # снег на коньке
    for sy in (-1, 1):
        sn = box("sn", (0, sy * 0.25, 2.66), (hx * 2 + 0.1, 0.35, 0.07), (-sy * 0.45, 0, 0), bev=0.03)
        paint(sn, SNOW, ao=0.0, mat="plain")
        parts.append(sn)
    join(parts, "Greenhouse")


# ================================================================== морошка на грядке
def crop_cloudberry():
    """Морошка: розетки морщинистых листьев и янтарно-оранжевые ягоды на коротких стебельках."""
    r = rnd(14)
    leaves = []
    for k in range(10):
        x = r.uniform(-0.5, 0.5)
        y = r.uniform(-0.25, 0.25)
        lf = leaf("leaf", (x, y, 0.22), (r.uniform(-1, 1), r.uniform(-1, 1), 0.5), 0.22, 0.17, droop=0.4,
                  shape=lambda t: math.sin(math.pi * min(1.0, t * 0.9 + 0.1)) * (0.8 + 0.2 * math.sin(t * 18)))
        paint(lf, shade(hexcol("5a8a44"), r.uniform(0.85, 1.1)), ao=0.0, fn=lambda co, n: 0.85 if math.sin(co.x * 50) > 0.6 else None)
        leaves.append(lf)
    parts = []
    for k in range(7):
        x = r.uniform(-0.45, 0.45)
        y = r.uniform(-0.22, 0.22)
        st = tube("st", [(x, y, 0.2), (x + 0.02, y, 0.38)], 0.012, 5)
        paint(st, hexcol("6b8a3a"), ao=0.0)
        drupes = []
        for j in range(7):
            a = j * 0.9
            drupes.append(sphere("dp", (x + 0.02 + math.cos(a) * 0.03, y + math.sin(a) * 0.03, 0.42 + (j % 3) * 0.02), 0.028, segs=8, rings=5))
        b = join(drupes, "berry")
        paint(b, hexcol("f5a030"), ao=0.0, noise_amt=0.05, fn=lambda co, n: hexcol("ffd27a") if n.z > 0.6 else None)
        parts += [st, b]
    join(parts, "Crop")
    join(leaves, "crop_leaf")


# ================================================================== одежда на герое
# Куски вешаются на суставы героя (player.glb): Torso — на Body (бёдра, z=0.45), SleeveL/R и MittenL/R — на плечи
# ArmL/ArmR (±0.29, 0, 0.98), BootL/R — на бёдра LegL/LegR (±0.12, 0, 0.45). Точка вращения куска = сустав.
def _piece(objs, name, pivot):
    p = join(objs, name)
    set_origin(p, pivot)
    p.location = (0, 0, 0)
    return p


def _torso(col, r_add, fn, collar_col=None):
    t = lathe("t", [(0.0, 0.4), (0.27 + r_add, 0.42), (0.29 + r_add, 0.55), (0.27 + r_add, 0.75), (0.26 + r_add, 0.9),
                    (0.22 + r_add, 1.0), (0.12, 1.06), (0.0, 1.07)], 22)
    subsurf(t, 1)
    paint(t, col, ao=0.0, noise_amt=0.06, fn=fn)
    parts = [t]
    if collar_col:
        c = tube("cl", [(math.cos(a) * 0.15, math.sin(a) * 0.15, 1.05) for a in [i * math.pi / 10 for i in range(21)]], 0.07, 10, caps=False)
        paint(c, collar_col, ao=0.0, noise_amt=0.2, nscale=25)
        parts.append(c)
    return parts


def _sleeves(col, r0, r1, cuff_col, fn=None):
    out = []
    for sx, nm in ((-1, "SleeveL"), (1, "SleeveR")):
        sh = (sx * 0.29, 0, 0.98)
        s = tube("sv", [(sx * 0.27, 0, 1.03), (sx * 0.3, 0.0, 0.9), (sx * 0.33, 0.01, 0.8), (sx * 0.34, 0.03, 0.67)],
                 [r0, r0 * 0.95, r1 * 1.05, r1], 12)
        paint(s, col, ao=0.0, fn=fn)
        c = tube("cf", [(sx * 0.342, 0.032, 0.69), (sx * 0.345, 0.035, 0.64)], r1 + 0.012, 12)
        paint(c, cuff_col, ao=0.0, noise_amt=0.15, nscale=25)
        out.append(_piece([s, c], nm, sh))
    return out


def wear_sweater():
    """Шерстяной свитер: красный, с белой полосой-«ёлочкой» на груди, высокий ворот."""
    red = hexcol("c8503a")

    def fn(co, n):
        if 0.78 < co.z < 0.88:
            return hexcol("f2ead8") if math.sin(math.atan2(co.y, co.x) * 18 + co.z * 60) > -0.2 else None
        if co.z < 0.5:
            return shade(red, 0.85) if int(math.atan2(co.y, co.x) * 20) % 2 else None
        return 0.93 if int(co.z * 40) % 2 else None
    _piece(_torso(red, 0.03, fn, collar_col=shade(red, 0.9)), "Torso", (0, 0, 0.45))
    _sleeves(red, 0.13, 0.085, shade(red, 0.85), fn=lambda co, n: 0.93 if int(co.z * 40) % 2 else None)


def wear_jacket():
    """Пуховая куртка: синяя, стёганая полосами, с меховым воротником, молнией и карманами."""
    blue = hexcol("4a7ab8")

    def fn(co, n):
        if abs(co.x) < 0.015 and co.y > 0.1:
            return hexcol("c9a050")
        if (co.z * 9) % 1.0 < 0.12:
            return shade(blue, 0.78)
        return None
    parts = _torso(blue, 0.06, fn, collar_col=hexcol("f2e8d2"))
    for sx in (-1, 1):
        pk = box("pk", (sx * 0.15, 0.31, 0.6), (0.14, 0.04, 0.11), bev=0.02)
        paint(pk, shade(blue, 0.85), ao=0.0)
        parts.append(pk)
    _piece(parts, "Torso", (0, 0, 0.45))
    _sleeves(blue, 0.15, 0.105, hexcol("f2e8d2"), fn=lambda co, n: shade(blue, 0.78) if (co.z * 10) % 1.0 < 0.12 else None)


def wear_boots():
    """Валенки: серые войлочные, до колена, с красной вышивкой по краю."""
    grey = hexcol("8a8f98")
    for sx, nm in ((-1, "BootL"), (1, "BootR")):
        hip = (sx * 0.12, 0, 0.45)
        shin = tube("sh", [(sx * 0.12, 0.0, 0.3), (sx * 0.12, 0.0, 0.06)], [0.105, 0.095], 12)
        paint(shin, grey, ao=0.0, noise_amt=0.2, nscale=30, fn=lambda co, n: hexcol("c8403a") if 0.25 < co.z < 0.29 else None)
        foot = sphere("ft", (sx * 0.12, 0.06, 0.06), 0.1, (0.95, 1.6, 0.6))
        paint(foot, grey, ao=0.0, noise_amt=0.2, nscale=30)
        _piece([shin, foot], nm, hip)


def wear_mittens():
    """Тёплые рукавицы: красные, с белым узором и вязаной манжетой."""
    red = hexcol("d84a5a")
    for sx, nm in ((-1, "MittenL"), (1, "MittenR")):
        sh = (sx * 0.29, 0, 0.98)
        m = sphere("mt", (sx * 0.345, 0.04, 0.57), 0.09, (0.95, 1.05, 1.2))
        paint(m, red, ao=0.0, fn=lambda co, n: hexcol("f2ead8") if math.sin(co.z * 70) > 0.7 and co.z > 0.56 else None)
        th = sphere("th", (sx * 0.3, 0.11, 0.6), 0.04, (1.0, 1.3, 1.0))
        paint(th, red, ao=0.0)
        cf = tube("cf", [(sx * 0.342, 0.035, 0.67), (sx * 0.344, 0.038, 0.63)], 0.085, 12)
        paint(cf, hexcol("f2ead8"), ao=0.0, fn=lambda co, n: 0.88 if int(math.atan2(co.y, co.x) * 10) % 2 else None)
        _piece([m, th, cf], nm, sh)


# ================================================================== инструменты
def tool_ice_pick():
    """Ледоруб: ручка с ремешком, стальная голова — клюв с одной стороны, лопатка — с другой."""
    h = log("h", (0, 0, 0.1), (0, 0, -0.7), 0.028, col=hexcol("4a6a8a"), rings=False)
    strap = tube("st", [(0.0, 0.03, -0.0), (0.0, 0.08, -0.15), (0.0, 0.03, -0.3)], 0.012, 5)
    paint(strap, hexcol("c8403a"), ao=0.0)
    pick = tube("pk", [(0, 0.02, -0.62), (0, 0.18, -0.66), (0, 0.32, -0.72)], [0.03, 0.022, 0.006], 8)
    paint(pick, hexcol("c9d2dc"), ao=0.0)
    adze = box("ad", (0, -0.13, -0.62), (0.07, 0.16, 0.04), (0.2, 0, 0), bev=0.01)
    paint(adze, hexcol("c9d2dc"), ao=0.0)
    spike = cyl("sp", (0, 0, -0.78), 0.0, 0.025, 0.08, (math.pi, 0, 0), 6)
    paint(spike, hexcol("c9d2dc"), ao=0.0)
    join([h, strap, pick, adze, spike], "Tool")


def tool_ice_drill():
    """Ледовый бур: Т-образная ручка и шнек — винтовая спираль с ножами на конце."""
    shaft = log("h", (0, 0, 0.12), (0, 0, -0.8), 0.022, col=hexcol("8f979e"), rings=False)
    grip = tube("gr", [(-0.2, 0, 0.12), (0.2, 0, 0.12)], 0.03, 8)
    paint(grip, hexcol("c9a050"), ao=0.0)
    spiral = tube("sp", [(math.cos(a) * 0.06, math.sin(a) * 0.06, -0.35 - a * 0.025) for a in [k * 0.5 for k in range(37)]], 0.012, 5)
    paint(spiral, hexcol("c9d2dc"), ao=0.0)
    tip = cyl("tp", (0, 0, -0.85), 0.0, 0.06, 0.08, (math.pi, 0, 0), 8)
    paint(tip, hexcol("c9d2dc"), ao=0.0)
    join([shaft, grip, spiral, tip], "Tool")


BUILDERS = {
    "ingrid": ingrid, "penguin": penguin, "penguin_feeder": penguin_feeder, "walrus": walrus,
    "glacier_wall": glacier_wall, "ice_steps": ice_steps, "frozen_waterfall": frozen_waterfall, "ice_ledge": ice_ledge,
    "observatory": observatory, "telescope": telescope, "star_dial": star_dial,
    "star_ring_1": star_ring_1, "star_ring_2": star_ring_2, "star_ring_3": star_ring_3,
    "sextant_broken": sextant_broken, "sextant": sextant, "woodpile": woodpile,
    "ice_chest": ice_chest, "brazier": brazier, "ice_tower_frozen": ice_tower_frozen, "ice_tower": ice_tower,
    "ice_shelf": ice_shelf, "ice_hole": ice_hole, "ice_floe_a": ice_floe_a, "ice_floe_b": ice_floe_b,
    "moss_a": moss_a, "moss_b": moss_b, "lingonberry_bush": lingonberry_bush, "pine_a": pine_a, "pine_b": pine_b,
    "ice_block": ice_block, "ice_wall_a": ice_wall_a, "ice_wall_b": ice_wall_b,
    "stove": stove, "greenhouse": greenhouse, 
    "wear_sweater": wear_sweater, "wear_jacket": wear_jacket, "wear_boots": wear_boots, "wear_mittens": wear_mittens,
}   # инструменты — в models_tools.py
