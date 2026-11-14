"""Джунгли и преграды: деревья-гиганты, папоротники, высокая трава, колючий кустарник, бамбук,
поваленные стволы, каменные гряды, цветы. Плюс сюжетные места: старый лагерь Лёвы,
шлюпка «Альбатроса», древний маяк на вершине (узел Bowl — чаша огня)."""
import math

from mathutils import Vector

from kit import (box, cyl, displace, empty, hexcol, ico, join, lathe, leaf, mix, paint, rnd, set_origin, set_parent,
                 shade, sphere, subsurf, tube)
from models_buildings import log, plank, stone

# приглушённая, не "кислотная" зелень
JG = hexcol("3c8a45")
JG2 = hexcol("4f9a4a")
JG_D = hexcol("2e6e3e")
OLIVE = hexcol("6f9a3e")
BARK_J = hexcol("7d6148")


def _leafy_fn(c):
    return lambda co, n: 1.15 if n.z > 0.5 else (0.8 if n.z < -0.3 else None)


# ------------------------------------------------------------------ дерево-гигант (рубится топором)
def jungle_tree(seed):
    rr = rnd(seed)
    h = rr.uniform(6.5, 8.0)
    parts = []
    trunk = tube("jt", [(0, 0, 0), (0.1, 0.05, h * 0.4), (-0.1, 0.1, h * 0.75), (0, 0, h)], [0.55, 0.42, 0.34, 0.28], 14)
    displace(trunk, 0.08, 0.3)
    subsurf(trunk, 1)
    parts.append(trunk)
    for k in range(5):   # корни-досками
        a = 2 * math.pi * k / 5 + rr.random()
        r = tube("br", [(math.cos(a) * 0.2, math.sin(a) * 0.2, 1.4), (math.cos(a) * 0.7, math.sin(a) * 0.7, 0.4), (math.cos(a) * 1.2, math.sin(a) * 1.2, -0.05)],
                 [0.22, 0.16, 0.06], 8)
        parts.append(r)
    for k in range(3):   # ветви
        a = 2 * math.pi * k / 3 + rr.random()
        z0 = h * rr.uniform(0.7, 0.9)
        parts.append(tube("bb", [(0, 0, z0), (math.cos(a) * 1.4, math.sin(a) * 1.4, z0 + 1.0), (math.cos(a) * 2.2, math.sin(a) * 2.2, z0 + 1.4)], [0.2, 0.12, 0.06], 8))
    for p in parts:
        paint(p, BARK_J, ao=0.3, ao_h=1.0, noise_amt=0.14, nscale=4,
              fn=lambda co, n: hexcol("5f8a3a") if (n.z > 0.3 and co.z < 2) else None, mat="bark")
    t = join(parts, "Trunk")
    crown = empty("Crown", (0, 0, h))
    blobs = []
    for i in range(9):
        a = 2 * math.pi * i / 9
        rr2 = 1.3 if i % 3 == 0 else 1.0
        b = ico("cb", (math.cos(a) * 1.7 * rr2, math.sin(a) * 1.7 * rr2, h + 0.5 + rr.uniform(-0.3, 0.6)), rr.uniform(1.1, 1.5), (1, 1, 0.7), sub=2)
        displace(b, 0.35, 0.4)
        c = shade(JG, 0.9 + 0.15 * rr.random())
        paint(b, c, ao=0.0, noise_amt=0.16, nscale=3, fn=_leafy_fn(c))
        blobs.append(b)
    top = ico("ct", (0, 0, h + 1.2), 1.7, (1, 1, 0.6), sub=2)
    displace(top, 0.4, 0.4)
    paint(top, JG2, ao=0.0, noise_amt=0.16, nscale=3, fn=_leafy_fn(JG2))
    blobs.append(top)
    cl = join(blobs, "Crown_leaf")
    set_origin(cl, (0, 0, h))
    set_parent(cl, crown)
    # свисающие лианы
    lianas = []
    for k in range(5):
        a = 2 * math.pi * k / 5 + 0.4
        x, y = math.cos(a) * 1.9, math.sin(a) * 1.9
        lianas.append(tube("li", [(x, y, h + 0.2), (x * 1.05, y * 1.05, h - 1.5), (x * 0.95, y * 0.95, h - 3.2)], [0.03, 0.025, 0.015], 5))
    for l in lianas:
        paint(l, hexcol("5f7a35"), ao=0.0)
    lj = join(lianas, "Lianas_leaf")
    set_parent(lj, crown)


