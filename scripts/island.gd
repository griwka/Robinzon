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
var flat := []      # [центр Vector2, радиус, высота, (ширина края)] — плато под постройки (форт, ледник)
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
var terrain_mat: ShaderMaterial


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
	_place_pois()   # заранее: трава не должна расти там, где будет лава
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
		var edge: float = flat[3] if flat.size() > 3 else 7.0
		h = lerpf(h, flat[2], smoothstep(flat[1] + edge, flat[1], fd))
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
	m.set_shader_parameter("painted", Models.PAINTED)
	m.set_shader_parameter("camp_pos", camp_center)
	m.set_shader_parameter("camp_radius", 5.5)
	for pair in [["sand", Palette.SAND], ["sand_dark", Palette.SAND_DARK], ["sand_light", Palette.SAND_LIGHT],
			["wet_sand", Palette.WET_SAND], ["seabed", Palette.SEABED], ["grass", Palette.GRASS],
			["grass_light", Palette.GRASS_LIGHT], ["grass_dark", Palette.GRASS_DARK], ["grass_warm", Palette.GRASS_WARM],
			["rock", Palette.ROCK], ["rock_dark", Palette.ROCK_DARK], ["dirt", Palette.DIRT], ["dirt_dark", Palette.DIRT_DARK]]:
		m.set_shader_parameter(pair[0], pair[1])
	if mix == "fog":
		# Туманный остров: илистый берег, болотная трава
		for pair in [["sand", Color("b0a382")], ["sand_dark", Color("948666")], ["sand_light", Color("c6b994")],
				["wet_sand", Color("6e624a")], ["seabed", Color("4f7f70")], ["grass", Color("6a9658")], ["grass_light", Color("80a868")],
				["grass_dark", Color("4e7848")], ["grass_warm", Color("8a9c5c")]]:
			m.set_shader_parameter(pair[0], pair[1])
	if mix == "eye":
		# Око шторма: чёрный каменный берег, тёмные скалы, сочная трава сада
		for pair in [["sand", Color("5a5456")], ["sand_dark", Color("444042")], ["sand_light", Color("706a6a")],
				["wet_sand", Color("343032")], ["seabed", Color("4f9aa8")], ["rock", Color("4e4a4e")], ["rock_dark", Color("3a363a")],
				["grass", Color("5aa04a")], ["grass_light", Color("74b45a")], ["grass_dark", Color("427a3a")]]:
			m.set_shader_parameter(pair[0], pair[1])
	if mix == "volcano":
		# Остров Вулкана: чёрный песок, сочная трава, тёмный базальт
		for pair in [["sand", Color("4c4648")], ["sand_dark", Color("3a3537")], ["sand_light", Color("625b5c")],
				["wet_sand", Color("2e2a2c")], ["seabed", Color("4fb0a8")], ["rock", Color("5e5858")], ["rock_dark", Color("454042")],
				["dirt", Color("7a5a48")], ["dirt_dark", Color("5e4638")]]:
			m.set_shader_parameter(pair[0], pair[1])
	if mix == "ice":
		# Ледяной остров: галечный берег, тундра с рыжими пятнами, выше — снег и голубой лёд
		for pair in [["sand", Color("e9e0c9")], ["sand_dark", Color("d6caae")], ["sand_light", Color("f5efe0")],
				["wet_sand", Color("b6aa92")], ["seabed", Color("72b9c9")]]:
			m.set_shader_parameter(pair[0], pair[1])
		var thawed: bool = Game.flags.get("ice_thawed", false)
		_set_grass_colors(m, 1.0 if thawed else 0.0)
		m.set_shader_parameter("snow_on", 1.0)
		m.set_shader_parameter("snow_amount", 0.0 if thawed else 1.0)
	terrain_mat = m
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
	if mix == "fog":
		# тихая вода лагуны: тёмная, зеленоватая
		water_mat.set_shader_parameter("shallow_color", Color("8cc2a8"))
		water_mat.set_shader_parameter("mid_color", Color("3f8a86"))
		water_mat.set_shader_parameter("deep_color", Color("1f4a68"))
	if mix == "ice":
		# северное море: холоднее и темнее, у берега — бледная ледяная бирюза
		water_mat.set_shader_parameter("shallow_color", Color("9ad8e2"))
		water_mat.set_shader_parameter("mid_color", Color("4aa2cc"))
		water_mat.set_shader_parameter("deep_color", Color("1f5a98"))
	var water := MeshInstance3D.new()
	water.name = "Water"
	water.mesh = plane
	water.material_override = water_mat
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)


