class_name Island
extends Node3D
## Процедурный остров: рельеф, вода, трава, цветы и ресурсы.
## Высота считается аналитически (height_at) — ей пользуются строительство, животные и вода.

const SIZE := 200.0
const RES := 160
const RADIUS := 52.0
const MAP_RES := 256
const H_MIN := -6.0
const H_MAX := 14.0

var seed_value := 1337
var shape_noise := FastNoiseLite.new()
var hill_noise := FastNoiseLite.new()
var detail_noise := FastNoiseLite.new()
var peak_center := Vector2(14, -12)
var rng := RandomNumberGenerator.new()
var spawn_point := Vector3.ZERO
var camp_center := Vector3.ZERO     # поляна для лагеря рядом с местом крушения
var wreck_point := Vector3.ZERO
var noise_tex: NoiseTexture2D
var water_mat: ShaderMaterial


func _init() -> void:
	rng.seed = seed_value
	shape_noise.seed = seed_value
	shape_noise.frequency = 0.9
	hill_noise.seed = seed_value + 1
	hill_noise.frequency = 0.035
	detail_noise.seed = seed_value + 2
	detail_noise.frequency = 0.25
	noise_tex = NoiseTexture2D.new()
	noise_tex.width = 256
	noise_tex.height = 256
	noise_tex.seamless = true
	var nz := FastNoiseLite.new()
	nz.seed = 7
	nz.frequency = 0.02
	nz.fractal_octaves = 3
	noise_tex.noise = nz
	noise_tex.generate_mipmaps = true


func build() -> void:
	_find_spawn()
	_build_terrain()
	_build_water()
	_build_grass()
	_spawn_resources()


# ------------------------------------------------------------------ Высота
func height_at(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var d := p.length()
	var ang := atan2(z, x)
	var r := RADIUS * (1.0 + 0.2 * shape_noise.get_noise_2d(cos(ang) * 1.5, sin(ang) * 1.5)
		+ 0.07 * shape_noise.get_noise_2d(cos(ang) * 4.0 + 10.0, sin(ang) * 4.0))
	var t := d / r
	var h := lerpf(H_MIN, 0.5, smoothstep(1.35, 0.95, t))
	var inland := smoothstep(0.92, 0.55, t)
	h += inland * (1.4 + 1.4 * (hill_noise.get_noise_2d(x, z) * 0.5 + 0.5))
	var pd := p.distance_to(peak_center)
	h += 10.0 * exp(-pd * pd / (2.0 * 12.0 * 12.0)) * inland
	h += detail_noise.get_noise_2d(x, z) * 0.15 * inland
	# пологая поляна под лагерь
	if camp_center != Vector3.ZERO:
		var cd := Vector2(x - camp_center.x, z - camp_center.z).length()
		var k := smoothstep(9.0, 5.0, cd)
		h = lerpf(h, maxf(camp_center.y, 1.6), k * 0.9)
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
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := RES + 1
	for j in n:
		for i in n:
			var x := -half + i * step
			var z := -half + j * step
			st.set_normal(normal_at(x, z))
			st.add_vertex(Vector3(x, height_at(x, z), z))
	for j in RES:
		for i in RES:
			var a := j * n + i
			var b := a + 1
			var c := a + n
			var d := c + 1
			st.add_index(a); st.add_index(b); st.add_index(c)
			st.add_index(b); st.add_index(d); st.add_index(c)
	var mesh := st.commit()

	var mi := MeshInstance3D.new()
	mi.name = "Terrain"
	mi.mesh = mesh
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/terrain.gdshader")
	m.set_shader_parameter("noise_tex", noise_tex)
	m.set_shader_parameter("camp_pos", camp_center)
	m.set_shader_parameter("camp_radius", 5.5)
	mi.material_override = m
	add_child(mi)

	var body := StaticBody3D.new()
	body.name = "TerrainBody"
	body.collision_layer = 1
	var cs := CollisionShape3D.new()
	cs.shape = mesh.create_trimesh_shape()
	body.add_child(cs)
	add_child(body)


# ------------------------------------------------------------------ Вода
func _build_water() -> void:
	var img := Image.create(MAP_RES, MAP_RES, false, Image.FORMAT_RF)
	for j in MAP_RES:
		for i in MAP_RES:
			var x := -SIZE * 0.5 + (i + 0.5) / MAP_RES * SIZE
			var z := -SIZE * 0.5 + (j + 0.5) / MAP_RES * SIZE
			img.set_pixel(i, j, Color(clampf((height_at(x, z) - H_MIN) / (H_MAX - H_MIN), 0.0, 1.0), 0, 0))
	var plane := PlaneMesh.new()
	plane.size = Vector2(900, 900)
	plane.subdivide_width = 120
	plane.subdivide_depth = 120
	water_mat = ShaderMaterial.new()
	water_mat.shader = preload("res://shaders/water.gdshader")
	water_mat.set_shader_parameter("height_map", ImageTexture.create_from_image(img))
	water_mat.set_shader_parameter("noise_tex", noise_tex)
	water_mat.set_shader_parameter("map_origin", Vector2(-SIZE * 0.5, -SIZE * 0.5))
	water_mat.set_shader_parameter("map_size", SIZE)
	water_mat.set_shader_parameter("height_min", H_MIN)
	water_mat.set_shader_parameter("height_max", H_MAX)
	var water := MeshInstance3D.new()
	water.name = "Water"
	water.mesh = plane
	water.material_override = water_mat
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)


