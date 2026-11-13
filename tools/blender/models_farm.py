"""Ферма: грядка (узел Soil) и растения на ней по стадиям роста.
Девять мест посадки — как в игре: x ∈ {-0.5, 0, 0.5}, Godot z ∈ {-0.3, 0, 0.3} (Blender y = −z)."""
import math

from mathutils import Vector

from kit import box, cyl, displace, hexcol, ico, join, lathe, leaf, paint, rnd, shade, sphere, subsurf, tube
from models_buildings import plank

GREEN = hexcol("5aa83f")
GREEN_D = hexcol("3f8a34")
SPOTS = [(x, y, 0.22) for y in (-0.3, 0.0, 0.3) for x in (-0.5, 0.0, 0.5)]


def garden_bed():
    """Грядка: борта из досок с угловыми столбиками и гвоздями, рыхлая земля с бороздами (узел Soil),
    камешки и соломка по краю. Посадки — в бороздах (SPOTS)."""
    rr = rnd(55)
    parts = []
    for y in (-0.55, 0.55):
        for row in range(2):   # две доски одна над другой
            parts.append(plank("side", (0, y, 0.06 + row * 0.11), (1.62, 0.07, 0.1), seed=int(y * 10) + row))
    for x in (-0.81, 0.81):
        for row in range(2):
            parts.append(plank("end", (x, 0, 0.06 + row * 0.11), (0.07, 1.04, 0.1), seed=int(x * 10) + row + 5, col=hexcol("a87342")))
    for x in (-0.81, 0.81):
        for y in (-0.55, 0.55):
            post = box("pst", (x, y, 0.13), (0.11, 0.11, 0.3), bev=0.025)
            paint(post, hexcol("8a5a32"), ao=0.25, ao_h=0.2, noise_amt=0.1, nscale=12,
                  fn=lambda co, n: hexcol("b88a58") if n.z > 0.7 else None)
            parts.append(post)
            for zz in (0.07, 0.18):   # шляпки гвоздей на бортах у столбика
                nl = sphere("nl", (x * 0.89, y * 1.065, zz), 0.011, (1, 0.4, 1), segs=8, rings=4)
                paint(nl, hexcol("6a6a70"), ao=0.0)
                parts.append(nl)
    join(parts, "Bed")
    soil = box("Soil", (0, 0, 0.12), (1.55, 1.03, 0.16), bev=0.05)
    ridges = []
    for y in (-0.3, 0.0, 0.3):   # гряды-валики, между ними — бороздки
        r = tube("rg", [(-0.7, y, 0.2), (-0.35, y + 0.01, 0.205), (0.0, y - 0.01, 0.2), (0.35, y + 0.01, 0.205), (0.7, y, 0.2)], 0.085, 10)
        ridges.append(r)
    s_ = join([soil] + ridges, "Soil")
    displace(s_, 0.018, 0.04)
    paint(s_, hexcol("6e4228"), ao=0.0, noise_amt=0.22, nscale=22,
          fn=lambda co, n: (hexcol("8a5634") if n.z > 0.8 and noise_v(co * 30) > 0.35 else (hexcol("553220") if n.z < 0.6 and co.z > 0.15 else None)))
    s_.name = "Soil"
    deco = []
    for k in range(7):   # камешки и соломинки у бортов
        x = rr.uniform(-0.7, 0.7)
        y = rr.choice((-0.47, 0.47)) + rr.uniform(-0.03, 0.03)
        st = ico("pb", (x, y, 0.2), rr.uniform(0.018, 0.03), (1.2, 1, 0.7), sub=1)
        paint(st, hexcol("a3a39a"), ao=0.0, noise_amt=0.1)
        deco.append(st)
    for k in range(10):
        x = rr.uniform(-0.72, 0.72)
        y = rr.choice((-0.46, 0.46, 0.15, -0.15)) + rr.uniform(-0.04, 0.04)
        a = rr.uniform(0, 3.14)
        sw = tube("sw", [(x - math.cos(a) * 0.06, y - math.sin(a) * 0.06, 0.2), (x + math.cos(a) * 0.06, y + math.sin(a) * 0.06, 0.205)], 0.005, 4)
        paint(sw, hexcol("e0c070"), ao=0.0)
        deco.append(sw)
    join(deco, "BedDeco")


