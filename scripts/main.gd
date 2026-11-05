extends Node3D
## Точка входа: собирает мир (остров, свет, небо, игрок, NPC, UI) и связывает системы.

var island: Island
var player: Player
var hud: HUD
var build: BuildSystem
var buildings_root: Node3D
var critters: Critters
var guide: QuestGuide
var map: MapScreen
var parrot: NPCParrot
var env: Environment
var sky_mat: ProceduralSkyMaterial
var sun: DirectionalLight3D
var moon: DirectionalLight3D
var fill: DirectionalLight3D
var sharpen: ColorRect
var clouds: Array[Node3D] = []
var _autosave_t := 0.0
var menu: GameMenu
var menu_cam: Camera3D
var in_menu := false
var _orbit := 0.0

# палитры: [верх неба, горизонт, цвет солнца, сила солнца, цвет теней, яркость теней, яркость воды]
const SKY_DAY := [Color("3a9cf0"), Color("bde9ff"), Color("fff4dc"), 0.5, Color("9a92cf"), 0.92, 1.0]
const SKY_SUNSET := [Color("4f63b8"), Color("ffb47a"), Color("ffb070"), 0.5, Color("8d6fb0"), 0.62, 0.85]
const SKY_NIGHT := [Color("0b1633"), Color("27406f"), Color("8fa8ff"), 0.0, Color("4a5c9a"), 0.48, 0.42]


func _ready() -> void:
	Game.load_game()   # заранее: остров должен знать, какие заросли уже расчищены
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--location="):   # для разработки: сразу на нужный остров
			Game.location = a.split("=")[1]
	_setup_environment()

	island = Island.new()
	island.configure(Game.location)
	island.name = "Island"
	island.add_to_group("island")
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
	var to_sea := island.wreck_point - island.spawn_point
	player.camera_yaw = atan2(to_sea.x, to_sea.z) + PI * 0.85

	if Game.location == "home":
		_spawn_story_objects()
	else:
		_spawn_arrival_dock()

	build = BuildSystem.new()
	build.island = island
	build.player = player
	build.buildings_root = buildings_root
	add_child(build)
	build.placed.connect(_on_building_placed)
	build.cancelled.connect(func(): player.can_interact = true)

	critters = Critters.new()
	add_child(critters)
	critters.setup(island, player)

	hud = HUD.new()
	add_child(hud)
	hud.station_check = _near_station
	hud.build_selected.connect(_on_build_selected)
	hud.panels_changed.connect(_on_panels_changed)
	Audio.listener = player
	Audio.island = island

	guide = QuestGuide.new()
	guide.name = "QuestGuide"
	add_child(guide)
	guide.setup(hud, player)
	map = MapScreen.new()
	map.name = "Map"
	add_child(map)
	map.setup(hud, island, player, guide)

	menu = GameMenu.new()
	menu.hud = hud
	add_child(menu)
	menu.continue_pressed.connect(start_play)
	menu.new_game_pressed.connect(_new_game)
	menu.resume_pressed.connect(_resume)
	menu.save_pressed.connect(_save)
	menu.to_main_menu_pressed.connect(func():
		_save()
		get_tree().paused = false
		get_tree().reload_current_scene())
	menu_cam = Camera3D.new()
	menu_cam.fov = 50
	menu_cam.far = 900
	add_child(menu_cam)

	_spawn_clouds()
	var loaded := _load()
	var args := OS.get_cmdline_user_args()
	if Game.skip_menu or (not args.is_empty() and not "--menu" in args):
		Game.skip_menu = false
		start_play.call_deferred()
	else:
		_show_main_menu(loaded)
	if not args.is_empty():
		var dev := preload("res://scripts/dev_tools.gd").new()
		dev.main = self
		add_child(dev)


func _show_main_menu(has_save: bool) -> void:
	in_menu = true
	hud.visible = false
	player.controls_enabled = false
	menu_cam.current = true
	_capture_mouse(false)
	menu.show_main(has_save)


## Начать (или продолжить) игру: убрать меню, вернуть камеру игроку.
func start_play() -> void:
	in_menu = false
	menu.hide_all()
	hud.visible = true
	player.camera.current = true
	player.controls_enabled = true
	_capture_mouse(true)
	if Game.flags.get("pending_sail", false):
		Game.flags.erase("pending_sail")
		player.global_position = island.spawn_point
		player.cam_rig.global_position = player.global_position + Vector3(0, 1.4, 0)
		hud.toast(Data.LOCATIONS[Game.location]["name"], Color("ffe08a"))
		Game.bump("sailed", "raft")
	if not Game.quest_started:
		Game.start_current_quest()


