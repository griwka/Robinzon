class_name EyeStorm
extends Node3D
## Око шторма: вокруг острова стеной кружится шторм, а над водой к вершине Великого маяка сходятся
## семь лучей — от семи маяков архипелага (их острова видны вдали, у самой стены).
## Финал «Открытое море» — стена светлеет и растворяется, лучи гаснут. Финал «Хранитель огня» — всё остаётся;
## «зажечь лучи» (день щедрости) — лучи вспыхивают ярче, окно в шторме — стена ненадолго редеет.

const WALL_R := 200.0
const WALL_H := 78.0
const ISLAND_R := 140.0
## Семь маяков: остров, цвет огня, угол (рад.) — откуда идёт луч.
const LIGHTS := [
	["home", Color("ffc070"), 0.3], ["banyan", Color("ffb050"), 1.2], ["fort", Color("ffd27a"), 2.1],
	["storm", Color("cfe4ff"), 3.0], ["ice", Color("a8e0ff"), 3.9], ["volcano", Color("ff7a3a"), 4.8], ["fog", Color("d8ffa0"), 5.6],
]

var top := Vector3(0, 33, 0)      # куда сходятся лучи (вершина Великого маяка)
var wall: Node3D
var _wall_mats: Array[ShaderMaterial] = []
var beams: Array[MeshInstance3D] = []
var _flash := 0.0
var _flash_t := 4.0
var _gone := false


static func beam_mat(c: Color, energy: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/beam.gdshader")
	m.set_shader_parameter("color", c)
	m.set_shader_parameter("energy", energy)
	return m


func _ready() -> void:
	add_to_group("eye_storm")
	var g := RandomNumberGenerator.new()
	g.seed = 8088
	# острова архипелага вдали — с огоньком маяка
	for spec in LIGHTS:
		var a: float = spec[2]
		var isl := Models.distant_island(g, g.randf_range(9.0, 13.0))
		isl.position = Vector3(cos(a), 0, sin(a)) * ISLAND_R + Vector3(0, -0.2, 0)
		add_child(isl)
		var spark := MeshInstance3D.new()
		spark.mesh = Models.sphere(0.9, 8, 5)
		spark.material_override = Models.flame_mat(Color("fff6d0"), spec[1], 4.0)
		spark.position = isl.position + Vector3(0, 9.0, 0)
		spark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		spark.name = "Spark"
		add_child(spark)
	if Game.flags.get("ending_open_sea", false):
		_gone = true
		return
	# стена шторма
	wall = Models.glb("storm_wall")
	if wall == null:
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 1.0
		cm.bottom_radius = 1.0
		cm.height = 1.0
		cm.cap_top = false
		cm.cap_bottom = false
		mi.mesh = cm
		mi.position.y = 0.5
		wall = Node3D.new()
		wall.add_child(mi)
	wall.scale = Vector3(WALL_R, WALL_H, WALL_R)
	wall.position.y = -6.0
	add_child(wall)
	var noise := NoiseTexture2D.new()
	noise.seamless = true
	noise.width = 512
	noise.height = 256
	var fn := FastNoiseLite.new()
	fn.frequency = 0.012
	fn.fractal_octaves = 4
	noise.noise = fn
	for mi in wall.find_children("*", "MeshInstance3D", true, false):
		var m := ShaderMaterial.new()
		m.shader = preload("res://shaders/storm_wall.gdshader")
		m.set_shader_parameter("noise_tex", noise)
		(mi as MeshInstance3D).material_override = m
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_wall_mats.append(m)
	# лучи
	for spec in LIGHTS:
		var a: float = spec[2]
		var from := Vector3(cos(a), 0, sin(a)) * ISLAND_R + Vector3(0, 9.0, 0)
		beams.append(_beam(from, top, spec[1]))


func _beam(from: Vector3, to: Vector3, c: Color) -> MeshInstance3D:
	var d := to - from
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.45
	cm.bottom_radius = 1.6
	cm.height = d.length()
	cm.radial_segments = 12
	cm.cap_top = false
	cm.cap_bottom = false
	mi.mesh = cm
	mi.material_override = beam_mat(c, 0.9)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var y := d.normalized()
	var x := y.cross(Vector3.UP)
	if x.length() < 0.01:
		x = Vector3.RIGHT
	x = x.normalized()
	var z := x.cross(y).normalized()
	mi.transform = Transform3D(Basis(x, y, z), from + d * 0.5)
	add_child(mi)
	return mi


func _process(delta: float) -> void:
	if wall == null:
		return
	wall.rotation.y += delta * 0.01
	# молнии в стене: вспышка и далёкий гром
	_flash_t -= delta
	if _flash_t <= 0.0 and not _gone:
		_flash_t = randf_range(5.0, 11.0)
		_flash = 1.0
		Audio.play("thunder%d" % randi_range(0, 2), -18.0, 0.1)
	_flash = move_toward(_flash, 0.0, delta * 2.5)
	for m in _wall_mats:
		m.set_shader_parameter("flash", _flash)


## Финал «Открытое море»: стена светлеет и уходит, лучи гаснут один за другим.
func dissolve() -> void:
	if _gone:
		return
	_gone = true
	var tw := create_tween()
	for i in beams.size():
		var m: ShaderMaterial = beams[i].material_override
		tw.tween_method(func(v: float): m.set_shader_parameter("fade", v), 1.0, 0.0, 0.8)
	for m in _wall_mats:
		tw.parallel().tween_method(func(v: float):
			m.set_shader_parameter("fade", v)
			m.set_shader_parameter("light", Color(0.55, 0.6, 0.72).lerp(Color(0.95, 0.96, 1.0), 1.0 - v)), 1.0, 0.0, 9.0)
	for s in find_children("Spark", "MeshInstance3D", false, false):
		tw.parallel().tween_property(s, "scale", Vector3(0.01, 0.01, 0.01), 4.0)
	tw.tween_callback(func(): if wall: wall.visible = false)


## «Зажечь лучи»: лучи вспыхивают и снова становятся спокойными.
func pulse() -> void:
	for b in beams:
		var m: ShaderMaterial = b.material_override
		var tw := create_tween()
		tw.tween_method(func(v: float): m.set_shader_parameter("energy", v), 0.9, 3.0, 0.6)
		tw.tween_method(func(v: float): m.set_shader_parameter("energy", v), 3.0, 0.9, 2.5)


## Окно в шторме: стена ненадолго редеет.
func open_window() -> void:
	for m in _wall_mats:
		var tw := create_tween()
		tw.tween_method(func(v: float): m.set_shader_parameter("fade", v), 1.0, 0.35, 2.0)
		tw.tween_interval(4.0)
		tw.tween_method(func(v: float): m.set_shader_parameter("fade", v), 0.35, 1.0, 3.0)


func gone() -> bool:
	return _gone
