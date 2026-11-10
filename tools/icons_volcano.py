"""Иконки главы 6 (Остров Вулкана). Тот же стиль, что в gen_icons.py: толстая тёплая обводка,
плоская заливка с мягким объёмом, крупный предмет на светлой подложке."""
import math

from gen_icons import (O, W, blob, ell, ell_pts, leaf_shape, line, new, poly, quad_curve, rgb, rrect, shine, stroke)


def i_aloe():
    img, d = new()
    for k, (a, ln) in enumerate(((-0.9, 260), (-0.45, 300), (0.0, 320), (0.45, 300), (0.9, 260))):
        x1 = 256 + math.sin(a) * ln
        y1 = 450 - math.cos(a) * ln
        poly(d, leaf_shape((256, 450), (x1, y1), 0, 34 - abs(k - 2) * 3), rgb("6fbf7a") if k % 2 else rgb("5aa868"))
        for j in range(3):
            t = 0.35 + j * 0.2
            ell(d, 256 + (x1 - 256) * t, 450 + (y1 - 450) * t, 6, 6, rgb("e8f2e0"), w=0)
    return img


def i_burn_salve():
    img, d = new()
    poly(d, ell_pts(256, 330, 160, 110, 0, 48, 0.0, math.pi), rgb("e8e0c8"))
    ell(d, 256, 330, 160, 50, rgb("bfe8b0"))
    rrect(d, (96, 230, 416, 300), 20, rgb("4f9a8a"))
    poly(d, leaf_shape((210, 330), (300, 300), 6, 18), rgb("6fbf7a"), w=8)
    shine(d, 200, 255, 50, 8, 0, 150)
    return img


def i_charcoal():
    img, d = new()
    for k, (x, y, r) in enumerate(((190, 320, 100), (320, 300, 110), (260, 220, 90))):
        poly(d, blob(x, y, r, 13 + k, 0.12, sy=0.8), rgb("3a3634") if k != 1 else rgb("2e2a28"))
    for x, y in ((200, 300), (330, 280), (250, 220)):
        line(d, quad_curve((x - 40, y), (x, y - 15), (x + 40, y + 5)), rgb("ff7a2a"), 6)
    return img


def i_ore():
    img, d = new()
    poly(d, blob(256, 290, 180, 31, 0.14, sy=0.8), rgb("6a6062"))
    for (x, y, r) in ((200, 260, 40), (300, 310, 50), (250, 360, 30), (330, 230, 28)):
        poly(d, blob(x, y, r, int(x), 0.2), rgb("c8643a"), w=8)
        ell(d, x - r * 0.3, y - r * 0.3, r * 0.2, r * 0.12, rgb("ffb070"), w=0)
    return img


def i_iron_ingot():
    img, d = new()
    poly(d, [(120, 300), (330, 230), (420, 290), (210, 380)], rgb("8a929a"))
    poly(d, [(120, 300), (210, 380), (210, 440), (120, 360)], rgb("6a727a"))
    poly(d, [(210, 380), (420, 290), (420, 350), (210, 440)], rgb("7a828a"))
    shine(d, 260, 290, 70, 12, -0.35, 170)
    return img


def i_iron_pickaxe():
    img, d = new()
    stroke(d, [(150, 460), (300, 150)], rgb("5a3a22"), 30)
    poly(d, quad_curve((90, 210), (270, 60), (460, 200)) + [(440, 220), (270, 110), (110, 230)], rgb("6a7a8a"))
    shine(d, 250, 105, 60, 8, 0.0, 170)
    return img


def i_iron_axe():
    """Железный топор: тёмная кованая голова, светлая заточенная кромка, кожаная обмотка рукояти."""
    img, d = new()
    stroke(d, [(120, 470), (300, 90)], rgb("9a6a3c"), 36)
    for k in range(4):
        y = 400 + k * 18
        line(d, [(128 - (y - 400) * 0.1 + 8, y), (160 - (y - 400) * 0.1, y - 14)], rgb("6b3a22"), 14)
    poly(d, [(215, 80), (300, 60), (420, 30), (470, 150), (430, 285), (310, 210), (230, 210)], rgb("5d6873"))
    d.polygon([(410, 42), (462, 150), (425, 272), (405, 262), (438, 150)], fill=rgb("dde4ea"))
    rrect(d, (250, 60, 320, 215), 18, rgb("4a535c"))
    shine(d, 330, 120, 40, 10, -0.4, 140)
    return img


