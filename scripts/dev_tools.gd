extends Node
## Инструменты разработчика. Включаются аргументами командной строки после "--":
##   --shot=путь     сделать скриншот и выйти (--frames=N — через сколько кадров)
##   --time=0..1     время суток
##   --demo          построить лагерь с фермой рядом с игроком (для скриншотов)
##   --yaw= --pitch= --dist=  положение камеры
##   --autotest      пройти главу через игровую логику и вывести результат
##                   (--chapter=N — какую; --from=K — начать с K-го задания главы, с нуля; --upto=K — остановиться после K заданий)
##   --bunker=N      поставить героя на ярус N бункера (Грозовой остров)
##   --near=glacier_top|ingrid|walrus|penguins|ice_tower|ice_chest_1..3 — герой у места на Ледяном острове
##   --thaw=1        Ледяной остров уже оттаял (для скриншотов «весны»)
##   --wear=sweater|jacket — герой в тёплой одежде (с jacket — ещё валенки и рукавицы); fire — огнеупорные рукавицы
##   --near=vera|springs|temple_gate|crater_top|volcano_tower|crater_foot — герой у места на Острове Вулкана
##   --solved=1      на Вулкане: монолит решён, мостки построены (для скриншотов)
##   --view=temple   на Вулкане: герой перед входом в храм, камера смотрит на дверь
##   --near=stilt_camp|signal_rock|fog_shrine|fog_tower|misha|renata — места на Туманном острове
##   --view=albatros на Туманном: герой на конце мостков, камера смотрит на «Альбатрос»
##   --fogdone=1     на Туманном: седьмой огонь горит, туман ушёл, «Альбатрос» починен (для скриншотов)
##   --near=eye_tower|eye_top|grandfather_house|great_lighthouse|order_board — места на Оке (и доска заказов дома)
##   --eyedeck=1..3  на Оке: герой на балконе Великого маяка (3 — вершина)
##   --lens=1        на Оке: линза стоит, Великий огонь золотой
##   --ending=sea|keeper  финал (для автотеста главы 8 и скриншотов «после финала»)

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
	if args.has("validate"):
		_validate_only.call_deferred()


