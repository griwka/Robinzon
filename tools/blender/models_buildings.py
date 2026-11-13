"""Постройки, декор и предметы. Размеры совпадают с коллизиями в игре.
Перевод координат: Godot (x, y, z) = Blender (x, −y... ) — точнее, Blender (x, y, z) → Godot (x, z, −y).
Значит «вперёд в Godot» (+Z) — это −Y в Blender."""
import math

from mathutils import Vector

from kit import (box, cyl, displace, empty, hexcol, ico, join, lathe, leaf, mix, paint, rnd, set_origin, set_parent,
                 shade, sphere, subsurf, tube)

WOOD = hexcol("b8834b")
WOOD_D = hexcol("8a5a32")
PLANK = hexcol("c99a5e")
ROPE = hexcol("d4b483")
STRAW = hexcol("d6ad55")
BAMBOO = hexcol("e0c06a")
STONE = hexcol("a3a8ad")
CLOTH = hexcol("f2ead3")
BLUE = hexcol("4f8fd8")


def grain(base):
    """Узор древесных волокон — теперь его рисует запекание (texbake: вид "wood"), здесь ничего не меняем."""
    return None


def boards(per_m, axis=2, seam=0.07):
    """Обшивка досками на ящике или стене: тёмный шов между досками, доски чуть разного тона.
    per_m — досок на метр вдоль оси axis (2 — вагонка по высоте). Волокна рисует запекание ("wood")."""
    def f(co, n):
        if abs(n[axis]) > 0.8:
            return None   # торцы досок — сверху и снизу
        t = co[axis] * per_m
        fr = t - math.floor(t)
        if fr < seam:
            return 0.6
        if fr < seam * 2.2:
            return 1.08   # светлая кромка над швом
        return (0.9, 1.0, 0.95, 1.04)[int(math.floor(t)) % 4]
    return f


def masonry(base, course=0.17, block=0.34, mortar=None, around=None, seed=0):
    """Кладка из камней или кирпичей: ряды высотой course, камни длиной block со смещением через ряд,
    светлые швы раствора, у каждого камня свой тон. around=(x, y) — кольцевая кладка вокруг оси (колодец):
    длина считается по дуге. Даёт fn(co, n) для paint."""
    mort = mortar or mix(base, hexcol("e8e0d0"), 0.55)
    from mathutils import noise as _nz

    def f(co, n):
        if abs(n.z) > 0.85 and around is None:
            return None
        row = math.floor(co.z / course)
        fz = co.z / course - row
        if around is not None:
            u = math.atan2(co.y - around[1], co.x - around[0]) * math.hypot(co.x - around[0], co.y - around[1])
        else:
            u = co.x if abs(n.x) < abs(n.y) else co.y
        u = u / block + 0.5 * (row % 2) + 0.12 * _nz.noise((co.x * 3.0, co.y * 3.0, row + seed))
        fu = u - math.floor(u)
        w = 0.07
        if fz < w or fz > 1 - w * 0.5 or fu < w * 0.6:
            return mort
        k = 0.88 + 0.2 * (_nz.noise((math.floor(u) * 1.7 + seed, row * 2.3, 0.5)) * 0.5 + 0.5)
        if fz < w * 2.2:
            k *= 0.86   # тень под камнем верхнего ряда
        return shade(base, k)
    return f


def plank(name, loc, size, rot=(0, 0, 0), col=PLANK, seed=0):
    """Доска: скруглённые рёбра, волокна вдоль длинной стороны, светлые торцы, у каждой доски свой тон."""
    p = box(name, loc, size, rot, bev=min(size) * 0.25, seg=2)
    long_ax = max(range(3), key=lambda i: size[i])
    tone = shade(col, 0.9 + 0.14 * ((seed * 37 + int(loc[0] * 13 + loc[1] * 7)) % 10) / 10)
    from mathutils import Euler
    rmat = Euler(rot).to_matrix()
    ax = rmat @ Vector([1.0 if i == long_ax else 0.0 for i in range(3)])
    c0 = Vector(loc)

    def f(co, n):
        if abs(n.dot(ax)) > 0.85:
            return shade(tone, 1.18)   # торец — светлее
        return None                     # волокна, кольца и сучки рисует запекание (texbake: "wood")
    paint(p, tone, ao=0.25, ao_h=0.3, noise_amt=0.07, nscale=9, fn=f, mat="wood")
    return p


def log(name, a, b, r, col=WOOD_D, rings=True):
    """Бревно или жердь: кора с продольными бороздами; торцы (rings=True) — светлый скол с годовыми кольцами."""
    from kit import bark_fn, wood_cap
    a, b = Vector(a), Vector(b)
    d = (b - a).normalized()
    segs = 12 if r > 0.035 else 8
    t = tube(name, [tuple(a), tuple(b)], [r, r * 0.95], segs, caps=not rings)
    paint(t, col, ao=0.25, ao_h=0.3, noise_amt=0.08, nscale=10, fn=bark_fn(tuple(a), tuple(d), col=col, seed=int(r * 1000) % 17),
          mat="bark")
    if not rings:
        return t
    o1 = d.orthogonal().normalized()
    o2 = d.cross(o1)
    parts = [t]
    for end, axis, rr_ in ((a, -d, r), (b, d, r * 0.95)):
        rim = [end + (o1 * math.cos(2 * math.pi * k / segs) + o2 * math.sin(2 * math.pi * k / segs)) * rr_ for k in range(segs)]
        # кольцо вершин торца должно совпасть с трубкой: у tube первая вершина — по своей нормали; торец рисуем чуть шире
        rim = [end + (q - end) * 1.02 for q in rim]
        parts.append(wood_cap(name + "_c", rim, end + axis * 0.004, axis, rr_, seed=int((end.x + end.y) * 100) % 50, depth=0.006, rough=0.004))
    return join(parts, name)


