"""Основные иконки (фрукты, материалы, инструменты), перерисованные на общих помощниках `gen_icons`:
плавные кривые (`spline`, `bez`, `tube`), своя система координат вдоль предмета (`Frame`),
узор прямо в цвете детали (`detail=`), чтобы свет, тень и блик ложились и на узор.
Свет всегда сверху-слева, контур — тёмный оттенок цвета самой детали."""
import math
import random

from gen_icons import (Frame, S, bez, ell, ell_pts, ink_line, leaf_shape, line, new, paint_soft, poly, quad_curve, rgb,
                       spline, tube)

# общая палитра дерева и металла — одни и те же цвета во всех инструментах
WOOD = rgb("c08a50")
WOOD_DK = rgb("8f5d2e")
WOOD_LT = rgb("e2b377")
STEEL = rgb("a9b4bf")
STEEL_DK = rgb("7d8b9b")
STEEL_LT = rgb("e6edf4")
ROPE = rgb("dcbc80")
ROPE_DK = rgb("a8844a")
LEAF = rgb("4fb04a")
LEAF_DK = rgb("2f8a3a")


def offset_path(path, widths, frac):
    """Кривая, сдвинутая от оси трубки на долю её толщины (для рёбер и бликов)."""
    n = len(path)
    ws = [float(widths)] * n if isinstance(widths, (int, float)) else (
        [widths[0] + (widths[1] - widths[0]) * i / (n - 1) for i in range(n)] if len(widths) == 2 else list(widths))
    out = []
    for i in range(n):
        a, b = path[max(i - 1, 0)], path[min(i + 1, n - 1)]
        dx, dy = b[0] - a[0], b[1] - a[1]
        ln = math.hypot(dx, dy) or 1.0
        out.append((path[i][0] - dy / ln * ws[i] * frac, path[i][1] + dx / ln * ws[i] * frac))
    return out


def leaf_blade(p0, p1, width, bend=0.0):
    """Лист-«капля» от p0 к p1 (плавный, симметричный)."""
    f = Frame(p0, p1)
    L = f.L
    pts = [(0, 0), (L * 0.22, -width * 0.62), (L * 0.55, -width * 0.52), (L * 0.85, -width * 0.2), (L, 0),
           (L * 0.85, width * 0.2), (L * 0.55, width * 0.52), (L * 0.22, width * 0.62)]
    pts = [(u, v + bend * math.sin(math.pi * u / L)) for u, v in pts]
    return spline(f.pts(pts), True, 10), f


def leaf_icon(d, p0, p1, width, col=LEAF, bend=0.0):
    pts, f = leaf_blade(p0, p1, width, bend)
    L = f.L

    def det(dd):
        paint_soft(dd, *f(L * 0.3, width * 0.2), L * 0.35, width * 0.4, lighten_c(col), 0.55)
        ink_line(dd, [f(L * 0.04, 0), f(L * 0.5, bend * 0.9), f(L * 0.9, bend * 0.2)], darken_c(col), max(5, width * 0.07))
        for k in (0.25, 0.45, 0.65):
            for sgn in (-1, 1):
                ink_line(dd, [f(L * k, bend * math.sin(math.pi * k)), f(L * (k + 0.16), sgn * width * 0.34 + bend * math.sin(math.pi * k))],
                         darken_c(col, 0.12), max(3, width * 0.04))
    poly(d, pts, col, detail=det)


def lighten_c(c, k=0.35):
    return tuple(int(v + (255 - v) * k) for v in c[:3]) + (255,)


def darken_c(c, k=0.22):
    return tuple(int(v * (1 - k)) for v in c[:3]) + (255,)


# ----------------------------------------------------------------- фрукты
def i_banana():
    img, d = new()
    fingers = [
        ((190, 150), (215, 250), (350, 280), (452, 190), 98),
        ((172, 150), (170, 290), (290, 390), (452, 318), 104),
        ((150, 150), (95, 320), (190, 450), (385, 430), 108),
    ]
    stem_pts = tube([(160, 150), (150, 100), (162, 62)], (44, 34))
    for p0, p1, p2, p3, wm in fingers:
        path = bez(p0, p1, p2, p3, 36)
        n = len(path)
        ws = [wm * (0.34 + 0.66 * math.sin(math.pi * (i / (n - 1))) ** 0.5) for i in range(n)]
        body = tube(path, ws)

        def det(dd, path=path, ws=ws, p0=p0, p3=p3):
            paint_soft(dd, p0[0], p0[1], 80, 70, rgb("93b03c"), 0.95)
            for fr, col in ((0.30, rgb("e6b21c")), (-0.30, rgb("e6b21c")), (0.0, rgb("f4cf3a"))):
                pp = offset_path(path, ws, fr)
                ink_line(dd, pp[3:-4], col, 5)
            ell_pts_ = ell_pts(p3[0], p3[1], 16, 16)
            dd.polygon(ell_pts_, fill=rgb("5a3a1c"))
        poly(d, body, rgb("ffd84a"), detail=det)
    poly(d, stem_pts, rgb("8a9a3c"), detail=lambda dd: ink_line(dd, [(158, 140), (152, 80)], rgb("6a7a2a"), 6))
    return img


