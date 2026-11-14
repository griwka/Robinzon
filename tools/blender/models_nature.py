"""Природа: пальмы, фруктовые деревья, саженец, кусты, валуны, камешки, коряга, ракушка.
Узлы с особыми именами нужны игре: Crown (крона трясётся), Coconuts, Fruit (плоды прячутся после сбора).
Слово leaf в имени объекта — листва (качается на ветру, растворяется у камеры)."""
import math

from mathutils import Vector

from kit import (cyl, displace, empty, hexcol, ico, join, lathe, leaf, mix, paint, rnd, set_origin, set_parent,
                 shade, sphere, subsurf, tube)

BARK = hexcol("a87b4f")
LEAF = hexcol("3d9a4c")
LEAF2 = hexcol("4fa857")


# ------------------------------------------------------------------ пальма
def frond(name, base, yaw, pitch, length, r, seed):
    """Лист пальмы: изогнутый черешок + множество листочков по обе стороны."""
    rr = rnd(seed)
    d = Vector((math.cos(yaw) * math.cos(pitch), math.sin(yaw) * math.cos(pitch), math.sin(pitch)))
    side = Vector((-math.sin(yaw), math.cos(yaw), 0))
    pts = []
    for i in range(9):
        t = i / 8
        p = Vector(base) + d * (t * length) - Vector((0, 0, 1)) * (t * t * length * 0.55)
        pts.append(p)
    parts = []
    stem = tube(name + "s", pts, [0.035 * (1 - t / 9) + 0.008 for t in range(9)], 6)
    paint(stem, hexcol("6b9a3a"), ao=0.0)
    parts.append(stem)
    col = LEAF if seed % 2 else LEAF2
    for i in range(1, 9):
        t = i / 8
        p = pts[i]
        ln = length * 0.42 * math.sin(math.pi * min(1.0, t * 0.9 + 0.12))
        tangent = (pts[min(i + 1, 8)] - pts[i - 1]).normalized()
        for sgn in (-1, 1):
            dirv = (side * sgn * 0.85 + tangent * 0.55 - Vector((0, 0, 0.35))).normalized()
            lf = leaf(name + "l", p, dirv, ln, 0.06 + 0.03 * (1 - t), droop=0.5, segs=5, fold=0.3, up=(0, 0, 1))
            paint(lf, shade(col, 0.88 + 0.2 * rr.random()), ao=0.0, noise_amt=0.05,
                  fn=lambda co, n: 1.12 if n.z > 0.5 else None)
            parts.append(lf)
    return join(parts, name)


def palm(seed=1):
    rr = rnd(seed)
    h = rr.uniform(4.4, 5.8)
    lean = Vector((rr.uniform(-0.6, 0.6), rr.uniform(-0.6, 0.6), 0))
    pts, radii = [], []
    for i in range(14):
        t = i / 13
        pts.append(Vector((0, 0, t * h)) + lean * (t ** 1.7))
        radii.append(0.25 * (1 - t) + 0.14)
    trunk = tube("trunk", pts, radii, 14)
    subsurf(trunk, 1)

    def rings(co, n):
        k = (co.z * 3.2) % 1.0
        return 0.78 if k < 0.18 else (1.08 if k > 0.75 else None)
    paint(trunk, BARK, ao=0.25, ao_h=0.6, noise_amt=0.1, nscale=6, fn=rings)
    trunk.name = "Trunk"
    top = pts[-1]
    crown = empty("Crown", tuple(top))
    fronds = []
    n = rr.randint(8, 10)
    for i in range(n):
        yaw = 2 * math.pi * i / n + rr.uniform(-0.2, 0.2)
        fronds.append(frond("fr%d" % i, tuple(top), yaw, rr.uniform(0.05, 0.55), rr.uniform(2.2, 2.9), 0, seed * 10 + i))
    fl = join(fronds, "Crown_leaf")
    set_origin(fl, tuple(top))
    set_parent(fl, crown)
    cocos = []
    for i in range(rr.randint(3, 5)):
        a = 2 * math.pi * i / 4 + rr.random()
        c = sphere("co", tuple(top + Vector((math.cos(a) * 0.22, math.sin(a) * 0.22, -0.25 - rr.random() * 0.08))), 0.16, (1, 1, 1.1), segs=14, rings=10)
        paint(c, hexcol("6b4423"), ao=0.0, noise_amt=0.12, nscale=12)
        cocos.append(c)
    co = join(cocos, "Coconuts")
    set_origin(co, tuple(top))
    set_parent(co, crown)


