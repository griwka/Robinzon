"""Глава 6 — Остров Вулкана: доктор Вера, черепаха и загон черепах, горячие источники и лечебница;
алоэ, дикий кофе, перец на грядке, горелое дерево, рудная жила, обсидиан, базальтовые столбы;
кузница, каменный мосток и колышки под него; стена кратера, выступы для подъёма, бортик лавового озера;
Огненный храм (вход и каменная дверь), монолит, каменный жёлоб, чаша, трещина с лавой, холодный камень;
маяк Огонь кратера (сломанный и починенный); огнеупорные рукавицы на герое; железная кирка.

Координаты: Blender (x, y, z) → Godot (x, z, −y). «Вперёд» в Godot (+Z) — это −Y в Blender."""
import math

import bmesh

from kit import (box, cyl, displace, empty, from_bm, hexcol, ico, join, lathe, leaf, paint, remesh, rnd, set_origin,
                 set_parent, shade, sphere, subsurf, tube)
from models_buildings import log, plank, stone
from models_ice import _block, _piece

BASALT = hexcol("4a4648")
BASALT_L = hexcol("6a6466")
RED_STONE = hexcol("a0523a")
OBSIDIAN = hexcol("2a2438")
LAVA = hexcol("ff7a2a")
EMBER = hexcol("ffb03a")
IRON = hexcol("4a4c52")
SKIN = hexcol("e8b896")
WATER = hexcol("5fd0c8")
LEAF = hexcol("4f9a4a")


def _flat(ob):
    """Плоские грани (базальт, обсидиан — гранёный камень, а не мыльный)."""
    for p in ob.data.polygons:
        p.use_smooth = False
    return ob


def _slab(name, loc, size, cuts=10):
    """Брусок с частой сеткой (на нём проступают вырезанные рисунки)."""
    ob = _block(name, size[0], size[1], size[2], cuts=cuts, z0=loc[2] - size[2] / 2)
    ob.location = (loc[0], loc[1], 0)
    return ob


def _basalt_fn(base=BASALT):
    """Шестигранные столбы: светлые рёбра и торцы, тёмные щели между столбами."""
    def f(co, n):
        if n.z > 0.6:
            return shade(base, 1.25)
        a = math.atan2(co.y, co.x) * 6
        if (co.x * 2.3 + co.y * 1.7) % 0.55 < 0.05:
            return shade(base, 0.6)
        if math.sin(co.z * 3.0 + a) > 0.93:
            return BASALT_L
        return None
    return f


# ================================================================== доктор Вера
def vera():
    """Доктор Вера: около шестидесяти, полная и тёплая. Пёстрый платок, вязаная кофта поверх платья,
    фартук с карманами, из которых торчат травы, в руке — кружка. Узлы Body и Head."""
    dress = hexcol("7a4a6a")
    cardigan = hexcol("d9a04a")
    body = lathe("vb", [(0.0, 0.0), (0.36, 0.02), (0.38, 0.3), (0.34, 0.65), (0.3, 0.92), (0.2, 1.05), (0.0, 1.07)], 22)
    subsurf(body, 1)
    paint(body, dress, ao=0.0, noise_amt=0.06,
          fn=lambda co, n: (cardigan if co.z > 0.55 and abs(co.x) > 0.08 else (shade(dress, 0.85) if co.z < 0.08 else None)))
    parts = [body]
    apron = box("ap", (0, 0.28, 0.42), (0.42, 0.06, 0.6), (0.06, 0, 0), bev=0.03)
    paint(apron, hexcol("f2ead8"), ao=0.0, fn=lambda co, n: hexcol("c8b8a0") if abs(co.z - 0.42) < 0.02 else None)
    parts.append(apron)
    for sx in (-1, 1):
        pk = box("pk", (sx * 0.11, 0.32, 0.3), (0.15, 0.04, 0.14), bev=0.02)
        paint(pk, hexcol("e8dcc4"), ao=0.0)
        parts.append(pk)
        for k in range(3):   # травы из карманов
            st = tube("hb", [(sx * 0.11 + (k - 1) * 0.03, 0.33, 0.33), (sx * 0.13 + (k - 1) * 0.05, 0.36, 0.48)], 0.012, 4)
            paint(st, hexcol("6f9a4a"), ao=0.0)
            parts.append(st)
    for sx in (-1, 1):
        a = tube("va", [(sx * 0.32, 0, 0.95), (sx * 0.4, 0.06, 0.72), (sx * 0.3, 0.2, 0.6)], [0.1, 0.09, 0.085], 10)
        paint(a, cardigan, ao=0.0, fn=lambda co, n: 0.88 if int(co.z * 30) % 2 else None)
        hd = sphere("vh", (sx * 0.26, 0.26, 0.6), 0.07)
        paint(hd, SKIN, ao=0.0)
        shoe = sphere("vs", (sx * 0.13, 0.08, 0.03), 0.09, (0.9, 1.4, 0.5))
        paint(shoe, hexcol("4a3020"), ao=0.0)
        parts += [a, hd, shoe]
    mug = lathe("mg", [(0.0, 0.0), (0.06, 0.0), (0.065, 0.12), (0.0, 0.12)], 12, loc=(0.24, 0.32, 0.56))
    paint(mug, hexcol("f2f2f2"), ao=0.0, fn=lambda co, n: hexcol("c8403a") if abs(co.z - 0.62) < 0.02 else None)
    parts.append(mug)
    b = join(parts, "Body")
    set_origin(b, (0, 0, 0))
    hp = [sphere("hd", (0, 0, 1.36), 0.27, segs=26, rings=14)]
    paint(hp[0], SKIN, ao=0.0)
    hair = sphere("hr", (0, -0.04, 1.4), 0.28, (1.05, 1.0, 0.9))
    displace(hair, 0.03, 0.05, "VORONOI")
    paint(hair, hexcol("cfc8c0"), ao=0.0, noise_amt=0.15, nscale=30)
    scarf = sphere("sc", (0, -0.03, 1.48), 0.29, (1.05, 1.05, 0.75))
    paint(scarf, hexcol("d8443a"), ao=0.0,
          fn=lambda co, n: hexcol("ffd23f") if (math.sin(co.x * 40) * math.sin(co.y * 40) > 0.6) else (hexcol("4f9a4a") if math.sin(co.x * 25 + co.z * 20) > 0.85 else None))
    knot = sphere("kn", (0, -0.27, 1.32), 0.07, (1.2, 0.8, 0.8))
    paint(knot, hexcol("d8443a"), ao=0.0)
    hp += [hair, scarf, knot]
    for sx in (-1, 1):
        w = sphere("w", (sx * 0.1, 0.23, 1.38), 0.045, (1, 0.42, 0.85))
        paint(w, hexcol("ffffff"), ao=0.0, noise_amt=0)
        i = sphere("i", (sx * 0.1, 0.25, 1.378), 0.026, (1, 0.4, 0.85))
        paint(i, hexcol("6a4a2a"), ao=0.0, noise_amt=0)
        lid = tube("ld", [(sx * 0.05, 0.25, 1.405), (sx * 0.15, 0.24, 1.405)], 0.012, 5)   # добрый прищур
        paint(lid, hexcol("8a5a4a"), ao=0.0)
        ch = sphere("ck", (sx * 0.17, 0.2, 1.3), 0.05, (1, 0.4, 0.7))
        paint(ch, hexcol("f29a8a"), ao=0.0, noise_amt=0)
        hp += [w, i, lid, ch]
    nose = sphere("ns", (0, 0.27, 1.33), 0.045, (0.9, 1.0, 0.9))
    paint(nose, shade(SKIN, 0.93), ao=0.0)
    mouth = tube("mo", [(-0.06, 0.245, 1.255), (0.0, 0.258, 1.24), (0.06, 0.245, 1.255)], 0.012, 6)
    paint(mouth, hexcol("8a3a32"), ao=0.0)
    hp += [nose, mouth]
    h = join(hp, "Head")
    set_origin(h, (0, 0, 1.08))
    set_parent(h, b)


