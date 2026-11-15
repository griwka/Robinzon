"""Иконки кулинарии и уюта («вечная игра» после финала): блюда из котелка и украшения лагеря.
Тот же стиль, что в gen_icons.py: деталь — poly(...) с объёмом, тёплая обводка, крупный предмет.
Проверка: python tools/gen_icons.py veg_stew lemonade — пересобрать только эти."""
import math

from gen_icons import (blob, ell, ell_pts, ink_line, leaf_shape, line, new, paint_soft, poly, quad_curve, rgb, spline, tube)

BOWL = rgb("8a5a32")
CLAY = rgb("c8683e")
PLATE = rgb("f6efe0")
PLATE_IN = rgb("e6dcc6")
CRUST = rgb("e0a85a")
CRUST_DK = rgb("b87a3a")
WHITE = rgb("ffffff")
GLASS = rgb("d8eef4")


# ------------------------------------------------------------------ помощники
def _steam(d, xs=(200, 256, 312), y=180):
    for x in xs:
        line(d, quad_curve((x, y), (x - 25, y - 50), (x + 6, y - 100)), rgb("ffffff", 200), 12)


def _bowl(d, soup, bowl=BOWL, cy=270, detail=None):
    """Миска с супом: вид чуть сверху. detail(dd) — узор на поверхности супа."""
    poly(d, ell_pts(256, cy, 208, 185, 0, 48, 0.0, math.pi), bowl)
    ell(d, 256, cy, 208, 72, soup, detail=detail, puff=0.4)


def _bits(d, items, rx=26, ry=15):
    for x, y, c in items:
        ell(d, x, y, rx, ry, rgb(c), w=6)


def _plate(d, cy=330, rx=215, ry=95):
    ell(d, 256, cy, rx, ry, PLATE, puff=0.5)
    ell(d, 256, cy - 4, rx - 42, ry - 26, PLATE_IN, w=0)


def _pie(d, top, cy=300, detail=None):
    """Круглый пирог: румяный бортик и верх своего цвета."""
    ell(d, 256, cy + 36, 205, 90, CRUST_DK, puff=0.5)
    ell(d, 256, cy - 10, 205, 88, CRUST, puff=0.6)
    ell(d, 256, cy - 14, 165, 64, top, w=8, detail=detail, puff=0.5)


def _glass(d, drink, x0=160, x1=352, top=150, bottom=440, fill_top=200, detail=None):
    """Стакан: стекло и напиток внутри."""
    k = 26
    poly(d, [(x0, top), (x1, top), (x1 - k, bottom), (x0 + k, bottom)], GLASS, gloss=1.4)
    t = (fill_top - top) / (bottom - top)
    poly(d, [(x0 + k * t + 12, fill_top), (x1 - k * t - 12, fill_top), (x1 - k - 10, bottom - 12), (x0 + k + 10, bottom - 12)], drink, w=0)
    if detail:
        detail(d)
    ell(d, (x0 + x1) / 2, top, (x1 - x0) / 2, 22, rgb("eef8fb"), w=8)
    ell(d, (x0 + x1) / 2, fill_top, (x1 - x0) / 2 - k * t - 12, 14, drink, w=0)
    line(d, [(x0 + 34, top + 50), (x0 + 48, bottom - 60)], rgb("ffffff", 170), 12)


def _slice(d, cx, cy, r, rind, flesh, ang=0.0):
    """Кружок-долька (лимон, томат)."""
    ell(d, cx, cy, r, r * 0.8, rind, ang=ang, w=8)
    ell(d, cx, cy, r * 0.74, r * 0.58, flesh, ang=ang, w=0)
    for k in range(6):
        a = ang + k * math.pi / 3
        d.line([(cx, cy), (cx + math.cos(a) * r * 0.7, cy + math.sin(a) * r * 0.55)], fill=rind, width=4)


def _omelette(d, extra):
    _plate(d)
    pts = spline([(110, 320), (150, 250), (250, 215), (360, 235), (410, 300), (350, 360), (220, 375), (140, 360)], True, 10)
    poly(d, pts, rgb("ffd24a"), detail=lambda dd: (paint_soft(dd, 230, 270, 90, 40, rgb("fff0a0"), 0.7),
                                                   paint_soft(dd, 340, 330, 60, 30, rgb("e8a030"), 0.5)))
    line(d, quad_curve((150, 330), (260, 290), (400, 300)), rgb("e0a030"), 8)
    extra(d)


