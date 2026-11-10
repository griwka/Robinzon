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
	if args.has("walktest"):
		_walktest.call_deferred()
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
	if _frames == 30 and args.has("wheel"):   # для скриншотов: круг действий (--demo --wheel=pen|bed|seeds)
		var wm := str(args["wheel"])
		for b in get_tree().get_nodes_in_group("building"):
			if wm == "pen" and b is AnimalPen and b.id == "coop":
				Game.inventory["corn"] = 3
				b.fed = false
				b.product_ready = false
				b.wheel_request(p)
				break
			if wm == "bed" and b is GardenBed and b.crop != "" and b.stage() != 3:
				Game.inventory["watering_can"] = 1
				Game.inventory["fertilizer"] = 2
				b.watered = false
				b.wheel_request(p)
				break
			if wm == "seeds" and b is GardenBed:
				b.crop = ""
				b.progress = 0.0
				b._refresh()
				Game.inventory["seed_carrot"] = 3
				Game.inventory["seed_corn"] = 2
				Game.inventory["seed_tomato"] = 1
				b.wheel_request(p)
				break
	if _frames == 30 and args.has("panel"):   # для скриншотов: окно (--panel=build|craft|inv)
		Game.inventory["wood"] = 12
		Game.inventory["fiber"] = 3
		for bid in Data.BUILDINGS:
			Game.unlocked[bid] = true
		for r in Data.RECIPES:
			Game.unlocked[r["id"]] = true
		Game.inventory_changed.emit()
		match str(args["panel"]):
			"build": main.hud.open_build()
			"craft": main.hud.open_craft()
			"inv": main.hud.open_inventory()
	if _frames == 30 and args.has("farline"):   # для скриншотов: реплика жителя с другого острова
		main.hud.show_dialogue([[str(args["farline"]), "Суп готов. Возвращайся, пока не остыл."]], Callable())
	if _frames == 3 and args.has("toolrow"):   # для скриншотов: все инструменты в ряд (--toolrow --nohud)
		var ids := ["stone_axe", "iron_axe", "machete", "iron_machete", "pickaxe", "iron_pickaxe",
			"shovel", "watering_can", "net", "fishing_rod", "ice_pick", "ice_drill"]
		var base: Vector3 = main.island.camp_center + Vector3(0, 0, 0)
		base.y = main.island.height_at(base.x, base.z) + 2.6
		for i in ids.size():
			var m := Models.tool_model(ids[i])
			main.add_child(m)
			m.global_position = base + Vector3((i % 6 - 2.5) * 0.62, -(i / 6) * 1.45, 0)
			m.rotation = Vector3(0, -PI / 2 + 0.55, 0)
			m.scale = Vector3.ONE * 1.25
		p.global_position = base + Vector3(0, -2.2, 6.0)
		p.visible = false
		var cam := Camera3D.new()
		main.add_child(cam)
		cam.global_position = base + Vector3(0, -0.7, 4.3)
		cam.look_at(base + Vector3(0, -0.95, 0))
		cam.fov = 50
		cam.current = true
	if _frames == 5 and args.has("sat"):   # для скриншотов: сытость (--sat=35) и износ (--worn=machete:0.7,stone_axe:0.2)
		Game.hunger = float(args["sat"])
		Game._hunger_stage = Game.hunger_stage()
		main.hud.update_hunger()
	if _frames == 5 and args.has("worn"):
		for pr in str(args["worn"]).split(","):
			var kv := pr.split(":")
			if kv.size() == 2 and Game.WEAR.has(kv[0]):
				Game.wear[kv[0]] = int(float(kv[1]) * Game.WEAR[kv[0]])
		Game.wear_changed.emit()
	if _frames == 30 and args.has("pausemenu"):   # для скриншотов: меню паузы
		main._pause()
	if _frames == 4 and args.has("slots"):   # для скриншотов: список ячеек (--slots=load|new|save|pauseload)
		Game.use_slot(2)
		main._save()
		Game.use_slot(1)
		main._save()
		var mode := str(args["slots"])
		if mode == "save" or mode == "pauseload":
			main._pause()
			main.menu.open_slots("save" if mode == "save" else "load", main.menu.show_pause)
		else:
			main.menu.open_slots(mode, main.menu.show_main.bind(true))
	if args.has("climb") and _frames >= 3:   # для скриншотов: герой на лиане N на высоте h (--climb=1:0.5)
		var cp: PackedStringArray = str(args["climb"]).split(":")
		var lianas := get_tree().get_nodes_in_group("climb")
		var ci := clampi(int(cp[0]), 0, lianas.size() - 1)
		var cl: Climbable = lianas[ci]
		if _frames == 3:
			Game.inventory["climbing_gloves"] = 1
			p.global_position = cl.world_bottom() + Vector3(0.6, 0.2, 0)
			p._start_climb(cl)
		var b := cl.world_bottom()
		var tp := cl.world_top()
		var hy := lerpf(b.y, tp.y - 1.2, float(cp[1]) if cp.size() > 1 else 0.5)
		p.global_position.y = hy
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
	_check(Game.hold_slots().has("machete") and Game.hold_slots().has("stone_axe"), "новый инструмент сам занимает свободную ячейку внизу")
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
## Ячейки сохранения: игра пишется в выбранную ячейку, в списке видно главу и остров, ячейки не мешают друг другу.
func _test_slots() -> void:
	_check(Game.slot_path(1) == Game.save_path and Game.slot_path(1) != Game.SAVE_PATH, "автотест пишет в свою ячейку, не в ячейки игрока")
	_check(not Game.slot_path(3).begins_with("user://save_3"), "ячейки автотеста — отдельные файлы")
	Game.use_slot(3)
	main._save()
	var info := Game.slot_info(3)
	_check(info.has("chapter") and str(info["chapter"]).begins_with("Глава 1") and info.has("island") and info.has("when"),
		"в ячейке 3 видно главу, остров и время сохранения: %s" % str(info))
	_check(Game.slot_info(4).is_empty(), "соседняя ячейка пуста")
	Game.delete_slot(3)
	_check(not Game.slot_used(3), "ячейку можно очистить")
	Game.use_slot(1)
	_check(Game.save_path == Game.slot_path(1), "вернулись в первую ячейку")


