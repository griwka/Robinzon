"""Иконки главы 4 (Грозовой остров). Рисуются теми же средствами, что и в gen_icons.py:
толстая тёплая обводка, плоская заливка с мягким объёмом, крупный предмет на светлой подложке."""
import math

from gen_icons import (O, W, blob, ell, ell_pts, leaf_shape, line, new, page, poly, quad_curve, rgb, rrect, shine,
                       stroke)


def i_copper_wire():
    img, d = new()
    for k in range(5):
        pts = ell_pts(256, 260 - k * 4, 170 - k * 12, 120 - k * 9, 0.15)
        line(d, pts, O, 34)
    for k in range(5):
        pts = ell_pts(256, 260 - k * 4, 170 - k * 12, 120 - k * 9, 0.15)
        line(d, pts, rgb("d9884a") if k % 2 else rgb("e8a060"), 20)
    stroke(d, quad_curve((410, 280), (460, 340), (430, 430)), rgb("d9884a"), 18)
    return img


def i_sand():
    img, d = new()
    poly(d, blob(256, 330, 190, 21, 0.06, sx=1.15, sy=0.55), rgb("ecd29a"))
    poly(d, blob(256, 270, 120, 23, 0.08, sx=1.1, sy=0.6), rgb("f4e0b0"), w=0)
    for x, y in ((180, 320), (260, 300), (330, 340), (220, 360), (300, 270)):
        ell(d, x, y, 6, 5, rgb("c9a86a"), w=0)
    return img


def i_glass():
    img, d = new()
    poly(d, [(110, 160), (330, 110), (410, 330), (190, 400)], rgb("bfe8f0"))
    poly(d, [(170, 190), (310, 160), (330, 210), (190, 240)], rgb("eafaff"), w=0)
    line(d, [(250, 330), (370, 300)], rgb("ffffff", 200), 10)
    return img


def _battery(charged):
    img, d = new()
    rrect(d, (120, 140, 392, 440), 26, rgb("4f7a5a") if charged else rgb("6b6f75"))
    rrect(d, (170, 100, 230, 150), 8, rgb("c9a050"))
    rrect(d, (282, 100, 342, 150), 8, rgb("c9a050"))
    rrect(d, (160, 200, 352, 380), 14, rgb("f2ede2"))
    if charged:
        poly(d, [(270, 210), (210, 300), (255, 300), (230, 375), (305, 270), (260, 270)], rgb("ffd23f"))
    else:
        for k in range(3):
            line(d, [(190, 240 + k * 50), (322, 240 + k * 50)], rgb("b8b0a0"), 10)
    return img


def i_battery():
    return _battery(False)


def i_battery_charged():
    return _battery(True)


def i_fuse():
    img, d = new()
    poly(d, [(120, 220), (392, 220), (392, 300), (120, 300)], rgb("f2ead3"))
    for x in (120, 360):
        rrect(d, (x - 30, 200, x + 30, 320), 12, rgb("c9a050"))
    line(d, quad_curve((150, 260), (256, 220), (360, 260)), rgb("8a5a32"), 8)
    shine(d, 256, 238, 90, 10, 0, 140)
    return img


def i_radio_tube():
    img, d = new()
    rrect(d, (190, 360, 322, 440), 10, rgb("3a3a3a"))
    for x in (215, 256, 297):
        line(d, [(x, 440), (x, 470)], rgb("c9a050"), 10)
    poly(d, quad_curve((190, 360), (170, 160), (256, 70)) + quad_curve((256, 70), (342, 160), (322, 360))[1:], rgb("ffe0b0"))
    rrect(d, (225, 180, 287, 300), 8, rgb("8a8a8a"))
    ell(d, 256, 230, 22, 22, rgb("ff9a3a"), w=0)
    shine(d, 215, 180, 18, 60, 0.1, 150)
    return img


def i_lantern():
    img, d = new()
    line(d, quad_curve((190, 110), (256, 30), (322, 110)), O, 18)
    rrect(d, (170, 100, 342, 150), 14, rgb("6b6f75"))
    poly(d, [(185, 150), (327, 150), (340, 390), (172, 390)], rgb("ffe39a"))
    ell(d, 256, 280, 40, 70, rgb("ffb23a"), w=0)
    ell(d, 256, 300, 20, 36, rgb("fff6dc"), w=0)
    for x in (215, 297):
        line(d, [(x, 150), (x - 4 if x < 256 else x + 4, 390)], O, 10)
    rrect(d, (150, 385, 362, 440), 16, rgb("6b6f75"))
    return img


def i_pumpkin():
    img, d = new()
    for k, (x, rx) in enumerate(((180, 95), (332, 95), (256, 105))):
        poly(d, blob(x, 300, rx, 3 + k, 0.05, sx=1.0, sy=1.25), rgb("f08a24") if k == 2 else rgb("e07818"))
    for x in (215, 297):
        line(d, quad_curve((x, 190), (x + (x - 256) * 0.2, 300), (x, 420)), rgb("c86a14"), 8)
    stroke(d, [(256, 175), (270, 110)], rgb("6b8a3a"), 22)
    poly(d, leaf_shape((270, 140), (370, 110), -10, 30), rgb("5cbf45"))
    return img


