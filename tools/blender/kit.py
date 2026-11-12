"""Набор инструментов для процедурного моделирования в Blender (bpy).

Все модели игры строятся из этих функций: примитивы, «трубки» по кривой, тела вращения,
листья, модификаторы (сглаживание, фаски, рельеф) и раскраска вершин с мягким затенением.
Ось Z — вверх, персонажи смотрят в +Y (в Godot это станет −Z, «вперёд»).
"""
import math
import random

import bpy  # noqa: F401  (bpy должен импортироваться первым)
import bmesh
from mathutils import Matrix, Vector, noise


# ============================================================ цвет
def hexcol(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))


def mix(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def shade(c, k):
    """k < 1 — темнее, k > 1 — светлее (к белому)."""
    if k <= 1:
        return tuple(v * k for v in c)
    t = k - 1
    return tuple(v + (1 - v) * t for v in c)


# ============================================================ сцена
def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def link(ob):
    bpy.context.scene.collection.objects.link(ob)
    return ob


def from_bm(name, bm, smooth=True):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    if smooth:
        for p in me.polygons:
            p.use_smooth = True
    return link(bpy.data.objects.new(name, me))


def place(ob, loc=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1)):
    ob.location = loc
    ob.rotation_euler = rot
    ob.scale = scale if isinstance(scale, (tuple, list)) else (scale, scale, scale)
    return ob


def empty(name, loc=(0, 0, 0), parent=None):
    e = link(bpy.data.objects.new(name, None))
    e.location = loc
    if parent:
        set_parent(e, parent)
    return e


# ============================================================ примитивы
def sphere(name, loc=(0, 0, 0), r=1.0, scale=(1, 1, 1), rot=(0, 0, 0), segs=20, rings=12):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=rings, radius=r)
    return place(from_bm(name, bm), loc, rot, scale)


def ico(name, loc=(0, 0, 0), r=1.0, scale=(1, 1, 1), rot=(0, 0, 0), sub=3):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=sub, radius=r)
    return place(from_bm(name, bm), loc, rot, scale)


def cyl(name, loc=(0, 0, 0), r1=0.5, r2=0.5, h=1.0, rot=(0, 0, 0), segs=16, scale=(1, 1, 1)):
    """Цилиндр/конус: основание в loc, растёт вверх по локальной Z."""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=segs, radius1=r1, radius2=r2, depth=h)
    bmesh.ops.translate(bm, verts=bm.verts, vec=(0, 0, h / 2))
    return place(from_bm(name, bm), loc, rot, scale)


def box(name, loc=(0, 0, 0), size=(1, 1, 1), rot=(0, 0, 0), bev=0.0, seg=2):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=size, verts=bm.verts)
    ob = place(from_bm(name, bm, smooth=False), loc, rot)
    if bev > 0:
        bevel(ob, bev, seg)
    return ob


def tube(name, pts, radii, segs=12, caps=True, twist=0.0):
    """Трубка вдоль ломаной: стволы, стебли, рога, хвосты, верёвки.
    pts — список точек, radii — радиус в каждой точке (или одно число)."""
    pts = [Vector(p) for p in pts]
    if not isinstance(radii, (list, tuple)):
        radii = [radii] * len(pts)
    bm = bmesh.new()
    rings = []
    prev_n = None
    for i, p in enumerate(pts):
        if i == 0:
            d = (pts[1] - pts[0]).normalized()
        elif i == len(pts) - 1:
            d = (pts[-1] - pts[-2]).normalized()
        else:
            d = ((pts[i + 1] - pts[i]).normalized() + (pts[i] - pts[i - 1]).normalized()).normalized()
        ref = Vector((0, 0, 1)) if abs(d.z) < 0.9 else Vector((1, 0, 0))
        n = prev_n if prev_n is not None else d.cross(ref).normalized()
        n = (n - d * n.dot(d)).normalized()   # переносим нормаль вдоль кривой без скручивания
        prev_n = n
        b = d.cross(n).normalized()
        ring = []
        for k in range(segs):
            a = 2 * math.pi * k / segs + twist * i
            ring.append(bm.verts.new(p + (n * math.cos(a) + b * math.sin(a)) * radii[i]))
        rings.append(ring)
    for i in range(len(rings) - 1):
        for k in range(segs):
            bm.faces.new((rings[i][k], rings[i][(k + 1) % segs], rings[i + 1][(k + 1) % segs], rings[i + 1][k]))
    if caps:
        bm.faces.new(rings[0][::-1])
        bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return from_bm(name, bm)


