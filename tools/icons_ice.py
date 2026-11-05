"""Иконки главы 5 (Ледяной остров). Тот же стиль, что в gen_icons.py: толстая тёплая обводка,
плоская заливка с мягким объёмом, крупный предмет на светлой подложке."""
import math

from gen_icons import (O, W, blob, ell, ell_pts, fish_icon, leaf_shape, line, new, poly, quad_curve, rgb, rrect, shine,
                       stroke)


def i_ice():
    img, d = new()
    poly(d, [(150, 150), (330, 110), (410, 230), (380, 400), (190, 430), (110, 300)], rgb("bfe6f5"))
    poly(d, [(170, 165), (320, 130), (360, 200), (210, 240)], rgb("e8f8ff"), w=0)
    line(d, [(250, 260), (300, 330), (280, 400)], rgb("8fc8e0"), 8)
    line(d, [(300, 330), (360, 340)], rgb("8fc8e0"), 6)
    shine(d, 200, 190, 40, 14, -0.3, 180)
    return img


def i_resin():
    img, d = new()
    poly(d, [(140, 120), (240, 90), (260, 440), (150, 450)], rgb("8a6a4a"))
    for k in range(5):
        line(d, [(160, 140 + k * 60), (235, 130 + k * 62)], rgb("6b4a32"), 8)
    poly(d, quad_curve((250, 180), (380, 200), (360, 330)) + quad_curve((360, 330), (300, 420), (260, 320))[1:], rgb("e8a83a"))
    ell(d, 330, 400, 34, 40, rgb("e8a83a"))
    shine(d, 300, 240, 16, 40, 0.3, 170)
    shine(d, 320, 385, 8, 12, 0.3, 170)
    return img


def i_cloudberry():
    img, d = new()
    poly(d, leaf_shape((256, 200), (410, 120), -10, 50), rgb("5a8a44"))
    poly(d, leaf_shape((240, 200), (90, 140), 10, 46), rgb("6fa04f"))
    for k in range(7):
        a = k * 2 * math.pi / 7
        ell(d, 256 + math.cos(a) * 62, 300 + math.sin(a) * 56, 46, 46, rgb("f5a030"))
    ell(d, 256, 300, 50, 50, rgb("f8b848"))
    for k in range(7):
        a = k * 2 * math.pi / 7 + 0.4
        ell(d, 256 + math.cos(a) * 62 - 10, 300 + math.sin(a) * 56 - 14, 10, 8, rgb("ffe0a0"), w=0)
    return img


def i_lingonberry():
    img, d = new()
    stroke(d, quad_curve((120, 110), (250, 140), (330, 220)), rgb("6b4a32"), 12)
    poly(d, leaf_shape((180, 125), (110, 60), 0, 26), rgb("2f5a34"))
    poly(d, leaf_shape((260, 155), (300, 70), 0, 26), rgb("3a6a3c"))
    for x, y, r in ((300, 270, 56), (220, 320, 60), (330, 360, 58), (250, 410, 52), (160, 390, 46)):
        ell(d, x, y, r, r, rgb("d8343a"))
        ell(d, x - r * 0.3, y - r * 0.35, r * 0.25, r * 0.18, rgb("ffa0a0"), w=0)
    return img


def i_ice_cream():
    img, d = new()
    poly(d, [(170, 250), (342, 250), (256, 470)], rgb("d6a05a"))
    for k in range(4):
        line(d, [(185 + k * 40, 255), (230 + k * 30, 420)], rgb("b8803a"), 6)
    ell(d, 205, 220, 72, 66, rgb("fff0e0"))
    ell(d, 307, 220, 72, 66, rgb("f5a030"))
    ell(d, 256, 150, 78, 70, rgb("fff6ec"))
    ell(d, 256, 85, 20, 20, rgb("d8343a"))
    shine(d, 230, 130, 22, 12, -0.4, 170)
    return img


def i_honey_tea():
    img, d = new()
    poly(d, [(140, 190), (360, 190), (340, 440), (160, 440)], rgb("f2ead8"))
    poly(d, [(152, 210), (348, 210), (343, 250), (157, 250)], rgb("d9883a"), w=0)
    line(d, quad_curve((360, 240), (450, 260), (350, 380)), O, 30)
    line(d, quad_curve((360, 240), (440, 262), (350, 380)), rgb("f2ead8"), 16)
    for k in range(3):
        y = 300 + k * 40
        line(d, [(185, y), (315, y)], rgb("c8503a") if k == 1 else rgb("e8d8c0"), 8)
    for x in (200, 256, 312):
        line(d, quad_curve((x, 170), (x - 25, 120), (x + 6, 70)), rgb("ffffff", 200), 12)
    return img


