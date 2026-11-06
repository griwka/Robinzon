#!/usr/bin/env python3
"""Генератор иконок предметов, портретов и значков интерфейса.

Рисует всё векторными фигурами с толстой коричневой обводкой — в стиле игры.
Запуск:  python3 tools/gen_icons.py   (результат — assets/icons/*.png)
Рисуем в 4 раза крупнее и уменьшаем — так получаются ровные сглаженные края.
"""
import math
import os
import random

import numpy as np

from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageFilter

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "icons")
S = 512            # размер холста для рисования
FINAL = 160        # итоговый размер иконки
O = (66, 36, 16, 255)   # цвет обводки (тёплый тёмно-коричневый)
W = 13             # толщина обводки


def rgb(h, a=255):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (a,)


def lighten(c, k=0.35):
    return tuple(int(v + (255 - v) * k) for v in c[:3]) + (c[3],)


def darken(c, k=0.3):
    return tuple(int(v * (1 - k)) for v in c[:3]) + (c[3],)


CUR = None   # текущий холст: фигуры с объёмом рисуются в отдельном слое и накладываются сюда


def new():
    global CUR
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    CUR = img
    return img, ImageDraw.Draw(img)


def _shifted(mask, dx, dy):
    out = Image.new("L", mask.size, 0)
    out.paste(mask, (dx, dy))
    return out


def _cel_fill(pts, fill, w=W):
    """Мягкая объёмная заливка в стиле оригинала:
    скруглённый силуэт, градиент (свет сверху-слева), мягкий блик, тень у края и контур."""
    raw = Image.new("L", (S, S), 0)
    ImageDraw.Draw(raw).polygon(pts, fill=255)
    _cel_mask(raw, fill, w)


