extends Node3D
## Точка входа: собирает мир (остров, свет, небо, игрок, NPC, UI) и связывает системы.

var island: Island
var player: Player
var hud: HUD
var build: BuildSystem
var buildings_root: Node3D
var critters: Critters
var parrot: NPCParrot
var world_env: WorldEnv
var weather: Weather
var warmth: Warmth
var heat: Heat
var fog: FogSystem
var clouds: Array[Node3D] = []
var _autosave_t := 0.0
var menu: GameMenu
var menu_cam: Camera3D
var in_menu := false
var _orbit := 0.0


func _ready() -> void:
	add_to_group("main")
	Game.load_game()   # заранее: остров должен знать, какие заросли уже расчищены
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--location="):   # для разработки: сразу на нужный остров
			Game.location = a.split("=")[1]
	world_env = WorldEnv.new()
	add_child(world_env)

	island = Island.new()
	island.configure(Game.location)
	island.name = "Island"
	island.add_to_group("island")
	add_child(island)
	island.build()
	island.spawn_distant_scenery(self)
	world_env.island = island

	buildings_root = Node3D.new()
	buildings_root.name = "Buildings"
	add_child(buildings_root)

	player = Player.new()
	player.name = "Player"
	add_child(player)
	player.global_position = island.spawn_point
	var to_sea := island.wreck_point - island.spawn_point
	player.camera_yaw = atan2(to_sea.x, to_sea.z) + PI * 0.85
	world_env.player = player
	weather = Weather.new()
	weather.world_env = world_env
	weather.player = player
	weather.island = island
	add_child(weather)
	if Game.location == "ice":
		warmth = Warmth.new()
		warmth.main = self
		warmth.player = player
		add_child(warmth)
	if Game.location == "volcano":
		heat = Heat.new()
		heat.main = self
		heat.player = player
		add_child(heat)
	if Game.location == "fog":
		fog = FogSystem.new()
		fog.main = self
		fog.world_env = world_env
		fog.player = player
		add_child(fog)

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
	Game.quest_completed.connect(func(q: Dictionary):
		if q.get("id", "") == "village":
			Audio.play("cheer", -2.0, 0.0)
		if q.get("id", "") == "lyova":
			Audio.play_theme("meeting")   # встреча с братом
		if q.get("id", "") == "choice":
			_ending()
		_spawn_village.call_deferred())
	hud.panels_changed.connect(_on_panels_changed)
	Audio.listener = player
	Audio.island = island
	var qp := QuestPointer.new()   # метка «!» над целью задания и «куда идти» в панели задания
	qp.main = self
	qp.hud = hud
	add_child(qp)
	if Game.location == "eye":
		Audio.play_theme("eye", true)   # своя тема Ока: тихая, с ветром
	else:
		Audio.stop_theme()

	menu = GameMenu.new()
	menu.hud = hud
	add_child(menu)
	menu.continue_pressed.connect(start_play)
	menu.new_game_pressed.connect(_new_game)
	menu.new_game_slot_pressed.connect(func(n: int):
		Game.use_slot(n)
		_new_game())
	menu.load_slot_pressed.connect(_load_slot)
	menu.to_camp_pressed.connect(to_camp)
	menu.save_slot_pressed.connect(func(n: int):
		Game.use_slot(n)
		_save())
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
	Game.playing = false
	hud.visible = false
	player.controls_enabled = false
	menu_cam.current = true
	_capture_mouse(false)
	menu.show_main(has_save)


## Начать (или продолжить) игру: убрать меню, вернуть камеру игроку.
func start_play() -> void:
	in_menu = false
	Game.playing = true
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
		Game.arrive(Game.location)
		Game.bump("sailed", "raft")
		Game.bump("sailed", Game.location)
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
	var vessel: String = {"fort": "canoe", "storm": "boat", "ice": "boat", "volcano": "boat", "fog": "boat", "eye": "boat"}.get(Game.location, "raft")
	dock.setup(vessel)
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
	match vessel:
		"canoe": parrot.position = Vector3(0, 2.6, 0.45)
		"boat": parrot.position = Vector3(0, 3.1, 0.3)
		_: parrot.position = Vector3(0, 2.9, 0)
	if Game.location == "eye":
		EyeIsland.spawn_shore(self, island)


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
	var side := Vector3(cos(wreck.rotation.y), 0, -sin(wreck.rotation.y))
	var cp := w + side * 4.0 + to_camp.normalized() * 1.0
	cp.y = island.height_at(cp.x, cp.z)
	crate.position = cp
	crate.rotation.y = 0.4


