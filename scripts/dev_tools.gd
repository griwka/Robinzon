extends Node
## Инструменты разработчика. Включаются аргументами командной строки после "--":
##   --shot=путь     сделать скриншот и выйти (--frames=N — через сколько кадров)
##   --time=0..1     время суток
##   --demo          построить лагерь с фермой рядом с игроком (для скриншотов)
##   --yaw= --pitch= --dist=  положение камеры
##   --autotest      пройти всю первую главу через игровую логику и вывести результат

var main: Node
var args := {}
var _frames := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	if args.has("autotest"):
		_autotest.call_deferred()
	if args.has("layout"):
		_layout_only.call_deferred()
	if args.has("validate"):
		_validate_only.call_deferred()


func _process(_delta: float) -> void:
	_frames += 1
	var p: Player = main.player
	if _frames == 2:
		if args.has("yaw"): p.camera_yaw = float(args["yaw"])
		if args.has("pitch"): p.camera_pitch = float(args["pitch"])
		if args.has("dist"): p.camera_distance = float(args["dist"])
		if args.has("demo"):
			_demo()
		if args.has("deck"):
			for n in get_tree().get_nodes_in_group("obstacle"):
				if n is BanyanTree:
					p.global_position = n.to_global(n._deck_center(int(args["deck"]) - 1)) + Vector3(1.2, 0.3, 0.6)
					p.cam_rig.global_position = p.global_position + Vector3(0, 1.4, 0)
			_flush()
		if args.has("fortview"):
			var f := _fort()
			if f:
				var mode: String = args["fortview"]
				if mode == "open":
					Game.flags["poi_fort_gate"] = true
					f.open_gate(false)
				if mode == "cellar":
					Game.flags["cellar_drained"] = true
					f._drain(false)
					p.global_position = f.global_position - f.side_dir * 5.0 + Vector3(0, 0.5, 0)
					p.camera_yaw = atan2(f.side_dir.x, f.side_dir.z)
				else:
					p.global_position = f.global_position + f.gate_dir * 16.0 + Vector3(0, 0.5, 0)
					p.camera_yaw = atan2(f.gate_dir.x, f.gate_dir.z)
				p.cam_rig.global_position = p.global_position + Vector3(0, 1.4, 0)
			_flush()
		if args.has("near") and main.island.poi_extra.has(args["near"]):
			var np_: Vector3 = main.island.poi_extra[args["near"]]
			p.global_position = np_ + Vector3(2.5, 0.5, 2.5)
			p.cam_rig.global_position = p.global_position + Vector3(0, 1.4, 0)
			_flush()
		if args.has("at"):
			var v: PackedStringArray = args["at"].split(",")
			p.global_position = Vector3(float(v[0]), float(v[1]), float(v[2]))
			p.cam_rig.global_position = p.global_position + Vector3(0, 1.4, 0)
			_flush()
		if args.has("gallery"):
			_gallery(args["gallery"].split(","))
		if args.has("overview"):
			_overview()
		if args.has("mapshot"):
			# карта острова картинкой — без 3D, работает и в --headless
			var img: Image = main.map.render_image(args.get("fog", "0") == "1")
			img.resize(img.get_width() * 3, img.get_height() * 3, Image.INTERPOLATE_NEAREST)
			img.save_png(args["mapshot"])
			print("map saved: ", args["mapshot"])
			get_tree().quit()
	if args.has("time"):
		Game.time_of_day = float(args["time"])
	if args.has("demo") and _frames > 2 and _frames < 6:
		_flush()
	if _frames == 8:
		var hud: HUD = main.hud
		match args.get("open", ""):
			"inventory": hud.open_inventory()
			"collections":
				Game.collections = {"shells": {"scallop": 3, "seahorse": 1, "starfish": 1}, "butterflies": {"lemon_wing": 2, "blue_wing": 1, "morpho": 1},
					"journal": {"page_1": 1, "page_2": 1, "page_3": 1}}
				hud.open_collections()
			"craft":
				Game.unlocked.merge({"stone_axe": true, "plank": true, "watering_can": true, "net": true}, true)
				hud.open_craft()
			"build":
				Game.unlocked.merge({"tent": true, "campfire": true, "workbench": true, "hut": true, "raft": true}, true)
				hud.open_build()
			"page":
				Game.dialogue_requested.emit([["journal", Data.COLLECTIONS["journal"]["items"][3]["text"]]], Callable())
			"dialog":
				Game.dialogue_requested.emit([["parrot", "Карр! Живой! Живой! Я уж думал, ты рыба! Я — Румба, местный житель."]], Callable())
			"pause":
				main._pause()
			"shop":
				Game.unlocked.merge({"shop_marta": true, "buy_hive_frame": true}, true)
				Game.inventory["coins"] = 47
				main.hud._shop_tab = args.get("tab", "buy")
				main.hud.open_shop("marta")
			"map":
				main.map.reveal(main.player.global_position, float(args.get("reveal", "40")))
				main.map.open()
			"settings":
				main._pause()
				main.menu.open_settings(main.menu.show_pause)
	if args.has("gallery") and _frames > 2:
		p.cam_rig.global_position = main.island.camp_center + Vector3(0, float(args.get("camy", "0.8")), 0)
	if args.has("shot") and _frames == int(args.get("frames", "90")):
		get_viewport().get_texture().get_image().save_png(args["shot"])
		print("screenshot saved: ", args["shot"])
		get_tree().quit()


