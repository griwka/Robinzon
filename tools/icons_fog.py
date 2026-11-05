"""Иконки главы 7 (Туманный остров). Тот же стиль, что в gen_icons.py: толстая тёплая обводка,
плоская заливка с мягким объёмом, крупный предмет на светлой подложке."""
import math

from gen_icons import (O, W, blob, ell, ell_pts, leaf_shape, line, new, poly, quad_curve, rgb, rrect, shine, stroke)


def i_direction_finder():
    img, d = new()
    rrect(d, (120, 170, 392, 440), 30, rgb("4a6a5a"))
    ell(d, 256, 300, 100, 100, rgb("f2ead8"))
    for k in range(8):
        a = k * math.pi / 4
        line(d, [(256 + math.cos(a) * 80, 300 + math.sin(a) * 80), (256 + math.cos(a) * 95, 300 + math.sin(a) * 95)], rgb("8a8a7a"), 8)
    poly(d, [(256, 220), (275, 300), (256, 310), (237, 300)], rgb("e8443a"), w=8)
    poly(d, [(256, 380), (275, 300), (256, 290), (237, 300)], rgb("6a7a8a"), w=8)
    stroke(d, [(330, 170), (370, 70)], rgb("3a3a3a"), 12)
    return img


def i_firefly():
    img, d = new()
    ell(d, 256, 300, 120, 120, rgb("e8ff7a", 90), w=0)
    ell(d, 256, 330, 70, 80, rgb("e8ff7a"))
    ell(d, 256, 220, 60, 55, rgb("3a3a2a"))
    for sx in (-1, 1):
        poly(d, blob(256 + sx * 90, 250, 60, 3 + sx, 0.05, sx=1.2, sy=0.6), rgb("e8f2f0"), w=8)
        line(d, quad_curve((256 + sx * 20, 175), (256 + sx * 40, 120), (256 + sx * 70, 110)), O, 8)
    shine(d, 235, 310, 18, 30, 0.2, 170)
    return img


def i_firefly_lantern():
    img, d = new()
    line(d, quad_curve((190, 120), (256, 50), (322, 120)), O, 18)
    rrect(d, (170, 110, 342, 160), 14, rgb("c9a050"))
    poly(d, [(180, 160), (332, 160), (350, 410), (162, 410)], rgb("d8f2e0"))
    for x, y in ((220, 230), (290, 260), (240, 330), (300, 350), (260, 200)):
        ell(d, x, y, 18, 18, rgb("e8ff7a"), w=0)
        ell(d, x, y, 34, 34, rgb("e8ff7a", 80), w=0)
    rrect(d, (150, 400, 362, 450), 16, rgb("c9a050"))
    return img


def i_wax():
    img, d = new()
    poly(d, [(130, 200), (382, 170), (400, 380), (150, 410)], rgb("f2d27a"))
    for k in range(4):
        for j in range(3):
            cx, cy = 180 + k * 55 + j * 10, 230 + j * 55
            pts = [(cx + math.cos(a) * 24, cy + math.sin(a) * 24) for a in [i * math.pi / 3 for i in range(6)]]
            poly(d, pts, rgb("e8b84a"), w=6)
    return img


def i_candle():
    img, d = new()
    rrect(d, (200, 200, 312, 450), 14, rgb("f6ead0"))
    poly(d, quad_curve((200, 240), (230, 280), (232, 330)) + [(212, 330)], rgb("eadcc0"), w=6)
    line(d, [(256, 200), (256, 170)], O, 8)
    poly(d, quad_curve((256, 70), (300, 140), (256, 175)) + quad_curve((256, 175), (212, 140), (256, 70))[1:], rgb("ffd23f"))
    ell(d, 256, 150, 12, 18, rgb("fff6c0"), w=0)
    return img


