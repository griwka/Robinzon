"""Новые виды растений островов (v1.0.5). Каждый вид — своя модель, у многих два варианта (a/b).

Тропики (дом, Баньян, форт, Око): монстера, таро, имбирь, гибискус, древовидный папоротник.
Грозовой (вересковая пустошь): дрок, наперстянка. Ледяной (тундра): карликовая берёза, пушица.
Вулкан: юкка, охия (куст с красными «пушистыми» цветами). Туманный (болото): рогоз, болотная ива.
Везде, где сыро: кучки грибов. Низкая травка-клевер с одуванчиками — отдельная сетка для GrassField.
Листья и тонкие стебли — в узлах *_leaf (ветер, двусторонние). Ось Z — вверх."""
import math

from mathutils import Vector, noise

from kit import (bark_fn, cyl, displace, hexcol, ico, join, leaf, mix, paint, rnd, shade, smooth_path, sphere, subsurf,
                 tube, BARK, BARK_D, MOSS)

LEAF = hexcol("3f8f45")
LEAF_L = hexcol("5aa64a")
LEAF_D = hexcol("2f7040")


def _shape_round(t):
    return math.sin(math.pi * min(1.0, t * 0.95 + 0.05)) ** 0.7


def _shape_heart(t):
    # широкое основание, острый кончик (таро)
    return (math.sin(math.pi * min(1.0, t * 0.8 + 0.2)) ** 0.6) * (1.0 - 0.15 * t)


def _shape_lance(t):
    return (1 - t) ** 0.8 * min(1.0, t * 5 + 0.15)


def _veins(col, k=1.2):
    """Светлая средняя жилка по листу (по нормали её не найти — по положению в полосе листа)."""
    return lambda co, n: None


def _on_blobs(rr, blobs, up=-0.15):
    """Точка на поверхности одного из шаров кроны (центр, радиус, сжатие по z) и нормаль наружу."""
    c, r, sz = blobs[rr.randrange(len(blobs))]
    while True:
        d = Vector((rr.uniform(-1, 1), rr.uniform(-1, 1), rr.uniform(-1, 1)))
        if 0.2 < d.length <= 1.0 and d.normalized().z > up:
            break
    d.normalize()
    return Vector((c[0] + d.x * r, c[1] + d.y * r, c[2] + d.z * r * sz)), d


def _stem(name, pts, r, col, segs=6):
    sp, sr = smooth_path(pts, r if isinstance(r, list) else [r] * len(pts), 4)
    t = tube(name, sp, sr, segs)
    paint(t, col, ao=0.0)
    return t


# ------------------------------------------------------------------ монстера: резные листья на длинных черешках
def _monstera(seed):
    rr = rnd(seed)
    parts = []
    for k in range(rr.randint(6, 8)):
        a = 2 * math.pi * k / 7 + rr.uniform(-0.25, 0.25)
        ln = rr.uniform(0.5, 0.8)
        top = Vector((math.cos(a) * ln * 0.55, math.sin(a) * ln * 0.55, ln * 0.9))
        parts.append(_stem("ms_leaf", [(0, 0, 0), tuple(top * 0.5 + Vector((0, 0, 0.12))), tuple(top)], [0.018, 0.014, 0.01], hexcol("4f8a3a")))
        d = Vector((math.cos(a), math.sin(a), -0.15))
        # лист — две половинки с прорезями: набор долек вдоль жилки
        w = rr.uniform(0.2, 0.26)
        for side in (-1, 1):
            sd = d.cross(Vector((0, 0, 1))).normalized() * side
            for j in range(5):
                t = 0.15 + j * 0.17
                p = top + d * (t * w * 2.2)
                lobe = leaf("ms_leaf", tuple(p), tuple((sd * 1.0 + d * (0.35 - t * 0.5)).normalized()), w * (1.05 - abs(t - 0.45) * 0.9), 0.055,
                            droop=0.35, segs=4, fold=0.15, shape=_shape_round)
                c = shade(LEAF if k % 2 else LEAF_D, 0.95 + 0.1 * rr.random())
                paint(lobe, c, ao=0.0, noise_amt=0.05, fn=lambda co, n, c=c: shade(c, 1.12) if n.z > 0.75 else None)
                parts.append(lobe)
    join(parts, "Monstera_leaf")


