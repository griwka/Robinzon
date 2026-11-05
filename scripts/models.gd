class_name Models
## Процедурные low-poly модели из примитивов (временная графика прототипа).
## Каждую функцию позже можно заменить загрузкой .glb из Blender — остальной код не изменится.

const TOON := preload("res://shaders/toon.gdshader")
const OUTLINE := preload("res://shaders/outline.gdshader")
const WING := preload("res://shaders/wing.gdshader")
const TOON_FOLIAGE := preload("res://shaders/toon_foliage.gdshader")
const FLAME := preload("res://shaders/flame.gdshader")
const CLOUD := preload("res://shaders/cloud.gdshader")

const PAINTED := preload("res://assets/textures/painted.png")

static var _mat_cache: Dictionary = {}
static var _outline_cache: Dictionary = {}
static var _unshaded_cache: Dictionary = {}


static var _scene_cache: Dictionary = {}


## Загрузить модель из Blender (assets/models/<name>.glb) и наложить игровые материалы:
## toon-шейдер с цветом вершин и контуром; у листвы — ветер и растворение у камеры.
## Если файла нет — вернёт null (тогда используется простая модель из примитивов).
static func glb(name: String) -> Node3D:
	var path := "res://assets/models/%s.glb" % name
	var ps: PackedScene = _scene_cache.get(name)
	if ps == null:
		if not ResourceLoader.exists(path):
			return null
		ps = load(path)
		_scene_cache[name] = ps
	var n: Node3D = ps.instantiate()
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var nm: String = mi.name.to_lower()
		if nm.contains("leaf") or nm.contains("frond") or nm.contains("crown_l"):
			mi.material_override = model_mat(true)
		else:
			mi.material_override = model_mat(false)
	return n


static func model_mat(foliage: bool) -> ShaderMaterial:
	var key := "model|%s" % foliage
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := ShaderMaterial.new()
	m.shader = TOON_FOLIAGE if foliage else TOON
	m.set_shader_parameter("albedo", Color.WHITE)
	m.set_shader_parameter("use_vertex_color", true)
	m.set_shader_parameter("rim_amount", 0.2)
	m.set_shader_parameter("gloss", 0.03)
	m.set_shader_parameter("painted", PAINTED)
	m.set_shader_parameter("paint_amount", 0.14 if foliage else 0.16)
	if foliage:
		m.set_shader_parameter("wind_strength", 0.8)
		m.set_shader_parameter("near_fade", 1.0)
	else:
		m.next_pass = outline_mat(0.022)
	_mat_cache[key] = m
	return m


static func clear_caches() -> void:
	_scene_cache.clear()
	_mat_cache.clear()
	_outline_cache.clear()
	_unshaded_cache.clear()
	FX.clear_caches()


# ============================================================== Материалы
static func mat(color: Color, outline := true, wind := 0.0, fade := false, gloss := 0.15) -> ShaderMaterial:
	var key := "%s|%s|%s|%s|%s" % [color.to_html(), outline, wind, fade, gloss]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := ShaderMaterial.new()
	m.shader = TOON_FOLIAGE if fade else TOON
	m.set_shader_parameter("albedo", color)
	m.set_shader_parameter("wind_strength", wind)
	m.set_shader_parameter("near_fade", 1.0 if fade else 0.0)
	m.set_shader_parameter("gloss", gloss)
	m.set_shader_parameter("painted", PAINTED)
	if outline:
		m.next_pass = outline_mat(0.03, 0.35, color)
	_mat_cache[key] = m
	return m


static func vc_mat(base: Color, wind := 0.0, fade := false) -> ShaderMaterial:
	var key := "vc|%s|%s|%s" % [base.to_html(), wind, fade]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := ShaderMaterial.new()
	m.shader = TOON_FOLIAGE if fade else TOON
	m.set_shader_parameter("albedo", base)
	m.set_shader_parameter("use_vertex_color", true)
	m.set_shader_parameter("wind_strength", wind)
	m.set_shader_parameter("near_fade", 1.0 if fade else 0.0)
	m.set_shader_parameter("rim_amount", 0.0)
	_mat_cache[key] = m
	return m


## Обводка. tint — насколько она окрашена в тёмный оттенок цвета предмета base (0 — чисто коричневая).
static func outline_mat(width: float, tint := 0.0, base := Color.WHITE) -> ShaderMaterial:
	var key := "%s|%s|%s" % [width, tint, base.to_html()]
	if _outline_cache.has(key):
		return _outline_cache[key]
	var o := ShaderMaterial.new()
	o.shader = OUTLINE
	o.set_shader_parameter("width", width)
	o.set_shader_parameter("tint", tint)
	o.set_shader_parameter("base_tint", base)
	_outline_cache[key] = o
	return o


## Материал пламени (светится, подхватывается свечением экрана).
static func flame_mat(core: Color, edge: Color, energy := 3.0) -> ShaderMaterial:
	var key := "flame|%s|%s|%s" % [core.to_html(), edge.to_html(), energy]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := ShaderMaterial.new()
	m.shader = FLAME
	m.set_shader_parameter("core", core)
	m.set_shader_parameter("edge", edge)
	m.set_shader_parameter("energy", energy)
	_mat_cache[key] = m
	return m


## Огонь целиком: два языка пламени, мерцающий тёплый свет, дым и угольки.
## size — масштаб (1 — костёр, 0.45 — факел, 2 — чаша маяка). Узлы: Fire (языки) и Light — их ищут постройки.
static func flame(root: Node3D, pos: Vector3, size := 1.0, light_energy := 2.0, light_range := 9.0) -> Node3D:
	var fire := Node3D.new()
	fire.name = "Fire"
	fire.position = pos
	root.add_child(fire)
	for spec in [[0.3, 0.85, 0.42, Color("ffd36b"), Color("ff7a1e"), 3.2], [0.17, 0.55, 0.3, Color("fff6c8"), Color("ffc23a"), 4.5]]:
		var f := MeshInstance3D.new()
		f.mesh = cyl(0.0, spec[0] * size, spec[1] * size, 8)
		f.material_override = flame_mat(spec[3], spec[4], spec[5])
		f.position.y = spec[2] * size
		f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		fire.add_child(f)
	var light := OmniLight3D.new()
	light.name = "Light"
	light.light_color = Color("ffb35c")
	light.light_energy = light_energy
	light.omni_range = light_range
	light.omni_attenuation = 1.4
	light.light_specular = 0.2
	light.position = pos + Vector3(0, 0.9 * size, 0)
	root.add_child(light)
	FX.fire_smoke(fire, Vector3(0, 0.4 * size, 0), size)
	return fire


