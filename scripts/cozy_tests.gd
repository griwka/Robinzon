class_name CozyTests
extends RefCounted
## Автотест кулинарии и уюта («вечная игра»). Зовётся из dev_tools.gd: после финала главы 8 (_test_ending)
## и отдельно, быстро: --autotest --cozyonly. Пишет только в сохранение тестов (save_dev*.json).


static func _ok(dev: Node, cond: bool, what: String) -> void:
	dev.call("_check", cond, what)


static func run(dev: Node) -> void:
	print("--- кулинария и уют ---")
	var saved_inv: Dictionary = Game.inventory.duplicate()
	var saved_flags: Dictionary = Game.flags.duplicate(true)
	var saved_unl: Dictionary = Game.unlocked.duplicate()
	var saved_stats: Dictionary = Game.stats.duplicate(true)
	var saved_hunger := Game.hunger
	_cooking(dev)
	_cozy(dev)
	Game.inventory = saved_inv
	Game.flags = saved_flags
	Game.unlocked = saved_unl
	Game.stats = saved_stats
	Game.hunger = saved_hunger
	Game.inventory_changed.emit()


static func _cooking(dev: Node) -> void:
	var main: Node = dev.get("main")
	var hud: HUD = main.get("hud")
	# до финала котелка нет, после — есть (и в старом сохранении тоже: миграция)
	var was_sea: bool = Game.flags.get("ending_open_sea", false)
	var was_keeper: bool = Game.flags.get("ending_keeper", false)
	Game.flags.erase("ending_open_sea")
	Game.flags.erase("ending_keeper")
	Game.unlocked.erase("cook_pot")
	CozyLife.migrate()
	_ok(dev, not Game.unlocked.has("cook_pot"), "до финала котелок закрыт")
	Game.flags["ending_keeper"] = true
	CozyLife.migrate()
	_ok(dev, Game.unlocked.has("cook_pot"), "после финала котелок открыт (в старом сохранении — миграцией)")
	Game.flags.erase("ending_keeper")
	if was_sea:
		Game.flags["ending_open_sea"] = true
	if was_keeper or not was_sea:
		Game.flags["ending_keeper"] = true

	# данные: у каждого рецепта своё блюдо, свой набор, продукты настоящие
	var bad: Array[String] = []
	var seen := {}
	for r in Cooking.RECIPES:
		var id: String = r["id"]
		var it: Dictionary = Data.ITEMS.get(id, {})
		if it.get("cat", "") != "food" or not it.has("food") or not Data.SELL_PRICES.has(id):
			bad.append(id + ": нет предмета, сытости или цены")
		var n := Cooking.units(r["in"])
		if n < Cooking.MIN_UNITS or n > Cooking.MAX_UNITS:
			bad.append(id + ": продуктов не 2–4")
		var keys: Array = r["in"].keys()
		keys.sort()
		var sig := ""
		for k in keys:
			sig += "%s%d," % [k, int(r["in"][k])]
			if not Cooking.is_ingredient(k):
				bad.append("%s: %s нельзя положить в котелок" % [id, k])
		if seen.has(sig):
			bad.append("%s и %s: один и тот же набор" % [id, seen[sig]])
		seen[sig] = id
	for c in Cooking.classic_recipes():
		var ck: Array = c["in"].keys()
		ck.sort()
		var csig := ""
		for k in ck:
			csig += "%s%d," % [k, int(c["in"][k])]
		if seen.has(csig):
			bad.append("%s совпадает с обычным рецептом %s" % [seen[csig], c["id"]])
	_ok(dev, bad.is_empty(), "рецепты котелка: %d штук, наборы не повторяются (%s)" % [Cooking.RECIPES.size(), "; ".join(bad)])

	# котелок — постройка, у него открывается окно
	var pot: Building = dev.call("_build", "cook_pot")
	_ok(dev, pot is CookPot and pot.is_in_group("interactable"), "котелок построен, к нему можно подойти")
	pot.interact(main.get("player"))
	var cl := dev.get_tree().get_first_node_in_group("cozy_life") as CozyLife
	_ok(dev, cl != null and cl.cook_ui != null and cl.cook_ui.panel.visible, "у котелка открывается окно готовки")

	# проба: совпало — блюдо и запись в книгу
	Game.flags.erase("cookbook")
	Game.flags.erase("buffs")
	Game.inventory = {"potato": 3, "carrot": 3, "tomato": 3, "coconut": 2, "fish": 4, "banana": 2}
	_ok(dev, not Cooking.known("veg_stew") and Cooking.known_count() == 0, "книга пустая: рецепты ещё не найдены")
	cl.cook_ui.put("potato")
	cl.cook_ui.put("carrot")
	cl.cook_ui.put("tomato")
	cl.cook_ui.boil()
	_ok(dev, Game.count("veg_stew") == 1 and Cooking.known("veg_stew") and Game.count("potato") == 2,
		"три овоща в котелке — овощное рагу, рецепт записан в книгу")
	_ok(dev, Cooking.cook_known("veg_stew") == "veg_stew" and Game.count("veg_stew") == 2, "знакомое блюдо варится одной кнопкой")
	# не совпало — каша-неудача: съедобна, не продаётся
	var got := Cooking.cook({"carrot": 1, "coconut": 1})
	_ok(dev, got == Cooking.FLOP and Game.count(Cooking.FLOP) == 1 and Game.count("coconut") == 1, "случайный набор — каша-неудача, продукты потрачены")
	_ok(dev, Game.sell_price("marta", Cooking.FLOP) == 0 and int(Data.ITEMS[Cooking.FLOP]["food"]) > 0, "кашу-неудачу можно съесть, но нельзя продать")
	_ok(dev, Cooking.cook({"fish": 1}) == "" and Cooking.cook({"fish": 4, "banana": 1}) == "" and Game.count("fish") == 4,
		"один продукт или пять — котелок не варит и ничего не тратит")
	_ok(dev, Cooking.cook({"wood": 2}) == "", "несъедобное в котелок не кладут")
	# обычные рецепты (похлёбка у костра) получаются и в котелке
	Game.inventory["potato"] = 2
	_ok(dev, Cooking.cook({"fish": 2, "potato": 1}) == "fish_soup", "обычный рецепт (рыбная похлёбка) получается и в котелке")
	# все рецепты достижимы игрой: каждый варится и даёт своё блюдо
	var wrong: Array[String] = []
	for r in Cooking.RECIPES:
		Game.inventory = (r["in"] as Dictionary).duplicate()
		if Cooking.cook(r["in"]) != r["id"] or Game.count(r["id"]) != 1:
			wrong.append(r["id"])
	_ok(dev, wrong.is_empty() and Cooking.known_count() == Cooking.RECIPES.size(), "каждый рецепт варится, книга собрана целиком (%s)" % ", ".join(wrong))

	# польза блюд: мягкая и на время
	Game.flags.erase("buffs")
	Game.hunger = 50.0
	var regen0 := Game.hunger_regen()
	Game.inventory = {"veg_stew": 1, "banana": 1, "coconut_fish": 1, "banana_pancakes": 1, "cabbage_soup": 1}
	Game.eat_best_food()
	_ok(dev, Game.count("veg_stew") == 1 and Game.count("banana") == 0, "Q сначала ест простую еду, блюда с пользой бережёт")
	Game.hunger = 30.0
	regen0 = Game.hunger_regen()
	Game.eat_item("veg_stew")
	_ok(dev, Cooking.has_buff("regen") and Game.hunger_regen() > regen0, "рагу: бодрость — силы возвращаются быстрее")
	Game.eat_item("coconut_fish")
	_ok(dev, Cooking.bite_mult() < 1.0 and Cooking.rare_mult() > 1.0, "рыба в кокосовом молоке: рыбацкая удача")
	Game.hunger = 90.0
	var sp0 := Game.hunger_speed()
	Game.eat_item("banana_pancakes")
	_ok(dev, Game.hunger_speed() > sp0 and Game.hunger_speed() < sp0 * 1.15, "оладьи: шаг чуть быстрее (не больше +15 %)")
	_ok(dev, is_equal_approx(CozyLife.night_hunger(), 1.0), "без тёплой еды ночь — как обычно")
	Game.hunger = 40.0
	Game.eat_item("cabbage_soup")
	_ok(dev, CozyLife.night_hunger() < 1.0, "щи: за ночь проголодаешься меньше")
	Cooking.tick(10000.0)
	_ok(dev, not Cooking.has_buff("regen") and not Cooking.has_buff("luck") and is_equal_approx(Cooking.speed_mult(), 1.0),
		"польза проходит сама, без вреда")

	# продажа и заказы
	Game.unlocked["shop_marta"] = true
	var mult := Game.sell_mult()
	_ok(dev, Game.sell_price("marta", "veg_stew") == maxi(1, int(round(Data.SELL_PRICES["veg_stew"] * 1.25 * mult))), "Марта берёт блюда из котелка на четверть дороже")
	Game.inventory = {"veg_stew": 2}
	Game.sell("marta", "veg_stew", 2)
	_ok(dev, Game.count("coins") == Game.sell_price("marta", "veg_stew") * 2 and Game.count("veg_stew") == 0, "блюда продаются торговцам")
	var dish_orders := 0
	for o in OrderBoard.POOL:
		if not Cooking.recipe(o[1]).is_empty():
			dish_orders += 1
	_ok(dev, dish_orders >= 3, "на доске заказов есть блюда из котелка (%d)" % dish_orders)

	# кулинарная книга видна в окне коллекций
	hud.open_collections()
	var texts: Array[String] = []
	for l in hud._body(hud.col_panel).find_children("*", "Label", true, false):
		texts.append((l as Label).text)
	var joined := "\n".join(texts)
	_ok(dev, joined.contains("Кулинарная книга — %d из %d" % [Cooking.RECIPES.size(), Cooking.RECIPES.size()]) and joined.contains("Овощное рагу"),
		"кулинарная книга показана в окне коллекций")
	hud.close_all()

	# сохранение: книга и действующая польза переживают запись и загрузку
	Game.inventory = {"veg_stew": 1}
	Game.hunger = 20.0
	Game.eat_item("veg_stew")
	main.call("_save")
	Game.flags.erase("cookbook")
	Game.flags.erase("buffs")
	Game.unlocked.erase("cook_pot")
	var loaded := Game.load_game()
	_ok(dev, not loaded.is_empty() and Cooking.known("veg_stew") and Cooking.has_buff("regen") and Game.unlocked.has("cook_pot"),
		"книга, польза и котелок сохраняются и загружаются")
	pot.queue_free()


