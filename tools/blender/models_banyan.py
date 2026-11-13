"""Глава 2 — остров Великого Баньяна: исполинское дерево, площадки-ярусы, лианы для лазания,
завесы лиан (преграда для мачете), жаровня с огнём и Марта — повар «Альбатроса»."""
import math

from mathutils import Vector

from kit import (box, cyl, displace, empty, hexcol, ico, join, lathe, leaf, mix, paint, remesh, rnd, set_origin,
                 set_parent, shade, sphere, subsurf, tube)
from models_buildings import log, plank, rope_wrap
from models_jungle import JG, JG2, JG_D, OLIVE

BARK = hexcol("7d6148")


def banyan_giant():
    """Ствол ~30 м: сросшиеся стволы, корни-досками, воздушные корни, огромная крона."""
    rr = rnd(101)
    parts = []
    for k in range(7):   # пучок сросшихся стволов
        a = 2 * math.pi * k / 7
        r0 = 2.2
        pts = [(math.cos(a) * r0, math.sin(a) * r0, 0.0)]
        for i in range(1, 8):
            t = i / 7
            rr_ = r0 * (1 - 0.55 * t) + 0.4 * math.sin(t * 6 + k)
            pts.append((math.cos(a + t * 0.6) * rr_, math.sin(a + t * 0.6) * rr_, t * 26))
        parts.append(tube("st", pts, [1.7 - 0.9 * i / 8 for i in range(8)], 10))
    for k in range(9):   # корни-досками
        a = 2 * math.pi * k / 9 + rr.random() * 0.3
        parts.append(tube("rt", [(math.cos(a) * 2.5, math.sin(a) * 2.5, 5.0), (math.cos(a) * 5.0, math.sin(a) * 5.0, 1.5),
                                 (math.cos(a) * 7.5, math.sin(a) * 7.5, -0.2)], [0.9, 0.6, 0.2], 8))
    for k in range(5):   # ветви под площадками и кроной
        a = 2 * math.pi * k / 5 + 0.3
        z0 = 18 + k * 1.5
        parts.append(tube("br", [(0, 0, z0), (math.cos(a) * 6, math.sin(a) * 6, z0 + 3), (math.cos(a) * 11, math.sin(a) * 11, z0 + 4)], [1.0, 0.6, 0.25], 8))
    for p in parts:
        displace(p, 0.25, 0.8)
        paint(p, BARK, ao=0.3, ao_h=3.0, noise_amt=0.15, nscale=0.8,
              fn=lambda co, n: hexcol("5f8a3a") if (n.z > 0.4 and co.z < 6) else (0.8 if math.sin(co.z * 2 + math.atan2(co.y, co.x) * 7) > 0.75 else None))
    join(parts, "Trunk")
    # воздушные корни — свисают с ветвей
    roots = []
    for k in range(16):
        a = 2 * math.pi * k / 16 + rr.random() * 0.2
        r = rr.uniform(6.5, 10.0)
        top = 22 + rr.uniform(0, 3)
        roots.append(tube("ar", [(math.cos(a) * r, math.sin(a) * r, top), (math.cos(a) * r * 1.02, math.sin(a) * r * 1.02, top * 0.5), (math.cos(a) * r, math.sin(a) * r, -0.2)],
                          [0.12, 0.1, 0.16], 6))
    for rt in roots:
        paint(rt, shade(BARK, 1.1), ao=0.0, noise_amt=0.1)
    join(roots, "AerialRoots")
    # крона
    blobs = []
    for i in range(16):
        a = 2 * math.pi * i / 16
        rad = 9 if i % 2 else 12
        b = ico("cb", (math.cos(a) * rad, math.sin(a) * rad, 27 + rr.uniform(-1, 2)), rr.uniform(4.5, 6.0), (1, 1, 0.6), sub=2)
        displace(b, 1.2, 1.4)
        c = shade(JG, 0.9 + 0.15 * rr.random())
        paint(b, c, ao=0.0, noise_amt=0.18, nscale=0.6, fn=lambda co, n, c=c: 1.15 if n.z > 0.5 else (0.78 if n.z < -0.3 else None))
        blobs.append(b)
    top = ico("ct", (0, 0, 31), 8, (1, 1, 0.55), sub=2)
    displace(top, 1.4, 1.4)
    paint(top, JG2, ao=0.0, noise_amt=0.18, nscale=0.6)
    blobs.append(top)
    join(blobs, "Crown_leaf")