static func unshaded(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if _unshaded_cache.has(key):
		return _unshaded_cache[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	_unshaded_cache[key] = m
	return m


# ============================================================== Примитивы
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


static func sphere(r: float, segs := 14, rings := 8) -> SphereMesh:
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


static func cyl(r_top: float, r_bottom: float, h: float, segs := 10) -> CylinderMesh:
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
	c.height = maxf(h, r * 2.0)
	c.radial_segments = 12
	c.rings = 4
	return c


## Бугристая сфера — для камней, крон и кустов.
static func lumpy(r: float, seed_value: int, amount := 0.18, segs := 12, rings := 7) -> ArrayMesh:
	var sm := sphere(r, segs, rings)
	var arr := sm.get_mesh_arrays()
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = 0.9 / r
	for i in verts.size():
		var v := verts[i]
		verts[i] = v * (1.0 + noise.get_noise_3dv(v) * amount * 2.0)
	arr[Mesh.ARRAY_VERTEX] = verts
	var st := SurfaceTool.new()
	st.create_from_arrays(arr)
	st.generate_normals()
	return st.commit()


## Изогнутый лист (пальма, банан). Середина темнее — даёт рисованную прожилку.
static func leaf_mesh(length: float, width: float, droop := 0.55) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 7
	var rows: Array = []
	for i in segs + 1:
		var t := float(i) / segs
		var z := -t * length
		var y := -t * t * length * droop
		var w := width * sin(PI * clampf(t * 0.95 + 0.05, 0.0, 1.0))
		rows.append([Vector3(-w, y - 0.03, z), Vector3(0, y + 0.05, z), Vector3(w, y - 0.03, z)])
	var c_mid := Color(0.72, 0.8, 0.62)
	var c_edge := Color(1, 1, 1)
	for i in segs:
		var a: Array = rows[i]
		var b: Array = rows[i + 1]
		for side in [[0, 1], [1, 2]]:
			var p0: Vector3 = a[side[0]]
			var p1: Vector3 = a[side[1]]
			var p2: Vector3 = b[side[0]]
			var p3: Vector3 = b[side[1]]
			var c0 := c_edge if side[0] != 1 else c_mid
			var c1 := c_edge if side[1] != 1 else c_mid
			for tri in [[[p0, c0], [p2, c0], [p1, c1]], [[p1, c1], [p2, c0], [p3, c1]],
					[[p0, c0], [p1, c1], [p2, c0]], [[p1, c1], [p3, c1], [p2, c0]]]:
				for v in tri:
					st.set_color(v[1])
					st.add_vertex(v[0])
	st.generate_normals()
	return st.commit()


## Плоский цветок из 5 лепестков (для MultiMesh).
static func flower_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var petals := 5
	for i in petals:
		var a := TAU * i / petals
		var b := a + TAU / petals * 0.5
		var c := a - TAU / petals * 0.5
		st.set_color(Color.WHITE)
		st.add_vertex(Vector3(0, 0.01, 0))
		st.add_vertex(Vector3(cos(c) * 0.06, 0.0, sin(c) * 0.06))
		st.add_vertex(Vector3(cos(a) * 0.13, 0.02, sin(a) * 0.13))
		st.add_vertex(Vector3(0, 0.01, 0))
		st.add_vertex(Vector3(cos(a) * 0.13, 0.02, sin(a) * 0.13))
		st.add_vertex(Vector3(cos(b) * 0.06, 0.0, sin(b) * 0.06))
	# серединка
	for i in 6:
		var a := TAU * i / 6
		var b := TAU * (i + 1) / 6
		st.set_color(Color(1.0, 0.82, 0.25))
		st.add_vertex(Vector3(0, 0.03, 0))
		st.add_vertex(Vector3(cos(b) * 0.035, 0.025, sin(b) * 0.035))
		st.add_vertex(Vector3(cos(a) * 0.035, 0.025, sin(a) * 0.035))
	st.generate_normals()
	return st.commit()


# ============================================================== Природа
static func palm(rng: RandomNumberGenerator) -> Node3D:
	var g := glb(["palm_a", "palm_b", "palm_c"][rng.randi() % 3])
	if g:
		return g
	var root := Node3D.new()
	var height := rng.randf_range(4.2, 6.2)
	var lean := Vector3(rng.randf_range(-0.3, 0.3), 0, rng.randf_range(-0.3, 0.3))
	var trunk := Color("a87b4f")
	var segs := 7
	var top := Vector3.ZERO
	for i in segs:
		var t := float(i) / segs
		var seg_h := height / segs
		var offset := lean * pow(t, 1.6) * height
		var r := lerpf(0.24, 0.15, t)
		part(root, cyl(r * 0.85, r * 1.12, seg_h * 1.02, 9), trunk if i % 2 == 0 else trunk.darkened(0.14),
			Vector3(offset.x, seg_h * (i + 0.5), offset.z), Vector3(lean.z * 0.8, 0, -lean.x * 0.8))
		top = Vector3(offset.x, height, offset.z)
	var crown := Node3D.new()
	crown.name = "Crown"
	crown.position = top
	root.add_child(crown)
	var cols := [Color("2fa84a"), Color("3dbb52"), Color("28974a")]
	var n := rng.randi_range(7, 9)
	for i in n:
		var a := TAU * i / n + rng.randf() * 0.3
		var mi := MeshInstance3D.new()
		mi.mesh = leaf_mesh(rng.randf_range(2.5, 3.1), 0.55)
		mi.material_override = vc_mat(cols[i % 3], 1.0, true)
		mi.rotation = Vector3(rng.randf_range(-0.4, 0.05), a, 0)
		crown.add_child(mi)
	var coco := Node3D.new()
	coco.name = "Coconuts"
	crown.add_child(coco)
	for i in 3:
		var a := TAU * i / 3.0
		part(coco, sphere(0.17, 10, 6), Color("6b4423"), Vector3(cos(a) * 0.22, -0.22, sin(a) * 0.22))
	return root


static func banana_tree(rng: RandomNumberGenerator) -> Node3D:
	var g := glb("banana_tree")
	if g:
		return g
	var root := Node3D.new()
	var h := rng.randf_range(2.4, 3.0)
	part(root, cyl(0.16, 0.24, h, 9), Color("8f9a4a"), Vector3(0, h * 0.5, 0))
	part(root, cyl(0.17, 0.2, 0.25, 9), Color("7a8240"), Vector3(0, h * 0.35, 0))
	var crown := Node3D.new()
	crown.name = "Crown"
	crown.position.y = h
	root.add_child(crown)
	for i in 6:
		var a := TAU * i / 6.0 + rng.randf() * 0.3
		var mi := MeshInstance3D.new()
		mi.mesh = leaf_mesh(rng.randf_range(1.8, 2.3), 0.62, 0.35)
		mi.material_override = vc_mat(Color("5cc94a") if i % 2 == 0 else Color("49b844"), 0.8, true)
		mi.rotation = Vector3(rng.randf_range(-0.7, -0.3), a, 0)
		crown.add_child(mi)
	var fruit := Node3D.new()
	fruit.name = "Fruit"
	fruit.position = Vector3(0.22, h - 0.35, 0)
	root.add_child(fruit)
	part(fruit, cyl(0.03, 0.03, 0.5, 6), Color("6d7a35"), Vector3(0, 0.15, 0))
	for ring in 3:
		for k in 5:
			var a := TAU * k / 5.0 + ring * 0.4
			part(fruit, capsule(0.045, 0.26), Color("ffe14d"),
				Vector3(cos(a) * 0.11, -ring * 0.13, sin(a) * 0.11), Vector3(0.35 * cos(a), 0, -0.35 * sin(a) + 0.2))
	return root


static func round_tree(rng: RandomNumberGenerator, leaf: Color, fruit_col: Color, fruit_size := 0.12) -> Node3D:
	var root := Node3D.new()
	var h := rng.randf_range(1.6, 2.0)
	part(root, cyl(0.12, 0.2, h, 8), Color("8a5a32"), Vector3(0, h * 0.5, 0))
	part(root, cyl(0.05, 0.08, 0.9, 6), Color("8a5a32"), Vector3(0.25, h * 0.85, 0), Vector3(0, 0, -0.7))
	var crown := Node3D.new()
	crown.name = "Crown"
	crown.position.y = h + 0.6
	root.add_child(crown)
	var blobs := [Vector3(0, 0.2, 0), Vector3(0.6, 0, 0.2), Vector3(-0.55, 0.05, -0.1), Vector3(0.1, 0.05, 0.6), Vector3(-0.1, 0.0, -0.6)]
	for i in blobs.size():
		var r := 0.85 if i == 0 else rng.randf_range(0.55, 0.7)
		var mi := MeshInstance3D.new()
		mi.mesh = lumpy(r, rng.randi(), 0.12)
		mi.material_override = mat(leaf if i % 2 == 0 else leaf.lightened(0.08), true, 0.25, true)
		mi.position = blobs[i]
		crown.add_child(mi)
	var fruit := Node3D.new()
	fruit.name = "Fruit"
	fruit.position = crown.position
	root.add_child(fruit)
	for i in 9:
		var a := TAU * i / 9.0 + rng.randf() * 0.4
		var y := rng.randf_range(-0.45, 0.35)
		var d := sqrt(maxf(0.0, 1.0 - y * y)) * 0.95
		part(fruit, sphere(fruit_size, 10, 6), fruit_col, Vector3(cos(a) * d, y, sin(a) * d), Vector3.ZERO, Vector3(1, 1.15, 1))
	return root


static func fruit_tree(kind: String, rng: RandomNumberGenerator) -> Node3D:
	if kind in ["mango", "lemon"]:
		var g := glb(kind + "_tree")
		if g:
			return g
	match kind:
		"banana": return banana_tree(rng)
		"mango": return round_tree(rng, Color("2f9a45"), Color("ff9f2e"), 0.13)
		"lemon": return round_tree(rng, Color("4fb84a"), Color("f7ef4a"), 0.1)
	return round_tree(rng, Color("2f9a45"), Color.RED)


static func sapling() -> Node3D:
	var g := glb("sapling")
	if g:
		return g
	var root := Node3D.new()
	part(root, cyl(0.08, 0.3, 0.12, 10), Color("7a5232"), Vector3(0, 0.05, 0))
	part(root, cyl(0.025, 0.035, 0.6, 6), Color("7a5a32"), Vector3(0, 0.35, 0))
	for i in 3:
		var a := TAU * i / 3.0
		part(root, sphere(0.12, 8, 5), Color("6fd04f"), Vector3(cos(a) * 0.12, 0.62 + i * 0.03, sin(a) * 0.12), Vector3.ZERO, Vector3(1, 0.4, 1.6))
	return root


static func rock(rng: RandomNumberGenerator, big := true) -> Node3D:
	var g := glb(["rock_a", "rock_b", "rock_c"][rng.randi() % 3] if big else ["pebble_a", "pebble_b"][rng.randi() % 2])
	if g:
		return g
	var root := Node3D.new()
	var base := Color("a7abb0").lerp(Color("bdb3a3"), rng.randf())
	var count := 3 if big else 1
	for i in count:
		var s := rng.randf_range(0.75, 1.2) * (1.0 if big else 0.22)
		var p := Vector3(0, s * 0.4, 0)
		if big and i > 0:
			p = Vector3(rng.randf_range(-0.6, 0.6), s * 0.3, rng.randf_range(-0.6, 0.6))
			s *= 0.6
		var mi := MeshInstance3D.new()
		mi.mesh = lumpy(1.0, rng.randi(), 0.2, 9, 6)
		mi.material_override = mat(base.darkened(0.07 * i), true, 0.0, false, 0.05)
		mi.position = p
		mi.rotation = Vector3(0, rng.randf() * TAU, 0)
		mi.scale = Vector3(s * rng.randf_range(1.0, 1.3), s * 0.72, s)
		root.add_child(mi)
		if big and i == 0:
			# мох сверху
			part(root, lumpy(0.55, rng.randi(), 0.15), Color("5fb04a"), p + Vector3(0, s * 0.55, 0), Vector3.ZERO, Vector3(s, 0.25, s * 0.8), false)
	return root


static func bush(rng: RandomNumberGenerator) -> Node3D:
	var g := glb(["bush_a", "bush_b", "bush_c"][rng.randi() % 3])
	if g:
		return g
	var root := Node3D.new()
	var col := Color("2f9a3e").lerp(Color("4cb63f"), rng.randf())
	for i in 4:
		var s := rng.randf_range(0.42, 0.62)
		var mi := MeshInstance3D.new()
		mi.mesh = lumpy(s, rng.randi(), 0.14)
		mi.material_override = mat(col.lightened(0.07 * i), true, 0.3)
		mi.position = Vector3(rng.randf_range(-0.42, 0.42), s * 0.85, rng.randf_range(-0.42, 0.42))
		root.add_child(mi)
	var palette := [Color("ff6fa5"), Color("ffd84a"), Color("ffffff"), Color("ff8a3d")]
	var fc: Color = palette[rng.randi() % palette.size()]
	for i in 5:
		var a := rng.randf() * TAU
		part(root, sphere(0.07, 8, 5), fc, Vector3(cos(a) * 0.5, 0.75 + rng.randf() * 0.35, sin(a) * 0.5), Vector3.ZERO, Vector3.ONE, false)
	return root


static func driftwood(rng: RandomNumberGenerator) -> Node3D:
	var g := glb("driftwood")
	if g:
		g.rotation.y = rng.randf() * TAU
		return g
	var root := Node3D.new()
	var col := Color("c8a985")
	part(root, cyl(0.12, 0.15, 1.6, 8), col, Vector3(0, 0.12, 0), Vector3(0, 0, PI / 2))
	part(root, cyl(0.06, 0.08, 0.6, 6), col.darkened(0.1), Vector3(0.3, 0.2, 0.15), Vector3(0.6, 0.4, PI / 2.5))
	root.rotation.y = rng.randf() * TAU
	return root


static func shell(rng: RandomNumberGenerator) -> Node3D:
	var g := glb("shell")
	if g:
		return g
	var root := Node3D.new()
	var col: Color = [Color("f6c7c0"), Color("ffe4b5"), Color("f7a8b8"), Color("ffffff")][rng.randi() % 4]
	part(root, cyl(0.02, 0.17, 0.12, 10), col, Vector3(0, 0.05, 0), Vector3(0.2, rng.randf() * TAU, 0))
	for i in 4:
		part(root, box(Vector3(0.015, 0.02, 0.16)), col.darkened(0.15), Vector3(0, 0.1, 0), Vector3(0.25, i * 0.5 - 0.75, 0), Vector3.ONE, false)
	return root


static func supply_crate(opened := false) -> Node3D:
	var g := glb("supply_crate")
	if g:
		if opened:
			var lid := g.find_child("Lid", true, false) as Node3D
			lid.position += Vector3(0, -0.3, 0.55)
			lid.rotation.x = 1.3
		return g
	var root := Node3D.new()
	var wood := Color("b07a45")
	part(root, box(Vector3(1.0, 0.7, 0.7)), wood, Vector3(0, 0.35, 0))
	for x in [-0.46, 0.46]:
		part(root, box(Vector3(0.1, 0.72, 0.72)), wood.darkened(0.2), Vector3(x, 0.36, 0))
	part(root, box(Vector3(1.02, 0.1, 0.72)), wood.darkened(0.2), Vector3(0, 0.35, 0))
	var lid := part(root, box(Vector3(1.04, 0.1, 0.74)), wood.lightened(0.05), Vector3(0, 0.75, 0))
	lid.name = "Lid"
	if opened:
		lid.position = Vector3(0, 0.45, 0.55)
		lid.rotation.x = 1.3
	# надпись-полоска
	part(root, box(Vector3(0.5, 0.18, 0.02)), Color("f2ead3"), Vector3(0, 0.4, 0.36), Vector3.ZERO, Vector3.ONE, false)
	return root


static func boat_wreck() -> Node3D:
	var g := glb("boat_wreck")
	if g:
		return g
	var root := Node3D.new()
	var wood := Color("9a6a3e")
	# корпус на боку
	var hull := Node3D.new()
	hull.rotation = Vector3(0, 0.4, 0.5)
	hull.position = Vector3(0, 0.5, 0)
	root.add_child(hull)
	for i in 6:
		var y := -0.5 + i * 0.2
		part(hull, box(Vector3(3.6 - abs(i - 2.5) * 0.35, 0.18, 0.08)), wood.darkened(0.08 * (i % 2)), Vector3(0, y, -0.6 + abs(i - 2.5) * 0.12))
	part(hull, box(Vector3(3.4, 0.12, 1.3)), wood.darkened(0.2), Vector3(0, -0.6, 0))
	part(hull, box(Vector3(0.12, 1.2, 1.2)), wood.darkened(0.1), Vector3(-1.7, 0, 0))
	# сломанная мачта — насест попугая
	part(root, cyl(0.08, 0.1, 2.6, 8), Color("7a5232"), Vector3(1.4, 1.3, 0.6), Vector3(0, 0, -0.15))
	part(root, cyl(0.05, 0.05, 1.2, 6), Color("7a5232"), Vector3(1.6, 2.4, 0.6), Vector3(0, 0, PI / 2))
	# обрывок паруса
	part(root, box(Vector3(0.9, 0.7, 0.03)), Color("f2ead3"), Vector3(1.2, 1.9, 0.62), Vector3(0, 0, 0.2))
	return root


static func distant_island(rng: RandomNumberGenerator, radius: float) -> Node3D:
	var root := Node3D.new()
	part(root, cyl(radius * 0.9, radius, 1.2, 16), Color("f5d78a"), Vector3(0, 0.2, 0), Vector3.ZERO, Vector3.ONE, false)
	part(root, lumpy(radius * 0.8, rng.randi(), 0.12), Color("3fa64a"), Vector3(0, 0.3, 0), Vector3.ZERO, Vector3(1, rng.randf_range(0.35, 0.7), 1), false)
	part(root, cyl(0, radius * 0.4, radius * rng.randf_range(0.6, 1.0), 8), Color("8a9296"),
		Vector3(rng.randf_range(-3, 3), radius * 0.5, rng.randf_range(-3, 3)), Vector3.ZERO, Vector3.ONE, false)
	return root


static func cloud(rng: RandomNumberGenerator) -> Node3D:
	var root := Node3D.new()
	var m: ShaderMaterial = _mat_cache.get("cloud")
	if m == null:
		m = ShaderMaterial.new()
		m.shader = CLOUD
		_mat_cache["cloud"] = m
	for i in rng.randi_range(3, 6):
		var mi := MeshInstance3D.new()
		mi.mesh = sphere(rng.randf_range(3.0, 6.0), 12, 7)
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(i * 4.0 - 8.0 + rng.randf_range(-1, 1), rng.randf_range(-1, 1.5), rng.randf_range(-2, 2))
		mi.scale = Vector3(1, 0.6, 1)
		root.add_child(mi)
	return root


# ============================================================== Грядки и урожай
static func garden_bed() -> Node3D:
	var g := glb("garden_bed")
	if g:
		return g
	var root := Node3D.new()
	var wood := Color("b8834b")
	for z in [-0.55, 0.55]:
		part(root, box(Vector3(1.75, 0.22, 0.12)), wood, Vector3(0, 0.11, z))
	for x in [-0.83, 0.83]:
		part(root, box(Vector3(0.12, 0.22, 1.2)), wood.darkened(0.1), Vector3(x, 0.11, 0))
	var soil := part(root, box(Vector3(1.56, 0.16, 1.0)), Color("7a4a2a"), Vector3(0, 0.1, 0), Vector3.ZERO, Vector3.ONE, false)
	soil.name = "Soil"
	for z in [-0.3, 0.0, 0.3]:
		var ridge := part(root, box(Vector3(1.5, 0.06, 0.14)), Color("8f5a34"), Vector3(0, 0.2, z), Vector3.ZERO, Vector3.ONE, false)
		ridge.name = "Ridge"
	return root


## Модель растения на грядке: stage 1 — ростки, 2 — подросшие, 3 — созрело.
static func crop(kind: String, stage: int) -> Node3D:
	var g := glb("crop_sprout" if stage == 1 else ("crop_young" if stage == 2 else "crop_" + kind))
	if g:
		return g
	var root := Node3D.new()
	var green := Color("5cc94a")
	var spots := []
	for z in [-0.3, 0.0, 0.3]:
		for x in [-0.5, 0.0, 0.5]:
			spots.append(Vector3(x, 0.22, z))
	if stage == 1:
		for p in spots:
			for side in [-1, 1]:
				part(root, sphere(0.06, 6, 4), green, p + Vector3(0.04 * side, 0.04, 0), Vector3(0, 0, 0.5 * side), Vector3(1.3, 0.4, 0.8), false)
		return root
	if stage == 2:
		for p in spots:
			for k in 3:
				var a := TAU * k / 3.0
				part(root, sphere(0.09, 6, 4), green.darkened(0.05 * k), p + Vector3(cos(a) * 0.06, 0.1, sin(a) * 0.06), Vector3(0, -a, 0.6), Vector3(1.5, 0.4, 0.8), false)
		return root
	match kind:
		"carrot":
			for p in spots:
				part(root, cyl(0.0, 0.07, 0.16, 8), Color("f58a1f"), p + Vector3(0, 0.02, 0), Vector3(PI, 0, 0))
				for k in 4:
					var a := TAU * k / 4.0
					part(root, cyl(0.0, 0.03, 0.3, 4), Color("3fae49"), p + Vector3(cos(a) * 0.03, 0.2, sin(a) * 0.03), Vector3(cos(a) * 0.35, 0, sin(a) * 0.35), Vector3.ONE, false)
		"potato":
			for p in spots:
				part(root, lumpy(0.14, int(p.x * 100 + p.z * 1000), 0.15), Color("4fae3c"), p + Vector3(0, 0.12, 0), Vector3.ZERO, Vector3(1, 0.8, 1))
				part(root, sphere(0.035, 6, 4), Color("f4f0ff"), p + Vector3(0.05, 0.26, 0.02), Vector3.ZERO, Vector3.ONE, false)
				part(root, sphere(0.06, 8, 5), Color("c8a064"), p + Vector3(-0.1, 0.02, 0.08))
		"corn":
			for i in [0, 2, 4, 6, 8]:
				var p: Vector3 = spots[i]
				part(root, cyl(0.025, 0.035, 1.2, 6), Color("6db33f"), p + Vector3(0, 0.6, 0))
				for k in 3:
					var a: float = TAU * k / 3.0 + i
					part(root, box(Vector3(0.05, 0.5, 0.01)), Color("7cc444"), p + Vector3(cos(a) * 0.1, 0.5 + k * 0.2, sin(a) * 0.1), Vector3(sin(a) * 0.6, a, cos(a) * 0.6), Vector3.ONE, false)
				part(root, capsule(0.05, 0.24), Color("ffd23f"), p + Vector3(0.06, 0.85, 0), Vector3(0, 0, -0.3))
		"tomato":
			for i in [1, 3, 4, 5, 7]:
				var p: Vector3 = spots[i]
				part(root, cyl(0.015, 0.015, 0.8, 4), Color("a07040"), p + Vector3(0, 0.4, 0), Vector3.ZERO, Vector3.ONE, false)
				part(root, lumpy(0.16, i * 31, 0.18), Color("3f9f3a"), p + Vector3(0, 0.45, 0), Vector3.ZERO, Vector3(1, 1.4, 1))
				for k in 3:
					var a: float = TAU * k / 3.0 + i
					part(root, sphere(0.06, 8, 5), Color("e8443a"), p + Vector3(cos(a) * 0.14, 0.35 + k * 0.1, sin(a) * 0.14))
		"cabbage":
			for i in [0, 2, 4, 6, 8]:
				var p: Vector3 = spots[i]
				part(root, sphere(0.17, 12, 7), Color("bfe88a"), p + Vector3(0, 0.12, 0), Vector3.ZERO, Vector3(1, 0.85, 1))
				for k in 4:
					var a := TAU * k / 4.0
					part(root, sphere(0.14, 8, 5), Color("8fcf5a"), p + Vector3(cos(a) * 0.13, 0.06, sin(a) * 0.13), Vector3(0, -a, 0.8), Vector3(1.2, 0.35, 0.9), false)
		"watermelon":
			for p in [Vector3(-0.35, 0.22, 0), Vector3(0.38, 0.22, 0.1)]:
				part(root, sphere(0.28, 14, 8), Color("2f8f3a"), p + Vector3(0, 0.14, 0), Vector3(0, 0.3, 0), Vector3(1.25, 0.85, 0.9))
				for k in 4:
					part(root, box(Vector3(0.62, 0.03, 0.03)), Color("8fd46a"), p + Vector3(0, 0.25 + k * 0.0, -0.2 + k * 0.13), Vector3(0, 0.3, 0), Vector3.ONE, false)
			for x in [-0.6, 0.0, 0.6]:
				part(root, sphere(0.1, 6, 4), green, Vector3(x, 0.26, -0.3), Vector3.ZERO, Vector3(1.4, 0.4, 0.9), false)
		_:
			for p in spots:
				part(root, sphere(0.12, 8, 5), green, p + Vector3(0, 0.1, 0))
	return root


# ============================================================== Животные и NPC
static func chicken() -> Node3D:
	var g := glb("chicken")
	if g:
		return g
	var root := Node3D.new()
	var body := Node3D.new()
	body.name = "Body"
	root.add_child(body)
	part(body, sphere(0.2, 12, 8), Color("fbfbf4"), Vector3(0, 0.3, 0), Vector3.ZERO, Vector3(1, 0.9, 1.2))
	part(body, cyl(0.0, 0.12, 0.2, 6), Color("f0efe6"), Vector3(0, 0.42, 0.2), Vector3(-0.9, 0, 0))
	for side in [-1, 1]:
		part(body, sphere(0.1, 8, 5), Color("eeece0"), Vector3(0.17 * side, 0.3, 0.02), Vector3.ZERO, Vector3(0.4, 0.8, 1.2))
	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 0.5, -0.17)
	body.add_child(head)
	part(head, sphere(0.11, 10, 6), Color("fbfbf4"))
	part(head, cyl(0.0, 0.035, 0.09, 6), Color("ffb02e"), Vector3(0, -0.01, -0.12), Vector3(-PI / 2, 0, 0), Vector3.ONE, false)
	for i in 3:
		part(head, sphere(0.035, 6, 4), Color("e8443a"), Vector3(0, 0.1 + i * 0.0, -0.04 + i * 0.04), Vector3.ZERO, Vector3.ONE, false)
	part(head, sphere(0.03, 6, 4), Color("e8443a"), Vector3(0, -0.07, -0.09), Vector3.ZERO, Vector3(1, 1.4, 1), false)
	for side in [-1, 1]:
		part(head, sphere(0.022, 6, 4), Color("1d1d1d"), Vector3(0.07 * side, 0.03, -0.07), Vector3.ZERO, Vector3.ONE, false)
	for side in [-1, 1]:
		part(root, cyl(0.015, 0.015, 0.16, 5), Color("ffb02e"), Vector3(0.07 * side, 0.08, 0), Vector3.ZERO, Vector3.ONE, false)
	return root


static func goat() -> Node3D:
	var g := glb("goat")
	if g:
		return g
	var root := Node3D.new()
	var fur := Color("f4efe4")
	var patch := Color("b98a5a")
	var body := Node3D.new()
	body.name = "Body"
	root.add_child(body)
	part(body, capsule(0.24, 0.85), fur, Vector3(0, 0.6, 0), Vector3(PI / 2, 0, 0))
	part(body, sphere(0.16, 8, 5), patch, Vector3(0.12, 0.72, 0.1), Vector3.ZERO, Vector3(0.9, 0.6, 1.3), false)
	part(body, cyl(0.0, 0.06, 0.15, 5), fur, Vector3(0, 0.75, 0.43), Vector3(-0.6, 0, 0))
	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 0.88, -0.42)
	body.add_child(head)
	part(head, capsule(0.13, 0.36), fur, Vector3(0, 0, -0.06), Vector3(-1.1, 0, 0))
	part(head, sphere(0.06, 6, 4), Color("f2b8b0"), Vector3(0, -0.1, -0.24), Vector3.ZERO, Vector3(1.2, 0.8, 0.8), false)
	part(head, cyl(0.0, 0.05, 0.16, 5), patch, Vector3(0, -0.2, -0.16), Vector3(PI, 0, 0), Vector3.ONE, false)
	for side in [-1, 1]:
		part(head, cyl(0.0, 0.035, 0.24, 6), Color("8a7a66"), Vector3(0.06 * side, 0.16, 0.04), Vector3(0.6, 0, -0.25 * side))
		part(head, sphere(0.06, 6, 4), fur, Vector3(0.14 * side, 0.06, 0.03), Vector3(0, 0, 0.6 * side), Vector3(1.5, 0.5, 0.8))
		part(head, sphere(0.025, 6, 4), Color("1d1d1d"), Vector3(0.08 * side, 0.04, -0.12), Vector3.ZERO, Vector3.ONE, false)
	for x in [-0.13, 0.13]:
		for z in [-0.25, 0.25]:
			part(root, cyl(0.045, 0.04, 0.42, 6), fur, Vector3(x, 0.21, z))
			part(root, cyl(0.045, 0.045, 0.06, 6), Color("5a4636"), Vector3(x, 0.03, z), Vector3.ZERO, Vector3.ONE, false)
	return root