def i_pumpkin_porridge():
    img, d = new()
    poly(d, ell_pts(256, 270, 205, 180, 0, 48, 0.0, math.pi), rgb("6f8fb0"))
    ell(d, 256, 270, 205, 70, rgb("f2a23a"))
    ell(d, 230, 262, 50, 18, rgb("ffd27a"), w=0)
    ell(d, 300, 275, 26, 12, rgb("f2c23a"), w=0)
    for x in (200, 256, 312):
        line(d, quad_curve((x, 190), (x - 25, 140), (x + 6, 90)), rgb("ffffff", 200), 12)
    stroke(d, [(360, 230), (440, 120)], rgb("c99a5e"), 20)
    return img


def i_feather():
    img, d = new()
    poly(d, leaf_shape((130, 430), (390, 80), 30, 80), rgb("f4f4ee"))
    line(d, quad_curve((120, 450), (250, 280), (390, 80)), rgb("c9c0b0"), 10)
    for k in range(6):
        t = 0.25 + k * 0.11
        x = 130 + (390 - 130) * t
        y = 430 + (80 - 430) * t
        line(d, [(x, y), (x - 50, y - 15)], rgb("ddd8cc"), 5)
    return img


def i_goose():
    img, d = new()
    poly(d, blob(220, 330, 140, 9, 0.05, sx=1.25, sy=0.75), rgb("f6f6ef"))
    poly(d, quad_curve((300, 300), (330, 200), (330, 130)) + quad_curve((370, 130), (370, 220), (340, 320))[0:], rgb("f6f6ef"))
    ell(d, 350, 120, 45, 40, rgb("f6f6ef"))
    poly(d, [(385, 110), (460, 125), (385, 140)], rgb("ff8a1a"))
    ell(d, 355, 110, 9, 9, rgb("1d1d1d"), w=0)
    poly(d, blob(190, 310, 70, 11, 0.08, sx=1.2, sy=0.55), rgb("e8e8de"), w=8)
    for x in (190, 250):
        stroke(d, [(x, 430), (x, 470)], rgb("ff9a2a"), 14)
    return img


def i_radio_set():
    img, d = new()
    stroke(d, [(330, 150), (360, 40)], rgb("3a3a3a"), 14)
    rrect(d, (150, 140, 362, 460), 30, rgb("4a6a5a"))
    rrect(d, (185, 180, 327, 270), 12, rgb("c9e8b0"))
    line(d, quad_curve((200, 240), (230, 200), (260, 240)) + quad_curve((260, 240), (290, 280), (312, 230))[1:], rgb("2f6a3a"), 6)
    for k in range(3):
        for j in range(4):
            ell(d, 200 + j * 37, 310 + k * 40, 10, 10, rgb("2a3a32"), w=0)
    ell(d, 205, 430, 18, 18, rgb("c0392b"), w=6)
    return img


def i_blueberry():
    img, d = new()
    poly(d, leaf_shape((256, 130), (420, 90), -10, 40), rgb("4f9a4a"))
    poly(d, leaf_shape((240, 140), (100, 100), 10, 36), rgb("5cbf45"))
    for x, y, r in ((200, 270, 70), (320, 260, 75), (260, 360, 80), (150, 370, 55), (370, 370, 55)):
        ell(d, x, y, r, r, rgb("3a4aa8"))
        ell(d, x + r * 0.2, y - r * 0.35, r * 0.25, r * 0.15, rgb("8a9ae8"), w=0)
        poly(d, [(x - 12, y - r + 6), (x, y - r - 10), (x + 12, y - r + 6)], rgb("2a2a6a"), w=0)
    return img


def i_sweater():
    img, d = new()
    poly(d, [(170, 110), (342, 110), (440, 190), (400, 260), (360, 230), (360, 450), (152, 450), (152, 230), (112, 260), (72, 190)], rgb("c8503a"))
    poly(d, [(200, 110), (312, 110), (290, 160), (222, 160)], rgb("e8ddc8"), w=8)
    for k in range(3):
        y = 280 + k * 50
        line(d, [(170, y), (342, y)], rgb("f2e2b8"), 12)
    rrect(d, (152, 410, 360, 450), 10, rgb("a8402a"))
    return img


def i_down_jacket():
    img, d = new()
    poly(d, [(170, 100), (342, 100), (450, 200), (410, 280), (370, 250), (370, 460), (142, 460), (142, 250), (102, 280), (62, 200)], rgb("4a7ab8"))
    for k in range(5):
        y = 170 + k * 60
        line(d, quad_curve((150, y), (256, y + 20), (362, y)), rgb("2f5a98"), 8)
    line(d, [(256, 110), (256, 455)], rgb("c9c0b0"), 10)
    poly(d, blob(256, 100, 110, 4, 0.1, sy=0.4), rgb("e8e0d0"))
    return img


