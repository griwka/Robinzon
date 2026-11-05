class_name Island
extends Node3D
## Процедурный остров: рельеф, вода, трава, цветы и ресурсы.
## Высота считается аналитически (height_at) — ей пользуются строительство, животные и вода.

const SIZE := 200.0
const RES := 160
const MAP_RES := 256
const H_MIN := -6.0
const H_MAX := 14.0

var seed_value := 1337
var radius := 52.0
var peak_h := 10.0
var loc := "home"
var mix := "home"
var flat := []      # [центр Vector2, радиус, высота] — плато под постройки (форт)
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


## Настроить остров по описанию из Data.LOCATIONS (вызывать до add_child / build).
func configure(location: String) -> void:
	var cfg: Dictionary = Data.LOCATIONS[location]
	loc = location
	seed_value = cfg["seed"]
	radius = cfg["radius"]
	peak_center = cfg["peak"]
	peak_h = cfg["peak_h"]
	mix = cfg["mix"]
	flat = cfg.get("flat", [])
	_init()


func _init() -> void:
	rng.seed = seed_value
	shape_noise.seed = seed_value
	shape_noise.frequency = 0.9
	hill_noise.seed = seed_value + 1
	hill_noise.frequency = 0.035
	detail_noise.seed = seed_value + 2
	detail_noise.frequency = 0.25
	noise_tex = NoiseTexture2D.new()
	noise_tex.width = 512
	noise_tex.height = 512
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
	var r := radius * (1.0 + 0.2 * shape_noise.get_noise_2d(cos(ang) * 1.5, sin(ang) * 1.5)
		+ 0.07 * shape_noise.get_noise_2d(cos(ang) * 4.0 + 10.0, sin(ang) * 4.0))
	var t := d / r
	var h := lerpf(H_MIN, 0.5, smoothstep(1.35, 0.95, t))
	var inland := smoothstep(0.92, 0.55, t)
	h += inland * (1.4 + 1.4 * (hill_noise.get_noise_2d(x, z) * 0.5 + 0.5))
	var pd := p.distance_to(peak_center)
	h += peak_h * exp(-pd * pd / (2.0 * 12.0 * 12.0)) * inland
	h += detail_noise.get_noise_2d(x, z) * 0.15 * inland
	# плато (под форт)
	if not flat.is_empty():
		var fd := p.distance_to(flat[0])
		h = lerpf(h, flat[2], smoothstep(flat[1] + 7.0, flat[1], fd))
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
		var x := g.randf_range(-radius * 1.2, radius * 1.2)
		var z := g.randf_range(-radius * 1.2, radius * 1.2)
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
		var cx := g.randf_range(-radius, radius)
		var cz := g.randf_range(-radius, radius)
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
	if mix == "fort":
		var f := Vector3(flat[0].x, 0, flat[0].y)
		f.y = height_at(f.x, f.z)
		poi["fort"] = f
		return
	if mix == "banyan":
		var c := Vector3(0, 0, 0)
		c.y = height_at(0, 0)
		poi["banyan_roots"] = c
		return
	# старый лагерь Лёвы — на западе, в глубине джунглей
	var oc := Vector3(-radius * 0.5, 0, radius * 0.08)
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
		if id == "banyan_roots":
			var tree := BanyanTree.new()
			tree.position = poi[id]
			holder.add_child(tree)
			continue
		if id == "fort":
			var fort := FortRuin.new()
			fort.island = self
			fort.position = poi[id]
			holder.add_child(fort)
			continue
		var sp := StoryPlace.new()
		sp.id = id
		sp.position = poi[id]
		sp.rotation.y = rng.randf() * TAU
		holder.add_child(sp)

	# сначала — всё, что стоит на своих местах: кольца преград, причал, хижина, глина, ящик.
	# Заросли растут потом и только там, где свободно (порядок случайных чисел прежний — сохранения не ломаются).
	_reserve_places()
	_barrier_rings(holder)
	if mix == "fort":
		_spawn_stepa(holder)
		_spawn_clay(holder)

	var patch := FastNoiseLite.new()
	patch.seed = seed_value + 5
	patch.frequency = 0.045
	# пальмовые рощи на пляже и солнечные поляны в чаще — чтобы лес не был ровной сеткой
	var grove := FastNoiseLite.new()
	grove.seed = seed_value + 11
	grove.frequency = 0.07
	var glade := FastNoiseLite.new()
	glade.seed = seed_value + 13
	glade.frequency = 0.055
	var camp2 := Vector2(camp_center.x, camp_center.z)
	var wreck2 := Vector2(wreck_point.x, wreck_point.z)
	var step := 2.25
	var n := int(radius * 1.35 * 2 / step)
	for j in n:
		for i in n:
			var x := -radius * 1.35 + i * step + rng.randf_range(-0.7, 0.7)
			var z := -radius * 1.35 + j * step + rng.randf_range(-0.7, 0.7)
			var roll := rng.randf()
			var seed_v := rng.randi()
			var h := height_at(x, z)
			if h < 0.15:
				continue
			var p2 := Vector2(x, z)
			var dc := p2.distance_to(camp2)
			var dw := p2.distance_to(wreck2)
			if _near_poi(p2, {"banyan": 10.0, "fort": 14.5}.get(mix, 5.0)):
				continue
			var kind := ""
			if dc < 9.5 or dw < 7.0:
				# стартовая полянка: только мелочь на песке
				if h < 1.05 and roll < 0.12:
					kind = ["pebble", "shell", "driftwood"][seed_v % 3]
			elif h < 1.05:
				# пляж: пальмы рощицами, дюнная трава, дары моря у воды
				var palms := 0.04 + 0.3 * clampf(grove.get_noise_2d(x, z) * 2.0, 0.0, 1.0)
				if roll < palms: kind = "palm"
				elif roll < palms + 0.07: kind = "tall_grass" if h > 0.5 else "driftwood"
				elif roll < palms + 0.15: kind = ["pebble", "shell"][seed_v % 2]
				elif roll < palms + 0.18: kind = "driftwood"
				elif roll < palms + 0.2: kind = "rock"
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
			elif glade.get_noise_2d(x, z) > 0.4:
				# поляна в чаще: светло, трава по пояс, цветы и фруктовые деревья
				if roll < 0.3: kind = "tall_grass"
				elif roll < 0.42: kind = "fern"
				elif roll < 0.47: kind = "banana" if seed_v % 2 == 0 else "mango"
				elif roll < 0.53: kind = "bush"
			elif mix == "banyan":
				# остров Баньяна: чаще великаны, папоротники, завесы лиан и фруктовые деревья
				if roll < 0.18: kind = "jungle_tree"
				elif roll < 0.33: kind = "fern"
				elif roll < 0.45: kind = "thicket"
				elif roll < 0.53: kind = "liana_curtain"
				elif roll < 0.63: kind = "tall_grass"
				elif roll < 0.68: kind = "palm"
				elif roll < 0.74: kind = "banana"
				elif roll < 0.78: kind = "mango"
				elif roll < 0.83: kind = "bush"
				elif roll < 0.86: kind = "fallen_log"
				elif roll < 0.88: kind = "rock"
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
				var flowers := 0.94 if glade.get_noise_2d(x, z) < 0.4 else 0.75
				if h > 1.1 and roll > flowers and dc > 9.5 and _is_free(p2, 0.8, 0.5):
					_add_decor(decor, "flower_patch", Vector3(x, h - 0.03, z), seed_v)
				continue
			# не ставим одно в другое: стволы, камни и кусты не налезают друг на друга и на особые места
			var fr := footprint(kind)
			if not _is_free(p2, fr, 0.55 if kind in SMALL_KINDS else 0.85):
				continue
			_occupy(p2, fr)
			_spawn(holder, kind, Vector3(x, h - 0.05, z), seed_v, ("j%d" if loc == "home" else loc + ":j%d") % _uid, -100.0)
	_spawn_fishing_spots(holder)
	_spawn_finds(holder)