# ================================================================== черепаха
def tortoise():
    """Гигантская черепаха: высокий панцирь с щитками, толстые ноги, морщинистая шея. Узлы Body и Head."""
    shell = sphere("sh", (0, 0, 0.42), 0.48, (1.0, 1.25, 0.72), segs=24, rings=14)

    def scutes(co, n):
        u = math.atan2(co.y, co.x) * 3.0
        v = co.z * 9.0
        if (u % 1.0) < 0.07 or (v % 1.0) < 0.07:
            return hexcol("4a3a24")
        if co.z < 0.25:
            return hexcol("8a7a52")
        return None
    paint(shell, hexcol("8a6a3a"), ao=0.0, noise_amt=0.1, nscale=6, fn=scutes)
    rim = tube("rm", [(math.cos(a) * 0.5, math.sin(a) * 0.62, 0.22) for a in [k * math.pi / 12 for k in range(25)]], 0.05, 6, caps=False)
    paint(rim, hexcol("6a5232"), ao=0.0)
    parts = [shell, rim]
    for sx in (-1, 1):
        for sy in (-1, 1):
            leg = tube("lg", [(sx * 0.36, sy * 0.38, 0.28), (sx * 0.42, sy * 0.42, 0.0)], [0.12, 0.13], 10)
            paint(leg, hexcol("8a8a7a"), ao=0.0, fn=lambda co, n: 0.85 if math.sin(co.z * 60) > 0.5 else None)
            parts.append(leg)
    tail = cyl("tl", (0, -0.62, 0.2), 0.05, 0.0, 0.15, (-2.0, 0, 0), 6)
    paint(tail, hexcol("8a8a7a"), ao=0.0)
    parts.append(tail)
    b = join(parts, "Body")
    set_origin(b, (0, 0, 0))
    neck = tube("nk", [(0, 0.5, 0.32), (0, 0.66, 0.4), (0, 0.76, 0.46)], [0.11, 0.1, 0.095], 10)
    paint(neck, hexcol("8a8a7a"), ao=0.0, fn=lambda co, n: 0.82 if math.sin(co.y * 70) > 0.4 else None)
    hd = sphere("hd", (0, 0.85, 0.48), 0.12, (0.95, 1.25, 0.85))
    paint(hd, hexcol("8a8a7a"), ao=0.0)
    hp = [neck, hd]
    for sx in (-1, 1):
        e = sphere("ey", (sx * 0.07, 0.92, 0.53), 0.022)
        paint(e, hexcol("1d1d1d"), ao=0.0, noise_amt=0)
        hp.append(e)
    mouth = tube("mo", [(-0.06, 0.95, 0.45), (0.0, 0.97, 0.44), (0.06, 0.95, 0.45)], 0.01, 5)
    paint(mouth, hexcol("3a3a32"), ao=0.0)
    hp.append(mouth)
    h = join(hp, "Head")
    set_origin(h, (0, 0.5, 0.32))
    set_parent(h, b)


def tortoise_pen():
    """Загон черепах: низкая стенка из камней кольцом, деревянная калитка, корыто с тыквой, навесик от солнца."""
    parts = []
    r = rnd(4)
    for k in range(22):
        a = 2 * math.pi * k / 22
        if abs(math.sin(a / 2)) < 0.14:
            continue   # калитка спереди (−Y)
        parts.append(stone("st", (math.cos(a - math.pi / 2) * 1.9, math.sin(a - math.pi / 2) * 1.9, 0.12), r.uniform(0.2, 0.28), k, BASALT_L))
    for sx in (-1, 1):
        parts.append(plank("gp", (sx * 0.45, -1.9, 0.35), (0.08, 0.08, 0.7), col=hexcol("8a5a32")))
    parts.append(plank("gb", (0, -1.9, 0.5), (0.9, 0.05, 0.08), col=hexcol("c99a5e")))
    trough = box("tr", (0.8, 0.6, 0.12), (0.9, 0.4, 0.22), bev=0.04)
    paint(trough, hexcol("9a6a3e"), ao=0.0)
    pk = sphere("pk", (0.8, 0.6, 0.3), 0.16, (1.0, 1.0, 0.75))
    paint(pk, hexcol("f08a24"), ao=0.0, fn=lambda co, n: 0.85 if math.sin(math.atan2(co.y - 0.6, co.x - 0.8) * 8) > 0.7 else None)
    parts += [trough, pk]
    for x, y in ((-1.1, 0.6), (-0.3, 0.6), (-1.1, 1.3), (-0.3, 1.3)):
        parts.append(log("ps", (x, y, 0.0), (x, y, 1.2), 0.05))
    roof = box("rf", (-0.7, 0.95, 1.25), (1.1, 0.95, 0.06), (0.1, 0, 0), bev=0.02)
    paint(roof, hexcol("d6ad55"), ao=0.0, noise_amt=0.2, nscale=20, fn=lambda co, n: 0.85 if int(co.x * 12) % 2 else None)
    parts.append(roof)
    join(parts, "TortoisePen")


