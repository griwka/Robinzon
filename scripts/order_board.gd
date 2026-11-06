class_name OrderBoard
extends StaticBody3D
## Доска заказов на острове крушения (после финала): жители и гости просят урожай и продукты хозяйства.
## Каждое утро — три новых заказа; за выполненный платят больше, чем лавка. Не успел — ничего не теряешь:
## завтра будут другие.

## [кто, что, сколько, просьба]
const POOL := [
	["marta", "egg", 6, "Яйца для пирогов. Гостей сегодня — как чаек на берегу."],
	["marta", "pumpkin", 3, "Тыквы на кашу. Большую кастрюлю."],
	["renata", "fish_soup", 2, "Похлёбку для вахты. Горячую."],
	["misha", "honey", 2, "Мёда! Немножко. Ну ладно, два."],
	["misha", "watermelon", 1, "Арбуз! Самый большой!"],
	["stepa", "fish", 5, "Рыбы на коптильню. Свежей, а не вчерашней."],
	["gosha", "iron_ingot", 2, "Железо. Для дела."],
	["petya", "corn", 6, "Кукурузы для кур..."],
	["pasha", "carrot", 8, "...и морковки для коз."],
	["ingrid", "cloudberry_jam", 1, "Банку варенья из морошки. Для точных расчётов."],
	["vera", "aloe", 4, "Алоэ для мазей. Свежее."],
	["timur", "roasted_coffee", 2, "КОФЕ! Жареный. Два. Я не кричу."],
	["lyova", "mango", 4, "Манго для команды. Помнишь, как я их таскал с Баньяна?"],
	["kesha", "banana", 5, "Кешью показывает на гроздь бананов и на свой живот. По очереди."],
	["marta", "cheese", 2, "Козьего сыра к ужину."],
	["renata", "wool", 3, "Шерсти на одеяла: ночи у моря свежие."],
]

var visual: Node3D


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("order_board")
	collision_layer = 4
	visual = Models.glb("order_board")
	if visual:
		add_child(visual)
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(1.8, 2.2, 0.4)
	cs.shape = b
	cs.position.y = 1.1
	add_child(cs)


## Сегодняшние заказы: индексы в POOL (одни и те же весь день).
static func today() -> Array:
	var g := RandomNumberGenerator.new()
	g.seed = Game.day * 7919 + 13
	var out := []
	while out.size() < 3:
		var i := g.randi_range(0, POOL.size() - 1)
		if not i in out:
			out.append(i)
	return out


static func reward(i: int) -> int:
	var o: Array = POOL[i]
	return int(ceil(Data.SELL_PRICES.get(o[1], 3) * int(o[2]) * 1.8)) + 5


static func done(i: int) -> bool:
	if int(Game.flags.get("orders_day", -1)) != Game.day:
		return false
	var d: Dictionary = Game.flags.get("orders_done", {})
	return d.has(str(i))


## Выполнить заказ: отдать предметы, получить монеты и спасибо.
static func fulfil(i: int) -> bool:
	var o: Array = POOL[i]
	if done(i) or Game.count(o[1]) < int(o[2]):
		return false
	Game.pay({o[1]: int(o[2])})
	if int(Game.flags.get("orders_day", -1)) != Game.day:
		Game.flags["orders_day"] = Game.day
		Game.flags["orders_done"] = {}
	var d: Dictionary = Game.flags["orders_done"]
	d[str(i)] = true
	Game.add_item("coins", reward(i), false)
	Game.bump("orders", "any")
	Audio.play("quest", -6.0, 0.1)
	var who: String = o[0]
	var thanks: String = "Спасибо! Выручил." if who != "kesha" else "Кешью обнимает бананы и тебя. Тебя — чуть меньше."
	Game.dialogue_requested.emit([["narrator" if who == "kesha" else who, thanks]], Callable())
	return true


func interact_point() -> Vector3:
	return global_position + Vector3(0, 1.2, 0)


func tool_hint() -> String:
	return ""


func get_hint() -> String:
	var left := 0
	for i in today():
		if not done(i):
			left += 1
	return "Доска заказов — %s" % ("сегодня ещё %d" % left if left > 0 else "на сегодня всё выполнено, завтра будут новые")


func interact(_player: Node) -> void:
	var opts := []
	for i in today():
		var o: Array = POOL[i]
		var who: String = Data.SPEAKERS.get(o[0], {}).get("name", "Кешью") if o[0] != "kesha" else "Обезьянка Кешью"
		var idx: int = i
		if done(i):
			opts.append({"text": "✓ %s — выполнено" % who, "icon": "portrait_" + str(o[0]), "callback": func(): pass})
			continue
		var have := Game.count(o[1])
		var text := "%s: «%s»  %s ×%d (есть %d) — %d мон." % [who, o[3], Game.item_name(o[1]), int(o[2]), have, reward(i)]
		opts.append({"text": text, "icon": o[1], "callback": func():
			if not fulfil(idx):
				Game.notified.emit("Не хватает: %s" % Game.item_name(POOL[idx][1]), Color("ff9d7a"))})
	Game.choice_requested.emit("Доска заказов (каждое утро — новые)", opts)