## Голод: шкала тает, по ступеням — замедления; еда закрывает голод; никто не умирает и ничего не запирается.
func _test_hunger() -> void:
	var p: Player = main.player
	var inv: Dictionary = Game.inventory.duplicate()
	var was_on := Game.hunger_on
	var was_playing := Game.playing
	Game.hunger_on = true
	Game.playing = true
	Game.hunger = 100.0
	Game._hunger_stage = 0
	_check(Game.hunger_stage() == 0 and Game.hunger_regen() > 1.0 and Game.can_sprint(), "сытый: силы возвращаются быстрее")
	Game._tick_hunger(Game.HUNGER_TIME * 0.5)
	_check(absf(Game.hunger - 50.0) < 0.5 and Game.hunger_stage() == 2, "за половину срока сытость падает вдвое (%.0f) — «проголодался»" % Game.hunger)
	_check(Game.hunger_regen() < 1.0 and Game.hunger_speed() == 1.0, "проголодался: силы медленнее, ходьба как обычно")
	Game.hunger = 30.0
	_check(Game.hunger_stage() == 3 and Game.hunger_speed() < 1.0 and Game.can_sprint(), "голоден: идёшь медленнее, бежать ещё можно")
	Game.hunger = 5.0
	_check(Game.hunger_stage() == 4 and not Game.can_sprint() and Game.hunger_speed() >= 0.7, "очень голоден: не бежишь, но идёшь")
	Game.hunger = 0.0
	Game._tick_hunger(600.0)
	_check(Game.hunger == 0.0, "ниже нуля голод не падает — герой не умирает")
	# подъём с пустым желудком всё равно возможен: на уступе силы копятся
	_check(maxf(0.5, Game.hunger_regen()) * 14.0 > 2.5 * 1.3, "даже очень голодным на уступе стены можно отдышаться")
	# еда
	Game.inventory = {"banana": 1, "fish_soup": 1, "carrot": 2}
	Game.hunger = 85.0
	var got := Game.eat_best_food()
	_check(got > 0 and got <= 15 and Game.count("fish_soup") == 1, "почти сыт — съедает малое (%d), похлёбку бережёт" % got)
	Game.hunger = 10.0
	var st0 := p.stamina
	p.stamina = 10.0
	Game.eat_best_food()
	_check(Game.count("fish_soup") == 0 and Game.hunger > 50.0 and p.stamina > 10.0, "очень голоден — съедает похлёбку, сытость и силы растут")
	Game.hunger = 70.0
	Game.sleep_until_morning()
	_check(absf(Game.hunger - 55.0) < 0.5, "за ночь сна проголодался (−15)")
	Game.hunger = 100.0
	Game._hunger_stage = 0
	Game.hunger_on = was_on
	Game.playing = was_playing
	p.stamina = st0
	Game.inventory = inv
	Game.inventory_changed.emit()


## Прибой выносит железо на сухой песок, ничего не вырастает на постройке, грядку можно убрать.
func _test_tide_and_spots() -> void:
	var p: Player = main.player
	var inv: Dictionary = Game.inventory.duplicate()
	var isl: Island = main.island
	var tide := get_tree().get_first_node_in_group("tide_scrap") as TideScrap
	_check(tide != null, "на острове крушения волны выносят обломки (TideScrap)")
	if tide:
		var piles: Array = []
		for c in tide.holder.get_children():
			if c is ResourceNode and (c as ResourceNode).washed and (c as ResourceNode).active:
				piles.append(c)
		_check(piles.size() >= 1 and piles.size() <= TideScrap.MAX, "с начала на берегу лежат обломки (%d)" % piles.size())
		var on_sand := true
		for c in piles:
			var h := isl.height_at((c as Node3D).global_position.x, (c as Node3D).global_position.z)
			if h < TideScrap.SAND_LO or h > TideScrap.SAND_HI:
				on_sand = false
		_check(on_sand, "обломки лежат на сухом песке — не в траве и не в воде")
		var n0 := tide.count()
		for i in 6:
			tide.wash_ashore(false)
		await get_tree().process_frame
		_check(tide.count() <= TideScrap.MAX + 6 and TideScrap.INTERVAL >= 180.0, "волна приходит не чаще раза в %d с, на берегу не больше %d сразу" % [int(TideScrap.INTERVAL), TideScrap.MAX])
		# на постройку обломки не попадают
		var spot := tide.find_spot()
		if spot != Vector3.INF:
			var bed0: Building = main.build.spawn_building("garden_bed", spot, 0.0)
			_check(not tide.spot_ok(spot), "там, где грядка, волна обломков не оставит")
			bed0.queue_free()
		# разобрали — исчезает и на том же месте не появляется
		if not piles.is_empty():
			var pile: ResourceNode = piles[0]
			var at := pile.global_position
			pile._deplete()
			await get_tree().create_timer(0.6).timeout
			_check(not is_instance_valid(pile), "разобранная кучка исчезла и на этом месте больше не появится")
			var back := false
			for c in tide.holder.get_children():
				if c is ResourceNode and (c as ResourceNode).washed and (c as Node3D).global_position.distance_to(at) < 0.3:
					back = true
			_check(not back, "на месте разобранной кучки пусто")
		# лишние кучки этой проверки — убрать
		for c in tide.holder.get_children():
			if c is ResourceNode and (c as ResourceNode).washed and tide.holder.get_children().find(c) >= 0 and tide.count() > n0:
				c.queue_free()
	# куст разобрали, на его месте поставили грядку — куст там больше не вырастет
	var bush: ResourceNode = null
	for n in get_tree().get_nodes_in_group("interactable"):
		if n is ResourceNode and n.kind == "bush" and n.active:
			bush = n
			break
	if bush:
		var layer := bush.collision_layer
		bush._deplete()
		var bed: Building = main.build.spawn_building("garden_bed", bush.global_position, 0.0)
		bush._respawn(layer)
		_check(not bush.active, "на грядке, поставленной на месте куста, куст не вырастает")
		bed.queue_free()
		await get_tree().process_frame
		var keep := p.global_position
		p.global_position = bush.global_position + Vector3(20, 0, 20)
		bush._respawn(layer)
		_check(bush.active, "грядку убрали — куст снова растёт на своём месте")
		p.global_position = keep
	# грядку можно убрать: доски и волокно вернутся, посаженное — семенами
	Game.inventory = {"seed_carrot": 1}
	var bed2 := main.build.spawn_building("garden_bed", isl.camp_center + Vector3(26, 0, 22), 0.0) as GardenBed
	bed2.plant("carrot")
	var opts := bed2.wheel_options(p)
	_check(not opts.is_empty() and str(opts[opts.size() - 1]["text"]) == "Убрать", "в круге у грядки есть «Убрать»")
	bed2.remove_bed()
	var cost: Dictionary = Data.BUILDINGS["garden_bed"]["cost"]
	var refunded := true
	for id in cost:
		if Game.count(id) < int(cost[id]):
			refunded = false
	_check(refunded and Game.count("seed_carrot") == 1 and bed2.is_queued_for_deletion(), "грядка убрана: материалы и семечко вернулись")
	Game.inventory = inv
	Game.inventory_changed.emit()


