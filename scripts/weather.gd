class_name Weather
extends Node3D
## Погода и «воздух» вокруг игрока:
## - днём в солнечном свете плавают пылинки и пыльца (мир не выглядит «вакуумным»);
## - иногда проходит тёплый тропический дождь: капли, брызги на земле, тёмное мокрое небо, шум, ветер сильнее.
##   Дождь только для настроения — грядки не поливает и задания не трогает.
## Светлячки ночью — в Critters. Для проверки: аргумент --rain=0.8 включает дождь сразу.
##
## На Грозовом острове — своя погода: вечные тучи и гроза по расписанию (каждые 4–5 минут, около полутора минут).
## - за 20 секунд — гром вдали и предупреждение Румбы, на экране значок тучи;
## - в грозу ливень (грядки поливаются сами), молнии бьют в громоотводы, Башню громов и высокие скалы;
## - если стоять на открытой вершине, молния ударит рядом: отбросит и выронишь 1–2 вещи (их можно подобрать);
## - там, куда молния ударила в землю, остаётся «стекляшка» — оплавленный песок для коллекции;
## - после грозы на пару минут выглядывает солнце.
## Для проверки: --storm=1 — гроза сразу и до конца, --storm=0 — без грозы.

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
var flakes: CPUParticles3D     # снег на Ледяном острове (до оттепели)
var _wind_t := 6.0

const STORM_WARN := 20.0       # сек предупреждения до грозы
const STORM_LEN := 90.0        # сек — сама гроза
const PEAK_H := 8.5            # выше этой высоты — «открытая вершина»
var storm_island := false
var storm_phase := "calm"      # calm / warn / storm / clear (солнце после грозы)
var _phase_left := 0.0
var _strike_t := 0.0
var _storm_forced := -1
var _bolt: MeshInstance3D
var _bolt_t := 0.0
var _flash := 0.0
var _rumble_t := 0.0
var _hit_player_cd := 0.0


func _ready() -> void:
	name = "Weather"
	add_to_group("weather")
	_next = randf_range(240.0, 480.0)
	storm_island = Game.location == "storm"
	_phase_left = 60.0   # первая гроза — вскоре после высадки
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--rain="):
			_forced = clampf(float(a.split("=")[1]), 0.0, 1.0)
		if a.begins_with("--storm="):
			_storm_forced = int(a.split("=")[1])
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
	# крупные медленные хлопья: падают наискосок и чуть кружатся
	flakes = CPUParticles3D.new()
	flakes.amount = 320
	flakes.lifetime = 6.0
	flakes.preprocess = 6.0
	flakes.local_coords = false
	flakes.mesh = FX._quad(FX.particle_mat(0.9, 0.85))
	flakes.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	flakes.emission_box_extents = Vector3(16, 0.5, 16)
	flakes.direction = Vector3(0.35, -1, 0.15)
	flakes.spread = 18.0
	flakes.gravity = Vector3(0, -0.4, 0)
	flakes.initial_velocity_min = 1.2
	flakes.initial_velocity_max = 2.0
	flakes.tangential_accel_min = -0.6
	flakes.tangential_accel_max = 0.6
	flakes.scale_amount_min = 0.05
	flakes.scale_amount_max = 0.1
	flakes.color = Color(1.0, 1.0, 1.0, 0.85)
	flakes.emitting = false
	add_child(flakes)


func _process(delta: float) -> void:
	if storm_island:
		_storm_process(delta)
	elif _forced >= 0.0:
		_target = _forced
	elif Game.cold_active():
		_target = 0.0   # на Ледяном острове вместо дождя — снег
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
	if not storm_island:
		rain = _target if _forced >= 0.0 else move_toward(rain, _target, delta / 10.0)
	if world_env:
		world_env.rain = rain
	Audio.rain_level = rain
	if player == null:
		return
	var p := player.global_position
	var indoor := p.y < -8.0   # в бункере дождя нет
	motes.global_position = p + Vector3(0, 1.6, 0)
	motes.emitting = Game.is_day() and rain < 0.25 and not indoor
	drops.global_position = p + Vector3(0, 10.5, 0)
	drops.emitting = rain > (0.55 if storm_island else 0.03) and not indoor
	drops.color = Color(0.8, 0.87, 0.98, 0.38 * rain)
	splashes.global_position = Vector3(p.x, p.y + 0.05, p.z)
	splashes.emitting = rain > (0.6 if storm_island else 0.15) and not indoor
	splashes.color = Color(0.92, 0.96, 1.0, 0.7 * rain)
	# Ледяной остров: идёт снег, порывы ветра
	var cold := Game.cold_active()
	flakes.emitting = cold and not indoor
	flakes.global_position = p + Vector3(0, 9.0, 0)
	if cold and not get_tree().paused:
		_wind_t -= delta
		if _wind_t <= 0.0:
			_wind_t = randf_range(9.0, 18.0)
			Audio.play("wind", randf_range(-14.0, -8.0), 0.15)