def deck():
    """Площадка-ярус 5×4 м: настил, перила, верёвочные поручни, корзины, свёрнутая сеть."""
    parts = [plank("dk%d" % i, (0, -1.8 + i * 0.4, 0.0), (5.0, 0.38, 0.14), seed=i) for i in range(10)]
    for x in (-2.4, 2.4):
        for y in (-1.9, 1.9):
            parts.append(log("pp", (x, y, -0.05), (x, y, 1.1), 0.08, rings=False))
    for y in (-1.95, 1.95):
        parts.append(log("rl", (-2.4, y, 1.0), (2.4, y, 1.0), 0.04, rings=False))
        r = tube("rp", [(-2.4, y, 0.55), (0, y + 0.02, 0.45), (2.4, y, 0.55)], 0.02, 5)
        paint(r, hexcol("d4b483"), ao=0.0)
        parts.append(r)
    for x, y in ((-1.8, 1.4), (1.6, 1.3)):
        bk = lathe("bs", [(0.0, 0.07), (0.25, 0.07), (0.3, 0.4), (0.0, 0.4)], 12, loc=(x, y, 0))
        paint(bk, hexcol("c9a050"), ao=0.0, fn=lambda co, n: 0.8 if int(co.z * 30) % 2 else None)
        parts.append(bk)
    join(parts, "Deck")


def liana():
    """Вертикальная лиана высотой 1 м (в игре растягивается по длине) с листиками."""
    parts = [tube("lv", [(0, 0, 0), (0.04, 0, 0.5), (0, 0, 1.0)], 0.06, 6, caps=False)]
    paint(parts[0], hexcol("6f7a35"), ao=0.0, fn=lambda co, n: 0.8 if int(co.z * 8) % 2 else None)
    for k in range(3):
        a = k * 2.1
        lf = leaf("ll_leaf", (0, 0, 0.2 + k * 0.3), (math.cos(a), math.sin(a), 0.2), 0.16, 0.06, droop=0.3, segs=3)
        paint(lf, JG2, ao=0.0)
        parts.append(lf)
    join(parts, "Liana_leaf")


def liana_curtain():
    """Завеса лиан между двумя стволами — рубится мачете."""
    rr = rnd(111)
    parts = [tube("tb", [(-1.3, 0, 2.6), (0, 0.1, 2.4), (1.3, 0, 2.6)], 0.12, 8)]
    paint(parts[0], BARK, ao=0.0)
    for k in range(14):
        x = -1.2 + k * 0.18 + rr.uniform(-0.05, 0.05)
        ln = rr.uniform(1.8, 2.5)
        v = tube("vn", [(x, 0, 2.5), (x + rr.uniform(-0.1, 0.1), rr.uniform(-0.1, 0.1), 2.5 - ln * 0.5), (x, 0, 2.5 - ln)], 0.03, 5)
        paint(v, hexcol("5f7a35"), ao=0.0)
        parts.append(v)
        for q in range(4):
            lf = leaf("lc_leaf", (x, 0, 2.4 - q * 0.5), (rr.uniform(-1, 1), rr.uniform(-1, 1), -0.3), 0.15, 0.06, droop=0.3, segs=3)
            paint(lf, shade(JG2, 0.85 + 0.2 * rr.random()), ao=0.0)
            parts.append(lf)
    join(parts, "Curtain_leaf")


