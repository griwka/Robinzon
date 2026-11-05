class_name Island
extends Node3D
## Процедурный остров: рельеф (low-poly, плоские грани), вода, трава и ресурсы.
## Высота считается аналитически (height_at), поэтому ею пользуются и строительство, и вода.

const SIZE := 200.0         # размер квадрата рельефа, м
const RES := 150            # клеток по стороне
const RADIUS := 52.0        # средний радиус острова
const MAP_RES := 256        # разрешение карты высот для шейдера воды
const H_MIN := -6.0
const H_MAX := 14.0

const SAND := Color("f2d48a")
const SAND_WET := Color("d9b56a")
const GRASS := Color("6cc04a")
const GRASS_DARK := Color("4fa53d")
const ROCK := Color("9a958c")
const SEABED := Color("e8c77a")

var seed_value := 1337
var shape_noise := FastNoiseLite.new()
var hill_noise := FastNoiseLite.new()
var detail_noise := FastNoiseLite.new()
var peak_center := Vector2(14, -10)
var rng := RandomNumberGenerator.new()
var spawn_point := Vector3.ZERO


func _init() -> void:
	rng.seed = seed_value
	shape_noise.seed = seed_value
	shape_noise.frequency = 0.9
	hill_noise.seed = seed_value + 1
	hill_noise.frequency = 0.035
	detail_noise.seed = seed_value + 2
	detail_noise.frequency = 0.25


func build() -> void:
	_build_terrain()
	_build_water()
	_build_grass()
	_spawn_resources()
	_find_spawn()


# ------------------------------------------------------------------ Высота
func height_at(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var d := p.length()
	var ang := atan2(z, x)
	# неровная береговая линия
	var r := RADIUS * (1.0 + 0.22 * shape_noise.get_noise_2d(cos(ang) * 1.5, sin(ang) * 1.5)
		+ 0.08 * shape_noise.get_noise_2d(cos(ang) * 4.0 + 10.0, sin(ang) * 4.0))
	var t := d / r
	# дно -> пляж
	var h := lerpf(H_MIN, 0.5, smoothstep(1.35, 0.95, t))
	# пологий подъём вглубь острова
	var inland := smoothstep(0.92, 0.55, t)
	h += inland * (1.4 + 1.6 * (hill_noise.get_noise_2d(x, z) * 0.5 + 0.5))
	# гора-вершина (место для будущего "восхождения")
	var pd := p.distance_to(peak_center)
	h += 10.0 * exp(-pd * pd / (2.0 * 13.0 * 13.0)) * inland
	h += detail_noise.get_noise_2d(x, z) * 0.18 * inland
	return h


func normal_at(x: float, z: float) -> Vector3:
	var e := 0.5
	var hx := height_at(x + e, z) - height_at(x - e, z)
	var hz := height_at(x, z + e) - height_at(x, z - e)
	return Vector3(-hx, 2.0 * e, -hz).normalized()


# ------------------------------------------------------------------ Рельеф
func _build_terrain() -> void:
	var step := SIZE / RES
	var half := SIZE * 0.5
	var hs := PackedFloat32Array()
	hs.resize((RES + 1) * (RES + 1))
	for j in RES + 1:
		for i in RES + 1:
			hs[j * (RES + 1) + i] = height_at(-half + i * step, -half + j * step)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)  # плоские нормали = low-poly вид
	var tint := RandomNumberGenerator.new()
	tint.seed = seed_value
	for j in RES:
		for i in RES:
			var x0 := -half + i * step
			var z0 := -half + j * step
			var v00 := Vector3(x0, hs[j * (RES + 1) + i], z0)
			var v10 := Vector3(x0 + step, hs[j * (RES + 1) + i + 1], z0)
			var v01 := Vector3(x0, hs[(j + 1) * (RES + 1) + i], z0 + step)
			var v11 := Vector3(x0 + step, hs[(j + 1) * (RES + 1) + i + 1], z0 + step)
			if v00.y < H_MIN + 0.01 and v11.y < H_MIN + 0.01 and v10.y < H_MIN + 0.01:
				continue  # глубокое дно не рисуем
			for tri in [[v00, v10, v01], [v10, v11, v01]]:
				var c := _color_for(tri, tint)
				st.set_color(c)
				for v in tri:
					st.add_vertex(v)
	st.generate_normals()
	var mesh := st.commit()

	var mi := MeshInstance3D.new()
	mi.name = "Terrain"
	mi.mesh = mesh
	var m := ShaderMaterial.new()
	m.shader = Models.TOON
	m.set_shader_parameter("use_vertex_color", true)
	m.set_shader_parameter("rim_amount", 0.0)
	m.set_shader_parameter("specular_amount", 0.0)
	mi.material_override = m
	add_child(mi)

	var body := StaticBody3D.new()
	body.name = "TerrainBody"
	body.collision_layer = 1
	var cs := CollisionShape3D.new()
	cs.shape = mesh.create_trimesh_shape()
	body.add_child(cs)
	add_child(body)