# ------------------------------------------------------------------ блюда
def i_kitchen_flop():
    img, d = new()
    def det(dd):
        paint_soft(dd, 200, 262, 60, 22, rgb("7a6a4a"), 0.8)
        paint_soft(dd, 320, 282, 50, 18, rgb("b8a880"), 0.7)
    _bowl(d, rgb("9a8a6a"), detail=det)
    for x, y, r in ((210, 262, 22), (300, 280, 16), (260, 250, 12)):
        ell(d, x, y, r, r * 0.7, rgb("b8a888"), w=6)
    line(d, quad_curve((230, 190), (200, 150), (240, 110)), rgb("8a9a5a", 220), 12)
    line(d, quad_curve((300, 180), (330, 140), (290, 96)), rgb("8a9a5a", 220), 12)
    return img


def i_veg_stew():
    img, d = new()
    _bowl(d, rgb("d9713a"), detail=lambda dd: paint_soft(dd, 256, 262, 150, 40, rgb("e88a4a"), 0.7))
    _bits(d, ((180, 262, "f58a1f"), (250, 248, "e8443a"), (318, 268, "d8b070"), (222, 292, "d8b070"), (296, 300, "f58a1f"), (350, 250, "4f9a4a")))
    _steam(d)
    return img


def i_corn_chowder():
    img, d = new()
    _bowl(d, rgb("f6dc6a"), detail=lambda dd: paint_soft(dd, 256, 262, 150, 40, rgb("fff0a8"), 0.7))
    for k in range(9):
        a = k * 2.4
        ell(d, 256 + math.cos(a) * (60 + 9 * k), 268 + math.sin(a) * (18 + 3 * k), 15, 12, rgb("ffc21a"), w=5)
    poly(d, leaf_shape((240, 250), (300, 232), -6, 12), rgb("4fa64a"), w=6)
    _steam(d)
    return img


def i_cabbage_soup():
    img, d = new()
    _bowl(d, rgb("c8d06a"), detail=lambda dd: paint_soft(dd, 256, 262, 150, 40, rgb("dce08a"), 0.7))
    for x, y, c in ((180, 258, "8fc85a"), (300, 246, "a6dc6a"), (240, 296, "8fc85a")):
        poly(d, blob(x, y, 32, x, 0.2, sy=0.55), rgb(c), w=6)
    _bits(d, ((340, 276, "f58a1f"), (206, 284, "f58a1f")), 20, 13)
    ell(d, 262, 262, 38, 22, WHITE, w=6)
    _steam(d)
    return img


def i_tomato_omelette():
    img, d = new()
    def extra(dd):
        _slice(dd, 190, 290, 44, rgb("d83a2a"), rgb("ff7a5a"))
        _slice(dd, 300, 320, 44, rgb("d83a2a"), rgb("ff7a5a"), 0.4)
        poly(dd, leaf_shape((330, 250), (390, 232), -6, 12), rgb("4fa64a"), w=6)
    _omelette(d, extra)
    return img


def i_banana_pancakes():
    img, d = new()
    _plate(d, 380, 210, 80)
    for k in range(4):
        y = 360 - k * 46
        poly(d, ell_pts(256, y, 160, 56, 0, 40), rgb("e8b060"), detail=lambda dd, yy=y: paint_soft(dd, 256, yy - 6, 120, 30, rgb("c8843a"), 0.6))
    for x, y in ((210, 205), (270, 195), (310, 222)):
        ell(d, x, y, 32, 22, rgb("fff0a8"), w=7)
        ell(d, x, y, 10, 7, rgb("e8c860"), w=0)
    poly(d, spline([(150, 250), (190, 300), (180, 350), (160, 300)], True, 8), rgb("d98a2a"), w=7)
    return img


def i_mango_dessert():
    img, d = new()
    poly(d, [(190, 380), (322, 380), (350, 450), (162, 450)], GLASS, gloss=1.3)
    poly(d, ell_pts(256, 250, 170, 150, 0, 40, 0.0, math.pi), GLASS, gloss=1.4)
    poly(d, ell_pts(256, 256, 150, 126, 0, 40, 0.0, math.pi), rgb("ffb040"), w=0)
    ell(d, 256, 250, 170, 50, rgb("fff0d8"), puff=0.6)
    for x, y in ((210, 236), (290, 244), (250, 268)):
        poly(d, [(x - 24, y - 16), (x + 22, y - 20), (x + 26, y + 14), (x - 20, y + 18)], rgb("ff9f2e"), w=7)
    poly(d, leaf_shape((300, 220), (360, 180), -8, 16), rgb("4fa64a"), w=7)
    return img