def rope_wrap(name, center, r, z0, turns=3, axis="z"):
    pts = []
    for i in range(turns * 12 + 1):
        a = 2 * math.pi * i / 12
        z = z0 + i * 0.006
        pts.append((center[0] + math.cos(a) * r, center[1] + math.sin(a) * r, z))
    t = tube(name, pts, 0.018, 6, caps=False)
    paint(t, ROPE, ao=0.0, noise_amt=0.08, mat="rope")
    return t


def stone(name, loc, r, seed, col=STONE):
    s = ico(name, loc, r, (1.15, 1.0, 0.75), (0, 0, seed), sub=2)
    displace(s, 0.3 * r, 0.8 * r, "VORONOI")
    subsurf(s, 1)
    paint(s, shade(col, 0.9 + 0.15 * (seed % 3) / 2), ao=0.3, ao_h=r, noise_amt=0.1, nscale=4 / r, mat="stone")
    return s


# ------------------------------------------------------------------ палатка из паруса
def tent():
    parts = []
    for sx in (-1, 1):
        # провисающее полотно: сетка с прогибом
        import bmesh
        from kit import from_bm
        bm = bmesh.new()
        nu, nv = 10, 6
        vs = []
        for i in range(nu + 1):
            row = []
            for j in range(nv + 1):
                y = -1.15 + 2.3 * i / nu
                t = j / nv
                x = sx * (0.05 + t * 0.82)
                z = 1.42 - t * 1.38 - math.sin(math.pi * i / nu) * math.sin(math.pi * t) * 0.07
                row.append(bm.verts.new((x, y, z)))
            vs.append(row)
        for i in range(nu):
            for j in range(nv):
                q = (vs[i][j], vs[i + 1][j], vs[i + 1][j + 1], vs[i][j + 1])
                bm.faces.new(q if sx > 0 else q[::-1])
        cl = from_bm("cloth", bm)
        from kit import solidify
        solidify(cl, 0.03)
        subsurf(cl, 1)

        def pat(co, n, sx=sx):
            if 0.38 < abs(co.x) < 0.5:
                return BLUE
            if -0.6 < co.y < -0.25 and 0.55 < abs(co.x) < 0.75:
                return hexcol("e8b45a")  # заплатка
            return 0.9 if int((co.y + 2) * 9) % 2 == 0 else None
        paint(cl, CLOTH, ao=0.25, ao_h=0.5, noise_amt=0.05, fn=pat)
        parts.append(cl)
    for y in (-1.18, 1.18):
        for sx in (-1, 1):
            parts.append(log("pole", (sx * 0.8, y, 0.0), (0, y, 1.5), 0.04, rings=False))
    parts.append(log("ridge", (0, -1.35, 1.46), (0, 1.35, 1.46), 0.035, rings=False))
    for sx in (-1, 1):
        for y in (-1.3, 1.3):
            r = tube("guy", [(sx * 0.1, y, 1.45), (sx * 1.2, y * 1.25, 0.02)], 0.01, 5)
            paint(r, ROPE, ao=0.0)
            peg = cyl("peg", (sx * 1.2, y * 1.25, -0.05), 0.03, 0.02, 0.18, segs=6)
            paint(peg, WOOD_D, ao=0.0)
            parts += [r, peg]
    mat = box("mat", (0, 0, 0.02), (1.3, 1.9, 0.04), bev=0.02)
    paint(mat, hexcol("c9a050"), ao=0.0, fn=lambda co, n: 0.85 if int(co.y * 14) % 2 == 0 else None, mat="straw")
    parts.append(mat)
    join(parts, "Tent")


# ------------------------------------------------------------------ костёр (огонь добавляет игра)
def campfire():
    parts = []
    for i in range(10):
        a = 2 * math.pi * i / 10
        parts.append(stone("st", (math.cos(a) * 0.6, math.sin(a) * 0.6, 0.08), 0.15, i))
    ash = cyl("ash", (0, 0, 0.0), 0.5, 0.48, 0.05, segs=20)
    paint(ash, hexcol("5a4a42"), ao=0.0, noise_amt=0.2, nscale=12)
    parts.append(ash)
    for i in range(5):
        a = 2 * math.pi * i / 5 + 0.3
        parts.append(log("lg", (math.cos(a) * 0.45, math.sin(a) * 0.45, 0.04), (math.cos(a) * 0.05, math.sin(a) * 0.05, 0.55), 0.06))
    for i in range(5):
        a = 2 * math.pi * i / 5 + 0.9
        e = sphere("em", (math.cos(a) * 0.2, math.sin(a) * 0.2, 0.06), 0.07, (1, 1, 0.5), segs=8, rings=5)
        paint(e, hexcol("ff7a2a"), ao=0.0, noise_amt=0.3, nscale=20, mat="plain")
        parts.append(e)
    join(parts, "Campfire")