def palm_a():
    palm(1)


def palm_b():
    palm(2)


def palm_c():
    palm(3)


# ------------------------------------------------------------------ банановое дерево
def banana_tree():
    rr = rnd(7)
    h = 2.6
    stem = tube("st", [(0, 0, 0), (0.03, 0, h * 0.5), (0.05, 0.02, h)], [0.24, 0.19, 0.15], 14)
    subsurf(stem, 1)
    paint(stem, hexcol("8f9a4a"), ao=0.3, ao_h=0.5, noise_amt=0.12, nscale=5,
          fn=lambda co, n: 0.8 if (math.atan2(co.y, co.x) * 3 + co.z * 2) % 1.0 < 0.15 else None)
    stem.name = "Trunk"
    crown = empty("Crown", (0.05, 0.02, h))
    leaves = []
    for i in range(7):
        yaw = 2 * math.pi * i / 7 + rr.uniform(-0.2, 0.2)
        d = (math.cos(yaw) * 0.6, math.sin(yaw) * 0.6, rr.uniform(0.9, 1.4))
        lf = leaf("bl", (0.05, 0.02, h - 0.1), d, rr.uniform(2.0, 2.5), rr.uniform(0.42, 0.52), droop=0.75, segs=12, fold=0.12,
                  shape=lambda t: math.sin(math.pi * min(1.0, t * 0.85 + 0.15)) ** 0.6)
        subsurf(lf, 1)
        c = LEAF2 if i % 2 else hexcol("49b844")
        # надрывы по краю листа
        paint(lf, c, ao=0.0, noise_amt=0.08, fn=lambda co, n, c=c: shade(c, 0.85) if math.sin(co.x * 40 + co.y * 40) > 0.85 else (1.12 if n.z > 0.4 else None))
        leaves.append(lf)
    lv = join(leaves, "Crown_leaf")
    set_origin(lv, (0.05, 0.02, h))
    set_parent(lv, crown)
    # гроздь бананов + фиолетовый бутон
    parts = [tube("fs", [(0.25, 0.0, h - 0.1), (0.35, 0.0, h - 0.4), (0.36, 0.0, h - 0.95)], 0.03, 6)]
    paint(parts[0], hexcol("6d7a35"), ao=0.0)
    for ring in range(4):
        z = h - 0.5 - ring * 0.13
        for k in range(6):
            a = 2 * math.pi * k / 6 + ring * 0.5
            base = Vector((0.36 + math.cos(a) * 0.05, math.sin(a) * 0.05, z))
            tip = base + Vector((math.cos(a) * 0.12, math.sin(a) * 0.12, 0.14))
            b = tube("ba", [base, (base + tip) / 2 + Vector((math.cos(a) * 0.03, math.sin(a) * 0.03, 0)), tip], [0.035, 0.04, 0.02], 8)
            paint(b, hexcol("ffe14d"), ao=0.0, fn=lambda co, n: 0.8 if co.z > z + 0.12 else None)
            parts.append(b)
    bud = sphere("bud", (0.36, 0.0, h - 1.05), 0.09, (1, 1, 1.5))
    paint(bud, hexcol("8a3a6a"), ao=0.0)
    parts.append(bud)
    fr = join(parts, "Fruit")
    set_origin(fr, (0.3, 0, h - 0.1))   # гроздь «наливается» от черешка (игра масштабирует её при созревании)


