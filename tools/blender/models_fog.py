"""Глава 7 — Туманный остров: выжившие с «Альбатроса» (юнга Миша, Рената, механик Гоша, близнецы Петя и Паша),
шхуна «Альбатрос» (разбитая и починенная, мачта с парусами, руль, ходовые огни), лагерь на сваях (помост, мостки, хижина),
мангры, светлячок, тыквенный фонарь и метка под него, сигнальный камень, стоячий камень, скала-экран с проходом,
Потерянный маяк (без чаши и с новой чашей); деревня на острове крушения: дом, колодец, длинный стол.

Координаты: Blender (x, y, z) → Godot (x, z, −y). «Вперёд» в Godot (+Z) — это −Y в Blender."""
import math

from kit import (box, cyl, displace, empty, hexcol, ico, join, lathe, leaf, paint, remesh, rnd, set_origin, set_parent,
                 shade, sphere, subsurf, tube)
from models_buildings import log, plank, stone
from models_ice import _block

SKIN = hexcol("e8b896")
SKIN_D = hexcol("c88a68")
WOOD_W = hexcol("8a6a4a")
MOSS = hexcol("6a8a4a")
HULL = hexcol("3a4a5a")
STONE_G = hexcol("8a9088")


# ================================================================== выжившие
def _person(body_col, legs_col, skin, hair_col, extra, name_scale=1.0, height=1.0):
    """Общий человечек «Альбатроса»: туловище-лейка, руки, ноги, голова; extra(parts, hp) добавляет своё.
    Узлы Body и Head, как у всех жителей."""
    hz = height
    body = lathe("pb", [(0.0, 0.08), (0.27, 0.1), (0.3, 0.38), (0.29, 0.7 * hz), (0.25, 0.95 * hz), (0.15, 1.04 * hz), (0.0, 1.06 * hz)], 20)
    subsurf(body, 1)
    paint(body, body_col, ao=0.0, noise_amt=0.07, fn=lambda co, n: legs_col if co.z < 0.38 else None)
    parts = [body]
    for sx in (-1, 1):
        a = tube("pa", [(sx * 0.27, 0, 0.95 * hz), (sx * 0.35, 0.05, 0.72 * hz), (sx * 0.32, 0.12, 0.52 * hz)], [0.085, 0.075, 0.07], 10)
        paint(a, body_col, ao=0.0)
        hd = sphere("ph", (sx * 0.31, 0.14, 0.48 * hz), 0.07)
        paint(hd, skin, ao=0.0)
        lg = tube("pl", [(sx * 0.12, 0, 0.15), (sx * 0.12, 0.02, 0.03)], 0.09, 10)
        paint(lg, legs_col, ao=0.0)
        bt = lathe("pt", [(0.0, 0.0), (0.11, 0.0), (0.11, 0.12), (0.0, 0.13)], 10, loc=(sx * 0.12, 0.04, 0), scale=(1, 1.4, 1))
        paint(bt, hexcol("3a2a1a"), ao=0.0)
        parts += [a, hd, lg, bt]
    hp = [sphere("hd", (0, 0, 1.36 * hz), 0.27, segs=26, rings=14)]
    paint(hp[0], skin, ao=0.0)
    for sx in (-1, 1):
        w = sphere("w", (sx * 0.1, 0.23, 1.39 * hz), 0.045, (1, 0.42, 0.9))
        paint(w, hexcol("ffffff"), ao=0.0, noise_amt=0)
        i = sphere("i", (sx * 0.1, 0.25, 1.385 * hz), 0.027, (1, 0.4, 0.9))
        paint(i, hexcol("3a2a1a"), ao=0.0, noise_amt=0)
        ear = sphere("er", (sx * 0.26, 0.0, 1.36 * hz), 0.055, (0.5, 0.8, 1.0))
        paint(ear, skin, ao=0.0)
        hp += [w, i, ear]
    nose = sphere("ns", (0, 0.27, 1.33 * hz), 0.04, (0.85, 1.0, 0.9))
    paint(nose, shade(skin, 0.93), ao=0.0)
    hp.append(nose)
    extra(parts, hp, hz)
    b = join(parts, "Body")
    set_origin(b, (0, 0, 0))
    h = join(hp, "Head")
    set_origin(h, (0, 0, 1.08 * hz))
    set_parent(h, b)