def monstera_a():
    _monstera(201)


def monstera_b():
    _monstera(202)


# ------------------------------------------------------------------ таро («слоновьи уши»): огромные листья-сердечки
def _taro(seed):
    rr = rnd(seed)
    parts = []
    n_ = rr.randint(5, 7)
    for k in range(n_):
        a = 2 * math.pi * k / n_ + rr.uniform(-0.3, 0.3)
        h = rr.uniform(0.6, 1.0)
        top = Vector((math.cos(a) * 0.25, math.sin(a) * 0.25, h))
        parts.append(_stem("tr_leaf", [(0, 0, 0), (math.cos(a) * 0.08, math.sin(a) * 0.08, h * 0.5), tuple(top)], [0.025, 0.02, 0.012], hexcol("6a9a4a")))
        lf = leaf("tr_leaf", tuple(top - Vector((math.cos(a), math.sin(a), 0)) * 0.08), (math.cos(a), math.sin(a), -0.35), rr.uniform(0.42, 0.55), 0.22,
                  droop=0.45, segs=8, fold=0.3, shape=_shape_heart)
        c = shade(hexcol("4a9a4a"), 0.92 + 0.12 * rr.random())
        paint(lf, c, ao=0.0, noise_amt=0.05, nscale=10)   # жилки и блик — texbake по координатам листа
        parts.append(lf)
    join(parts, "Taro_leaf")


def taro_a():
    _taro(211)


def taro_b():
    _taro(212)


# ------------------------------------------------------------------ имбирь: стебли-трости с узкими листьями и алым цветком-факелом
def ginger():
    rr = rnd(221)
    parts = []
    flowers = []
    for k in range(7):
        a = rr.uniform(0, 2 * math.pi)
        r = rr.uniform(0, 0.25)
        x, y = math.cos(a) * r, math.sin(a) * r
        h = rr.uniform(0.7, 1.15)
        lean = Vector((math.cos(a), math.sin(a), 0)) * rr.uniform(0.05, 0.2)
        parts.append(_stem("gs_leaf", [(x, y, 0), (x + lean.x * 0.5, y + lean.y * 0.5, h * 0.5), (x + lean.x, y + lean.y, h)], [0.014, 0.012, 0.008], hexcol("5a8a3a")))
        for j in range(5):
            z = h * (0.35 + j * 0.13)
            aa = j * 2.5 + a
            p = (x + lean.x * z / h, y + lean.y * z / h, z)
            lf = leaf("gl_leaf", p, (math.cos(aa), math.sin(aa), 0.25), rr.uniform(0.26, 0.34), 0.045, droop=0.5, segs=6, fold=0.3, shape=_shape_lance)
            paint(lf, shade(LEAF_L, 0.9 + 0.12 * rr.random()), ao=0.0)
            parts.append(lf)
    for k in range(3):   # цветы на отдельных стеблях
        a = 2 * math.pi * k / 3 + 0.4
        x, y = math.cos(a) * 0.22, math.sin(a) * 0.22
        h = rr.uniform(0.55, 0.8)
        parts.append(_stem("gf_leaf", [(x, y, 0), (x * 1.1, y * 1.1, h)], 0.01, hexcol("7a7a3a")))
        for j in range(9):   # прицветники-«чешуи» факела
            t = j / 8
            ang = j * 2.1
            rad = 0.055 * (1 - t * 0.6)
            p = (x * 1.1 + math.cos(ang) * rad * 0.3, y * 1.1 + math.sin(ang) * rad * 0.3, h + t * 0.14)
            br = leaf("gb", p, (math.cos(ang), math.sin(ang), 0.6 + t), 0.06 * (1 - t * 0.5) + 0.02, 0.03, droop=-0.2, segs=3, fold=0.4)
            paint(br, hexcol("e8384a") if j % 3 else hexcol("ff6a5a"), ao=0.0, noise_amt=0)
            flowers.append(br)
    join(parts, "Ginger_leaf")
    join(flowers, "GingerFlower")