def i_coconut_fish():
    img, d = new()
    poly(d, ell_pts(256, 270, 215, 190, 0, 48, 0.0, math.pi), rgb("7b5230"),
         detail=lambda dd: [ink_line(dd, [(120 + k * 50, 300), (140 + k * 46, 430)], rgb("5a3a20"), 6) for k in range(6)])
    ell(d, 256, 270, 215, 76, rgb("fbf6e8"), puff=0.4)
    ell(d, 256, 276, 180, 56, rgb("f2ead0"), w=0)
    fish = spline([(150, 270), (200, 236), (290, 236), (340, 262), (390, 236), (384, 300), (340, 280), (290, 304), (200, 304)], True, 8)
    poly(d, fish, rgb("d8a868"), w=8, detail=lambda dd: paint_soft(dd, 250, 256, 80, 16, rgb("f0d0a0"), 0.7))
    _slice(d, 330, 312, 34, rgb("e8d83a"), rgb("fff8a0"), 0.3)
    poly(d, leaf_shape((180, 300), (240, 318), 6, 10), rgb("4fa64a"), w=6)
    return img


def i_fish_pie():
    img, d = new()
    def det(dd):
        for k in range(5):
            ink_line(dd, [(130 + k * 62, 230), (150 + k * 62, 350)], CRUST_DK, 9)
    _pie(d, rgb("eab868"), detail=det)
    tail = spline([(256, 250), (236, 190), (190, 140), (256, 160), (322, 140), (276, 190)], True, 8)
    poly(d, tail, rgb("7fa8c8"), w=9)
    return img


def i_fish_veg():
    img, d = new()
    _plate(d)
    fish = spline([(120, 300), (180, 250), (300, 245), (360, 286), (420, 246), (414, 340), (360, 306), (300, 345), (180, 345)], True, 8)
    poly(d, fish, rgb("c8a070"), detail=lambda dd: (paint_soft(dd, 250, 276, 100, 22, rgb("ecd0a0"), 0.7),
                                                    [ink_line(dd, [(210 + k * 40, 262), (200 + k * 40, 330)], rgb("8a5a32"), 6) for k in range(3)]))
    ell(d, 165, 290, 8, 8, rgb("3a2a1a"), w=0)
    poly(d, tube([(150, 370), (250, 392)], (30, 14)), rgb("f58a1f"), w=7)
    _slice(d, 330, 372, 38, rgb("d83a2a"), rgb("ff7a5a"))
    return img


def i_stuffed_pepper():
    img, d = new()
    _plate(d, 380, 215, 80)
    for cx, s in ((170, 0), (330, 1)):
        body = spline([(cx - 80, 250), (cx - 60, 190), (cx, 176), (cx + 62, 190), (cx + 80, 250), (cx + 60, 360), (cx, 392), (cx - 60, 360)], True, 8)
        poly(d, body, rgb("e63a2c"), detail=lambda dd, c=cx: paint_soft(dd, c - 30, 250, 22, 60, rgb("ff7a62"), 0.8), gloss=1.2)
        ell(d, cx, 204, 62, 28, rgb("ffe9a6"), w=8, detail=lambda dd, c=cx: paint_soft(dd, c + 10, 200, 30, 12, rgb("f2b84a"), 0.7))
        ell(d, cx - 18, 200, 12, 8, rgb("e8443a"), w=0)
        ell(d, cx + 22, 208, 10, 7, rgb("4fa64a"), w=0)
    return img


def i_pumpkin_soup():
    img, d = new()
    _bowl(d, rgb("f29a30"), bowl=rgb("e07a24"), detail=lambda dd: paint_soft(dd, 256, 262, 150, 40, rgb("ffb850"), 0.7))
    line(d, spline([(190, 270), (230, 248), (280, 262), (300, 286), (262, 296), (236, 280)], False, 10), rgb("fff6e0"), 12)
    for x, y in ((330, 256), (350, 282), (170, 290)):
        poly(d, leaf_shape((x - 14, y), (x + 14, y), 0, 7), rgb("d8e0a0"), w=4)
    _steam(d)
    return img