# ------------------------------------------------------------------ Трава и цветы
const SNOW_LINE := 2.1   # Ледяной остров до оттепели: выше этой высоты — снег


## Лавовое поле перед храмом на Вулкане: там не растёт трава.
func _lava_field(x: float, z: float) -> bool:
	if poi.has("great_lighthouse"):   # Око: внутри Великого маяка трава не растёт
		var t: Vector3 = poi["great_lighthouse"]
		return Vector2(x - t.x, z - t.z).length() < 6.8
	if not poi.has("temple_gate"):
		return false
	var g: Vector3 = poi["temple_gate"]
	return Vector2(x - g.x, z - g.z).length() < 9.8


## Ледяной остров ещё скован холодом.
var cold := false
var grass_field: GrassField   # мелкая трава и цветы, которые можно расчистить


func _build_grass() -> void:
	cold = mix == "ice" and not Game.flags.get("ice_thawed", false)
	for old in ["Grass", "Flowers", "GrassField"]:
		var n := get_node_or_null(old)
		if n:
			remove_child(n)
			n.queue_free()
	# мелкая трава и цветы — кусками, их можно расчистить (GrassField)
	grass_field = GrassField.new()
	grass_field.setup(self)
	add_child(grass_field)
	if terrain_mat:
		terrain_mat.set_shader_parameter("clear_mask", grass_field.mask_texture())
		terrain_mat.set_shader_parameter("mask_origin", Vector2(-GrassField.HALF, -GrassField.HALF))
		terrain_mat.set_shader_parameter("mask_size", GrassField.HALF * 2.0)
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
		if cold and h > SNOW_LINE + detail_noise.get_noise_2d(x * 0.3, z * 0.3) * 0.8 - 0.2:
			continue   # под снегом трава не растёт
		if _lava_field(x, z):
			continue
		var s := g.randf_range(0.8, 1.6)
		tr.append(Transform3D(Basis(Vector3.UP, g.randf() * TAU).scaled(Vector3(s, s * g.randf_range(0.8, 1.3), s)), Vector3(x, h - 0.03, z)))
		cols.append(Color.WHITE.lerp(Color("e8ffb0"), g.randf() * 0.4))
	for i in tr.size():
		grass_field.add("Grass", tr[i], cols[i])
	grass_field.commit("Grass", tuft_mesh, _grass_mat(), 60.0)
	if cold:
		return   # цветы распустятся в оттепель

	var ft: Array[Transform3D] = []
	var fc: Array[Color] = []
	var palette := [Color("ff6fa5"), Color("ffd84a"), Color("ffffff"), Color("b28cff"), Color("ff8a3d"), Color("6fc3ff")]
	if mix == "ice":
		palette = [Color("ffffff"), Color("fff4c0"), Color("ffd84a"), Color("ffffff")]   # северные цветы: белые и жёлтые
	if mix == "fog":
		palette = [Color("f4f6f2"), Color("d8d0f0"), Color("cfe8f0"), Color("f4f6f2")]   # бледные цветы болота
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
			if h < 1.3 or h > 7.5 or Vector2(x - camp_center.x, z - camp_center.z).length() < 6.5 or _lava_field(x, z):
				continue
			var s := g.randf_range(0.8, 1.4)
			ft.append(Transform3D(Basis(Vector3.UP, g.randf() * TAU).scaled(Vector3(s, s, s)), Vector3(x, h + 0.12, z)))
			fc.append(col)
	var fmat := ShaderMaterial.new()
	fmat.shader = Models.TOON
	fmat.set_shader_parameter("use_vertex_color", true)
	fmat.set_shader_parameter("rim_amount", 0.0)
	fmat.set_shader_parameter("paint_amount", 0.0)
	for i in ft.size():
		grass_field.add("Flowers", ft[i], fc[i])
	grass_field.commit("Flowers", Models.flower_mesh(), fmat, 50.0)


func _grass_mat() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/grass.gdshader")
	m.set_shader_parameter("base_color", TUNDRA_TUFT_BASE if cold else Palette.TUFT_BASE)
	m.set_shader_parameter("tip_color", TUNDRA_TUFT_TIP if cold else Palette.TUFT_TIP)
	return m


# ------------------------------------------------------------------ Ледяной остров: тундра и оттепель
const TUNDRA := [Color("8a9858"), Color("a6ac6c"), Color("6a7a46"), Color("c48a52")]   # трава, светлая, тёмная, рыжие пятна
const TUNDRA_TUFT_BASE := Color("7c8a4c")
const TUNDRA_TUFT_TIP := Color("cdbc7c")