def noise_v(co):
    from mathutils import noise
    return noise.noise(co)


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


# ================================================================== культуры: растения по узлам для плавного роста
# Каждое растение — пустышка «P<n>» в точке посадки (низ — уровень земли грядки). В ней:
#   P<n>_leaf      — листья и тонкие стебли (листва: ветер, двусторонняя),
#   P<n>_stem      — толстое: стебель, колышек, лоза,
#   P<n>_fruit<k>  — каждый плод отдельно, точка вращения — в его центре: игра «наливает» плоды по одному.
# Игра растит растение целиком из маленького ростка (масштаб от земли) — ступенек стадий больше нет.

def _plant(idx, base, leaves, stems, fruits):
    from kit import empty, set_origin, set_parent
    base = tuple(base)
    e = empty("P%d" % idx, base)
    if leaves:
        lj = join(leaves, "P%d_leaf" % idx)
        set_origin(lj, base)
        set_parent(lj, e)
    if stems:
        sj = join(stems, "P%d_stem" % idx)
        set_origin(sj, base)
        set_parent(sj, e)
    for k, (ob, ctr) in enumerate(fruits):
        if isinstance(ob, list):
            ob = join(ob, "P%d_fruit%d" % (idx, k))
        ob.name = "P%d_fruit%d" % (idx, k)
        ob.data.name = ob.name
        set_origin(ob, tuple(ctr))
        set_parent(ob, e)
    return e


def _leaflet(name, base, d, ln, w, col, droop=0.35, fold=0.25, shape=None, vein=None, segs=6):
    lf = leaf(name, tuple(base), tuple(d), ln, w, droop=droop, segs=segs, fold=fold, shape=shape)
    c2 = vein or shade(col, 1.18)
    paint(lf, col, ao=0.0, noise_amt=0.06, nscale=14,
          fn=lambda co, n: None)
    return lf


def _round(t):
    return math.sin(math.pi * min(1.0, t * 0.95 + 0.05)) ** 0.8


def _frond(name, base, a, ln, col, rr, pairs=4, up=1.0):
    """Перистый лист моркови/помидора: черешок и пары листочков."""
    out = []
    base = Vector(base)
    d = Vector((math.cos(a) * 0.55, math.sin(a) * 0.55, up)).normalized()
    pts = [base + d * ln * t + Vector((0, 0, -ln * 0.25 * t * t)) for t in (0, 0.35, 0.7, 1.0)]
    st = tube(name + "_s", [tuple(p) for p in pts], [0.008, 0.007, 0.005, 0.003], 4)
    paint(st, shade(col, 0.85), ao=0.0)
    out.append(st)
    side = Vector((-math.sin(a), math.cos(a), 0))
    for i in range(pairs):
        t = 0.3 + 0.7 * i / max(1, pairs - 1)
        p = pts[0].lerp(pts[3], t)
        for sg in (-1, 1):
            dd = side * sg + d * 0.6
            out.append(_leaflet(name, p, dd, ln * (0.3 - 0.12 * t) + 0.03, 0.022 + 0.01 * (1 - t), shade(col, 0.92 + 0.12 * rr.random()), droop=0.4))
    out.append(_leaflet(name, pts[3], d, ln * 0.18 + 0.02, 0.02, col, droop=0.3))
    return out


def crop_carrot():
    rr = rnd(101)
    for i, (x, y, z) in enumerate(SPOTS):
        leaves = []
        for k in range(7):
            a = 2 * math.pi * k / 7 + rr.uniform(-0.2, 0.2)
            leaves += _frond("cf_leaf", (x, y, z + 0.04), a, rr.uniform(0.26, 0.36), GREEN if k % 2 else hexcol("6cbc48"), rr, 4, 1.6)
        root = lathe("cr", [(0.0, -0.1), (0.028, -0.07), (0.05, -0.02), (0.058, 0.02), (0.05, 0.045), (0.0, 0.05)], 14, loc=(x, y, z))
        paint(root, hexcol("f58a1f"), ao=0.0, noise_amt=0.05, fn=lambda co, n: shade(hexcol("f58a1f"), 0.82) if int(co.z * 140) % 3 == 0 else (hexcol("8fb83f") if co.z > z + 0.04 else None))
        _plant(i, (x, y, z), leaves, [], [(root, (x, y, z))])


