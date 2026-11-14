"""Персонажи и животные: герой, попугай Румба, курица, коза, краб.
У героя — скелет (rig.py): сетки Body, Head, ArmL/R, LegL/R привязаны к костям весами.
У животных подвижные части — отдельные объекты с точкой вращения в суставе (их анимирует игра)."""
import math

from mathutils import noise

import rig
from kit import (box, cyl, empty, hexcol, ico, join, lathe, leaf, mix, paint, set_origin, set_parent, shade,
                 sphere, subsurf, tube)

SKIN = hexcol("f6c9a0")
SKIN_D = hexcol("e8a87c")
HAIR = hexcol("e07a2e")
SHIRT = hexcol("7f9a4a")
SHORTS = hexcol("8a5a32")
ROPE = hexcol("d4b483")
WHITE = hexcol("ffffff")
EYE = hexcol("2b6b3a")
DARK = hexcol("22160e")


# ------------------------------------------------------------------ герой
def player():
    """Чиби-картограф: большая голова с растрёпанными рыжими волосами, рваная рубаха, шорты на верёвке."""
    # туловище (от бёдер); гнётся в пояснице и груди — веса по высоте, rig.w_body
    torso = lathe("t", [(0.0, 0.42), (0.25, 0.44), (0.27, 0.55), (0.25, 0.75), (0.24, 0.9), (0.2, 1.0), (0.09, 1.05), (0.0, 1.06)], 20)
    subsurf(torso, 1)
    paint(torso, SHIRT, ao=0.0, noise_amt=0.05,
          fn=lambda co, n: 0.82 if (co.z < 0.6 and math.sin(math.atan2(co.y, co.x) * 7) > 0.55 and co.z < 0.52) else (0.9 if abs(co.x) < 0.03 and co.y > 0 else None))
    shorts = lathe("s", [(0.0, 0.3), (0.27, 0.3), (0.285, 0.4), (0.27, 0.5), (0.0, 0.5)], 20)
    paint(shorts, SHORTS, ao=0.0)
    belt = tube("b", [(math.cos(a) * 0.272, math.sin(a) * 0.272, 0.5) for a in [i * math.pi / 12 for i in range(25)]], 0.022, 6, caps=False)
    paint(belt, ROPE, ao=0.0)
    knot = sphere("k", (0.06, 0.27, 0.5), 0.035)
    paint(knot, shade(ROPE, 0.9), ao=0.0)
    # заплатка
    patch = box("p", (-0.12, 0.235, 0.78), (0.1, 0.02, 0.09), (0.2, 0, 0.15), 0.01)
    paint(patch, hexcol("c9a050"), ao=0.0)
    join([torso, shorts, belt, knot, patch], "Body")

    # голова
    head_parts = []
    skull = sphere("h", (0, 0, 1.4), 0.33, (1.0, 0.96, 1.0), segs=28, rings=16)
    paint(skull, SKIN, ao=0.0, fn=lambda co, n: 1.0 if co.y > -0.1 else 0.95)
    head_parts.append(skull)
    for sx in (-1, 1):
        ear = sphere("e", (sx * 0.32, -0.02, 1.38), 0.075, (0.45, 0.9, 1.0))
        paint(ear, SKIN_D, ao=0.0)
        head_parts.append(ear)
        white = sphere("w", (sx * 0.12, 0.27, 1.42), 0.066, (1.0, 0.42, 1.2))
        paint(white, WHITE, ao=0.0, noise_amt=0)
        iris = sphere("i", (sx * 0.125, 0.29, 1.415), 0.042, (1.0, 0.4, 1.15))
        paint(iris, EYE, ao=0.0, noise_amt=0)
        pupil = sphere("pu", (sx * 0.127, 0.303, 1.414), 0.021, (1.0, 0.4, 1.0))
        paint(pupil, DARK, ao=0.0, noise_amt=0)
        glint = sphere("g", (sx * 0.11, 0.31, 1.437), 0.011, (1, 0.5, 1))
        paint(glint, WHITE, ao=0.0, noise_amt=0)
        lid = sphere("ld", (sx * 0.12, 0.262, 1.462), 0.07, (1.05, 0.45, 0.42))   # веко: живой, а не «кукольный» взгляд
        paint(lid, shade(SKIN, 0.96), ao=0.0, fn=lambda co, n: shade(SKIN_D, 0.85) if n.z < -0.3 else None)
        head_parts.append(lid)
        brow = tube("br", [(sx * 0.07, 0.3, 1.52), (sx * 0.13, 0.31, 1.535), (sx * 0.18, 0.29, 1.52)], 0.014, 6)
        paint(brow, shade(HAIR, 0.7), ao=0.0, mat="smooth")
        cheek = sphere("c", (sx * 0.2, 0.25, 1.31), 0.05, (1.0, 0.4, 0.7))
        paint(cheek, hexcol("f29a8a"), ao=0.0, noise_amt=0)
        head_parts += [white, iris, pupil, glint, brow, cheek]
    nose = sphere("n", (0, 0.33, 1.35), 0.035, (1.0, 0.8, 0.8))
    paint(nose, SKIN_D, ao=0.0)
    mouth = tube("m", [(-0.05, 0.31, 1.26), (0, 0.322, 1.245), (0.05, 0.31, 1.26)], 0.011, 6)
    paint(mouth, hexcol("a04a3a"), ao=0.0)
    head_parts += [nose, mouth]
    # волосы: шапка + пряди + чёлка, сплавленные в одну цельную причёску
    import random as _r
    from kit import remesh
    rr = _r.Random(5)
    hair = [sphere("hc", (0, -0.04, 1.47), 0.345, (1.03, 1.0, 0.86), segs=24, rings=14)]
    for i in range(22):
        th = rr.uniform(0, 2 * math.pi)
        ph = rr.uniform(0.2, 1.2)
        nx, ny, nz = math.sin(ph) * math.cos(th), math.sin(ph) * math.sin(th), math.cos(ph)
        if ny > 0.5 and nz < 0.65:
            continue
        base = (nx * 0.28, ny * 0.28 - 0.04, 1.48 + nz * 0.24)
        ln = rr.uniform(0.13, 0.21)
        tip = (base[0] + nx * ln, base[1] + ny * ln - 0.06, base[2] + nz * ln * 0.55 - 0.03)
        mid = ((base[0] + tip[0]) / 2 + nx * 0.03, (base[1] + tip[1]) / 2, (base[2] + tip[2]) / 2 + 0.035)
        hair.append(tube("tf", [base, mid, tip], [0.075, 0.045, 0.004], 10))
    for k in range(5):  # чёлка
        x = -0.18 + k * 0.09
        hair.append(tube("bg", [(x, 0.2, 1.64), (x * 1.1, 0.3, 1.6), (x * 1.2 + 0.03, 0.34, 1.51)], [0.06, 0.04, 0.004], 10))
    hm = join(hair, "Hair")
    remesh(hm, 0.014, 3)
    paint(hm, HAIR, ao=0.0, noise_amt=0.06, nscale=14,
          fn=lambda co, n: 0.82 if co.z < 1.45 else (1.1 if n.z > 0.6 else None), mat="hair")
    head_parts.append(hm)
    join(head_parts, "Head")

    # руки: плечо — локоть — запястье (кругов вдоль руки много, чтобы она гнулась в локте)
    for sx, nm in ((-1, "ArmL"), (1, "ArmR")):
        sh = (sx * 0.29, 0, 0.98)
        arm = tube("a", *rig.resample([sh, (sx * 0.33, 0.01, 0.8), (sx * 0.34, 0.03, 0.62)], [0.08, 0.07, 0.065]), 12)
        paint(arm, SKIN, ao=0.0)
        sleeve = tube("sl", [(sx * 0.27, 0, 1.0), (sx * 0.31, 0.0, 0.88)], [0.11, 0.1], 12)
        paint(sleeve, SHIRT, ao=0.0, fn=lambda co, n: 0.85 if co.z < 0.9 else None)
        hand = sphere("hd", (sx * 0.345, 0.04, 0.58), 0.075, (0.9, 1.0, 1.1))
        paint(hand, SKIN, ao=0.0)
        thumb = sphere("th", (sx * 0.31, 0.1, 0.6), 0.03, (1.0, 1.4, 1.0))
        paint(thumb, SKIN, ao=0.0)
        fingers = []
        for f in range(4):   # четыре коротких пальца, чуть согнутых
            fx = sx * (0.37 - f * 0.018)
            fy = 0.0 + f * 0.024
            fg = tube("fg", [(fx, fy, 0.54), (fx * 1.005, fy + 0.012, 0.495), (fx, fy + 0.03, 0.47)], [0.019, 0.016, 0.013], 6)
            paint(fg, SKIN, ao=0.0, fn=lambda co, n: SKIN_D if co.z < 0.49 else None)
            fingers.append(fg)
        join([arm, sleeve, hand, thumb] + fingers, nm)

    # ноги: бедро — колено — щиколотка, босые ступни
    for sx, nm in ((-1, "LegL"), (1, "LegR")):
        hip = (sx * 0.12, 0, 0.45)
        leg = tube("l", *rig.resample([hip, (sx * 0.12, 0.0, 0.25), (sx * 0.12, 0.0, 0.07)], [0.1, 0.085, 0.075]), 12)
        paint(leg, SKIN, ao=0.0)
        cuff = tube("cf", [(sx * 0.12, 0, 0.4), (sx * 0.12, 0, 0.28)], [0.115, 0.11], 12)
        paint(cuff, SHORTS, ao=0.0, fn=lambda co, n: 0.8 if co.z < 0.3 else None)
        foot = sphere("f", (sx * 0.12, 0.06, 0.045), 0.085, (0.9, 1.5, 0.55))
        paint(foot, SKIN, ao=0.0)
        toes = [sphere("to", (sx * 0.12 + k * 0.03 - 0.045, 0.17, 0.035), 0.022) for k in range(4)]
        for t in toes:
            paint(t, SKIN_D, ao=0.0)
        join([leg, cuff, foot] + toes, nm)
    rig.dress()   # скелет и веса