def i_coconut():
    img, d = new()
    outline = spline([(256, 62), (372, 100), (446, 232), (410, 380), (256, 452), (102, 380), (66, 232), (140, 100)], True, 12)
    rnd = random.Random(4)

    def det(dd):
        paint_soft(dd, 200, 170, 120, 100, rgb("a06a3c"), 0.55)
        for i in range(46):
            a = rnd.uniform(-1.0, 1.0)
            x0 = 256 + a * 70 + rnd.uniform(-8, 8)
            y0 = 90 + rnd.uniform(0, 40)
            x1 = 256 + a * 195 + rnd.uniform(-10, 10)
            y1 = 440 - abs(a) * 40 - rnd.uniform(0, 40)
            pts = bez((x0, y0), (256 + a * 150, 190), (256 + a * 215, 330), (x1, y1), 12)
            col = rgb("4a2c14") if i % 3 else rgb("b98550")
            ink_line(dd, pts, col, rnd.choice((3, 4, 5)))
        for ex, ey in ((282, 150), (330, 172), (296, 206)):
            dd.polygon(ell_pts(ex, ey, 27, 28), fill=rgb("b88a56"))
            dd.polygon(ell_pts(ex, ey, 20, 21), fill=rgb("20120a"))
            dd.polygon(ell_pts(ex - 5, ey - 6, 6, 5), fill=rgb("7a5a3a"))
    poly(d, outline, rgb("80542f"), detail=det, gloss=0.8)
    return img


def i_mango():
    img, d = new()
    outline = spline([(112, 262), (150, 160), (262, 112), (384, 146), (446, 250), (410, 360), (300, 438), (178, 410), (122, 338)], True, 12)

    def det(dd):
        paint_soft(dd, 400, 360, 140, 110, rgb("8fc23a"), 0.9)
        paint_soft(dd, 190, 235, 150, 120, rgb("ff4a38"), 0.9)
        paint_soft(dd, 255, 300, 120, 90, rgb("ff8a2e"), 0.6)
        rnd = random.Random(8)
        for _ in range(26):
            x, y = rnd.uniform(140, 410), rnd.uniform(150, 400)
            dd.ellipse((x - 3, y - 3, x + 3, y + 3), fill=rgb("f7d26a"))
    poly(d, outline, rgb("ffb83a"), detail=det, gloss=1.1)
    poly(d, tube([(268, 130), (278, 96), (300, 72)], (26, 20)), rgb("7a5230"))
    leaf_icon(d, (296, 84), (452, 40), 62, LEAF, -14)
    return img


def i_lemon():
    img, d = new()
    f = Frame((62, 368), (450, 160))
    L = f.L
    pts = []
    for i in range(72):
        t = 2 * math.pi * i / 72
        k = 1 + 0.16 * abs(math.cos(t)) ** 16          # «носики» на концах
        pts.append(f(L / 2 + math.cos(t) * L * 0.44 * k, math.sin(t) * 138))
    ang = math.atan2(f.uy, f.ux)

    def det(dd):
        paint_soft(dd, *f(L * 0.36, -40), 110, 70, rgb("fff6a8"), 0.8, ang)
        paint_soft(dd, *f(L * 0.78, 50), 100, 70, rgb("f0b92a"), 0.6, ang)
        rnd = random.Random(5)
        for _ in range(44):
            x, y = f(rnd.uniform(L * 0.1, L * 0.9), rnd.uniform(-100, 100))
            dd.ellipse((x - 2.5, y - 2.5, x + 2.5, y + 2.5), fill=rgb("d8b928"))
    poly(d, pts, rgb("f9e84a"), detail=det, gloss=1.1)
    poly(d, tube([f(L * 0.9, 4), f(L * 0.95, -14), f(L * 1.0, -26)], (20, 15)), rgb("7a5230"))
    leaf_icon(d, f(L * 0.80, -62), (462, 60), 62, LEAF, -12)
    return img


# ----------------------------------------------------------------- дерево и камень
def _grain(dd, f, u0, u1, vs, col, w=5, wob=4):
    for k, v in enumerate(vs):
        pts = [f(u0 + (u1 - u0) * i / 8, v + math.sin(i * 1.3 + k * 2.1) * wob) for i in range(9)]
        ink_line(dd, pts, col, w)


def _log(d, p0, p1, width, bark=rgb("9a6a38"), cap=rgb("ecc98e")):
    f = Frame(p0, p1)
    L = f.L
    body = [f(0, -width / 2), f(L, -width / 2 * 0.96), f(L, width / 2 * 0.96), f(0, width / 2)]
    rnd = random.Random(int(p0[0] + p0[1]))

    def det(dd):
        paint_soft(dd, *f(L * 0.3, -width * 0.25), L * 0.4, width * 0.3, rgb("c08c52"), 0.5)
        for _ in range(11):
            u = rnd.uniform(10, L - 70)
            ink_line(dd, [f(u, v := rnd.uniform(-width * 0.42, width * 0.42)), f(u + rnd.uniform(45, 120), v + rnd.uniform(-5, 5))],
                     rgb("5f3b1c"), rnd.choice((4, 5, 6)))
    poly(d, body, bark, detail=det)
    ang = math.atan2(f.uy, f.ux)
    cx, cy = f(L, 0)

    def det_cap(dd):
        for k, r_ in enumerate((0.8, 0.55, 0.3)):
            dd.line(ell_pts(cx, cy, width * 0.16 * r_ * 1.05, width * 0.46 * r_, ang)[:], fill=rgb("c79a5e"), width=5)
        dd.polygon(ell_pts(cx, cy, 4, 8, ang), fill=rgb("a8743a"))
    ell(d, cx, cy, width * 0.19, width * 0.48, cap, ang, detail=det_cap, puff=0.5)


