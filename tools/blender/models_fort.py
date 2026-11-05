"""Глава 3 — Старый форт: стены, ворота, разрушенная караулка, рычаги подвала, хижина боцмана,
боцман Стёпа, свинья, свинарник, печь для обжига, глиняная яма, удочка и лопата."""
import math

from mathutils import Vector

from kit import (box, cyl, displace, empty, hexcol, ico, join, lathe, leaf, mix, paint, remesh, rnd, set_origin,
                 set_parent, shade, sphere, subsurf, tube)
from models_buildings import log, plank, rope_wrap, stone, thatch_cone

FORT_STONE = hexcol("9c958a")
FORT_DARK = hexcol("7a7368")
MOSS = hexcol("5f8a48")


def _stone_fn(co, n):
    # кладка: ряды блоков со швами, мох сверху
    row = int(co.z / 0.42)
    off = 0.35 if row % 2 else 0.0
    seam_z = (co.z % 0.42) < 0.04
    seam_x = ((co.x + co.y + off) % 0.7) < 0.05
    if n.z > 0.7 and co.z > 2.2:
        return MOSS
    if seam_z or seam_x:
        return 0.72
    return 0.9 + 0.12 * ((row * 7 + int((co.x + co.y + off) / 0.7) * 3) % 5) / 4


def fort_wall():
    """Секция крепостной стены 4.4 × 0.9 × 3 м с зубцами, местами обвалившаяся."""
    rr = rnd(201)
    parts = []
    w = box("w", (0, 0, 1.4), (4.4, 0.9, 2.8))
    displace(w, 0.04, 0.3)
    paint(w, FORT_STONE, ao=0.3, ao_h=0.8, noise_amt=0.08, nscale=3, fn=_stone_fn)
    parts.append(w)
    for k in range(5):
        if k == 3 and rr.random() < 0.9:
            continue   # выпавший зубец
        z = box("cr", (-1.8 + k * 0.9, 0, 3.05), (0.6, 0.95, 0.5), bev=0.03)
        paint(z, shade(FORT_STONE, 1.05), ao=0.0, noise_amt=0.1, fn=_stone_fn)
        parts.append(z)
    for k in range(3):
        parts.append(stone("rb", (rr.uniform(-1.8, 1.8), rr.uniform(0.6, 1.0), 0.1), rr.uniform(0.15, 0.3), k, FORT_DARK))
    vine = tube("vn", [(1.2, 0.47, 0.0), (1.4, 0.48, 1.2), (0.9, 0.48, 2.4), (1.1, 0.47, 2.9)], 0.04, 6)
    paint(vine, hexcol("4f7a3a"), ao=0.0)
    parts.append(vine)
    join(parts, "FortWall")


def fort_gate():
    """Арка ворот (4.4 м) и две дубовые створки (узел Doors — створки открываются в игре)."""
    parts = []
    for sx in (-1, 1):
        p = box("pl", (sx * 1.95, 0, 1.75), (0.6, 1.2, 3.5))
        paint(p, FORT_STONE, ao=0.3, ao_h=0.8, fn=_stone_fn)
        parts.append(p)
    arch = box("ar", (0, 0, 3.4), (4.5, 1.2, 0.8), bev=0.05)
    paint(arch, shade(FORT_STONE, 0.95), ao=0.0, fn=_stone_fn)
    sign = box("sg", (0, -0.62, 3.4), (1.2, 0.05, 0.4), bev=0.02)
    paint(sign, hexcol("6b3a22"), ao=0.0)
    parts += [arch, sign]
    join(parts, "Gate")
    for sx, nm in ((-1, "DoorL"), (1, "DoorR")):
        door = box(nm, (sx * 0.8, 0, 1.5), (1.6, 0.18, 3.0), bev=0.03)
        paint(door, hexcol("7a5232"), ao=0.0, fn=lambda co, n: 0.8 if int((co.x + 4) * 5) % 2 else (hexcol("3a3a3a") if abs(co.z - 2.3) < 0.08 or abs(co.z - 0.7) < 0.08 else None))
        set_origin(door, (sx * 1.6, 0, 0))