def i_cloudberry_jam():
    img, d = new()
    poly(d, [(150, 170), (362, 170), (380, 440), (132, 440)], rgb("f08a1a"))
    poly(d, [(160, 200), (352, 200), (366, 420), (146, 420)], rgb("f5a030"), w=0)
    rrect(d, (140, 110, 372, 175), 16, rgb("e8ddc8"))
    for k in range(5):
        line(d, [(155 + k * 46, 115), (175 + k * 46, 172)], rgb("c8503a"), 8)
    rrect(d, (190, 260, 322, 340), 10, rgb("fff6dc"))
    ell(d, 256, 300, 24, 22, rgb("f08a1a"))
    shine(d, 175, 260, 14, 60, 0.1, 150)
    return img


def i_felt_boots():
    img, d = new()
    for k, x0 in enumerate((110, 270)):
        poly(d, [(x0, 110), (x0 + 110, 110), (x0 + 115, 330), (x0 + 170, 360), (x0 + 175, 440), (x0 - 10, 440), (x0 - 5, 330)],
             rgb("8a8f98") if k else rgb("9aa0a8"))
        rrect(d, (x0 - 8, 100, x0 + 118, 140), 10, rgb("a8adb5"))
        line(d, [(x0 + 5, 175), (x0 + 105, 175)], rgb("c8403a"), 12)
        for j in range(4):
            ell(d, x0 + 18 + j * 25, 200, 7, 7, rgb("f2ead8"), w=0)
    return img


def i_mittens():
    img, d = new()
    for k, x0 in enumerate((80, 260)):
        poly(d, blob(x0 + 90, 250, 100, 21 + k, 0.06, sx=0.85, sy=1.1), rgb("d84a5a"))
        ell(d, x0 + 10, 250, 34, 50, rgb("d84a5a"))
        rrect(d, (x0 + 25, 340, x0 + 160, 410), 14, rgb("f2ead8"))
        for j in range(5):
            line(d, [(x0 + 40 + j * 25, 345), (x0 + 40 + j * 25, 405)], rgb("d8cdb8"), 6)
        for j in range(3):
            ell(d, x0 + 60 + j * 30, 230, 9, 9, rgb("f2ead8"), w=0)
    return img


def i_ice_pick():
    img, d = new()
    stroke(d, [(150, 450), (330, 110)], rgb("4a6a8a"), 28)
    poly(d, [(250, 120), (330, 85), (450, 130), (340, 135)], rgb("c9d2dc"))
    poly(d, [(320, 95), (300, 50), (260, 70), (300, 120)], rgb("c9d2dc"))
    stroke(d, quad_curve((190, 380), (150, 330), (205, 300)), rgb("c8403a"), 10)
    poly(d, [(145, 440), (165, 470), (135, 490)], rgb("c9d2dc"), w=8)
    return img


def i_ice_drill():
    img, d = new()
    stroke(d, [(130, 90), (382, 90)], rgb("c9a050"), 30)
    stroke(d, [(256, 90), (256, 430)], rgb("8f979e"), 18)
    for k in range(7):
        y = 200 + k * 34
        poly(d, [(256 - 70, y), (256 + 70, y + 20), (256 + 70, y + 32), (256 - 70, y + 12)], rgb("c9d2dc"), w=8)
    poly(d, [(220, 440), (292, 440), (256, 495)], rgb("c9d2dc"), w=8)
    return img


# ----------------------------------------------------------------- листы звёздных карт
def _stars(d, pts, col=rgb("3a5a7a")):
    line(d, pts, rgb("8aa0c0"), 5)
    for x, y in pts:
        ell(d, x, y, 9, 9, col, w=0)


def dd_sail(d):
    _stars(d, [(180, 280), (250, 130), (320, 280), (180, 280)])
    ell(d, 340, 120, 14, 14, rgb("e8b42a"), w=0)


def dd_fish(d):
    _stars(d, [(160, 210), (220, 170), (300, 190), (340, 220), (300, 250), (220, 260), (160, 210)])
    _stars(d, [(340, 220), (380, 190), (380, 250), (340, 220)])


def dd_eye(d):
    pts = [(150 + math.cos(a) * 1.0 * 110 + 110, 215 + math.sin(a) * 55) for a in [k * math.pi / 4 for k in range(9)]]
    _stars(d, pts)
    ell(d, 260, 215, 20, 20, rgb("3a5a7a"), w=0)


def dd_dial(d):
    for r in (110, 80, 50):
        line(d, ell_pts(256, 210, r, r * 0.6), rgb("c9a050"), 6)
    for k in range(6):
        a = -math.pi / 2 + k * math.pi / 3
        ell(d, 256 + math.cos(a) * 125, 210 + math.sin(a) * 75, 7, 7, rgb("8a6a3a"), w=0)


def dd_point(d):
    for a in (0.3, 1.9, 3.6):
        line(d, [(256 + math.cos(a) * 140, 210 + math.sin(a) * 90), (256, 210)], rgb("8aa0c0"), 5)
    ell(d, 256, 210, 22, 22, rgb("c0392b"), w=6)


def dd_lens(d):
    ell(d, 256, 210, 90, 90, rgb("bfe8f0"), w=8)
    line(d, [(220, 150), (270, 220), (250, 280)], rgb("c0392b"), 6)
    line(d, [(380, 140), (330, 170)], rgb("8a6a3a"), 6)


