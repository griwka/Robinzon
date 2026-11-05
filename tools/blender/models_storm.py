"""Глава 4 — Грозовой остров: радист Тимур, гуси и гусятник, громоотвод, навес, метеостанция,
бункер (стены, ярусы, лестница, перила, лампа, люки), генератор, стол метеорологов, радиостанция,
гидросамолёт, кладбищенские камни, Башня громов, бот Стёпы, тыквы на грядке и растения острова:
кривое дерево, вереск, черничник. Плюс куча металлолома, песчаная яма, обвал и «стекляшка молнии».

Координаты: Blender (x, y, z) → Godot (x, z, −y). «Вперёд» в Godot (+Z) — это −Y в Blender."""
import math

from mathutils import Vector

from kit import (box, cyl, displace, empty, hexcol, ico, join, lathe, leaf, mix, paint, remesh, rnd, set_origin,
                 set_parent, shade, sphere, subsurf, tube)
from models_buildings import log, plank, rope_wrap, stone, thatch_cone

RUST = hexcol("a0623a")
IRON = hexcol("6b6f75")
STEEL = hexcol("8f979e")
COPPER = hexcol("d9884a")
VERDIGRIS = hexcol("5fb39a")
CONCRETE = hexcol("9a978e")
BUNKER = hexcol("7a7468")
DARK_STONE = hexcol("4e4a56")
OLIVE = hexcol("6b7a4a")
PAINT_GREEN = hexcol("4f7a5a")
GLASS = hexcol("bfe8f0")
SKIN = hexcol("d9a07a")
HEATHER = hexcol("b56fb8")


def _rust_fn(base=RUST):
    return lambda co, n: (shade(base, 0.75) if math.sin(co.x * 13 + co.y * 7 + co.z * 11) > 0.6
                          else (hexcol("c87a42") if math.sin(co.x * 5 - co.z * 9) > 0.85 else None))


def dense_panel(name, center, w, h, step=0.15, facing="-y"):
    """Плоская панель w × h с частой сеткой — на ней проступают узоры раскраски (кладка, знаки, настил).
    facing: "-y" — вертикальная, лицом к −Y (в Godot это +Z); "z" — горизонтальная, лицом вверх."""
    import bmesh
    from mathutils import Matrix
    from kit import from_bm, place
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=max(2, int(w / step)), y_segments=max(2, int(h / step)), size=0.5)
    bmesh.ops.scale(bm, vec=(w, h, 1.0), verts=bm.verts)
    if facing == "-y":
        bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(math.pi / 2, 3, "X"))
    ob = place(from_bm(name, bm, smooth=False), center)
    return ob


def _rivets(parts, pts, r=0.025, col=IRON):
    for p in pts:
        rv = sphere("rv", p, r, segs=8, rings=5)
        paint(rv, col, ao=0.0, noise_amt=0)
        parts.append(rv)


# ================================================================== радист Тимур
def timur():
    """Радист Тимур: около сорока, жилистый, в комбинезоне с пятнами мазута, наушники на шее,
    одна штанина подвёрнута — нога в лубке, в руке палка-костыль. Узлы Body и Head — как у всех жителей."""
    overall = hexcol("4a6a5a")
    shirt = hexcol("e8dcc0")
    body = lathe("tb", [(0.0, 0.08), (0.27, 0.1), (0.3, 0.35), (0.3, 0.7), (0.27, 0.95), (0.16, 1.05), (0.0, 1.07)], 20)
    subsurf(body, 1)
    paint(body, overall, ao=0.0, fn=lambda co, n: (hexcol("2a2a26") if math.sin(co.x * 17 + co.z * 9) > 0.93 else
                                                   (hexcol("c9a050") if (abs(co.x) < 0.02 and co.y > 0.2 and co.z > 0.6) else None)))
    parts = [body]
    # нагрудный карман и лямки комбинезона
    pocket = box("pk", (0.0, 0.27, 0.78), (0.2, 0.04, 0.16), bev=0.02)
    paint(pocket, shade(overall, 0.85), ao=0.0)
    parts.append(pocket)
    for sx in (-1, 1):
        strap = box("st", (sx * 0.12, 0.25, 0.92), (0.06, 0.05, 0.25))
        paint(strap, shade(overall, 0.8), ao=0.0)
        parts.append(strap)
        a = tube("ta", [(sx * 0.27, 0, 0.95), (sx * 0.36, 0.05, 0.72), (sx * 0.32, 0.12, 0.52)], [0.08, 0.07, 0.065], 10)
        paint(a, shirt, ao=0.0, fn=lambda co, n: 0.88 if int(co.z * 18) % 2 else None)
        hd = sphere("th", (sx * 0.31, 0.14, 0.48), 0.07)
        paint(hd, SKIN, ao=0.0, fn=lambda co, n: hexcol("3a3a36") if co.z < 0.45 else None)   # руки в мазуте
        parts += [a, hd]
    # ноги: левая — в лубке (доски и бинт)
    for sx in (-1, 1):
        leg = tube("tl", [(sx * 0.12, 0, 0.15), (sx * 0.12, 0.02, 0.03)], 0.09, 10)
        paint(leg, overall, ao=0.0)
        bt = lathe("tbt", [(0.0, 0.0), (0.11, 0.0), (0.11, 0.12), (0.0, 0.13)], 10, loc=(sx * 0.12, 0.04, 0), scale=(1, 1.4, 1))
        paint(bt, hexcol("3a2a1a"), ao=0.0)
        parts += [leg, bt]
    for k in range(2):
        sp = box("sp", (-0.12 + (k - 0.5) * 0.18, 0.02, 0.2), (0.03, 0.05, 0.36))
        paint(sp, hexcol("c99a5e"), ao=0.0)
        parts.append(sp)
    bandage = cyl("bd", (-0.12, 0.02, 0.1), 0.11, 0.11, 0.2, segs=12)
    paint(bandage, hexcol("f2ead3"), ao=0.0, fn=lambda co, n: 0.85 if int(co.z * 40) % 2 else None)
    parts.append(bandage)
    # костыль — палка с перекладиной
    crutch = tube("cr", [(0.42, 0.18, 0.0), (0.42, 0.16, 0.95)], 0.022, 6)
    paint(crutch, hexcol("8a5a32"), ao=0.0)
    cbar = tube("cb", [(0.36, 0.16, 0.95), (0.48, 0.16, 0.95)], 0.03, 6)
    paint(cbar, hexcol("6b4524"), ao=0.0)
    parts += [crutch, cbar]
    # наушники на шее
    for sx in (-1, 1):
        cup = cyl("hp", (sx * 0.17, 0.08, 1.02), 0.07, 0.07, 0.05, (0, math.pi / 2 * sx, 0), 12)
        paint(cup, hexcol("2a2a2a"), ao=0.0)
        parts.append(cup)
    band = tube("hb", [(math.cos(a) * 0.17, 0.08 + math.sin(a) * 0.17 * 0.3, 1.02 - math.sin(a) * 0.08) for a in
                       [k * math.pi / 8 for k in range(9)]], 0.018, 6, caps=False)
    paint(band, hexcol("3a3a3a"), ao=0.0)
    cable = tube("hc", [(0.17, 0.1, 1.0), (0.22, 0.2, 0.8), (0.1, 0.27, 0.75)], 0.008, 5)
    paint(cable, hexcol("1d1d1d"), ao=0.0)
    parts += [band, cable]
    b = join(parts, "Body")
    set_origin(b, (0, 0, 0))
    # голова: короткая стрижка ёжиком, щетина, широкая улыбка, очки на лбу
    hp = [sphere("hd", (0, 0, 1.36), 0.28, segs=26, rings=14)]
    paint(hp[0], SKIN, ao=0.0, fn=lambda co, n: (hexcol("8a6a5a") if (co.z < 1.3 and co.y > 0.05) else None))
    hair = sphere("hr", (0, -0.03, 1.45), 0.27, (1.0, 1.0, 0.75))
    displace(hair, 0.02, 0.05, "VORONOI")
    paint(hair, hexcol("2a2420"), ao=0.0, noise_amt=0.2, nscale=30)
    hp.append(hair)
    for sx in (-1, 1):
        w = sphere("w", (sx * 0.1, 0.24, 1.4), 0.05, (1, 0.42, 0.9))
        paint(w, hexcol("ffffff"), ao=0.0, noise_amt=0)
        i = sphere("i", (sx * 0.1, 0.26, 1.395), 0.03, (1, 0.4, 0.9))
        paint(i, hexcol("5a3a22"), ao=0.0, noise_amt=0)
        br = tube("br", [(sx * 0.04, 0.25, 1.48), (sx * 0.16, 0.22, 1.5)], 0.018, 6)
        paint(br, hexcol("2a2420"), ao=0.0)
        ear = sphere("er", (sx * 0.27, 0.0, 1.36), 0.06, (0.5, 0.8, 1.0))
        paint(ear, SKIN, ao=0.0)
        hp += [w, i, br, ear]
    # очки-«консервы» на лбу
    for sx in (-1, 1):
        g = cyl("gg", (sx * 0.09, 0.2, 1.56), 0.07, 0.07, 0.05, (-1.2, 0, 0), 14)
        paint(g, hexcol("c9a050"), ao=0.0, fn=lambda co, n: GLASS if n.y > 0.5 else None)
        hp.append(g)
    strap = tube("gs", [(math.cos(a) * 0.28, math.sin(a) * 0.28, 1.55) for a in [k * math.pi / 10 for k in range(11)]], 0.015, 5, caps=False)
    paint(strap, hexcol("3a2a1a"), ao=0.0)
    nose = sphere("ns", (0, 0.29, 1.34), 0.05, (0.9, 1.0, 0.8))
    paint(nose, shade(SKIN, 0.92), ao=0.0)
    mouth = tube("mo", [(-0.08, 0.255, 1.25), (0.0, 0.27, 1.23), (0.08, 0.255, 1.25)], 0.015, 6)
    paint(mouth, hexcol("7a2a22"), ao=0.0)
    hp += [strap, nose, mouth]
    h = join(hp, "Head")
    set_origin(h, (0, 0, 1.08))
    set_parent(h, b)