def i_wood():
    img, d = new()
    _log(d, (70, 345), (360, 300), 128)
    _log(d, (110, 205), (400, 160), 128, bark=rgb("a57440"))
    return img


def _plank(d, cy, ang, col, seed, length=410, th=104):
    pts = []
    c, s = math.cos(ang), math.sin(ang)
    for x, y in ((-length / 2, -th / 2), (length / 2, -th / 2), (length / 2, th / 2), (-length / 2, th / 2)):
        pts.append((256 + x * c - y * s, cy + x * s + y * c))
    f = Frame((256 - length / 2 * c, cy - length / 2 * s), (256 + length / 2 * c, cy + length / 2 * s))
    rnd = random.Random(seed)

    def det(dd):
        paint_soft(dd, *f(length * 0.3, -th * 0.2), length * 0.4, th * 0.3, lighten_c(col, 0.3), 0.6)
        _grain(dd, f, 8, length - 8, [-th * 0.3, -th * 0.08, th * 0.16, th * 0.34], darken_c(col, 0.16), 4, 3)
        kx, ky = f(rnd.uniform(0.25, 0.7) * length, rnd.uniform(-0.15, 0.15) * th)
        dd.polygon(ell_pts(kx, ky, 17, 11, ang), fill=darken_c(col, 0.32))
        dd.polygon(ell_pts(kx, ky, 8, 5, ang), fill=darken_c(col, 0.46))
        for u in (22, length - 22):
            nx, ny = f(u, 0)
            dd.ellipse((nx - 8, ny - 8, nx + 8, ny + 8), fill=rgb("5d6670"))
            dd.ellipse((nx - 4, ny - 5, nx, ny - 1), fill=rgb("c7ced6"))
    poly(d, pts, col, detail=det)


def i_plank():
    img, d = new()
    _plank(d, 330, -0.06, rgb("d49a5a"), 1)
    _plank(d, 210, 0.05, rgb("e0aa68"), 2)
    return img


def i_stone():
    img, d = new()
    outline = spline([(70, 300), (95, 210), (180, 130), (290, 110), (390, 150), (445, 240), (430, 340), (340, 410), (200, 420), (110, 380)], True, 12)

    def det(dd):
        paint_soft(dd, 200, 190, 150, 90, rgb("d3d8de"), 0.7)
        dd.polygon([(140, 235), (200, 150), (300, 130), (260, 215), (180, 270)], fill=rgb("c4cad2"))
        dd.polygon([(300, 130), (390, 160), (420, 250), (330, 270), (260, 215)], fill=rgb("a3a9b2"))
        ink_line(dd, [(260, 215), (330, 270), (345, 350)], rgb("7f858f"), 6)
        ink_line(dd, [(180, 270), (260, 215)], rgb("8d939d"), 5)
        paint_soft(dd, 360, 370, 130, 60, rgb("737a85"), 0.7)
    poly(d, outline, rgb("aab0b8"), detail=det, gloss=0.6)
    return img


# ----------------------------------------------------------------- инструменты
def _handle(d, f, u0, u1, w0, w1, col=WOOD):
    path = [f(u0 + (u1 - u0) * i / 12, 0) for i in range(13)]
    body = tube(path, (w0, w1))

    def det(dd):
        _grain(dd, f, u0 + 6, u1 - 6, [-w1 * 0.22, w1 * 0.1, w1 * 0.28], WOOD_DK, 4, 1.5)
        ink_line(dd, [f(u0 + 6, -w0 * 0.3), f(u1 - 6, -w1 * 0.3)], WOOD_LT, 6)
    poly(d, body, col, detail=det)


def _lash(d, f, u, span, w=40, n=3):
    for k in range(n):
        uu = u + k * span / max(n - 1, 1)
        poly(d, [f(uu - 7, -w / 2 - 3), f(uu + 9, -w / 2 - 3), f(uu + 9, w / 2 + 3), f(uu - 7, w / 2 + 3)], ROPE,
             detail=lambda dd, uu=uu: ink_line(dd, [f(uu, -w / 2), f(uu + 2, w / 2)], ROPE_DK, 4))