# ------------------------------------------------------------------ Трава и цветы
func _build_grass() -> void:
	# пучок из 5 широких травинок
	var tuft := SurfaceTool.new()
	tuft.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 5:
		var a := k * TAU / 5.0 + 0.3
		var dir := Vector3(cos(a), 0, sin(a))
		var side := Vector3(-dir.z, 0, dir.x) * 0.06
		var lean := dir * 0.12
		var hgt := 0.38 + (k % 3) * 0.08
		tuft.set_color(Color.WHITE)
		tuft.add_vertex(dir * 0.04 - side)
		tuft.add_vertex(dir * 0.04 + side)
		tuft.add_vertex(dir * 0.04 + lean + Vector3(0, hgt, 0))
	tuft.generate_normals()
	var tuft_mesh := tuft.commit()

	var g := RandomNumberGenerator.new()
	g.seed = seed_value + 7
	var tr: Array[Transform3D] = []
	var cols: Array[Color] = []
	var attempts := 0
	while tr.size() < 7000 and attempts < 70000:
		attempts += 1
		var x := g.randf_range(-RADIUS * 1.2, RADIUS * 1.2)
		var z := g.randf_range(-RADIUS * 1.2, RADIUS * 1.2)
		var h := height_at(x, z)
		if h < 1.25 or h > 9.0 or normal_at(x, z).y < 0.82:
			continue
		if Vector2(x - camp_center.x, z - camp_center.z).length() < 6.5:
			continue
		var s := g.randf_range(0.8, 1.6)
		tr.append(Transform3D(Basis(Vector3.UP, g.randf() * TAU).scaled(Vector3(s, s * g.randf_range(0.8, 1.3), s)), Vector3(x, h - 0.03, z)))
		cols.append(Color.WHITE.lerp(Color("e8ffb0"), g.randf() * 0.4))
	_add_multimesh("Grass", tuft_mesh, tr, cols, _grass_mat())

	var ft: Array[Transform3D] = []
	var fc: Array[Color] = []
	var palette := [Color("ff6fa5"), Color("ffd84a"), Color("ffffff"), Color("b28cff"), Color("ff8a3d"), Color("6fc3ff")]
	attempts = 0
	while ft.size() < 900 and attempts < 30000:
		attempts += 1
		# цветы растут полянками
		var cx := g.randf_range(-RADIUS, RADIUS)
		var cz := g.randf_range(-RADIUS, RADIUS)
		var col: Color = palette[g.randi() % palette.size()]
		for k in 8:
			var x := cx + g.randf_range(-1.8, 1.8)
			var z := cz + g.randf_range(-1.8, 1.8)
			var h := height_at(x, z)
			if h < 1.3 or h > 7.5 or Vector2(x - camp_center.x, z - camp_center.z).length() < 6.5:
				continue
			var s := g.randf_range(0.8, 1.4)
			ft.append(Transform3D(Basis(Vector3.UP, g.randf() * TAU).scaled(Vector3(s, s, s)), Vector3(x, h + 0.12, z)))
			fc.append(col)
	var fmat := ShaderMaterial.new()
	fmat.shader = Models.TOON
	fmat.set_shader_parameter("use_vertex_color", true)
	fmat.set_shader_parameter("rim_amount", 0.0)
	_add_multimesh("Flowers", Models.flower_mesh(), ft, fc, fmat, true)


func _grass_mat() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/grass.gdshader")
	return m


