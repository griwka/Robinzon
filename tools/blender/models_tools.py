"""Инструменты в руке героя: топоры, мачете, кирки, лопата, лейка, сачок, удочка, ледоруб, ледовый бур.

Общее правило (как ждёт игра): хват — в начале координат, рукоять уходит вниз по −Z,
рабочая сторона (лезвие топора, остриё мачете, носик лейки) смотрит в +Y.
Каждая модель — из нескольких деталей: рукоять с волокнами дерева и обмоткой, кованые или
колотые головы с заточенной кромкой, заклёпки, ремешки. Низкополигонально, но без «кубиков».
"""
import math

import bmesh

from kit import (box, cyl, from_bm, hexcol, ico, join, lathe, paint, shade, solidify, sphere, tube, displace)

WOOD = hexcol("9a6a3c")
WOOD_DARK = hexcol("6e4526")
LEATHER = hexcol("6b3a22")
ROPE = hexcol("d2ad72")
STEEL = hexcol("aeb8c2")
STEEL_EDGE = hexcol("eef3f7")
IRON = hexcol("5d6873")
IRON_EDGE = hexcol("c9d3dc")
BRASS = hexcol("d2a548")
STONE = hexcol("7a8088")
FLINT = hexcol("626a73")


def smoothstep(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


# ------------------------------------------------------------------ детали
def handle(name, z_top, z_bot, r_top, r_bot, col=WOOD, segs=10, swell=0.0):
    """Деревянная рукоять: чуть сужается, по ней идут волокна; у конца — скруглённый торец."""
    n = 7
    pts, rad = [], []
    for i in range(n):
        t = i / (n - 1)
        pts.append((0, 0, z_top + (z_bot - z_top) * t))
        rad.append(r_top + (r_bot - r_top) * t + swell * math.sin(t * math.pi))
    h = tube(name, pts, rad, segs)
    # волокна вдоль рукояти рисует запекание (texbake_props → "wood", направление — атрибут u0 трубки)
    paint(h, col, ao=0.0, noise_amt=0.06, nscale=12, mat="wood")
    cap = sphere(name + "c", (0, 0, z_top), r_top * 1.02, (1, 1, 0.55), segs=10, rings=6)
    paint(cap, shade(col, 0.92), ao=0.0, mat="endgrain")
    return [h, cap]


def wrap(name, z0, z1, r, col=LEATHER, turns=5, w=0.011):
    """Обмотка рукояти ремешком: спираль поверх дерева."""
    pts = []
    steps = turns * 14
    for i in range(steps + 1):
        t = i / steps
        a = t * turns * 2 * math.pi
        pts.append((math.cos(a) * r, math.sin(a) * r, z0 + (z1 - z0) * t))
    t = tube(name, pts, w, 6, caps=False)
    paint(t, col, ao=0.0, noise_amt=0.1, nscale=30)     # зерно и заломы кожи — texbake_props ("leather")
    return t


def lashing(name, zc, r, col=ROPE, rows=3, cross=True):
    """Верёвочная обвязка головы к рукояти: кольца и накрест."""
    out = []
    for k in range(rows):
        z = zc + (k - (rows - 1) / 2) * 0.026
        ring = [(math.cos(a) * r, math.sin(a) * r * 1.15, z + 0.006 * math.sin(a * 2)) for a in [i * math.pi / 8 for i in range(17)]]
        out.append(tube(name + "r%d" % k, ring, 0.011, 6, caps=False))
    if cross:
        for s in (-1, 1):
            out.append(tube(name + "x%d" % s, [(-r * 1.05, -0.02, zc + 0.05 * s), (0, -0.07, zc), (r * 1.05, -0.02, zc - 0.05 * s)], 0.01, 6))
    for o in out:
        paint(o, col, ao=0.0, noise_amt=0.12, nscale=40)
    return out


def rivet(name, loc, r=0.011, axis="x", col=BRASS):
    rot = (0, math.pi / 2, 0) if axis == "x" else ((math.pi / 2, 0, 0) if axis == "y" else (0, 0, 0))
    rv = cyl(name, (loc[0] - (r * 0.0), loc[1], loc[2]), r, r * 0.8, 0.008, rot, 8)
    paint(rv, col, ao=0.0)
    return rv


def blade(name, outline, thick_fn, col, edge_col=None, edge_fn=None):
    """Плоская кованая деталь в плоскости YZ: контур outline [(y, z), ...] по кругу, толщина по X — thick_fn(y, z).
    У режущей кромки толщина сходит почти в ноль, кромка светлее (заточка)."""
    bm = bmesh.new()
    front, back = [], []
    for (y, z) in outline:
        t = max(0.0015, thick_fn(y, z)) * 0.5
        front.append(bm.verts.new((t, y, z)))
        back.append(bm.verts.new((-t, y, z)))
    bm.faces.new(front)
    bm.faces.new(back[::-1])
    n = len(outline)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((front[i], back[i], back[j], front[j]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 4])
    ob = from_bm(name, bm, smooth=False)

    def f(co, nrm):
        if edge_col is not None and edge_fn is not None and edge_fn(co.y, co.z):
            return edge_col
        return 1.06 if nrm.x > 0.3 else (0.9 if nrm.x < -0.3 else 0.82)
    paint(ob, col, ao=0.0, noise_amt=0.04, nscale=20, fn=f)
    return ob


def arc(y0, z0, y1, z1, bulge, n=8):
    """Точки дуги от (y0,z0) до (y1,z1) с выгибом bulge (вбок от хорды)."""
    pts = []
    dy, dz = y1 - y0, z1 - z0
    ln = math.hypot(dy, dz) or 1.0
    ny, nz = -dz / ln, dy / ln
    for i in range(n + 1):
        t = i / n
        b = bulge * math.sin(t * math.pi)
        pts.append((y0 + dy * t + ny * b, z0 + dz * t + nz * b))
    return pts


# ------------------------------------------------------------------ топоры
def _axe_outline(scale=1.0):
    """Контур топора: обух у рукояти, щёки расходятся к широкому лезвию с выпуклой кромкой."""
    s = scale
    top = [(-0.045 * s, -0.47), (0.04 * s, -0.47), (0.12 * s, -0.43)]
    edge = arc(0.215 * s, -0.405, 0.225 * s, -0.705, 0.03 * s, 9)
    bot = [(0.12 * s, -0.66), (0.04 * s, -0.6), (-0.045 * s, -0.6)]
    return top + edge + bot


def tool_stone_axe():
    """Каменный топор: колотый кремень, вставлен в расщеп рукояти и примотан верёвкой накрест."""
    parts = handle("h", 0.12, -0.66, 0.031, 0.036, WOOD_DARK, swell=0.004)
    parts.append(wrap("w", 0.07, -0.08, 0.035, LEATHER, 4))
    # каменная голова — неровный клин: толстый у рукояти, острый к кромке, со сколами
    outline = [(-0.05, -0.46), (0.05, -0.45), (0.13, -0.42), (0.2, -0.44), (0.235, -0.52), (0.24, -0.6),
               (0.22, -0.68), (0.15, -0.7), (0.06, -0.64), (-0.05, -0.62)]
    head = blade("hd", outline, lambda y, z: 0.085 - 0.07 * smoothstep(0.02, 0.23, y) + 0.008 * math.sin(z * 90 + y * 60),
                 STONE, hexcol("aab1b8"), lambda y, z: y > 0.215)

    # сколы и раковистые волны кремня, меловая корка — texbake_props ("flint"); кромка светлее
    paint(head, STONE, ao=0.0, noise_amt=0.08, nscale=18,
          fn=lambda co, nrm: hexcol("aab1b8") if co.y > 0.222 else (0.9 if nrm.x < 0 else None))
    parts.append(head)
    parts += lashing("l", -0.54, 0.05, ROPE, 3)
    join(parts, "Tool")


def tool_iron_axe():
    """Железный топор: кованый клин с проушиной, светлая заточенная кромка, клинышек в торце рукояти."""
    parts = handle("h", 0.12, -0.64, 0.03, 0.035, WOOD, swell=0.005)
    parts.append(wrap("w", 0.08, -0.1, 0.034, LEATHER, 5))
    head = blade("hd", _axe_outline(1.05), lambda y, z: 0.07 - 0.064 * smoothstep(0.03, 0.22, y),
                 IRON, IRON_EDGE, lambda y, z: y > 0.19)
    parts.append(head)
    # проушина — кольцо вокруг рукояти, обух — плоский торец сзади
    eye = cyl("ey", (0, 0, -0.615), 0.046, 0.046, 0.15, segs=12)
    paint(eye, shade(IRON, 0.9), ao=0.0)
    parts.append(eye)
    poll = box("pl", (0, -0.05, -0.535), (0.07, 0.03, 0.13), bev=0.008)
    paint(poll, shade(IRON, 0.8), ao=0.0)
    parts.append(poll)
    wedge = box("wd", (0, 0, -0.47), (0.012, 0.05, 0.012))
    paint(wedge, BRASS, ao=0.0)
    parts.append(wedge)
    join(parts, "Tool")


# ------------------------------------------------------------------ мачете
def _machete(name_col, edge_col, length=0.55, guard_col=STEEL, scale_col=LEATHER, fuller=False, rivet_col=BRASS):
    parts = []
    # рукоять: две накладки, заклёпки, отверстие под темляк
    grip = box("g", (0, 0, -0.05), (0.034, 0.05, 0.26), bev=0.012, seg=3)
    paint(grip, scale_col, ao=0.0, noise_amt=0.1, nscale=25, mat="leather")
    parts.append(grip)
    for z in (0.04, -0.06, -0.15):
        parts.append(rivet("rv%d" % int(z * 100), (0.019, 0, z), 0.008, "x", rivet_col))
        parts.append(rivet("rb%d" % int(z * 100), (-0.019, 0, z), 0.008, "x", rivet_col))
    pom = sphere("pm", (0, 0, 0.085), 0.03, (0.75, 1.0, 0.6), segs=10, rings=6)
    paint(pom, guard_col, ao=0.0)
    parts.append(pom)
    guard = box("gd", (0, 0.0, -0.19), (0.05, 0.13, 0.024), bev=0.008)
    paint(guard, guard_col, ao=0.0)
    parts.append(guard)
    # клинок: обух прямой, лезвие с «брюшком», скошенное остриё
    z0 = -0.2
    tip = z0 - length
    spine = [(-0.025, z0), (-0.028, z0 - length * 0.55), (-0.02, tip + 0.06)]
    point = [(0.0, tip - 0.01), (0.05, tip + 0.02)]
    belly = arc(0.075, tip + 0.06, 0.03, z0 - 0.01, -0.025, 8)
    outline = spine + point + belly
    bl = blade("bl", outline, lambda y, z: 0.014 - 0.012 * smoothstep(-0.01, 0.06, y),
               name_col, edge_col, lambda y, z: y > 0.035 or (z < tip + 0.05 and y > 0.0))
    parts.append(bl)
    if fuller:
        f = tube("fu", [(0.0062, -0.012, z0 - 0.04), (0.0062, -0.012, z0 - length * 0.72)], 0.004, 4)
        paint(f, shade(name_col, 0.6), ao=0.0)
        parts.append(f)
        f2 = tube("fv", [(-0.0062, -0.012, z0 - 0.04), (-0.0062, -0.012, z0 - length * 0.72)], 0.004, 4)
        paint(f2, shade(name_col, 0.6), ao=0.0)
        parts.append(f2)
    join(parts, "Tool")


def tool_machete():
    """Мачете: светлый клинок из старого металла, кожаная рукоять на медных заклёпках."""
    _machete(STEEL, STEEL_EDGE, 0.52, hexcol("8f9499"), LEATHER)


def tool_iron_machete():
    """Железное мачете: длиннее и тяжелее, тёмный клинок с долом, латунная гарда и навершие."""
    _machete(hexcol("6e7a86"), IRON_EDGE, 0.6, BRASS, hexcol("4a2a1a"), fuller=True)


# ------------------------------------------------------------------ кирки
def tool_pickaxe():
    """Кирка: деревянная колодка на рукояти, в неё вбиты и примотаны два заострённых камня."""
    parts = handle("h", 0.12, -0.62, 0.03, 0.036, WOOD_DARK, swell=0.004)
    parts.append(wrap("w", 0.07, -0.09, 0.034, LEATHER, 4))
    block = box("bk", (0, 0, -0.57), (0.07, 0.2, 0.09), bev=0.015, seg=2)
    paint(block, WOOD, ao=0.0, mat="wood")
    parts.append(block)
    for s in (-1, 1):
        pts = [(0, s * 0.09, -0.56), (0, s * 0.2, -0.53), (0, s * 0.31, -0.47), (0, s * 0.35, -0.43)]
        st = tube("pt%d" % s, pts, [0.045, 0.037, 0.02, 0.004], 7)
        displace(st, 0.006, 0.05, "VORONOI", seed=3 + s)
        paint(st, FLINT, ao=0.0, noise_amt=0.1, nscale=30, fn=lambda co, n: hexcol("b7bcc2") if abs(co.y) > 0.3 else None)
        parts.append(st)
    parts += lashing("l", -0.57, 0.052, ROPE, 2, cross=False)
    join(parts, "Tool")


def tool_iron_pickaxe():
    """Железная кирка: кованая изогнутая голова — длинный клюв и плоское долото, обойма на рукояти."""
    parts = handle("h", 0.12, -0.66, 0.031, 0.037, WOOD, swell=0.005)
    parts.append(wrap("w", 0.08, -0.1, 0.035, LEATHER, 5))
    beak = tube("bk", [(0, 0.0, -0.61), (0, 0.14, -0.6), (0, 0.27, -0.56), (0, 0.38, -0.48)], [0.042, 0.036, 0.022, 0.004], 4, twist=0.0)
    paint(beak, IRON, ao=0.0, fn=lambda co, n: IRON_EDGE if co.y > 0.33 else (1.1 if n.z > 0.5 else None))
    parts.append(beak)
    chisel = tube("ch", [(0, 0.0, -0.61), (0, -0.14, -0.6), (0, -0.27, -0.57), (0, -0.34, -0.54)], [0.042, 0.036, 0.03, 0.026], 4)
    paint(chisel, IRON, ao=0.0, fn=lambda co, n: 1.1 if n.z > 0.5 else None)
    parts.append(chisel)
    tipc = box("tc", (0, -0.35, -0.535), (0.055, 0.02, 0.012), bev=0.003)
    paint(tipc, IRON_EDGE, ao=0.0)
    parts.append(tipc)
    collar = cyl("cl", (0, 0, -0.67), 0.05, 0.05, 0.12, segs=10)
    paint(collar, shade(IRON, 0.85), ao=0.0, fn=lambda co, n: 1.15 if abs(co.z + 0.61) > 0.05 else None)
    parts.append(collar)
    join(parts, "Tool")


# ------------------------------------------------------------------ лопата
def tool_shovel():
    """Лопата: рукоять с поперечной ручкой сверху, кованая втулка, выгнутое полотно с ребром и упором для ноги."""
    parts = handle("h", 0.08, -0.56, 0.026, 0.03, WOOD, swell=0.003)
    grip = tube("gr", [(-0.075, 0, 0.13), (-0.04, 0, 0.165), (0.04, 0, 0.165), (0.075, 0, 0.13)], 0.017, 8)
    paint(grip, WOOD_DARK, ao=0.0)
    parts.append(grip)
    for s in (-1, 1):
        arm = tube("ar%d" % s, [(s * 0.075, 0, 0.13), (s * 0.03, 0, 0.07), (0, 0, 0.05)], 0.014, 6)
        paint(arm, WOOD_DARK, ao=0.0)
        parts.append(arm)
    sock = cyl("sk", (0, 0, -0.64), 0.034, 0.03, 0.12, segs=10)
    paint(sock, IRON, ao=0.0)
    parts.append(sock)
    # полотно: сетка в плоскости XZ, выгнута по Y (совок), заострённый закруглённый низ
    bm = bmesh.new()
    cols, rows = 9, 8
    grid = []
    for j in range(rows + 1):
        v = j / rows                              # 0 — у втулки, 1 — кончик
        half = 0.115 * (1.0 - 0.65 * smoothstep(0.62, 1.0, v) ** 1.5)
        row = []
        for i in range(cols + 1):
            u = (i / cols) * 2 - 1
            x = u * half
            z = -0.64 - v * 0.3 - (1 - u * u) * 0.0 * v
            y = 0.035 * (u * u) - 0.01 * v
            row.append(bm.verts.new((x, y, z)))
        grid.append(row)
    for j in range(rows):
        for i in range(cols):
            bm.faces.new((grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i]))
    sp = from_bm("bl", bm)
    solidify(sp, 0.012)
    paint(sp, STEEL, ao=0.0, fn=lambda co, n: STEEL_EDGE if co.z < -0.9 else (0.9 if n.y < 0 else None))
    parts.append(sp)
    rib = tube("rb", [(0, 0.004, -0.64), (0, 0.006, -0.82)], [0.013, 0.004], 6)
    paint(rib, shade(STEEL, 0.85), ao=0.0)
    parts.append(rib)
    step = box("st", (0, 0.012, -0.645), (0.235, 0.03, 0.012), bev=0.004)
    paint(step, IRON, ao=0.0)
    parts.append(step)
    join(parts, "Tool")