def i_shovel():
    img, d = new()
    f = Frame((105, 85), (415, 455))
    L = f.L
    _handle(d, f, 40, L * 0.62, 38, 34)
    poly(d, tube([f(36, -62), f(36, 62)], 36), WOOD, detail=lambda dd: ink_line(dd, [f(36, -52), f(36, 52)], WOOD_LT, 6))
    blade = spline(f.pts([(L * 0.60, -20), (L * 0.64, -60), (L * 0.76, -78), (L * 0.90, -62), (L * 0.985, -26), (L * 1.0, 0),
                          (L * 0.985, 26), (L * 0.90, 62), (L * 0.76, 78), (L * 0.64, 60), (L * 0.60, 20)]), True, 10)

    def det(dd):
        paint_soft(dd, *f(L * 0.72, -30), 70, 40, STEEL_LT, 0.8)
        ink_line(dd, [f(L * 0.70, 0), f(L * 0.93, 0)], STEEL_LT, 9)
        ink_line(dd, [f(L * 0.66, -52), f(L * 0.78, -66), f(L * 0.90, -52)], STEEL_DK, 5)
        ink_line(dd, [f(L * 0.66, 52), f(L * 0.78, 66), f(L * 0.90, 52)], STEEL_DK, 5)
    poly(d, blade, STEEL, detail=det, gloss=1.1)
    poly(d, [f(L * 0.575, -24), f(L * 0.67, -30), f(L * 0.67, 30), f(L * 0.575, 24)], STEEL_DK,
         detail=lambda dd: ink_line(dd, [f(L * 0.59, -14), f(L * 0.66, -14)], STEEL, 5))
    return img


def _machete(blade_col, hl, dk, grip_col, guard_col, rivets=False):
    img, d = new()
    f = Frame((85, 445), (440, 70))
    L = f.L
    grip = tube([f(0, 0), f(L * 0.22, 0)], (46, 42))

    def gdet(dd):
        for k in range(5):
            u = 12 + k * 20
            ink_line(dd, [f(u, -22), f(u + 10, 22)], darken_c(grip_col, 0.4), 5)
        if rivets:
            for u in (30, 78):
                x, y = f(u, 0)
                dd.ellipse((x - 8, y - 8, x + 8, y + 8), fill=guard_col)
    poly(d, grip, grip_col, detail=gdet)
    blade = spline(f.pts([(L * 0.24, -22), (L * 0.55, -26), (L * 0.80, -34), (L * 0.96, -30), (L * 1.0, -4), (L * 0.93, 34),
                          (L * 0.80, 56), (L * 0.55, 44), (L * 0.24, 22)]), True, 10)

    def det(dd):
        paint_soft(dd, *f(L * 0.5, -14), 130, 16, hl, 0.9)
        ink_line(dd, f.pts([(L * 0.30, -6), (L * 0.60, -8), (L * 0.88, -12)]), hl, 8)
        ink_line(dd, f.pts([(L * 0.30, 14), (L * 0.60, 30), (L * 0.90, 24)]), dk, 5)
    poly(d, blade, blade_col, detail=det, gloss=1.1)
    poly(d, tube([f(L * 0.225, -34), f(L * 0.225, 34)], 18, False), guard_col)
    return img


def i_machete():
    return _machete(STEEL, STEEL_LT, STEEL_DK, rgb("8a5230"), rgb("c9a45a"))


def i_iron_machete():
    return _machete(rgb("69767f"), rgb("c4cfd9"), rgb("48535c"), rgb("4a2a1a"), rgb("d2a548"), True)


def i_mangrove_wood():
    img, d = new()
    for k, (y, x0) in enumerate(((360, 70), (255, 100), (150, 70))):
        _log(d, (x0, y), (x0 + 290, y - 22), 104, bark=rgb("8a5a40") if k % 2 else rgb("7a4c36"), cap=rgb("e6b896"))
    return img


def i_mangrove_plank():
    img, d = new()
    for k, (y, ang) in enumerate(((365, -0.05), (255, 0.04), (145, -0.03))):
        _plank(d, y, ang, rgb("b8774a") if k % 2 else rgb("a8683e"), 7 + k, 400, 92)
    return img


def _axe(stone):
    img, d = new()
    f = Frame((70, 470), (300, 150))
    L = f.L
    _handle(d, f, 0, L + 10, 46, 38, WOOD if stone else rgb("a97844"))
    if stone:
        head = spline(f.pts([(L - 50, -40), (L + 4, -52), (L + 40, -20), (L + 64, 50), (L + 98, 130), (L + 92, 172), (L + 50, 190),
                             (L - 14, 172), (L - 70, 150), (L - 92, 112), (L - 62, 50), (L - 52, -4)]), True, 2)

        def det(dd):
            paint_soft(dd, *f(L - 10, 40), 80, 60, rgb("d3d9e0"), 0.8)
            dd.polygon(f.pts([(L + 50, 190), (L + 92, 172), (L + 98, 130), (L + 64, 50), (L + 44, 120)]), fill=rgb("eef2f6"))
            ink_line(dd, f.pts([(L - 40, 30), (L + 6, 90), (L + 30, 150)]), rgb("7a828c"), 5)
            ink_line(dd, f.pts([(L - 20, -16), (L + 14, 40)]), rgb("7a828c"), 5)
            ink_line(dd, f.pts([(L - 60, 110), (L - 14, 150)]), rgb("858c96"), 5)
        poly(d, head, rgb("a4abb4"), detail=det, gloss=0.6)
        _lash(d, f, L - 40, 56, 54, 3)
    else:
        head = spline(f.pts([(L - 44, -46), (L + 14, -46), (L + 24, -8), (L + 56, 44), (L + 96, 124), (L + 100, 160), (L + 64, 184),
                             (L + 8, 176), (L - 74, 190), (L - 104, 160), (L - 80, 112), (L - 52, 44), (L - 46, -6)]), True, 9)

        def det(dd):
            paint_soft(dd, *f(L - 10, 60), 80, 60, rgb("8995a2"), 0.8)
            ink_line(dd, f.pts([(L - 90, 164), (L - 30, 176), (L + 40, 176), (L + 86, 160)]), rgb("eef3f8"), 8)
            ink_line(dd, f.pts([(L - 20, -30), (L + 4, 20), (L + 40, 90), (L + 70, 130)]), rgb("a5b2bf"), 5)
        poly(d, head, rgb("69767f"), detail=det, gloss=1.0)
        poly(d, [f(L - 36, -52), f(L + 20, -52), f(L + 20, 52), f(L - 36, 52)], rgb("4f5a64"),
             detail=lambda dd: ink_line(dd, [f(L - 28, -36), f(L + 12, -36)], rgb("8a97a4"), 5))
    return img