static func parrot() -> Node3D:
	var g := glb("parrot")
	if g:
		return g
	var root := Node3D.new()
	var body := Node3D.new()
	body.name = "Body"
	root.add_child(body)
	part(body, capsule(0.13, 0.42), Color("e8443a"), Vector3(0, 0.22, 0), Vector3(0.25, 0, 0))
	part(body, sphere(0.07, 8, 5), Color("ffd23f"), Vector3(0, 0.2, -0.1), Vector3.ZERO, Vector3(1.3, 1.5, 0.6), false)
	for side in [-1, 1]:
		var w := part(body, capsule(0.07, 0.34), Color("2f6fe0"), Vector3(0.13 * side, 0.22, 0.03), Vector3(0.35, 0, 0.15 * side))
		w.name = "WingL" if side < 0 else "WingR"
	part(body, box(Vector3(0.08, 0.04, 0.42)), Color("2f6fe0"), Vector3(0, 0.02, 0.27), Vector3(0.9, 0, 0))
	part(body, box(Vector3(0.05, 0.03, 0.36)), Color("ffd23f"), Vector3(0, 0.0, 0.3), Vector3(0.95, 0, 0), Vector3.ONE, false)
	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 0.46, -0.03)
	body.add_child(head)
	part(head, sphere(0.12, 12, 8), Color("e8443a"))
	part(head, sphere(0.06, 8, 5), Color("f2ead3"), Vector3(0, 0.0, -0.08), Vector3.ZERO, Vector3(1.6, 1.0, 0.6), false)
	part(head, cyl(0.0, 0.045, 0.12, 6), Color("3a2f2a"), Vector3(0, -0.03, -0.14), Vector3(-PI / 2 - 0.5, 0, 0), Vector3.ONE, false)
	for side in [-1, 1]:
		part(head, sphere(0.035, 8, 5), Color("ffffff"), Vector3(0.07 * side, 0.03, -0.08), Vector3.ZERO, Vector3.ONE, false)
		part(head, sphere(0.02, 6, 4), Color("1d1d1d"), Vector3(0.08 * side, 0.03, -0.1), Vector3.ZERO, Vector3.ONE, false)
	for side in [-1, 1]:
		part(root, cyl(0.012, 0.012, 0.08, 4), Color("5a5a5a"), Vector3(0.05 * side, 0.02, 0), Vector3.ZERO, Vector3.ONE, false)
	return root


