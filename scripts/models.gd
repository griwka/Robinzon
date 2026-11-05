class_name Models
## Процедурные low-poly модели из примитивов.
## Это временная графика для прототипа: позже каждую функцию можно заменить
## на загрузку модели из Blender (.glb), не трогая остальной код.

const TOON := preload("res://shaders/toon.gdshader")
const OUTLINE := preload("res://shaders/outline.gdshader")

static var _mat_cache: Dictionary = {}
static var _outline_cache: Dictionary = {}


static func mat(color: Color, outline := true, wind := 0.0) -> ShaderMaterial:
	var key := "%s|%s|%s" % [color.to_html(), outline, wind]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := ShaderMaterial.new()
	m.shader = TOON
	m.set_shader_parameter("albedo", color)
	m.set_shader_parameter("wind_strength", wind)
	if outline:
		m.next_pass = outline_mat(0.022)
	_mat_cache[key] = m
	return m


static func outline_mat(width: float) -> ShaderMaterial:
	if _outline_cache.has(width):
		return _outline_cache[width]
	var o := ShaderMaterial.new()
	o.shader = OUTLINE
	o.set_shader_parameter("width", width)
	_outline_cache[width] = o
	return o


static func part(parent: Node3D, mesh: Mesh, color: Color, pos := Vector3.ZERO,
		rot := Vector3.ZERO, scl := Vector3.ONE, outline := true, wind := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat(color, outline, wind)
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	parent.add_child(mi)
	return mi


static func sphere(r: float, segs := 12, rings := 8) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = segs
	s.rings = rings
	return s


static func box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


static func cyl(r_top: float, r_bottom: float, h: float, segs := 8) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bottom
	c.height = h
	c.radial_segments = segs
	c.rings = 1
	return c


static func capsule(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = h
	c.radial_segments = 10
	c.rings = 4
	return c


static func leaf_mesh(length: float, width: float) -> ArrayMesh:
	# Изогнутый лист пальмы из полосы треугольников (двусторонний за счёт двух граней)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 6
	var pts: Array = []
	for i in segs + 1:
		var t := float(i) / segs
		var z := -t * length
		var y := -t * t * length * 0.55
		var w := width * sin(PI * clamp(t * 0.95 + 0.05, 0.0, 1.0))
		pts.append([Vector3(-w, y, z), Vector3(0, y + 0.04, z), Vector3(w, y, z)])
	for i in segs:
		var a: Array = pts[i]
		var b: Array = pts[i + 1]
		for side in [[0, 1], [1, 2]]:
			var p0: Vector3 = a[side[0]]
			var p1: Vector3 = a[side[1]]
			var p2: Vector3 = b[side[0]]
			var p3: Vector3 = b[side[1]]
			for tri in [[p0, p2, p1], [p1, p2, p3], [p0, p1, p2], [p1, p3, p2]]:
				for v in tri:
					st.add_vertex(v)
	st.generate_normals()
	return st.commit()


# ============================================================== Природа
static func palm(rng: RandomNumberGenerator) -> Node3D:
	var root := Node3D.new()
	var height := rng.randf_range(4.0, 6.0)
	var lean := Vector3(rng.randf_range(-0.25, 0.25), 0, rng.randf_range(-0.25, 0.25))
	var trunk_col := Color("8b6a43")
	var segs := 6
	var top := Vector3.ZERO
	for i in segs:
		var t := float(i) / segs
		var seg_h := height / segs
		var offset := lean * pow(t, 1.6) * height
		var p := Vector3(offset.x, seg_h * (i + 0.5), offset.z)
		var r := lerpf(0.22, 0.14, t)
		var col := trunk_col if i % 2 == 0 else trunk_col.darkened(0.12)
		part(root, cyl(r * 0.9, r * 1.1, seg_h * 1.05, 7), col, p, Vector3(lean.z * 0.8, 0, -lean.x * 0.8))
		top = Vector3(offset.x, height, offset.z)
	var crown := Node3D.new()
	crown.name = "Crown"
	crown.position = top
	root.add_child(crown)
	var leaf_cols := [Color("3fae49"), Color("56c45c"), Color("349c43")]
	var n := rng.randi_range(7, 9)
	for i in n:
		var a := TAU * i / n + rng.randf() * 0.3
		var l := part(crown, leaf_mesh(rng.randf_range(2.4, 3.0), 0.5), leaf_cols[i % 3],
			Vector3.ZERO, Vector3(rng.randf_range(-0.35, 0.1), a, 0), Vector3.ONE, false, 1.0)
		l.name = "Leaf%d" % i
	var coco := Node3D.new()
	coco.name = "Coconuts"
	crown.add_child(coco)
	for i in 3:
		var a := TAU * i / 3.0
		part(coco, sphere(0.16, 8, 6), Color("6b4423"), Vector3(cos(a) * 0.22, -0.2, sin(a) * 0.22))
	return root


static func rock(rng: RandomNumberGenerator, big := true) -> Node3D:
	var root := Node3D.new()
	var base := Color("9aa0a6").lerp(Color("b5ab9a"), rng.randf())
	var count := 3 if big else 1
	for i in count:
		var s := rng.randf_range(0.7, 1.2) * (1.0 if big else 0.25)
		var m := sphere(1.0, 7, 4)
		var p := Vector3(rng.randf_range(-0.5, 0.5), s * 0.45, rng.randf_range(-0.5, 0.5)) if big and i > 0 else Vector3(0, s * 0.45, 0)
		part(root, m, base.darkened(0.08 * i), p, Vector3(rng.randf() * 0.5, rng.randf() * TAU, 0),
			Vector3(s * rng.randf_range(0.9, 1.3), s * 0.75, s))
	return root


static func bush(rng: RandomNumberGenerator) -> Node3D:
	var root := Node3D.new()
	var col := Color("2f8f3a").lerp(Color("4fae3c"), rng.randf())
	for i in 4:
		var s := rng.randf_range(0.45, 0.7)
		part(root, sphere(s, 9, 6), col.lightened(0.06 * i),
			Vector3(rng.randf_range(-0.45, 0.45), s * 0.8, rng.randf_range(-0.45, 0.45)), Vector3.ZERO, Vector3.ONE, true, 0.4)
	# цветочки
	for i in 3:
		var a := rng.randf() * TAU
		part(root, sphere(0.08, 6, 4), [Color("ff6fa5"), Color("ffd84a"), Color("ffffff")][i],
			Vector3(cos(a) * 0.55, 0.9 + rng.randf() * 0.3, sin(a) * 0.55), Vector3.ZERO, Vector3.ONE, false)
	return root


static func driftwood(rng: RandomNumberGenerator) -> Node3D:
	var root := Node3D.new()
	var col := Color("b99b7a")
	part(root, cyl(0.12, 0.15, 1.6, 7), col, Vector3(0, 0.12, 0), Vector3(0, 0, PI / 2))
	part(root, cyl(0.06, 0.08, 0.6, 6), col.darkened(0.1), Vector3(0.3, 0.2, 0.15), Vector3(0.6, 0.4, PI / 2.5))
	root.rotation.y = rng.randf() * TAU
	return root


static func shell(rng: RandomNumberGenerator) -> Node3D:
	var root := Node3D.new()
	var col: Color = [Color("f4c6c0"), Color("ffe4b5"), Color("f7a8b8")][rng.randi() % 3]
	part(root, cyl(0.02, 0.16, 0.12, 8), col, Vector3(0, 0.05, 0), Vector3(0.2, rng.randf() * TAU, 0))
	return root


static func distant_island(rng: RandomNumberGenerator, radius: float) -> Node3D:
	var root := Node3D.new()
	part(root, cyl(radius * 0.9, radius, 1.2, 14), Color("f0d58a"), Vector3(0, 0.2, 0), Vector3.ZERO, Vector3.ONE, false)
	part(root, sphere(radius * 0.8, 12, 6), Color("3f9d4a"), Vector3(0, 0.3, 0), Vector3.ZERO, Vector3(1, rng.randf_range(0.35, 0.8), 1), false)
	part(root, cyl(0, radius * 0.4, radius * rng.randf_range(0.6, 1.0), 7), Color("7d8a8f"),
		Vector3(rng.randf_range(-3, 3), radius * 0.5, rng.randf_range(-3, 3)), Vector3.ZERO, Vector3.ONE, false)
	return root


static func cloud(rng: RandomNumberGenerator) -> Node3D:
	var root := Node3D.new()
	var m := ShaderMaterial.new()
	m.shader = TOON
	m.set_shader_parameter("albedo", Color(1, 1, 1))
	m.set_shader_parameter("rim_amount", 0.8)
	for i in rng.randi_range(3, 6):
		var mi := MeshInstance3D.new()
		mi.mesh = sphere(rng.randf_range(3.0, 6.0), 10, 6)
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(i * 4.0 - 8.0 + rng.randf_range(-1, 1), rng.randf_range(-1, 1.5), rng.randf_range(-2, 2))
		mi.scale = Vector3(1, 0.6, 1)
		root.add_child(mi)
	return root


# ============================================================== Постройки
static func building(id: String) -> Node3D:
	match id:
		"campfire": return campfire()
		"torch": return torch()
		"workbench": return workbench()
		"hut": return hut()
		"raft": return raft()
		"shell_deco": return shell_deco()
	return Node3D.new()


static func campfire() -> Node3D:
	var root := Node3D.new()
	for i in 8:
		var a := TAU * i / 8.0
		part(root, sphere(0.16, 7, 4), Color("8f9499"), Vector3(cos(a) * 0.6, 0.1, sin(a) * 0.6), Vector3.ZERO, Vector3(1, 0.7, 1))
	for i in 4:
		var a := TAU * i / 4.0 + 0.4
		part(root, cyl(0.06, 0.07, 0.9, 6), Color("7a5230"), Vector3(cos(a) * 0.18, 0.25, sin(a) * 0.18),
			Vector3(sin(a) * 0.9, 0, cos(a) * -0.9))
	var fire := Node3D.new()
	fire.name = "Fire"
	root.add_child(fire)
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.albedo_color = Color("ff9a2e")
	var fm2 := fm.duplicate()
	fm2.albedo_color = Color("ffe066")
	var f1 := MeshInstance3D.new()
	f1.mesh = cyl(0.0, 0.3, 0.8, 6)
	f1.material_override = fm
	f1.position.y = 0.5
	fire.add_child(f1)
	var f2 := MeshInstance3D.new()
	f2.mesh = cyl(0.0, 0.17, 0.5, 6)
	f2.material_override = fm2
	f2.position.y = 0.4
	fire.add_child(f2)
	var light := OmniLight3D.new()
	light.name = "Light"
	light.light_color = Color("ffb35c")
	light.light_energy = 2.0
	light.omni_range = 9.0
	light.position.y = 1.0
	light.shadow_enabled = false
	root.add_child(light)
	return root


static func torch() -> Node3D:
	var root := Node3D.new()
	part(root, cyl(0.05, 0.07, 1.6, 6), Color("6e4a2a"), Vector3(0, 0.8, 0))
	part(root, cyl(0.16, 0.1, 0.18, 7), Color("4a3b30"), Vector3(0, 1.62, 0))
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.albedo_color = Color("ffb030")
	var f := MeshInstance3D.new()
	f.name = "Flame"
	f.mesh = cyl(0.0, 0.14, 0.4, 6)
	f.material_override = fm
	f.position.y = 1.9
	root.add_child(f)
	var light := OmniLight3D.new()
	light.name = "Light"
	light.light_color = Color("ffb35c")
	light.light_energy = 1.4
	light.omni_range = 7.0
	light.position.y = 2.1
	root.add_child(light)
	return root


static func workbench() -> Node3D:
	var root := Node3D.new()
	var wood := Color("a8784a")
	part(root, box(Vector3(1.8, 0.14, 0.8)), wood, Vector3(0, 0.85, 0))
	for x in [-0.75, 0.75]:
		for z in [-0.3, 0.3]:
			part(root, box(Vector3(0.12, 0.8, 0.12)), wood.darkened(0.2), Vector3(x, 0.4, z))
	part(root, box(Vector3(0.5, 0.08, 0.3)), Color("8f9499"), Vector3(-0.4, 0.96, 0.1))
	part(root, cyl(0.04, 0.04, 0.5, 6), Color("6e4a2a"), Vector3(0.4, 0.97, -0.1), Vector3(0, 0.6, PI / 2))
	part(root, box(Vector3(0.6, 0.25, 0.4)), wood.lightened(0.1), Vector3(0.5, 0.2, 0))
	return root


static func hut() -> Node3D:
	var root := Node3D.new()
	var bamboo := Color("d9b866")
	var straw := Color("caa250")
	# стены из бамбука
	for side in 4:
		var a := side * PI / 2.0
		var dir := Vector3(sin(a), 0, cos(a))
		var right := Vector3(cos(a), 0, -sin(a))
		for i in 9:
			var t := (i - 4) * 0.36
			if side == 0 and abs(t) < 0.5:
				continue  # дверной проём
			part(root, cyl(0.09, 0.09, 2.0, 6), bamboo.darkened(0.08 * (i % 2)),
				dir * 1.55 + right * t + Vector3(0, 1.0, 0))
	part(root, box(Vector3(3.4, 0.15, 3.4)), Color("a8784a"), Vector3(0, 0.07, 0))
	# крыша
	part(root, cyl(0.0, 2.7, 1.8, 4), straw, Vector3(0, 2.85, 0), Vector3(0, PI / 4, 0))
	part(root, cyl(0.0, 2.5, 1.5, 4), straw.lightened(0.1), Vector3(0, 3.15, 0), Vector3(0, PI / 4, 0))
	return root


static func raft() -> Node3D:
	var root := Node3D.new()
	var wood := Color("b07c4a")
	for i in 6:
		part(root, cyl(0.17, 0.17, 3.0, 7), wood.darkened(0.06 * (i % 2)), Vector3((i - 2.5) * 0.36, 0.15, 0), Vector3(PI / 2, 0, 0))
	for z in [-1.1, 1.1]:
		part(root, box(Vector3(2.3, 0.08, 0.2)), Color("d4b483"), Vector3(0, 0.33, z))
	part(root, cyl(0.06, 0.06, 2.6, 6), Color("6e4a2a"), Vector3(0, 1.6, 0))
	var sail := part(root, box(Vector3(1.6, 1.5, 0.04)), Color("f2ead3"), Vector3(0, 1.9, 0.05))
	sail.name = "Sail"
	return root


static func shell_deco() -> Node3D:
	var root := Node3D.new()
	for i in 7:
		var a := TAU * i / 7.0
		part(root, cyl(0.02, 0.14, 0.12, 8), [Color("f4c6c0"), Color("ffe4b5"), Color("f7a8b8")][i % 3],
			Vector3(cos(a) * 0.45, 0.06, sin(a) * 0.45), Vector3(0.3, a, 0))
	part(root, sphere(0.3, 8, 5), Color("ff7fb0"), Vector3(0, 0.25, 0), Vector3.ZERO, Vector3(1, 0.6, 1))
	part(root, sphere(0.12, 6, 4), Color("ffd84a"), Vector3(0, 0.45, 0))
	return root


# ============================================================== Инструменты
static func axe() -> Node3D:
	var root := Node3D.new()
	part(root, cyl(0.03, 0.035, 0.7, 6), Color("7a5230"), Vector3(0, -0.25, 0))
	part(root, box(Vector3(0.08, 0.18, 0.24)), Color("8f9499"), Vector3(0, -0.55, -0.1))
	return root


static func pick() -> Node3D:
	var root := Node3D.new()
	part(root, cyl(0.03, 0.035, 0.75, 6), Color("7a5230"), Vector3(0, -0.25, 0))
	part(root, box(Vector3(0.06, 0.08, 0.6)), Color("8a7f9e"), Vector3(0, -0.58, 0))
	return root
