"""Иконки украшений лагеря и котелка («вечная игра», вкладка «Декор» в строительстве).
Подключаются через icons_decor.ICONS. Стиль — как в gen_icons.py: объёмные детали poly(...), тёплая обводка."""
import math

from gen_icons import (blob, ell, ell_pts, ink_line, leaf_shape, line, new, paint_soft, poly, quad_curve, rgb, spline, tube)

WOOD = rgb("c08a50")
WOOD_DK = rgb("8f5d2e")
WOOD_LT = rgb("e2b377")
IRON = rgb("4a4c55")
STONE = rgb("a8a49c")
ROPE = rgb("dcbc80")
RED = rgb("d9483a")
BLUE = rgb("4f8fd8")
YELLOW = rgb("f2c23a")
GREEN = rgb("4fa64a")
PINK = rgb("ff7fa8")
VIOLET = rgb("a884e8")
CREAM = rgb("f4ecd8")
LAMP = rgb("ffd86a")
WHITE = rgb("f6f2e6")
PETALS = [PINK, YELLOW, rgb("ffffff"), VIOLET, rgb("f28a3a"), RED]


def R(d, x0, y0, x1, y1, col, **kw):
    poly(d, [(x0, y0), (x1, y0), (x1, y1), (x0, y1)], col, **kw)


def post(d, x, y0, y1, w=26, col=WOOD_DK):
    poly(d, tube([(x, y1), (x, y0)], w), col)


def grain(x0, x1, ys, col=WOOD_DK):
    return lambda dd: [ink_line(dd, [(x0, y), (x1, y + 3)], col, 5) for y in ys]


def flower(d, x, y, col, r=20):
    poly(d, [ell_pts(x + math.cos(k * 1.2566) * r * 0.75, y + math.sin(k * 1.2566) * r * 0.75, r * 0.62, r * 0.62, n=12) for k in range(5)], col, w=10)
    ell(d, x, y, r * 0.42, r * 0.42, rgb("ffb02e"), w=0)


def leaves(d, x, y, n=3, s=44):
    for k in range(n):
        a = -math.pi / 2 + (k - (n - 1) / 2) * 0.8
        poly(d, leaf_shape((x, y), (x + math.cos(a) * s, y + math.sin(a) * s), 0, 13), GREEN, w=7)


def lamp(d, cx, cy, s=54):
    poly(d, [(cx - s * 0.75, cy - s), (cx + s * 0.75, cy - s), (cx, cy - s * 1.7)], IRON)
    R(d, cx - s * 0.62, cy - s, cx + s * 0.62, cy + s * 0.7, LAMP, detail=lambda dd: paint_soft(dd, cx, cy, s * 0.4, s * 0.5, rgb("fff6c0"), 0.9), gloss=1.4)
    R(d, cx - s * 0.75, cy + s * 0.62, cx + s * 0.75, cy + s * 0.92, IRON, w=8)
    d.line([(cx, cy - s), (cx, cy + s * 0.62)], fill=IRON, width=8)


# ------------------------------------------------------------------ котелок
def i_cook_pot():
    img, d = new()
    for sx in (-1, 1):
        poly(d, tube([(256 + sx * 190, 470), (256 + sx * 20, 60)], 24), WOOD_DK)
    d.line([(256, 80), (256, 190)], fill=IRON, width=10)
    poly(d, tube(quad_curve((120, 250), (256, 120), (392, 250)), 12), IRON, w=8)
    body = spline([(116, 250), (396, 250), (410, 330), (350, 420), (256, 440), (162, 420), (102, 330)], True, 8)
    poly(d, body, rgb("3a3b44"), detail=lambda dd: paint_soft(dd, 190, 320, 40, 60, rgb("6a6d7a"), 0.8), gloss=1.3)
    ell(d, 256, 250, 150, 44, rgb("e8a43a"), detail=lambda dd: paint_soft(dd, 230, 244, 70, 16, rgb("f8d27a"), 0.8), puff=0.4)
    for x, y, c in ((210, 246, "e8443a"), (280, 256, "4f9a4a"), (320, 242, "f58a1f")):
        ell(d, x, y, 18, 11, rgb(c), w=5)
    for x in (200, 256, 312):
        line(d, quad_curve((x, 200), (x - 22, 160), (x + 6, 120)), rgb("ffffff", 200), 11)
    poly(d, [ell_pts(210, 478, 26, 34, n=14), ell_pts(256, 462, 30, 46, n=14), ell_pts(302, 478, 26, 34, n=14)], rgb("ff8a2a"), w=10)
    return img


