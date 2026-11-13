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
	elif absf(progress - _shown) > 0.0015:
		_grow_visual()


# ------------------------------------------------------------------ плавный рост
# Модель культуры (crop_<вид>) — растения-узлы P0..P8; в каждом листья, стебель и плоды P<n>_fruit<k>.
# Растение тянется из маленького ростка непрерывно по progress (у каждого — свой небольшой сдвиг),
# плоды появляются со второй половины роста, наливаются и из зелёных становятся спелыми.
# Стадии (stage) для заданий и сбора — прежние: это только вид.
var _crop_built := ""
var _plants: Array = []        # [Node3D растение, сдвиг 0..0.12, [MeshInstance3D плоды]]
var _fruit_mat: ShaderMaterial
var _shown := -1.0
const UNRIPE := Color(0.62, 0.86, 0.5)   # цвет-множитель незрелых плодов


func _build_crop() -> void:
	if crop_node:
		crop_node.queue_free()
		crop_node = null
	_plants.clear()
	_crop_built = crop
	if crop == "":
		return
	crop_node = Models.glb("crop_" + crop)
	if crop_node == null:
		crop_node = Models.crop(crop, 3)
	visual.add_child(crop_node)
	_fruit_mat = (Models.model_mat(false).duplicate() as ShaderMaterial)
	var i := 0
	for c in crop_node.find_children("P*", "Node3D", false, false):
		var nm := String(c.name)
		if nm.length() < 2 or not nm.substr(1).is_valid_int():
			continue
		var fruits: Array = []
		for mi in (c as Node3D).find_children("*_fruit*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).material_override = _fruit_mat
			fruits.append(mi)
		_plants.append([c, fposmod(i * 0.37, 1.0) * 0.12, fruits])
		i += 1
	_shown = -1.0
	_grow_visual()


func _grow_visual() -> void:
	if crop_node == null:
		return
	_shown = progress
	if _plants.is_empty():   # старая модель без растений-узлов — растёт целиком
		var k := lerpf(0.15, 1.0, smoothstep(0.0, 1.0, progress))
		crop_node.scale = Vector3(k, k, k)
		return
	for pl in _plants:
		var g := clampf((progress - float(pl[1])) / (1.0 - float(pl[1])), 0.0, 1.0)
		var body := smoothstep(0.0, 0.85, g)
		var w := lerpf(0.14, 1.0, body)
		var h := lerpf(0.08, 1.0, body * body * 0.4 + body * 0.6)   # сначала стелется, потом тянется вверх
		(pl[0] as Node3D).scale = Vector3(w, h, w)
		var fg := smoothstep(0.45, 1.0, g)
		for mi in pl[2]:
			var f := mi as MeshInstance3D
			f.visible = fg > 0.02
			# плод держим в натуральную величину независимо от высоты растения: «наливается» сам
			var fk := lerpf(0.25, 1.0, fg)
			f.scale = Vector3(fk, fk * w / maxf(h, 0.01), fk)   # растение растёт неровно (w, h, w) — плод не сплющиваем
	_fruit_mat.set_shader_parameter("albedo", UNRIPE.lerp(Color.WHITE, smoothstep(0.7, 1.0, progress)))


func _refresh() -> void:
	_stage = stage()
	if crop != _crop_built:
		_build_crop()
	else:
		_grow_visual()
	if _stage == 3 and crop_node:
		crop_node.scale = Vector3(0.92, 0.92, 0.92)   # созрело: мягкий «прыжок»
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
			if watered and can_fertilize():
				fertilize()
			elif can_water():
				water()
			else:
				Game.notified.emit("%s созреет через ~%d c" % [Data.CROPS[crop]["name"], int(_time_left())], Color("ffe08a"))


func can_water() -> bool:
	return crop != "" and progress < 1.0 and not watered and Game.has_tool("watering_can")


func can_fertilize() -> bool:
	return crop != "" and progress < 1.0 and not fertilized and Game.count("fertilizer") > 0


func water() -> void:
	if not can_water():
		return
	watered = true
	Game.bump("watered", "bed")
	Audio.play("water", -3.0, 0.1, global_position)
	FX.burst(self, Vector3(0, 0.5, 0), Color("6fc3ff"), 16)
	_refresh()


func fertilize() -> void:
	if not can_fertilize():
		return
	Game.pay({"fertilizer": 1})
	fertilized = true
	Audio.play("plant", -2.0, 0.1, global_position)
	FX.burst(self, Vector3(0, 0.5, 0), Color("7a5a3a"), 12)
	Game.notified.emit("Удобрено: теперь растёт вдвое быстрее", Color("c9f59b"))


## Убрать грядку (поставил не там): материалы возвращаются целиком, посаженное — семенами обратно в сумку.
func remove_bed() -> void:
	if crop != "" and stage() < 3:
		Game.add_item(_seed_for(crop), 1, false)
	for id in Data.BUILDINGS["garden_bed"]["cost"]:
		Game.add_item(id, int(Data.BUILDINGS["garden_bed"]["cost"][id]), false)
	Game.notified.emit("Грядка убрана — материалы вернулись в сумку" + (", семена тоже" if crop != "" else ""), Color("ffe08a"))
	Audio.play("build", -4.0, 0.1, global_position)
	FX.poof(get_parent(), position + Vector3(0, 0.3, 0), Color("8a6a42"), 1.2)
	queue_free()


func _remove_option() -> Dictionary:
	var back := "вернёт доски и семена" if crop != "" else "вернёт доски"
	return {"text": "Убрать", "note": back, "icon": "plank", "callback": remove_bed}


## Что можно сделать с грядкой сейчас — для круга действий (последним — «Убрать грядку»). Пусто — выбирать не из чего.
func wheel_options(player: Node = null) -> Array:
	var opts := []
	match stage():
		0:
			for c in Data.CROPS:
				var seed_id := _seed_for(c)
				if Game.count(seed_id) > 0 and can_grow(c):
					opts.append({"text": Data.CROPS[c]["name"], "note": "семян: %d · ~%d с" % [Game.count(seed_id), int(Data.CROPS[c]["time"])],
						"icon": seed_id, "callback": plant.bind(c)})
			opts.append(_remove_option())
			return opts
		3:
			return []
	if not can_grow(crop):
		return [_remove_option()]
	var w_note := "уже полито" if watered else ("ускорит рост" if Game.has_tool("watering_can") else "нужна лейка")
	opts.append({"text": "Полить", "note": w_note, "icon": "watering_can", "enabled": can_water(), "callback": func():
		if player and player.has_method("gesture"):
			Game.hold("watering_can")
			player.gesture("watering_can")
		water()})
	var f_note := "уже удобрено" if fertilized else ("вдвое быстрее · есть: %d" % Game.count("fertilizer") if Game.count("fertilizer") > 0 else "нет удобрения")
	opts.append({"text": "Удобрить", "note": f_note, "icon": "fertilizer", "enabled": can_fertilize(), "callback": fertilize})
	opts.append(_remove_option())
	return opts


## Круг действий по E: семена на выбор или «полить / удобрить». true — круг открыт.
## Когда доступно одно-единственное дело (собрать урожай, полить) — круга нет, оно делается сразу.
func wheel_request(player: Node) -> bool:
	var opts := wheel_options(player)
	if opts.is_empty() or opts.size() > 8:
		return false
	if stage() == 0:
		var seeds := opts.size() - 1
		Game.wheel_requested.emit("Что посадить?" if seeds > 0 else "Грядка",
			"" if seeds > 0 else "Нет семян — поищи в кустах или купи у Румбы", opts)
		return true
	# полезные дела (без «Убрать»): одно-единственное — делаем сразу (полить), иначе — круг
	var useful := 0
	for i in opts.size() - 1:
		if opts[i].get("enabled", true):
			useful += 1
	if useful == 1 and opts[0].get("enabled", true):
		return false
	var info := "растёт: %d%% · ещё ~%d с" % [int(progress * 100), int(_time_left())] if can_grow(crop) else "здесь не растёт"
	Game.wheel_requested.emit(Data.CROPS[crop]["name"], info, opts)
	return true


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
		Game.add_item(_seed_for(crop), 1, false)   # иногда одно семечко назад — остальные покупают в лавке
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