func _add_multimesh(name_: String, mesh: Mesh, tr: Array[Transform3D], cols: Array[Color], material: Material, instance_colors_as_vertex := false) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = tr.size()
	for i in tr.size():
		mm.set_instance_transform(i, tr[i])
		mm.set_instance_color(i, cols[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = name_
	mmi.multimesh = mm
	mmi.material_override = material
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


# ------------------------------------------------------------------ Растительность и преграды
## Остров почти весь зарос. Свободна только полянка у места крушения.
## Ближе к лагерю — трава и папоротник (рвутся руками), дальше — колючки и бамбук (мачете),
## в чаще — деревья-гиганты и поваленные стволы (топор), у вершины и шлюпки — каменные гряды (кирка).
var poi: Dictionary = {}       # id сюжетного места -> позиция
var _uid := 0


func _place_pois() -> void:
	# старый лагерь Лёвы — на западе, в глубине джунглей
	var oc := Vector3(-RADIUS * 0.5, 0, RADIUS * 0.08)
	oc.y = height_at(oc.x, oc.z)
	poi["old_camp"] = oc
	# шлюпка «Альбатроса» — на северном пляже
	var a := -PI * 0.5
	var r := 20.0
	while r < 90.0 and height_at(cos(a) * r, sin(a) * r) > 0.7:
		r += 0.5
	var lb := Vector3(cos(a) * (r - 1.5), 0, sin(a) * (r - 1.5))
	lb.y = height_at(lb.x, lb.z)
	poi["lifeboat"] = lb
	# древний маяк — на вершине горы
	var best := Vector3(peak_center.x, 0, peak_center.y)
	for i in 60:
		var q := Vector3(peak_center.x + rng.randf_range(-4, 4), 0, peak_center.y + rng.randf_range(-4, 4))
		if height_at(q.x, q.z) > height_at(best.x, best.z):
			best = q
	best.y = height_at(best.x, best.z)
	poi["lighthouse"] = best


func _spawn_resources() -> void:
	_place_pois()
	var holder := Node3D.new()
	holder.name = "Resources"
	add_child(holder)
	var decor := Node3D.new()
	decor.name = "Decor"
	add_child(decor)
	for id in poi:
		var sp := StoryPlace.new()
		sp.id = id
		sp.position = poi[id]
		sp.rotation.y = rng.randf() * TAU
		holder.add_child(sp)

	var patch := FastNoiseLite.new()
	patch.seed = seed_value + 5
	patch.frequency = 0.045
	var camp2 := Vector2(camp_center.x, camp_center.z)
	var wreck2 := Vector2(wreck_point.x, wreck_point.z)
	var step := 2.25
	var n := int(RADIUS * 1.35 * 2 / step)
	for j in n:
		for i in n:
			var x := -RADIUS * 1.35 + i * step + rng.randf_range(-0.7, 0.7)
			var z := -RADIUS * 1.35 + j * step + rng.randf_range(-0.7, 0.7)
			var roll := rng.randf()
			var seed_v := rng.randi()
			var h := height_at(x, z)
			if h < 0.15:
				continue
			var p2 := Vector2(x, z)
			var dc := p2.distance_to(camp2)
			var dw := p2.distance_to(wreck2)
			if _near_poi(p2, 5.0):
				continue
			var kind := ""
			if dc < 9.5 or dw < 7.0:
				# стартовая полянка: только мелочь на песке
				if h < 1.05 and roll < 0.12:
					kind = ["pebble", "shell", "driftwood"][seed_v % 3]
			elif h < 1.05:
				# пляж: пальмы, дюнная трава, дары моря
				if roll < 0.13: kind = "palm"
				elif roll < 0.2: kind = "tall_grass"
				elif roll < 0.27: kind = ["pebble", "shell"][seed_v % 2]
				elif roll < 0.31: kind = "driftwood"
				elif roll < 0.33: kind = "rock"
			elif h > 9.0:
				if roll < 0.25: kind = "rock"
				elif roll < 0.55: kind = "tall_grass"
			elif dc < 17.0:
				# опушка: можно пробиться руками, но местами нужен мачете
				if roll < 0.34: kind = "tall_grass"
				elif roll < 0.54: kind = "fern"
				elif roll < 0.66: kind = "bush"
				elif roll < 0.8: kind = "thicket"
				elif roll < 0.88: kind = "palm"
				elif roll < 0.92: kind = "banana"
			else:
				var bamboo_patch := patch.get_noise_2d(x, z) > 0.32
				if bamboo_patch:
					kind = "bamboo" if roll < 0.75 else "fern"
				elif roll < 0.17: kind = "jungle_tree"
				elif roll < 0.38: kind = "thicket"
				elif roll < 0.53: kind = "fern"
				elif roll < 0.65: kind = "tall_grass"
				elif roll < 0.72: kind = "palm"
				elif roll < 0.78: kind = "bush"
				elif roll < 0.81: kind = "banana"
				elif roll < 0.83: kind = "mango"
				elif roll < 0.87: kind = "fallen_log"
				elif roll < 0.9: kind = "rock"
			_uid += 1
			if kind == "":
				if h > 1.1 and roll > 0.94 and dc > 9.5:
					_add_decor(decor, "flower_patch", Vector3(x, h - 0.03, z), seed_v)
				continue
			_spawn(holder, kind, Vector3(x, h - 0.05, z), seed_v, "j%d" % _uid, -100.0)
	_barrier_rings(holder)


func _near_poi(p2: Vector2, r: float) -> bool:
	for id in poi:
		var q: Vector3 = poi[id]
		if p2.distance_to(Vector2(q.x, q.z)) < r:
			return true
	return false


## Кольца преград вокруг сюжетных мест — без нужного инструмента не пройти.
func _barrier_rings(holder: Node3D) -> void:
	# шаг по кольцу меньше диаметра преграды + игрока — щелей нет
	var specs := {"old_camp": [["thicket", 5.4, 18], ["jungle_tree", 7.6, 17]],
		"lifeboat": [["cliff", 6.0, 10]],
		"lighthouse": [["cliff", 6.2, 11]]}
	for id in specs:
		var c: Vector3 = poi[id]
		var k := 0
		for ring in specs[id]:
			var kind: String = ring[0]
			var rad: float = ring[1]
			var cnt: int = ring[2]
			for i in cnt:
				k += 1
				var a := TAU * i / cnt + (0.15 if kind == "jungle_tree" else 0.0)
				var pos := c + Vector3(cos(a) * rad, 0, sin(a) * rad)
				pos.y = height_at(pos.x, pos.z) - 0.05
				var yaw := -a + PI / 2 if kind == "cliff" else -100.0
				_spawn(holder, kind, pos, k * 7919 + i, "r_%s_%d" % [id, k], yaw)


func _spawn(holder: Node3D, kind: String, pos: Vector3, seed_v: int, uid: String, yaw: float) -> void:
	if Game.cleared.has(uid):
		return
	var node: Node3D
	if kind in ["banana", "mango"]:
		var t := FruitTree.new()
		t.setup("fruit_tree")
		t.tree_type = kind
		t.wild = true
		t.rng_seed = seed_v
		node = t
	else:
		var r := ResourceNode.new()
		r.kind = kind
		r.rng_seed = seed_v
		r.uid = uid
		r.yaw = yaw
		node = r
	node.position = pos
	holder.add_child(node)


func _add_decor(holder: Node3D, model: String, pos: Vector3, seed_v: int) -> void:
	var m := Models.glb(model)
	if m == null:
		return
	m.position = pos
	m.rotation.y = float(seed_v % 628) / 100.0
	for gi in m.find_children("*", "GeometryInstance3D", true, false):
		(gi as GeometryInstance3D).visibility_range_end = 45.0
		(gi as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(m)


func _find_spawn() -> void:
	# стартуем на южном пляже, лагерь — чуть выше по склону
	var a := PI * 0.5
	var r := 10.0
	var saved_camp := camp_center
	camp_center = Vector3.ZERO
	while r < 90.0:
		var x := cos(a) * r
		var z := sin(a) * r
		if height_at(x, z) < 1.0:
			wreck_point = Vector3(cos(a) * (r + 1.0), 0, sin(a) * (r + 1.0))
			wreck_point.y = height_at(wreck_point.x, wreck_point.z)
			camp_center = Vector3(cos(a) * (r - 9.0), 0, sin(a) * (r - 9.0))
			camp_center.y = height_at(camp_center.x, camp_center.z)
			spawn_point = Vector3(cos(a) * (r - 2.5), 0, sin(a) * (r - 2.5)) + Vector3(2.5, 0, 0)
			spawn_point.y = height_at(spawn_point.x, spawn_point.z) + 0.5
			wreck_point.y = height_at(wreck_point.x, wreck_point.z)
			return
		r += 0.5
	camp_center = saved_camp
	spawn_point = Vector3(0, height_at(0, 0) + 1.0, 0)


var banyan: Node3D   # остров Великого Баньяна на горизонте (цель первой главы)


func spawn_distant_scenery(parent: Node3D) -> void:
	var g := RandomNumberGenerator.new()
	g.seed = seed_value + 99
	for i in 5:
		var a := TAU * i / 5.0 + (0.0 if i == 0 else g.randf() * 0.5)
		var d := 230.0 if i == 0 else g.randf_range(190, 260)
		var isl := Models.distant_island(g, 30.0 if i == 0 else g.randf_range(14, 24))
		isl.position = Vector3(cos(a) * d, -0.2, sin(a) * d)
		parent.add_child(isl)
		if i == 0:
			banyan = isl
			var tree := Models.glb("jungle_tree_a")
			if tree:
				tree.scale = Vector3.ONE * 4.5
				tree.position = Vector3(0, 6.0, 0)
				isl.add_child(tree)