def lathe(name, profile, segs=24, loc=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1)):
    """Тело вращения: профиль [(радиус, высота), ...] снизу вверх. Горшки, плоды, бочки."""
    bm = bmesh.new()
    rings = []
    for r, z in profile:
        ring = []
        for k in range(segs):
            a = 2 * math.pi * k / segs
            ring.append(bm.verts.new((math.cos(a) * r, math.sin(a) * r, z)))
        rings.append(ring)
    for i in range(len(rings) - 1):
        for k in range(segs):
            bm.faces.new((rings[i][k], rings[i][(k + 1) % segs], rings[i + 1][(k + 1) % segs], rings[i + 1][k]))
    if profile[0][0] > 1e-4:
        bm.faces.new(rings[0][::-1])
    if profile[-1][0] > 1e-4:
        bm.faces.new(rings[-1])
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return place(from_bm(name, bm), loc, rot, scale)


def leaf(name, base, direction, length, width, droop=0.35, segs=8, fold=0.25, up=(0, 0, 1), shape=None):
    """Лист: полоса с прогибом по средней жилке и провисанием к кончику."""
    base = Vector(base)
    d = Vector(direction).normalized()
    upv = Vector(up)
    side = d.cross(upv)
    if side.length < 1e-3:
        side = d.cross(Vector((1, 0, 0)))
    side.normalize()
    upv = side.cross(d).normalized()
    bm = bmesh.new()
    rows = []
    for i in range(segs + 1):
        t = i / segs
        w = width * (shape(t) if shape else math.sin(math.pi * min(1.0, t * 0.92 + 0.08)))
        c = base + d * (t * length) - upv * (t * t * length * droop)
        mid = c + upv * (w * fold)
        rows.append((bm.verts.new(c - side * w), bm.verts.new(mid), bm.verts.new(c + side * w)))
    for i in range(segs):
        a, b = rows[i], rows[i + 1]
        bm.faces.new((a[0], b[0], b[1], a[1]))
        bm.faces.new((a[1], b[1], b[2], a[2]))
    return from_bm(name, bm)


# ============================================================ модификаторы
def subsurf(ob, lvl=2):
    m = ob.modifiers.new("ss", "SUBSURF")
    m.levels = lvl
    m.render_levels = lvl
    return ob


def bevel(ob, w=0.02, seg=2):
    m = ob.modifiers.new("bv", "BEVEL")
    m.width = w
    m.segments = seg
    m.limit_method = "ANGLE"
    return ob


def displace(ob, strength=0.1, size=0.5, kind="CLOUDS", seed=0):
    tex = bpy.data.textures.new(ob.name + "_tex", kind)
    if kind == "CLOUDS":
        tex.noise_scale = size
        tex.noise_depth = 2
    elif kind == "VORONOI":
        tex.noise_scale = size
    m = ob.modifiers.new("dp", "DISPLACE")
    m.texture = tex
    m.strength = strength
    m.mid_level = 0.5
    m.texture_coords = "OBJECT" if False else "LOCAL"
    return ob


def remesh(ob, voxel=0.02, smooth=4):
    """Сплавить несколько пересекающихся форм в одну гладкую (voxel remesh + сглаживание)."""
    m = ob.modifiers.new("rm", "REMESH")
    m.mode = "VOXEL"
    m.voxel_size = voxel
    m.use_smooth_shade = True
    if smooth:
        s = ob.modifiers.new("sm", "SMOOTH")
        s.iterations = smooth
        s.factor = 0.6
    return ob


def solidify(ob, t=0.012):
    m = ob.modifiers.new("so", "SOLIDIFY")
    m.thickness = t
    m.offset = 0
    return ob


def bake(ob):
    """Применить модификаторы и трансформацию (меш в мировых координатах, объект — в нуле)."""
    dg = bpy.context.evaluated_depsgraph_get()
    ev = ob.evaluated_get(dg)
    me = bpy.data.meshes.new_from_object(ev)
    ob.modifiers.clear()
    old = ob.data
    ob.data = me
    me.transform(ob.matrix_world)
    ob.matrix_world = Matrix.Identity(4)
    if old.users == 0:
        bpy.data.meshes.remove(old)
    return ob