def i_stone_axe():
    return _axe(True)


def i_iron_axe():
    return _axe(False)


def _pick(head, hl, dk, wood):
    img, d = new()
    f = Frame((130, 470), (340, 95))
    L = f.L
    _handle(d, f, 0, L + 30, 46, 38, wood)
    outer = [(L - 40, -196), (L - 2, -140), (L + 26, -64), (L + 36, 0), (L + 26, 64), (L - 2, 140), (L - 40, 196)]
    inner = [(L - 64, 180), (L - 34, 120), (L - 14, 56), (L - 8, 0), (L - 14, -56), (L - 34, -120), (L - 64, -180)]
    hd = spline(f.pts(outer + inner), True, 8)

    def det(dd):
        paint_soft(dd, *f(L, -110), 90, 40, hl, 0.9)
        ink_line(dd, f.pts([(L - 30, -160), (L + 6, -90), (L + 22, -30)]), hl, 7)
        ink_line(dd, f.pts([(L - 30, 160), (L + 6, 90), (L + 22, 30)]), dk, 6)
    poly(d, hd, head, detail=det, gloss=1.1)
    poly(d, [f(L - 26, -30), f(L + 20, -30), f(L + 20, 30), f(L - 26, 30)], dk,
         detail=lambda dd: ink_line(dd, [f(L - 20, -18), f(L + 14, -18)], head, 5))
    return img


def i_pickaxe():
    return _pick(STEEL, STEEL_LT, STEEL_DK, WOOD)


def i_iron_pickaxe():
    return _pick(rgb("69767f"), rgb("c4cfd9"), rgb("48535c"), rgb("a97844"))


def i_ice_pick():
    img, d = new()
    f = Frame((95, 470), (330, 150))
    L = f.L
    _handle(d, f, 0, L, 40, 34, rgb("5f86b0"))

    def grip(dd):
        for u in range(30, int(L * 0.42), 22):
            ink_line(dd, [f(u, -20), f(u + 12, 20)], rgb("a82e28"), 5)
    poly(d, tube([f(20, 0), f(L * 0.42, 0)], 46, False), rgb("d9483c"), detail=grip)
    poly(d, [f(-4, -16), f(-4, 16), f(-46, 0)], STEEL, gloss=1.0)           # острый шип на конце
    outer = [(L - 30, -170), (L + 2, -120), (L + 24, -50), (L + 30, 0), (L + 24, 50), (L + 6, 90), (L - 6, 130)]
    inner = [(L - 40, 118), (L - 24, 80), (L - 8, 40), (L - 6, 0), (L - 10, -50), (L - 30, -110), (L - 54, -150)]
    hd = spline(f.pts(outer + inner), True, 8)

    def det(dd):
        paint_soft(dd, *f(L, -90), 80, 36, STEEL_LT, 0.9)
        ink_line(dd, f.pts([(L - 24, -140), (L + 6, -80), (L + 18, -26)]), STEEL_LT, 7)
    poly(d, hd, STEEL, detail=det, gloss=1.1)
    poly(d, [f(L - 24, -28), f(L + 20, -28), f(L + 20, 28), f(L - 24, 28)], STEEL_DK)
    return img


def i_ice_drill():
    img, d = new()
    poly(d, tube([(256, 110), (256, 420)], 30, False), STEEL_DK,
         detail=lambda dd: ink_line(dd, [(248, 120), (248, 410)], STEEL, 6))
    for k in range(6):
        y = 205 + k * 42
        body = tube(spline([(256 - 78, y + 28), (256, y + 4), (256 + 78, y - 22)], False, 8), 40)
        poly(d, body, STEEL, detail=lambda dd, y=y: ink_line(dd, [(256 - 66, y + 14), (256, y - 8), (256 + 64, y - 32)], STEEL_LT, 6), gloss=1.0)
    poly(d, [(226, 455), (286, 455), (256, 506)], STEEL_DK)
    poly(d, tube([(256, 70), (256, 140)], 46, False), STEEL_DK)
    poly(d, tube([(130, 82), (382, 82)], 36), WOOD, detail=lambda dd: ink_line(dd, [(145, 72), (370, 72)], WOOD_LT, 7))
    return img