func _flush() -> void:
	var hud: HUD = main.hud
	var guard := 0
	while hud.dialogue_open() and guard < 200:
		hud.advance_dialogue()
		guard += 1


# ------------------------------------------------------------------ Галерея моделей
func _gallery(names: PackedStringArray) -> void:
	var isl: Island = main.island
	var c: Vector3 = isl.camp_center
	var p: Player = main.player
	p.visible = names.has("player") == false
	var spacing := float(args.get("spacing", "1.6"))
	var root := Node3D.new()
	main.add_child(root)
	var right := Vector3(1, 0, 0)
	for i in names.size():
		var m := Models.glb(names[i])
		if m == null:
			print("нет модели: ", names[i])
			continue
		root.add_child(m)
		var pos := c + right * (i - (names.size() - 1) / 2.0) * spacing
		pos.y = isl.height_at(pos.x, pos.z)
		m.global_position = pos
		m.rotation.y = float(args.get("rot", "0.5"))
	p.global_position = c + Vector3(0, 0, 4.0)
	p.cam_rig.global_position = c + Vector3(0, 0.8, 0)
	p.camera_yaw = 0.0
	p.controls_enabled = false
	main.hud.visible = false


# ------------------------------------------------------------------ Вид сверху
## --overview — весь остров сверху (ортографическая камера), чтобы проверить расстановку.
## --overview=N — квадрат N метров вокруг героя (с --at= или --near=).
func _overview() -> void:
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	var isl: Island = main.island
	var span: float = float(args["overview"]) if args["overview"] != "1" else isl.radius * 2.7
	cam.size = span
	cam.far = 400.0
	main.add_child(cam)
	var pl: Player = main.player
	var c: Vector3 = Vector3.ZERO if args["overview"] == "1" else pl.global_position
	cam.global_position = Vector3(c.x, 120.0, c.z)
	cam.rotation = Vector3(-PI / 2, 0, 0)
	cam.current = true
	main.hud.visible = false
	main.player.controls_enabled = false
	# дальние объекты не прячем: смотрим на весь остров сразу
	for gi in main.island.find_children("*", "GeometryInstance3D", true, false):
		(gi as GeometryInstance3D).visibility_range_end = 0.0


# ------------------------------------------------------------------ Демо-лагерь
func _demo() -> void:
	var isl: Island = main.island
	var c: Vector3 = isl.camp_center
	var bs: BuildSystem = main.build
	var to_sea := (isl.wreck_point - c).normalized()
	var right := Vector3(-to_sea.z, 0, to_sea.x)
	var place := func(id: String, off: Vector3, rot := 0.0, v := "", state := {}) -> Building:
		var pos: Vector3 = c + right * off.x + to_sea * off.z
		pos.y = isl.height_at(pos.x, pos.z)
		return bs.spawn_building(id, pos, atan2(to_sea.x, to_sea.z) + rot, v, state)
	place.call("tent", Vector3(-4.5, 0, -2.0), PI)
	place.call("campfire", Vector3(-1.5, 0, 0.5))
	place.call("workbench", Vector3(2.0, 0, -2.5), PI)
	place.call("torch", Vector3(-3.0, 0, 1.6))
	place.call("bench", Vector3(-1.5, 0, 2.2), PI)
	var crops := ["carrot", "corn", "tomato", "cabbage", "watermelon", "potato"]
	for i in crops.size():
		var x := 3.0 + (i % 3) * 2.1
		var z := 1.0 + (i / 3) * 1.6
		place.call("garden_bed", Vector3(x, 0, z), 0.0, "", {"crop": crops[i], "progress": 1.0 if i != 5 else 0.5, "watered": i % 2 == 0})
	place.call("fruit_tree", Vector3(7.5, 0, -2.0), 0.0, "banana", {"grow": 1.0, "fruit": 1.0})
	place.call("fruit_tree", Vector3(9.5, 0, 0.5), 0.0, "lemon", {"grow": 1.0, "fruit": 1.0})
	place.call("fruit_tree", Vector3(5.0, 0, -4.0), 0.0, "mango", {"grow": 1.0, "fruit": 1.0})
	place.call("coop", Vector3(-6.0, 0, 3.5), 0.5)
	place.call("goat_pen", Vector3(-1.0, 0, -6.5))
	place.call("flowerbed", Vector3(0.5, 0, 2.6))
	place.call("scarecrow", Vector3(6.0, 0, 3.8))
	for k in 4:
		place.call("fence", Vector3(2.4 + k * 1.3, 0, 4.6))
	for id in ["wood", "stone", "fiber", "rope", "plank", "leaf", "stone_axe", "watering_can", "net", "seed_carrot",
			"seed_corn", "carrot", "tomato", "banana", "coconut", "egg", "milk", "sapling_lemon", "fried_egg", "cheese"]:
		Game.inventory[id] = 6 if not Data.ITEMS[id]["cat"] == "tool" else 1
	Game.inventory_changed.emit()
	main.player.global_position = c + to_sea * 2.5 + right * 1.0 + Vector3(0, 0.5, 0)
	main.player.cam_rig.global_position = main.player.global_position


