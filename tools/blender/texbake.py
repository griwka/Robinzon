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
    out = {k: [] for k in ("uv", "co", "nr", "p0", "n0", "pid", "ovl", "vc", "obj", "u0", "uok", "flat")}
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
        u0 = _attr(me, "u0", V, 3)
        uok = _attr(me, "uok", P, 1, np.int32, "value")
        sm = np.zeros(P, bool)
        me.polygons.foreach_get("use_smooth", sm)
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
        out["u0"].append((u0 if u0 is not None else np.zeros((V, 3), np.float32))[tv])
        out["uok"].append(uok[tp] if uok is not None else np.zeros(T, np.int32))
        out["flat"].append(~sm[tp])
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


def bake_model(name, family, size=None, boost=None, seed=0, default="fur", report=False):
    """Запечь всю модель (все сетки сцены) в один атлас и назначить материал с текстурой.
    family: "people" | "animals" | "build" (постройки и лодки) — как угадывать вид поверхности и какую деталь
    рисовать; default — вид шкуры животного ("fur", "feather", "hide", "smooth"). Возвращает размер текстуры."""
    objs = [o for o in bpy.context.scene.objects if o.type == "MESH" and len(o.data.polygons)]
    if not objs:
        return 0
    build = family == "build"
    if boost is None:
        boost = {} if build else ({"Head": 1.6} if family == "people" else {"Head": 1.35})
    area = surface_area(objs)
    # постройки: мелочь ~512, крупное — 1024 (≈1 см на пиксель у хижины)
    size = size or (pick_size(area, density=150.0, lo=512) if build else pick_size(area))
    unwrap(objs, boost)
    g = gather(objs)
    tri, xs, ys, bary = rasterize(g["uv"], size)
    P = _interp(g["p0"], tri, bary)
    N = flat_normals(g, tri, bary) if build else _norm(_interp(g["n0"], tri, bary))
    vc = _interp(g["vc"], tri, bary)
    pid = g["pid"][tri]
    col = eval_programs(pid, P, N, vc)
    col = eval_overlays(g["ovl"][tri], P, N, col)
    if build:
        kind = kinds_build(pid)
        uok = g["uok"][tri]
        U = local_frames(pid, P, _interp(g["u0"], tri, bary), uok, seed)
        px = math.sqrt(area / max(1, len(tri)))
        col = detail_build(kind, col, P, N, U, uok, px, seed)
        if report:
            print("  %d px, %.1f мм на пиксель" % (size, px * 1000))
            report_kinds(name, pid, kind)
    else:
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


# ============================================================ постройки и лодки (v1.0.7)
# Вид поверхности программы раскраски: явный (paint(..., mat=)), иначе по точному цвету из словаря ниже,
# иначе по оттенку. Что угадалось, печатает report_kinds (python tools/blender/build.py --kinds <имена>).
KNOWN = {
    # дерево: доски, брёвна без коры, ящики
    "b8834b": "wood", "8a5a32": "wood", "c99a5e": "wood", "a87342": "wood", "9a6a3e": "wood", "c08a50": "wood",
    "a07040": "wood", "b07a45": "wood", "bf8a52": "wood", "8a6a48": "wood", "6b4524": "wood", "7a5232": "wood",
    "b8885a": "wood", "a87a4a": "wood", "8a6a4a": "wood", "a88458": "wood", "c9a467": "bark", "ecc58a": "wood",
    "9a5e38": "wood", "7a5236": "wood", "a87b3a": "straw", "d6b07a": "wood",
    # солома, сено, бамбук
    "d6ad55": "straw", "d9c45a": "hay", "e0c06a": "hay", "e8cf8a": "hay", "e0c070": "hay", "c9a050": "straw",
    "c9b060": "bamboo", "b8a050": "bamboo",
    # верёвка и ткань
    "d4b483": "rope", "f2ead3": "canvas", "efe2c8": "canvas", "e8ddc8": "canvas", "f2ead8": "canvas", "8a7a5a": "canvas",
    "8a8a6a": "canvas", "e8443a": "canvas",
    # камень, кирпич, глина, земля
    "a3a8ad": "stone", "4a4648": "stone", "6a6466": "stone", "6a6e72": "stone", "a3a39a": "stone", "b8b0a0": "stone",
    "d9d2c4": "stone", "9c958a": "stone", "7a7368": "stone", "8a9088": "stone",
    "b8583a": "brick", "a85a3a": "brick", "c0704a": "clay", "d9774a": "clay", "c87048": "clay",
    "6e4228": "soil", "6a4a2a": "soil", "5a4a42": "soil", "6a4028": "soil",
    # металл
    "4a4c52": "iron", "6b6f75": "iron", "8f979e": "metal", "8f9499": "metal", "c9cfd6": "metal", "6a6a70": "iron",
    "d9884a": "metal", "a0623a": "rust", "3a3a3a": "iron", "2a2a2e": "iron",
    # крашеное дерево: борта, ульи, двери
    "3f6a8a": "painted", "4f7a9a": "painted", "7f9fb8": "planked", "3a4a5a": "planked", "4a5a52": "planked",
    "f2c23a": "painted", "e0a83a": "painted", "4f7a5a": "painted", "e8dcc4": "painted", "a0a080": "painted",
    "c8503a": "clay",
}
_KNOWN = {}