func _pause() -> void:
	get_tree().paused = true
	_capture_mouse(false)
	menu.show_pause()


func _resume() -> void:
	menu.hide_all()
	get_tree().paused = false
	_capture_mouse(not hud.any_open())


## Причал на новом острове: плот, на котором мы приплыли (на нём можно уплыть обратно), и Румба на мачте.
func _spawn_arrival_dock() -> void:
	var dock := Building.new()
	dock.setup("canoe" if Game.location == "fort" else "raft")
	var w := island.wreck_point
	w.y = maxf(w.y, 0.0)
	dock.position = w
	var to_land := island.camp_center - w
	dock.rotation.y = atan2(to_land.x, to_land.z)
	add_child(dock)
	dock.remove_from_group("building")   # не сохраняется: причал есть всегда
	dock.sail_requested.connect(_choose_destination)
	parrot = NPCParrot.new()
	dock.add_child(parrot)
	parrot.position = Vector3(0, 2.6 if Game.location == "fort" else 2.9, 0) + (Vector3(0, 0, 0.45) if Game.location == "fort" else Vector3.ZERO)


func _spawn_story_objects() -> void:
	var wreck := Models.boat_wreck()
	var w := island.wreck_point
	add_child(wreck)
	wreck.position = w
	var to_camp := island.camp_center - w
	wreck.rotation.y = atan2(to_camp.x, to_camp.z) + PI / 2
	var body := StaticBody3D.new()
	body.collision_layer = 4
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(3.6, 1.2, 1.4)
	cs.shape = b
	cs.position.y = 0.5
	body.add_child(cs)
	wreck.add_child(body)
	# попугай на сломанной мачте
	parrot = NPCParrot.new()
	wreck.add_child(parrot)
	parrot.position = Vector3(1.6, 2.45, 0.6)
	# обломки можно обыскать (там металл для мачете)
	var search := StoryPlace.new()
	search.id = "wreck"
	wreck.add_child(search)
	search.position = Vector3(0, 0.4, 0)
	# ящик неподалёку
	var crate := SupplyCrate.new()
	add_child(crate)
	crate.position = island.crate_point   # место заранее освобождено от зарослей
	crate.rotation.y = 0.4


# ================================================================== Окружение
func _setup_environment() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_curve = 0.1
	sky_mat.sun_angle_max = 8.0
	sky_mat.sun_curve = 0.05
	sky.sky_material = sky_mat
	env.sky = sky
	# Тени — не серые, а тёплого сиреневого оттенка, как в мультфильмах
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("8f86c9")
	env.ambient_light_energy = 0.78
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	# Чёткая картинка: без свечения, без размывающего тонмаппинга, туман только вдали
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.glow_enabled = false
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_depth_begin = 140.0
	env.fog_depth_end = 520.0
	env.fog_density = 1.0
	env.fog_light_color = Color("bde9ff")
	env.fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.97
	env.adjustment_contrast = 1.07
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	# резкость поверх 3D, под интерфейсом
	var post := CanvasLayer.new()
	post.layer = 1
	add_child(post)
	sharpen = ColorRect.new()
	sharpen.set_anchors_preset(Control.PRESET_FULL_RECT)
	sharpen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sm := ShaderMaterial.new()
	sm.shader = preload("res://shaders/sharpen.gdshader")
	sharpen.material = sm
	post.add_child(sharpen)

	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.shadow_blur = 0.0   # резкие мультяшные тени
	sun.light_specular = 0.6
	add_child(sun)
	# мягкий заполняющий свет без теней: теневая сторона персонажей не уходит в грязь
	fill = DirectionalLight3D.new()
	fill.name = "Fill"
	fill.light_color = Color("ffe6c8")
	fill.light_energy = 0.16
	fill.light_specular = 0.0
	fill.shadow_enabled = false
	add_child(fill)
	moon = DirectionalLight3D.new()
	moon.name = "Moon"
	moon.light_color = Color("9fb4ff")
	moon.light_energy = 0.0
	moon.rotation = Vector3(-1.0, 0.6, 0)
	add_child(moon)