var earned_by_selling := 0


func _shop_for(item_id: String) -> String:
	for sh in Data.SHOPS:
		if not Game.shop_open(sh):
			continue
		if item_id == "any":
			return sh
		for e in Game.shop_items(sh):
			if e["item"] == item_id:
				return sh
	return "rumba"


# ------------------------------------------------------------------ Ошибки игрока
## Ситуации, когда игрок делает «не то» или «не в том порядке», а задание всё равно должно быть выполнимо.
func _test_mistakes() -> void:
	var start_q := func(task: Dictionary) -> int:
		var key: String = task["kind"] + ":" + Game._task_target(task)
		var zero: bool = task["kind"] in Game.ZERO_BASE_KINDS
		Game.quest_baseline = {key: 0 if zero else Game.stat(task["kind"], Game._task_target(task))}
		return Game.task_progress(task)
	Game.reset_state()
	Game.bump("found", "crate")
	_check(start_q.call({"kind": "found", "target": "crate", "count": 1}) == 1, "ящик открыт раньше задания — засчитано")
	Game.bump("cleared", "cliff", 21)
	_check(start_q.call({"kind": "cleared", "target": "cliff", "count": 2}) == 2, "все скалы разбиты раньше задания — засчитано")
	Game.add_item("bamboo", 12, true, true)
	_check(start_q.call({"kind": "collected", "target": "bamboo", "count": 12}) == 12, "бамбук нарублен раньше задания (весь) — засчитано")
	Game.add_item("stone_axe", 1, true, true)
	_check(start_q.call({"kind": "crafted", "target": "stone_axe", "count": 1}) == 1, "топор сделан раньше задания — засчитано")
	# еда, нужная по заданию, не съедается и не продаётся
	Game.reset_state()
	var qs: Array = Data.CHAPTERS[1]["quests"]
	for i in qs.size():
		if qs[i]["id"] == "feast":
			Game.chapter = 1
			Game.quest_index = i
	Game.quest_started = true
	Game.quest_baseline = {}
	Game.inventory = {"fried_egg": 1, "baked_potato": 1, "banana": 2}
	var got := Game.eat_best_food()
	_check(Game.count("fried_egg") == 1 and Game.count("baked_potato") == 1 and got > 0, "на лиане съедается банан, а не еда для Марты")
	_check(Game.sellable("fried_egg") == 0, "еду для задания нельзя случайно продать")
	Game.sell("marta", "fried_egg", 1)
	_check(Game.count("fried_egg") == 1, "продажа отложенного предмета не проходит")
	# монеты не уходят в минус, без денег покупка не проходит
	Game.inventory = {"coins": 3}
	_check(not Game.buy("marta", "hive_frame", 40) and Game.count("coins") == 3, "без денег купить нельзя, монеты не пропадают")
	# семена всегда можно купить — земледелие не заходит в тупик
	Game.location = args.get("location", "home")
	Game.unlocked = {"shop_rumba": true}
	var has_seed := false
	for e in Game.shop_items("rumba"):
		has_seed = has_seed or e["item"] == "seed_carrot"
	_check(has_seed, "семена моркови в лавке Румбы есть всегда")
	# конечные ресурсы острова покрывают задания
	if Game.location == "home":
		var bamboo := 0
		var cliffs := 0
		for n in get_tree().get_nodes_in_group("obstacle"):
			if n is ResourceNode and n.kind == "bamboo":
				bamboo += 1
			if n is ResourceNode and n.kind == "cliff":
				cliffs += 1
		_check(bamboo * 3 >= 18, "бамбука на острове хватает на хижину с запасом (%d рощ = %d бамбука, нужно 12)" % [bamboo, bamboo * 3])
		_check(cliffs >= 10, "скал хватает на задание (%d)" % cliffs)
	# проверка самого валидатора: ломаем копию сюжета — он должен заметить
	var broken: Array = Data.CHAPTERS.duplicate(true)
	broken[0]["quests"][2]["reward"]["unlock"] = []   # палатка больше не открывает мачете
	var v := QuestValidator.new()
	_check(v.run(broken).size() > 0, "валидатор ловит сломанный сюжет («%s»)" % (v.errors[0] if v.errors.size() else "—"))
	Game.reset_state()
	Game.location = args.get("location", "home")