# ------------------------------------------------------------------ мебель
def i_camp_table():
    img, d = new()
    for x in (130, 382):
        post(d, x, 250, 450, 30)
    poly(d, [(70, 200), (442, 200), (470, 262), (42, 262)], WOOD, detail=grain(80, 440, (222, 244)))
    poly(d, [(200, 196), (312, 196), (324, 262), (188, 262)], CREAM, w=8, detail=lambda dd: [dd.line([(196, y), (318, y)], fill=RED, width=9) for y in (212, 240)])
    R(d, 120, 150, 168, 206, rgb("c8683e"), w=9)
    R(d, 350, 150, 398, 206, BLUE, w=9)
    for k, c in enumerate(("ff9f2e", "e8443a", "ffe14d")):
        ell(d, 232 + k * 26, 186 - (k % 2) * 14, 20, 20, rgb(c), w=7)
    return img


def i_camp_stool():
    img, d = new()
    for x0, x1 in ((180, 130), (256, 256), (332, 382)):
        poly(d, tube([(x0, 260), (x1, 460)], 30), WOOD_DK)
    ell(d, 256, 250, 170, 52, WOOD, puff=0.5)
    ell(d, 256, 208, 150, 60, RED, detail=lambda dd: [dd.line([(140 + k * 56, 160), (140 + k * 56, 262)], fill=CREAM, width=12) for k in range(5)])
    return img


def i_rocking_chair():
    img, d = new()
    poly(d, tube(quad_curve((90, 420), (256, 500), (440, 400)), 26), WOOD_DK)
    post(d, 170, 300, 440, 22)
    post(d, 360, 110, 440, 22)
    poly(d, [(150, 290), (370, 290), (380, 330), (140, 330)], WOOD)
    poly(d, tube([(360, 80), (350, 300)], 20), WOOD)
    poly(d, [(262, 96), (372, 96), (366, 290), (270, 290)], RED, detail=lambda dd: ([dd.line([(260, y), (374, y)], fill=CREAM, width=9) for y in (140, 200, 260)],
                                                                              [dd.line([(x, 96), (x, 292)], fill=CREAM, width=9) for x in (296, 338)]))
    poly(d, tube([(150, 240), (360, 232)], 22), WOOD_LT)
    return img


def i_camp_shelf():
    img, d = new()
    R(d, 96, 60, 416, 460, rgb("9a6a3a"))
    R(d, 124, 86, 388, 434, rgb("6a4424"), w=0)
    for y in (196, 316, 434):
        R(d, 108, y - 14, 404, y + 12, WOOD, w=8)
    poly(d, spline([(150, 182), (140, 140), (160, 110), (180, 110), (200, 140), (190, 182)], True, 6), rgb("c8683e"), w=8)
    for k, c in enumerate((WHITE, RED, YELLOW)):
        R(d, 236 + k * 46, 142, 270 + k * 46, 182, c, w=7)
    poly(d, ell_pts(180, 280, 44, 34, 0, 20, 0, math.pi), rgb("d8c8a0"), w=8)
    poly(d, spline([(300, 302), (290, 250), (312, 222), (336, 222), (356, 250), (346, 302)], True, 6), BLUE, w=8)
    R(d, 144, 370, 196, 420, rgb("f2a93a"), w=8)
    poly(d, ell_pts(310, 380, 60, 44, 0, 20, 0, math.pi), rgb("d6ad55"), w=8)
    return img