## Цвета травы на земле: k = 0 — тундра, 1 — летняя трава (после оттепели).
func _set_grass_colors(m: ShaderMaterial, k: float) -> void:
	var summer := [Palette.GRASS, Palette.GRASS_LIGHT, Palette.GRASS_DARK, Palette.GRASS_WARM]
	var names := ["grass", "grass_light", "grass_dark", "grass_warm"]
	for i in 4:
		var c: Color = (TUNDRA[i] as Color).lerp(summer[i] as Color, k * 0.75)
		m.set_shader_parameter(names[i], c)


## Оттепель (зажжено Холодное сердце): снег сходит, трава зеленеет, распускаются цветы.
func thaw(animate: bool) -> void:
	if mix != "ice" or terrain_mat == null:
		return
	if animate:
		var tw := create_tween()
		tw.tween_method(func(v: float):
			terrain_mat.set_shader_parameter("snow_amount", 1.0 - v)
			_set_grass_colors(terrain_mat, v), 0.0, 1.0, 7.0).set_trans(Tween.TRANS_SINE)
		tw.tween_callback(_build_grass)
		for i in 6:
			get_tree().create_timer(0.8 + i * 1.1, false).timeout.connect(func(): Audio.play("drip", -4.0, 0.2))
	else:
		terrain_mat.set_shader_parameter("snow_amount", 0.0)
		_set_grass_colors(terrain_mat, 1.0)
		_build_grass()
	get_tree().call_group("player", "update_clothes")


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
	if mix == "storm":
		# станция — на плато вершины, Башня громов — на восточном мысу, самолёт — в западной бухте
		var st := Vector3(flat[0].x, 0, flat[0].y)
		st.y = height_at(st.x, st.z)
		poi["station"] = st
		poi["storm_tower"] = _shore_point(0.15, 7.5)
		poi["seaplane"] = _shore_point(PI * 1.08, -1.5)
		var gv := st + Vector3(12.0, 0, 9.0)
		gv.y = height_at(gv.x, gv.z)
		poi["graves"] = gv
		for k in ["storm_tower", "seaplane", "graves"]:
			poi_extra[k] = poi[k]
		return
	if mix == "fog":
		# лагерь на сваях — в лагуне на востоке; сигнальный камень Миши — в болоте, к нему тропа от места высадки;
		# на скалистом холме — стоячие камни, скала-экран и Потерянный маяк
		poi["stilt_camp"] = _shore_point(0.25, 0.0)
		var rock := Vector3(-radius * 0.22, 0, radius * 0.08)
		rock.y = height_at(rock.x, rock.z)
		poi["signal_rock"] = rock
		var sh := Vector3(peak_center.x, 0, peak_center.y + 6.5)
		sh.y = height_at(sh.x, sh.z)
		poi["fog_shrine"] = sh
		for k in ["stilt_camp", "signal_rock", "fog_shrine"]:
			poi_extra[k] = poi[k]
		return
	if mix == "eye":
		# Великий маяк — на плато на севере, сад деда — к западу от лагеря, в кольце зарослей
		var t := Vector3(flat[0].x, 0, flat[0].y)
		t.y = height_at(t.x, t.z)
		poi["great_lighthouse"] = t
		var gd := Vector3(-radius * 0.36, 0, 3.0)
		gd.y = height_at(gd.x, gd.z)
		poi["eye_garden"] = gd
		for k in ["great_lighthouse", "eye_garden"]:
			poi_extra[k] = poi[k]
		return
	if mix == "volcano":
		# кратер — столовая гора; подъём — со стороны лагеря; храм — в стене кратера сбоку;
		# горячие источники с лечебницей Веры — недалеко от лагеря
		var cr := Vector3(flat[0].x, flat[2], flat[0].y)
		poi["crater"] = cr
		var to_c := Vector3(camp_center.x - cr.x, 0, camp_center.z - cr.z).normalized()
		var cfoot := cr + to_c * (VolcanoCrater.WALL_R + 2.0)
		cfoot.y = height_at(cfoot.x, cfoot.z)
		poi["crater_foot"] = cfoot
		var east := Vector3(-to_c.z, 0, to_c.x)
		var gate := cr + east * (VolcanoCrater.WALL_R + 0.9)
		gate.y = height_at(gate.x, gate.z)
		poi["temple_gate"] = gate
		var sp := camp_center + Vector3(-to_c.z, 0, to_c.x) * -15.0 - to_c * 4.0
		sp.y = height_at(sp.x, sp.z)
		poi["springs"] = sp
		for k in ["temple_gate", "springs", "crater_foot"]:
			poi_extra[k] = poi[k]
		return
	if mix == "ice":
		# ледник с обсерваторией — на столовой горе; тропа к нему (с моржом) — со стороны лагеря;
		# маяк — на восточном мысу, пингвины — у бухты на западе, ларцы — на уступе, под водопадом и в бору
		var gl := Vector3(flat[0].x, flat[2], flat[0].y)
		poi["glacier"] = gl
		var to_camp := Vector3(camp_center.x - gl.x, 0, camp_center.z - gl.z).normalized()
		var foot := gl + to_camp * (IceGlacier.WALL_R + 2.0)
		foot.y = height_at(foot.x, foot.z)
		poi["glacier_foot"] = foot
		poi["ice_tower"] = _shore_point(-0.3, 7.5)
		poi["penguins"] = _shore_point(PI * 1.02, 3.0)
		var ledge := Vector3(radius * 0.46, 0, radius * 0.1)
		ledge.y = height_at(ledge.x, ledge.z)
		poi["ice_ledge"] = ledge
		var grove := Vector3(-radius * 0.44, 0, -radius * 0.12)
		grove.y = height_at(grove.x, grove.z)
		poi["ice_chest_3"] = grove
		for k in ["ice_tower", "penguins", "ice_ledge", "ice_chest_3", "glacier_foot"]:
			poi_extra[k] = poi[k]
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