## Износ инструментов, железные топор и мачете.
func _test_wear() -> void:
	var p: Player = main.player
	var inv: Dictionary = Game.inventory.duplicate()
	var held0 := Game.held
	Game.inventory = {"stone_axe": 1}
	Game.wear = {}
	Game.bar = []
	_check(Game.tool_hp("stone_axe") == 1.0, "новый топор — полная прочность")
	Game.use_tool("stone_axe")
	_check(Game.wear.get("stone_axe", 0) == 1 and Game.tool_hp("stone_axe") < 1.0, "удар изнашивает топор")
	Game.wear["stone_axe"] = Game.WEAR["stone_axe"] - 1
	Game.hold("stone_axe")
	Game.use_tool("stone_axe")
	_check(Game.count("stone_axe") == 0 and Game.held_tool() == "" and not Game.wear.has("stone_axe"), "топор сломался — пропал из сумки и из руки")
	var axe_r := {}
	for r in Data.RECIPES:
		if r["out"].has("stone_axe"):
			axe_r = r
	_give(axe_r["in"])
	var had_unlock := Game.unlocked.has("stone_axe")
	Game.unlocked["stone_axe"] = true   # раз топор был — рецепт открыт
	_check(Game.craft(axe_r) and Game.count("stone_axe") == 1 and Game.tool_hp("stone_axe") == 1.0, "сломанный топор делается заново по тому же рецепту")
	if not had_unlock:
		Game.unlocked.erase("stone_axe")
	# железный топор: рубит всё, что каменный, вдвое сильнее и втрое дольше
	Game.inventory["iron_axe"] = 1
	_check(Game.has_tool("stone_axe") and Game.tool_for("stone_axe") == "iron_axe" and Game.tool_power("iron_axe") == 2,
		"железный топор заменяет каменный и бьёт вдвое сильнее")
	_check(Game.WEAR["iron_axe"] > Game.WEAR["stone_axe"] * 2, "железный топор живёт дольше каменного")
	_check(not Game.hold_slots().has("stone_axe") and Game.hold_slots().has("iron_axe"), "при железном каменный топор не занимает ячейку внизу")
	var tree: ResourceNode = null
	for n in get_tree().get_nodes_in_group("interactable"):
		if n is ResourceNode and n.kind == "jungle_tree" and n.active:
			tree = n
			break
	if tree:
		var hp0 := tree.hp
		var w0: int = Game.wear.get("iron_axe", 0)
		Game.hold("iron_axe")
		tree.interact(p)
		_check(tree.hp == hp0 - 2 and Game.wear.get("iron_axe", 0) == w0 + 1, "удар железным топором: −2 дереву, износ железного")
		tree.hp = hp0
	var palm: ResourceNode = null
	for n in get_tree().get_nodes_in_group("interactable"):
		if n is ResourceNode and n.kind == "palm" and n.active:
			palm = n
			break
	if palm:
		var php := palm.hp
		Game.hold("iron_axe")
		palm.interact(p)
		_check(palm.hp == php - 2, "железным топором пальму рубят (не трясут)")
		palm.hp = php
	_check(Game.has_tool("machete") == false, "мачете без мачете нет")
	Game.inventory["iron_machete"] = 1
	_check(Game.has_tool("machete") and Game.tool_for("machete") == "iron_machete", "железное мачете заменяет простое")
	_check(Game.WEAR.has("pickaxe") and not Game.WEAR.has("watering_can") and not Game.WEAR.has("net"), "ломаются рабочие инструменты (не лейка и не сачок)")
	Game.inventory = inv
	Game.wear = {}
	Game.bar = []
	Game.held = held0
	Game.inventory_changed.emit()


## Правки по списку от игрока: трава без стены, круг действий, четыре ячейки, реплики издалека.
func _test_friend_list() -> void:
	var p: Player = main.player
	var inv: Dictionary = Game.inventory.duplicate()
	var held0 := Game.held
	var pos0 := p.global_position
	# 1. густая трава: не стена, но замедляет
	var grass: ResourceNode = null
	for n in get_tree().get_nodes_in_group("interactable"):
		if n is ResourceNode and n.kind == "tall_grass" and n.active:
			grass = n
			break
	_check(grass != null and grass.collision_layer == 8, "густая трава — не стена (сквозь неё проходят)")
	if grass:
		p.global_position = grass.global_position + Vector3(0, 0.2, 0)
		p._find_target()
		_check(p.in_grass, "в густой траве герой идёт медленнее")
		p.global_position = main.island.spawn_point
		p._find_target()
		_check(not p.in_grass, "на чистом месте — обычная скорость")
	# 5. круг действий у грядки и загона
	var got := []
	var on_wheel := func(title: String, info: String, options: Array): got.append([title, info, options])
	Game.wheel_requested.connect(on_wheel)
	var c: Vector3 = main.island.camp_center
	var bed := main.build.spawn_building("garden_bed", c + Vector3(30, 0, 30), 0.0) as GardenBed
	Game.inventory = {"seed_carrot": 2, "seed_corn": 1}
	_check(bed.wheel_request(p) and got.size() == 1 and got[0][2].size() == 3 and str(got[0][2][2]["text"]) == "Убрать",
		"пустая грядка: круг с семенами на выбор и «Убрать»")
	if not got.is_empty():
		(got[0][2][0]["callback"] as Callable).call()
	_check(bed.crop != "", "выбор в круге сажает семена (%s)" % bed.crop)
	got.clear()
	Game.inventory["watering_can"] = 1
	_check(not bed.wheel_request(p) and got.is_empty(), "дело одно (полить) — круга нет, оно делается сразу")
	bed.interact(p)
	_check(bed.watered, "грядка полита")
	Game.inventory["fertilizer"] = 1
	_check(bed.wheel_request(p) and got.size() == 1 and not got[0][2][0].get("enabled", true) and got[0][2][1].get("enabled", true),
		"полито, есть удобрение: в круге «полить» погашено, «удобрить» доступно")
	if not got.is_empty():
		(got[0][2][1]["callback"] as Callable).call()
	_check(bed.fertilized and Game.count("fertilizer") == 0, "выбор в круге удобряет грядку")
	got.clear()
	var coop := main.build.spawn_building("coop", c + Vector3(34, 0, 30), 0.0) as AnimalPen
	Game.inventory["corn"] = 3
	_check(coop.wheel_request(p) and got.size() == 1 and got[0][2].size() == 2 and str(got[0][2][0]["text"]) == "Покормить"
		and str(got[0][2][1]["text"]) == "Погладить", "курятник: круг «покормить / погладить»")
	if not got.is_empty():
		(got[0][2][0]["callback"] as Callable).call()
	_check(coop.fed, "выбор в круге кормит кур")
	got.clear()
	Game.inventory.erase("corn")
	coop.fed = false
	coop.wheel_request(p)
	_check(got.size() == 1 and not got[0][2][0].get("enabled", true), "корма нет: «покормить» погашено, видно, сколько нужно (%s)" % (str(got[0][2][0]["note"]) if not got.is_empty() else "—"))
	Game.wheel_requested.disconnect(on_wheel)
	for a in coop.animals:
		if is_instance_valid(a):
			a.queue_free()
	coop.queue_free()
	bed.queue_free()
	# 6. четыре ячейки инструментов
	Game.inventory = {"machete": 1, "stone_axe": 1, "pickaxe": 1, "shovel": 1, "fishing_rod": 1, "net": 1}
	Game.bar = []
	Game._bar_recent = []
	Game.held = ""
	_check(Game.hold_slots().size() == Game.BAR_SIZE, "внизу четыре ячейки инструментов, остальные — в сумке")
	var out := ""
	for id in ["machete", "stone_axe", "pickaxe", "shovel", "fishing_rod", "net"]:
		if not Game.bar.has(id):
			out = id
			break
	Game.hold(Game.bar[1])
	Game.hold(Game.bar[2])
	Game.hold(Game.bar[3])
	var oldest: String = Game.bar[0]
	Game.hold(out)
	_check(Game.held_tool() == out and Game.bar.has(out) and not Game.bar.has(oldest) and Game.bar.size() == Game.BAR_SIZE,
		"инструмент из сумки занимает ячейку того, которым дольше всех не пользовались")
	# 11. реплики издалека
	_check(main.hud.speaker_far("marta") and not main.hud.speaker_far("parrot") and not main.hud.speaker_far("narrator"),
		"Марта на другом острове — её слова приходят издалека; Румба и рассказчик — рядом")
	Game.inventory = inv
	Game.bar = []
	Game._bar_recent = []
	Game.held = held0
	p.global_position = pos0
	Game.inventory_changed.emit()


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