func _color_for(tri: Array, tint: RandomNumberGenerator) -> Color:
	var a: Vector3 = tri[0]
	var b: Vector3 = tri[1]
	var c: Vector3 = tri[2]
	var n := (b - a).cross(c - a).normalized()
	if n.y < 0:
		n = -n
	var h := (a.y + b.y + c.y) / 3.0
	var col: Color
	if h < -0.3:
		col = SEABED
	elif h < 0.35:
		col = SAND_WET
	elif h < 1.05:
		col = SAND
	elif n.y < 0.78 or h > 9.5:
		col = ROCK
	else:
		col = GRASS.lerp(GRASS_DARK, clampf((h - 1.0) / 6.0, 0.0, 1.0))
	var v := tint.randf_range(-0.035, 0.035)
	return Color(col.r + v, col.g + v, col.b + v)


# ------------------------------------------------------------------ Вода
func _build_water() -> void:
	var img := Image.create(MAP_RES, MAP_RES, false, Image.FORMAT_RF)
	for j in MAP_RES:
		for i in MAP_RES:
			var x := -SIZE * 0.5 + (i + 0.5) / MAP_RES * SIZE
			var z := -SIZE * 0.5 + (j + 0.5) / MAP_RES * SIZE
			var h := height_at(x, z)
			img.set_pixel(i, j, Color(clampf((h - H_MIN) / (H_MAX - H_MIN), 0.0, 1.0), 0, 0))
	var tex := ImageTexture.create_from_image(img)

	var plane := PlaneMesh.new()
	plane.size = Vector2(900, 900)
	plane.subdivide_width = 120
	plane.subdivide_depth = 120
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/water.gdshader")
	mat.set_shader_parameter("height_map", tex)
	mat.set_shader_parameter("map_origin", Vector2(-SIZE * 0.5, -SIZE * 0.5))
	mat.set_shader_parameter("map_size", SIZE)
	mat.set_shader_parameter("height_min", H_MIN)
	mat.set_shader_parameter("height_max", H_MAX)
	var water := MeshInstance3D.new()
	water.name = "Water"
	water.mesh = plane
	water.material_override = mat
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)


