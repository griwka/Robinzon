extends Node3D
## Точка входа: собирает мир (остров, свет, небо, игрок, UI) и связывает системы.

var island: Island
var player: Player
var hud: HUD
var build: BuildSystem
var buildings_root: Node3D
var env: Environment
var sky_mat: ProceduralSkyMaterial
var sun: DirectionalLight3D
var moon: DirectionalLight3D
var clouds: Array[Node3D] = []
var _autosave_t := 0.0

# палитры неба: [верх, горизонт, свет солнца, энергия солнца, окружающий свет]
const SKY_DAY := [Color("3d9be9"), Color("bfe8ff"), Color("fff3d6"), 1.25, 0.8]
const SKY_SUNSET := [Color("4a5fa8"), Color("ffb37a"), Color("ffb070"), 0.9, 0.6]
const SKY_NIGHT := [Color("0c1430"), Color("2c3f6e"), Color("8fa8ff"), 0.0, 0.35]


func _ready() -> void:
	_setup_environment()

	island = Island.new()
	island.name = "Island"
	add_child(island)
	island.build()
	island.spawn_distant_scenery(self)

	buildings_root = Node3D.new()
	buildings_root.name = "Buildings"
	add_child(buildings_root)

	player = Player.new()
	player.name = "Player"
	add_child(player)
	player.global_position = island.spawn_point
	player.camera_yaw = PI  # смотрим вглубь острова

	build = BuildSystem.new()
	build.island = island
	build.player = player
	build.buildings_root = buildings_root
	add_child(build)
	build.placed.connect(_on_building_placed)
	build.cancelled.connect(func(): player.can_interact = true)

	hud = HUD.new()
	add_child(hud)
	hud.station_check = _near_station
	hud.build_selected.connect(_on_build_selected)
	hud.panels_changed.connect(_on_panels_changed)
	hud.new_game_requested.connect(_new_game)

	_spawn_clouds()
	_load()
	if not OS.get_cmdline_user_args().is_empty():
		var dev := preload("res://scripts/dev_tools.gd").new()
		dev.main = self
		add_child(dev)
	_capture_mouse(true)
	if Game.quest_index == 0:
		hud.toast("Ты очнулся на берегу необитаемого острова...", Color("ffe08a"))
		hud.toast("F1 — управление", Color("bfe3ff"))


# ================================================================== Окружение
func _setup_environment() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_curve = 0.12
	sky_mat.ground_bottom_color = Color("1d6fa8")
	sky_mat.ground_horizon_color = Color("bfe8ff")
	sky_mat.sun_angle_max = 20.0
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.55
	env.ambient_light_color = Color("ffe9cf")  # тёплые тени, как в мультфильмах
	env.ambient_light_sky_contribution = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.05
	env.fog_enabled = true
	env.fog_light_color = Color("bfe8ff")
	env.fog_density = 0.0035
	env.fog_sky_affect = 0.15
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.15
	env.adjustment_contrast = 1.05
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 70.0
	sun.shadow_blur = 1.5
	add_child(sun)
	moon = DirectionalLight3D.new()
	moon.name = "Moon"
	moon.light_color = Color("8fa8ff")
	moon.light_energy = 0.0
	moon.rotation = Vector3(-1.0, 0.6, 0)
	add_child(moon)


func _update_sky() -> void:
	var t := Game.time_of_day
	var angle := (t - 0.25) * TAU            # 0 — рассвет, PI/2 — полдень, PI — закат
	var elev := sin(angle)                    # высота солнца над горизонтом -1..1
	sun.rotation = Vector3(-angle, deg_to_rad(-35), 0)
	var a: Array
	var b: Array
	var k: float
	if elev > 0.25:
		a = SKY_DAY; b = SKY_DAY; k = 0.0
	elif elev > 0.0:
		a = SKY_SUNSET; b = SKY_DAY; k = elev / 0.25
	elif elev > -0.2:
		a = SKY_NIGHT; b = SKY_SUNSET; k = (elev + 0.2) / 0.2
	else:
		a = SKY_NIGHT; b = SKY_NIGHT; k = 0.0
	var top: Color = a[0].lerp(b[0], k)
	var hor: Color = a[1].lerp(b[1], k)
	sky_mat.sky_top_color = top
	sky_mat.sky_horizon_color = hor
	sky_mat.ground_horizon_color = hor
	sky_mat.ground_bottom_color = top.darkened(0.3)
	env.fog_light_color = hor
	sun.light_color = a[2].lerp(b[2], k)
	sun.light_energy = lerpf(a[3], b[3], k) if elev > -0.05 else 0.0
	sun.visible = sun.light_energy > 0.01
	env.ambient_light_energy = lerpf(a[4], b[4], k)
	moon.light_energy = clampf(-elev * 1.5, 0.0, 0.35)
	# у горизонта тени очень длинные и рябят — плавно гасим их
	sun.shadow_opacity = clampf((elev - 0.05) * 5.0, 0.0, 1.0)