# ------------------------------------------------------------------ Прохождение ногами
## Пройти героем к точке по-настоящему: нажата «вперёд», камера развёрнута к цели, работает физика.
## Заросли на пути (их в игре вырубают инструментом) убираем; застрять можно только на рельефе и стенах.
## Возвращает "" — дошёл, иначе — где застрял.
func _walk_to(goal: Vector3, max_t := 40.0, near := 1.6, honest := false) -> String:
	var p: Player = main.player
	p.controls_enabled = true
	var t := 0.0
	var last := p.global_position
	var still := 0.0
	var blocked := ""
	var best_d := INF
	var best_t := 0.0
	while t < max_t:
		var d := Vector3(goal.x - p.global_position.x, 0, goal.z - p.global_position.z)
		if d.length() < near:
			Input.action_release("move_forward")
			Input.action_release("move_left")
			Input.action_release("move_right")
			return ""
		if d.length() < best_d - 0.3:
			best_d = d.length()
			best_t = t
		elif honest and t - best_t > 5.0:
			Input.action_release("move_forward")
			Input.action_release("move_left")
			Input.action_release("move_right")
			return "топчется на месте у %s (высота земли %.1f, до точки %.1f м%s)" % [str(p.global_position.snapped(Vector3.ONE * 0.1)),
				main.island.height_at(p.global_position.x, p.global_position.z), d.length(), "" if blocked == "" else "; путь закрыт: " + blocked]
		p.camera_yaw = atan2(-d.x, -d.z)
		Input.action_press("move_forward")
		await get_tree().physics_frame
		var dt := get_physics_process_delta_time()
		t += dt
		if p.global_position.distance_to(last) < 0.6 * dt:
			still += dt
		else:
			still = 0.0
		last = p.global_position
		if still > 0.6:
			# упёрлись: если это заросли или камень — в игре их расчищают; убираем ближайшие
			var cleared := false
			for n in get_tree().get_nodes_in_group("obstacle"):
				if n is ResourceNode and n.active and (n as Node3D).global_position.distance_to(p.global_position) < 2.6:
					var tool: String = ResourceNode.KINDS[n.kind]["tool"]
					if honest and tool != "" and not Game.has_tool(tool):
						if not _kit_ok(tool):
							blocked = "%s — нужен %s, а его ещё нельзя сделать" % [n.kind, Game.item_name(tool)]
							continue   # без инструмента не прорубиться — как в игре
					n._deplete()
					cleared = true
			if honest and not cleared:
				# как игрок: упёрся — подпрыгнуть, потом шагнуть вбок
				if still > 0.6 and still < 0.6 + dt * 1.5:
					Input.action_press("jump")
					await get_tree().physics_frame
					Input.action_release("jump")
				if still > 1.2 and still < 1.8:
					Input.action_press("move_left" if int(t) % 2 == 0 else "move_right")
				else:
					Input.action_release("move_left")
					Input.action_release("move_right")
			if not cleared and still > 2.5:
				Input.action_release("move_forward")
				Input.action_release("move_left")
				Input.action_release("move_right")
				return "застрял в %s (высота земли %.1f, до цели %.1f м%s)" % [str(p.global_position.snapped(Vector3.ONE * 0.1)),
					main.island.height_at(p.global_position.x, p.global_position.z), d.length(), "" if blocked == "" else "; путь закрыт: " + blocked]
	Input.action_release("move_forward")
	return "не дошёл за %d с, остановился в %s" % [int(max_t), str(p.global_position.snapped(Vector3.ONE * 0.1))]


## Тесты пишут в своё сохранение (save_dev.json); пока герой долго идёт ногами, игра успевает сделать автосохранение.
## Стираем его при выходе, иначе следующий тест начнёт с того места, где закончил этот.
func _exit_tree() -> void:
	if (args.has("autotest") or args.has("walktest")) and Game.save_path != Game.SAVE_PATH:
		Game.delete_save()


# ------------------------------------------------------------------ Автотест ногами (--autotest --walk)
var walk_mode := false
var _nav_ready := false
var _nav_region: NavigationRegion3D
var walk_stats := {"ok": 0, "fail": 0, "skip": 0, "climbs": 0, "drops": 0}


## Навигационная сетка острова: рельеф, постройки, стены, деревья. Преграды, которые расчищают инструментом
## (заросли, завалы), в сетку не входят — путь идёт сквозь них, а прорубаем их по дороге, если есть чем.
func _nav_bake() -> void:
	var nm := NavigationMesh.new()
	nm.cell_size = 0.25
	nm.cell_height = 0.1
	nm.agent_radius = 0.5   # с запасом к радиусу героя (0.3), кратно клетке; дорожки у храма — отдельным маршрутом
	nm.agent_height = 1.6
	nm.agent_max_climb = 0.4
	nm.agent_max_slope = 44.0
	nm.region_min_size = 4.0
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = 1 | 2 | 4
	var hidden: Array = []
	for n in get_tree().get_nodes_in_group("obstacle"):
		if n is ResourceNode and n.active and n.is_obstacle() and n.collision_layer != 0:
			hidden.append([n, n.collision_layer])
			n.collision_layer = 0
	# выключенные стенки (место под мосток, когда мосток стоит; открытые ворота) сетка иначе считает стенами
	var off_shapes: Array = []
	for cs in main.find_children("*", "CollisionShape3D", true, false):
		if (cs as CollisionShape3D).disabled and (cs as CollisionShape3D).shape:
			off_shapes.append([cs, (cs as CollisionShape3D).shape])
			(cs as CollisionShape3D).shape = null
	var src := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nm, src, main)
	for h in hidden:
		h[0].collision_layer = h[1]
	for o in off_shapes:
		o[0].shape = o[1]
	NavigationServer3D.bake_from_source_geometry_data(nm, src)
	var map: RID = (main as Node3D).get_world_3d().navigation_map
	NavigationServer3D.map_set_cell_size(map, nm.cell_size)
	NavigationServer3D.map_set_cell_height(map, nm.cell_height)
	if _nav_region:
		_nav_region.queue_free()   # пересборка: постройки и открытые проходы меняют остров
	var reg := NavigationRegion3D.new()
	reg.navigation_mesh = nm
	main.add_child(reg)
	_nav_region = reg
	# сетка подключается к карте не сразу: ждём, пока по ней начнёт строиться путь
	for i in 120:
		await get_tree().physics_frame
		if i > 3 and NavigationServer3D.map_get_iteration_id(map) > 0 				and not NavigationServer3D.map_get_path(map, main.player.global_position, main.island.camp_center, true).is_empty():
			break
	_nav_ready = true
	print("      навигационная сетка: %d многоугольников" % nm.get_polygon_count())