# ================================================================== источники и лечебница
def hot_springs():
    """Три каменные чаши с голубой горячей водой. Центры (Godot): (−1.4, 0.2), (1.3, −0.4), (0.2, 1.6)."""
    parts = []
    r = rnd(8)
    for (x, y, rad) in ((-1.4, -0.2, 1.1), (1.3, 0.4, 0.95), (0.2, -1.6, 0.85)):
        basin = lathe("bs", [(rad + 0.25, 0.0), (rad + 0.3, 0.22), (rad + 0.05, 0.32), (rad - 0.05, 0.2), (0.0, 0.05)], 20, loc=(x, y, 0))
        displace(basin, 0.04, 0.2)
        paint(basin, BASALT_L, ao=0.2, ao_h=0.3, fn=lambda co, n: hexcol("d8cfa8") if n.z > 0.6 and co.z > 0.25 else None)
        water = cyl("wt", (x, y, 0.2), rad - 0.02, rad - 0.02, 0.04, segs=20)
        paint(water, WATER, ao=0.0, noise_amt=0, fn=lambda co, n: hexcol("bff4ee") if math.sin(co.x * 7 + co.y * 5) > 0.8 else None)
        parts += [basin, water]
        for k in range(5):
            a = r.uniform(0, 2 * math.pi)
            parts.append(stone("rs", (x + math.cos(a) * (rad + 0.4), y + math.sin(a) * (rad + 0.4), 0.1), r.uniform(0.12, 0.2), k, BASALT))
    # кружка и пучок трав на краю
    mug = lathe("mg", [(0.0, 0.0), (0.06, 0.0), (0.065, 0.12), (0.0, 0.12)], 12, loc=(-0.2, 0.2, 0.25))
    paint(mug, hexcol("c8a050"), ao=0.0)
    parts.append(mug)
    join(parts, "HotSprings")


def clinic():
    """Лечебница Веры: домик из камня и досок, крыльцо, пучки трав под навесом, бочка, вывеска с листиком."""
    parts = []
    walls = box("wl", (0, 0, 1.0), (2.8, 2.2, 2.0), bev=0.04)
    paint(walls, hexcol("e8dcc4"), ao=0.25, ao_h=0.6, fn=lambda co, n: (BASALT_L if co.z < 0.45 else None))
    parts.append(walls)
    for sx in (-1, 1):
        rf = box("rf", (sx * 0.78, 0, 2.3), (1.75, 2.6, 0.08), (0, sx * 0.55, 0), bev=0.03)
        paint(rf, hexcol("b8583a"), ao=0.0, fn=lambda co, n: 0.85 if int(co.y * 8) % 2 else None)
        parts.append(rf)
    door = box("dr", (0.4, -1.12, 0.8), (0.75, 0.06, 1.5), bev=0.03)
    paint(door, hexcol("6f9a8a"), ao=0.0, fn=lambda co, n: hexcol("c9a050") if abs(co.x - 0.65) < 0.04 and abs(co.z - 0.85) < 0.05 else None)
    win = box("wn", (-0.75, -1.12, 1.2), (0.6, 0.05, 0.5), bev=0.02)
    paint(win, hexcol("bfe8f0"), ao=0.0, fn=lambda co, n: hexcol("8a5a32") if abs(co.x + 0.75) < 0.03 or abs(co.z - 1.2) < 0.03 else None)
    porch = box("pr", (0, -1.5, 0.08), (2.8, 0.8, 0.12), bev=0.02)
    paint(porch, hexcol("c99a5e"), ao=0.0, fn=lambda co, n: 0.88 if int(co.x * 6) % 2 else None)
    parts += [door, win, porch]
    for x in (-1.3, 1.3):
        parts.append(log("pp", (x, -1.8, 0.1), (x, -1.8, 1.9), 0.06))
    awn = box("aw", (0, -1.55, 1.95), (2.9, 0.9, 0.05), (-0.25, 0, 0), bev=0.02)
    paint(awn, hexcol("4f9a8a"), ao=0.0, fn=lambda co, n: hexcol("f2ead8") if int(co.x * 4) % 2 else None)
    parts.append(awn)
    r = rnd(3)
    for k in range(6):   # пучки трав
        x = -1.1 + k * 0.45
        st = tube("hs", [(x, -1.75, 1.75), (x, -1.75, 1.45)], 0.01, 4)
        paint(st, hexcol("8a6a4a"), ao=0.0)
        bun = sphere("hb", (x, -1.75, 1.38), 0.1, (0.8, 0.8, 1.4))
        paint(bun, shade(hexcol("6f9a4a"), r.uniform(0.8, 1.15)), ao=0.0, noise_amt=0.2, nscale=30)
        parts += [st, bun]
    barrel = lathe("br", [(0.0, 0.0), (0.28, 0.0), (0.32, 0.35), (0.28, 0.7), (0.0, 0.7)], 14, loc=(1.6, -1.2, 0))
    paint(barrel, hexcol("8a5a32"), ao=0.0, fn=lambda co, n: IRON if abs(co.z - 0.15) < 0.03 or abs(co.z - 0.55) < 0.03 else None)
    sign = box("sg", (-1.25, -1.86, 1.55), (0.5, 0.04, 0.32), bev=0.02)
    paint(sign, hexcol("f2ead8"), ao=0.0,
          fn=lambda co, n: hexcol("4f9a4a") if n.y < -0.5 and (co.x + 1.25) ** 2 * 8 + (co.z - 1.55) ** 2 * 20 < 0.08 else None)
    chim = box("ch", (0.9, 0.5, 2.6), (0.35, 0.35, 0.8), bev=0.03)
    paint(chim, BASALT_L, ao=0.0)
    parts += [barrel, sign, chim]
    join(parts, "Clinic")