# ------------------------------------------------------------------ Проверка сюжета «на бумаге»
func _validate() -> void:
	var v := QuestValidator.new()
	var errs := v.run()
	_check(errs.is_empty(), "все задания всех глав выполнимы по данным (%d проблем)" % errs.size())
	for e in errs:
		print("      ✗ " + e)
	for r in v.report:
		print("      ₭ " + r)


func _validate_only() -> void:
	print("=== VALIDATE ===")
	_validate()
	print("=== %s (%d ошибок) ===" % ["PASSED" if fails.is_empty() else "FAILED", fails.size()])
	get_tree().quit(0 if fails.is_empty() else 1)


# ------------------------------------------------------------------ Форт
func _fort() -> FortRuin:
	for n in get_tree().get_nodes_in_group("obstacle"):
		if n is FortRuin:
			return n
	return null


func _test_fort() -> void:
	var fort := _fort()
	_check(fort != null, "на острове стоит форт")
	if fort == null:
		return
	var walls := 0
	for c in fort._body.get_children():
		if c is CollisionShape3D and not c.disabled:
			walls += 1
	_check(walls >= 15 + 2 + 1, "стены форта замкнуты, ворота закрыты (%d препятствий)" % walls)
	# сквозь стену не пройти: луч от лагеря к центру форта упирается в стену или ворота
	var space := fort.get_world_3d().direct_space_state
	var blocked := 0
	for k in 16:
		var a := TAU * k / 16.0 + 0.1
		var from := fort.global_position + Vector3(cos(a), 0, sin(a)) * 14.0 + Vector3(0, 1.0, 0)
		var q := PhysicsRayQueryParameters3D.create(from, fort.global_position + Vector3(0, 1.0, 0), 4)
		if not space.intersect_ray(q).is_empty():
			blocked += 1
	_check(blocked == 16, "со всех 16 сторон внутрь не пройти, пока ворота заперты (%d/16)" % blocked)
	# рычаги: неверный порядок — вода возвращается, верный — уходит
	Game.flags.erase("cellar_drained")
	fort.pull("star")
	_check(not Game.flags.get("cellar_drained", false) and fort._pulled.is_empty(), "неверный порядок рычагов сбрасывается")
	# рыбалка: дёрнуть раньше поклёвки — без рыбы
	var spot: FishingSpot = null
	for c in get_tree().get_nodes_in_group("interactable"):
		if c is FishingSpot:
			spot = c
	_check(spot != null, "у берега есть места для рыбалки")
	if spot:
		Game.inventory["fishing_rod"] = 1
		var before := Game.count("fish")
		spot.interact(main.player)
		spot.interact(main.player)
		_check(Game.count("fish") == before and spot.state == FishingSpot.IDLE, "подсечь раньше поклёвки — рыба уходит")
		Game.inventory.erase("fishing_rod")
	var clay := 0
	for n in get_tree().get_nodes_in_group("interactable"):
		if n is ResourceNode and n.kind == "clay":
			clay += 1
	_check(clay >= 3, "на берегу есть глиняные ямы (%d)" % clay)


# ------------------------------------------------------------------ Лазание
func _test_climb() -> void:
	var p: Player = main.player
	var lianas := get_tree().get_nodes_in_group("climb")
	_check(lianas.size() == 3, "на Баньяне три лианы")
	var c: Climbable = lianas[0]
	var b := c.world_bottom()
	p.global_position = b + Vector3(0.6, 0.3, 0)
	p._find_climb()
	_check(p.near_climb == c, "у лианы появляется подсказка лезть")
	Game.inventory["climbing_gloves"] = 1
	_flush()
	p.controls_enabled = true
	p._start_climb(c)
	Input.action_press("move_forward")
	var start_stamina := p.stamina
	var steps := 0
	while p.climbing and steps < 1200:
		p._physics_process(1.0 / 60.0)
		steps += 1
	Input.action_release("move_forward")
	_check(p.climbing == null and p.global_position.y > c.world_top().y - 1.5, "лазание доводит до яруса (высота %.1f м за %.1f c)" % [p.global_position.y - b.y, steps / 60.0])
	_check(p.stamina < start_stamina - 10.0, "подъём тратит силы (%d → %d)" % [start_stamina, p.stamina])
	Game.inventory.erase("climbing_gloves")


# ------------------------------------------------------------------ Расстановка
## Круг, который объект занимает на земле: [центр, радиус, описание] (или пусто — не мешает).
func _footprint(n: Node) -> Array:
	var p := (n as Node3D).global_position
	var c := Vector2(p.x, p.z)
	if n is ResourceNode:
		var r := n as ResourceNode
		if not r.active or r.collision_layer != 2:
			return []
		var cfg: Dictionary = ResourceNode.KINDS[r.kind]
		return [c, maxf(float(cfg["radius"]), float(cfg.get("long", 0.0)) * 0.7), r.kind]
	if n is FruitTree and n.wild:
		return [c, 0.6, "wild_" + n.tree_type]
	if n is StoryPlace and float(StoryPlace.PLACES[n.id]["radius"]) > 0.0:
		return [c, float(StoryPlace.PLACES[n.id]["radius"]), n.id]
	if n is NPCPerson:
		return [c, 0.5, "npc_" + n.npc_id]
	if n is SupplyCrate:
		return [c, 0.6, "crate"]
	return []