def i_decor_chest():
    img, d = new()
    R(d, 70, 250, 442, 440, rgb("3f9a9a"), detail=lambda dd: [dd.polygon([(130 + k * 76, 345), (160 + k * 76, 300), (190 + k * 76, 345), (160 + k * 76, 390)], fill=YELLOW) for k in range(4)])
    lid = spline([(70, 256), (70, 190), (130, 120), (382, 120), (442, 190), (442, 256)], True, 8)
    poly(d, lid, RED, detail=lambda dd: (dd.rectangle((240, 100, 272, 270), fill=YELLOW), paint_soft(dd, 170, 160, 60, 24, rgb("ff8a6a"), 0.7)))
    for x in (120, 392):
        R(d, x - 14, 118, x + 14, 440, IRON, w=6)
    R(d, 226, 226, 286, 300, rgb("d8a83a"), w=9)
    return img


# ------------------------------------------------------------------ коврики
def i_rug_wool():
    img, d = new()
    cols = [rgb("c8503a"), CREAM, rgb("4a7ab8"), CREAM, rgb("e8b42a"), CREAM]
    pts = [(120, 180), (470, 250), (392, 400), (42, 330)]

    def det(dd):
        for k in range(12):
            t0, t1 = k / 12, (k + 1) / 12
            a = (120 + 350 * t0, 180 + 70 * t0)
            b = (120 + 350 * t1, 180 + 70 * t1)
            dd.polygon([a, b, (b[0] - 78, b[1] + 150), (a[0] - 78, a[1] + 150)], fill=cols[k % 6])
    poly(d, pts, rgb("c8503a"), detail=det, puff=0.3)
    for k in range(7):
        t = k / 6
        for (ax, ay, dx) in ((120 - 78 * t, 180 + 150 * t, -26), (470 - 78 * t, 250 + 150 * t, 26)):
            d.line([(ax, ay), (ax + dx, ay - 6)], fill=rgb("8a5a32"), width=7)
    return img


def i_rug_straw():
    img, d = new()

    def det(dd):
        for k, r in enumerate((190, 160, 128, 96, 62, 30)):
            c = rgb("b8583a") if k in (1, 4) else (rgb("e2bf6a") if k % 2 else rgb("c89a44"))
            dd.ellipse((256 - r, 290 - r * 0.56, 256 + r, 290 + r * 0.56), fill=c)
    ell(d, 256, 290, 215, 122, rgb("d6ad55"), detail=det, puff=0.35)
    return img


# ------------------------------------------------------------------ гирлянды
def _posts(d):
    post(d, 80, 90, 470, 24)
    post(d, 432, 90, 470, 24)


def i_garland_flags():
    img, d = new()
    _posts(d)
    curve = quad_curve((80, 120), (256, 300), (432, 120), 20)
    line(d, curve, rgb("8f6a3a"), 9)
    for k, c in enumerate((RED, YELLOW, BLUE, GREEN, PINK)):
        x, y = curve[2 + k * 4]
        poly(d, [(x - 30, y), (x + 30, y), (x, y + 78)], c, w=10)
    return img


def i_garland_lights():
    img, d = new()
    _posts(d)
    curve = quad_curve((80, 120), (256, 300), (432, 120), 20)
    line(d, curve, rgb("4a3b30"), 9)
    for k in range(5):
        x, y = curve[2 + k * 4]
        ell(d, x, y + 34, 27, 32, LAMP if k % 2 == 0 else rgb("ffb36a"), w=10, gloss=1.6)
        R(d, x - 10, y - 4, x + 10, y + 10, IRON, w=0)
    return img


