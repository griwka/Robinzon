"""Иконки главы 8 (Око шторма). Тот же стиль, что в gen_icons.py: толстая тёплая обводка,
плоская заливка с мягким объёмом, крупный предмет на светлой подложке."""
import math

from gen_icons import (O, blob, ell, leaf_shape, line, new, poly, quad_curve, rgb, rrect, shine)


def i_pie():
    img, d = new()
    poly(d, [(80, 300), (432, 300), (400, 400), (112, 400)], rgb("c87a3a"))
    poly(d, blob(256, 290, 180, 7, 0.03, sx=1.0, sy=0.45), rgb("f0b860"))
    for k in range(5):
        x = 150 + k * 52
        line(d, quad_curve((x, 250), (x + 20, 285), (x, 320)), rgb("c8843a"), 10)
    for x, y in ((210, 270), (300, 280)):
        poly(d, leaf_shape((x, y), (x + 50, y - 25), 6, 16), rgb("e8443a"))
    shine(d, 200, 255, 30, 14, 0.0, 150)
    return img


def i_bandages():
    img, d = new()
    ell(d, 230, 290, 150, 150, rgb("f2ead8"))
    ell(d, 230, 290, 60, 60, rgb("d8ccb0"))
    ell(d, 230, 290, 30, 30, rgb("b8a888"), w=6)
    poly(d, [(330, 220), (450, 300), (440, 360), (330, 330)], rgb("f2ead8"))
    for k in range(3):
        line(d, [(350 + k * 30, 250 + k * 15), (345 + k * 30, 335 - k * 5)], rgb("d8ccb0"), 6)
    poly(d, [(170, 160), (190, 160), (190, 190), (220, 190), (220, 210), (190, 210), (190, 240), (170, 240), (170, 210), (140, 210), (140, 190), (170, 190)], rgb("e8443a"), w=6)
    return img


def i_grandfather_letters():
    img, d = new()
    for k, (x, y, a) in enumerate(((150, 200, -0.15), (190, 240, 0.08), (230, 280, -0.05))):
        pts = [(x, y), (x + 230, y + 230 * math.tan(a) * 0.3), (x + 230, y + 150), (x, y + 150)]
        poly(d, pts, rgb("efe4c8") if k < 2 else rgb("f6ecd2"))
        line(d, [(x, y), (x + 115, y + 80), (x + 230, y)], rgb("b8a888"), 6)
    line(d, [(230, 330), (460, 330)], rgb("c87a52"), 14)
    line(d, [(345, 280), (345, 430)], rgb("c87a52"), 14)
    ell(d, 345, 330, 22, 18, rgb("c87a52"))
    ell(d, 290, 395, 16, 16, rgb("8a2a2a"), w=0)
    return img


def i_feast():
    img, d = new()
    ell(d, 256, 330, 200, 90, rgb("f2ead8"))
    ell(d, 256, 320, 170, 70, rgb("e8dcc0"), w=0)
    poly(d, blob(190, 290, 70, 3, 0.05, sy=0.6), rgb("f0b860"))
    for k in range(3):
        ell(d, 300 + k * 35, 300 - k * 10, 28, 28, [rgb("e0443a"), rgb("ff9f2e"), rgb("ffe14d")][k])
    poly(d, [(330, 160), (400, 160), (390, 290), (340, 290)], rgb("c87048"))
    ell(d, 365, 160, 35, 12, rgb("8a4a2a"))
    for k in range(3):
        line(d, quad_curve((150 + k * 40, 220), (170 + k * 40, 180), (150 + k * 40, 140)), rgb("ffffff", 160), 8)
    return img


def dd_names(d):
    for k in range(5):
        y = 120 + k * 40
        w = [210, 160, 240, 190, 120][k]
        line(d, [(150, y), (150 + w, y + (k % 2) * 4)], rgb("6b4524") if k < 4 else rgb("3a3a8a"), 7)
    line(d, [(150, 320), (330, 320)], rgb("b89a6a"), 5)