def jungle_tree_a():
    jungle_tree(21)


def jungle_tree_b():
    jungle_tree(22)


# ------------------------------------------------------------------ папоротник
def fern(seed):
    rr = rnd(seed)
    parts = []
    for k in range(rr.randint(9, 12)):
        a = 2 * math.pi * k / 11 + rr.uniform(-0.2, 0.2)
        stem = [(0, 0, 0.05)]
        ln = rr.uniform(0.7, 1.0)
        for i in range(1, 7):
            t = i / 6
            stem.append((math.cos(a) * ln * t, math.sin(a) * ln * t, 0.05 + math.sin(t * math.pi * 0.8) * ln * 0.6))
        s = tube("fs", stem, 0.012, 4)
        paint(s, OLIVE, ao=0.0)
        parts.append(s)
        for i in range(1, 6):
            p = Vector(stem[i])
            tan = (Vector(stem[i + 1]) - Vector(stem[i - 1])).normalized()
            side = tan.cross(Vector((0, 0, 1))).normalized()
            for sg in (-1, 1):
                lf = leaf("fl_leaf", tuple(p), tuple(side * sg + tan * 0.6), 0.22 * (1 - i / 7) + 0.06, 0.035, droop=0.3, segs=4)
                paint(lf, shade(JG2, 0.9 + 0.1 * rr.random()), ao=0.0)
                parts.append(lf)
    join(parts, "Fern_leaf")


def fern_a():
    fern(31)


def fern_b():
    fern(32)


# ------------------------------------------------------------------ высокая трава (руками)
def tall_grass():
    rr = rnd(41)
    parts = []
    for k in range(26):
        a = rr.uniform(0, 2 * math.pi)
        r = rr.uniform(0, 0.4)
        x, y = math.cos(a) * r, math.sin(a) * r
        h = rr.uniform(0.7, 1.3)
        lean = Vector((math.cos(a), math.sin(a), 0)) * rr.uniform(0.1, 0.35)
        lf = leaf("tg_leaf", (x, y, 0), (lean.x, lean.y, 1), h, 0.04, droop=0.25, segs=5, fold=0.2,
                  shape=lambda t: (1 - t) ** 0.7)
        c = mix(OLIVE, hexcol("a9b860"), rr.random() * 0.5)
        paint(lf, c, ao=0.3, ao_h=0.5, noise_amt=0.05)
        parts.append(lf)
    for k in range(4):   # колоски
        x, y = rr.uniform(-0.3, 0.3), rr.uniform(-0.3, 0.3)
        s = sphere("sp", (x, y, rr.uniform(1.1, 1.35)), 0.03, (1, 1, 3), segs=8, rings=5)
        paint(s, hexcol("d9c47a"), ao=0.0)
        parts.append(s)
    join(parts, "TallGrass_leaf")