# ================================================================== растения
def aloe_plant():
    """Алоэ: розетка толстых сизо-зелёных листьев с белыми крапинками и зубчиками."""
    r = rnd(5)
    leaves = []
    for k in range(9):
        a = k * 2.4
        tilt = 0.5 + (k % 3) * 0.15
        lf = leaf("leaf", (0, 0, 0.05), (math.cos(a) * tilt, math.sin(a) * tilt, 1.0), r.uniform(0.45, 0.6), 0.09,
                  droop=0.15, fold=0.6, shape=lambda t: 1.0 - t * 0.9)
        paint(lf, hexcol("6fbf7a"), ao=0.0, fn=lambda co, n: hexcol("e8f2e0") if math.sin(co.x * 60) * math.sin(co.y * 60) > 0.7 else None)
        leaves.append(lf)
    pot = sphere("bs", (0, 0, 0.0), 0.18, (1.0, 1.0, 0.4))
    paint(pot, hexcol("5a4a3a"), ao=0.0)
    c = join(leaves + [pot], "Aloe")
    from kit import solidify
    solidify(c, 0.02)


def coffee_bush():
    """Дикий кофе: куст с глянцевыми тёмными листьями и гроздьями красных ягод у веток."""
    r = rnd(23)
    blobs = []
    for k in range(6):
        a = k * 1.1
        blobs.append(sphere("cb", (math.cos(a) * 0.25, math.sin(a) * 0.25, 0.7 + r.uniform(-0.15, 0.25)), 0.38, (1.0, 1.0, 0.85)))
    c = join(blobs, "bush_leaf")
    remesh(c, 0.08, 2)
    displace(c, 0.06, 0.15)
    paint(c, hexcol("2f6a3a"), ao=0.3, ao_h=0.5, noise_amt=0.2, nscale=10, fn=lambda co, n: hexcol("4a8a4a") if n.z > 0.7 else None)
    trunk = tube("tr", [(0, 0, 0), (0.05, 0, 0.5)], [0.05, 0.035], 6)
    paint(trunk, hexcol("6b4a32"), ao=0.0)
    parts = [c, trunk]
    for k in range(22):
        a = r.uniform(0, 2 * math.pi)
        d = r.uniform(0.35, 0.55)
        z = r.uniform(0.45, 1.05)
        b = sphere("bb", (math.cos(a) * d, math.sin(a) * d, z), 0.045, segs=8, rings=5)
        paint(b, hexcol("c8302a"), ao=0.0, noise_amt=0, fn=lambda co, n: hexcol("ff8a6a") if n.z > 0.7 else None)
        parts.append(b)
    join(parts, "Coffee")


def crop_pepper():
    """Перец на грядке: кустики с узкими листьями и красными стручками."""
    r = rnd(17)
    leaves = []
    parts = []
    for (x, y) in ((-0.35, 0.0), (0.0, 0.1), (0.35, -0.05)):
        st = tube("st", [(x, y, 0.15), (x + 0.02, y, 0.55)], 0.02, 5)
        paint(st, hexcol("4f7a3a"), ao=0.0)
        parts.append(st)
        for k in range(5):
            a = k * 1.3 + r.uniform(0, 0.5)
            lf = leaf("leaf", (x, y, 0.3 + k * 0.05), (math.cos(a), math.sin(a), 0.4), 0.2, 0.06, droop=0.5)
            paint(lf, shade(LEAF, r.uniform(0.85, 1.1)), ao=0.0)
            leaves.append(lf)
        for k in range(3):
            a = k * 2.1 + 0.4
            pp = tube("pp", [(x + math.cos(a) * 0.08, y + math.sin(a) * 0.08, 0.45), (x + math.cos(a) * 0.12, y + math.sin(a) * 0.12, 0.3),
                             (x + math.cos(a) * 0.13, y + math.sin(a) * 0.13, 0.24)], [0.035, 0.03, 0.006], 8)
            paint(pp, hexcol("e8342a"), ao=0.0, fn=lambda co, n: hexcol("ff8a7a") if n.x > 0.6 else None)
            parts.append(pp)
    join(parts, "Crop")
    join(leaves, "crop_leaf")


def _charred(seed):
    """Горелое дерево: чёрный растрескавшийся ствол с обломанными сучьями; в трещинах тлеет."""
    r = rnd(seed)
    pts = [(0, 0, -0.1), (0.05, 0.02, 1.2), (0.15 * r.uniform(-1, 1), 0.1, 2.4), (0.2, 0.1 * r.uniform(-1, 1), 3.4)]
    trunk = tube("tr", pts, [0.28, 0.22, 0.15, 0.06], 10)
    paint(trunk, hexcol("2e2a28"), ao=0.0, noise_amt=0.2, nscale=8,
          fn=lambda co, n: (hexcol("ff7a2a") if math.sin(co.z * 13 + math.atan2(co.y, co.x) * 4) > 0.97 else
                            (hexcol("4a4442") if math.sin(co.z * 30) > 0.6 else None)))
    parts = [trunk]
    for k in range(4):
        z = r.uniform(1.2, 3.0)
        a = r.uniform(0, 2 * math.pi)
        br = tube("br", [(0.05, 0.02, z), (math.cos(a) * 0.7, math.sin(a) * 0.7, z + 0.5)], [0.07, 0.02], 6)
        paint(br, hexcol("2e2a28"), ao=0.0)
        parts.append(br)
    for k in range(3):
        root = tube("rt", [(0, 0, 0.1), (math.cos(k * 2.1) * 0.55, math.sin(k * 2.1) * 0.55, -0.05)], [0.12, 0.04], 6)
        paint(root, hexcol("2e2a28"), ao=0.0)
        parts.append(root)
    join(parts, "Trunk")