## Точка у берега под углом a: inland > 0 — столько метров вглубь суши от кромки, < 0 — в воду.
func _shore_point(a: float, inland: float) -> Vector3:
	var r := 15.0
	while r < 95.0 and height_at(cos(a) * r, sin(a) * r) > 0.7:
		r += 0.5
	var p := Vector3(cos(a) * (r - inland), 0, sin(a) * (r - inland))
	p.y = maxf(height_at(p.x, p.z), -0.4)
	return p


func _spawn_resources() -> void:
	if poi.is_empty():
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
		if id == "glacier":
			var gl := IceGlacier.new()
			gl.island = self
			gl.site = poi[id]
			gl.foot = poi["glacier_foot"]
			gl.position = Vector3(poi[id].x, 0, poi[id].z)
			holder.add_child(gl)
			continue
		if id in ["glacier_foot", "crater_foot"]:
			continue
		if id == "crater":
			var vc := VolcanoCrater.new()
			vc.island = self
			vc.site = poi[id]
			vc.foot = poi["crater_foot"]
			vc.position = Vector3(poi[id].x, 0, poi[id].z)
			holder.add_child(vc)
			crater_node = vc
			continue
		if id == "temple_gate":
			_pending_temple = poi[id]
			continue
		if id == "stilt_camp":
			var sc := StiltCamp.new()
			sc.island = self
			sc.position = poi[id]
			holder.add_child(sc)
			continue
		if id == "signal_rock":
			var sr := SignalRock.new()
			sr.island = self
			sr.trail_from = camp_center
			sr.position = poi[id]
			holder.add_child(sr)
			continue
		if id == "fog_shrine":
			var fs := FogShrine.new()
			fs.island = self
			fs.back = Vector3(peak_center.x - poi[id].x, 0, peak_center.y - poi[id].z).normalized()
			fs.position = poi[id]
			holder.add_child(fs)
			continue
		if id == "great_lighthouse":
			var gl8 := GreatLighthouse.new()
			gl8.island = self
			var tc := Vector3(camp_center.x - poi[id].x, 0, camp_center.z - poi[id].z)
			gl8.toward = tc.normalized() if tc.length() > 0.1 else Vector3.BACK
			gl8.position = poi[id]
			holder.add_child(gl8)
			continue
		if id == "eye_garden":
			var eg := EyeIsland.new()
			eg.island = self
			var fc := Vector3(camp_center.x - poi[id].x, 0, camp_center.z - poi[id].z)
			eg.front = fc.normalized() if fc.length() > 0.1 else Vector3.BACK
			eg.position = poi[id]
			holder.add_child(eg)
			continue
		if id == "springs":
			var hs := HotSprings.new()
			hs.island = self
			hs.position = poi[id]
			holder.add_child(hs)
			continue
		if id == "penguins":
			var pc := PenguinColony.new()
			pc.island = self
			pc.position = poi[id]
			holder.add_child(pc)
			continue
		if id == "ice_ledge":
			var il := IceLedge.new()
			il.position = poi[id]
			il.rotation.y = atan2(camp_center.x - poi[id].x, camp_center.z - poi[id].z)
			holder.add_child(il)
			continue
		if id == "station":
			var stn := StormStation.new()
			stn.site = poi[id]
			stn.position = Vector3(poi[id].x, 0, poi[id].z)
			holder.add_child(stn)
			poi_extra["timur"] = poi[id] + Vector3(-1.2, 0, 2.4)
			continue
		var sp := StoryPlace.new()
		sp.id = id
		sp.position = poi[id]
		sp.rotation.y = rng.randf() * TAU
		if id == "seaplane":
			sp.rotation.y = atan2(poi[id].x, poi[id].z) + PI * 0.5
		elif id in ["storm_tower", "ice_tower"]:
			sp.rotation.y = 0.0
		holder.add_child(sp)

	var patch := FastNoiseLite.new()
	patch.seed = seed_value + 5
	patch.frequency = 0.045
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
			if mix == "fog" and h > -0.5 and h < 0.15 and roll < 0.22 and not _near_poi(Vector2(x, z), 10.0) \
					and Vector2(x - poi["stilt_camp"].x, z - poi["stilt_camp"].z).length() > 21.0:
				# мангры стоят прямо в мелкой воде, на корнях-ходулях
				_uid += 1
				_spawn(holder, "mangrove", Vector3(x, h - 0.05, z), seed_v, loc + ":m%d" % _uid, -100.0)
				continue
			if h < 0.15:
				continue
			var p2 := Vector2(x, z)
			var dc := p2.distance_to(camp2)
			var dw := p2.distance_to(wreck2)
			if _near_poi(p2, {"banyan": 10.0, "fort": 14.5, "storm": 10.5, "ice": 11.0, "volcano": 11.0, "fog": 10.0, "eye": 9.0}.get(mix, 5.0)):
				continue
			if mix == "fog" and _near_trail(p2):
				continue
			var kind := ""
			if mix == "eye" and dc >= 9.5 and dw >= 7.0:
				kind = _eye_kind(h, roll, seed_v)
			elif mix == "fog" and dc >= 9.5 and dw >= 7.0:
				kind = _fog_kind(h, dc, roll, seed_v)
			elif mix == "volcano" and dc >= 9.5 and dw >= 7.0:
				kind = _volcano_kind(h, dc, roll, seed_v)
			elif mix == "ice" and dc >= 9.5 and dw >= 7.0:
				kind = _ice_kind(h, dc, roll, seed_v, p2)
			elif mix == "storm" and dc >= 9.5 and dw >= 7.0:
				kind = _storm_kind(h, dc, roll, seed_v)
			elif dc < 9.5 or dw < 7.0:
				# стартовая полянка: только мелочь на песке
				if h < 1.05 and roll < 0.12:
					kind = ["pebble", "shell", "driftwood"][seed_v % 3]
				elif mix == "ice" and h > 1.05 and h < SNOW_LINE and roll < 0.1:
					kind = "moss"
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
				if h > 1.1 and roll > 0.94 and dc > 9.5:
					_add_decor(decor, "flower_patch", Vector3(x, h - 0.03, z), seed_v)
				continue
			_spawn(holder, kind, Vector3(x, h - 0.05, z), seed_v, ("j%d" if loc == "home" else loc + ":j%d") % _uid, -100.0)
	_barrier_rings(holder)
	_spawn_fishing_spots(holder)
	if mix == "fort":
		_spawn_stepa(holder)
		_spawn_clay(holder)
	if mix == "home":
		var tide := TideScrap.new()   # волны выносят на песок обломки — железо на новое мачете
		tide.island = self
		tide.holder = holder
		add_child(tide)
	if mix == "storm":
		_spawn_scrap(holder)
		_spawn_pits(holder, "sand", 6, "storm:sand_%d")
	if mix == "ice":
		_spawn_floes(decor)
	if mix == "fog":
		var life := FogLife.new()
		life.island = self
		holder.add_child(life)
	if mix == "volcano":
		_spawn_obsidian(holder)
	if mix == "volcano" and crater_node:
		# храм строится после кратера: ему нужна стена кратера, чтобы упереть в неё лавовые ручьи
		var tp := VolcanoTemple.new()
		tp.island = self
		tp.crater = crater_node
		tp.position = _pending_temple
		holder.add_child(tp)