# ------------------------------------------------------------------ колючий кустарник (мачете)
def thicket():
    rr = rnd(51)
    parts = []
    for i in range(7):
        r = rr.uniform(0.45, 0.7)
        b = ico("th", (rr.uniform(-0.6, 0.6), rr.uniform(-0.6, 0.6), r * 0.8), r, (1, 1, 0.85), sub=2)
        displace(b, 0.25, 0.15, "VORONOI")
        c = shade(JG_D, 0.9 + 0.15 * rr.random())
        paint(b, c, ao=0.3, ao_h=0.6, noise_amt=0.18, nscale=8, fn=_leafy_fn(c))
        parts.append(b)
    for k in range(30):  # шипы
        a = rr.uniform(0, 2 * math.pi)
        z = rr.uniform(0.3, 1.2)
        p = Vector((math.cos(a) * 0.8, math.sin(a) * 0.8, z))
        th = cyl("tn", tuple(p), 0.025, 0.0, 0.12, (rr.uniform(0.5, 1.5), 0, a), segs=5)
        paint(th, hexcol("c9b48a"), ao=0.0)
        parts.append(th)
    for k in range(6):  # мелкие красные ягоды
        a = rr.uniform(0, 2 * math.pi)
        s = sphere("be", (math.cos(a) * 0.75, math.sin(a) * 0.75, rr.uniform(0.6, 1.1)), 0.04, segs=8, rings=5)
        paint(s, hexcol("c23a3a"), ao=0.0)
        parts.append(s)
    join(parts, "Thicket_leaf")


# ------------------------------------------------------------------ бамбук (мачете)
def bamboo_clump():
    rr = rnd(61)
    parts = []
    for k in range(9):
        a = rr.uniform(0, 2 * math.pi)
        r = rr.uniform(0, 0.5)
        x, y = math.cos(a) * r, math.sin(a) * r
        h = rr.uniform(3.2, 5.0)
        lean = (rr.uniform(-0.3, 0.3), rr.uniform(-0.3, 0.3))
        st = tube("bs", [(x, y, 0), (x + lean[0] * 0.5, y + lean[1] * 0.5, h * 0.5), (x + lean[0], y + lean[1], h)], [0.07, 0.06, 0.04], 10)

        def nodes(co, n):
            k2 = (co.z / 0.45) % 1.0
            return 0.72 if k2 < 0.06 else (1.08 if k2 < 0.2 else None)
        paint(st, hexcol("a9b84a"), ao=0.3, ao_h=0.8, noise_amt=0.05, fn=nodes, mat="bamboo")
        parts.append(st)
        for j in range(4):
            z = h * (0.55 + j * 0.13)
            ang = rr.uniform(0, 2 * math.pi)
            for q in range(3):
                lf = leaf("bl_leaf", (x + lean[0] * z / h, y + lean[1] * z / h, z), (math.cos(ang + q * 0.5), math.sin(ang + q * 0.5), -0.1),
                          0.4, 0.05, droop=0.4, segs=4)
                paint(lf, JG2, ao=0.0)
                parts.append(lf)
    join(parts, "Bamboo_leaf")


# ------------------------------------------------------------------ поваленный ствол (топор)
def fallen_log():
    _fallen_log(71, True)


def fallen_log_b():
    _fallen_log(72, False)