def crop_potato():
    rr = rnd(102)
    for i, (x, y, z) in enumerate(SPOTS):
        leaves, stems, fruits = [], [], []
        for k in range(8):
            a = 2 * math.pi * k / 8 + rr.uniform(-0.2, 0.2)
            h = rr.uniform(0.12, 0.26)
            tip = Vector((x + math.cos(a) * 0.13, y + math.sin(a) * 0.13, z + h))
            st = tube("ps", [(x, y, z), (x + math.cos(a) * 0.05, y + math.sin(a) * 0.05, z + h * 0.7), tuple(tip)], [0.012, 0.01, 0.007], 5)
            paint(st, GREEN_D, ao=0.0)
            leaves.append(st)
            for q in range(3):   # сложный лист: три овальных листочка
                aa = a + (q - 1) * 0.7
                leaves.append(_leaflet("pl_leaf", tip, (math.cos(aa), math.sin(aa), 0.25), 0.12 - abs(q - 1) * 0.03, 0.05,
                                       shade(hexcol("4f9a3c"), 0.92 + 0.15 * rr.random()), droop=0.25, fold=0.3, shape=_round))
        for q in range(2):   # цветы — белые с жёлтой серединкой
            fx, fy = x + rr.uniform(-0.06, 0.06), y + rr.uniform(-0.06, 0.06)
            fl = []
            for p in range(5):
                pa = 2 * math.pi * p / 5
                pt = leaf("pf", (fx, fy, z + 0.3), (math.cos(pa), math.sin(pa), 0.2), 0.035, 0.022, droop=0.1, segs=3)
                paint(pt, hexcol("f4ecff") if q else hexcol("d8c8f4"), ao=0.0, noise_amt=0)
                fl.append(pt)
            c = sphere("pc", (fx, fy, z + 0.305), 0.012, segs=8, rings=5)
            paint(c, hexcol("ffd23f"), ao=0.0)
            fl.append(c)
            fruits.append((fl, (fx, fy, z + 0.3)))
        for q in range(2):   # клубни выглядывают из земли
            a = rr.uniform(0, 6.28)
            tx, ty = x + math.cos(a) * 0.12, y + math.sin(a) * 0.12
            tb = ico("pt", (tx, ty, z + 0.01), 0.055, (1.3, 1.0, 0.8), sub=2)
            displace(tb, 0.012, 0.04)
            paint(tb, hexcol("d4a868"), ao=0.0, noise_amt=0.15, nscale=30, fn=lambda co, n: 0.78 if noise_spot(co * 40) > 0.6 else None)
            fruits.append((tb, (tx, ty, z)))
        _plant(i, (x, y, z), leaves, stems, fruits)


def noise_spot(co):
    from mathutils import noise
    return noise.noise(co)