# ============================================================ раскраска
def paint(ob, color, ao=0.35, ao_h=0.35, noise_amt=0.06, nscale=3.0, top=0.08, ground=0.0, fn=None, seed=0):
    """Раскрасить вершины: базовый цвет + мягкое затенение у земли и снизу + лёгкий шум.
    fn(co, normal) -> множитель или цвет (tuple) для узоров."""
    bake(ob)
    me = ob.data
    if "Col" not in me.color_attributes:
        me.color_attributes.new(name="Col", type="BYTE_COLOR", domain="CORNER")
    attr = me.color_attributes["Col"]
    off = Vector((seed * 13.1, seed * 7.7, seed * 3.3))
    for poly in me.polygons:
        for li in poly.loop_indices:
            vi = me.loops[li].vertex_index
            co = me.vertices[vi].co
            nrm = me.vertices[vi].normal
            c = color
            if fn:
                r = fn(co, nrm)
                if isinstance(r, tuple):
                    c = r
                elif r is not None:
                    c = shade(c, r)
            h = max(0.0, co.z - ground)
            k = 1.0 - ao * (1.0 - min(1.0, h / ao_h)) ** 2
            k *= 1.0 - 0.18 * max(0.0, -nrm.z)
            k *= 1.0 + top * max(0.0, nrm.z)
            k *= 1.0 + noise_amt * noise.noise((co + off) * nscale)
            out = tuple(min(1.0, max(0.0, v * k)) for v in c)
            attr.data[li].color_srgb = (out[0], out[1], out[2], 1.0)
    me.color_attributes.active_color = attr
    return ob


def join(objs, name):
    objs = [o for o in objs if o is not None]
    for o in objs:
        if o.modifiers or o.matrix_world != Matrix.Identity(4):
            bake(o)
    target = objs[0]
    if len(objs) > 1:
        with bpy.context.temp_override(active_object=target, object=target,
                                       selected_objects=objs, selected_editable_objects=objs):
            bpy.ops.object.join()
    target.name = name
    target.data.name = name
    return target


def set_origin(ob, pivot):
    """Перенести точку вращения объекта в pivot (мировые координаты), не сдвигая меш."""
    p = Vector(pivot)
    ob.data.transform(Matrix.Translation(-p))
    ob.matrix_world = Matrix.Translation(p)
    return ob


def set_parent(child, parent):
    mw = child.matrix_world.copy()
    child.parent = parent
    child.matrix_parent_inverse = parent.matrix_world.inverted()
    child.matrix_world = mw