## Око шторма: чёрные камни на берегу, выше — трава, кусты и валуны; деревьев мало (остров каменный).
func _eye_kind(h: float, roll: float, seed_v: int) -> String:
	if h < 1.05:
		if roll < 0.09: return ["pebble", "shell", "driftwood"][seed_v % 3]
		if roll < 0.14: return "rock"
		return ""
	if roll < 0.2: return "tall_grass"
	if roll < 0.3: return "fern"
	if roll < 0.37: return "bush"
	if roll < 0.43: return "rock"
	if roll < 0.46: return "palm"
	if roll < 0.48: return "pebble"
	return ""


## Ледяной остров: на берегу — галька и льдины, в тундре — мох, брусника и сосны (у западного бора — гуще),
## выше — снег, ледяные глыбы (лёд для мороженого), валуны и ледяные стены.
func _ice_kind(h: float, dc: float, roll: float, seed_v: int, p2: Vector2) -> String:
	var grove: Vector3 = poi.get("ice_chest_3", Vector3(9999, 0, 0))
	var in_grove := p2.distance_to(Vector2(grove.x, grove.z)) < 16.0
	if h < 1.05:
		if roll < 0.08: return ["pebble", "shell", "driftwood"][seed_v % 3]
		if roll < 0.13: return "ice_block"
		if roll < 0.18: return "moss"
		if roll < 0.2: return "rock"
		return ""
	var tundra := h < SNOW_LINE + 0.4   # выше — снег: там ни мха, ни брусники
	if in_grove and h < 6.0:
		if roll < 0.4: return "pine"
		if roll < 0.55 and tundra: return "moss"
		if roll < 0.62: return "lingonberry"
		return ""
	if h > 6.5:
		if roll < 0.12: return "ice_block"
		if roll < 0.24: return "rock"
		if roll < 0.32: return "ice_wall"
		return ""
	if dc < 17.0:
		if roll < 0.3: return "moss" if tundra else ""
		if roll < 0.42: return "lingonberry"
		if roll < 0.5: return "pine"
		if roll < 0.55: return "rock"
		return ""
	if roll < 0.13: return "pine"
	if roll < 0.3: return "moss" if tundra else ""
	if roll < 0.38: return "lingonberry" if tundra else ""
	if roll < 0.44: return "rock"
	if roll < 0.5: return "ice_block"
	if roll < 0.55 and h > 3.0: return "ice_wall"
	if roll < 0.58: return "fallen_log"
	return ""