static func crab() -> Node3D:
	var g := glb("crab")
	if g:
		return g
	var root := Node3D.new()
	var red := Color("ff5a3a")
	part(root, sphere(0.14, 10, 6), red, Vector3(0, 0.1, 0), Vector3.ZERO, Vector3(1.3, 0.55, 1))
	for side in [-1, 1]:
		part(root, sphere(0.06, 8, 5), red.lightened(0.1), Vector3(0.2 * side, 0.12, -0.1), Vector3.ZERO, Vector3(1, 0.7, 1.3))
		part(root, cyl(0.01, 0.01, 0.07, 4), red, Vector3(0.04 * side, 0.18, -0.08), Vector3.ZERO, Vector3.ONE, false)
		part(root, sphere(0.02, 6, 4), Color("1d1d1d"), Vector3(0.04 * side, 0.22, -0.08), Vector3.ZERO, Vector3.ONE, false)
		for k in 3:
			part(root, cyl(0.012, 0.012, 0.14, 4), red.darkened(0.15), Vector3(0.16 * side, 0.05, -0.04 + k * 0.06), Vector3(0, 0, 0.9 * side), Vector3.ONE, false)
	return root


static func butterfly(color: Color) -> Node3D:
	var root := Node3D.new()
	part(root, capsule(0.015, 0.12), Color("3a2f2a"), Vector3.ZERO, Vector3(PI / 2, 0, 0), Vector3.ONE, false)
	var m := ShaderMaterial.new()
	m.shader = WING
	m.set_shader_parameter("color", color)
	m.set_shader_parameter("spot", color.darkened(0.6))
	for side in [-1, 1]:
		var pivot := Node3D.new()
		pivot.name = "WingL" if side < 0 else "WingR"
		root.add_child(pivot)
		var q := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(0.16, 0.14)
		q.mesh = qm
		q.material_override = m
		q.rotation.x = -PI / 2
		q.position = Vector3(0.08 * side, 0, 0)
		q.scale.x = side
		q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pivot.add_child(q)
	return root