# ------------------------------------------------------------------ Находки
const BOTTLES := 3
const STASHES := 2
var finds: Array[Vector3] = []


## Бутылки с записками — у кромки воды подальше от лагеря, тайники — в глубине чащи.
## Свой генератор случайных чисел: расстановка зарослей от этого не меняется.
func _spawn_finds(holder: Node3D) -> void:
	var g := RandomNumberGenerator.new()
	g.seed = seed_value + 31
	var camp2 := Vector2(camp_center.x, camp_center.z)
	var placed: Array[Vector2] = []
	for want in [["bottle", BOTTLES], ["stash", STASHES]]:
		var kind: String = want[0]
		var made := 0
		for attempt in 3000:
			if made >= int(want[1]):
				break
			var a := g.randf() * TAU
			var r := g.randf_range(0.2, 1.3) * radius
			var p := Vector2(cos(a), sin(a)) * r
			var h := height_at(p.x, p.y)
			var ok := false
			if kind == "bottle":
				ok = h > 0.2 and h < 0.7 and p.distance_to(camp2) > 15.0
			else:
				ok = h > 1.6 and h < 8.5 and p.distance_to(camp2) > 20.0 and normal_at(p.x, p.y).y > 0.85
			if not ok or _near_poi(p, 14.0 if mix == "home" else 16.0):
				continue
			var spaced := true
			for q in placed:
				spaced = spaced and q.distance_to(p) > 22.0
			if not spaced or not _is_free(p, 0.8, 1.0):
				continue
			placed.append(p)
			_occupy(p, 0.8)
			var f := FindSpot.new()
			f.kind = kind
			f.index = made if kind == "bottle" else BOTTLES + made
			f.loc = loc
			f.position = Vector3(p.x, h - 0.04, p.y)
			f.rotation.y = g.randf() * TAU
			holder.add_child(f)
			finds.append(f.position)
			made += 1