## Туманный остров: тропа от места высадки к сигнальному камню — без зарослей.
func _near_trail(p: Vector2) -> bool:
	if not poi.has("signal_rock"):
		return false
	var a := Vector2(camp_center.x, camp_center.z)
	var b := Vector2(poi["signal_rock"].x, poi["signal_rock"].z)
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
	return p.distance_to(a + ab * t) < 2.8


## Туманный остров: на берегу — мангры, коряги; в болоте — трава, папоротник, кусты, мангры, редкие деревья;
## на холме — камни.
func _fog_kind(h: float, dc: float, roll: float, seed_v: int) -> String:
	if h < 1.05:
		if roll < 0.18: return "mangrove"
		if roll < 0.26: return "tall_grass"
		if roll < 0.31: return ["shell", "driftwood"][seed_v % 2]
		return ""
	if h > 4.5:
		if roll < 0.18: return "rock"
		if roll < 0.36: return "tall_grass"
		if roll < 0.42: return "fern"
		return ""
	if dc < 17.0:
		if roll < 0.28: return "tall_grass"
		if roll < 0.42: return "fern"
		if roll < 0.5: return "bush"
		return ""
	if roll < 0.2: return "tall_grass"
	if roll < 0.36: return "fern"
	if roll < 0.44: return "mangrove"
	if roll < 0.52: return "bush"
	if roll < 0.57: return "jungle_tree"
	if roll < 0.62: return "fallen_log"
	if roll < 0.65: return "rock"
	return ""


var crater_node: VolcanoCrater
var _pending_temple := Vector3.ZERO


## Обсидиан — чёрные глыбы у подножия кратера (с тыльной стороны, подальше от храма и подъёма). Отрастает.
func _spawn_obsidian(holder: Node3D) -> void:
	var cr: Vector3 = poi["crater"]
	var gate: Vector3 = poi["temple_gate"]
	var foot: Vector3 = poi["crater_foot"]
	var k := 0
	for i in 22:
		var a := TAU * i / 22.0
		var p := cr + Vector3(cos(a), 0, sin(a)) * 12.3
		if Vector2(p.x - gate.x, p.z - gate.z).length() < 13.5 or Vector2(p.x - foot.x, p.z - foot.z).length() < 5.0:
			continue
		var h := height_at(p.x, p.z)
		if h < 1.2:
			continue
		k += 1
		_spawn(holder, "obsidian_rock", Vector3(p.x, h - 0.05, p.z), 9100 + k, "volcano:obs_%d" % k, -100.0)