# ------------------------------------------------------------------ гибискус: плотный куст с красными и розовыми цветками (мачете)
def _hibiscus(seed, petal):
    rr = rnd(seed)
    body = []
    blobs = []
    for i in range(6):
        r = rr.uniform(0.38, 0.55)
        ctr = (rr.uniform(-0.45, 0.45), rr.uniform(-0.45, 0.45), 0.45 + r * 0.6)
        blobs.append((ctr, r * 0.95, 0.85))
        b = ico("hb", ctr, r, (1, 1, 0.85), sub=2)
        displace(b, 0.18, 0.12, "VORONOI")
        c = shade(LEAF_D, 0.92 + 0.15 * rr.random())
        paint(b, c, ao=0.3, ao_h=0.7, noise_amt=0.16, nscale=9, fn=lambda co, n, c=c: shade(c, 1.18) if n.z > 0.55 else None)
        body.append(b)
    for k in range(5):   # ветки у земли
        a = 2 * math.pi * k / 5
        body.append(_stem("hst", [(0, 0, 0), (math.cos(a) * 0.2, math.sin(a) * 0.2, 0.35)], [0.035, 0.02], BARK_D))
    flowers = []
    for k in range(16):
        c, out = _on_blobs(rr, blobs)
        col = petal[k % len(petal)]
        for p in range(5):   # пять широких лепестков
            pa = 2 * math.pi * p / 5
            side = out.orthogonal().normalized()
            d = (side * math.cos(pa) + out.cross(side) * math.sin(pa) + out * 0.5).normalized()
            pt = leaf("hp", tuple(c), tuple(d), 0.085, 0.055, droop=-0.1, segs=4, fold=0.25, shape=_shape_round)
            paint(pt, col, ao=0.0, noise_amt=0.03, fn=lambda co, n, c=c, col=col: shade(col, 0.7) if (co - c).length < 0.022 else None)
            flowers.append(pt)
        st = tube("hpi", [tuple(c), tuple(c + out * 0.07)], 0.006, 4)
        paint(st, hexcol("ffe27a"), ao=0.0)
        flowers.append(st)
    join(body, "Hibiscus_leaf")
    join(flowers, "HibiscusFlowers")


def hibiscus_a():
    _hibiscus(231, [hexcol("e8384a"), hexcol("ff5a6a"), hexcol("e8384a")])


def hibiscus_b():
    _hibiscus(232, [hexcol("ff8ab0"), hexcol("ffb0c8"), hexcol("ffd25a")])


# ------------------------------------------------------------------ древовидный папоротник (топор)
def _tree_fern(seed):
    rr = rnd(seed)
    h = rr.uniform(2.3, 2.9)
    lean = Vector((rr.uniform(-0.25, 0.25), rr.uniform(-0.25, 0.25), 0))
    pts = [(0, 0, 0), tuple(lean * 0.3 + Vector((0, 0, h * 0.4))), tuple(lean * 0.7 + Vector((0, 0, h * 0.75))), tuple(lean + Vector((0, 0, h)))]
    tr = tube("tf", pts, [0.17, 0.14, 0.12, 0.13], 12)
    displace(tr, 0.025, 0.06)
    # ствол в «рубцах» от старых листьев: тёмные пятна-ромбы, у земли — мох
    paint(tr, hexcol("6a5040"), ao=0.3, ao_h=0.6, noise_amt=0.14, nscale=8,
          fn=lambda co, n: MOSS if co.z < 0.35 and noise.noise(co * 6) > -0.1 else None, mat="palm")
    trunk = [tr]
    top = Vector(pts[-1])
    fronds = []
    for k in range(11):
        a = 2 * math.pi * k / 11 + rr.uniform(-0.15, 0.15)
        ln = rr.uniform(1.1, 1.45)
        rise = rr.uniform(0.35, 0.65)
        d = Vector((math.cos(a), math.sin(a), rise)).normalized()
        sp = [top + d * ln * t + Vector((0, 0, -ln * 0.55 * t * t)) for t in (0, 0.3, 0.6, 1.0)]
        rach = tube("tfr_leaf", [tuple(p) for p in sp], [0.022, 0.016, 0.01, 0.004], 5)
        paint(rach, hexcol("5a7a3a"), ao=0.0)
        fronds.append(rach)
        side = Vector((-math.sin(a), math.cos(a), 0))
        for i in range(1, 9):
            t = i / 9
            p = sp[0].lerp(sp[1], min(1, t * 3)) if t < 0.33 else (sp[1].lerp(sp[2], (t - 0.33) * 3) if t < 0.66 else sp[2].lerp(sp[3], (t - 0.66) * 3))
            for sg in (-1, 1):
                pl = leaf("tfp_leaf", tuple(p), tuple((side * sg + d * 0.4).normalized()), 0.32 * (1 - t * 0.7) + 0.06, 0.07, droop=0.4, segs=4, fold=0.25,
                          shape=_shape_lance)
                paint(pl, shade(LEAF_L if i % 2 else LEAF, 0.92 + 0.1 * rr.random()), ao=0.0)
                fronds.append(pl)
    for k in range(4):   # молодые листья-«улитки» на макушке
        a = 2 * math.pi * k / 4 + 0.5
        coil = [tuple(top + Vector((math.cos(a) * (0.05 + 0.04 * math.cos(t * 4)), math.sin(a) * (0.05 + 0.04 * math.cos(t * 4)), 0.05 + t * 0.12 + 0.04 * math.sin(t * 4))))
                for t in [s / 8 for s in range(9)]]
        cl = tube("tfc_leaf", coil, [0.02 - 0.0015 * i for i in range(9)], 5)
        paint(cl, hexcol("8ab04a"), ao=0.0)
        fronds.append(cl)
    join(trunk, "Trunk")
    from kit import empty, set_origin, set_parent
    crown = empty("Crown", tuple(top))
    cj = join(fronds, "Crown_leaf")
    set_origin(cj, tuple(top))
    set_parent(cj, crown)


