"""Иконки «живого мира»: записки из бутылок, морское стекло, знаки строителей, редкие существа, камень со знаками.
Стиль — как в gen_icons.py. Проверка: python tools/gen_icons.py bottle_1 sign_home sea_turtle"""
import math

from gen_icons import (blob, butterfly, ell, ell_pts, fish_icon, ink_line, leaf_shape, line, new, paint_soft, poly, quad_curve, rgb, spline,
                       tube)

STONE = rgb("a8a49c")
CARVE = rgb("3a3832")
MOSS = rgb("6d9a40")


# ------------------------------------------------------------------ записки из бутылок
def bottle(seal):
    def f():
        img, d = new()
        body = spline([(120, 300), (150, 230), (300, 150), (360, 190), (420, 150), (444, 176), (392, 232), (410, 290), (270, 400), (170, 400)], True, 8)
        poly(d, body, rgb("8fd0b8"), detail=lambda dd: (paint_soft(dd, 230, 250, 70, 30, rgb("d8f4e8"), 0.8, -0.5),
                                                        paint_soft(dd, 300, 340, 60, 30, rgb("5fa890"), 0.6, -0.5)), gloss=1.6)
        note = spline([(170, 330), (190, 270), (290, 220), (330, 260), (250, 340), (200, 370)], True, 8)
        poly(d, note, rgb("f6ecd0"), w=8, detail=lambda dd: [ink_line(dd, [(210 + k * 12, 320 - k * 16), (270 + k * 12, 280 - k * 16)], rgb("8a7458"), 5) for k in range(3)])
        poly(d, [(410, 128), (450, 108), (476, 150), (440, 176)], rgb("b88a50"))
        poly(d, tube([(250, 236), (300, 300)], 16), seal, w=7)
        return img
    return f


BOTTLE_SEALS = ["d9483a", "4f8fd8", "f2c23a", "4fa64a", "a884e8", "f28a3a"]


# ------------------------------------------------------------------ морское стекло
def sea_glass(col, seed):
    def f():
        img, d = new()
        poly(d, blob(256, 280, 175, seed, 0.14, sx=1.0, sy=0.78), col,
             detail=lambda dd: (paint_soft(dd, 200, 230, 70, 40, rgb("ffffff"), 0.55, -0.4), paint_soft(dd, 320, 340, 80, 40, rgb("000000"), 0.12)), gloss=1.7)
        ell(d, 196, 226, 30, 14, rgb("ffffff", 190), ang=-0.5, w=0)
        return img
    return f


# ------------------------------------------------------------------ знаки строителей
def _g_sail(dd):
    dd.line([(196, 330), (196, 170), (330, 330), (196, 330)], fill=CARVE, width=18, joint="curve")
    dd.line([(170, 366), (350, 366)], fill=CARVE, width=18)


def _g_root(dd):
    dd.line([(256, 190), (256, 290)], fill=CARVE, width=18)
    for sx in (-1, 1):
        dd.line([(256, 290), (256 + sx * 80, 370)], fill=CARVE, width=18)
        dd.line([(256, 250), (256 + sx * 52, 320)], fill=CARVE, width=14)
    dd.ellipse((226, 136, 286, 196), outline=CARVE, width=16)


def _g_key(dd):
    dd.ellipse((214, 150, 298, 234), outline=CARVE, width=18)
    dd.line([(256, 234), (256, 372)], fill=CARVE, width=18)
    dd.line([(256, 372), (310, 372)], fill=CARVE, width=18)
    dd.line([(256, 322), (300, 322)], fill=CARVE, width=18)


def _g_bolt(dd):
    dd.line([(290, 150), (206, 262), (270, 262), (226, 380)], fill=CARVE, width=20, joint="curve")
    dd.line([(226, 380), (316, 240), (256, 240)], fill=CARVE, width=20, joint="curve")


