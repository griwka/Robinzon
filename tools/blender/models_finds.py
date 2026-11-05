"""Находки на островах: бутылка с запиской (на пляже) и тайник команды «Альбатроса» (в чаще)."""
import math

from kit import box, cyl, hexcol, join, lathe, leaf, paint, set_origin, set_parent, shade, solidify, sphere, tube

BUILDERS = {}

GLASS = hexcol("8fd8b8")
CORK = hexcol("b98a52")
PAPER = hexcol("f4e6c0")
SAND = hexcol("e9cf8e")
WOOD = hexcol("9a6a3e")
CLOTH = hexcol("e0503a")
ROPE = hexcol("d4b483")


def message_bottle():
    """Бутылка лежит на боку, наполовину в песке; внутри свёрнутая записка."""
    tilt = (0, math.pi / 2 - 0.18, 0.35)
    glass = lathe("gl", [(0.0, 0.0), (0.085, 0.0), (0.095, 0.02), (0.095, 0.2), (0.085, 0.24),
                         (0.045, 0.29), (0.035, 0.36), (0.04, 0.37), (0.04, 0.39), (0.0, 0.39)], 18,
                  loc=(-0.18, 0, 0.09), rot=tilt)
    # стекло: светлое сверху (блик), чуть темнее у песка
    paint(glass, GLASS, ao=0.25, ao_h=0.12, noise_amt=0.02, top=0.35,
          fn=lambda co, n: 1.35 if n.z > 0.75 else None)
    cork = cyl("ck", (0.0, 0, 0.0), 0.034, 0.03, 0.06, rot=tilt, segs=10)
    cork.location = (0.2, 0.07, 0.15)
    paint(cork, CORK, ao=0.0, noise_amt=0.15, nscale=20)
    note = tube("nt", [(-0.12, 0.0, 0.1), (0.08, 0.06, 0.13)], 0.035, 10)
    paint(note, PAPER, ao=0.0, fn=lambda co, n: 0.78 if math.sin(co.x * 90) > 0.8 else None)
    string = tube("st", [(0.15, 0.05, 0.14), (0.17, 0.06, 0.12), (0.2, 0.02, 0.07)], 0.008, 6)
    paint(string, hexcol("c0392b"), ao=0.0)
    # песок, намытый волной у бутылки
    mound = sphere("md", (-0.05, -0.02, -0.02), 0.28, scale=(1.4, 1.0, 0.25), segs=16, rings=8)
    paint(mound, hexcol("e2c486"), ao=0.0, noise_amt=0.08, nscale=12)
    join([mound, glass, cork, note, string], "Bottle")


def crew_stash():
    """Тайник: ящичек, прикопанный у корней, рядом — шест с красной тряпкой (видно издалека)."""
    parts = []
    body = box("bx", (0, 0, 0.16), (0.62, 0.42, 0.3), bev=0.03)
    paint(body, WOOD, ao=0.3, ao_h=0.15, noise_amt=0.12, nscale=9,
          fn=lambda co, n: 0.72 if (abs(co.x) > 0.27 or abs(co.z - 0.16) < 0.02) else None)
    parts.append(body)
    for x in (-0.18, 0.18):
        band = box("bd", (x, 0, 0.16), (0.05, 0.44, 0.32))
        paint(band, ROPE, ao=0.0, noise_amt=0.1, nscale=30)
        parts.append(band)
    # земля, присыпавшая ящик
    soil = sphere("sl", (0, 0, 0.0), 0.5, scale=(1.25, 1.0, 0.22), segs=18, rings=8)
    paint(soil, hexcol("8a6a42"), ao=0.0, noise_amt=0.18, nscale=8,
          fn=lambda co, n: hexcol("6f9a3e") if co.z > 0.07 and abs(co.x) > 0.35 else None)
    parts.append(soil)
    # шест с тряпкой — метка команды
    pole = tube("pl", [(0.42, 0.18, -0.05), (0.46, 0.2, 0.7), (0.5, 0.21, 1.25)], [0.03, 0.026, 0.02], 8)
    paint(pole, shade(WOOD, 0.85), ao=0.2, ao_h=0.3)
    parts.append(pole)
    # красная тряпка, повязанная на шест: узел и две ленты в разные стороны — видно с любой стороны
    knot = sphere("kn", (0.5, 0.21, 1.2), 0.06, scale=(1.2, 1.2, 0.9), segs=10, rings=6)
    paint(knot, shade(CLOTH, 0.85), ao=0.0)
    parts.append(knot)
    for d, ln in (((0.0, -1.0, -0.35), 0.5), ((-0.9, 0.3, -0.45), 0.38)):
        flag = leaf("fl", (0.5, 0.21, 1.2), d, ln, 0.13, droop=0.3, segs=6, fold=0.15, up=(0, 0, 1),
                    shape=lambda t: 0.75 + 0.25 * math.sin(t * 9.0))
        solidify(flag, 0.02)
        paint(flag, CLOTH, ao=0.0, noise_amt=0.1, nscale=12)
        parts.append(flag)
    b = join(parts, "Stash")
    lid = box("ld", (0, 0, 0.34), (0.66, 0.46, 0.07), bev=0.02)
    paint(lid, shade(WOOD, 1.12), ao=0.0, noise_amt=0.12, nscale=9)
    lid = join([lid], "Lid")
    set_origin(lid, (0, 0.23, 0.34))
    set_parent(lid, b)


BUILDERS.update({"message_bottle": message_bottle, "crew_stash": crew_stash})