def fire_bowl():
    bowl = lathe("fb", [(0.0, 0.0), (0.35, 0.0), (0.3, 0.6), (0.7, 0.9), (0.8, 1.05), (0.7, 1.1), (0.0, 0.95)], 18)
    paint(bowl, hexcol("5c5866"), ao=0.0, noise_amt=0.12, fn=lambda co, n: hexcol("4a3a32") if n.z > 0.6 and co.z > 0.9 else None)
    join([bowl], "FireBowl")


# ------------------------------------------------------------------ Марта
def marta():
    """Марта: повар «Альбатроса». Седые волосы в пучке под банданой, фартук, деревянный половник."""
    skin = hexcol("e8b48a")
    hair = hexcol("d9d4cc")
    dress = hexcol("6f8fb0")
    apron = hexcol("f2ead3")
    body = lathe("mb", [(0.0, 0.05), (0.3, 0.07), (0.32, 0.3), (0.27, 0.6), (0.25, 0.85), (0.21, 0.98), (0.09, 1.03), (0.0, 1.04)], 20)
    subsurf(body, 1)
    paint(body, dress, ao=0.0, fn=lambda co, n: apron if (co.y > 0.05 and 0.12 < co.z < 0.85 and abs(co.x) < 0.2) else None)
    parts = [body]
    for sx in (-1, 1):
        a = tube("ma", [(sx * 0.26, 0, 0.95), (sx * 0.33, 0.06, 0.75), (sx * 0.3, 0.12, 0.58)], [0.075, 0.065, 0.06], 10)
        paint(a, dress, ao=0.0, fn=lambda co, n: skin if co.z < 0.72 else None)
        h = sphere("mh", (sx * 0.29, 0.14, 0.55), 0.065)
        paint(h, skin, ao=0.0)
        f = sphere("mf", (sx * 0.12, 0.05, 0.04), 0.08, (0.9, 1.5, 0.5))
        paint(f, hexcol("6b4a2a"), ao=0.0)
        parts += [a, h, f]
    ladle = log("ld", (0.29, 0.16, 0.45), (0.3, 0.2, 1.0), 0.015, col=hexcol("a07040"), rings=False)
    cup = sphere("lc", (0.29, 0.16, 0.42), 0.06, (1, 1, 0.6))
    paint(cup, hexcol("a07040"), ao=0.0)
    parts += [ladle, cup]
    b = join(parts, "Body")
    set_origin(b, (0, 0, 0))
    hp = [sphere("hd", (0, 0, 1.36), 0.31, segs=26, rings=14)]
    paint(hp[0], skin, ao=0.0)
    for sx in (-1, 1):
        for nm, loc, r, sc, c in (("w", (sx * 0.11, 0.26, 1.39), 0.055, (1, 0.42, 1.1), hexcol("ffffff")),
                                  ("i", (sx * 0.115, 0.285, 1.385), 0.035, (1, 0.4, 1.1), hexcol("5a3a22")),
                                  ("c", (sx * 0.19, 0.23, 1.29), 0.05, (1, 0.4, 0.7), hexcol("e8866a"))):
            o = sphere(nm, loc, r, sc)
            paint(o, c, ao=0.0, noise_amt=0)
            hp.append(o)
        wr = tube("wr", [(sx * 0.17, 0.27, 1.43), (sx * 0.22, 0.25, 1.42)], 0.006, 4)   # морщинки-лучики
        paint(wr, hexcol("b88a6a"), ao=0.0)
        hp.append(wr)
    smile = tube("sm", [(-0.07, 0.29, 1.25), (0, 0.305, 1.23), (0.07, 0.29, 1.25)], 0.012, 6)
    paint(smile, hexcol("a04a3a"), ao=0.0)
    nose = sphere("ns", (0, 0.31, 1.33), 0.035, (1, 0.8, 0.8))
    paint(nose, shade(skin, 0.92), ao=0.0)
    hairp = [sphere("hc", (0, -0.05, 1.42), 0.32, (1.02, 1.0, 0.85)), sphere("bun", (0, -0.22, 1.62), 0.14)]
    hm = join(hairp, "Hair")
    remesh(hm, 0.02, 2)
    paint(hm, hair, ao=0.0, noise_amt=0.08, nscale=14)
    band = tube("bd", [(math.cos(a) * 0.325, math.sin(a) * 0.325 - 0.02, 1.52 + 0.04 * math.sin(a)) for a in [k * math.pi / 10 for k in range(21)]], 0.04, 8, caps=False)
    paint(band, hexcol("d9573b"), ao=0.0, fn=lambda co, n: hexcol("ffffff") if int((math.atan2(co.y, co.x) + 4) * 6) % 2 else None)
    knot = sphere("kn", (0.0, -0.33, 1.55), 0.06)
    paint(knot, hexcol("d9573b"), ao=0.0)
    hp += [nose, smile, hm, band, knot]
    h = join(hp, "Head")
    set_origin(h, (0, 0, 1.05))
    set_parent(h, b)