def _g_star(dd):
    pts = []
    for k in range(11):
        a = -math.pi / 2 + k * math.pi / 5
        r = 112 if k % 2 == 0 else 48
        pts.append((256 + math.cos(a) * r, 268 + math.sin(a) * r))
    dd.line(pts, fill=CARVE, width=16, joint="curve")


def _g_flame(dd):
    dd.line([(256, 150), (318, 262), (306, 340), (256, 376), (206, 340), (194, 262), (256, 150)], fill=CARVE, width=18, joint="curve")
    dd.line([(256, 250), (280, 320), (256, 344), (232, 320), (256, 250)], fill=CARVE, width=12, joint="curve")


def _g_eye(dd):
    dd.arc((146, 180, 366, 400), 215, 325, fill=CARVE, width=18)
    dd.arc((146, 136, 366, 356), 35, 145, fill=CARVE, width=18)
    dd.ellipse((224, 236, 288, 300), outline=CARVE, width=18)
    dd.ellipse((246, 258, 266, 278), fill=CARVE)


def sign(glyph, tint):
    def f():
        img, d = new()
        slab = spline([(110, 450), (104, 150), (150, 80), (256, 60), (362, 80), (408, 150), (402, 450)], True, 8)

        def det(dd):
            paint_soft(dd, 200, 110, 90, 40, MOSS, 0.75)
            paint_soft(dd, 360, 420, 60, 30, MOSS, 0.6)
            paint_soft(dd, 256, 268, 120, 130, tint, 0.3)
            glyph(dd)
        poly(d, slab, STONE, detail=det, puff=0.7, gloss=0.5)
        return img
    return f


SIGNS = {"sign_home": (_g_sail, "d8c8a0"), "sign_banyan": (_g_root, "9ab86a"), "sign_fort": (_g_key, "b8a888"),
         "sign_storm": (_g_bolt, "e8d85a"), "sign_ice": (_g_star, "bfe6f5"), "sign_volcano": (_g_flame, "f28a3a"),
         "sign_fog": (_g_eye, "a8b8c8")}


