"""Запекание раскраски моделей в текстуру (альбедо) — чёткие границы вместо «мыла».

Почему: раньше цвет жил только в вершинах (kit.paint), и между вершинами он плавно перетекал по крупным граням —
полосы тельняшки, края одежды, пятна шерсти расплывались. Теперь та же «программа раскраски» (цвет, fn(co, n),
затенение, шум — всё, что записал kit.paint) считается в КАЖДОМ пикселе текстуры. Модельные файлы менять не нужно:
узоры, которые там уже описаны, просто становятся резкими.

Как устроено (bake_model):
1. Развёртка: smart UV project по всем сеткам модели сразу, голове — больше места (лицо крупнее), упаковка в один атлас.
2. Растеризация в numpy: для каждого пикселя атласа — треугольник и барицентрические координаты.
3. Цвет пикселя: программа kit.PAINTS[pid] в исходных координатах раскраски (атрибуты p0/n0), потом перекраски
   kit.OVERLAYS (тельняшки), потом мелкая деталь по виду поверхности: ткань — складки и плетение, волосы — пряди,
   шерсть — штрихи, руно — завитки, перья — чешуйки рядов, кожа — тёплая и гладкая; глаза и блики не трогаем.
4. Поля вокруг островов развёртки заливаются соседним цветом (иначе на швах и вдали — тёмные нитки).
5. Картинка PNG и материал с ней — в .glb (Godot извлекает текстуру рядом: assets/models/<имя>_albedo.png).
"""
import math
import os
import tempfile

import bpy
import numpy as np
from mathutils import Vector, noise

import kit

TMP = os.path.join(tempfile.gettempdir(), "island_texbake")


# ============================================================ шум (векторный, для мелкой детали)
_rng = np.random.RandomState(7)
_PERM = np.concatenate([_rng.permutation(256)] * 2).astype(np.int64)
_GRAD = np.array([[1, 1, 0], [-1, 1, 0], [1, -1, 0], [-1, -1, 0], [1, 0, 1], [-1, 0, 1], [1, 0, -1], [-1, 0, -1],
                  [0, 1, 1], [0, -1, 1], [0, 1, -1], [0, -1, -1], [1, 1, 0], [-1, 1, 0], [0, -1, 1], [0, -1, -1]], np.float64)


def pn(p):
    """Градиентный шум Перлина для массива точек (N, 3) → (N,), примерно −1..1."""
    p = np.asarray(p, np.float64)
    pi = np.floor(p)
    f = p - pi
    i = pi.astype(np.int64) & 255
    u = f * f * f * (f * (f * 6 - 15) + 10)

    def g(dx, dy, dz):
        h = _PERM[_PERM[_PERM[i[:, 0] + dx] + i[:, 1] + dy] + i[:, 2] + dz] & 15
        gr = _GRAD[h]
        return gr[:, 0] * (f[:, 0] - dx) + gr[:, 1] * (f[:, 1] - dy) + gr[:, 2] * (f[:, 2] - dz)

    x00 = g(0, 0, 0) + u[:, 0] * (g(1, 0, 0) - g(0, 0, 0))
    x10 = g(0, 1, 0) + u[:, 0] * (g(1, 1, 0) - g(0, 1, 0))
    x01 = g(0, 0, 1) + u[:, 0] * (g(1, 0, 1) - g(0, 0, 1))
    x11 = g(0, 1, 1) + u[:, 0] * (g(1, 1, 1) - g(0, 1, 1))
    y0 = x00 + u[:, 1] * (x10 - x00)
    y1 = x01 + u[:, 1] * (x11 - x01)
    return y0 + u[:, 2] * (y1 - y0)


def smooth01(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3 - 2 * t)


# ============================================================ развёртка
def _select_only(objs):
    for o in bpy.context.scene.objects:
        o.select_set(False)
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]