BUILDERS = {"banyan_giant": banyan_giant, "deck": deck, "liana": liana, "liana_curtain": liana_curtain,
            "fire_bowl": fire_bowl, "marta": marta}


# ------------------------------------------------------------------ вторая половина главы 2
def sheep():
    wool = hexcol("f4efe6")
    face = hexcol("3a3036")
    from kit import remesh
    blobs = [sphere("w", (x, y, 0.55 + z), 0.22, segs=12, rings=8) for x, y, z in
             ((0, 0, 0.05), (0.14, 0.2, 0), (-0.14, 0.2, 0), (0.14, -0.2, 0), (-0.14, -0.2, 0), (0, 0.32, 0.02), (0, -0.32, 0.02), (0, 0, 0.18))]
    import random as _r
    rr = _r.Random(3)
    for k in range(70):   # кудряшки шерсти
        th = rr.uniform(0, math.pi * 0.85)
        ph = rr.uniform(0, 2 * math.pi)
        c = (math.sin(th) * math.cos(ph) * 0.3, math.sin(th) * math.sin(ph) * 0.46, 0.6 + math.cos(th) * 0.24)
        blobs.append(sphere("cu", c, rr.uniform(0.06, 0.09), segs=8, rings=6))
    b = join(blobs, "w")
    remesh(b, 0.022, 1)
    from mathutils import noise as _nz
    paint(b, wool, ao=0.3, ao_h=0.45, noise_amt=0.1, nscale=14,
          fn=lambda co, n: shade(wool, 0.84) if _nz.noise(co * 22) < -0.35 else (shade(wool, 1.04) if n.z > 0.6 else None))
    parts = [b]
    for x in (-0.13, 0.13):
        for y in (-0.25, 0.25):
            l = tube("l", [(x, y, 0.4), (x, y, 0.03)], 0.04, 8)
            paint(l, face, ao=0.0)
            parts.append(l)
    body = join(parts, "Body")
    set_origin(body, (0, 0, 0))
    hp = [sphere("h", (0, 0.45, 0.72), 0.12, (0.85, 1.25, 0.95))]
    paint(hp[0], face, ao=0.0)
    tuft = sphere("tf", (0, 0.42, 0.84), 0.09, (1.2, 1, 0.7))
    paint(tuft, wool, ao=0.0, noise_amt=0.1, nscale=20)
    hp.append(tuft)
    for sx in (-1, 1):
        e = leaf("ear", (sx * 0.09, 0.42, 0.76), (sx, -0.2, -0.3), 0.12, 0.04, droop=0.1)
        paint(e, face, ao=0.0)
        ey = sphere("ey", (sx * 0.06, 0.55, 0.76), 0.022)
        paint(ey, hexcol("ffffff"), ao=0.0, noise_amt=0)
        hp += [e, ey]
    h = join(hp, "Head")
    set_origin(h, (0, 0.33, 0.66))
    set_parent(h, body)