# ============================================================== Постройки
static func building(id: String) -> Node3D:
	var names := {"fruit_tree": "sapling"}
	var g := glb(names.get(id, id))
	if g:
		match id:
			"campfire": _add_fire(g)
			"torch": _add_torch_flame(g)
		return g
	match id:
		"tent": return tent()
		"campfire": return campfire()
		"torch": return torch()
		"workbench": return workbench()
		"hut": return hut()
		"raft": return raft()
		"garden_bed": return garden_bed()
		"fruit_tree": return sapling()
		"coop": return coop()
		"goat_pen": return goat_pen()
		"fence": return fence()
		"flowerbed": return flowerbed()
		"bench": return bench()
		"hammock": return hammock()
		"scarecrow": return scarecrow()
		"shell_path": return shell_path()
	return Node3D.new()


static func tent() -> Node3D:
	var root := Node3D.new()
	var cloth := Color("f2ead3")
	var stripe := Color("4f8fd8")
	for side in [-1, 1]:
		part(root, box(Vector3(0.05, 1.7, 2.2)), cloth, Vector3(0.55 * side, 0.72, 0), Vector3(0, 0, 0.62 * side))
		part(root, box(Vector3(0.06, 0.22, 2.22)), stripe, Vector3(0.38 * side, 1.0, 0), Vector3(0, 0, 0.62 * side), Vector3.ONE, false)
	part(root, box(Vector3(0.5, 0.45, 0.06)), Color("e8b45a"), Vector3(0.5, 0.75, 1.07), Vector3(0, 0, 0.62), Vector3.ONE, false)
	for z in [-1.15, 1.15]:
		part(root, cyl(0.04, 0.05, 1.55, 6), Color("7a5232"), Vector3(-0.35, 0.7, z), Vector3(0, 0, -0.45))
		part(root, cyl(0.04, 0.05, 1.55, 6), Color("7a5232"), Vector3(0.35, 0.7, z), Vector3(0, 0, 0.45))
	part(root, cyl(0.035, 0.035, 2.6, 6), Color("7a5232"), Vector3(0, 1.42, 0), Vector3(PI / 2, 0, 0))
	part(root, box(Vector3(1.3, 0.04, 1.8)), Color("c9a050"), Vector3(0, 0.03, 0), Vector3.ZERO, Vector3.ONE, false)
	return root