def i_iron_machete():
    """Железное мачете: тёмный длинный клинок с долом, латунная гарда, тёмная рукоять."""
    img, d = new()
    rrect(d, (60, 340, 190, 410), 26, rgb("4a2a1a"))
    for x in (95, 135, 170):
        ell(d, x, 375, 9, 9, rgb("d2a548"), w=5)
    poly(d, [(185, 325), (215, 300), (240, 425), (205, 440)], rgb("d2a548"))
    blade = quad_curve((225, 330), (370, 210), (480, 70)) + quad_curve((480, 70), (440, 225), (235, 405))[1:]
    poly(d, blade, rgb("6e7a86"))
    line(d, quad_curve((245, 340), (360, 245), (462, 95)), rgb("e6edf2"), 9)
    line(d, quad_curve((235, 365), (350, 280), (430, 150)), rgb("4a545e"), 7)
    return img


def i_iron_nails():
    img, d = new()
    for k in range(5):
        x = 150 + k * 52
        a = (k - 2) * 0.12
        stroke(d, [(x, 160), (x + math.sin(a) * 260, 420)], rgb("8a929a"), 18)
        rrect(d, (x - 30, 140, x + 30, 168), 8, rgb("6a727a"))
    return img


def i_obsidian():
    img, d = new()
    poly(d, [(150, 420), (120, 280), (230, 90), (330, 160), (400, 330), (320, 440)], rgb("2a2438"))
    poly(d, [(230, 90), (260, 260), (120, 280)], rgb("4a3a6a"), w=0)
    poly(d, [(330, 160), (260, 260), (400, 330)], rgb("3a2e52"), w=0)
    line(d, [(200, 140), (170, 250)], rgb("b8a8e8", 200), 10)
    return img


def i_crucible():
    img, d = new()
    poly(d, [(140, 160), (372, 160), (340, 420), (172, 420)], rgb("b8784a"))
    ell(d, 256, 160, 116, 32, rgb("8a5a32"))
    ell(d, 256, 160, 90, 20, rgb("ff9a3a"), w=0)
    for k in range(3):
        line(d, [(170 + k * 4, 240 + k * 60), (342 - k * 4, 240 + k * 60)], rgb("9a6a3e"), 7)
    stroke(d, [(372, 200), (450, 170)], rgb("4a4c52"), 16)
    return img


def i_obsidian_lens():
    img, d = new()
    ell(d, 256, 256, 180, 180, rgb("c9a050"))
    ell(d, 256, 256, 145, 145, rgb("3a2e52"))
    ell(d, 256, 256, 110, 110, rgb("4a3a6a"), w=0)
    shine(d, 210, 200, 60, 22, -0.6, 160)
    ell(d, 300, 310, 18, 18, rgb("ffb03a", 180), w=0)
    return img


def i_coffee():
    img, d = new()
    poly(d, leaf_shape((256, 140), (410, 90), -12, 40), rgb("2f6a3a"))
    poly(d, leaf_shape((240, 150), (100, 110), 12, 36), rgb("3f7a44"))
    for x, y, r in ((200, 280, 64), (310, 270, 68), (250, 370, 70), (150, 380, 52), (360, 380, 54)):
        ell(d, x, y, r, r * 0.9, rgb("c8302a"))
        ell(d, x - r * 0.3, y - r * 0.35, r * 0.25, r * 0.15, rgb("ff8a6a"), w=0)
    return img


def i_roasted_coffee():
    img, d = new()
    for k, (x, y, a) in enumerate(((180, 230, 0.4), (320, 220, -0.5), (250, 330, 0.1), (160, 370, -0.3), (350, 360, 0.6))):
        ell(d, x, y, 70, 50, rgb("5a3422"), ang=a)
        line(d, [(x - math.cos(a) * 50, y - math.sin(a) * 50), (x + math.cos(a) * 50, y + math.sin(a) * 50)], rgb("2e1a12"), 8)
    for x in (200, 300):
        line(d, quad_curve((x, 160), (x - 25, 110), (x + 6, 60)), rgb("ffffff", 200), 12)
    return img


