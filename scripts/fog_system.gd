class_name FogSystem
extends Node
## Туман Туманного острова (пока не зажжён седьмой огонь).
##
## Объёмный туман окутывает весь остров: дальше нескольких шагов — белая стена. Туман расступается только
## вокруг огня: у костров, факелов, тыквенных фонарей, сигнального огня Миши и ламп лагеря — там, в объёмный туман,
## вставлены «пустоты» (FogVolume с отрицательной плотностью). Вокруг героя — маленькая пустота, с фонарём —
## больше, с фонарём со светлячками — самая большая. Тыквенные фонари на метках разгоняют туман навсегда:
## они сохраняются вместе с постройками острова. Когда горит Потерянный маяк, туман уходит совсем.

const DENSITY := 0.085
const RADIUS := {"campfire": 6.5, "torch": 4.0, "pumpkin_lantern": 7.5, "stove": 5.0}

var main: Node
var world_env: WorldEnv
var player: Node3D
var _vols := {}         # id источника -> FogVolume
var _player_vol: FogVolume
var _refresh := 0.0
var _fading := false


func _ready() -> void:
	name = "FogSystem"
	add_to_group("fog_system")
	if Game.flags.get("fog_cleared", false):
		return
	var env := world_env.env
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = DENSITY
	env.volumetric_fog_albedo = Color("d6e0d8")
	env.volumetric_fog_emission = Color(0.1, 0.12, 0.11)
	env.volumetric_fog_emission_energy = 1.0
	env.volumetric_fog_anisotropy = 0.3
	env.volumetric_fog_length = 48.0
	env.volumetric_fog_detail_spread = 1.5
	env.volumetric_fog_sky_affect = 0.7
	env.volumetric_fog_ambient_inject = 0.4
	_player_vol = _hole(3.2)
	player.add_child(_player_vol)


## Пустота в тумане радиусом r (эллипсоид пониже, чтобы был виден «потолок» тумана).
static func _hole(r: float) -> FogVolume:
	var v := FogVolume.new()
	v.shape = RenderingServer.FOG_VOLUME_SHAPE_ELLIPSOID
	v.size = Vector3(r * 2.0, 7.0, r * 2.0)
	var m := FogMaterial.new()
	m.density = -1.2
	m.edge_fade = 0.7
	v.material = m
	return v


## Насколько далеко видно от этой точки (для автотеста и подсказок).
func clear_at(p: Vector3) -> bool:
	if Game.flags.get("fog_cleared", false):
		return true
	for k in _vols:
		var v: FogVolume = _vols[k]
		if is_instance_valid(v) and Vector2(v.global_position.x - p.x, v.global_position.z - p.z).length() < v.size.x * 0.5:
			return true
	return false


func refresh() -> void:
	var alive := {}
	for id in RADIUS:
		for b in get_tree().get_nodes_in_group("station_" + id):
			_ensure(b as Node3D, float(RADIUS[id]), alive)
	for n in get_tree().get_nodes_in_group("fog_light"):
		_ensure(n as Node3D, float(n.get("fog_radius")), alive)
	for k in _vols.keys():
		if not alive.has(k):
			if is_instance_valid(_vols[k]):
				_vols[k].queue_free()
			_vols.erase(k)


func _ensure(n: Node3D, r: float, alive: Dictionary) -> void:
	var k := n.get_instance_id()
	alive[k] = true
	if _vols.has(k) and is_instance_valid(_vols[k]):
		return
	var v := _hole(r)
	v.position = Vector3(0, 1.5, 0)
	n.add_child(v)
	_vols[k] = v


var _frog_t := 4.0


func _process(delta: float) -> void:
	_frog_t -= delta
	if _frog_t <= 0.0:
		_frog_t = randf_range(5.0, 12.0)
		Audio.play("frog", randf_range(-16.0, -9.0), 0.15)
	var env := world_env.env
	if Game.flags.get("fog_cleared", false):
		# седьмой огонь горит: туман уходит в море
		if env.volumetric_fog_enabled:
			env.volumetric_fog_density = move_toward(env.volumetric_fog_density, 0.0, delta * DENSITY / 6.0)
			if env.volumetric_fog_density <= 0.0001:
				env.volumetric_fog_enabled = false
		return
	_refresh -= delta
	if _refresh <= 0.0:
		_refresh = 0.5
		refresh()
	if _player_vol:
		var r := 3.2
		if Game.light_kind() == "firefly":
			r = 9.0
		elif Game.light_kind() == "lantern":
			r = 5.5
		_player_vol.size = Vector3(r * 2.0, 7.0, r * 2.0)
