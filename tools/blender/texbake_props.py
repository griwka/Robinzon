"""Камни и мелочь на текстурах (v1.0.9): валуны, галька, скалы, обвалы, базальт, обсидиан, руда, лёд и снег,
ракушки, плавник, коряги, глина и песок, кучи железа, ящики и сундуки, вещи на столах и все инструменты в руке.

Конвейер тот же, что у построек (texbake.py: развёртка → растеризация → программы раскраски в каждом пикселе →
мелкая деталь → поля островов), но вид поверхности решается ПО ПИКСЕЛЮ: если программа раскраски вернула свой
цвет (мох на камне, снег на льду, латунные оковки сундука), у этого цвета может быть свой вид (COLORS) — так
у одного объекта бывают и дерево, и латунь, и мох.

Свои виды поверхности (detail_props), остальное — texbake.detail_build (wood, bark, metal, rope, canvas…):
  rock     — валун: крапинки минералов, редкие трещины, лишайник пятнами на верхних гранях;
  cliff    — скала: то же + слои породы волнистыми линиями, у каждого слоя свой тон;
  basalt   — базальт: мелкое зерно, пузырьки-поры, поперечные трещины-отдельности;
  obsidian — вулканическое стекло: раковистый излом (изолинии), фиолетовый отлив, блики;
  ore      — руда: тёмная порода, ржавые прожилки с ореолом, золотистые блёстки;
  flint    — кремень: раковистые волны и меловая корка пятнами;
  ice      — лёд: глубина, трещины с тенью, пузырьки, иней сверху;  snow — снег: мягкие ямки и голубые тени;
  moss     — мох комочками;  sand — песок: зёрна и крупинки ракушек;  mud — глина в яме: трещины усыхания;
  shell    — ракушка: тонкие кольца роста, перламутр;  driftwood — плавник: выбеленное дерево, продольные трещины;
  leather  — кожа ремешков: зерно и заломы;  cork — пробка: поры;  paper — бумага: волокна, обрез пачек;
  brass    — латунь: шлифовка, тёмный налёт, редкая зелень;  edge — заточенная кромка: шлифовка вдоль;
  forged   — кованое железо: вмятины от молота;  enamel — крашеный металл: мазки, сколы до серого металла;
  coal     — угли: светящиеся трещинки и пепел;  ember — жар;  glass — оплавленный песок (фульгурит);
  rubber   — резина, оплётка.

Узоры — только шумом и ячейками (cells): никаких полос «через одну» и sin-пятен (в текстуре стали бы «зеброй»).
Всё мельче ~2 пикселей атласа плавно гаснет (px — метров в пикселе), поэтому вдали не рябит.
"""
import math
import os

import bpy
import numpy as np
from mathutils import Vector, noise

import kit
import texbake as tb
from texbake import _an, _band, _mixc, pn, smooth01

# ============================================================ какие модели и как
# вид по умолчанию для программ без mat= (если цвет не нашёлся в COLORS)
MODEL_KIND = {
    "rock_a": "rock", "rock_b": "rock", "rock_c": "rock", "pebble_a": "rock", "pebble_b": "rock",
    "cliff_a": "cliff", "cliff_b": "cliff", "rockfall": "rock",
    "basalt_a": "basalt", "basalt_b": "basalt", "obsidian_rock": "obsidian", "ore_vein": "ore",
    "ice_block": "ice", "ice_wall_a": "ice", "ice_wall_b": "ice", "ice_floe_a": "ice", "ice_floe_b": "ice",
    "ice_shelf": "ice", "ice_hole": "ice",
    "shell": "shell", "driftwood": "driftwood",
    "clay_pit": "mud", "sand_pit": "sand", "fulgurite": "glass", "scrap_pile": "rust",
}

# вид по цвету (программы или того, что вернула её fn) — для всех моделей пачки
COLORS = {
    # камень
    "a7abb0": "rock", "bdb3a3": "rock", "8a8690": "rock", "9a969e": "rock", "8f8a80": "rock",
    "6fb04a": "moss", "6f9a48": "moss",
    "4a4648": "basalt", "6a6466": "basalt", "2a2438": "obsidian", "8a6ab8": "obsidian", "4a3a6a": "obsidian",
    "5e5658": "ore", "45404a": "stone", "5e5862": "stone",
    # лёд и снег
    "9fd6ee": "ice", "dff3fb": "ice", "5fa8d2": "ice", "f7fbff": "snow", "d3e3f4": "snow",
    # берег
    "f6c7c0": "shell", "c8a985": "driftwood",
    "f0dca8": "sand", "e8d098": "sand", "b8603a": "mud", "c87048": "mud", "3a3632": "soil",
    "d9e8e0": "glass", "9fd8c0": "glass",
    # металл, угли
    "c9a050": "brass", "e8c050": "brass", "d9a84a": "brass", "d2a548": "brass",
    "9aa0a6": "iron", "c9d2dc": "metal", "8f979e": "metal", "6b6f75": "metal", "4a4d52": "metal", "dfe4e8": "metal",
    "c0392b": "enamel", "7a5a3a": "rust", "2a2a2a": "rubber",
    "3a2a22": "coal", "ff7a2a": "ember",
    # инструменты (models_tools.py)
    "9a6a3c": "wood", "6e4526": "wood", "6b3a22": "leather", "d2ad72": "rope", "4a2a1a": "leather",
    "aeb8c2": "metal", "eef3f7": "edge", "5d6873": "forged", "c9d3dc": "edge", "6e7a86": "forged",
    "7a8088": "flint", "aab1b8": "flint", "626a73": "flint", "b7bcc2": "flint",
    "5fb0e8": "enamel", "3f86c0": "enamel", "f2c24a": "enamel", "e8443a": "enamel", "c8403a": "canvas",
    "d7b46a": "bamboo", "a8823e": "bamboo", "b08a42": "bamboo", "c9cf5a": "bamboo", "8c9a3a": "bamboo",
    "c89a62": "cork", "f4f1ea": "plain", "f2ead8": "canvas", "f4f4f4": "clean",
    "4a6a8a": "rubber", "2a3a4a": "rubber", "d8403a": "canvas",
    # бумага, кожа переплёта
    "efe4c8": "paper", "f6ecd2": "paper", "efe2c0": "paper", "c87a52": "rope",
    "6a2e22": "leather", "5a2418": "leather", "4a3424": "wood", "3a5a7a": "canvas",
}