def i_sign_stone():
    img, d = new()
    poly(d, ell_pts(256, 440, 200, 44, n=30), rgb("7a766e"))
    slab = spline([(120, 440), (114, 130), (160, 66), (256, 50), (352, 66), (398, 130), (392, 440)], True, 8)

    def det(dd):
        paint_soft(dd, 190, 90, 80, 34, MOSS, 0.7)
        for k in range(6):
            x, y = 180 + (k % 3) * 76, 150 + (k // 3) * 86
            dd.ellipse((x - 24, y - 24, x + 24, y + 24), outline=CARVE, width=9)
            dd.line([(x - 12, y + 10), (x, y - 14), (x + 12, y + 10)], fill=CARVE, width=8)
        dd.arc((176, 300, 336, 440), 215, 325, fill=CARVE, width=14)
        dd.arc((176, 260, 336, 400), 35, 145, fill=CARVE, width=14)
        dd.ellipse((236, 330, 276, 370), fill=rgb("ffd86a"), outline=CARVE, width=10)
    poly(d, slab, STONE, detail=det, puff=0.7, gloss=0.5)
    return img


# ------------------------------------------------------------------ редкие существа
def i_snow_moth():
    return butterfly(rgb("fbfbf4"), rgb("cfd6e8"), "snow_moth")


def i_gold_beetle():
    img, d = new()
    for sx in (-1, 1):
        for k, (y0, y1) in enumerate(((230, 180), (290, 300), (350, 410))):
            line(d, [(256 + sx * 90, y0), (256 + sx * 170, y1), (256 + sx * 196, y1 + 34)], rgb("3a2a1a"), 16)
        line(d, quad_curve((256 + sx * 24, 128), (256 + sx * 60, 60), (256 + sx * 110, 76)), rgb("3a2a1a"), 12)
    ell(d, 256, 150, 70, 56, rgb("3a2a1a"))
    body = spline([(256, 180), (360, 230), (380, 330), (330, 430), (256, 460), (182, 430), (132, 330), (152, 230)], True, 8)
    poly(d, body, rgb("f2c23a"), detail=lambda dd: (paint_soft(dd, 200, 270, 40, 80, rgb("fff0a8"), 0.9), paint_soft(dd, 320, 380, 50, 60, rgb("b8822a"), 0.6),
                                                    dd.line([(256, 184), (256, 456)], fill=rgb("a8742a"), width=10)), gloss=1.8)
    return img


def i_sea_turtle():
    img, d = new()
    skin = rgb("8fb88a")
    for sx in (-1, 1):
        poly(d, spline([(256 + sx * 110, 200), (256 + sx * 230, 130), (256 + sx * 244, 190), (256 + sx * 150, 280)], True, 8), skin)
        poly(d, spline([(256 + sx * 110, 370), (256 + sx * 190, 420), (256 + sx * 170, 460), (256 + sx * 96, 420)], True, 8), skin)
    poly(d, spline([(216, 130), (226, 70), (256, 50), (286, 70), (296, 130), (256, 160)], True, 8), skin)
    for sx in (-1, 1):
        ell(d, 256 + sx * 22, 88, 8, 8, rgb("1d1d1d"), w=0)
    shell = spline([(256, 130), (370, 190), (396, 300), (340, 410), (256, 440), (172, 410), (116, 300), (142, 190)], True, 8)

    def det(dd):
        for (x, y) in ((256, 210), (200, 290), (312, 290), (256, 370)):
            dd.regular_polygon((x, y, 52), 6, rotation=30, outline=rgb("3a5a3a"), fill=rgb("6f9e6a"), width=8)
        paint_soft(dd, 210, 220, 60, 40, rgb("9ac890"), 0.6)
    poly(d, shell, rgb("5a8a5a"), detail=det, gloss=1.2)
    return img


def i_glow_crab():
    img, d = new()
    col = rgb("6fd8b8")
    for sx in (-1, 1):
        for k in range(3):
            y = 300 + k * 44
            line(d, [(256 + sx * 110, y), (256 + sx * 200, y - 10), (256 + sx * 232, y + 50)], rgb("4aa890"), 18)
        poly(d, tube([(256 + sx * 100, 250), (256 + sx * 180, 190)], 30), col)
        poly(d, blob(256 + sx * 196, 160, 52, 5 + sx, 0.1), rgb("8ae8c8"))
        line(d, [(256 + sx * 34, 220), (256 + sx * 40, 150)], col, 14)
        ell(d, 256 + sx * 40, 140, 16, 16, rgb("1d1d1d"), w=6)
    body = ell_pts(256, 310, 150, 100, n=40)
    poly(d, body, col, detail=lambda dd: [paint_soft(dd, x, y, 26, 18, rgb("f0fff6"), 0.95) for x, y in ((200, 280), (270, 260), (320, 310), (236, 340))], gloss=1.5)
    return img


i_moon_fish = fish_icon(rgb("bfd8ff"), rgb("ffffff"), rgb("8aa8e8"), spots=rgb("fff6c0"))

ICONS = {"sign_stone": i_sign_stone, "snow_moth": i_snow_moth, "gold_beetle": i_gold_beetle, "sea_turtle": i_sea_turtle,
         "glow_crab": i_glow_crab, "moon_fish": i_moon_fish}
for _k, _c in enumerate(BOTTLE_SEALS):
    ICONS["bottle_%d" % (_k + 1)] = bottle(rgb(_c))
for _k, (_id, _c) in enumerate((("glass_green", "6fbf8a"), ("glass_white", "e8f0ec"), ("glass_amber", "d89a3a"), ("glass_blue", "4a7ad8"),
                                ("glass_red", "d8344a"))):
    ICONS[_id] = sea_glass(rgb(_c), 20 + _k * 7)
for _id, (_g, _c) in SIGNS.items():
    ICONS[_id] = sign(_g, rgb(_c))