def fulg(base, tip):
    def draw():
        img, d = new()
        poly(d, blob(256, 420, 150, 61, 0.08, sy=0.28), rgb("5a524a"))
        for k, a in enumerate((-0.6, -0.15, 0.3, 0.75)):
            pts = [(256, 420)]
            for i in range(1, 6):
                pts.append((256 + math.sin(a) * i * 50 + (15 if i % 2 else -15), 420 - i * 60))
            stroke(d, pts, base if k % 2 else tip, 30 - k * 3)
        shine(d, 230, 250, 12, 60, 0.3, 140)
        return img
    return draw


def dd_radio(d):
    rrect(d, (200, 200, 320, 290), 10, rgb("4a6a5a"))
    line(d, [(300, 200), (330, 120)], O, 8)
    for k in range(3):
        r = 40 + k * 30
        line(d, [(330 + math.cos(a) * r, 120 + math.sin(a) * r) for a in [-1.2 + i * 0.2 for i in range(7)]], rgb("d9884a"), 6)


def dd_numbers(d):
    for k in range(4):
        y = 140 + k * 35
        line(d, [(140, y), (240 + (k % 2) * 40, y)], rgb("8a6a3a"), 7)
    line(d, [(300, 280), (380, 140)], rgb("c0392b"), 6)
    ell(d, 380, 140, 14, 14, rgb("c0392b"), w=0)


def dd_tower(d):
    poly(d, [(225, 310), (295, 310), (282, 150), (238, 150)], rgb("3a3a42"), w=8)
    poly(d, [(240, 150), (280, 150), (276, 125), (244, 125)], rgb("bfe8f0"), w=8)
    line(d, [(260, 125), (260, 70)], rgb("5fb39a"), 8)
    poly(d, [(250, 90), (285, 90), (262, 120), (290, 120), (240, 165), (255, 128), (232, 128)], rgb("ffd23f"), w=6)


def portrait_timur():
    img, d = new()
    ell(d, 256, 256, 240, 240, rgb("b8d0c0"))
    poly(d, [(140, 410), (372, 410), (410, 512), (102, 512)], rgb("4a6a5a"))
    ell(d, 256, 280, 140, 148, rgb("d9a07a"))
    poly(d, blob(256, 165, 135, 33, 0.12, sy=0.45), rgb("2a2420"))
    # очки-консервы на лбу
    for sx in (-1, 1):
        ell(d, 256 + sx * 55, 175, 38, 30, rgb("bfe8f0"), w=10)
    line(d, [(218, 175), (294, 175)], rgb("c9a050"), 10)
    for sx in (-1, 1):
        ell(d, 256 + sx * 52, 285, 20, 24, rgb("ffffff"), w=8)
        ell(d, 256 + sx * 52, 290, 11, 13, rgb("5a3a22"), w=0)
        line(d, [(256 + sx * 30, 250), (256 + sx * 82, 242)], rgb("2a2420"), 12)
    ell(d, 256, 325, 26, 22, rgb("c88a68"))
    poly(d, quad_curve((200, 360), (256, 420), (312, 360)), rgb("7a2a22"), w=8)
    line(d, [(212, 365), (300, 365)], rgb("ffffff"), 10)
    # наушники на шее
    for sx in (-1, 1):
        ell(d, 256 + sx * 120, 420, 38, 44, rgb("2a2a2a"))
    line(d, quad_curve((136, 420), (256, 480), (376, 420)), rgb("3a3a3a"), 14)
    return img


def portrait_radio():
    img, d = new()
    ell(d, 256, 256, 240, 240, rgb("e8cf9a"))
    rrect(d, (120, 170, 392, 380), 26, rgb("5a5e52"))
    rrect(d, (150, 200, 362, 260), 10, rgb("f2d48a"))
    line(d, [(250, 205), (250, 255)], rgb("c0392b"), 8)
    for k in range(4):
        ell(d, 175 + k * 55, 320, 18, 18, rgb("1d1d1d"))
    for k in range(3):
        r = 50 + k * 34
        line(d, [(392 + math.cos(a) * r * 0.6, 150 + math.sin(a) * r) for a in [-1.0 + i * 0.25 for i in range(9)]], rgb("8a6a3a"), 8)
    return img


ICONS = {
    "copper_wire": i_copper_wire, "sand": i_sand, "glass": i_glass, "battery": i_battery,
    "battery_charged": i_battery_charged, "fuse": i_fuse, "radio_tube": i_radio_tube, "lantern": i_lantern,
    "pumpkin_porridge": i_pumpkin_porridge, "feather": i_feather, "goose": i_goose, "radio_set": i_radio_set,
    "blueberry": i_blueberry, "sweater": i_sweater, "down_jacket": i_down_jacket,
    "fulg_twig": fulg(rgb("d9d0b8"), rgb("ece4d0")), "fulg_tube": fulg(rgb("c9b890"), rgb("e0d0a8")),
    "fulg_star": fulg(rgb("e8e0d0"), rgb("fff6e8")), "fulg_green": fulg(rgb("6fc090"), rgb("a8e0c0")),
    "fulg_blue": fulg(rgb("5f9ae0"), rgb("9fc8f8")),
}
CROPS = {"pumpkin": i_pumpkin}