func _update_sky() -> void:
	var t := Game.time_of_day
	var angle := (t - 0.25) * TAU
	var elev := sin(angle)
	sun.rotation = Vector3(-angle, deg_to_rad(-35), 0)
	fill.rotation = Vector3(-0.5, deg_to_rad(145), 0)
	fill.light_energy = 0.22 * clampf(elev * 3.0, 0.0, 1.0)
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
	sun.shadow_opacity = clampf((elev - 0.05) * 5.0, 0.0, 1.0)
	env.ambient_light_color = a[4].lerp(b[4], k)
	env.ambient_light_energy = lerpf(a[5], b[5], k)
	moon.light_energy = clampf(-elev * 1.2, 0.0, 0.25)
	if island and island.water_mat:
		island.water_mat.set_shader_parameter("brightness", lerpf(a[6], b[6], k))


var _answer_fire: Node3D


## Когда маяк зажжён — на острове Великого Баньяна отвечает огонь брата.
func _update_answer_fire() -> void:
	if _answer_fire or Game.location != "home" or not Game.flags.get("lighthouse_lit", false) or island.banyan == null:
		return
	_answer_fire = Node3D.new()
	island.banyan.add_child(_answer_fire)
	_answer_fire.position = Vector3(0, 40.0, 0)
	var f := MeshInstance3D.new()
	f.mesh = Models.sphere(2.2, 10, 6)
	f.material_override = Models.unshaded(Color("ffb030"))
	_answer_fire.add_child(f)
	var l := OmniLight3D.new()
	l.light_color = Color("ffb35c")
	l.light_energy = 8.0
	l.omni_range = 60.0
	_answer_fire.add_child(l)


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
	var sh := int(Game.settings.get("sharpen", 2))
	sharpen.visible = sh > 0
	(sharpen.material as ShaderMaterial).set_shader_parameter("strength", 0.25 if sh == 1 else 0.5)
	_update_answer_fire()
	if in_menu:
		# камера медленно облетает остров
		_orbit += delta * 0.05
		var c := island.camp_center
		menu_cam.global_position = c + Vector3(cos(_orbit) * 34.0, 16.0, sin(_orbit) * 34.0)
		menu_cam.look_at(c + Vector3(0, 2.0, 0))
	for c in clouds:
		c.position.x += delta * 2.0
		if c.position.x > 280:
			c.position.x = -280
	if not hud.any_open():
		if build.is_active():
			hud.set_hint("ЛКМ — поставить «%s»,  R — повернуть,  ПКМ — отмена" % Data.BUILDINGS[build.active_id]["name"])
		else:
			hud.set_hint(player.get_hint())
	else:
		hud.set_hint("")
	hud.set_crosshair(build.is_active())
	hud.set_stamina(player.stamina, Player.STAMINA_MAX)
	if not in_menu:
		_autosave_t += delta
	if _autosave_t > 90.0:
		_autosave_t = 0.0
		_save()


# ================================================================== Ввод
func _unhandled_input(event: InputEvent) -> void:
	if hud.dialogue_open():
		if event.is_action_pressed("interact") or event.is_action_pressed("jump") or event.is_action_pressed("ui_accept"):
			hud.advance_dialogue()
			get_viewport().set_input_as_handled()
		return
	if in_menu:
		return
	if event.is_action_pressed("ui_cancel"):
		if hud.any_open():
			hud.close_all()
		elif build.is_active():
			build.cancel()
		else:
			_pause()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not hud.any_open():
		_capture_mouse(true)
		get_viewport().set_input_as_handled()
		return
	var toggles := {"craft_menu": hud.craft_panel, "build_menu": hud.build_panel, "inventory": hud.inv_panel,
		"collections": hud.col_panel, "journal": hud.journal_panel, "help": hud.help_panel, "map": map.panel}
	for action in toggles:
		if event.is_action_pressed(action):
			var p: PanelContainer = toggles[action]
			if p.visible:
				hud.close_all()
			else:
				build.cancel(false)
				player.can_interact = true
				match action:
					"craft_menu": hud.open_craft()
					"build_menu": hud.open_build()
					"inventory": hud.open_inventory()
					"collections": hud.open_collections()
					"journal": hud.open_journal()
					"help": hud.show_help()
					"map": map.open()
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("save"):
		_save()
	elif event.is_action_pressed("load"):
		get_tree().reload_current_scene()


