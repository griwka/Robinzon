"""Украшения лагеря для «вечной игры» (вкладка «Декор»): мебель, коврики, гирлянды, фонарики, клумбы,
дорожки, заборчики, вывески. Размеры совпадают с Data.BUILDINGS (radius, posts) в игре.
Blender (x, y, z) → Godot (x, z, −y). Узлы Lamp* — где игра зажигает свет вечером (DecorPiece),
узел Vane — поворотная часть флюгера. Запекание — как у построек (список DECOR в build.py)."""
import math

from kit import box, cyl, displace, empty, hexcol, ico, join, lathe, leaf, paint, rnd, set_origin, set_parent, shade, sphere, tube
from models_buildings import PLANK, ROPE, WOOD, WOOD_D, bamboo, log, plank, rope_wrap, stone
from models_decor import (BLUE, CREAM, GREEN, IRON_L, LAMP, ORANGE, PINK, RED, TERRA, VIOLET, YELLOW, _iron)

PETALS = [PINK, YELLOW, hexcol("ffffff"), VIOLET, ORANGE, RED]
WHITE = hexcol("f4f0e4")
BRASS = hexcol("d8a83a")


# ------------------------------------------------------------------ помощники
def _pboard(name, loc, size, rot=(0, 0, 0), col=CREAM, fn=None):
    """Крашеная доска (штакетник, вывески, стрелки)."""
    b = box(name, loc, size, rot, bev=min(size) * 0.2, seg=2)
    paint(b, col, ao=0.15, ao_h=0.3, noise_amt=0.05, nscale=8, fn=fn, mat="painted")
    return b


def _flower(parts, x, y, z0, h, col, r=0.035):
    st = tube("fl", [(x, y, z0), (x + 0.01, y, z0 + h)], 0.011, 5)
    paint(st, hexcol("3fae49"), ao=0.0, mat="plain")
    parts.append(st)
    for k in range(5):
        a = 2 * math.pi * k / 5
        pe = sphere("pt", (x + math.cos(a) * r * 1.1, y + math.sin(a) * r * 1.1, z0 + h + 0.01), r, (1, 1, 0.45), segs=8, rings=5)
        paint(pe, col, ao=0.0, noise_amt=0, mat="plain")
        parts.append(pe)
    c = sphere("pc", (x, y, z0 + h + 0.03), r * 0.6, segs=8, rings=5)
    paint(c, hexcol("ffb02e"), ao=0.0, noise_amt=0, mat="plain")
    parts.append(c)


def _greens(parts, x, y, z, n, seed):
    rr = rnd(seed)
    for i in range(n):
        a = rr.uniform(0, 2 * math.pi)
        lf = leaf("lf_leaf", (x, y, z), (math.cos(a), math.sin(a), rr.uniform(0.5, 1.1)), rr.uniform(0.14, 0.22), 0.07, droop=0.5, segs=4)
        paint(lf, shade(GREEN, rr.uniform(0.85, 1.1)), ao=0.0, noise_amt=0.04, mat="leaf")
        parts.append(lf)