# ------------------------------------------------------------------ деревья с круглой кроной
def round_tree(seed, leaf_col, fruit_col, fruit_r, fruit_shape=(1, 1, 1.1)):
    rr = rnd(seed)
    h = 1.9
    trunk = tube("tr", [(0, 0, 0), (0.05, 0, h * 0.5), (0.0, 0.05, h)], [0.2, 0.14, 0.12], 12)
    br1 = tube("b1", [(0.03, 0, h * 0.7), (0.45, 0.1, h + 0.35)], [0.09, 0.04], 8)
    br2 = tube("b2", [(0.0, 0.03, h * 0.8), (-0.35, -0.2, h + 0.45)], [0.08, 0.035], 8)
    roots = [tube("rt", [(0, 0, 0.15), (math.cos(a) * 0.32, math.sin(a) * 0.32, -0.02)], [0.09, 0.03], 8)
             for a in (0.3, 2.4, 4.3)]
    for o in [trunk, br1, br2] + roots:
        subsurf(o, 1)
        paint(o, hexcol("8a5a32"), ao=0.25, ao_h=0.4, noise_amt=0.12, nscale=8,
              fn=lambda co, n: 0.85 if math.sin(co.z * 30 + math.atan2(co.y, co.x) * 2) > 0.7 else None)
    t = join([trunk, br1, br2] + roots, "Trunk")
    cz = h + 0.75
    crown = empty("Crown", (0, 0, cz))
    blobs = []
    for i, (x, y, z, r) in enumerate([(0, 0, 0.25, 0.95), (0.62, 0.15, 0, 0.68), (-0.6, -0.1, 0.05, 0.66), (0.1, 0.62, 0.0, 0.62),
                                      (-0.1, -0.62, 0.0, 0.64), (0.35, -0.35, 0.45, 0.55), (-0.35, 0.35, 0.5, 0.55)]):
        b = ico("cb", (x, y, cz + z), r, sub=3)
        displace(b, 0.22, 0.25)
        subsurf(b, 1)
        c = shade(leaf_col, 0.92 + 0.14 * (i % 3) / 2)
        paint(b, c, ao=0.0, noise_amt=0.14, nscale=5,
              fn=lambda co, n, c=c: 1.18 if n.z > 0.55 else (0.78 if n.z < -0.2 else None))
        blobs.append(b)
    cl = join(blobs, "Crown_leaf")
    set_origin(cl, (0, 0, cz))
    set_parent(cl, crown)
    fruits = []
    for i in range(11):
        a = 2 * math.pi * i / 11 + rr.uniform(-0.3, 0.3)
        zz = rr.uniform(-0.45, 0.4)
        dd = math.sqrt(max(0.0, 1.0 - zz * zz)) * 1.02
        c = (math.cos(a) * dd, math.sin(a) * dd, cz + zz)
        f = sphere("Fruit_%d" % i, c, fruit_r, fruit_shape, segs=14, rings=10)
        paint(f, fruit_col, ao=0.0, noise_amt=0.05, fn=lambda co, n: 1.15 if n.z > 0.4 else None)
        leafy = leaf("fl", (c[0], c[1], c[2] + fruit_r * fruit_shape[2] * 0.9), (math.cos(a), math.sin(a), 0.8), fruit_r * 0.9, fruit_r * 0.35, droop=0.2, segs=3)
        paint(leafy, shade(leaf_col, 1.1), ao=0.0)
        f = join([f, leafy], "Fruit_%d" % i)
        fruits.append((f, c))
    # каждый плод отдельно, точка вращения — в его центре: игра «наливает» плоды по одному
    holder = empty("Fruit", (0, 0, cz))
    for f, c in fruits:
        set_origin(f, c)
        set_parent(f, holder)


def mango_tree():
    round_tree(11, hexcol("2f8a48"), hexcol("ff8f2e"), 0.13, (1, 1, 1.25))


def lemon_tree():
    round_tree(12, hexcol("4a9e4c"), hexcol("f7ef4a"), 0.1, (1, 1, 1.3))


