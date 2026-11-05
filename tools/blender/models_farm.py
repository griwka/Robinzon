"""Ферма: грядка (узел Soil) и растения на ней по стадиям роста.
Девять мест посадки — как в игре: x ∈ {-0.5, 0, 0.5}, Godot z ∈ {-0.3, 0, 0.3} (Blender y = −z)."""
import math

from mathutils import Vector

from kit import box, cyl, displace, hexcol, ico, join, lathe, leaf, paint, rnd, sphere, subsurf, tube
from models_buildings import plank

GREEN = hexcol("5aa83f")
GREEN_D = hexcol("3f8a34")
SPOTS = [(x, y, 0.22) for y in (-0.3, 0.0, 0.3) for x in (-0.5, 0.0, 0.5)]


def garden_bed():
    parts = []
    for y in (-0.55, 0.55):
        parts.append(plank("side", (0, y, 0.11), (1.76, 0.12, 0.22), seed=int(y * 10)))
    for x in (-0.83, 0.83):
        parts.append(plank("end", (x, 0, 0.11), (0.12, 1.2, 0.22), seed=int(x * 10), col=hexcol("a87342")))
    for x in (-0.83, 0.83):
        for y in (-0.55, 0.55):
            peg = cyl("pg", (x, y, 0), 0.05, 0.045, 0.28, segs=8)
            paint(peg, hexcol("8a5a32"), ao=0.0)
            parts.append(peg)
    join(parts, "Bed")
    soil = box("Soil", (0, 0, 0.12), (1.56, 1.0, 0.14), bev=0.04)
    ridges = []
    for y in (-0.3, 0.0, 0.3):
        r = tube("rg", [(-0.72, y, 0.2), (0.72, y, 0.2)], 0.075, 8)
        ridges.append(r)
    s = join([soil] + ridges, "Soil")
    displace(s, 0.02, 0.05)
    paint(s, hexcol("7a4a2a"), ao=0.0, noise_amt=0.2, nscale=18)
    s.name = "Soil"


def _sprouts(scale):
    parts = []
    rr = rnd(int(scale * 100))
    for (x, y, z) in SPOTS:
        for k in range(3 if scale > 0.5 else 2):
            a = 2 * math.pi * k / 3 + rr.random()
            lf = leaf("sp_leaf", (x, y, z), (math.cos(a), math.sin(a), 1.2), 0.14 * scale + 0.05, 0.05 * scale + 0.02, droop=0.5)
            paint(lf, GREEN if k % 2 else hexcol("6fc24f"), ao=0.0)
            parts.append(lf)
    return parts


def crop_sprout():
    join(_sprouts(0.4), "Crop_leaf")


def crop_young():
    join(_sprouts(1.0), "Crop_leaf")


def crop_carrot():
    parts = []
    for (x, y, z) in SPOTS:
        top = cyl("ct", (x, y, z - 0.02), 0.075, 0.06, 0.07, segs=12)
        paint(top, hexcol("f58a1f"), ao=0.0, fn=lambda co, n: 0.85 if int(co.z * 120) % 2 else None)
        parts.append(top)
        for k in range(5):
            a = 2 * math.pi * k / 5
            lf = leaf("cl_leaf", (x, y, z + 0.05), (math.cos(a) * 0.4, math.sin(a) * 0.4, 1), 0.32, 0.035, droop=0.3)
            paint(lf, GREEN, ao=0.0)
            parts.append(lf)
    join(parts, "Crop")


def crop_potato():
    parts = []
    rr = rnd(4)
    for (x, y, z) in SPOTS:
        b = ico("pb", (x, y, z + 0.12), 0.16, (1, 1, 0.8), sub=2)
        displace(b, 0.06, 0.07)
        paint(b, GREEN_D, ao=0.0, noise_amt=0.15, nscale=12, fn=lambda co, n: 1.15 if n.z > 0.5 else None)
        parts.append(b)
        for k in range(2):
            f = sphere("pf", (x + rr.uniform(-0.1, 0.1), y + rr.uniform(-0.1, 0.1), z + 0.27), 0.03, segs=8, rings=5)
            paint(f, hexcol("e8dcff"), ao=0.0, noise_amt=0)
            parts.append(f)
        tub = sphere("pt", (x - 0.12, y + 0.08, z + 0.01), 0.06, (1.2, 1, 0.8), segs=10, rings=6)
        paint(tub, hexcol("c8a064"), ao=0.0)
        parts.append(tub)
    join(parts, "Crop")