def tree_fern_a():
    _tree_fern(241)


def tree_fern_b():
    _tree_fern(242)


# ------------------------------------------------------------------ Грозовой: дрок (жёлтый колючий куст) и наперстянка
def gorse():
    rr = rnd(251)
    body, flowers = [], []
    for i in range(5):
        r = rr.uniform(0.32, 0.45)
        b = ico("gr", (rr.uniform(-0.35, 0.35), rr.uniform(-0.35, 0.35), 0.35 + r * 0.5), r, (1, 1, 0.8), sub=2)
        displace(b, 0.16, 0.08, "VORONOI")
        paint(b, shade(hexcol("4a6a3a"), 0.92 + 0.15 * rr.random()), ao=0.3, ao_h=0.6, noise_amt=0.2, nscale=14)
        body.append(b)
    for k in range(70):   # жёлтые цветочки по всей поверхности
        a = rr.uniform(0, 2 * math.pi)
        z = rr.uniform(0.3, 1.05)
        rad = 0.55 * math.sqrt(max(0.05, 1 - ((z - 0.6) / 0.55) ** 2)) + 0.08
        f = sphere("gf", (math.cos(a) * rad, math.sin(a) * rad, z), rr.uniform(0.025, 0.04), (1, 1, 0.7), segs=8, rings=5)
        paint(f, hexcol("ffd23f") if k % 4 else hexcol("ffb52a"), ao=0.0, noise_amt=0)
        flowers.append(f)
    join(body, "Gorse_leaf")
    join(flowers, "GorseFlowers")


def foxglove():
    rr = rnd(261)
    parts, flowers = [], []
    for k in range(9):   # розетка листьев у земли
        a = 2 * math.pi * k / 9
        lf = leaf("fg_leaf", (0, 0, 0.02), (math.cos(a), math.sin(a), 0.3), rr.uniform(0.22, 0.3), 0.07, droop=0.4, segs=5, fold=0.25, shape=_shape_lance)
        paint(lf, shade(hexcol("4f7a4a"), 0.92 + 0.1 * rr.random()), ao=0.0)
        parts.append(lf)
    for s in range(3):   # стрелки с колокольчиками
        a = 2 * math.pi * s / 3 + 0.3
        x, y = math.cos(a) * 0.08, math.sin(a) * 0.08
        h = rr.uniform(0.75, 1.05)
        parts.append(_stem("fs_leaf", [(x, y, 0), (x * 1.3, y * 1.3, h * 0.5), (x * 1.5, y * 1.5, h)], [0.012, 0.01, 0.005], hexcol("5a7a3a")))
        col = [hexcol("c858b8"), hexcol("e080c8"), hexcol("f2d8f0")][s]
        for j in range(11):
            t = j / 10
            z = h * (0.45 + t * 0.52)
            ang = j * 2.4
            c = Vector((x * (1.3 + t * 0.2) + math.cos(ang) * 0.03, y * (1.3 + t * 0.2) + math.sin(ang) * 0.03, z))
            bell = cyl("fb", tuple(c), 0.022 * (1 - t * 0.5) + 0.008, 0.012 * (1 - t * 0.5) + 0.004, 0.05 * (1 - t * 0.4) + 0.015,
                       (math.pi * 0.62, 0, ang + math.pi / 2), segs=8)
            paint(bell, col, ao=0.0, noise_amt=0, fn=lambda co, n, c=c: hexcol("f8eef8") if (co - c).length < 0.012 else None)
            flowers.append(bell)
    join(parts, "Foxglove_leaf")
    join(flowers, "FoxgloveBells")