## Остров Вулкана: на чёрном пляже — пальмы и коряги; на склонах — папоротник, трава, алоэ, дикий кофе,
## горелые деревья (уголь), рыжие рудные жилы; выше, у кратера, — обсидиан и базальтовые столбы.
func _volcano_kind(h: float, dc: float, roll: float, seed_v: int) -> String:
	if h < 1.05:
		if roll < 0.1: return ["pebble", "shell", "driftwood"][seed_v % 3]
		if roll < 0.18: return "palm"
		if roll < 0.21: return "rock"
		return ""
	if dc < 17.0:
		if roll < 0.24: return "tall_grass"
		if roll < 0.38: return "fern"
		if roll < 0.5: return "aloe"
		if roll < 0.58: return "coffee_bush"
		if roll < 0.64: return "bush"
		if roll < 0.69: return "palm"
		return ""
	if h > 5.0:
		if roll < 0.12: return "obsidian_rock"
		if roll < 0.22: return "charred_tree"
		if roll < 0.3: return "rock"
		if roll < 0.36: return "ore_vein"
		if roll < 0.4: return "aloe"
		return ""
	if roll < 0.14: return "fern"
	if roll < 0.27: return "tall_grass"
	if roll < 0.36: return "coffee_bush"
	if roll < 0.45: return "aloe"
	if roll < 0.53: return "charred_tree"
	if roll < 0.6: return "ore_vein"
	if roll < 0.65: return "palm"
	if roll < 0.7: return "jungle_tree"
	if roll < 0.75: return "bush"
	if roll < 0.78: return "rock"
	if roll < 0.8: return "basalt"
	return ""


## Льдины в море вокруг Ледяного острова (только для вида).
func _spawn_floes(decor: Node3D) -> void:
	var g := RandomNumberGenerator.new()
	g.seed = seed_value + 31
	var n := 0
	for k in 300:
		if n >= 22:
			break
		var a := g.randf() * TAU
		var r := g.randf_range(radius * 1.05, radius * 1.6)
		var x := cos(a) * r
		var z := sin(a) * r
		var h := height_at(x, z)
		if h > -1.4 or h < -5.5:
			continue
		if Vector2(x - wreck_point.x, z - wreck_point.z).length() < 9.0:
			continue
		var m := Models.glb(["ice_floe_a", "ice_floe_b"][n % 2])
		if m == null:
			return
		var s := g.randf_range(0.7, 1.5)
		m.scale = Vector3(s, s, s)
		m.position = Vector3(x, -0.08, z)
		m.rotation.y = g.randf() * TAU
		decor.add_child(m)
		n += 1


## Грозовой остров: вереск и черника на холмах, кривые деревья, валуны; у вершины — камни.
func _storm_kind(h: float, dc: float, roll: float, seed_v: int) -> String:
	if h < 1.05:
		if roll < 0.06: return "crooked_tree"
		if roll < 0.14: return "tall_grass"
		if roll < 0.22: return ["pebble", "shell", "driftwood"][seed_v % 3]
		if roll < 0.25: return "rock"
		return ""
	if h > 8.0:
		if roll < 0.3: return "rock"
		if roll < 0.55: return "heather"
		return ""
	if dc < 17.0:
		if roll < 0.3: return "heather"
		if roll < 0.45: return "tall_grass"
		if roll < 0.55: return "blueberry"
		if roll < 0.62: return "bush"
		if roll < 0.68: return "rock"
		return ""
	if roll < 0.14: return "crooked_tree"
	if roll < 0.38: return "heather"
	if roll < 0.48: return "blueberry"
	if roll < 0.6: return "tall_grass"
	if roll < 0.66: return "bush"
	if roll < 0.74: return "rock"
	if roll < 0.78: return "fallen_log"
	return ""


## Кучи ржавого железа — у станции (снаружи скал) и у самолёта в бухте. Железо со временем находится снова.
func _spawn_scrap(holder: Node3D) -> void:
	var k := 0
	for spec in [["station", 12.5, 7], ["seaplane", 6.0, 7]]:
		var c: Vector3 = poi[spec[0]]
		var n: int = spec[2]
		var rad: float = spec[1]
		for i in n:
			var a := TAU * i / n + 0.4
			var p := c + Vector3(cos(a), 0, sin(a)) * rad
			var h := height_at(p.x, p.z)
			if h < 0.25:
				continue
			k += 1
			_spawn(holder, "scrap_pile", Vector3(p.x, h - 0.03, p.z), 7000 + k, "storm:scrap_%d" % k, -100.0)


