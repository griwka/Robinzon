class_name Weather
extends Node3D
## Погода и «воздух» вокруг игрока:
## - днём в солнечном свете плавают пылинки и пыльца (мир не выглядит «вакуумным»);
## - иногда проходит тёплый тропический дождь: капли, брызги на земле, тёмное мокрое небо, шум, ветер сильнее.
##   Дождь только для настроения — грядки не поливает и задания не трогает.
## Светлячки ночью — в Critters. Для проверки: аргумент --rain=0.8 включает дождь сразу.

var world_env: WorldEnv
var player: Node3D
var island: Island
var rain := 0.0            # текущая сила дождя 0..1 (меняется плавно)
var _target := 0.0
var _left := 0.0           # сколько ещё (сек) идёт дождь
var _next := 0.0           # через сколько (сек) решать, будет ли дождь
var _forced := -1.0
var motes: CPUParticles3D
var drops: CPUParticles3D
var splashes: CPUParticles3D


func _ready() -> void:
	name = "Weather"
	_next = randf_range(240.0, 480.0)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--rain="):
			_forced = clampf(float(a.split("=")[1]), 0.0, 1.0)
	motes = CPUParticles3D.new()
	motes.amount = 70
	motes.lifetime = 7.0
	motes.preprocess = 7.0
	motes.local_coords = false
	motes.mesh = FX._quad(FX.particle_mat(1.25, 0.6))
	motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	motes.emission_box_extents = Vector3(14, 3, 14)
	motes.direction = Vector3(1, 0.2, 0.3)
	motes.spread = 180.0
	motes.gravity = Vector3(0.05, 0.02, 0.0)
	motes.initial_velocity_min = 0.05
	motes.initial_velocity_max = 0.25
	motes.tangential_accel_min = -0.1
	motes.tangential_accel_max = 0.1
	motes.scale_amount_min = 0.025
	motes.scale_amount_max = 0.05
	motes.scale_amount_curve = FX.curve([Vector2(0, 0), Vector2(0.2, 1), Vector2(0.8, 1), Vector2(1, 0)])
	motes.color = Color(1.0, 0.97, 0.85, 0.55)
	add_child(motes)
	drops = CPUParticles3D.new()
	drops.amount = 900
	drops.lifetime = 0.75
	drops.local_coords = false
	drops.mesh = FX._quad(FX.particle_mat(0.0, 0.6, 8.0))
	drops.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	drops.emission_box_extents = Vector3(13, 0.5, 13)
	drops.direction = Vector3(0.12, -1, 0.05)
	drops.spread = 3.0
	drops.gravity = Vector3.ZERO
	drops.initial_velocity_min = 15.0
	drops.initial_velocity_max = 18.0
	drops.scale_amount_min = 0.026
	drops.scale_amount_max = 0.038
	drops.color = Color(0.86, 0.92, 1.0, 0.0)
	drops.emitting = false
	add_child(drops)
	splashes = CPUParticles3D.new()
	splashes.amount = 260
	splashes.lifetime = 0.35
	splashes.local_coords = false
	splashes.mesh = FX._quad(FX.particle_mat(0.0, 0.45))
	splashes.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	splashes.emission_box_extents = Vector3(11, 0.05, 11)
	splashes.direction = Vector3.UP
	splashes.spread = 60.0
	splashes.gravity = Vector3(0, -6, 0)
	splashes.initial_velocity_min = 0.6
	splashes.initial_velocity_max = 1.2
	splashes.scale_amount_min = 0.06
	splashes.scale_amount_max = 0.12
	splashes.scale_amount_curve = FX.curve([Vector2(0, 0.4), Vector2(1, 1.2)])
	splashes.color = Color(0.92, 0.96, 1.0, 0.0)
	splashes.emitting = false
	add_child(splashes)


func _process(delta: float) -> void:
	if _forced >= 0.0:
		_target = _forced
	elif not get_tree().paused:
		if _left > 0.0:
			_left -= delta
			if _left <= 0.0:
				_target = 0.0
		else:
			_next -= delta
			if _next <= 0.0:
				_next = randf_range(480.0, 960.0)
				if randf() < 0.35:
					_target = randf_range(0.55, 1.0)
					_left = randf_range(70.0, 150.0)
	rain = _target if _forced >= 0.0 else move_toward(rain, _target, delta / 10.0)
	if world_env:
		world_env.rain = rain
	Audio.rain_level = rain
	if player == null:
		return
	var p := player.global_position
	motes.global_position = p + Vector3(0, 1.6, 0)
	motes.emitting = Game.is_day() and rain < 0.25
	drops.global_position = p + Vector3(0, 10.5, 0)
	drops.emitting = rain > 0.03
	drops.color = Color(0.8, 0.87, 0.98, 0.38 * rain)
	splashes.global_position = Vector3(p.x, p.y + 0.05, p.z)
	splashes.emitting = rain > 0.15
	splashes.color = Color(0.92, 0.96, 1.0, 0.7 * rain)