# ------------------------------------------------------------------ попугай Румба
RED = hexcol("e8443a")
YEL = hexcol("ffd23f")
BLUE = hexcol("2f6fe0")


def parrot():
    body = lathe("pb", [(0.0, 0.05), (0.09, 0.08), (0.135, 0.18), (0.13, 0.3), (0.1, 0.4), (0.0, 0.45)], 18, rot=(0.3, 0, 0))
    subsurf(body, 1)
    paint(body, RED, ao=0.0, noise_amt=0.05, fn=lambda co, n: 1.12 if co.y > 0.04 else None)
    tail = []
    for i, (c, ln) in enumerate(((RED, 0.5), (BLUE, 0.46), (YEL, 0.38))):
        t = leaf("tl", (0, -0.04 - i * 0.01, 0.1), (0, -0.45, -0.9), ln, 0.055 - i * 0.008, droop=0.05, fold=0.1)
        subsurf(t, 1)
        paint(t, c, ao=0.0, fn=lambda co, n: 0.85 if co.z < -0.15 else None)
        tail.append(t)
    feet = []
    for sx in (-1, 1):
        f = tube("ft", [(sx * 0.05, 0.02, 0.08), (sx * 0.05, 0.05, 0.0), (sx * 0.05, 0.1, -0.01)], 0.018, 6)
        paint(f, hexcol("5a5a5a"), ao=0.0)
        feet.append(f)
    b = join([body] + tail + feet, "Body")
    set_origin(b, (0, 0, 0))
    # голова
    hp = []
    skull = sphere("ph", (0, 0.07, 0.5), 0.12, segs=22, rings=14)
    paint(skull, RED, ao=0.0)
    hp.append(skull)
    for sx in (-1, 1):
        patch = sphere("pa", (sx * 0.075, 0.12, 0.51), 0.06, (0.5, 1.0, 1.0))
        paint(patch, hexcol("f7efe0"), ao=0.0, noise_amt=0, fn=lambda co, n: 0.9 if (int(co.z * 120) % 3 == 0) else None)
        eye = sphere("pe", (sx * 0.1, 0.14, 0.525), 0.026)
        paint(eye, hexcol("fff6c0"), ao=0.0, noise_amt=0)
        pup = sphere("pp", (sx * 0.112, 0.152, 0.527), 0.014)
        paint(pup, DARK, ao=0.0, noise_amt=0)
        hp += [patch, eye, pup]
    upper = tube("bk", [(0, 0.16, 0.53), (0, 0.24, 0.52), (0, 0.27, 0.47), (0, 0.24, 0.42)], [0.055, 0.045, 0.03, 0.008], 10)
    paint(upper, hexcol("3a2f2a"), ao=0.0, fn=lambda co, n: 1.5 if co.z > 0.5 else None)
    lower = sphere("lb", (0, 0.18, 0.455), 0.035, (0.8, 1.1, 0.7))
    paint(lower, hexcol("2a221e"), ao=0.0)
    hp += [upper, lower]
    h = join(hp, "Head")
    set_origin(h, (0, 0.04, 0.42))
    set_parent(h, b)
    # крылья: красный — жёлтый — синий
    for sx, nm in ((-1, "WingL"), (1, "WingR")):
        w = leaf("w", (sx * 0.12, 0.08, 0.36), (sx * 0.15, -0.55, -0.65), 0.38, 0.09, droop=0.08, fold=-0.2, up=(sx, 0, 0.3))
        subsurf(w, 1)

        def band(co, n, sx=sx):
            d = (0.36 - co.z)
            return RED if d < 0.07 else (YEL if d < 0.11 else BLUE)
        paint(w, RED, ao=0.0, fn=band)
        wing = join([w], nm)
        set_origin(wing, (sx * 0.12, 0.08, 0.36))
        set_parent(wing, b)


