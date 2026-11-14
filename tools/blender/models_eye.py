"""Глава 8 — Око шторма: Лёва (худой, в обгоревшей куртке, руки в бинтах), домик деда, насест для попугая,
одичавшая яблоня, скамейка, которую чинили много раз, заросшая грядка, коробка писем, Книга Хранителей на каменном столе,
Великий маяк (снаружи и внутри: три яруса, полая середина с дверью), выступы и уступы на его стене,
чаша Великого огня с оправой линзы, стена шторма; после финала — доска заказов.

Координаты: Blender (x, y, z) → Godot (x, z, −y). «Вперёд» в Godot (+Z) — это −Y в Blender."""
import math

import bmesh
import bpy

from kit import (box, cyl, displace, empty, from_bm, hexcol, ico, join, lathe, leaf, paint, rnd, set_origin, set_parent,
                 shade, sphere, subsurf, tube)
from models_buildings import plank, stone
from models_fog import _person

# чёрный камень Ока: тёплый, чуть фиолетовый — не «уголь»
BLACK = hexcol("45404a")
BLACK_L = hexcol("5e5862")
MORTAR = hexcol("8a8288")
BRONZE = hexcol("9a7038")
WOOD_OLD = hexcol("8a6a48")
WOOD_W = hexcol("a88458")
MOSS = hexcol("6a9a4a")


# ================================================================== Лёва
def lyova():
    """Лёва: худой, седой не по возрасту, в обгоревшей капитанской куртке; руки в бинтах, щетина."""
    def extra(parts, hp, hz):
        # подпалины на куртке
        r = rnd(8)
        for k in range(7):
            a = r.uniform(0, 2 * math.pi)
            z = r.uniform(0.45, 0.95)
            p = sphere("bn", (math.cos(a) * 0.27, math.sin(a) * 0.27, z), r.uniform(0.05, 0.08), (1.0, 0.4, 1.2))
            paint(p, hexcol("2a2420"), ao=0.0, fn=lambda co, n: hexcol("8a4a22") if (co.z * 31) % 1.0 < 0.3 else None)
            parts.append(p)
        # воротник и пуговицы капитанской куртки
        collar = tube("cl", [(math.cos(a) * 0.17, math.sin(a) * 0.17 + 0.01, 1.03) for a in [k * math.pi / 8 for k in range(17)]], 0.045, 8, caps=False)
        paint(collar, hexcol("26303c"), ao=0.0)
        parts.append(collar)
        for k in range(3):
            bt = sphere("bt", (0.0, 0.29, 0.62 + k * 0.13), 0.02, segs=8, rings=5)
            paint(bt, hexcol("c9a050"), ao=0.0, noise_amt=0)
            parts.append(bt)
        # бинты на кистях и запястьях
        for sx in (-1, 1):
            for k in range(3):
                z = 0.47 + k * 0.05
                w = tube("bd", [(sx * 0.31 + math.cos(a) * 0.08, 0.14 + math.sin(a) * 0.08, z + a * 0.004) for a in [j * math.pi / 6 for j in range(13)]],
                         0.018, 6, caps=False)
                paint(w, hexcol("f2ead8"), ao=0.0)
                parts.append(w)
        # седые растрёпанные волосы
        hair = sphere("hr", (0, -0.03, 1.45), 0.28, (1.0, 1.0, 0.72))
        paint(hair, hexcol("c8c4bc"), ao=0.0, noise_amt=0.18, nscale=25, mat="hair")
        hp.append(hair)
        for k in range(6):
            a = -0.9 + k * 0.36
            sp = tube("tf", [(math.sin(a) * 0.2, math.cos(a) * 0.1 - 0.05, 1.6), (math.sin(a) * 0.3, math.cos(a) * 0.14 - 0.08, 1.66)], [0.045, 0.006], 6)
            paint(sp, hexcol("b8b4ac"), ao=0.0, mat="hair")
            hp.append(sp)
        # щетина, усталые брови, тонкий рот
        stub = sphere("st", (0, 0.12, 1.24), 0.2, (1.05, 0.75, 0.6))
        paint(stub, hexcol("9a948a"), ao=0.0, noise_amt=0.3, nscale=40, mat="stubble")
        hp.append(stub)
        for sx in (-1, 1):
            br = tube("bw", [(sx * 0.04, 0.25, 1.47), (sx * 0.15, 0.24, 1.455)], 0.015, 6)
            paint(br, hexcol("8a8680"), ao=0.0)
            hp.append(br)
            bag = sphere("bg", (sx * 0.1, 0.235, 1.355), 0.045, (1.0, 0.35, 0.4))
            paint(bag, hexcol("c89a80"), ao=0.0, noise_amt=0)
            hp.append(bag)
        mouth = tube("mo", [(-0.05, 0.25, 1.27), (0.0, 0.255, 1.265), (0.05, 0.25, 1.27)], 0.011, 6)
        paint(mouth, hexcol("8a4a3a"), ao=0.0)
        hp.append(mouth)
    _person(hexcol("2e3a4a"), hexcol("4a4238"), hexcol("e0b493"), hexcol("c8c4bc"), extra)
    b = bpy.data.objects["Body"]
    b.scale = (0.86, 0.86, 1.0)          # худой
    bpy.data.objects["Head"].scale = (1 / 0.86, 1 / 0.86, 1.0)