static func _add_fire(root: Node3D) -> void:
	var point := root.find_child("FirePoint", true, false) as Node3D
	flame(root, point.position if point else Vector3(0, 0.08, 0), 1.0, 2.0, 9.0)


static func _add_torch_flame(root: Node3D) -> void:
	var point := root.find_child("FirePoint", true, false) as Node3D
	flame(root, point.position if point else Vector3(0, 1.75, 0), 0.45, 1.4, 7.0)


static func campfire() -> Node3D:
	var root := Node3D.new()
	for i in 9:
		var a := TAU * i / 9.0
		part(root, lumpy(0.17, i * 7, 0.15, 8, 5), Color("9aa0a6"), Vector3(cos(a) * 0.6, 0.1, sin(a) * 0.6), Vector3.ZERO, Vector3(1, 0.7, 1))
	for i in 4:
		var a := TAU * i / 4.0 + 0.4
		part(root, cyl(0.06, 0.07, 0.9, 6), Color("7a5230"), Vector3(cos(a) * 0.18, 0.25, sin(a) * 0.18), Vector3(sin(a) * 0.9, 0, cos(a) * -0.9))
	flame(root, Vector3(0, 0.08, 0), 1.0, 2.0, 9.0)
	return root


static func torch() -> Node3D:
	var root := Node3D.new()
	part(root, cyl(0.05, 0.07, 1.6, 6), Color("6e4a2a"), Vector3(0, 0.8, 0))
	part(root, cyl(0.16, 0.1, 0.18, 8), Color("4a3b30"), Vector3(0, 1.62, 0))
	flame(root, Vector3(0, 1.72, 0), 0.45, 1.4, 7.0)
	return root