# ------------------------------------------------------------------ Уют и гости
static func _cozy(dev: Node) -> void:
	var main: Node = dev.get("main")
	var hud: HUD = main.get("hud")
	Game.flags["ending_keeper"] = true
	CozyLife.migrate()
	var decor: Array = []
	for id in Data.BUILDINGS:
		if Data.BUILDINGS[id].get("decor", false):
			decor.append(id)
	var locked: Array[String] = []
	for id in decor:
		if not Game.unlocked.has(id):
			locked.append(id)
	_ok(dev, decor.size() >= 20 and decor.size() <= 30 and locked.is_empty(), "украшений %d, после финала все открыты (%s)" % [decor.size(), ", ".join(locked)])
	# счёт уюта: разное — выгодно, одинаковое — всё меньше
	_ok(dev, CozyLife.score_of([]) == 0 and CozyLife.level_of(0) == 0, "пустой лагерь — уют 0")
	var one := CozyLife.score_of(["lantern_post"])
	var five := CozyLife.score_of(["lantern_post", "lantern_post", "lantern_post", "lantern_post", "lantern_post"])
	_ok(dev, one == 4 and five < one * 3, "пять одинаковых фонарей дают меньше трёх разных вещей (%d против %d)" % [five, one * 3])
	var torches: Array = []
	for i in 30:
		torches.append("torch")
	_ok(dev, CozyLife.level_of(CozyLife.score_of(torches)) <= 1, "30 факелов не делают лагерь уютным")
	var top: int = CozyLife.LEVELS[CozyLife.LEVELS.size() - 1]
	_ok(dev, CozyLife.score_of(decor) >= top, "все украшения по разу дают высшую ступень (%d из %d)" % [CozyLife.score_of(decor), top])
	# подарки: только вещи и недорогие
	var rich: Array[String] = []
	for gid in CozyLife.GUESTS:
		for g in CozyLife.GUESTS[gid]["gifts"]:
			if g[0] == "coins" or int(Data.SELL_PRICES.get(g[0], 3)) * int(g[1]) > CozyLife.GIFT_MAX_VALUE:
				rich.append("%s: %s" % [gid, g[0]])
	_ok(dev, rich.is_empty(), "подарки гостей — вещи не дороже %d монет (%s)" % [CozyLife.GIFT_MAX_VALUE, ", ".join(rich)])
	# украшения за монеты — на судне Лёвы
	var sold := false
	for e in Game.shop_items("lyova"):
		if e["item"] == "gramophone" and int(e["price"]) >= 100:
			sold = true
	_ok(dev, sold, "патефон продаётся на судне Лёвы за монеты (трата, а не доход)")
	# меню строительства: вкладка «Декор»
	hud._build_tab = "декор"
	hud.open_build()
	var texts: Array[String] = []
	for l in hud._body(hud.build_panel).find_children("*", "Label", true, false):
		texts.append((l as Label).text)
	var joined := "\n".join(texts)
	_ok(dev, joined.contains("Кресло-качалка") and joined.contains("Гирлянда огоньков"), "украшения стоят на вкладке «Декор»")
	hud._build_tab = "дом"
	hud.close_all()
	if Game.location != "home":
		print("      (лагерь, гости и бонусы уюта проверяются на острове крушения: --autotest --cozyonly)")
		return

	# лагерь: костёр и украшения вокруг него
	var cl := dev.get_tree().get_first_node_in_group("cozy_life") as CozyLife
	var bs: BuildSystem = main.get("build")
	var isl: Island = main.get("island")
	var made: Array = []
	var fire: Building = dev.call("_build", "campfire")
	made.append(fire)
	Game.flags.erase("cozy_best")
	cl._update_cozy()
	_ok(dev, CozyLife.level_now == 0 and cl.cozy_text().contains("Пусто"), "костёр без украшений: уют «Пусто»")
	var chair := _put(main, bs, isl, fire, made, "rocking_chair", 0)
	var rug := _put(main, bs, isl, fire, made, "rug_wool", 1)
	var lamp := _put(main, bs, isl, fire, made, "lantern_post", 2) as DecorPiece
	_ok(dev, chair is DecorPiece and chair.is_in_group("interactable"), "украшение — своя постройка, к ней можно подойти")
	_ok(dev, is_zero_approx(rug.block_radius()) and rug.collision_layer == 8, "по коврику ходят, на него можно ставить мебель")
	_ok(dev, lamp._lights.size() == 1, "у фонаря есть свой свет")
	Game.time_of_day = 0.95
	lamp._update_lamps()
	var lit: bool = lamp._lights[0].visible
	Game.time_of_day = 0.5
	lamp._update_lamps()
	_ok(dev, lit and not lamp._lights[0].visible, "фонарь сам зажигается вечером и гаснет днём")
	_ok(dev, (chair as DecorPiece).act().contains("качаешься"), "в кресле-качалке можно посидеть")
	cl._update_cozy()
	var s3 := CozyLife.score_now
	_ok(dev, s3 == 4 + 3 + 4 and CozyLife.level_now == 1, "кресло, коврик и фонарь: уют %d, ступень «%s»" % [s3, CozyLife.LEVEL_NAMES[CozyLife.level_now]])
	# далеко от костра — не считается
	var far_pos: Vector3 = fire.global_position + Vector3(CozyLife.CAMP_R + 6.0, 0, 0)
	far_pos.y = isl.height_at(far_pos.x, far_pos.z)
	var far := bs.spawn_building("gramophone", far_pos, 0.0)
	made.append(far)
	cl._update_cozy()
	_ok(dev, CozyLife.score_now == s3, "украшение далеко от костра уюта не добавляет")
	# убрать — материалы возвращаются целиком
	Game.inventory = {}
	(far as DecorPiece).remove_piece()
	_ok(dev, Game.count("gramophone") == 1 and not far.is_in_group("building"), "украшение можно убрать: всё возвращается в сумку")
	# много разного — высокая ступень и бонусы
	var i := 3
	for id in decor:
		if not id in ["rocking_chair", "rug_wool", "lantern_post"]:
			_put(main, bs, isl, fire, made, id, i)
			i += 1
	cl._update_cozy()
	_ok(dev, CozyLife.level_now == CozyLife.LEVELS.size() - 1, "все украшения у костра: ступень «%s» (%d очков)" % [CozyLife.LEVEL_NAMES[CozyLife.level_now], CozyLife.score_now])
	Game.flags.erase("buffs")
	_ok(dev, CozyLife.night_hunger() < 1.0 and CozyLife.night_hunger() >= 0.3, "в уютном лагере за ночь проголодаешься меньше (×%.2f), но не даром" % CozyLife.night_hunger())
	Game.hunger = 70.0
	var was_on := Game.hunger_on
	Game.hunger_on = true
	Game.sleep_until_morning()
	Game.hunger_on = was_on
	_ok(dev, Game.hunger > 55.0 and Game.hunger < 70.0, "сон в уютном лагере: сытость %d вместо 55" % int(Game.hunger))
	var pl: Node3D = main.get("player")
	var was_pos := pl.global_position
	Game.hunger = 50.0
	pl.global_position = fire.global_position + Vector3(40, 0, 0)
	cl._update_cozy()
	var regen_far := Game.hunger_regen()
	pl.global_position = fire.global_position + Vector3(2, 0.5, 0)
	cl._update_cozy()
	_ok(dev, CozyLife.resting and Game.hunger_regen() > regen_far, "у костра в уютном лагере силы возвращаются быстрее")

	# вечерний гость
	Game.flags.erase("guest")
	Game.flags.erase("guest_roll_day")
	var was_playing := Game.playing
	Game.playing = true
	Game.time_of_day = 0.5
	cl._update_guest()
	_ok(dev, cl._guest == null, "днём гостей нет")
	var lvl := CozyLife.level_now
	while CozyLife.guest_today(lvl) == "" or CozyLife.gift_today(CozyLife.guest_today(lvl), lvl).is_empty():
		Game.day += 1
	var gid := CozyLife.guest_today(lvl)
	var gift := CozyLife.gift_today(gid, lvl)
	Game.time_of_day = 0.75
	cl._update_guest()
	_ok(dev, cl._guest != null and cl._guest.guest_id == gid and cl._guest.is_in_group("interactable"), "вечером к костру идёт гость (%s)" % gid)
	var guest := cl._guest
	guest.global_position = guest.target
	Game.inventory = {}
	var talks := Game.stat("guests", "any")
	guest.interact(pl)
	dev.call("_flush")
	_ok(dev, guest.talked and Game.stat("guests", "any") == talks + 1, "гость говорит пару реплик")
	_ok(dev, Game.count(str(gift[0])) == int(gift[1]) and Game.count("coins") == 0, "гость оставил подарок: %s ×%d (не монеты)" % [Game.item_name(str(gift[0])), int(gift[1])])
	guest.interact(pl)
	dev.call("_flush")
	_ok(dev, Game.count(str(gift[0])) == int(gift[1]), "второй раз за вечер подарка нет")
	cl._guest = null
	guest.free()
	cl._update_guest()
	_ok(dev, cl._guest != null and cl._guest.talked, "после загрузки вечером гость на месте и помнит разговор")
	var g2 := cl._guest
	Game.time_of_day = 0.3
	Game.day += 1
	cl._update_guest()
	_ok(dev, g2.leaving and cl._guest == null, "утром гость уходит; не поговорил — ничего не потерял")
	g2.free()
	# без уюта гости не заходят
	Game.flags.erase("guest")
	Game.flags.erase("guest_roll_day")
	var none := true
	for d in 20:
		Game.day += 1
		if CozyLife.guest_today(0) != "":
			none = false
	_ok(dev, none, "в пустой лагерь гости не заходят")
	pl.global_position = was_pos
	for b in made:
		if is_instance_valid(b):
			b.remove_from_group("building")
			b.queue_free()
	Game.playing = was_playing