# ================================================================== Гроза (Грозовой остров)
func _storm_process(delta: float) -> void:
	if get_tree().paused:
		return
	if _storm_forced == 1 or Game.storm_force:
		storm_phase = "storm"
		_phase_left = 999.0
	elif _storm_forced == 0:
		storm_phase = "calm"
		_phase_left = 999.0
	else:
		_phase_left -= delta
		if _phase_left <= 0.0:
			match storm_phase:
				"calm":
					storm_phase = "warn"
					_phase_left = STORM_WARN
					_warn()
				"warn":
					storm_phase = "storm"
					_phase_left = STORM_LEN
					Game.notified.emit("Гроза! Прячься под навес и не стой на вершинах", Color("bfe3ff"))
				"storm":
					storm_phase = "clear"
					_phase_left = 120.0
					Game.notified.emit("Гроза ушла, выглянуло солнце. Поищи стекляшки там, куда била молния", Color("ffe08a"))
				_:
					storm_phase = "calm"
					_phase_left = randf_range(150.0, 210.0)
	# вечные тучи; в грозу — ливень; после грозы — солнце
	var overcast: float = {"calm": 0.5, "warn": 0.62, "storm": 1.0, "clear": 0.0}[storm_phase]
	_target = overcast
	rain = move_toward(rain, _target, delta / (2.0 if storm_phase == "storm" else 8.0))
	Game.storm = 1.0 if storm_phase == "storm" else (0.3 if storm_phase == "warn" else 0.0)
	# гром вдали перед грозой
	if storm_phase == "warn":
		_rumble_t -= delta
		if _rumble_t <= 0.0:
			_rumble_t = randf_range(5.0, 9.0)
			Audio.play("thunder%d" % (randi() % 3), -16.0, 0.1)
	if storm_phase == "storm":
		_strike_t -= delta
		if _strike_t <= 0.0:
			_strike_t = randf_range(3.5, 7.0)
			_random_strike()
		# ливень поливает грядки
		for b in get_tree().get_nodes_in_group("building"):
			if b is GardenBed and b.crop != "" and not b.watered and b.progress < 1.0:
				b.watered = true
				b._refresh()
	_hit_player_cd -= delta
	# вспышка и молния гаснут
	_flash = maxf(0.0, _flash - delta * 4.0)
	if world_env:
		world_env.flash = _flash
	if _bolt:
		_bolt_t -= delta
		_bolt.visible = _bolt_t > 0.0 and fmod(_bolt_t, 0.08) > 0.03
		if _bolt_t <= 0.0:
			_bolt.queue_free()
			_bolt = null


func _warn() -> void:
	Audio.play("thunder0", -14.0, 0.05)
	if not Game.flags.get("storm_seen", false):
		Game.dialogue_requested.emit([["parrot", "Карр! Гром! Гроза идёт! Под крышу, под навес!"],
			["parrot", "В грозу не лезь наверх. Молния любит высокое. А дождь польёт грядки сам."]], Callable())
	else:
		Game.notified.emit("Карр! Гроза идёт! Под крышу!", Color("ff9d7a"))
	Game.flags["storm_seen"] = true


## Куда бьёт молния: громоотводы и башня притягивают её, иначе — высокие скалы. Игрок на вершине — рядом с ним.
func _random_strike() -> void:
	if player and _hit_player_cd <= 0.0 and _player_exposed():
		_hit_player_cd = 6.0
		var side := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * 1.6
		var at := player.global_position + side
		if island:
			at.y = island.height_at(at.x, at.z)
		strike_at(at, true)
		_knock_player(side)
		return
	var targets: Array[Vector3] = []
	for b in get_tree().get_nodes_in_group("station_lightning_rod"):
		targets.append((b as Node3D).global_position + Vector3(0, 4.2, 0))
	for n in get_tree().get_nodes_in_group("obstacle"):
		if n is StoryPlace and n.id == "storm_tower":
			targets.append(n.global_position + Vector3(0, 13.0, 0))
	if not targets.is_empty() and randf() < 0.6:
		strike_at(targets[randi() % targets.size()])
		return
	# высокое место где-нибудь на острове
	if island:
		for k in 30:
			var a := randf() * TAU
			var r := randf_range(5.0, island.radius * 0.9)
			var x := cos(a) * r
			var z := sin(a) * r
			var h := island.height_at(x, z)
			if h > 4.0:
				strike_at(Vector3(x, h, z), true)
				return