def unwrap(objs, boost=None, margin=0.004):
    """Smart UV project по всем сеткам, крупнее — то, что важнее (boost: имя объекта → множитель), упаковка в атлас."""
    boost = boost or {}
    for o in objs:
        me = o.data
        while me.uv_layers:
            me.uv_layers.remove(me.uv_layers[0])
        me.uv_layers.new(name="UVMap")
    _select_only(objs)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(58), island_margin=0.0, area_weight=0.0,
                             correct_aspect=True, scale_to_bounds=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    for o in objs:
        k = boost.get(o.name, 1.0)
        if k != 1.0:
            uv = np.empty(len(o.data.loops) * 2, np.float32)
            o.data.uv_layers.active.data.foreach_get("uv", uv)
            o.data.uv_layers.active.data.foreach_set("uv", uv * k)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.select_all(action="SELECT")
    bpy.ops.uv.pack_islands(rotate=True, scale=True, margin_method="FRACTION", margin=margin)
    bpy.ops.object.mode_set(mode="OBJECT")


# ============================================================ сбор данных сетки
def _attr(me, name, n, width, dtype=np.float32, prop="vector"):
    if name not in me.attributes:
        return None
    a = np.empty(n * width, dtype)
    me.attributes[name].data.foreach_get(prop, a)
    return a.reshape(n, width) if width > 1 else a


def gather(objs):
    """Все треугольники модели одним набором массивов (вершины каждого треугольника, uv, атрибуты)."""
    out = {k: [] for k in ("uv", "co", "nr", "p0", "n0", "pid", "ovl", "vc", "obj")}
    for oi, o in enumerate(objs):
        me = o.data
        me.calc_loop_triangles()
        T, L, V, P = len(me.loop_triangles), len(me.loops), len(me.vertices), len(me.polygons)
        if T == 0:
            continue
        tl = np.empty(T * 3, np.int64)
        me.loop_triangles.foreach_get("loops", tl)
        tl = tl.reshape(T, 3)
        tv = np.empty(T * 3, np.int64)
        me.loop_triangles.foreach_get("vertices", tv)
        tv = tv.reshape(T, 3)
        tp = np.empty(T, np.int64)
        me.loop_triangles.foreach_get("polygon_index", tp)
        uv = np.empty(L * 2, np.float32)
        me.uv_layers.active.data.foreach_get("uv", uv)
        uv = uv.reshape(L, 2)
        co = np.empty(V * 3, np.float32)
        me.vertices.foreach_get("co", co)
        co = co.reshape(V, 3)
        nr = np.empty(V * 3, np.float32)
        me.vertices.foreach_get("normal", nr)
        nr = nr.reshape(V, 3)
        p0 = _attr(me, "p0", V, 3)
        n0 = _attr(me, "n0", V, 3)
        pid = _attr(me, "pid", P, 1, np.int32, "value")
        ovl = _attr(me, "ovl", P, 1, np.int32, "value")
        if "Col" in me.color_attributes and me.color_attributes["Col"].domain == "CORNER":
            vc = np.empty(L * 4, np.float32)
            me.color_attributes["Col"].data.foreach_get("color_srgb", vc)
            vc = vc.reshape(L, 4)[:, :3]
        else:
            vc = np.ones((L, 3), np.float32)
        out["uv"].append(uv[tl])
        out["co"].append(co[tv])
        out["nr"].append(nr[tv])
        out["p0"].append((p0 if p0 is not None else co)[tv])
        out["n0"].append((n0 if n0 is not None else nr)[tv])
        out["pid"].append(pid[tp] if pid is not None else np.zeros(T, np.int32))
        out["ovl"].append(ovl[tp] if ovl is not None else np.zeros(T, np.int32))
        out["vc"].append(vc[tl])
        out["obj"].append(np.full(T, oi, np.int32))
    return {k: np.concatenate(v) for k, v in out.items()}