static func _put(main: Node, bs: BuildSystem, isl: Island, fire: Node3D, made: Array, id: String, i: int) -> Building:
	var a := i * 0.7
	var pos: Vector3 = fire.global_position + Vector3(cos(a), 0, sin(a)) * (3.0 + (i % 4) * 2.2)
	pos.y = isl.height_at(pos.x, pos.z)
	var b := bs.spawn_building(id, pos, 0.0)
	main.call("_connect_building", b)
	made.append(b)
	return b


# ------------------------------------------------------------------ Скриншоты
## --open=cook — окно котелка (в сумке продукты, часть рецептов уже найдена); --open=cookbook — кулинарная книга;
## --open=cozy — лагерь с украшениями у костра и вечерним гостем (время — --time=0.76, камера — --yaw/--pitch/--dist);
## --open=decor — меню строительства, вкладка «Декор».
const CAMP := [
	["rug_wool", 0.0, 2.3, 0.0], ["rocking_chair", -1.5, 2.7, 2.6], ["decor_chest", 1.5, 3.0, 3.4], ["camp_table", 3.0, 1.2, 1.2],
	["camp_stool", 2.2, 2.4, 0.0], ["camp_stool", 4.0, 2.2, 0.0], ["cook_pot", -3.0, 0.4, 1.2], ["camp_shelf", -4.2, -1.4, 0.9],
	["garland_lights", 0.0, -3.2, 0.0], ["garland_flags", 5.2, -1.2, 1.2], ["lantern_post", -4.8, 2.6, 0.6], ["lantern_post", 5.2, 3.6, 2.4],
	["paper_lantern", 1.6, 4.6, 0.0], ["stone_lantern", -2.4, 4.6, 0.0], ["flower_tub", 4.2, -0.2, 0.0], ["flower_barrow", -5.6, 0.6, 1.0],
	["flower_arch", 0.0, 6.4, 0.0], ["stone_path", 0.0, 4.8, 0.0], ["stone_path", 0.0, 7.6, 0.4], ["picket_fence", -1.7, 6.4, 0.0],
	["picket_fence", -3.0, 6.4, 0.0], ["picket_fence", 1.7, 6.4, 0.0], ["picket_fence", 3.0, 6.4, 0.0], ["sign_camp", 2.4, 7.6, 0.0],
	["sign_arrows", -2.4, 7.8, 0.0], ["bird_feeder", 6.2, -3.6, 0.0], ["weather_vane", -6.0, -3.2, 0.0], ["log_stack", -2.0, -4.6, 0.0],
	["wind_chime", 3.2, -3.0, 0.0], ["gramophone", -2.6, 2.0, 2.2], ["wash_stand", -4.6, -3.2, 0.6], ["bamboo_fence", 6.8, 1.4, 1.57],
	["bamboo_fence", 6.8, 2.7, 1.57], ["garden_gate", 6.8, 0.0, 1.57], ["plank_path", 5.6, 0.2, 0.0], ["rug_straw", 3.0, 1.3, 0.0],
]