func _player_exposed() -> bool:
	if player.global_position.y < PEAK_H or player.global_position.y < -8.0:
		return false
	for b in get_tree().get_nodes_in_group("station_shelter"):
		if (b as Node3D).global_position.distance_to(player.global_position) < 1.8:
			return false
	return true


## Удар молнии в точку: ослепительный зигзаг, вспышка неба, гром (чем дальше — тем позже и тише).
func strike_at(pos: Vector3, ground := false) -> void:
	if _bolt:
		_bolt.queue_free()
	_bolt = _make_bolt(pos)
	get_parent().add_child(_bolt)
	_bolt_t = 0.35
	_flash = 1.0
	var d: float = player.global_position.distance_to(pos) if player else 30.0
	var vol := -2.0 - d * 0.18
	if player and player.global_position.y < -8.0:
		vol -= 14.0   # в бункере гром глухой
	get_tree().create_timer(clampf(d / 120.0, 0.0, 1.2), false).timeout.connect(func():
		Audio.play("thunder%d" % (randi() % 3), vol, 0.08))
	if player and d < 25.0 and player.has_method("add_trauma"):
		player.add_trauma(clampf(0.5 - d * 0.02, 0.05, 0.5))
	if ground:
		FX.sparks(get_parent(), pos + Vector3(0, 0.3, 0), 14)
		FX.poof(get_parent(), pos + Vector3(0, 0.2, 0), Color("cfc7d6"), 1.2)
		_leave_fulgurite(pos)


func _make_bolt(to: Vector3) -> MeshInstance3D:
	var top := to + Vector3(randf_range(-6, 6), 45.0, randf_range(-6, 6))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts: Array[Vector3] = [top]
	var n := 12
	for i in range(1, n):
		var t := float(i) / n
		pts.append(top.lerp(to, t) + Vector3(randf_range(-1.6, 1.6), 0, randf_range(-1.6, 1.6)) * (1.0 - t * 0.7))
	pts.append(to)
	var cam := get_viewport().get_camera_3d()
	var eye := cam.global_position if cam else to + Vector3(0, 0, 10)
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var w := 0.22 * (1.0 - float(i) / pts.size() * 0.5)
		var side := (b - a).cross(eye - a)
		side = side.normalized() * w if side.length() > 0.001 else Vector3(w, 0, 0)
		st.add_vertex(a - side)
		st.add_vertex(a + side)
		st.add_vertex(b + side)
		st.add_vertex(a - side)
		st.add_vertex(b + side)
		st.add_vertex(b - side)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.92, 0.95, 1.0)
	m.emission_enabled = true
	m.emission = Color(0.75, 0.85, 1.0)
	m.emission_energy_multiplier = 6.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var l := OmniLight3D.new()
	l.light_color = Color("cfe0ff")
	l.light_energy = 12.0
	l.omni_range = 40.0
	l.position = to + Vector3(0, 6.0, 0)
	mi.add_child(l)
	return mi


## Молния ударила рядом с игроком: отбрасывает, роняет 1–2 вещи (без вреда — их можно подобрать).
func _knock_player(from_side: Vector3) -> void:
	var push := -from_side.normalized() * 7.0 + Vector3(0, 5.0, 0)
	if player is CharacterBody3D:
		(player as CharacterBody3D).velocity = push
	if player.has_method("add_trauma"):
		player.add_trauma(0.8)
	var droppable: Array[String] = []
	for id in Game.inventory:
		var cat: String = Game.item(id).get("cat", "")
		if cat in ["material", "crop", "fruit", "product"] and Game.sellable(id) > 0:
			droppable.append(id)
	droppable.shuffle()
	var lost: Array[String] = []
	for i in mini(randi_range(1, 2), droppable.size()):
		var id := droppable[i]
		var n := mini(Game.sellable(id), randi_range(1, 3))
		Game.pay({id: n})
		var pk := Pickup.new()
		pk.item_id = id
		pk.amount = n
		var a := randf() * TAU
		var at := player.global_position + Vector3(cos(a), 0, sin(a)) * randf_range(1.5, 3.0)
		if island:
			at.y = island.height_at(at.x, at.z)
		pk.position = at
		get_parent().add_child(pk)
		lost.append(Game.item_name(id).to_lower())
	var tail := (" Выпало: %s — подбери." % ", ".join(lost)) if not lost.is_empty() else ""
	Game.notified.emit("БАХ! Молния ударила рядом и отбросила тебя!" + tail, Color("ff9d7a"))


func _leave_fulgurite(pos: Vector3) -> void:
	if Game.collection_complete("fulgurites") or get_tree().get_nodes_in_group("pickup").size() > 8 or randf() > 0.55:
		return
	if island and island.height_at(pos.x, pos.z) < 0.3:
		return
	var pk := Pickup.new()
	pk.collection = "fulgurites"
	pk.position = pos
	get_parent().add_child(pk)