def _known():
    if not _KNOWN:
        for h, k in KNOWN.items():
            _KNOWN[tuple(round(v, 4) for v in kit.hexcol(h))] = k
    return _KNOWN


def guess_build(color):
    """Вид поверхности по цвету программы раскраски (когда mat не задан)."""
    c = tuple(round(v, 4) for v in color[:3])
    k = _known().get(c)
    if k:
        return k
    r, g, b = color[:3]
    mx, mn = max(r, g, b), min(r, g, b)
    s = (mx - mn) / max(mx, 1e-4)
    if mx < 0.14:
        return "clean"
    if s < 0.14:
        return "canvas" if mx > 0.86 else "stone"
    if mx == r:
        hue = (60 * (g - b) / max(mx - mn, 1e-4)) % 360
    elif mx == g:
        hue = 60 * (b - r) / max(mx - mn, 1e-4) + 120
    else:
        hue = 60 * (r - g) / max(mx - mn, 1e-4) + 240
    if 70 < hue < 170 and s > 0.25:
        return "leaf"
    if 14 <= hue <= 46 and 0.3 < s < 0.8 and mx < 0.86:
        return "wood"
    return "plain"


def kinds_build(pid):
    kind = np.empty(len(pid), object)
    for p in np.unique(pid):
        idx = pid == p
        prog = kit.PAINTS[p] if 0 < p < len(kit.PAINTS) else None
        if prog is None:
            kind[idx] = "plain"
            continue
        m = prog["mat"]
        if m is None:
            m = "clean" if prog["noise_amt"] == 0 else guess_build(prog["color"])
        kind[idx] = m
    return kind


def report_kinds(name, pid, kind):
    """Какой вид поверхности у каждой программы раскраски — чтобы проверить угаданное."""
    agg = {}
    for p in np.unique(pid):
        prog = kit.PAINTS[p] if 0 < p < len(kit.PAINTS) else None
        h = "".join("%02x" % int(round(v * 255)) for v in prog["color"][:3]) if prog else "------"
        src = "mat" if prog and prog["mat"] else "угад"
        sel = pid == p
        k = kind[sel][0]
        agg[(h, k, src)] = agg.get((h, k, src), 0) + int(sel.sum())
    print("  виды поверхности %s:" % name)
    for (h, k, src), n in sorted(agg.items(), key=lambda t: -t[1]):
        print("    %s  %-9s %-4s %7d px" % (h, k, src, n))


def local_frames(pid, P, U, uok, seed=0):
    """«Развёрнутые» координаты детали для каждого пикселя: x, y — поперёк, z — вдоль (волокна, кора, пряди).
    Трубки и тела вращения знают их сами (kit: u0); у остальных — главные оси каждой программы раскраски
    (у доски — вдоль длины, поперёк — ширина и толщина), со случайным сдвигом — у каждой доски свой рисунок."""
    out = U.astype(np.float64).copy()
    rng = np.random.RandomState(seed + 11)
    for p in np.unique(pid):
        idx = np.nonzero((pid == p) & (uok == 0))[0]
        if len(idx) < 4:
            continue
        q = P[idx] - P[idx].mean(axis=0)
        w, v = np.linalg.eigh(q.T @ q / len(idx))
        a, b1, b2 = v[:, 2], v[:, 1], v[:, 0]          # вдоль, ширина, толщина
        out[idx, 0] = q @ b2 + rng.uniform(-1, 1)
        out[idx, 1] = q @ b1 + rng.uniform(-1, 1)
        out[idx, 2] = q @ a
    return out