func _process(_delta: float) -> void:
	_frames += 1
	var p: Player = main.player
	if _frames == 1 and args.get("thaw", "") == "1":
		Game.flags["ice_thawed"] = true
		main.island.thaw(false)
	if _frames == 2 and args.has("wear"):
		if args["wear"] == "sweater":
			Game.inventory["sweater"] = 1
		elif args["wear"] == "fire":
			Game.inventory["fire_gloves"] = 1
		else:
			for id in ["down_jacket", "felt_boots", "mittens"]:
				Game.inventory[id] = 1
		p.update_clothes()
	if _frames == 1 and args.has("quest"):   # для скриншотов: текущее задание по id (--quest=old_camp)
		for ci in Data.CHAPTERS.size():
			var qs: Array = Data.CHAPTERS[ci]["quests"]
			for qi in qs.size():
				if qs[qi]["id"] == args["quest"]:
					Game.chapter = ci
					Game.quest_index = qi
					Game.quest_started = false
					Game.start_current_quest()
					_flush()
	if _frames == 1 and args.get("lens", "") == "1":
		Game.flags["eye_lens"] = true
		get_tree().call_group("great_fire", "refresh", false)
	if _frames == 1 and args.has("ending") and not args.has("autotest"):
		Game.flags["ending_open_sea" if args["ending"] == "sea" else "ending_keeper"] = true
		get_tree().call_group("great_fire", "refresh", false)
		if args["ending"] == "sea":
			for es in get_tree().get_nodes_in_group("eye_storm"):
				es.dissolve()
	if _frames == 2 and args.has("give"):   # для скриншотов: выдать предметы (--give=stone_axe,machete)
		for id in str(args["give"]).split(","):
			Game.inventory[id] = 1
		Game.inventory_changed.emit()
	if _frames == 2 and args.has("hold"):
		Game.hold(str(args["hold"]))
	if _frames >= 2 and args.has("pose"):   # для скриншотов: застывшая поза работы (--pose=stone_axe:0.32)
		var pp: PackedStringArray = str(args["pose"]).split(":")
		p.swing_kind = pp[0]
		p.pose_hold = float(pp[1]) if pp.size() > 1 else 0.5
		if args.has("face"):
			p.model.rotation.y = float(args["face"])
	if _frames == 2 and args.get("near", "") == "crate":   # для скриншотов: герой у ящика, лицом к нему
		for c in get_tree().get_nodes_in_group("interactable"):
			if c is SupplyCrate:
				p.global_position = c.global_position + Vector3(1.4, 0.4, 0.6)
				p.model.rotation.y = atan2(p.global_position.x - c.global_position.x, p.global_position.z - c.global_position.z)
				p.cam_rig.global_position = p.global_position + Vector3(0, 1.4, 0)
	if _frames == 2 and args.has("eyedeck"):
		var gl := _tower()
		if gl:
			p.global_position = gl.deck_point(int(args["eyedeck"]) - 1)
			p.cam_rig.global_position = p.global_position + Vector3(0, 1.4, 0)
			_flush()
	if _frames == 1 and args.get("fogdone", "") == "1":
		Game.flags["fog_cleared"] = true
		for part in StiltCamp.PARTS:
			Game.flags["restored_" + part] = true
	if _frames == 2 and args.get("solved", "") == "1":
		var tp := _temple()
		if tp:
			for sp in tp.spots:
				main.build.spawn_building("stone_bridge", sp.global_position, sp.rotation.y)
			Game.flags["monolith_solved"] = true
			for c in tp.chutes:
				c.dir = int(VolcanoTemple.TARGET[c.index])
				c._face(false)
			tp._open(false)
	if _frames == 2 and args.get("view", "") == "albatros":
		var cv := _camp()
		if cv:
			p.global_position = cv.to_global(cv.out * 10.5 + Vector3(0, StiltCamp.DECK_TOP + 0.4 - cv.global_position.y, 0))
			p.cam_rig.global_position = p.global_position + Vector3(0, 1.4, 0)
			p.camera_yaw = atan2(-cv.out.x, -cv.out.z) + 0.5
			_flush()
	if _frames == 2 and args.get("view", "") == "temple":
		var tv := _temple()
		if tv:
			p.global_position = tv.global_position + tv.out * 4.0 + Vector3(0, 0.5, 0)
			p.cam_rig.global_position = p.global_position + Vector3(0, 1.4, 0)
			p.camera_yaw = atan2(tv.out.x, tv.out.z)
			_flush()
	if _frames == 2:
		if args.has("dbgdraw"):   # отладка рендера: 1 — без света, 2 — только свет, 5 — нормали, 12 — SSAO
			get_viewport().debug_draw = int(args["dbgdraw"]) as Viewport.DebugDraw
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
		if args.has("bunker"):
			var stn := _station()
			if stn:
				if args.get("lit", "") == "1":
					Game.flags["restored_generator"] = true
					Game.inventory["lantern"] = 1
				p.global_position = stn.deck_point("bunker" + args["bunker"])
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
		if args.has("lookat") and main.island.poi.has(args["lookat"]):   # камерой на сюжетное место
			var d: Vector3 = main.island.poi[args["lookat"]] - p.global_position
			p.camera_yaw = atan2(-d.x, -d.z)
	if args.has("time"):
		Game.time_of_day = float(args["time"])
	if args.has("demo") and _frames > 2 and _frames < 6:
		_flush()
	if _frames == 8:
		var hud: HUD = main.hud
		if args.has("nohud"):   # чистый кадр без интерфейса — для оценки картинки
			_flush()
			hud.visible = false
		if args.has("flush"):   # закрыть вступительные диалоги, интерфейс оставить
			_flush()
		if args.has("building"):   # для скриншотов: режим строительства (--building=campfire)
			Game.unlocked[str(args["building"])] = true
			main.build.start(str(args["building"]))
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
			"settings":
				main._pause()
				main.menu.open_settings(main.menu.show_pause)
	if args.has("gallery") and _frames > 2:
		p.cam_rig.global_position = main.island.camp_center + Vector3(0, float(args.get("camy", "0.8")), 0)
	if args.has("fxtest") and _frames == int(args.get("frames", "90")) - int(args.get("fxlead", "2")):
		# все эффекты сразу перед кадром (время замедлено, чтобы застать их в полёте)
		Engine.time_scale = float(args.get("fxscale", "0.08"))
		var fwd := -p.camera.global_transform.basis.z
		fwd.y = 0.0
		fwd = fwd.normalized()
		var right := fwd.cross(Vector3.UP)
		var base := p.global_position + fwd * 2.2
		var w: Node3D = main
		FX.burst(w, base - right * 2.4 + Vector3(0, 0.6, 0), Color("c9a26b"), 14)
		FX.sparks(w, base - right * 1.2 + Vector3(0, 0.6, 0), 12)
		FX.burst(w, base - right * 1.2 + Vector3(0, 0.6, 0), Color("a0a4a8"), 8)
		FX.leaves(w, base + Vector3(0, 0.8, 0), Color("4f9a4a"), 9)
		FX.poof(w, base + right * 1.3 + Vector3(0, 0.5, 0), Color("8fa850"), 1.0)
		FX.ring(w, base + right * 2.6 + Vector3(0, 0.08, 0), Color("e6dcc0"), 1.0, 14)
		FX.dust(w, p.global_position + Vector3(0, 0.05, 0), Color("f1dfb0"), 8, 0.45)
		FX.popup(w, p.global_position + Vector3(0, 1.85, 0), "wood", 3)
		FX.popup(w, p.global_position + Vector3(0, 2.15, 0), "stone", 2)
		FX.flash(p.model, 1.0, 0.6)
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
## Палатка по заданию — только на поляне у лагеря, костёр — только у палатки.
func _test_quest_places() -> void:
	var bs: BuildSystem = main.build
	var c: Vector3 = main.island.camp_center
	var far := c + Vector3(25, 0, 0)
	Game.chapter = 0
	for i in Data.CHAPTERS[0]["quests"].size():
		if Data.CHAPTERS[0]["quests"][i]["id"] == "tent":
			Game.quest_index = i
	Game.quest_started = true
	_check(bs.quest_place_problem("tent", far) != "" and bs.quest_place_problem("tent", c + Vector3(2, 0, 1)) == "",
		"палатку по заданию ставят только на поляне у лагеря")
	for i in Data.CHAPTERS[0]["quests"].size():
		if Data.CHAPTERS[0]["quests"][i]["id"] == "fire":
			Game.quest_index = i
	_check(bs.quest_place_problem("campfire", c) != "", "костёр без палатки рядом не засчитать")
	var tent: Building = bs.spawn_building("tent", c, 0.0)
	_check(bs.quest_place_problem("campfire", c + Vector3(3, 0, 0)) == "" and bs.quest_place_problem("campfire", far) != "",
		"костёр — только рядом с палаткой")
	tent.queue_free()
	Game.chapter = 0
	Game.quest_index = 0
	Game.quest_started = false


## Пальма: с пустыми руками её трясут (кокосы), с топором в руке — рубят. Инструменты в ячейках 1–0.
func _test_palm() -> void:
	var p: Player = main.player
	var palm: ResourceNode = null
	for n in get_tree().get_nodes_in_group("interactable"):
		if n is ResourceNode and n.kind == "palm" and n.active and n.coconut_ready:
			palm = n
			break
	if palm == null:
		_check(false, "на острове есть пальма с кокосами")
		return
	var had := Game.count("stone_axe")
	Game.inventory["stone_axe"] = 1
	var hp0 := palm.hp
	var leaf0 := Game.count("leaf")
	Game.hold("")
	palm.interact(p)
	_check(not palm.coconut_ready and palm.hp == hp0 and Game.count("leaf") == leaf0 + 1, "пустыми руками пальму трясут: кокосы падают, пальма цела")
	Game.hold("stone_axe")
	palm.interact(p)
	_check(palm.hp == hp0 - 1, "с топором в руке пальму рубят")
	Game.inventory["machete"] = 1
	_check(Game.hold_slots() == ["machete", "stone_axe"], "в ячейках внизу — инструменты по порядку")
	var bush: ResourceNode = null
	for n in get_tree().get_nodes_in_group("interactable"):
		if n is ResourceNode and n.kind == "thicket" and n.active:
			bush = n
	if bush:
		p.target = bush
		p._swing_t = 0.0
		p.try_interact()
		_check(Game.held_tool() == "machete", "к колючкам герой сам берёт мачете (умный выбор)")
		p._swing_t = 0.0
		p.target = null
	Game.inventory.erase("machete")
	Game.hold("")
	palm.hp = hp0
	palm.coconut_ready = true
	if had == 0:
		Game.inventory.erase("stone_axe")
	Game.inventory.erase("leaf")
	Game.inventory.erase("coconut")
	if leaf0 > 0:
		Game.inventory["leaf"] = leaf0