def charred_tree_a():
    _charred(3)


def charred_tree_b():
    _charred(11)


def ore_vein():
    """Рудная жила: глыба тёмного камня с рыжими ржавыми прожилками и блёстками."""
    s = ico("ov", (0, 0, 0.5), 0.85, (1.25, 1.0, 0.75), sub=3)
    displace(s, 0.25, 0.6, "VORONOI")
    paint(s, hexcol("5e5658"), ao=0.25, ao_h=0.5, noise_amt=0.1,
          fn=lambda co, n: (hexcol("c8643a") if math.sin(co.x * 6 + co.z * 9) > 0.75 else
                            (hexcol("e8a050") if math.sin(co.x * 23 + co.y * 17) > 0.95 else None)))
    join([s], "OreVein")


def obsidian_rock():
    """Обсидиан: острые чёрные глыбы с фиолетовым отливом и гладкими гранями."""
    r = rnd(9)
    parts = []
    for k in range(4):
        a = k * 1.6
        c = _flat(cyl("ob", (math.cos(a) * 0.3, math.sin(a) * 0.3, 0.0), r.uniform(0.25, 0.35), 0.02, r.uniform(0.6, 1.2),
                      (r.uniform(-0.3, 0.3), r.uniform(-0.3, 0.3), a), segs=5))
        paint(c, OBSIDIAN, ao=0.0, noise_amt=0.0,
              fn=lambda co, n: (hexcol("8a6ab8") if n.z > 0.3 and math.sin(co.x * 9) > 0.3 else (hexcol("4a3a6a") if n.x > 0.5 else None)))
        parts.append(c)
    base = ico("bs", (0, 0, 0.1), 0.5, (1.2, 1.0, 0.4), sub=1)
    paint(base, BASALT, ao=0.0)
    parts.append(base)
    join(parts, "Obsidian")


def _basalt(seed):
    """Базальтовые столбы: тесная группа шестигранных колонн разной высоты, вытянута вдоль X (3 м)."""
    r = rnd(seed)
    parts = []
    for i in range(7):
        for j in range(2):
            x = -1.35 + i * 0.45 + (0.22 if j else 0.0)
            y = -0.25 + j * 0.42
            h = r.uniform(1.8, 2.8) * (0.85 if j else 1.0)
            c = _flat(cyl("bc", (x, y, -0.1), 0.24, 0.24, h, segs=6))
            parts.append(c)
    b = join(parts, "Basalt")
    paint(b, BASALT, ao=0.25, ao_h=0.8, noise_amt=0.08, fn=_basalt_fn())


def basalt_a():
    _basalt(4)


def basalt_b():
    _basalt(19)


# ================================================================== кузница, мосток
def forge():
    """Кузница: каменный горн под кирпичной трубой, мехи, наковальня на чурбаке, бочка с водой, клещи.
    Горн спереди (−Y Blender); FirePoint — в горне."""
    parts = []
    hearth = _block("hr", 1.2, 0.9, 0.9, cuts=6)
    paint(hearth, BASALT_L, ao=0.25, ao_h=0.4, fn=lambda co, n: shade(BASALT_L, 0.8) if (co.z * 5) % 1.0 < 0.1 else None)
    pit = box("pt", (0, -0.2, 0.92), (0.7, 0.45, 0.06))
    paint(pit, hexcol("2a2220"), ao=0.0, fn=lambda co, n: LAVA if math.sin(co.x * 30) * math.sin(co.y * 30) > 0.3 else None)
    hood = cyl("hd", (0, 0.05, 1.3), 0.7, 0.25, 0.7, segs=4, rot=(0, 0, math.pi / 4))
    paint(hood, hexcol("b8583a"), ao=0.0, fn=lambda co, n: hexcol("e8d8c0") if (co.z * 7) % 1.0 < 0.1 else None)
    chim = box("ch", (0, 0.05, 2.4), (0.35, 0.35, 1.5), bev=0.03)
    paint(chim, hexcol("b8583a"), ao=0.0, fn=lambda co, n: hexcol("e8d8c0") if (co.z * 7) % 1.0 < 0.1 else None)
    for sx in (-1, 1):
        parts.append(log("ps", (sx * 0.5, -0.35, 0.9), (sx * 0.4, -0.2, 1.35), 0.05))
    bel = sphere("bl", (0.85, 0.15, 0.7), 0.25, (1.2, 0.8, 0.45))
    paint(bel, hexcol("8a5a32"), ao=0.0, fn=lambda co, n: 0.8 if math.sin(co.z * 60) > 0.5 else None)
    stump = cyl("su", (-1.1, -0.5, 0.0), 0.28, 0.3, 0.5, segs=12)
    paint(stump, hexcol("8a5a32"), ao=0.0, fn=lambda co, n: hexcol("d6b07a") if n.z > 0.8 else None)
    anvil = box("an", (-1.1, -0.5, 0.62), (0.5, 0.2, 0.18), bev=0.03)
    horn = cyl("ah", (-1.35, -0.5, 0.64), 0.08, 0.0, 0.25, (0, -math.pi / 2, 0), 8)
    paint(anvil, IRON, ao=0.0)
    paint(horn, IRON, ao=0.0)
    barrel = lathe("br", [(0.0, 0.0), (0.25, 0.0), (0.28, 0.3), (0.25, 0.6), (0.0, 0.58)], 14, loc=(1.0, -0.6, 0))
    paint(barrel, hexcol("8a5a32"), ao=0.0, fn=lambda co, n: (hexcol("5fb0d8") if n.z > 0.8 else (IRON if abs(co.z - 0.15) < 0.03 else None)))
    tongs = tube("tg", [(-0.9, -0.55, 0.72), (-0.6, -0.55, 0.75), (-0.5, -0.5, 0.74)], 0.015, 5)
    paint(tongs, IRON, ao=0.0)
    parts += [hearth, pit, hood, chim, bel, stump, anvil, horn, barrel, tongs]
    f = join(parts, "Forge")
    empty("FirePoint", (0, -0.2, 0.95), f)