static func workbench() -> Node3D:
	var root := Node3D.new()
	var wood := Color("b8834b")
	part(root, box(Vector3(1.8, 0.14, 0.8)), wood, Vector3(0, 0.85, 0))
	for x in [-0.75, 0.75]:
		for z in [-0.3, 0.3]:
			part(root, box(Vector3(0.12, 0.8, 0.12)), wood.darkened(0.2), Vector3(x, 0.4, z))
	part(root, box(Vector3(1.5, 0.08, 0.08)), wood.darkened(0.2), Vector3(0, 0.25, 0.3))
	part(root, box(Vector3(0.5, 0.08, 0.3)), Color("9aa0a6"), Vector3(-0.4, 0.96, 0.1))
	part(root, cyl(0.04, 0.04, 0.5, 6), Color("6e4a2a"), Vector3(0.4, 0.97, -0.1), Vector3(0, 0.6, PI / 2))
	part(root, box(Vector3(0.6, 0.25, 0.4)), wood.lightened(0.1), Vector3(0.5, 0.2, 0))
	part(root, cyl(0.12, 0.12, 0.3, 10), Color("8a5a32"), Vector3(-0.55, 0.15, 0))
	return root


static func hut() -> Node3D:
	var root := Node3D.new()
	var bamboo := Color("e0c06a")
	var straw := Color("d6ad55")
	part(root, box(Vector3(3.5, 0.2, 3.5)), Color("a8784a"), Vector3(0, 0.1, 0))
	for x in [-1.6, 1.6]:
		for z in [-1.6, 1.6]:
			part(root, cyl(0.1, 0.1, 2.4, 6), Color("8a6a3a"), Vector3(x, 1.2, z))
	for side in 4:
		var a := side * PI / 2.0
		var dir := Vector3(sin(a), 0, cos(a))
		var right := Vector3(cos(a), 0, -sin(a))
		for i in 9:
			var t := (i - 4) * 0.36
			if side == 0 and abs(t) < 0.5:
				continue  # дверной проём
			if side == 1 and abs(t) < 0.4:
				part(root, cyl(0.085, 0.085, 0.9, 6), bamboo.darkened(0.08 * (i % 2)), dir * 1.55 + right * t + Vector3(0, 0.5, 0))
				continue  # окно
			part(root, cyl(0.085, 0.085, 2.1, 6), bamboo.darkened(0.08 * (i % 2)), dir * 1.55 + right * t + Vector3(0, 1.1, 0))
	# связки на стенах
	for side in 4:
		var a := side * PI / 2.0
		part(root, box(Vector3(3.3, 0.06, 0.24)), Color("8a6a3a"), Vector3(sin(a), 0, cos(a)) * 1.55 + Vector3(0, 1.75, 0), Vector3(0, a, 0), Vector3.ONE, false)
	part(root, cyl(0.0, 2.8, 1.6, 4), straw, Vector3(0, 2.9, 0), Vector3(0, PI / 4, 0))
	part(root, cyl(0.0, 2.3, 1.4, 4), straw.lightened(0.08), Vector3(0, 3.25, 0), Vector3(0, PI / 4, 0))
	part(root, cyl(0.0, 1.0, 0.8, 4), straw.darkened(0.06), Vector3(0, 3.8, 0), Vector3(0, PI / 4, 0))
	return root


static func raft() -> Node3D:
	var root := Node3D.new()
	var wood := Color("b8834b")
	for i in 6:
		part(root, cyl(0.17, 0.17, 3.0, 8), wood.darkened(0.06 * (i % 2)), Vector3((i - 2.5) * 0.36, 0.15, 0), Vector3(PI / 2, 0, 0))
	for z in [-1.1, 1.1]:
		part(root, box(Vector3(2.3, 0.08, 0.2)), Color("d4b483"), Vector3(0, 0.33, z))
	part(root, cyl(0.06, 0.06, 2.6, 6), Color("6e4a2a"), Vector3(0, 1.6, 0))
	var sail := part(root, box(Vector3(1.6, 1.5, 0.04)), Color("f2ead3"), Vector3(0, 1.9, 0.05))
	sail.name = "Sail"
	part(root, box(Vector3(1.6, 0.2, 0.05)), Color("4f8fd8"), Vector3(0, 2.2, 0.05), Vector3.ZERO, Vector3.ONE, false)
	return root


static func coop() -> Node3D:
	var root := Node3D.new()
	var wood := Color("c08a50")
	for x in [-0.55, 0.55]:
		for z in [-0.45, 0.45]:
			part(root, box(Vector3(0.1, 0.6, 0.1)), wood.darkened(0.25), Vector3(x, 0.3, z))
	part(root, box(Vector3(1.3, 0.8, 1.1)), wood, Vector3(0, 1.0, 0))
	for i in 4:
		part(root, box(Vector3(1.32, 0.04, 1.12)), wood.darkened(0.15), Vector3(0, 0.7 + i * 0.2, 0), Vector3.ZERO, Vector3.ONE, false)
	part(root, box(Vector3(0.32, 0.36, 0.04)), Color("3a2a1a"), Vector3(0, 0.9, -0.56), Vector3.ZERO, Vector3.ONE, false)
	part(root, cyl(0.0, 1.15, 0.7, 4), Color("d6ad55"), Vector3(0, 1.75, 0), Vector3(0, PI / 4, 0), Vector3(1.0, 1, 0.9))
	part(root, box(Vector3(0.32, 0.04, 0.9)), wood.darkened(0.1), Vector3(0, 0.35, -0.9), Vector3(0.75, 0, 0))
	# маленький заборчик вокруг
	for i in 12:
		var a := TAU * i / 12.0
		if abs(a - PI * 1.5) < 0.4:
			continue
		part(root, cyl(0.04, 0.05, 0.5, 5), Color("a87b4f"), Vector3(cos(a) * 1.5, 0.25, sin(a) * 1.5))
	return root


static func goat_pen() -> Node3D:
	var root := Node3D.new()
	var wood := Color("a87b4f")
	var s := 1.9
	for i in 4:
		var a := i * PI / 2.0
		var dir := Vector3(sin(a), 0, cos(a))
		var right := Vector3(cos(a), 0, -sin(a))
		for k in 5:
			var t := (k - 2) * s * 0.5
			part(root, cyl(0.05, 0.06, 0.9, 6), wood.darkened(0.15), dir * s + right * t + Vector3(0, 0.45, 0))
		for y in [0.35, 0.7]:
			if i == 0 and y < 0.5:
				continue
			part(root, box(Vector3(s * 2.0, 0.08, 0.06)), wood, dir * s + Vector3(0, y, 0), Vector3(0, a, 0))
	# навес
	part(root, box(Vector3(1.4, 0.08, 1.0)), Color("5fb04a"), Vector3(-0.9, 1.3, -0.9), Vector3(0.25, 0, 0))
	for x in [-1.5, -0.3]:
		for z in [-1.3, -0.5]:
			part(root, cyl(0.04, 0.04, 1.3, 5), wood.darkened(0.2), Vector3(x, 0.65, z))
	# кормушка
	part(root, box(Vector3(0.9, 0.25, 0.35)), wood.lightened(0.1), Vector3(0.9, 0.18, -1.3))
	part(root, box(Vector3(0.8, 0.06, 0.25)), Color("c9d45a"), Vector3(0.9, 0.3, -1.3), Vector3.ZERO, Vector3.ONE, false)
	return root