## Инструменты не ломаются — вторую копию не сделать и не купить; лишние в старом сохранении разбираются.
func _test_unique() -> void:
	var inv: Dictionary = Game.inventory.duplicate()
	var unl: Dictionary = Game.unlocked.duplicate()
	Game.unlocked["net"] = true
	Game.inventory = {"net": 1, "bamboo": 5, "rope": 5, "fiber": 10}
	var r := {}
	for rr in Data.RECIPES:
		if rr["out"].has("net"):
			r = rr
	_check(not Game.craft(r) and Game.count("net") == 1, "второй сачок не сделать — он уже есть")
	Game.inventory = {"net": 3}
	Game._merge_duplicate_tools()
	var back := 0
	for m in r["in"]:
		back += Game.count(m)
	_check(Game.count("net") == 1 and back > 0, "лишние сачки из старого сохранения разобраны на материалы")
	Game.inventory = inv
	Game.unlocked = unl
	Game.inventory_changed.emit()


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


# ------------------------------------------------------------------ Грозовой остров
func _station() -> StormStation:
	for n in get_tree().get_nodes_in_group("bunker"):
		return n
	return null


func _test_storm() -> void:
	var stn := _station()
	_check(stn != null, "на вершине стоит метеостанция с бункером")
	if stn == null:
		return
	var ladders := 0
	for c in get_tree().get_nodes_in_group("climb"):
		if c.ladder:
			ladders += 1
	_check(ladders == StormStation.DECKS - 1, "в бункере %d лестниц между 7 ярусами" % ladders)
	# без света проёмы вниз закрыты
	Game.flags.erase("restored_generator")
	Game.inventory.erase("lantern")
	stn._update_gates()
	_check(not stn._gates[1].disabled and not stn._gates[3].disabled, "без генератора и фонаря вниз не спуститься")
	Game.flags["restored_generator"] = true
	stn._update_gates()
	_check(stn._gates[1].disabled and not stn._gates[3].disabled, "генератор открывает ярусы 2–3, ниже нужен фонарь")
	Game.inventory["lantern"] = 1
	stn._update_gates()
	_check(stn._gates[3].disabled, "с фонарём можно спуститься до дна")
	Game.flags.erase("restored_generator")
	Game.inventory.erase("lantern")
	stn._update_gates()
	# громоотвод заряжает только в грозу
	Game.unlocked["lightning_rod"] = true
	var rod := _pen("lightning_rod")
	_give({"battery": 1})
	Game.storm_force = false
	main.weather._storm_forced = 0
	main.weather._process(0.0)
	rod.interact(main.player)
	_check(rod.fed, "на громоотвод вешается пустой аккумулятор")
	rod._process(0.0)
	Game.world_time += 3.0
	rod._process(0.0)
	_check(rod.progress == 0.0, "без грозы аккумулятор не заряжается")
	Game.storm_force = true
	Game.world_time += Data.PENS["lightning_rod"]["time"] * 0.5
	rod._process(0.0)
	_check(rod.progress > 0.0 and not rod.product_ready, "в грозу заряд растёт (%d%%)" % int(rod.progress * 100))
	Game.world_time += 4.0
	for i in 20:
		Game.world_time += 3.0
		rod._process(0.0)
	_check(rod.product_ready, "за грозу аккумулятор заряжается")
	rod.interact(main.player)
	_check(Game.count("battery_charged") >= 1, "заряженный аккумулятор попадает в сумку")
	Game.inventory.erase("battery_charged")
	# в грозу по лиане не лезут, а по лестнице — можно
	var p: Player = main.player
	var lad: Climbable = null
	for c in get_tree().get_nodes_in_group("climb"):
		lad = c
	_check(Game.storm_active(), "гроза идёт (принудительно)")
	if lad:
		p.global_position = lad.world_bottom() + Vector3(0.6, 0.3, 0)
		p._find_climb()
		_check(p.near_climb == lad and lad.ladder, "у лестницы бункера можно лезть без перчаток")
	# молния у героя на вершине: отбросит и уронит вещи, которые можно подобрать
	var isl: Island = main.island
	var top: Vector3 = isl.poi["station"] + Vector3(2.0, 0.5, -2.0)
	p.global_position = top
	_give({"wood": 5, "stone": 5})
	var before := Game.count("wood") + Game.count("stone")
	main.weather._hit_player_cd = 0.0
	main.weather._random_strike()
	var dropped := get_tree().get_nodes_in_group("pickup")
	_check(Game.count("wood") + Game.count("stone") < before and dropped.size() > 0, "молния на вершине роняет вещи (%d на земле)" % dropped.size())
	for d in dropped:
		if d.item_id != "":
			d.interact(p)
	_check(Game.count("wood") + Game.count("stone") == before, "выроненное можно подобрать — ничего не теряется")
	Game.inventory.erase("wood")
	Game.inventory.erase("stone")
	# ливень поливает грядки
	Game.unlocked["garden_bed"] = true
	var bed := _bed()
	_give({"seed_pumpkin": 1})
	bed.plant("pumpkin")
	main.weather._storm_process(0.1)
	_check(bed.watered, "в грозу грядки поливаются сами")
	# песок и железо есть на острове
	var sand := 0
	var scrap := 0
	for n in get_tree().get_nodes_in_group("interactable"):
		if n is ResourceNode and n.kind == "sand":
			sand += 1
		if n is ResourceNode and n.kind == "scrap_pile":
			scrap += 1
	_check(sand >= 4, "на пляже есть песок (%d ям)" % sand)
	_check(scrap >= 8, "у станции и самолёта есть железо (%d куч)" % scrap)
	main.weather._storm_forced = -1


# ------------------------------------------------------------------ Ледяной остров
func _glacier() -> IceGlacier:
	for n in get_tree().get_nodes_in_group("glacier"):
		return n
	return null


