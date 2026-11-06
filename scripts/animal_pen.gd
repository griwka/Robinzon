class_name AnimalPen
extends Building
## Курятник / загон: покорми животных → через время собери продукт (яйца, молоко).

var fed := false
var progress := 0.0
var product_ready := false
var animals: Array[Animal] = []


func _custom_interact() -> void:
	pass


func _ready() -> void:
	super()
	marker = FX.marker(self, marker_height())
	var cfg: Dictionary = Data.PENS[id]
	for i in cfg["count"]:
		var a := Animal.new()
		a.pen = self
		a.kind = cfg["animal"]
		a.home = global_position
		a.radius = 1.2 if id == "coop" else (1.0 if id == "goose_house" else 1.4)
		if id == "tortoise_pen":
			a.size = [1.3, 1.0, 0.65][i % 3]   # Генерал, Тортила, Малыш
		a.position = position + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))
		get_parent().add_child.call_deferred(a)
		animals.append(a)
	_refresh()


func _exit_tree() -> void:
	for a in animals:
		if is_instance_valid(a):
			a.queue_free()


func marker_height() -> float:
	return {"coop": 2.6, "beehive": 2.1, "sheep_pen": 1.9, "pig_sty": 1.9, "goose_house": 2.2, "lightning_rod": 4.4, "tortoise_pen": 1.6}.get(id, 1.8)


## Доля времени, когда идёт гроза (для «пропущенного» времени — сон, далёкий остров).
const STORM_SHARE := 0.15


func _process(delta: float) -> void:
	super(delta)
	var dt := world_dt()
	if fed and not product_ready:
		if Data.PENS[id].get("storm", false):
			# громоотвод заряжает только в грозу; если время «пролетело» (сон) — за прошедшие грозы
			if Game.storm_active():
				pass
			elif dt > 5.0:
				dt *= STORM_SHARE
			else:
				dt = 0.0
		progress += dt / Data.PENS[id]["time"]
		if progress >= 1.0:
			product_ready = true
			_refresh()


func _refresh() -> void:
	var cfg: Dictionary = Data.PENS[id]
	if product_ready:
		FX.set_marker(marker, true, cfg["product"])
	elif not fed:
		FX.set_marker(marker, true, cfg["feed"].keys()[0])
	else:
		FX.set_marker(marker, false)


func _cost_text(cost: Dictionary) -> String:
	var parts: Array[String] = []
	for k in cost:
		parts.append("%s ×%d" % [Game.item_name(k), cost[k]])
	return ", ".join(parts)


func get_hint() -> String:
	var cfg: Dictionary = Data.PENS[id]
	if product_ready:
		return "Собрать: %s ×%d" % [Game.item_name(cfg["product"]), cfg["amount"]]
	if id == "lightning_rod":
		if not fed:
			return "Громоотвод — повесить пустой аккумулятор (есть: %d)" % Game.count("battery")
		if not Game.storm_active():
			return "Аккумулятор висит. Заряжается только в грозу (%d%%)" % int(progress * 100.0)
		return "Гроза! Аккумулятор заряжается: %d%%" % int(progress * 100.0)
	if not fed:
		return "%s голодны — покормить: %s (есть: %d)" % [cfg["animal_name"], _cost_text(cfg["feed"]), Game.count(cfg["feed"].keys()[0])]
	return "%s сыты. %s — %s" % [cfg["animal_name"], Game.item_name(cfg["product"]), time_left_text()]


## Сколько ждать продукта: «через 1 мин 10 с» (по игровому времени, как его считает загон).
func time_left_text() -> String:
	var left := int(ceil(maxf(0.0, 1.0 - progress) * float(Data.PENS[id]["time"])))
	if left >= 60:
		return "через %d мин %d с" % [left / 60, left % 60]
	return "через %d с" % maxi(left, 1)


## Есть ли у загона дело для игрока (собрать продукт или покормить).
func needs_care() -> bool:
	return product_ready or (not fed and id != "lightning_rod")


func interact(_player: Node) -> void:
	var cfg: Dictionary = Data.PENS[id]
	if product_ready:
		Game.add_item(cfg["product"], cfg["amount"])
		Game.bump("product", cfg["product"], cfg["amount"])
		var bonus: Dictionary = cfg.get("bonus", {})
		for b in bonus:
			Game.add_item(b, bonus[b])
			Game.bump("product", b, bonus[b])
		product_ready = false
		fed = false
		progress = 0.0
		FX.burst(self, Vector3(0, 1.0, 0), Data.ITEMS[cfg["product"]]["color"], 10)
	elif not fed:
		if Game.pay(cfg["feed"]):
			fed = true
			progress = 0.0
			Game.bump("fed", id)
			Audio.play({"coop": "cluck", "beehive": "rustle", "pig_sty": "oink", "goose_house": "honk", "lightning_rod": "radio", "tortoise_pen": "tortoise", "sheep_pen": "baa"}.get(id, "bleat"), -2.0, 0.1, global_position)
			Game.notified.emit("Аккумулятор подключён. Ждём грозу!" if id == "lightning_rod" else "%s накормлены!" % cfg["animal_name"], Color("ffe08a"))
			for a in animals:
				if is_instance_valid(a):
					a.happy()
		else:
			Game.notified.emit("Нужен пустой аккумулятор" if id == "lightning_rod" else "Нужен корм: %s" % _cost_text(cfg["feed"]), Color("ff9d7a"))
	else:
		Game.notified.emit(get_hint(), Color("ffe08a"))
	_refresh()


func get_state() -> Dictionary:
	return {"fed": fed, "progress": progress, "ready": product_ready}


func apply_state(d: Dictionary) -> void:
	fed = bool(d.get("fed", false))
	progress = float(d.get("progress", 0.0))
	product_ready = bool(d.get("ready", false))
	if is_inside_tree():
		_refresh()