# ============================================================ экспорт
def material_for_vertex_colors():
    mat = bpy.data.materials.get("VC")
    if mat:
        return mat
    mat = bpy.data.materials.new("VC")
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    attr = nt.nodes.new("ShaderNodeVertexColor")
    attr.layer_name = "Col"
    nt.links.new(attr.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.9
    return mat


def export(path):
    mat = material_for_vertex_colors()
    for ob in bpy.context.scene.objects:
        if ob.type == "MESH":
            ob.data.materials.clear()
            ob.data.materials.append(mat)
    kw = dict(filepath=path, export_format="GLB", export_apply=True, export_yup=True, use_selection=False)
    props = bpy.ops.export_scene.gltf.get_rna_type().properties.keys()
    if "export_vertex_color" in props:
        kw["export_vertex_color"] = "ACTIVE"
    if "export_animations" in props:
        kw["export_animations"] = False
    bpy.ops.export_scene.gltf(**kw)


def rnd(seed):
    return random.Random(seed)


# ============================================================ древесина: кора, торцы с кольцами, щепа
BARK = hexcol("7a5a40")
BARK_D = hexcol("5a4030")
WOOD_IN = hexcol("e6c48e")      # светлая заболонь на сколе
WOOD_HEART = hexcol("c99a62")   # тёмная сердцевина
MOSS = hexcol("6d9a40")
MOSS_L = hexcol("93b552")


def _frames(pts):
    """Нормаль и бинормаль вдоль ломаной без скручивания (как в tube)."""
    pts = [Vector(p) for p in pts]
    out = []
    prev_n = None
    for i, p in enumerate(pts):
        if i == 0:
            d = (pts[1] - pts[0]).normalized()
        elif i == len(pts) - 1:
            d = (pts[-1] - pts[-2]).normalized()
        else:
            d = ((pts[i + 1] - pts[i]).normalized() + (pts[i] - pts[i - 1]).normalized()).normalized()
        ref = Vector((0, 0, 1)) if abs(d.z) < 0.9 else Vector((1, 0, 0))
        n = prev_n if prev_n is not None else d.cross(ref).normalized()
        n = (n - d * n.dot(d)).normalized()
        prev_n = n
        out.append((p, d, n, d.cross(n).normalized()))
    return out


def bark_trunk(name, pts, radii, segs=18, seed=0, furrows=9, bump=0.06, rings_per_m=6):
    """Ствол с корой: по кругу — борозды коры (вмятины в форме), вдоль — бугры. Концы открыты:
    их закрывают wood_cap (скол с кольцами) или корни. Возвращает (объект, первый и последний круг вершин)."""
    fr = _frames(pts)
    # промежуточные круги — чтобы бугры и борозды были видны
    dense = []
    for i in range(len(pts) - 1):
        a, b = Vector(pts[i]), Vector(pts[i + 1])
        k = max(1, int((b - a).length * rings_per_m))
        for j in range(k):
            t = j / k
            dense.append((a.lerp(b, t), radii[i] + (radii[i + 1] - radii[i]) * t))
    dense.append((Vector(pts[-1]), radii[-1]))
    fr = _frames([p for p, _ in dense])
    off = Vector((seed * 3.1, seed * 1.7, seed * 2.3))
    bm = bmesh.new()
    rings = []
    s = 0.0
    for i, ((p, r), (_, d, n, b)) in enumerate(zip(dense, fr)):
        if i:
            s += (dense[i][0] - dense[i - 1][0]).length
        ring = []
        for k in range(segs):
            a = 2 * math.pi * k / segs
            groove = max(0.0, math.sin(a * furrows + noise.noise(Vector((s * 1.5, k * 0.3, 0)) + off) * 2.5))
            rr = r * (1.0 - 0.1 * groove ** 3 + bump * noise.noise(Vector((math.cos(a) * 1.3, math.sin(a) * 1.3, s * 1.4)) + off))
            ring.append(bm.verts.new(p + (n * math.cos(a) + b * math.sin(a)) * rr))
        rings.append(ring)
    for i in range(len(rings) - 1):
        for k in range(segs):
            bm.faces.new((rings[i][k], rings[i][(k + 1) % segs], rings[i + 1][(k + 1) % segs], rings[i + 1][k]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    first = [v.co.copy() for v in rings[0]]
    last = [v.co.copy() for v in rings[-1]]
    ob = from_bm(name, bm)
    return ob, first, last, fr[0], fr[-1]


def wood_cap(name, rim, center, axis, rr, seed=0, depth=0.05, rough=0.03, heart=None):
    """Торец бревна по кругу rim (точки): неровный скол, утопленный на depth, с годовыми кольцами,
    тёмной сердцевиной и трещинами. axis — наружу от бревна."""
    rng = random.Random(seed)
    axis = Vector(axis).normalized()
    center = Vector(center)
    bm = bmesh.new()
    nr = 12
    rows = [[bm.verts.new(p) for p in rim]]
    for j in range(1, nr):
        t = j / nr
        row = []
        for p in rim:
            q = center.lerp(Vector(p), 1 - t)
            q -= axis * (depth * min(1.0, t * 1.6) + rough * noise.noise(q * 9.0 + Vector((seed, 0, 0))))
            row.append(bm.verts.new(q))
        rows.append(row)
    c = bm.verts.new(center - axis * (depth + rng.uniform(0, rough)))
    m = len(rim)
    for j in range(nr - 1):
        for k in range(m):
            bm.faces.new((rows[j][k], rows[j][(k + 1) % m], rows[j + 1][(k + 1) % m], rows[j + 1][k]))
    for k in range(m):
        bm.faces.new((rows[-1][k], rows[-1][(k + 1) % m], c))
    # нормали наружу (по оси)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    f0 = bm.faces[0]
    f0.normal_update()
    if f0.normal.dot(axis) < 0:
        bmesh.ops.reverse_faces(bm, faces=bm.faces)
    ob = from_bm(name, bm)
    hc = heart or WOOD_HEART
    crack_a = rng.uniform(0, 6.28)

    def f(co, nrm):
        v = co - center
        v = v - axis * v.dot(axis)
        d = v.length / max(rr, 1e-3)
        ang = math.atan2(v.dot(axis.orthogonal().normalized().cross(axis)), v.dot(axis.orthogonal().normalized()))
        if d > 0.9:
            return mix(WOOD_IN, BARK, 0.55)      # тонкий тёмный ободок под корой
        wob = 0.03 * noise.noise(Vector((math.cos(ang) * 2, math.sin(ang) * 2, seed)))
        ring = (d + wob) * 6.0
        base = mix(hc, WOOD_IN, min(1.0, d * 1.4))
        if abs(ang - crack_a) < 0.07 and d > 0.2:   # трещина от сердцевины
            return shade(base, 0.55)
        return shade(base, 0.76) if ring % 1.0 < 0.28 else base
    paint(ob, WOOD_IN, ao=0.0, noise_amt=0.05, nscale=14, fn=f)
    return ob


def splinters(name, rim, axis, seed=0, count=9, length=(0.08, 0.3), width=0.07, bark_col=None):
    """Щепа по краю скола: вытянутые клинья вдоль оси; снаружи кора, внутри светлое дерево."""
    rng = random.Random(seed)
    axis = Vector(axis).normalized()
    parts = []
    m = len(rim)
    ctr = sum((Vector(p) for p in rim), Vector()) / m
    for i in range(count):
        k = int(i * m / count + rng.uniform(0, m / count * 0.6)) % m
        p = Vector(rim[k])
        out = (p - ctr).normalized()
        ln = rng.uniform(*length)
        tip = p + axis * ln + out * rng.uniform(-0.02, 0.04) - out * width * 0.4
        w = width * rng.uniform(0.7, 1.2)
        side = axis.cross(out).normalized()
        bm = bmesh.new()
        base_in = p - out * w * 0.9
        vs = [bm.verts.new(p + side * w * 0.6), bm.verts.new(p - side * w * 0.6),
              bm.verts.new(base_in), bm.verts.new(tip)]
        bm.faces.new((vs[0], vs[1], vs[3]))
        bm.faces.new((vs[1], vs[2], vs[3]))
        bm.faces.new((vs[2], vs[0], vs[3]))
        bm.faces.new((vs[0], vs[2], vs[1]))
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        ob = from_bm(name, bm, smooth=False)
        bc = bark_col or BARK
        paint(ob, WOOD_IN, ao=0.0, noise_amt=0.06, nscale=20,
              fn=lambda co, n, out=out, bc=bc: bc if n.dot(out) > 0.45 else None)
        parts.append(ob)
    return parts


def bark_fn(axis_pt, axis_dir, col=None, moss=0.0, seed=0, moss_up=0.35):
    """Раскраска коры: продольные тёмные борозды, светлые гребни, пятна мха сверху (moss 0..1)."""
    col = col or BARK
    axis_pt = Vector(axis_pt)
    axis_dir = Vector(axis_dir).normalized()
    ref = axis_dir.orthogonal().normalized()
    ref2 = axis_dir.cross(ref)
    off = Vector((seed * 5.3, seed * 2.1, seed * 7.7))

    def f(co, n):
        v = co - axis_pt
        s = v.dot(axis_dir)
        w = v - axis_dir * s
        a = math.atan2(w.dot(ref2), w.dot(ref))
        if moss > 0 and n.z > moss_up:
            m = noise.noise(co * 1.3 + off) + 0.3 * noise.noise(co * 4.5 + off) + (n.z - 0.8) * 0.6
            if m > 0.62 - moss * 0.6:
                return MOSS_L if (m > 0.85 - moss * 0.4 and n.z > 0.8) else MOSS
        g = math.sin(a * 11 + noise.noise(Vector((s * 1.2, 0, seed))) * 3.0 + s * 0.6)
        if g > 0.6:
            return shade(col, 0.68)
        if g < -0.8:
            return shade(col, 1.14)
        return None
    return f


def smooth_path(pts, radii, sub=4):
    """Сгладить ломаную (Катмулл — Ром): плавные корни, ветки, стебли. Возвращает (точки, радиусы)."""
    P = [Vector(p) for p in pts]
    if len(P) < 3:
        return pts, radii
    out_p, out_r = [], []
    for i in range(len(P) - 1):
        p0 = P[i - 1] if i > 0 else P[0] * 2 - P[1]
        p1, p2 = P[i], P[i + 1]
        p3 = P[i + 2] if i + 2 < len(P) else P[-1] * 2 - P[-2]
        for j in range(sub):
            t = j / sub
            t2, t3 = t * t, t * t * t
            q = 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3)
            out_p.append(tuple(q))
            out_r.append(radii[i] + (radii[i + 1] - radii[i]) * t)
    out_p.append(tuple(P[-1]))
    out_r.append(radii[-1])
    return out_p, out_r