static func shot(dev: Node, what: String) -> void:
	if not what in ["cook", "cookbook", "cozy", "decor"]:
		return
	var main: Node = dev.get("main")
	var hud: HUD = main.get("hud")
	dev.call("_flush")
	Game.flags["ending_open_sea"] = true
	CozyLife.migrate()
	var b := {}
	for id in ["veg_stew", "tomato_omelette", "coconut_fish", "banana_pancakes", "pumpkin_soup", "lemonade", "cheese_salad", "corn_cakes",
			"cloudberry_pie", "milk_coffee", "fish_pie", "spicy_corn", "honey_carrot", "truffle_potato"]:
		b[id] = 1
	Game.flags["cookbook"] = b
	dev.call("_give", {"potato": 4, "carrot": 5, "tomato": 3, "corn": 6, "cabbage": 2, "pumpkin": 2, "egg": 4, "milk": 3, "honey": 2,
		"fish": 5, "coconut": 3, "lemon": 2, "banana": 4, "mango": 2, "truffle": 1, "cheese": 1, "pepper": 2, "plank": 12, "wood": 9,
		"rope": 4, "stone": 9, "bamboo": 6, "fiber": 10})
	var cl := dev.get_tree().get_first_node_in_group("cozy_life") as CozyLife
	match what:
		"cookbook":
			hud.open_collections()
		"decor":
			hud._build_tab = "декор"
			hud.open_build()
		"cook":
			cl.open_cooking()
			cl.cook_ui.put("fish")
			cl.cook_ui.put("fish")
			cl.cook_ui.put("coconut")
		"cozy":
			var bs: BuildSystem = main.get("build")
			var isl: Island = main.get("island")
			var c: Vector3 = isl.camp_center
			for n in dev.get_tree().get_nodes_in_group("obstacle"):
				if n is ResourceNode and (n as Node3D).global_position.distance_to(c) < 13.0:
					n.call("_deplete")
			if isl.grass_field:
				isl.grass_field.clear_at(c, 10.0, true)
			var fire := bs.spawn_building("campfire", Vector3(c.x, isl.height_at(c.x, c.z), c.z), 0.0)
			for e in CAMP:
				var pos := Vector3(c.x + float(e[1]), 0, c.z + float(e[2]))
				pos.y = isl.height_at(pos.x, pos.z)
				bs.spawn_building(str(e[0]), pos, float(e[3]))
			cl._update_cozy()
			Game.flags["guest"] = {"id": "marta", "day": Game.day, "talked": false}
			cl._spawn_guest("marta", fire, false)
			var pl: Node3D = main.get("player")
			pl.global_position = Vector3(c.x - 0.6, isl.height_at(c.x - 0.6, c.z + 3.6) + 0.3, c.z + 3.6)
			cl._update_cozy()
			cl._update_labels()