# ============================================================ растеризация
def rasterize(uv, size):
    """uv: (T, 3, 2) в 0..1. Возвращает (tri, x, y, bary (N, 3)) — пиксели, центры которых внутри треугольников."""
    p = uv.astype(np.float64) * size - 0.5          # центр пикселя i — в координате i
    mn = np.floor(p.min(axis=1)).astype(np.int64)
    mx = np.ceil(p.max(axis=1)).astype(np.int64)
    mn = np.clip(mn, 0, size - 1)
    mx = np.clip(mx, 0, size - 1)
    ext = np.maximum(mx[:, 0] - mn[:, 0], mx[:, 1] - mn[:, 1]) + 1
    a, b, c = p[:, 0], p[:, 1], p[:, 2]
    den = (b[:, 1] - c[:, 1]) * (a[:, 0] - c[:, 0]) + (c[:, 0] - b[:, 0]) * (a[:, 1] - c[:, 1])
    ok = np.abs(den) > 1e-12
    res_t, res_x, res_y, res_b = [], [], [], []
    lo = 0
    for B in (1, 2, 4, 8, 16, 32, 64, 128, 256, 512, 1024, 2048):
        sel = np.nonzero(ok & (ext > lo) & (ext <= B))[0]
        lo = B
        if len(sel) == 0:
            continue
        gy, gx = np.mgrid[0:B, 0:B]
        offs = np.stack([gx.ravel(), gy.ravel()], 1)
        chunk = max(1, 4_000_000 // (B * B))
        for s in range(0, len(sel), chunk):
            t = sel[s:s + chunk]
            q = mn[t][:, None, :] + offs[None]                    # (n, B², 2)
            qx = q[..., 0].astype(np.float64)
            qy = q[..., 1].astype(np.float64)
            d = den[t][:, None]
            w0 = ((b[t, 1] - c[t, 1])[:, None] * (qx - c[t, 0][:, None]) + (c[t, 0] - b[t, 0])[:, None] * (qy - c[t, 1][:, None])) / d
            w1 = ((c[t, 1] - a[t, 1])[:, None] * (qx - c[t, 0][:, None]) + (a[t, 0] - c[t, 0])[:, None] * (qy - c[t, 1][:, None])) / d
            w2 = 1 - w0 - w1
            eps = -1e-6
            inside = (w0 >= eps) & (w1 >= eps) & (w2 >= eps) & (q[..., 0] <= mx[t][:, None, 0]) & (q[..., 1] <= mx[t][:, None, 1])
            ti, kk = np.nonzero(inside)
            if len(ti) == 0:
                continue
            res_t.append(t[ti])
            res_x.append(q[ti, kk, 0])
            res_y.append(q[ti, kk, 1])
            res_b.append(np.stack([w0[ti, kk], w1[ti, kk], w2[ti, kk]], 1))
    if not res_t:
        z = np.zeros(0, np.int64)
        return z, z, z, np.zeros((0, 3))
    return np.concatenate(res_t), np.concatenate(res_x), np.concatenate(res_y), np.concatenate(res_b)


def _interp(arr, tri, bary):
    return (arr[tri] * bary[:, :, None]).sum(axis=1)


def _norm(v):
    ln = np.linalg.norm(v, axis=1, keepdims=True)
    return np.where(ln > 1e-6, v / np.maximum(ln, 1e-6), np.array([0.0, 0.0, 1.0]))


def _shade(c, k):
    """kit.shade для массивов: k < 1 — темнее, k > 1 — к белому."""
    k = k[:, None]
    return np.where(k <= 1, c * k, c + (1 - c) * (k - 1))


# ============================================================ цвет по программам раскраски
def eval_programs(pid, P, N, vc):
    col = vc.astype(np.float64).copy()
    for p in np.unique(pid):
        prog = kit.PAINTS[p] if 0 < p < len(kit.PAINTS) else None
        if prog is None:
            continue
        idx = np.nonzero(pid == p)[0]
        base = np.tile(np.array(prog["color"][:3], np.float64), (len(idx), 1))
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
                    base[j] = r[:3]
                elif r is not None:
                    mult[j] = r
            if noise_amt:
                nz[j] = noise.noise((co + off) * nscale)
        base = _shade(base, mult)
        h = np.maximum(0.0, Pi[:, 2] - prog["ground"])
        k = 1.0 - prog["ao"] * (1.0 - np.minimum(1.0, h / prog["ao_h"])) ** 2
        k *= 1.0 - 0.18 * np.maximum(0.0, -Ni[:, 2])
        k *= 1.0 + prog["top"] * np.maximum(0.0, Ni[:, 2])
        k *= 1.0 + noise_amt * nz
        col[idx] = np.clip(base * k[:, None], 0.0, 1.0)
    return col


def eval_overlays(ovl, P, N, col):
    for o in np.unique(ovl):
        if o <= 0 or o >= len(kit.OVERLAYS):
            continue
        fn = kit.OVERLAYS[o]
        idx = np.nonzero(ovl == o)[0]
        for j in idx:
            r = fn(Vector(P[j]), Vector(N[j]))
            if r is not None:
                col[j] = r[:3]
    return col


# ============================================================ мелкая деталь по виду поверхности
def is_skin(c):
    r, g, b = c[:, 0], c[:, 1], c[:, 2]
    mx, mn = c.max(axis=1), c.min(axis=1)
    return (r > 0.62) & (g > 0.42) & (b > 0.28) & (r >= g) & (g >= b) & ((r - b) > 0.12) & ((mx - mn) < 0.45)


def kinds_for(pid, col, family, default="fur"):
    """Вид поверхности каждого пикселя: явный (paint(..., mat=)) или угаданный по цвету.
    У людей — кожа или ткань; у животных — default (шерсть, перья, шкура), но кожа (морда обезьяны) и
    оранжевые клювы и лапы птиц — гладкие."""
    kind = np.empty(len(pid), object)
    mx = col.max(axis=1)
    mn = col.min(axis=1)
    eye = (mx < 0.13) | ((mx > 0.93) & (mn > 0.88))     # зрачки, белки, блики
    skin = is_skin(col)
    for p in np.unique(pid):
        idx = pid == p
        prog = kit.PAINTS[p] if 0 < p < len(kit.PAINTS) else None
        m = prog["mat"] if prog else None
        if m is None and prog is not None and prog["noise_amt"] == 0:
            m = "clean"
        if m is None:
            if family == "people":
                kind[idx & skin] = "skin"
                kind[idx & ~skin] = "cloth"
            else:
                kind[idx] = default
                kind[idx & skin] = "smooth"
                if default == "feather":
                    beak = (col[:, 0] > 0.85) & (col[:, 1] > 0.35) & (col[:, 1] < 0.78) & (col[:, 2] < 0.32)
                    kind[idx & beak] = "smooth"
        else:
            kind[idx] = m
    kind[eye & (kind != "hair")] = "clean"
    return kind


def _weave_uv(P, N):
    """Две координаты на поверхности: проекция на плоскость, ближайшую к касательной (как трипланар)."""
    a = np.abs(N)
    ax = a.argmax(axis=1)
    u = np.where(ax == 0, P[:, 1], P[:, 0])
    v = np.where(ax == 2, P[:, 1], P[:, 2])
    return u, v


def detail(kind, col, P, N, seed=0):
    off = np.array([seed * 3.7, seed * 1.3, seed * 5.1])
    k = np.ones(len(col))

    m = kind == "cloth"
    if m.any():
        p, n = P[m], N[m]
        ang = np.arctan2(p[:, 1], p[:, 0])
        nz = pn(p * 4.0 + off)
        vert = np.sin(ang * 9 + nz * 3.0)
        horiz = np.sin(p[:, 2] * 24 + pn(p * 3.0 + off) * 2.5)
        low = np.clip((1.0 - p[:, 2]) * 1.4, 0, 1)
        f = np.maximum(0, (vert - 0.45) / 0.55) * (0.35 + 0.65 * low) + np.maximum(0, (horiz - 0.75) / 0.25) * 0.5
        kk = 1.0 - 0.13 * np.minimum(1.0, f)
        kk *= np.where(n[:, 2] > 0.55, 1.04, 1.0)
        u, v = _weave_uv(p, n)
        F = 2 * math.pi / 0.011                                   # плетение: нитки ~5 мм
        w = np.sign(np.sin(u * F)) * np.sign(np.sin(v * F))
        kk *= 1.0 + 0.03 * w
        kk *= 1.0 + 0.035 * pn(p * 160 + off)                    # волокна
        k[m] = kk

    m = kind == "hair"
    if m.any():
        p, n = P[m], N[m]
        c = p.mean(axis=0)
        d = p - c
        az = np.arctan2(d[:, 1], d[:, 0])
        el = np.arctan2(d[:, 2], np.hypot(d[:, 0], d[:, 1]))
        s = np.sin(az * 64 + pn(p * 7.0 + off) * 2.4 + pn(p * 26.0 + off) * 0.7)
        s2 = np.sin(az * 150 + pn(p * 11.0 + off) * 3.0)
        fade = smooth01(1.2, 0.75, el) * smooth01(0.88, 0.55, n[:, 2])   # у макушки пряди сходятся «звездой» — там гладко
        kk = 1.0 - 0.2 * smooth01(0.55, 0.95, s) * fade - 0.08 * smooth01(0.6, 1.0, s2) * fade
        kk *= 1.0 + 0.1 * smooth01(0.75, 1.0, -s) * fade * (n[:, 2] > -0.2)
        k[m] = kk

    m = kind == "beard"
    if m.any():
        p = P[m]
        s = np.sin(p[:, 0] * 260 + pn(p * 9.0 + off) * 3.0)
        k[m] = 1.0 - 0.16 * smooth01(0.5, 0.95, s) + 0.06 * pn(p * 40 + off)

    m = kind == "stubble"
    if m.any():
        p = P[m]
        k[m] = 1.0 - 0.22 * smooth01(0.25, 0.45, pn(p * 170 + off)) + 0.05 * pn(p * 30 + off)

    m = kind == "fur"
    if m.any():
        p, n = P[m], N[m]
        st = 0.65 * pn(p * np.array([95.0, 20.0, 95.0]) + off) + 0.35 * pn(p * np.array([200.0, 42.0, 200.0]) + off)
        kk = 1.0 + 0.16 * st
        kk *= 1.0 + 0.06 * np.maximum(0, n[:, 2]) - 0.08 * np.maximum(0, -n[:, 2])
        k[m] = kk

    m = kind == "wool"
    if m.any():
        p, n = P[m], N[m]
        r1 = np.abs(pn(p * 34.0 + off))
        r2 = np.abs(pn(p * 70.0 + off + 17.0))
        kk = 1.0 - 0.2 * (1 - smooth01(0.0, 0.08, r1)) - 0.1 * (1 - smooth01(0.0, 0.06, r2))
        kk *= 1.0 + 0.05 * pn(p * 12.0 + off)
        k[m] = kk

    m = kind == "feather"
    if m.any():
        p, n = P[m], N[m]
        c = p.mean(axis=0)
        d = p - c
        az = np.arctan2(d[:, 0], d[:, 2])
        row = 0.035
        a = -p[:, 1] / row                                       # ряды назад от клюва
        ri = np.floor(a)
        fr = a - ri
        t = az * 7.0 / math.pi + 0.5 * (ri % 2)
        ft = t - np.floor(t) - 0.5
        edge = 0.82 - 1.6 * ft * ft                              # край пера — дужкой
        line = smooth01(0.1, 0.0, np.abs(fr - edge))
        kk = 1.0 - 0.14 * line + 0.07 * (fr - 0.5) * (fr < edge)
        kk *= 1.0 + 0.03 * pn(p * 120 + off)
        k[m] = kk

    m = kind == "skin"
    if m.any():
        p, n = P[m], N[m]
        warm = 0.04 * np.maximum(0, -n[:, 2]) + 0.03 * np.maximum(0, 0.2 - n[:, 2])
        c = col[m]
        c2 = np.stack([np.minimum(1, c[:, 0] * (1 + warm * 0.5)), c[:, 1] * (1 - warm * 0.3), c[:, 2] * (1 - warm * 0.8)], 1)
        col[m] = c2 * (1.0 + 0.015 * pn(p * 30 + off))[:, None]

    m = kind == "hide"
    if m.any():
        p = P[m]
        k[m] = 1.0 + 0.06 * pn(p * 22 + off) + 0.035 * pn(p * 85 + off)

    m = kind == "smooth"
    if m.any():
        k[m] = 1.0 + 0.025 * pn(P[m] * 40 + off)

    return np.clip(col * k[:, None], 0.0, 1.0)


# ============================================================ поля вокруг островов
def dilate(img, mask, steps=12):
    img = img.copy()
    mask = mask.copy()
    for _ in range(steps):
        acc = np.zeros_like(img)
        cnt = np.zeros(mask.shape, np.float64)
        for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0), (1, 1), (1, -1), (-1, 1), (-1, -1)):
            m = np.roll(np.roll(mask, dy, 0), dx, 1)
            acc += np.roll(np.roll(img, dy, 0), dx, 1) * m[..., None]
            cnt += m
        grow = (~mask) & (cnt > 0)
        if not grow.any():
            break
        img[grow] = acc[grow] / cnt[grow][:, None]
        mask = mask | grow
    if (~mask).any():
        img[~mask] = img[mask].mean(axis=0) if mask.any() else 0.5
    return img