# ================================================================== сад деда
def grandfather_house():
    """Домик деда: низ из чёрного камня, стены из старых досок, двускатная крыша со мхом, крыльцо с навесом,
    дверь, окно со ставнями, труба. Перед домом (−Y) — крыльцо."""
    parts = []
    r = rnd(31)
    W, D, H = 3.6, 3.0, 2.3
    # цоколь из камня
    for k in range(18):
        t = k / 18.0
        if t < 0.25:
            x, y = -W / 2 + t / 0.25 * W, -D / 2
        elif t < 0.5:
            x, y = W / 2, -D / 2 + (t - 0.25) / 0.25 * D
        elif t < 0.75:
            x, y = W / 2 - (t - 0.5) / 0.25 * W, D / 2
        else:
            x, y = -W / 2, D / 2 - (t - 0.75) / 0.25 * D
        parts.append(stone("fs", (x, y, 0.25), r.uniform(0.32, 0.42), k, BLACK_L))
    base = box("bs", (0, 0, 0.4), (W, D, 0.8), bev=0.04)
    paint(base, BLACK_L, ao=0.2, fn=lambda co, n: shade(BLACK_L, 0.8) if (co.z * 5 + (co.x + co.y) * 1.3) % 1.0 < 0.1 else None)
    parts.append(base)
    # дощатые стены
    walls = box("wl", (0, 0, 0.8 + (H - 0.8) / 2), (W - 0.1, D - 0.1, H - 0.8), bev=0.02)
    paint(walls, WOOD_OLD, ao=0.15, fn=lambda co, n: shade(WOOD_OLD, 0.78) if (co.z * 4.2) % 1.0 < 0.08 else
          (hexcol("b89a6a") if 1.3 < co.z < 1.75 and co.x > 1.0 and n.y > 0.5 else None))
    parts.append(walls)
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(plank("cp", (sx * (W / 2 - 0.05), sy * (D / 2 - 0.05), H / 2 + 0.2), (0.16, 0.16, H - 0.2), col=hexcol("6a4a2e")))
    # двускатная крыша вдоль X, конёк на 3.3 м
    for sy in (-1, 1):
        roof = box("rf", (0, sy * 0.95, 2.82), (W + 0.6, 2.1, 0.14), (-sy * 0.5, 0, 0), bev=0.03)
        paint(roof, hexcol("8a5a3a"), ao=0.0, fn=lambda co, n: (MOSS if math.sin(co.x * 3.1 + co.y * 2.0) > 0.55 else
                                                               (shade(hexcol("8a5a3a"), 0.8) if (co.x * 2.5) % 1.0 < 0.1 else None)))
        parts.append(roof)
    for sx in (-1, 1):
        bm = bmesh.new()
        v = [bm.verts.new((sx * (W / 2 - 0.05), -D / 2 + 0.05, H)), bm.verts.new((sx * (W / 2 - 0.05), D / 2 - 0.05, H)),
             bm.verts.new((sx * (W / 2 - 0.05), 0, 3.2))]
        bm.faces.new(v if sx > 0 else v[::-1])
        g = from_bm("gb", bm, smooth=False)
        paint(g, WOOD_W, ao=0.0)
        parts.append(g)
    ridge = tube("rg", [(-W / 2 - 0.3, 0, 3.32), (W / 2 + 0.3, 0, 3.32)], 0.08, 8)
    paint(ridge, hexcol("6a4a2e"), ao=0.0)
    parts.append(ridge)
    chim = box("ch", (W / 2 - 0.6, 0.6, 3.2), (0.5, 0.5, 1.2), bev=0.03)
    paint(chim, BLACK_L, ao=0.0, fn=lambda co, n: shade(BLACK_L, 0.75) if (co.z * 6) % 1.0 < 0.12 else None)
    parts.append(chim)
    # дверь и окно — на передней стене (−Y)
    door = box("dr", (-0.6, -D / 2 - 0.03, 1.05), (0.9, 0.08, 1.8), bev=0.02)
    paint(door, hexcol("5a3a22"), ao=0.0, fn=lambda co, n: shade(hexcol("5a3a22"), 0.8) if (co.x * 7) % 1.0 < 0.1 else None)
    knob = sphere("kn", (-0.25, -D / 2 - 0.09, 1.0), 0.04)
    paint(knob, BRONZE, ao=0.0)
    parts += [door, knob]
    win = box("wn", (0.85, -D / 2 - 0.02, 1.45), (0.8, 0.06, 0.65))
    paint(win, hexcol("bfe0f0"), ao=0.0, noise_amt=0)
    parts.append(win)
    for x, z, sx, sz in ((0.85, 1.45, 0.06, 0.7), (0.85, 1.45, 0.85, 0.06)):
        f = box("wf", (x, -D / 2 - 0.06, z), (sx, 0.05, sz))
        paint(f, hexcol("f2ead8"), ao=0.0)
        parts.append(f)
    for sx in (-1, 1):
        sh = box("sh", (0.85 + sx * 0.62, -D / 2 - 0.06, 1.45), (0.4, 0.05, 0.75), (0, sx * 0.25, 0))
        paint(sh, hexcol("4a7a8a"), ao=0.0, fn=lambda co, n: 0.85 if (co.z * 9) % 1.0 < 0.15 else None)
        parts.append(sh)
    # крыльцо и навес
    deck = plank("pd", (-0.2, -D / 2 - 0.45, 0.22), (2.6, 0.9, 0.12), col=WOOD_W)
    parts.append(deck)
    for x in (-1.4, 1.0):
        parts.append(plank("pp", (x, -D / 2 - 0.82, 1.15), (0.1, 0.1, 1.9), col=hexcol("6a4a2e")))
    awn = box("aw", (-0.2, -D / 2 - 0.55, 2.15), (2.9, 1.2, 0.08), (-0.25, 0, 0), bev=0.02)
    paint(awn, hexcol("8a5a3a"), ao=0.0, fn=lambda co, n: MOSS if math.sin(co.x * 4.0) > 0.6 else None)
    parts.append(awn)
    # фото на стене у двери (дед в лётной куртке с попугаем)
    ph = box("ph", (0.05, -D / 2 - 0.05, 1.55), (0.32, 0.03, 0.4))
    paint(ph, hexcol("6a4a2e"), ao=0.0)
    pi = box("pi", (0.05, -D / 2 - 0.07, 1.55), (0.24, 0.02, 0.32))
    paint(pi, hexcol("d8c8a0"), ao=0.0, fn=lambda co, n: hexcol("e8443a") if co.x > 0.08 and co.z > 1.6 else
          (hexcol("5a4a3a") if abs(co.x - 0.02) < 0.06 and co.z < 1.62 else None))
    parts += [ph, pi]
    join(parts, "GrandfatherHouse")