def torch():
    parts = [log("tp", (0, 0, 0), (0, 0, 1.6), 0.055, rings=False)]
    bowl = lathe("tb", [(0.06, 1.5), (0.16, 1.6), (0.18, 1.72), (0.0, 1.72)], 12)
    paint(bowl, hexcol("4a3b30"), ao=0.0, fn=lambda co, n: 0.8 if int(co.z * 50) % 2 else None, mat="iron")
    parts.append(bowl)
    parts.append(rope_wrap("tr", (0, 0), 0.06, 1.3, 3))
    join(parts, "Torch")


# ------------------------------------------------------------------ верстак
def workbench():
    parts = [plank("top%d" % i, (0, -0.28 + i * 0.19, 0.86), (1.85, 0.18, 0.08), seed=i) for i in range(4)]
    for x in (-0.78, 0.78):
        for y in (-0.3, 0.3):
            parts.append(plank("leg", (x, y, 0.42), (0.11, 0.11, 0.84), col=WOOD_D))
    parts.append(plank("bar", (0, 0.3, 0.22), (1.5, 0.07, 0.07), col=WOOD_D))
    parts.append(plank("bar2", (0, -0.3, 0.22), (1.5, 0.07, 0.07), col=WOOD_D))
    parts.append(plank("shelf", (0, 0, 0.24), (1.5, 0.55, 0.04), col=WOOD))
    # тиски, пила, молоток, стружка, ведро
    vise = box("vise", (-0.7, -0.38, 0.95), (0.2, 0.12, 0.14), bev=0.02)
    paint(vise, hexcol("8f9499"), ao=0.0)
    saw = box("saw", (0.25, 0.0, 0.92), (0.55, 0.14, 0.01), (0, 0, 0.25))
    paint(saw, hexcol("c9cfd6"), ao=0.0, fn=lambda co, n: 0.7 if co.y < -0.04 else None)
    handle = box("sh", (0.0, -0.07, 0.93), (0.12, 0.08, 0.03), (0, 0, 0.25), bev=0.01)
    paint(handle, hexcol("a04a2a"), ao=0.0)
    hammer = log("hm", (-0.3, 0.15, 0.92), (-0.05, 0.25, 0.92), 0.018, rings=False)
    hh = box("hh", (-0.32, 0.14, 0.93), (0.05, 0.12, 0.05), bev=0.01)
    paint(hh, hexcol("6b6f75"), ao=0.0)
    parts += [vise, saw, handle, hammer, hh]
    for i in range(6):
        sh = sphere("chip", (0.5 + i * 0.06, -0.2 + (i % 3) * 0.08, 0.91), 0.035, (1.4, 0.6, 0.3), segs=8, rings=5)
        paint(sh, hexcol("ecc58a"), ao=0.0)
        parts.append(sh)
    bucket = lathe("bk", [(0.0, 0.0), (0.13, 0.0), (0.16, 0.25), (0.0, 0.25)], 14, loc=(0.55, 0.55, 0))
    paint(bucket, WOOD, ao=0.2, fn=lambda co, n: hexcol("8f9499") if (0.04 < co.z < 0.07 or 0.18 < co.z < 0.21) else None)
    parts.append(bucket)
    join(parts, "Workbench")


# ------------------------------------------------------------------ бамбуковая хижина
def bamboo(name, a, b, r):
    t = tube(name, [a, b], r, 10)
    ln = (Vector(b) - Vector(a)).length

    def f(co, n):
        k = ((co - Vector(a)).dot((Vector(b) - Vector(a)).normalized()) / 0.42) % 1.0
        return 0.75 if k < 0.07 else (1.08 if k < 0.2 else None)
    paint(t, BAMBOO, ao=0.25, ao_h=0.4, noise_amt=0.06, fn=f, mat="bamboo")
    return t