## Дойти ногами по сетке. "" — дошёл.
func _game_dist(a: Vector3, b: Vector3) -> float:
	var to := b - a
	if absf(to.y) > 3.0:
		return INF
	to.y *= 0.5
	return to.length()


func _nav_walk(goal: Vector3, near := 2.0) -> String:
	var p: Player = main.player
	var map: RID = (main as Node3D).get_world_3d().navigation_map
	var path := NavigationServer3D.map_get_path(map, p.global_position, goal, true)
	if path.is_empty():
		return "нет пути"
	var end: Vector3 = path[path.size() - 1]
	var end_miss := _game_dist(end + Vector3(0, 0.9, 0), goal)
	if end_miss > near + 3.0:
		return "путь обрывается в %.1f м от цели (в %s)" % [Vector3(end - goal).length(), str(end.snapped(Vector3.ONE * 0.1))]
	for i in range(1, path.size()):
		var last := i == path.size() - 1
		var why := await _walk_to(path[i], 30.0, 0.55 if not last else 0.6, true)
		if why != "":
			if _game_dist(p.global_position + Vector3(0, 0.9, 0), goal) <= near:
				return ""   # уже дотягиваемся — дальше идти не нужно
			return why
		if _game_dist(p.global_position + Vector3(0, 0.9, 0), goal) <= near * 0.8:
			return ""
	# сетка кончилась чуть раньше цели (склон, край стены): последние метры — напрямую, как игрок
	if _game_dist(p.global_position + Vector3(0, 0.9, 0), goal) > near:
		await _walk_to(goal, 6.0, 0.5, true)
	var miss := _game_dist(p.global_position + Vector3(0, 0.9, 0), goal)
	if miss > near:
		return "не дотянуться: остановился в %.1f м от цели (в %s)" % [miss, str(p.global_position.snapped(Vector3.ONE * 0.1))]
	return ""


## Маршрут через ручьи лавы к двери храма (Вулкан): снаружи — по мосткам и по узким дорожкам между ручьями.
## Первая точка — снаружи, последняя — у двери. Навигационная сетка эти дорожки (0,5 м) не видит, а герой проходит.
func _temple_lanes() -> Array:
	var tp := _temple()
	var c := tp.global_position
	var a_out := atan2(tp.out.z, tp.out.x)
	var at := func(r: float, da: float) -> Vector3:
		var v := c + Vector3(cos(a_out + da), 0, sin(a_out + da)) * r
		v.y = main.island.height_at(v.x, v.z)
		return v
	var ch: Array = VolcanoTemple.CHANNELS
	var cur_a: float = ch[ch.size() - 1][1]
	var pts: Array = [at.call(float(ch[ch.size() - 1][0]) + 2.4, cur_a)]
	for k in range(ch.size() - 1, -1, -1):
		var r: float = ch[k][0]
		var a: float = ch[k][1]
		var lane: float = r + 1.0   # по дорожке между ручьями — до места мостка
		var n := int(ceil(absf(a - cur_a) / 0.12))
		for j in range(1, n + 1):
			pts.append(at.call(lane, lerpf(cur_a, a, float(j) / n)))
		pts.append(at.call(r + 1.0, a))
		pts.append(at.call(r - 1.0, a))   # через мосток
		cur_a = a
	pts.append(c + tp.out * 1.5)
	return pts


## Внутри колец лавы у храма?
func _in_temple_rings(q: Vector3) -> bool:
	var tp := _temple()
	if tp == null:
		return false
	var ch: Array = VolcanoTemple.CHANNELS
	if absf(q.y - main.island.height_at(tp.global_position.x, tp.global_position.z)) > 3.0:
		return false   # выше или ниже храма (гребень кратера) — это не внутри колец
	return Vector2(q.x - tp.global_position.x, q.z - tp.global_position.z).length() < float(ch[ch.size() - 1][0]) + 0.8


## Добраться до точки: пешком; не выходит — спрыгнуть вниз или залезть по лиане/стене, которая туда выводит.
func _reach(goal: Vector3, depth := 0, near := 2.0) -> String:
	var p: Player = main.player
	if _temple() and _in_temple_rings(goal) != _in_temple_rings(p.global_position) and depth < 12:
		var lanes := _temple_lanes()
		if not _in_temple_rings(goal):
			lanes.reverse()   # изнутри — наружу
		else:
			var w0 := await _reach(lanes[0], depth + 1, 1.2)
			if w0 != "":
				return "к мосткам у храма не дойти: " + w0
		for i in range(1, lanes.size()):
			var wl := await _walk_to(lanes[i], 15.0, 0.45, true)
			var lp: Vector3 = lanes[i]
			if wl != "" and Vector2(lp.x - p.global_position.x, lp.z - p.global_position.z).length() > 1.2:
				return "по мосткам у храма не пройти (точка %d): %s" % [i, wl]
		if _in_temple_rings(goal) and _game_dist(p.global_position + Vector3(0, 0.9, 0), goal) <= near:
			return ""
		return await _reach(goal, depth + 1, near)
	var why := await _nav_walk(goal, near)
	if why == "" or depth >= 12:
		return why
	# сетка грубая (ступеньки, подвал, узкие проходы): пробуем просто идти прямо к цели, как игрок
	if absf(p.global_position.y - goal.y) < 3.0:
		var dw2 := await _walk_to(goal, 25.0, near * 0.8, true)
		if dw2 == "" or _game_dist(p.global_position + Vector3(0, 0.9, 0), goal) <= near:
			return ""
	# люк бункера (Грозовой): вниз и наверх — через люк, как в игре (E)
	var below := goal.y < -8.0
	if below != (p.global_position.y < -8.0):
		for h in get_tree().get_nodes_in_group("interactable"):
			if h is StormStation.Hatch and h.down == below:
				var hw := await _reach(h.interact_point(), depth + 1, 2.3)
				if hw != "":
					return "к люку не дойти: " + hw
				h.interact(p)
				for i in 20:
					await get_tree().physics_frame
				return await _reach(goal, depth + 1, near)
	if p.global_position.y > goal.y + 2.0:
		var dw := await _climb_down(goal)
		if dw != "":
			dw = await _jump_down(goal)
		if dw != "":
			return why + "; спуститься не вышло: " + dw
		return await _reach(goal, depth + 1, near)
	var best: Climbable = null
	var bd := INF
	for c in get_tree().get_nodes_in_group("climb"):
		var e: Vector3 = c.world_exit()
		var dd := e.distance_to(goal)
		if dd < 14.0 and absf(e.y - goal.y) < 2.5 and dd < bd:
			best = c
			bd = dd
	if best == null:
		return why
	# к низу подъёма — так близко, чтобы ухватиться (в игре — 1.35 м по горизонтали)
	var w := await _reach(best.world_bottom() + Vector3(0, 0.9, 0), depth + 1, 1.25)
	if w != "":
		# точно как в игре: дотянулись ли до подъёма (подсказка «лезть»)
		await _walk_to(best.world_bottom(), 4.0, 0.9, true)
		p._find_climb()
		if not (p.near_climb == best and not p.near_climb_down):
			return "к низу подъёма не дойти: " + w
	var cw := await _climb_up(best)
	if cw != "":
		return cw
	return await _reach(goal, depth + 1, near)