def crop_corn():
    parts = []
    for (x, y, z) in SPOTS[::2]:
        st = tube("cs", [(x, y, z), (x, y, z + 0.7), (x + 0.02, y, z + 1.3)], [0.035, 0.03, 0.015], 8)
        paint(st, hexcol("6db33f"), ao=0.0)
        parts.append(st)
        for k in range(5):
            a = 2 * math.pi * k / 5 + x
            lf = leaf("cn_leaf", (x, y, z + 0.3 + k * 0.18), (math.cos(a), math.sin(a), 0.6), 0.45, 0.04, droop=0.6)
            paint(lf, hexcol("7cc444"), ao=0.0)
            parts.append(lf)
        cob = sphere("cb", (x + 0.07, y, z + 0.85), 0.05, (1, 1, 2.6), (0, 0.3, 0), segs=12, rings=8)
        paint(cob, hexcol("ffd23f"), ao=0.0, fn=lambda co, n: 0.85 if (int(co.z * 80) + int(math.atan2(co.y, co.x) * 6)) % 2 else None)
        husk = leaf("hk_leaf", (x + 0.05, y, z + 0.72), (0.3, 0, 1), 0.22, 0.05, droop=0.1)
        paint(husk, hexcol("9bd060"), ao=0.0)
        parts += [cob, husk]
    join(parts, "Crop")


def crop_tomato():
    parts = []
    rr = rnd(6)
    for (x, y, z) in [SPOTS[i] for i in (1, 3, 4, 5, 7)]:
        stake = cyl("sk", (x + 0.06, y, z), 0.012, 0.012, 0.85, segs=5)
        paint(stake, hexcol("a07040"), ao=0.0)
        b = ico("tb", (x, y, z + 0.45), 0.2, (1, 1, 1.5), sub=2)
        displace(b, 0.07, 0.07)
        paint(b, hexcol("3f9f3a"), ao=0.0, noise_amt=0.15, nscale=12, fn=lambda co, n: 1.15 if n.z > 0.5 else None)
        parts += [stake, b]
        for k in range(4):
            a = 2 * math.pi * k / 4 + rr.random()
            t = sphere("tm", (x + math.cos(a) * 0.17, y + math.sin(a) * 0.17, z + 0.3 + rr.uniform(0, 0.3)), 0.06, segs=12, rings=8)
            paint(t, hexcol("e8443a"), ao=0.0, fn=lambda co, n: 1.2 if n.z > 0.6 else None)
            parts.append(t)
    join(parts, "Crop")


def crop_cabbage():
    parts = []
    for (x, y, z) in SPOTS[::2]:
        head = sphere("ch", (x, y, z + 0.12), 0.16, (1, 1, 0.85), segs=16, rings=10)
        paint(head, hexcol("c2e88c"), ao=0.0, fn=lambda co, n: 0.88 if math.sin(math.atan2(co.y - y, co.x - x) * 5 + co.z * 20) > 0.7 else None)
        parts.append(head)
        for k in range(6):
            a = 2 * math.pi * k / 6
            lf = leaf("cb_leaf", (x, y, z + 0.05), (math.cos(a), math.sin(a), 0.5), 0.26, 0.12, droop=0.3, fold=0.3)
            paint(lf, hexcol("8fcf5a"), ao=0.0, fn=lambda co, n: 0.85 if abs(math.sin((co.x + co.y) * 50)) > 0.95 else None)
            parts.append(lf)
    join(parts, "Crop")


def crop_watermelon():
    parts = []
    for (x, y, rot) in ((-0.35, 0.0, 0.3), (0.38, 0.12, -0.4)):
        m = sphere("wm", (x, y, 0.36), 0.27, (1.3, 0.92, 0.85), (0, 0, rot), segs=20, rings=12)
        paint(m, hexcol("2f8f3a"), ao=0.0, fn=lambda co, n, x=x, rot=rot: hexcol("8fd46a") if math.sin(math.atan2(co.z - 0.36, (co.x - x) * math.sin(rot) + co.y * math.cos(rot)) * 7) > 0.55 else None)
        parts.append(m)
    vine = tube("vn", [(-0.7, -0.35, 0.22), (-0.3, -0.2, 0.24), (0.1, -0.35, 0.22), (0.5, -0.2, 0.24), (0.7, 0.3, 0.22)], 0.015, 6)
    paint(vine, GREEN, ao=0.0)
    parts.append(vine)
    for k in range(8):
        x = -0.7 + k * 0.2
        lf = leaf("wl_leaf", (x, -0.3 + (k % 2) * 0.1, 0.24), (0.2, 1 if k % 2 else -1, 0.4), 0.16, 0.08, droop=0.2)
        paint(lf, GREEN, ao=0.0)
        parts.append(lf)
    join(parts, "Crop")


BUILDERS = {"garden_bed": garden_bed, "crop_sprout": crop_sprout, "crop_young": crop_young, "crop_carrot": crop_carrot,
            "crop_potato": crop_potato, "crop_corn": crop_corn, "crop_tomato": crop_tomato,
            "crop_cabbage": crop_cabbage, "crop_watermelon": crop_watermelon}
