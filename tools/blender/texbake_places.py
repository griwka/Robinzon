"""Особые и сюжетные места на текстурах (v1.0.10): свои виды поверхности поверх texbake.detail_build.

Как подключено: build.py запекает модели из списка PLACES семейством "places" — это те же постройки ("build"),
но вид поверхности сначала ищется здесь (guess: цвета мест → вид), а после detail_build рисуется своя деталь (detail).
Явный вид — как обычно: paint(..., mat="ashlar").

Свои виды:
  ashlar    — старый тёсаный камень: зерно, щербинки, лишайник розетками, потёки от дождя, мох сверху;
  damp_stone — камень под землёй (шахта бункера): то же, но без лишайника и мха — сырые пятна и потёки;
  concrete  — бетон бункера: поры, светлые камешки, швы опалубки, потёки сверху вниз, сырые пятна;
  rustdoor  — крашеное железо (двери, люки, шкафы): мазки краски, царапины, сколы до ржавчины, рыжие потёки;
  glacier   — лёд ледника: слои годами (волнистые линии), трещины, пузырьки, снежная пыль сверху;
  ice       — прозрачный лёд (глыбы, ступени, застывший водопад): трещины, пузырьки, натёки вниз;
  snow      — снег: мягкие бугорки и искорки;
  basalt    — вулканический камень: поры-пузырьки, зерно, рыжие пятна окисла, трещины;
  lava_rock — застывшая лава: «канаты» волнами, тёмная корка, пыль в ложбинках;
  carved    — камень храма: зерно, следы резца, копоть, стёртые места светлее;
  wet_wood  — мокрые сваи и мостки: волокна, мокрая тёмная полоса внизу, зелёный налёт, ракушки у воды;
  glass     — стекло и линза: гладко, мягкий блик;
  brass     — латунь и медь: шлифовка, зелёная патина пятнами;
  plaster   — побелка и штукатурка: мазки кистью, отслоившиеся пятна до камня.
Все узоры — по шуму или тонкими швами, без полос «через одну» (иначе в чёткой текстуре — «зебра»).
"""
import math

import numpy as np

import kit
from texbake import _an, _band, _mixc, pn, smooth01

KINDS = ("ashlar", "damp_stone", "giant_bark", "concrete", "rustdoor", "glacier", "ice", "snow", "basalt", "lava_rock", "carved",
         "wet_wood", "glass", "brass", "plaster")

# цвета программ раскраски в моделях мест → вид поверхности (если mat не задан в paint)
KNOWN = {
    # камень форта, маяков, башен, святилища
    "9c958a": "ashlar", "7a7368": "ashlar", "b8ab98": "ashlar", "8a7a62": "ashlar", "a39c90": "ashlar",
    "948e83": "ashlar", "a19a90": "ashlar",
    # бетон и камень бункера
    "9a978e": "concrete", "7a7468": "concrete", "c8c2b4": "concrete", "8a8478": "concrete", "6b6660": "concrete",
    # крашеное железо
    "4f7a5a": "rustdoor", "5a5e52": "rustdoor", "3a5a7a": "rustdoor",
    # латунь, медь
    "c9a050": "brass", "d9884a": "brass", "5fb39a": "brass",
}
_KNOWN = {}


def guess(color):
    if not _KNOWN:
        for h, k in KNOWN.items():
            _KNOWN[tuple(round(v, 4) for v in kit.hexcol(h))] = k
    return _KNOWN.get(tuple(round(v, 4) for v in color[:3]))


def _streak(p, across, along, off):
    """Шум, вытянутый по вертикали: потёки, натёки, следы дождя."""
    return pn(np.stack([p[:, 0] / across, p[:, 1] / across, p[:, 2] / along], 1) + off)


def _bl(period, px):
    return float(smooth01(1.8, 3.6, np.array([period / px]))[0])