def stone_bridge():
    """Каменный мосток над лавой: плиты по двум опорным камням, длина 3,4 м вдоль Y, ширина 1,6 м."""
    parts = []
    r = rnd(6)
    for k in range(5):
        y = -1.36 + k * 0.68
        sl = box("sl", (r.uniform(-0.05, 0.05), y, 0.18), (1.5, 0.64, 0.14), (0, 0, r.uniform(-0.05, 0.05)), bev=0.04)
        paint(sl, BASALT_L, ao=0.0, noise_amt=0.12, fn=lambda co, n: shade(BASALT_L, 1.15) if n.z > 0.6 else None)
        parts.append(sl)
    for y in (-1.6, 1.6):
        for x in (-0.6, 0.6):
            parts.append(stone("ps", (x, y, 0.05), 0.28, int(x * 10 + y * 3), BASALT))
    join(parts, "Bridge")


def bridge_marker():
    """Колышки с верёвкой — место, где Лёва клал мостки через лаву."""
    parts = []
    for y in (-1.6, 1.6):
        for x in (-0.7, 0.7):
            parts.append(log("st", (x, y, 0.0), (x, y, 0.7), 0.04, col=hexcol("8a5a32"), rings=False))
    for x in (-0.7, 0.7):
        rp = tube("rp", [(x, -1.6, 0.6), (x, 0.0, 0.45), (x, 1.6, 0.6)], 0.015, 5)
        paint(rp, hexcol("d4b483"), ao=0.0)
        parts.append(rp)
    flag = box("fl", (-0.7, -1.6, 0.62), (0.03, 0.18, 0.12))
    paint(flag, hexcol("c8403a"), ao=0.0)
    parts.append(flag)
    join(parts, "BridgeMarker")


# ================================================================== кратер
def crater_wall():
    """Кусок стены кратера: 3,9 м по дуге радиусом 8,6 м, 8 м в высоту (низ — z=0), лицом наружу (−Y).
    Тесные шестигранные базальтовые столбы, сверху — каменный бортик с золой."""
    R = 8.6
    parts = []
    r = rnd(31)
    for i in range(9):
        x = -1.85 + i * 0.44 + r.uniform(-0.05, 0.05)
        h = r.uniform(7.6, 8.5)
        c = _flat(cyl("cc", (x, -0.15 + r.uniform(-0.12, 0.12), -0.2), 0.27, 0.27, h, segs=6))
        parts.append(c)
    back = box("bk", (0, 0.35, 3.9), (3.9, 0.8, 8.2))
    parts.append(back)
    w = join(parts, "CraterWall")
    me = w.data
    for v in me.vertices:
        x, y, z = v.co
        rr = R + 0.55 - (y + 0.6)
        phi = x / R
        v.co.x = rr * math.sin(phi)
        v.co.y = R - rr * math.cos(phi)
    paint(w, BASALT, ao=0.3, ao_h=1.5, noise_amt=0.08, fn=_basalt_fn())
    lip = tube("lp", [(math.sin(a / R) * (R - 0.1), R - math.cos(a / R) * (R - 0.1), 8.0) for a in [-2.0 + k * 0.4 for k in range(11)]], 0.35, 8)
    lip.scale = (1.0, 1.0, 0.6)
    displace(lip, 0.1, 0.3)
    paint(lip, hexcol("6a6060"), ao=0.0, noise_amt=0.15, fn=lambda co, n: hexcol("9a908a") if n.z > 0.6 else None)
    join([w, lip], "CraterWall")


def rock_holds():
    """Выступы для подъёма по стене кратера на 1 м высоты: обломанные торцы столбов и трещины."""
    parts = []
    for k in range(2):
        z = 0.2 + k * 0.5
        x = -0.2 if k % 2 == 0 else 0.2
        h = box("hl", (x, -0.02, z), (0.32, 0.22, 0.1), (0, 0, 0.1 * (1 - 2 * k)), bev=0.03)
        paint(h, BASALT_L, ao=0.0, fn=lambda co, n: shade(BASALT_L, 1.2) if n.z > 0.5 else None)
        parts.append(h)
    crack = box("ck", (0.0, 0.06, 0.5), (0.05, 0.05, 0.9))
    paint(crack, hexcol("ff7a2a"), ao=0.0, noise_amt=0)
    parts.append(crack)
    join(parts, "RockHolds")


def lava_rim():
    """Бортик вокруг озера лавы на краю кратера: кольцо обломков базальта и застывших натёков."""
    parts = []
    r = rnd(12)
    for k in range(16):
        a = 2 * math.pi * k / 16
        rad = 3.75 + r.uniform(-0.1, 0.15)
        parts.append(stone("rm", (math.cos(a) * rad, math.sin(a) * rad, 0.15), r.uniform(0.32, 0.45), k, BASALT))
    for k in range(8):
        a = r.uniform(0, 2 * math.pi)
        dr = sphere("dr", (math.cos(a) * 3.4, math.sin(a) * 3.4, 0.08), 0.35, (1.4, 0.8, 0.3))
        paint(dr, hexcol("2e2a28"), ao=0.0, fn=lambda co, n: LAVA if math.sin(co.x * 20 + co.y * 13) > 0.85 else None)
        parts.append(dr)
    join(parts, "LavaRim")