def sapling():
    pot = lathe("pt", [(0.0, 0.0), (0.2, 0.0), (0.26, 0.25), (0.29, 0.27), (0.29, 0.31), (0.0, 0.31)], 22)
    paint(pot, hexcol("d9774a"), ao=0.0, fn=lambda co, n: 1.1 if co.z > 0.26 else None)
    soil = cyl("so", (0, 0, 0.27), 0.25, 0.25, 0.05, segs=22)
    paint(soil, hexcol("5a3a22"), ao=0.0)
    stem = tube("ss", [(0, 0, 0.3), (0.02, 0, 0.55), (-0.01, 0.01, 0.8)], [0.025, 0.02, 0.012], 6)
    paint(stem, hexcol("6fbf4a"), ao=0.0)
    parts = [pot, soil, stem]
    for i, (z, a) in enumerate(((0.55, 0.3), (0.68, 2.5), (0.8, 4.4))):
        lf = leaf("sl_leaf", (0, 0, z), (math.cos(a), math.sin(a), 0.4), 0.22, 0.08, droop=0.2)
        paint(lf, hexcol("6fd04f"), ao=0.0)
        parts.append(lf)
    join(parts, "Sapling")


# ------------------------------------------------------------------ кусты
def bush(seed):
    rr = rnd(seed)
    col = mix(hexcol("2f8a45"), hexcol("4a9a48"), rr.random())
    parts = []
    for i in range(5):
        r = rr.uniform(0.4, 0.6)
        b = ico("bb", (rr.uniform(-0.45, 0.45), rr.uniform(-0.45, 0.45), r * 0.85), r, sub=3)
        displace(b, 0.16, 0.18)
        c = shade(col, 0.92 + 0.1 * i / 4)
        paint(b, c, ao=0.3, ao_h=0.5, noise_amt=0.15, nscale=7,
              fn=lambda co, n, c=c: 1.2 if n.z > 0.6 else (0.8 if n.z < -0.3 else None))
        parts.append(b)
    pal = [hexcol("ff6fa5"), hexcol("ffd84a"), hexcol("ffffff"), hexcol("ff8a3d")]
    fc = pal[seed % len(pal)]
    for i in range(9):
        a = rr.uniform(0, 2 * math.pi)
        z = rr.uniform(0.6, 1.15)
        p = Vector((math.cos(a) * 0.58, math.sin(a) * 0.58, z))
        for k in range(5):
            pa = 2 * math.pi * k / 5
            pe = sphere("pe", tuple(p + Vector((math.cos(pa) * 0.04, math.sin(pa) * 0.04, 0.02))), 0.035, (1, 1, 0.5), segs=8, rings=5)
            paint(pe, fc, ao=0.0, noise_amt=0)
            parts.append(pe)
        ctr = sphere("pc", tuple(p + Vector((0, 0, 0.035))), 0.022, segs=8, rings=5)
        paint(ctr, hexcol("ffb02e"), ao=0.0, noise_amt=0)
        parts.append(ctr)
    join(parts, "Bush_leaf")


def bush_a():
    bush(1)


def bush_b():
    bush(2)


def bush_c():
    bush(3)


# ------------------------------------------------------------------ камни
def _moss_top(z0, nz):
    """Мох на верхних гранях выше z0: граница рваная (шум), снизу — отдельные пятнышки."""
    from mathutils import noise

    def f(co, n):
        v = n.z + 0.22 * noise.noise(co * 5.0) + 0.1 * noise.noise(co * 17.0)
        return hexcol("6fb04a") if (v > nz and co.z > z0) else None
    return f


def rock(seed, big=True):
    rr = rnd(seed)
    col = mix(hexcol("a7abb0"), hexcol("bdb3a3"), rr.random())
    parts = []
    n = 3 if big else 1
    for i in range(n):
        s = rr.uniform(0.8, 1.15) * (1.0 if i == 0 else 0.55) * (1.0 if big else 0.22)
        x, y = (0, 0) if i == 0 else (rr.uniform(-0.7, 0.7), rr.uniform(-0.7, 0.7))
        r = ico("rk", (x, y, s * 0.35), s, (rr.uniform(1.0, 1.3), 1.0, 0.7), (0, 0, rr.uniform(0, 3)), sub=2)
        displace(r, 0.35 * s, 0.6 * s, "VORONOI")
        subsurf(r, 1)
        # мох на макушке: край — по шуму, не по ровной линии (в текстуре видно каждый пиксель); деталь камня
        # (крапинки, трещины, лишайник) и мха рисует texbake_props
        paint(r, shade(col, 1 - 0.06 * i), ao=0.35, ao_h=0.4 * s + 0.05, noise_amt=0.12, nscale=4 / s,
              fn=_moss_top(0.35, 0.72) if big else None)
        parts.append(r)
    join(parts, "Rock")