func _test_ice() -> void:
	var gl := _glacier()
	_check(gl != null, "на Ледяном острове стоит ледник с обсерваторией")
	if gl == null:
		return
	var p: Player = main.player
	var w: Warmth = main.warmth
	_check(w != null and Game.cold_active(), "на Ледяном острове холодно, шкала тепла работает")
	_check(gl.climb.ice and gl.climb.locked_hint != "", "к ледяной стене не подойти, пока на тропе спит морж")
	# высота обрыва: снизу не запрыгнуть
	_check(gl.top - gl.climb.bottom.y > 4.5, "обрыв ледника высокий (%.1f м)" % (gl.top - gl.climb.bottom.y))
	# холод: без одежды — втрое быстрее, чем в куртке
	var far := gl.foot_point() + Vector3(0, 0, 0)
	p.global_position = far
	Game.inventory = {}
	Game.warmth = 100.0
	w.tick(10.0)
	var bare := 100.0 - Game.warmth
	Game.inventory = {"down_jacket": 1}
	Game.warmth = 100.0
	w.tick(10.0)
	var jacket := 100.0 - Game.warmth
	_check(bare > 0.0 and absf(bare / maxf(jacket, 0.01) - 3.0) < 0.05, "без тёплой одежды остываешь втрое быстрее, чем в куртке (%.1f / %.1f)" % [bare, jacket])
	Game.inventory = {"down_jacket": 1, "felt_boots": 1, "mittens": 1}
	Game.warmth = 100.0
	w.tick(10.0)
	_check(100.0 - Game.warmth < jacket * 0.65, "валенки и рукавицы греют ещё лучше")
	# у костра теплеет
	var fire: Building = main.build.spawn_building("campfire", far + Vector3(2.0, 0, 0), 0.0)
	Game.warmth = 20.0
	w.tick(1.0)
	_check(Game.warmth > 40.0 and w.near_fire, "у костра шкала тепла растёт")
	# чай
	Game.inventory["honey_tea"] = 1
	Game.warmth = 40.0
	p.global_position = far + Vector3(0, 0, 30.0)
	_check(Warmth.drink_tea() and Game.warmth == 100.0, "кружка чая с мёдом согревает сразу")
	w.tick(10.0)
	_check(Game.warmth == 100.0, "пока греет чай, холод не страшен")
	Game.warm_tea = 0.0
	# замёрз: инструменты не держатся, лезть нельзя
	Game.warmth = 0.0
	Game.inventory["ice_pick"] = 1
	var wall: ResourceNode = null
	for n in get_tree().get_nodes_in_group("interactable"):
		if n is ResourceNode and n.kind == "ice_wall" and n.active:
			wall = n
	if wall:
		var hp0: int = wall.hp
		wall.interact(p)
		_check(wall.hp == hp0, "замёрзшими руками ледоруб не держится")
	_check(Game.frozen(), "без тепла герой замерзает")
	# через полминуты без тепла Румба утаскивает к огню
	for i in 31:
		w.tick(1.0)
	await get_tree().create_timer(1.6).timeout
	_check(Game.warmth >= 60.0 and p.global_position.distance_to(fire.global_position) < 4.5, "замёрзшего героя Румба утаскивает к огню")
	_flush()
	fire.queue_free()
	# лунки: без бура не просверлить
	var holes := 0
	for n in get_tree().get_nodes_in_group("interactable"):
		if n is FishingSpot and n.ice:
			holes += 1
			if holes == 1:
				n.interact(p)
				_check(not n.drilled(), "без ледового бура лунку не просверлить")
	_check(holes >= 3, "на бухте у пингвинов есть лунки (%d)" % holes)
	var feeder := false
	var walrus := false
	var ingrid := false
	for n in get_tree().get_nodes_in_group("interactable"):
		if n is NPCPerson:
			feeder = feeder or n.npc_id == "penguins"
			walrus = walrus or n.npc_id == "walrus"
			ingrid = ingrid or n.npc_id == "ingrid"
	_check(feeder and walrus and ingrid, "пингвины, морж и Ингрид на месте")
	var penguins := 0
	for n in get_tree().get_nodes_in_group("interactable"):
		if n is Animal and n.kind == "penguin":
			penguins += 1
	_check(penguins >= 5, "у бухты живут пингвины (%d)" % penguins)
	# теплица: внутри растёт всё, снаружи в мороз — только морошка
	Game.unlocked["garden_bed"] = true
	var bed := _bed()
	_check(not bed.can_grow("carrot") and bed.can_grow("cloudberry"), "в мороз на улице растёт только морошка")
	var gh := main.build.spawn_building("greenhouse", far + Vector3(-6.0, 0, 4.0), 0.0) as Greenhouse
	_check(gh != null and gh.beds.size() == 4 and gh.beds[0].can_grow("carrot"), "в теплице четыре грядки, растёт и морковь")
	Game.inventory["seed_carrot"] = 1
	gh.beds[0].plant("carrot")
	var st := gh.get_state()
	_check(st["beds"][0]["crop"] == "carrot", "грядки теплицы сохраняются вместе с ней")
	gh.queue_free()
	# звёздный круг: днём не решить, неверные кольца — не решено
	_check(not gl.dial.solved(), "звёздный круг не решён с самого начала")
	gl.dial.pos = [1, 2, 5]
	_check(not gl.dial.check(), "неверное положение колец не засчитывается")
	gl.dial.pos = IceGlacier.STARS_START.duplicate()
	# ресурсы
	var counts := {}
	for n in get_tree().get_nodes_in_group("interactable"):
		if n is ResourceNode:
			counts[n.kind] = counts.get(n.kind, 0) + 1
	_check(counts.get("ice_wall", 0) >= 14, "ледяных стен хватает на задания (%d, нужно 7)" % counts.get("ice_wall", 0))
	_check(counts.get("pine", 0) >= 8, "сосен для смолы хватает (%d)" % counts.get("pine", 0))
	_check(counts.get("ice_block", 0) >= 4, "есть ледяные глыбы для мороженого (%d)" % counts.get("ice_block", 0))
	var chests := 0
	for n in get_tree().get_nodes_in_group("interactable"):
		if n is StoryPlace and n.id.begins_with("ice_chest"):
			chests += 1
	_check(chests == 3, "на острове три ледяных ларца")
	Game.inventory = {}
	Game.warmth = 100.0
	p.global_position = main.island.spawn_point