def gatehouse():
    """Караулка у ворот: обрушенные стены, стол, сундучок, рассыпанные бумаги."""
    parts = []
    for x, y, h in ((-1.4, -1.2, 2.2), (1.4, -1.2, 1.4), (-1.4, 1.2, 1.8), (1.4, 1.2, 0.9)):
        b = box("cn", (x, y, h / 2), (0.5, 0.5, h))
        paint(b, FORT_STONE, ao=0.2, fn=_stone_fn)
        parts.append(b)
    for (a, b_, h) in (((-1.4, -1.2), (-1.4, 1.2), 1.6), ((-1.4, 1.2), (0.6, 1.2), 1.1)):
        mid = ((a[0] + b_[0]) / 2, (a[1] + b_[1]) / 2)
        ln = math.hypot(b_[0] - a[0], b_[1] - a[1])
        wl = box("wl", (mid[0], mid[1], h / 2), (ln if a[1] == b_[1] else 0.4, 0.4 if a[1] == b_[1] else ln, h))
        paint(wl, FORT_STONE, ao=0.2, fn=_stone_fn)
        parts.append(wl)
    parts.append(plank("tb", (0.2, 0.1, 0.8), (1.2, 0.7, 0.08)))
    for x in (-0.3, 0.7):
        for y in (-0.2, 0.4):
            parts.append(plank("tl", (x, y, 0.4), (0.08, 0.08, 0.8), col=hexcol("8a5a32")))
    for k in range(4):
        pg = box("pg", (-0.1 + k * 0.18, 0.05 + (k % 2) * 0.15, 0.86), (0.2, 0.26, 0.01), (0, 0, k * 0.4))
        paint(pg, hexcol("f2e2b8"), ao=0.0)
        parts.append(pg)
    for k in range(5):
        parts.append(stone("rb", (-0.8 + k * 0.5, -0.6 + (k % 2) * 0.9, 0.12), 0.22, k, FORT_DARK))
    join(parts, "Gatehouse")


def lever():
    """Рычаг шлюза на каменной тумбе. Узел Handle — сама рукоять (поворачивается в игре)."""
    base = box("bs", (0, 0, 0.4), (0.5, 0.5, 0.8), bev=0.05)
    paint(base, FORT_STONE, ao=0.2, fn=_stone_fn)
    plate = box("pl", (0, -0.26, 0.55), (0.34, 0.03, 0.34), bev=0.02)
    paint(plate, hexcol("c9a050"), ao=0.0)
    join([base, plate], "Lever")
    h = tube("Handle", [(0, 0, 0.8), (0, 0, 1.55)], [0.05, 0.035], 8)
    paint(h, hexcol("5a4a3a"), ao=0.0)
    knob = sphere("kb", (0, 0, 1.6), 0.09)
    paint(knob, hexcol("d9573b"), ao=0.0)
    hd = join([h, knob], "Handle")
    set_origin(hd, (0, 0, 0.8))


def cellar_wall():
    """Низкая стена подвала (обрушившийся свод) 4 × 0.6 × 1.4 м."""
    w = box("cw", (0, 0, 0.7), (4.0, 0.6, 1.4))
    displace(w, 0.05, 0.3)
    paint(w, FORT_DARK, ao=0.3, ao_h=0.5, fn=_stone_fn)
    join([w], "CellarWall")


def fresco_slab():
    """Каменная плита-рамка под рисунок (сам рисунок накладывается в игре)."""
    s = box("fs", (0, 0, 1.3), (3.2, 0.4, 2.6), bev=0.06)
    paint(s, hexcol("b8ab98"), ao=0.2, noise_amt=0.1)
    f = box("fr", (0, -0.22, 1.3), (3.0, 0.06, 2.4), bev=0.02)
    paint(f, hexcol("8a7a62"), ao=0.0)
    join([s, f], "FrescoSlab")