def _fallen_log(seed, rooted):
    """Упавшее дерево: кора с бороздами; с одного конца — вывороченные корни (или ровный срез топором),
    с другого — обломанный неровный торец с годовыми кольцами и щепой; обломанные сучья, мох, трутовики, грибы."""
    from kit import BARK, bark_fn, bark_trunk, splinters, wood_cap
    rr = rnd(seed)
    if rooted:
        path = [(-1.3, 0.0, 0.42), (-1.0, 0.03, 0.40), (-0.6, 0.07, 0.38), (0.2, -0.04, 0.36), (0.95, 0.05, 0.34), (1.45, 0.0, 0.33)]
        radii = [0.52, 0.43, 0.39, 0.37, 0.34, 0.31]
        bark_col = BARK
    else:
        path = [(-1.35, 0.0, 0.36), (-0.6, -0.06, 0.35), (0.2, 0.05, 0.33), (0.95, -0.03, 0.32), (1.4, 0.0, 0.3)]
        radii = [0.37, 0.36, 0.35, 0.33, 0.3]
        bark_col = hexcol("6e5a48")
    lg, first, last, fa, fb = bark_trunk("fl", path, radii, segs=22, seed=seed - 64, furrows=11, bump=0.08)
    paint(lg, bark_col, ao=0.35, ao_h=0.35, noise_amt=0.1, nscale=6,
          fn=bark_fn((0, 0, 0.37), (1, 0, 0), moss=0.45 if rooted else 0.75, seed=3 + seed, moss_up=0.5))
    parts = [lg]
    # обломанный конец (+X): утопленный неровный скол с кольцами и щепа по краю
    parts.append(wood_cap("cap_b", last, fb[0] + fb[1] * 0.02, fb[1], radii[-1], seed=seed + 11, depth=0.07, rough=0.04))
    parts += splinters("spl", last, fb[1], seed=seed + 5, count=11, length=(0.05, 0.26), width=0.15)
    if rooted:
        parts += _log_roots(rr, first, fa)
    else:
        # ровный срез топором: светлый торец с кольцами
        parts.append(wood_cap("cap_a", first, fa[0] - fa[1] * 0.01, -fa[1], radii[0], seed=seed + 5, depth=0.01, rough=0.008))
    parts += _log_details(rr, radii[2])
    join(parts, "FallenLog")
    # папоротнички у ствола (и росток на бревне без корней) — листвой, качаются на ветру
    leaves = []
    spots = ((0.1, -0.5, 6, 0.34), (1.3, 0.45, 5, 0.26), (-0.8, 0.52, 4, 0.24)) if rooted else ((-0.4, -0.45, 6, 0.3), (1.1, 0.42, 5, 0.24))
    for (cx, cy, n_, ln) in spots:
        for k in range(n_):
            a = 2 * math.pi * k / n_ + rr.uniform(-0.3, 0.3)
            lf = leaf("fl_leaf", (cx, cy, 0.02), (math.cos(a), math.sin(a), 0.9), ln, 0.06, droop=0.5, segs=5)
            paint(lf, shade(JG2 if k % 2 else OLIVE, 0.9 + 0.12 * rr.random()), ao=0.0)
            leaves.append(lf)
    if not rooted:
        top = radii[2] * 2 - 0.02
        st = tube("sprout_leaf", [(0.35, 0.0, top - 0.04), (0.36, 0.01, top + 0.08)], 0.014, 5)
        paint(st, OLIVE, ao=0.0)
        leaves.append(st)
        for k in range(5):
            a = 2 * math.pi * k / 5
            lf = leaf("fl_leaf", (0.36, 0.01, top + 0.08), (math.cos(a), math.sin(a), 1.0), 0.2, 0.07, droop=0.45, segs=5)
            paint(lf, shade(JG2, 0.95 + 0.1 * rr.random()), ao=0.0)
            leaves.append(lf)
    join(leaves, "FallenLog_leaf")