# ------------------------------------------------------------------ Ледяной: карликовая берёза и пушица
def dwarf_birch():
    rr = rnd(271)
    stems, leaves = [], []
    for k in range(6):
        a = 2 * math.pi * k / 6 + rr.uniform(-0.3, 0.3)
        ln = rr.uniform(0.6, 0.95)
        pts = [(0, 0, 0), (math.cos(a) * ln * 0.3, math.sin(a) * ln * 0.3, ln * 0.35), (math.cos(a) * ln * 0.7, math.sin(a) * ln * 0.7, ln * 0.55),
               (math.cos(a + 0.3) * ln, math.sin(a + 0.3) * ln, ln * 0.62)]
        st = _stem("db", pts, [0.032, 0.024, 0.015, 0.007], hexcol("7a4a3a"))
        paint(st, hexcol("7a4a3a"), ao=0.0, mat="birch")   # светлые чечевички поперёк — texbake
        stems.append(st)
        for j in range(16):
            t = 0.2 + 0.8 * j / 15
            p = Vector(pts[1]).lerp(Vector(pts[3]), t) + Vector((rr.uniform(-0.05, 0.05), rr.uniform(-0.05, 0.05), rr.uniform(0, 0.05)))
            aa = rr.uniform(0, 6.28)
            lf = leaf("dbl_leaf", tuple(p), (math.cos(aa), math.sin(aa), 0.6), 0.11, 0.075, droop=0.15, segs=4, fold=0.2, shape=_shape_round)
            c = [hexcol("8aa84a"), hexcol("c8a83a"), hexcol("d8783a")][(j + k) % 3]   # осенняя пёстрая листва
            paint(lf, c, ao=0.0, noise_amt=0.05, mat="leaf_matte")
            leaves.append(lf)
    join(stems, "DwarfBirch")
    join(leaves, "DwarfBirch_leaf")


def cotton_grass():
    rr = rnd(281)
    parts, fluff = [], []
    for k in range(22):
        a = rr.uniform(0, 2 * math.pi)
        r = rr.uniform(0, 0.28)
        x, y = math.cos(a) * r, math.sin(a) * r
        lf = leaf("cg_leaf", (x, y, 0), (math.cos(a) * 0.3, math.sin(a) * 0.3, 1), rr.uniform(0.3, 0.5), 0.02, droop=0.35, segs=4, fold=0.2, shape=_shape_lance)
        paint(lf, mix(hexcol("8a9a4a"), hexcol("c8b86a"), rr.random() * 0.6), ao=0.2, ao_h=0.3)
        parts.append(lf)
    for k in range(9):   # стебельки с белыми пушистыми шариками
        a = rr.uniform(0, 2 * math.pi)
        r = rr.uniform(0.05, 0.25)
        x, y = math.cos(a) * r, math.sin(a) * r
        h = rr.uniform(0.45, 0.7)
        tip = (x + math.cos(a) * 0.05, y + math.sin(a) * 0.05, h)
        parts.append(_stem("cgs_leaf", [(x, y, 0), tip], 0.005, hexcol("7a8a4a")))
        f = ico("cgf_leaf", (tip[0], tip[1], tip[2] + 0.04), 0.05, (1, 1, 1.25), sub=2)
        displace(f, 0.025, 0.02)
        paint(f, hexcol("fbfbf6"), ao=0.0, noise_amt=0.05, fn=lambda co, n: hexcol("e8e8e0") if n.z < -0.3 else None)
        fluff.append(f)
    join(parts + fluff, "CottonGrass_leaf")