def detail(kind, col, P, N, U, uok, px, seed=0):
    """Мелкая деталь своих видов поверхности (остальные пиксели не трогаем)."""
    off = np.array([seed * 2.9 + 11.0, seed * 1.7 + 5.0, seed * 4.3 + 2.0])
    col = col.copy()
    k = np.ones(len(col))

    def sel(*names):
        m = np.zeros(len(kind), bool)
        for nm in names:
            m |= kind == nm
        return m

    def bl(period):
        return _bl(period, px)

    # ---------------- старый тёсаный камень: зерно, щербинки, лишайник, потёки, мох сверху
    m = sel("ashlar", "damp_stone")
    if m.any():
        p, n, c = P[m], N[m], col[m]
        dry = (kind[m] == "ashlar").astype(np.float64)
        gs = max(0.008, 2.2 * px)
        g = pn(p / gs + off) * bl(gs)
        kk = (1 + 0.08 * g) * (1 + 0.07 * pn(p / 0.15 + off + 1.0)) * (1 + 0.05 * pn(p / 0.6 + off + 2.0))
        pit = (1 - smooth01(-0.62, -0.48, pn(p / max(0.02, 3 * px) + off + 3.0))) * bl(0.02)
        kk *= 1 - 0.22 * pit
        chip = smooth01(0.52, 0.58, pn(p / 0.09 + off + 4.0))
        kk *= 1 + 0.1 * chip
        side = np.abs(n[:, 2]) < 0.7
        # потёки — редкие, местами (иначе на гладкой плите читаются как волокна дерева)
        rain = smooth01(0.3, 0.65, _streak(p, 0.06, 0.9, off + 5.0)) * smooth01(0.05, 0.45, pn(p / 0.9 + off + 11.0)) * side
        kk *= 1 - 0.12 * rain
        # лишайник — подкрашивает камень (светлее и чуть зеленее), а не заливает его: на тёмном камне не «камуфляж»
        lv = pn(p / 0.11 + off + 6.0) + 0.35 * pn(p / 0.03 + off + 7.0) * bl(0.03)
        lich = smooth01(0.56, 0.64, lv) * (n[:, 2] > -0.3) * dry * smooth01(-0.1, 0.3, pn(p / 1.3 + off + 12.0))
        tint = np.clip(c * np.array([1.22, 1.3, 1.08]) + np.array([0.05, 0.06, 0.02]), 0.0, 1.0)
        c = _mixc(c, tint, 0.8 * lich)
        lo = pn(p / 0.07 + off + 8.0)
        c = _mixc(c, np.clip(c * np.array([1.35, 1.1, 0.8]) + np.array([0.08, 0.03, 0.0]), 0, 1),
                  0.7 * smooth01(0.66, 0.7, lo) * (n[:, 2] > -0.3) * dry)
        moss = smooth01(0.15, 0.4, pn(p / 0.25 + off + 9.0) + 0.5 * (n[:, 2] - 0.55)) * (n[:, 2] > 0.45) * dry
        c = _mixc(c, (0.40, 0.55, 0.26), 0.7 * moss)
        damp = smooth01(0.15, 0.55, pn(p / 0.9 + off + 10.0)) * (1 - dry)
        c = _mixc(c, c * np.array([0.78, 0.8, 0.76]), 0.6 * damp)
        kk *= 1 - 0.1 * rain * (1 - dry)
        col[m] = c
        k[m] = kk

    # ---------------- кора исполинского ствола (баньян): длинные борозды вдоль ствола, пластины, мох у корней
    m = sel("giant_bark")
    if m.any():
        p, n, u = P[m], N[m], U[m]
        fa = max(0.07, 2.6 * px)
        v = _an(u, fa, 1.6, off + 1.0) + 0.4 * _an(u, fa * 0.45, 0.7, off + 2.0) * bl(fa * 0.45)
        crev = 1 - smooth01(-0.3, -0.1, v)
        ridge = smooth01(0.2, 0.5, v)
        kk = (1 - 0.3 * crev) * (1 + 0.1 * ridge) * (1 + 0.06 * pn(p / 0.6 + off + 3.0))
        kk *= 1 + 0.04 * pn(p / max(0.02, 2 * px) + off + 4.0) * bl(0.02)
        c = col[m]
        lich = smooth01(0.5, 0.62, pn(p / 0.5 + off + 5.0)) * (1 - crev)
        c = _mixc(c, np.clip(c * np.array([1.2, 1.3, 1.05]) + 0.04, 0, 1), 0.6 * lich)
        col[m] = c
        k[m] = kk

    # ---------------- бетон: поры, камешки, швы опалубки, потёки, сырость
    m = sel("concrete")
    if m.any():
        p, n, c = P[m], N[m], col[m]
        gs = max(0.006, 2.0 * px)
        kk = (1 + 0.05 * pn(p / gs + off) * bl(gs)) * (1 + 0.06 * pn(p / 0.2 + off + 1.0))
        pore = (1 - smooth01(-0.6, -0.5, pn(p / max(0.012, 2.5 * px) + off + 2.0))) * bl(0.012)
        kk *= 1 - 0.3 * pore
        agg = smooth01(0.55, 0.62, pn(p / max(0.02, 3 * px) + off + 3.0)) * bl(0.02)
        kk *= 1 + 0.12 * agg
        side = np.abs(n[:, 2]) < 0.7
        lift = _band(p[:, 2] / 0.6 + 0.04 * pn(p / 0.5 + off + 4.0), max(0.012, 0.6 * px / 0.6), 0.5 * px / 0.6)
        kk *= 1 - 0.12 * lift * side
        drip = smooth01(0.1, 0.5, _streak(p, 0.05, 1.1, off + 5.0)) * smooth01(-0.2, 0.3, pn(p / 1.2 + off + 6.0)) * side
        c = _mixc(c, c * np.array([0.78, 0.76, 0.70]), 0.8 * drip)
        damp = smooth01(0.2, 0.6, pn(p / 0.8 + off + 7.0))
        c = _mixc(c, c * np.array([0.84, 0.88, 0.80]), 0.5 * damp)
        col[m] = c
        k[m] = kk

    # ---------------- крашеное железо: мазки, царапины, сколы до ржавчины, рыжие потёки
    m = sel("rustdoor")
    if m.any():
        p, n, c, u = P[m], N[m], col[m], U[m]
        kk = (1 + 0.04 * _an(u, max(0.01, 2 * px), 0.25, off) * bl(0.01)) * (1 + 0.06 * pn(p / 0.3 + off + 1.0))
        sc = np.abs(pn(p * np.array([1 / 0.04, 1 / 0.04, 1 / 0.4]) + off + 2.0))
        sw = min(0.06, max(0.015, 0.8 * px / 0.04))
        kk *= 1 + 0.12 * (1 - smooth01(sw * 0.5, sw, sc)) * smooth01(0.2, 0.4, pn(p / 0.3 + off + 3.0))
        cv = pn(p / 0.05 + off + 4.0) + 0.4 * pn(p / 0.015 + off + 5.0) * bl(0.015)
        mask = smooth01(0.0, 0.35, pn(p / 0.5 + off + 6.0))
        chip = smooth01(0.42, 0.5, cv) * mask
        rim = smooth01(0.36, 0.42, cv) * (1 - smooth01(0.42, 0.5, cv)) * mask
        rust = _mixc(np.tile([0.50, 0.27, 0.15], (len(p), 1)), (0.78, 0.45, 0.22), 0.5 + 0.5 * pn(p / 0.03 + off + 7.0))
        c = _mixc(c, rust, 0.9 * chip)
        kk *= 1 - 0.18 * rim
        side = np.abs(n[:, 2]) < 0.7
        st = smooth01(0.25, 0.6, _streak(p, 0.025, 0.5, off + 8.0)) * smooth01(0.0, 0.4, pn(p / 0.4 + off + 9.0)) * side
        c = _mixc(c, (0.62, 0.34, 0.18), 0.45 * st)
        col[m] = c
        k[m] = kk

    # ---------------- лёд ледника: слои, трещины, пузырьки, снежная пыль
    m = sel("glacier", "ice")
    if m.any():
        p, n, c = P[m], N[m], col[m]
        gl = kind[m] == "glacier"
        layer = _band(p[:, 2] / 0.45 + 0.9 * pn(p / 2.2 + off) + 0.25 * pn(p / 0.6 + off + 1.0),
                      max(0.03, 0.7 * px / 0.45), 0.6 * px / 0.45) * gl * smooth01(0.85, 0.55, np.abs(n[:, 2]))
        c = _mixc(c, c * np.array([0.72, 0.84, 0.98]), 0.55 * layer)
        cr = np.abs(pn(p / 0.7 + off + 2.0))
        w = min(0.05, max(0.012, 0.9 * px / 0.7))
        crack = (1 - smooth01(w * 0.5, w, cr)) * smooth01(0.0, 0.4, pn(p / 1.5 + off + 3.0))
        c = _mixc(c, (0.97, 0.99, 1.0), 0.6 * crack)
        cr2 = np.abs(pn(p / 0.22 + off + 4.0))
        w2 = min(0.06, max(0.015, 0.9 * px / 0.22))
        crack2 = (1 - smooth01(w2 * 0.5, w2, cr2)) * smooth01(0.2, 0.5, pn(p / 0.6 + off + 5.0)) * bl(0.03)
        c = _mixc(c, (0.92, 0.97, 1.0), 0.4 * crack2)
        bub = smooth01(0.6, 0.66, pn(p / max(0.012, 2.5 * px) + off + 6.0)) * bl(0.012)
        c = _mixc(c, (1.0, 1.0, 1.0), 0.5 * bub)
        side = np.abs(n[:, 2]) < 0.75
        run = smooth01(0.2, 0.6, _streak(p, 0.05, 0.7, off + 7.0)) * side * (~gl)
        c = _mixc(c, c * np.array([0.82, 0.9, 1.0]), 0.45 * run)
        deep = smooth01(0.1, 0.6, pn(p / 1.1 + off + 8.0))
        c = _mixc(c, c * np.array([0.8, 0.9, 1.0]), 0.3 * deep)
        dust = smooth01(0.4, 0.8, n[:, 2]) * smooth01(-0.3, 0.2, pn(p / 0.35 + off + 9.0))
        c = _mixc(c, (0.96, 0.98, 1.0), 0.7 * dust)
        col[m] = c
        k[m] = 1 + 0.03 * pn(p / 0.15 + off + 10.0)

    # ---------------- снег: мягкие бугорки, искорки
    m = sel("snow")
    if m.any():
        p = P[m]
        sp = smooth01(0.62, 0.7, pn(p / max(0.008, 2 * px) + off + 1.0)) * bl(0.008)
        col[m] = _mixc(col[m], (1.0, 1.0, 1.0), 0.6 * sp)
        k[m] = (1 + 0.04 * pn(p / 0.3 + off)) * (1 + 0.02 * pn(p / 0.06 + off + 2.0))

    # ---------------- вулканический камень: поры, зерно, окисел, трещины
    m = sel("basalt", "lava_rock")
    if m.any():
        p, n, c = P[m], N[m], col[m]
        lr = kind[m] == "lava_rock"
        gs = max(0.008, 2.2 * px)
        kk = (1 + 0.08 * pn(p / gs + off) * bl(gs)) * (1 + 0.08 * pn(p / 0.18 + off + 1.0))
        vs = max(0.018, 3.2 * px)
        v = pn(p / vs + off + 2.0)
        hole = (1 - smooth01(-0.55, -0.42, v)) * bl(vs)
        lip = smooth01(-0.42, -0.34, v) * (1 - smooth01(-0.3, -0.2, v)) * bl(vs)
        kk *= (1 - 0.35 * hole) * (1 + 0.1 * lip)
        ox = smooth01(0.3, 0.6, pn(p / 0.4 + off + 3.0)) * (~lr)
        c = _mixc(c, c * np.array([1.25, 0.95, 0.75]), 0.35 * ox)
        cr = np.abs(pn(p / 0.35 + off + 4.0))
        w = min(0.06, max(0.015, 0.9 * px / 0.35))
        kk *= 1 - 0.3 * (1 - smooth01(w * 0.5, w, cr)) * smooth01(0.1, 0.4, pn(p / 1.0 + off + 5.0))
        # застывшая лава: «канаты» дугами поперёк течения и пыль в ложбинках
        rope = pn(np.stack([p[:, 0] / 0.09, p[:, 1] / 0.09, p[:, 2] / 0.3], 1) + off + 6.0) + 0.5 * pn(p / 0.6 + off + 7.0)
        ridge = _band(rope * 3.0, 0.12, max(0.05, 0.6 * px / 0.09))
        kk = np.where(lr, kk * (1 + 0.14 * ridge) * (1 - 0.1 * smooth01(0.3, 0.6, -rope)), kk)
        dust = smooth01(0.5, 0.85, n[:, 2]) * smooth01(0.1, 0.5, pn(p / 0.2 + off + 8.0))
        c = _mixc(c, c * 1.35 + 0.06, 0.4 * dust)
        col[m] = c
        k[m] = kk

    # ---------------- камень храма: зерно, следы резца, копоть, стёртые места
    m = sel("carved")
    if m.any():
        p, n, c, u = P[m], N[m], col[m], U[m]
        gs = max(0.006, 2.0 * px)
        kk = (1 + 0.07 * pn(p / gs + off) * bl(gs)) * (1 + 0.06 * pn(p / 0.25 + off + 1.0))
        chisel = pn(np.stack([(p[:, 0] + p[:, 2]) / 0.012, (p[:, 1] - p[:, 2]) / 0.012, p[:, 2] / 0.06], 1) + off + 2.0)
        kk *= 1 + 0.05 * chisel * bl(0.012)
        soot = smooth01(0.2, 0.6, pn(p / 0.5 + off + 3.0)) * smooth01(0.0, 2.5, p[:, 2])
        c = _mixc(c, c * 0.62, 0.45 * soot)
        worn = smooth01(0.45, 0.6, pn(p / 0.15 + off + 4.0))
        kk *= 1 + 0.1 * worn
        pit = (1 - smooth01(-0.62, -0.5, pn(p / max(0.015, 3 * px) + off + 5.0))) * bl(0.015)
        kk *= 1 - 0.2 * pit
        col[m] = c
        k[m] = kk

    # ---------------- мокрое дерево свай и мостков: волокна, мокрый низ, зелёный налёт, ракушки
    m = sel("wet_wood")
    if m.any():
        from texbake import _wood_rings
        p, n, c, u = P[m], N[m], col[m], U[m]
        line, fr = _wood_rings(u, px, off)
        fa = max(0.004, 1.6 * px)
        kk = (1 - 0.15 * line) * (1.03 - 0.06 * fr) * (1 + 0.05 * _an(u, fa, 0.35, off + 1.0) * bl(fa))
        # вода — на 0,55 м ниже настила (верх настила в модели — z=0)
        wl = -0.5 + 0.08 * pn(p / 0.4 + off + 2.0)
        wet = smooth01(wl + 0.32, wl - 0.02, p[:, 2])
        c = _mixc(c, c * np.array([0.62, 0.6, 0.55]), 0.8 * wet)
        alg = wet * smooth01(-0.1, 0.4, pn(p / 0.12 + off + 3.0))
        c = _mixc(c, (0.30, 0.42, 0.24), 0.6 * alg)
        bar = smooth01(0.58, 0.64, pn(p / max(0.015, 2.5 * px) + off + 4.0)) * smooth01(wl, wl - 0.2, p[:, 2]) * bl(0.015)
        c = _mixc(c, (0.86, 0.84, 0.76), 0.8 * bar)
        drip = smooth01(0.3, 0.7, _streak(p, 0.04, 0.6, off + 5.0)) * (1 - wet) * (np.abs(n[:, 2]) < 0.7)
        kk *= 1 - 0.1 * drip
        col[m] = c
        k[m] = kk

    # ---------------- стекло и линза: гладко, мягкий блик
    m = sel("glass")
    if m.any():
        p = P[m]
        k[m] = 1 + 0.05 * pn(p / 0.5 + off) + 0.08 * smooth01(0.45, 0.7, pn(p / 0.25 + off + 1.0))

    # ---------------- латунь и медь: шлифовка, патина пятнами
    m = sel("brass")
    if m.any():
        p, n, c, u = P[m], N[m], col[m], U[m]
        fa = max(0.003, 1.5 * px)
        kk = (1 + 0.05 * _an(u, fa, 0.15, off) * bl(fa)) * (1 + 0.06 * pn(p / 0.15 + off + 1.0))
        pv = pn(p / 0.08 + off + 2.0) + 0.4 * pn(p / 0.025 + off + 3.0) * bl(0.025)
        pat = smooth01(0.35, 0.5, pv)
        c = _mixc(c, (0.42, 0.70, 0.60), 0.7 * pat)
        kk *= 1 + 0.12 * smooth01(0.4, 0.8, n[:, 2]) * (1 - pat)
        col[m] = c
        k[m] = kk

    # ---------------- побелка и штукатурка: мазки, отслоившиеся пятна
    m = sel("plaster")
    if m.any():
        p, n, c = P[m], N[m], col[m]
        kk = (1 + 0.04 * pn(p * np.array([1 / 0.05, 1 / 0.05, 1 / 0.15]) + off) ) * (1 + 0.05 * pn(p / 0.4 + off + 1.0))
        pv = pn(p / 0.18 + off + 2.0) + 0.35 * pn(p / 0.05 + off + 3.0) * bl(0.05)
        peel = smooth01(0.48, 0.54, pv)
        edge = smooth01(0.42, 0.48, pv) * (1 - smooth01(0.48, 0.54, pv))
        c = _mixc(c, c * np.array([0.72, 0.66, 0.6]), 0.85 * peel)
        kk *= 1 - 0.2 * edge
        low = smooth01(0.6, 0.0, p[:, 2]) * smooth01(-0.2, 0.3, pn(p / 0.3 + off + 4.0))
        c = _mixc(c, c * np.array([0.8, 0.78, 0.72]), 0.5 * low)
        col[m] = c
        k[m] = kk

    return np.clip(col * k[:, None], 0.0, 1.0)
