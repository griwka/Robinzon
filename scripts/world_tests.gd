class_name WorldTests
extends RefCounted
## Автотест «живого мира»: находки с моря, камни со знаками и тайник, редкие существа и слухи.
## Зовётся из CozyTests.run (после финала главы 8 и в --autotest --cozyonly). Пишет только в сохранение тестов.


static func _ok(dev: Node, cond: bool, what: String) -> void:
	dev.call("_check", cond, what)


static func run(dev: Node) -> void:
	print("--- живой мир ---")
	var saved_inv: Dictionary = Game.inventory.duplicate()
	var saved_flags: Dictionary = Game.flags.duplicate(true)
	var saved_unl: Dictionary = Game.unlocked.duplicate()
	var saved_stats: Dictionary = Game.stats.duplicate(true)
	var saved_cols: Dictionary = Game.collections.duplicate(true)
	var saved_day := Game.day
	var saved_time := Game.time_of_day
	_all(dev)
	dev.call("_flush")
	Game.inventory = saved_inv
	Game.flags = saved_flags
	Game.unlocked = saved_unl
	Game.stats = saved_stats
	Game.collections = saved_cols
	Game.day = saved_day
	Game.time_of_day = saved_time
	Game.inventory_changed.emit()


static func _all(dev: Node) -> void:
	var main: Node = dev.get("main")
	var hud: HUD = main.get("hud")
	var isl: Island = main.get("island")
	var pl: Node3D = main.get("player")
	var wl := dev.get_tree().get_first_node_in_group("world_life") as WorldLife
	_ok(dev, wl != null and wl.drift != null and wl.runes != null and wl.rare != null, "живой мир запущен на острове")
	if wl == null or wl.drift == null:
		return
	Game.collections.erase("sea_bottles")
	Game.collections.erase("sea_glass")
	Game.collections.erase("signs")
	Game.collections.erase("rare_life")
	for k in Game.flags.keys():
		if str(k).begins_with("rune_") or str(k).begins_with("col_sea") or str(k) in ["col_signs", "col_rare_life"]:
			Game.flags.erase(k)
	Game.unlocked.erase("sign_stone")
	Game.inventory = {}

	# ---- находки с моря
	if wl.drift.enabled():
		for f in dev.get_tree().get_nodes_in_group("drift_find"):
			(f as Node).remove_from_group("drift_find")
			(f as Node).queue_free()
		var b := wl.drift.wash_ashore(false, "bottle")
		_ok(dev, b != null and b.is_in_group("interactable"), "волна вынесла бутылку на песок")
		if b != null:
			var h := isl.height_at(b.global_position.x, b.global_position.z)
			_ok(dev, h >= SeaDrift.SAND_LO and h <= SeaDrift.SAND_HI, "находка лежит на сухом песке у воды (высота %.2f)" % h)
			_ok(dev, b.take() == "bottle_1" and WorldLife.has("sea_bottles", "bottle_1"), "в бутылке — первая записка, она в коллекции")
			dev.call("_flush")
		var notes := 1
		for i in 5:
			var nb := wl.drift.wash_ashore(false, "bottle")
			if nb != null and nb.take().begins_with("bottle_"):
				notes += 1
			dev.call("_flush")
		_ok(dev, notes == 6 and Game.collection_complete("sea_bottles") and Game.flags.get("col_sea_bottles", false),
			"шесть бутылок — шесть разных записок, коллекция собрана")
		var extra := wl.drift.wash_ashore(false, "bottle")
		_ok(dev, extra != null and extra.take() == "glass", "седьмая бутылка пустая — достаётся стекло, а не повтор")
		var g := wl.drift.wash_ashore(false, "glass")
		_ok(dev, g != null and g.take() == "sea_glass" and not (Game.collections.get("sea_glass", {}) as Dictionary).is_empty(), "морское стекло идёт в свою коллекцию")
		var pod := wl.drift.wash_ashore(false, "pod")
		var got_seed := pod.take() if pod != null else ""
		_ok(dev, got_seed in SeaDrift.POD_SEEDS and Game.count(got_seed) == 1, "в стручке — семена (%s)" % got_seed)
		var fl := wl.drift.wash_ashore(false, "float")
		_ok(dev, fl != null and fl.take() == "rope" and Game.count("rope") == 1, "с поплавка — обрывок верёвки")
		_ok(dev, Game.count("coins") == 0, "море не приносит монет")
		var seen := {}
		for i in 200:
			seen[SeaDrift.pick_kind(i / 200.0)] = true
		_ok(dev, seen.size() == SeaDrift.KINDS.size(), "волны приносят все четыре вида находок")
	else:
		print("      (на Оке шторма море ничего не приносит)")

	# ---- камни со знаками и тайник
	var loc := Game.location
	if loc in RuneStones.ISLANDS:
		var rs := wl.runes
		_ok(dev, rs.stones.size() == 3 and rs.center != Vector3.INF, "на острове три камня со знаками")
		if rs.stones.size() == 3:
			var on_land := true
			var facing := true
			for s in rs.stones:
				if isl.height_at(s.global_position.x, s.global_position.z) < 0.8:
					on_land = false
				var to := rs.center - s.global_position
				to.y = 0.0
				var fwd := s.global_transform.basis.z
				fwd.y = 0.0
				if to.normalized().dot(fwd.normalized()) < 0.98:
					facing = false
			_ok(dev, on_land, "камни стоят на суше")
			_ok(dev, facing, "стрелки всех трёх камней смотрят в одну точку")
			_ok(dev, rs.center.distance_to(isl.camp_center) > 12.0, "тайник не в лагере (от костра %.0f м)" % rs.center.distance_to(isl.camp_center))
			var again := RuneStones.find_spots(isl)
			_ok(dev, again.size() == 4 and (again[0] as Vector3).distance_to(rs.center) < 0.01, "места камней одни и те же при каждой загрузке")
			_ok(dev, rs.cache == null and not rs.dig(), "пока не найдены все три — тайника не видно и копать нечего")
			rs.stones[0].interact(pl)
			rs.stones[1].interact(pl)
			dev.call("_flush")
			_ok(dev, RuneStones.found_count(loc) == 2 and rs.cache == null, "два камня — ещё рано")
			rs.stones[2].interact(pl)
			dev.call("_flush")
			_ok(dev, rs.cache != null and rs.cache.is_in_group("interactable"), "третий камень — на месте тайника просела земля")
			_ok(dev, not rs.dig() and not RuneStones.cache_open(loc), "без лопаты тайник не выкопать (и ничего не теряется)")
			Game.inventory = {"shovel": 1}
			rs.cache.interact(pl)
			dev.call("_flush")
			var loot: Dictionary = RuneStones.LOOT[loc]
			var all_loot := true
			for id in loot:
				if Game.count(id) < int(loot[id]):
					all_loot = false
			_ok(dev, RuneStones.cache_open(loc) and all_loot and Game.count("coins") == 0, "лопатой тайник выкопан: внутри вещи, монет нет")
			_ok(dev, WorldLife.has("signs", "sign_" + loc), "знак острова — в коллекции «Знаки строителей»")
			_ok(dev, not rs.dig() and rs.cache == null, "тайник один: второй раз копать нечего")
		for l in RuneStones.ISLANDS:
			WorldLife.collect("signs", "sign_" + l)
			dev.call("_flush")
		_ok(dev, Game.collection_complete("signs") and Game.unlocked.has("sign_stone"), "все семь знаков открывают украшение «Камень со знаками»")
	else:
		print("      (на этом острове камней со знаками нет)")
	Game.unlocked.erase("sign_stone")
	Game.flags["ending_keeper"] = true
	CozyLife.migrate()
	_ok(dev, not Game.unlocked.has("sign_stone"), "«Камень со знаками» не открывается сам после финала — только за знаки")

	# ---- редкие существа
	Game.collections.erase("rare_life")
	var rare := wl.rare
	_ok(dev, RareLife.rumor("stepa").size() == 2 and RareLife.rumor("gosha").is_empty(), "о редких существах рассказывают жители (слух Стёпы про лунную рыбу)")
	# лунная рыба: ночью в полнолуние
	Game.day = 1
	Game.time_of_day = 0.95
	while not RareLife.full_moon():
		Game.day += 1
	_ok(dev, RareLife.on_catch(false, 0.0) and RareLife.met("moon_fish"), "ночью в полнолуние на удочку попалась лунная рыба")
	dev.call("_flush")
	Game.time_of_day = 0.5
	_ok(dev, not RareLife.on_catch(false, 0.0), "днём лунная рыба не клюёт")
	Game.time_of_day = 0.95
	Game.day += int(WorldEnv.MOON_CYCLE / 2.0)
	_ok(dev, not RareLife.on_catch(false, 0.0), "в новолуние — тоже")
	_ok(dev, RareLife.rumor("stepa").is_empty(), "встретил — слух больше не пересказывают")
	# белая бабочка: днём после дождя, сачком
	if rare.moth != null:
		Game.time_of_day = 0.5
		rare._rain_until = -1.0
		_ok(dev, not rare.moth_time(), "без дождя белой бабочки нет")
		rare._rain_until = Game.world_time + 60.0
		rare.moth.set_shown(rare.moth_time())
		_ok(dev, rare.moth.shown and rare.moth.is_in_group("interactable"), "после дождя над поляной летает белая бабочка")
		Game.inventory = {}
		rare.moth.interact(pl)
		_ok(dev, not RareLife.met("snow_moth"), "без сачка её не поймать")
		Game.inventory = {"net": 1}
		rare.moth.interact(pl)
		dev.call("_flush")
		_ok(dev, RareLife.met("snow_moth"), "сачком — поймал, рассмотрел и отпустил")
		rare.moth.set_shown(false)
	# пугливые: шагом — можно, бегом — прячутся
	var shy := RareLife.Shy.new()
	var sp: Vector3 = isl.camp_center + Vector3(6, 0, 0)
	sp.y = isl.height_at(sp.x, sp.z)
	shy.setup("glow_crab", isl, sp)
	rare.add_child(shy)
	shy.set_shown(true)
	_ok(dev, shy.shown and shy.is_in_group("interactable"), "светящийся краб вышел на берег")
	shy.scare()
	_ok(dev, not shy.shown and not shy.is_in_group("interactable"), "подбежал — краб зарылся в песок")
	shy.set_shown(true)
	_ok(dev, not shy.shown, "и сразу не выходит")
	shy.hidden_until = 0.0
	shy.set_shown(true)
	shy.interact(pl)
	dev.call("_flush")
	_ok(dev, RareLife.met("glow_crab"), "подошёл шагом — рассмотрел светящегося краба")
	shy.free()
	if Game.location == "home":
		Game.time_of_day = 0.28
		_ok(dev, RareLife.turtle_time() and rare.turtle != null, "на рассвете на берег выходит морская черепаха")
		rare.turtle.hidden_until = 0.0
		rare.turtle.set_shown(true)
		var th := isl.height_at(rare.turtle.home.x, rare.turtle.home.z)
		_ok(dev, rare.turtle.shown and th > 0.2 and th < 0.9, "черепаха — на песке у воды (высота %.2f)" % th)
		rare.turtle.interact(pl)
		dev.call("_flush")
		_ok(dev, RareLife.met("sea_turtle"), "черепаху можно рассмотреть вблизи")
		rare.turtle.set_shown(false)
		# золотой жук: в полдень на клумбе
		Game.time_of_day = 0.5
		rare.beetle.host = null
		for b in dev.get_tree().get_nodes_in_group("building"):
			if str(b.get("id")) in RareLife.FLOWERS:
				(b as Node).remove_from_group("building")
				(b as Node).queue_free()
		rare.beetle.update(RareLife.beetle_time())
		_ok(dev, not rare.beetle.shown, "нет клумб — жуку негде сидеть")
		var bs: BuildSystem = main.get("build")
		var fp: Vector3 = isl.camp_center + Vector3(-5, 0, 3)
		fp.y = isl.height_at(fp.x, fp.z)
		var bed := bs.spawn_building("flowerbed", fp, 0.0)
		rare.beetle.update(RareLife.beetle_time())
		_ok(dev, rare.beetle.shown and rare.beetle.global_position.distance_to(bed.global_position) < 1.0, "в полдень золотой жук сидит на клумбе")
		Game.inventory = {"net": 1}
		rare.beetle.interact(pl)
		dev.call("_flush")
		_ok(dev, RareLife.met("gold_beetle"), "золотой жук пойман сачком")
		rare.beetle.update(false)
		bed.remove_from_group("building")
		bed.queue_free()
		_ok(dev, Game.collection_complete("rare_life") and Game.flags.get("col_rare_life", false) and Game.count("coins") == 0,
			"все пять встреч — коллекция собрана, награда вещами")
	# окно коллекций показывает новое
	hud.open_collections()
	var texts: Array[String] = []
	for l in hud._body(hud.col_panel).find_children("*", "Label", true, false):
		texts.append((l as Label).text)
	var joined := "\n".join(texts)
	_ok(dev, joined.contains("Письма из бутылок") and joined.contains("Знаки строителей") and joined.contains("Редкие встречи") and joined.contains("Морское стекло"),
		"новые коллекции видны в окне коллекций")
	hud.close_all()