def thatch_cone(name, z, r_bottom, h, sides=4, rot=math.pi / 4):
    """Соломенная крыша: несколько ярусов снопов внахлёст, у каждого — неровная «бахрома» снизу,
    полосы соломинок и чуть разный тон. sides=4 — четырёхскатная, больше — круглая."""
    import bmesh
    from kit import from_bm
    rng = rnd(int(r_bottom * 100 + z * 10))
    courses = 4
    segs = sides * 12 if sides <= 6 else 40
    parts = []

    def rad_at(a, r):
        if sides > 6:
            return r
        # «квадратный» обвод: радиус до стороны многоугольника
        k = math.pi / sides
        da = ((a - rot) % (2 * k)) - k
        return r * math.cos(k) / math.cos(da)
    for c in range(courses):
        t0 = c / courses
        t1 = min(1.0, (c + 1.35) / courses)
        r0 = r_bottom * (1 - t0) + 0.05 * t0
        r1 = r_bottom * (1 - t1) + 0.05 * t1
        bm = bmesh.new()
        bot, top = [], []
        for k in range(segs):
            a = 2 * math.pi * k / segs
            fringe = (0.07 if k % 2 else 0.0) + rng.uniform(0, 0.04)
            rb = rad_at(a, r0) + 0.05
            bot.append(bm.verts.new((math.cos(a) * rb, math.sin(a) * rb, z + h * t0 - fringe)))
            rt = rad_at(a, r1)
            top.append(bm.verts.new((math.cos(a) * rt, math.sin(a) * rt, z + h * t1)))
        for k in range(segs):
            bm.faces.new((bot[k], bot[(k + 1) % segs], top[(k + 1) % segs], top[k]))
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        ob = from_bm(name + "_c%d" % c, bm)
        from kit import solidify
        solidify(ob, 0.06)
        tone = shade(STRAW, 0.92 + 0.12 * (c % 2))
        paint(ob, tone, ao=0.0, noise_amt=0.12, nscale=16,
              fn=lambda co, n, tone=tone: shade(tone, 0.84) if math.sin(math.atan2(co.y, co.x) * 70 + co.z * 9) > 0.55 else (
                  shade(tone, 1.12) if n.z > 0.6 else None), mat="straw")
        parts.append(ob)
    return join(parts, name)


def hut():
    parts = [plank("floor%d" % i, (0, -1.6 + i * 0.4, 0.12), (3.5, 0.38, 0.12), seed=i) for i in range(9)]
    for x in (-1.6, 1.6):
        for y in (-1.6, 1.6):
            parts.append(log("post", (x, y, 0), (x, y, 2.4), 0.1, rings=False))
    for side in range(4):
        a = side * math.pi / 2
        d = Vector((math.sin(a), -math.cos(a), 0))   # side 0 — дверь (вперёд в Godot)
        right = Vector((math.cos(a), math.sin(a), 0))
        for i in range(9):
            t = (i - 4) * 0.36
            p = d * 1.55 + right * t
            if side == 0 and abs(t) < 0.5:
                continue
            top = 2.15
            if side == 1 and abs(t) < 0.4:
                top = 0.95   # окно
            parts.append(bamboo("bw", (p.x, p.y, 0.15), (p.x, p.y, top), 0.085))
        tie = tube("tie", [tuple(d * 1.56 + right * -1.6 + Vector((0, 0, 1.75))), tuple(d * 1.56 + right * 1.6 + Vector((0, 0, 1.75)))], 0.03, 6)
        paint(tie, ROPE, ao=0.0)
        parts.append(tie)
    # дверной проём и окно — рамки
    parts.append(log("lintel", (-0.55, -1.6, 2.0), (0.55, -1.6, 2.0), 0.06, rings=False))
    parts.append(log("sill", (1.6, -0.45, 0.98), (1.6, 0.45, 0.98), 0.05, rings=False))
    # многоярусная соломенная крыша с бахромой
    parts += [thatch_cone("r1", 2.1, 2.85, 1.55), thatch_cone("r2", 2.55, 2.25, 1.3), thatch_cone("r3", 3.2, 1.1, 0.8)]
    ridge = sphere("knob", (0, 0, 4.0), 0.14, (1, 1, 0.8))
    paint(ridge, hexcol("a87b3a"), ao=0.0)
    parts.append(ridge)
    # крыльцо-ступенька и горшок
    parts.append(plank("step", (0, -1.95, 0.08), (1.0, 0.45, 0.12)))
    pot = lathe("pot", [(0.0, 0.0), (0.13, 0.0), (0.18, 0.22), (0.0, 0.22)], 14, loc=(0.8, -2.0, 0))
    paint(pot, hexcol("d9774a"), ao=0.0)
    parts.append(pot)
    for k in range(5):
        a = k * 1.25
        lf = leaf("pl_leaf", (0.8, -2.0, 0.2), (math.cos(a), math.sin(a), 1.0), 0.3, 0.07, droop=0.4)
        paint(lf, hexcol("3fae49"), ao=0.0)
        parts.append(lf)
    join(parts, "Hut")


# ------------------------------------------------------------------ курятник
def coop():
    parts = []
    for x in (-0.55, 0.55):
        for y in (-0.45, 0.45):
            parts.append(plank("st", (x, y, 0.3), (0.1, 0.1, 0.6), col=WOOD_D))
    for i in range(5):
        parts.append(plank("wl", (0, 0, 0.7 + i * 0.16), (1.3, 1.1, 0.15), seed=i, col=hexcol("c08a50")))
    door = box("dr", (0, 0.56, 0.9), (0.32, 0.04, 0.36), bev=0.02)
    paint(door, hexcol("3a2a1a"), ao=0.0)
    parts.append(door)
    parts.append(thatch_cone("rf", 1.5, 1.2, 0.75))
    # пандус с перекладинами (вперёд в Godot = −Y в Blender — к игроку)
    ramp = plank("ramp", (0, 0.95, 0.33), (0.32, 0.9, 0.04), (0.72, 0, 0))
    parts.append(ramp)
    for k in range(4):
        parts.append(plank("rs", (0, 0.68 + k * 0.17, 0.53 - k * 0.15), (0.3, 0.03, 0.03), col=WOOD_D))
    nest = lathe("ns", [(0.0, 0.0), (0.22, 0.0), (0.25, 0.12), (0.18, 0.1), (0.0, 0.06)], 14, loc=(-0.9, -0.2, 0))
    paint(nest, STRAW, ao=0.0, noise_amt=0.2, nscale=25)
    parts.append(nest)
    for i in range(14):
        a = 2 * math.pi * i / 14
        if abs(a - math.pi / 2) < 0.4:
            continue
        parts.append(log("fp", (math.cos(a) * 1.5, math.sin(a) * 1.5, 0), (math.cos(a) * 1.5, math.sin(a) * 1.5, 0.5), 0.045, rings=False))
    join(parts, "Coop")