# ------------------------------------------------------------------ фонарики
def i_lantern_post():
    img, d = new()
    post(d, 170, 60, 470, 30)
    poly(d, tube([(170, 100), (360, 80)], 20), WOOD_DK)
    for k in range(3):
        ell(d, 140 + k * 30, 468, 22, 14, STONE, w=7)
    d.line([(340, 90), (340, 150)], fill=IRON, width=8)
    lamp(d, 340, 250, 62)
    return img


def i_paper_lantern():
    img, d = new()
    poly(d, tube([(150, 470), (150, 70)], 22), rgb("e0c06a"), detail=lambda dd: [dd.line([(138, y), (162, y)], fill=rgb("a88a3a"), width=5) for y in (150, 250, 350)])
    poly(d, tube(quad_curve((150, 80), (240, 20), (320, 90)), 14), rgb("c9a050"), w=9)
    body = spline([(320, 110), (400, 150), (424, 240), (400, 330), (320, 370), (240, 330), (216, 240), (240, 150)], True, 8)
    poly(d, body, rgb("e8443a"), detail=lambda dd: ([dd.arc((216 + k * 30, 110, 424 - k * 30, 370), 0, 360, fill=rgb("b82a22"), width=5) for k in range(1, 3)],
                                                    paint_soft(dd, 320, 240, 50, 80, rgb("ffb04a"), 0.85)), gloss=1.3)
    R(d, 286, 96, 354, 120, rgb("3a2a20"), w=7)
    R(d, 286, 362, 354, 386, rgb("3a2a20"), w=7)
    poly(d, tube([(320, 386), (320, 460)], (10, 26)), YELLOW, w=7)
    return img


def i_stone_lantern():
    img, d = new()
    poly(d, [(150, 430), (362, 430), (340, 470), (172, 470)], STONE)
    R(d, 216, 300, 296, 432, STONE)
    poly(d, [(150, 270), (362, 270), (340, 306), (172, 306)], STONE)
    R(d, 186, 170, 326, 272, STONE, detail=lambda dd: (dd.rectangle((226, 190, 286, 256), fill=LAMP), paint_soft(dd, 256, 222, 20, 26, rgb("fff6c0"), 0.9)))
    poly(d, [(110, 176), (402, 176), (300, 90), (212, 90)], rgb("8a867e"), detail=lambda dd: paint_soft(dd, 190, 150, 40, 14, rgb("6d9a40"), 0.8))
    ell(d, 256, 78, 26, 26, STONE, w=10)
    return img


# ------------------------------------------------------------------ клумбы
def i_flower_tub():
    img, d = new()
    leaves(d, 256, 250, 5, 80)
    for k, (x, y) in enumerate(((180, 170), (256, 120), (330, 170), (220, 220), (296, 222))):
        flower(d, x, y, PETALS[k], 30)
    poly(d, [(120, 270), (392, 270), (360, 460), (152, 460)], WOOD, detail=lambda dd: [dd.line([(160 + k * 48, 270), (172 + k * 42, 460)], fill=WOOD_DK, width=6) for k in range(5)])
    for y in (310, 420):
        R(d, 130 + (y - 310) * 0.2, y - 10, 382 - (y - 310) * 0.2, y + 10, IRON, w=6)
    return img


def i_flower_barrow():
    img, d = new()
    poly(d, tube([(60, 250), (300, 330)], 20), WOOD_DK)
    leaves(d, 250, 240, 5, 70)
    for k, (x, y) in enumerate(((190, 170), (260, 130), (330, 160), (230, 215), (310, 220), (380, 200))):
        flower(d, x, y, PETALS[k], 27)
    poly(d, [(130, 250), (440, 230), (400, 370), (190, 370)], BLUE, detail=lambda dd: paint_soft(dd, 230, 290, 60, 30, rgb("8ab8f0"), 0.7))
    post(d, 200, 370, 460, 20)
    ell(d, 400, 410, 62, 62, WOOD_DK)
    ell(d, 400, 410, 34, 34, WOOD, w=8)
    ell(d, 400, 410, 10, 10, IRON, w=0)
    return img