## Проверка расстановки: объекты не налезают друг на друга и на важные места, не стоят в воде,
## к жителям, ящику, глине и рыбалке можно подойти. Возвращает число проблем (и печатает их).
func _layout_problems(verbose := true) -> int:
	var isl: Island = main.island
	var items: Array = []
	var seen := {}
	for g in ["obstacle", "interactable"]:
		for n in get_tree().get_nodes_in_group(g):
			if seen.has(n):
				continue
			seen[n] = true
			var f := _footprint(n)
			if not f.is_empty():
				items.append(f)
	for e in isl.reserved:
		items.append([e[0], e[1], "место:" + str(e[2])])
	var problems := 0
	var cell := 4.0
	var grid := {}
	for i in items.size():
		var k := Vector2i(int(floor(items[i][0].x / cell)), int(floor(items[i][0].y / cell)))
		if not grid.has(k):
			grid[k] = []
		grid[k].append(i)
	var overl := {}
	for i in items.size():
		var a: Array = items[i]
		var k := Vector2i(int(floor(a[0].x / cell)), int(floor(a[0].y / cell)))
		for dx in [-1, 0, 1]:
			for dz in [-1, 0, 1]:
				for j in grid.get(k + Vector2i(dx, dz), []):
					if j <= i:
						continue
					var b: Array = items[j]
					if str(a[2]).begins_with("место:") and str(b[2]).begins_with("место:"):
						continue
					var d: float = a[0].distance_to(b[0])
					if d < 0.3 and (str(a[2]).begins_with("место:") or str(b[2]).begins_with("место:")):
						continue   # сам объект на своём месте
					# мелкая трава может касаться соседей, крупное — нет
					var small: bool = a[2] in Island.SMALL_KINDS or b[2] in Island.SMALL_KINDS
					if d < (a[1] + b[1]) * (0.5 if small else 0.75):
						var key := "%s + %s" % [a[2], b[2]] if str(a[2]) < str(b[2]) else "%s + %s" % [b[2], a[2]]
						overl[key] = overl.get(key, 0) + 1
						problems += 1
	if verbose:
		for key in overl:
			print("      наложение: %s ×%d" % [key, overl[key]])
	var wet := 0
	for n in get_tree().get_nodes_in_group("obstacle"):
		if n is ResourceNode and n.active and not (n.kind in ["shell", "pebble", "driftwood"]):
			var p: Vector3 = n.global_position
			if isl.height_at(p.x, p.z) < 0.12:
				wet += 1
	if verbose and wet > 0:
		print("      в воде: %d" % wet)
	problems += wet
	# подходы: вокруг важных мест должна быть свободная точка
	var blockers: Array = []
	for f in items:
		if not str(f[2]).begins_with("место:"):
			blockers.append(f)
	for n in get_tree().get_nodes_in_group("interactable"):
		if not (n is NPCPerson or n is SupplyCrate or n is FishingSpot or (n is ResourceNode and n.kind == "clay")):
			continue
		var p: Vector3 = (n as Node3D).global_position
		var c := Vector2(p.x, p.z)
		var free := false
		for s in 16:
			var a := TAU * s / 16.0
			var q := c + Vector2(cos(a), sin(a)) * (2.4 if n is FishingSpot else 1.3)
			if isl.height_at(q.x, q.y) < -0.8:
				continue
			var ok := true
			for f in blockers:
				if f[0] != c and q.distance_to(f[0]) < f[1] + 0.35:
					ok = false
					break
			free = free or ok
		if not free:
			problems += 1
			if verbose:
				print("      не подойти: %s" % QuestGuide.name_of(n))
	return problems


func _layout_only() -> void:
	print("=== LAYOUT %s ===" % Game.location)
	var isl: Island = main.island
	print("      лагерь %s, берег %s, герой %s" % [isl.camp_center, isl.wreck_point, isl.spawn_point])
	await get_tree().process_frame
	var n := _layout_problems(true)
	var kinds := {}
	for r in get_tree().get_nodes_in_group("obstacle"):
		if r is ResourceNode:
			kinds[r.kind] = kinds.get(r.kind, 0) + 1
		elif r is FruitTree:
			kinds["wild_" + r.tree_type] = kinds.get("wild_" + r.tree_type, 0) + 1
	print("      состав: ", kinds)
	print("=== %d проблем ===" % n)
	get_tree().quit(0)