def monkey():
    fur = hexcol("8a5a32")
    skin = hexcol("e8b88a")
    body = sphere("b", (0, 0, 0.32), 0.17, (1, 0.9, 1.25), segs=16, rings=10)
    paint(body, fur, ao=0.0, fn=lambda co, n: skin if (co.y > 0.1 and co.z < 0.36) else None)
    parts = [body]
    tail = tube("t", [(0, -0.14, 0.2), (0, -0.35, 0.25), (0, -0.42, 0.5), (0, -0.32, 0.62)], [0.035, 0.03, 0.025, 0.015], 8)
    paint(tail, fur, ao=0.0)
    parts.append(tail)
    for sx in (-1, 1):
        a = tube("a", [(sx * 0.15, 0.02, 0.45), (sx * 0.24, 0.08, 0.3), (sx * 0.2, 0.14, 0.18)], 0.04, 8)
        l = tube("l", [(sx * 0.09, 0.02, 0.18), (sx * 0.13, 0.08, 0.06), (sx * 0.11, 0.14, 0.02)], 0.045, 8)
        for o in (a, l):
            paint(o, fur, ao=0.0)
        parts += [a, l]
    bd = join(parts, "Body")
    set_origin(bd, (0, 0, 0))
    hp = [sphere("h", (0, 0.03, 0.6), 0.15, segs=18, rings=12)]
    paint(hp[0], fur, ao=0.0)
    face = sphere("f", (0, 0.11, 0.58), 0.11, (1.1, 0.6, 0.9))
    paint(face, skin, ao=0.0)
    hp.append(face)
    for sx in (-1, 1):
        ear = sphere("e", (sx * 0.15, 0.02, 0.63), 0.06, (0.5, 1, 1))
        paint(ear, skin, ao=0.0)
        ey = sphere("ey", (sx * 0.05, 0.17, 0.62), 0.025)
        paint(ey, hexcol("1d1d1d"), ao=0.0, noise_amt=0)
        hp += [ear, ey]
    m = tube("m", [(-0.04, 0.18, 0.54), (0, 0.19, 0.53), (0.04, 0.18, 0.54)], 0.008, 5)
    paint(m, hexcol("6b3a22"), ao=0.0)
    hp.append(m)
    h = join(hp, "Head")
    set_origin(h, (0, 0.02, 0.48))
    set_parent(h, bd)


def beehive():
    parts = [log("st", (0, 0, 0), (0, 0, 0.55), 0.05, rings=False)]
    parts.append(plank("base", (0, 0, 0.58), (0.7, 0.6, 0.06)))
    for i in range(3):
        bx = box("bx", (0, 0, 0.75 + i * 0.27), (0.62, 0.52, 0.24), bev=0.03)
        paint(bx, hexcol("f2c23a") if i % 2 == 0 else hexcol("e0a83a"), ao=0.0, fn=lambda co, n: 0.85 if abs(co.y) > 0.24 else None)
        parts.append(bx)
    roof = box("rf", (0, 0, 1.6), (0.78, 0.68, 0.1), (0, 0.0, 0), bev=0.03)
    paint(roof, hexcol("a87342"), ao=0.0)
    hole = box("hl", (0, 0.27, 0.68), (0.2, 0.02, 0.05))
    paint(hole, hexcol("2a1a10"), ao=0.0)
    parts += [roof, hole]
    for k in range(6):
        a = k * 1.1
        f = sphere("fl", (math.cos(a) * 0.55, math.sin(a) * 0.55, 0.12), 0.06, (1, 1, 0.5), segs=8, rings=5)
        paint(f, [hexcol("ff6fa5"), hexcol("ffd84a"), hexcol("b28cff")][k % 3], ao=0.0)
        parts.append(f)
    join(parts, "Beehive")