# ------------------------------------------------------------------ курица
def chicken():
    body = sphere("cb", (0, 0, 0.3), 0.2, (1.0, 1.25, 0.9), segs=22, rings=14)
    paint(body, hexcol("fbfbf4"), ao=0.0, noise_amt=0.04)
    tail = []
    for i in range(5):
        a = -0.6 + i * 0.3
        t = leaf("ct", (0, -0.18, 0.36), (math.sin(a) * 0.3, -0.5, 0.9), 0.2, 0.05, droop=0.4)
        paint(t, hexcol("f0efe6") if i % 2 else hexcol("e8e2d0"), ao=0.0)
        tail.append(t)
    wings = []
    for sx in (-1, 1):
        w = sphere("cw", (sx * 0.17, -0.02, 0.31), 0.12, (0.35, 1.0, 0.65))
        paint(w, hexcol("eeeadc"), ao=0.0, fn=lambda co, n: 0.9 if co.z < 0.27 else None)
        wings.append(w)
    legs = []
    for sx in (-1, 1):
        l = tube("cl", [(sx * 0.07, 0.02, 0.15), (sx * 0.07, 0.03, 0.02)], 0.016, 6)
        paint(l, hexcol("ffb02e"), ao=0.0)
        legs.append(l)
        for a in (-0.5, 0, 0.5):
            toe = tube("co", [(sx * 0.07, 0.03, 0.015), (sx * 0.07 + math.sin(a) * 0.06, 0.03 + math.cos(a) * 0.06, 0.008)], 0.01, 5)
            paint(toe, hexcol("ffa020"), ao=0.0)
            legs.append(toe)
    b = join([body] + tail + wings + legs, "Body")
    set_origin(b, (0, 0, 0))
    hp = [sphere("chh", (0, 0.17, 0.5), 0.1, segs=18, rings=12)]
    paint(hp[0], hexcol("fbfbf4"), ao=0.0)
    beak = cyl("cbk", (0, 0.26, 0.49), 0.03, 0.0, 0.08, (-math.pi / 2, 0, 0), 8)
    paint(beak, hexcol("ffb02e"), ao=0.0)
    hp.append(beak)
    for i in range(3):
        cm = sphere("cc", (0, 0.13 + i * 0.045, 0.6 - abs(i - 1) * 0.015), 0.035, (0.6, 1.0, 1.1))
        paint(cm, RED, ao=0.0)
        hp.append(cm)
    wat = sphere("cwa", (0, 0.23, 0.42), 0.028, (0.7, 0.8, 1.3))
    paint(wat, RED, ao=0.0)
    hp.append(wat)
    for sx in (-1, 1):
        e = sphere("ce", (sx * 0.07, 0.24, 0.52), 0.018)
        paint(e, DARK, ao=0.0, noise_amt=0)
        hp.append(e)
    h = join(hp, "Head")
    set_origin(h, (0, 0.15, 0.42))
    set_parent(h, b)