# ------------------------------------------------------------------ берег: боцман и хозяйство
def fisher_hut():
    """Хижина боцмана: сваи, дощатый домик, сети, бочка, перевёрнутая лодка."""
    parts = []
    for x in (-1.2, 1.2):
        for y in (-1.0, 1.0):
            parts.append(log("pl", (x, y, 0), (x, y, 0.6), 0.08, rings=False))
    parts.append(plank("fl", (0, 0, 0.62), (2.8, 2.4, 0.1)))
    for k in range(6):
        z = 0.75 + k * 0.3
        for side in (-1, 1):
            parts.append(plank("ws", (side * 1.3, 0, z), (0.08, 2.2, 0.28), col=hexcol("9a7046"), seed=k))
        parts.append(plank("wb", (0, 1.1, z), (2.5, 0.08, 0.28), col=hexcol("9a7046"), seed=k))
    door = box("dr", (0, -1.12, 1.25), (0.8, 0.06, 1.2), bev=0.02)
    paint(door, hexcol("5a3a22"), ao=0.0)
    parts.append(door)
    parts.append(thatch_cone("rf", 2.55, 2.1, 1.1))
    # сеть на жердях
    import bmesh
    from kit import from_bm, solidify
    bm = bmesh.new()
    vs = [[bm.verts.new((1.7 + 0.0 * i, -1.0 + i * 0.25, 1.5 - j * 0.3 - 0.08 * math.sin(i))) for j in range(4)] for i in range(9)]
    for i in range(8):
        for j in range(3):
            bm.faces.new((vs[i][j], vs[i + 1][j], vs[i + 1][j + 1], vs[i][j + 1]))
    net = from_bm("nt", bm)
    solidify(net, 0.02)
    paint(net, hexcol("c9b88a"), ao=0.0, fn=lambda co, n: 0.6 if (int(co.y * 20) + int(co.z * 20)) % 2 else None)
    parts.append(net)
    for y in (-1.1, 1.1):
        parts.append(log("np", (1.7, y, 0), (1.7, y, 1.6), 0.04, rings=False))
    barrel = lathe("br", [(0.0, 0.0), (0.28, 0.0), (0.34, 0.35), (0.28, 0.7), (0.0, 0.7)], 14, loc=(-1.8, -1.3, 0))
    paint(barrel, hexcol("8a5a32"), ao=0.0, fn=lambda co, n: hexcol("6b6f75") if (abs(co.z - 0.15) < 0.04 or abs(co.z - 0.55) < 0.04) else None)
    parts.append(barrel)
    join(parts, "FisherHut")


def stepa():
    """Боцман Стёпа: широкий, седая борода, вязаная шапка, бушлат, трубка."""
    coat = hexcol("2f3e5c")
    skin = hexcol("e0a888")
    beard = hexcol("d9d4cc")
    body = lathe("sb", [(0.0, 0.08), (0.36, 0.1), (0.4, 0.35), (0.38, 0.7), (0.33, 0.95), (0.2, 1.05), (0.0, 1.07)], 20)
    subsurf(body, 1)
    paint(body, coat, ao=0.0, fn=lambda co, n: hexcol("c9a050") if (abs(co.x) < 0.03 and co.y > 0.2 and int(co.z * 8) % 2 == 0) else (hexcol("3a2a1a") if abs(co.z - 0.5) < 0.04 else None))
    parts = [body]
    for sx in (-1, 1):
        a = tube("sa", [(sx * 0.34, 0, 0.95), (sx * 0.44, 0.05, 0.7), (sx * 0.4, 0.12, 0.5)], [0.1, 0.09, 0.08], 10)
        paint(a, coat, ao=0.0)
        hd = sphere("sh", (sx * 0.39, 0.14, 0.46), 0.08)
        paint(hd, skin, ao=0.0)
        bt = lathe("bt", [(0.0, 0.0), (0.12, 0.0), (0.12, 0.15), (0.0, 0.16)], 10, loc=(sx * 0.15, 0.03, 0), scale=(1, 1.5, 1))
        paint(bt, hexcol("2a1a10"), ao=0.0)
        parts += [a, hd, bt]
    b = join(parts, "Body")
    set_origin(b, (0, 0, 0))
    hp = [sphere("hd", (0, 0, 1.38), 0.31, segs=26, rings=14)]
    paint(hp[0], skin, ao=0.0)
    bd = [sphere("bd", (0, 0.12, 1.22), 0.26, (1.05, 0.8, 0.95)), sphere("ms", (0, 0.27, 1.32), 0.1, (1.6, 0.6, 0.5))]
    bdm = join(bd, "Beard")
    remesh(bdm, 0.02, 2)
    paint(bdm, beard, ao=0.0, noise_amt=0.1, nscale=16)
    hp.append(bdm)
    for sx in (-1, 1):
        w = sphere("w", (sx * 0.11, 0.26, 1.43), 0.05, (1, 0.42, 0.9))
        paint(w, hexcol("ffffff"), ao=0.0, noise_amt=0)
        i = sphere("i", (sx * 0.115, 0.28, 1.425), 0.03, (1, 0.4, 0.9))
        paint(i, hexcol("3a5a7a"), ao=0.0, noise_amt=0)
        br = tube("br", [(sx * 0.05, 0.27, 1.5), (sx * 0.18, 0.25, 1.52)], 0.022, 6)
        paint(br, beard, ao=0.0)
        hp += [w, i, br]
    nose = sphere("ns", (0, 0.31, 1.37), 0.05, (1, 0.9, 0.8))
    paint(nose, hexcol("d98a70"), ao=0.0)
    hat = lathe("ht", [(0.0, 1.5), (0.33, 1.5), (0.34, 1.6), (0.3, 1.72), (0.18, 1.8), (0.0, 1.82)], 18, loc=(0, -0.02, 0))
    paint(hat, hexcol("8a2a2a"), ao=0.0, fn=lambda co, n: 0.8 if int(co.z * 30) % 2 else None)
    pipe = tube("pp", [(0.08, 0.3, 1.27), (0.2, 0.42, 1.25)], 0.015, 6)
    bowl = lathe("pb", [(0.0, 0.0), (0.035, 0.0), (0.04, 0.08), (0.0, 0.07)], 8, loc=(0.21, 0.43, 1.24))
    for o in (pipe, bowl):
        paint(o, hexcol("5a3a22"), ao=0.0)
    hp += [nose, hat, pipe, bowl]
    h = join(hp, "Head")
    set_origin(h, (0, 0, 1.08))
    set_parent(h, b)