def i_pumpkin_lantern():
    img, d = new()
    for k, (x, rx) in enumerate(((180, 95), (332, 95), (256, 110))):
        poly(d, blob(x, 300, rx, 3 + k, 0.05, sx=1.0, sy=1.2), rgb("f08a24") if k == 2 else rgb("e07818"))
    for sx in (-1, 1):
        poly(d, [(256 + sx * 60, 250), (256 + sx * 95, 290), (256 + sx * 25, 290)], rgb("ffd23f"), w=8)
    poly(d, [(190, 340), (322, 340), (300, 380), (275, 360), (256, 385), (237, 360), (212, 380)], rgb("ffd23f"), w=8)
    stroke(d, [(256, 185), (270, 120)], rgb("6b8a3a"), 22)
    return img


def i_mangrove_wood():
    img, d = new()
    for k in range(3):
        y = 220 + k * 70
        poly(d, [(110, y), (390, y - 30), (400, y + 20), (120, y + 50)], rgb("7a5a3a") if k % 2 else rgb("8a6a4a"))
        ell(d, 395, y - 5, 18, 26, rgb("c9a26b"), w=6)
    return img


def i_mangrove_plank():
    img, d = new()
    for k in range(3):
        y = 210 + k * 75
        poly(d, [(100, y), (400, y - 30), (410, y + 20), (110, y + 50)], rgb("a0703c") if k % 2 else rgb("b8834b"))
        line(d, [(140, y + 15), (380, y - 12)], rgb("7a5232"), 5)
    return img


def i_ship_rope():
    img, d = new()
    for k in range(5):
        line(d, ell_pts(256, 280 - k * 6, 170 - k * 22, 110 - k * 14, 0.1), O, 40)
    for k in range(5):
        line(d, ell_pts(256, 280 - k * 6, 170 - k * 22, 110 - k * 14, 0.1), rgb("c9a467") if k % 2 else rgb("b8944f"), 26)
    stroke(d, quad_curve((400, 300), (450, 360), (420, 440)), rgb("c9a467"), 22)
    return img


def i_ship_sail():
    img, d = new()
    stroke(d, [(150, 70), (150, 460)], rgb("8a5a32"), 18)
    poly(d, quad_curve((160, 90), (380, 160), (420, 410)) + [(160, 410)], rgb("efe6d0"))
    for k in range(3):
        line(d, [(170, 180 + k * 80), (330 + k * 25, 200 + k * 80)], rgb("d6c8a8"), 8)
    poly(d, [(330, 300), (380, 300), (385, 350), (335, 350)], rgb("c8503a"), w=8)
    return img


def i_medkit():
    img, d = new()
    rrect(d, (110, 170, 402, 420), 30, rgb("f2ead8"))
    rrect(d, (200, 120, 312, 180), 16, rgb("8a8a7a"))
    poly(d, [(230, 220), (282, 220), (282, 270), (332, 270), (332, 322), (282, 322), (282, 372), (230, 372), (230, 322), (180, 322), (180, 270), (230, 270)], rgb("e8443a"))
    return img


def i_sea_chart():
    img, d = new()
    poly(d, [(90, 150), (420, 120), (430, 400), (100, 430)], rgb("e8d8a8"))
    for k in range(3):
        line(d, ell_pts(270, 280, 120 - k * 35, 80 - k * 24), rgb("6a8aa0"), 6)
    ell(d, 270, 280, 14, 14, rgb("c0392b"), w=0)
    line(d, [(140, 380), (230, 300), (250, 290)], rgb("c0392b"), 6)
    for x in (130, 380):
        ell(d, x, 140 if x < 200 else 128, 20, 20, rgb("8a5a32"))
    return img


def moth_icon(wing, edge, dot):
    def draw():
        img, d = new()
        for sx in (-1, 1):
            poly(d, blob(256 + sx * 105, 220, 95, 11 + sx, 0.08, sx=1.0, sy=0.8), wing)
            poly(d, blob(256 + sx * 80, 340, 65, 21 + sx, 0.08, sx=0.9, sy=0.9), edge)
            ell(d, 256 + sx * 105, 220, 22, 22, dot, w=6)
        ell(d, 256, 280, 28, 110, rgb("6a5a4a"))
        for sx in (-1, 1):
            line(d, quad_curve((256 + sx * 10, 175), (256 + sx * 50, 110), (256 + sx * 90, 105)), O, 8)
        return img
    return draw