# ------------------------------------------------------------------ лейка
def tool_watering_can():
    """Лейка: стоячее ведёрко с ободом и двумя обручами, ручка дугой над крышкой (за неё и держат),
    длинный носик от дна вперёд-вверх с латунным ситечком, задняя ручка — наклонять при поливе."""
    blue = hexcol("5fb0e8")
    dark = hexcol("3f86c0")
    zc = -0.21
    body = lathe("b", [(0.0, -0.33), (0.1, -0.33), (0.115, -0.31), (0.12, -0.2), (0.112, -0.1), (0.075, -0.075), (0.0, -0.075)], 22)
    paint(body, blue, ao=0.0, fn=lambda co, n: 0.84 if abs(co.z + 0.3) < 0.01 or abs(co.z + 0.13) < 0.01 else None)
    parts = [body]
    for k, z in enumerate((-0.3, -0.13)):
        band = tube("bd%d" % k, [(math.cos(a) * 0.122, math.sin(a) * 0.122, z) for a in [i * math.pi / 11 for i in range(23)]], 0.007, 5, caps=False)
        paint(band, dark, ao=0.0)
        parts.append(band)
    lid = cyl("ld", (0, -0.03, -0.09), 0.045, 0.04, 0.02, segs=14)
    paint(lid, dark, ao=0.0)
    parts.append(lid)
    arch = tube("h", [(0, -0.08, -0.085), (0, -0.07, -0.02), (0, -0.035, 0.012), (0, 0.035, 0.012), (0, 0.07, -0.02), (0, 0.08, -0.085)], 0.014, 7)
    paint(arch, dark, ao=0.0)
    parts.append(arch)
    back = tube("bh", [(0, -0.115, -0.12), (0, -0.165, -0.17), (0, -0.165, -0.25), (0, -0.115, -0.29)], 0.012, 6)
    paint(back, dark, ao=0.0)
    parts.append(back)
    spout = tube("s", [(0, 0.1, -0.29), (0, 0.18, -0.24), (0, 0.27, -0.15), (0, 0.33, -0.08)], [0.024, 0.019, 0.015, 0.014], 8)
    paint(spout, dark, ao=0.0)
    parts.append(spout)
    rose = cyl("rs", (0, 0.33, -0.08), 0.016, 0.042, 0.045, (-0.75, 0, 0), 12)
    def holes(co, n):
        # дырочки ситечка — кружками по сетке (а не косыми полосами)
        if n.y < 0.4:
            return None
        fx, fz = (co.x * 220) % 1.0 - 0.5, (co.z * 220) % 1.0 - 0.5
        return 0.45 if fx * fx + fz * fz < 0.07 else None
    paint(rose, BRASS, ao=0.0, fn=holes)
    parts.append(rose)
    join(parts, "Tool")