def dd_boat(d):
    poly(d, [(170, 250), (350, 250), (320, 290), (200, 290)], rgb("b8834b"), w=8)
    ell(d, 260, 170, 26, 26, rgb("4a7ab8"), w=8)
    poly(d, [(250, 195), (270, 195), (275, 250), (245, 250)], rgb("e8443a"), w=8)
    for x in (160, 230, 300):
        line(d, quad_curve((x, 305), (x + 25, 292), (x + 50, 305)), rgb("4f8fd8"), 8)


def dd_bowl(d):
    poly(d, [(170, 240), (350, 240), (320, 300), (200, 300)], rgb("9a7038"), w=8)
    poly(d, [(230, 240), (290, 240), (260, 140)], rgb("ffb04a"), w=8)
    poly(d, [(245, 240), (275, 240), (260, 180)], rgb("fff0b0"), w=8)
    for a in (-0.6, 0.0, 0.6):
        line(d, [(260, 135), (260 + math.sin(a) * 90, 135 - math.cos(a) * 60)], rgb("ffd27a"), 6)


def dd_window(d):
    poly(d, blob(260, 200, 110, 13, 0.12, sy=0.8), rgb("6a7488"), w=8)
    ell(d, 260, 205, 45, 60, rgb("bfe8ff"), w=8)
    poly(d, [(225, 230), (295, 230), (285, 255), (235, 255)], rgb("b8834b"), w=8)


def dd_empty(d):
    line(d, [(150, 140), (330, 140)], rgb("6b4524"), 7)
    line(d, [(150, 190), (300, 190)], rgb("6b4524"), 7)
    line(d, [(150, 240), (360, 240)], rgb("b89a6a"), 4)


PAGES = (dd_names, dd_boat, dd_bowl, dd_window, dd_empty)


def portrait_lyova():
    img, d = new()
    ell(d, 256, 256, 240, 240, rgb("c8d8e8"))
    poly(d, [(130, 410), (382, 410), (420, 512), (92, 512)], rgb("2e3a4a"))
    for x, y in ((170, 460), (330, 480)):
        ell(d, x, y, 26, 18, rgb("2a2420"), w=0)
    ell(d, 256, 285, 128, 145, rgb("e0b493"))
    poly(d, blob(256, 345, 112, 23, 0.06, sx=1.0, sy=0.55), rgb("b8b2a8"))
    ell(d, 256, 295, 128, 120, rgb("e0b493"), w=0)
    poly(d, blob(256, 165, 140, 61, 0.16, sy=0.55), rgb("c8c4bc"))
    for k in range(7):
        a = -1.1 + k * 0.37
        x0, y0 = 256 + math.sin(a) * 110, 170 - math.cos(a) * 55
        poly(d, [(x0 - 22, y0 + 10), (x0 + 22, y0 + 10), (x0 + math.sin(a) * 70 + 15, y0 - math.cos(a) * 45 - 20)], rgb("d8d4cc"), w=10)
    for sx in (-1, 1):
        ell(d, 256 + sx * 50, 285, 19, 21, rgb("ffffff"), w=8)
        ell(d, 256 + sx * 50, 289, 10, 11, rgb("3a5a7a"), w=0)
        line(d, [(256 + sx * 25, 250), (256 + sx * 80, 246)], rgb("8a8680"), 12)
        line(d, quad_curve((256 + sx * 30, 318), (256 + sx * 50, 326), (256 + sx * 70, 318)), rgb("c89a80"), 6)
    ell(d, 256, 330, 22, 18, rgb("d0a080"))
    line(d, quad_curve((222, 378), (256, 388), (290, 378)), rgb("8a4a3a"), 9)
    return img


ICONS = {"pie": i_pie, "bandages": i_bandages, "grandfather_letters": i_grandfather_letters, "feast": i_feast}
PORTRAITS = {"portrait_lyova": portrait_lyova}