def _log_roots(rr, first, fa):
    """Комель: тёмный торец с землёй, корни звездой расходятся и уходят в землю, комья земли, взрыхлённая земля."""
    from kit import BARK_D, smooth_path, wood_cap
    x0 = fa[0].x
    parts = []
    root_cap = wood_cap("cap_a", first, fa[0] - fa[1] * 0.02, -fa[1], 0.46, seed=12, depth=-0.1, rough=0.06, heart=hexcol("5e4432"))
    paint(root_cap, hexcol("5e4532"), ao=0.0, noise_amt=0.25, nscale=7,
          fn=lambda co, n: hexcol("7d6446") if noise_v(co * 4) > 0.3 else None)
    parts.append(root_cap)
    for k in range(9):
        a = 2 * math.pi * k / 9 + rr.uniform(-0.18, 0.18)
        cy, cz = math.cos(a), math.sin(a)
        ln = rr.uniform(0.55, 0.95)
        r0 = 0.4
        p0 = Vector((x0 + 0.35, cy * r0 * 0.85, 0.42 + cz * r0 * 0.85))
        p1 = Vector((x0 - 0.02, cy * (r0 + 0.12), 0.42 + cz * (r0 + 0.12)))
        p2 = Vector((x0 - 0.25 - ln * 0.25, cy * (r0 + 0.25 + ln * 0.3), 0.42 + cz * (r0 + 0.2 + ln * 0.25)))
        pts = [p0, p1, p2]
        if p2.z < 0.55:   # нижние корни загибаются в землю
            pts.append(Vector((p2.x - 0.25, p2.y * 1.15, max(-0.2, p2.z - 0.45))))
        else:             # верхние торчат вверх и назад, тонко
            pts.append(p2 + Vector((-0.3, cy * 0.12, 0.06)))
        sp, sr = smooth_path([tuple(q) for q in pts], [0.16, 0.12, 0.06, 0.018], 4)
        root = tube("rt", sp, sr, 9)
        displace(root, 0.02, 0.08)
        paint(root, BARK_D, ao=0.0, noise_amt=0.15, nscale=8,
              fn=lambda co, n: hexcol("6a5440") if co.z < 0.12 else (shade(BARK_D, 1.25) if n.z > 0.55 else None))
        parts.append(root)
        if k % 3 != 1:   # тонкие отростки
            q = pts[2]
            tw = tube("rt2", [tuple(q), tuple(q + Vector((-0.18, cy * 0.2, cz * 0.1 - 0.06))), tuple(q + Vector((-0.28, cy * 0.3, cz * 0.12 - 0.2)))],
                      [0.035, 0.02, 0.008], 6)
            paint(tw, BARK_D, ao=0.0)
            parts.append(tw)
    for k in range(5):   # комья земли и камешки, застрявшие в корнях
        a = rr.uniform(0, 2 * math.pi)
        rad = rr.uniform(0.2, 0.45)
        clod = ico("cl", (x0 - rr.uniform(0.05, 0.2), math.cos(a) * rad, 0.42 + math.sin(a) * rad), rr.uniform(0.08, 0.14), (0.8, 1, 0.9), sub=1)
        displace(clod, 0.03, 0.1)
        paint(clod, hexcol("8f8a80") if k % 3 == 0 else hexcol("6b4f38"), ao=0.0, noise_amt=0.2, nscale=9)
        parts.append(clod)
    dirt = ico("dr", (x0 - 0.35, 0.0, -0.05), 0.55, (1.0, 1.3, 0.25), sub=2)   # взрыхлённая земля под корнями
    displace(dirt, 0.06, 0.3)
    paint(dirt, hexcol("6f5238"), ao=0.0, noise_amt=0.2, nscale=6, fn=lambda co, n: hexcol("86684a") if noise_v(co * 5) > 0.2 else None)
    parts.append(dirt)
    return parts