# ------------------------------------------------------------------ сачок
def tool_net():
    """Сачок: бамбуковая палка с коленцами, проволочный обруч и сетка — кольца и нити."""
    parts = []
    shaft = tube("h", [(0, 0, 0.12), (0, 0, -0.76)], [0.02, 0.018], 10)
    paint(shaft, hexcol("d7b46a"), ao=0.0, fn=lambda co, n: hexcol("a8823e") if int((co.z + 2) * 9) % 3 == 0 and ((co.z + 2) * 9) % 1 < 0.25 else None)
    parts.append(shaft)
    for z in (0.02, -0.25, -0.52):
        node = cyl("n%d" % int(-z * 100), (0, 0, z - 0.008), 0.024, 0.024, 0.016, segs=10)
        paint(node, hexcol("b08a42"), ao=0.0)
        parts.append(node)
    parts.append(wrap("w", 0.1, -0.02, 0.022, hexcol("c8403a"), 3, 0.009))
    hoop_c = (0, 0, -0.9)
    R = 0.15
    hoop = tube("r", [(math.cos(a) * R, 0, hoop_c[2] + math.sin(a) * R) for a in [k * math.pi / 12 for k in range(25)]], 0.011, 6, caps=False)
    paint(hoop, hexcol("f2c24a"), ao=0.0)
    parts.append(hoop)
    neck = tube("nk", [(0, 0, -0.76), (0, 0, -0.75 - 0.0)], 0.02, 6)
    paint(neck, hexcol("f2c24a"), ao=0.0)
    parts.append(neck)
    # сетка: мешок вниз по +Y — кольца поменьше и нити от обруча к донышку
    depth = 0.2
    for k in range(1, 4):
        t = k / 4
        rr = R * (1 - t * 0.75)
        ring = tube("sr%d" % k, [(math.cos(a) * rr, depth * t, hoop_c[2] + math.sin(a) * rr) for a in [i * math.pi / 10 for i in range(21)]], 0.0035, 4, caps=False)
        paint(ring, hexcol("f4f1ea"), ao=0.0)
        parts.append(ring)
    for k in range(10):
        a = k * math.pi / 5
        pts = []
        for j in range(5):
            t = j / 4
            rr = R * (1 - t * 0.75)
            pts.append((math.cos(a) * rr, depth * t + 0.01 * t * t, hoop_c[2] + math.sin(a) * rr))
        th = tube("st%d" % k, pts, 0.0035, 4, caps=False)
        paint(th, hexcol("f4f1ea"), ao=0.0)
        parts.append(th)
    bottom = sphere("bt", (0, depth + 0.005, hoop_c[2]), R * 0.27, (1, 0.35, 1), segs=10, rings=6)
    paint(bottom, hexcol("f4f1ea"), ao=0.0)
    parts.append(bottom)
    join(parts, "Tool")