def i_pumpkin_pie():
    img, d = new()
    _plate(d, 390, 215, 76)
    poly(d, [(100, 330), (400, 250), (420, 340), (120, 420)], CRUST_DK)
    poly(d, [(100, 330), (400, 250), (410, 200), (360, 170), (96, 280)], rgb("e88a3a"),
         detail=lambda dd: paint_soft(dd, 240, 250, 120, 40, rgb("f8a850"), 0.7))
    poly(d, tube([(364, 168), (420, 196), (424, 340)], 30), CRUST, w=10)
    poly(d, blob(230, 236, 46, 5, 0.18, sy=0.7), WHITE, w=8)
    return img


def i_truffle_potato():
    img, d = new()
    _plate(d)
    for x, y, r, s in ((180, 300, 62, 3), (290, 280, 70, 8), (350, 330, 56, 12), (240, 345, 58, 20)):
        poly(d, blob(x, y, r, s, 0.1, sy=0.78), rgb("d8b070"), detail=lambda dd, xx=x, yy=y: paint_soft(dd, xx - 14, yy - 12, 28, 16, rgb("f0d8a0"), 0.8))
    for x, y, a in ((200, 262, 0.2), (300, 250, -0.3), (270, 310, 0.5), (350, 296, 0.1)):
        ell(d, x, y, 26, 13, rgb("4a3a2a"), ang=a, w=6)
        ell(d, x, y, 14, 6, rgb("8a7458"), ang=a, w=0)
    poly(d, leaf_shape((150, 250), (200, 220), -6, 11), rgb("4fa64a"), w=6)
    return img


def i_truffle_omelette():
    img, d = new()
    def extra(dd):
        for x, y, a in ((200, 280, 0.2), (270, 262, -0.3), (330, 300, 0.5), (250, 326, 0.0)):
            ell(dd, x, y, 30, 16, rgb("4a3a2a"), ang=a, w=6)
            ell(dd, x, y, 16, 7, rgb("8a7458"), ang=a, w=0)
        poly(dd, leaf_shape((330, 246), (392, 226), -6, 12), rgb("4fa64a"), w=6)
    _omelette(d, extra)
    return img


def i_berry_compote():
    img, d = new()
    def det(dd):
        for x, y, c in ((220, 330, "4a5ab8"), (290, 370, "d8343a"), (250, 400, "4a5ab8"), (300, 300, "d8343a"), (210, 392, "d8343a")):
            ell(dd, x, y, 20, 20, rgb(c), w=6)
    _glass(d, rgb("b0406a"), detail=det)
    return img


def i_lemonade():
    img, d = new()
    def det(dd):
        for x, y in ((220, 250), (286, 300), (236, 350)):
            poly(dd, [(x - 26, y - 22), (x + 22, y - 28), (x + 28, y + 20), (x - 20, y + 26)], rgb("eefaff", 230), w=5)
    _glass(d, rgb("f6ec7a"), detail=det)
    poly(d, tube([(300, 420), (330, 150), (380, 96)], 16), rgb("e8443a"), w=7)
    _slice(d, 170, 160, 52, rgb("e8d83a"), rgb("fff8a0"), 0.3)
    return img


def i_watermelon_ice():
    img, d = new()
    poly(d, tube([(256, 380), (256, 478)], 30), rgb("e0c08a"), w=10)
    body = spline([(150, 400), (150, 180), (190, 96), (256, 70), (322, 96), (362, 180), (362, 400)], True, 8)
    def det(dd):
        dd.rectangle((100, 348, 420, 420), fill=rgb("3aa64a"))
        dd.rectangle((100, 330, 420, 350), fill=rgb("f2f6d8"))
        for x, y in ((210, 170), (290, 200), (230, 262), (300, 290), (256, 130)):
            dd.ellipse((x - 9, y - 14, x + 9, y + 14), fill=rgb("3a2a1a"))
    poly(d, body, rgb("f2586a"), detail=det, gloss=1.3)
    return img


def i_aloe_drink():
    img, d = new()
    def det(dd):
        for x, y in ((220, 300), (290, 350), (240, 400)):
            poly(dd, [(x - 20, y - 16), (x + 18, y - 20), (x + 22, y + 14), (x - 16, y + 18)], rgb("d8f5c8", 230), w=5)
    _glass(d, rgb("9ad88a"), detail=det)
    poly(d, tube([(300, 240), (350, 150), (410, 76)], (46, 8)), rgb("5fb86a"), w=9,
         detail=lambda dd: ink_line(dd, [(310, 230), (400, 90)], rgb("3a8a4a"), 6))
    return img