# ------------------------------------------------------------------ Проходимость
## Заливка по сетке от внешнего края кольца к сюжетному месту: можно ли дойти, ничего не расчищая.
func _reachable(poi_id: String) -> bool:
	var isl: Island = main.island
	var c: Vector3 = isl.poi[poi_id]
	var R := 16.0 if poi_id == "banyan_roots" else 11.0
	var goal := 6.0 if poi_id == "banyan_roots" else 2.5   # у Баньяна в центре ствол — цель: зона корней
	var cell := 0.4
	var blockers := []
	for n in get_tree().get_nodes_in_group("obstacle"):
		if n is ResourceNode and n.collision_layer == 2:
			var cfg: Dictionary = ResourceNode.KINDS[n.kind]
			var p: Vector3 = n.global_position
			if Vector2(p.x - c.x, p.z - c.z).length() < R + 3.0:
				blockers.append([Vector2(p.x, p.z), cfg["radius"], cfg.get("long", 0.0), n.visual.rotation.y])
	var size := int(R * 2 / cell)
	var blocked := func(x: float, z: float) -> bool:
		if isl.height_at(x, z) < -0.9:
			return true
		var q := Vector2(x, z)
		for b in blockers:
			var d: Vector2 = q - b[0]
			if b[2] > 0.0:
				var local := d.rotated(b[3])
				if abs(local.x) < b[2] + 0.3 and abs(local.y) < b[1] * 0.8 + 0.3:
					return true
			elif d.length() < b[1] + 0.3:
				return true
		return false
	var seen := {}
	var queue := []
	for i in size:
		for edge in [Vector2i(i, 0), Vector2i(i, size - 1), Vector2i(0, i), Vector2i(size - 1, i)]:
			queue.append(edge)
	while not queue.is_empty():
		var g: Vector2i = queue.pop_back()
		if seen.has(g) or g.x < 0 or g.y < 0 or g.x >= size or g.y >= size:
			continue
		seen[g] = true
		var x := c.x - R + g.x * cell
		var z := c.z - R + g.y * cell
		if blocked.call(x, z):
			continue
		if Vector2(x - c.x, z - c.z).length() < goal:
			return true
		for dlt in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			queue.append(g + dlt)
	return false


# ------------------------------------------------------------------ Автотест
var fails := []


func _check(cond: bool, what: String) -> void:
	print(("  OK   " if cond else "  FAIL ") + what)
	if not cond:
		fails.append(what)


func _give(cost: Dictionary) -> void:
	for id in cost:
		Game.inventory[id] = Game.count(id) + cost[id]
	Game.inventory_changed.emit()


func _spot(i: int) -> Vector3:
	var isl: Island = main.island
	var c: Vector3 = isl.camp_center
	var a := i * 2.399
	var r := 2.0 + sqrt(float(i)) * 2.2
	var p := c + Vector3(cos(a) * r, 0, sin(a) * r)
	p.y = isl.height_at(p.x, p.z)
	return p


var _spot_i := 0


func _build(id: String, variant := "") -> Building:
	var bs: BuildSystem = main.build
	var cost := bs.cost_of(id, variant)
	_give(cost)
	Game.pay(cost)
	var pos := _spot(_spot_i)
	_spot_i += 1
	if id == "raft":
		pos = main.island.wreck_point + Vector3(0, 0, 3)
	var b := bs.spawn_building(id, pos, 0.0, variant)
	main._connect_building(b)
	Game.bump("built", id)
	return b


func _craft(out_id: String) -> void:
	for r in Data.RECIPES:
		if r["out"].has(out_id):
			_give(r["in"])
			_check(Game.craft(r), "крафт: %s" % Game.item_name(out_id))
			return


func _advance(nodes: Array, seconds: float) -> void:
	for n in nodes:
		n._process(0.0)
	Game.world_time += seconds
	for n in nodes:
		n._process(0.0)


func _bed() -> GardenBed:
	for b in get_tree().get_nodes_in_group("building"):
		if b is GardenBed and b.crop == "":
			return b
	return _build("garden_bed") as GardenBed


func _grow_and_harvest(crop: String) -> void:
	var bed := _bed()
	var seed_id := bed._seed_for(crop)
	_give({seed_id: 1})
	bed.plant(crop)
	_advance([bed], Data.CROPS[crop]["time"] + 1.0)
	bed.interact(main.player)


func _pen(id: String) -> AnimalPen:
	for b in get_tree().get_nodes_in_group("building"):
		if b is AnimalPen and b.id == id:
			return b
	return _build(id) as AnimalPen