# ================================================================== Ответный огонь
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
	f.material_override = Models.flame_mat(Color("fff0b0"), Color("ff9a30"), 4.0)
	_answer_fire.add_child(f)
	var l := OmniLight3D.new()
	l.light_color = Color("ffb35c")
	l.light_energy = 8.0
	l.omni_range = 60.0
	_answer_fire.add_child(l)


# ================================================================== Фонарь и рация
var _lantern: OmniLight3D


## Фонарь в руке светит в бункере, ночью и в тумане. Фонарь со светлячками — зелёный и вдвое дальше.
func _update_lantern() -> void:
	var fogged: bool = Game.location == "fog" and not Game.flags.get("fog_cleared", false)
	var big := Game.light_kind() == "firefly"
	var on: bool = Game.has_light() and (world_env.indoor or not Game.is_day() or fogged)
	if on and _lantern == null:
		_lantern = OmniLight3D.new()
		_lantern.light_color = Color("ffd59a")
		_lantern.light_energy = 1.8
		_lantern.omni_range = 9.0
		_lantern.omni_attenuation = 1.2
		_lantern.shadow_enabled = true
		_lantern.position = Vector3(0.0, 2.6, 0.0)   # над головой: светит вокруг и не слепит в лицо
		player.add_child(_lantern)
	if _lantern:
		_lantern.visible = on
		_lantern.light_color = Color("d8ffa0") if big else Color("ffd59a")
		_lantern.omni_range = 15.0 if big else 9.0
		if on:
			var t := Time.get_ticks_msec() / 1000.0
			_lantern.light_energy = (1.6 if world_env.indoor else 1.1) * (0.94 + 0.06 * sin(t * 7.0))


## Рация Тимура (клавиша T): короткая связь с Тимуром с любого острова.
func _radio_call() -> void:
	Audio.play("radio", -4.0, 0.05)
	var lines := {
		"home": "ПРИЁМ! Ты дома? Полей там грядки и за меня. У меня опять дождь. Как всегда.",
		"banyan": "ПРИЁМ! Привет Марте! Скажи, что я помню её пирог. И что я ВСЁ ЕЩЁ голоден.",
		"fort": "ПРИЁМ! Стёпа рядом? Передай: «Тимур говорит — не кури трубку в трюме». Он поймёт.",
		"storm": "ПРИЁМ! Я тебя ВИЖУ. Помаши. ...Нет, другой рукой. Ладно, конец связи.",
		"ice": "ПРИЁМ! Как там Ингрид? Передай, что я НЕ кричу. Это у меня голос такой. И надень шапку!",
		"volcano": "ПРИЁМ! Вера рядом? Спроси про кофе. Нет, не спрашивай. Спроси! ...Ладно, просто понюхай его за меня.",
		"fog": "ПРИЁМ! Ты там? В ТУМАНЕ? Миша рядом? Скажи ему... скажи, что я СЛЫШАЛ. Каждую ночь слышал.",
		"eye": "ПРИЁМ! Ты в самом Оке?! Тут у меня в эфире так тихо, будто весь шторм прислушивается. Держись!",
	}
	# разговор по заданию (Тимур говорит по рации) — засчитывается здесь
	if NPCPerson.quest_talk("timur", true):
		return
	if Game.ended():
		lines["eye"] = "ПРИЁМ! Я на связи. Всегда на связи. Это моя работа — и, кажется, моё счастье."
	if Game.location == "ice" and Game.flags.get("ice_thawed", false):
		lines["ice"] = "ПРИЁМ! Ингрид мне ответила! САМА! Я чуть рацию не уронил. Конец связи. То есть нет. То есть да."
	var night := "" if Game.is_day() else " Ночью слушаю эфир. Пока тишина. Только шорох... как будто туман шуршит."
	var text: String = lines.get(Game.location, "ПРИЁМ! Слышу тебя хорошо!")
	Game.dialogue_requested.emit([["timur", text + night]], Callable())