def _bed(parts, cx, cy, z, r, n, seed, hmin=0.14, hmax=0.3):
    """Цветы и зелень пятном радиуса r на высоте z."""
    rr = rnd(seed)
    _greens(parts, cx, cy, z, max(4, n // 2), seed + 1)
    for i in range(n):
        a = rr.uniform(0, 2 * math.pi)
        d = rr.uniform(0, r)
        _flower(parts, cx + math.cos(a) * d, cy + math.sin(a) * d * 0.9, z, rr.uniform(hmin, hmax), PETALS[(i + seed) % len(PETALS)])


def _mug(name, loc, col=TERRA):
    m = lathe(name, [(0.0, 0.0), (0.045, 0.0), (0.05, 0.09), (0.04, 0.09), (0.038, 0.02), (0.0, 0.02)], 10, loc=loc)
    paint(m, col, ao=0.0, mat="clay")
    return m


def _jug(name, loc, col=TERRA, k=1.0):
    j = lathe(name, [(0.0, 0.0), (0.07 * k, 0.0), (0.11 * k, 0.1 * k), (0.1 * k, 0.2 * k), (0.05 * k, 0.27 * k), (0.06 * k, 0.32 * k),
                     (0.045 * k, 0.32 * k), (0.035 * k, 0.27 * k), (0.0, 0.26 * k)], 12, loc=loc)
    paint(j, col, ao=0.1, ao_h=0.3, mat="clay")
    return j


def _catenary(x0, x1, z, sag, n=16):
    return [(x0 + (x1 - x0) * i / n, 0.0, z - sag * (1 - (2 * i / n - 1) ** 2)) for i in range(n + 1)]


def _foot_stones(parts, x=0.0, y=0.0, n=3, r=0.09):
    for i in range(n):
        parts.append(stone("ps", (x + math.cos(i * 2.1) * 0.13, y + math.sin(i * 2.1) * 0.13, 0.04), r, i))


# ------------------------------------------------------------------ мебель
def camp_table():
    parts = [plank("top%d" % i, (0, -0.24 + i * 0.16, 0.7), (1.1, 0.15, 0.05), seed=i) for i in range(4)]
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(log("lg", (sx * 0.46, sy * 0.24, 0.0), (sx * 0.42, sy * 0.2, 0.68), 0.04, rings=False))
        parts.append(plank("br", (sx * 0.44, 0, 0.3), (0.05, 0.5, 0.05), col=WOOD_D))
    cloth = box("cl", (0, 0, 0.73), (0.45, 0.7, 0.012))
    paint(cloth, CREAM, ao=0.0, mat="canvas", fn=lambda co, n: RED if (int((co.y + 2) * 12) % 2 == 0 and abs(co.x) > 0.16) else None)
    parts.append(cloth)
    parts += [_mug("m1", (-0.36, -0.12, 0.725)), _mug("m2", (0.36, 0.1, 0.725), BLUE), _jug("jg", (0.0, 0.1, 0.735), hexcol("d8c8a0"), 0.8)]
    pl = lathe("plt", [(0.0, 0.735), (0.1, 0.735), (0.13, 0.76), (0.0, 0.75)], 12, loc=(-0.02, -0.17, 0))
    paint(pl, hexcol("f2ead8"), ao=0.0, mat="clay")
    parts.append(pl)
    for i, c in enumerate(("ff9f2e", "e8443a", "ffe14d")):
        f = sphere("fr", (-0.06 + i * 0.045, -0.17 + (i % 2) * 0.04, 0.785), 0.035, segs=8, rings=6)
        paint(f, hexcol(c), ao=0.0, noise_amt=0, mat="plain")
        parts.append(f)
    join(parts, "CampTable")


def camp_stool():
    seat = cyl("st", (0, 0, 0.4), 0.24, 0.24, 0.06, segs=16)
    paint(seat, PLANK, ao=0.1, mat="wood")
    parts = [seat]
    for i in range(3):
        a = 2 * math.pi * i / 3 + 0.5
        parts.append(log("lg", (math.cos(a) * 0.24, math.sin(a) * 0.24, 0.0), (math.cos(a) * 0.12, math.sin(a) * 0.12, 0.41), 0.032, rings=False))
    cush = sphere("cu", (0, 0, 0.47), 0.2, (1, 1, 0.28), segs=14, rings=8)
    paint(cush, RED, ao=0.0, mat="canvas", fn=lambda co, n: CREAM if abs(math.sin(co.x * 22)) > 0.9 else None)
    parts.append(cush)
    join(parts, "CampStool")


def rocking_chair():
    parts = []
    for sx in (-1, 1):
        pts = [(sx * 0.3, -0.5 + 1.0 * i / 8, 0.05 + 0.16 * ((i - 4) / 4) ** 2) for i in range(9)]
        rk = tube("rk", pts, 0.035, 8)
        paint(rk, WOOD_D, ao=0.0, mat="wood")
        parts.append(rk)
        parts.append(log("fl", (sx * 0.3, -0.3, 0.07), (sx * 0.3, -0.32, 0.72), 0.03, rings=False))
        parts.append(log("bl", (sx * 0.3, 0.26, 0.07), (sx * 0.3, 0.42, 1.25), 0.03, rings=False))
        parts.append(plank("arm", (sx * 0.3, -0.02, 0.72), (0.07, 0.62, 0.04), col=WOOD))
    for i in range(4):
        parts.append(plank("seat%d" % i, (0, -0.26 + i * 0.15, 0.46 - i * 0.012), (0.56, 0.13, 0.035), seed=i))
    for i in range(5):
        parts.append(plank("bk%d" % i, (-0.22 + i * 0.11, 0.335, 0.86), (0.08, 0.035, 0.74), (-0.145, 0, 0), seed=i + 3))
    parts.append(plank("bt", (0, 0.4, 1.22), (0.66, 0.04, 0.09), (-0.145, 0, 0), col=WOOD_D))
    bl = box("pled", (0.1, 0.3, 0.95), (0.4, 0.07, 0.62), (-0.145, 0, 0.05), bev=0.03, seg=2)
    paint(bl, hexcol("c8503a"), ao=0.0, mat="canvas",
          fn=lambda co, n: CREAM if (int((co.z + 3) * 14) % 3 == 0 or int((co.x + 3) * 14) % 3 == 0) else None)
    parts.append(bl)
    join(parts, "RockingChair")


def camp_shelf():
    parts = []
    for sx in (-1, 1):
        parts.append(plank("side", (sx * 0.5, 0, 0.7), (0.05, 0.34, 1.4), col=WOOD_D))
    for i, z in enumerate((0.12, 0.56, 1.0, 1.38)):
        parts.append(plank("sh%d" % i, (0, 0, z), (1.02, 0.36, 0.045), seed=i))
    back = box("back", (0, 0.16, 0.76), (0.98, 0.02, 1.24))
    paint(back, shade(PLANK, 0.8), ao=0.2, mat="planked")
    parts.append(back)
    parts += [_jug("j1", (-0.3, 0.0, 1.02), TERRA), _jug("j2", (0.3, 0.02, 0.58), BLUE, 0.9),
              _mug("m1", (0.0, -0.05, 1.02), hexcol("f2ead8")), _mug("m2", (0.14, 0.0, 1.02), RED), _mug("m3", (0.3, -0.03, 1.02), YELLOW)]
    for i, x in enumerate((-0.32, -0.08)):
        b = lathe("bw", [(0.0, 0.0), (0.06, 0.0), (0.12, 0.07), (0.11, 0.07), (0.0, 0.02)], 12, loc=(x, 0.0, 0.585))
        paint(b, (TERRA, hexcol("d8c8a0"))[i], ao=0.0, mat="clay")
        parts.append(b)
    jar = lathe("jar", [(0.0, 0.0), (0.07, 0.0), (0.075, 0.13), (0.05, 0.15), (0.055, 0.18), (0.0, 0.18)], 12, loc=(-0.25, 0.0, 0.145))
    paint(jar, hexcol("f2a93a"), ao=0.0, mat="plain", fn=lambda co, n: CREAM if co.z > 0.29 else None)
    parts.append(jar)
    bask = lathe("bk", [(0.0, 0.0), (0.13, 0.0), (0.17, 0.16), (0.15, 0.16), (0.0, 0.03)], 12, loc=(0.2, 0.0, 0.145))
    paint(bask, hexcol("d6ad55"), ao=0.1, mat="straw")
    parts.append(bask)
    join(parts, "CampShelf")


def decor_chest():
    teal = hexcol("3f9a9a")

    def pat(co, n):
        if abs(n.y) > 0.6 and 0.14 < co.z < 0.36:
            u = (co.x + 2) * 5
            if abs((u % 1.0) - 0.5) + abs((co.z - 0.25) * 5) < 0.42:
                return YELLOW
        if 0.3 < abs(co.x) < 0.36:
            return IRON_L
        return None
    body = box("body", (0, 0, 0.24), (0.9, 0.55, 0.44), bev=0.03, seg=2)
    paint(body, teal, ao=0.25, ao_h=0.3, mat="painted", fn=pat)
    lid = cyl("lid", (-0.45, 0, 0.46), 0.275, 0.275, 0.9, rot=(0, math.pi / 2, 0), segs=16, scale=(0.55, 1, 1))
    paint(lid, RED, ao=0.1, mat="painted", fn=lambda co, n: IRON_L if 0.3 < abs(co.x) < 0.36 else (YELLOW if abs(co.x) < 0.04 else None))
    lock = box("lock", (0, -0.285, 0.43), (0.1, 0.03, 0.12), bev=0.01)
    _iron(lock, BRASS, "metal")
    parts = [body, lid, lock]
    for sx in (-1, 1):
        h = tube("hd", [(sx * 0.46, -0.1, 0.3), (sx * 0.52, 0, 0.26), (sx * 0.46, 0.1, 0.3)], 0.014, 6)
        paint(h, ROPE, ao=0.0, mat="rope")
        parts.append(h)
    join(parts, "DecorChest")


# ------------------------------------------------------------------ коврики
def rug_wool():
    cols = [hexcol("c8503a"), CREAM, hexcol("4a7ab8"), CREAM, hexcol("e8b42a"), CREAM]
    rug = box("rug", (0, 0, 0.02), (1.6, 1.05, 0.03), bev=0.012, seg=2)

    def stripes(co, n):
        if abs(co.y) > 0.46:
            return hexcol("8a2a2a")
        return cols[int((co.x + 0.8) / 1.6 * 12) % len(cols)]
    paint(rug, hexcol("c8503a"), ao=0.0, noise_amt=0.05, nscale=20, fn=stripes, mat="canvas")
    parts = [rug]
    for sx in (-1, 1):
        for i in range(11):
            f = tube("fr", [(sx * 0.8, -0.48 + i * 0.096, 0.02), (sx * 0.88, -0.48 + i * 0.096, 0.012)], 0.008, 4)
            paint(f, CREAM, ao=0.0, mat="rope")
            parts.append(f)
    join(parts, "RugWool")


def rug_straw():
    rug = cyl("rug", (0, 0, 0.0), 0.82, 0.8, 0.035, segs=28)

    def rings(co, n):
        d = math.hypot(co.x, co.y)
        k = int(d / 0.1)
        if k in (3, 6):
            return hexcol("b8583a")
        return 0.86 if (d / 0.1) % 1.0 < 0.14 else (1.0, 1.06)[k % 2]
    paint(rug, hexcol("d6ad55"), ao=0.0, noise_amt=0.08, nscale=30, fn=rings, mat="straw")
    join([rug], "RugStraw")


# ------------------------------------------------------------------ гирлянды
def _garland_posts(parts, off=1.2, h=2.3):
    for sx in (-1, 1):
        parts.append(log("post", (sx * off, 0, 0.0), (sx * off, 0, h), 0.05, rings=False))
        cap = sphere("cap", (sx * off, 0, h + 0.03), 0.07, segs=10, rings=6)
        paint(cap, WOOD_D, ao=0.0, mat="wood")
        parts.append(cap)
        parts.append(stone("ps", (sx * off + 0.1, 0.08, 0.04), 0.09, 3 + sx))


def garland_flags():
    parts = []
    _garland_posts(parts)
    r = tube("rope", _catenary(-1.2, 1.2, 2.22, 0.36), 0.012, 5, caps=False)
    paint(r, ROPE, ao=0.0, mat="rope")
    parts.append(r)
    cols = [RED, YELLOW, BLUE, GREEN, ORANGE, PINK, hexcol("ffffff"), VIOLET, RED]
    for i in range(9):
        t = (i + 0.5) / 9
        x = -1.2 + 2.4 * t
        z = 2.22 - 0.36 * (1 - (2 * t - 1) ** 2)
        fl = cyl("flag", (x, 0, z - 0.005), 0.1, 0.0, 0.24, rot=(math.pi, 0, 0), segs=4, scale=(1, 0.08, 1))
        paint(fl, cols[i], ao=0.0, noise_amt=0.03, mat="canvas")
        parts.append(fl)
    join(parts, "GarlandFlags")


def garland_lights():
    parts = []
    _garland_posts(parts)
    r = tube("rope", _catenary(-1.2, 1.2, 2.22, 0.34), 0.01, 5, caps=False)
    paint(r, hexcol("4a3b30"), ao=0.0, mat="rope")
    parts.append(r)
    lamps = []
    cols = [LAMP, hexcol("ffb36a"), hexcol("ffe9a0"), LAMP, hexcol("ffb36a"), hexcol("ffe9a0"), LAMP]
    for i in range(7):
        t = (i + 0.5) / 7
        x = -1.2 + 2.4 * t
        z = 2.22 - 0.34 * (1 - (2 * t - 1) ** 2)
        cap = cyl("cp", (x, 0, z - 0.05), 0.022, 0.022, 0.05, segs=6)
        _iron(cap, IRON_L)
        b = sphere("bulb_glow", (x, 0, z - 0.11), 0.065, (1, 1, 1.15), segs=10, rings=7)
        paint(b, cols[i], ao=0.0, noise_amt=0, mat="plain")
        parts += [cap, b]
        lamps.append((x, 0, z - 0.11))
    g = join(parts, "GarlandLights")
    for i, p in enumerate(lamps):
        empty("Lamp%d" % i, p, g)


# ------------------------------------------------------------------ фонарики
def _lamp_box(parts, c, s=0.11, h=0.2):
    """Фонарь: железный каркас, стекло, крышка-шатёр. c — центр низа."""
    x, y, z = c
    glass = box("glass_glow", (x, y, z + h / 2), (s * 1.7, s * 1.7, h))
    paint(glass, LAMP, ao=0.0, noise_amt=0, mat="plain")
    parts.append(glass)
    for sx in (-1, 1):
        for sy in (-1, 1):
            bar = box("bar", (x + sx * s * 0.88, y + sy * s * 0.88, z + h / 2), (0.022, 0.022, h + 0.02))
            _iron(bar)
            parts.append(bar)
    base = box("lb", (x, y, z - 0.012), (s * 2.1, s * 2.1, 0.03), bev=0.006)
    roof = cyl("lr", (x, y, z + h), s * 1.6, 0.02, 0.1, rot=(0, 0, math.pi / 4), segs=4)
    for o in (base, roof):
        _iron(o)
        parts.append(o)
    ring = tube("ring", [(x - 0.03, y, z + h + 0.1), (x, y, z + h + 0.15), (x + 0.03, y, z + h + 0.1)], 0.008, 5)
    _iron(ring, IRON_L)
    parts.append(ring)


def lantern_post():
    parts = [log("post", (0, 0, 0.0), (0, 0, 2.05), 0.055, rings=False)]
    parts.append(log("arm", (0, 0, 1.92), (0.42, 0, 2.0), 0.03, rings=False))
    parts.append(log("brace", (0, 0, 1.62), (0.28, 0, 1.94), 0.022, rings=False))
    parts.append(rope_wrap("tie", (0, 0), 0.062, 1.86, 2))
    _foot_stones(parts)
    _lamp_box(parts, (0.38, 0, 1.6))
    g = join(parts, "LanternPost")
    empty("Lamp0", (0.38, 0, 1.7), g)


def paper_lantern():
    parts = [bamboo("stick", (0, 0, 0.0), (0.0, 0.0, 1.45), 0.028)]
    hook = tube("hook", [(0, 0, 1.43), (0.1, 0, 1.56), (0.24, 0, 1.52), (0.26, 0, 1.42)], 0.012, 6)
    paint(hook, hexcol("c9a050"), ao=0.0, mat="bamboo")
    parts.append(hook)
    lan = lathe("paper_glow", [(0.0, 0.0), (0.06, 0.0), (0.13, 0.07), (0.155, 0.16), (0.13, 0.25), (0.06, 0.32), (0.0, 0.32)], 14, loc=(0.26, 0, 1.08))
    paint(lan, hexcol("e8443a"), ao=0.0, noise_amt=0.03, mat="plain",
          fn=lambda co, n: 0.82 if (co.z * 26) % 1.0 < 0.16 else (hexcol("ffb04a") if abs(math.atan2(co.y, co.x - 0.26)) < 0.3 and 1.18 < co.z < 1.3 else None))
    parts.append(lan)
    for z in (1.07, 1.4):
        c = cyl("cap", (0.26, 0, z), 0.065, 0.065, 0.025, segs=10)
        paint(c, hexcol("3a2a20"), ao=0.0, mat="wood")
        parts.append(c)
    ts = tube("tassel", [(0.26, 0, 1.07), (0.262, 0, 0.9)], [0.01, 0.022], 5)
    paint(ts, YELLOW, ao=0.0, mat="rope")
    parts.append(ts)
    parts.append(stone("ps", (0.08, 0.05, 0.04), 0.09, 2))
    g = join(parts, "PaperLantern")
    empty("Lamp0", (0.26, 0, 1.24), g)


def stone_lantern():
    gray = hexcol("a8a49c")
    base = cyl("base", (0, 0, 0.0), 0.3, 0.26, 0.12, segs=6)
    col = cyl("col", (0, 0, 0.12), 0.11, 0.09, 0.5, segs=8)
    plat = cyl("plat", (0, 0, 0.62), 0.24, 0.27, 0.07, segs=6)
    for o in (base, col, plat):
        paint(o, gray, ao=0.2, ao_h=0.3, noise_amt=0.1, nscale=10, mat="stone")
    house = box("house", (0, 0, 0.82), (0.3, 0.3, 0.26), bev=0.02, seg=2)
    paint(house, gray, ao=0.1, noise_amt=0.1, nscale=10, mat="stone",
          fn=lambda co, n: LAMP if (0.74 < co.z < 0.9 and (abs(co.x) < 0.075 or abs(co.y) < 0.075) and abs(n.z) < 0.5) else None)
    roof = cyl("roof", (0, 0, 0.95), 0.36, 0.05, 0.2, rot=(0, 0, math.pi / 4), segs=4)
    paint(roof, shade(gray, 0.85), ao=0.0, noise_amt=0.12, nscale=9, mat="stone",
          fn=lambda co, n: hexcol("6d9a40") if (n.z > 0.5 and math.sin(co.x * 17) * math.cos(co.y * 13) > 0.45) else None)
    knob = sphere("knob", (0, 0, 1.17), 0.06, segs=8, rings=6)
    paint(knob, gray, ao=0.0, mat="stone")
    g = join([base, col, plat, house, roof, knob], "StoneLantern")
    empty("Lamp0", (0, 0, 0.82), g)


# ------------------------------------------------------------------ клумбы
def flower_tub():
    tub = lathe("tub", [(0.0, 0.0), (0.26, 0.0), (0.32, 0.34), (0.28, 0.34), (0.27, 0.3), (0.0, 0.3)], 16)

    def staves(co, n):
        if abs(co.z - 0.08) < 0.018 or abs(co.z - 0.27) < 0.018:
            return IRON_L
        a = math.atan2(co.y, co.x) * 16 / (2 * math.pi)
        return 0.72 if (a % 1.0) < 0.1 else (0.95, 1.05)[int(math.floor(a)) % 2]
    paint(tub, WOOD, ao=0.2, ao_h=0.25, fn=staves, mat="wood")
    soil = cyl("soil", (0, 0, 0.28), 0.27, 0.27, 0.03, segs=14)
    paint(soil, hexcol("5a3a24"), ao=0.0, noise_amt=0.2, nscale=15, mat="soil")
    parts = [tub, soil]
    _bed(parts, 0, 0, 0.3, 0.2, 8, 5, 0.16, 0.34)
    join(parts, "FlowerTub")


def flower_barrow():
    parts = []
    tray = box("tray", (0, 0.05, 0.5), (0.62, 0.95, 0.3), (0.12, 0, 0), bev=0.03, seg=2)
    paint(tray, BLUE, ao=0.25, ao_h=0.3, mat="painted", fn=lambda co, n: 0.8 if abs(n.z) < 0.5 and int((co.y + 2) * 7) % 3 == 0 else None)
    soil = box("soil", (0, 0.05, 0.655), (0.54, 0.86, 0.04), (0.12, 0, 0))
    paint(soil, hexcol("5a3a24"), ao=0.0, noise_amt=0.2, nscale=15, mat="soil")
    wheel = cyl("wheel", (-0.04, -0.62, 0.2), 0.2, 0.2, 0.08, rot=(0, math.pi / 2, 0), segs=16)
    paint(wheel, WOOD_D, ao=0.1, mat="wood", fn=lambda co, n: IRON_L if abs(math.hypot(co.y + 0.62, co.z - 0.2) - 0.19) < 0.022 else None)
    parts += [tray, soil, wheel]
    for sx in (-1, 1):
        parts.append(log("hd", (sx * 0.27, -0.62, 0.2), (sx * 0.36, 0.95, 0.72), 0.028, rings=False))
        parts.append(log("leg", (sx * 0.3, 0.42, 0.0), (sx * 0.3, 0.42, 0.52), 0.028, rings=False))
    _bed(parts, 0.0, -0.18, 0.64, 0.2, 7, 11, 0.14, 0.3)
    _bed(parts, 0.0, 0.3, 0.7, 0.2, 7, 17, 0.14, 0.3)
    join(parts, "FlowerBarrow")


def flower_arch():
    parts = []
    off, h = 0.95, 1.75
    arc = [(-off, 0.0), (-off, h)] + [(math.cos(math.pi - math.pi * i / 10) * off, h + math.sin(math.pi * i / 10) * 0.55) for i in range(1, 10)] + [(off, h), (off, 0.0)]
    for dy in (-0.14, 0.14):
        t = tube("arch", [(x, dy, z) for x, z in arc], 0.035, 8)
        paint(t, hexcol("e0c06a"), ao=0.1, mat="bamboo", fn=lambda co, n: 0.75 if (co.z * 4.2) % 1.0 < 0.07 else None)
        parts.append(t)
    for x, z in arc[1:-1]:
        cr = tube("cr", [(x, -0.14, z), (x, 0.14, z)], 0.02, 6)
        paint(cr, hexcol("c9a050"), ao=0.0, mat="bamboo")
        parts.append(cr)
    rr = rnd(9)
    vine = [(x + rr.uniform(-0.05, 0.05), 0.16 * math.sin(i * 1.9), z) for i, (x, z) in enumerate(arc)]
    v = tube("vine", vine, 0.016, 5, caps=False)
    paint(v, hexcol("3f8a3a"), ao=0.0, mat="plain")
    parts.append(v)
    for i, (x, y, z) in enumerate(vine[1:-1]):
        for k in range(3):
            a = rr.uniform(0, 2 * math.pi)
            lf = leaf("v_leaf", (x, y, z), (math.cos(a), math.sin(a), rr.uniform(-0.2, 0.6)), rr.uniform(0.16, 0.24), 0.09, droop=0.5, segs=4)
            paint(lf, shade(GREEN, rr.uniform(0.85, 1.1)), ao=0.0, noise_amt=0.04, mat="leaf")
            parts.append(lf)
        col = PETALS[i % len(PETALS)]
        for k in range(2):
            fx, fy, fz = x + rr.uniform(-0.08, 0.08), y + rr.uniform(-0.1, 0.1), z + rr.uniform(-0.06, 0.1)
            for q in range(5):
                a = 2 * math.pi * q / 5
                pe = sphere("pt", (fx + math.cos(a) * 0.045, fy, fz + math.sin(a) * 0.045), 0.04, (1, 0.5, 1), segs=8, rings=5)
                paint(pe, col, ao=0.0, noise_amt=0, mat="plain")
                parts.append(pe)
            c = sphere("pc", (fx, fy - 0.01, fz), 0.025, segs=8, rings=5)
            paint(c, hexcol("ffb02e"), ao=0.0, noise_amt=0, mat="plain")
            parts.append(c)
    for sx in (-1, 1):
        parts.append(stone("ps", (sx * off, 0.0, 0.04), 0.14, 3 + sx))
    join(parts, "FlowerArch")


# ------------------------------------------------------------------ дорожки
def plank_path():
    rr = rnd(4)
    parts = [plank("cross", (0.0, 0.0, 0.012), (0.07, 0.92, 0.025), col=WOOD_D)]
    for i in range(4):
        parts.append(plank("pp%d" % i, (rr.uniform(-0.03, 0.03), -0.36 + i * 0.24, 0.04), (rr.uniform(0.86, 0.98), 0.21, 0.045),
                           (0, 0, rr.uniform(-0.04, 0.04)), seed=i))
    join(parts, "PlankPath")


def stone_path():
    rr = rnd(7)
    parts = []
    spots = [(0.0, 0.0, 0.24), (0.3, 0.16, 0.16), (-0.28, 0.2, 0.17), (-0.2, -0.26, 0.18), (0.26, -0.24, 0.17), (0.02, 0.36, 0.11), (0.0, -0.4, 0.1)]
    for x, y, r in spots:
        s = ico("sp", (x, y, 0.012), r, (1.0, rr.uniform(0.8, 1.0), 0.16), (0, 0, rr.uniform(0, 3)), sub=2)
        displace(s, 0.02, 0.2, "VORONOI")
        paint(s, shade(hexcol("b8b2a6"), rr.uniform(0.86, 1.06)), ao=0.1, ao_h=0.05, noise_amt=0.1, nscale=12, mat="stone")
        parts.append(s)
    join(parts, "StonePath")


# ------------------------------------------------------------------ заборчики
def picket_fence():
    parts = [_pboard("rail%d" % i, (0, 0.03, z), (1.3, 0.035, 0.07), col=WHITE) for i, z in enumerate((0.25, 0.6))]
    for i in range(7):
        x = -0.57 + i * 0.19
        parts.append(_pboard("pk%d" % i, (x, 0, 0.4), (0.12, 0.03, 0.74), col=WHITE))
        tip = cyl("tip", (x, 0, 0.77), 0.085, 0.0, 0.1, rot=(0, 0, math.pi / 4), segs=4, scale=(1, 0.26, 1))
        paint(tip, WHITE, ao=0.0, mat="painted")
        parts.append(tip)
    join(parts, "PicketFence")


def bamboo_fence():
    parts = [bamboo("post", (x, 0, 0.0), (x, 0, 0.92), 0.045) for x in (-0.6, 0.6)]
    for z in (0.28, 0.68):
        parts.append(bamboo("rail", (-0.66, 0.03, z), (0.66, 0.03, z), 0.03))
    for i in range(6):
        x = -0.45 + i * 0.18
        parts.append(bamboo("bar", (x, -0.02, 0.04), (x, -0.02, 0.8 + (i % 2) * 0.06), 0.022))
        for z in (0.28, 0.68):
            tie = cyl("tie", (x, 0.005, z - 0.02), 0.04, 0.04, 0.04, segs=6)
            paint(tie, hexcol("5a4030"), ao=0.0, mat="rope")
            parts.append(tie)
    join(parts, "BambooFence")


def garden_gate():
    off = 0.55
    parts = []
    for sx in (-1, 1):
        parts.append(log("post", (sx * off, 0, 0.0), (sx * off, 0, 1.25), 0.07, rings=False))
        cap = cyl("cap", (sx * off, 0, 1.25), 0.1, 0.02, 0.1, segs=8)
        paint(cap, WOOD_D, ao=0.0, mat="wood")
        parts.append(cap)
    ang = 0.6   # створка приоткрыта: висит на левом столбе
    ca, sa = math.cos(ang), math.sin(ang)

    def at(u, z):
        return (-off + 0.08 + u * ca, u * sa, z)
    for i in range(5):
        u = 0.08 + i * 0.19
        hgt = 0.86 + (0.1 if i in (1, 2, 3) else 0.0) + (0.06 if i == 2 else 0.0)
        parts.append(_pboard("gb%d" % i, at(u, 0.09 + hgt / 2), (0.15, 0.03, hgt), (0, 0, ang), col=WHITE))
    for z in (0.25, 0.8):
        parts.append(_pboard("gr", at(0.46, z), (0.94, 0.04, 0.07), (0, 0, ang), col=hexcol("d8d2c2")))
    latch = box("latch", at(0.86, 0.62), (0.1, 0.05, 0.035), (0, 0, ang))
    _iron(latch, IRON_L)
    parts.append(latch)
    for z in (0.3, 0.85):
        hg = box("hinge", (-off + 0.08, 0.0, z), (0.07, 0.07, 0.06))
        _iron(hg)
        parts.append(hg)
    join(parts, "GardenGate")


# ------------------------------------------------------------------ вывески
def sign_camp():
    parts = [log("post", (x, 0, 0.0), (x, 0, 1.55), 0.045, rings=False) for x in (-0.42, 0.42)]
    parts.append(log("top", (-0.52, 0, 1.5), (0.52, 0, 1.5), 0.035, rings=False))

    def art(co, n):
        if n.y > -0.5:
            return None
        x, z = co.x, co.z - 1.08
        if abs(x) > 0.4 or abs(z) > 0.2:
            return hexcol("8a5a32")            # рамка
        w = 0.07 - abs(abs(x + 0.2) - 0.07) * 0.6      # чайка — две дуги
        if abs(x + 0.2) < 0.14 and abs(z - 0.04 - w) < 0.018:
            return hexcol("3a4a6a")
        if 0.0 < x < 0.34 and (abs(z - 0.08) < 0.016 or abs(z) < 0.016 or (abs(z + 0.08) < 0.016 and x < 0.24)):
            return hexcol("4a2c14")            # строчки названия
        return None
    board = box("board", (0, -0.02, 1.08), (0.9, 0.05, 0.5), bev=0.015, seg=2)
    paint(board, hexcol("f2e2b8"), ao=0.1, noise_amt=0.05, nscale=8, fn=art, mat="painted")
    parts.append(board)
    for sx in (-1, 1):
        r = tube("rope", [(sx * 0.32, -0.02, 1.33), (sx * 0.32, -0.01, 1.5)], 0.012, 5)
        paint(r, ROPE, ao=0.0, mat="rope")
        parts.append(r)
    join(parts, "SignCamp")


def sign_arrows():
    parts = [log("post", (0, 0, 0.0), (0, 0, 2.1), 0.055, rings=False)]
    _foot_stones(parts, r=0.1)
    specs = [(1.82, 0.3, RED, 1), (1.55, -0.5, WHITE, -1), (1.28, 0.9, BLUE, 1), (1.02, -0.15, YELLOW, -1), (0.76, 0.55, GREEN, 1)]
    for i, (z, ang, col, side) in enumerate(specs):
        ca, sa = math.cos(ang), math.sin(ang)
        ln = 0.62
        # доска перед столбом (−Y), сдвинута в сторону, куда показывает
        cx, cy = side * ca * 0.2 + sa * 0.07, side * sa * 0.2 - ca * 0.07
        parts.append(_pboard("ar%d" % i, (cx, cy, z), (ln, 0.035, 0.17), (0, 0, ang), col=col))
        tx, ty = cx + side * ca * ln / 2, cy + side * sa * ln / 2
        tip = cyl("tip", (tx, ty, z), 0.125, 0.0, 0.14, rot=(0, side * math.pi / 2, ang), segs=4, scale=(1, 0.2, 1))
        paint(tip, col, ao=0.0, mat="painted")
        parts.append(tip)
    join(parts, "SignArrows")


# ------------------------------------------------------------------ прочее
def wash_stand():
    parts = [plank("top%d" % i, (0, -0.13 + i * 0.13, 0.78), (0.72, 0.12, 0.045), seed=i) for i in range(3)]
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(log("lg", (sx * 0.3, sy * 0.14, 0.0), (sx * 0.29, sy * 0.13, 0.77), 0.032, rings=False))
    parts.append(plank("low", (0, 0, 0.26), (0.62, 0.3, 0.035), col=WOOD_D))
    basin = lathe("basin", [(0.0, 0.0), (0.12, 0.0), (0.22, 0.1), (0.2, 0.1), (0.1, 0.03), (0.0, 0.03)], 16, loc=(-0.1, 0, 0.805))
    paint(basin, hexcol("f2ead8"), ao=0.0, mat="clay", fn=lambda co, n: BLUE if co.z > 0.885 else None)
    water = cyl("water", (-0.1, 0, 0.87), 0.17, 0.17, 0.01, segs=14)
    paint(water, hexcol("8fd0e8"), ao=0.0, noise_amt=0.04, mat="plain")
    parts += [basin, water, _jug("jug", (0.22, 0.03, 0.805), hexcol("f2ead8"), 0.95), _jug("jug2", (0.1, 0.0, 0.28), TERRA, 1.1)]
    rail = log("rail", (-0.42, -0.16, 0.6), (-0.42, 0.16, 0.6), 0.016, rings=False)
    towel = box("towel", (-0.425, 0.0, 0.46), (0.03, 0.22, 0.3), bev=0.01)
    paint(towel, CREAM, ao=0.0, mat="canvas", fn=lambda co, n: BLUE if (co.z < 0.37 and int(co.z * 60) % 2 == 0) else None)
    parts += [rail, towel]
    join(parts, "WashStand")


def bird_feeder():
    parts = [log("post", (0, 0, 0.0), (0, 0, 1.4), 0.045, rings=False)]
    tray = box("tray", (0, 0, 1.42), (0.5, 0.42, 0.04), bev=0.01)
    paint(tray, PLANK, ao=0.1, mat="wood")
    parts.append(tray)
    for sx in (-1, 1):
        parts.append(plank("rim", (sx * 0.24, 0, 1.46), (0.03, 0.42, 0.05), col=WOOD_D))
        for sy in (-1, 1):
            parts.append(log("col", (sx * 0.2, sy * 0.16, 1.44), (sx * 0.2, sy * 0.16, 1.74), 0.016, rings=False))
        roof = box("roof", (sx * 0.15, 0, 1.82), (0.36, 0.52, 0.03), (0, sx * 0.6, 0), bev=0.008)
        paint(roof, RED, ao=0.0, mat="painted", fn=lambda co, n: 0.8 if int((co.y + 2) * 9) % 2 == 0 else None)
        parts.append(roof)
    for i in range(9):
        g = sphere("corn", (-0.12 + (i % 3) * 0.08, -0.1 + (i // 3) * 0.07, 1.45), 0.018, segs=6, rings=4)
        paint(g, YELLOW, ao=0.0, noise_amt=0, mat="plain")
        parts.append(g)
    body = sphere("bird", (0.14, 0.1, 1.51), 0.06, (1.25, 0.9, 0.95), segs=10, rings=7)
    paint(body, YELLOW, ao=0.0, mat="plain", fn=lambda co, n: hexcol("fff2c8") if co.z < 1.495 else None)
    head = sphere("bh", (0.2, 0.1, 1.57), 0.042, segs=10, rings=7)
    paint(head, YELLOW, ao=0.0, mat="plain",
          fn=lambda co, n: hexcol("1d1d1d") if (co.x > 0.215 and abs(co.z - 1.58) < 0.012 and abs(abs(co.y - 0.1) - 0.025) < 0.012) else None)
    beak = cyl("beak", (0.235, 0.1, 1.565), 0.014, 0.0, 0.04, rot=(0, math.pi / 2, 0), segs=5)
    paint(beak, ORANGE, ao=0.0, mat="plain")
    tail = box("tail", (0.06, 0.1, 1.54), (0.08, 0.03, 0.012), (0, -0.5, 0))
    paint(tail, hexcol("c8922a"), ao=0.0, mat="plain")
    parts += [body, head, beak, tail]
    join(parts, "BirdFeeder")


def weather_vane():
    parts = [log("post", (0, 0, 0.0), (0, 0, 1.9), 0.05, rings=False)]
    _foot_stones(parts)
    rod = cyl("rod", (0, 0, 1.9), 0.014, 0.012, 0.5, segs=6)
    _iron(rod)
    parts.append(rod)
    for ang in (0, math.pi / 2):
        cr = tube("cr", [(-0.2 * math.cos(ang), -0.2 * math.sin(ang), 2.08), (0.2 * math.cos(ang), 0.2 * math.sin(ang), 2.08)], 0.009, 5)
        _iron(cr)
        parts.append(cr)
    for ang in (0, math.pi / 2, math.pi, 3 * math.pi / 2):
        b = sphere("nb", (0.2 * math.cos(ang), 0.2 * math.sin(ang), 2.08), 0.026, segs=8, rings=5)
        _iron(b, BRASS, "metal")
        parts.append(b)
    main = join(parts, "WeatherVane")
    # поворотная часть: стрела и чайка (узел Vane крутит игра)
    arrow = tube("arrow", [(-0.34, 0, 2.3), (0.3, 0, 2.3)], 0.011, 5)
    _iron(arrow)
    tip = cyl("tip", (0.3, 0, 2.3), 0.05, 0.0, 0.12, rot=(0, math.pi / 2, 0), segs=4, scale=(1, 0.3, 1))
    _iron(tip)
    fin = box("fin", (-0.3, 0, 2.3), (0.14, 0.012, 0.14), (0, math.pi / 4, 0))
    _iron(fin)
    gull = sphere("gull", (0.0, 0, 2.4), 0.07, (1.5, 0.35, 0.8), segs=10, rings=6)
    _iron(gull, BRASS, "metal")
    vp = [arrow, tip, fin, gull]
    for sx in (-1, 1):
        w = box("wing", (-0.02, 0, 2.47), (0.2, 0.012, 0.08), (0, sx * 0.5 - 0.2, 0))
        _iron(w, BRASS, "metal")
        vp.append(w)
    bk = cyl("bk", (0.1, 0, 2.4), 0.02, 0.0, 0.06, rot=(0, math.pi / 2, 0), segs=5)
    _iron(bk, BRASS, "metal")
    vp.append(bk)
    vane = join(vp, "Vane")
    set_origin(vane, (0, 0, 2.3))
    set_parent(vane, main)


def log_stack():
    parts = []
    for sx in (-1, 1):
        for sy in (-0.2, 0.2):
            parts.append(log("post", (sx * 0.62, sy, 0.0), (sx * 0.62, sy, 1.05), 0.035, rings=False))
    for sy in (-0.2, 0.2):
        parts.append(log("base", (-0.68, sy, 0.05), (0.68, sy, 0.05), 0.035, rings=False))
    rr = rnd(12)
    z = 0.18
    row = 0
    while z < 0.9:
        n = 6 if row % 2 == 0 else 5
        for i in range(n):
            x = -0.5 + (i + (0.5 if row % 2 else 0.0)) * 0.2
            parts.append(log("lg", (x, -0.3 + rr.uniform(-0.02, 0.02), z), (x, 0.3 + rr.uniform(-0.02, 0.02), z), rr.uniform(0.085, 0.1),
                             col=shade(WOOD_D, rr.uniform(0.85, 1.15))))
        z += 0.175
        row += 1
    for sx in (-1, 1):
        roof = box("roof", (sx * 0.34, 0, 1.16), (0.78, 0.8, 0.035), (0, sx * 0.22, 0), bev=0.008)
        paint(roof, hexcol("7a5a40"), ao=0.0, noise_amt=0.12, nscale=9, mat="bark")
        parts.append(roof)
    join(parts, "LogStack")


def wind_chime():
    parts = [log("post", (0, 0, 0.0), (0, 0, 1.95), 0.045, rings=False), log("arm", (0, 0, 1.85), (0.46, 0, 1.92), 0.026, rings=False)]
    parts.append(stone("ps", (0.08, 0.06, 0.04), 0.1, 1))
    st = tube("st", [(0.4, 0, 1.9), (0.4, 0, 1.72)], 0.007, 4)
    paint(st, ROPE, ao=0.0, mat="rope")
    disc = cyl("disc", (0.4, 0, 1.7), 0.13, 0.13, 0.025, segs=14)
    paint(disc, PLANK, ao=0.0, mat="wood")
    parts += [st, disc]
    cols = ["f6c7c0", "bfe6f5", "ffe4b5", "f7a8b8", "d8f0c8"]
    for i in range(5):
        a = 2 * math.pi * i / 5
        x, y = 0.4 + math.cos(a) * 0.1, math.sin(a) * 0.1
        ln = 0.22 + 0.07 * (i % 3)
        s = tube("s", [(x, y, 1.7), (x, y, 1.7 - ln)], 0.005, 4)
        paint(s, ROPE, ao=0.0, mat="rope")
        if i % 2 == 0:
            t = cyl("tube", (x, y, 1.7 - ln - 0.2), 0.018, 0.018, 0.2, segs=8)
            paint(t, hexcol("bfe6f5"), ao=0.0, noise_amt=0.02, mat="metal")
        else:
            t = lathe("shell", [(0.0, 0.0), (0.05, 0.01), (0.0, 0.07)], 8, loc=(x, y, 1.7 - ln - 0.06))
            paint(t, hexcol(cols[i]), ao=0.0, mat="plain")
        parts += [s, t]
    s = tube("sc", [(0.4, 0, 1.7), (0.4, 0, 1.22)], 0.005, 4)
    paint(s, ROPE, ao=0.0, mat="rope")
    sail = box("sail", (0.4, 0, 1.15), (0.1, 0.01, 0.14), (0, math.pi / 4, 0))
    paint(sail, RED, ao=0.0, mat="painted")
    parts += [s, sail]
    join(parts, "WindChime")


def gramophone():
    parts = []
    cab = box("cab", (0, 0, 0.36), (0.56, 0.5, 0.72), bev=0.03, seg=2)
    paint(cab, hexcol("7a4a2a"), ao=0.25, ao_h=0.3, mat="wood",
          fn=lambda co, n: hexcol("5a3420") if (abs(n.y) > 0.6 and abs(co.x) < 0.2 and 0.12 < co.z < 0.58
                                                 and (abs(abs(co.x) - 0.19) < 0.012 or abs(co.z - 0.13) < 0.012 or abs(co.z - 0.57) < 0.012)) else None)
    knob = sphere("knob", (0.12, -0.26, 0.36), 0.025, segs=8, rings=5)
    _iron(knob, BRASS, "metal")
    box2 = box("box", (0, 0, 0.79), (0.46, 0.42, 0.14), bev=0.02, seg=2)
    paint(box2, hexcol("9a5a32"), ao=0.1, mat="wood")
    disc = cyl("disc", (-0.04, -0.02, 0.86), 0.17, 0.17, 0.012, segs=20)
    paint(disc, hexcol("1d1d22"), ao=0.0, noise_amt=0.02, mat="plain",
          fn=lambda co, n: RED if math.hypot(co.x + 0.04, co.y + 0.02) < 0.055 else (0.6 if int(math.hypot(co.x + 0.04, co.y + 0.02) * 90) % 2 == 0 else None))
    crank = tube("crank", [(0.23, -0.05, 0.79), (0.32, -0.05, 0.79), (0.32, -0.05, 0.7), (0.37, -0.05, 0.7)], 0.011, 5)
    _iron(crank, BRASS, "metal")
    neck = tube("neck", [(0.14, 0.14, 0.86), (0.16, 0.18, 1.0), (0.12, 0.14, 1.12), (0.04, 0.02, 1.2)], [0.02, 0.022, 0.028, 0.04], 8)
    _iron(neck, BRASS, "metal")
    # раструб смотрит вперёд-вверх (−Y)
    horn = lathe("horn", [(0.04, 0.0), (0.07, 0.12), (0.13, 0.26), (0.24, 0.38), (0.3, 0.42), (0.28, 0.42), (0.22, 0.37), (0.11, 0.25), (0.05, 0.11), (0.02, 0.0)], 18,
                 loc=(0.04, 0.02, 1.2), rot=(0.95, 0, 0.25))
    paint(horn, hexcol("e8b84a"), ao=0.15, ao_h=0.4, noise_amt=0.04, mat="metal")
    arm = tube("arm", [(0.14, 0.14, 0.9), (0.06, 0.02, 0.885), (-0.02, -0.06, 0.875)], 0.01, 5)
    _iron(arm, BRASS, "metal")
    parts += [cab, knob, box2, disc, crank, neck, horn, arm]
    for sx in (-1, 1):
        for sy in (-1, 1):
            ft = cyl("ft", (sx * 0.22, sy * 0.19, 0.0), 0.035, 0.045, 0.04, segs=8)
            paint(ft, hexcol("5a3420"), ao=0.0, mat="wood")
            parts.append(ft)
    join(parts, "Gramophone")


BUILDERS = {
    "camp_table": camp_table, "camp_stool": camp_stool, "rocking_chair": rocking_chair, "camp_shelf": camp_shelf,
    "decor_chest": decor_chest, "rug_wool": rug_wool, "rug_straw": rug_straw, "garland_flags": garland_flags,
    "garland_lights": garland_lights, "lantern_post": lantern_post, "paper_lantern": paper_lantern, "stone_lantern": stone_lantern,
    "flower_tub": flower_tub, "flower_barrow": flower_barrow, "flower_arch": flower_arch, "plank_path": plank_path,
    "stone_path": stone_path, "picket_fence": picket_fence, "bamboo_fence": bamboo_fence, "garden_gate": garden_gate,
    "sign_camp": sign_camp, "sign_arrows": sign_arrows, "wash_stand": wash_stand, "bird_feeder": bird_feeder,
    "weather_vane": weather_vane, "log_stack": log_stack, "wind_chime": wind_chime, "gramophone": gramophone,
}