# ================================================================== храм
def temple_facade():
    """Вход в Огненный храм, вырезанный в стене кратера: два столба с огненными знаками, тяжёлая перемычка
    с солнцем, лучи которого стекают в чашу, ступени. Лицом наружу (−Y Blender)."""
    parts = []
    for sx in (-1, 1):
        col = box("cl", (sx * 1.25, -0.2, 1.6), (0.6, 0.7, 3.2), bev=0.06)
        paint(col, RED_STONE, ao=0.25, ao_h=1.0, noise_amt=0.1,
              fn=lambda co, n: (EMBER if (n.y < -0.5 and abs(math.sin(co.z * 4.0)) < 0.12) else None))
        parts.append(col)
    lintel = _slab("ln", (0, -0.25, 3.45), (3.4, 0.8, 0.7), cuts=14)

    def sun(co, n):
        if n.y < -0.5:
            dx, dz = co.x, co.z - 3.5
            d = math.hypot(dx, dz)
            if d < 0.18:
                return EMBER
            if d < 0.42 and abs(math.sin(math.atan2(dz, dx) * 5)) < 0.25:
                return hexcol("e8a050")
        return None
    paint(lintel, RED_STONE, ao=0.0, noise_amt=0.1, fn=sun)
    parts.append(lintel)
    frame = box("fr", (0, 0.1, 1.5), (1.95, 0.4, 3.1))
    paint(frame, hexcol("1a1414"), ao=0.0)
    parts.append(frame)
    for k in range(3):
        st = box("sp", (0, -0.55 - k * 0.3, 0.06 + (2 - k) * 0.12), (2.6 - k * 0.1, 0.32, 0.14 + (2 - k) * 0.24), bev=0.03)
        paint(st, BASALT_L, ao=0.0, noise_amt=0.1)
        parts.append(st)
    for sx in (-1, 1):   # огненные чаши у входа
        bw = lathe("bw", [(0.0, 0.0), (0.15, 0.0), (0.12, 0.6), (0.3, 0.75), (0.32, 0.85), (0.0, 0.8)], 12, loc=(sx * 1.9, -0.7, 0))
        paint(bw, BASALT, ao=0.0, fn=lambda co, n: LAVA if co.z > 0.78 and n.z > 0.5 else None)
        parts.append(bw)
    join(parts, "TempleFacade")


def temple_door():
    """Каменная плита-дверь храма (опускается вниз, когда лава наполнит чашу)."""
    d = _slab("dr", (0, -0.05, 1.45), (1.9, 0.3, 2.9), cuts=14)
    paint(d, hexcol("6a4a3a"), ao=0.0, noise_amt=0.12,
          fn=lambda co, n: (EMBER if n.y < -0.5 and math.hypot(co.x, co.z - 1.6) < 0.25 else
                            (hexcol("4a3228") if n.y < -0.5 and abs(math.hypot(co.x, co.z - 1.6) - 0.6) < 0.05 else None)))
    join([d], "TempleDoor")


def monolith():
    """Монолит у входа: плита с рисунком «Солнце в чаше» — лучи стекают по желобам в чашу."""
    slab = _slab("sl", (0, 0, 1.0), (0.9, 0.3, 2.0), cuts=16)

    def pic(co, n):
        if n.y < -0.5:
            dx, dz = co.x, co.z - 1.45
            if math.hypot(dx, dz) < 0.16:
                return EMBER
            for k in range(4):
                a = -math.pi / 2 + (k - 1.5) * 0.45
                px, pz = math.cos(a), math.sin(a)
                t = dx * px + dz * pz
                if 0.2 < t < 0.55 and abs(dx * pz - dz * px) < 0.035:
                    return hexcol("e8a050")
            if abs(dz + 0.85) < 0.05 and abs(dx) < 0.25:
                return hexcol("e8a050")
        return None
    paint(slab, RED_STONE, ao=0.2, ao_h=0.6, noise_amt=0.1, fn=pic)
    base = box("bs", (0, 0, 0.08), (1.2, 0.5, 0.16), bev=0.03)
    paint(base, BASALT, ao=0.0)
    join([slab, base], "Monolith")


def lava_chute():
    """Каменный жёлоб на поворотном круглом камне; носик смотрит вперёд (−Y Blender → +Z Godot)."""
    base = cyl("bs", (0, 0, 0.0), 0.45, 0.42, 0.3, segs=14)
    paint(base, BASALT, ao=0.0, fn=lambda co, n: BASALT_L if n.z > 0.7 else None)
    trough = box("tr", (0, -0.2, 0.42), (0.36, 0.9, 0.2), bev=0.03)
    paint(trough, RED_STONE, ao=0.0, fn=lambda co, n: hexcol("2a1a14") if n.z > 0.7 and abs(co.x) < 0.12 else None)
    spout = cyl("sp", (0, -0.65, 0.42), 0.12, 0.06, 0.2, (math.pi / 2, 0, 0), 8)
    paint(spout, RED_STONE, ao=0.0)
    arrow = box("ar", (0, -0.4, 0.53), (0.08, 0.3, 0.02))
    paint(arrow, EMBER, ao=0.0, noise_amt=0)
    join([base, trough, spout, arrow], "Chute")


def lava_bowl():
    """Каменная чаша на тумбе — сюда должна стечь лава."""
    b = lathe("bw", [(0.0, 0.0), (0.4, 0.0), (0.3, 0.5), (0.55, 0.75), (0.6, 0.95), (0.5, 0.92), (0.0, 0.75)], 18)
    paint(b, RED_STONE, ao=0.2, ao_h=0.4, noise_amt=0.1, fn=lambda co, n: hexcol("2a1a14") if n.z > 0.5 and co.z > 0.8 else None)
    join([b], "LavaBowl")


def lava_crack():
    """Трещина в скале у входа: оттуда сочится лава (сама лава — из игры)."""
    parts = []
    r = rnd(2)
    for k in range(5):
        a = k * 1.25
        parts.append(stone("cr", (math.cos(a) * 0.55, math.sin(a) * 0.55, 0.1), r.uniform(0.25, 0.35), k, BASALT))
    glow = sphere("gl", (0, 0, 0.02), 0.35, (1.0, 1.6, 0.15))
    paint(glow, LAVA, ao=0.0, noise_amt=0)
    parts.append(glow)
    join(parts, "LavaCrack")


def cold_stone():
    """Холодный камень: застывшая чёрная лава, остывшая до сизого, с инеем-налётом пемзы."""
    s = ico("cs", (0, 0, 0.3), 0.45, (1.2, 1.0, 0.7), sub=2)
    displace(s, 0.12, 0.4, "VORONOI")
    paint(s, hexcol("3a3e48"), ao=0.2, ao_h=0.3, noise_amt=0.1, fn=lambda co, n: hexcol("8a909a") if n.z > 0.7 else None)
    join([s], "ColdStone")