func rain_wind() -> float:
	return weather.rain * 3.0 if weather else 0.0


func _spawn_clouds() -> void:
	if Game.location == "eye":
		return   # над Оком небо чистое, тучи — только в стене шторма
	var g := RandomNumberGenerator.new()
	g.seed = 4242
	# облака — кольцом у горизонта и пониже: так их видно в кадре, а не только если задрать камеру
	for i in 18:
		var c := Models.cloud(g)
		var a := g.randf() * TAU
		var r := g.randf_range(170.0, 360.0)
		c.position = Vector3(cos(a) * r, g.randf_range(24.0, 46.0), sin(a) * r)
		c.scale = Vector3.ONE * g.randf_range(1.3, 2.6)
		add_child(c)
		clouds.append(c)


func _process(delta: float) -> void:
	world_env.update(delta)
	_update_answer_fire()
	_update_lantern()
	if in_menu:
		# камера медленно облетает остров
		_orbit += delta * 0.05
		var c := island.camp_center
		menu_cam.global_position = c + Vector3(cos(_orbit) * 34.0, 16.0, sin(_orbit) * 34.0)
		menu_cam.look_at(c + Vector3(0, 2.0, 0))
	for c in clouds:
		c.position.x += delta * (1.5 + rain_wind())
		if c.position.x > 340:
			c.position.x = -340
	if not hud.any_open():
		if build.is_active():
			hud.set_hint(build.reason if build.reason != "" else "ЛКМ — поставить «%s»,  R — повернуть,  ПКМ — отмена" % Data.BUILDINGS[build.active_id]["name"])
		else:
			hud.set_hint(player.get_hint())
	else:
		hud.set_hint("")
	hud.set_crosshair(build.is_active())
	# точка на предмете, с которым будет действие
	var tg: Node = player.target
	var show_dot := false
	if tg != null and is_instance_valid(tg) and not build.is_active() and not hud.any_open() and tg.has_method("interact_point"):
		var wp: Vector3 = tg.interact_point()
		var cam := player.camera
		if not cam.is_position_behind(wp):
			hud.set_target_dot(cam.unproject_position(wp), true)
			show_dot = true
	if not show_dot:
		hud.set_target_dot(Vector2.ZERO, false)
	player.build_aim = build.is_active()
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
		"collections": hud.col_panel, "journal": hud.journal_panel, "help": hud.help_panel}
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
			get_viewport().set_input_as_handled()
			return
	# 1–9, 0 — взять инструмент из ячейки внизу (ещё раз — убрать, руки свободны)
	if event is InputEventKey and event.pressed and not event.echo:
		var kc: int = (event as InputEventKey).physical_keycode
		if kc >= KEY_0 and kc <= KEY_9:
			var idx := 9 if kc == KEY_0 else kc - KEY_1
			var slots := Game.hold_slots()
			# 5 — фонарь (включить / выключить), 6 — огнеупорные рукавицы (надеть / снять)
			for g in Game.GEAR_KEYS:
				if idx + 1 == int(Game.GEAR_KEYS[g]) and Game.gear_owned(g):
					Game.toggle_gear(g)
			if idx < slots.size():
				Game.hold("" if Game.held == slots[idx] else slots[idx])
				Audio.play("click", -6.0, 0.05)
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("radio") and Game.has_tool("radio_set"):
		_radio_call()
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
	# постройка «встаёт» на место: кольцо пыли по земле и лёгкий толчок камеры
	var r: float = Data.BUILDINGS[b.id].get("radius", 1.0)
	get_tree().create_timer(0.18, false).timeout.connect(func():
		if is_instance_valid(b):
			FX.ring(b, Vector3(0, 0.08, 0), Color("e6dcc0"), clampf(r, 0.6, 2.4), 14)
			player.add_trauma(0.12))
	if not build.is_active():
		get_tree().create_timer(0.2).timeout.connect(func(): player.can_interact = true)


func _connect_building(b: Building) -> void:
	b.craft_requested.connect(func(station): hud.open_craft(station))
	b.sleep_requested.connect(_sleep)
	b.choice_requested.connect(hud.show_choices)
	b.sail_requested.connect(_choose_destination)


# ================================================================== Плавание между островами
## Паром Миши (вызывается через группу «main»).
func choose_destination() -> void:
	_choose_destination()