# ------------------------------------------------------------------ Занятые места
const SMALL_KINDS := ["tall_grass", "fern", "bush", "pebble", "shell", "driftwood"]
const OCC_CELL := 3.0
var _occ: Dictionary = {}   # Vector2i -> [[центр, радиус], ...]
var crate_point := Vector3.ZERO   # ящик с «Альбатроса» на острове крушения


## Сколько места на земле занимает заросль/ресурс.
static func footprint(kind: String) -> float:
	if kind in ["banana", "mango"]:
		return 0.7
	var cfg: Dictionary = ResourceNode.KINDS[kind]
	return maxf(float(cfg["radius"]), float(cfg.get("long", 0.0)) * 0.75)


func _occupy(p: Vector2, r: float) -> void:
	var k := Vector2i(int(floor(p.x / OCC_CELL)), int(floor(p.y / OCC_CELL)))
	if not _occ.has(k):
		_occ[k] = []
	_occ[k].append([p, r])


## Свободно ли место: ни с чем уже стоящим круги не пересекаются больше, чем на (1 - k).
func _is_free(p: Vector2, r: float, k: float) -> bool:
	var c := Vector2i(int(floor(p.x / OCC_CELL)), int(floor(p.y / OCC_CELL)))
	var reach := int(ceil((r + 3.0) / OCC_CELL))
	for dz in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			for e in _occ.get(c + Vector2i(dx, dz), []):
				if p.distance_to(e[0]) < (r + float(e[1])) * k:
					return false
	return true


func _reserve(p: Vector3, r: float, what: String) -> void:
	var p2 := Vector2(p.x, p.z)
	reserved.append([p2, r, what])
	_occupy(p2, r)


## Места, где ничего не должно расти: обломки, ящик, причал, хижина Стёпы, глиняные ямы.
func _reserve_places() -> void:
	var to_camp := camp_center - wreck_point
	to_camp.y = 0
	if loc == "home":
		_reserve(wreck_point, 2.6, "обломки «Чайки»")
		# ящик — сбоку от обломков (там же его ставит main.gd)
		var yaw := atan2(to_camp.x, to_camp.z) + PI / 2
		var side := Vector3(cos(yaw), 0, -sin(yaw))
		crate_point = wreck_point + side * 4.0 + to_camp.normalized() * 1.0
		crate_point.y = height_at(crate_point.x, crate_point.z)
		_reserve(crate_point, 1.3, "ящик")
	else:
		_reserve(wreck_point, 2.8, "причал")


## Глиняные ямы — ровно 6 штук на песке недалеко от лагеря (глина восстанавливается).
func _spawn_clay(holder: Node3D) -> void:
	var c := Vector2(camp_center.x, camp_center.z)
	var placed: Array[Vector2] = []
	var a0 := atan2(wreck_point.z, wreck_point.x)
	for k in 400:
		if placed.size() >= 6:
			break
		var a := a0 + (k % 40 - 20) * 0.05
		var r := 8.0 + (k / 40) * 2.5
		var p := c + Vector2(cos(a), sin(a)) * r
		var h := height_at(p.x, p.y)
		if h < 0.3 or h > 1.0 or p.distance_to(Vector2(wreck_point.x, wreck_point.z)) < 5.0:
			continue
		var ok := true
		for q in placed:
			ok = ok and q.distance_to(p) > 3.5
		if not ok:
			continue
		placed.append(p)
		_reserve(Vector3(p.x, h, p.y), 1.1, "глина")
		_spawn(holder, "clay", Vector3(p.x, h - 0.03, p.y), 4000 + k, "fort:clay_%d" % placed.size(), -100.0)