## Инструмент «с собой»: глава в тесте начинается с пустой сумкой, а игрок к этому времени его уже сделал.
## Рецепт открыт — выдаём (true); ещё закрыт — инструмента у игрока быть не может (false).
func _kit_ok(tool: String) -> bool:
	if Game.has_tool(tool):
		return true
	for r in Data.RECIPES:
		if r["out"].has(tool) and Game.recipe_unlocked(r):
			_give({tool: 1})
			return true
	return false


## На морозе (Ледяной до оттепели) — как игрок: тёплая одежда, если её уже можно сделать, и погреться у огня.
func _warm_up(need := 60.0) -> void:
	if not Game.cold_active():
		return
	for c in ["down_jacket", "sweater", "felt_boots", "mittens"]:
		_kit_ok(c)
	if Game.warmth >= need:
		return
	var wm := get_tree().get_first_node_in_group("warmth") as Warmth
	if wm == null:
		return
	var p: Player = main.player
	var f := wm.nearest_fire(p.global_position)
	if f == Vector3.INF:
		return
	await _nav_walk(f, 2.0)
	var t := 0.0
	while Game.warmth < 95.0 and t < 12.0:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()


## Перед подъёмом отдышаться, как игрок: постоять, пока силы не вернутся (на земле — быстро).
func _rest() -> void:
	var p: Player = main.player
	var t := 0.0
	while p.stamina < Player.STAMINA_MAX * 0.8 and t < 8.0:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()


## Залезть: встать у низа, нажать Пробел, держать «вверх» до самого верха.
func _climb_up(c: Climbable) -> String:
	var p: Player = main.player
	var b := c.world_bottom()
	await _walk_to(b, 6.0, 0.9, true)
	await get_tree().physics_frame
	if p.near_climb != c:
		return "у низа подъёма (%s) нельзя ухватиться" % str(b.snapped(Vector3.ONE * 0.1))
	# снаряжение: глава в тесте начинается с пустой сумкой, а игрок к этому времени уже сделал нужное.
	# Если рецепт открыт — вещь «с собой»; если ещё нет — это настоящая ошибка сюжета
	var kit: Array[String] = []
	if not c.ladder:
		kit.append("climbing_gloves")
	if c.ice:
		kit.append("ice_pick")
	for tool in kit:
		if not Game.has_tool(tool) and not _kit_ok(tool):
			return "для подъёма нужен «%s», а его ещё нельзя сделать" % Game.item_name(tool)
	if Game.cold_active() and Game.warmth < 80.0:
		await _warm_up(80.0)
		await _reach(b + Vector3(0, 0.9, 0), 6, 1.25)   # от огня — обратно к подъёму
		await _walk_to(b, 4.0, 0.9, true)
	await _rest()
	await get_tree().physics_frame
	if p.near_climb != c or p.near_climb_down:
		return "отошёл от подъёма и не вернулся (у %s)" % str(p.global_position.snapped(Vector3.ONE * 0.1))
	Input.action_press("jump")
	await get_tree().physics_frame
	Input.action_release("jump")
	await get_tree().physics_frame
	if p.climbing != c:
		var why := c.locked_hint
		if why == "" and not c.ladder and Game.storm_active():
			why = "гроза — лазать нельзя"
		elif why == "" and Game.frozen():
			why = "герой замёрз"
		elif why == "" and p.stamina < 10.0:
			why = "нет сил"
		elif why == "" and c.ice and not (Game.has_tool("ice_pick") and Game.has_tool("climbing_gloves")):
			why = "нет ледоруба или перчаток"
		elif why == "":
			why = "near=%s down=%s силы=%d тепло=%d" % [str(p.near_climb == c), str(p.near_climb_down), int(p.stamina), int(Game.warmth)]
		return "не начать подъём: %s" % (why if why != "" else "непонятно почему")
	var t := 0.0
	Input.action_press("move_forward")
	while p.climbing == c and t < 60.0:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		# на уступе можно повисеть: устали — отдыхаем, как игрок
		if c.rest_step > 0.0 and p.stamina < Player.STAMINA_MAX * 0.25 and c.at_rest(p.global_position.y - b.y):
			Input.action_release("move_forward")
			while p.stamina < Player.STAMINA_MAX * 0.9 and p.climbing == c:
				await get_tree().physics_frame
			Input.action_press("move_forward")
	Input.action_release("move_forward")
	if p.climbing == c:
		return "подъём не кончился за минуту"
	if p.global_position.y < c.world_top().y - 1.5:
		return "сорвался с подъёма на высоте %.1f м" % (p.global_position.y - b.y)
	walk_stats["climbs"] += 1
	return ""


## Спуститься по подъёму сверху (лиана, стена, лестница): дойти до места схода, Пробел, держать S до низа.
func _climb_down(goal: Vector3) -> String:
	var p: Player = main.player
	var y0 := p.global_position.y
	var best: Climbable = null
	var bd := INF
	for c in get_tree().get_nodes_in_group("climb"):
		var e: Vector3 = c.world_exit()
		if absf(e.y - y0) > 1.5 or c.world_bottom().y > y0 - 2.0:
			continue
		var dd: float = Vector2(e.x - p.global_position.x, e.z - p.global_position.z).length() + c.world_bottom().distance_to(goal) * 0.3
		if dd < bd:
			bd = dd
			best = c
	if best == null:
		return "сверху нет подъёма вниз"
	await _nav_walk(best.world_exit(), 0.5)
	await get_tree().physics_frame
	if not (p.near_climb == best and p.near_climb_down):
		return "у верха подъёма не ухватиться"
	if not best.ladder and not _kit_ok("climbing_gloves"):
		return "для спуска нужны перчатки, а их ещё нельзя сделать"
	if best.ice and not _kit_ok("ice_pick"):
		return "для спуска нужен ледоруб, а его ещё нельзя сделать"
	if Game.frozen():
		return "герой замёрз наверху"
	await _rest()
	Input.action_press("jump")
	await get_tree().physics_frame
	Input.action_release("jump")
	await get_tree().physics_frame
	if p.climbing != best:
		return "спуск не начался"
	var t := 0.0
	Input.action_press("move_back")
	while p.climbing == best and t < 60.0:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	Input.action_release("move_back")
	if p.global_position.y > y0 - 1.5:
		return "спуск не довёл вниз"
	walk_stats["climbs"] += 1
	return ""