def i_fishing_rod():
    img, d = new()
    path = bez((88, 450), (190, 300), (330, 170), (445, 62), 35)
    ws = [38 - 24 * i / 35 for i in range(36)]
    poly(d, tube(path, ws), rgb("c79a4a"), detail=lambda dd: ink_line(dd, offset_path(path, ws, -0.25)[2:-2], rgb("eccf8a"), 5))
    for i in (12, 20, 27):                      # колечки-проводники
        x, y = path[i]
        poly(d, ell_pts(x + 3, y - 15, 10, 10), STEEL, w=10)

    def cork(dd):
        for j in range(1, 8):
            ink_line(dd, [(path[j][0] - 18, path[j][1] - 8), (path[j][0] + 18, path[j][1] + 8)], rgb("b68a50"), 4)
    poly(d, tube(path[:9], 52), rgb("e1b878"), detail=cork)

    def reel(dd):
        dd.polygon(ell_pts(185, 405, 16, 16), fill=STEEL_DK)
        ink_line(dd, [(185, 405), (225, 380)], rgb("d9483c"), 8)
    poly(d, ell_pts(185, 405, 40, 40), STEEL, detail=reel)
    line(d, bez((445, 62), (470, 170), (462, 260), (455, 322), 20), rgb("3b3b3b"), 4)
    poly(d, ell_pts(455, 352, 28, 34), rgb("f6f0e6"), detail=lambda dd: dd.polygon([(420, 318), (490, 318), (490, 352), (420, 352)], fill=rgb("e04a3c")))
    return img


def i_net():
    img, d = new()
    f = Frame((70, 470), (290, 230))
    _handle(d, f, 0, f.L, 36, 30)
    cx, cy, rx, ry = 345, 160, 125, 112
    bag = ell_pts(cx, cy, rx, ry, 0, 48)[:-1]

    def det(dd):
        for k in range(-6, 7):
            dd.line([(cx + k * 26 - 120, cy - 120), (cx + k * 26 + 120, cy + 120)], fill=rgb("8fa88a"), width=4)
            dd.line([(cx + k * 26 + 120, cy - 120), (cx + k * 26 - 120, cy + 120)], fill=rgb("8fa88a"), width=4)
    poly(d, bag, rgb("eaf2e4"), detail=det, puff=0.3, gloss=0.4)
    ring = ell_pts(cx, cy, rx + 6, ry + 6, 0, 48)
    line(d, ring, rgb("5a3a1c"), 30)
    line(d, ring, WOOD, 20)
    line(d, ell_pts(cx, cy, rx + 6, ry + 6, 0, 48, math.pi * 1.0, math.pi * 1.6), WOOD_LT, 6)
    return img


def i_watering_can():
    img, d = new()
    spout = bez((150, 380), (110, 320), (90, 240), (70, 150), 20)             # носик с «розеткой»
    poly(d, tube(spout, (46, 28)), rgb("4f9fe0"))

    def rose(dd):
        for k in range(-1, 2):
            dd.ellipse((58 + k * 22 - 4, 120 - k * 8 - 4, 58 + k * 22 + 4, 120 - k * 8 + 4), fill=rgb("1f4f86"))
    poly(d, ell_pts(66, 138, 52, 22, -0.4), rgb("3b82c4"), detail=rose)
    handle = bez((330, 200), (470, 150), (480, 340), (338, 370), 24)
    poly(d, tube(handle, 30), rgb("3b82c4"))
    body = spline([(150, 210), (250, 196), (340, 210), (358, 400), (330, 432), (170, 432), (140, 400)], True, 10)

    def det(dd):
        paint_soft(dd, 195, 280, 60, 110, rgb("8cc8f4"), 0.7)
        ink_line(dd, [(150, 250), (340, 250)], rgb("3b82c4"), 7)
        ink_line(dd, [(146, 392), (346, 392)], rgb("3b82c4"), 7)
    poly(d, body, rgb("4f9fe0"), detail=det, gloss=1.1)
    poly(d, ell_pts(246, 205, 98, 26), rgb("2a5f9a"), detail=lambda dd: paint_soft(dd, 230, 205, 50, 12, rgb("1c4476"), 0.9))
    return img


ICONS = {
    "banana": i_banana, "coconut": i_coconut, "mango": i_mango, "lemon": i_lemon,
    "wood": i_wood, "plank": i_plank, "stone": i_stone,
    "shovel": i_shovel, "stone_axe": i_stone_axe, "pickaxe": i_pickaxe, "machete": i_machete, "iron_machete": i_iron_machete,
    "mangrove_wood": i_mangrove_wood, "mangrove_plank": i_mangrove_plank,
    "iron_axe": i_iron_axe, "iron_pickaxe": i_iron_pickaxe, "ice_pick": i_ice_pick, "ice_drill": i_ice_drill,
    "fishing_rod": i_fishing_rod, "net": i_net, "watering_can": i_watering_can,
}


# ----------------------------------------------------------------- овощи и прочее
def _wavy(cx, cy, rx, ry, n_wave, amp, phase=0.0, pts=72):
    out = []
    for i in range(pts):
        t = 2 * math.pi * i / pts
        k = 1 + amp * math.sin(t * n_wave + phase)
        out.append((cx + math.cos(t) * rx * k, cy + math.sin(t) * ry * k))
    return out