# ------------------------------------------------------------------ Снимки
## --open=runes — герой у камней со знаками (все найдены, тайник виден), в консоль — где они стоят на этом острове;
## --open=drift — на песке лежат все четыре находки; --open=turtle — рассвет, черепаха на берегу;
## --open=worldcols — окно коллекций с новыми коллекциями.
static func shot(dev: Node, what: String) -> void:
	var main: Node = dev.get("main")
	var hud: HUD = main.get("hud")
	var isl: Island = main.get("island")
	var pl: Player = main.get("player")
	dev.call("_flush")
	var wl := dev.get_tree().get_first_node_in_group("world_life") as WorldLife
	if wl == null or wl.runes == null:
		print("WORLD %s: живой мир не запущен" % Game.location)
		return
	match what:
		"runes":
			var rs := wl.runes
			print("RUNES %s: камней %d, тайник %s, до лагеря %.0f м" % [Game.location, rs.stones.size(), str(rs.center.snapped(Vector3.ONE * 0.1)),
				rs.center.distance_to(isl.camp_center) if rs.center != Vector3.INF else -1.0])
			if rs.stones.size() < 3:
				return
			for o in dev.get_tree().get_nodes_in_group("obstacle"):
				if o is ResourceNode and (o as Node3D).global_position.distance_to(rs.center) < 13.0:
					o.queue_free()      # для снимка: расчищаем вокруг, чтобы камни было видно
			for i in 3:
				Game.flags[RuneStones.flag(Game.location, i)] = true
			rs._refresh_cache()
			var s0: Vector3 = rs.stones[0].global_position
			var out := (rs.center - s0).normalized()
			pl.global_position = rs.center + out * 1.6 + Vector3(0, 0.4, 0)
			pl.camera_yaw = atan2(out.x, out.z)
			pl.camera_pitch = -0.95      # сверху: видно все три камня и бугорок между ними
			pl.camera_distance = 14.0
		"drift":
			var base := Vector3.INF
			for f in dev.get_tree().get_nodes_in_group("drift_find"):
				(f as Node).queue_free()
			var first := wl.drift.wash_ashore(false, "bottle")
			if first == null:
				return
			base = first.global_position
			var k := 0
			for kind in ["glass", "float", "pod"]:
				k += 1
				var f := SeaDrift.DriftFind.new()
				f.kind = kind
				var side := Vector3(-base.z, 0, base.x).normalized()
				var p := base + side * (k * 1.3)
				p.y = isl.height_at(p.x, p.z)
				f.position = p
				isl.add_child(f)
			var up := Vector3(-base.x, 0, -base.z).normalized()
			pl.global_position = base + up * 1.5 + Vector3(-base.z, 0, base.x).normalized() * 2.0 + Vector3(0, 0.5, 0)
			pl.camera_yaw = atan2(up.x, up.z)
			pl.camera_pitch = -1.0
			pl.camera_distance = 6.0
		"turtle":
			if wl.rare.turtle == null:
				return
			var t := wl.rare.turtle
			t.hidden_until = 0.0
			t.set_shown(true)
			var up2 := Vector3(-t.home.x, 0, -t.home.z).normalized()
			pl.global_position = t.home + up2 * 2.2 + Vector3(0, 0.5, 0)
			pl.camera_yaw = atan2(up2.x, up2.z)
			pl.camera_pitch = -0.8
			pl.camera_distance = 6.0
		"worldcols":
			Game.collections["sea_bottles"] = {"bottle_1": 1, "bottle_2": 1, "bottle_3": 1}
			Game.collections["sea_glass"] = {"glass_green": 2, "glass_white": 1, "glass_blue": 1}
			Game.collections["signs"] = {"sign_home": 1, "sign_banyan": 1, "sign_storm": 1, "sign_fog": 1}
			Game.collections["rare_life"] = {"snow_moth": 1, "sea_turtle": 1, "moon_fish": 1}
			hud.open_collections()