def pig():
    pink = hexcol("f2a8a8")
    body = sphere("pb", (0, 0, 0.42), 0.3, (0.95, 1.35, 0.85), segs=18, rings=12)
    paint(body, pink, ao=0.0, fn=lambda co, n: hexcol("8a5a3a") if (co.x > 0.1 and -0.1 < co.y < 0.2 and co.z > 0.45) else None)
    parts = [body]
    for x in (-0.15, 0.15):
        for y in (-0.25, 0.25):
            l = tube("pl", [(x, y, 0.25), (x, y, 0.03)], 0.06, 8)
            paint(l, shade(pink, 0.9), ao=0.0)
            parts.append(l)
    tail = tube("pt", [(0, -0.4, 0.5)] + [(math.cos(a) * 0.05, -0.45 - a * 0.01, 0.52 + math.sin(a) * 0.05) for a in [k * 0.8 for k in range(8)]], 0.015, 5)
    paint(tail, pink, ao=0.0)
    parts.append(tail)
    bd = join(parts, "Body")
    set_origin(bd, (0, 0, 0))
    hp = [sphere("ph", (0, 0.38, 0.5), 0.2, segs=16, rings=10)]
    paint(hp[0], pink, ao=0.0)
    snout = cyl("sn", (0, 0.55, 0.47), 0.08, 0.08, 0.06, (-math.pi / 2, 0, 0), 12)
    paint(snout, hexcol("e88a8a"), ao=0.0, fn=lambda co, n: hexcol("8a4a4a") if (abs(co.x) > 0.02 and abs(co.x) < 0.04 and n.y > 0.5) else None)
    hp.append(snout)
    for sx in (-1, 1):
        ear = leaf("pe", (sx * 0.12, 0.35, 0.65), (sx * 0.6, 0.4, 0.5), 0.13, 0.06, droop=0.6)
        paint(ear, pink, ao=0.0)
        e = sphere("ey", (sx * 0.08, 0.53, 0.56), 0.02)
        paint(e, hexcol("1d1d1d"), ao=0.0, noise_amt=0)
        hp += [ear, e]
    h = join(hp, "Head")
    set_origin(h, (0, 0.3, 0.45))
    set_parent(h, bd)


def pig_sty():
    parts = []
    s = 1.7
    for side in range(4):
        a = side * math.pi / 2
        d = Vector((math.sin(a), -math.cos(a), 0))
        right = Vector((math.cos(a), math.sin(a), 0))
        for k in range(5):
            p = d * s + right * (k - 2) * s * 0.5
            parts.append(log("pp", (p.x, p.y, 0), (p.x, p.y, 0.7), 0.06, rings=False))
        for z in (0.3, 0.6):
            if side == 0 and z < 0.5:
                continue
            a0, a1 = d * s - right * s, d * s + right * s
            parts.append(log("rl", (a0.x, a0.y, z), (a1.x, a1.y, z), 0.045, col=hexcol("a07040"), rings=False))
    mud = cyl("md", (0.3, -0.2, 0.0), 1.1, 1.0, 0.05, segs=16, scale=(1.2, 1, 1))
    displace(mud, 0.03, 0.2)
    paint(mud, hexcol("6a4a2a"), ao=0.0, noise_amt=0.3, nscale=10)
    trough = box("tr", (-1.0, 1.1, 0.15), (1.0, 0.35, 0.25), bev=0.04)
    paint(trough, hexcol("8a5a32"), ao=0.0)
    shelter = box("sh", (1.0, 1.0, 0.55), (1.2, 1.0, 1.1), bev=0.04)
    paint(shelter, hexcol("c08a50"), ao=0.2, fn=lambda co, n: 0.85 if int(co.z * 7) % 2 else None)
    roof = cyl("rf", (1.0, 1.0, 1.1), 0.95, 0.05, 0.5, (0, 0, math.pi / 4), segs=4)
    paint(roof, hexcol("d6ad55"), ao=0.0, noise_amt=0.2, nscale=20)
    parts += [mud, trough, shelter, roof]
    join(parts, "PigSty")