def i_cabbage():
    img, d = new()
    back = _wavy(256, 292, 212, 170, 9, 0.035)

    def det_back(dd):
        paint_soft(dd, 190, 220, 120, 70, rgb("86c85a"), 0.7)
        for a in (-1.0, -0.5, 0.0, 0.5, 1.0):
            ink_line(dd, bez((256, 430), (256 + a * 90, 360), (256 + a * 150, 300), (256 + a * 195, 250), 14), rgb("4f9a3c"), 6)
    poly(d, back, rgb("5fae4c"), detail=det_back)
    head = ell_pts(256, 240, 150, 142, 0, 60)[:-1]

    def det_head(dd):
        paint_soft(dd, 205, 175, 90, 70, rgb("e3f6b8"), 0.9)
        paint_soft(dd, 320, 320, 100, 70, rgb("86c85a"), 0.6)
        for a in (-1.0, -0.5, 0.0, 0.5, 1.0):
            ink_line(dd, bez((256, 380), (256 + a * 60, 300), (256 + a * 100, 220), (256 + a * 112, 130), 14), rgb("86c85a"), 5)
        ink_line(dd, bez((130, 200), (200, 150), (320, 150), (384, 210), 14), rgb("c2e68a"), 5)
    poly(d, head, rgb("b4e07c"), detail=det_head)
    for sgn in (-1, 1):
        pts = spline([(256 + sgn * 6, 450), (256 + sgn * 120, 430), (256 + sgn * 196, 350), (256 + sgn * 190, 270),
                      (256 + sgn * 130, 310), (256 + sgn * 70, 360)], True, 10)

        def det_leaf(dd, sgn=sgn):
            paint_soft(dd, 256 + sgn * 150, 330, 50, 40, rgb("9ad462"), 0.8)
            ink_line(dd, bez((256 + sgn * 20, 440), (256 + sgn * 100, 410), (256 + sgn * 150, 350), (256 + sgn * 178, 290), 12), rgb("4f9a3c"), 6)
        poly(d, pts, rgb("6cb852"), detail=det_leaf)
    return img


def i_clay():
    img, d = new()
    pts = spline([(78, 305), (96, 215), (190, 158), (300, 148), (400, 188), (444, 268), (424, 360), (330, 414), (190, 418), (108, 372)], True, 12)

    def det(dd):
        paint_soft(dd, 190, 200, 130, 70, rgb("e2956a"), 0.8)
        paint_soft(dd, 350, 360, 120, 60, rgb("96482a"), 0.7)
    poly(d, pts, rgb("c9784c"), detail=det, gloss=0.9)
    return img


def i_sand():
    img, d = new()
    pts = spline([(52, 410), (92, 336), (176, 262), (256, 222), (340, 262), (424, 336), (462, 410), (400, 436), (112, 436)], True, 10)

    def det(dd):
        paint_soft(dd, 220, 270, 120, 60, rgb("fbeec0"), 0.85)
        paint_soft(dd, 380, 400, 110, 40, rgb("c9a45e"), 0.7)
        for y, a in ((330, 0), (372, 1), (410, 0)):
            ink_line(dd, bez((110 + y * 0.08, y), (190, y - 22), (320, y + 18), (410 - y * 0.08, y), 12), rgb("d2b36f"), 5)
        rnd = random.Random(21)
        for _ in range(60):
            x, y = rnd.uniform(100, 420), rnd.uniform(290, 425)
            dd.ellipse((x - 3, y - 3, x + 3, y + 3), fill=rgb("c19b58") if rnd.random() < 0.6 else rgb("fff3cf"))
    poly(d, pts, rgb("eed49a"), detail=det, gloss=0.4)
    return img


def i_pepper():
    img, d = new()
    path = bez((236, 160), (372, 190), (384, 350), (232, 468), 34)
    ws = [20 + 74 * math.sin(math.pi * 0.5 * min(1.0, (i / 34) * 1.35 + 0.0)) ** 0.8 if i < 12 else 0 for i in range(35)]
    ws = [92 * (1 - (i / 34)) ** 0.7 + 8 for i in range(35)]

    def det(dd):
        paint_soft(dd, 282, 230, 40, 70, rgb("ff7a62"), 0.8, 0.5)
        paint_soft(dd, 330, 380, 50, 70, rgb("b01e1c"), 0.6)
    poly(d, tube(path, ws), rgb("e63a2c"), detail=det, gloss=1.2)
    cap = spline([(196, 168), (214, 136), (248, 126), (284, 138), (298, 168), (262, 186), (224, 188)], True, 8)
    poly(d, cap, rgb("4fa044"), detail=lambda dd: paint_soft(dd, 238, 150, 32, 20, rgb("8ad060"), 0.8))
    poly(d, tube([(246, 134), (240, 100), (262, 66)], (20, 13)), rgb("5f9a3a"))
    return img