def crop_corn():
    rr = rnd(103)
    for i, (x, y, z) in enumerate(SPOTS[::2]):
        h = rr.uniform(1.25, 1.45)
        stems, leaves = [], []
        st = tube("cs", [(x, y, z), (x + 0.01, y, z + h * 0.5), (x + 0.03, y + 0.01, z + h)], [0.032, 0.026, 0.012], 8)
        paint(st, hexcol("78b84a"), ao=0.0, fn=lambda co, n: shade(hexcol("78b84a"), 0.8) if (co.z * 5.5) % 1.0 < 0.08 else None)
        stems.append(st)
        for k in range(7):
            a = k * 2.4 + rr.uniform(-0.3, 0.3)
            zz = z + 0.15 + k * h * 0.11
            leaves.append(_leaflet("cn_leaf", (x, y, zz), (math.cos(a), math.sin(a), 0.75), rr.uniform(0.5, 0.62), 0.045,
                                   shade(hexcol("7cc444"), 0.9 + 0.15 * rr.random()), droop=0.75, fold=0.3, shape=lambda t: (1 - t) ** 0.6 * min(1, t * 6 + 0.2)))
        for k in range(6):   # метёлка
            a = 2 * math.pi * k / 6
            sp = tube("ct_leaf", [(x + 0.03, y + 0.01, z + h), (x + 0.03 + math.cos(a) * 0.07, y + 0.01 + math.sin(a) * 0.07, z + h + 0.13)], [0.006, 0.003], 4)
            paint(sp, hexcol("e8d27a"), ao=0.0)
            leaves.append(sp)
        fruits = []
        for q in range(1 if i % 2 else 2):
            a = 0.6 + q * 3.0
            cz = z + h * (0.5 + q * 0.08)
            c = Vector((x + math.cos(a) * 0.06, y + math.sin(a) * 0.06, cz))
            cob = sphere("cb", tuple(c + Vector((0, 0, 0.06))), 0.042, (1, 1, 2.7), (0.25 * math.sin(a), -0.25 * math.cos(a), 0), segs=14, rings=10)
            paint(cob, hexcol("ffd23f"), ao=0.0, fn=lambda co, n: shade(hexcol("ffd23f"), 0.8) if (int(co.z * 90) + int(math.atan2(co.y, co.x) * 7)) % 2 else None)
            husk = []
            for hk in range(3):
                ha = a + (hk - 1) * 1.6
                hl = leaf("hk", tuple(c + Vector((math.cos(ha) * 0.025, math.sin(ha) * 0.025, -0.05))), (math.cos(ha) * 0.2, math.sin(ha) * 0.2, 1), 0.2, 0.04, droop=0.05, fold=0.4)
                paint(hl, hexcol("a9d468"), ao=0.0)
                husk.append(hl)
            silk = tube("sk", [tuple(c + Vector((0, 0, 0.16))), tuple(c + Vector((math.cos(a) * 0.04, math.sin(a) * 0.04, 0.22)))], [0.012, 0.004], 5)
            paint(silk, hexcol("b8743a"), ao=0.0)
            fruits.append(([cob, silk] + husk, tuple(c)))
        _plant(i, (x, y, z), leaves, stems, fruits)


def crop_tomato():
    rr = rnd(104)
    for i, (x, y, z) in enumerate([SPOTS[j] for j in (1, 3, 4, 5, 7)]):
        stems, leaves, fruits = [], [], []
        stake = cyl("sk", (x + 0.07, y + 0.04, z - 0.05), 0.012, 0.01, 0.95, segs=6)
        paint(stake, hexcol("a87a4a"), ao=0.0, fn=lambda co, n: 0.85 if int(co.z * 30) % 4 == 0 else None)
        stems.append(stake)
        st = tube("ts", [(x, y, z), (x + 0.02, y, z + 0.35), (x + 0.05, y + 0.02, z + 0.7), (x + 0.06, y + 0.03, z + 0.82)], [0.016, 0.013, 0.01, 0.006], 6)
        paint(st, hexcol("5f9a3a"), ao=0.0)
        stems.append(st)
        for k in range(7):
            a = k * 2.2 + rr.uniform(-0.3, 0.3)
            zz = z + 0.12 + k * 0.1
            leaves += _frond("tl_leaf", (x + 0.02, y, zz), a, rr.uniform(0.17, 0.24), hexcol("3f9f3a"), rr, 3, 0.5)
        for truss in range(2):
            a = truss * 3.1 + 0.5
            zc = z + 0.3 + truss * 0.2
            for k in range(3):
                ta = a + (k - 1) * 0.55
                c = Vector((x + math.cos(ta) * 0.13, y + math.sin(ta) * 0.13, zc - k * 0.04))
                r = rr.uniform(0.045, 0.058)
                t = sphere("tm", tuple(c), r, (1, 1, 0.86), segs=14, rings=9)
                paint(t, hexcol("e8443a"), ao=0.0, fn=lambda co, n: shade(hexcol("e8443a"), 1.25) if n.z > 0.65 else None)
                cal = []
                for s in range(5):
                    sa = 2 * math.pi * s / 5
                    sl = leaf("cl", tuple(c + Vector((0, 0, r * 0.82))), (math.cos(sa), math.sin(sa), -0.2), 0.035, 0.009, droop=0.2, segs=3)
                    paint(sl, hexcol("3f8a34"), ao=0.0)
                    cal.append(sl)
                fruits.append(([t] + cal, tuple(c)))
        _plant(i, (x, y, z), leaves, stems, fruits)