func _choose_destination() -> void:
	var options := []
	for loc in Data.LOCATIONS:
		if loc == Game.location:
			continue
		var cfg: Dictionary = Data.LOCATIONS[loc]
		if cfg.has("unlock_flag") and not Game.flags.get(cfg["unlock_flag"], false):
			continue
		# в туман — только ночью (после седьмого огня остров виден и днём)
		if cfg.get("night", false) and not Game.flags.get("fog_cleared", false) and not Game.fog_hours():
			options.append({"text": "%s — днём там сплошной туман. Дождаться ночи и плыть" % cfg["name"], "icon": "sym_moon",
				"callback": func():
					Game.wait_until_night(0.86)
					travel_to(loc)})
			continue
		options.append({"text": "Плыть: %s" % cfg["name"], "icon": "sail", "callback": travel_to.bind(loc)})
	if Game.flags.get("storm_route", false) and not Game.flags.get("restored_stepa_boat", false):
		options.append({"text": "Грозовой остров — на каноэ не доплыть, нужен бот Стёпы", "icon": "sym_star",
			"callback": func(): Game.notified.emit("Почини бот Стёпы на берегу форта", Color("ffe08a"))})
	if Game.flags.get("eye_route", false) and not Game.flags.get("eye_ready", false):
		options.append({"text": "Око шторма — сначала собери команду (задание «Последний рейс»)", "icon": "sym_sun",
			"callback": func(): Game.notified.emit("Обойди всех: Марту, Стёпу, Ингрид, Веру, Ренату и вызови Тимура по рации", Color("ffe08a"))})
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
	Game.save_game({"buildings": list, "player": [p.x, p.y, p.z]})


func _load() -> bool:
	var full := Game.load_game()
	if full.is_empty():
		return false
	var data: Dictionary = Game.loc_data.get(Game.location, {})
	for b in data.get("buildings", []):
		var node := build.spawn_building(b["id"], Vector3(b["x"], b["y"], b["z"]), b["rot"], b.get("v", ""), b.get("s", {}))
		_connect_building(node)
	_spawn_village.call_deferred()
	_spawn_postgame.call_deferred()
	var p: Array = data.get("player", [])
	if p.size() == 3:
		player.global_position = Vector3(p[0], p[1] + 0.3, p[2])
		player.cam_rig.global_position = player.global_position + Vector3(0, 1.4, 0)
	hud.toast("Сохранение загружено (день %d)" % Game.day, Color("bfe3ff"))
	return true


# ================================================================== Деревня (глава 7)
var _village_done := false


## Выжившие с «Альбатроса» живут на острове крушения: вокруг длинного стола (или у лагеря).
func _spawn_village() -> void:
	if _village_done or Game.location != "home" or not Game.flags.get("village_moved", false):
		return
	_village_done = true
	var c := island.camp_center
	for t in get_tree().get_nodes_in_group("station_long_table"):
		c = (t as Node3D).global_position
	var who := ["renata", "gosha", "petya", "pasha", "misha"]
	if Game.flags.get("stepa_at_fog", false):
		who.append("stepa")
	for i in who.size():
		var a := TAU * i / who.size()
		var p := c + Vector3(cos(a), 0, sin(a)) * 2.6
		p.y = island.height_at(p.x, p.z)
		var n := NPCPerson.new()
		n.npc_id = who[i]
		n.position = p
		n.rotation.y = atan2(c.x - p.x, c.z - p.z)
		add_child(n)


# ================================================================== Финал (глава 8)
const EPILOGUE_SEA := [
	["narrator", "«Альбатрос» уходит домой с командой, Лёвой и тобой. Ты везёшь письма: письма команды — их родным, письма деда — маме."],
	["narrator", "Через месяц вы возвращаетесь: ты, Лёва, Миша и корабль учёных. Архипелаг становится заповедником. Марта открывает столовую для гостей."],
	["narrator", "Тимур наконец слышит в эфире весь мир. Стёпа плывёт домой и через полгода возвращается: «Дома скучно»."],
	["parrot", "Румба видел море. Большое. Румба одобряет."],
	["narrator", "Теперь к островам ходят торговые корабли, и урожай стоит дороже. У причала дома — судно Лёвы, у лагеря — доска заказов для гостей."],
]
const EPILOGUE_KEEPER := [
	["narrator", "Год спустя у берега твоего острова качается бутылка. Внутри — записка. Знакомый почерк."],
	["lyova", "«Мама плакала. Потом смеялась. Потом опять плакала, над письмами деда. Передаёт варенье, лови следующую бутылку. Мы с Мишей строим новую шхуну. Летом жди. — Л.»"],
	["narrator", "Острова живые: всё растёт быстро. У Великого огня можно зажечь лучи — и день станет днём щедрости. Соскучишься — открой окно в шторме, и корабль Лёвы придёт к причалу."],
	["parrot", "Румба остался. Румба теперь Хранитель попугаев. Это важная должность."],
]