def _band(f, hw, soft):
    """Полоса шириной 2·hw вокруг целых значений f (f — в периодах), сглаженная на soft."""
    fr = f - np.floor(f)
    d = np.minimum(fr, 1.0 - fr)
    return 1.0 - smooth01(hw - soft, hw + soft, d)


def _an(U, across, along, off):
    """Шум, вытянутый вдоль z «развёрнутых» координат: волокна, борозды коры."""
    return pn(np.stack([U[:, 0] / across, U[:, 1] / across, U[:, 2] / along], 1) + off)


def _an_dir(P, D, across, along, off):
    """Шум, вытянутый вдоль направления D (у каждого пикселя своё): соломинки по скату крыши."""
    s = (P * D).sum(axis=1)
    q = P - D * s[:, None]
    return pn(q / across + D * (s / along)[:, None] + off)


def _mixc(c, target, t):
    t = np.clip(t, 0.0, 1.0)[:, None]
    return c * (1 - t) + np.asarray(target, np.float64) * t


def _wood_rings(U, px, off):
    """Волокна дерева в уютном стиле: тёмные линии вдоль детали (по «поперечной» координате), плавные волны и
    редкие дуги. Так линии идут вдоль доски на любой её стороне и вдоль круглой жерди. Возвращает (линия, 0..1 между линиями)."""
    R = max(0.028, 5.0 * px)
    a = (U[:, 0] + U[:, 1]) * 0.7071
    wob = 1.9 * pn(U * np.array([1 / 0.3, 1 / 0.3, 1 / 0.9]) + off) + 0.5 * pn(U * np.array([1 / 0.1, 1 / 0.1, 1 / 0.3]) + off + 3.1)
    f = a / R + wob
    line = _band(f, 0.11, 0.8 * px / R)
    fr = f - np.floor(f)
    return line, fr