def _log_details(rr, r):
    """Обломанные сучья (косые, толстые у ствола), трутовики-полочки на боку и грибы рядом."""
    from kit import BARK, bark_fn, splinters, wood_cap
    parts = []
    for (x, a, ln) in ((-0.55, 1.15, 0.38), (0.45, -0.95, 0.32), (1.0, 2.25, 0.26), (-0.1, 2.0, 0.22)):
        base = Vector((x, math.cos(a) * (r - 0.04), r + math.sin(a) * (r - 0.04)))
        out = Vector((0.55, math.cos(a), math.sin(a) * 0.8)).normalized()
        tip = base + out * ln
        br = tube("br", [tuple(base - out * 0.1), tuple(base + out * ln * 0.45), tuple(tip)], [0.12, 0.085, 0.07], 10)
        paint(br, BARK, ao=0.0, noise_amt=0.1, fn=bark_fn(tuple(base), tuple(out), seed=int(x * 10)))
        parts.append(br)
        o1 = out.orthogonal().normalized()
        o2 = out.cross(o1)
        rim = [tip + (o1 * math.cos(t) + o2 * math.sin(t)) * 0.07 for t in [2 * math.pi * i / 10 for i in range(10)]]
        parts.append(wood_cap("bc", rim, tip, out, 0.07, seed=int(x * 7) + 20, depth=0.02, rough=0.012))
        parts += splinters("bs", rim, out, seed=int(x * 9) + 30, count=4, length=(0.04, 0.14), width=0.05)
    for (x, a, sz) in ((-0.25, -0.45, 0.12), (-0.08, -0.7, 0.09), (0.2, -0.5, 0.1), (0.85, 2.5, 0.11)):
        y, z = math.cos(a) * (r + 0.01), r + math.sin(a) * (r + 0.01)
        sh = sphere("fg", (x, y, z + 0.03), sz, (1.0, 0.7, 0.26), (0, 0, 0), segs=14, rings=7)
        paint(sh, hexcol("e0b46e"), ao=0.0, noise_amt=0.06,
              fn=lambda co, n: hexcol("f6e6c4") if n.z < -0.2 else (hexcol("b5793e") if n.z > 0.55 else None))
        parts.append(sh)
    for (x, y, h) in ((-1.85, -0.75, 0.14), (-1.7, -0.92, 0.09), (1.3, 0.55, 0.11), (1.42, 0.48, 0.07)):
        st = cyl("ms", (x, y, -0.02), 0.022, 0.017, h + 0.02, segs=8)
        paint(st, hexcol("efe4cc"), ao=0.0)
        cp = sphere("mc", (x, y, h), 0.06, (1, 1, 0.55), segs=12, rings=6)
        paint(cp, hexcol("c8643a"), ao=0.0, fn=lambda co, n: hexcol("f2e0c0") if n.z < 0 else None)
        parts += [st, cp]
    return parts


def noise_v(co):
    from mathutils import noise
    return noise.noise(co)


# ------------------------------------------------------------------ каменная гряда (кирка)
def cliff(seed):
    rr = rnd(seed)
    parts = []
    for i in range(6):
        x = -1.6 + i * 0.65
        s = rr.uniform(0.7, 1.1)
        r = ico("cl", (x, rr.uniform(-0.25, 0.25), s * 0.8), s, (0.8, 0.75, 1.25), (0, rr.uniform(-0.3, 0.3), rr.random()), sub=2)
        displace(r, 0.35, 0.5, "VORONOI")
        subsurf(r, 1)
        c = mix(hexcol("8f9196"), hexcol("a89f90"), rr.random())
        # слои породы, трещины и лишайник рисует texbake_props ("cliff"); мох сверху — с рваным краем
        paint(r, c, ao=0.35, ao_h=0.6, noise_amt=0.12, nscale=3,
              fn=lambda co, n: hexcol("6f9a48") if (n.z + 0.2 * noise_v(co * 4.0) > 0.78 and co.z > 1.2) else None)
        parts.append(r)
    join(parts, "Cliff")


def cliff_a():
    cliff(81)


def cliff_b():
    cliff(82)


# ------------------------------------------------------------------ тропические цветы (проходимые)
def flower_patch():
    rr = rnd(91)
    parts = []
    for k in range(6):  # гибискус
        a = rr.uniform(0, 2 * math.pi)
        r = rr.uniform(0.1, 0.5)
        x, y = math.cos(a) * r, math.sin(a) * r
        h = rr.uniform(0.25, 0.5)
        st = tube("st", [(x, y, 0), (x, y, h)], 0.012, 5)
        paint(st, OLIVE, ao=0.0)
        parts.append(st)
        c = [hexcol("e8445a"), hexcol("ff8a3d"), hexcol("ffd84a"), hexcol("f7a8d8")][k % 4]
        for q in range(5):
            pa = 2 * math.pi * q / 5
            lf = leaf("pt", (x, y, h), (math.cos(pa), math.sin(pa), 0.5), 0.09, 0.05, droop=0.1, segs=3, fold=0.3)
            paint(lf, c, ao=0.0, noise_amt=0)
            parts.append(lf)
        ctr = sphere("ct", (x, y, h + 0.02), 0.02, segs=8, rings=5)
        paint(ctr, hexcol("ffe27a"), ao=0.0)
        parts.append(ctr)
        for q in range(2):
            lf = leaf("fp_leaf", (x, y, h * 0.4), (math.cos(a + q * 3), math.sin(a + q * 3), 0.3), 0.18, 0.06, droop=0.3)
            paint(lf, JG2, ao=0.0)
            parts.append(lf)
    join(parts, "Flowers_leaf")