# ================================================================== гуси
def goose():
    """Белый гусь: длинная шея, оранжевый клюв и лапы. Узлы Body и Head (Head — с шеей)."""
    white = hexcol("f6f6ef")
    body = sphere("gb", (0, 0, 0.32), 0.22, (0.9, 1.35, 0.85), segs=22, rings=14)
    paint(body, white, ao=0.0, noise_amt=0.04, fn=lambda co, n: 0.9 if co.z < 0.24 else None)
    parts = [body]
    tail = cyl("gt", (0, -0.28, 0.36), 0.09, 0.0, 0.18, (-2.0, 0, 0), 8)
    paint(tail, shade(white, 0.95), ao=0.0)
    parts.append(tail)
    for sx in (-1, 1):
        w = sphere("gw", (sx * 0.17, -0.04, 0.36), 0.13, (0.3, 1.1, 0.6), (0.15, 0, 0))
        paint(w, hexcol("e8e8de"), ao=0.0, fn=lambda co, n: 0.85 if co.y < -0.12 else None)
        l = tube("gl", [(sx * 0.08, 0.02, 0.16), (sx * 0.08, 0.03, 0.02)], 0.018, 6)
        paint(l, hexcol("ff9a2a"), ao=0.0)
        foot = sphere("gf", (sx * 0.08, 0.08, 0.015), 0.05, (1.0, 1.4, 0.25))
        paint(foot, hexcol("ff8a1a"), ao=0.0)
        parts += [w, l, foot]
    b = join(parts, "Body")
    set_origin(b, (0, 0, 0))
    neck = tube("gn", [(0, 0.2, 0.4), (0, 0.27, 0.6), (0, 0.27, 0.78)], [0.07, 0.055, 0.055], 12)
    paint(neck, white, ao=0.0)
    hd = sphere("gh", (0, 0.3, 0.82), 0.075, (0.9, 1.25, 0.9))
    paint(hd, white, ao=0.0)
    beak = cyl("gk", (0, 0.38, 0.81), 0.035, 0.012, 0.12, (-math.pi / 2, 0, 0), 10)
    paint(beak, hexcol("ff8a1a"), ao=0.0)
    knob = sphere("gkn", (0, 0.37, 0.845), 0.025)
    paint(knob, hexcol("e8701a"), ao=0.0)
    hp = [neck, hd, beak, knob]
    for sx in (-1, 1):
        e = sphere("ge", (sx * 0.05, 0.35, 0.84), 0.014)
        paint(e, hexcol("1d1d1d"), ao=0.0, noise_amt=0)
        hp.append(e)
    h = join(hp, "Head")
    set_origin(h, (0, 0.2, 0.4))
    set_parent(h, b)


def goose_house():
    """Гусятник: домик с двускатной крышей, плетень, корыто с водой. Радиус ~1.6 м."""
    parts = []
    hut = box("gh", (0.6, 0.8, 0.45), (1.2, 1.0, 0.9), bev=0.03)
    paint(hut, hexcol("c99a5e"), ao=0.25, fn=lambda co, n: 0.85 if int(co.z * 8) % 2 else None)
    door = box("gd", (0.6, 0.29, 0.3), (0.45, 0.04, 0.5), bev=0.02)
    paint(door, hexcol("3a2a1a"), ao=0.0)
    parts += [hut, door]
    for sx in (-1, 1):
        roof = box("gr", (0.6 + sx * 0.33, 0.8, 1.05), (0.8, 1.2, 0.06), (0, sx * 0.62, 0), bev=0.02)
        paint(roof, hexcol("d6ad55"), ao=0.0, noise_amt=0.2, nscale=20, fn=lambda co, n: 0.85 if int(co.y * 12) % 2 else None)
        parts.append(roof)
    # плетень полукругом
    for k in range(11):
        a = math.pi * 0.15 + k * math.pi * 1.25 / 10
        p = (math.cos(a) * 1.5, math.sin(a) * 1.5 - 0.1)
        parts.append(log("gp", (p[0], p[1], 0), (p[0], p[1], 0.55), 0.04, rings=False))
    for z in (0.22, 0.45):
        pts = [(math.cos(a) * 1.5, math.sin(a) * 1.5 - 0.1, z) for a in [math.pi * 0.15 + k * math.pi * 1.25 / 20 for k in range(21)]]
        rail = tube("grl", pts, 0.025, 6)
        paint(rail, hexcol("a07040"), ao=0.0)
        parts.append(rail)
    trough = box("gtr", (-0.7, -0.4, 0.1), (0.7, 0.35, 0.2), bev=0.04)
    paint(trough, hexcol("8a5a32"), ao=0.0)
    water = box("gwa", (-0.7, -0.4, 0.19), (0.6, 0.27, 0.02))
    paint(water, hexcol("6fb8d8"), ao=0.0, noise_amt=0)
    straw = cyl("gs", (0.0, 0.2, 0.0), 0.5, 0.45, 0.06, segs=14, scale=(1.4, 1, 1))
    displace(straw, 0.03, 0.1)
    paint(straw, hexcol("e0c06a"), ao=0.0, noise_amt=0.3, nscale=25)
    parts += [trough, water, straw]
    join(parts, "GooseHouse")


# ================================================================== громоотвод и навес
def lightning_rod():
    """Громоотвод: железный шест 4 м с медным остриём, медная жила вниз, дощатое основание,
    ящик для аккумулятора у подножия."""
    parts = []
    base = box("lb", (0, 0, 0.08), (0.9, 0.9, 0.16), bev=0.03)
    paint(base, hexcol("a87a4a"), ao=0.2, fn=lambda co, n: 0.85 if int(co.x * 6) % 2 else None)
    pole = tube("lp", [(0, 0, 0.1), (0, 0, 3.9)], [0.06, 0.04], 10)
    paint(pole, IRON, ao=0.0, fn=_rust_fn(IRON))
    tip = cyl("lt", (0, 0, 3.9), 0.06, 0.0, 0.5, segs=10)
    paint(tip, COPPER, ao=0.0)
    ring = cyl("lr", (0, 0, 3.75), 0.12, 0.12, 0.05, segs=12)
    paint(ring, COPPER, ao=0.0)
    parts += [base, pole, tip, ring]
    for a in (0.0, 2.1, 4.2):   # растяжки
        st = tube("ls", [(0, 0, 2.6), (math.cos(a) * 0.85, math.sin(a) * 0.85, 0.12)], 0.01, 4)
        paint(st, STEEL, ao=0.0)
        parts.append(st)
    wire = tube("lw", [(0.07, 0, 3.75), (0.09, 0.02, 2.0), (0.12, 0.05, 0.6), (0.3, 0.2, 0.35)], 0.018, 6)
    paint(wire, COPPER, ao=0.0)
    box_ = box("lx", (0.32, 0.25, 0.3), (0.32, 0.26, 0.3), bev=0.03)
    paint(box_, PAINT_GREEN, ao=0.0, fn=lambda co, n: hexcol("ffd84a") if (n.y < -0.5 and abs(co.x - 0.32) < 0.05 and abs(co.z - 0.33) < 0.08) else None)
    parts += [wire, box_]
    join(parts, "LightningRod")