def i_pepper():
    img, d = new()
    poly(d, quad_curve((230, 140), (420, 200), (300, 470)) + quad_curve((300, 470), (180, 330), (230, 140))[1:], rgb("e8342a"))
    shine(d, 280, 230, 18, 70, 0.4, 150)
    poly(d, [(200, 110), (270, 110), (260, 150), (210, 150)], rgb("4f9a4a"))
    stroke(d, quad_curve((235, 110), (230, 60), (270, 40)), rgb("4f7a3a"), 14)
    return img


def i_spicy_soup():
    img, d = new()
    poly(d, ell_pts(256, 270, 205, 180, 0, 48, 0.0, math.pi), rgb("8a5a32"))
    ell(d, 256, 270, 205, 70, rgb("e8643a"))
    for x, y, c in ((190, 265, "e8342a"), (290, 255, "ffffff"), (330, 280, "4f9a4a"), (230, 285, "c8a064")):
        ell(d, x, y, 26, 14, rgb(c), w=6)
    for x in (200, 256, 312):
        line(d, quad_curve((x, 180), (x - 25, 130), (x + 6, 80)), rgb("ffffff", 200), 12)
    poly(d, quad_curve((370, 150), (460, 170), (420, 260)) + [(400, 200)], rgb("e8342a"), w=8)
    return img


def i_fertilizer():
    img, d = new()
    poly(d, [(150, 160), (362, 160), (390, 450), (122, 450)], rgb("c8a46a"))
    poly(d, blob(256, 165, 110, 9, 0.1, sy=0.35), rgb("7a5a3a"))
    poly(d, leaf_shape((256, 330), (340, 260), -8, 24), rgb("5cbf45"), w=8)
    poly(d, leaf_shape((256, 330), (180, 270), 8, 22), rgb("4f9a4a"), w=8)
    line(d, [(256, 330), (256, 400)], rgb("4f7a3a"), 10)
    return img


def i_fire_gloves():
    img, d = new()
    for k, x0 in enumerate((80, 260)):
        poly(d, [(x0 + 20, 450), (x0 + 160, 450), (x0 + 150, 300), (x0 + 30, 300)], rgb("a8602a"))
        poly(d, blob(x0 + 90, 230, 95, 41 + k, 0.06, sx=0.85, sy=1.1), rgb("c8783a"))
        ell(d, x0 + 10, 240, 34, 48, rgb("c8783a"))
        line(d, [(x0 + 30, 330), (x0 + 150, 330)], rgb("3a2a1a"), 8)
        poly(d, blob(x0 + 90, 220, 30, 7 + k, 0.1), rgb("e8a050"), w=6)
    return img


def i_herbal_tea():
    img, d = new()
    poly(d, [(170, 200), (342, 200), (360, 440), (152, 440)], rgb("e8dcc4"))
    line(d, quad_curve((170, 200), (256, 150), (342, 200)), rgb("8a6a4a"), 10)
    for k, (a, col) in enumerate(((-0.6, "8fae5a"), (-0.2, "6f9a4a"), (0.2, "a8c86a"), (0.6, "7fae5a"))):
        poly(d, leaf_shape((256, 200), (256 + math.sin(a) * 140, 200 - math.cos(a) * 150), 0, 26), rgb(col), w=8)
    rrect(d, (200, 300, 312, 380), 10, rgb("f2ead8"))
    poly(d, leaf_shape((230, 340), (285, 325), 4, 12), rgb("4f9a4a"), w=6)
    return img


def stone_icon(kind):
    def draw():
        img, d = new()
        if kind == "pumice":
            poly(d, blob(256, 280, 170, 5, 0.1, sy=0.75), rgb("d8d0c0"))
            for k in range(14):
                a = k * 2.3
                ell(d, 256 + math.cos(a) * 110, 280 + math.sin(a) * 70, 10, 8, rgb("a8a090"), w=0)
        elif kind == "sulfur":
            for k in range(6):
                a = k * 1.05
                poly(d, [(256, 300), (256 + math.cos(a) * 160, 300 + math.sin(a) * 120), (256 + math.cos(a + 0.4) * 120, 300 + math.sin(a + 0.4) * 90)],
                     rgb("f2d23a") if k % 2 else rgb("e8c02a"))
            shine(d, 220, 250, 30, 10, -0.4, 170)
        elif kind == "basalt_stone":
            pts = [(256 + math.cos(a) * 150, 270 + math.sin(a) * 150 * 0.5) for a in [k * math.pi / 3 for k in range(6)]]
            poly(d, [(x, y + 120) for x, y in pts[:4]][::-1] + pts[:4][::1], rgb("454042"))
            poly(d, pts, rgb("6a6466"))
        elif kind == "obsidian_shard":
            poly(d, [(256, 70), (360, 300), (290, 450), (180, 380), (150, 220)], rgb("3a2a5a"))
            line(d, [(230, 130), (190, 300)], rgb("b8a8e8", 200), 10)
        else:
            ell(d, 256, 280, 170, 130, rgb("3a2e2a"))
            ell(d, 256, 280, 100, 80, rgb("ff7a2a"))
            ell(d, 256, 280, 50, 50, rgb("ffd23f"), w=0)
            ell(d, 256, 280, 18, 18, rgb("2e1a12"), w=0)
        return img
    return draw