# ------------------------------------------------------------------ удочка
def tool_fishing_rod():
    """Удочка: пробковая рукоять, катушка с ручкой, бамбуковое удилище с коленцами, кольца, леска и поплавок."""
    parts = []
    cork = tube("ck", [(0, 0, 0.12), (0, 0, -0.12)], [0.028, 0.026], 10)
    paint(cork, hexcol("c89a62"), ao=0.0, noise_amt=0.2, nscale=60)
    parts.append(cork)
    rod_pts = [(0, 0, -0.12), (0, 0.07, -0.45), (0, 0.2, -0.82), (0, 0.4, -1.18)]
    rod = tube("r", rod_pts, [0.017, 0.013, 0.009, 0.004], 8)
    paint(rod, hexcol("c9cf5a"), ao=0.0, fn=lambda co, n: hexcol("8c9a3a") if ((-co.z * 8) % 1.0) < 0.12 else None)
    parts.append(rod)
    reel = cyl("rl", (-0.03, 0.035, -0.06), 0.045, 0.045, 0.035, (0, math.pi / 2, 0), 14)
    paint(reel, hexcol("6b6f75"), ao=0.0, fn=lambda co, n: hexcol("c8403a") if abs(n.x) > 0.7 else None)
    parts.append(reel)
    foot = tube("ft", [(0, 0.01, -0.03), (0, 0.035, -0.06), (0, 0.01, -0.09)], 0.008, 5)
    paint(foot, hexcol("6b6f75"), ao=0.0)
    parts.append(foot)
    crank = tube("cr", [(-0.05, 0.035, -0.06), (-0.055, 0.075, -0.05)], 0.006, 5)
    knob = sphere("kn", (-0.057, 0.08, -0.05), 0.012, segs=8, rings=5)
    paint(crank, hexcol("4a4d52"), ao=0.0)
    paint(knob, hexcol("f2ead8"), ao=0.0)
    parts += [crank, knob]
    for k, t in enumerate((0.3, 0.55, 0.78, 0.97)):
        # кольцо на удилище
        i = min(int(t * 3), 2)
        f = t * 3 - i
        a, b = rod_pts[i], rod_pts[i + 1]
        p = tuple(a[m] + (b[m] - a[m]) * f for m in range(3))
        g = tube("gd%d" % k, [(p[0] + math.cos(q) * 0.012, p[1] + 0.016 + math.sin(q) * 0.012, p[2]) for q in [j * math.pi / 5 for j in range(11)]], 0.0025, 4, caps=False)
        paint(g, hexcol("dfe4e8"), ao=0.0)
        parts.append(g)
    line_t = tube("ln", [(0, 0.405, -1.19), (0, 0.43, -1.3), (0, 0.44, -1.38)], 0.0018, 4)
    paint(line_t, hexcol("f4f4f4"), ao=0.0)
    parts.append(line_t)
    bob = sphere("bb", (0, 0.44, -1.4), 0.022, (1, 1, 1.3), segs=10, rings=7)
    paint(bob, hexcol("e8443a"), ao=0.0, fn=lambda co, n: hexcol("f4f1ea") if co.z < -1.4 else None)
    parts.append(bob)
    join(parts, "Tool")


