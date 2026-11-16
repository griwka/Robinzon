"""«Живой мир»: находки с моря, камни со знаками строителей маяков, тайник, редкие существа.
Blender (x, y, z) → Godot (x, z, −y): лицо камня со знаком — это −Y Blender (в игре камень повёрнут лицом к тайнику).
Запекание — как у построек (список WORLD в build.py)."""
import math

from mathutils import noise as _nz

from kit import box, cyl, displace, empty, hexcol, ico, join, lathe, leaf, paint, rnd, shade, sphere, subsurf, tube
from models_buildings import ROPE, stone

STONE = hexcol("9a968c")
STONE_D = hexcol("6a665e")
MOSS = hexcol("6d9a40")
CARVE = hexcol("3a3832")
GOLD = hexcol("e8b83a")


# ------------------------------------------------------------------ знаки: рисунок на лице камня (x — вбок, z — вверх)
def _seg(px, pz, ax, az, bx, bz):
    """Расстояние от точки до отрезка."""
    dx, dz = bx - ax, bz - az
    ln = dx * dx + dz * dz
    t = 0.0 if ln < 1e-9 else max(0.0, min(1.0, ((px - ax) * dx + (pz - az) * dz) / ln))
    return math.hypot(px - ax - dx * t, pz - az - dz * t)


def _poly(px, pz, pts, closed=True):
    n = len(pts)
    d = 9.0
    for i in range(n if closed else n - 1):
        a, b = pts[i], pts[(i + 1) % n]
        d = min(d, _seg(px, pz, a[0], a[1], b[0], b[1]))
    return d


def g_sail(x, z):
    return min(_poly(x, z, [(-0.16, -0.14), (0.14, -0.14), (-0.16, 0.2)]), _seg(x, z, -0.22, -0.2, 0.2, -0.2))


def g_root(x, z):
    d = _seg(x, z, 0.0, 0.2, 0.0, -0.02)
    for sx in (-1, 1):
        d = min(d, _seg(x, z, 0.0, -0.02, sx * 0.16, -0.2), _seg(x, z, 0.0, 0.06, sx * 0.1, -0.08))
    return min(d, abs(math.hypot(x, z - 0.2) - 0.06))


def g_key(x, z):
    d = abs(math.hypot(x, z - 0.12) - 0.08)
    d = min(d, _seg(x, z, 0.0, 0.04, 0.0, -0.2))
    return min(d, _seg(x, z, 0.0, -0.2, 0.09, -0.2), _seg(x, z, 0.0, -0.12, 0.07, -0.12))


def g_bolt(x, z):
    return _poly(x, z, [(0.06, 0.22), (-0.1, 0.0), (0.02, 0.0), (-0.06, -0.22), (0.12, 0.04), (0.0, 0.04)], closed=False)


def g_star(x, z):
    pts = []
    for k in range(10):
        a = math.pi / 2 + k * math.pi / 5
        r = 0.2 if k % 2 == 0 else 0.085
        pts.append((math.cos(a) * r, math.sin(a) * r))
    return _poly(x, z, pts)


def g_flame(x, z):
    return _poly(x, z, [(0.0, 0.22), (0.12, 0.02), (0.1, -0.14), (0.0, -0.2), (-0.1, -0.14), (-0.12, 0.02)])


def g_eye(x, z):
    d = min(abs(math.hypot(x, (z + 0.16) * 0.9) - 0.26), abs(math.hypot(x, (z - 0.16) * 0.9) - 0.26)) if abs(x) < 0.21 else 9.0
    return min(d, abs(math.hypot(x, z) - 0.055))


def g_arrow(x, z):
    """Стрелка вниз-вперёд под знаком: туда, куда смотрит камень."""
    return min(_seg(x, z, 0.0, 0.1, 0.0, -0.1), _seg(x, z, 0.0, -0.1, -0.08, -0.02), _seg(x, z, 0.0, -0.1, 0.08, -0.02))