static func fence() -> Node3D:
	var root := Node3D.new()
	var wood := Color("a87b4f")
	for x in [-0.6, 0.6]:
		part(root, cyl(0.05, 0.06, 0.8, 6), wood.darkened(0.15), Vector3(x, 0.4, 0))
	for y in [0.3, 0.5, 0.68]:
		part(root, cyl(0.025, 0.025, 1.3, 5), Color("c9a467"), Vector3(0, y, 0), Vector3(0, 0, PI / 2))
	return root


static func flowerbed() -> Node3D:
	var root := Node3D.new()
	for i in 8:
		var a := TAU * i / 8.0
		part(root, lumpy(0.12, i * 3, 0.15, 8, 5), Color("a3a8ad"), Vector3(cos(a) * 0.5, 0.06, sin(a) * 0.5), Vector3.ZERO, Vector3(1, 0.7, 1))
	part(root, cyl(0.45, 0.45, 0.08, 12), Color("7a4a2a"), Vector3(0, 0.05, 0), Vector3.ZERO, Vector3.ONE, false)
	var cols := [Color("ff6fa5"), Color("ffd84a"), Color("ffffff"), Color("b28cff"), Color("ff8a3d")]
	for i in 9:
		var a := TAU * i / 9.0
		var r := 0.12 if i % 3 == 0 else 0.3
		var p := Vector3(cos(a) * r, 0.0, sin(a) * r)
		part(root, cyl(0.012, 0.012, 0.3, 4), Color("3fae49"), p + Vector3(0, 0.2, 0), Vector3.ZERO, Vector3.ONE, false)
		part(root, sphere(0.07, 8, 5), cols[i % cols.size()], p + Vector3(0, 0.36, 0), Vector3.ZERO, Vector3(1, 0.6, 1))
	return root


static func bench() -> Node3D:
	var root := Node3D.new()
	var wood := Color("b8834b")
	for z in [-0.12, 0.12]:
		part(root, box(Vector3(1.4, 0.06, 0.2)), wood, Vector3(0, 0.45, z))
	part(root, box(Vector3(1.4, 0.3, 0.06)), wood.darkened(0.08), Vector3(0, 0.75, 0.24), Vector3(-0.15, 0, 0))
	for x in [-0.6, 0.6]:
		part(root, box(Vector3(0.08, 0.45, 0.4)), wood.darkened(0.2), Vector3(x, 0.22, 0))
	return root


static func hammock() -> Node3D:
	var root := Node3D.new()
	for x in [-1.2, 1.2]:
		part(root, cyl(0.07, 0.08, 1.6, 6), Color("8a5a32"), Vector3(x, 0.8, 0))
	for i in 7:
		var t := (i - 3) / 3.0
		var y := 0.55 + t * t * 0.45
		part(root, box(Vector3(0.36, 0.04, 0.8)), Color("e8443a") if i % 2 == 0 else Color("f2ead3"), Vector3(t * 1.05, y, 0), Vector3(0, 0, -t * 0.5), Vector3.ONE, i == 3)
	return root


static func scarecrow() -> Node3D:
	var root := Node3D.new()
	part(root, cyl(0.04, 0.05, 1.8, 6), Color("8a5a32"), Vector3(0, 0.9, 0))
	part(root, cyl(0.035, 0.035, 1.2, 6), Color("8a5a32"), Vector3(0, 1.35, 0), Vector3(0, 0, PI / 2))
	part(root, box(Vector3(0.55, 0.6, 0.25)), Color("6f9bd1"), Vector3(0, 1.2, 0))
	part(root, box(Vector3(0.2, 0.2, 0.26)), Color("e8b45a"), Vector3(0.12, 1.1, 0), Vector3.ZERO, Vector3.ONE, false)
	part(root, sphere(0.2, 10, 6), Color("e8cf8a"), Vector3(0, 1.75, 0))
	part(root, cyl(0.12, 0.38, 0.08, 10), Color("c9a050"), Vector3(0, 1.9, 0))
	part(root, cyl(0.1, 0.14, 0.2, 10), Color("c9a050"), Vector3(0, 2.0, 0))
	for side in [-1, 1]:
		part(root, cyl(0.0, 0.06, 0.2, 5), Color("e8cf8a"), Vector3(0.62 * side, 1.35, 0), Vector3(0, 0, PI / 2 * side), Vector3.ONE, false)
		part(root, box(Vector3(0.05, 0.05, 0.02)), Color("1d1d1d"), Vector3(0.07 * side, 1.8, -0.19), Vector3.ZERO, Vector3.ONE, false)
	return root


static func shell_path() -> Node3D:
	var root := Node3D.new()
	part(root, cyl(0.5, 0.52, 0.08, 10), Color("d9d2c4"), Vector3(0, 0.04, 0), Vector3.ZERO, Vector3(1, 1, 0.85))
	for i in 3:
		var a := TAU * i / 3.0 + 0.3
		part(root, cyl(0.01, 0.09, 0.06, 8), [Color("f6c7c0"), Color("ffe4b5"), Color("f7a8b8")][i], Vector3(cos(a) * 0.25, 0.1, sin(a) * 0.22), Vector3(0.2, a, 0), Vector3.ONE, false)
	return root


# ============================================================== Инструменты
static func tool_model(id: String) -> Node3D:
	var g := glb("tool_" + id)
	if g:
		return g
	var root := Node3D.new()
	match id:
		"stone_axe":
			part(root, cyl(0.03, 0.035, 0.7, 6), Color("7a5230"), Vector3(0, -0.25, 0))
			part(root, box(Vector3(0.08, 0.18, 0.24)), Color("9aa0a6"), Vector3(0, -0.55, -0.1))
		"pickaxe":
			part(root, cyl(0.03, 0.035, 0.75, 6), Color("7a5230"), Vector3(0, -0.25, 0))
			part(root, box(Vector3(0.06, 0.08, 0.6)), Color("9a8fb0"), Vector3(0, -0.58, 0))
		"watering_can":
			part(root, cyl(0.11, 0.12, 0.22, 10), Color("5fb0e8"), Vector3(0, -0.15, -0.05), Vector3(PI / 2, 0, 0))
			part(root, cyl(0.02, 0.03, 0.25, 6), Color("5fb0e8"), Vector3(0, -0.1, -0.25), Vector3(0.6, 0, 0))
		"net":
			part(root, cyl(0.02, 0.025, 0.8, 6), Color("c9a467"), Vector3(0, -0.3, 0))
			part(root, cyl(0.14, 0.14, 0.02, 10), Color("f2f2f2"), Vector3(0, -0.75, 0), Vector3(PI / 2, 0, 0), Vector3.ONE, false)
	return root