# ------------------------------------------------------------------ коза
def goat():
    fur = hexcol("f4efe4")
    patch = hexcol("b98a5a")
    body = sphere("gb", (0, 0, 0.56), 0.28, (0.9, 1.55, 0.88), segs=24, rings=14)
    subsurf(body, 1)
    paint(body, fur, ao=0.0, noise_amt=0.06,
          fn=lambda co, n: patch if (((co.x - 0.2) / 0.16) ** 2 + ((co.y - 0.03) / 0.16) ** 2 + ((co.z - 0.72) / 0.14) ** 2
                                     + 0.35 * noise.noise(co * 9.0)) < 1.0 else None)
    parts = [body]
    tail = tube("gt", [(0, -0.42, 0.72), (0, -0.5, 0.82)], [0.05, 0.02], 8)
    paint(tail, fur, ao=0.0)
    parts.append(tail)
    for x in (-0.13, 0.13):
        for y in (-0.27, 0.27):
            leg = tube("gl", [(x, y, 0.45), (x, y, 0.22), (x, y + 0.01, 0.05)], [0.075, 0.058, 0.052], 10)
            paint(leg, fur, ao=0.0)
            hoof = cyl("gh", (x, y + 0.01, 0.0), 0.05, 0.045, 0.06, segs=10)
            paint(hoof, hexcol("5a4636"), ao=0.0)
            parts += [leg, hoof]
    b = join(parts, "Body")
    set_origin(b, (0, 0, 0))
    hp = []
    neck = tube("gn", [(0, 0.3, 0.72), (0, 0.42, 0.85)], [0.12, 0.1], 12)
    paint(neck, fur, ao=0.0)
    skull = sphere("gs", (0, 0.48, 0.92), 0.13, (0.9, 1.0, 1.0))
    paint(skull, fur, ao=0.0)
    snout = sphere("gsn", (0, 0.62, 0.86), 0.09, (0.85, 1.2, 0.85))
    paint(snout, hexcol("f2e6d6"), ao=0.0)
    nose = sphere("gno", (0, 0.72, 0.87), 0.035, (1.2, 0.6, 0.8))
    paint(nose, hexcol("e8a8a0"), ao=0.0)
    beard = cyl("gbd", (0, 0.62, 0.62), 0.0, 0.05, 0.2, (math.pi, 0, 0), 8)
    beard.location = (0, 0.62, 0.82)
    paint(beard, shade(fur, 0.9), ao=0.0)
    hp += [neck, skull, snout, nose, beard]
    for sx in (-1, 1):
        horn = tube("gho", [(sx * 0.06, 0.48, 1.02), (sx * 0.1, 0.42, 1.12), (sx * 0.14, 0.34, 1.14), (sx * 0.16, 0.3, 1.08)],
                    [0.035, 0.03, 0.022, 0.008], 8)
        paint(horn, hexcol("9a8a72"), ao=0.0, fn=lambda co, n: 0.85 if int(co.z * 60) % 2 == 0 else None)
        ear = leaf("ge", (sx * 0.12, 0.47, 0.95), (sx * 1.0, -0.1, -0.3), 0.14, 0.04, droop=0.1)
        paint(ear, fur, ao=0.0)
        eye = sphere("gey", (sx * 0.1, 0.56, 0.96), 0.022)
        paint(eye, DARK, ao=0.0, noise_amt=0)
        hp += [horn, ear, eye]
    h = join(hp, "Head")
    set_origin(h, (0, 0.33, 0.78))
    set_parent(h, b)