def i_cabbage_pie():
    img, d = new()
    _pie(d, rgb("eab868"), detail=lambda dd: paint_soft(dd, 256, 280, 110, 40, rgb("f6d898"), 0.6))
    for a0, c in ((0.0, "8fc85a"), (2.1, "a6dc6a"), (4.2, "8fc85a")):
        x, y = 256 + math.cos(a0) * 16, 284 + math.sin(a0) * 8
        x2, y2 = 256 + math.cos(a0) * 110, 284 + math.sin(a0) * 44
        poly(d, leaf_shape((x, y), (x2, y2), 0, 26), rgb(c), w=7)
    ell(d, 256, 284, 16, 10, CRUST_DK, w=0)
    return img


def i_corn_cakes():
    img, d = new()
    _plate(d, 390, 215, 76)
    for k in range(3):
        y = 370 - k * 44
        poly(d, blob(256 + (k - 1) * 14, y, 150, 30 + k, 0.05, sy=0.4), rgb("f0c850"),
             detail=lambda dd, yy=y, kk=k: [paint_soft(dd, 190 + j * 60 + kk * 12, yy - 6 + (j % 2) * 14, 18, 9, rgb("c8922a"), 0.8) for j in range(3)])
    ell(d, 300, 256, 12, 9, rgb("ffc21a"), w=5)
    ell(d, 326, 268, 12, 9, rgb("ffc21a"), w=5)
    return img


def i_spicy_corn():
    img, d = new()
    poly(d, tube([(96, 430), (190, 336)], 22), rgb("c08a50"), w=10)
    cob = tube([(170, 356), (400, 126)], (104, 78))
    def det(dd):
        for i in range(9):
            for j in range(-2, 3):
                u = 20 + i * 34
                x = 170 + u * 0.707 + j * 22 * 0.707
                y = 356 - u * 0.707 + j * 22 * 0.707
                dd.ellipse((x - 13, y - 13, x + 13, y + 13), fill=rgb("ffe26a") if (i + j) % 3 else rgb("f2b02a"), outline=rgb("c8922a"), width=3)
        for x, y in ((230, 300), (300, 230), (340, 200), (270, 250), (370, 160)):
            dd.ellipse((x - 8, y - 6, x + 8, y + 6), fill=rgb("d8281c"))
    poly(d, cob, rgb("f6c83a"), detail=det)
    pep = tube(quad_curve((330, 380), (420, 380), (450, 300)), (40, 8))
    poly(d, pep, rgb("e63a2c"), w=8)
    poly(d, tube([(330, 380), (306, 372)], 14), rgb("4fa044"), w=6)
    return img


def i_honey_carrot():
    img, d = new()
    _plate(d, 380, 215, 82)
    for k, (y, dx) in enumerate(((300, 0), (350, 30), (400, -10))):
        c = tube([(120 + dx, y), (400 + dx, y - 40)], (64, 22))
        poly(d, c, rgb("f58a1f"), detail=lambda dd, yy=y, xx=dx: (paint_soft(dd, 200 + xx, yy - 26, 60, 10, rgb("ffd27a"), 0.9),
                                                             [ink_line(dd, [(170 + xx + j * 60, yy - 30 - j * 8), (176 + xx + j * 60, yy - 8 - j * 8)], rgb("c86a14"), 5) for j in range(3)]), gloss=1.5)
    poly(d, spline([(250, 150), (286, 210), (280, 250), (250, 264), (222, 250), (216, 210)], True, 8), rgb("f2a93a"), w=8, gloss=1.6)
    return img


def i_milk_coffee():
    img, d = new()
    ell(d, 256, 420, 205, 56, PLATE, puff=0.5)
    poly(d, tube(quad_curve((380, 250), (480, 280), (372, 372)), 26), rgb("f6efe0"), w=12)
    poly(d, [(110, 210), (402, 210), (372, 410), (140, 410)], rgb("f6efe0"), gloss=1.2)
    ell(d, 256, 210, 146, 46, rgb("b88860"), detail=lambda dd: (paint_soft(dd, 256, 210, 70, 20, rgb("f6e8d0"), 0.95),
                                                             ink_line(dd, [(210, 214), (256, 196), (302, 214)], rgb("b88860"), 7)), puff=0.3)
    _steam(d, (210, 256, 302), 150)
    return img