def _slab(name, w, d, h, seed, glyphs, lean=0.0):
    """Стоячий камень с резьбой на лице (−Y). glyphs — [(функция знака, cx, cz, масштаб)]."""
    s = box(name, (0, 0, h / 2 - 0.08), (w, d, h), (lean, 0, 0), bev=min(w, d) * 0.3, seg=3)
    subsurf(s, 1)
    displace(s, 0.05, 0.5, "CLOUDS", seed=seed)

    def fn(co, n):
        if n.y < -0.55:
            for g, cx, cz, k in glyphs:
                dd = g((co.x - cx) / k, (co.z - cz) / k) * k
                if dd < 0.02:
                    return CARVE
                if dd < 0.034:
                    return shade(STONE, 1.16)       # светлая кромка резьбы
        m = _nz.noise((co.x * 2.4 + seed, co.y * 2.4, co.z * 2.0))
        if n.z > 0.45 and m > -0.05:
            return MOSS
        if co.z < 0.3 and m > 0.22:
            return shade(MOSS, 0.85)
        return None
    paint(s, shade(STONE, 0.92 + 0.05 * (seed % 3)), ao=0.3, ao_h=0.5, noise_amt=0.1, nscale=6, fn=fn, mat="stone")
    return s


def _rune_stone(seed, sign, w, h, lean):
    parts = [_slab("slab", w, 0.36, h, seed, [(sign, 0.0, h * 0.58, 1.0), (g_arrow, 0.0, h * 0.24, 1.0)], lean)]
    for i in range(4):
        a = i * 1.7 + seed
        parts.append(stone("ps", (math.cos(a) * (w * 0.55), math.sin(a) * 0.3, 0.05), 0.12 + 0.03 * (i % 2), i + seed))
    rr = rnd(seed)
    for i in range(5):
        a = rr.uniform(0, 2 * math.pi)
        lf = leaf("g_leaf", (math.cos(a) * w * 0.5, math.sin(a) * 0.3, 0.0), (math.cos(a) * 0.4, math.sin(a) * 0.4, 1.0), rr.uniform(0.2, 0.34), 0.05, droop=0.5, segs=4)
        paint(lf, shade(hexcol("5fae4a"), rr.uniform(0.85, 1.1)), ao=0.0, mat="leaf")
        parts.append(lf)
    return parts


def rune_stone_a():
    join(_rune_stone(3, g_sail, 0.86, 1.5, 0.05), "RuneStoneA")


def rune_stone_b():
    join(_rune_stone(8, g_eye, 0.78, 1.36, -0.07), "RuneStoneB")


def rune_stone_c():
    join(_rune_stone(14, g_bolt, 0.92, 1.62, 0.03), "RuneStoneC")