# своё для отдельных моделей (цвет → вид; "*" — вместо вида из mat=, например stone → rock)
MODEL_COLORS = {
    "rockfall": {"stone": "rock"},
    "tool_ice_drill": {"c9a050": "wood", "a8823e": "wood"},
    "tool_fishing_rod": {"c8403a": "enamel", "f2ead8": "plain"},
    "tool_net": {"c8403a": "canvas"},
    "ice_chest": {"9aa0a6": "iron"},
    "keepers_book": {"c0392b": "canvas", "f4f4ee": "plain", "2a2a3a": "clean", "4a3a2a": "clean"},
    "letters_box": {"5a4a8a": "clean"},
    "ice_hole": {"1f4a6a": "water", "3f7a9a": "water"},
    "penguin_feeder": {"6b4a32": "bark", "8fb0c8": "fish", "e8f0f8": "fish", "8a9aa8": "metal", "d6b07a": "painted", "3a5a7a": "clean"},
    "sextant": {"dff3fb": "clean"}, "sextant_broken": {"dff3fb": "clean", "8aa0aa": "clean"},
}


def _near(h):
    """Цвет, которого нет в COLORS, — вид ближайшего известного «оттенка» (kit.shade темнее/светлее того же цвета):
    shade(IRON, 0.85) — тоже кованое железо."""
    c = np.array(kit.hexcol(h))
    best, kind = 0.035, None
    for kh, kv in COLORS.items():
        kc = np.array(kit.hexcol(kh))
        t = float(c @ kc / max(kc @ kc, 1e-6))
        if not 0.55 < t < 1.3:
            continue
        e = float(np.abs(c - kc * t).max())
        if e < best:
            best, kind = e, kv
    return kind

PROPS = list(MODEL_KIND) + [
    "supply_crate", "chest", "ice_chest", "letters_box", "keepers_book", "woodpile", "brazier",
    "sextant", "sextant_broken", "lantern_mark", "bridge_marker", "penguin_feeder",
    "tool_stone_axe", "tool_iron_axe", "tool_machete", "tool_iron_machete", "tool_pickaxe", "tool_iron_pickaxe",
    "tool_shovel", "tool_watering_can", "tool_net", "tool_fishing_rod", "tool_ice_pick", "tool_ice_drill",
]

# атлас крупнее, чем «мелочь» (по умолчанию — по площади, 256…512): скалы, обвал, базальт, ледяные стены видны вблизи
TEX_SIZE = {"cliff_a": 1024, "cliff_b": 1024, "rockfall": 1024, "basalt_a": 1024, "basalt_b": 1024,
            "ice_wall_a": 1024, "ice_wall_b": 1024, "ice_shelf": 1024}
# инструменты в руке видны крупно — всегда 512
for _n in PROPS:
    if _n.startswith("tool_"):
        TEX_SIZE[_n] = 512

MY_KINDS = ("rock", "cliff", "basalt", "obsidian", "ore", "flint", "ice", "snow", "moss", "sand", "mud", "shell",
            "driftwood", "leather", "cork", "paper", "brass", "edge", "forged", "enamel", "coal", "ember", "glass",
            "rubber", "water", "fish")


def _hex(c):
    return "".join("%02x" % int(round(min(1.0, max(0.0, v)) * 255)) for v in c[:3])


# ============================================================ ячеистый шум (Ворли)
def _hash(ix, iy, iz, s):
    h = (ix * 73856093) ^ (iy * 19349663) ^ (iz * 83492791) ^ (s * 2654435761)
    h = h & 0xFFFFFFFF
    h = ((h ^ (h >> 16)) * 0x45D9F3B) & 0xFFFFFFFF
    h = ((h ^ (h >> 16)) * 0x45D9F3B) & 0xFFFFFFFF
    return h ^ (h >> 16)