## Спуститься с высоты: идти к цели с прыжками, пока не окажемся ниже; не вышло — пробуем другие стороны.
func _jump_down(goal: Vector3) -> String:
	var p: Player = main.player
	var y0 := p.global_position.y
	# сначала — проём у верха лестницы или лианы (в бункере спрыгивают именно там)
	for c in get_tree().get_nodes_in_group("climb"):
		var e: Vector3 = c.world_exit()
		var tb: Vector3 = c.world_bottom()
		if absf(e.y - y0) < 1.5 and Vector2(e.x - p.global_position.x, e.z - p.global_position.z).length() < 14.0 and tb.y < y0 - 2.0:
			await _nav_walk(e, 1.0)
			var dv := Vector3(tb.x - e.x, 0, tb.z - e.z)
			if dv.length() < 0.1:
				continue
			p.camera_yaw = atan2(-dv.x, -dv.z)
			var t0 := 0.0
			Input.action_press("move_forward")
			while t0 < 3.0 and not (p.global_position.y < y0 - 1.5 and p.is_on_floor()):
				await get_tree().physics_frame
				t0 += get_physics_process_delta_time()
			Input.action_release("move_forward")
			if p.global_position.y < y0 - 1.5:
				walk_stats["drops"] += 1
				return ""
	var dirs: Array = [goal - p.global_position]
	for k in 8:
		dirs.append(Vector3(cos(k * PI / 4), 0, sin(k * PI / 4)))
	for d in dirs:
		var dv: Vector3 = d
		dv.y = 0.0
		if dv.length() < 0.01:
			continue
		var t := 0.0
		p.camera_yaw = atan2(-dv.x, -dv.z)
		Input.action_press("move_forward")
		while t < 3.0:
			if int(t * 4.0) % 4 == 0:
				Input.action_press("jump")
			else:
				Input.action_release("jump")
			await get_tree().physics_frame
			t += get_physics_process_delta_time()
			if p.global_position.y < y0 - 1.5 and p.is_on_floor():
				break
		Input.action_release("move_forward")
		Input.action_release("jump")
		if p.global_position.y < y0 - 1.5:
			walk_stats["drops"] += 1
			return ""
	return "со всех сторон перила или стены (высота %.1f)" % y0


## Куда идти для пункта задания (Vector3.INF — цели на этом острове нет или ходить не нужно).
func _task_goal(t: Dictionary) -> Vector3:
	var target: String = t["target"]
	var p: Player = main.player
	match t["kind"]:
		"talk", "delivered":
			if t.get("radio", false):
				return Vector3.INF
			var who: String = t.get("to", "marta") if t["kind"] == "delivered" else target
			if who == "parrot" and main.parrot:
				return main.parrot.global_position
			for n in get_tree().get_nodes_in_group("interactable"):
				if n is NPCPerson and n.npc_id == who:
					return n.interact_point()
		"collected", "found", "lit", "restored":
			var best := Vector3.INF
			for c in get_tree().get_nodes_in_group("interactable"):
				var ok: bool = (target == "crate" and c is SupplyCrate) or (c is StoryPlace and (c.id == target or (target == "ice_chest" and c.id.begins_with("ice_chest"))))
				if ok and (c as Node3D).global_position.distance_to(p.global_position) < best.distance_to(p.global_position):
					best = c.interact_point()
			return best
		"cleared":
			var best := Vector3.INF
			for c in get_tree().get_nodes_in_group("interactable"):
				if c is ResourceNode and c.kind == target and c.active \
						and (c as Node3D).global_position.distance_to(p.global_position) < best.distance_to(p.global_position):
					best = c.interact_point()
			return best
		"fished":
			for c in get_tree().get_nodes_in_group("interactable"):
				if c is FishingSpot and (c.ice == (target == "ice_fish")):
					return (c as Node3D).global_position
		"solved":
			match target:
				"shadows": return _shrine().global_position if _shrine() else Vector3.INF
				"monolith": return _temple().global_position if _temple() else Vector3.INF
				"stars": return _glacier().dial.global_position if _glacier() else Vector3.INF
				_:
					var f := _fort()
					if f and not f.levers.is_empty():
						return (f.levers[0] as Node3D).global_position
		"reached":
			if target.begins_with("eye_deck"):
				return _tower().deck_point(int(target.substr(8)) - 1) if _tower() else Vector3.INF
			match target:
				"stilt_camp": return _camp().deck_point() if _camp() else Vector3.INF
				"temple_gate": return _temple().global_position + _temple().out * 1.5 if _temple() else Vector3.INF
				"crater_top": return _crater().top_point() if _crater() else Vector3.INF
				"glacier_top": return _glacier().top_point() if _glacier() else Vector3.INF
			if target.begins_with("bunker"):
				return _station().deck_point(target) if _station() else Vector3.INF
			for n in get_tree().get_nodes_in_group("obstacle"):
				if n is BanyanTree and target.begins_with("deck"):
					return n.to_global(n._deck_center(int(target.substr(4)) - 1))
	return Vector3.INF


## Перед пунктом задания — дойти до цели ногами. Не вышло — ошибка, а героя переносим, чтобы проверить остальное.
func _walk_for_task(t: Dictionary) -> void:
	if not _nav_ready:
		await _nav_bake()
	var goal := _task_goal(t)
	if goal == Vector3.INF:
		walk_stats["skip"] += 1
		return
	var p: Player = main.player
	# дотянуться, как в игре: до места — 3.6 м, до большой преграды — 3.4, до жителя и ящика — 2.6
	var near := 2.0
	match t["kind"]:
		"found", "lit", "restored":
			near = 3.3 if t["target"] != "crate" else 2.3
		"talk", "delivered", "collected", "fished":
			near = 2.3
		"cleared":
			near = 3.1 if ResourceNode.KINDS.has(t["target"]) and t["target"] in ["rock", "jungle_tree", "cliff", "fallen_log", "thicket", "bamboo", "crooked_tree", "rockfall", "ice_wall", "pine", "basalt"] else 2.3
	if _game_dist(p.global_position + Vector3(0, 0.9, 0), goal) <= near:
		walk_stats["ok"] += 1
		return
	var from := p.global_position
	var why := await _reach(goal, 0, near)
	if why != "":
		# по ходу главы построили мостки, открыли ворота, расчистили проходы — пересобираем сетку и пробуем ещё раз
		await _nav_bake()
		why = await _reach(goal, 0, near)
	_check(why == "", "ногами: %s → «%s» (%s %s)%s" % [str(from.snapped(Vector3.ONE)), t["text"], t["kind"], t["target"],
		"" if why == "" else " — " + why])
	walk_stats["ok" if why == "" else "fail"] += 1
	if why != "":
		p.global_position = goal + Vector3(0, 0.6, 0)
		p.velocity = Vector3.ZERO
		for i in 5:
			await get_tree().physics_frame