def crop_cabbage():
    rr = rnd(105)
    for i, (x, y, z) in enumerate(SPOTS[::2]):
        leaves = []
        for k in range(8):
            a = 2 * math.pi * k / 8 + rr.uniform(-0.15, 0.15)
            col = shade(hexcol("8cc26a"), 0.9 + 0.12 * rr.random())
            lf = leaf("cb_leaf", (x, y, z + 0.03), (math.cos(a), math.sin(a), 0.55 if k % 2 else 0.35), rr.uniform(0.22, 0.28), 0.13,
                      droop=0.35, segs=7, fold=0.35, shape=_round)
            paint(lf, col, ao=0.0, noise_amt=0.06,
                  fn=lambda co, n, a=a: shade(hexcol("8cc26a"), 1.28) if abs(math.sin(math.atan2(co.y - y, co.x - x) - a) * math.hypot(co.x - x, co.y - y)) < 0.008 else None)
            leaves.append(lf)
        c = (x, y, z + 0.13)
        head = [sphere("ch", c, 0.135, (1, 1, 0.92), segs=18, rings=12)]
        paint(head[0], hexcol("cdeaa0"), ao=0.0, fn=lambda co, n: shade(hexcol("cdeaa0"), 0.86) if math.sin(math.atan2(co.y - y, co.x - x) * 4 + co.z * 18) > 0.8 else None)
        for k in range(5):   # листья, обнимающие кочан
            a = 2 * math.pi * k / 5 + 0.3
            lf = leaf("wr", (x + math.cos(a) * 0.08, y + math.sin(a) * 0.08, z + 0.02), (math.cos(a) * 0.35, math.sin(a) * 0.35, 1), 0.2, 0.1,
                      droop=-0.25, segs=6, fold=0.5, shape=_round)
            paint(lf, hexcol("a8d47e"), ao=0.0)
            head.append(lf)
        _plant(i, (x, y, z), leaves, [], [(head, c)])