def shelter():
    """Навес: четыре бамбуковых столба, крыша из листьев на стропилах. Под ним можно стоять."""
    parts = []
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(log("sp", (sx * 1.05, sy * 1.05, 0), (sx * 1.05, sy * 1.05, 2.45), 0.07, col=hexcol("c9b060"), rings=False))
            parts.append(rope_wrap("sr", (sx * 1.05, sy * 1.05), 0.075, 2.2, 2))
    for sy in (-1, 1):
        parts.append(log("sb", (-1.25, sy * 1.05, 2.45), (1.25, sy * 1.05, 2.45), 0.06, col=hexcol("c9b060"), rings=False))
    for k in range(5):
        x = -1.0 + k * 0.5
        parts.append(log("sk", (x, -1.3, 2.4), (x, 1.3, 2.75 - abs(0) * 0.1), 0.035, col=hexcol("b8a050"), rings=False))
    join(parts, "Shelter")
    parts = []
    r = rnd(44)
    for k in range(26):
        x = r.uniform(-1.3, 1.3)
        y = r.uniform(-1.3, 1.3)
        lf = leaf("leaf", (x, y - 0.6, 2.55 + (y + 1.3) * 0.08), (r.uniform(-0.2, 0.2), 1.0, 0.1), 1.3, 0.28, droop=0.15, segs=6)
        paint(lf, shade(hexcol("5f9a3a"), r.uniform(0.85, 1.1)), ao=0.0, noise_amt=0.1)
        parts.append(lf)
    join(parts, "roof_leaf")


# ================================================================== метеостанция
def met_station():
    """Домик метеостанции «Ветер-3»: железобетон, плоская крыша, мачта антенны с растяжками,
    флюгер, будка для градусников, ящик с проводами. Футпринт 3.2 × 2.6 м."""
    parts = []
    house = box("mh", (0, 0, 1.3), (3.0, 2.4, 2.6), bev=0.06)
    paint(house, hexcol("c8c2b4"), ao=0.3, ao_h=0.6, noise_amt=0.1, nscale=4,
          fn=lambda co, n: (hexcol("8a8478") if co.z < 0.5 else (0.9 if math.sin(co.z * 3 + co.x * 2) > 0.92 else None)))
    roof = box("mr", (0, 0, 2.65), (3.3, 2.7, 0.15), bev=0.03)
    paint(roof, hexcol("6b6660"), ao=0.0)
    door = box("md", (-0.7, -1.22, 1.0), (0.8, 0.06, 1.9), bev=0.03)
    paint(door, hexcol("4f7a5a"), ao=0.0, fn=lambda co, n: IRON if abs(co.x + 0.4) < 0.04 and abs(co.z - 1.0) < 0.06 else None)
    win = box("mw", (0.7, -1.22, 1.5), (0.9, 0.06, 0.7), bev=0.02)
    paint(win, hexcol("3a4a5a"), ao=0.0, fn=lambda co, n: hexcol("e8dcc0") if (abs(co.x - 0.7) < 0.03 or abs(co.z - 1.5) < 0.03) else None)
    sign = box("ms", (0.0, -1.24, 2.25), (1.4, 0.04, 0.32), bev=0.01)
    paint(sign, hexcol("e8dcc0"), ao=0.0, fn=lambda co, n: hexcol("2a2a2a") if (n.y < -0.5 and abs(co.z - 2.25) < 0.06 and int(co.x * 12) % 2) else None)
    parts += [house, roof, door, win, sign]
    # мачта антенны (решётчатая) на крыше
    mx, my = 1.0, 0.6
    for k in range(3):
        a = k * 2 * math.pi / 3
        leg = tube("ml", [(mx + math.cos(a) * 0.25, my + math.sin(a) * 0.25, 2.7), (mx + math.cos(a) * 0.06, my + math.sin(a) * 0.06, 8.0)], 0.03, 6)
        paint(leg, hexcol("c0392b") if k == 0 else hexcol("e8e2d8"), ao=0.0, fn=lambda co, n: hexcol("c0392b") if int(co.z * 1.2) % 2 else hexcol("e8e2d8"))
        parts.append(leg)
    for z in range(3, 8):
        rr = 0.25 - (z - 2.7) / 5.3 * 0.19
        ring = tube("mrg", [(mx + math.cos(a) * rr, my + math.sin(a) * rr, z) for a in [i * 2 * math.pi / 6 for i in range(7)]], 0.015, 4, caps=False)
        paint(ring, hexcol("e8e2d8"), ao=0.0)
        parts.append(ring)
    for a in (0.5, 2.6, 4.7):
        gy = tube("mg", [(mx, my, 6.5), (mx + math.cos(a) * 2.4, my + math.sin(a) * 2.4, 0.02)], 0.008, 4)
        paint(gy, STEEL, ao=0.0)
        parts.append(gy)
    ant = tube("ma", [(mx - 0.8, my, 7.6), (mx + 0.8, my, 7.6)], 0.02, 5)
    paint(ant, STEEL, ao=0.0)
    light = sphere("mlt", (mx, my, 8.08), 0.07)
    paint(light, hexcol("ff4a3a"), ao=0.0, noise_amt=0)
    parts += [ant, light]
    # флюгер на углу крыши
    vp = tube("vp", [(-1.3, 1.0, 2.7), (-1.3, 1.0, 3.6)], 0.025, 6)
    paint(vp, IRON, ao=0.0)
    arrow = box("va", (-1.3, 1.0, 3.62), (0.04, 0.6, 0.05))
    paint(arrow, IRON, ao=0.0)
    fin = box("vf", (-1.3, 0.72, 3.65), (0.02, 0.18, 0.16))
    paint(fin, hexcol("c0392b"), ao=0.0)
    cups = []
    for a in (0.0, 2.1, 4.2):
        c = sphere("vc", (-1.3 + math.cos(a) * 0.22, 1.0 + math.sin(a) * 0.22, 3.4), 0.06, (1, 1, 0.6))
        paint(c, STEEL, ao=0.0)
        cups.append(c)
    parts += [vp, arrow, fin] + cups
    # будка с градусниками на ножках и ящик с проводами
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(log("bl", (2.3 + sx * 0.2, -0.6 + sy * 0.2, 0), (2.3 + sx * 0.2, -0.6 + sy * 0.2, 1.0), 0.03, col=hexcol("e8e2d8"), rings=False))
    booth = box("bt", (2.3, -0.6, 1.25), (0.55, 0.55, 0.55), bev=0.02)
    paint(booth, hexcol("f2ede2"), ao=0.0, fn=lambda co, n: 0.85 if int(co.z * 25) % 2 else None)
    broof = box("btr", (2.3, -0.6, 1.56), (0.65, 0.65, 0.06), bev=0.01)
    paint(broof, hexcol("e8e2d8"), ao=0.0)
    cab = box("cb", (-1.75, 0.2, 0.6), (0.4, 0.5, 1.2), bev=0.03)
    paint(cab, PAINT_GREEN, ao=0.2, fn=_rust_fn(PAINT_GREEN))
    parts += [booth, broof, cab]
    for k in range(4):
        parts.append(stone("ms", (-1.6 + k * 1.1, -1.5 - (k % 2) * 0.3, 0.1), 0.18, k, hexcol("8a8a8e")))
    join(parts, "MetStation")


# ================================================================== бункер
def _glyph_fn(base):
    """Древние знаки Хранителей на камне: круги, лучи и волны — чуть светлее камня."""
    def f(co, n):
        u = co.x
        v = co.z
        cell_u = (u + 6) % 1.5 - 0.75
        cell_v = (v % 1.5) - 0.75
        r = math.hypot(cell_u, cell_v)
        if abs(r - 0.42) < 0.035 and int((u + 6) / 1.5 + v / 1.5) % 3 == 0:
            return hexcol("c9b890")
        if abs(cell_v - 0.08 * math.sin(cell_u * 12)) < 0.03 and int((u + 6) / 1.5 + v / 1.5) % 3 == 1:
            return hexcol("b8a87a")
        row = int(v / 0.5)
        off = 0.4 if row % 2 else 0.0
        if (v % 0.5) < 0.03 or ((u + off + 6) % 0.8) < 0.03:
            return 0.72
        return 0.92 + 0.1 * ((row * 7 + int((u + off + 6) / 0.8) * 3) % 5) / 4
    return f