# ------------------------------------------------------------------ Вулкан: юкка (мачете) и охия
def yucca():
    rr = rnd(291)
    trunk = []
    t1 = tube("yt", [(0, 0, 0), (0.05, 0.02, 0.35), (0.08, 0.0, 0.62)], [0.09, 0.075, 0.07], 10)
    paint(t1, hexcol("8a7458"), ao=0.3, ao_h=0.4, noise_amt=0.15, nscale=10, mat="palm")   # рубцы от листьев
    trunk.append(t1)
    leaves = []
    top = Vector((0.08, 0.0, 0.62))
    for k in range(26):   # жёсткие острые листья шаром
        th = math.acos(1 - 2 * (k + 0.5) / 26 * 0.8)
        ph = k * 2.4
        d = Vector((math.sin(th) * math.cos(ph), math.sin(th) * math.sin(ph), math.cos(th)))
        lf = leaf("yl_leaf", tuple(top), tuple(d), rr.uniform(0.42, 0.58), 0.032, droop=0.08, segs=4, fold=0.35, shape=lambda t: (1 - t) ** 0.9)
        c = shade(hexcol("6a9a5a"), 0.9 + 0.15 * rr.random())
        paint(lf, c, ao=0.0, fn=lambda co, n, c=c: hexcol("c8b86a") if (co - top).length > 0.48 else None)
        leaves.append(lf)
    for k in range(10):   # сухие листья «юбкой» под шаром
        a = 2 * math.pi * k / 10
        lf = leaf("yd_leaf", tuple(top - Vector((0, 0, 0.06))), (math.cos(a), math.sin(a), -0.9), 0.3, 0.028, droop=0.0, segs=3, fold=0.3, shape=lambda t: 1 - t)
        paint(lf, hexcol("b89a6a"), ao=0.0)
        leaves.append(lf)
    join(trunk, "Yucca")
    join(leaves, "Yucca_leaf")


def ohia():
    rr = rnd(301)
    body, fl = [], []
    for k in range(4):
        a = 2 * math.pi * k / 4 + 0.4
        body.append(_stem("ob", [(0, 0, 0), (math.cos(a) * 0.15, math.sin(a) * 0.15, 0.5), (math.cos(a) * 0.35, math.sin(a) * 0.35, 0.95)],
                          [0.05, 0.035, 0.02], hexcol("7a6050")))
    blobs = []
    for i in range(6):
        r = rr.uniform(0.26, 0.4)
        a = rr.uniform(0, 6.28)
        ctr = (math.cos(a) * 0.32, math.sin(a) * 0.32, 0.9 + rr.uniform(0, 0.4))
        blobs.append((ctr, r * 0.95, 0.75))
        b = ico("oc", ctr, r, (1, 1, 0.75), sub=2)
        displace(b, 0.14, 0.12, "VORONOI")
        c = shade(hexcol("5a7a5a"), 0.92 + 0.14 * rr.random())   # серовато-зелёная листва
        paint(b, c, ao=0.0, noise_amt=0.15, nscale=10, fn=lambda co, n, c=c: shade(c, 1.2) if n.z > 0.5 else None)
        body.append(b)
    for k in range(18):   # красные «помпоны» из тычинок — прямо на кроне
        c, out = _on_blobs(rr, blobs, 0.1)
        for s in range(9):
            d = (out + Vector((rr.uniform(-0.6, 0.6), rr.uniform(-0.6, 0.6), rr.uniform(-0.6, 0.6)))).normalized()
            st = tube("os", [tuple(c), tuple(c + d * 0.06)], [0.005, 0.003], 3)
            paint(st, hexcol("e8303a"), ao=0.0)
            tip = sphere("ot", tuple(c + d * 0.062), 0.007, segs=6, rings=4)
            paint(tip, hexcol("ffd23f"), ao=0.0)
            fl += [st, tip]
    join(body[:4], "OhiaStems")
    join(body[4:], "Ohia_leaf")
    join(fl, "OhiaFlowers")