def i_flower_arch():
    img, d = new()
    arc = [(110, 470), (110, 250)] + quad_curve((110, 250), (256, 20), (402, 250), 16) + [(402, 470)]
    poly(d, tube(arc, 30), rgb("e0c06a"))
    for k in range(9):
        x, y = arc[2 + k * 2]
        poly(d, leaf_shape((x, y), (x + (30 if k % 2 else -30), y - 30), 0, 12), GREEN, w=7)
    for k in range(7):
        x, y = arc[3 + k * 2]
        flower(d, x, y, PETALS[k % 6], 26)
    flower(d, 110, 360, PINK, 24)
    flower(d, 402, 330, YELLOW, 24)
    return img


# ------------------------------------------------------------------ дорожки
def i_plank_path():
    img, d = new()
    for k in range(4):
        y = 130 + k * 82
        dx = (k % 2) * 22 - 10
        poly(d, [(70 + dx, y), (430 + dx, y - 14), (444 + dx, y + 52), (84 + dx, y + 66)], WOOD if k % 2 else WOOD_LT,
             detail=grain(90 + dx, 420 + dx, (y + 16, y + 38)))
        for x in (104 + dx, 404 + dx):
            ell(d, x, y + 26, 7, 7, IRON, w=0)
    return img


def i_stone_path():
    img, d = new()
    for k, (x, y, r) in enumerate(((256, 270, 104), (400, 200, 62), (120, 190, 66), (150, 380, 70), (380, 370, 66), (270, 110, 46), (266, 430, 40))):
        poly(d, blob(x, y, r, 11 + k, 0.1, sy=0.62), rgb("b8b2a6") if k % 2 else rgb("9c978c"),
             detail=lambda dd, xx=x, yy=y, rr=r: paint_soft(dd, xx - rr * 0.25, yy - rr * 0.2, rr * 0.4, rr * 0.2, rgb("d8d2c6"), 0.7), puff=0.6)
    return img


# ------------------------------------------------------------------ заборчики
def i_picket_fence():
    img, d = new()
    for y in (230, 380):
        R(d, 40, y - 18, 472, y + 18, rgb("dcd6c6"), w=9)
    for k in range(5):
        x = 86 + k * 85
        poly(d, [(x - 32, 460), (x - 32, 150), (x, 96), (x + 32, 150), (x + 32, 460)], WHITE)
    return img


def i_bamboo_fence():
    img, d = new()
    bam = rgb("e0c06a")
    for y in (200, 380):
        poly(d, tube([(40, y), (472, y)], 24), rgb("c9a050"))
    for k in range(5):
        x = 86 + k * 85
        poly(d, tube([(x, 460), (x, 110 + (k % 2) * 30)], 34), bam, detail=lambda dd, xx=x: [dd.line([(xx - 18, y), (xx + 18, y)], fill=rgb("a88a3a"), width=5) for y in (170, 290, 420)])
        for y in (200, 380):
            R(d, x - 22, y - 12, x + 22, y + 12, rgb("6a4a30"), w=6)
    return img


def i_garden_gate():
    img, d = new()
    for x in (80, 432):
        post(d, x, 110, 470, 40)
        poly(d, [(x - 30, 116), (x + 30, 116), (x, 60)], WOOD_DK)
    for k in range(4):
        x = 150 + k * 62
        h = (150, 120, 120, 150)[k]
        poly(d, [(x - 24, 450), (x - 24, h + 30), (x, h), (x + 24, h + 30), (x + 24, 450)], WHITE)
    poly(d, tube([(126, 420), (360, 210)], 22), rgb("dcd6c6"), w=9)
    for y in (220, 400):
        R(d, 104, y - 14, 150, y + 14, IRON, w=6)
    ell(d, 352, 320, 16, 16, IRON, w=6)
    return img