def i_cloudberry_pie():
    img, d = new()
    _pie(d, rgb("f6c868"), detail=lambda dd: paint_soft(dd, 256, 280, 110, 40, rgb("ffe098"), 0.6))
    for k in range(7):
        a = k * 2 * math.pi / 7
        x, y = 256 + math.cos(a) * 96, 286 + math.sin(a) * 36
        poly(d, [ell_pts(x - 9, y, 12, 11, n=12), ell_pts(x + 9, y, 12, 11, n=12), ell_pts(x, y - 10, 12, 11, n=12)], rgb("f5a030"), w=10)
    poly(d, [ell_pts(247, 286, 13, 12, n=12), ell_pts(267, 286, 13, 12, n=12), ell_pts(257, 274, 13, 12, n=12)], rgb("f58a1f"), w=10)
    return img


def i_cheese_salad():
    img, d = new()
    poly(d, ell_pts(256, 290, 208, 170, 0, 48, 0.0, math.pi), CLAY)
    ell(d, 256, 290, 208, 66, rgb("7abf4a"), puff=0.4)
    for x, y, s, c in ((170, 262, 4, "8fd45a"), (256, 240, 9, "a6dc6a"), (340, 262, 14, "8fd45a"), (210, 296, 21, "a6dc6a"), (310, 300, 25, "6fbf4a")):
        poly(d, blob(x, y, 50, s, 0.22, sy=0.62), rgb(c), w=7)
    for x, y in ((200, 250), (300, 262), (250, 290)):
        poly(d, [(x - 22, y - 18), (x + 18, y - 22), (x + 24, y + 12), (x - 16, y + 18)], rgb("ffe9a6"), w=7)
    _slice(d, 340, 232, 36, rgb("d83a2a"), rgb("ff7a5a"))
    _slice(d, 160, 300, 30, rgb("d83a2a"), rgb("ff7a5a"), 0.5)
    return img


def i_tropical_shake():
    img, d = new()
    def det(dd):
        dd.polygon([(180, 300), (336, 300), (322, 430), (196, 430)], fill=rgb("ff8a5a"))
        dd.polygon([(184, 360), (330, 360), (322, 430), (196, 430)], fill=rgb("f2586a"))
    _glass(d, rgb("ffc078"), detail=det)
    poly(d, tube([(290, 420), (316, 150), (360, 90)], 16), rgb("4f8fd8"), w=7)
    wedge = ell_pts(180, 160, 70, 70, 0, 24, math.pi * 0.9, math.pi * 1.9)
    poly(d, wedge, rgb("7b5230"), w=9)
    poly(d, ell_pts(182, 158, 52, 52, 0, 24, math.pi * 0.9, math.pi * 1.9), rgb("fbf6e8"), w=0)
    return img


DISHES = {
    "kitchen_flop": i_kitchen_flop, "veg_stew": i_veg_stew, "corn_chowder": i_corn_chowder, "cabbage_soup": i_cabbage_soup,
    "tomato_omelette": i_tomato_omelette, "banana_pancakes": i_banana_pancakes, "mango_dessert": i_mango_dessert,
    "coconut_fish": i_coconut_fish, "fish_pie": i_fish_pie, "fish_veg": i_fish_veg, "stuffed_pepper": i_stuffed_pepper,
    "pumpkin_soup": i_pumpkin_soup, "pumpkin_pie": i_pumpkin_pie, "truffle_potato": i_truffle_potato,
    "truffle_omelette": i_truffle_omelette, "berry_compote": i_berry_compote, "lemonade": i_lemonade,
    "watermelon_ice": i_watermelon_ice, "aloe_drink": i_aloe_drink, "cabbage_pie": i_cabbage_pie, "corn_cakes": i_corn_cakes,
    "spicy_corn": i_spicy_corn, "honey_carrot": i_honey_carrot, "milk_coffee": i_milk_coffee, "cloudberry_pie": i_cloudberry_pie,
    "cheese_salad": i_cheese_salad, "tropical_shake": i_tropical_shake,
}

ICONS = dict(DISHES)

import icons_decor_camp as _camp   # noqa: E402 — украшения лагеря и котелок

ICONS.update(_camp.ICONS)