def dd_letter(d):
    rrect(d, (170, 140, 342, 260), 8, rgb("f2ead8"), w=8)
    line(d, [(170, 140), (256, 210), (342, 140)], O, 6)
    ell(d, 256, 215, 18, 18, rgb("c0392b"), w=0)


PAGES = (dd_letter,) * 6


def _portrait(bg, cloth, skin, hair, extra=None):
    def draw():
        img, d = new()
        ell(d, 256, 256, 240, 240, rgb(bg))
        poly(d, [(120, 410), (392, 410), (430, 512), (82, 512)], rgb(cloth))
        ell(d, 256, 285, 135, 145, rgb(skin))
        poly(d, blob(256, 170, 140, 41, 0.12, sy=0.5), rgb(hair))
        for sx in (-1, 1):
            ell(d, 256 + sx * 52, 290, 20, 24, rgb("ffffff"), w=8)
            ell(d, 256 + sx * 52, 295, 11, 13, rgb("3a2a1a"), w=0)
        ell(d, 256, 330, 24, 20, rgb("d8a07e"))
        if extra:
            extra(d)
        else:
            line(d, quad_curve((215, 375), (256, 395), (297, 375)), rgb("8a3a32"), 10)
        return img
    return draw


def _misha_extra(d):
    poly(d, quad_curve((200, 365), (256, 425), (312, 365)), rgb("8a3a32"), w=8)
    for k in range(6):
        ell(d, 190 + (k % 3) * 18 + (130 if k >= 3 else 0), 325 + (k // 3) * 0, 6, 6, rgb("c87a52"), w=0)


def _renata_extra(d):
    line(d, [(225, 378), (290, 378)], rgb("7a3a32"), 10)
    line(d, [(300, 235), (318, 270)], rgb("e8a8a0"), 6)


def _gosha_extra(d):
    poly(d, blob(256, 395, 110, 77, 0.1, sy=0.55), rgb("5a3a22"))


def _twin_extra(col):
    def ex(d):
        poly(d, quad_curve((205, 365), (256, 410), (307, 365)), rgb("8a3a32"), w=8)
        poly(d, blob(256, 140, 130, 5, 0.04, sy=0.45), rgb(col))
        ell(d, 256, 70, 30, 30, rgb("f2ead8"))
    return ex


ICONS = {
    "direction_finder": i_direction_finder, "firefly": i_firefly, "firefly_lantern": i_firefly_lantern, "wax": i_wax,
    "candle": i_candle, "pumpkin_lantern": i_pumpkin_lantern, "mangrove_wood": i_mangrove_wood,
    "mangrove_plank": i_mangrove_plank, "ship_rope": i_ship_rope, "ship_sail": i_ship_sail, "medkit": i_medkit,
    "sea_chart": i_sea_chart,
    "moth_moon": moth_icon(rgb("bfe8b0"), rgb("9fd090"), rgb("6a8a5a")),
    "moth_ghost": moth_icon(rgb("eef0f2"), rgb("d6dade"), rgb("a8b0b8")),
    "moth_hawk": moth_icon(rgb("a08a6a"), rgb("e8a050"), rgb("4a3a2a")),
    "moth_lilac": moth_icon(rgb("c8a8e0"), rgb("a888c8"), rgb("6a4a8a")),
    "moth_star": moth_icon(rgb("ffd27a"), rgb("2a2a2a"), rgb("ffffff")),
}
PORTRAITS = {
    "portrait_misha": _portrait("cfe0f0", "f2c23a", "e8b896", "c8783a", _misha_extra),
    "portrait_renata": _portrait("d8d0c8", "2f3e5c", "e8b896", "2a1e1a", _renata_extra),
    "portrait_gosha": _portrait("d0d8d0", "eef2f6", "c88a68", "3a3a42", _gosha_extra),
    "portrait_petya": _portrait("cfe0f0", "eef2f6", "e8b896", "d6b07a", _twin_extra("3a6a9a")),
    "portrait_pasha": _portrait("f0e0cf", "eef2f6", "e8b896", "d6b07a", _twin_extra("c8643a")),
}
