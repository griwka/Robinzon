class_name Lava
## Лава Острова Вулкана: материал и меши (дуга-ручей, круглое озеро, прямой поток) и источники жара.
## Каждый источник жара — узел в группе «lava» с методами heat_at(p) (0..1) и push_dir(p) (куда отбросит жар).

const SHADER := preload("res://shaders/lava.gdshader")

static var _mat: ShaderMaterial


static func material() -> ShaderMaterial:
	if _mat:
		return _mat
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	var nt := NoiseTexture2D.new()
	nt.width = 256
	nt.height = 256
	nt.seamless = true
	var nz := FastNoiseLite.new()
	nz.seed = 61
	nz.frequency = 0.03
	nz.fractal_octaves = 3
	nt.noise = nz
	nt.generate_mipmaps = true
	_mat.set_shader_parameter("noise_tex", nt)
	return _mat


## Полоса лавы по дуге: центр c (мировой), радиус r, ширина w, от угла a0 до a1. height(x, z) — высота земли.
static func arc_mesh(c: Vector3, r: float, w: float, a0: float, a1: float, height: Callable, origin: Vector3) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := maxi(4, int((a1 - a0) * r / 0.5))
	for i in n:
		var t0 := a0 + (a1 - a0) * i / n
		var t1 := a0 + (a1 - a0) * (i + 1) / n
		var q: Array[Vector3] = []
		for pair in [[t0, r - w * 0.5], [t0, r + w * 0.5], [t1, r + w * 0.5], [t1, r - w * 0.5]]:
			var a: float = pair[0]
			var rr: float = pair[1]
			var x := c.x + cos(a) * rr
			var z := c.z + sin(a) * rr
			var y: float = height.call(x, z) + 0.07
			q.append(Vector3(x, y, z) - origin)
		for k in [0, 1, 2, 0, 2, 3]:
			st.set_normal(Vector3.UP)
			st.add_vertex(q[k])
	return st.commit()


## Круглое озеро лавы радиусом r (плоский диск).
static func disk_mesh(r: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 40
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		st.set_normal(Vector3.UP)
		st.add_vertex(Vector3.ZERO)
		st.set_normal(Vector3.UP)
		st.add_vertex(Vector3(cos(a1) * r, 0, sin(a1) * r))
		st.set_normal(Vector3.UP)
		st.add_vertex(Vector3(cos(a0) * r, 0, sin(a0) * r))
	return st.commit()


## Прямой ручей лавы от a до b (локальные точки) шириной w.
static func strip_mesh(a: Vector3, b: Vector3, w: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var d := b - a
	d.y = 0.0
	var side := Vector3(-d.z, 0, d.x).normalized() * w * 0.5 if d.length() > 0.001 else Vector3(w * 0.5, 0, 0)
	var q := [a - side, a + side, b + side, b - side]
	for k in [0, 1, 2, 0, 2, 3]:
		st.set_normal(Vector3.UP)
		st.add_vertex(q[k])
	return st.commit()


static func mesh_node(mesh: Mesh) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


# ------------------------------------------------------------------ источники жара
## Ручей-дуга вокруг точки center (мировой): жар растёт ближе к лаве; skip(p) — где лавы нет (внутри кратера).
class Arc extends Node3D:
	var center := Vector3.ZERO
	var radius := 5.0
	var half_width := 0.75
	var reach := 2.4
	var skip: Callable

	func _ready() -> void:
		add_to_group("lava")

	func heat_at(p: Vector3) -> float:
		if absf(p.y - center.y) > 5.0 or (skip.is_valid() and skip.call(p)):
			return 0.0
		var d := absf(Vector2(p.x - center.x, p.z - center.z).length() - radius) - half_width
		return clampf(1.0 - d / reach, 0.0, 1.0) if d < reach else 0.0

	func push_dir(p: Vector3) -> Vector3:
		var v := Vector3(p.x - center.x, 0, p.z - center.z)
		var out := v.normalized() if v.length() > 0.01 else Vector3.FORWARD
		return out if v.length() > radius else -out


## Круглое озеро лавы.
class Pool extends Node3D:
	var radius := 3.6
	var reach := 3.4

	func _ready() -> void:
		add_to_group("lava")

	func heat_at(p: Vector3) -> float:
		if absf(p.y - global_position.y) > 6.0:
			return 0.0
		var d := Vector2(p.x - global_position.x, p.z - global_position.z).length() - radius
		return clampf(1.0 - d / reach, 0.0, 1.0) if d < reach else 0.0

	func push_dir(p: Vector3) -> Vector3:
		var v := Vector3(p.x - global_position.x, 0, p.z - global_position.z)
		return v.normalized() if v.length() > 0.01 else Vector3.FORWARD