# ================================================================== Огонь кратера
def _volcano_tower(restored):
    """Огонь кратера: башня из красного камня с чашей; к чаше с озера ведёт каменный жёлоб с заслонкой.
    У сломанной жёлоб обвалился. FirePoint — где игра зажигает огонь."""
    parts = []
    tower = lathe("tw", [(1.6, 0.0), (1.5, 0.5), (1.3, 3.0), (1.1, 5.5), (1.35, 5.8), (1.35, 6.1), (0.0, 6.1)], 18)
    displace(tower, 0.07, 0.5, "VORONOI")
    paint(tower, RED_STONE, ao=0.3, ao_h=1.0, noise_amt=0.1,
          fn=lambda co, n: (shade(RED_STONE, 0.7) if (co.z * 1.8) % 1.0 < 0.07 else (EMBER if (abs(math.atan2(co.y, co.x) - 1.57) < 0.08 and co.z > 1.0) else None)))
    parts.append(tower)
    door = box("dr", (0, -1.4, 0.85), (0.7, 0.4, 1.6), bev=0.05)
    paint(door, hexcol("1a1414"), ao=0.0)
    parts.append(door)
    for k in range(5):
        a = 2 * math.pi * k / 5 + 0.3
        parts.append(stone("bs", (math.cos(a) * 2.0, math.sin(a) * 2.0, 0.15), 0.35, k, BASALT))
    # жёлоб от озера (сзади, +Y Blender — к центру кратера) к чаше
    if restored:
        ch = box("ch", (0, 2.2, 3.4), (0.5, 3.6, 0.25), (0.6, 0, 0), bev=0.03)
        paint(ch, IRON, ao=0.0, fn=lambda co, n: LAVA if n.z > 0.6 else None)
        gate = box("gt", (0, 1.0, 5.6), (0.6, 0.08, 0.5), bev=0.02)
        paint(gate, IRON, ao=0.0)
        parts += [ch, gate]
    else:
        for k in range(3):
            pc = box("pc", (0.3 * (k - 1), 2.4 + k * 0.4, 0.15), (0.5, 0.9, 0.2), (0.3 * k, 0.2, 0.5 * k), bev=0.03)
            paint(pc, hexcol("6a5a50"), ao=0.0)
            parts.append(pc)
    t = join(parts, "VolcanoTower")
    bowl = lathe("bw", [(0.0, 6.1), (0.6, 6.15), (0.9, 6.5), (0.8, 6.55), (0.0, 6.3)], 18)
    paint(bowl, hexcol("3a2e2a"), ao=0.0, fn=lambda co, n: (LAVA if restored and n.z > 0.5 else None))
    set_parent(bowl, t)
    empty("FirePoint", (0, 0, 6.4), t)


def volcano_tower_ruin():
    _volcano_tower(False)


def volcano_tower():
    _volcano_tower(True)


# ================================================================== рукавицы и кирка
def wear_fire_gloves():
    """Огнеупорные рукавицы: толстые кожаные краги с раструбом до локтя, на ладони — заплатка."""
    leather = hexcol("c8783a")
    for sx, nm in ((-1, "MittenL"), (1, "MittenR")):
        sh = (sx * 0.29, 0, 0.98)
        m = sphere("mt", (sx * 0.345, 0.04, 0.57), 0.095, (0.95, 1.05, 1.2))
        paint(m, leather, ao=0.0, fn=lambda co, n: shade(leather, 0.8) if math.sin(co.z * 80) > 0.85 else None)
        th = sphere("th", (sx * 0.3, 0.11, 0.6), 0.042, (1.0, 1.3, 1.0))
        paint(th, leather, ao=0.0)
        cuff = tube("cf", [(sx * 0.342, 0.035, 0.66), (sx * 0.338, 0.03, 0.78)], [0.1, 0.11], 12)
        paint(cuff, shade(leather, 0.85), ao=0.0, fn=lambda co, n: hexcol("3a2a1a") if abs(co.z - 0.7) < 0.012 else None)
        _piece([m, th, cuff], nm, sh)


def tool_iron_pickaxe():
    """Железная кирка: тёмная ручка, тяжёлая стальная голова с длинным клювом."""
    h = log("h", (0, 0, 0.1), (0, 0, -0.68), 0.032, col=hexcol("5a3a22"), rings=False)
    head = tube("hd", [(0, -0.38, -0.5), (0, -0.12, -0.62), (0, 0.12, -0.62), (0, 0.38, -0.5)], [0.012, 0.05, 0.05, 0.012], 8)
    paint(head, hexcol("6a7a8a"), ao=0.0, fn=lambda co, n: hexcol("c9d2dc") if n.z > 0.5 else None)
    ring = cyl("rg", (0, 0, -0.66), 0.045, 0.045, 0.1, segs=10)
    paint(ring, IRON, ao=0.0)
    join([h, head, ring], "Tool")


BUILDERS = {
    "vera": vera, "tortoise": tortoise, "tortoise_pen": tortoise_pen, "hot_springs": hot_springs, "clinic": clinic,
    "aloe_plant": aloe_plant, "coffee_bush": coffee_bush, "crop_pepper": crop_pepper,
    "charred_tree_a": charred_tree_a, "charred_tree_b": charred_tree_b, "ore_vein": ore_vein, "obsidian_rock": obsidian_rock,
    "basalt_a": basalt_a, "basalt_b": basalt_b, "forge": forge, "stone_bridge": stone_bridge, "bridge_marker": bridge_marker,
    "crater_wall": crater_wall, "rock_holds": rock_holds, "lava_rim": lava_rim,
    "temple_facade": temple_facade, "temple_door": temple_door, "monolith": monolith, "lava_chute": lava_chute,
    "lava_bowl": lava_bowl, "lava_crack": lava_crack, "cold_stone": cold_stone,
    "volcano_tower_ruin": volcano_tower_ruin, "volcano_tower": volcano_tower,
    "wear_fire_gloves": wear_fire_gloves, "tool_iron_pickaxe": tool_iron_pickaxe,
}