# ------------------------------------------------------------------ загон для коз
def goat_pen():
    parts = []
    s = 1.9
    for side in range(4):
        a = side * math.pi / 2
        d = Vector((math.sin(a), -math.cos(a), 0))
        right = Vector((math.cos(a), math.sin(a), 0))
        for k in range(5):
            p = d * s + right * (k - 2) * s * 0.5
            parts.append(log("pp", (p.x, p.y, 0), (p.x, p.y, 0.95), 0.06, rings=False))
        for z in (0.38, 0.75):
            if side == 0 and z < 0.5:
                continue
            a0 = d * s - right * s
            a1 = d * s + right * s
            parts.append(log("rail", (a0.x, a0.y, z), (a1.x, a1.y, z), 0.04, col=WOOD, rings=False))
    # навес из пальмовых листьев
    for x in (-1.5, -0.3):
        for y in (0.5, 1.3):
            parts.append(log("np", (x, y, 0), (x, y, 1.25 + (0.1 if y > 1 else 0)), 0.045, rings=False))
    for k in range(6):
        lf = leaf("roof_leaf", (-1.6 + k * 0.25, 1.4, 1.42), (0.1, -1, -0.25), 1.1, 0.16, droop=0.15, fold=0.1)
        paint(lf, hexcol("5fb04a"), ao=0.0, noise_amt=0.1)
        parts.append(lf)
    # кормушка с сеном
    tr = box("tr", (0.9, 1.3, 0.18), (0.9, 0.35, 0.25), bev=0.03)
    paint(tr, WOOD, ao=0.2, mat="wood")
    hay = box("hay", (0.9, 1.3, 0.32), (0.8, 0.25, 0.08), bev=0.03)
    displace(hay, 0.04, 0.05)
    paint(hay, hexcol("d9c45a"), ao=0.0, noise_amt=0.25, nscale=30)
    parts += [tr, hay]
    join(parts, "GoatPen")


# ------------------------------------------------------------------ плот
def raft():
    parts = []
    for i in range(6):
        x = (i - 2.5) * 0.36
        parts.append(log("rl", (x, -1.5, 0.15), (x, 1.5, 0.15), 0.17))
    for y in (-1.1, 1.1):
        parts.append(plank("cb", (0, y, 0.33), (2.3, 0.2, 0.08), col=ROPE))
        for i in range(6):
            parts.append(rope_wrap("rw", ((i - 2.5) * 0.36, y), 0.19, 0.08, 1))
    mast = log("mast", (0, 0, 0.3), (0, 0, 2.9), 0.06, rings=False)
    boom = log("boom", (0, 0, 1.15), (0, -0.1, 1.15), 0.04, rings=False)
    parts += [mast, boom]
    base = join(parts, "Raft")
    import bmesh
    from kit import from_bm, solidify
    bm = bmesh.new()
    vs = []
    for i in range(5):
        row = []
        for j in range(5):
            x = -0.8 + 1.6 * i / 4
            z = 1.2 + 1.5 * j / 4
            y = -0.06 - math.sin(math.pi * i / 4) * math.sin(math.pi * j / 4) * 0.25
            row.append(bm.verts.new((x, y, z)))
        vs.append(row)
    for i in range(4):
        for j in range(4):
            bm.faces.new((vs[i][j], vs[i + 1][j], vs[i + 1][j + 1], vs[i][j + 1]))
    sail = from_bm("Sail", bm)
    solidify(sail, 0.02)
    subsurf(sail, 1)
    paint(sail, CLOTH, ao=0.0, fn=lambda co, n: BLUE if 2.05 < co.z < 2.25 else None)
    sail.name = "Sail"
    set_parent(sail, base)


# ------------------------------------------------------------------ декор
def fence():
    parts = [log("fp", (x, 0, 0), (x, 0, 0.8), 0.055, rings=False) for x in (-0.6, 0.6)]
    for z in (0.3, 0.5, 0.68):
        t = tube("wv", [(-0.62, 0.0, z), (-0.2, 0.04, z + 0.02), (0.2, -0.04, z - 0.02), (0.62, 0.0, z)], 0.028, 6)
        paint(t, hexcol("c9a467"), ao=0.0, noise_amt=0.1)
        parts.append(t)
    join(parts, "Fence")