def cells(p, scale, seed=0):
    """Ячейки вокруг случайных точек: (F1, F2 — расстояния до двух ближайших точек, в долях ячейки; rnd — случайное
    число 0..1 ближайшей ячейки). F2 − F1 ≈ 0 — граница ячеек (трещины усыхания), F1 мало — центр (пузырёк, вмятина)."""
    q = np.asarray(p, np.float64) / scale
    out1 = np.empty(len(q))
    out2 = np.empty(len(q))
    outr = np.empty(len(q))
    for s in range(0, len(q), 200_000):
        qq = q[s:s + 200_000]
        i = np.floor(qq).astype(np.int64)
        b1 = np.full(len(qq), 9.0)
        b2 = np.full(len(qq), 9.0)
        br = np.zeros(len(qq))
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                for dz in (-1, 0, 1):
                    cx, cy, cz = i[:, 0] + dx, i[:, 1] + dy, i[:, 2] + dz
                    h = _hash(cx, cy, cz, seed)
                    jx = (h & 1023) / 1023.0
                    jy = ((h >> 10) & 1023) / 1023.0
                    jz = ((h >> 20) & 1023) / 1023.0
                    d = (cx + jx - qq[:, 0]) ** 2 + (cy + jy - qq[:, 1]) ** 2 + (cz + jz - qq[:, 2]) ** 2
                    r = (_hash(cx, cy, cz, seed + 7) & 4095) / 4095.0
                    closer = d < b1
                    b2 = np.where(closer, b1, np.minimum(b2, d))
                    br = np.where(closer, r, br)
                    b1 = np.where(closer, d, b1)
        out1[s:s + 200_000] = np.sqrt(b1)
        out2[s:s + 200_000] = np.sqrt(b2)
        outr[s:s + 200_000] = br
    return out1, out2, outr


def _iso(v, w):
    """Тонкая линия там, где шум v проходит через ноль (ширина w в единицах шума) — извилистые трещины и прожилки."""
    return 1.0 - smooth01(w * 0.5, w, np.abs(v))


# ============================================================ цвет и вид — по пикселю
def eval_base(pid, P, N, vc):
    """Как texbake.eval_programs, но ещё возвращает «исходный» цвет каждого пикселя (тот, что вернула fn, или цвет
    программы) — по нему решаем вид поверхности (мох на камне, снег на льду, латунные оковки)."""
    col = vc.astype(np.float64).copy()
    base = col.copy()
    for p in np.unique(pid):
        prog = kit.PAINTS[p] if 0 < p < len(kit.PAINTS) else None
        if prog is None:
            continue
        idx = np.nonzero(pid == p)[0]
        b = np.tile(np.array(prog["color"][:3], np.float64), (len(idx), 1))
        fn = prog["fn"]
        noise_amt, nscale, seed = prog["noise_amt"], prog["nscale"], prog["seed"]
        off = Vector((seed * 13.1, seed * 7.7, seed * 3.3))
        nz = np.zeros(len(idx))
        mult = np.ones(len(idx))
        Pi, Ni = P[idx], N[idx]
        for j in range(len(idx)):
            co = Vector(Pi[j])
            if fn is not None:
                r = fn(co, Vector(Ni[j]))
                if isinstance(r, tuple):
                    b[j] = r[:3]
                elif r is not None:
                    mult[j] = r
            if noise_amt:
                nz[j] = noise.noise((co + off) * nscale)
        base[idx] = b
        sh = tb._shade(b, mult)
        h = np.maximum(0.0, Pi[:, 2] - prog["ground"])
        k = 1.0 - prog["ao"] * (1.0 - np.minimum(1.0, h / prog["ao_h"])) ** 2
        k *= 1.0 - 0.18 * np.maximum(0.0, -Ni[:, 2])
        k *= 1.0 + prog["top"] * np.maximum(0.0, Ni[:, 2])
        k *= 1.0 + noise_amt * nz
        col[idx] = np.clip(sh * k[:, None], 0.0, 1.0)
    return col, base


def kinds_props(name, pid, base):
    """Вид поверхности каждого пикселя. Порядок: цвет, который вернула fn (если он в COLORS/MODEL_COLORS) →
    mat= программы (с заменой из MODEL_COLORS, например stone → rock) → цвет программы → MODEL_KIND → угадать по цвету."""
    own = MODEL_COLORS.get(name, {})
    kind = np.empty(len(pid), object)
    key = (np.clip(np.round(base * 255), 0, 255).astype(np.int64) * np.array([65536, 256, 1])).sum(axis=1)
    for p in np.unique(pid):
        sel_p = pid == p
        prog = kit.PAINTS[p] if 0 < p < len(kit.PAINTS) else None
        if prog is None:
            kind[sel_p] = MODEL_KIND.get(name, "plain")
            continue
        ph = _hex(prog["color"])
        m = prog["mat"]
        if m is not None:
            pk = own.get(m, m)
        else:
            pk = own.get(ph) or COLORS.get(ph) or MODEL_KIND.get(name) or _near(ph)
            if pk is None:
                pk = "clean" if prog["noise_amt"] == 0 else tb.guess_build(prog["color"])
        for kv in np.unique(key[sel_p]):
            h = "%06x" % kv
            s = sel_p & (key == kv)
            if h != ph and (h in own or h in COLORS):
                kind[s] = own.get(h) or COLORS[h]
            else:
                kind[s] = pk
    return kind