def rock_a():
    rock(1)


def rock_b():
    rock(2)


def rock_c():
    rock(3)


def pebble_a():
    rock(4, False)


def pebble_b():
    rock(5, False)


def driftwood():
    rr = rnd(9)
    pts = [(-0.8, 0, 0.12), (-0.3, 0.06, 0.14), (0.2, -0.04, 0.13), (0.8, 0.03, 0.11)]
    log = tube("dw", pts, [0.12, 0.15, 0.13, 0.1], 12, twist=0.3)
    displace(log, 0.03, 0.15)
    subsurf(log, 1)
    br = tube("db", [(0.2, -0.04, 0.15), (0.45, -0.3, 0.32), (0.6, -0.42, 0.36)], [0.06, 0.04, 0.02], 8)
    br2 = tube("db2", [(-0.4, 0.06, 0.16), (-0.55, 0.3, 0.2)], [0.05, 0.02], 8)
    for o in (log, br, br2):
        # волокна и трещины выбеленного дерева — texbake_props ("driftwood")
        paint(o, hexcol("c8a985"), ao=0.3, ao_h=0.15, noise_amt=0.12, nscale=10)
    join([log, br, br2], "Driftwood")


def shell():
    parts = []
    base = Vector((0, 0, 0.02))
    ribs = 9
    pts = []
    for i in range(ribs * 4 + 1):
        a = math.pi * 0.1 + math.pi * 0.8 * i / (ribs * 4)
        r = 0.16 * (1 + 0.06 * abs(math.sin(i / 4 * math.pi)))
        pts.append((math.cos(a) * r, math.sin(a) * r * 0.9))
    import bmesh
    from kit import from_bm
    bm = bmesh.new()
    c = bm.verts.new((0, -0.02, 0.02))
    ring = [bm.verts.new((x, y - 0.02, 0.02 + 0.06 * math.sin(math.pi * (j / len(pts))) * 0.5)) for j, (x, y) in enumerate(pts)]
    top = bm.verts.new((0, 0.04, 0.08))
    for j in range(len(ring) - 1):
        bm.faces.new((c, ring[j + 1], ring[j]))
        bm.faces.new((top, ring[j], ring[j + 1]))
    sh = from_bm("sh", bm)
    subsurf(sh, 1)
    def shell_fn(co, n):
        # рёбра веером от «замка»: мягкий профиль (не полосы через одну), к краю — пара тёмных колец роста
        a = math.atan2(co.y + 0.02, co.x)
        rib = 0.5 + 0.5 * math.cos(a * ribs * 2)
        d = math.hypot(co.x, co.y + 0.02)
        band = 0.9 if (0.105 < d < 0.118 or 0.138 < d < 0.146) else 1.0
        return (0.86 + 0.16 * rib * rib) * band
    paint(sh, hexcol("f6c7c0"), ao=0.0, fn=shell_fn)
    parts.append(sh)
    join(parts, "Shell")


BUILDERS = {"palm_a": palm_a, "palm_b": palm_b, "palm_c": palm_c, "banana_tree": banana_tree,
            "mango_tree": mango_tree, "lemon_tree": lemon_tree, "sapling": sapling,
            "bush_a": bush_a, "bush_b": bush_b, "bush_c": bush_c,
            "rock_a": rock_a, "rock_b": rock_b, "rock_c": rock_c, "pebble_a": pebble_a, "pebble_b": pebble_b,
            "driftwood": driftwood, "shell": shell}