func _do_task(t: Dictionary) -> void:
	var need: int = t["count"] - Game.task_progress(t)
	var target: String = t["target"]
	match t["kind"]:
		"talk":
			if target == "parrot":
				main.parrot.interact(main.player)
			else:
				for n in get_tree().get_nodes_in_group("interactable"):
					if n is NPCPerson and n.npc_id == target:
						n.interact(main.player)
		"collected":
			if target == "crate":
				for c in get_tree().get_nodes_in_group("interactable"):
					if c is SupplyCrate:
						c.interact(main.player)
			else:
				Game.add_item(target, need)
		"crafted":
			var guard := 0
			while Game.task_progress(t) < t["count"] and guard < 15:
				_craft(target)
				guard += 1
		"built":
			for i in need:
				_build(target, "banana" if target == "fruit_tree" else "")
		"planted":
			for i in need:
				var bed := _bed()
				_give({bed._seed_for(target): 1})
				bed.plant(target)
		"harvested":
			var guard := 0
			while Game.task_progress(t) < t["count"] and guard < 20:
				_grow_and_harvest(target)
				guard += 1
		"watered":
			if not Game.has_tool("watering_can"):
				_give({"watering_can": 1})
			for i in need:
				var bed := _bed()
				_give({"seed_carrot": 1})
				bed.plant("carrot")
				bed.interact(main.player)
		"fed":
			var pen := _pen(target)
			_give(Data.PENS[target]["feed"])
			pen.interact(main.player)
		"product":
			var pen_id := ""
			for pid in Data.PENS:
				if Data.PENS[pid]["product"] == target:
					pen_id = pid
			var guard := 0
			while Game.task_progress(t) < t["count"] and guard < 10:
				var pen := _pen(pen_id)
				if not pen.fed:
					_give(Data.PENS[pen_id]["feed"])
					pen.interact(main.player)
				_advance([pen], Data.PENS[pen_id]["time"] + 1.0)
				pen.interact(main.player)
				guard += 1
		"cleared":
			var tools := {"thicket": "machete", "bamboo": "machete", "jungle_tree": "stone_axe", "fallen_log": "stone_axe", "cliff": "pickaxe", "rock": "pickaxe", "liana_curtain": "machete"}
			if tools.has(target) and not Game.has_tool(tools[target]):
				_give({tools[target]: 1})
			var done := 0
			for c in get_tree().get_nodes_in_group("interactable"):
				if done >= need:
					break
				if c is ResourceNode and c.kind == target and c.active:
					for k in ResourceNode.KINDS[target]["hp"]:
						c.interact(main.player)
					done += 1
		"found", "lit":
			if target == "crate":
				for c in get_tree().get_nodes_in_group("interactable"):
					if c is SupplyCrate:
						c.interact(main.player)
				return
			if t["kind"] == "lit":
				_give(StoryPlace.PLACES[target]["fuel"])
			for c in get_tree().get_nodes_in_group("interactable"):
				if c is StoryPlace and c.id == target:
					c.interact(main.player)          # осмотр
					if t["kind"] == "lit":
						_flush()
						c.interact(main.player)      # зажечь
					break
		"fished":
			if not Game.has_tool("fishing_rod"):
				_give({"fishing_rod": 1})
			var spot: FishingSpot = null
			for c in get_tree().get_nodes_in_group("interactable"):
				if c is FishingSpot:
					spot = c
			for i in need:
				spot.interact(main.player)     # закинуть
				spot.state = FishingSpot.BITE  # поклёвка
				spot.interact(main.player)     # подсечь
		"solved":
			var fort := _fort()
			for sym in ["moon", "star", "sun"]:
				for lv in fort.levers:
					if lv.symbol == sym:
						lv.interact(main.player)
		"sold":
			var shop := "rumba" if target == "any" else target
			_give({"carrot": need})
			Game.sell(shop, "carrot", need)
		"bought":
			var shop_id := _shop_for(target)
			var item_id := "seed_carrot" if target == "any" else target
			var price := 0
			for e in Game.shop_items(shop_id):
				if e["item"] == item_id:
					price = e["price"]
			# честная экономика: монеты зарабатываем продажей урожая, а не выдаём даром
			var want_coins := price * need - Game.count("coins")
			if want_coins > 0:
				var n_sell: int = int(ceil(want_coins / float(Data.SELL_PRICES["watermelon"])))
				_give({"watermelon": n_sell})
				Game.sell(shop_id, "watermelon", n_sell)
				earned_by_selling += Data.SELL_PRICES["watermelon"] * n_sell
			for i in need:
				Game.buy(shop_id, item_id, price)
		"restored":
			_give(StoryPlace.PLACES[target]["restore"])
			for c in get_tree().get_nodes_in_group("interactable"):
				if c is StoryPlace and c.id == target:
					c.interact(main.player)
					_flush()
					c.interact(main.player)
					break
		"collection":
			var guard := 0
			while Game.task_progress(t) < t["count"] and guard < 10:
				Game.add_collectible(target)
				guard += 1
		"caught":
			if not Game.has_tool("net"):
				_give({"net": 1})
			var n := 0
			for c in get_tree().get_nodes_in_group("interactable"):
				if c is Critters.Butterfly and n < need:
					c.interact(main.player)
					n += 1
		"sailed":
			# прибытие на новый остров (в игре — после перезагрузки сцены)
			Game.bump("sailed", "raft")
		"reached":
			var tree := get_tree().get_first_node_in_group("obstacle")
			for n in get_tree().get_nodes_in_group("obstacle"):
				if n is BanyanTree:
					tree = n
			var idx := int(target.substr(4)) - 1
			main.player.global_position = tree.to_global(tree._deck_center(idx)) + Vector3(0, 0.3, 0)
			tree._process(0.0)
		"delivered":
			_give({target: need})
			for n in get_tree().get_nodes_in_group("interactable"):
				if n is NPCPerson and n.npc_id == t.get("to", "marta"):
					n.interact(main.player)
					break