# ------------------------------------------------------------------ Туманный: рогоз и болотная ива
def cattail():
    rr = rnd(311)
    parts, heads = [], []
    for k in range(18):
        a = rr.uniform(0, 2 * math.pi)
        r = rr.uniform(0, 0.3)
        x, y = math.cos(a) * r, math.sin(a) * r
        lf = leaf("ct_leaf", (x, y, 0), (math.cos(a) * 0.18, math.sin(a) * 0.18, 1), rr.uniform(0.9, 1.4), 0.035, droop=0.18, segs=6, fold=0.3, shape=_shape_lance)
        paint(lf, mix(hexcol("5a8a4a"), hexcol("8aa05a"), rr.random() * 0.5), ao=0.25, ao_h=0.4)
        parts.append(lf)
    for k in range(6):
        a = rr.uniform(0, 2 * math.pi)
        r = rr.uniform(0.02, 0.22)
        x, y = math.cos(a) * r, math.sin(a) * r
        h = rr.uniform(1.0, 1.45)
        parts.append(_stem("cts_leaf", [(x, y, 0), (x + math.cos(a) * 0.04, y + math.sin(a) * 0.04, h + 0.18)], 0.008, hexcol("6a8a3a")))
        cx, cy = x + math.cos(a) * 0.035, y + math.sin(a) * 0.035
        hd = cyl("cth", (cx, cy, h - 0.12), 0.03, 0.03, 0.2, segs=10)
        subsurf(hd, 1)
        paint(hd, hexcol("7a4a2a"), ao=0.0, noise_amt=0.12, nscale=30, mat="velvet")
        heads.append(hd)
    join(parts + heads, "Cattail_leaf")


def swamp_willow():
    rr = rnd(321)
    h = 2.7
    pts = [(0, 0, 0), (0.1, 0.05, 0.9), (-0.05, 0.1, 1.8), (0.05, 0.0, h)]
    tr = tube("sw", pts, [0.17, 0.13, 0.1, 0.08], 12)
    displace(tr, 0.04, 0.1)
    paint(tr, hexcol("6a5a48"), ao=0.3, ao_h=0.8, noise_amt=0.15, nscale=7, fn=bark_fn((0, 0, 0), (0, 0, 1), col=hexcol("6a5a48"), moss=0.3, seed=9, moss_up=0.2))
    trunk = [tr]
    for k in range(4):   # ветви вверх и в стороны
        a = 2 * math.pi * k / 4 + 0.3
        z0 = rr.uniform(1.6, 2.4)
        trunk.append(_stem("swb", [(0, 0, z0), (math.cos(a) * 0.6, math.sin(a) * 0.6, z0 + 0.5), (math.cos(a) * 1.0, math.sin(a) * 1.0, z0 + 0.7)],
                           [0.06, 0.035, 0.015], hexcol("6a5a48")))
    from kit import empty, set_origin, set_parent
    crown = empty("Crown", (0, 0, h))
    leaves = []
    for k in range(26):   # плакучие ветки — свисающие плети с узкими листьями
        a = 2 * math.pi * k / 26 + rr.uniform(-0.1, 0.1)
        r0 = rr.uniform(0.5, 1.1)
        z0 = h + rr.uniform(0.2, 0.7)
        top = Vector((math.cos(a) * r0, math.sin(a) * r0, z0))
        ln = rr.uniform(1.0, 1.7)
        bot = top + Vector((math.cos(a) * 0.35, math.sin(a) * 0.35, -ln))
        mid = top.lerp(bot, 0.4) + Vector((math.cos(a) * 0.2, math.sin(a) * 0.2, 0.1))
        whip = tube("sww_leaf", [tuple(top), tuple(mid), tuple(bot)], [0.008, 0.006, 0.003], 4)
        paint(whip, hexcol("7a8a4a"), ao=0.0)
        leaves.append(whip)
        for j in range(7):
            t = 0.15 + j * 0.13
            p = top.lerp(mid, t / 0.4) if t < 0.4 else mid.lerp(bot, (t - 0.4) / 0.6)
            aa = j * 2.2 + a
            lf = leaf("swl_leaf", tuple(p), (math.cos(aa), math.sin(aa), -0.6), 0.16, 0.045, droop=0.2, segs=3, fold=0.2, shape=_shape_lance)
            paint(lf, shade(hexcol("7aa05a"), 0.9 + 0.15 * rr.random()), ao=0.0)
            leaves.append(lf)
    for i in range(8):   # верх кроны — мягкие облачка листвы над ветвями
        a = 2 * math.pi * i / 8 + rr.uniform(-0.2, 0.2)
        rad = 0.75 if i % 2 else 0.35
        b = ico("swc", (math.cos(a) * rad, math.sin(a) * rad, h + 0.35 + rr.uniform(0, 0.45)), rr.uniform(0.42, 0.58), (1, 1, 0.8), sub=2)
        displace(b, 0.22, 0.25)
        paint(b, shade(hexcol("7aa05a"), 0.9 + 0.1 * rr.random()), ao=0.0, noise_amt=0.15, nscale=4)
        leaves.append(b)
    join(trunk, "Trunk")
    cj = join(leaves, "Crown_leaf")
    set_origin(cj, (0, 0, h))
    set_parent(cj, crown)


