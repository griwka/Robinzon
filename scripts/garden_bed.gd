class_name GardenBed
extends Building
## Грядка: посадить семена → ростки → созрело → собрать. Полив лейкой ускоряет рост вдвое.

var crop := ""
var progress := 0.0
var watered := false
var in_greenhouse := false   # грядка внутри теплицы: растёт и в мороз, на четверть быстрее
var fertilized := false      # удобрение от черепах: эта посадка растёт вдвое быстрее
var _stage := -1
var crop_node: Node3D


func _custom_interact() -> void:
	pass


func _ready() -> void:
	super()
	marker = FX.marker(self, marker_height())
	_refresh()


func marker_height() -> float:
	return 1.3


func stage() -> int:
	if crop == "":
		return 0
	if progress < 0.45:
		return 1
	if progress < 1.0:
		return 2
	return 3


func _process(delta: float) -> void:
	super(delta)
	var dt := world_dt()
	if crop != "" and progress < 1.0 and can_grow(crop):
		var speed := (2.0 if watered else 1.0) * (1.25 if in_greenhouse else 1.0) * (2.0 if fertilized else 1.0)
		progress = minf(1.0, progress + dt * speed / Data.CROPS[crop]["time"])
	if stage() != _stage:
		_refresh()


func _refresh() -> void:
	_stage = stage()
	if crop_node:
		crop_node.queue_free()
		crop_node = null
	if _stage > 0:
		crop_node = Models.crop(crop, _stage)
		visual.add_child(crop_node)
		if _stage == 3:
			crop_node.scale = Vector3(0.7, 0.7, 0.7)
			create_tween().tween_property(crop_node, "scale", Vector3.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var soil := visual.get_node_or_null("Soil") as MeshInstance3D
	if soil:
		soil.material_override = Models.mat(Color("54331d") if watered else Color("7a4a2a"), false)
	FX.set_marker(marker, _stage == 3, crop)


## Растёт ли культура здесь: в теплице — всё; морошка на улице — только на Ледяном острове;
## остальное на улице — где не мороз.
func can_grow(c: String) -> bool:
	if in_greenhouse:
		return true
	if Data.CROPS[c].get("cold", false):
		return Game.location == "ice"
	return not Game.cold_active()


func tool_hint() -> String:
	return "watering_can" if crop != "" and not watered and progress < 1.0 else ""


func get_hint() -> String:
	match stage():
		0: return "Грядка — посадить семена"
		3: return "Собрать урожай: %s" % Data.CROPS[crop]["name"]
	if not can_grow(crop):
		return "%s не растёт: %s" % [Data.CROPS[crop]["name"], "здесь слишком тепло для северной ягоды" if Data.CROPS[crop].get("cold", false) else "мороз"]
	var t := "%s растёт: %d%%" % [Data.CROPS[crop]["name"], int(progress * 100)]
	if not watered:
		t += " · полить лейкой" if Game.has_tool("watering_can") else " · (лейка ускорит рост)"
	elif not fertilized and Game.count("fertilizer") > 0:
		t += " · удобрить"
	return t


func interact(_player: Node) -> void:
	match stage():
		0:
			var options := []
			var blocked := false
			for c in Data.CROPS:
				var seed_id := _seed_for(c)
				if Game.count(seed_id) > 0 and not can_grow(c):
					blocked = true
				elif Game.count(seed_id) > 0:
					options.append({"text": "%s  (семян: %d, ~%d c)" % [Data.CROPS[c]["name"], Game.count(seed_id), int(Data.CROPS[c]["time"])],
						"icon": seed_id, "callback": plant.bind(c)})
			if options.is_empty() and blocked:
				Game.notified.emit("Здесь это не вырастет. В мороз на улице растёт только морошка, остальное — в теплице. Морошке же нужен холод или теплица", Color("ff9d7a"))
			elif options.is_empty():
				Game.notified.emit("Нет семян. Поищи в кустах или спроси Румбу!", Color("ff9d7a"))
			else:
				choice_requested.emit("Что посадить?", options)
		3:
			_harvest()
		_:
			if watered and not fertilized and Game.count("fertilizer") > 0:
				Game.pay({"fertilizer": 1})
				fertilized = true
				Audio.play("plant", -2.0, 0.1, global_position)
				FX.burst(self, Vector3(0, 0.5, 0), Color("7a5a3a"), 12)
				Game.notified.emit("Удобрено: теперь растёт вдвое быстрее", Color("c9f59b"))
			elif not watered and Game.has_tool("watering_can"):
				watered = true
				Game.bump("watered", "bed")
				Audio.play("water", -3.0, 0.1, global_position)
				FX.burst(self, Vector3(0, 0.5, 0), Color("6fc3ff"), 16)
				_refresh()
			else:
				Game.notified.emit("%s созреет через ~%d c" % [Data.CROPS[crop]["name"], int(_time_left())], Color("ffe08a"))


func _seed_for(c: String) -> String:
	for id_ in Data.ITEMS:
		if Data.ITEMS[id_].get("crop", "") == c:
			return id_
	return ""


func _time_left() -> float:
	return (1.0 - progress) * Data.CROPS[crop]["time"] / ((2.0 if watered else 1.0) * (1.25 if in_greenhouse else 1.0) * (2.0 if fertilized else 1.0))


func plant(c: String) -> void:
	if stage() != 0 or not Game.pay({_seed_for(c): 1}):
		return
	crop = c
	progress = 0.0
	watered = false
	fertilized = false
	Game.bump("planted", c)
	Audio.play("plant", -2.0, 0.1, global_position)
	FX.burst(self, Vector3(0, 0.3, 0), Color("8f5a34"), 10)
	_refresh()


func _harvest() -> void:
	var cfg: Dictionary = Data.CROPS[crop]
	var n := randi_range(cfg["yield"][0], cfg["yield"][1])
	if Game.bounty_today():
		n *= 2   # день щедрости: Хранитель зажёг лучи
	Game.add_item(crop, n)
	Game.bump("harvested", crop, n)
	Audio.play("harvest", -2.0, 0.1, global_position)
	if randf() < cfg["seed_back"]:
		Game.add_item(_seed_for(crop), randi_range(1, 2), false)
	FX.burst(self, Vector3(0, 0.5, 0), Data.ITEMS[crop]["color"], 14)
	crop = ""
	progress = 0.0
	watered = false
	fertilized = false
	_refresh()


func get_state() -> Dictionary:
	return {"crop": crop, "progress": progress, "watered": watered, "fert": fertilized}


func apply_state(d: Dictionary) -> void:
	crop = d.get("crop", "")
	progress = float(d.get("progress", 0.0))
	watered = bool(d.get("watered", false))
	fertilized = bool(d.get("fert", false))
	if is_inside_tree():
		_refresh()