def sheep_pen():
    parts = []
    s = 1.8
    for side in range(4):
        a = side * math.pi / 2
        d = Vector((math.sin(a), -math.cos(a), 0))
        right = Vector((math.cos(a), math.sin(a), 0))
        for k in range(5):
            p = d * s + right * (k - 2) * s * 0.5
            parts.append(log("pp", (p.x, p.y, 0), (p.x, p.y, 0.85), 0.055, rings=False))
        for z in (0.35, 0.7):
            if side == 0 and z < 0.5:
                continue
            a0, a1 = d * s - right * s, d * s + right * s
            parts.append(log("rl", (a0.x, a0.y, z), (a1.x, a1.y, z), 0.04, col=hexcol("c9a467"), rings=False))
    shed = box("sh", (-0.9, 1.0, 0.6), (1.4, 1.0, 1.2), bev=0.04)
    paint(shed, hexcol("c08a50"), ao=0.2, fn=lambda co, n: 0.85 if int(co.z * 7) % 2 else None)
    roof = cyl("rf", (-0.9, 1.0, 1.2), 1.05, 0.05, 0.6, (0, 0, math.pi / 4), segs=4)
    paint(roof, hexcol("d6ad55"), ao=0.0, noise_amt=0.2, nscale=20)
    hay = box("hy", (0.9, 1.2, 0.15), (0.8, 0.5, 0.3), bev=0.06)
    displace(hay, 0.04, 0.05)
    paint(hay, hexcol("d9c45a"), ao=0.0, noise_amt=0.25, nscale=30)
    parts += [shed, roof, hay]
    join(parts, "SheepPen")