def _cel_mask(raw, fill, w=W):
    bbox = raw.getbbox()
    if bbox is None:
        return
    bw, bh = bbox[2] - bbox[0], bbox[3] - bbox[1]
    size = min(bw, bh)
    # скругляем углы: размытие + порог
    r = max(2, min(9, size // 12))
    mask = raw.filter(ImageFilter.GaussianBlur(r)).point(lambda v: 255 if v > 118 else 0)
    # градиент вдоль диагонали
    light, dark = lighten(fill, 0.30), darken(fill, 0.20)
    yy, xx = np.mgrid[0:bh + 2, 0:bw + 2]
    g = np.clip((xx / max(bw, 1) * 0.45 + yy / max(bh, 1) * 0.75) / 1.2, 0, 1)
    grad = Image.fromarray((g * 255).astype(np.uint8), "L")
    g_rgb = Image.composite(Image.new("RGBA", grad.size, dark), Image.new("RGBA", grad.size, light), grad)
    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    layer.paste(g_rgb, (bbox[0] - 1, bbox[1] - 1))
    layer.putalpha(mask)
    if size > 36:
        # мягкая тень у нижне-правого края
        off = max(6, int(size * 0.10))
        inner = ImageChops.subtract(mask, _shifted(mask, -off, -off)).filter(ImageFilter.GaussianBlur(off * 0.6))
        inner = ImageChops.multiply(inner, mask)
        sh = Image.new("RGBA", (S, S), darken(fill, 0.38))
        sh.putalpha(inner.point(lambda v: int(v * 0.75)))
        layer.alpha_composite(sh)
        # мягкий блик сверху-слева
        hl = Image.new("L", (S, S), 0)
        cx, cy = bbox[0] + bw * 0.34, bbox[1] + bh * 0.28
        ImageDraw.Draw(hl).ellipse((cx - bw * 0.2, cy - bh * 0.13, cx + bw * 0.2, cy + bh * 0.13), fill=255)
        hl = ImageChops.multiply(hl.filter(ImageFilter.GaussianBlur(max(4, size * 0.06))), mask)
        hi = Image.new("RGBA", (S, S), (255, 255, 255, 255))
        hi.putalpha(hl.point(lambda v: int(v * 0.55)))
        layer.alpha_composite(hi)
    if w:
        ow = max(3, w // 2) * 2 + 1
        edge = mask.filter(ImageFilter.MaxFilter(ow))
        out = Image.new("RGBA", (S, S), O)
        out.putalpha(edge)
        CUR.alpha_composite(out)
    CUR.alpha_composite(layer)


def tint(pts, cx, cy, r, color, alpha=0.8):
    """Мягкий румянец внутри формы (плавный переход цвета, как у спелого фрукта)."""
    shape = Image.new("L", (S, S), 0)
    ImageDraw.Draw(shape).polygon(pts, fill=255)
    spot = Image.new("L", (S, S), 0)
    ImageDraw.Draw(spot).ellipse((cx - r, cy - r, cx + r, cy + r), fill=int(255 * alpha))
    spot = ImageChops.multiply(spot.filter(ImageFilter.GaussianBlur(r * 0.45)), shape)
    layer = Image.new("RGBA", (S, S), color)
    layer.putalpha(spot)
    CUR.alpha_composite(layer)


def poly(d, pts, fill, w=W):
    pts = [(float(x), float(y)) for x, y in pts]
    if w >= 10 and CUR is not None and fill[3] == 255:
        _cel_fill(pts, fill, w)
        return
    else:
        d.polygon(pts, fill=fill)
    if w:
        d.line(pts + [pts[0]], fill=O, width=w, joint="curve")
        for x, y in pts:
            d.ellipse((x - w / 2, y - w / 2, x + w / 2, y + w / 2), fill=O)


def ell_pts(cx, cy, rx, ry, ang=0.0, n=64, a0=0.0, a1=2 * math.pi):
    out = []
    ca, sa = math.cos(ang), math.sin(ang)
    for i in range(n + 1):
        t = a0 + (a1 - a0) * i / n
        x, y = rx * math.cos(t), ry * math.sin(t)
        out.append((cx + x * ca - y * sa, cy + x * sa + y * ca))
    return out


def ell(d, cx, cy, rx, ry, fill, ang=0.0, w=W):
    poly(d, ell_pts(cx, cy, rx, ry, ang)[:-1], fill, w)


def blob(cx, cy, r, seed, amp=0.12, n=40, sx=1.0, sy=1.0):
    rnd = random.Random(seed)
    ph = [rnd.random() * 6.28 for _ in range(3)]
    pts = []
    for i in range(n):
        t = 2 * math.pi * i / n
        k = 1 + amp * (math.sin(t * 2 + ph[0]) * 0.6 + math.sin(t * 3 + ph[1]) * 0.3 + math.sin(t * 5 + ph[2]) * 0.2)
        pts.append((cx + math.cos(t) * r * k * sx, cy + math.sin(t) * r * k * sy))
    return pts


def line(d, pts, color, w):
    d.line(pts, fill=color, width=int(w), joint="curve")
    for x, y in (pts[0], pts[-1]):
        d.ellipse((x - w / 2, y - w / 2, x + w / 2, y + w / 2), fill=color)


def stroke(d, pts, color, w):
    """Линия с обводкой (сначала тёмная толстая, потом цветная)."""
    line(d, pts, O, w + W)
    line(d, pts, color, w)


def rect_pts(cx, cy, w, h, ang):
    ca, sa = math.cos(ang), math.sin(ang)
    out = []
    for x, y in ((-w / 2, -h / 2), (w / 2, -h / 2), (w / 2, h / 2), (-w / 2, h / 2)):
        out.append((cx + x * ca - y * sa, cy + x * sa + y * ca))
    return out


def rrect(d, box, r, fill, w=W):
    d.rounded_rectangle(box, r, fill=fill, outline=O, width=w)


def shine(d, cx, cy, rx, ry, ang=-0.6, a=150):
    pts = ell_pts(cx, cy, rx, ry, ang)
    d.polygon(pts, fill=(255, 255, 255, a))


def quad_curve(p0, p1, p2, n=24):
    out = []
    for i in range(n + 1):
        t = i / n
        x = (1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t * t * p2[0]
        y = (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t * t * p2[1]
        out.append((x, y))
    return out


def leaf_shape(p0, p2, bend, width):
    """Лист между точками p0 и p2, изогнутый на bend, шириной width."""
    mx, my = (p0[0] + p2[0]) / 2, (p0[1] + p2[1]) / 2
    dx, dy = p2[0] - p0[0], p2[1] - p0[1]
    ln = math.hypot(dx, dy)
    nx, ny = -dy / ln, dx / ln
    a = (mx + nx * (bend + width), my + ny * (bend + width))
    b = (mx + nx * (bend - width), my + ny * (bend - width))
    return quad_curve(p0, a, p2) + quad_curve(p2, b, p0)[1:]


# ----------------------------------------------------------------- материалы
def i_wood():
    img, d = new()
    for cx, cy, ang in ((250, 300, -0.45), (270, 220, 0.35)):
        body = rect_pts(cx, cy, 330, 120, ang)
        poly(d, body, rgb("a8733f"))
        # волокна
        for k in (-25, 15):
            ca, sa = math.cos(ang), math.sin(ang)
            p0 = (cx - 120 * ca - k * sa, cy - 120 * sa + k * ca)
            p1 = (cx + 100 * ca - k * sa, cy + 100 * sa + k * ca)
            line(d, [p0, p1], rgb("8a5a2c"), 8)
        ex, ey = cx + 165 * math.cos(ang), cy + 165 * math.sin(ang)
        ell(d, ex, ey, 34, 60, rgb("e7c08a"), ang)
        ell(d, ex, ey, 16, 30, rgb("c99a5e"), ang, w=6)
    return img


def i_stone():
    img, d = new()
    poly(d, blob(256, 280, 170, 3, 0.1, sy=0.78), rgb("a3a8ad"))
    return img


def i_fiber():
    img, d = new()
    rnd = random.Random(2)
    cols = [rgb("8cc04f"), rgb("a6d05e"), rgb("78ad42")]
    for i in range(11):
        t = (i - 5) / 5
        top = (256 + t * 190 + rnd.randint(-15, 15), 60 + abs(t) * 60)
        mid = (256 + t * 60 + rnd.randint(-30, 30), 230)
        stroke(d, quad_curve((256 + t * 30, 450), mid, top), cols[i % 3], 20)
    rrect(d, (196, 300, 316, 352), 16, rgb("c99a5e"))
    line(d, [(205, 326), (307, 326)], rgb("a87b4f"), 6)
    return img


def i_leaf():
    img, d = new()
    spine = quad_curve((90, 450), (230, 250), (440, 70))
    for i in range(2, len(spine) - 1, 2):
        x, y = spine[i]
        k = 1 - i / len(spine)
        ln = 70 + 80 * k
        for side in (-1, 1):
            tip = (x + side * ln * 0.75 - ln * 0.35, y + side * ln * 0.55 + ln * 0.35)
            poly(d, leaf_shape((x, y), tip, side * 8, 16 + 8 * k), rgb("3fae49") if side > 0 else rgb("52bf56"))
    stroke(d, spine, rgb("6b9a3a"), 12)
    return img


def i_rope():
    img, d = new()
    for r in (170, 125, 80):
        pts = ell_pts(256, 270, r, r * 0.8)
        line(d, pts, O, 52)
        line(d, pts, rgb("d4b483"), 36)
        for i in range(0, 64, 4):
            p = pts[i]
            d.line([p, (p[0] + 10, p[1] - 10)], fill=rgb("b8955f"), width=5)
    stroke(d, quad_curve((400, 290), (470, 380), (420, 470)), rgb("d4b483"), 36)
    return img


def i_plank():
    img, d = new()
    for cy, ang in ((300, -0.08), (200, 0.06)):
        body = rect_pts(256, cy, 400, 95, ang)
        poly(d, body, rgb("d39a5c"))
        for k, off in ((-15, 0), (18, 40)):
            ca, sa = math.cos(ang), math.sin(ang)
            p0 = (256 - 150 * ca - k * sa + off, cy - 150 * sa + k * ca)
            p1 = (256 + 110 * ca - k * sa + off, cy + 110 * sa + k * ca)
            line(d, [p0, p1], rgb("b07a42"), 7)
        for sx in (-160, 160):
            x = 256 + sx * math.cos(ang)
            y = cy + sx * math.sin(ang)
            d.ellipse((x - 11, y - 11, x + 11, y + 11), fill=rgb("6b6f75"))
    return img


def scallop(d, cx, cy, r, color):
    pts = []
    n = 9
    for i in range(n * 8 + 1):
        t = math.pi + math.pi * i / (n * 8)
        bump = 1 + 0.06 * abs(math.sin(i / 8 * math.pi))
        pts.append((cx + math.cos(t) * r * bump, cy + math.sin(t) * r * bump * 1.0))
    pts += [(cx + r * 0.25, cy + r * 0.25), (cx - r * 0.25, cy + r * 0.25)]
    poly(d, pts, color)
    for i in range(1, n):
        t = math.pi + math.pi * i / n
        line(d, [(cx, cy + r * 0.2), (cx + math.cos(t) * r * 0.92, cy + math.sin(t) * r * 0.92)], darken(color, 0.2), 8)
    poly(d, [(cx - r * 0.35, cy + r * 0.2), (cx + r * 0.35, cy + r * 0.2), (cx + r * 0.2, cy + r * 0.45), (cx - r * 0.2, cy + r * 0.45)], darken(color, 0.1))


def i_shell():
    img, d = new()
    scallop(d, 256, 330, 200, rgb("f6c7c0"))
    return img


def i_sail():
    img, d = new()
    stroke(d, [(170, 60), (170, 460)], rgb("8a5a32"), 24)
    poly(d, [(190, 80), (440, 400), (190, 400)], rgb("f2ead3"))
    poly(d, [(190, 250), (316, 250), (370, 320), (190, 320)], rgb("4f8fd8"), w=0)
    d.line([(190, 80), (440, 400), (190, 400), (190, 80)], fill=O, width=W, joint="curve")
    return img


# ----------------------------------------------------------------- урожай
def i_carrot():
    img, d = new()
    for ang, col in ((-0.5, "3fae49"), (0.0, "58c45e"), (0.5, "3fae49")):
        p0 = (300, 170)
        p2 = (300 + math.sin(ang) * 170 + 40, 170 - math.cos(ang) * 150)
        poly(d, leaf_shape(p0, p2, 0, 32), rgb(col))
    body = quad_curve((200, 150), (280, 140), (380, 200)) + [(150, 460)]
    poly(d, body, rgb("f58a1f"))
    for t in (0.3, 0.5, 0.7):
        x = 250 - t * 80
        y = 190 + t * 220
        line(d, [(x - 10, y), (x + 50 - t * 40, y - 15)], rgb("c9651a"), 8)
    d.polygon(leaf_shape((220, 180), (180, 380), 10, 14), fill=(255, 255, 255, 110))
    return img


def i_potato():
    img, d = new()
    poly(d, blob(256, 270, 175, 11, 0.12, sx=1.15, sy=0.78), rgb("c8a064"))
    for x, y in ((180, 300), (300, 230), (330, 330), (240, 350)):
        ell(d, x, y, 13, 9, rgb("8a6a3a"), w=0)
    return img


def i_corn():
    img, d = new()
    poly(d, leaf_shape((256, 470), (130, 120), 40, 60), rgb("6db33f"))
    poly(d, leaf_shape((256, 470), (390, 120), -40, 60), rgb("5aa035"))
    ell(d, 256, 250, 95, 190, rgb("ffd23f"))
    for row in range(-6, 7):
        for col in (-2, -1, 0, 1, 2):
            y = 250 + row * 26
            x = 256 + col * 32 + (row % 2) * 8
            if ((x - 256) / 85) ** 2 + ((y - 250) / 180) ** 2 < 1:
                d.ellipse((x - 11, y - 10, x + 11, y + 10), fill=rgb("e8b52a"))
    poly(d, leaf_shape((256, 470), (170, 220), 30, 55), rgb("7cc444"))
    return img


def i_tomato():
    img, d = new()
    ell(d, 256, 285, 185, 160, rgb("e8443a"))
    star = []
    for i in range(10):
        r = 95 if i % 2 == 0 else 35
        t = -math.pi / 2 + i * math.pi / 5
        star.append((256 + math.cos(t) * r, 150 + math.sin(t) * r * 0.55))
    poly(d, star, rgb("3fae49"))
    stroke(d, [(256, 140), (270, 70)], rgb("3f8f3a"), 18)
    return img


def i_cabbage():
    img, d = new()
    for ang in (-1.0, 1.0, -0.45, 0.45):
        poly(d, leaf_shape((256, 380), (256 + math.sin(ang) * 230, 380 - math.cos(ang) * 160), -ang * 40, 95), rgb("7fc24e"))
    ell(d, 256, 260, 150, 135, rgb("c2e88c"))
    for a in (-0.7, -0.25, 0.25, 0.7):
        line(d, quad_curve((256, 390), (256 + a * 230, 270), (256 + a * 110, 140)), rgb("8fcf5a"), 9)
    line(d, quad_curve((150, 220), (256, 170), (362, 220)), rgb("a7dc72"), 8)
    return img


def i_watermelon():
    img, d = new()
    pts = ell_pts(256, 190, 220, 230, 0, 64, 0.0, math.pi)
    poly(d, pts, rgb("2f8f3a"))
    d.polygon(ell_pts(256, 190, 195, 205, 0, 64, 0.0, math.pi), fill=rgb("bfe88a"))
    d.polygon(ell_pts(256, 190, 178, 188, 0, 64, 0.0, math.pi), fill=rgb("ff5a5f"))
    d.line([(36, 190), (476, 190)], fill=O, width=W)
    for x, y in ((180, 250), (256, 290), (330, 250), (220, 320), (295, 320), (256, 230)):
        ell(d, x, y, 9, 15, rgb("2a1a12"), w=0)
    return img


def i_coconut():
    img, d = new()
    ell(d, 256, 270, 175, 170, rgb("7b5230"))
    for i in range(14):
        t = i / 14 * math.pi * 2
        line(d, [(256 + math.cos(t) * 60, 270 + math.sin(t) * 60), (256 + math.cos(t + 0.2) * 150, 270 + math.sin(t + 0.2) * 150)], rgb("5f3d22"), 6)
    for x, y in ((220, 200), (290, 200), (256, 255)):
        ell(d, x, y, 20, 24, rgb("3a2414"), w=0)
    return img


def i_banana():
    img, d = new()
    stem = (150, 150)
    for k, (tip, bend) in enumerate((((420, 170), (300, 300)), ((440, 290), (290, 380)), ((380, 410), (230, 420)))):
        outer = quad_curve(stem, bend, tip)
        inner = quad_curve(tip, ((bend[0] + stem[0]) / 2 + 30, (bend[1] + stem[1]) / 2 - 20), stem)
        poly(d, outer + inner[1:], rgb("ffd84a") if k != 1 else rgb("ffcb2e"))
        ell(d, tip[0], tip[1], 11, 11, rgb("5a3a1a"), w=0)
    rrect(d, (100, 95, 190, 185), 26, rgb("9aa548"))
    return img


def i_mango():
    img, d = new()
    pts = []
    for i in range(64):
        t = 2 * math.pi * i / 64
        r = 1 - 0.12 * math.cos(t * 2 + 0.6)
        x, y = math.cos(t) * 175 * r, math.sin(t) * 150 * r
        pts.append((x * math.cos(-0.5) - y * math.sin(-0.5) + 256, x * math.sin(-0.5) + y * math.cos(-0.5) + 290))
    poly(d, pts, rgb("ffb238"))
    tint(pts, 190, 230, 150, rgb("ff4d3a"), 0.85)
    tint(pts, 360, 370, 120, rgb("8fc43a"), 0.8)
    stroke(d, [(300, 150), (330, 100)], rgb("6b4a2a"), 14)
    poly(d, leaf_shape((330, 105), (455, 75), -25, 32), rgb("3fae49"))
    return img


def i_lemon():
    img, d = new()
    pts = []
    for i in range(64):
        t = 2 * math.pi * i / 64
        r = 1 + 0.18 * abs(math.cos(t)) ** 8
        pts.append((256 + math.cos(t) * 190 * r, 270 + math.sin(t) * 140))
    poly(d, pts, rgb("f7ef4a"))
    poly(d, leaf_shape((330, 140), (440, 90), -20, 26), rgb("3fae49"))
    return img


# ----------------------------------------------------------------- семена и саженцы
def packet(inner_img):
    img, d = new()
    top = [(110, 90)] + [(110 + i * 29, 70 if i % 2 else 90) for i in range(1, 11)] + [(400, 90)]
    poly(d, top + [(410, 450), (100, 450)], rgb("f2dfb0"))
    d.rectangle((115, 380, 395, 420), fill=rgb("c9a467"))
    ell(d, 256, 240, 120, 120, rgb("fff6dc"), w=10)
    small = inner_img.resize((220, 220), Image.LANCZOS)
    img.alpha_composite(small, (146, 130))
    return img


def pot(inner_img):
    img, d = new()
    # горшок поменьше слева, крупный плод справа — сразу понятно, что за дерево
    stroke(d, quad_curve((170, 290), (160, 200), (175, 120)), rgb("6fbf4a"), 16)
    poly(d, leaf_shape((172, 180), (70, 130), 10, 34), rgb("6fd04f"))
    poly(d, leaf_shape((174, 145), (270, 95), -10, 34), rgb("5cbf45"))
    poly(d, [(70, 300), (270, 300), (245, 460), (95, 460)], rgb("d9774a"))
    rrect(d, (55, 270, 285, 325), 14, rgb("e8875a"))
    small = inner_img.resize((300, 300), Image.LANCZOS)
    img.alpha_composite(small, (210, 190))
    return img


# ----------------------------------------------------------------- продукты и блюда
def i_egg():
    img, d = new()
    poly(d, ell_pts(256, 390, 210, 80, 0, 48, 0, math.pi) + [(46, 360), (466, 360)][::-1], rgb("c9a050"))
    pts = []
    for i in range(64):
        t = 2 * math.pi * i / 64
        ry = 190 if math.sin(t) < 0 else 150
        pts.append((256 + math.cos(t) * 135, 250 + math.sin(t) * ry))
    poly(d, pts, rgb("fff1d6"))
    for k in range(9):
        x0 = 60 + k * 46
        line(d, quad_curve((x0, 380), (x0 + 30, 340), (x0 + 70, 385)), rgb("e8c46a"), 9)
        line(d, quad_curve((x0 + 10, 420), (x0 + 40, 390), (x0 + 80, 425)), rgb("a87b3a"), 8)
    return img


def i_milk():
    img, d = new()
    poly(d, [(200, 90), (312, 90), (312, 160), (380, 240), (380, 450), (132, 450), (132, 240), (200, 160)], rgb("f4f7ff"))
    rrect(d, (190, 50, 322, 100), 12, rgb("4f8fd8"))
    d.rectangle((140, 290, 372, 380), fill=rgb("8fc3ff"))
    ell(d, 256, 335, 36, 30, rgb("fff4dc"), w=8)
    shine(d, 175, 300, 18, 60, 0.0, 170)
    return img


def i_fried_egg():
    img, d = new()
    stroke(d, [(400, 330), (490, 420)], rgb("3a3a3a"), 40)
    ell(d, 250, 260, 220, 200, rgb("4a4a4e"))
    ell(d, 250, 260, 180, 160, rgb("2e2e32"), w=8)
    poly(d, blob(250, 260, 140, 21, 0.13, sy=0.85), rgb("fffaf0"))
    ell(d, 260, 245, 60, 56, rgb("ffb92e"))
    return img


def i_baked_potato():
    img, d = new()
    foil = []
    for i in range(36):
        t = math.pi * i / 35
        r = 200 + (12 if i % 2 else -12)
        foil.append((256 + math.cos(t) * r, 360 + math.sin(t) * r * 0.32))
    poly(d, [(56, 360)] + foil[::-1] + [(456, 360)], rgb("c9cfd6"))
    body = blob(256, 300, 185, 31, 0.06, sx=1.0, sy=0.62)
    poly(d, body, rgb("b9793a"))
    for x, y in ((130, 320), (380, 330), (330, 380), (170, 370)):
        ell(d, x, y, 10, 7, rgb("8a5a2a"), w=0)
    # крестообразный надрез: видна жёлтая мякоть
    star = []
    for i in range(16):
        r = 95 if i % 2 == 0 else 40
        t = -math.pi / 4 + i * math.pi / 8
        star.append((256 + math.cos(t) * r * 1.2, 265 + math.sin(t) * r * 0.55))
    poly(d, star, rgb("ffe59a"))
    rrect(d, (225, 238, 287, 285), 12, rgb("ffd23f"))
    for x in (205, 256, 307):
        line(d, quad_curve((x, 215), (x - 28, 165), (x + 6, 110)), rgb("ffffff", 210), 13)
    return img


def i_cheese():
    img, d = new()
    poly(d, [(80, 300), (420, 180), (440, 260), (100, 400)], rgb("f2c23a"))
    poly(d, [(80, 300), (420, 180), (300, 120)], rgb("ffe38a"))
    poly(d, [(100, 400), (440, 260), (440, 360), (100, 460)], rgb("e8b52a"))
    for x, y, r in ((200, 360, 22), (330, 330, 30), (380, 390, 16), (250, 420, 14), (290, 220, 18)):
        ell(d, x, y, r, r * 0.8, rgb("c99a20"), w=6)
    return img


def i_fruit_salad():
    img, d = new()
    # дольки: апельсин, киви, банан, клубника — узнаваемые сверху
    ell(d, 170, 230, 70, 70, rgb("ff9f2e"))
    for a in range(6):
        t = a * math.pi / 3
        line(d, [(170, 230), (170 + math.cos(t) * 55, 230 + math.sin(t) * 55)], rgb("ffd08a"), 6)
    ell(d, 330, 220, 68, 68, rgb("8bc34a"))
    ell(d, 330, 220, 26, 26, rgb("f0f5d0"), w=0)
    for a in range(10):
        t = a * math.pi / 5
        ell(d, 330 + math.cos(t) * 40, 220 + math.sin(t) * 40, 5, 9, rgb("2a2a1a"), t, w=0)
    ell(d, 250, 180, 50, 50, rgb("fff0b0"))
    ell(d, 250, 180, 14, 14, rgb("e8d080"), w=0)
    poly(d, [(230, 260), (290, 255), (262, 320)], rgb("e8443a"))
    poly(d, ell_pts(256, 290, 215, 190, 0, 48, 0.0, math.pi), rgb("b8834b"))
    d.line([(41, 290), (471, 290)], fill=O, width=W)
    line(d, ell_pts(256, 320, 160, 120, 0, 32, 0.6, math.pi - 0.6), rgb("d39a5c"), 10)
    return img


# ----------------------------------------------------------------- инструменты
def i_stone_axe():
    img, d = new()
    stroke(d, [(120, 470), (300, 80)], rgb("a8733f"), 40)
    poly(d, [(200, 70), (390, 30), (470, 150), (430, 270), (240, 230)], rgb("9aa0a6"))
    d.polygon([(395, 50), (455, 150), (420, 250), (398, 242), (428, 150)], fill=rgb("dde1e5"))
    for k in range(3):
        y = 150 + k * 28
        line(d, [(215, y + 22), (330, y - 18)], O, 26)
        line(d, [(215, y + 22), (330, y - 18)], rgb("d4b483"), 14)
    return img


def i_machete():
    img, d = new()
    rrect(d, (70, 330, 200, 400), 26, rgb("6b3a22"))
    poly(d, [(190, 320), (220, 300), (240, 420), (205, 435)], rgb("8f9499"))
    blade = quad_curve((225, 330), (360, 220), (470, 90)) + quad_curve((470, 90), (430, 230), (235, 400))[1:]
    poly(d, blade, rgb("c9cfd6"))
    line(d, quad_curve((240, 345), (360, 250), (455, 110)), rgb("eef2f6"), 8)
    return img


def i_scrap():
    img, d = new()
    poly(d, [(90, 300), (180, 150), (330, 120), (440, 210), (400, 380), (230, 420), (130, 400)], rgb("9aa3ab"))
    poly(d, [(180, 150), (330, 120), (300, 200), (200, 230)], rgb("c2c9cf"))
    for x, y in ((170, 320), (300, 340), (360, 260)):
        ell(d, x, y, 16, 16, rgb("6b6f75"), w=6)
    poly(d, [(330, 120), (380, 60), (400, 140)], rgb("b08a5a"))
    return img


def i_bamboo():
    img, d = new()
    for k, (x0, x1) in enumerate(((150, 230), (240, 300), (330, 360))):
        stroke(d, [(x0, 470), (x1, 60)], rgb("b8c450") if k != 1 else rgb("a9b84a"), 44)
        for t in (0.25, 0.5, 0.75):
            x = x0 + (x1 - x0) * t
            y = 470 - 410 * t
            line(d, [(x - 26, y), (x + 26, y - 4)], rgb("7a8a30"), 10)
    poly(d, leaf_shape((300, 140), (450, 90), -20, 30), rgb("4f9a4a"))
    return img


def i_coins():
    img, d = new()
    # стопка старых морских монет и одна монета сверху, лицом к нам
    for k in range(4):
        y = 400 - k * 42
        ell(d, 200, y, 120, 42, rgb("d9a520"))
        ell(d, 200, y - 10, 120, 42, rgb("f2c23a"))
    ell(d, 330, 250, 125, 125, rgb("f2c23a"))
    ell(d, 330, 250, 92, 92, rgb("e0a820"), w=8)
    # якорь на монете
    line(d, [(330, 190), (330, 310)], rgb("a87010"), 14)
    line(d, quad_curve((280, 280), (330, 330), (380, 280)), rgb("a87010"), 12)
    line(d, [(305, 210), (355, 210)], rgb("a87010"), 12)
    ell(d, 330, 178, 14, 14, rgb("a87010"), w=0)
    return img


def i_copper_nails():
    img, d = new()
    for k in range(4):
        x = 140 + k * 75
        stroke(d, [(x, 120 + k * 10), (x + 30, 430 - k * 5)], rgb("d9884a"), 22)
        ell(d, x - 2, 115 + k * 10, 38, 18, rgb("e8a060"), -0.1)
    return img


def i_hive_frame():
    img, d = new()
    rrect(d, (90, 90, 420, 420), 18, rgb("c08a50"))
    d.rectangle((130, 130, 380, 380), fill=rgb("f2c23a"))
    for r in range(6):
        for c in range(6):
            x = 150 + c * 40 + (r % 2) * 20
            y = 150 + r * 38
            pts = [(x + math.cos(a) * 17, y + math.sin(a) * 17) for a in [k * math.pi / 3 for k in range(6)]]
            d.polygon(pts, fill=rgb("e0a020"))
    return img


def i_honey():
    img, d = new()
    poly(d, lathe_pts := [(170, 170), (342, 170), (390, 260), (380, 430), (132, 430), (122, 260)], rgb("f2a93a"))
    rrect(d, (150, 120, 362, 180), 16, rgb("c9a050"))
    poly(d, [(170, 120), (342, 120), (330, 80), (182, 80)], rgb("e8ddc8"))
    line(d, [(250, 200), (250, 330)], rgb("ffd27a"), 14)
    return img


def i_wool():
    img, d = new()
    for x, y, r in ((200, 300, 110), (320, 280, 120), (260, 200, 110), (180, 200, 80), (350, 190, 80)):
        ell(d, x, y, r, r * 0.85, rgb("f4efe6"), w=W)
    for k in range(5):
        line(d, quad_curve((150 + k * 50, 260), (170 + k * 50, 230), (190 + k * 50, 260)), rgb("d9d2c4"), 6)
    return img


def i_wool_cloth():
    img, d = new()
    poly(d, [(100, 150), (420, 120), (430, 380), (90, 410)], rgb("e8ddc8"))
    for k in range(7):
        y = 160 + k * 36
        line(d, [(110, y), (420, y - 25)], rgb("c9b8a0"), 6)
    poly(d, [(90, 410), (430, 380), (440, 420), (100, 450)], rgb("d9573b"))
    return img


def i_sheep():
    img, d = new()
    for x, y in ((180, 260), (260, 220), (340, 260), (220, 320), (310, 320)):
        ell(d, x, y, 90, 80, rgb("f4efe6"))
    ell(d, 410, 230, 60, 70, rgb("3a3036"))
    ell(d, 425, 215, 12, 12, rgb("ffffff"), w=0)
    for x in (190, 250, 300, 350):
        stroke(d, [(x, 380), (x, 450)], rgb("3a3036"), 18)
    return img


def i_lyova_key():
    img, d = new()
    ell(d, 160, 180, 90, 90, rgb("e8c050"))
    ell(d, 160, 180, 40, 40, (0, 0, 0, 0), w=W)
    d.ellipse((120, 140, 200, 220), fill=(0, 0, 0, 0))
    stroke(d, [(220, 240), (420, 440)], rgb("e8c050"), 36)
    stroke(d, [(360, 380), (410, 330)], rgb("e8c050"), 26)
    stroke(d, [(400, 420), (440, 380)], rgb("e8c050"), 26)
    line(d, quad_curve((90, 120), (40, 40), (150, 60)), rgb("d4b483"), 10)
    return img


def i_liana():
    img, d = new()
    pts = [(250 + math.sin(t / 30 * math.pi * 3) * 90, 40 + t * 14) for t in range(31)]
    stroke(d, pts, rgb("6f7a35"), 26)
    for k in range(4):
        x, y = pts[5 + k * 7]
        poly(d, leaf_shape((x, y), (x + (90 if k % 2 else -90), y + 40), 10, 30), rgb("4f9a4a"))
    return img


def i_climbing_gloves():
    img, d = new()
    for k, x0 in enumerate((110, 270)):
        poly(d, blob(x0 + 70, 300, 110, 13 + k, 0.08, sx=0.8, sy=1.0), rgb("b8834b"))
        for f in range(4):
            stroke(d, [(x0 + 20 + f * 34, 220), (x0 + 15 + f * 36, 110 + abs(f - 1.5) * 20)], rgb("b8834b"), 30)
        line(d, [(x0 + 10, 380), (x0 + 130, 380)], rgb("6f7a35"), 14)
    return img


def fish_icon(body, belly, fin, stripes=None, spots=None):
    def draw():
        img, d = new()
        poly(d, [(110, 260), (40, 160), (60, 260), (40, 360)], fin)                      # хвост
        poly(d, blob(270, 260, 170, 7, 0.04, sx=1.15, sy=0.62), body)
        d.polygon(ell_pts(290, 300, 140, 50), fill=belly)
        poly(d, [(230, 160), (330, 110), (350, 170)], fin)                                # спинной плавник
        if stripes:
            for x in (230, 300):
                line(d, quad_curve((x, 170), (x + 20, 260), (x, 350)), stripes, 22)
        if spots:
            for x, y in ((220, 220), (280, 250), (330, 215), (250, 290)):
                ell(d, x, y, 12, 12, spots, w=0)
        ell(d, 385, 235, 24, 24, rgb("ffffff"), w=8)
        ell(d, 390, 237, 12, 12, rgb("1d1d1d"), w=0)
        line(d, quad_curve((420, 285), (440, 295), (420, 305)), O, 8)
        return img
    return draw


def i_fish_soup():
    img, d = new()
    poly(d, ell_pts(256, 260, 210, 190, 0, 48, 0.0, math.pi), rgb("8a5a32"))
    ell(d, 256, 260, 210, 70, rgb("e8b45a"))
    for x, y, c in ((190, 255, "f58a1f"), (290, 245, "ffffff"), (330, 270, "3fae49"), (230, 275, "c8a064")):
        ell(d, x, y, 26, 16, rgb(c), w=6)
    for x in (200, 256, 312):
        line(d, quad_curve((x, 180), (x - 25, 130), (x + 6, 80)), rgb("ffffff", 200), 12)
    return img


def i_truffle():
    img, d = new()
    poly(d, blob(256, 290, 160, 41, 0.12, sx=1.0, sy=0.85), rgb("4a3a2a"))
    for k in range(14):
        a = k * 2.4
        ell(d, 256 + math.cos(a) * 90, 290 + math.sin(a) * 70, 14, 10, rgb("6a5a48"), w=0)
    poly(d, leaf_shape((330, 160), (440, 90), -20, 26), rgb("4f9a4a"))
    return img


def i_clay():
    img, d = new()
    poly(d, blob(256, 300, 170, 51, 0.1, sx=1.15, sy=0.7), rgb("c87048"))
    for x, y in ((200, 270), (300, 300), (250, 340)):
        line(d, quad_curve((x - 40, y), (x, y - 20), (x + 40, y)), rgb("a8583a"), 8)
    return img


def i_brick():
    img, d = new()
    for k, (x, y) in enumerate(((150, 320), (360, 320), (255, 200))):
        poly(d, [(x - 105, y - 50), (x + 105, y - 50), (x + 105, y + 50), (x - 105, y + 50)], rgb("b8583a"))
        for q in range(3):
            ell(d, x - 50 + q * 50, y, 10, 10, rgb("8a3a22"), w=0)
    return img


def i_piglet():
    img, d = new()
    ell(d, 240, 290, 170, 130, rgb("f2a8a8"))
    ell(d, 390, 250, 85, 80, rgb("f2a8a8"))
    ell(d, 455, 265, 30, 34, rgb("e88a8a"))
    for y in (255, 280):
        ell(d, 455, y, 6, 8, rgb("8a4a4a"), w=0)
    poly(d, [(360, 180), (395, 140), (410, 200)], rgb("e88a8a"))
    ell(d, 410, 230, 12, 12, rgb("1d1d1d"), w=0)
    for x in (150, 210, 280, 330):
        stroke(d, [(x, 390), (x, 450)], rgb("e88a8a"), 26)
    line(d, quad_curve((70, 260), (40, 230), (70, 210)), O, 10)
    return img


def i_fishing_rod():
    img, d = new()
    stroke(d, [(110, 460), (430, 60)], rgb("b8c450"), 22)
    ell(d, 170, 380, 40, 40, rgb("8f9499"))
    line(d, quad_curve((430, 60), (470, 260), (440, 400)), rgb("eeeeee"), 5)
    ell(d, 440, 410, 22, 22, rgb("d9573b"))
    return img


def i_shovel():
    img, d = new()
    stroke(d, [(150, 70), (300, 330)], rgb("a8733f"), 30)
    stroke(d, [(110, 90), (190, 45)], rgb("a8733f"), 26)
    poly(d, [(270, 300), (360, 250), (450, 410), (400, 470), (330, 450)], rgb("8f9499"))
    return img


def i_fort_key():
    img, d = new()
    ell(d, 160, 180, 100, 100, rgb("9aa0a6"))
    d.ellipse((115, 135, 205, 225), fill=(0, 0, 0, 0))
    stroke(d, [(230, 250), (430, 450)], rgb("9aa0a6"), 40)
    for q in range(3):
        stroke(d, [(340 + q * 30, 360 + q * 30), (390 + q * 30, 310 + q * 30)], rgb("9aa0a6"), 24)
    return img


def i_lamp_oil():
    img, d = new()
    poly(d, [(200, 180), (312, 180), (380, 280), (370, 450), (142, 450), (132, 280)], rgb("6b8a3a"))
    rrect(d, (220, 110, 292, 190), 12, rgb("8a5a32"))
    poly(d, [(170, 300), (342, 300), (342, 400), (170, 400)], rgb("f2e2b8"), w=8)
    poly(d, [(256, 320), (285, 370), (227, 370)], rgb("ff8a1e"), w=6)
    return img


def symbol(kind, col):
    def draw():
        img, d = new()
        ell(d, 256, 256, 220, 220, rgb("f2e2b8"))
        if kind == "moon":
            ell(d, 236, 256, 140, 140, col)
            d.ellipse((236 + 70 - 120, 256 - 40 - 120, 236 + 70 + 120, 256 - 40 + 120), fill=rgb("f2e2b8"))
            line(d, ell_pts(306, 216, 120, 120, 0, 40, 1.7, 3.6), O, W)
        elif kind == "star":
            pts = []
            for i in range(10):
                r = 150 if i % 2 == 0 else 62
                t = -math.pi / 2 + i * math.pi / 5
                pts.append((256 + math.cos(t) * r, 256 + math.sin(t) * r))
            poly(d, pts, col)
        else:
            for k in range(12):
                a = k * math.pi / 6
                stroke(d, [(256 + math.cos(a) * 110, 256 + math.sin(a) * 110), (256 + math.cos(a) * 175, 256 + math.sin(a) * 175)], col, 22)
            ell(d, 256, 256, 95, 95, col)
        return img
    return draw


def portrait_stepa():
    img, d = new()
    ell(d, 256, 256, 240, 240, rgb("a8c8e0"))
    poly(d, [(120, 410), (392, 410), (430, 512), (82, 512)], rgb("2f3e5c"))
    ell(d, 256, 270, 145, 145, rgb("e0a888"))
    poly(d, blob(256, 360, 130, 71, 0.08, sx=1.05, sy=0.75), rgb("d9d4cc"))
    poly(d, [(110, 200), (402, 200), (380, 110), (256, 70), (132, 110)], rgb("8a2a2a"))
    for k in range(5):
        line(d, [(140 + k * 58, 120), (140 + k * 58, 195)], rgb("6a1a1a"), 8)
    for sx in (-1, 1):
        ell(d, 256 + sx * 52, 265, 18, 20, rgb("ffffff"), w=8)
        ell(d, 256 + sx * 52, 268, 10, 11, rgb("3a5a7a"), w=0)
        line(d, [(256 + sx * 25, 232), (256 + sx * 85, 225)], rgb("d9d4cc"), 16)
    ell(d, 256, 310, 30, 26, rgb("d98a70"))
    stroke(d, [(300, 345), (380, 380)], rgb("5a3a22"), 12)
    ell(d, 390, 372, 22, 26, rgb("5a3a22"))
    return img


def fresco(scene):
    """Большой рисунок на стене (охра по камню): старинный стиль, простые силуэты."""
    img = Image.new("RGBA", (S * 2, S), rgb("d9c4a0"))
    d = ImageDraw.Draw(img)
    rnd_ = random.Random(len(scene))
    for k in range(400):   # фактура камня
        x, y = rnd_.randint(0, S * 2), rnd_.randint(0, S)
        r = rnd_.randint(2, 9)
        d.ellipse((x - r, y - r, x + r, y + r), fill=rgb("c9b088", 140))
    ink = rgb("7a3a22")
    red = rgb("b8583a")
    def person(x, y, s=1.0):
        d.ellipse((x - 14 * s, y - 70 * s, x + 14 * s, y - 42 * s), fill=ink)
        d.line([(x, y - 42 * s), (x, y)], fill=ink, width=int(9 * s))
        d.line([(x, y), (x - 18 * s, y + 40 * s)], fill=ink, width=int(8 * s))
        d.line([(x, y), (x + 18 * s, y + 40 * s)], fill=ink, width=int(8 * s))
        d.line([(x - 22 * s, y - 30 * s), (x + 22 * s, y - 34 * s)], fill=ink, width=int(7 * s))
    def tower(x, y, lit=True):
        d.polygon([(x - 30, y), (x + 30, y), (x + 20, y - 150), (x - 20, y - 150)], fill=ink)
        if lit:
            d.polygon([(x - 26, y - 150), (x, y - 210), (x + 26, y - 150)], fill=red)
            for a in range(-3, 4):
                d.line([(x, y - 180), (x + a * 40, y - 240)], fill=red, width=5)
    if scene == "light":
        for k, x in enumerate((180, 520, 860)):
            tower(x, 420)
            person(x - 70, 420)
            person(x + 70, 420)
        d.line([(60, 425), (S * 2 - 60, 425)], fill=ink, width=8)
    elif scene == "storm":
        for k in range(9):
            x = 80 + k * 115
            d.arc((x - 60, 60, x + 60, 180), 180, 360, fill=ink, width=12)
        for k in range(5):
            x = 120 + k * 200
            d.line([(x, 190), (x - 30, 260), (x + 10, 260), (x - 20, 330)], fill=red, width=10)
        tower(S - 0, 470)
        for k in range(6):
            r = 120 + k * 60
            d.arc((S - r, 470 - r * 0.6, S + r, 470 + r * 0.6), 200, 340, fill=ink, width=6)
    else:  # map: шесть островов с башнями по кругу, седьмой (Туманный) пунктиром, в центре — Око
        cx, cy, rx, ry = S, S // 2, 400, 175
        def at(deg):
            a = math.radians(deg)
            return cx + rx * math.sin(a), cy - ry * math.cos(a) + 20
        # по часовой от севера: Грозовой, Ледяной, Вулкан, (Туманный), твой остров, Баньян, форт
        isl = [(at(0), 50), (at(55), 52), (at(115), 55), (at(180), 60), (at(245), 62), (at(305), 52)]
        for (x, y), r in isl:
            d.ellipse((x - r, y - r * 0.6, x + r, y + r * 0.6), outline=ink, width=8)
            d.polygon([(x - 8, y - 5), (x + 8, y - 5), (x + 5, y - 45), (x - 5, y - 45)], fill=red)
        fx, fy = at(148)
        for k in range(0, 360, 30):   # седьмой остров — пунктиром, без башни
            d.arc((fx - 46, fy - 28, fx + 46, fy + 28), k, k + 16, fill=ink, width=7)
        for (x, y), r in isl:         # пунктир от каждого маяка к центру
            for t in range(2, 8, 2):
                x0, y0 = x + (cx - x) * t / 10, y + (cy + 20 - y) * t / 10
                x1, y1 = x + (cx - x) * (t + 1) / 10, y + (cy + 20 - y) * (t + 1) / 10
                d.line([(x0, y0), (x1, y1)], fill=ink, width=5)
        oy = cy + 20
        d.ellipse((cx - 78, oy - 50, cx + 78, oy + 50), outline=red, width=10)
        d.ellipse((cx - 50, oy - 30, cx + 50, oy + 30), outline=red, width=6)
        d.polygon([(cx - 12, oy + 8), (cx + 12, oy + 8), (cx + 8, oy - 60), (cx - 8, oy - 60)], fill=ink)
        d.polygon([(cx - 14, oy - 60), (cx, oy - 92), (cx + 14, oy - 60)], fill=red)
    return img


def i_pickaxe():
    img, d = new()
    stroke(d, [(160, 460), (300, 120)], rgb("a8733f"), 34)
    head = quad_curve((80, 200), (290, 30), (470, 210)) + quad_curve((470, 210), (290, 90), (80, 200))[1:]
    poly(d, head, rgb("9a8fb0"))
    d.polygon(quad_curve((120, 175), (290, 60), (430, 185)) + [(290, 95)], fill=rgb("bdb3d0"))
    return img


def i_watering_can():
    img, d = new()
    stroke(d, quad_curve((340, 250), (470, 200), (470, 100)), rgb("5fb0e8"), 28)
    ell(d, 475, 92, 34, 22, rgb("4a90c8"), -0.6)
    line(d, ell_pts(220, 190, 110, 90, 0, 32, math.pi, 2 * math.pi), O, 46)
    line(d, ell_pts(220, 190, 110, 90, 0, 32, math.pi, 2 * math.pi), rgb("4a90c8"), 28)
    rrect(d, (90, 190, 360, 440), 40, rgb("5fb0e8"))
    d.rectangle((110, 250, 340, 290), fill=rgb("8fc8f2"))
    shine(d, 140, 350, 20, 55, 0.0, 120)
    return img


def i_net():
    img, d = new()
    stroke(d, [(120, 470), (280, 250)], rgb("c9a467"), 26)
    ell(d, 330, 170, 125, 115, rgb("f2f2f2", 120))
    for k in range(-4, 5):
        d.line([(330 + k * 28, 60), (330 + k * 28, 280)], fill=rgb("c9c9c9"), width=5)
        d.line([(210, 170 + k * 26), (450, 170 + k * 26)], fill=rgb("c9c9c9"), width=5)
    mask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(mask).polygon(ell_pts(330, 170, 118, 108), fill=255)
    clear = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    inv = Image.eval(mask, lambda v: 255 - v)
    img.paste(clear, (0, 0), Image.composite(inv, Image.new("L", (S, S), 0), _ring_mask()))
    line(d, ell_pts(330, 170, 125, 115), O, 34)
    line(d, ell_pts(330, 170, 125, 115), rgb("f2d16b"), 18)
    return img


def _ring_mask():
    m = Image.new("L", (S, S), 0)
    ImageDraw.Draw(m).polygon(ell_pts(330, 170, 160, 150), fill=255)
    return m


# ----------------------------------------------------------------- коллекции
def i_scallop():
    img, d = new()
    scallop(d, 256, 330, 200, rgb("f7b2a0"))
    return img


def i_seahorse():
    img, d = new()
    # тело — цепочка кругов вдоль S-образной линии (голова -> брюшко -> хвост-завиток)
    key = [(250, 170, 46), (275, 215, 50), (270, 260, 56), (248, 300, 54), (250, 340, 40), (268, 372, 27), (276, 402, 19)]
    path = []
    for i in range(len(key) - 1):
        (x0, y0, r0), (x1, y1, r1) = key[i], key[i + 1]
        for k in range(8):
            t = k / 8
            path.append((x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, r0 + (r1 - r0) * t))
    for i in range(28):
        ang = i / 27 * math.pi * 1.6
        r = 38 - i * 0.9
        path.append((238 + math.cos(ang) * r, 410 + math.sin(ang) * r, 18 - i * 0.35))
    mask = Image.new("L", (S, S), 0)
    md = ImageDraw.Draw(mask)
    for x, y, r in path:
        md.ellipse((x - r, y - r, x + r, y + r), fill=255)
    md.ellipse((175, 85, 285, 185), fill=255)                       # голова
    md.rounded_rectangle((90, 128, 200, 160), 14, fill=255)          # вытянутая мордочка
    _cel_mask(mask, rgb("ffa94d"))
    poly(d, leaf_shape((318, 225), (345, 320), 22, 26), rgb("ffd27a"))   # спинной плавник
    for k, (x, y, r) in enumerate(key[1:6]):
        line(d, [(x - r * 0.7, y), (x + r * 0.6, y + 6)], rgb("e07a2a"), 7)
    for k in range(3):
        poly(d, [(205 + k * 25, 92), (220 + k * 25, 55), (235 + k * 25, 96)], rgb("ff8a2a"), w=9)
    ell(d, 228, 128, 17, 17, rgb("ffffff"), w=6)
    ell(d, 231, 129, 8, 8, rgb("1d1d1d"), w=0)
    return img


def i_rapana():
    img, d = new()
    # закрученная раковина: шпиль-завиток и широкое устье
    poly(d, [(120, 60), (300, 160), (230, 250)], rgb("d98a4c"))
    poly(d, blob(290, 320, 175, 61, 0.06, sx=0.9, sy=1.0), rgb("e39a5c"))
    for k in range(3):
        line(d, ell_pts(290, 320, 150 - k * 45, 160 - k * 48, 0, 32, -2.4, 0.6), rgb("b86a35"), 10)
    ell(d, 330, 350, 72, 100, rgb("ffd6b0"), 0.3, w=14)
    ell(d, 340, 360, 36, 60, rgb("f2a27a"), 0.3, w=0)
    for k in range(4):
        ell(d, 175 + k * 28, 130 + k * 26, 12, 9, rgb("fff1e0"), w=0)
    return img


def i_starfish():
    img, d = new()
    pts = []
    for i in range(10):
        r = 210 if i % 2 == 0 else 85
        t = -math.pi / 2 + i * math.pi / 5
        pts.append((256 + math.cos(t) * r, 270 + math.sin(t) * r))
    poly(d, pts, rgb("ff7a59"))
    for i in range(5):
        t = -math.pi / 2 + i * 2 * math.pi / 5
        for k in (0.35, 0.6, 0.8):
            ell(d, 256 + math.cos(t) * 200 * k, 270 + math.sin(t) * 200 * k, 11, 11, rgb("ffd0a6"), w=0)
    return img


def i_pearl():
    img, d = new()
    scallop(d, 256, 360, 210, rgb("f6d6e8"))
    ell(d, 256, 250, 95, 95, rgb("eef4ff"))
    d.polygon(ell_pts(280, 280, 60, 50), fill=rgb("d6dff0"))
    shine(d, 225, 215, 28, 18, -0.6, 230)
    return img


def butterfly(base, edge, kind):
    img, d = new()
    for side in (-1, 1):
        # верхнее крыло — треугольное, нижнее — округлое
        up = [(256 + side * 20, 230), (256 + side * 230, 80), (256 + side * 215, 250), (256 + side * 40, 265)]
        poly(d, quad_curve(up[0], (256 + side * 120, 60), up[1]) + quad_curve(up[1], (256 + side * 250, 170), up[2]) + [up[3]], base)
        low = blob(256 + side * 105, 340, 85, 30 + side, 0.08, sx=0.9, sy=1.0)
        poly(d, low, darken(base, 0.06))
        line(d, quad_curve((256 + side * 215, 90), (256 + side * 250, 170), (256 + side * 215, 250)), edge, 16)
        if kind == "swallowtail":
            stroke(d, [(256 + side * 120, 405), (256 + side * 140, 475)], base, 20)
            for k in range(3):
                line(d, [(256 + side * (70 + k * 50), 120 + k * 25), (256 + side * (55 + k * 45), 250)], O, 14)
        if kind == "peacock_eye":
            ell(d, 256 + side * 150, 160, 42, 38, rgb("ffd23f"), w=8)
            ell(d, 256 + side * 150, 160, 22, 20, rgb("3b6cff"), w=0)
            ell(d, 256 + side * 100, 345, 24, 24, rgb("3b6cff"), w=6)
        if kind in ("blue_wing", "morpho"):
            for k in range(3):
                ell(d, 256 + side * (200 - k * 6), 120 + k * 50, 9, 9, rgb("ffffff"), w=0)
        if kind == "lemon_wing":
            ell(d, 256 + side * 140, 170, 18, 18, rgb("ff9f2e"), w=0)
    ell(d, 256, 280, 24, 115, rgb("3a2f2a"))
    stroke(d, quad_curve((246, 175), (220, 100), (180, 70)), rgb("3a2f2a"), 8)
    stroke(d, quad_curve((266, 175), (292, 100), (332, 70)), rgb("3a2f2a"), 8)
    return img


# ----------------------------------------------------------------- страницы журнала
def page(doodle):
    img, d = new()
    edge = []
    rnd = random.Random(len(doodle.__name__))
    for i in range(12):
        edge.append((90 + i * 30, 70 + rnd.randint(-8, 8)))
    poly(d, edge + [(450, 90), (440, 460), (80, 450), (95, 90)], rgb("f2e2b8"))
    for k in range(4):
        y = 340 + k * 26
        line(d, [(130, y), (390 - (k % 2) * 60, y)], rgb("b89a6a"), 7)
    doodle(d)
    return img


def dd_ship(d):
    poly(d, [(160, 250), (360, 250), (330, 300), (190, 300)], rgb("a8733f"))
    line(d, [(260, 250), (260, 120)], O, 9)
    poly(d, [(265, 125), (340, 230), (265, 230)], rgb("f2ead3"))
    for x in (150, 210, 270, 330):
        line(d, quad_curve((x, 315), (x + 25, 300), (x + 50, 315)), rgb("4f8fd8"), 8)


def dd_sprout(d):
    poly(d, [(200, 300), (320, 300), (300, 250), (220, 250)], rgb("7a4a2a"))
    line(d, quad_curve((260, 250), (250, 200), (262, 150)), rgb("3f9f3a"), 10)
    poly(d, leaf_shape((262, 190), (190, 150), 10, 26), rgb("6fd04f"))
    poly(d, leaf_shape((262, 165), (335, 125), -10, 26), rgb("5cbf45"))


def dd_storm(d):
    poly(d, blob(260, 170, 85, 71, 0.15, sy=0.55), rgb("8a96a8"))
    poly(d, [(250, 205), (280, 205), (262, 245), (290, 245), (235, 310), (250, 255), (228, 255)], rgb("ffd23f"))
    for x in (170, 330):
        line(d, [(x, 220), (x - 15, 270)], rgb("6fa3d8"), 7)


def dd_lighthouse(d):
    poly(d, [(230, 300), (290, 300), (278, 160), (242, 160)], rgb("3a3a42"))
    poly(d, [(236, 160), (284, 160), (284, 130), (236, 130)], rgb("ffd23f"))
    poly(d, [(230, 130), (290, 130), (260, 100)], rgb("3a3a42"))
    for a in (-0.35, 0.35):
        line(d, [(260, 145), (260 + math.sin(a) * 140 * (1 if a > 0 else -1) * -1, 145 - 40)], rgb("ffe38a"), 6)


def dd_tree(d):
    line(d, [(260, 300), (260, 190)], rgb("8a5a32"), 22)
    poly(d, blob(260, 160, 95, 81, 0.12, sy=0.6), rgb("3fae49"))
    poly(d, [(250, 95), (270, 95), (275, 70), (245, 70)], rgb("ff8a1e"))


def dd_letter(d):
    for k in range(3):
        y = 150 + k * 40
        line(d, [(140, y), (380, y)], rgb("8a6a3a"), 8)
    line(d, quad_curve((300, 290), (340, 250), (380, 290)), rgb("6b4524"), 9)
    line(d, [(330, 260), (360, 300)], rgb("6b4524"), 9)


def portrait_journal():
    img, d = new()
    ell(d, 256, 256, 240, 240, rgb("e8cf9a"))
    poly(d, [(80, 160), (250, 190), (250, 430), (80, 400)], rgb("f7ecd0"))
    poly(d, [(430, 160), (262, 190), (262, 430), (430, 400)], rgb("f2e2b8"))
    for k in range(5):
        y = 230 + k * 32
        line(d, [(110, y - 8), (225, y + 8)], rgb("b89a6a"), 6)
        line(d, [(290, y + 8), (400, y - 8)], rgb("b89a6a"), 6)
    poly(d, [(244, 180), (268, 180), (268, 440), (244, 440)], rgb("8a5a32"))
    return img


# ----------------------------------------------------------------- портреты и значки
def portrait_parrot():
    img, d = new()
    ell(d, 256, 256, 240, 240, rgb("8fd4f2"))
    poly(d, blob(240, 300, 175, 41, 0.05, sy=1.05), rgb("e8443a"))
    ell(d, 300, 245, 75, 60, rgb("f2ead3"), w=10)
    for k in range(3):
        line(d, [(270 + k * 20, 225 + k * 16), (320 + k * 20, 225 + k * 16)], rgb("c9b8a0"), 6)
    ell(d, 290, 230, 34, 36, rgb("ffffff"), w=10)
    ell(d, 298, 232, 18, 20, rgb("1d1d1d"), w=0)
    ell(d, 304, 224, 6, 6, rgb("ffffff"), w=0)
    beak = quad_curve((350, 240), (470, 260), (400, 380)) + [(360, 330)]
    poly(d, beak, rgb("3a2f2a"))
    poly(d, [(355, 300), (400, 330), (365, 340)], rgb("6b5a50"), w=8)
    poly(d, leaf_shape((120, 300), (70, 470), 20, 50), rgb("2f6fe0"))
    poly(d, leaf_shape((170, 120), (130, 30), 10, 30), rgb("ffd23f"))
    return img


def portrait_player():
    img, d = new()
    ell(d, 256, 256, 240, 240, rgb("ffd9a6"))
    poly(d, [(150, 400), (362, 400), (400, 512), (112, 512)], rgb("7f9a4a"))
    ell(d, 256, 270, 150, 150, rgb("f6c9a0"))
    hair = blob(256, 190, 165, 51, 0.1, sy=0.62)
    poly(d, hair, rgb("e07a2e"))
    for x in (160, 210, 260, 310, 350):
        poly(d, [(x - 30, 200), (x + 30, 200), (x + 5, 270)], rgb("e07a2e"), w=10)
    for side in (-1, 1):
        ell(d, 256 + side * 55, 300, 22, 28, rgb("ffffff"), w=8)
        ell(d, 256 + side * 55, 304, 13, 16, rgb("2b6b3a"), w=0)
        ell(d, 256 + side * 95, 345, 22, 13, rgb("f29a8a"), w=0)
    line(d, quad_curve((225, 370), (256, 392), (287, 370)), O, 10)
    return img


def portrait_marta():
    img, d = new()
    ell(d, 256, 256, 240, 240, rgb("bfe0f0"))
    poly(d, [(140, 420), (372, 420), (410, 512), (102, 512)], rgb("6f8fb0"))
    poly(d, [(200, 420), (312, 420), (330, 512), (182, 512)], rgb("f2ead3"))
    ell(d, 256, 280, 140, 145, rgb("e8b48a"))
    poly(d, blob(256, 190, 150, 61, 0.06, sy=0.55), rgb("d9d4cc"))
    ell(d, 256, 95, 60, 50, rgb("d9d4cc"))
    line(d, quad_curve((120, 210), (256, 160), (392, 210)), rgb("d9573b"), 30)
    for sx in (-1, 1):
        ell(d, 256 + sx * 52, 290, 20, 24, rgb("ffffff"), w=8)
        ell(d, 256 + sx * 52, 294, 11, 13, rgb("5a3a22"), w=0)
        ell(d, 256 + sx * 90, 335, 22, 13, rgb("e8866a"), w=0)
        line(d, [(256 + sx * 80, 280), (256 + sx * 100, 270)], rgb("b88a6a"), 6)
    line(d, quad_curve((215, 370), (256, 395), (297, 370)), O, 10)
    return img


def portrait_kesha():
    img, d = new()
    ell(d, 256, 256, 240, 240, rgb("cfe8b0"))
    for sx in (-1, 1):
        ell(d, 256 + sx * 150, 250, 55, 60, rgb("e8b88a"))
    ell(d, 256, 260, 150, 145, rgb("8a5a32"))
    ell(d, 256, 300, 105, 85, rgb("e8b88a"))
    for sx in (-1, 1):
        ell(d, 256 + sx * 48, 250, 26, 30, rgb("ffffff"), w=8)
        ell(d, 256 + sx * 48, 256, 15, 18, rgb("1d1d1d"), w=0)
    line(d, quad_curve((215, 340), (256, 365), (297, 340)), O, 10)
    line(d, quad_curve((150, 430), (256, 470), (362, 430)), rgb("d4b483"), 10)
    ell(d, 256, 470, 22, 26, rgb("e8c050"))
    return img


def bubble():
    img, d = new()
    ell(d, 256, 240, 200, 200, rgb("fff6dc"), w=26)
    poly(d, [(210, 420), (302, 420), (256, 490)], rgb("fff6dc"), w=0)
    line(d, [(212, 428), (256, 494), (300, 428)], O, 26)
    return img


def exclaim():
    img, d = new()
    rrect(d, (205, 60, 307, 340), 40, rgb("ffd23f"))
    ell(d, 256, 420, 52, 52, rgb("ffd23f"))
    return img


# ----------------------------------------------------------------- сборка
def fit(img, margin=0.04, shadow=True):
    """Растянуть рисунок почти на всю иконку и добавить мягкую тень под предметом."""
    bbox = img.getchannel("A").getbbox()
    if bbox is None:
        return img
    crop = img.crop(bbox)
    avail = int(S * (1 - 2 * margin))
    k = min(avail / crop.width, (avail - 20) / crop.height)
    crop = crop.resize((max(1, int(crop.width * k)), max(1, int(crop.height * k))), Image.LANCZOS)
    crop = ImageEnhance.Color(crop).enhance(1.28)       # насыщеннее
    crop = ImageEnhance.Contrast(crop).enhance(1.06)
    out = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    x = (S - crop.width) // 2
    y = (S - 20 - crop.height) // 2
    placed = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    placed.alpha_composite(crop, (x, y))
    if shadow:
        a = placed.getchannel("A").point(lambda v: 255 if v > 40 else 0)
        halo = a.filter(ImageFilter.MaxFilter(23)).filter(ImageFilter.GaussianBlur(2))
        # тень-«подложка» под наклейкой
        drop = Image.new("RGBA", (S, S), (70, 38, 14, 255))
        drop.putalpha(_shifted(halo, 5, 12).point(lambda v: int(v * 0.7)).filter(ImageFilter.GaussianBlur(4)))
        out.alpha_composite(drop)
        # кремовый ободок, как у наклеек в оригинале
        rim = Image.new("RGBA", (S, S), (255, 246, 222, 255))
        rim.putalpha(halo)
        out.alpha_composite(rim)
    out.alpha_composite(placed)
    return out


def save(name, img, do_fit=True):
    if do_fit:
        img = fit(img)
    out = img.resize((FINAL, FINAL), Image.LANCZOS)
    out.save(os.path.join(OUT, name + ".png"))


def main():
    import sys
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import icons_storm as storm   # глава 4
    import icons_ice as ice       # глава 5
    import icons_volcano as volcano   # глава 6
    import icons_fog as fog           # глава 7
    import icons_eye as eye           # глава 8
    os.makedirs(OUT, exist_ok=True)
    crops = {"carrot": i_carrot, "potato": i_potato, "corn": i_corn, "tomato": i_tomato,
             "cabbage": i_cabbage, "watermelon": i_watermelon}
    fruits = {"banana": i_banana, "mango": i_mango, "lemon": i_lemon, "coconut": i_coconut}
    icons = {
        "wood": i_wood, "stone": i_stone, "fiber": i_fiber, "leaf": i_leaf, "rope": i_rope,
        "plank": i_plank, "shell": i_shell, "sail": i_sail,
        "egg": i_egg, "milk": i_milk, "fried_egg": i_fried_egg, "baked_potato": i_baked_potato,
        "cheese": i_cheese, "fruit_salad": i_fruit_salad,
        "stone_axe": i_stone_axe, "pickaxe": i_pickaxe, "machete": i_machete,
        "coins": i_coins, "copper_nails": i_copper_nails, "hive_frame": i_hive_frame, "honey": i_honey, "wool": i_wool,
        "wool_cloth": i_wool_cloth, "sheep": i_sheep, "lyova_key": i_lyova_key, "liana": i_liana,
        "climbing_gloves": i_climbing_gloves,
        "fish_soup": i_fish_soup, "truffle": i_truffle, "clay": i_clay, "brick": i_brick, "piglet": i_piglet,
        "fishing_rod": i_fishing_rod, "shovel": i_shovel, "fort_key": i_fort_key, "lamp_oil": i_lamp_oil,
        "fish": fish_icon(rgb("7fa8c8"), rgb("d8e8f0"), rgb("5a88a8")),
        "perch": fish_icon(rgb("8fae4a"), rgb("e8e0a0"), rgb("d9573b"), stripes=rgb("4a6a2a")),
        "mackerel": fish_icon(rgb("4a7ab8"), rgb("e8f0f8"), rgb("2a5a98"), stripes=rgb("1a3a6a")),
        "parrotfish": fish_icon(rgb("4ac8a8"), rgb("ffd27a"), rgb("e8448a"), spots=rgb("e8448a")),
        "clownfish": fish_icon(rgb("ff8a2a"), rgb("ffb05a"), rgb("1d1d1d"), stripes=rgb("ffffff")),
        "goldfish": fish_icon(rgb("ffc23a"), rgb("fff0a0"), rgb("ff9a1a"), spots=rgb("fff6c0")),
        "sym_moon": symbol("moon", rgb("4f6fb8")), "sym_star": symbol("star", rgb("e8b42a")), "sym_sun": symbol("sun", rgb("e8642a")), "scrap": i_scrap, "bamboo": i_bamboo, "watering_can": i_watering_can, "net": i_net,
        "scallop": i_scallop, "seahorse": i_seahorse, "rapana": i_rapana, "starfish": i_starfish, "pearl": i_pearl,
    }
    crops.update(storm.CROPS)
    icons.update(storm.ICONS)
    crops.update(ice.CROPS)
    icons.update(ice.ICONS)
    crops.update(volcano.CROPS)
    icons.update(volcano.ICONS)
    icons.update(fog.ICONS)
    icons.update(eye.ICONS)
    icons.update(crops)
    icons.update(fruits)
    for name, fn in icons.items():
        save(name, fn())
    for c, fn in crops.items():
        save("seed_" + c, packet(fn()))
    for t in ("banana", "mango", "lemon"):
        save("sapling_" + t, pot(fruits[t]()))
    bf = {"lemon_wing": ("ffe85c", "ffe85c"), "blue_wing": ("8fd0ff", "2f5fb0"), "swallowtail": ("ffd36a", "ffd36a"),
          "peacock_eye": ("d0456b", "d0456b"), "morpho": ("3b8cff", "14264a")}
    for k, (b, e) in bf.items():
        save(k, butterfly(rgb(b), rgb(e), k))
    for i, dd in enumerate((dd_ship, dd_sprout, dd_storm, dd_lighthouse, dd_tree, dd_letter)):
        save("page_%d" % (i + 1), page(dd))
    for i, dd in enumerate((dd_tree, dd_storm, dd_letter)):
        save("page_b%d" % (i + 1), page(dd))
    for i, dd in enumerate((dd_letter, dd_lighthouse, dd_storm)):
        save("page_f%d" % (i + 1), page(dd))
    for i, dd in enumerate((storm.dd_numbers, dd_storm, dd_letter)):
        save("page_s%d" % (i + 1), page(dd))
    for i, dd in enumerate((storm.dd_radio, storm.dd_numbers, storm.dd_tower)):
        save("page_t%d" % (i + 1), page(dd))
    for i, dd in enumerate(ice.PAGES):
        save("map_%d" % (i + 1), page(dd))
    for i, dd in enumerate(volcano.PAGES):
        save("page_v%d" % (i + 1), page(dd))
    for i, dd in enumerate(fog.PAGES):
        save("letter_%d" % (i + 1), page(dd))
    for i, dd in enumerate(eye.PAGES):
        save("book_%d" % (i + 1), page(dd))
    for scene in ("light", "storm", "map"):
        fresco(scene).save(os.path.join(OUT, "fresco_%s.png" % scene))
    big = 256
    for name, fn in (("portrait_parrot", portrait_parrot), ("portrait_player", portrait_player), ("portrait_journal", portrait_journal),
                     ("portrait_marta", portrait_marta), ("portrait_kesha", portrait_kesha), ("portrait_stepa", portrait_stepa),
                     ("portrait_timur", storm.portrait_timur), ("portrait_radio", storm.portrait_radio)) + tuple(ice.PORTRAITS.items()) + tuple(volcano.PORTRAITS.items()) + tuple(fog.PORTRAITS.items()) + tuple(eye.PORTRAITS.items()):
        fn().resize((big, big), Image.LANCZOS).save(os.path.join(OUT, name + ".png"))
    save("bubble", bubble(), False)
    save("exclaim", exclaim())
    print("icons:", len(os.listdir(OUT)))


if __name__ == "__main__":
    main()