def bunker_wall():
    """Стена шахты Хранителей: панель 12 × 4.5 м из тёмного камня с вырезанными знаками (знаки — на −Y),
    поверх — провода метеорологов на скобах."""
    back = box("bw", (0, 0.2, 2.25), (12.0, 0.3, 4.5))
    paint(back, shade(BUNKER, 0.7), ao=0.0)
    face = dense_panel("bf", (0, 0.04, 2.25), 12.0, 4.5, 0.12)
    displace(face, 0.05, 0.2)
    paint(face, BUNKER, ao=0.25, ao_h=0.5, noise_amt=0.1, nscale=3, fn=_glyph_fn(BUNKER))
    parts = [back, face]
    pts = [(-6.0, -0.05, 3.6)] + [(-6 + k * 1.0, -0.06, 3.6 - 0.12 * math.sin(k * 1.3)) for k in range(1, 13)]
    for c, dz in ((hexcol("1d1d1d"), 0.0), (hexcol("8a2a22"), -0.08)):
        cable = tube("wc", [(p[0], p[1], p[2] + dz) for p in pts], 0.02, 5)
        paint(cable, c, ao=0.0)
        parts.append(cable)
    for k in range(6):
        br = box("wb", (-5.0 + k * 2.0, -0.06, 3.62), (0.06, 0.08, 0.2))
        paint(br, IRON, ao=0.0)
        parts.append(br)
    join(parts, "BunkerWall")


def bunker_ceiling():
    c = box("bc", (0, 0, 0.3), (12.0, 12.0, 0.6))
    displace(c, 0.05, 0.3)
    paint(c, shade(BUNKER, 0.8), ao=0.0, noise_amt=0.12, nscale=2)
    hatch = cyl("bh", (-4.6, 4.6, -0.02), 0.6, 0.6, 0.08, segs=16)
    paint(hatch, hexcol("e8d0a0"), ao=0.0, noise_amt=0)   # светлое пятно люка наверху
    join([c, hatch], "BunkerCeiling")


def bunker_deck():
    """Ярус: каменная плита 12 × 6.5 м, по ней — железный настил с заклёпками. Верх — на нуле."""
    slab = box("ds", (0, 0, -0.31), (12.0, 6.5, 0.6))
    paint(slab, shade(BUNKER, 0.8), ao=0.0, noise_amt=0.1)
    parts = [slab]
    for k in range(5):
        pl = dense_panel("dp", (-4.8 + k * 2.4, 0, 0.02), 2.3, 6.3, 0.1, facing="z")
        paint(pl, STEEL, ao=0.0, noise_amt=0.12, nscale=6,
              fn=lambda co, n: 0.8 if ((co.x * 6 + co.y * 6) % 1.0 < 0.15 or (co.x * 6 - co.y * 6) % 1.0 < 0.15)
              else (0.88 if math.sin(co.x * 3 + co.y * 5) > 0.7 else None))
        parts.append(pl)
    join(parts, "BunkerDeck")


def ladder():
    """Сегмент железной лестницы 1 м: две стойки и ступенька. Лестницу собирают из сегментов."""
    parts = []
    for sx in (-1, 1):
        rail = box("lr", (sx * 0.24, 0, 0.5), (0.05, 0.06, 1.0))
        paint(rail, IRON, ao=0.0, fn=_rust_fn(IRON))
        parts.append(rail)
    for z in (0.15, 0.5, 0.85):
        rung = tube("lg", [(-0.24, 0, z), (0.24, 0, z)], 0.02, 6)
        paint(rung, STEEL, ao=0.0)
        parts.append(rung)
    join(parts, "Ladder")


def bunker_rail():
    """Перила 1 м: стойка, два прута."""
    parts = [tube("rp", [(-0.5, 0, 0), (-0.5, 0, 1.1)], 0.03, 6)]
    for z in (0.55, 1.08):
        parts.append(tube("rr", [(-0.5, 0, z), (0.5, 0, z)], 0.025, 6))
    for p in parts:
        paint(p, hexcol("d9a520"), ao=0.0, fn=lambda co, n: hexcol("2a2a2a") if int((co.x + co.z) * 5) % 2 else None)
    join(parts, "Rail")


def bunker_chain():
    """Цепь поперёк проёма и табличка «Темно»."""
    parts = []
    for sx in (-1, 1):
        post = tube("cp", [(sx * 0.8, 0, 0), (sx * 0.8, 0, 1.1)], 0.04, 8)
        paint(post, hexcol("d9a520"), ao=0.0)
        parts.append(post)
    for k in range(16):
        t = k / 15
        x = -0.8 + 1.6 * t
        z = 1.0 - 0.22 * math.sin(math.pi * t)
        link = sphere("cl", (x, 0, z), 0.04, (1.6, 0.6, 1.0), (0, (k % 2) * 1.5, 0), segs=8, rings=5)
        paint(link, STEEL, ao=0.0)
        parts.append(link)
    sign = box("cs", (0, -0.03, 0.62), (0.6, 0.03, 0.32), bev=0.01)
    paint(sign, hexcol("f2d14a"), ao=0.0, fn=lambda co, n: hexcol("1d1d1d") if (abs(co.z - 0.62) < 0.09 and int(co.x * 14) % 2 and n.y < -0.5) else None)
    parts.append(sign)
    join(parts, "Chain")


def bunker_lamp():
    """Лампа в проволочной клетке на кабеле. Лампочка — светлое стекло."""
    cable = tube("lc", [(0, 0, 0.2), (0, 0, 1.0)], 0.012, 5)
    paint(cable, hexcol("1d1d1d"), ao=0.0)
    cap = cyl("lk", (0, 0, 0.15), 0.07, 0.05, 0.08, segs=10)
    paint(cap, IRON, ao=0.0)
    bulb = sphere("lb", (0, 0, 0.05), 0.08)
    paint(bulb, hexcol("fff2c8"), ao=0.0, noise_amt=0)
    parts = [cable, cap, bulb]
    for k in range(6):
        a = k * math.pi / 3
        w = tube("lw", [(math.cos(a) * 0.04, math.sin(a) * 0.04, 0.16), (math.cos(a) * 0.11, math.sin(a) * 0.11, 0.05),
                        (math.cos(a) * 0.04, math.sin(a) * 0.04, -0.07)], 0.007, 4)
        paint(w, IRON, ao=0.0)
        parts.append(w)
    join(parts, "Lamp")


def bunker_shelves():
    """Стеллаж метеорологов: банки, коробки, свёрнутые карты."""
    parts = []
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(box("sp", (sx * 0.9, sy * 0.25, 1.0), (0.05, 0.05, 2.0)))
    for z in (0.3, 0.9, 1.5, 1.95):
        parts.append(box("ss", (0, 0, z), (1.9, 0.55, 0.04)))
    for p in parts:
        paint(p, PAINT_GREEN, ao=0.0, fn=_rust_fn(PAINT_GREEN))
    r = rnd(9)
    for z in (0.32, 0.92, 1.52):
        x = -0.8
        while x < 0.75:
            w = r.uniform(0.15, 0.3)
            if r.random() < 0.5:
                o = cyl("sj", (x + w / 2, r.uniform(-0.1, 0.1), z), w * 0.4, w * 0.4, r.uniform(0.15, 0.3), segs=10)
                paint(o, r.choice([IRON, hexcol("c0392b"), hexcol("d9c08a")]), ao=0.0)
            else:
                o = box("sb", (x + w / 2, 0, z + 0.1), (w * 0.9, 0.4, 0.2), bev=0.01)
                paint(o, r.choice([hexcol("c9a26b"), hexcol("a8875a"), hexcol("e8dcc0")]), ao=0.0)
            parts.append(o)
            x += w + 0.04
    join(parts, "Shelves")


def bunker_crates():
    parts = []
    r = rnd(12)
    for i, (x, y, z, s) in enumerate(((0, 0, 0.3, 0.6), (0.65, 0.1, 0.25, 0.5), (0.2, 0.05, 0.85, 0.5))):
        c = box("cr", (x, y, z), (s, s, s), (0, 0, r.uniform(-0.2, 0.2)), bev=0.02)
        paint(c, hexcol("8a7a5a"), ao=0.0, fn=lambda co, n: 0.8 if (abs(co.x) % 0.3 < 0.03) else None)
        parts.append(c)
    drum = cyl("dr", (-0.6, 0.3, 0.0), 0.28, 0.28, 0.85, segs=16)
    paint(drum, hexcol("3a5a7a"), ao=0.0, fn=lambda co, n: shade(hexcol("3a5a7a"), 0.7) if abs(co.z % 0.28) < 0.03 else _rust_fn(hexcol("3a5a7a"))(co, n))
    parts.append(drum)
    join(parts, "Crates")