def page_map(doodle):
    """Лист звёздной карты: голубоватая бумага, рисунок созвездия, строчки расчётов."""
    def draw():
        from gen_icons import page
        img = page(doodle)
        return img
    return draw


# ----------------------------------------------------------------- портреты
def portrait_ingrid():
    img, d = new()
    ell(d, 256, 256, 240, 240, rgb("b8cce0"))
    poly(d, [(120, 410), (392, 410), (430, 512), (82, 512)], rgb("b88550"))
    poly(d, [(200, 405), (312, 405), (290, 512), (222, 512)], rgb("f2e8d2"), w=8)
    line(d, quad_curve((150, 400), (256, 450), (362, 400)), rgb("3a5a7a"), 34)
    ell(d, 256, 280, 130, 148, rgb("e8b896"))
    poly(d, blob(256, 165, 135, 37, 0.06, sy=0.45), rgb("d8d4cc"))
    ell(d, 256, 95, 55, 42, rgb("cfcac0"))
    for sx in (-1, 1):
        ell(d, 256 + sx * 52, 285, 40, 34, rgb("dfeef5"), w=8)
        ell(d, 256 + sx * 52, 288, 10, 12, rgb("3a6a9a"), w=0)
        line(d, [(256 + sx * 25, 238), (256 + sx * 85, 236)], rgb("9a948a"), 10)
    line(d, [(236, 285), (276, 285)], rgb("5a5e66"), 8)
    ell(d, 256, 330, 20, 20, rgb("d8a07e"))
    line(d, [(225, 370), (290, 365)], rgb("8a3a32"), 9)
    return img


def portrait_walrus():
    img, d = new()
    ell(d, 256, 256, 240, 240, rgb("cfe0ee"))
    poly(d, blob(256, 300, 190, 5, 0.04, sx=1.05, sy=0.85), rgb("a8785e"))
    ell(d, 256, 340, 120, 80, rgb("d0a888"))
    for sx in (-1, 1):
        poly(d, [(256 + sx * 40, 380), (256 + sx * 60, 380), (256 + sx * 55, 490), (256 + sx * 45, 490)], rgb("f4ecd8"))
        line(d, quad_curve((256 + sx * 150, 245), (256 + sx * 120, 230), (256 + sx * 95, 250)), rgb("3a2a22"), 10)
        for k in range(4):
            line(d, [(256 + sx * 40, 330 + k * 14), (256 + sx * 170, 315 + k * 20)], rgb("f2e8d0"), 5)
    ell(d, 256, 300, 30, 20, rgb("5a3a2a"))
    return img


def portrait_penguins():
    img, d = new()
    ell(d, 256, 256, 240, 240, rgb("d6e8f5"))
    for k, (x, s) in enumerate(((170, 0.8), (340, 0.85), (256, 1.0))):
        poly(d, blob(x, 330, 110 * s, 7 + k, 0.03, sx=0.8, sy=1.25), rgb("23262e"))
        ell(d, x, 360, 60 * s, 95 * s, rgb("f6f6f2"), w=0)
        ell(d, x, 210 - (1 - s) * 60, 62 * s, 58 * s, rgb("23262e"))
        poly(d, [(x - 16 * s, 230 - (1 - s) * 60), (x + 16 * s, 230 - (1 - s) * 60), (x, 262 - (1 - s) * 60)], rgb("ff8a1a"), w=6)
        for sx in (-1, 1):
            ell(d, x + sx * 22 * s, 200 - (1 - s) * 60, 10 * s, 10 * s, rgb("ffffff"), w=0)
    return img


ICONS = {
    "ice": i_ice, "resin": i_resin, "lingonberry": i_lingonberry, "ice_cream": i_ice_cream, "honey_tea": i_honey_tea,
    "cloudberry_jam": i_cloudberry_jam, "felt_boots": i_felt_boots, "mittens": i_mittens, "ice_pick": i_ice_pick,
    "ice_drill": i_ice_drill,
    "cod": fish_icon(rgb("9a9a6a"), rgb("e8e4c8"), rgb("7a7a4a"), spots=rgb("7a7a50")),
    "herring": fish_icon(rgb("8fb0c8"), rgb("eef4f8"), rgb("5a7a98"), stripes=rgb("6a8aa8")),
    "char": fish_icon(rgb("5a7a6a"), rgb("e87a5a"), rgb("e85a3a"), spots=rgb("f2d0b0")),
    "polar_cod": fish_icon(rgb("b8c8d0"), rgb("f2f6f8"), rgb("8a9aa8")),
    "ice_fish": fish_icon(rgb("d8f0ff"), rgb("ffffff"), rgb("9fd8ff"), stripes=rgb("bfe8ff")),
}
CROPS = {"cloudberry": i_cloudberry}
PAGES = (dd_sail, dd_sail, dd_fish, dd_eye, dd_point, dd_lens)
PORTRAITS = {"portrait_ingrid": portrait_ingrid, "portrait_walrus": portrait_walrus, "portrait_penguins": portrait_penguins}