def kiln():
    """Печь для обжига кирпичей: глиняный купол, топка, труба, стопка кирпичей."""
    dome = lathe("dm", [(0.0, 0.0), (0.9, 0.0), (0.92, 0.5), (0.75, 1.1), (0.4, 1.45), (0.0, 1.55)], 20)
    displace(dome, 0.04, 0.2)
    paint(dome, hexcol("c0704a"), ao=0.2, ao_h=0.4, noise_amt=0.12, nscale=5, fn=lambda co, n: 0.85 if (co.z * 4) % 1.0 < 0.08 else None)
    mouth = box("mo", (0, -0.85, 0.35), (0.6, 0.3, 0.55), bev=0.08)
    paint(mouth, hexcol("2a1a10"), ao=0.0)
    chimney = cyl("ch", (0.2, 0.2, 1.3), 0.18, 0.15, 0.7, segs=12)
    paint(chimney, hexcol("a85a3a"), ao=0.0)
    parts = [dome, mouth, chimney]
    for k in range(6):
        parts.append(box("bk", (1.3 + (k % 3) * 0.26, -0.3 + (k // 3) * 0.0, 0.07 + (k // 3) * 0.13), (0.24, 0.12, 0.12), bev=0.01))
        paint(parts[-1], hexcol("b8583a"), ao=0.0)
    for k in range(3):
        parts.append(log("wd", (-1.2, -0.4 + k * 0.15, 0.08 + (k % 2) * 0.1), (-0.6, -0.3 + k * 0.15, 0.08 + (k % 2) * 0.1), 0.07))
    join(parts, "Kiln")


def clay_pit():
    pit = cyl("cp", (0, 0, -0.05), 0.75, 0.6, 0.12, segs=18, scale=(1.2, 1, 1))
    displace(pit, 0.04, 0.2)
    paint(pit, hexcol("b8603a"), ao=0.0, noise_amt=0.2, nscale=8, fn=lambda co, n: 1.15 if n.z > 0.8 else None)
    parts = [pit]
    for k in range(4):
        a = k * 1.6
        lump = ico("lp", (math.cos(a) * 0.55, math.sin(a) * 0.45, 0.08), 0.12, (1.2, 1, 0.7), sub=1)
        paint(lump, hexcol("c87048"), ao=0.0)
        parts.append(lump)
    join(parts, "ClayPit")


def tool_fishing_rod():
    rod = tube("r", [(0, 0, 0.1), (0, 0.15, -0.6), (0, 0.4, -1.2)], [0.025, 0.018, 0.008], 6)
    paint(rod, hexcol("b8c450"), ao=0.0, fn=lambda co, n: 0.75 if int(co.z * 10) % 3 == 0 else None)
    reel = cyl("rl", (0.04, 0.02, -0.15), 0.05, 0.05, 0.04, (0, math.pi / 2, 0), 10)
    paint(reel, hexcol("6b6f75"), ao=0.0)
    join([rod, reel], "Tool")


def tool_shovel():
    h = log("h", (0, 0, 0.1), (0, 0, -0.55), 0.025, rings=False)
    blade = box("b", (0, 0.0, -0.68), (0.2, 0.03, 0.26), bev=0.02)
    paint(blade, hexcol("8f9499"), ao=0.0, fn=lambda co, n: 1.2 if co.z < -0.75 else None)
    grip = log("g", (-0.07, 0, 0.12), (0.07, 0, 0.12), 0.02, rings=False)
    join([h, blade, grip], "Tool")


BUILDERS = {"fort_wall": fort_wall, "fort_gate": fort_gate, "gatehouse": gatehouse, "lever": lever,
            "cellar_wall": cellar_wall, "fresco_slab": fresco_slab, "fisher_hut": fisher_hut, "stepa": stepa,
            "pig": pig, "pig_sty": pig_sty, "kiln": kiln, "clay_pit": clay_pit,
            "tool_fishing_rod": tool_fishing_rod, "tool_shovel": tool_shovel}