# ------------------------------------------------------------------ лёд
def tool_ice_pick():
    """Ледоруб: рукоять в резиновой оплётке, петля темляка, стальная голова — зубчатый клюв и лопатка, штык снизу."""
    parts = handle("h", 0.12, -0.66, 0.026, 0.03, hexcol("4a6a8a"), swell=0.0)
    parts.append(wrap("w", 0.09, -0.12, 0.03, hexcol("2a3a4a"), 6, 0.012))
    strap = tube("st", [(0.0, 0.03, 0.0), (0.0, 0.09, -0.12), (0.0, 0.05, -0.26), (0.0, 0.03, -0.28)], 0.011, 5)
    paint(strap, hexcol("d8403a"), ao=0.0)
    parts.append(strap)
    # клюв: изогнутый, с зубцами по нижней кромке
    outline = [(-0.02, -0.6), (0.1, -0.61), (0.22, -0.64), (0.32, -0.71), (0.3, -0.715)]
    for k in range(6):
        y = 0.28 - k * 0.04
        outline += [(y, -0.705 + k * 0.009 + (0.012 if k % 2 == 0 else 0.0)), (y - 0.02, -0.69 + k * 0.009)]
    outline += [(0.05, -0.655), (-0.02, -0.65)]
    pick = blade("pk", outline, lambda y, z: 0.03 - 0.022 * smoothstep(0.05, 0.3, y), STEEL, STEEL_EDGE, lambda y, z: y > 0.27)
    parts.append(pick)
    adze = blade("ad", [(-0.02, -0.6), (-0.12, -0.585), (-0.17, -0.57), (-0.175, -0.64), (-0.12, -0.65), (-0.02, -0.65)],
                 lambda y, z: 0.065 - 0.045 * smoothstep(-0.05, -0.17, y), STEEL, STEEL_EDGE, lambda y, z: y < -0.16)
    parts.append(adze)
    head = box("hd", (0, -0.0, -0.625), (0.05, 0.06, 0.07), bev=0.01)
    paint(head, shade(STEEL, 0.85), ao=0.0)
    parts.append(head)
    spike = cyl("sp", (0, 0, -0.66), 0.03, 0.0, 0.1, (math.pi, 0, 0), 8)
    paint(spike, STEEL, ao=0.0)
    parts.append(spike)
    join(parts, "Tool")