# ------------------------------------------------------------------ Трава
func _build_grass() -> void:
	var blade := SurfaceTool.new()
	blade.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 3:
		var a := k * TAU / 3.0
		var dir := Vector3(cos(a), 0, sin(a)) * 0.07
		blade.set_color(Color.WHITE)
		blade.add_vertex(-dir)
		blade.add_vertex(dir)
		blade.add_vertex(Vector3(dir.z * 0.5, 0.45, -dir.x * 0.5))
	blade.generate_normals()
	var blade_mesh := blade.commit()

	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	var g := RandomNumberGenerator.new()
	g.seed = seed_value + 7
	var attempts := 0
	while transforms.size() < 9000 and attempts < 60000:
		attempts += 1
		var x := g.randf_range(-RADIUS * 1.2, RADIUS * 1.2)
		var z := g.randf_range(-RADIUS * 1.2, RADIUS * 1.2)
		var h := height_at(x, z)
		if h < 1.2 or h > 9.0:
			continue
		if normal_at(x, z).y < 0.8:
			continue
		var s := g.randf_range(0.7, 1.5)
		var b := Basis(Vector3.UP, g.randf() * TAU).scaled(Vector3(s, s * g.randf_range(0.8, 1.4), s))
		transforms.append(Transform3D(b, Vector3(x, h - 0.03, z)))
		colors.append(Color.WHITE.lerp(Color("e8ffb0"), g.randf() * 0.5))

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = blade_mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
		mm.set_instance_color(i, colors[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Grass"
	mmi.multimesh = mm
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/grass.gdshader")
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)

	# цветы
	var fm := MultiMesh.new()
	fm.transform_format = MultiMesh.TRANSFORM_3D
	fm.use_colors = true
	fm.mesh = Models.sphere(0.07, 6, 4)
	var ft: Array[Transform3D] = []
	var fc: Array[Color] = []
	var palette := [Color("ff6fa5"), Color("ffd84a"), Color("ffffff"), Color("b28cff"), Color("ff8a3d")]
	attempts = 0
	while ft.size() < 700 and attempts < 20000:
		attempts += 1
		var x := g.randf_range(-RADIUS, RADIUS)
		var z := g.randf_range(-RADIUS, RADIUS)
		var h := height_at(x, z)
		if h < 1.3 or h > 7.0:
			continue
		ft.append(Transform3D(Basis(), Vector3(x, h + 0.25, z)))
		fc.append(palette[g.randi() % palette.size()])
	fm.instance_count = ft.size()
	for i in ft.size():
		fm.set_instance_transform(i, ft[i])
		fm.set_instance_color(i, fc[i])
	var fmi := MultiMeshInstance3D.new()
	fmi.multimesh = fm
	var fmat := StandardMaterial3D.new()
	fmat.vertex_color_use_as_albedo = true
	fmat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	fmi.material_override = fmat
	fmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(fmi)


# ------------------------------------------------------------------ Ресурсы
func _spawn_resources() -> void:
	var holder := Node3D.new()
	holder.name = "Resources"
	add_child(holder)
	var placed: Array[Vector2] = []
	var plan := {
		"palm": {"count": 70, "h": [0.7, 6.5], "gap": 3.5},
		"bush": {"count": 45, "h": [1.2, 7.0], "gap": 2.0},
		"rock": {"count": 26, "h": [1.2, 12.0], "gap": 3.0},
		"pebble": {"count": 30, "h": [0.15, 1.3], "gap": 1.2},
		"driftwood": {"count": 16, "h": [0.1, 0.9], "gap": 2.5},
		"shell": {"count": 22, "h": [0.05, 0.8], "gap": 1.0},
	}
	for kind in plan:
		var cfg: Dictionary = plan[kind]
		var n := 0
		var tries := 0
		while n < cfg["count"] and tries < 8000:
			tries += 1
			var x := rng.randf_range(-RADIUS * 1.3, RADIUS * 1.3)
			var z := rng.randf_range(-RADIUS * 1.3, RADIUS * 1.3)
			var h := height_at(x, z)
			if h < cfg["h"][0] or h > cfg["h"][1]:
				continue
			if kind != "rock" and normal_at(x, z).y < 0.75:
				continue
			var p2 := Vector2(x, z)
			var ok := true
			for q in placed:
				if q.distance_to(p2) < cfg["gap"]:
					ok = false
					break
			if not ok:
				continue
			placed.append(p2)
			var node := ResourceNode.new()
			node.kind = kind
			node.position = Vector3(x, h - 0.05, z)
			node.rng_seed = rng.randi()
			holder.add_child(node)
			n += 1


func _find_spawn() -> void:
	# стартуем на южном пляже
	var a := PI * 0.5
	var r := 10.0
	while r < 90.0:
		var x := cos(a) * r
		var z := sin(a) * r
		if height_at(x, z) < 1.3:
			spawn_point = Vector3(cos(a) * (r - 4.0), 0, sin(a) * (r - 4.0))
			spawn_point.y = height_at(spawn_point.x, spawn_point.z) + 0.5
			return
		r += 0.5
	spawn_point = Vector3(0, height_at(0, 0) + 1.0, 0)


func spawn_distant_scenery(parent: Node3D) -> void:
	var g := RandomNumberGenerator.new()
	g.seed = seed_value + 99
	# силуэты других островов на горизонте — будущие локации
	for i in 5:
		var a := TAU * i / 5.0 + g.randf() * 0.5
		var d := g.randf_range(190, 260)
		var isl := Models.distant_island(g, g.randf_range(14, 26))
		isl.position = Vector3(cos(a) * d, -0.2, sin(a) * d)
		parent.add_child(isl)