def perch():
    """Насест для попугая: шест с перекладиной, жестяная плошка, крестовина и красное пёрышко."""
    parts = []
    for a in (0.0, math.pi / 2):
        ft = plank("ft", (0, 0, 0.05), (0.9, 0.1, 0.08), (0, 0, a), col=hexcol("6a4a2e"))
        parts.append(ft)
    pole = tube("pl", [(0, 0, 0.05), (0.02, 0, 0.8), (0, 0.01, 1.45)], [0.05, 0.045, 0.04], 8)
    paint(pole, WOOD_W, ao=0.0, fn=lambda co, n: shade(WOOD_W, 0.85) if (co.z * 6) % 1.0 < 0.15 else None)
    bar = tube("br", [(-0.35, 0, 1.45), (0.35, 0, 1.45)], 0.035, 8)
    paint(bar, hexcol("c8a070"), ao=0.0, fn=lambda co, n: shade(hexcol("c8a070"), 0.7) if abs(co.x) < 0.12 else None)
    cup = lathe("cp", [(0.0, 1.38), (0.1, 1.39), (0.12, 1.47), (0.11, 1.48), (0.0, 1.43)], 12, loc=(0.42, 0, 0))
    paint(cup, hexcol("a8b0b8"), ao=0.0)
    feather = leaf("fe", (-0.05, 0.02, 0.06), (1, 0.3, 0.15), 0.18, 0.05, droop=0.1)
    paint(feather, hexcol("e8443a"), ao=0.0)
    parts += [pole, bar, cup, feather]
    join(parts, "Perch")


def apple_tree():
    """Старая яблоня: кривой ствол, раскидистая крона, красные яблоки, пара упавших в траву."""
    r = rnd(44)
    parts = []
    trunk = tube("tr", [(0, 0, -0.1), (0.15, 0.05, 0.8), (-0.05, 0.1, 1.5), (0.1, 0, 2.0)], [0.22, 0.17, 0.14, 0.1], 10)
    displace(trunk, 0.03, 0.2, "VORONOI")
    paint(trunk, hexcol("6a5040"), ao=0.2, mat="bark")
    parts.append(trunk)
    for a, ln in ((0.4, 0.9), (2.3, 0.8), (4.2, 0.85)):
        br = tube("bb", [(0.05, 0.03, 1.6), (math.cos(a) * ln * 0.6, math.sin(a) * ln * 0.6, 2.1), (math.cos(a) * ln, math.sin(a) * ln, 2.45)], [0.09, 0.06, 0.035], 8)
        paint(br, hexcol("6a5040"), ao=0.0)
        parts.append(br)
    for k in range(4):
        a = r.uniform(0, 2 * math.pi)
        ap = sphere("fa", (math.cos(a) * r.uniform(0.6, 1.2), math.sin(a) * r.uniform(0.6, 1.2), 0.07), 0.08)
        paint(ap, hexcol("d8443a"), ao=0.0, fn=lambda co, n: hexcol("f2c03a") if n.z > 0.6 else None)
        parts.append(ap)
    join(parts, "AppleTree")
    crown = []
    for k in range(7):
        a = k * 2 * math.pi / 6 if k < 6 else 0
        rad = 0.9 if k < 6 else 0.0
        c = ico("cr", (math.cos(a) * rad, math.sin(a) * rad, 2.7 + (0.45 if k == 6 else r.uniform(-0.15, 0.15))), r.uniform(0.75, 0.95), sub=2)
        displace(c, 0.12, 0.4, "VORONOI", seed=k)
        crown.append(c)
    cr = join(crown, "Crown_leaf")
    paint(cr, hexcol("5aa04a"), ao=0.25, ao_h=1.6, ground=2.0, noise_amt=0.15, nscale=2.5,
          fn=lambda co, n: hexcol("78b858") if n.z > 0.55 else None)
    apples = []
    for k in range(14):
        a = r.uniform(0, 2 * math.pi)
        z = r.uniform(2.3, 3.2)
        rad = 1.55 - abs(z - 2.75) * 0.6
        ap = sphere("ap", (math.cos(a) * rad, math.sin(a) * rad, z), 0.1, segs=10, rings=6)
        paint(ap, hexcol("e0443a"), ao=0.0, fn=lambda co, n: hexcol("f2a03a") if n.z > 0.5 else None)
        apples.append(ap)
    ab = join(apples, "Apples")
    set_parent(ab, bpy.data.objects["AppleTree"])
    set_parent(cr, bpy.data.objects["AppleTree"])