# ------------------------------------------------------------------ грибы и низкая травка
def mushrooms():
    rr = rnd(331)
    parts = []
    for k in range(7):
        a = rr.uniform(0, 2 * math.pi)
        r = rr.uniform(0, 0.22)
        x, y = math.cos(a) * r, math.sin(a) * r
        h = rr.uniform(0.06, 0.16)
        st = cyl("mst", (x, y, -0.01), 0.018, 0.014, h + 0.01, segs=8)
        paint(st, hexcol("f2e8d4"), ao=0.0)
        cap_r = rr.uniform(0.035, 0.07)
        col = [hexcol("c8643a"), hexcol("d8a060"), hexcol("e85a3a")][k % 3]
        cp = sphere("mcp", (x, y, h), cap_r, (1, 1, 0.55), segs=12, rings=7)
        paint(cp, col, ao=0.0, fn=lambda co, n, col=col: hexcol("f4ead8") if n.z < 0 else (hexcol("fbf4e8") if (col == hexcol("e85a3a") and noise.noise(co * 60) > 0.55) else None))
        parts += [st, cp]
    for k in range(3):
        a = rr.uniform(0, 6.28)
        lf = leaf("mm_leaf", (math.cos(a) * 0.15, math.sin(a) * 0.15, 0.0), (math.cos(a), math.sin(a), 0.2), 0.12, 0.05, droop=0.2, segs=3)
        paint(lf, hexcol("b88a4a"), ao=0.0)   # опавший лист
        parts.append(lf)
    join(parts, "Mushrooms")


def clover_tuft():
    """Кустик клевера (и иногда одуванчик) — для травяной сетки GrassField: маленький, без контура."""
    rr = rnd(341)
    parts = []
    for k in range(6):
        a = 2 * math.pi * k / 6 + rr.uniform(-0.2, 0.2)
        ln = rr.uniform(0.07, 0.12)
        tip = (math.cos(a) * ln, math.sin(a) * ln, rr.uniform(0.05, 0.09))
        parts.append(_stem("cv_leaf", [(0, 0, 0), tip], 0.004, hexcol("4f8a3a"), 3))
        for q in range(3):   # тройной листочек
            qa = a + (q - 1) * 2.1
            lf = leaf("cv_leaf", tip, (math.cos(qa), math.sin(qa), 0.15), 0.035, 0.024, droop=0.05, segs=3, fold=0.15, shape=_shape_round)
            paint(lf, shade(hexcol("4f9a3e"), 0.95 + 0.12 * rr.random()), ao=0.0, noise_amt=0)
            parts.append(lf)
    fl = sphere("cvf_leaf", (0.02, -0.01, 0.13), 0.022, (1, 1, 0.8), segs=8, rings=5)
    paint(fl, hexcol("f4f0f8"), ao=0.0, fn=lambda co, n: hexcol("e8a8c8") if n.z < 0.2 else None)
    parts.append(fl)
    parts.append(_stem("cvs_leaf", [(0, 0, 0), (0.02, -0.01, 0.12)], 0.003, hexcol("5a8a3a"), 3))
    join(parts, "Clover_leaf")


BUILDERS = {"monstera_a": monstera_a, "monstera_b": monstera_b, "taro_a": taro_a, "taro_b": taro_b, "ginger": ginger,
            "hibiscus_a": hibiscus_a, "hibiscus_b": hibiscus_b, "tree_fern_a": tree_fern_a, "tree_fern_b": tree_fern_b,
            "gorse": gorse, "foxglove": foxglove, "dwarf_birch": dwarf_birch, "cotton_grass": cotton_grass,
            "yucca": yucca, "ohia": ohia, "cattail": cattail, "swamp_willow": swamp_willow, "mushrooms": mushrooms,
            "clover_tuft": clover_tuft}