func _capture_mouse(on: bool) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if on else Input.MOUSE_MODE_VISIBLE


func _on_panels_changed(open: bool) -> void:
	if in_menu:
		return
	player.controls_enabled = not open
	_capture_mouse(not open)


func _on_build_selected(id: String, variant: String) -> void:
	player.can_interact = false
	build.start(id, variant)


func _on_building_placed(b: Building) -> void:
	_connect_building(b)
	if not build.is_active():
		get_tree().create_timer(0.2).timeout.connect(func(): player.can_interact = true)


func _connect_building(b: Building) -> void:
	b.craft_requested.connect(func(station): hud.open_craft(station))
	b.sleep_requested.connect(_sleep)
	b.choice_requested.connect(hud.show_choices)
	b.sail_requested.connect(_choose_destination)


# ================================================================== Плавание между островами
func _choose_destination() -> void:
	var options := []
	for loc in Data.LOCATIONS:
		if loc == Game.location:
			continue
		var cfg: Dictionary = Data.LOCATIONS[loc]
		if cfg.has("unlock_flag") and not Game.flags.get(cfg["unlock_flag"], false):
			continue
		options.append({"text": "Плыть: %s" % cfg["name"], "icon": "sail", "callback": travel_to.bind(loc)})
	if Game.flags.get("storm_route", false):
		options.append({"text": "Грозовой остров — глава 4 (в разработке)", "icon": "sym_star",
			"callback": func(): Game.notified.emit("Грозовой остров появится в следующей версии игры", Color("ffe08a"))})
	if options.is_empty():
		Game.notified.emit("Плыть пока некуда. Куда указывает свет?..", Color("ffe08a"))
		return
	hud.show_choices("Куда плывём?", options)


func travel_to(loc: String) -> void:
	player.controls_enabled = false
	Audio.play("water", 0.0, 0.0)
	hud.fade_through(func():
		_save()
		Game.location = loc
		Game.flags["pending_sail"] = true
		Game.flags["visited_" + loc] = true
		Game.save_game(Game.loc_data.get(loc, {}))
		Game.skip_menu = true
		get_tree().reload_current_scene())


func _near_station(station: String) -> bool:
	for b in get_tree().get_nodes_in_group("station_" + station):
		if b.global_position.distance_to(player.global_position) < 4.0:
			return true
	return false


func _sleep() -> void:
	player.controls_enabled = false
	Audio.play("sleep", -2.0, 0.0)
	hud.fade_through(func():
		Game.sleep_until_morning()
		hud.toast("Доброе утро! Пока ты спал, грядки подросли.", Color("ffe08a"))
		player.controls_enabled = true
		_save())


# ================================================================== Сохранение
func _save() -> void:
	var list := []
	for b in get_tree().get_nodes_in_group("building"):
		list.append({"id": b.id, "v": b.variant, "x": b.global_position.x, "y": b.global_position.y,
			"z": b.global_position.z, "rot": b.rotation.y, "s": b.get_state()})
	var p := player.global_position
	Game.save_game({"buildings": list, "player": [p.x, p.y, p.z], "explored": map.to_save()})


func _load() -> bool:
	var full := Game.load_game()
	if full.is_empty():
		return false
	var data: Dictionary = Game.loc_data.get(Game.location, {})
	for b in data.get("buildings", []):
		var node := build.spawn_building(b["id"], Vector3(b["x"], b["y"], b["z"]), b["rot"], b.get("v", ""), b.get("s", {}))
		_connect_building(node)
	map.from_save(str(data.get("explored", "")))
	var p: Array = data.get("player", [])
	if p.size() == 3:
		player.global_position = Vector3(p[0], p[1] + 0.3, p[2])
		player.cam_rig.global_position = player.global_position + Vector3(0, 1.4, 0)
	hud.toast("Сохранение загружено (день %d)" % Game.day, Color("bfe3ff"))
	return true


func _new_game() -> void:
	Game.delete_save()
	Game.reset_state()
	Game.skip_menu = true
	get_tree().paused = false
	get_tree().reload_current_scene()


func _exit_tree() -> void:
	Models.clear_caches()
	FX._tex_cache.clear()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and player and not in_menu:
		_save()