def detail_build(kind, col, P, N, U, uok, px, seed=0):
    """Мелкая деталь построек и лодок — в уютном стиле: чётко и насыщенно, но без фотореализма.
    px — сколько метров в пикселе атласа: всё мельче ~2 пикселей плавно гаснет (не рябит)."""
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

    # ---------------- дерево: годовые кольца дугами, волокна, сучки
    m = sel("wood")
    if m.any():
        u, p = U[m], P[m]
        line, fr = _wood_rings(u, px, off)
        fa = max(0.004, 1.6 * px)
        fib = _an(u, fa, 0.35, off + 7.0) * bl(fa) + 0.5 * _an(u, fa * 2.5, 0.6, off + 9.0)
        kv = _an(u, 0.07, 0.24, off + 21.0)
        knot = smooth01(0.55, 0.61, kv)
        halo = smooth01(0.44, 0.5, kv) * (1 - smooth01(0.53, 0.57, kv))
        kk = (1 - 0.17 * line) * (1.03 - 0.07 * fr) * (1 + 0.055 * fib)
        kk *= 1 - 0.34 * knot - 0.12 * halo
        kk *= 1 + 0.06 * pn(p / 0.45 + off + 1.0)
        k[m] = kk

    # ---------------- крашеное дерево: мазки кисти, кольца под краской, сколы до дерева; обшивка — пояса досок
    m = sel("painted", "planked")
    if m.any():
        u, p, c = U[m], P[m], col[m]
        line, fr = _wood_rings(u, px, off)
        kk = (1 - 0.06 * line) * (1 + 0.035 * _an(u, max(0.012, 2 * px), 0.3, off + 4.0))
        kk *= 1 + 0.05 * pn(p / 0.35 + off)
        pl = kind[m] == "planked"
        if pl.any():
            hz = 0.17
            si = np.floor(p[:, 2] / hz)
            seam = _band(p[:, 2] / hz, max(0.04, 0.6 * px / hz), 0.5 * px / hz)
            butt = _band((u[:, 2] + si * 0.93) / 2.4, max(0.004, 0.6 * px / 2.4), 0.5 * px / 2.4)
            kk = np.where(pl, kk * (1 - 0.28 * seam) * (1 - 0.22 * butt) * (1 + 0.04 * np.sin(si * 2.3)), kk)
        cv = pn(p / 0.05 + off + 13.0)
        mask = smooth01(0.1, 0.4, pn(p / 0.6 + off + 5.0))
        chip = smooth01(0.5, 0.55, cv) * mask
        edge = smooth01(0.44, 0.49, cv) * (1 - smooth01(0.5, 0.55, cv)) * mask
        col[m] = _mixc(c, (0.71, 0.53, 0.34), 0.9 * chip)
        k[m] = kk * (1 - 0.2 * edge)

    # ---------------- кора: продольные борозды, пластинки, лишайник
    m = sel("bark")
    if m.any():
        u, p, n = U[m], P[m], N[m]
        fa = max(0.022, 2.6 * px)
        v = _an(u, fa, 0.17, off + 2.0) + 0.35 * _an(u, fa * 0.5, 0.08, off + 6.0) * bl(fa * 0.5)
        crev = 1 - smooth01(-0.34, -0.16, v)
        ridge = smooth01(0.22, 0.48, v)
        plate = _band(u[:, 2] / 0.11 + 0.9 * _an(u, 0.04, 0.5, off + 8.0), max(0.05, 0.6 * px / 0.11), 0.5 * px / 0.11)
        kk = (1 - 0.32 * crev) * (1 + 0.1 * ridge) * (1 - 0.14 * plate * smooth01(-0.1, 0.25, v))
        kk *= 1 + 0.05 * pn(p / max(0.006, 2 * px) + off) * bl(0.006)
        lich = smooth01(0.52, 0.6, pn(p / 0.035 + off + 30.0)) * (n[:, 2] > -0.3) * (1 - crev)
        col[m] = _mixc(col[m], (0.70, 0.74, 0.58), 0.35 * lich)
        k[m] = kk

    # ---------------- торец: поры (кольца рисует kit.wood_cap)
    m = sel("endgrain")
    if m.any():
        p = P[m]
        k[m] = (1 + 0.06 * pn(p / max(0.005, 2 * px) + off) * bl(0.005)) * (1 + 0.04 * pn(p / 0.05 + off))

    # ---------------- бамбук: тонкие продольные волокна, крапинки
    m = sel("bamboo")
    if m.any():
        u, p = U[m], P[m]
        fa = max(0.003, 1.6 * px)
        kk = 1 + 0.07 * _an(u, fa, 0.5, off + 3.0) * bl(fa) + 0.04 * _an(u, fa * 3, 0.8, off + 4.0)
        kk *= 1 - 0.22 * smooth01(0.55, 0.65, pn(p / max(0.012, 3 * px) + off + 9.0))
        k[m] = kk

    # ---------------- солома и сено: соломинки по скату, тёмные щели, светлые стебли
    m = sel("straw", "hay")
    if m.any():
        p, n = P[m], N[m]
        down = np.array([0.0, 0.0, -1.0]) + n * n[:, 2:3]
        ln = np.linalg.norm(down, axis=1, keepdims=True)
        D = np.where(ln > 0.25, down / np.maximum(ln, 1e-6), np.array([1.0, 0.0, 0.0]))
        hay = kind[m] == "hay"
        D = np.where(hay[:, None], np.array([1.0, 0.0, 0.0]), D)
        # пучки соломы: тонкие тёмные щели между ними (|шум| около нуля — извилистые линии вдоль ската),
        # внутри пучка — светлые стебли; ширина пучка — не меньше 4 пикселей: издали не сливается в «песок»
        aw = max(0.03, 4.0 * px)
        v1 = _an_dir(p, D, aw, 0.55, off + 1.0)
        v1b = _an_dir(p, np.tile([0.0, 1.0, 0.0], (len(p), 1)), aw, 0.55, off + 2.0)
        w1 = min(0.16, max(0.07, 0.9 * px / aw))
        gap = 1 - smooth01(w1 * 0.5, w1, np.abs(v1))
        gapb = 1 - smooth01(w1 * 0.5, w1, np.abs(v1b))
        gap = np.where(hay, np.maximum(gap, gapb) * 0.8, gap)
        v2 = _an_dir(p, D, aw * 0.45, 0.3, off + 5.0)
        w2 = min(0.2, max(0.08, 0.9 * px / (aw * 0.45)))
        gap2 = (1 - smooth01(w2 * 0.5, w2, np.abs(v2))) * bl(aw * 0.45)
        hi = smooth01(0.3, 0.6, v1)
        kk = (1 - 0.34 * gap) * (1 - 0.18 * gap2) * (1 + 0.1 * hi) * (1 + 0.05 * v1) * (1 + 0.06 * pn(p / 0.3 + off))
        col[m] = _mixc(col[m], (0.97, 0.86, 0.52), 0.22 * hi)
        k[m] = kk

    # ---------------- камень: зёрна, пятна, трещины, светлые сколы
    m = sel("stone")
    if m.any():
        p = P[m]
        gs = max(0.008, 2.2 * px)
        g = pn(p / gs + off) * bl(gs)
        kk = (1 + 0.1 * smooth01(0.35, 0.55, g)) * (1 - 0.14 * (1 - smooth01(-0.6, -0.4, g)))
        kk *= 1 + 0.08 * pn(p / 0.12 + off + 3.0) + 0.05 * pn(p / 0.4 + off + 4.0)
        cs = 0.2
        cr = np.abs(pn(p / cs + off + 7.0))
        w = min(0.08, max(0.025, 1.0 * px / cs))
        crack = (1 - smooth01(w * 0.5, w, cr)) * smooth01(0.2, 0.45, pn(p / 0.6 + off + 8.0))
        chip = smooth01(0.5, 0.56, pn(p / 0.07 + off + 9.0))
        k[m] = kk * (1 - 0.2 * crack) * (1 + 0.1 * chip)

    # ---------------- кирпич и глина: крапинка, обжиг пятнами, следы рук
    m = sel("brick", "clay")
    if m.any():
        p = P[m]
        gs = max(0.005, 2 * px)
        sp = pn(p / gs + off) * bl(gs)
        clay = kind[m] == "clay"
        kk = (1 - np.where(clay, 0.1, 0.18) * (1 - smooth01(-0.62, -0.45, sp))) * (1 + 0.05 * sp)
        kk *= 1 + np.where(clay, 0.03, 0.08) * pn(p / 0.13 + off + 2.0)
        strokes = pn(p * np.array([1 / 0.07, 1 / 0.07, 1 / 0.012]) + off + 6.0) * bl(0.012)
        kk = np.where(clay, kk * (1 + 0.05 * strokes), kk * (1 - 0.1 * smooth01(0.45, 0.6, pn(p / 0.05 + off + 7.0))))
        k[m] = kk

    # ---------------- металл: шлифовка вдоль детали, царапины, ржавые пятнышки, листы с заклёпками
    m = sel("metal", "iron", "rust", "plate")
    if m.any():
        u, p, c, n = U[m], P[m], col[m], N[m]
        km = kind[m]
        fa = max(0.003, 1.5 * px)
        kk = 1 + 0.04 * _an(u, fa, 0.2, off + 1.0) * bl(fa) + 0.06 * pn(p / 0.2 + off + 2.0)
        sc = np.abs(_an(u, 0.05, 0.5, off + 3.0))
        sw = min(0.06, max(0.015, 0.8 * px / 0.05))
        scratch = (1 - smooth01(sw * 0.5, sw, sc)) * smooth01(0.2, 0.45, pn(p / 0.3 + off + 4.0))
        kk = kk * (1 + 0.16 * scratch)
        rv = pn(p / 0.06 + off + 5.0) + 0.4 * pn(p / 0.02 + off + 6.0) * bl(0.02)
        spot = smooth01(0.45, 0.6, rv) * np.where(km == "iron", 1.0, np.where(km == "plate", 0.6, 0.0))
        c = _mixc(c, (0.62, 0.36, 0.2), 0.75 * spot)
        rs = km == "rust"
        if rs.any():
            t = 0.5 + 0.5 * pn(p / 0.09 + off + 7.0) + 0.25 * pn(p / 0.03 + off + 8.0)
            rc = _mixc(np.tile([0.45, 0.24, 0.14], (len(p), 1)), (0.80, 0.48, 0.25), t)
            c = np.where(rs[:, None], c * 0.45 + rc * 0.55, c)
            pit = 1 - smooth01(-0.65, -0.45, pn(p / max(0.006, 2 * px) + off + 9.0))
            kk = np.where(rs, kk * (1 - 0.25 * pit), kk)
        pl = km == "plate"
        if pl.any():
            uu, vv = _weave_uv(p, n)
            a, b = uu / 0.62, vv / 0.4 + 0.5 * np.floor(uu / 0.62)
            sw2 = max(0.006, 0.7 * px)
            seam = np.maximum(_band(a, sw2 / 0.62, 0.5 * px / 0.62), _band(b, sw2 / 0.4, 0.5 * px / 0.4))
            rs_ = max(0.007, 1.6 * px)
            step = max(0.06, 7 * px)
            fa_, fb_ = a - np.floor(a), b - np.floor(b)
            da = np.minimum(fa_, 1 - fa_) * 0.62 - 0.03
            db = np.minimum(fb_, 1 - fb_) * 0.4 - 0.03
            ta = (vv / step) - np.floor(vv / step) - 0.5
            tb = (uu / step) - np.floor(uu / step) - 0.5
            dr = np.minimum(np.hypot(da, ta * step), np.hypot(db, tb * step))
            riv = 1 - smooth01(rs_ * 0.7, rs_, dr)
            kk = np.where(pl, kk * (1 - 0.3 * seam) * (1 + 0.22 * riv), kk)
        col[m] = c
        k[m] = kk

    # ---------------- верёвка: три пряди винтом
    m = sel("rope")
    if m.any():
        u, p = U[m], P[m]
        has = uok[m] > 0
        r = np.maximum(np.hypot(u[:, 0], u[:, 1]), 0.004)
        th = np.arctan2(u[:, 1], u[:, 0])
        st = np.sin(3 * th + 2 * math.pi * u[:, 2] / (6.5 * r))
        vis = smooth01(1.5, 3.0, 2 * math.pi * r / 3 / px)
        groove = (1 - smooth01(-0.95, -0.55, st)) * vis * has
        hi = smooth01(0.5, 0.95, st) * vis * has
        fib = pn(p / max(0.004, 2 * px) + off) * bl(0.004)
        k[m] = (1 - 0.32 * groove) * (1 + 0.08 * hi) * (1 + 0.05 * fib) * (1 + 0.05 * pn(p / 0.2 + off))

    # ---------------- парусина: плетение (если видно), мягкие складки, пятна
    m = sel("canvas")
    if m.any():
        p, n = P[m], N[m]
        uu, vv = _weave_uv(p, n)
        F = 2 * math.pi / 0.006
        wv = np.sign(np.sin(uu * F)) * np.sign(np.sin(vv * F)) * bl(0.006)
        fold = pn(p * np.array([1 / 0.25, 1 / 0.25, 1 / 0.08]) + off)
        stain = smooth01(0.3, 0.6, pn(p / 0.35 + off + 3.0))
        k[m] = (1 + 0.03 * wv) * (1 + 0.06 * fold) * (1 - 0.06 * stain) * \
            (1 + 0.03 * pn(p / max(0.004, 2 * px) + off) * bl(0.004))

    # ---------------- земля, ил, зола: комочки и светлые крупинки
    m = sel("soil")
    if m.any():
        p = P[m]
        gs = max(0.01, 2.2 * px)
        k[m] = (1 + 0.14 * pn(p / gs + off) * bl(gs) + 0.08 * pn(p / 0.05 + off + 1.0)) * \
            (1 + 0.2 * smooth01(0.6, 0.7, pn(p / 0.02 + off + 2.0)) * bl(0.02))

    # ---------------- листья (навесы, крыши из листьев), прочее
    m = sel("leaf")
    if m.any():
        p = P[m]
        k[m] = 1 + 0.07 * pn(p / 0.09 + off) + 0.04 * pn(p / 0.025 + off + 1.0) * bl(0.025)
    m = sel("plain")
    if m.any():
        p = P[m]
        k[m] = 1 + 0.035 * pn(p / 0.15 + off) + 0.025 * pn(p / max(0.01, 2 * px) + off + 1.0) * bl(0.01)
    return np.clip(col * k[:, None], 0.0, 1.0)


def flat_normals(g, tri, bary):
    """Нормаль пикселя в координатах раскраски: у плоских граней (ящики, доски) — нормаль самой грани,
    а не усреднённая по вершинам (иначе узоры fn(co, n) и деталь «плывут» по грани наискось)."""
    p0 = g["p0"].astype(np.float64)
    fnrm = np.cross(p0[:, 1] - p0[:, 0], p0[:, 2] - p0[:, 0])
    ref = g["n0"].sum(axis=1)
    fnrm = np.where(((fnrm * ref).sum(axis=1) < 0)[:, None], -fnrm, fnrm)
    fnrm = _norm(fnrm)
    sm = _norm(_interp(g["n0"], tri, bary))
    return np.where(g["flat"][tri][:, None], fnrm[tri], sm)