# ------------------------------------------------------------------ вывески
def i_sign_camp():
    img, d = new()
    for x in (110, 402):
        post(d, x, 60, 470, 30)
    poly(d, tube([(70, 80), (442, 80)], 24), WOOD_DK)
    for x in (160, 352):
        d.line([(x, 90), (x, 160)], fill=rgb("a8844a"), width=9)

    def det(dd):
        dd.line(quad_curve((120, 270), (150, 220), (180, 262)) + quad_curve((180, 262), (210, 220), (240, 270)), fill=rgb("3a4a6a"), width=12)
        for y, x1 in ((220, 390), (262, 390), (304, 340)):
            dd.line([(270, y), (x1, y)], fill=rgb("4a2c14"), width=12)
    R(d, 76, 160, 436, 350, rgb("f2e2b8"), detail=det)
    return img


def i_sign_arrows():
    img, d = new()
    post(d, 256, 50, 470, 32)
    for k, (y, c, s) in enumerate(((110, RED, 1), (200, WHITE, -1), (290, BLUE, 1), (380, YELLOW, -1))):
        x0, x1 = (200, 400) if s > 0 else (312, 112)
        tipx = x1 + s * 60
        poly(d, [(x0, y - 34), (x1, y - 34), (tipx, y), (x1, y + 34), (x0, y + 34)], c)
    return img


# ------------------------------------------------------------------ прочее
def i_wash_stand():
    img, d = new()
    for x in (130, 382):
        post(d, x, 270, 470, 28)
    R(d, 110, 380, 402, 410, WOOD_DK, w=8)
    poly(d, [(70, 240), (442, 240), (456, 290), (56, 290)], WOOD)
    poly(d, ell_pts(210, 200, 120, 70, 0, 30, 0, math.pi), WHITE)
    ell(d, 210, 200, 120, 34, rgb("8fd0e8"), w=10, puff=0.3)
    poly(d, spline([(350, 240), (330, 170), (350, 120), (350, 80), (400, 80), (400, 120), (420, 170), (400, 240)], True, 6), WHITE)
    R(d, 30, 290, 84, 430, CREAM, w=9, detail=lambda dd: [dd.line([(30, y), (84, y)], fill=BLUE, width=8) for y in (380, 404)])
    return img


def i_bird_feeder():
    img, d = new()
    post(d, 256, 330, 480, 30)
    poly(d, [(110, 300), (402, 300), (420, 346), (92, 346)], WOOD)
    for x in (150, 362):
        post(d, x, 170, 304, 16, WOOD)
    poly(d, [(70, 190), (256, 50), (442, 190), (410, 214), (256, 100), (102, 214)], RED)
    body = spline([(210, 286), (196, 250), (220, 222), (262, 222), (290, 250), (280, 286)], True, 8)
    poly(d, body, YELLOW, w=9)
    ell(d, 286, 220, 28, 28, YELLOW, w=9)
    poly(d, [(310, 214), (340, 222), (310, 232)], rgb("f28a3a"), w=6)
    ell(d, 292, 214, 5, 5, rgb("1d1d1d"), w=0)
    for k in range(4):
        ell(d, 130 + k * 22, 292, 8, 8, rgb("ffc21a"), w=4)
    return img


def i_weather_vane():
    img, d = new()
    post(d, 256, 300, 480, 28)
    d.line([(256, 110), (256, 300)], fill=IRON, width=12)
    d.line([(150, 280), (362, 280)], fill=IRON, width=9)
    for x in (150, 362):
        ell(d, x, 280, 16, 16, rgb("d8a83a"), w=7)
    poly(d, tube([(90, 190), (380, 190)], 16), IRON)
    poly(d, [(380, 150), (460, 190), (380, 230)], IRON)
    poly(d, [(90, 150), (150, 190), (90, 230), (60, 190)], IRON)
    gull = spline([(180, 120), (220, 70), (256, 104), (292, 70), (332, 120), (292, 110), (256, 140), (220, 110)], True, 8)
    poly(d, gull, rgb("d8a83a"))
    return img


