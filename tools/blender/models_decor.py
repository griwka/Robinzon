"""Кулинария и уют «вечной игры»: котелок и украшения лагеря (мебель, коврики, гирлянды, фонарики,
клумбы, дорожки, заборчики, вывески). Размеры совпадают с Data.BUILDINGS (radius) в игре.
Blender (x, y, z) → Godot (x, z, −y): «вперёд в Godot» (+Z) — это −Y в Blender.
Запекание — как у построек (список BUILDINGS в build.py, texbake.detail_build)."""
import math

from mathutils import Vector

from kit import box, cyl, displace, empty, hexcol, ico, join, lathe, leaf, mix, paint, rnd, shade, sphere, subsurf, tube
from models_buildings import PLANK, ROPE, STONE, WOOD, WOOD_D, log, plank, rope_wrap, stone

IRON = hexcol("3a3b40")
IRON_L = hexcol("5a5d66")
SOOT = hexcol("26221f")
CREAM = hexcol("f2ead3")
RED = hexcol("d9483a")
BLUE = hexcol("4f8fd8")
YELLOW = hexcol("f2c23a")
GREEN = hexcol("4fa64a")
PINK = hexcol("ff7fa8")
VIOLET = hexcol("a884e8")
ORANGE = hexcol("f28a3a")
LAMP = hexcol("ffd27a")
TERRA = hexcol("c8683e")


def _iron(ob, col=IRON, mat="iron"):
    paint(ob, col, ao=0.0, noise_amt=0.05, mat=mat)
    return ob


# ------------------------------------------------------------------ котелок
def cook_pot():
    """Котелок на треноге над каменным очагом: кольцо камней, угли, три жерди, чугунный котёл на цепи,
    похлёбка, половник; рядом — чурбак-столик с миской. FirePoint — под котлом."""
    parts = []
    for i in range(9):
        a = 2 * math.pi * i / 9 + 0.2
        parts.append(stone("st", (math.cos(a) * 0.46, math.sin(a) * 0.46, 0.07), 0.13, i))
    ash = cyl("ash", (0, 0, 0.0), 0.4, 0.38, 0.05, segs=18)
    paint(ash, hexcol("4a403a"), ao=0.0, noise_amt=0.2, nscale=12, mat="soil")
    parts.append(ash)
    for i in range(4):
        a = 2 * math.pi * i / 4 + 0.5
        parts.append(log("lg", (math.cos(a) * 0.3, math.sin(a) * 0.3, 0.06), (-math.cos(a) * 0.12, -math.sin(a) * 0.12, 0.16), 0.05))
    for i in range(4):
        a = 2 * math.pi * i / 4 + 1.2
        e = sphere("em", (math.cos(a) * 0.14, math.sin(a) * 0.14, 0.07), 0.06, (1, 1, 0.5), segs=8, rings=5)
        paint(e, hexcol("ff7a2a"), ao=0.0, noise_amt=0.3, nscale=20, mat="plain")
        parts.append(e)
    # тренога: три жерди сходятся наверху, перевязаны верёвкой
    top = Vector((0, 0, 1.72))
    for i in range(3):
        a = 2 * math.pi * i / 3 + math.pi / 2
        foot = Vector((math.cos(a) * 0.7, math.sin(a) * 0.7, 0.0))
        tip = top + (top - foot).normalized() * 0.16
        parts.append(log("leg", tuple(foot), tuple(tip), 0.04, rings=False))
    parts.append(rope_wrap("tie", (0, 0), 0.07, 1.66, 2))
    # цепь и крюк
    for k in range(5):
        z = 1.6 - k * 0.09
        ln = cyl("ch", (0, 0, z - 0.04), 0.022, 0.022, 0.07, segs=6, rot=(0, 0, k * 1.3))
        _iron(ln, IRON_L)
        parts.append(ln)
    # котёл: пузатый чугунный, с ободом и дужкой
    pot = lathe("pot", [(0.0, 0.5), (0.2, 0.5), (0.32, 0.58), (0.38, 0.74), (0.36, 0.92), (0.32, 1.0), (0.35, 1.03),
                        (0.35, 1.06), (0.3, 1.06), (0.3, 0.98), (0.0, 0.98)], 22)
    paint(pot, IRON, ao=0.2, ao_h=0.6, noise_amt=0.08, nscale=10, mat="iron",
          fn=lambda co, n: SOOT if co.z < 0.62 else (IRON_L if co.z > 1.02 else None))
    parts.append(pot)
    soup = cyl("soup", (0, 0, 0.97), 0.3, 0.3, 0.02, segs=20)
    paint(soup, hexcol("e8a43a"), ao=0.0, noise_amt=0.12, nscale=14, mat="plain",
          fn=lambda co, n: hexcol("f2d27a") if (math.sin(co.x * 23 + 1) * math.cos(co.y * 19) > 0.72) else None)
    parts.append(soup)
    for x, y, c in ((0.1, 0.08, "e8443a"), (-0.12, 0.05, "f58a1f"), (0.02, -0.14, "4f9a4a"), (-0.06, -0.04, "f6e8c0"), (0.15, -0.08, "f58a1f")):
        b = sphere("bit", (x, y, 0.99), 0.04, (1, 1, 0.45), segs=8, rings=5)
        paint(b, hexcol(c), ao=0.0, noise_amt=0.0, mat="plain")
        parts.append(b)
    bail = tube("bail", [(-0.34, 0, 1.04), (-0.26, 0, 1.2), (0, 0, 1.28), (0.26, 0, 1.2), (0.34, 0, 1.04)], 0.016, 6)
    _iron(bail, IRON_L)
    parts.append(bail)
    # половник торчит из котла
    lad = tube("lad", [(0.1, 0.12, 0.98), (0.3, 0.3, 1.2), (0.42, 0.42, 1.34)], [0.018, 0.016, 0.02], 6)
    paint(lad, WOOD, ao=0.0, mat="wood")
    parts.append(lad)
    # чурбак-столик с миской и ложкой (справа, +X)
    parts.append(log("stump", (0.66, -0.42, 0.0), (0.66, -0.42, 0.44), 0.2, col=WOOD_D))
    bowl = lathe("bowl", [(0.0, 0.45), (0.07, 0.45), (0.13, 0.52), (0.14, 0.56), (0.12, 0.56), (0.1, 0.5), (0.0, 0.49)], 14, loc=(0.66, -0.42, 0.0))
    paint(bowl, TERRA, ao=0.0, mat="clay")
    parts.append(bowl)
    s = join(parts, "CookPot")
    empty("FirePoint", (0, 0, 0.1), s)


BUILDERS = {"cook_pot": cook_pot}