# ============================================================ мелкая деталь
def detail_props(kind, col, P, N, U, uok, px, seed=0):
    off = np.array([seed * 3.7, seed * 1.3, seed * 5.1])
    k = np.ones(len(col))
    col = col.copy()

    def bl(period):
        return float(smooth01(1.8, 3.6, np.array([period / px]))[0])

    def sel(*names):
        m = np.zeros(len(kind), bool)
        for nm in names:
            m |= kind == nm
        return m

    # ---------------- валуны и скалы: крапинки минералов, трещины, лишайник; у скал — слои породы
    m = sel("rock", "cliff")
    if m.any():
        p, n, c = P[m], N[m], col[m]
        # крупные тёплые и холодные пятна тона + чёткие «мазки» потемнее (как рисованная фактура, но резкие)
        t1 = pn(p / 0.5 + off)
        kk = 1 + 0.1 * t1 + 0.06 * pn(p / 0.15 + off + 1.0)
        c = _mixc(c, (0.74, 0.66, 0.56), 0.25 * smooth01(0.1, 0.5, t1))
        c = _mixc(c, (0.58, 0.62, 0.68), 0.2 * smooth01(-0.1, -0.5, t1))
        blot = smooth01(0.22, 0.28, pn(p / 0.11 + off + 14.0) + 0.3 * pn(p / 0.035 + off + 15.0) * bl(0.035))
        kk *= 1 - 0.1 * blot
        gs = max(0.02, 2.6 * px)
        dark = smooth01(0.38, 0.46, pn(p / gs + off + 2.0)) * bl(gs)
        light = smooth01(0.42, 0.5, pn(p / gs + off + 3.0)) * bl(gs)
        kk *= (1 - 0.24 * dark) * (1 + 0.14 * light)
        fg = max(0.005, 1.6 * px)
        kk *= 1 + 0.05 * pn(p / fg + off + 4.0) * bl(fg)
        cr = pn(p / 0.32 + off + 5.0) + 0.3 * pn(p / 0.09 + off + 6.0) * bl(0.09)
        w = min(0.08, max(0.028, 1.4 * px / 0.32))
        mask = smooth01(0.0, 0.3, pn(p / 0.8 + off + 7.0))
        crack = _iso(cr, w) * mask
        lip = (1 - smooth01(w, 3 * w, np.abs(cr))) * (1 - crack) * mask
        kk *= (1 - 0.4 * crack) * (1 + 0.08 * lip)
        cl = kind[m] == "cliff"
        if cl.any():
            # слои разной толщины: фаза слоя плывёт по шуму вдоль высоты, линии местами обрываются
            f = p[:, 2] / 0.3 + 0.9 * pn(p * np.array([0.7, 0.7, 1.6]) + off + 8.0)                 + 0.08 * pn(p / 0.12 + off + 9.0) * bl(0.12)
            li = np.floor(f)
            tone = np.sin(li * 12.9898 + seed) * 43758.5453
            tone = tone - np.floor(tone)
            bed = _band(f, max(0.03, 0.7 * px / 0.3), 0.5 * px / 0.3) * smooth01(-0.05, 0.25, pn(p / 0.45 + off + 10.0))
            kk = np.where(cl, kk * (0.93 + 0.14 * tone) * (1 - 0.18 * bed), kk)
            c = np.where(cl[:, None], _mixc(c, (0.80, 0.68, 0.52), 0.18 * smooth01(0.6, 0.9, tone)), c)
        up = smooth01(-0.1, 0.5, n[:, 2])
        lv = pn(p / 0.07 + off + 11.0) + 0.35 * pn(p / 0.022 + off + 12.0) * bl(0.022)
        lich = smooth01(0.44, 0.5, lv) * smooth01(0.25, 0.7, n[:, 2])
        c = _mixc(c, (0.78, 0.80, 0.62), 0.5 * lich)
        dots = smooth01(0.58, 0.63, pn(p / 0.045 + off + 13.0)) * up * bl(0.045) * (1 - lich)
        c = _mixc(c, (0.90, 0.64, 0.33), 0.6 * dots)
        col[m] = c
        k[m] = kk

    # ---------------- мох комочками
    m = sel("moss")
    if m.any():
        p = P[m]
        gs = max(0.012, 2.5 * px)
        a = pn(p / gs + off + 20.0)
        kk = (1 + 0.12 * smooth01(0.1, 0.5, a)) * (1 - 0.16 * (1 - smooth01(-0.5, -0.2, a))) * bl(gs) + (1 - bl(gs))
        kk *= 1 + 0.07 * pn(p / 0.08 + off + 21.0)
        # не кислотный: ярко-зелёный цвет из моделей уводим к тёплому оливковому, местами — к жёлто-зелёному
        c = col[m] * 0.4 + np.array([0.40, 0.55, 0.26]) * 0.6
        col[m] = _mixc(c, (0.66, 0.70, 0.32), 0.35 * smooth01(0.25, 0.6, pn(p / 0.07 + off + 22.0)))
        k[m] = kk

    # ---------------- базальт: мелкое зерно, поры, поперечные трещины
    m = sel("basalt")
    if m.any():
        p, n = P[m], N[m]
        kk = 1 + 0.06 * pn(p / 0.4 + off) + 0.05 * pn(p / max(0.006, 1.8 * px) + off + 1.0) * bl(0.006)
        f1, f2, r = cells(p, max(0.035, 4.5 * px), seed + 3)
        pore = (1 - smooth01(0.13, 0.2, f1)) * (r > 0.55) * bl(0.035)
        kk *= 1 - 0.35 * pore
        side = 1 - smooth01(0.5, 0.8, np.abs(n[:, 2]))
        j = (p[:, 2] + 0.12 * pn(p * np.array([3.0, 3.0, 0.5]) + off + 2.0)) / 0.5
        joint = _band(j, max(0.02, 0.8 * px / 0.5), 0.5 * px / 0.5) * smooth01(0.0, 0.3, pn(p / 0.35 + off + 3.0)) * side
        kk *= 1 - 0.35 * joint
        col[m] = _mixc(col[m], (0.47, 0.40, 0.36), 0.25 * smooth01(0.2, 0.6, pn(p / 0.3 + off + 4.0)))
        k[m] = kk

    # ---------------- обсидиан: раковистый излом, фиолетовый отлив, блики
    m = sel("obsidian")
    if m.any():
        p, n = P[m], N[m]
        v = pn(p / 0.3 + off + 5.0) * 2.2 + pn(p / 0.09 + off + 6.0) * 0.4
        ring = _band(v, max(0.05, 0.8 * px / 0.08), 0.5 * px / 0.08) * smooth01(-0.1, 0.3, pn(p / 0.25 + off + 8.0))
        kk = 1 + 0.35 * ring * bl(0.08)
        sh = smooth01(0.2, 0.9, (n @ np.array([0.35, -0.45, 0.82])))
        c = _mixc(col[m], (0.52, 0.42, 0.74), 0.32 * sh)
        glint = smooth01(0.62, 0.66, pn(p / 0.06 + off + 7.0)) * bl(0.06)
        c = _mixc(c, (0.86, 0.82, 0.96), 0.7 * glint)
        col[m] = c
        k[m] = kk

    # ---------------- руда: тёмная порода, ржавые прожилки с ореолом, блёстки
    m = sel("ore")
    if m.any():
        p = P[m]
        c = col[m]
        kk = 1 + 0.07 * pn(p / 0.35 + off) + 0.06 * pn(p / max(0.008, 2 * px) + off + 1.0) * bl(0.008)
        # две-три широкие жилы (а не сеть, как у лавы): толщина плывёт, по краю — ржавый ореол
        v1 = pn(p / 0.55 + off + 2.0) + 0.25 * pn(p / 0.14 + off + 3.0)
        v2 = pn(p / 0.3 + off + 4.0) + 0.2 * pn(p / 0.08 + off + 5.0)
        th = 0.75 + 0.5 * smooth01(-0.4, 0.4, pn(p / 0.2 + off + 6.0))
        w1 = max(0.07, 1.2 * px / 0.55) * th
        w2 = max(0.05, 1.0 * px / 0.3) * th
        vein = np.maximum(_iso(v1, w1), _iso(v2, w2) * smooth01(0.1, 0.4, pn(p / 0.6 + off + 9.0)))
        halo = (1 - smooth01(w1, 3.5 * w1, np.abs(v1))) * (1 - vein)
        c = _mixc(c, (0.52, 0.38, 0.32), 0.5 * halo)
        vc_ = _mixc(np.tile([0.62, 0.34, 0.22], (len(p), 1)), (0.86, 0.56, 0.32), smooth01(-0.3, 0.5, pn(p / 0.05 + off + 7.0)))
        c = c * (1 - vein[:, None]) + vc_ * vein[:, None]
        f1, f2, r = cells(p, max(0.03, 4 * px), seed + 5)
        glint = (1 - smooth01(0.1, 0.17, f1)) * (r > 0.7) * bl(0.03)
        c = _mixc(c, (1.0, 0.86, 0.45), 0.9 * glint)
        col[m] = c
        k[m] = kk

    # ---------------- кремень: раковистые волны, меловая корка пятнами
    m = sel("flint")
    if m.any():
        p = P[m]
        v = pn(p / 0.06 + off + 8.0) * 3.0 + pn(p / 0.02 + off + 9.0) * 0.4
        ring = _band(v, max(0.06, 0.8 * px / 0.015), 0.5 * px / 0.015) * bl(0.015) * smooth01(0.0, 0.35, pn(p / 0.05 + off + 12.0))
        kk = (1 + 0.1 * ring) * (1 + 0.08 * pn(p / 0.04 + off + 10.0))
        cortex = smooth01(0.42, 0.48, pn(p / 0.05 + off + 11.0))
        col[m] = _mixc(col[m], (0.84, 0.81, 0.73), 0.75 * cortex)
        k[m] = kk * (1 - 0.1 * cortex * (1 - smooth01(0.48, 0.55, pn(p / 0.05 + off + 11.0))))

    # ---------------- лёд: глубина, трещины с тенью, пузырьки, иней сверху
    m = sel("ice")
    if m.any():
        p, n = P[m], N[m]
        c = col[m]
        # гранёный лёд: у каждой «грани» (ячейки) свой тон, по стыкам — светлые плоскости раскола; глубина — синее
        g1, g2, gr = cells(p, 0.32, seed + 21)
        c = _mixc(c, (0.34, 0.60, 0.82), 0.3 * gr)
        c = _mixc(c, (0.86, 0.95, 1.0), 0.35 * (1 - smooth01(0.0, max(0.04, 1.5 * px / 0.32), g2 - g1)))
        deep = smooth01(-0.1, 0.55, pn(p / 0.45 + off + 12.0))
        c = _mixc(c, (0.28, 0.55, 0.80), 0.45 * deep)
        cr = pn(p / 0.34 + off + 13.0) + 0.3 * pn(p / 0.1 + off + 14.0) * bl(0.1)
        w = min(0.08, max(0.03, 1.5 * px / 0.34))
        mask = smooth01(-0.2, 0.2, pn(p / 0.9 + off + 15.0))
        crack = _iso(cr, w) * mask
        shadow = (1 - smooth01(w, 3.5 * w, np.abs(cr))) * (1 - crack) * mask
        c = _mixc(c, (0.45, 0.70, 0.86), 0.45 * shadow)
        c = _mixc(c, (0.94, 0.98, 1.0), 0.9 * crack)
        f1, f2, r = cells(p, max(0.05, 5 * px), seed + 9)
        rad = 0.1 + 0.12 * r
        bub = (1 - smooth01(rad - 0.04, rad, f1)) * (r > 0.45) * bl(0.04)
        rim = (1 - smooth01(rad, rad + 0.05, f1)) * (r > 0.45) * (1 - bub) * bl(0.04)
        c = _mixc(c, (0.97, 0.99, 1.0), 0.7 * bub)
        c = _mixc(c, (0.42, 0.68, 0.86), 0.35 * rim)
        frost = smooth01(0.35, 0.85, n[:, 2]) * smooth01(-0.2, 0.3, pn(p / 0.12 + off + 16.0))
        c = _mixc(c, (0.92, 0.97, 1.0), 0.35 * frost)
        col[m] = c
        k[m] = 1 + 0.04 * pn(p / max(0.006, 2 * px) + off + 17.0) * bl(0.006)

    # ---------------- снег: мягкие ямки, голубые тени
    m = sel("snow")
    if m.any():
        p = P[m]
        # ямки и бугорки наметённого снега: голубая тень в ямках, тёплый свет на гребнях
        hol = smooth01(0.0, 0.5, pn(p / 0.16 + off + 18.0) + 0.3 * pn(p / 0.05 + off + 60.0) * bl(0.05))
        col[m] = _mixc(col[m], (0.74, 0.84, 0.96), 0.55 * hol)
        col[m] = _mixc(col[m], (1.0, 0.98, 0.94), 0.4 * smooth01(0.1, 0.5, -pn(p / 0.16 + off + 18.0)))
        k[m] = 1 + 0.025 * pn(p / max(0.008, 2 * px) + off + 19.0) * bl(0.008)

    # ---------------- песок: зёрна, тёмные крупинки, обломки ракушек
    m = sel("sand")
    if m.any():
        p = P[m]
        gs = max(0.005, 1.6 * px)
        kk = (1 + 0.08 * pn(p / gs + off + 23.0) * bl(gs)) * (1 + 0.05 * pn(p / 0.15 + off + 24.0))
        f1, f2, r = cells(p, max(0.025, 3.5 * px), seed + 11)
        speck = (1 - smooth01(0.12, 0.19, f1)) * bl(0.025)
        c = _mixc(col[m], (0.55, 0.47, 0.38), 0.6 * speck * (r < 0.25))
        c = _mixc(c, (0.98, 0.86, 0.82), 0.7 * speck * (r > 0.9))
        col[m] = c
        k[m] = kk

    # ---------------- глина в яме: влажная, сверху — трещины усыхания
    m = sel("mud")
    if m.any():
        p, n = P[m], N[m]
        kk = (1 + 0.07 * pn(p / 0.12 + off + 25.0)) * (1 + 0.05 * pn(p / max(0.005, 2 * px) + off + 26.0) * bl(0.005))
        f1, f2, r = cells(p * np.array([1.0, 1.0, 0.3]), 0.09, seed + 13)
        edge = 1 - smooth01(0.02, max(0.05, 1.2 * px / 0.09), f2 - f1)
        top = smooth01(0.5, 0.85, n[:, 2])
        kk *= 1 - 0.38 * edge * top
        kk *= 1 + 0.06 * (r - 0.5) * top
        col[m] = _mixc(col[m], (0.86, 0.55, 0.38), 0.18 * top * smooth01(0.1, 0.25, f2 - f1))
        k[m] = kk

    # ---------------- ракушка: тонкие кольца роста, перламутр изнутри
    m = sel("shell")
    if m.any():
        p, n = P[m], N[m]
        d = np.hypot(p[:, 0], p[:, 1] + 0.02)
        g = (d + 0.006 * pn(p / 0.03 + off + 27.0)) / 0.017
        grow = _band(g, max(0.05, 0.5 * px / 0.017), 0.5 * px / 0.017) * bl(0.017)
        grow *= smooth01(-0.2, 0.3, pn(p / 0.04 + off + 26.0))          # кольца роста — не сплошь, обрывками
        kk = 1 - 0.07 * grow
        c = col[m]
        under = smooth01(0.0, -0.5, n[:, 2])
        hue = 0.5 + 0.5 * pn(p / 0.03 + off + 28.0)
        nacre = _mixc(np.tile([0.92, 0.86, 0.98], (len(p), 1)), (0.86, 0.96, 0.94), hue)
        c = c * (1 - 0.7 * under[:, None]) + nacre * (0.7 * under[:, None])
        col[m] = c
        k[m] = kk * (1 + 0.03 * pn(p / max(0.003, 1.5 * px) + off + 29.0) * bl(0.003))

    # ---------------- плавник: выбеленное солью дерево, волокна и длинные трещины
    m = sel("driftwood")
    if m.any():
        u, p = U[m], P[m]
        line, fr = tb._wood_rings(u, px, off)
        fa = max(0.004, 1.6 * px)
        fib = _an(u, fa, 0.3, off + 30.0) * bl(fa) + 0.5 * _an(u, fa * 2.5, 0.5, off + 31.0)
        chk = _an(u, 0.012, 0.5, off + 32.0)
        cw = max(0.06, 0.8 * px / 0.012)
        check = _iso(chk, cw) * smooth01(0.0, 0.3, _an(u, 0.05, 0.9, off + 33.0))
        kk = (1 - 0.12 * line) * (1 + 0.06 * fib) * (1 - 0.4 * check)
        col[m] = _mixc(col[m], (0.80, 0.78, 0.74), 0.35 * smooth01(-0.2, 0.5, pn(p / 0.25 + off + 34.0)))
        k[m] = kk

    # ---------------- кожа: зерно, заломы, потёртость
    m = sel("leather")
    if m.any():
        p = P[m]
        gs = max(0.003, 1.5 * px)
        kk = 1 + 0.07 * pn(p / gs + off + 35.0) * bl(gs)
        crease = _iso(pn(p / 0.03 + off + 36.0), max(0.06, 0.8 * px / 0.03)) * smooth01(0.0, 0.3, pn(p / 0.08 + off + 37.0))
        kk *= (1 - 0.18 * crease) * (1 + 0.07 * pn(p / 0.05 + off + 38.0))
        k[m] = kk

    # ---------------- пробка: поры
    m = sel("cork")
    if m.any():
        p = P[m]
        f1, f2, r = cells(p, max(0.006, 3 * px), seed + 15)
        pore = (1 - smooth01(0.12, 0.22, f1)) * (r > 0.5) * bl(0.006)
        k[m] = (1 - 0.32 * pore) * (1 + 0.08 * pn(p / 0.02 + off + 39.0))

    # ---------------- бумага: волокна, обрез пачек тонкими листами
    m = sel("paper")
    if m.any():
        p, n = P[m], N[m]
        kk = 1 + 0.025 * pn(p / max(0.003, 1.5 * px) + off + 40.0) * bl(0.003)
        side = 1 - smooth01(0.4, 0.7, np.abs(n[:, 2]))
        sheet = _band((p[:, 2] + 0.002 * pn(p / 0.02 + off + 41.0)) / 0.004, 0.1, 0.5 * px / 0.004) * bl(0.004)
        kk *= 1 - 0.1 * sheet * side
        col[m] = _mixc(col[m], (0.86, 0.80, 0.66), 0.25 * smooth01(0.3, 0.7, pn(p / 0.08 + off + 42.0)))
        k[m] = kk

    # ---------------- латунь, кромка, кованое железо, крашеный металл: шлифовка и царапины, у каждого своё
    m = sel("brass", "edge", "forged", "enamel")
    if m.any():
        u, p, c = U[m], P[m], col[m]
        km = kind[m]
        fa = max(0.002, 1.4 * px)
        brush = _an(u, fa, 0.15, off + 43.0) * bl(fa)
        kk = 1 + 0.05 * brush + 0.04 * pn(p / 0.1 + off + 44.0)
        sc = _an(u, 0.03, 0.4, off + 45.0)
        scratch = _iso(sc, min(0.06, max(0.015, 0.8 * px / 0.03))) * smooth01(0.2, 0.45, pn(p / 0.2 + off + 46.0))
        kk *= 1 + 0.14 * scratch * (km != "enamel")
        br = km == "brass"
        if br.any():
            tarn = smooth01(0.0, 0.5, pn(p / 0.04 + off + 47.0))
            green = smooth01(0.55, 0.62, pn(p / 0.03 + off + 48.0))
            kk = np.where(br, kk * (1 - 0.14 * tarn), kk)
            c = np.where(br[:, None], _mixc(c, (0.42, 0.66, 0.54), 0.6 * green), c)
        fg = km == "forged"
        if fg.any():
            f1, f2, r = cells(p, max(0.012, 3 * px), seed + 17)
            dent = smooth01(0.0, 0.6, f1) * bl(0.012)
            kk = np.where(fg, kk * (1.05 - 0.12 * dent) * (1 - 0.1 * (1 - smooth01(0.0, 0.08, f2 - f1)) * bl(0.012)), kk)
        en = km == "enamel"
        if en.any():
            cv = pn(p / 0.025 + off + 49.0)
            chip = smooth01(0.52, 0.57, cv) * smooth01(0.05, 0.35, pn(p / 0.3 + off + 50.0))
            edge = smooth01(0.46, 0.51, cv) * (1 - smooth01(0.52, 0.57, cv)) * smooth01(0.05, 0.35, pn(p / 0.3 + off + 50.0))
            c = np.where(en[:, None], _mixc(c, (0.66, 0.68, 0.70), 0.9 * chip), c)
            kk = np.where(en, kk * (1 - 0.2 * edge) * (1 + 0.04 * pn(p / 0.06 + off + 51.0)), kk)
        col[m] = c
        k[m] = kk

    # ---------------- угли: светящиеся трещинки, пепел сверху; жар
    m = sel("coal")
    if m.any():
        p, n = P[m], N[m]
        v = pn(p / 0.04 + off + 52.0)
        glow = _iso(v, max(0.1, 0.8 * px / 0.04)) * bl(0.04)
        ash = smooth01(0.2, 0.5, pn(p / 0.05 + off + 53.0)) * smooth01(0.3, 0.8, n[:, 2])
        c = _mixc(col[m], (0.62, 0.60, 0.58), 0.6 * ash)
        col[m] = _mixc(c, (1.0, 0.50, 0.16), 0.85 * glow * (1 - ash))
    m = sel("ember")
    if m.any():
        p = P[m]
        col[m] = _mixc(col[m], (1.0, 0.82, 0.38), 0.5 * smooth01(0.1, 0.5, pn(p / 0.03 + off + 54.0)))

    # ---------------- оплавленный песок (фульгурит): стекло с пузырьками, корка песка
    m = sel("glass")
    if m.any():
        p = P[m]
        crust = smooth01(0.0, 0.15, pn(p / 0.025 + off + 55.0) + 0.3 * pn(p / 0.008 + off + 56.0) * bl(0.008))
        c = _mixc(col[m], (0.86, 0.78, 0.60), 0.8 * crust)
        f1, f2, r = cells(p, max(0.01, 3 * px), seed + 19)
        bub = (1 - smooth01(0.15, 0.24, f1)) * (r > 0.5) * (1 - crust) * bl(0.01)
        col[m] = _mixc(c, (0.97, 1.0, 0.98), 0.7 * bub)
        k[m] = 1 + 0.06 * pn(p / max(0.004, 2 * px) + off + 57.0) * bl(0.004)

    # ---------------- тёмная вода в лунке: блики пятнами; рыба: чешуя дужками-ячейками, светлое брюшко
    m = sel("water")
    if m.any():
        p = P[m]
        gl = smooth01(0.3, 0.42, pn(p * np.array([1 / 0.05, 1 / 0.12, 1.0]) + off + 61.0))
        col[m] = _mixc(col[m], (0.36, 0.60, 0.74), 0.6 * gl)
    m = sel("fish")
    if m.any():
        p = P[m]
        f1, f2, r = cells(p * np.array([1.0, 1.6, 1.6]), max(0.012, 3 * px), seed + 23)
        edge = 1 - smooth01(0.02, max(0.06, 1.2 * px / 0.012), f2 - f1)
        k[m] = (1 - 0.14 * edge * bl(0.012)) * (1 + 0.05 * pn(p / 0.05 + off + 62.0))

    # ---------------- резина, оплётка
    m = sel("rubber")
    if m.any():
        p = P[m]
        k[m] = 1 + 0.06 * pn(p / max(0.004, 2 * px) + off + 58.0) * bl(0.004) + 0.04 * pn(p / 0.1 + off + 59.0)

    col = np.clip(col * k[:, None], 0.0, 1.0)
    rest = ~sel(*MY_KINDS)
    if rest.any():
        col[rest] = tb.detail_build(kind[rest], col[rest], P[rest], N[rest], U[rest], uok[rest], px, seed)
    return col