def flowerbed():
    parts = [stone("fs", (math.cos(a) * 0.5, math.sin(a) * 0.5, 0.06), 0.12, i) for i, a in enumerate([k * math.pi / 5 for k in range(10)])]
    soil = cyl("so", (0, 0, 0.0), 0.46, 0.44, 0.1, segs=20)
    paint(soil, hexcol("6a4028"), ao=0.0, noise_amt=0.2, nscale=15)
    parts.append(soil)
    pal = [hexcol("ff6fa5"), hexcol("ffd84a"), hexcol("ffffff"), hexcol("b28cff"), hexcol("ff8a3d")]
    rr = rnd(3)
    for i in range(11):
        a = rr.uniform(0, 2 * math.pi)
        r = rr.uniform(0, 0.32)
        x, y = math.cos(a) * r, math.sin(a) * r
        h = rr.uniform(0.25, 0.45)
        st = tube("fl", [(x, y, 0.08), (x, y, h)], 0.012, 5)
        paint(st, hexcol("3fae49"), ao=0.0)
        parts.append(st)
        c = pal[i % len(pal)]
        for k in range(5):
            pa = 2 * math.pi * k / 5
            pe = sphere("pt", (x + math.cos(pa) * 0.04, y + math.sin(pa) * 0.04, h + 0.01), 0.035, (1, 1, 0.45), segs=8, rings=5)
            paint(pe, c, ao=0.0, noise_amt=0)
            parts.append(pe)
        ctr = sphere("pc", (x, y, h + 0.03), 0.02, segs=8, rings=5)
        paint(ctr, hexcol("ffb02e"), ao=0.0, noise_amt=0)
        parts.append(ctr)
    join(parts, "Flowerbed")


def bench():
    parts = [plank("seat%d" % i, (0, -0.12 + i * 0.2, 0.46), (1.4, 0.18, 0.06), seed=i) for i in range(2)]
    parts.append(plank("back", (0, 0.27, 0.78), (1.4, 0.06, 0.28), (-0.15, 0, 0)))
    for x in (-0.6, 0.6):
        parts.append(plank("lg", (x, 0, 0.22), (0.08, 0.42, 0.44), col=WOOD_D))
        parts.append(plank("bk", (x, 0.27, 0.6), (0.07, 0.06, 0.4), col=WOOD_D))
    join(parts, "Bench")


def hammock():
    parts = [log("hp", (x, 0, 0), (x, 0, 1.6), 0.08, rings=False) for x in (-1.25, 1.25)]
    import bmesh
    from kit import from_bm, solidify
    bm = bmesh.new()
    vs = []
    for i in range(13):
        row = []
        t = (i - 6) / 6
        for j in range(5):
            y = -0.42 + 0.84 * j / 4
            z = 0.55 + t * t * 0.55 - math.sin(math.pi * j / 4) * 0.08
            row.append(bm.verts.new((t * 1.05, y * (0.6 + 0.4 * (1 - abs(t))), z)))
        vs.append(row)
    for i in range(12):
        for j in range(4):
            bm.faces.new((vs[i][j], vs[i + 1][j], vs[i + 1][j + 1], vs[i][j + 1]))
    net = from_bm("hm", bm)
    solidify(net, 0.025)
    subsurf(net, 1)
    paint(net, hexcol("e8443a"), ao=0.0, fn=lambda co, n: CLOTH if int((co.x + 2) * 5) % 2 == 0 else None)
    parts.append(net)
    for sx in (-1, 1):
        r = tube("hr", [(sx * 1.05, 0, 1.1), (sx * 1.2, 0, 1.35)], 0.015, 5)
        paint(r, ROPE, ao=0.0)
        parts.append(r)
    join(parts, "Hammock")


def scarecrow():
    parts = [log("sp", (0, 0, 0), (0, 0, 1.8), 0.045, rings=False), log("sa", (-0.62, 0, 1.35), (0.62, 0, 1.35), 0.04, rings=False)]
    shirt = box("sh", (0, 0, 1.2), (0.6, 0.28, 0.62), bev=0.08, seg=3)
    paint(shirt, hexcol("6f9bd1"), ao=0.0, mat="canvas",
          fn=lambda co, n: hexcol("e8b45a") if (0.05 < co.x < 0.22 and 0.98 < co.z < 1.15) else (0.85 if int(co.z * 20) % 3 == 0 else None))
    parts.append(shirt)
    for sx in (-1, 1):
        sl = tube("sl", [(sx * 0.28, 0, 1.35), (sx * 0.55, 0, 1.33)], [0.09, 0.08], 10)
        paint(sl, hexcol("6f9bd1"), ao=0.0, mat="canvas")
        straw = cyl("ss", (sx * 0.55, 0, 1.33), 0.07, 0.0, 0.2, (0, sx * math.pi / 2, 0), 8)
        paint(straw, hexcol("e8cf8a"), ao=0.0, noise_amt=0.3, nscale=40)
        parts += [sl, straw]
    head = sphere("hd", (0, 0, 1.75), 0.2, segs=16, rings=10)
    paint(head, hexcol("e8cf8a"), ao=0.0, noise_amt=0.2, nscale=30)
    hat = lathe("ht", [(0.0, 1.86), (0.4, 1.86), (0.38, 1.9), (0.16, 1.92), (0.15, 2.1), (0.0, 2.12)], 18)
    paint(hat, hexcol("c9a050"), ao=0.0, fn=lambda co, n: hexcol("a04a2a") if 1.92 < co.z < 1.97 else None)
    parts += [head, hat]
    for sx in (-1, 1):
        e = box("ey", (sx * 0.07, -0.19, 1.8), (0.06, 0.02, 0.02), (0, 0, 0.7 * sx))
        paint(e, hexcol("1d1d1d"), ao=0.0)
        parts.append(e)
    m = tube("mo", [(-0.07, -0.19, 1.68), (0, -0.2, 1.66), (0.07, -0.19, 1.68)], 0.008, 5)
    paint(m, hexcol("1d1d1d"), ao=0.0)
    parts.append(m)
    join(parts, "Scarecrow")