func _spawn_clouds() -> void:
	var g := RandomNumberGenerator.new()
	g.seed = 4242
	for i in 14:
		var c := Models.cloud(g)
		c.position = Vector3(g.randf_range(-250, 250), g.randf_range(55, 80), g.randf_range(-250, 250))
		c.scale = Vector3.ONE * g.randf_range(0.8, 1.6)
		add_child(c)
		clouds.append(c)


func _process(delta: float) -> void:
	_update_sky()
	for c in clouds:
		c.position.x += delta * 2.0
		if c.position.x > 280:
			c.position.x = -280
	if not hud.any_open():
		if build.is_active():
			hud.set_hint("ЛКМ — поставить «%s»,  R — повернуть,  ПКМ — отмена" % Game.BUILDINGS[build.active_id]["name"])
		else:
			hud.set_hint(player.get_hint())
	else:
		hud.set_hint("")
	hud.set_crosshair(build.is_active())
	_autosave_t += delta
	if _autosave_t > 90.0:
		_autosave_t = 0.0
		_save()


# ================================================================== Ввод
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if hud.any_open():
			hud.close_all()
		elif Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			_capture_mouse(false)
		return
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not hud.any_open():
		_capture_mouse(true)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("craft_menu"):
		if hud.craft_panel.visible:
			hud.close_all()
		else:
			build.cancel(false)
			hud.open_craft()
	elif event.is_action_pressed("build_menu"):
		if hud.build_panel.visible:
			hud.close_all()
		else:
			build.cancel(false)
			hud.open_build()
	elif event.is_action_pressed("help"):
		if hud.help_panel.visible:
			hud.close_all()
		else:
			hud.show_help()
	elif event.is_action_pressed("eat"):
		Game.eat_best_food()
	elif event.is_action_pressed("save"):
		_save()
	elif event.is_action_pressed("load"):
		get_tree().reload_current_scene()
	elif event.is_action_pressed("new_game"):
		_new_game()


func _capture_mouse(on: bool) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if on else Input.MOUSE_MODE_VISIBLE


func _on_panels_changed(open: bool) -> void:
	player.controls_enabled = not open
	_capture_mouse(not open)


func _on_build_selected(id: String) -> void:
	player.can_interact = false
	build.start(id)


func _on_building_placed(b: Building) -> void:
	_connect_building(b)
	if not build.is_active():
		# небольшая задержка, чтобы клик установки не засчитался как удар
		get_tree().create_timer(0.2).timeout.connect(func(): player.can_interact = true)


func _connect_building(b: Building) -> void:
	b.craft_requested.connect(func(station): hud.open_craft(station))
	b.sleep_requested.connect(_sleep)
	b.sail_requested.connect(func():
		Game.register_sailed()
		hud.show_victory())


func _near_station(station: String) -> bool:
	for b in get_tree().get_nodes_in_group("station_" + station):
		if b.global_position.distance_to(player.global_position) < 4.0:
			return true
	return false


func _sleep() -> void:
	player.controls_enabled = false
	hud.fade_through(func():
		if Game.time_of_day > 0.27:
			Game.day += 1
		Game.time_of_day = 0.27
		Game.add_energy(Game.MAX_ENERGY)
		hud.toast("Доброе утро! Силы восстановлены.", Color("ffe08a"))
		player.controls_enabled = true
		_save())


# ================================================================== Сохранение
func _save() -> void:
	var list := []
	for b in get_tree().get_nodes_in_group("building"):
		list.append({"id": b.id, "x": b.global_position.x, "y": b.global_position.y,
			"z": b.global_position.z, "rot": b.rotation.y})
	var p := player.global_position
	Game.save_game({"buildings": list, "player": [p.x, p.y, p.z]})


func _load() -> void:
	var data := Game.load_game()
	if data.is_empty():
		return
	for b in data.get("buildings", []):
		var node := build.spawn_building(b["id"], Vector3(b["x"], b["y"], b["z"]), b["rot"])
		_connect_building(node)
	var p: Array = data.get("player", [])
	if p.size() == 3:
		player.global_position = Vector3(p[0], p[1] + 0.3, p[2])
		player.cam_rig.global_position = player.global_position + Vector3(0, 1.4, 0)
	hud.toast("Сохранение загружено (день %d)" % Game.day, Color("bfe3ff"))


func _new_game() -> void:
	Game.reset()
	get_tree().reload_current_scene()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and player:
		_save()
