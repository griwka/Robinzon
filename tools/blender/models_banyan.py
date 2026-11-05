"""Глава 2 — остров Великого Баньяна: исполинское дерево, площадки-ярусы, лианы для лазания,
завесы лиан (преграда для мачете), жаровня с огнём и Мелани — кок «Альбатроса»."""
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


# ------------------------------------------------------------------ Мелани
def melanie():
    """Мелани: кок «Альбатроса». Седые волосы в пучке под банданой, фартук, деревянный половник."""
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
            "fire_bowl": fire_bowl, "melanie": melanie}