# ------------------------------------------------------------------ сюжетные места
def old_camp():
    """Заросший лагерь Лёвы: рухнувшая палатка, остывший очаг, разбитый ящик, пюпитр с журналом."""
    parts = []
    for i, (x, y) in enumerate(((-0.8, -0.6), (0.9, -0.6))):
        parts.append(log("op", (x, y, 0), (x * 0.3, y + 0.2, 1.1), 0.05, rings=False))
    import bmesh
    from kit import from_bm, solidify
    bm = bmesh.new()
    vs = []
    for i in range(7):
        row = []
        for j in range(5):
            x = -1.2 + 2.4 * i / 6
            y = -1.0 + 2.0 * j / 4
            z = 0.9 * math.sin(math.pi * i / 6) * (0.7 + 0.3 * math.cos(j)) - 0.2 * (j / 4)
            row.append(bm.verts.new((x, y, max(0.05, z))))
        vs.append(row)
    for i in range(6):
        for j in range(4):
            bm.faces.new((vs[i][j], vs[i + 1][j], vs[i + 1][j + 1], vs[i][j + 1]))
    cl = from_bm("cloth", bm)
    solidify(cl, 0.03)
    subsurf(cl, 1)
    # рухнувшая палатка: зелёная плесень и мох пятнами по шуму (не полосами)
    from mathutils import noise as _nz
    paint(cl, hexcol("c9bfa0"), ao=0.3, ao_h=0.4, noise_amt=0.15, nscale=6, mat="canvas",
          fn=lambda co, n: hexcol("6f8a4a") if _nz.noise(co * 2.4) + 0.35 * _nz.noise(co * 7.0) > 0.25 else None)
    parts.append(cl)
    for k in range(7):
        a = 2 * math.pi * k / 7
        parts.append(stone("fs", (2.0 + math.cos(a) * 0.45, 0.6 + math.sin(a) * 0.45, 0.06), 0.13, k, hexcol("8a8f94")))
    for k in range(3):
        parts.append(plank("cr", (-1.6 + k * 0.25, 1.3, 0.12 + (k % 2) * 0.1), (0.9, 0.2, 0.06), (0.3 * k, 0, 0.4 * k), col=hexcol("9a7046")))
    stand = log("sd", (1.5, -1.6, 0), (1.5, -1.6, 0.9), 0.05, rings=False)
    book = box("bk", (1.5, -1.6, 0.95), (0.4, 0.3, 0.06), (0.4, 0, 0.2), bev=0.02)
    paint(book, hexcol("8a3a2a"), ao=0.0, fn=lambda co, n: hexcol("f2e2b8") if n.z > 0.6 else None, mat="plain")
    parts += [stand, book]
    join(parts, "OldCamp")