def tool_ice_drill():
    """Ледовый бур: Т-образная ручка с деревянными рукоятками, вал и винтовой шнек, два ножа на конце."""
    parts = []
    shaft = tube("h", [(0, 0, 0.14), (0, 0, -0.82)], 0.02, 10)
    paint(shaft, hexcol("8f979e"), ao=0.0)
    parts.append(shaft)
    bar = tube("br", [(-0.24, 0, 0.14), (0.24, 0, 0.14)], 0.017, 8)
    paint(bar, hexcol("8f979e"), ao=0.0)
    parts.append(bar)
    for s in (-1, 1):
        g = tube("g%d" % s, [(s * 0.1, 0, 0.14), (s * 0.24, 0, 0.14)], 0.031, 10)
        paint(g, hexcol("c9a050"), ao=0.0, mat="wood")
        parts.append(g)
        cap = sphere("c%d" % s, (s * 0.245, 0, 0.14), 0.032, (0.5, 1, 1), segs=10, rings=6)
        paint(cap, hexcol("a8823e"), ao=0.0)
        parts.append(cap)
    # шнек: лента по винту вокруг вала
    bm = bmesh.new()
    inner, outer = [], []
    steps = 64
    for i in range(steps + 1):
        a = i * 0.42
        z = -0.32 - i * 0.0072
        inner.append(bm.verts.new((math.cos(a) * 0.02, math.sin(a) * 0.02, z)))
        outer.append(bm.verts.new((math.cos(a) * 0.072, math.sin(a) * 0.072, z - 0.006)))
    for i in range(steps):
        bm.faces.new((inner[i], outer[i], outer[i + 1], inner[i + 1]))
    flight = from_bm("fl", bm)
    solidify(flight, 0.006)
    paint(flight, hexcol("c9d2dc"), ao=0.0, fn=lambda co, n: 1.12 if n.z > 0.3 else 0.85)
    parts.append(flight)
    for s in (-1, 1):
        knife = box("k%d" % s, (s * 0.04, 0, -0.81), (0.07, 0.012, 0.03), (0, s * 0.35, 0), bev=0.004)
        paint(knife, STEEL_EDGE, ao=0.0)
        parts.append(knife)
    tip = cyl("tp", (0, 0, -0.82), 0.02, 0.0, 0.06, (math.pi, 0, 0), 8)
    paint(tip, STEEL, ao=0.0)
    parts.append(tip)
    join(parts, "Tool")


BUILDERS = {
    "tool_stone_axe": tool_stone_axe, "tool_iron_axe": tool_iron_axe,
    "tool_machete": tool_machete, "tool_iron_machete": tool_iron_machete,
    "tool_pickaxe": tool_pickaxe, "tool_iron_pickaxe": tool_iron_pickaxe,
    "tool_shovel": tool_shovel, "tool_watering_can": tool_watering_can, "tool_net": tool_net,
    "tool_fishing_rod": tool_fishing_rod, "tool_ice_pick": tool_ice_pick, "tool_ice_drill": tool_ice_drill,
}