def grandpa_bench():
    """Скамейка деда: доски трёх разных цветов (чинили много раз), заплатки на гвоздях, верёвка на ножке."""
    parts = []
    for k, c in enumerate((hexcol("b8834b"), hexcol("8a6a48"), hexcol("c99a5e"))):
        parts.append(plank("sp", (0, -0.15 + k * 0.15, 0.48), (1.7, 0.14, 0.06), col=c, seed=k))
    for k, c in enumerate((hexcol("a07a50"), hexcol("d6b07a"))):
        parts.append(plank("bk", (0, 0.32, 0.75 + k * 0.2), (1.7, 0.06, 0.14), col=c, seed=k + 5))
    for sx in (-1, 1):
        parts.append(plank("lg", (sx * 0.7, -0.15, 0.24), (0.08, 0.08, 0.48), col=hexcol("6a4a2e")))
        parts.append(plank("lb", (sx * 0.7, 0.32, 0.5), (0.08, 0.08, 1.0), col=hexcol("6a4a2e")))
    patch = plank("pt", (0.35, 0.0, 0.52), (0.3, 0.2, 0.03), col=hexcol("d6c09a"))
    parts.append(patch)
    for k in range(4):
        n = sphere("nl", (0.23 + (k % 2) * 0.24, -0.08 + (k // 2) * 0.16, 0.54), 0.015, segs=6, rings=4)
        paint(n, hexcol("8a929a"), ao=0.0, noise_amt=0)
        parts.append(n)
    rope = tube("rp", [(-0.7 + 0.06 * math.cos(a), -0.15 + 0.06 * math.sin(a), 0.2 + a * 0.012) for a in [j * math.pi / 5 for j in range(21)]], 0.014, 5, caps=False)
    paint(rope, hexcol("d4b483"), ao=0.0)
    parts.append(rope)
    join(parts, "GrandpaBench")


def wild_bed():
    """Заросшая грядка: рассохшаяся рамка из досок, комья земли, сорная трава, одичавшая капуста и согнутый колышек."""
    r = rnd(9)
    parts = []
    for sy in (-1, 1):
        parts.append(plank("fx", (0, sy * 0.45, 0.1), (1.8, 0.08, 0.2), col=hexcol("7a5a3a"), seed=sy + 2))
    for sx in (-1, 1):
        parts.append(plank("fy", (sx * 0.86, 0, 0.1), (0.08, 0.9, 0.2), col=hexcol("7a5a3a"), seed=sx + 4))
    soil = box("sl", (0, 0, 0.12), (1.66, 0.82, 0.12))
    paint(soil, hexcol("6a4a34"), ao=0.0, noise_amt=0.2, nscale=8)
    parts.append(soil)
    for k in range(16):
        x, y = r.uniform(-0.75, 0.75), r.uniform(-0.35, 0.35)
        for j in range(3):
            a = r.uniform(0, 2 * math.pi)
            bl = leaf("wd", (x, y, 0.17), (math.cos(a) * 0.3, math.sin(a) * 0.3, 1.0), r.uniform(0.25, 0.45), 0.05, droop=0.3)
            paint(bl, hexcol("6aa04a") if j % 2 else hexcol("8ab858"), ao=0.0)
            parts.append(bl)
    for x in (-0.45, 0.4):
        cb = sphere("cb", (x, 0.05, 0.28), 0.18, (1.0, 1.0, 0.7))
        displace(cb, 0.03, 0.08)
        paint(cb, hexcol("8ac06a"), ao=0.0, fn=lambda co, n: hexcol("b8d888") if n.z > 0.7 else None, mat="cabbage")
        parts.append(cb)
    stake = tube("sk", [(0.75, -0.3, 0.1), (0.8, -0.32, 0.6), (0.95, -0.36, 0.85)], 0.025, 6)
    paint(stake, hexcol("a07a50"), ao=0.0, mat="wood")
    parts.append(stake)
    join(parts, "WildBed")


def letters_box():
    """Ящик с письмами деда: пачки конвертов, перевязанные бечёвкой, сверху — одно письмо отдельно."""
    parts = []
    crate = box("cr", (0, 0, 0.2), (0.62, 0.42, 0.4), bev=0.02)
    paint(crate, WOOD_W, ao=0.15, fn=lambda co, n: shade(WOOD_W, 0.78) if (co.z * 7) % 1.0 < 0.12 else None)
    inner = box("in", (0, 0, 0.38), (0.54, 0.34, 0.05))
    paint(inner, hexcol("4a3424"), ao=0.0)
    parts += [crate, inner]
    for k in range(5):
        x = -0.2 + k * 0.1
        st = box("st", (x, 0, 0.44), (0.08, 0.26, 0.14), (0.0, 0.08 * (k % 2 - 0.5), 0))
        paint(st, hexcol("efe4c8"), ao=0.0, fn=lambda co, n: shade(hexcol("efe4c8"), 0.9) if (co.z * 50) % 1.0 < 0.3 else None)
        tie = box("ti", (x, 0, 0.44), (0.085, 0.02, 0.15))
        paint(tie, hexcol("c87a52"), ao=0.0)
        parts += [st, tie]
    top = box("tp", (0.05, -0.05, 0.54), (0.24, 0.16, 0.01), (0, 0, 0.3))
    paint(top, hexcol("f6ecd2"), ao=0.0, fn=lambda co, n: hexcol("5a4a8a") if abs(co.y + 0.05) < 0.012 and abs(co.x - 0.05) < 0.08 else None)
    parts.append(top)
    join(parts, "LettersBox")


def keepers_book():
    """Книга Хранителей: тяжёлый каменный стол из чёрного камня с резьбой, раскрытая толстая книга в коже,
    закладка, чернильница с пером."""
    parts = []
    top = box("tt", (0, 0, 0.88), (1.3, 0.85, 0.16), bev=0.04)
    paint(top, BLACK_L, ao=0.0, fn=lambda co, n: shade(BLACK_L, 1.25) if n.z > 0.5 else None)
    leg = lathe("lg", [(0.5, 0.0), (0.42, 0.12), (0.3, 0.3), (0.32, 0.6), (0.42, 0.8), (0.0, 0.8)], 8)
    paint(leg, BLACK, ao=0.2, fn=lambda co, n: hexcol("c9a050") if abs(co.z - 0.45) < 0.03 else None)
    parts += [top, leg]
    for sx in (-1, 1):
        cover = box("cv", (sx * 0.27, 0, 0.98), (0.52, 0.66, 0.04), (0, sx * -0.08, 0), bev=0.01)
        paint(cover, hexcol("6a2e22"), ao=0.0)
        pages = box("pg", (sx * 0.25, 0, 1.03), (0.46, 0.6, 0.07), (0, sx * -0.1, 0), bev=0.01)
        paint(pages, hexcol("efe2c0"), ao=0.0, fn=lambda co, n: (hexcol("4a3a2a") if n.z > 0.7 and (co.y * 22) % 1.0 < 0.2 and abs(co.x) > 0.06 else None))
        parts += [cover, pages]
    spine = tube("sn", [(0, -0.3, 1.0), (0, 0.3, 1.0)], 0.04, 8)
    paint(spine, hexcol("5a2418"), ao=0.0)
    ribbon = box("rb", (0.02, -0.38, 0.97), (0.03, 0.2, 0.01))
    paint(ribbon, hexcol("c0392b"), ao=0.0)
    ink = lathe("ik", [(0.0, 0.96), (0.07, 0.96), (0.07, 1.06), (0.03, 1.08), (0.0, 1.08)], 10, loc=(0.5, 0.28, 0))
    paint(ink, hexcol("2a2a3a"), ao=0.0)
    quill = leaf("ql", (0.5, 0.28, 1.06), (0.3, -0.1, 1.0), 0.32, 0.05, droop=0.15)
    paint(quill, hexcol("f4f4ee"), ao=0.0)
    parts += [spine, ribbon, ink, quill]
    join(parts, "KeepersBook")


# ================================================================== Великий маяк
H1, H2, H3 = 9.0, 18.0, 28.0


def bdir(d):
    """Направление в модели для угла d от линии подъёма (см. GreatLighthouse: подъём смотрит в −Y)."""
    return (-math.sin(d), -math.cos(d))


def _stone_fn(base, rows=0.62):
    def f(co, n):
        z = co.z
        a = math.atan2(co.y, co.x)
        row = int(z / rows)
        if (z / rows) % 1.0 < 0.09:
            return MORTAR
        if ((a * 6.0 + row * 0.5) % 1.0) < 0.04:
            return shade(MORTAR, 0.8)
        k = ((row * 7 + int(a * 6.0 + row * 0.5)) % 5) / 5.0
        return shade(base, 0.86 + k * 0.28)
    return f


def _ring_wall(name, r_out, r_in, z0, z1, gap_a, gap_w, gap_top, segs=48):
    """Полая стена (кольцо) с дверным проёмом: угол середины gap_a (рад., в плоскости XY), полуширина gap_w, высота gap_top."""
    bm = bmesh.new()
    zs = [z0, gap_top, z1]

    def in_gap(a):
        return abs((a - gap_a + math.pi) % (2 * math.pi) - math.pi) < gap_w

    def v(r, a, z):
        return bm.verts.new((math.cos(a) * r, math.sin(a) * r, z))

    for i in range(segs):
        a0 = 2 * math.pi * i / segs
        a1 = 2 * math.pi * (i + 1) / segs
        gap = in_gap((a0 + a1) * 0.5)
        for j in range(2):
            if gap and j == 0:
                continue
            za, zb = zs[j], zs[j + 1]
            bm.faces.new((v(r_out, a0, za), v(r_out, a1, za), v(r_out, a1, zb), v(r_out, a0, zb)))
            bm.faces.new((v(r_in, a1, za), v(r_in, a0, za), v(r_in, a0, zb), v(r_in, a1, zb)))
        # верх и низ стены
        bm.faces.new((v(r_in, a0, z1), v(r_out, a0, z1), v(r_out, a1, z1), v(r_in, a1, z1)))
        if not gap:
            bm.faces.new((v(r_out, a0, z0), v(r_in, a0, z0), v(r_in, a1, z0), v(r_out, a1, z0)))
        else:
            bm.faces.new((v(r_out, a0, gap_top), v(r_in, a0, gap_top), v(r_in, a1, gap_top), v(r_out, a1, gap_top)))
        # откосы проёма
        prev_gap = in_gap((a0 - math.pi / segs))
        if gap and not prev_gap:
            bm.faces.new((v(r_out, a0, z0), v(r_out, a0, gap_top), v(r_in, a0, gap_top), v(r_in, a0, z0)))
        next_gap = in_gap((a1 + math.pi / segs))
        if gap and not next_gap:
            bm.faces.new((v(r_in, a1, z0), v(r_in, a1, gap_top), v(r_out, a1, gap_top), v(r_out, a1, z0)))
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return from_bm(name, bm, smooth=False)


def _railing(parts, r, z, n):
    for k in range(n):
        a = 2 * math.pi * k / n
        parts.append(tube("rp", [(math.cos(a) * r, math.sin(a) * r, z), (math.cos(a) * r, math.sin(a) * r, z + 1.12)], 0.045, 6))
    for zz in (z + 0.55, z + 1.12):
        parts.append(tube("rr", [(math.cos(a) * r, math.sin(a) * r, zz) for a in [k * 2 * math.pi / 64 for k in range(65)]], 0.04, 6, caps=False))


def _hatch(parts, d, rad, z):
    x, y = bdir(d)
    hole = box("hh", (x * rad, y * rad, z + 0.01), (0.95, 0.95, 0.03), (0, 0, -d))
    paint(hole, hexcol("1e1a18"), ao=0.0, noise_amt=0)
    lid = plank("hl", (x * rad + x * 0.1, y * rad + y * 0.1, z + 0.48), (0.9, 0.06, 0.9), (math.pi / 2 - 0.2, 0, -d), col=WOOD_OLD)
    parts += [hole, lid]


def _corbels(parts, r0, r1, z, n):
    for k in range(n):
        a = 2 * math.pi * (k + 0.5) / n
        c = box("cb", (math.cos(a) * (r0 + r1) / 2, math.sin(a) * (r0 + r1) / 2, z - 0.25), (r1 - r0, 0.4, 0.5), (0, 0, a), bev=0.04)
        paint(c, BLACK_L, ao=0.0)
        parts.append(c)


def great_lighthouse():
    """Великий маяк: три яруса. Низ — сплошная кладка из чёрного камня, балкон с перилами и люком;
    середина — полая, с дверью на первом балконе и окнами-бойницами (внутри — лестница, её ставит игра);
    верх — снова кладка, резной пояс с огнями маяков; наверху площадка с перилами и каменная корона."""
    parts = []
    # основание и нижний ярус
    low = lathe("lw", [(4.6, -0.6), (4.5, 0.3), (4.1, 0.45), (4.05, H1 - 0.4)], 64)
    paint(low, BLACK, ao=0.3, ao_h=1.5, noise_amt=0.05, fn=_stone_fn(BLACK))
    parts.append(low)
    # балкон 1: плита (внутри — дощатый пол средней части), корбели, перила, люк над подъёмом
    s1 = lathe("s1", [(0.0, H1 - 0.4), (6.2, H1 - 0.4), (6.2, H1), (0.0, H1)], 64)
    paint(s1, BLACK_L, ao=0.0, fn=lambda co, n: (hexcol("a07a50") if (co.x * co.x + co.y * co.y) < 3.3 * 3.3 and n.z > 0.5 else
                                                 (shade(BLACK_L, 1.2) if n.z > 0.5 else None)))
    parts.append(s1)
    _corbels(parts, 4.05, 6.0, H1 - 0.4, 20)
    _railing(parts, 6.08, H1, 28)
    _hatch(parts, 0.0, 4.55, H1)
    # средний ярус — полый, дверь на стороне d = +PI/2
    dx, dy = bdir(math.pi / 2)
    mid = _ring_wall("md", 3.85, 3.3, H1, H2 - 0.4, math.atan2(dy, dx), 0.28, H1 + 2.6)
    paint(mid, BLACK, ao=0.0, fn=lambda co, n: (hexcol("8a7a6a") if (co.x * co.x + co.y * co.y) < 3.5 * 3.5 else
                                               (hexcol("2a2228") if 13.0 < co.z < 14.6 and (math.atan2(co.y, co.x) * 4 / math.pi) % 1.0 < 0.1 else
                                                _stone_fn(BLACK)(co, n))))
    parts.append(mid)
    frame = []
    for side in (-1, 1):
        a = math.atan2(dy, dx) + side * 0.28
        frame.append(box("dj", (math.cos(a) * 3.87, math.sin(a) * 3.87, H1 + 1.3), (0.22, 0.3, 2.6), (0, 0, a), bev=0.03))
    a = math.atan2(dy, dx)
    frame.append(box("dl", (math.cos(a) * 3.88, math.sin(a) * 3.88, H1 + 2.7), (0.35, 2.4, 0.3), (0, 0, a), bev=0.03))
    for f in frame:
        paint(f, hexcol("c9a050"), ao=0.0, fn=lambda co, n: shade(hexcol("c9a050"), 0.8) if (co.z * 3) % 1.0 < 0.1 else None)
    parts += frame
    # балкон 2 (он же потолок средней части)
    s2 = lathe("s2", [(0.0, H2 - 0.4), (6.0, H2 - 0.4), (6.0, H2), (0.0, H2)], 64)
    paint(s2, BLACK_L, ao=0.0, fn=lambda co, n: shade(BLACK_L, 1.2) if n.z > 0.5 else (hexcol("8a7a6a") if n.z < -0.5 and (co.x * co.x + co.y * co.y) < 3.3 * 3.3 else None))
    parts.append(s2)
    _corbels(parts, 3.85, 5.8, H2 - 0.4, 20)
    _railing(parts, 5.88, H2, 28)
    _hatch(parts, math.pi + 0.4, 4.6, H2)
    # верхний ярус с резным поясом: семь огоньков — семь маяков архипелага
    up = lathe("up", [(3.55, H2), (3.5, H3 - 0.4)], 64)
    paint(up, BLACK, ao=0.0, fn=lambda co, n: (hexcol("c9a050") if 22.4 < co.z < 22.7 else _stone_fn(BLACK)(co, n)))
    parts.append(up)
    cols = ("ffc070", "ffb050", "ffd27a", "cfe4ff", "a8e0ff", "ff7a3a", "d8ffa0")
    for k, c in enumerate(cols):
        a = 2 * math.pi * k / 7 + 0.2
        g = sphere("gl", (math.cos(a) * 3.53, math.sin(a) * 3.53, 22.55), 0.16, (1.0, 1.0, 1.0), segs=10, rings=6)
        paint(g, hexcol(c), ao=0.0, noise_amt=0)
        parts.append(g)
    # площадка на вершине, перила, люк, корона из шести столбиков
    s3 = lathe("s3", [(0.0, H3 - 0.4), (5.2, H3 - 0.4), (5.2, H3), (0.0, H3)], 64)
    paint(s3, BLACK_L, ao=0.0, fn=lambda co, n: (hexcol("c9a050") if n.z > 0.5 and 2.6 < math.hypot(co.x, co.y) < 2.75 else
                                                (shade(BLACK_L, 1.25) if n.z > 0.5 else None)))
    parts.append(s3)
    _corbels(parts, 3.5, 5.0, H3 - 0.4, 18)
    _railing(parts, 5.08, H3, 24)
    _hatch(parts, -math.pi / 2 + 0.3, 4.35, H3)
    for k in range(6):
        a = 2 * math.pi * k / 6 + 0.26
        col = tube("cn", [(math.cos(a) * 5.0, math.sin(a) * 5.0, H3), (math.cos(a) * 4.9, math.sin(a) * 4.9, H3 + 4.4)], [0.2, 0.16], 8)
        paint(col, BLACK_L, ao=0.0, fn=lambda co, n: hexcol("c9a050") if co.z > H3 + 4.1 else None)
        parts.append(col)
    crown = tube("cw", [(math.cos(a) * 4.9, math.sin(a) * 4.9, H3 + 4.5) for a in [k * 2 * math.pi / 48 for k in range(49)]], 0.22, 8, caps=False)
    paint(crown, BRONZE, ao=0.0)
    parts.append(crown)
    join(parts, "GreatLighthouse")


def tower_holds():
    """Выступы на стене маяка на 1 м: обтёсанные камни-ступени и старая железная скоба."""
    parts = []
    for k in range(2):
        z = 0.2 + k * 0.5
        x = -0.22 if k % 2 == 0 else 0.22
        h = box("hl", (x, -0.05, z), (0.34, 0.24, 0.11), (0, 0, 0.08 * (1 - 2 * k)), bev=0.03)
        paint(h, BLACK_L, ao=0.0, fn=lambda co, n: shade(BLACK_L, 1.3) if n.z > 0.5 else None)
        parts.append(h)
    sb = tube("sb", [(0.0, 0.0, 0.62), (0.0, -0.14, 0.62), (0.0, -0.14, 0.82), (0.0, 0.0, 0.82)], 0.02, 6)
    paint(sb, hexcol("6a5a4a"), ao=0.0)
    parts.append(sb)
    join(parts, "TowerHolds")


def tower_ledge():
    """Уступ для отдыха на стене маяка: каменная полка и кольцо, за которое держатся."""
    parts = []
    shelf = box("sf", (0, -0.22, -0.02), (1.0, 0.46, 0.16), bev=0.04)
    paint(shelf, BLACK_L, ao=0.0, fn=lambda co, n: shade(BLACK_L, 1.3) if n.z > 0.5 else None)
    parts.append(shelf)
    for sx in (-1, 1):
        br = box("br", (sx * 0.38, -0.1, -0.18), (0.1, 0.2, 0.2), (0.6, 0, 0))
        paint(br, BLACK, ao=0.0)
        parts.append(br)
    ring = tube("rg", [(0.32 + 0.09 * math.cos(a), -0.02, 0.55 + 0.09 * math.sin(a)) for a in [k * math.pi / 8 for k in range(17)]], 0.018, 6, caps=False)
    paint(ring, hexcol("8a7a5a"), ao=0.0)
    parts.append(ring)
    join(parts, "TowerLedge")


def great_fire():
    """Чаша Великого огня — размером с комнату: бронзовая чаша на каменном кольце с резьбой, угли внутри;
    над ней — оправа линзы на четырёх изогнутых стойках. FirePoint — где горит огонь."""
    parts = []
    base = lathe("bs", [(2.4, 0.0), (2.3, 0.35), (1.8, 0.45), (0.0, 0.45)], 48)
    paint(base, BLACK_L, ao=0.0, fn=lambda co, n: hexcol("c9a050") if 0.18 < co.z < 0.24 else None)
    bowl = lathe("bw", [(0.0, 0.4), (1.5, 0.45), (2.0, 0.75), (2.25, 1.15), (2.15, 1.25), (1.85, 1.1), (1.2, 0.9), (0.0, 0.85)], 48)
    paint(bowl, BRONZE, ao=0.0, fn=lambda co, n: (hexcol("3a2a2a") if n.z > 0.6 and math.hypot(co.x, co.y) < 1.9 else
                                                 (shade(BRONZE, 1.3) if 0.95 < co.z < 1.02 else None)))
    parts += [base, bowl]
    r = rnd(5)
    for k in range(18):
        a = r.uniform(0, 2 * math.pi)
        d = r.uniform(0.0, 1.5)
        e = sphere("em", (math.cos(a) * d, math.sin(a) * d, 0.92), r.uniform(0.12, 0.22), (1.0, 1.0, 0.5))
        paint(e, hexcol("4a2a2a"), ao=0.0, fn=lambda co, n: hexcol("ff7a3a") if n.z < 0.3 else None)
        parts.append(e)
    for k in range(4):
        a = math.pi / 4 + k * math.pi / 2
        st = tube("st", [(math.cos(a) * 2.15, math.sin(a) * 2.15, 1.2), (math.cos(a) * 2.0, math.sin(a) * 2.0, 2.6),
                         (math.cos(a) * 1.15, math.sin(a) * 1.15, 3.6)], [0.09, 0.08, 0.06], 8)
        paint(st, BRONZE, ao=0.0)
        parts.append(st)
    ring = tube("rg", [(math.cos(a) * 1.05, math.sin(a) * 1.05, 3.65) for a in [k * 2 * math.pi / 32 for k in range(33)]], 0.09, 8, caps=False)
    paint(ring, shade(BRONZE, 1.15), ao=0.0)
    parts.append(ring)
    b = join(parts, "GreatFire")
    lens = cyl("Lens", (0, 0, 3.6), 1.0, 1.0, 0.1, segs=32)
    paint(lens, hexcol("4a3a6a"), ao=0.0, noise_amt=0, fn=lambda co, n: hexcol("8a7ab8") if n.z > 0.5 and co.x < -0.2 else None)
    set_parent(lens, b)
    empty("FirePoint", (0, 0, 0.95), b)


def storm_wall():
    """Стена шторма: открытый цилиндр радиусом 1 и высотой 1 (игра растягивает его на 170 × 150 м)
    с мягкими «клубами» по краю. Цвет и движение туч рисует шейдер."""
    bm = bmesh.new()
    segs, rows = 96, 10
    rings = []
    for j in range(rows + 1):
        z = j / rows
        ring = []
        for i in range(segs):
            a = 2 * math.pi * i / segs
            bulge = 1.0 + 0.025 * math.sin(a * 7 + z * 5) + 0.015 * math.sin(a * 17 - z * 9)
            ring.append(bm.verts.new((math.cos(a) * bulge, math.sin(a) * bulge, z)))
        rings.append(ring)
    for j in range(rows):
        for i in range(segs):
            bm.faces.new((rings[j][i], rings[j + 1][i], rings[j + 1][(i + 1) % segs], rings[j][(i + 1) % segs]))
    w = from_bm("StormWall", bm)
    paint(w, hexcol("5a6478"), ao=0.0, noise_amt=0)


# ================================================================== после финала
def order_board():
    """Доска заказов: два столба, навес из досок, доска с приколотыми записками, фонарик сбоку."""
    parts = []
    for sx in (-1, 1):
        parts.append(plank("ps", (sx * 0.8, 0, 1.1), (0.14, 0.14, 2.2), col=hexcol("6a4a2e")))
    board = plank("bd", (0, 0, 1.35), (1.5, 0.08, 1.0), col=WOOD_W)
    parts.append(board)
    roof = box("rf", (0, 0.05, 2.25), (1.9, 0.6, 0.08), (0.25, 0, 0), bev=0.02)
    paint(roof, hexcol("8a5a3a"), ao=0.0)
    parts.append(roof)
    for k, (x, z, c) in enumerate(((-0.45, 1.55, "f6ecd2"), (0.1, 1.45, "fff4c0"), (0.5, 1.6, "e8f2f6"), (-0.2, 1.1, "f6ecd2"), (0.4, 1.1, "ffe0d0"))):
        nt = box("nt", (x, -0.05, z), (0.34, 0.01, 0.28), (0, 0.06 * (k % 3 - 1), 0))
        paint(nt, hexcol(c), ao=0.0, fn=lambda co, n: hexcol("6a5a4a") if (co.z * 30) % 1.0 < 0.2 and n.y < -0.5 else None)
        pin = sphere("pn", (x, -0.07, z + 0.11), 0.025, segs=6, rings=4)
        paint(pin, hexcol("e8443a"), ao=0.0, noise_amt=0)
        parts += [nt, pin]
    lamp = lathe("lp", [(0.0, 1.75), (0.1, 1.77), (0.12, 1.95), (0.06, 2.02), (0.0, 2.03)], 10, loc=(0.95, -0.12, 0))
    paint(lamp, hexcol("ffd27a"), ao=0.0)
    parts.append(lamp)
    join(parts, "OrderBoard")


BUILDERS = {
    "lyova": lyova, "grandfather_house": grandfather_house, "perch": perch, "apple_tree": apple_tree,
    "grandpa_bench": grandpa_bench, "wild_bed": wild_bed, "letters_box": letters_box, "keepers_book": keepers_book,
    "great_lighthouse": great_lighthouse, "tower_holds": tower_holds, "tower_ledge": tower_ledge, "great_fire": great_fire,
    "storm_wall": storm_wall, "order_board": order_board,
}