# ============================================================ всё вместе
def surface_area(objs):
    a = 0.0
    for o in objs:
        for p in o.data.polygons:
            a += p.area
    return a


def pick_size(area, density=360.0, lo=256, hi=1024):
    want = math.sqrt(area / 0.62) * density
    s = lo
    while s < want and s < hi:
        s *= 2
    return s


def bake_model(name, family, size=None, boost=None, seed=0, default="fur"):
    """Запечь всю модель (все сетки сцены) в один атлас и назначить материал с текстурой.
    family: "people" | "animals" — как угадывать вид поверхности; default — вид шкуры животного
    ("fur", "feather", "hide", "smooth"). Возвращает размер текстуры."""
    objs = [o for o in bpy.context.scene.objects if o.type == "MESH" and len(o.data.polygons)]
    if not objs:
        return 0
    if boost is None:
        boost = {"Head": 1.6} if family == "people" else {"Head": 1.35}
    size = size or pick_size(surface_area(objs))
    unwrap(objs, boost)
    g = gather(objs)
    tri, xs, ys, bary = rasterize(g["uv"], size)
    P = _interp(g["p0"], tri, bary)
    N = _norm(_interp(g["n0"], tri, bary))
    vc = _interp(g["vc"], tri, bary)
    pid = g["pid"][tri]
    col = eval_programs(pid, P, N, vc)
    col = eval_overlays(g["ovl"][tri], P, N, col)
    kind = kinds_for(pid, col, family, default)
    col = detail(kind, col, P, N, seed)

    img = np.zeros((size, size, 3), np.float64)
    mask = np.zeros((size, size), bool)
    img[ys, xs] = col
    mask[ys, xs] = True
    img = dilate(img, mask)

    os.makedirs(TMP, exist_ok=True)
    path = os.path.join(TMP, name + "_albedo.png")
    im = bpy.data.images.new(name + "_albedo", size, size, alpha=False)
    px = np.ones((size, size, 4), np.float32)
    px[..., :3] = img
    im.pixels.foreach_set(px.ravel())
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
    return size
