extends Node
## Инструменты разработчика. Включаются аргументами командной строки после "--":
##   godot -- --shot=res://shot.png --time=0.45 --demo
##   --shot=путь     сделать скриншот через пару секунд и выйти
##   --time=0..1     время суток
##   --demo          выдать ресурсы и поставить несколько построек рядом с игроком
##   --yaw= --pitch= --dist=  положение камеры
##   --autotest      прогнать игровой цикл (крафт, стройка, задания) и вывести результат в консоль

var main: Node
var args := {}
var _frames := 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	if args.has("time"):
		Game.time_of_day = float(args["time"])
	if args.has("autotest"):
		_autotest.call_deferred()


func _process(_delta: float) -> void:
	_frames += 1
	var p: Player = main.player
	if _frames == 2:
		if args.has("yaw"): p.camera_yaw = float(args["yaw"])
		if args.has("pitch"): p.camera_pitch = float(args["pitch"])
		if args.has("dist"): p.camera_distance = float(args["dist"])
		if args.has("time"): Game.time_of_day = float(args["time"])
		if args.has("demo"):
			_demo()
	if args.has("time"):
		Game.time_of_day = float(args["time"])
	if args.has("shot") and _frames == int(args.get("frames", "90")):
		var img := get_viewport().get_texture().get_image()
		img.save_png(args["shot"])
		print("screenshot saved: ", args["shot"])
		get_tree().quit()


func _demo() -> void:
	var p: Player = main.player
	var fwd := -Basis(Vector3.UP, p.camera_yaw).z
	var right := Basis(Vector3.UP, p.camera_yaw).x
	var base := p.global_position + fwd * 7.0
	var spots := {"campfire": Vector3.ZERO, "workbench": right * 3.5 + fwd * 1.0,
		"hut": -right * 5.0 + fwd * 3.0, "torch": right * 1.8 - fwd * 1.5, "shell_deco": -right * 1.6 - fwd * 1.0}
	for id in spots:
		var pos: Vector3 = base + spots[id]
		pos.y = main.island.height_at(pos.x, pos.z)
		main.build.spawn_building(id, pos, 0.3)
	for id in ["wood", "stone", "fiber", "rope", "leaf", "coconut", "stone_axe"]:
		Game.inventory[id] = 5 if id != "stone_axe" else 1
	Game.inventory_changed.emit()


func _check(cond: bool, what: String, fails: Array) -> void:
	print(("  OK   " if cond else "  FAIL ") + what)
	if not cond:
		fails.append(what)


func _autotest() -> void:
	print("=== AUTOTEST ===")
	var fails := []
	Game.reset()
	var isl: Island = main.island
	var p: Player = main.player
	_check(isl.height_at(0, 0) > 1.0, "центр острова над водой", fails)
	_check(isl.height_at(150, 150) < -1.0, "вдали — море", fails)
	_check(p.global_position.y > 0.0, "игрок появился на суше", fails)
	var res := get_tree().get_nodes_in_group("interactable")
	_check(res.size() > 150, "на острове есть ресурсы (%d)" % res.size(), fails)

	# собрать волокно с куста
	var bush: ResourceNode = null
	for n in res:
		if n is ResourceNode and n.kind == "bush":
			bush = n
			break
	bush.interact(p)
	bush.interact(p)
	_check(Game.count("fiber") == 2, "куст даёт 2 волокна", fails)
	_check(not bush.active, "куст исчез после сбора", fails)
	Game.add_item("fiber", 1)
	_check(Game.quest_index == 1, "задание 1 выполнено", fails)
	_check(Game.craft(Game.RECIPES[0]), "крафт верёвки", fails)
	_check(Game.count("rope") == 1 and Game.count("fiber") == 0, "верёвка создана, волокно списано", fails)
	_check(not Game.craft(Game.RECIPES[1]), "топор без ресурсов не крафтится", fails)
	Game.add_item("wood", 2)
	Game.add_item("stone", 2)
	_check(Game.craft(Game.RECIPES[1]) and Game.has_tool("stone_axe"), "крафт каменного топора", fails)

	# срубить пальму
	var palm: ResourceNode = null
	for n in res:
		if n is ResourceNode and n.kind == "palm" and n.active:
			palm = n
			break
	var wood_before := Game.count("wood")
	for i in 4:
		palm.interact(p)
	_check(Game.count("wood") == wood_before + 3, "пальма даёт 3 древесины", fails)

	# энергия
	var e := Game.energy
	_check(e < Game.MAX_ENERGY, "действия тратят энергию (%d)" % e, fails)
	Game.add_item("coconut", 1)
	Game.eat_best_food()
	_check(Game.energy > e, "кокос восстанавливает энергию", fails)

	# строительство
	Game.add_item("wood", 10)
	Game.add_item("stone", 10)
	var spot := p.global_position + Vector3(0, 0, -4)
	spot.y = isl.height_at(spot.x, spot.z)
	var bs: BuildSystem = main.build
	var cost: Dictionary = Game.BUILDINGS["campfire"]["cost"]
	_check(Game.pay(cost), "оплата костра", fails)
	var b := bs.spawn_building("campfire", spot, 0)
	Game.register_built("campfire")
	_check(get_tree().get_nodes_in_group("station_campfire").size() == 1, "костёр построен", fails)

	# сохранение / загрузка
	main._save()
	var inv_copy: Dictionary = Game.inventory.duplicate()
	Game.inventory = {}
	var data := Game.load_game()
	_check(Game.inventory == inv_copy, "инвентарь сохраняется и загружается", fails)
	_check(data.get("buildings", []).size() == 1, "постройки сохраняются", fails)
	b.queue_free()
	Game.reset()

	print("=== %s (%d ошибок) ===" % ["PASSED" if fails.is_empty() else "FAILED", fails.size()])
	get_tree().quit(0 if fails.is_empty() else 1)