# ----------------------------------------------------------------- страницы
def dd_storm_boat(d):
    poly(d, [(170, 260), (330, 260), (310, 300), (190, 300)], rgb("a8733f"))
    line(d, [(250, 260), (250, 160)], O, 8)
    for k in range(3):
        line(d, quad_curve((120 + k * 20, 140 + k * 15), (180, 110), (240, 140 + k * 15)), rgb("6a7a9a"), 6)


def dd_lens(d):
    ell(d, 256, 210, 80, 80, rgb("4a3a6a"), w=8)
    line(d, [(225, 150), (275, 225), (255, 280)], rgb("c0392b"), 6)
    poly(d, [(330, 150), (390, 150), (380, 220), (340, 220)], rgb("b8784a"), w=6)


def dd_hands(d):
    for sx in (-1, 1):
        poly(d, blob(256 + sx * 70, 220, 50, 11 + sx, 0.1, sy=1.2), rgb("e8b896"), w=8)
    line(d, quad_curve((190, 260), (256, 300), (322, 260)), rgb("c0392b"), 6)


def portrait_vera():
    img, d = new()
    ell(d, 256, 256, 240, 240, rgb("f2d8c0"))
    poly(d, [(110, 400), (402, 400), (440, 512), (72, 512)], rgb("d9a04a"))
    poly(d, [(210, 400), (302, 400), (290, 512), (222, 512)], rgb("7a4a6a"), w=8)
    ell(d, 256, 285, 138, 145, rgb("e8b896"))
    poly(d, blob(256, 175, 150, 47, 0.08, sy=0.5), rgb("d8443a"))
    for k in range(9):
        a = k * 0.7
        ell(d, 256 + math.cos(a) * 100, 165 + math.sin(a) * 40, 10, 10, rgb("ffd23f"), w=0)
    for sx in (-1, 1):
        line(d, quad_curve((256 + sx * 30, 280), (256 + sx * 55, 268), (256 + sx * 80, 280)), rgb("6a4a2a"), 10)
        ell(d, 256 + sx * 80, 330, 26, 16, rgb("f29a8a"), w=0)
    ell(d, 256, 320, 26, 22, rgb("d8a07e"))
    poly(d, quad_curve((205, 365), (256, 405), (307, 365)), rgb("8a3a32"), w=8)
    return img


ICONS = {
    "aloe": i_aloe, "burn_salve": i_burn_salve, "charcoal": i_charcoal, "ore": i_ore, "iron_ingot": i_iron_ingot,
    "iron_pickaxe": i_iron_pickaxe, "iron_axe": i_iron_axe, "iron_machete": i_iron_machete, "iron_nails": i_iron_nails, "obsidian": i_obsidian, "crucible": i_crucible,
    "obsidian_lens": i_obsidian_lens, "coffee": i_coffee, "roasted_coffee": i_roasted_coffee, "spicy_soup": i_spicy_soup,
    "fertilizer": i_fertilizer, "fire_gloves": i_fire_gloves, "herbal_tea": i_herbal_tea,
    "pumice": stone_icon("pumice"), "sulfur": stone_icon("sulfur"), "basalt_stone": stone_icon("basalt_stone"),
    "obsidian_shard": stone_icon("obsidian_shard"), "fire_eye": stone_icon("fire_eye"),
}
CROPS = {"pepper": i_pepper}
PAGES = (dd_storm_boat, dd_lens, dd_hands)
PORTRAITS = {"portrait_vera": portrait_vera}