def shell_path():
    slab = cyl("sl", (0, 0, 0), 0.52, 0.5, 0.08, segs=16, scale=(1, 0.85, 1))
    displace(slab, 0.02, 0.1)
    paint(slab, hexcol("d9d2c4"), ao=0.0, noise_amt=0.1, nscale=8)
    parts = [slab]
    for i, (x, y, c) in enumerate(((0.22, 0.1, "f6c7c0"), (-0.2, 0.15, "ffe4b5"), (0.0, -0.22, "f7a8b8"))):
        s = lathe("sh", [(0.0, 0.07), (0.09, 0.075), (0.0, 0.13)], 10, loc=(x, y, 0))
        paint(s, hexcol(c), ao=0.0, fn=lambda co, n: 0.85 if math.sin(math.atan2(co.y - y, co.x - x) * 8) > 0.6 else None)
        parts.append(s)
    join(parts, "ShellPath")


# ------------------------------------------------------------------ ящик и обломки лодки
def supply_crate():
    parts = []
    for i in range(4):
        parts.append(plank("cs", (0, 0, 0.09 + i * 0.17), (1.0, 0.7, 0.16), seed=i, col=hexcol("b07a45")))
    for x in (-0.48, 0.48):
        parts.append(plank("cf", (x, 0, 0.36), (0.08, 0.74, 0.72), col=hexcol("8a5a32")))
    label = box("lb", (0, -0.36, 0.4), (0.55, 0.01, 0.2))
    paint(label, CLOTH, ao=0.0, fn=lambda co, n: hexcol("3a2a1a") if (0.37 < co.z < 0.43 and abs(co.x) < 0.22) else None)
    parts.append(label)
    body = join(parts, "Crate")
    lid_parts = [plank("lid%d" % i, (0, -0.26 + i * 0.26, 0.75), (1.04, 0.25, 0.08), seed=i, col=hexcol("bf8a52")) for i in range(3)]
    lid = join(lid_parts, "Lid")
    set_origin(lid, (0, 0, 0.75))
    set_parent(lid, body)


def boat_wreck():
    parts = []
    wood = hexcol("9a6a3e")
    # корпус на боку: изогнутые доски обшивки и шпангоуты
    for i in range(7):
        a = -0.9 + i * 0.3
        y0 = math.sin(a) * 0.65
        z0 = 0.55 - math.cos(a) * 0.55 + 0.1
        ln = 3.6 - abs(i - 3) * 0.3
        pts = [(-ln / 2 + k * ln / 6, y0 * (1 - 0.25 * abs(k - 3) / 3), z0 + 0.12 * abs(k - 3) / 3) for k in range(7)]
        t = tube("hb", pts, 0.08, 6)
        from kit import bevel
        paint(t, shade(wood, 0.9 + 0.1 * (i % 2)), ao=0.3, ao_h=0.4, noise_amt=0.12, nscale=8, mat="wood")
        parts.append(t)
    for k in range(5):
        x = -1.3 + k * 0.65
        rib = tube("rb", [(x, math.sin(a) * 0.65, 0.55 - math.cos(a) * 0.55 + 0.1) for a in [-1.0 + j * 0.3 for j in range(8)]], 0.05, 6)
        paint(rib, shade(wood, 0.75), ao=0.3, ao_h=0.4)
        parts.append(rib)
    keel = log("kl", (-1.9, 0, 0.12), (1.9, 0, 0.12), 0.09, col=shade(wood, 0.7))
    parts.append(keel)
    # сломанная мачта с насестом для попугая (позиция насеста — empty "Perch")
    mast = log("ms", (1.4, -0.6, 0.0), (1.55, -0.6, 2.45), 0.09, col=hexcol("7a5232"))
    yard = log("yd", (1.0, -0.6, 2.38), (2.2, -0.6, 2.4), 0.05, col=hexcol("7a5232"))
    parts += [mast, yard]
    import bmesh
    from kit import from_bm, solidify
    bm = bmesh.new()
    vs = [[bm.verts.new((1.1 + 0.25 * i, -0.62 - 0.05 * math.sin(i + j), 2.3 - 0.25 * j - (0.15 if (i + j) % 3 == 0 else 0))) for j in range(5)] for i in range(4)]
    for i in range(3):
        for j in range(4):
            bm.faces.new((vs[i][j], vs[i + 1][j], vs[i + 1][j + 1], vs[i][j + 1]))
    sail = from_bm("sl", bm)
    solidify(sail, 0.02)
    paint(sail, CLOTH, ao=0.0, fn=lambda co, n: 0.8 if (co.x * 13 + co.z * 7) % 1.0 < 0.1 else None)
    parts.append(sail)
    # надпись "ЧАЙКА" — тёмная полоса на борту
    plate = box("pl", (-0.6, -0.45, 0.62), (0.9, 0.02, 0.16), (0.45, 0, 0))
    paint(plate, hexcol("f2ead3"), ao=0.0, fn=lambda co, n: hexcol("2a3a6a") if abs(co.z - 0.62) < 0.04 else None, mat="painted")
    parts.append(plate)
    w = join(parts, "Wreck")
    empty("Perch", (1.6, -0.6, 2.45), w)