def misha():
    """Юнга Миша, 17 лет: худой, в слишком большой штормовке, вихры, улыбка до ушей, веснушки."""
    def extra(parts, hp, hz):
        hood = tube("hd", [(math.cos(a) * 0.2, math.sin(a) * 0.2 - 0.02, 1.02) for a in [k * math.pi / 10 for k in range(21)]], 0.07, 8, caps=False)
        paint(hood, hexcol("f2c23a"), ao=0.0)
        parts.append(hood)
        hair = sphere("hr", (0, -0.03, 1.45), 0.27, (1.0, 1.0, 0.75))
        displace(hair, 0.05, 0.06, "VORONOI")
        paint(hair, hexcol("c8783a"), ao=0.0, noise_amt=0.2, nscale=25)
        hp.append(hair)
        for k in range(4):
            sp = tube("tf", [(-0.1 + k * 0.07, 0.15, 1.6), (-0.12 + k * 0.08, 0.22, 1.66)], [0.04, 0.005], 6)
            paint(sp, hexcol("c8783a"), ao=0.0)
            hp.append(sp)
        smile = tube("mo", [(-0.09, 0.24, 1.27), (0.0, 0.26, 1.23), (0.09, 0.24, 1.27)], 0.015, 6)
        paint(smile, hexcol("8a3a32"), ao=0.0)
        hp.append(smile)
        for k in range(6):
            fr = sphere("fk", ((k % 3 - 1) * 0.04 + (0.1 if k < 3 else -0.1), 0.25, 1.32 + (k // 3) * 0.01), 0.008)
            paint(fr, hexcol("c87a52"), ao=0.0, noise_amt=0)
            hp.append(fr)
    _person(hexcol("f2c23a"), hexcol("4a5a7a"), SKIN, hexcol("c8783a"), extra)


def renata():
    """Рената, помощник капитана: прямая, строгая; тёмный бушлат с медными пуговицами, коса, шрам на брови."""
    def extra(parts, hp, hz):
        for k in range(3):
            for sx in (-1, 1):
                bt = sphere("bt", (sx * 0.1, 0.28, 0.6 + k * 0.12), 0.022, segs=8, rings=5)
                paint(bt, hexcol("d9a84a"), ao=0.0, noise_amt=0)
                parts.append(bt)
        hair = sphere("hr", (0, -0.03, 1.44), 0.28, (1.0, 1.02, 0.78))
        paint(hair, hexcol("2a1e1a"), ao=0.0, noise_amt=0.12, nscale=25)
        braid = tube("br", [(0, -0.2, 1.38), (0.05, -0.28, 1.15), (0.02, -0.3, 0.9)], [0.07, 0.06, 0.035], 8)
        paint(braid, hexcol("2a1e1a"), ao=0.0, fn=lambda co, n: 0.75 if int(co.z * 25) % 2 else None)
        brow = tube("bw", [(-0.15, 0.24, 1.47), (-0.04, 0.25, 1.46)], 0.016, 6)
        paint(brow, hexcol("2a1e1a"), ao=0.0)
        brow2 = tube("bw2", [(0.04, 0.25, 1.46), (0.15, 0.24, 1.48)], 0.016, 6)
        paint(brow2, hexcol("2a1e1a"), ao=0.0)
        scar = tube("sc", [(0.11, 0.25, 1.5), (0.14, 0.24, 1.44)], 0.006, 4)
        paint(scar, hexcol("e8a8a0"), ao=0.0)
        mouth = tube("mo", [(-0.05, 0.25, 1.26), (0.05, 0.25, 1.26)], 0.012, 6)
        paint(mouth, hexcol("7a3a32"), ao=0.0)
        hp += [hair, braid, brow, brow2, scar, mouth]
    _person(hexcol("2f3e5c"), hexcol("3a3a3a"), SKIN, hexcol("2a1e1a"), extra)


def gosha():
    """Механик Гоша: здоровяк в промасленной тельняшке с закатанными рукавами, руки-лопаты, борода, гаечный ключ."""
    def extra(parts, hp, hz):
        for sx in (-1, 1):
            fist = sphere("fs", (sx * 0.33, 0.14, 0.47), 0.11)
            paint(fist, SKIN_D, ao=0.0)
            parts.append(fist)
        wrench = tube("wr", [(0.38, 0.2, 0.45), (0.4, 0.22, 0.15)], 0.025, 6)
        paint(wrench, hexcol("8f979e"), ao=0.0)
        parts.append(wrench)
        beard = sphere("bd", (0, 0.12, 1.24), 0.22, (1.05, 0.8, 0.85))
        displace(beard, 0.03, 0.05, "VORONOI")
        paint(beard, hexcol("5a3a22"), ao=0.0, noise_amt=0.2, nscale=30)
        cap = sphere("cp", (0, -0.02, 1.5), 0.26, (1.05, 1.05, 0.5))
        paint(cap, hexcol("3a3a42"), ao=0.0)
        hp += [beard, cap]
    _person(hexcol("eef2f6"), hexcol("3a4a5a"), SKIN_D, hexcol("5a3a22"), extra, height=1.05)
    # тельняшка: полосы перекрашиваем по высоте
    import bpy
    b = bpy.data.objects["Body"]
    attr = b.data.color_attributes["Col"]
    for poly in b.data.polygons:
        for li in poly.loop_indices:
            co = b.data.vertices[b.data.loops[li].vertex_index].co
            if 0.42 < co.z < 1.0 and int(co.z * 18) % 2 == 0 and abs(co.x) < 0.33:
                attr.data[li].color_srgb = (0.18, 0.28, 0.48, 1.0)


def _twin(stripe, cap):
    def extra(parts, hp, hz):
        hat = sphere("ht", (0, -0.02, 1.52), 0.25, (1.0, 1.0, 0.55))
        paint(hat, cap, ao=0.0, fn=lambda co, n: shade(cap, 0.8) if int(co.z * 30) % 2 else None)
        pom = sphere("pm", (0, -0.02, 1.68), 0.06)
        paint(pom, hexcol("f2ead8"), ao=0.0)
        hair = sphere("hr", (0, -0.05, 1.42), 0.27, (1.0, 1.0, 0.7))
        paint(hair, hexcol("d6b07a"), ao=0.0)
        grin = tube("mo", [(-0.07, 0.245, 1.27), (0.0, 0.258, 1.25), (0.07, 0.245, 1.27)], 0.013, 6)
        paint(grin, hexcol("8a3a32"), ao=0.0)
        hp += [hair, hat, pom, grin]
        scarf = tube("sc", [(math.cos(a) * 0.19, math.sin(a) * 0.19, 1.03) for a in [k * math.pi / 10 for k in range(21)]], 0.055, 8, caps=False)
        paint(scarf, stripe, ao=0.0)
        parts.append(scarf)
    _person(hexcol("eef2f6"), hexcol("2f3e5c"), SKIN, hexcol("d6b07a"), extra)
    import bpy
    b = bpy.data.objects["Body"]
    attr = b.data.color_attributes["Col"]
    for poly in b.data.polygons:
        for li in poly.loop_indices:
            co = b.data.vertices[b.data.loops[li].vertex_index].co
            if 0.42 < co.z < 1.0 and int(co.z * 18) % 2 == 0 and abs(co.x) < 0.31:
                attr.data[li].color_srgb = stripe + (1.0,)


def petya():
    """Петя Лукин: близнец в тельняшке, синяя шапка с помпоном и синий шарф."""
    _twin(hexcol("3a6a9a"), hexcol("3a6a9a"))


def pasha():
    """Паша Лукин: такой же близнец, но шапка и шарф — рыжие."""
    _twin(hexcol("c8643a"), hexcol("c8643a"))


# ================================================================== «Альбатрос»
def _hull(wreck):
    """Корпус шхуны 15 м (вдоль X), ватерлиния — z=0, борт до z=2.4. Разбитый — во мху, с пробоинами,
    обломок мачты; починенный — чистый тёмно-синий борт с белой полосой и надписью."""
    # корпус — по шпангоутам: в каждом сечении U-образный борт; к носу сужается до острого форштевня
    import bmesh
    from kit import from_bm
    stations = [(-7.0, 1.3, 1.6), (-6.2, 1.7, 1.9), (-4.0, 1.95, 2.2), (-1.0, 2.0, 2.3), (2.0, 1.95, 2.3),
                (4.5, 1.6, 2.1), (6.2, 0.9, 1.8), (7.4, 0.12, 1.4)]
    bm = bmesh.new()
    rings = []
    ns = 10
    for x, w, depth in stations:
        ring = []
        for i in range(ns + 1):
            th = math.pi * i / ns
            y = w * math.cos(th)
            z = 2.4 - depth * math.sin(th) - (0.4 if x > 6 else 0.0) * (1 - math.sin(th))
            ring.append(bm.verts.new((x, y, z - 0.6)))
        rings.append(ring)
    for a, b in zip(rings[:-1], rings[1:]):
        for i in range(ns):
            bm.faces.new((a[i], b[i], b[i + 1], a[i + 1]))
    bm.faces.new(rings[0][::-1])
    bm.faces.new(rings[-1])
    bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=2, use_grid_fill=True)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    h = from_bm("hull", bm)
    subsurf(h, 1)

    def fn(co, n):
        if wreck and (math.sin(co.x * 1.7 + co.z * 2.2) > 0.4 and co.z < 1.6):
            return MOSS
        if wreck and (math.sin(co.x * 3 + 1.3) * math.sin(co.z * 4) > 0.85):
            return hexcol("2a1e1a")   # пробоины
        if co.z > 1.65:
            return hexcol("f2ead8")
        if 1.25 < co.z < 1.45:
            return hexcol("e8443a") if not wreck else hexcol("a0705a")
        if co.z < 0.1:
            return hexcol("7a3a2a")
        return None
    paint(h, HULL if not wreck else hexcol("4a5a52"), ao=0.2, ao_h=1.0, noise_amt=0.12, nscale=1.5, fn=fn)
    deck = box("dk", (0, 0, 1.9), (13.0, 3.2, 0.12))
    paint(deck, hexcol("c99a5e") if not wreck else hexcol("8a8a5a"), ao=0.0, noise_amt=0.1,
          fn=lambda co, n: 0.85 if int(co.y * 5) % 2 else None)
    cabin = box("cb", (-4.0, 0, 2.6), (3.0, 2.0, 1.4), bev=0.06)
    paint(cabin, hexcol("e8dcc4") if not wreck else hexcol("a0a080"), ao=0.0,
          fn=lambda co, n: hexcol("bfe8f0") if (abs(n.y) > 0.6 and abs(co.z - 2.7) < 0.2 and int(co.x * 2) % 2) else None)
    roof = box("rf", (-4.0, 0, 3.35), (3.3, 2.3, 0.12))
    paint(roof, hexcol("8a5a32"), ao=0.0)
    bow = tube("bs", [(7.2, 0, 1.7), (9.0, 0, 2.3)], [0.1, 0.05], 8)   # бушприт
    paint(bow, WOOD_W, ao=0.0)
    rail = []
    for sy in (-1, 1):
        rail.append(tube("rl", [(-6.5, sy * 1.6, 2.4), (0, sy * 1.85, 2.4), (6.0, sy * 1.4, 2.4)], 0.05, 6))
    r = join(rail, "rail")
    paint(r, WOOD_W, ao=0.0)
    parts2 = [h, deck, cabin, roof, bow, r]
    if wreck:
        stub = tube("st", [(0.5, 0, 1.9), (0.6, 0.1, 4.2)], [0.18, 0.12], 10)
        paint(stub, hexcol("6a5a3a"), ao=0.0, fn=lambda co, n: MOSS if co.z < 3.0 else None)
        rag = leaf("rg", (0.6, 0.1, 4.0), (0.3, 1.0, -0.6), 1.4, 0.5, droop=0.5)
        paint(rag, hexcol("8a8a6a"), ao=0.0)
        parts2 += [stub, rag]
        rr = rnd(3)
        for k in range(8):
            fl = sphere("fl", (rr.uniform(-5, 5), rr.uniform(-1.4, 1.4), rr.uniform(2.2, 3.6)), 0.05)
            paint(fl, hexcol("e8ff7a"), ao=0.0, noise_amt=0)
            parts2.append(fl)
    else:
        name = box("nm", (5.0, -1.72, 1.85), (2.0, 0.05, 0.2))
        paint(name, hexcol("f2ead8"), ao=0.0, fn=lambda co, n: hexcol("2a2a2a") if int(co.x * 6) % 2 else None)
        parts2.append(name)
    join(parts2, "Albatros")


def albatros_wreck():
    _hull(True)


def albatros():
    _hull(False)


def albatros_mast():
    """Мачта с реями и парусами из шерсти (кремовые, с заплатками), ванты."""
    parts = []
    for x, hgt in ((0.6, 11.0), (-3.0, 8.5)):
        m = tube("ms", [(x, 0, 1.9), (x, 0, hgt)], [0.2, 0.12], 10)
        paint(m, WOOD_W, ao=0.0)
        parts.append(m)
        for k, z in enumerate((hgt * 0.45, hgt * 0.75)):
            yard = tube("yd", [(x, -2.0 + k * 0.4, z), (x, 2.0 - k * 0.4, z)], 0.07, 6)
            paint(yard, WOOD_W, ao=0.0)
            sail = _block("sl", 0.05, 3.6 - k * 0.8, 2.4, cuts=8, z0=z - 2.5)
            sail.location = (x + 0.15, 0, 0)
            paint(sail, hexcol("f2ead8"), ao=0.0, noise_amt=0.05,
                  fn=lambda co, n: (hexcol("e0d4b8") if (co.z * 2.5) % 1.0 < 0.08 else
                                    (hexcol("c8503a") if (co.y > 0.9 and (co.z * 1.7) % 1.0 > 0.8) else None)))
            parts += [yard, sail]
    for sy in (-1, 1):
        sh = tube("sh", [(0.6, sy * 1.7, 2.3), (0.6, 0, 10.5)], 0.02, 4)
        paint(sh, hexcol("c9a467"), ao=0.0)
        parts.append(sh)
    flag = box("fl", (0.6, 0.6, 11.0), (0.03, 1.0, 0.6))
    paint(flag, hexcol("e8443a"), ao=0.0)
    parts.append(flag)
    join(parts, "Mast")


def albatros_helm():
    """Штурвал на корме: колесо со спицами на тумбе."""
    parts = []
    post = box("ps", (-6.0, 0, 2.4), (0.3, 0.3, 1.0), bev=0.03)
    paint(post, WOOD_W, ao=0.0)
    wheel = tube("wh", [(-5.8, math.cos(a) * 0.5, 2.9 + math.sin(a) * 0.5) for a in [k * math.pi / 8 for k in range(17)]], 0.04, 6, caps=False)
    paint(wheel, hexcol("c99a5e"), ao=0.0)
    parts += [post, wheel]
    for k in range(8):
        a = k * math.pi / 4
        sp = tube("sp", [(-5.8, 0, 2.9), (-5.8, math.cos(a) * 0.65, 2.9 + math.sin(a) * 0.65)], 0.03, 5)
        paint(sp, hexcol("8a5a32"), ao=0.0)
        parts.append(sp)
    join(parts, "Helm")


def albatros_lights():
    """Ходовые огни: фонари на носу, корме и мачте, в них — светлячки. Узлы Lamp* — где игра ставит свет."""
    parts = []
    spots = [(7.0, 0, 2.8), (-6.8, 0, 3.2), (0.6, 0, 9.0)]
    for i, p in enumerate(spots):
        lamp = lathe("lp", [(0.0, -0.2), (0.15, -0.2), (0.18, 0.1), (0.12, 0.25), (0.0, 0.28)], 10, loc=p)
        paint(lamp, hexcol("d8ffa0"), ao=0.0, noise_amt=0, fn=lambda co, n: hexcol("4a4c52") if abs(n.z) > 0.8 else None)
        parts.append(lamp)
    l = join(parts, "Lights")
    for i, p in enumerate(spots):
        empty("Lamp%d" % i, p, l)


# ================================================================== лагерь на сваях
def stilt_platform():
    """Помост на сваях 10 × 9 м (верх — z=0), доски, сваи уходят в воду, перила."""
    parts = []
    r = rnd(5)
    for k in range(18):
        y = -4.25 + k * 0.5
        parts.append(plank("pl", (r.uniform(-0.05, 0.05), y, -0.06), (10.0, 0.46, 0.12), col=hexcol("9a7a52"), seed=k))
    for x in (-4.6, -1.5, 1.5, 4.6):
        for y in (-4.0, 0.0, 4.0):
            parts.append(log("st", (x, y, -3.0), (x, y, 0.0), 0.15, col=hexcol("5a4030")))
    for sx in (-1, 1):
        parts.append(log("rl", (sx * 4.9, -4.2, 0.9), (sx * 4.9, 4.2, 0.9), 0.05, rings=False))
        for y in (-4.0, 0.0, 4.0):
            parts.append(log("rp", (sx * 4.9, y, 0.0), (sx * 4.9, y, 0.95), 0.05, rings=False))
    join(parts, "Platform")


def stilt_pier():
    """Мостки 2,2 × 5 м к борту корабля (верх — z=0)."""
    parts = []
    for k in range(10):
        parts.append(plank("pl", (0, -2.25 + k * 0.5, -0.06), (2.2, 0.46, 0.12), col=hexcol("9a7a52"), seed=k))
    for y in (-2.2, 2.2):
        for x in (-1.0, 1.0):
            parts.append(log("st", (x, y, -3.0), (x, y, 0.6), 0.12, col=hexcol("5a4030")))
    join(parts, "Pier")


def stilt_hut():
    """Хижина выживших: стены из жердей и парусины «Альбатроса», крыша из листьев, фонарь у входа."""
    parts = []
    walls = box("wl", (0, 0, 1.0), (2.2, 2.0, 2.0), bev=0.04)
    paint(walls, hexcol("c9b890"), ao=0.25, ao_h=0.6, noise_amt=0.15, nscale=6,
          fn=lambda co, n: (hexcol("8a6a4a") if int(co.x * 6 + co.y * 6) % 4 == 0 else (hexcol("e8443a") if 1.2 < co.z < 1.35 else None)))
    door = box("dr", (0, -1.02, 0.8), (0.7, 0.05, 1.5), bev=0.02)
    paint(door, hexcol("3a2e24"), ao=0.0)
    parts += [walls, door]
    for sx in (-1, 1):
        rf = box("rf", (sx * 0.62, 0, 2.35), (1.4, 2.5, 0.12), (0, sx * 0.62, 0), bev=0.03)
        paint(rf, hexcol("6a8a4a"), ao=0.0, noise_amt=0.2, nscale=12, fn=lambda co, n: 0.85 if int(co.y * 10) % 2 else None)
        parts.append(rf)
    lamp = sphere("lm", (0.6, -1.15, 1.7), 0.1)
    paint(lamp, hexcol("ffd27a"), ao=0.0, noise_amt=0)
    parts.append(lamp)
    join(parts, "Hut")


# ================================================================== растения, светлячок, фонари
def _mangrove(seed):
    """Мангр: ствол на изогнутых корнях-ходулях, низкая широкая крона."""
    r = rnd(seed)
    parts = []
    for k in range(7):
        a = k * 2 * math.pi / 7 + r.uniform(-0.2, 0.2)
        root = tube("rt", [(math.cos(a) * 1.2, math.sin(a) * 1.2, -0.6), (math.cos(a) * 0.9, math.sin(a) * 0.9, 0.6),
                           (math.cos(a) * 0.35, math.sin(a) * 0.35, 1.3), (0, 0, 1.5)], [0.06, 0.07, 0.08, 0.1], 6)
        parts.append(root)
    trunk = tube("tr", [(0, 0, 1.4), (0.1, 0.0, 3.2)], [0.2, 0.14], 10)
    parts.append(trunk)
    t = join(parts, "Trunk")
    paint(t, hexcol("6a5040"), ao=0.0, noise_amt=0.15, nscale=8, fn=lambda co, n: MOSS if co.z < 0.3 else None)
    crown = []
    for k in range(6):
        crown.append(sphere("cr", (r.uniform(-1.0, 1.0), r.uniform(-1.0, 1.0), 3.5 + r.uniform(-0.2, 0.4)), r.uniform(0.7, 1.0), (1.3, 1.2, 0.6)))
    c = join(crown, "crown_leaf")
    remesh(c, 0.17, 3)
    displace(c, 0.08, 0.3)
    paint(c, hexcol("3f6a44"), ao=0.0, noise_amt=0.18, nscale=4, fn=lambda co, n: 1.15 if n.z > 0.6 else (0.8 if n.z < -0.3 else None))
    set_parent(c, t)


def mangrove_a():
    _mangrove(4)


def mangrove_b():
    _mangrove(21)


def firefly():
    """Светлячок: маленький жучок с ярким салатовым брюшком и прозрачными крылышками."""
    body = sphere("fb", (0, 0, 0), 0.05, (0.8, 1.3, 0.8))
    paint(body, hexcol("3a3a2a"), ao=0.0, noise_amt=0)
    glow = sphere("fg", (0, -0.06, 0), 0.05, (0.9, 1.0, 0.9))
    paint(glow, hexcol("e8ff7a"), ao=0.0, noise_amt=0)
    parts = [body, glow]
    for sx in (-1, 1):
        w = sphere("fw", (sx * 0.05, 0.02, 0.03), 0.05, (1.2, 0.6, 0.15), (0, sx * 0.4, 0))
        paint(w, hexcol("e8f2f0"), ao=0.0, noise_amt=0)
        parts.append(w)
    join(parts, "Firefly")


def pumpkin_lantern():
    """Тыквенный фонарь: тыква с прорезанной рожицей на колышке, внутри свеча. FirePoint — у свечи."""
    parts = []
    stake = log("sk", (0, 0, 0.0), (0, 0, 0.35), 0.04, col=hexcol("8a5a32"), rings=False)
    parts.append(stake)
    pk = []
    for k in range(8):
        a = k * math.pi / 4
        pk.append(sphere("pk", (math.cos(a) * 0.08, math.sin(a) * 0.08, 0.55), 0.2, (0.75, 0.75, 0.95)))
    p = join(pk, "pk")
    remesh(p, 0.03, 2)

    def face(co, n):
        if n.y < -0.5:
            if (abs(co.x - 0.08) < 0.035 or abs(co.x + 0.08) < 0.035) and 0.6 < co.z < 0.66:
                return hexcol("ffd23f")
            if abs(co.x) < 0.12 and 0.45 < co.z < 0.5:
                return hexcol("ffd23f")
        return 0.85 if math.sin(math.atan2(co.y, co.x) * 8) > 0.7 else None
    paint(p, hexcol("f08a24"), ao=0.0, fn=face)
    stem = tube("sm", [(0, 0, 0.78), (0.03, 0, 0.88)], 0.025, 6)
    paint(stem, hexcol("6b8a3a"), ao=0.0)
    parts += [p, stem]
    l = join(parts, "PumpkinLantern")
    empty("FirePoint", (0, 0, 0.48), l)


def lantern_mark():
    """Метка под фонарь: колышек с белой тряпочкой."""
    st = log("st", (0, 0, 0.0), (0, 0, 0.6), 0.03, col=hexcol("8a5a32"), rings=False)
    rag = leaf("rg", (0, 0, 0.55), (1, 0.3, -0.4), 0.25, 0.1, droop=0.3)
    paint(rag, hexcol("f2ead8"), ao=0.0)
    join([st, rag], "Mark")


def signal_rock():
    """Сигнальный камень: большой валун в болоте, наверху — каменное кольцо для огня, вокруг — дрова. FirePoint — в кольце."""
    rk = ico("rk", (0, 0, 0.6), 1.4, (1.2, 1.0, 0.75), sub=3)
    displace(rk, 0.3, 0.8, "VORONOI")
    paint(rk, STONE_G, ao=0.3, ao_h=0.6, noise_amt=0.1, fn=lambda co, n: MOSS if n.z > 0.5 and co.z < 1.2 else None)
    parts = [rk]
    for k in range(7):
        a = k * 2 * math.pi / 7
        parts.append(stone("rg", (math.cos(a) * 0.45, math.sin(a) * 0.45, 1.65), 0.14, k, hexcol("6a6e68")))
    for k in range(4):
        a = k * 1.4 + 0.3
        parts.append(log("lg", (math.cos(a) * 1.6, math.sin(a) * 1.6, 0.1), (math.cos(a) * 2.2, math.sin(a) * 2.0, 0.15), 0.08))
    r = join(parts, "SignalRock")
    empty("FirePoint", (0, 0, 1.75), r)


def standing_stone():
    """Стоячий камень святилища: высокий, чуть наклонённый, со стёртыми знаками и мхом."""
    s = _block("ss", 0.9, 0.6, 2.6, cuts=6)
    displace(s, 0.12, 0.6, "VORONOI")
    paint(s, STONE_G, ao=0.2, ao_h=0.6, noise_amt=0.1,
          fn=lambda co, n: (MOSS if (n.z > 0.5 or co.z < 0.3) else (hexcol("6a6e68") if math.sin(co.z * 9) > 0.85 and abs(n.y) > 0.6 else None)))
    s.rotation_euler = (0.05, 0.04, 0)
    join([s], "Stone")


def screen_rock():
    """Скала-экран: гладкая светлая плита в скале, знак Ока; в середине — плита-проход Door (опускается)."""
    back = ico("bk", (0, 0.6, 1.8), 2.4, (1.3, 0.5, 0.95), sub=3)
    displace(back, 0.3, 0.8, "VORONOI")
    paint(back, hexcol("6a6e68"), ao=0.3, ao_h=1.0, noise_amt=0.1, fn=lambda co, n: MOSS if n.z > 0.6 else None)
    face = _block("fc", 4.6, 0.3, 3.4, cuts=14)
    face.location = (0, -0.2, 0)

    def eye(co, n):
        if n.y < -0.5:
            d = math.hypot(co.x, co.z - 2.2)
            if abs(d - 0.55) < 0.06 or d < 0.1:
                return hexcol("4a4e48")
        return None
    paint(face, hexcol("c8ccc4"), ao=0.0, noise_amt=0.05, fn=eye)
    r = join([back, face], "ScreenRock")
    door = _block("dr", 1.4, 0.35, 2.0, cuts=4)
    door.location = (0, -0.38, 0)
    paint(door, hexcol("b8bcb4"), ao=0.0, noise_amt=0.05, fn=lambda co, n: hexcol("8a8e88") if abs(co.x) < 0.02 else None)
    d = join([door], "Door")
    set_parent(d, r)


def _fog_tower(lit):
    """Потерянный маяк: серая башня во мху, без чаши (древние сняли её); у починенной — новая чаша из железа
    и обсидиана на кирпичной кладке. FirePoint — где игра зажигает огонь."""
    parts = []
    tower = lathe("tw", [(1.7, 0.0), (1.6, 0.5), (1.35, 4.0), (1.15, 7.5), (1.35, 7.8), (1.35, 8.1), (0.0, 8.1)], 18)
    subsurf(tower, 2)
    displace(tower, 0.07, 0.5, "VORONOI")
    paint(tower, STONE_G, ao=0.3, ao_h=1.2, noise_amt=0.1,
          fn=lambda co, n: (MOSS if math.sin(co.x * 2 + co.z * 1.3) > 0.4 and co.z < 6.0 else (shade(STONE_G, 0.75) if (co.z * 1.7) % 1.0 < 0.07 else None)))
    door = box("dr", (0, -1.5, 0.9), (0.8, 0.4, 1.7), bev=0.05)
    paint(door, hexcol("1a1e1a"), ao=0.0)
    parts += [tower, door]
    t = join(parts, "FogTower")
    if lit:
        base = box("bb", (0, 0, 8.3), (1.4, 1.4, 0.4), bev=0.04)
        paint(base, hexcol("b8583a"), ao=0.0, fn=lambda co, n: hexcol("e8d8c0") if (co.z * 7) % 1.0 < 0.1 else None)
        bowl = lathe("bw", [(0.0, 8.5), (0.6, 8.55), (0.95, 8.95), (0.85, 9.0), (0.0, 8.75)], 18)
        paint(bowl, hexcol("4a4c52"), ao=0.0, fn=lambda co, n: hexcol("3a2a5a") if n.z > 0.4 else None)
        set_parent(base, t)
        set_parent(bowl, t)
        empty("FirePoint", (0, 0, 8.85), t)
    else:
        empty("FirePoint", (0, 0, 8.3), t)


def fog_tower_ruin():
    _fog_tower(False)


def fog_tower():
    _fog_tower(True)


# ================================================================== деревня
def village_house():
    """Дом для команды: белёные стены, черепичная крыша, крылечко с цветами, круглое окошко как иллюминатор."""
    parts = []
    walls = _block("wl", 3.0, 2.6, 2.2, cuts=8)
    paint(walls, hexcol("f2ead8"), ao=0.25, ao_h=0.6, noise_amt=0.06,
          fn=lambda co, n: (hexcol("6a8aa0") if (n.y < -0.5 and math.hypot(co.x + 0.75, co.z - 1.3) < 0.28) else
                            (hexcol("c9b890") if co.z < 0.3 else None)))
    door = box("dr", (0.5, -1.32, 0.85), (0.8, 0.06, 1.6), bev=0.03)
    paint(door, hexcol("4f7a9a"), ao=0.0)
    parts += [walls, door]
    for sx in (-1, 1):
        rf = box("rf", (sx * 0.85, 0, 2.6), (2.0, 3.0, 0.14), (0, sx * 0.6, 0), bev=0.03)
        paint(rf, hexcol("c8503a"), ao=0.0, fn=lambda co, n: 0.82 if int(co.y * 6) % 2 else None)
        parts.append(rf)
    step = box("st", (0.5, -1.6, 0.08), (1.4, 0.6, 0.16), bev=0.02)
    paint(step, hexcol("a3a8ad"), ao=0.0)
    parts.append(step)
    for k in range(3):
        fl = sphere("fl", (-0.3 + k * 0.3, -1.5, 0.3), 0.12)
        paint(fl, [hexcol("ff6fa5"), hexcol("ffd84a"), hexcol("b28cff")][k], ao=0.0)
        parts.append(fl)
    chim = box("ch", (-0.9, 0.6, 3.0), (0.35, 0.35, 0.8), bev=0.02)
    paint(chim, hexcol("a3a8ad"), ao=0.0)
    parts.append(chim)
    join(parts, "House")


def well():
    """Колодец: каменное кольцо, навес на двух столбах, ворот с ведром."""
    parts = []
    ring = lathe("rg", [(0.75, 0.0), (0.8, 0.8), (0.55, 0.85), (0.55, 0.1)], 18)
    paint(ring, hexcol("a3a8ad"), ao=0.25, ao_h=0.5, noise_amt=0.15, fn=lambda co, n: 0.8 if int(co.z * 6) % 2 else None)
    water = cyl("wt", (0, 0, 0.5), 0.55, 0.55, 0.02, segs=16)
    paint(water, hexcol("3f7a9a"), ao=0.0, noise_amt=0)
    parts += [ring, water]
    for sx in (-1, 1):
        parts.append(log("ps", (sx * 0.7, 0, 0.6), (sx * 0.7, 0, 1.9), 0.06))
    parts.append(log("ax", (-0.75, 0, 1.5), (0.75, 0, 1.5), 0.05, rings=False))
    for sx in (-1, 1):
        rf = box("rf", (0, sx * 0.35, 2.05), (1.8, 0.9, 0.08), (sx * 0.5, 0, 0), bev=0.02)
        paint(rf, hexcol("8a5a32"), ao=0.0)
        parts.append(rf)
    bucket = lathe("bk", [(0.0, 0.0), (0.13, 0.0), (0.15, 0.22), (0.0, 0.2)], 10, loc=(0.2, 0, 1.0))
    paint(bucket, hexcol("8a5a32"), ao=0.0)
    rope = tube("rp", [(0.2, 0, 1.5), (0.2, 0, 1.22)], 0.012, 4)
    paint(rope, hexcol("d4b483"), ao=0.0)
    parts += [bucket, rope]
    join(parts, "Well")


def long_table():
    """Длинный стол на всю команду: доски на козлах, лавки, кувшин, хлеб, миска с фруктами."""
    parts = []
    parts.append(plank("tp", (0, 0, 0.8), (3.4, 1.0, 0.08), col=hexcol("c99a5e")))
    for x in (-1.4, 1.4):
        for sy in (-1, 1):
            parts.append(plank("lg", (x, sy * 0.35, 0.4), (0.08, 0.08, 0.8), col=hexcol("8a5a32")))
    for sy in (-1, 1):
        parts.append(plank("bn", (0, sy * 0.9, 0.45), (3.2, 0.35, 0.06), col=hexcol("b8834b")))
        for x in (-1.3, 1.3):
            parts.append(plank("bl", (x, sy * 0.9, 0.22), (0.06, 0.3, 0.44), col=hexcol("8a5a32")))
    jug = lathe("jg", [(0.0, 0.84), (0.1, 0.84), (0.12, 0.98), (0.06, 1.1), (0.0, 1.1)], 10, loc=(-0.8, 0, 0))
    paint(jug, hexcol("c87048"), ao=0.0)
    bread = sphere("br", (0.4, 0.1, 0.9), 0.15, (1.4, 1.0, 0.6))
    paint(bread, hexcol("d6a050"), ao=0.0)
    bowl = lathe("bw", [(0.0, 0.84), (0.2, 0.86), (0.22, 0.95), (0.0, 0.9)], 12, loc=(1.1, -0.1, 0))
    paint(bowl, hexcol("6f8fb0"), ao=0.0)
    parts += [jug, bread, bowl]
    for k, c in enumerate((hexcol("ffe14d"), hexcol("ff9f2e"), hexcol("e8443a"))):
        f = sphere("fr", (1.05 + k * 0.08, -0.1 + (k % 2) * 0.08, 0.98), 0.07)
        paint(f, c, ao=0.0)
        parts.append(f)
    join(parts, "LongTable")


BUILDERS = {
    "misha": misha, "renata": renata, "gosha": gosha, "petya": petya, "pasha": pasha,
    "albatros_wreck": albatros_wreck, "albatros": albatros, "albatros_mast": albatros_mast, "albatros_helm": albatros_helm,
    "albatros_lights": albatros_lights, "stilt_platform": stilt_platform, "stilt_pier": stilt_pier, "stilt_hut": stilt_hut,
    "mangrove_a": mangrove_a, "mangrove_b": mangrove_b, "firefly": firefly, "pumpkin_lantern": pumpkin_lantern,
    "lantern_mark": lantern_mark, "signal_rock": signal_rock, "standing_stone": standing_stone, "screen_rock": screen_rock,
    "fog_tower_ruin": fog_tower_ruin, "fog_tower": fog_tower, "village_house": village_house, "well": well,
    "long_table": long_table,
}