def bunker_hatch():
    """Люк в бункер на поверхности: бетонное кольцо, откинутая стальная крышка, поручни лестницы."""
    ring = lathe("hr", [(0.55, 0.0), (0.75, 0.0), (0.72, 0.25), (0.55, 0.25)], 24)
    paint(ring, CONCRETE, ao=0.0, noise_amt=0.15, nscale=6)
    hole = cyl("hh", (0, 0, 0.02), 0.56, 0.56, 0.02, segs=24)
    paint(hole, hexcol("120f0c"), ao=0.0, noise_amt=0)
    lid = cyl("hl", (0, 0.62, 0.25), 0.6, 0.6, 0.08, (math.radians(-105), 0, 0), 24)
    paint(lid, PAINT_GREEN, ao=0.0, fn=lambda co, n: 0.75 if int(abs(co.x) * 8) % 3 == 0 else _rust_fn(PAINT_GREEN)(co, n))
    wheel = tube("hw", [(math.cos(a) * 0.22, 0.68 + 0.05, 0.3 + 0.0 + math.sin(a) * 0.22 + 0.25) for a in [k * math.pi / 8 for k in range(17)]], 0.02, 5, caps=False)
    paint(wheel, hexcol("c0392b"), ao=0.0)
    parts = [ring, hole, lid, wheel]
    for sx in (-1, 1):
        h = tube("hg", [(sx * 0.25, -0.5, 0.0), (sx * 0.25, -0.5, 0.75), (sx * 0.25, -0.35, 0.85), (sx * 0.25, -0.2, 0.75), (sx * 0.25, -0.2, 0.1)], 0.025, 6)
        paint(h, hexcol("d9a520"), ao=0.0)
        parts.append(h)
    join(parts, "Hatch")


def bunker_hatch_inner():
    """Внизу у выхода: жёлтая плита с полосами и стрелкой вверх."""
    pl = box("hp", (0, 0, 0.02), (1.2, 1.2, 0.04), bev=0.01)
    paint(pl, hexcol("f2d14a"), ao=0.0, fn=lambda co, n: hexcol("1d1d1d") if ((co.x + co.y) % 0.3 < 0.12 and (abs(co.x) > 0.45 or abs(co.y) > 0.45)) else None)
    ar = box("ha", (0, 0, 0.05), (0.18, 0.5, 0.02))
    head = cyl("hh", (0, 0.32, 0.04), 0.2, 0.0, 0.02, (0, 0, 0), 3)
    for o in (ar, head):
        paint(o, hexcol("1d1d1d"), ao=0.0)
    join([pl, ar, head], "HatchInner")


# ================================================================== сюжетные места бункера
def _generator(broken):
    parts = []
    body = box("gb", (0, 0, 0.55), (1.3, 0.8, 1.1), bev=0.06)
    paint(body, PAINT_GREEN, ao=0.25, fn=_rust_fn(PAINT_GREEN) if broken else (lambda co, n: 0.9 if int(co.z * 10) % 2 else None))
    parts.append(body)
    for sx in (-1, 1):
        fly = cyl("gf", (sx * 0.7, 0, 0.55), 0.38, 0.38, 0.1, (0, math.pi / 2 * sx, 0), 20)
        paint(fly, IRON, ao=0.0, fn=lambda co, n: 0.7 if int(math.atan2(co.y, co.z) * 3) % 2 else None)
        parts.append(fly)
    for k, x in enumerate((-0.35, 0.0, 0.35)):
        d = cyl("gd", (x, -0.41, 0.8), 0.11, 0.11, 0.03, (math.pi / 2, 0, 0), 14)
        paint(d, hexcol("f2ede2"), ao=0.0, fn=lambda co, n: hexcol("c0392b") if (abs(co.z - 0.8 - 0.04) < 0.012 and n.y < -0.5) else None)
        parts.append(d)
    switch = box("gs", (0.45, -0.42, 0.35), (0.12, 0.05, 0.2))
    paint(switch, hexcol("1d1d1d"), ao=0.0)
    parts.append(switch)
    for k in range(3):   # гнёзда для аккумуляторов/предохранителей
        f = box("gq", (-0.35 + k * 0.3, -0.42, 0.35), (0.14, 0.04, 0.12))
        paint(f, hexcol("e8b42a") if not broken else hexcol("3a2a22"), ao=0.0)
        parts.append(f)
    if broken:
        for k in range(4):
            w = tube("gw", [(0.2 + k * 0.1, 0.42, 0.9), (0.4 + k * 0.08, 0.7, 0.6 - k * 0.1), (0.3 + k * 0.1, 0.9, 0.05)], 0.02, 5)
            paint(w, hexcol("2a2a2a"), ao=0.0)
            parts.append(w)
        soot = sphere("gso", (0, -0.25, 1.05), 0.35, (1.2, 0.6, 0.3))
        paint(soot, hexcol("2a2622"), ao=0.0)
        parts.append(soot)
    else:
        for c, x in ((hexcol("1d1d1d"), 0.2), (hexcol("c0392b"), 0.3)):
            w = tube("gw", [(x, 0.42, 0.9), (x + 0.2, 0.8, 1.2), (x + 0.3, 1.5, 3.0)], 0.02, 5)
            paint(w, c, ao=0.0)
            parts.append(w)
        lamp = sphere("gl", (-0.5, -0.42, 1.0), 0.05)
        paint(lamp, hexcol("7aff7a"), ao=0.0, noise_amt=0)
        parts.append(lamp)
    join(parts, "Generator")


def generator_broken():
    _generator(True)


def generator():
    _generator(False)


def station_desk():
    """Стол метеорологов: железный стол, барометр, лампа, журнал в клеёнке, стул."""
    parts = [box("dt", (0, 0, 0.78), (1.6, 0.8, 0.05), bev=0.01)]
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(box("dl", (sx * 0.74, sy * 0.34, 0.39), (0.05, 0.05, 0.78)))
    drawers = box("dd", (0.5, 0, 0.55), (0.5, 0.7, 0.4), bev=0.01)
    parts.append(drawers)
    for p in parts:
        paint(p, PAINT_GREEN, ao=0.0, fn=_rust_fn(PAINT_GREEN))
    book = box("db", (-0.3, 0.0, 0.83), (0.42, 0.3, 0.06), (0, 0, 0.2), bev=0.01)
    paint(book, hexcol("2f4a6a"), ao=0.0, fn=lambda co, n: hexcol("f2e2b8") if n.z < 0.5 and abs(n.z) < 0.5 else None)
    baro = cyl("dbr", (0.35, 0.1, 0.81), 0.13, 0.13, 0.05, (0, 0, 0), 18)
    paint(baro, hexcol("c9a050"), ao=0.0, fn=lambda co, n: hexcol("f2ede2") if n.z > 0.5 and math.hypot(co.x - 0.35, co.y - 0.1) < 0.1 else None)
    lamp = tube("dla", [(-0.65, 0.25, 0.8), (-0.65, 0.25, 1.15), (-0.5, 0.1, 1.25)], 0.015, 6)
    paint(lamp, IRON, ao=0.0)
    shade_ = cyl("dls", (-0.48, 0.08, 1.15), 0.06, 0.12, 0.12, segs=12)
    paint(shade_, PAINT_GREEN, ao=0.0)
    chair = box("dc", (0, -0.6, 0.45), (0.45, 0.45, 0.05))
    back = box("dcb", (0, -0.82, 0.75), (0.45, 0.04, 0.55))
    for o in (chair, back):
        paint(o, hexcol("8a5a32"), ao=0.0)
    parts = parts + [book, baro, lamp, shade_, chair, back]
    for sx in (-1, 1):
        for sy in (-1, 1):
            l = box("dcl", (sx * 0.2, -0.6 + sy * 0.2, 0.22), (0.04, 0.04, 0.44))
            paint(l, hexcol("6b4524"), ao=0.0)
            parts.append(l)
    join(parts, "StationDesk")