# ============================================================ всё вместе
def bake(name, seed=0, report=False):
    """Запечь модель пачки в один атлас (как texbake.bake_model для построек, но вид — по пикселю). Размер атласа."""
    objs = [o for o in bpy.context.scene.objects if o.type == "MESH" and len(o.data.polygons)]
    if not objs:
        return 0
    area = tb.surface_area(objs)
    size = TEX_SIZE.get(name) or tb.pick_size(area, density=260.0, lo=256, hi=512)
    tb.unwrap(objs, {}, margin=0.006 if size <= 256 else 0.004)
    g = tb.gather(objs)
    tri, xs, ys, bary = tb.rasterize(g["uv"], size)
    P = tb._interp(g["p0"], tri, bary)
    N = tb.flat_normals(g, tri, bary)
    vc = tb._interp(g["vc"], tri, bary)
    pid = g["pid"][tri]
    col, base = eval_base(pid, P, N, vc)
    col = tb.eval_overlays(g["ovl"][tri], P, N, col)
    kind = kinds_props(name, pid, base)
    uok = g["uok"][tri]
    U = tb.local_frames(pid, P, tb._interp(g["u0"], tri, bary), uok, seed)
    px = math.sqrt(area / max(1, len(tri)))
    col = detail_props(kind, col, P, N, U, uok, px, seed)
    if report:
        print("  %d px, %.1f мм на пиксель" % (size, px * 1000))
        agg = {}
        for kv in np.unique(kind):
            agg[kv] = int((kind == kv).sum())
        print("  виды: " + ", ".join("%s %d" % (a, b) for a, b in sorted(agg.items(), key=lambda t: -t[1])))

    img = np.zeros((size, size, 3), np.float64)
    mask = np.zeros((size, size), bool)
    img[ys, xs] = col
    mask[ys, xs] = True
    img = tb.dilate(img, mask)
    _save(name, img, size, objs)
    return size


def _save(name, img, size, objs):
    """Картинка в PNG и материал с ней на все сетки (как в конце texbake.bake_model)."""
    os.makedirs(tb.TMP, exist_ok=True)
    path = os.path.join(tb.TMP, name + "_albedo.png")
    im = bpy.data.images.new(name + "_albedo", size, size, alpha=False)
    pxs = np.ones((size, size, 4), np.float32)
    pxs[..., :3] = img
    im.pixels.foreach_set(pxs.ravel())
    im.filepath_raw = path
    im.file_format = "PNG"
    im.save()
    mat = bpy.data.materials.new(name + "_mat")
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = im
    tex.interpolation = "Linear"
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.9
    for o in objs:
        o.data.materials.clear()
        o.data.materials.append(mat)