# ------------------------------------------------------------------ Остров Вулкана
func _crater() -> VolcanoCrater:
	for n in get_tree().get_nodes_in_group("crater"):
		return n
	return null


func _temple() -> VolcanoTemple:
	for n in get_tree().get_nodes_in_group("temple"):
		return n
	return null


func _test_volcano() -> void:
	var cr := _crater()
	var tp := _temple()
	var p: Player = main.player
	var h: Heat = main.heat
	_check(cr != null and tp != null and h != null, "на Острове Вулкана есть кратер, храм и жар")
	if cr == null or tp == null or h == null:
		return
	_check(cr.top - cr.climb.bottom.y > 4.5 and cr.climb.rock and cr.climb.hot, "стена кратера высокая (%.1f м), лезть — по горячим выступам" % (cr.top - cr.climb.bottom.y))
	_check(tp.spots.size() == 3 and tp.bridged_count() == 0, "на лаве три места под мостки, пока пустые")
	var closed := 0
	for sp in tp.spots:
		if not sp.block.disabled:
			closed += 1
	_check(closed == 3, "без мостков лава не пускает к храму")
	# сквозь лаву не пройти: от внешнего края поля к двери любой путь упирается в стенку над лавой
	var space := tp.get_world_3d().direct_space_state
	var blocked := 0
	for k in 9:
		var a := -1.0 + k * 0.25
		var dir := (tp.out * cos(a) + tp.side * sin(a)).normalized()
		var from := tp.global_position + dir * 9.6 + Vector3(0, 0.5, 0)
		var to := tp.global_position + dir * 3.0 + Vector3(0, 0.5, 0)
		from.y = main.island.height_at(from.x, from.z) + 0.5
		to.y = main.island.height_at(to.x, to.z) + 0.5
		var q := PhysicsRayQueryParameters3D.create(from, to, 2)
		if not space.intersect_ray(q).is_empty():
			blocked += 1
	_check(blocked == 9, "лавовые ручьи перегораживают все пути к двери (%d/9)" % blocked)
	# жар: у лавы растёт, в рукавицах — вдвое медленнее, полный — отбрасывает
	var sp0: VolcanoTemple.BridgeSpot = tp.spots[0]
	var near_lava := sp0.global_position + tp.side * 0.0 + Vector3(0, 0.3, 0)
	p.global_position = near_lava
	Game.inventory = {}
	Game.heat = 0.0
	h.tick(0.5)
	var bare := Game.heat
	Game.inventory = {"fire_gloves": 1}
	Game.heat = 0.0
	h.tick(0.5)
	var gloved := Game.heat
	_check(bare > 5.0 and absf(bare / maxf(gloved, 0.01) - 2.0) < 0.1, "у лавы жар растёт, в огнеупорных рукавицах — вдвое медленнее (%.1f / %.1f)" % [bare, gloved])
	Game.inventory = {"burn_salve": 1}
	Game.heat = 60.0
	_check(Heat.use_salve() and Game.heat <= 20.0 and Game.salve_t > 0.0, "мазь от ожогов сбивает жар и действует минуту")
	Game.salve_t = 0.0
	Game.heat = 99.5
	p.velocity = Vector3.ZERO
	h._push_cd = 0.0
	h.tick(0.5)
	_check(Game.heat < 100.0 and p.velocity.length() > 3.0, "полный жар отбрасывает героя от лавы, без вреда")
	# источники остужают
	var springs: HotSprings = null
	for n in get_tree().get_nodes_in_group("cool_spot"):
		springs = n
	_check(springs != null, "у лагеря есть горячие источники")
	if springs:
		p.global_position = springs.global_position + Vector3(0.5, 0.3, 0.5)
		Game.heat = 90.0
		h.tick(1.0)
		_check(Game.heat < 20.0, "у источников жар спадает сразу")
	# монолит: неверные жёлоба — дверь закрыта
	tp.pull_lever()
	_check(not tp.solved(), "с неверными жёлобами лава до чаши не доходит")
	# ресурсы для глав
	var counts := {}
	for n in get_tree().get_nodes_in_group("interactable"):
		if n is ResourceNode:
			counts[n.kind] = counts.get(n.kind, 0) + 1
	for k in ["aloe", "coffee_bush", "charred_tree", "ore_vein", "obsidian_rock"]:
		_check(counts.get(k, 0) >= 5, "на острове есть «%s» (%d)" % [k, counts.get(k, 0)])
	_check(counts.get("basalt", 0) >= 10, "базальтовых столбов хватает (%d, нужно 3)" % counts.get("basalt", 0))
	Game.inventory = {}
	Game.heat = 0.0
	p.global_position = main.island.spawn_point


# ------------------------------------------------------------------ Туманный остров
func _camp() -> StiltCamp:
	for n in get_tree().get_nodes_in_group("stilt_camp"):
		return n
	return null


func _shrine() -> FogShrine:
	for n in get_tree().get_nodes_in_group("fog_shrine"):
		return n
	return null


func _signal() -> SignalRock:
	for n in get_tree().get_nodes_in_group("signal_rock"):
		return n
	return null