func _autotest() -> void:
	print("=== AUTOTEST ===")
	Game.delete_save()
	Game.reset_state()
	Game.location = args.get("location", "home")
	await get_tree().process_frame
	_flush()
	Game.start_current_quest()
	var isl: Island = main.island
	var p: Player = main.player
	_check(isl.height_at(0, 0) > 1.0, "центр острова над водой")
	_check(isl.height_at(150, 150) < -1.0, "вдали — море")
	_check(p.global_position.y > 0.0, "игрок появился на суше")
	_check(get_tree().get_nodes_in_group("interactable").size() > 150, "на острове есть ресурсы и живность")
	_check(Game.quest_started and Game.current_quest()["id"] == "wake", "первое задание началось")
	for poi_id in main.island.poi.keys():
		if poi_id == "fort":
			continue   # форт закрыт стенами, а не зарослями — проверяется отдельно (_test_fort)
		_check(not _reachable(poi_id), "к месту «%s» не пройти без инструментов" % poi_id)
	_check(_layout_problems(false) == 0, "заросли не налезают друг на друга и на особые места, к жителям и ящикам можно подойти")
	var guide: QuestGuide = main.guide
	guide._find_target()
	_check(guide.has_target(), "компас задания находит цель (%s)" % guide.target_name)

	var ch := int(args.get("chapter", "1")) - 1
	if ch == 0:
		_validate()
		_test_mistakes()
		Game.start_current_quest()
		_flush()
	if ch == 1:
		_test_climb()
	if ch == 2:
		_test_fort()
	if ch > 0:
		Game.chapter = ch
		Game.quest_index = 0
		Game.quest_started = false
		Game.start_current_quest()
		_flush()
	var qs: Array = Data.CHAPTERS[ch]["quests"]
	var guard := 0
	while not Game.current_quest().is_empty() and Game.chapter == ch and guard < 60:
		guard += 1
		var q := Game.current_quest()
		_flush()
		if not Game.quest_started:
			Game.start_current_quest()
			_flush()
		for t in q["tasks"]:
			if Game.current_quest() != q:
				break
			if Game.task_progress(t) < t["count"]:
				_do_task(t)
				_flush()
		_flush()
		_check(Game.current_quest() != q, "задание «%s»" % q["title"])
		if Game.current_quest() == q:
			for t in q["tasks"]:
				print("      %s: %d/%d" % [t["text"], Game.task_progress(t), t["count"]])
			break
	var done_ch: bool = Game.chapter > ch or (Game.quest_index >= qs.size())
	_check(done_ch, "глава %d пройдена" % (ch + 1))
	print("      ₭ заработано продажей урожая по ходу главы: %d монет" % earned_by_selling)
	if ch + 1 < Data.CHAPTERS.size():
		var nq := Game.current_quest()
		_check(Game.chapter == ch + 1 and not nq.is_empty() and nq["id"] == Data.CHAPTERS[ch + 1]["quests"][0]["id"],
			"после главы %d сразу начинается глава %d («%s»)" % [ch + 1, ch + 2, nq.get("title", "—")])
	if ch > 0:
		Game.delete_save()
		print("=== %s (%d ошибок) ===" % ["PASSED" if fails.is_empty() else "FAILED", fails.size()])
		get_tree().quit(0 if fails.is_empty() else 1)
		return
	_check(Game.unlocked.has("raft") and Game.unlocked.has("hut"), "постройки открываются по сюжету")
	_check(Game.collections.get("butterflies", {}).size() > 0, "бабочки попадают в коллекцию")

	# сохранение / загрузка
	main._save()
	var inv_copy: Dictionary = Game.inventory.duplicate()
	var n_build := get_tree().get_nodes_in_group("building").size()
	Game.inventory = {}
	var data := Game.load_game()
	_check(Game.inventory == inv_copy, "инвентарь сохраняется и загружается")
	var here: Dictionary = data.get("locations", {}).get(Game.location, {})
	_check(here.get("buildings", []).size() == n_build, "постройки сохраняются (%d)" % n_build)
	var bed_state := false
	for b in here.get("buildings", []):
		if b["id"] == "garden_bed" and b["s"].has("crop"):
			bed_state = true
	_check(bed_state, "состояние грядок сохраняется")
	_check(data.get("cleared", []).size() > 5, "расчищенные заросли сохраняются (%d)" % data.get("cleared", []).size())
	var obstacles := 0
	for c in get_tree().get_nodes_in_group("obstacle"):
		if c is ResourceNode and c.is_obstacle():
			obstacles += 1
	_check(obstacles > 400, "остров зарос: преград %d" % obstacles)
	Game.delete_save()
	Game.reset_state()

	print("=== %s (%d ошибок) ===" % ["PASSED" if fails.is_empty() else "FAILED", fails.size()])
	get_tree().quit(0 if fails.is_empty() else 1)