## Маршрут ногами: из одной точки через несколько — без телепортов. Печатает и проверяет каждый отрезок.
func _walk_route(name_: String, start: Vector3, points: Array) -> void:
	var p: Player = main.player
	p.global_position = start + Vector3(0, 0.6, 0)
	p.velocity = Vector3.ZERO
	for i in 10:
		await get_tree().physics_frame
	for i in points.size():
		var why := await _walk_to(points[i])
		_check(why == "", "%s: отрезок %d из %d%s" % [name_, i + 1, points.size(), "" if why == "" else " — " + why])
		if why != "":
			return


func _walktest() -> void:
	print("=== WALKTEST ===")
	if Game.save_path == Game.SAVE_PATH:
		get_tree().quit(1)   # ни в коем случае не трогать сохранение игрока
		return
	Game.delete_save()
	await get_tree().process_frame
	_flush()
	var isl: Island = main.island
	var camp := isl.camp_center
	# у причала стоит лодка (дома — обломки «Чайки»): идём не в неё, а к берегу перед ней
	var dock := isl.wreck_point + (camp - isl.wreck_point).normalized() * 3.0
	Game.location = isl.loc   # старое тестовое сохранение могло подменить остров — верим тому, что построено
	match isl.loc:
		"fort":
			var f := _fort()
			Game.flags["poi_fort_gate"] = true
			f.open_gate(false)
			var yard := f.global_position
			var gate_in := f.global_position + f.gate_dir * (FortRuin.R - 2.5)
			var gate_out := f.global_position + f.gate_dir * (FortRuin.R + 3.0)
			var cellar := f.global_position - f.side_dir * 4.0
			await _walk_route("из двора форта к причалу", yard, [gate_in, gate_out, camp, dock])
			await _walk_route("от причала в форт и в подвал", dock, [camp, gate_out, gate_in, yard, cellar])
			await _walk_route("из подвала обратно к воротам", cellar, [yard, gate_in, gate_out])
		"storm":
			# бункер под землёй и ниже уровня моря: на каждом ярусе герой стоит на полу, а не «всплывает»
			var stn := _station()
			Game.flags["restored_generator"] = true
			for k in range(1, StormStation.DECKS + 1):
				var dp := stn.deck_point("bunker%d" % k)
				var p: Player = main.player
				p.global_position = dp
				p.velocity = Vector3.ZERO
				for i in 90:
					await get_tree().physics_frame
				var dy := p.global_position.y - dp.y
				_check(absf(dy) < 0.8 and not p.in_water(), "ярус %d бункера (высота %.1f): герой стоит на полу (сдвиг %.2f м)" % [k, dp.y, dy])
			await _walk_route("от причала к лагерю и обратно", dock, [camp, dock])
		"volcano":
			# к двери храма — по трём мосткам над ручьями лавы и по дорожкам между ручьями
			var tp := _temple()
			_give({"iron_pickaxe": 1})   # к храму идут уже с железной киркой (базальт вокруг)
			for sp in tp.spots:
				var bb: Building = main.build.spawn_building("stone_bridge", sp.global_position, sp.rotation.y)
				bb._claim_spot()
			for i in 5:
				await get_tree().physics_frame
			var pts := _temple_lanes()
			var start: Vector3 = pts.pop_front()
			var p: Player = main.player
			p.global_position = start + Vector3(0, 0.6, 0)
			p.velocity = Vector3.ZERO
			for i in 10:
				await get_tree().physics_frame
			for i in pts.size():
				var why := await _walk_to(pts[i], 15.0, 0.45, true)
				if why != "":
					_check(false, "к храму по мосткам: точка %d из %d — %s" % [i + 1, pts.size(), why])
					break
				if i == pts.size() - 1:
					_check(true, "к двери храма по трём мосткам — дошёл ногами")
			await _walk_route("от причала к лагерю и обратно", dock, [camp, dock])
		_:
			await _walk_route("от причала к лагерю и обратно", dock, [camp, dock])
	# прыгнул в воду на глубине — должен выплыть к берегу (раньше на глубине стояла «невидимая стена»)
	for turn in [1.3, -1.3]:
		var out := Vector3(dock.x, 0, dock.z).normalized().rotated(Vector3.UP, turn)
		var deep := Vector3.INF
		for k in 80:
			var q := out * (isl.radius * 0.5 + k)
			if isl.height_at(q.x, q.z) < -1.8:
				deep = q
				break
		if deep == Vector3.INF:
			continue
		# ближайший берег по пути назад к острову
		var shore := deep
		while shore.length() > 1.0 and isl.height_at(shore.x, shore.z) < 0.4:
			shore -= out * 0.5
		shore -= out * 1.5
		deep.y = -1.4
		await _walk_route("из глубокой воды к берегу (%.1f)" % turn, deep, [Vector3(shore.x, 0, shore.z)])
	if args.has("scan"):
		# из разных мест острова — к лагерю: находим ямы и тупики, откуда не выбраться ногами
		var g := RandomNumberGenerator.new()
		g.seed = 4321
		var n := int(args["scan"])
		var tried := 0
		while tried < n:
			var a := g.randf() * TAU
			var r := g.randf_range(4.0, isl.radius * 1.05)
			var q := Vector3(cos(a) * r, 0, sin(a) * r)
			q.y = isl.height_at(q.x, q.z)
			if q.y < 0.3:
				continue
			tried += 1
			await _walk_route("из точки %s к лагерю" % str(q.snapped(Vector3.ONE)), q, [camp])
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
	# и обратно: у верха (там, где сошли) — Пробел, и спускаемся по той же лиане до земли
	p.global_position = c.world_exit()
	p._find_climb()
	_check(p.near_climb == c and p.near_climb_down and p.get_hint().contains("Спуститься"), "у верха лианы можно спуститься: «%s»" % p.get_hint())
	p.stamina = Player.STAMINA_MAX
	p._start_climb_down(c)
	Input.action_press("move_back")
	steps = 0
	while p.climbing and steps < 1200:
		p._physics_process(1.0 / 60.0)
		steps += 1
	Input.action_release("move_back")
	_check(p.climbing == null and p.global_position.y < b.y + 0.6, "спуск по лиане доводит до земли (высота %.1f м)" % (p.global_position.y - b.y))
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
						if tools.has(target) and not Game.has_tool(tools[target]):
							_give({tools[target]: 1})   # сломался — игрок сделал бы новый по тому же рецепту
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
				if args.has("debugshadows"):
					var st := []
					for k in sh.spots.size():
						st.append("%d:%s" % [k, sh.spots[k].used])
					print("      метки у камней: ", " ".join(st), "  нужно: ", FogShrine.RIGHT, "  решено: ", sh.solved())
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
	walk_mode = args.has("walk")
	print("=== AUTOTEST%s ===" % (" НОГАМИ" if walk_mode else ""))
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
		_test_friend_list()
		_test_hunger()
		_test_wear()
		await _test_tide_and_spots()
		_test_slots()
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
				if walk_mode:
					await _walk_for_task(t)
					_flush()
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