def _vine_plant(i, base, rr, fruit_fn, leaf_col, spread, n_leaves=7, leaf_size=0.15):
    """Лоза по грядке: стебель, лопастные листья, усики — и плод от fruit_fn(центр)."""
    x, y, z = base
    stems, leaves = [], []
    for side in (-1, 1):
        pts = [(x, y, z + 0.02)]
        for k in range(1, 5):
            t = k / 4
            pts.append((x + side * spread * t, y + 0.18 * math.sin(t * 4 + i) * side, z + 0.03 + 0.02 * math.sin(t * 7)))
        v = tube("vn", pts, [0.016, 0.014, 0.012, 0.01, 0.006], 6)
        paint(v, hexcol("5f9a3a"), ao=0.0)
        stems.append(v)
        for k in range(n_leaves // 2 + 1):
            p = Vector(pts[min(4, k + 1)])
            a = rr.uniform(0, 6.28)
            for q in range(3):   # лопастный лист из трёх долей
                aa = a + (q - 1) * 0.75
                leaves.append(_leaflet("vl_leaf", p + Vector((0, 0, 0.02)), (math.cos(aa), math.sin(aa), 0.9), leaf_size * (1.0 - abs(q - 1) * 0.2), leaf_size * 0.5,
                                       shade(leaf_col, 0.9 + 0.15 * rr.random()), droop=0.35, fold=0.3, shape=_round))
        q = Vector(pts[2])
        tw = [tuple(q + Vector((math.cos(t * 6) * 0.025, math.sin(t * 6) * 0.025, 0.03 + t * 0.08))) for t in [s / 10 for s in range(11)]]
        tdr = tube("td_leaf", tw, 0.003, 4, caps=False)
        paint(tdr, hexcol("7ab84a"), ao=0.0)
        leaves.append(tdr)
    return stems, leaves


def crop_watermelon():
    rr = rnd(106)
    for i, (x, y) in enumerate(((-0.36, 0.05), (0.38, -0.08))):
        z = 0.22
        stems, leaves = _vine_plant(i, (x, y, z), rr, None, hexcol("4f9a3c"), 0.35)
        c = Vector((x, y + (0.12 if i == 0 else -0.12), z + 0.16))
        rot = 0.3 if i == 0 else -0.4
        m = sphere("wm", tuple(c), 0.24, (1.3, 0.95, 0.72), (0, 0, rot), segs=22, rings=14)
        paint(m, hexcol("2f8f3a"), ao=0.0, fn=lambda co, n, c=c, rot=rot: hexcol("8fd46a") if math.sin(
            math.atan2(co.z - c.z, (co.x - c.x) * math.sin(rot) - (co.y - c.y) * math.cos(rot)) * 8 + noise_spot(co * 9) * 1.2) > 0.45 else None)
        stem = tube("ws", [tuple(c + Vector((math.cos(rot) * 0.3, math.sin(rot) * 0.3, 0.02))), tuple(c + Vector((math.cos(rot) * 0.36, math.sin(rot) * 0.36, 0.06)))], [0.012, 0.006], 5)
        paint(stem, hexcol("6a8a3a"), ao=0.0)
        _plant(i, (x, y, z), leaves, stems, [([m, stem], tuple(c))])


def crop_pumpkin():
    rr = rnd(107)
    for i, (x, y) in enumerate(((-0.4, 0.08), (0.42, -0.1))):
        z = 0.22
        stems, leaves = _vine_plant(i, (x, y, z), rr, None, hexcol("3f8f3a"), 0.38, 8, 0.19)
        c = Vector((x + 0.02, y + (0.08 if i == 0 else -0.08), z + 0.14))
        prof = []
        for k in range(9):
            t = k / 8
            prof.append((0.27 * math.sin(math.pi * (0.06 + t * 0.88)) ** 0.75 + 0.005, -0.13 + 0.26 * t))
        pk = lathe("pk", prof, 32, loc=tuple(c))
        # рёбра тыквы: вдавливаем по кругу
        for v in pk.data.vertices:
            d = Vector((v.co.x, v.co.y, 0))
            if d.length > 1e-4:
                a = math.atan2(v.co.y, v.co.x)
                v.co.x *= 1.0 - 0.07 * (0.5 + 0.5 * math.cos(a * 10))
                v.co.y *= 1.0 - 0.07 * (0.5 + 0.5 * math.cos(a * 10))
        paint(pk, hexcol("f28a2a"), ao=0.0, fn=lambda co, n, c=c: shade(hexcol("f28a2a"), 0.8) if math.cos(math.atan2(co.y - c.y, co.x - c.x) * 10) > 0.75 else (
            shade(hexcol("f28a2a"), 1.15) if n.z > 0.7 else None))
        stem = tube("pks", [tuple(c + Vector((0, 0, 0.1))), tuple(c + Vector((0.02, 0.01, 0.18))), tuple(c + Vector((0.06, 0.02, 0.21)))], [0.025, 0.018, 0.012], 6)
        paint(stem, hexcol("6a7a3a"), ao=0.0)
        _plant(i, (x, y, z), leaves, stems, [([pk, stem], tuple(c))])


def crop_pepper():
    rr = rnd(108)
    for i, (x, y, z) in enumerate([SPOTS[j] for j in (0, 2, 4, 6, 8)]):
        stems, leaves, fruits = [], [], []
        st = tube("pps", [(x, y, z), (x, y, z + 0.25), (x + 0.02, y, z + 0.45)], [0.014, 0.011, 0.006], 6)
        paint(st, hexcol("5a9a3a"), ao=0.0)
        stems.append(st)
        for k in range(10):
            a = k * 2.3 + rr.uniform(-0.3, 0.3)
            zz = z + 0.12 + k * 0.032
            p = Vector((x + math.cos(a) * 0.04, y + math.sin(a) * 0.04, zz))
            leaves.append(_leaflet("pp_leaf", p, (math.cos(a), math.sin(a), 0.45), rr.uniform(0.11, 0.15), 0.045,
                                   shade(hexcol("3f9a3a"), 0.9 + 0.15 * rr.random()), droop=0.3, fold=0.25, shape=_round))
        for k in range(3):
            a = k * 2.1 + 0.4
            top = Vector((x + math.cos(a) * 0.09, y + math.sin(a) * 0.09, z + 0.3 - k * 0.04))
            prof = [(0.0, -0.13), (0.012, -0.11), (0.026, -0.07), (0.032, -0.02), (0.03, 0.0), (0.012, 0.01)]
            pp = lathe("pp", prof, 12, loc=tuple(top))
            for v in pp.data.vertices:   # чуть изогнут
                t = max(0.0, -v.co.z) / 0.13
                v.co.x += 0.03 * t * t
            col = [hexcol("e8352a"), hexcol("f2782a"), hexcol("e8352a")][k]
            paint(pp, col, ao=0.0, fn=lambda co, n, col=col: shade(col, 1.25) if n.x < -0.5 else None)
            cap = sphere("pcap", tuple(top + Vector((0, 0, 0.01))), 0.02, (1, 1, 0.6), segs=8, rings=5)
            paint(cap, hexcol("3f8a34"), ao=0.0)
            fruits.append(([pp, cap], tuple(top + Vector((0, 0, -0.05)))))
        _plant(i, (x, y, z), leaves, stems, fruits)


def crop_cloudberry():
    rr = rnd(109)
    for i, (x, y, z) in enumerate(SPOTS):
        leaves, fruits = [], []
        for k in range(3):
            a = 2 * math.pi * k / 3 + rr.uniform(-0.3, 0.3)
            p = Vector((x + math.cos(a) * 0.05, y + math.sin(a) * 0.05, z + 0.08))
            st = tube("cbs_leaf", [(x, y, z), tuple(p)], 0.005, 4)
            paint(st, hexcol("6a9a3a"), ao=0.0)
            leaves.append(st)
            for q in range(5):   # пятилопастный морщинистый лист
                aa = a + (q - 2) * 0.55
                leaves.append(_leaflet("cbl_leaf", p, (math.cos(aa), math.sin(aa), 0.15), 0.07 - abs(q - 2) * 0.008, 0.035,
                                       shade(hexcol("4f8f3a"), 0.95 + 0.1 * rr.random()), droop=0.15, fold=0.2, shape=_round))
        c = Vector((x + 0.02, y - 0.01, z + 0.16))
        stalk = tube("cbk_leaf", [(x, y, z), tuple(c + Vector((0, 0, -0.03)))], 0.004, 4)
        paint(stalk, hexcol("7a8a3a"), ao=0.0)
        leaves.append(stalk)
        berry = []
        for k in range(12):   # ягода из шариков-костянок
            th = math.acos(1 - 2 * (k + 0.5) / 12)
            ph = k * 2.4
            q = c + Vector((math.sin(th) * math.cos(ph), math.sin(th) * math.sin(ph), math.cos(th) * 0.9)) * 0.022
            dr = sphere("dr", tuple(q), 0.013, segs=8, rings=5)
            paint(dr, hexcol("f2a03a"), ao=0.0, fn=lambda co, n: hexcol("ffd27a") if n.z > 0.5 else None)
            berry.append(dr)
        for s in range(4):
            sa = 2 * math.pi * s / 4
            sl = leaf("cs", tuple(c + Vector((0, 0, -0.02))), (math.cos(sa), math.sin(sa), -0.3), 0.03, 0.012, droop=0.1, segs=3)
            paint(sl, hexcol("5a8a3a"), ao=0.0)
            berry.append(sl)
        fruits.append((berry, tuple(c)))
        if i % 3 == 1:   # белый цветок
            fl = []
            fc = Vector((x - 0.06, y + 0.05, z + 0.13))
            for p in range(5):
                pa = 2 * math.pi * p / 5
                pt = leaf("cf", tuple(fc), (math.cos(pa), math.sin(pa), 0.15), 0.035, 0.024, droop=0.1, segs=3)
                paint(pt, hexcol("fbf8ee"), ao=0.0, noise_amt=0)
                fl.append(pt)
            cc = sphere("cfc", tuple(fc), 0.01, segs=8, rings=5)
            paint(cc, hexcol("ffd23f"), ao=0.0)
            fl.append(cc)
            fruits.append((fl, tuple(fc)))
        _plant(i, (x, y, z), leaves, [], fruits)


BUILDERS = {"garden_bed": garden_bed, "crop_sprout": crop_sprout, "crop_young": crop_young, "crop_carrot": crop_carrot,
            "crop_potato": crop_potato, "crop_corn": crop_corn, "crop_tomato": crop_tomato,
            "crop_cabbage": crop_cabbage, "crop_watermelon": crop_watermelon, "crop_pumpkin": crop_pumpkin,
            "crop_pepper": crop_pepper, "crop_cloudberry": crop_cloudberry}