## Выбор сделан: стена шторма уходит (или остаётся), эпилог, титры, отметка в главном меню.
func _ending() -> void:
	var sea: bool = Game.flags.get("ending_open_sea", false)
	var key := "sea" if sea else "keeper"
	var seen := str(Game.settings.get("endings", "")).split(",", false)
	if not key in seen:
		seen.append(key)
		Game.settings["endings"] = ",".join(seen)
		Game.save_settings()
	Audio.play_theme("sea" if sea else "keeper")
	if sea:
		get_tree().call_group("eye_storm", "dissolve")
	else:
		Game.add_item("cloudberry_jam", 3, false)   # мама передала варенье
	Game.dialogue_requested.emit(EPILOGUE_SEA if sea else EPILOGUE_KEEPER, func():
		hud.show_credits(sea, func():
			hud.toast("Дальше — вечная игра: ферма, коллекции, заказы жителей", Color("ffe08a"))
			_save()))


# ================================================================== После финала
var _postgame_done := false


## Дома после финала: доска заказов у лагеря и судно Лёвы у причала
## («Открытое море» — всегда, «Хранитель огня» — в день, когда открыто окно в шторме).
func _spawn_postgame() -> void:
	if _postgame_done or Game.location != "home" or not Game.ended():
		return
	_postgame_done = true
	var c := island.camp_center
	var to_sea := island.wreck_point - c
	to_sea.y = 0.0
	to_sea = to_sea.normalized()
	var side := Vector3(-to_sea.z, 0, to_sea.x)
	var bp := c - side * 5.5 - to_sea * 1.5
	bp.y = island.height_at(bp.x, bp.z)
	var board := OrderBoard.new()
	board.position = bp
	board.rotation.y = atan2(c.x - bp.x, c.z - bp.z)
	add_child(board)
	island.poi_extra["order_board"] = bp
	if Game.flags.get("ending_open_sea", false) or Game.window_open():
		var lp := c.lerp(island.wreck_point, 0.55) + side * 3.0
		lp.y = island.height_at(lp.x, lp.z)
		var lv := NPCPerson.new()
		lv.npc_id = "lyova"
		lv.position = lp
		lv.rotation.y = atan2(lp.x - c.x, lp.z - c.z)
		add_child(lv)
		island.poi_extra["lyova"] = lp


## «Вернуться в лагерь» из паузы: герой застрял (за камнем, в яме, в воде) — переносим его к месту высадки.
## Ничего не теряется и ничего не стоит: это страховка, а не наказание.
func to_camp() -> void:
	_resume()
	player.controls_enabled = false
	hud.fade_through(func():
		if player.climbing:
			player._stop_climb()
		player.velocity = Vector3.ZERO
		player.global_position = island.spawn_point + Vector3(0, 0.4, 0)
		player.cam_rig.global_position = player.global_position + Vector3(0, 1.4, 0)
		player.controls_enabled = true
		hud.toast("Ты снова в лагере", Color("ffe08a")))


## Загрузить игру из другой ячейки: всё начинается с чистого листа и читается из её файла.
func _load_slot(n: int) -> void:
	Game.use_slot(n)
	Game.reset_state()
	Game.skip_menu = true
	get_tree().paused = false
	get_tree().reload_current_scene()


func _new_game() -> void:
	Game.delete_save()
	Game.reset_state()
	Game.skip_menu = true
	get_tree().paused = false
	get_tree().reload_current_scene()


func _exit_tree() -> void:
	Models.clear_caches()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and player and not in_menu:
		_save()