def _radio(broken):
    """Радиостанция: железная стойка с панелями, ручки, шкала, лампы сверху, микрофон, наушники."""
    parts = []
    rack = box("rr", (0, 0, 0.75), (1.3, 0.55, 1.5), bev=0.03)
    paint(rack, hexcol("5a5e52"), ao=0.2, fn=_rust_fn(hexcol("5a5e52")) if broken else None)
    parts.append(rack)
    dial = box("rd", (0, -0.29, 1.1), (0.8, 0.03, 0.22), bev=0.01)
    paint(dial, hexcol("f2d48a") if not broken else hexcol("8a7a5a"), ao=0.0,
          fn=lambda co, n: hexcol("1d1d1d") if (n.y < -0.5 and int((co.x + 1) * 25) % 4 == 0) else None)
    parts.append(dial)
    for k in range(5):
        kn = cyl("rk", (-0.45 + k * 0.22, -0.3, 0.75), 0.06, 0.05, 0.05, (math.pi / 2, 0, 0), 12)
        paint(kn, hexcol("1d1d1d"), ao=0.0)
        parts.append(kn)
    meter = cyl("rm", (0.4, -0.29, 0.45), 0.1, 0.1, 0.02, (math.pi / 2, 0, 0), 16)
    paint(meter, hexcol("f2ede2"), ao=0.0)
    parts.append(meter)
    for k in range(4):   # лампы на крышке
        x = -0.4 + k * 0.27
        if broken and k in (1, 2):
            stub = cyl("rs", (x, 0.05, 1.5), 0.05, 0.05, 0.06, segs=10)
            paint(stub, hexcol("2a2622"), ao=0.0)
            parts.append(stub)
            continue
        tb = lathe("rt", [(0.0, 1.5), (0.05, 1.5), (0.05, 1.62), (0.045, 1.68), (0.0, 1.7)], 12, loc=(x, 0.05, 0))
        paint(tb, hexcol("ffb36a") if not broken else hexcol("8a8070"), ao=0.0, noise_amt=0)
        parts.append(tb)
    mic = tube("rmc", [(0.5, -0.5, 0.0), (0.5, -0.5, 0.9), (0.4, -0.45, 1.05)], 0.015, 6)
    paint(mic, IRON, ao=0.0)
    head = sphere("rmh", (0.38, -0.44, 1.07), 0.05, (1, 1, 1.2))
    paint(head, hexcol("2a2a2a"), ao=0.0)
    parts += [mic, head]
    if broken:
        soot = sphere("rso", (0, -0.1, 1.45), 0.4, (1.4, 0.8, 0.25))
        paint(soot, hexcol("2a2622"), ao=0.0)
        parts.append(soot)
    else:
        for k in range(3):
            w = tube("rw", [(-0.6 + k * 0.1, 0.28, 1.4), (-0.7 + k * 0.1, 0.6, 2.2), (-0.5 + k * 0.1, 0.4, 3.5)], 0.02, 5)
            paint(w, hexcol("8a2a22") if k == 1 else hexcol("1d1d1d"), ao=0.0)
            parts.append(w)
    join(parts, "Radio")


def radio_broken():
    _radio(True)


def radio():
    _radio(False)


# ================================================================== остров
def seaplane():
    """Гидросамолёт 1958 года: ржавый фюзеляж наполовину в воде, крыло задрано вверх, поплавок, винт.
    Начало координат — на уровне воды."""
    parts = []
    fus = lathe("sf", [(0.0, -3.2), (0.35, -3.0), (0.65, -1.8), (0.7, 0.0), (0.6, 1.6), (0.3, 2.6), (0.0, 2.8)], 20,
                rot=(math.pi / 2 + 0.15, 0.25, 0), loc=(0, 0, -0.2))
    displace(fus, 0.04, 0.2)
    paint(fus, hexcol("8fa0a8"), ao=0.0, fn=lambda co, n: (RUST if math.sin(co.y * 3 + co.x * 9 + co.z * 5) > 0.3 else
                                                         (hexcol("2f4a6a") if abs(co.z - 0.0) < 0.06 else None)))
    parts.append(fus)
    wing = box("sw", (0.0, -0.2, 0.6), (6.5, 1.2, 0.12), (0.0, 0.45, 0.1), bev=0.04)
    paint(wing, hexcol("a0aab0"), ao=0.0, fn=lambda co, n: RUST if math.sin(co.x * 4 + co.y * 6) > 0.4 else (0.85 if int(co.x * 3) % 2 else None))
    parts.append(wing)
    tail = box("st", (0, 2.8, 1.0), (0.1, 0.9, 1.2), (0.15, 0, 0), bev=0.03)
    paint(tail, hexcol("8fa0a8"), ao=0.0, fn=lambda co, n: hexcol("c0392b") if co.z > 1.3 else _rust_fn(hexcol("8fa0a8"))(co, n))
    parts.append(tail)
    flt = lathe("sp", [(0.0, -1.2), (0.22, -0.9), (0.25, 0.0), (0.18, 0.9), (0.0, 1.1)], 14, rot=(math.pi / 2, 0, 0), loc=(1.6, 0.0, -0.1))
    paint(flt, RUST, ao=0.0, fn=_rust_fn())
    parts.append(flt)
    prop = box("spp", (0.15, -3.25, 0.3), (1.4, 0.08, 0.14), (0, 0.3, 0.6))
    paint(prop, hexcol("3a3a3a"), ao=0.0)
    parts.append(prop)
    for k in range(5):
        parts.append(stone("sr", (-1.5 + k * 0.9, 1.5 - (k % 2) * 2.6, -0.35), 0.35, k, hexcol("6a6e72")))
    join(parts, "Seaplane")


def graves():
    """Четыре камня с выбитыми именами и низкая каменная ограда. Место для пятого — пустое."""
    parts = []
    for k in range(4):
        x = -1.2 + k * 0.8
        st_ = box("gs", (x, 0.3, 0.38), (0.45, 0.16, 0.76), (0.05 * (k - 1.5), 0, 0.04 * k), bev=0.05)
        displace(st_, 0.02, 0.2)
        paint(st_, hexcol("9a9690"), ao=0.2, noise_amt=0.12, nscale=6,
              fn=lambda co, n: (hexcol("5a5650") if (n.y < -0.5 and 0.35 < co.z < 0.65 and int(co.z * 30) % 3 == 0) else
                                (hexcol("6f8a4a") if co.z > 0.7 and n.z > 0.5 else None)))
        parts.append(st_)
        fl = sphere("gf", (x + 0.05, 0.05, 0.05), 0.07, (1, 1, 0.5))
        paint(fl, hexcol("e8d84a") if k % 2 else hexcol("ffffff"), ao=0.0)
        parts.append(fl)
    empty_ = cyl("ge", (1.95, 0.3, 0.0), 0.3, 0.3, 0.03, segs=12, scale=(1.0, 0.5, 1))
    paint(empty_, hexcol("6a5a42"), ao=0.0)
    parts.append(empty_)
    for k in range(9):
        a = k / 8
        x = -1.7 + a * 4.0
        parts.append(stone("gw", (x, -0.45, 0.1), 0.17, k, hexcol("8a8a8e")))
    join(parts, "Graves")


def _tower(restored):
    """Башня громов: чёрный камень, медный шпиль (позеленевший), чаша; у починенной — медная жила
    от шпиля к чаше и стеклянный колпак над чашей. FirePoint — где игра зажигает огонь."""
    parts = []
    tower = lathe("tw", [(1.8, 0.0), (1.7, 0.5), (1.4, 3.5), (1.2, 7.0), (1.0, 9.0), (1.3, 9.3), (1.3, 9.6), (0.0, 9.6)], 18)
    displace(tower, 0.08, 0.5, "VORONOI")
    paint(tower, DARK_STONE, ao=0.3, ao_h=1.2, noise_amt=0.12, nscale=3,
          fn=lambda co, n: (hexcol("8a8296") if (co.z * 1.6) % 1.0 < 0.06 else
                            (hexcol("c9b890") if (abs(math.atan2(co.y, co.x) - 1.2) < 0.08 and int(co.z) % 2) else None)))
    parts.append(tower)
    door = box("dr", (0, -1.55, 0.9), (0.8, 0.4, 1.7), bev=0.05)
    paint(door, hexcol("16141a"), ao=0.0)
    parts.append(door)
    for k in range(4):   # каменные «рёбра» к шпилю
        a = k * math.pi / 2 + math.pi / 4
        rib = tube("rb", [(math.cos(a) * 1.1, math.sin(a) * 1.1, 9.6), (math.cos(a) * 0.5, math.sin(a) * 0.5, 11.0), (0, 0, 11.6)], 0.12, 6)
        paint(rib, shade(DARK_STONE, 1.1), ao=0.0)
        parts.append(rib)
    spire = cyl("sp", (0, 0, 11.4), 0.18, 0.0, 2.2, segs=12)
    paint(spire, VERDIGRIS if not restored else COPPER, ao=0.0, fn=lambda co, n: (COPPER if (not restored and math.sin(co.z * 8) > 0.6) else None))
    parts.append(spire)
    for k in range(6):
        a = 2 * math.pi * k / 6 + 0.2
        parts.append(stone("rbs", (math.cos(a) * 2.3, math.sin(a) * 2.3, 0.15), 0.4, k, shade(DARK_STONE, 1.2)))
    if not restored:
        torn = tube("tw2", [(0.15, 0.0, 11.4), (0.6, 0.2, 10.6), (0.9, 0.5, 10.4)], 0.03, 5)
        paint(torn, VERDIGRIS, ao=0.0)
        parts.append(torn)
    else:
        wire = tube("cw", [(0.12, 0, 11.6), (0.5, -0.1, 10.8), (0.75, -0.1, 10.2), (0.6, 0.0, 9.95)], 0.035, 6)
        paint(wire, COPPER, ao=0.0)
        parts.append(wire)
    t = join(parts, "StormTower")
    bowl = lathe("bw", [(0.0, 9.6), (0.6, 9.65), (0.85, 10.0), (0.75, 10.05), (0.0, 9.8)], 18)
    paint(bowl, hexcol("6b5a3a"), ao=0.0)
    bowl.name = "Bowl"
    set_parent(bowl, t)
    if restored:
        dome = lathe("dm", [(0.82, 10.02), (0.8, 10.4), (0.6, 10.8), (0.3, 11.0), (0.0, 11.05)], 18)
        paint(dome, GLASS, ao=0.0, noise_amt=0)
        set_parent(dome, t)
        frame = tube("df", [(math.cos(a) * 0.83, math.sin(a) * 0.83, 10.03) for a in [k * math.pi / 8 for k in range(17)]], 0.03, 5, caps=False)
        paint(frame, COPPER, ao=0.0)
        set_parent(frame, t)
    empty("FirePoint", (0, 0, 9.9), t)