func _test_fog() -> void:
	var camp := _camp()
	var shrine := _shrine()
	var sig := _signal()
	var fs: FogSystem = main.fog
	var p: Player = main.player
	_check(camp != null and shrine != null and sig != null and fs != null, "на Туманном острове есть лагерь, святилище, сигнальный камень и туман")
	if camp == null or shrine == null or sig == null or fs == null:
		return
	_check(main.world_env.env.volumetric_fog_enabled, "остров окутан объёмным туманом")
	# у костра туман расступается
	var fire: Building = main.build.spawn_building("campfire", main.island.camp_center, 0.0)
	fs.refresh()
	_check(fs.clear_at(main.island.camp_center) and not fs.clear_at(sig.global_position + Vector3(0, 0, 9)), "туман расступается у огня, а вдали — стоит")
	fire.queue_free()
	# плыть в туман — только ночью
	Game.time_of_day = 0.5
	_check(not Game.fog_hours(), "днём в туман не плывут")
	Game.time_of_day = 0.9
	_check(Game.fog_hours(), "ночью — можно")
	# светлячки ловятся сачком
	var bugs := get_tree().get_nodes_in_group("firefly")
	_check(bugs.size() >= 10, "над болотом летают светлячки (%d)" % bugs.size())
	if bugs.size() > 0:
		Game.inventory.erase("net")
		var b: FogLife.Bug = bugs[0]
		b.interact(p)
		_check(Game.count("firefly") == 0 and b.active, "без сачка светлячка не поймать")
	# Миша прячется, пока на тропе нет света
	var misha: NPCPerson = null
	for n in get_tree().get_nodes_in_group("interactable"):
		if n is NPCPerson and n.npc_id == "misha":
			misha = n
	_check(misha != null and sig.spots.size() == 5, "у сигнального камня Миша, на тропе пять меток")
	_check(shrine.spots.size() == 6 and not shrine.solved(), "у стоячих камней шесть меток, проход закрыт")
	# неверные фонари у камней — проход закрыт; фонарь можно забрать
	var bs: BuildSystem = main.build
	var wrong: Building = bs.spawn_building("pumpkin_lantern", shrine.spots[1].global_position, 0.0)
	wrong._claim_spot()
	shrine._process(0.0)
	_check(not shrine.solved() and shrine.spots[1].used, "фонарь не на той метке — скала не открывается")
	wrong.interact(p)
	_check(not shrine.spots[1].used and Game.count("pumpkin_lantern") == 1, "фонарь у камней можно забрать и переставить")
	Game.inventory.erase("pumpkin_lantern")
	_check(not camp.ship.ready_to_sail(), "«Альбатрос» не готов к выходу, пока не починен")
	var mangroves := 0
	for n in get_tree().get_nodes_in_group("interactable"):
		if n is ResourceNode and n.kind == "mangrove":
			mangroves += 1
	_check(mangroves >= 12, "у берега растут мангры (%d)" % mangroves)
	Game.inventory = {}
	p.global_position = main.island.spawn_point


# ------------------------------------------------------------------ Око шторма
func _tower() -> GreatLighthouse:
	for n in get_tree().get_nodes_in_group("great_lighthouse"):
		return n
	return null


func _storm() -> EyeStorm:
	for n in get_tree().get_nodes_in_group("eye_storm"):
		return n
	return null


func _test_eye() -> void:
	var gl := _tower()
	var es := _storm()
	var p: Player = main.player
	_check(gl != null and es != null, "на Оке есть Великий маяк и стена шторма")
	if gl == null or es == null:
		return
	_check(es.wall != null and es.beams.size() == 7, "вокруг — стена шторма и семь лучей маяков")
	_check(gl.climbs.size() == 3 and gl.climbs[1].ladder, "подъём из трёх участков: стена, лестница внутри, стена")
	gl._process(0.0)
	_check(gl.climbs[0].locked_hint != "", "на маяк не лезут, пока не прочитана Книга Хранителей")
	var crew := 0
	var lyova_here := false
	for n in get_tree().get_nodes_in_group("interactable"):
		if n is NPCPerson and n.npc_id in EyeIsland.CREW:
			crew += 1
		if n is NPCPerson and n.npc_id == "lyova":
			lyova_here = n.global_position.y > gl.global_position.y + float(GreatLighthouse.H[2]) - 1.0
	_check(crew == EyeIsland.CREW.size(), "команда ждёт на берегу (%d)" % crew)
	_check(lyova_here, "Лёва сидит на вершине маяка, у огня")
	_check(gl.fire_node._state == "blue", "до линзы Великий огонь синий")
	var places := {}
	for n in get_tree().get_nodes_in_group("interactable"):
		if n is StoryPlace:
			places[n.id] = n
	_check(places.has("grandfather_house") and places.has("grandfather_letters") and places.has("keepers_book"), "в саду домик и письма, у маяка — Книга")
	if places.has("keepers_book"):
		# порядок находок: письма — после дома, Книга — после писем
		places["keepers_book"].interact(p)
		_check(not Game.flags.get("poi_keepers_book", false), "Книгу не открыть раньше писем деда")
	# ветер на балконе толкает к перилам, внутри башни — тихо
	p.global_position = gl.deck_point(0)
	GreatLighthouse.gust = 1.0
	gl._phase = 2
	gl._phase_t = 99.0
	gl._process(0.0)
	_check(p.ext_push.length() > 1.0, "в порыв ветер толкает героя на балконе")
	p.global_position = gl.global_position + Vector3(0, float(GreatLighthouse.H[0]) + 0.3, 0)
	gl._process(0.0)
	_check(p.ext_push == Vector3.ZERO and p.force_indoor, "внутри башни ветра нет, камера ближе")
	# в порыв на внешней стене силы тают быстрее, если лезть
	var c3: Climbable = gl.climbs[2]
	_check(c3.wind and c3.rest_step > 0.0, "верхняя стена — на ветру, с уступами для отдыха")
	GreatLighthouse.gust = 0.0
	gl._phase = 0
	gl._phase_t = 6.0
	p.ext_push = Vector3.ZERO
	p.force_indoor = false
	p.global_position = main.island.spawn_point