# ------------------------------------------------------------------ краб
def crab():
    col = hexcol("ff5a3a")
    shell = sphere("kb", (0, 0, 0.1), 0.15, (1.35, 1.0, 0.55), segs=20, rings=12)
    paint(shell, col, ao=0.0, fn=lambda co, n: 1.15 if co.z > 0.14 else None)
    parts = [shell]
    for sx in (-1, 1):
        arm = tube("ka", [(sx * 0.17, 0.05, 0.1), (sx * 0.24, 0.12, 0.14)], 0.03, 8)
        claw = sphere("kc", (sx * 0.25, 0.18, 0.15), 0.06, (0.9, 1.3, 0.8))
        pincer = cyl("kp", (sx * 0.25, 0.22, 0.15), 0.03, 0.0, 0.08, (-math.pi / 2, 0, 0), 8)
        stalk = tube("ks", [(sx * 0.05, 0.1, 0.14), (sx * 0.05, 0.12, 0.21)], 0.012, 6)
        eye = sphere("ke", (sx * 0.05, 0.12, 0.22), 0.022)
        for o in (arm, claw, pincer, stalk):
            paint(o, shade(col, 1.05), ao=0.0)
        paint(eye, DARK, ao=0.0)
        parts += [arm, claw, pincer, stalk, eye]
        for k in range(3):
            y = -0.05 + k * 0.06
            l = tube("kl", [(sx * 0.17, y, 0.08), (sx * 0.26, y - 0.02, 0.1), (sx * 0.31, y - 0.03, 0.0)], 0.014, 6)
            paint(l, shade(col, 0.85), ao=0.0)
            parts.append(l)
    join(parts, "Crab")


BUILDERS = {"player": player, "parrot": parrot, "chicken": chicken, "goat": goat, "crab": crab}