def storm_tower_ruin():
    _tower(False)


def storm_tower():
    _tower(True)


# ================================================================== бот Стёпы
def _boat(wreck):
    """Бот: деревянный корпус 4.2 м, мачта с шерстяным парусом, кирпичи в трюме. Нос — в +Y Blender (−Z Godot)."""
    parts = []
    hull_col = hexcol("3f6a8a")
    prof = [(0.0, -2.1), (0.55, -1.8), (0.85, -0.8), (0.9, 0.4), (0.7, 1.5), (0.0, 2.2)]
    for i, side in enumerate((-1, 1)):
        pts = []
        for (w, y) in prof:
            pts.append((side * w, y))
        for k in range(len(pts) - 1):
            a = pts[k]
            b = pts[k + 1]
            if wreck and side == 1 and k == 2 and z1 > 0.6:
                continue   # пробоина в борту
            for z0, z1 in ((0.2, 0.45), (0.45, 0.7)):
                mid = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)
                ln = math.hypot(b[0] - a[0], b[1] - a[1])
                ang = math.atan2(b[1] - a[1], b[0] - a[0])
                pl = box("hp", (mid[0] * (0.85 if z0 < 0.4 else 1.0), mid[1], (z0 + z1) / 2), (ln + 0.04, 0.08, z1 - z0 - 0.01),
                         (0, 0, ang))
                paint(pl, hull_col if z1 > 0.6 else hexcol("e8e2d8"), ao=0.0, noise_amt=0.1,
                      fn=(lambda co, n: RUST if wreck and math.sin(co.y * 7 + co.z * 13) > 0.7 else None))
                parts.append(pl)
    keel = tube("kl", [(0, -2.0, 0.25), (0, -1.0, 0.05), (0, 1.0, 0.05), (0, 2.15, 0.6)], 0.08, 8)
    paint(keel, hexcol("6b4524"), ao=0.0)
    deck = box("dk", (0, -0.3, 0.3), (1.4, 2.6, 0.06))
    paint(deck, hexcol("c99a5e"), ao=0.0, fn=lambda co, n: 0.85 if int(co.x * 8) % 2 else None)
    parts += [keel, deck]
    for k in range(6 if not wreck else 2):   # кирпичный балласт
        br = box("bk", (-0.3 + (k % 3) * 0.3, -0.6 + (k // 3) * 0.22, 0.4), (0.26, 0.12, 0.1), bev=0.01)
        paint(br, hexcol("b8583a"), ao=0.0)
        parts.append(br)
    mast_h = 3.2 if not wreck else 1.6
    mast = tube("ms", [(0, 0.3, 0.3), (0, 0.3, 0.3 + mast_h)], [0.07, 0.05], 8)
    paint(mast, hexcol("8a5a32"), ao=0.0)
    parts.append(mast)
    if not wreck:
        boom = tube("bm", [(0, 0.3, 0.9), (0, -1.6, 0.95)], 0.04, 6)
        paint(boom, hexcol("8a5a32"), ao=0.0)
        import bmesh
        from kit import from_bm, solidify
        bm = bmesh.new()
        v = [bm.verts.new(p) for p in ((0, 0.25, 0.95), (0, 0.25, 3.4), (0, -1.55, 1.0))]
        bm.faces.new(v)
        sail = from_bm("sl", bm)
        solidify(sail, 0.02)
        paint(sail, hexcol("e8ddc8"), ao=0.0, fn=lambda co, n: 0.88 if int(co.z * 6) % 2 else (hexcol("c0392b") if co.z > 3.0 else None))
        parts += [boom, sail]
        for k in range(2):
            oar = tube("or", [(-0.9 - k * 0.1, -0.6 + k * 0.5, 0.75), (-1.8, 0.4 + k * 0.5, 0.2)], 0.03, 6)
            paint(oar, hexcol("c99a5e"), ao=0.0)
            parts.append(oar)
        parts.append(rope_wrap("rp", (0.0, 0.3), 0.08, 0.6, 3))
    else:
        rag = leaf("rg", (0, 0.3, 1.5), (0.6, -0.2, -0.8), 0.8, 0.3, droop=0.6)
        paint(rag, hexcol("8a7a5a"), ao=0.0)
        parts.append(rag)
        for k in range(3):
            parts.append(plank("lp", (1.3 + k * 0.2, -0.5 + k * 0.6, 0.05), (0.9, 0.18, 0.06), (0, 0, 0.6 * k), col=hexcol("3f6a8a"), seed=k))
    b = join(parts, "Boat")
    if wreck:
        b.rotation_euler = (0, 0.12, 0)   # чуть завалился набок на песке


def stepa_boat_wreck():
    _boat(True)


def stepa_boat():
    _boat(False)


# ================================================================== растения и мелочь
def crop_pumpkin():
    """Тыквы на грядке: три спелые тыквы, плети и широкие листья."""
    parts = []
    for i, (x, y, s) in enumerate(((-0.4, 0.05, 1.0), (0.38, -0.12, 0.85), (0.05, 0.22, 0.7))):
        pts = []
        for k in range(8):
            a = k * math.pi / 4
            pts.append(sphere("pk", (x + math.cos(a) * 0.1 * s, y + math.sin(a) * 0.1 * s, 0.38 * s), 0.17 * s, (0.75, 0.75, 1.0)))
        pk = join(pts, "pk")
        remesh(pk, 0.035, 2)
        paint(pk, hexcol("f08a24"), ao=0.25, ao_h=0.2, noise_amt=0.06,
              fn=lambda co, n: 0.85 if math.sin(math.atan2(co.y, co.x) * 8) > 0.7 else None)
        stem = tube("ps", [(x, y, 0.52 * s + 0.15), (x + 0.04, y + 0.02, 0.62 * s + 0.15)], 0.025, 6)
        paint(stem, hexcol("6b8a3a"), ao=0.0)
        parts += [pk, stem]
    vine = tube("pv", [(-0.6, 0.0, 0.25), (-0.2, 0.25, 0.27), (0.2, 0.0, 0.26), (0.6, -0.2, 0.25)], 0.02, 6)
    paint(vine, hexcol("5a8a3a"), ao=0.0)
    parts.append(vine)
    r = rnd(8)
    leaves = []
    for k in range(9):
        x = r.uniform(-0.6, 0.6)
        y = r.uniform(-0.3, 0.3)
        lf = leaf("leaf", (x, y, 0.25), (r.uniform(-1, 1), r.uniform(-1, 1), 0.6), 0.32, 0.18, droop=0.5)
        paint(lf, shade(hexcol("4f9a4a"), r.uniform(0.85, 1.1)), ao=0.0)
        leaves.append(lf)
    join(parts, "Crop")
    join(leaves, "crop_leaf")


def _crooked(seed):
    """Кривое дерево, наклонённое ветром: изогнутый ствол, плоская крона, вытянутая в одну сторону."""
    r = rnd(seed)
    lean = r.uniform(0.6, 1.0)
    pts = [(0, 0, 0), (0.1, 0.0, 0.8), (0.4 * lean, 0.1, 1.6), (0.9 * lean, 0.0, 2.3), (1.5 * lean, -0.1, 2.8)]
    trunk = tube("tr", pts, [0.22, 0.18, 0.14, 0.11, 0.08], 10)
    paint(trunk, hexcol("6b5040"), ao=0.2, noise_amt=0.15, nscale=8, fn=lambda co, n: 0.8 if math.sin(co.z * 20 + co.x * 5) > 0.7 else None)
    parts = [trunk]
    br = tube("br", [(0.4 * lean, 0.1, 1.6), (0.1, 0.6, 2.3), (0.3, 0.9, 2.6)], [0.08, 0.06, 0.04], 8)
    paint(br, hexcol("6b5040"), ao=0.0)
    parts.append(br)
    crown = []
    for k in range(7):
        x = 0.8 * lean + r.uniform(-0.6, 1.4)
        y = r.uniform(-0.7, 0.9)
        crown.append(sphere("cr", (x, y, 2.75 + r.uniform(-0.15, 0.25)), r.uniform(0.45, 0.7), (1.4, 1.1, 0.55)))
    c = join(crown, "crown_leaf")
    remesh(c, 0.11, 3)
    displace(c, 0.08, 0.3)
    paint(c, hexcol("4f7a3a"), ao=0.0, noise_amt=0.18, nscale=4, fn=lambda co, n: 1.15 if n.z > 0.6 else (0.8 if n.z < -0.3 else None))
    parts.append(c)
    for k in range(3):
        root = tube("rt", [(0, 0, 0.1), (math.cos(k * 2.1) * 0.5, math.sin(k * 2.1) * 0.5, -0.05)], [0.1, 0.04], 6)
        paint(root, hexcol("5a4030"), ao=0.0)
        parts.append(root)
    trunk_j = join([p for p in parts if p is not c], "Trunk")
    set_parent(c, trunk_j)


def crooked_tree_a():
    _crooked(3)


def crooked_tree_b():
    _crooked(17)


def _heather(seed):
    """Вереск: низкая кочка из мелких веточек, усыпанная розово-сиреневыми цветками."""
    r = rnd(seed)
    parts = []
    base = sphere("hb", (0, 0, 0.18), 0.5, (1.2, 1.0, 0.55))
    displace(base, 0.08, 0.15)
    paint(base, hexcol("4a6a3a"), ao=0.3, ao_h=0.3, noise_amt=0.2, nscale=8)
    parts.append(base)
    for k in range(40):
        a = r.uniform(0, 2 * math.pi)
        d = r.uniform(0.0, 0.55)
        x, y = math.cos(a) * d * 1.2, math.sin(a) * d
        z = 0.18 + 0.27 * (1 - (d / 0.55) ** 2)
        sp = tube("hs", [(x, y, z - 0.05), (x + r.uniform(-0.05, 0.05), y + r.uniform(-0.05, 0.05), z + r.uniform(0.15, 0.3))], 0.02, 4)
        paint(sp, shade(HEATHER, r.uniform(0.85, 1.15)), ao=0.0, noise_amt=0.1)
        parts.append(sp)
    join(parts, "Heather_leaf")


def heather_a():
    _heather(5)


def heather_b():
    _heather(23)


def blueberry_bush():
    """Черничник: невысокий кустик с мелкими листьями и синими ягодами."""
    r = rnd(31)
    leaves = []
    for k in range(5):
        a = k * 1.3
        leaves.append(sphere("bl", (math.cos(a) * 0.22, math.sin(a) * 0.22, 0.32 + r.uniform(-0.05, 0.08)), 0.28, (1.1, 1.0, 0.7)))
    c = join(leaves, "bush_leaf")
    remesh(c, 0.075, 2)
    displace(c, 0.05, 0.12)
    paint(c, hexcol("3f7a3a"), ao=0.3, ao_h=0.3, noise_amt=0.2, nscale=10)
    parts = [c]
    for k in range(16):
        a = r.uniform(0, 2 * math.pi)
        d = r.uniform(0.25, 0.42)
        b = sphere("bb", (math.cos(a) * d, math.sin(a) * d * 0.9, r.uniform(0.25, 0.5)), 0.045, segs=8, rings=5)
        paint(b, hexcol("3a4aa8"), ao=0.0, noise_amt=0, fn=lambda co, n: hexcol("8a9ae8") if n.z > 0.7 else None)
        parts.append(b)
    join(parts, "Blueberry")


def scrap_pile():
    """Куча ржавого железа: листы, трубы, колесо, бочка."""
    r = rnd(77)
    parts = []
    for k in range(5):
        sh = box("ss", (r.uniform(-0.4, 0.4), r.uniform(-0.3, 0.3), 0.1 + k * 0.05), (r.uniform(0.5, 0.9), r.uniform(0.3, 0.6), 0.03),
                 (r.uniform(-0.4, 0.4), r.uniform(-0.3, 0.3), r.uniform(0, 3)))
        paint(sh, r.choice([RUST, hexcol("8f979e"), hexcol("7a5a3a")]), ao=0.0, fn=_rust_fn())
        parts.append(sh)
    for k in range(3):
        pp = tube("sp", [(r.uniform(-0.6, 0.0), r.uniform(-0.4, 0.4), 0.15), (r.uniform(0.2, 0.7), r.uniform(-0.4, 0.4), r.uniform(0.1, 0.35))], 0.05, 8)
        paint(pp, IRON, ao=0.0, fn=_rust_fn(IRON))
        parts.append(pp)
    wheel = cyl("sw", (0.45, 0.25, 0.2), 0.22, 0.22, 0.08, (1.2, 0.3, 0), 16)
    paint(wheel, hexcol("2a2a2a"), ao=0.0)
    parts.append(wheel)
    drum = cyl("sd", (-0.5, 0.2, 0.0), 0.2, 0.2, 0.5, (0.2, 0.4, 0), 14)
    paint(drum, hexcol("c0392b"), ao=0.0, fn=_rust_fn(hexcol("c0392b")))
    parts.append(drum)
    join(parts, "ScrapPile")


def sand_pit():
    pile = cyl("sp", (0, 0, -0.04), 0.7, 0.55, 0.12, segs=18, scale=(1.2, 1, 1))
    displace(pile, 0.04, 0.2)
    paint(pile, hexcol("f0dca8"), ao=0.0, noise_amt=0.15, nscale=12, fn=lambda co, n: 1.1 if n.z > 0.8 else None)
    parts = [pile]
    for k in range(3):
        a = k * 2.0
        m = sphere("sm", (math.cos(a) * 0.45, math.sin(a) * 0.35, 0.08), 0.15, (1.3, 1, 0.5))
        paint(m, hexcol("e8d098"), ao=0.0)
        parts.append(m)
    join(parts, "SandPit")


def rockfall():
    """Обвал: груда валунов вдоль тропы (3.4 × 1.4 м)."""
    parts = []
    r = rnd(55)
    for k in range(7):
        x = -1.4 + k * 0.47 + r.uniform(-0.1, 0.1)
        rad = r.uniform(0.35, 0.6)
        parts.append(stone("rf", (x, r.uniform(-0.3, 0.3), rad * 0.7 + (0.4 if k in (2, 4) else 0.0)), rad, k + 3, hexcol("8a8690")))
    for k in range(3):
        parts.append(stone("rs", (-0.8 + k * 0.8, r.uniform(-0.6, 0.6), 0.1), 0.18, k + 20, hexcol("9a969e")))
    join(parts, "Rockfall")


def fulgurite():
    """«Стекляшка молнии»: оплавленный песок — ветвистый стеклянный корешок в маленькой воронке."""
    r = rnd(91)
    crater = cyl("fc", (0, 0, -0.02), 0.35, 0.25, 0.05, segs=14)
    paint(crater, hexcol("3a3632"), ao=0.0, noise_amt=0.2, nscale=12)
    parts = [crater]
    for k in range(4):
        a = k * 1.6
        pts = [(0, 0, 0.0)]
        for i in range(1, 5):
            pts.append((math.cos(a) * 0.05 * i + r.uniform(-0.02, 0.02), math.sin(a) * 0.05 * i, 0.06 * i * (1 - k * 0.15)))
        g = tube("fg", pts, [0.05, 0.04, 0.03, 0.02, 0.01], 6)
        paint(g, hexcol("d9e8e0"), ao=0.0, noise_amt=0.1, fn=lambda co, n: hexcol("9fd8c0") if co.z > 0.12 else None)
        parts.append(g)
    join(parts, "Fulgurite")


BUILDERS = {
    "timur": timur, "goose": goose, "goose_house": goose_house, "lightning_rod": lightning_rod, "shelter": shelter,
    "met_station": met_station, "bunker_wall": bunker_wall, "bunker_ceiling": bunker_ceiling, "bunker_deck": bunker_deck,
    "ladder": ladder, "bunker_rail": bunker_rail, "bunker_chain": bunker_chain, "bunker_lamp": bunker_lamp,
    "bunker_shelves": bunker_shelves, "bunker_crates": bunker_crates, "bunker_hatch": bunker_hatch,
    "bunker_hatch_inner": bunker_hatch_inner, "generator_broken": generator_broken, "generator": generator,
    "station_desk": station_desk, "radio_broken": radio_broken, "radio": radio, "seaplane": seaplane, "graves": graves,
    "storm_tower_ruin": storm_tower_ruin, "storm_tower": storm_tower, "stepa_boat_wreck": stepa_boat_wreck,
    "stepa_boat": stepa_boat, "crop_pumpkin": crop_pumpkin, "crooked_tree_a": crooked_tree_a,
    "crooked_tree_b": crooked_tree_b, "heather_a": heather_a, "heather_b": heather_b, "blueberry_bush": blueberry_bush,
    "scrap_pile": scrap_pile, "sand_pit": sand_pit, "rockfall": rockfall, "fulgurite": fulgurite,
}