## После финала: флаги, стена шторма, огонь, бонусы «вечной игры», доска заказов.
func _test_ending() -> void:
	var sea: bool = args.get("ending", "sea") != "keeper"
	_check(Game.flags.get("ending_open_sea", false) == sea and Game.flags.get("ending_keeper", false) == (not sea), "выбран финал «%s»" % ("Открытое море" if sea else "Хранитель огня"))
	_check(Game.ended() and Game.unlocked.has("shop_lyova"), "после финала открыто торговое судно Лёвы")
	_check(str(Game.settings.get("endings", "")).contains("sea" if sea else "keeper"), "отметка о финале — в главном меню")
	_check(main.hud.credits != null and not main.hud.credits.visible, "показаны титры с портретами")
	var gf: GreatLighthouse.GreatFire = get_tree().get_first_node_in_group("great_fire")
	var es := _storm()
	if sea:
		_check(es.gone() and gf._state == "out", "шторм растворился, Великий огонь погас")
		_check(is_equal_approx(Game.sell_mult(), 1.5), "урожай дороже: пришли торговые корабли")
	else:
		_check(not es.gone() and gf._state == "gold", "шторм остался, огонь горит золотым")
		_check(Game.count("cloudberry_jam") >= 3, "в бутылке от Лёвы — варенье")
		var bed := _bed()
		Game.flags["bounty_day"] = Game.day
		_check(Game.bounty_today(), "Хранитель зажёг лучи: день щедрости")
		_give({"seed_carrot": 1})
		bed.plant("carrot")
		_advance([bed], Data.CROPS["carrot"]["time"] + 1.0)
		var before := Game.count("carrot")
		bed.interact(main.player)
		_check(Game.count("carrot") - before >= int(Data.CROPS["carrot"]["yield"][0]) * 2, "в день щедрости урожай вдвое больше")
		Game.flags["window_day"] = Game.day
		_check(Game.window_open(), "окно в шторме открыто — корабль Лёвы у причала дома")
	# доска заказов: три заказа на день, за выполненный — монеты
	var ids := OrderBoard.today()
	_check(ids.size() == 3, "на доске три заказа")
	var o: Array = OrderBoard.POOL[ids[0]]
	_give({o[1]: int(o[2])})
	var coins := Game.count("coins")
	var ok := OrderBoard.fulfil(ids[0])
	_check(ok and Game.count("coins") - coins == OrderBoard.reward(ids[0]) and OrderBoard.done(ids[0]), "заказ выполнен и оплачен")
	_check(not OrderBoard.fulfil(ids[0]), "один заказ — один раз")
	_flush()
	Game.delete_save()   # после титров игра сохранилась — следующему автотесту это не нужно


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
	var mesa: Node3D = _glacier()
	if mesa == null:
		mesa = _crater()
	var blocked := func(x: float, z: float) -> bool:
		if isl.height_at(x, z) < -0.9:
			return true
		if mesa and Vector2(x - mesa.global_position.x, z - mesa.global_position.z).length() < IceGlacier.WALL_R + 0.45:
			return true   # обрыв (ледник, кратер): снизу наверх не зайти
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
	var rot := 0.0
	if id == "stone_bridge":
		var sp := bs.free_spot(Vector3.ZERO, 9999.0)
		pos = sp.global_position
		rot = sp.rotation.y
	if id == "pumpkin_lantern":
		var sp2 := bs.free_spot(Vector3.ZERO, 9999.0, ["lantern_spot"])
		pos = sp2.global_position
	var b := bs.spawn_building(id, pos, rot, variant)
	if id in ["stone_bridge", "pumpkin_lantern"]:
		b._claim_spot()
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
			if t.get("radio", false):
				NPCPerson.quest_talk(target, true)   # в игре — клавиша T
				return
			if target == "stepa" and Game.location != "fort" and Game.current_quest().get("id", "") == "stepa_comes":
				# Стёпа в форте: в игре за ним плывут; здесь — как будто поговорили на берегу
				Game.bump("talk", "stepa")
				Game.flags["stepa_aboard"] = true
				return
			if target == "misha" and Game.location == "fog":
				Game.flags["trail_lit"] = _signal().lit_count() >= 5 or Game.flags.get("trail_lit", false)
				_check(Game.flags.get("trail_lit", false), "тропа к Мише освещена всеми пятью фонарями")
			if target == "parrot":
				main.parrot.interact(main.player)
			else:
				var found := false
				for n in get_tree().get_nodes_in_group("interactable"):
					if n is NPCPerson and n.npc_id == target:
						n.interact(main.player)
						found = true
						break
				if not found:
					# житель на другом острове: в игре туда плывут, здесь — как будто поговорили там
					NPCPerson.quest_talk(target)
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
			var tools := {"thicket": "machete", "bamboo": "machete", "jungle_tree": "stone_axe", "fallen_log": "stone_axe", "cliff": "pickaxe", "rock": "pickaxe", "liana_curtain": "machete",
				"crooked_tree": "stone_axe", "rockfall": "pickaxe", "ice_wall": "ice_pick", "pine": "stone_axe", "ice_block": "ice_pick",
				"basalt": "iron_pickaxe"}
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
			if target == "ice_chest":
				for c in get_tree().get_nodes_in_group("interactable"):
					if c is StoryPlace and c.id.begins_with("ice_chest") and Game.task_progress(t) < t["count"]:
						_give(c.PLACES[c.id]["brazier"])
						c.interact(main.player)          # поставить жаровню
						Game.world_time += float(c.PLACES[c.id]["melt"]) + 1.0
						c.interact(main.player)          # лёд растаял — открыть
						_flush()
				return
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
			if target == "ice_fish":
				for c in get_tree().get_nodes_in_group("interactable"):
					if c is FishingSpot and c.ice:
						spot = c
				if not spot.drilled():
					spot.interact(main.player)  # просверлить лунку
			for i in need:
				spot.interact(main.player)     # закинуть
				spot.state = FishingSpot.BITE  # поклёвка
				spot.interact(main.player)     # подсечь
		"solved":
			if target == "shadows":
				var sh := _shrine()
				for i in FogShrine.RIGHT:
					_give({"pumpkin_lantern": 1})
					Game.pay({"pumpkin_lantern": 1})
					var lb: Building = main.build.spawn_building("pumpkin_lantern", sh.spots[i].global_position, 0.0)
					lb._claim_spot()
				sh._process(0.0)
				return
			if target == "monolith":
				var tp := _temple()
				for c in tp.chutes:
					while c.dir != int(VolcanoTemple.TARGET[c.index]):
						c.interact(main.player)
				tp.pull_lever()
				return
			if target == "stars":
				var gl := _glacier()
				Game.time_of_day = 0.85      # ночь: звёзды видно
				_check(not Game.is_day(), "у телескопа ночь")
				for i in 3:
					while int(gl.dial.pos[i]) != int(IceGlacier.STARS_TARGET[i]):
						gl.dial.pos[i] = (int(gl.dial.pos[i]) + 1) % 6
				gl.dial.check()
				return
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
			if target == "firefly":
				var got := 0
				for c in get_tree().get_nodes_in_group("firefly"):
					if got < need and c.active:
						c.interact(main.player)
						got += 1
				return
			var n := 0
			for c in get_tree().get_nodes_in_group("interactable"):
				if c is Critters.Butterfly and n < need:
					c.interact(main.player)
					n += 1
		"sailed":
			if target == "albatros":
				_camp().ship.sail(false)
				return
			# прибытие на новый остров (в игре — после перезагрузки сцены)
			Game.arrive(target)
			Game.bump("sailed", "raft")
			Game.bump("sailed", target)
		"chose":
			for f in get_tree().get_nodes_in_group("great_fire"):
				var gf: GreatLighthouse.GreatFire = f
				_check(gf.get_hint().contains("выбор"), "у Великого огня можно сделать выбор")
				gf.choose("keeper" if args.get("ending", "sea") == "keeper" else "sea")
				_flush()
		"reached":
			if target.begins_with("eye_deck"):
				var gl := _tower()
				main.player.global_position = gl.deck_point(int(target.substr(8)) - 1)
				gl._process(0.0)
				return
			if target == "stilt_camp":
				var cp := _camp()
				main.player.global_position = cp.deck_point()
				cp._process(0.0)
				return
			if target == "temple_gate":
				var tp := _temple()
				_check(tp.bridged_count() == 3, "все три мостка лежат на местах")
				main.player.global_position = tp.global_position + tp.out * 1.5 + Vector3(0, 0.5, 0)
				tp._process(0.0)
				return
			if target == "crater_top":
				var cr := _crater()
				main.player.global_position = cr.top_point()
				cr._process(0.0)
				return
			if target == "glacier_top":
				var gl := _glacier()
				main.player.global_position = gl.top_point()
				gl._process(0.0)
				return
			if target.begins_with("bunker"):
				var stn := _station()
				main.player.global_position = stn.deck_point(target)
				stn._process(0.0)
				return
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
	_check(Game.save_path != Game.SAVE_PATH, "автотест пишет в своё сохранение и не трогает сохранение игрока")
	if Game.save_path == Game.SAVE_PATH:
		get_tree().quit(1)   # ни в коем случае не удалять настоящее сохранение
		return
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
		if not Island.RINGS.has(poi_id):
			continue   # без кольца преград (форт закрыт стенами, самолёт и камни — открыты)
		_check(not _reachable(poi_id), "к месту «%s» не пройти без инструментов" % poi_id)

	var ch := int(args.get("chapter", "1")) - 1
	if ch == 0:
		_validate()
		_test_quest_places()
		_test_palm()
		_test_unique()
		_test_mistakes()
		Game.start_current_quest()
		_flush()
	if ch == 1:
		_test_climb()
	if ch == 2 or (ch == 3 and Game.location == "fort"):
		_test_fort()
	if ch == 3 and Game.location == "storm":
		_test_storm()
		Game.storm_force = true   # молнии нужны для громоотвода и Башни громов
	if ch == 4 and Game.location == "ice":
		await _test_ice()
	if ch == 5 and Game.location == "volcano":
		_test_volcano()
	if ch == 6 and Game.location == "fog" and int(args.get("from", "0")) == 0:
		_test_fog()
	var endings_before := str(Game.settings.get("endings", ""))
	if ch == 7 and Game.location == "eye" and int(args.get("from", "0")) == 0:
		_test_eye()
	if ch > 0:
		# всё, что открыли предыдущие задания (рецепты, лавки, флаги), — как у игрока, дошедшего сюда
		var from_q := int(args.get("from", "0"))
		for ci in ch + 1:
			var cqs: Array = Data.CHAPTERS[ci]["quests"]
			for qi in cqs.size():
				if ci == ch and qi >= from_q:
					break
				var rw: Dictionary = cqs[qi].get("reward", {})
				Game._grant({"unlock": rw.get("unlock", []), "flags": rw.get("flags", []), "collect": rw.get("collect", {})})
				for t in cqs[qi]["tasks"]:
					if t["kind"] == "restored":
						Game.flags["restored_" + t["target"]] = true
					if t["kind"] == "lit" and StoryPlace.PLACES.has(t["target"]):
						Game.flags[StoryPlace.PLACES[t["target"]].get("flag", "lit_" + t["target"])] = true
		Game.chapter = ch
		Game.quest_index = from_q
		Game.quest_started = false
		Game.start_current_quest()
		_flush()
	var qs: Array = Data.CHAPTERS[ch]["quests"]
	var guard := 0
	var upto := int(args.get("upto", "999"))
	var done_q := 0
	while not Game.current_quest().is_empty() and Game.chapter == ch and guard < 60 and done_q < upto:
		done_q += 1
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
	if ch == 7 and Game.location == "eye" and done_ch:
		_test_ending()
		Game.settings["endings"] = endings_before   # отметку в меню автотест за игрока не ставит
		Game.save_settings()
	if ch == 6 and Game.location == "fog" and done_ch:
		_check(Game.flags.get("lit_fog_tower", false) and Game.flags.get("eye_route", false), "седьмой огонь горит, «Альбатрос» вышел, открыт путь к Оку")
		_check(Game.collection_complete("letters"), "все шесть писем команды собраны")
	if ch == 5 and Game.location == "volcano" and done_ch:
		_check(Game.flags.get("lit_volcano_tower", false) and Game.flags.get("fog_route", false), "Огонь кратера горит, открыт путь к Туманному острову")
		_check(Game.collection_complete("journal_volcano"), "все три записи с Вулкана собраны")
		_check(Game.count("crucible") >= 1 and Game.count("obsidian_lens") >= 1, "линза отлита, тигель остался в сумке")
	if ch == 4 and Game.location == "ice" and done_ch:
		_check(Game.flags.get("ice_thawed", false) and not Game.cold_active(), "Холодное сердце зажжено — на острове оттепель, холода больше нет")
		_check(Game.collection_complete("star_maps"), "все шесть листов звёздных карт собраны")
	if upto < 999:
		var target_i := int(args.get("from", "0")) + upto
		_check(Game.quest_index >= target_i or Game.chapter > ch, "пройдено %d заданий главы %d" % [upto, ch + 1])
		print("=== %s (%d ошибок) ===" % ["PASSED" if fails.is_empty() else "FAILED", fails.size()])
		get_tree().quit(0 if fails.is_empty() else 1)
		return
	_check(done_ch, "глава %d пройдена" % (ch + 1))
	print("      ₭ заработано продажей урожая по ходу главы: %d монет" % earned_by_selling)
	if ch + 1 < Data.CHAPTERS.size():
		var nq := Game.current_quest()
		_check(Game.chapter == ch + 1 and not nq.is_empty() and nq["id"] == Data.CHAPTERS[ch + 1]["quests"][0]["id"],
			"после главы %d сразу начинается глава %d («%s»)" % [ch + 1, ch + 2, nq.get("title", "—")])
	if ch > 0:
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