## Ямы у воды недалеко от лагеря (песок на Грозовом) — восстанавливаются.
func _spawn_pits(holder: Node3D, kind: String, want: int, uid_fmt: String) -> void:
	var c := Vector2(camp_center.x, camp_center.z)
	var placed: Array[Vector2] = []
	var a0 := atan2(wreck_point.z, wreck_point.x)
	for k in 400:
		if placed.size() >= want:
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
		_spawn(holder, kind, Vector3(p.x, h - 0.03, p.y), 4000 + k, uid_fmt % placed.size(), -100.0)


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
		_spawn(holder, "clay", Vector3(p.x, h - 0.03, p.y), 4000 + k, "fort:clay_%d" % placed.size(), -100.0)


## Места для рыбалки — бурлящая вода у берега недалеко от лагеря.
func _spawn_fishing_spots(holder: Node3D) -> void:
	var want: int = {"fort": 4, "home": 2, "banyan": 2, "storm": 3, "ice": 2, "volcano": 3}.get(mix, 2)
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
	var sp := hp + to_camp.normalized() * 2.6
	sp.y = height_at(sp.x, sp.z)
	poi_extra["stepa"] = sp
	if not Game.flags.get("stepa_at_fog", false):   # глава 7: Стёпа уплыл к своим на Туманный
		var st := NPCPerson.new()
		st.npc_id = "stepa"
		st.position = sp
		holder.add_child(st)
	# бот боцмана лежит на берегу у хижины, кормой к воде (глава 4)
	var bp := hp - side * 4.5 - to_camp.normalized() * 2.0
	bp.y = maxf(height_at(bp.x, bp.z), 0.05)
	var boat := StoryPlace.new()
	boat.id = "stepa_boat"
	boat.position = bp
	boat.rotation.y = atan2(to_camp.x, to_camp.z)
	holder.add_child(boat)
	poi_extra["stepa_boat"] = bp


var poi_extra: Dictionary = {}


func _near_poi(p2: Vector2, r: float) -> bool:
	for id in poi:
		var q: Vector3 = poi[id]
		if p2.distance_to(Vector2(q.x, q.z)) < r:
			return true
	return false


## Кольца преград вокруг сюжетных мест — без нужного инструмента не пройти.
## [вид преграды, радиус кольца, сколько штук]
const RINGS := {"old_camp": [["thicket", 5.4, 18], ["jungle_tree", 7.6, 17]],
	"banyan_roots": [["liana_curtain", 11.5, 28], ["thicket", 13.2, 30]],
	"lifeboat": [["cliff", 6.0, 10]],
	"lighthouse": [["cliff", 6.2, 11]],
	"station": [["cliff", 9.4, 17]],
	"storm_tower": [["rockfall", 5.2, 12]],
	# Ледяной: у подножия ледника — полукольцо ледяных стен (вторую половину закрывает обрыв), маяк — во льду
	"glacier_foot": [["ice_wall", 4.6, 14]],
	"ice_tower": [["ice_wall", 5.4, 14]],
	# Вулкан: лавовое поле перед храмом закрыто полукольцом базальтовых столбов (вторую половину — стена кратера)
	"temple_gate": [["basalt", 10.9, 28]],
	# Око: сад деда зарос колючим кустарником — только мачете
	"eye_garden": [["thicket", 7.6, 26]]}


func _barrier_rings(holder: Node3D) -> void:
	# шаг по кольцу меньше диаметра преграды + игрока — щелей нет
	var specs_all := RINGS
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
				var mesa: Vector3 = poi.get("glacier", poi.get("crater", Vector3(9999, 0, 9999)))
				if Vector2(pos.x - mesa.x, pos.z - mesa.z).length() < IceGlacier.WALL_R + 1.1:
					continue   # эту часть кольца закрывает обрыв (ледник или кратер)
				pos.y = height_at(pos.x, pos.z) - 0.05
				var yaw := -a + PI / 2 if kind in ["cliff", "liana_curtain", "rockfall", "ice_wall", "basalt"] else -100.0
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
	if mix == "eye":
		# вокруг Ока — стена шторма, семь лучей и острова архипелага (их строит EyeStorm)
		var es := EyeStorm.new()
		var t: Vector3 = poi.get("great_lighthouse", Vector3.ZERO)
		es.top = t + Vector3(0, GreatLighthouse.H[2] + 5.0, 0)
		parent.add_child(es)
		return
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