def sign_stone():
    """Украшение за коллекцию: гладкий камень со всеми семью знаками строителей. Lamp0 — свет вечером."""
    signs = [g_sail, g_root, g_key, g_bolt, g_star, g_flame, g_eye]
    glyphs = []
    for i, g in enumerate(signs):
        if i < 6:
            glyphs.append((g, -0.27 + (i % 3) * 0.27, 1.16 - (i // 3) * 0.36, 0.5))
        else:
            glyphs.append((g, 0.0, 0.44, 0.62))
    s = _slab("slab", 1.0, 0.34, 1.6, 21, glyphs)
    base = cyl("base", (0, 0, 0.0), 0.62, 0.56, 0.12, segs=8)
    paint(base, STONE_D, ao=0.2, noise_amt=0.1, nscale=8, mat="stone")
    parts = [s, base]
    for i in range(5):
        a = i * 1.26
        parts.append(stone("ps", (math.cos(a) * 0.62, math.sin(a) * 0.5, 0.06), 0.1, i + 2))
    g = join(parts, "SignStone")
    empty("Lamp0", (0, -0.26, 0.9), g)


def rune_cache():
    """Просевший бугорок на месте тайника: рыхлая земля, пара камней, торчит угол ящика."""
    m = lathe("mound", [(0.0, 0.1), (0.25, 0.09), (0.5, 0.12), (0.66, 0.08), (0.74, 0.0)], 18)
    displace(m, 0.04, 0.3, "CLOUDS", seed=4)
    paint(m, hexcol("6a4a30"), ao=0.2, ao_h=0.15, noise_amt=0.2, nscale=12, mat="soil",
          fn=lambda co, n: hexcol("4a3220") if math.hypot(co.x, co.y) < 0.3 else None)
    crate = box("crate", (0.06, 0.02, 0.1), (0.3, 0.24, 0.2), (0.25, 0.2, 0.3), bev=0.02)
    paint(crate, hexcol("8a5a32"), ao=0.2, mat="wood", fn=lambda co, n: hexcol("3a3b40") if abs(co.x - 0.06) < 0.025 else None)
    parts = [m, crate]
    for i in range(3):
        a = i * 2.1 + 0.5
        parts.append(stone("ps", (math.cos(a) * 0.6, math.sin(a) * 0.6, 0.04), 0.1, i))
    join(parts, "RuneCache")


# ------------------------------------------------------------------ находки с моря
def drift_bottle():
    """Бутылка на боку, наполовину в песке; внутри — свёрнутая записка, горлышко заткнуто пробкой."""
    b = lathe("glass", [(0.0, 0.0), (0.085, 0.0), (0.095, 0.03), (0.095, 0.2), (0.07, 0.26), (0.032, 0.3), (0.03, 0.4), (0.036, 0.41),
                        (0.036, 0.43), (0.0, 0.43)], 14, loc=(-0.2, 0, 0.09), rot=(0, math.pi / 2 - 0.18, 0.3))
    paint(b, hexcol("7fc8a8"), ao=0.0, noise_amt=0.04, mat="plain",
          fn=lambda co, n: hexcol("c8ecd8") if _nz.noise((co.x * 9, co.y * 9, co.z * 9)) > 0.42 else None)
    cork = cyl("cork", (0.0, 0, 0.0), 0.03, 0.026, 0.05, segs=8)
    cork.location = (0.2, 0.13, 0.165)
    cork.rotation_euler = (0, math.pi / 2 - 0.18, 0.3)
    paint(cork, hexcol("b88a50"), ao=0.0, mat="plain")
    note = cyl("note", (0, 0, 0), 0.035, 0.035, 0.16, segs=8)
    note.location = (-0.14, 0.02, 0.1)
    note.rotation_euler = (0, math.pi / 2 - 0.18, 0.3)
    paint(note, hexcol("f2e6c4"), ao=0.0, mat="plain")
    sand = lathe("sand", [(0.0, 0.05), (0.2, 0.04), (0.3, 0.0)], 12, loc=(-0.12, -0.02, 0.0))
    paint(sand, hexcol("ecd29a"), ao=0.0, noise_amt=0.1, nscale=20, mat="plain")
    join([b, cork, note, sand], "DriftBottle")


def drift_glass():
    """Обкатанные морем стёклышки в песке."""
    parts = []
    sand = lathe("sand", [(0.0, 0.035), (0.16, 0.03), (0.24, 0.0)], 12)
    paint(sand, hexcol("ecd29a"), ao=0.0, noise_amt=0.1, nscale=20, mat="plain")
    parts.append(sand)
    for i, (x, y, c, r) in enumerate(((0.0, 0.0, "6fbf8a", 0.07), (0.1, 0.06, "e8f0ec", 0.05), (-0.09, 0.05, "4a7ad8", 0.045), (0.03, -0.1, "d89a3a", 0.05))):
        g = ico("gl", (x, y, 0.045), r, (1.0, 0.75, 0.4), (0.2 * i, 0.1, i * 1.3), sub=2)
        paint(g, hexcol(c), ao=0.0, noise_amt=0.03, mat="plain")
        parts.append(g)
    join(parts, "DriftGlass")


def drift_float():
    """Чужой рыбацкий поплавок: стеклянный шар в верёвочной сетке, обрывок сети."""
    ball = sphere("ball", (0, 0, 0.17), 0.17, segs=16, rings=10)
    paint(ball, hexcol("5fb8a8"), ao=0.1, ao_h=0.3, noise_amt=0.03, mat="plain")
    parts = [ball]
    for k in range(4):
        a = k * math.pi / 4
        pts = [(math.cos(a) * math.sin(t) * 0.178, math.sin(a) * math.sin(t) * 0.178, 0.17 + math.cos(t) * 0.178) for t in [i * math.pi / 8 for i in range(17)]]
        pts += [(-p[0], -p[1], p[2]) for p in reversed(pts[1:-1])]
        r = tube("net", pts + [pts[0]], 0.009, 5, caps=False)
        paint(r, ROPE, ao=0.0, mat="rope")
        parts.append(r)
    for z in (0.1, 0.24):
        rr_ = math.sqrt(max(0.0, 0.178 ** 2 - (z - 0.17) ** 2))
        ring = tube("ring", [(math.cos(i * math.pi / 8) * rr_, math.sin(i * math.pi / 8) * rr_, z) for i in range(17)], 0.009, 5, caps=False)
        paint(ring, ROPE, ao=0.0, mat="rope")
        parts.append(ring)
    tail = tube("tail", [(0.0, 0.0, 0.35), (0.1, 0.05, 0.3), (0.26, 0.1, 0.06), (0.4, 0.06, 0.02)], 0.012, 5)
    paint(tail, ROPE, ao=0.0, mat="rope")
    parts.append(tail)
    join(parts, "DriftFloat")


def drift_pod():
    """Стручок неизвестного растения: приоткрыт, внутри видны семена."""
    parts = []
    for side, col in ((-1, "8a5a32"), (1, "7a4a2a")):
        h = lathe("husk", [(0.0, 0.0), (0.05, 0.03), (0.085, 0.12), (0.08, 0.24), (0.04, 0.34), (0.0, 0.37)], 10,
                  loc=(-0.16, side * 0.03, 0.07), rot=(side * 0.28, math.pi / 2 - 0.1, 0), scale=(1, 0.55, 1))
        paint(h, hexcol(col), ao=0.1, ao_h=0.2, noise_amt=0.12, nscale=14, mat="bark")
        parts.append(h)
    for i in range(4):
        s = sphere("seed", (-0.1 + i * 0.075, 0.0, 0.1), 0.03, (1, 0.8, 0.8), segs=8, rings=6)
        paint(s, hexcol("f2c860"), ao=0.0, noise_amt=0, mat="plain")
        parts.append(s)
    lf = leaf("p_leaf", (-0.17, 0, 0.08), (-1, 0.3, 0.5), 0.2, 0.07, droop=0.4, segs=4)
    paint(lf, hexcol("7a9a4a"), ao=0.0, mat="leaf")
    parts.append(lf)
    sand = lathe("sand", [(0.0, 0.04), (0.2, 0.03), (0.28, 0.0)], 12)
    paint(sand, hexcol("ecd29a"), ao=0.0, noise_amt=0.1, nscale=20, mat="plain")
    parts.append(sand)
    join(parts, "DriftPod")


# ------------------------------------------------------------------ редкие существа
def glow_crab():
    """Светящийся краб Туманного острова: бледно-зелёный панцирь со светлыми пятнами."""
    col = hexcol("6fd8b8")
    body = sphere("body", (0, 0, 0.1), 0.15, (1.35, 1.0, 0.55), segs=14, rings=9)
    paint(body, col, ao=0.1, ao_h=0.2, noise_amt=0.04, mat="plain",
          fn=lambda co, n: hexcol("e8fff0") if (n.z > 0.5 and _nz.noise((co.x * 14, co.y * 14, 1.5)) > 0.3) else None)
    parts = [body]
    for sx in (-1, 1):
        claw = sphere("claw", (sx * 0.2, -0.13, 0.11), 0.065, (1.0, 1.35, 0.75), segs=10, rings=7)
        paint(claw, shade(col, 1.12), ao=0.0, mat="plain")
        arm = tube("arm", [(sx * 0.13, -0.04, 0.1), (sx * 0.2, -0.1, 0.11)], 0.022, 6)
        paint(arm, col, ao=0.0, mat="plain")
        stalk = tube("stalk", [(sx * 0.05, -0.1, 0.14), (sx * 0.055, -0.12, 0.22)], 0.011, 5)
        paint(stalk, col, ao=0.0, mat="plain")
        eye = sphere("eye", (sx * 0.055, -0.12, 0.23), 0.022, segs=8, rings=6)
        paint(eye, hexcol("1d1d1d"), ao=0.0, noise_amt=0, mat="plain")
        parts += [claw, arm, stalk, eye]
        for k in range(3):
            y = -0.02 + k * 0.07
            leg = tube("leg", [(sx * 0.15, y, 0.08), (sx * 0.27, y + 0.01, 0.1), (sx * 0.32, y + 0.02, 0.0)], 0.013, 5)
            paint(leg, shade(col, 0.82), ao=0.0, mat="plain")
            parts.append(leg)
    join(parts, "GlowCrab")


def gold_beetle():
    """Золотой жук: блестящие надкрылья со швом, тёмная голова, усики."""
    body = sphere("body", (0, 0, 0.05), 0.075, (0.85, 1.25, 0.62), segs=14, rings=9)
    paint(body, GOLD, ao=0.0, noise_amt=0.02, mat="metal",
          fn=lambda co, n: hexcol("a8742a") if (abs(co.x) < 0.006 and n.z > 0.2) else (hexcol("fff0a8") if (n.z > 0.75 and abs(co.x) > 0.02) else None))
    head = sphere("head", (0, -0.09, 0.045), 0.04, (1.0, 0.9, 0.8), segs=10, rings=7)
    paint(head, hexcol("3a2a1a"), ao=0.0, mat="plain")
    parts = [body, head]
    for sx in (-1, 1):
        ant = tube("ant", [(sx * 0.015, -0.12, 0.05), (sx * 0.04, -0.17, 0.08), (sx * 0.07, -0.18, 0.06)], 0.005, 4)
        paint(ant, hexcol("3a2a1a"), ao=0.0, mat="plain")
        parts.append(ant)
        for k in range(3):
            y = -0.05 + k * 0.05
            leg = tube("leg", [(sx * 0.05, y, 0.04), (sx * 0.1, y, 0.04), (sx * 0.12, y + 0.01, 0.0)], 0.006, 4)
            paint(leg, hexcol("3a2a1a"), ao=0.0, mat="plain")
            parts.append(leg)
    join(parts, "GoldBeetle")


def sea_turtle():
    """Морская черепаха: плоский панцирь с пластинами, ласты, голова вперёд (−Y)."""
    shell_c = hexcol("5a8a5a")
    skin = hexcol("8fb88a")
    shell = sphere("shell", (0, 0.02, 0.2), 0.42, (0.9, 1.15, 0.42), segs=18, rings=10)

    def plates(co, n):
        if n.z < 0.15:
            return hexcol("d8c890")                  # светлый край панциря
        u = co.x * 5.2
        v = co.y * 5.2 + (0.5 if int(math.floor(u)) % 2 else 0.0)
        fu, fv = u - math.floor(u), v - math.floor(v)
        if min(fu, 1 - fu) < 0.07 or min(fv, 1 - fv) < 0.07:
            return hexcol("3a5a3a")
        return shade(shell_c, 0.92 + 0.14 * ((int(math.floor(u)) * 7 + int(math.floor(v)) * 3) % 3) / 2)
    paint(shell, shell_c, ao=0.15, ao_h=0.3, noise_amt=0.05, nscale=8, fn=plates, mat="plain")
    belly = sphere("belly", (0, 0.02, 0.13), 0.38, (0.86, 1.1, 0.22), segs=14, rings=8)
    paint(belly, hexcol("e8dca8"), ao=0.2, mat="plain")
    head = sphere("head", (0, -0.52, 0.2), 0.12, (0.9, 1.25, 0.85), segs=12, rings=8)
    paint(head, skin, ao=0.0, noise_amt=0.05, mat="plain",
          fn=lambda co, n: hexcol("1d1d1d") if (abs(abs(co.x) - 0.075) < 0.02 and abs(co.z - 0.23) < 0.02 and co.y < -0.54) else None)
    neck = tube("neck", [(0, -0.36, 0.18), (0, -0.5, 0.2)], 0.075, 8)
    paint(neck, skin, ao=0.0, mat="plain")
    parts = [shell, belly, head, neck]
    for sx in (-1, 1):
        ff = sphere("flipf", (sx * 0.46, -0.3, 0.09), 0.2, (1.25, 0.5, 0.16), (0, 0, sx * 0.7), segs=10, rings=7)
        fb = sphere("flipb", (sx * 0.36, 0.42, 0.08), 0.13, (1.0, 0.6, 0.18), (0, 0, -sx * 0.6), segs=10, rings=7)
        for f in (ff, fb):
            paint(f, skin, ao=0.0, noise_amt=0.06, nscale=14, mat="plain")
            parts.append(f)
    tail = cyl("tail", (0, 0.5, 0.12), 0.04, 0.0, 0.12, rot=(-math.pi / 2, 0, 0), segs=6)
    paint(tail, skin, ao=0.0, mat="plain")
    parts.append(tail)
    join(parts, "SeaTurtle")


BUILDERS = {
    "rune_stone_a": rune_stone_a, "rune_stone_b": rune_stone_b, "rune_stone_c": rune_stone_c, "sign_stone": sign_stone,
    "rune_cache": rune_cache, "drift_bottle": drift_bottle, "drift_glass": drift_glass, "drift_float": drift_float,
    "drift_pod": drift_pod, "glow_crab": glow_crab, "gold_beetle": gold_beetle, "sea_turtle": sea_turtle,
}