# ------------------------------------------------------------------ инструменты в руке (рукоять вниз от кисти)
def tool_axe():
    h = log("h", (0, 0, 0.1), (0, 0, -0.62), 0.03, rings=False)
    head = box("hd", (0, 0.1, -0.55), (0.07, 0.24, 0.17), bev=0.03)
    paint(head, hexcol("9aa0a6"), ao=0.0, fn=lambda co, n: 1.25 if co.y > 0.18 else None)
    wrap = rope_wrap("w", (0, 0), 0.04, -0.6, 2)
    join([h, head, wrap], "Tool")


def tool_machete():
    h = log("h", (0, 0, 0.1), (0, 0, -0.18), 0.03, col=hexcol("6b3a22"), rings=False)
    guard = box("g", (0, 0, -0.2), (0.05, 0.12, 0.03), bev=0.01)
    paint(guard, hexcol("8f9499"), ao=0.0)
    import bmesh
    from kit import from_bm, solidify
    bm = bmesh.new()
    pts = [(0, -0.03, -0.2), (0, 0.03, -0.2), (0, 0.06, -0.55), (0, 0.02, -0.72), (0, -0.04, -0.62)]
    vs = [bm.verts.new(p) for p in pts]
    bm.faces.new(vs)
    bl = from_bm("b", bm)
    solidify(bl, 0.012)
    paint(bl, hexcol("c9cfd6"), ao=0.0, fn=lambda co, n: 1.2 if co.y > 0.03 else None)
    join([h, guard, bl], "Tool")


def tool_pickaxe():
    h = log("h", (0, 0, 0.1), (0, 0, -0.65), 0.03, rings=False)
    head = tube("hd", [(0, -0.32, -0.5), (0, -0.1, -0.6), (0, 0.1, -0.6), (0, 0.32, -0.5)], [0.012, 0.04, 0.04, 0.012], 8)
    paint(head, hexcol("9a8fb0"), ao=0.0)
    join([h, head], "Tool")


def tool_watering_can():
    body = lathe("b", [(0.0, -0.32), (0.11, -0.32), (0.12, -0.1), (0.09, -0.06), (0.0, -0.06)], 16, rot=(math.pi / 2, 0, 0), loc=(0, -0.1, -0.15))
    paint(body, hexcol("5fb0e8"), ao=0.0, fn=lambda co, n: 0.85 if abs(co.z + 0.15) < 0.02 else None)
    spout = tube("s", [(0, 0.08, -0.12), (0, 0.25, -0.02), (0, 0.32, 0.03)], [0.025, 0.018, 0.03], 8)
    paint(spout, hexcol("4a90c8"), ao=0.0)
    handle = tube("h", [(0, -0.05, -0.05), (0, -0.05, 0.05), (0, -0.2, 0.05), (0, -0.25, -0.05)], 0.018, 6)
    paint(handle, hexcol("4a90c8"), ao=0.0)
    join([body, spout, handle], "Tool")


def tool_net():
    h = log("h", (0, 0, 0.1), (0, 0, -0.75), 0.022, col=hexcol("c9a467"), rings=False)
    hoop = tube("r", [(math.cos(a) * 0.14, 0, -0.9 + math.sin(a) * 0.14) for a in [k * math.pi / 8 for k in range(17)]], 0.012, 6, caps=False)
    paint(hoop, hexcol("f2d16b"), ao=0.0)
    bag = sphere("b", (0, 0.05, -0.9), 0.13, (1, 0.6, 1), segs=12, rings=8)
    paint(bag, hexcol("f2f2f2"), ao=0.0, fn=lambda co, n: 0.75 if (int(co.x * 60) + int(co.z * 60)) % 2 == 0 else None)
    join([h, hoop, bag], "Tool")


BUILDERS = {"tent": tent, "campfire": campfire, "torch": torch, "workbench": workbench, "hut": hut, "coop": coop,
            "goat_pen": goat_pen, "raft": raft, "fence": fence, "flowerbed": flowerbed, "bench": bench,
            "hammock": hammock, "scarecrow": scarecrow, "shell_path": shell_path, "supply_crate": supply_crate,
            "boat_wreck": boat_wreck}   # инструменты — в models_tools.py