## Места для рыбалки — бурлящая вода у берега недалеко от лагеря.
func _spawn_fishing_spots(holder: Node3D) -> void:
	var want: int = {"fort": 4, "home": 2, "banyan": 2}.get(mix, 2)
	var c := Vector2(camp_center.x, camp_center.z)
	var placed: Array[Vector2] = []
	var a0 := atan2(wreck_point.z, wreck_point.x)
	for k in 160:
		if placed.size() >= want:
			break
		var a := a0 + (k * 0.037) * (1 if k % 2 == 0 else -1)
		var r := 20.0
		while r < radius * 1.6 and height_at(cos(a) * r, sin(a) * r) > -0.35:
			r += 0.4
		var p := Vector2(cos(a) * r, sin(a) * r)
		if p.distance_to(c) > 40.0:
			continue
		var ok := true
		for q in placed:
			if q.distance_to(p) < 7.0:
				ok = false
		if not ok:
			continue
		placed.append(p)
		var fs := FishingSpot.new()
		fs.position = Vector3(p.x, 0.0, p.y)
		holder.add_child(fs)


## Хижина боцмана Стёпы — на берегу недалеко от места высадки.
func _spawn_stepa(holder: Node3D) -> void:
	var to_camp := (camp_center - wreck_point)
	to_camp.y = 0
	var side := Vector3(-to_camp.z, 0, to_camp.x).normalized()
	var hp := wreck_point + side * 9.0 + to_camp.normalized() * 3.0
	hp.y = height_at(hp.x, hp.z)
	_reserve(hp, 2.4, "хижина Стёпы")
	_reserve(hp + to_camp.normalized() * 2.6, 1.3, "Стёпа")
	var hut := Models.glb("fisher_hut")
	if hut:
		hut.position = hp
		hut.rotation.y = atan2(-to_camp.x, -to_camp.z) + PI
		holder.add_child(hut)
		var body := StaticBody3D.new()
		body.collision_layer = 4
		var cs := CollisionShape3D.new()
		var b := BoxShape3D.new()
		b.size = Vector3(2.9, 2.6, 2.5)
		cs.shape = b
		cs.position.y = 1.3
		body.add_child(cs)
		hut.add_child(body)
	var st := NPCPerson.new()
	st.npc_id = "stepa"
	var sp := hp + to_camp.normalized() * 2.6
	sp.y = height_at(sp.x, sp.z)
	st.position = sp
	holder.add_child(st)
	poi_extra["stepa"] = sp


var poi_extra: Dictionary = {}
var reserved: Array = []   # [центр Vector2, радиус, что там] — места, где не растут заросли


func _near_poi(p2: Vector2, r: float) -> bool:
	for id in poi:
		var q: Vector3 = poi[id]
		if p2.distance_to(Vector2(q.x, q.z)) < r:
			return true
	return false


## Кольца преград вокруг сюжетных мест — без нужного инструмента не пройти.
func _barrier_rings(holder: Node3D) -> void:
	# шаг по кольцу меньше диаметра преграды + игрока — щелей нет
	var specs_all := {"old_camp": [["thicket", 5.4, 18], ["jungle_tree", 7.6, 17]],
		"banyan_roots": [["liana_curtain", 11.5, 28], ["thicket", 13.2, 30]],
		"lifeboat": [["cliff", 6.0, 10]],
		"lighthouse": [["cliff", 6.2, 11]]}
	for id in specs_all:
		if not poi.has(id):
			continue
		var c: Vector3 = poi[id]
		var k := 0
		for ring in specs_all[id]:
			var kind: String = ring[0]
			var rad: float = ring[1]
			var cnt: int = ring[2]
			for i in cnt:
				k += 1
				var a := TAU * i / cnt + (0.15 if kind == "jungle_tree" else 0.0)
				var pos := c + Vector3(cos(a) * rad, 0, sin(a) * rad)
				pos.y = height_at(pos.x, pos.z) - 0.05
				var yaw := -a + PI / 2 if kind in ["cliff", "liana_curtain"] else -100.0
				_occupy(Vector2(pos.x, pos.z), footprint(kind))
				_spawn(holder, kind, pos, k * 7919 + i, "%s:r_%s_%d" % [loc, id, k], yaw)


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
		if i == 0 and loc == "home":
			banyan = isl
			var tree := Models.glb("jungle_tree_a")
			if tree:
				tree.scale = Vector3.ONE * 4.5
				tree.position = Vector3(0, 6.0, 0)
				isl.add_child(tree)