def _sail(patch):
    img, d = new()
    poly(d, tube([(150, 62), (150, 458)], 22), rgb("96643a"), detail=lambda dd: ink_line(dd, [(144, 70), (144, 450)], WOOD_LT, 5))
    edge = bez((168, 90), (260, 180), (360, 270), (452, 408), 24)
    cloth = spline(edge + [(300, 424), (168, 420)], True, 4)

    def det(dd):
        paint_soft(dd, 230, 250, 90, 120, rgb("fffaf0"), 0.8)
        paint_soft(dd, 400, 380, 80, 40, rgb("d5c6a2"), 0.8)
        for k in range(3):
            y = 190 + k * 75
            ink_line(dd, bez((172, y), (230, y + 14), (300, y + 8), (350 + k * 30, y - 10), 10), rgb("d9ccaa"), 5)
        if patch:
            dd.polygon([(260, 300), (340, 292), (346, 366), (268, 372)], fill=rgb("c8503a"))
            ink_line(dd, [(260, 300), (346, 366)], rgb("a03a28"), 4)
            ink_line(dd, [(340, 292), (268, 372)], rgb("a03a28"), 4)
        else:
            dd.polygon([(168, 300), (480, 290), (480, 340), (168, 350)], fill=rgb("4f8fd8"))
    poly(d, cloth, rgb("f4ead2"), detail=det, puff=0.5, gloss=0.5)
    poly(d, tube([(150, 424), (310, 438)], 20), rgb("96643a"))
    return img


def i_sail():
    return _sail(False)


def i_ship_sail():
    return _sail(True)


def i_brick():
    img, d = new()
    rnd = random.Random(12)
    for x, y in ((140, 340), (370, 340), (255, 200)):
        pts = [(x - 112, y - 56), (x + 112, y - 56), (x + 112, y + 56), (x - 112, y + 56)]

        def det(dd, x=x, y=y):
            paint_soft(dd, x - 40, y - 20, 90, 30, rgb("e2805a"), 0.7)
            paint_soft(dd, x + 60, y + 30, 70, 25, rgb("8f3a22"), 0.6)
            for _ in range(22):
                px, py = rnd.uniform(x - 100, x + 100), rnd.uniform(y - 44, y + 44)
                dd.ellipse((px - 3, py - 3, px + 3, py + 3), fill=rgb("9a432a") if rnd.random() < 0.6 else rgb("e89a74"))
        poly(d, pts, rgb("c4603e"), detail=det, gloss=0.6)
    return img


def _nails(col, head, tip):
    img, d = new()
    for k in range(5):
        a = (k - 2) * 0.13
        hx, hy = 256 + (k - 2) * 62, 120 + abs(k - 2) * 14
        ex, ey = hx + math.sin(a) * 340 + (k - 2) * 8, hy + 340
        shank = tube([(hx, hy), (ex, ey)], (24, 10))
        poly(d, shank, col, detail=lambda dd, hx=hx, hy=hy, ex=ex, ey=ey: ink_line(dd, [(hx - 5, hy + 20), (ex - 3, ey - 20)], tip, 5))
        poly(d, ell_pts(hx, hy, 40, 17, -a), head, gloss=1.1)
    return img


def i_copper_nails():
    return _nails(rgb("d9884a"), rgb("e8a566"), rgb("f6c08a"))


def i_iron_nails():
    return _nails(rgb("8a949e"), rgb("6c7882"), rgb("d3dbe2"))


def i_wool():
    img, d = new()
    bumps = [(150, 305, 88), (256, 335, 92), (362, 305, 88), (178, 205, 88), (336, 200, 92), (256, 255, 100)]
    shapes = [ell_pts(x, y, r, r * 0.92, 0, 36)[:-1] for x, y, r in bumps]

    def det(dd):
        paint_soft(dd, 200, 200, 120, 90, rgb("ffffff"), 0.8)
        paint_soft(dd, 330, 340, 130, 70, rgb("cfc6b4"), 0.7)
        for x, y, r in bumps:
            ink_line(dd, bez((x - r * 0.5, y + r * 0.2), (x - r * 0.2, y - r * 0.4), (x + r * 0.3, y - r * 0.35), (x + r * 0.5, y + r * 0.2), 10), rgb("d8cfbd"), 5)
    poly(d, shapes, rgb("f6f1e6"), detail=det, gloss=0.5)
    return img


def i_wool_cloth():
    img, d = new()
    for cy, cw, col, ang in ((350, 390, rgb("efe3cc"), 0.02), (225, 340, rgb("f6ecd8"), -0.025)):
        c, s = math.cos(ang), math.sin(ang)
        pts = [(256 + x * c - y * s, cy + x * s + y * c) for x, y in ((-cw / 2, -78), (cw / 2, -78), (cw / 2, 78), (-cw / 2, 78))]

        def det(dd, cy=cy, cw=cw):
            for k in range(-10, 11):
                dd.line([(256 - cw / 2, cy + k * 12), (256 + cw / 2, cy + k * 12)], fill=rgb("e0d2b8"), width=3)
                dd.line([(256 + k * 18, cy - 78), (256 + k * 18, cy + 78)], fill=rgb("e0d2b8"), width=3)
            dd.polygon([(256 - cw / 2, cy + 52), (256 + cw / 2, cy + 52), (256 + cw / 2, cy + 78), (256 - cw / 2, cy + 78)], fill=rgb("d9573b"))
            paint_soft(dd, 256 - cw * 0.2, cy - 40, cw * 0.3, 30, rgb("ffffff"), 0.7)
        poly(d, pts, col, detail=det, puff=0.5, gloss=0.4)
    return img


ICONS.update({
    "cabbage": i_cabbage, "clay": i_clay, "sand": i_sand, "pepper": i_pepper, "sail": i_sail, "ship_sail": i_ship_sail,
    "brick": i_brick, "copper_nails": i_copper_nails, "iron_nails": i_iron_nails, "wool": i_wool, "wool_cloth": i_wool_cloth,
})