def canoe():
    """Каноэ с балансиром: долблёный корпус (нос и корма приподняты, полоса краски по борту),
    балансир-поплавок на двух поперечинах с обмоткой, две скамьи, весло, мачта с треугольным парусом.
    Длина 3 м вдоль Y (в игре — вдоль Z), как коробка столкновения 1.0 × 0.4 × 3.0."""
    import bmesh
    from kit import from_bm, solidify
    bm = bmesh.new()
    rows = []
    ns, nu = 24, 10
    for i in range(ns + 1):
        t = i / ns
        y = -1.5 + 3.0 * t
        s_ = math.sin(math.pi * t)
        w = 0.34 * s_ ** 0.55 + 0.004
        dz = 0.3 * s_ ** 0.45 + 0.004
        top = 0.42 + 0.2 * abs(2 * t - 1) ** 4
        row = []
        for j in range(nu + 1):
            ph = -math.pi / 2 + math.pi * j / nu
            row.append(bm.verts.new((w * math.sin(ph), y, top - dz * math.cos(ph) ** 0.8)))
        rows.append(row)
    for i in range(ns):
        for j in range(nu):
            bm.faces.new((rows[i][j], rows[i + 1][j], rows[i + 1][j + 1], rows[i][j + 1]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    hull = from_bm("hull", bm)
    solidify(hull, 0.045)
    subsurf(hull, 1)
    wood = hexcol("9a5e38")
    paint(hull, wood, ao=0.25, ao_h=0.3, noise_amt=0.08, nscale=8,
          fn=lambda co, n: (hexcol("f2e2c0") if n.z > 0.6 and co.z > 0.38 else (
              hexcol("c8402e") if 0.33 < co.z < 0.39 and abs(n.z) < 0.7 else (
              hexcol("f2d27a") if 0.39 <= co.z < 0.41 and abs(n.z) < 0.7 else (
              shade(wood, 1.15) if n.z > 0.3 else (0.85 if math.sin(co.y * 14 + co.z * 30) > 0.85 else None))))))
    parts = [hull]
    for y in (-0.7, 0.55):   # скамьи
        parts.append(plank("sb", (0, y, 0.33), (0.56, 0.16, 0.035), seed=int(y * 10)))
    # балансир: поплавок справа, две поперечины, стойки, обмотка
    fx = 1.05
    float_ = tube("am", [(fx, -1.0, 0.16), (fx, -0.85, 0.2), (fx, 0.0, 0.21), (fx, 0.85, 0.2), (fx, 1.0, 0.17)], [0.02, 0.06, 0.075, 0.06, 0.02], 10)
    paint(float_, hexcol("7a5236"), ao=0.0, noise_amt=0.1, nscale=10, fn=lambda co, n: hexcol("9a7250") if n.z > 0.5 else None)
    parts.append(float_)
    for y in (-0.55, 0.55):
        parts.append(log("bo", (-0.25, y, 0.44), (fx + 0.06, y, 0.4), 0.032, col=hexcol("8a6a48"), rings=True))
        parts.append(log("st", (fx, y, 0.22), (fx, y, 0.41), 0.022, col=hexcol("8a6a48"), rings=False))
        for xx in (0.3, fx):
            parts.append(rope_wrap("rw", (xx, y), 0.04, 0.38 if xx < 1 else 0.36, 2))
    # весло, положенное поперёк
    parts.append(log("pd", (-0.3, -0.25, 0.38), (0.35, 0.65, 0.4), 0.018, col=hexcol("b8834b"), rings=False))
    blade = sphere("bl", (0.42, 0.78, 0.4), 0.11, (0.5, 1.3, 0.12), (0, 0, -0.62), segs=12, rings=6)
    paint(blade, hexcol("b8834b"), ao=0.0, fn=lambda co, n: hexcol("c8402e") if abs(co.y - 0.8) < 0.025 else None)
    parts.append(blade)
    mast = log("ms", (0, 0.35, 0.15), (0, 0.35, 2.3), 0.035, rings=False)
    parts.append(mast)
    join(parts, "Canoe")
    # парус-треугольник, чуть надутый ветром, с рейками
    bm = bmesh.new()
    vs = []
    for i in range(6):
        row = []
        for j in range(6 - i):
            u = j / 5
            v = i / 5
            p = Vector((0.03, 0.35, 0.55)) + Vector((0, 0, 1.7)) * v + Vector((0, -1.15, 0.05)) * u
            p.x += math.sin(math.pi * u) * math.sin(math.pi * min(1, v * 1.2)) * 0.12
            row.append(bm.verts.new(p))
        vs.append(row)
    for i in range(5):
        for j in range(5 - i):
            bm.faces.new((vs[i][j], vs[i][j + 1], vs[i + 1][j]))
            if j + 1 < len(vs[i + 1]):
                bm.faces.new((vs[i][j + 1], vs[i + 1][j + 1], vs[i + 1][j]))
    sail = from_bm("Sail_cloth", bm)
    solidify(sail, 0.015)
    paint(sail, hexcol("efe2c8"), ao=0.0, fn=lambda co, n: hexcol("c8a878") if (co.z - 0.55) % 0.42 < 0.03 else (
        hexcol("d9573b") if co.z > 1.95 else None))


def treehouse_ruin():
    """Разрушенный дом Лёвы на ярусе: каркас, провалившаяся крыша, доски вразброс."""
    parts = []
    for x, y, h in ((-1.0, -0.9, 2.0), (1.0, -0.9, 1.4), (-1.0, 0.9, 2.0), (1.0, 0.9, 0.9)):
        parts.append(log("pp", (x, y, 0), (x, y, h), 0.07, rings=False))
    parts.append(log("bm", (-1.0, -0.9, 1.9), (-1.0, 0.9, 1.9), 0.05, rings=False))
    for k in range(4):
        parts.append(plank("wl", (-1.0, -0.6 + k * 0.4, 0.3 + (k % 2) * 0.25), (0.06, 0.36, 0.5)))
    for k in range(5):
        parts.append(plank("db", (-0.4 + k * 0.25, -0.2 + (k % 3) * 0.3, 0.06 + 0.04 * k), (0.9, 0.18, 0.05), (0.1 * k, 0.05, 0.6 * k)))
    tarp = box("tp", (0.2, 0.2, 0.15), (1.4, 1.2, 0.04), (0.15, -0.1, 0.3), bev=0.02)
    paint(tarp, hexcol("c9bfa0"), ao=0.0, fn=lambda co, n: hexcol("6f8a4a") if math.sin(co.x * 6 + co.y * 5) > 0.6 else None)
    parts.append(tarp)
    join(parts, "TreehouseRuin")


def treehouse():
    """Восстановленный дом Лёвы: стены из досок, круглое окно, крыша из листьев, флюгер-альбатрос."""
    parts = [plank("fl", (0, 0, 0.04), (2.3, 2.0, 0.08))]
    for side in range(4):
        a = side * math.pi / 2
        d = Vector((math.sin(a), -math.cos(a), 0))
        right = Vector((math.cos(a), math.sin(a), 0))
        ln = 2.2 if side % 2 == 0 else 1.9
        for k in range(6):
            z = 0.2 + k * 0.32
            if side == 0 and k < 5 and False:
                continue
            p = d * (0.95 if side % 2 == 0 else 1.1)
            w = box("wb", (p.x, p.y, z), (ln if side % 2 == 0 else 0.08, 0.08 if side % 2 == 0 else ln, 0.3), bev=0.02)
            if side == 0 and abs(k - 1.5) < 2 and True:
                pass
            paint(w, shade(hexcol("c08a50"), 0.9 + 0.1 * (k % 2)), ao=0.2, ao_h=0.5, fn=lambda co, n: 0.82 if math.sin(co.x * 20 + co.y * 20) > 0.8 else None)
            parts.append(w)
    door = box("dr", (0, -0.98, 0.6), (0.6, 0.04, 1.1), bev=0.02)
    paint(door, hexcol("6b3a22"), ao=0.0)
    win = cyl("wn", (1.12, 0, 1.2), 0.25, 0.25, 0.04, (0, math.pi / 2, 0), 16)
    paint(win, hexcol("8fc3e8"), ao=0.0, fn=lambda co, n: hexcol("6b3a22") if (abs(co.y) < 0.03 or abs(co.z - 1.2) < 0.03) else None)
    parts += [door, win]
    roof = cyl("rf", (0, 0, 2.05), 1.75, 0.08, 1.1, (0, 0, math.pi / 4), segs=4)
    displace(roof, 0.05, 0.08)
    paint(roof, hexcol("4f8a3a"), ao=0.0, noise_amt=0.15, nscale=12, fn=lambda co, n: 0.8 if math.sin(co.z * 40) > 0.7 else None)
    parts.append(roof)
    vane = log("vn", (0, 0, 3.1), (0, 0, 3.6), 0.02, rings=False)
    bird = leaf("vb", (-0.2, 0, 3.6), (1, 0, 0), 0.4, 0.06, droop=0.0, fold=0.0, up=(0, 1, 0))
    paint(bird, hexcol("f2f2f2"), ao=0.0)
    parts += [vane, bird]
    join(parts, "Treehouse")


def chest():
    body = box("b", (0, 0, 0.22), (0.8, 0.5, 0.44), bev=0.04)
    paint(body, hexcol("8a5a32"), ao=0.0, fn=lambda co, n: hexcol("c9a050") if (abs(co.x) > 0.34 or abs(co.z - 0.22) < 0.03) else None)
    lock = box("lk", (0, -0.27, 0.36), (0.12, 0.04, 0.14), bev=0.01)
    paint(lock, hexcol("e8c050"), ao=0.0)
    lid = lathe("ld", [(0.0, 0.0), (0.25, 0.0), (0.25, 0.05), (0.0, 0.26)], 12, rot=(0, math.pi / 2, 0), scale=(1, 1, 1.6), loc=(0, 0, 0.44))
    paint(lid, hexcol("9a6a3e"), ao=0.0)
    b = join([body, lock], "Chest")
    l = join([lid], "Lid")
    set_origin(l, (0, 0.25, 0.44))
    set_parent(l, b)


BUILDERS.update({"sheep": sheep, "monkey": monkey, "beehive": beehive, "sheep_pen": sheep_pen, "canoe": canoe,
                 "treehouse_ruin": treehouse_ruin, "treehouse": treehouse, "chest": chest})