def lifeboat():
    """Шлюпка «Альбатроса», вытащенная на камни. На борту — название."""
    parts = []
    wood = hexcol("7f9fb8")
    hull = lathe("hl", [(0.0, 0.0), (0.45, 0.05), (0.62, 0.3), (0.66, 0.55)], 20, scale=(1, 2.6, 1))
    from kit import solidify
    solidify(hull, 0.05)
    paint(hull, wood, ao=0.3, ao_h=0.3, noise_amt=0.1, nscale=6,
          fn=lambda co, n: hexcol("f2ead3") if 0.38 < co.z < 0.48 else (0.85 if int(co.z * 20) % 2 else None))
    parts.append(hull)
    for y in (-0.6, 0.0, 0.6):
        parts.append(plank("bn", (0, y, 0.35), (1.1, 0.18, 0.05), col=hexcol("b8834b")))
    oar = log("oar", (-0.9, -1.5, 0.05), (0.6, 1.2, 0.08), 0.03, col=hexcol("b8834b"), rings=False)
    blade = box("bl", (0.65, 1.3, 0.08), (0.14, 0.35, 0.02), (0, 0, -0.5), bev=0.01)
    paint(blade, hexcol("b8834b"), ao=0.0, mat="wood")
    parts += [oar, blade]
    for k in range(4):
        parts.append(stone("ls", (-0.9 + k * 0.6, 1.8 - k * 0.3, 0.1), 0.25, k))
    b = join(parts, "Lifeboat")
    b.rotation_euler = (0.12, 0.08, 0.3)


def lighthouse_ruin():
    """Древний маяк из чёрного камня. Bowl — чаша, в которой игра зажигает огонь."""
    parts = []
    dark = hexcol("5c5866")
    tower = lathe("tw", [(1.5, 0.0), (1.45, 0.4), (1.25, 2.5), (1.1, 4.6), (1.2, 4.8), (1.2, 5.0), (0.0, 5.0)], 16)
    displace(tower, 0.08, 0.5, "VORONOI")
    paint(tower, dark, ao=0.3, ao_h=1.2, noise_amt=0.12, nscale=3, mat="ashlar",
          fn=lambda co, n: hexcol("5f8a4a") if (n.z > 0.7 and co.z < 0.5) else (0.75 if (co.z * 2.2) % 1.0 < 0.07 else None))
    parts.append(tower)
    door = box("dr", (0, -1.32, 0.8), (0.7, 0.3, 1.5), bev=0.05)
    paint(door, hexcol("1a1820"), ao=0.0)
    parts.append(door)
    for k in range(8):   # зубцы и разрушенный край
        a = 2 * math.pi * k / 8
        if k in (2, 5):
            continue
        z = box("cr", (math.cos(a) * 1.1, math.sin(a) * 1.1, 5.25), (0.45, 0.35, 0.5), (0, 0, a), bev=0.04)
        paint(z, shade(dark, 1.1), ao=0.0, noise_amt=0.1, mat="ashlar")
        parts.append(z)
    for k in range(6):
        a = 2 * math.pi * k / 6 + 0.3
        parts.append(stone("rb", (math.cos(a) * 2.0, math.sin(a) * 2.0, 0.15), 0.35, k, shade(dark, 1.15)))
    vine = tube("vn", [(1.25, 0.3, 0.0), (1.2, 0.5, 1.5), (1.05, 0.2, 3.2), (1.0, -0.3, 4.4)], 0.05, 6)
    paint(vine, hexcol("4f7a3a"), ao=0.0, mat="bark")
    parts.append(vine)
    t = join(parts, "Lighthouse")
    bowl = lathe("bw", [(0.0, 5.0), (0.5, 5.05), (0.7, 5.4), (0.62, 5.45), (0.0, 5.2)], 18)
    paint(bowl, hexcol("6b5a3a"), ao=0.0, fn=lambda co, n: hexcol("5a4a42") if n.z > 0.5 else None, mat="iron")
    bowl.name = "Bowl"
    set_parent(bowl, t)
    empty("FirePoint", (0, 0, 5.5), t)


BUILDERS = {"jungle_tree_a": jungle_tree_a, "jungle_tree_b": jungle_tree_b, "fern_a": fern_a, "fern_b": fern_b,
            "tall_grass": tall_grass, "thicket": thicket, "bamboo_clump": bamboo_clump, "fallen_log": fallen_log, "fallen_log_b": fallen_log_b,
            "cliff_a": cliff_a, "cliff_b": cliff_b, "flower_patch": flower_patch,
            "old_camp": old_camp, "lifeboat": lifeboat, "lighthouse_ruin": lighthouse_ruin}