def i_log_stack():
    img, d = new()
    for x in (70, 442):
        post(d, x, 150, 470, 22)
    for row in range(3):
        n = 4 if row % 2 == 0 else 3
        for k in range(n):
            x = 124 + k * 88 + (44 if row % 2 else 0)
            y = 410 - row * 82
            ell(d, x, y, 44, 44, rgb("8a5a32"))
            ell(d, x, y, 30, 30, rgb("ecc98e"), w=0)
            d.ellipse((x - 14, y - 14, x + 14, y + 14), outline=rgb("c99a62"), width=4)
    poly(d, [(40, 170), (256, 80), (472, 170), (450, 200), (256, 124), (62, 200)], rgb("7a5a40"))
    return img


def i_wind_chime():
    img, d = new()
    post(d, 110, 50, 480, 28)
    poly(d, tube([(110, 90), (350, 70)], 18), WOOD_DK)
    d.line([(320, 80), (320, 150)], fill=rgb("a8844a"), width=7)
    ell(d, 320, 164, 96, 26, WOOD, puff=0.5)
    for k, (x, ln) in enumerate(((250, 150), (296, 210), (344, 170), (390, 230))):
        d.line([(x, 180), (x, 180 + ln - 80)], fill=rgb("a8844a"), width=6)
        if k % 2 == 0:
            poly(d, tube([(x, 180 + ln - 90), (x, 180 + ln)], 26), rgb("bfe6f5"), w=9, gloss=1.6)
        else:
            poly(d, [(x - 28, 180 + ln - 70), (x + 28, 180 + ln - 70), (x, 180 + ln)], rgb("f6c7c0"), w=9)
    return img


def i_gramophone():
    img, d = new()
    R(d, 110, 330, 400, 470, rgb("7a4a2a"), detail=lambda dd: dd.rectangle((160, 362, 350, 440), outline=rgb("5a3420"), width=8))
    poly(d, [(90, 290), (420, 290), (400, 336), (110, 336)], rgb("9a5a32"))
    ell(d, 230, 290, 110, 30, rgb("1d1d22"), w=9, puff=0.3)
    ell(d, 230, 290, 34, 10, RED, w=0)
    poly(d, tube(quad_curve((340, 290), (360, 200), (300, 190)), 22), rgb("d8a83a"), w=9)
    horn = spline([(300, 200), (150, 40), (250, 30), (400, 60), (440, 150)], True, 8)
    poly(d, horn, rgb("e8b84a"), detail=lambda dd: paint_soft(dd, 310, 100, 70, 40, rgb("a8742a"), 0.7), gloss=1.5)
    poly(d, tube([(400, 316), (460, 316), (460, 360)], 12), rgb("d8a83a"), w=7)
    return img


ICONS = {
    "cook_pot": i_cook_pot, "camp_table": i_camp_table, "camp_stool": i_camp_stool, "rocking_chair": i_rocking_chair,
    "camp_shelf": i_camp_shelf, "decor_chest": i_decor_chest, "rug_wool": i_rug_wool, "rug_straw": i_rug_straw,
    "garland_flags": i_garland_flags, "garland_lights": i_garland_lights, "lantern_post": i_lantern_post,
    "paper_lantern": i_paper_lantern, "stone_lantern": i_stone_lantern, "flower_tub": i_flower_tub, "flower_barrow": i_flower_barrow,
    "flower_arch": i_flower_arch, "plank_path": i_plank_path, "stone_path": i_stone_path, "picket_fence": i_picket_fence,
    "bamboo_fence": i_bamboo_fence, "garden_gate": i_garden_gate, "sign_camp": i_sign_camp, "sign_arrows": i_sign_arrows,
    "wash_stand": i_wash_stand, "bird_feeder": i_bird_feeder, "weather_vane": i_weather_vane, "log_stack": i_log_stack,
    "wind_chime": i_wind_chime, "gramophone": i_gramophone,
}
