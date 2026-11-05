extends Node
## Глобальное состояние игры (autoload "Game").
## Здесь описаны все предметы, рецепты, постройки и задания — баланс правится в одном месте.

signal inventory_changed
signal energy_changed(value: float, max_value: float)
signal notified(text: String, color: Color)
signal quest_changed
signal time_changed(time_of_day: float, day: int)

const SAVE_PATH := "user://save.json"

# ---------------------------------------------------------------- Предметы
const ITEMS := {
	"wood": {"name": "Древесина", "short": "Дерево", "color": Color("a0703c")},
	"stone": {"name": "Камень", "short": "Камень", "color": Color("9aa0a6")},
	"fiber": {"name": "Волокно", "short": "Волокно", "color": Color("9bc25b")},
	"leaf": {"name": "Пальмовый лист", "short": "Листья", "color": Color("3f9f4a")},
	"coconut": {"name": "Кокос", "short": "Кокос", "color": Color("7b5230"), "food": 12},
	"baked_coconut": {"name": "Печёный кокос", "short": "Печ. кокос", "color": Color("c7843d"), "food": 30},
	"rope": {"name": "Верёвка", "short": "Верёвка", "color": Color("d4b483")},
	"plank": {"name": "Доска", "short": "Доска", "color": Color("c8955a")},
	"shell": {"name": "Ракушка", "short": "Ракушка", "color": Color("f4c6c0")},
	"stone_axe": {"name": "Каменный топор", "short": "Топор", "color": Color("6d8fa8"), "tool": true},
	"pickaxe": {"name": "Кирка", "short": "Кирка", "color": Color("8a7f9e"), "tool": true},
}

# ---------------------------------------------------------------- Рецепты
# station: "" — крафт в руках, иначе нужно стоять рядом с постройкой этого типа.
const RECIPES := [
	{"id": "rope", "out": {"rope": 1}, "in": {"fiber": 3}, "station": ""},
	{"id": "stone_axe", "out": {"stone_axe": 1}, "in": {"wood": 2, "stone": 2, "rope": 1}, "station": ""},
	{"id": "plank", "out": {"plank": 2}, "in": {"wood": 2}, "station": "workbench"},
	{"id": "pickaxe", "out": {"pickaxe": 1}, "in": {"plank": 2, "stone": 3, "rope": 2}, "station": "workbench"},
	{"id": "baked_coconut", "out": {"baked_coconut": 1}, "in": {"coconut": 1}, "station": "campfire"},
]

# ---------------------------------------------------------------- Постройки
const BUILDINGS := {
	"campfire": {"name": "Костёр", "cost": {"wood": 3, "stone": 3}, "radius": 0.9,
		"desc": "Свет ночью и готовка еды."},
	"torch": {"name": "Факел", "cost": {"wood": 1, "fiber": 2}, "radius": 0.35,
		"desc": "Освещает тропинки."},
	"workbench": {"name": "Верстак", "cost": {"wood": 6, "stone": 2, "rope": 1}, "radius": 1.1,
		"desc": "Доски и сложные инструменты."},
	"hut": {"name": "Хижина", "cost": {"plank": 8, "leaf": 10, "rope": 4}, "radius": 2.0,
		"desc": "Сон до утра восстанавливает силы."},
	"shell_deco": {"name": "Ракушечная клумба", "cost": {"shell": 4, "stone": 2}, "radius": 0.6,
		"desc": "Просто красиво."},
	"raft": {"name": "Плот", "cost": {"plank": 10, "rope": 6, "leaf": 4}, "radius": 1.8, "shore": true,
		"desc": "Строится у кромки воды. Путь к новым островам!"},
}

# ---------------------------------------------------------------- Задания (обучение)
# kind: collected / crafted / built — считаются по общей статистике.
const QUESTS := [
	{"text": "Собери волокно в кустах", "kind": "collected", "target": "fiber", "count": 3},
	{"text": "Сплети верёвку (меню крафта — C)", "kind": "crafted", "target": "rope", "count": 1},
	{"text": "Подбери камни на пляже", "kind": "collected", "target": "stone", "count": 2},
	{"text": "Собери плавник на берегу", "kind": "collected", "target": "wood", "count": 2},
	{"text": "Смастери каменный топор", "kind": "crafted", "target": "stone_axe", "count": 1},
	{"text": "Наруби древесины", "kind": "collected", "target": "wood", "count": 12},
	{"text": "Построй костёр (меню строительства — B)", "kind": "built", "target": "campfire", "count": 1},
	{"text": "Построй верстак", "kind": "built", "target": "workbench", "count": 1},
	{"text": "Сделай доски на верстаке", "kind": "crafted", "target": "plank", "count": 10},
	{"text": "Смастери кирку", "kind": "crafted", "target": "pickaxe", "count": 1},
	{"text": "Построй хижину", "kind": "built", "target": "hut", "count": 1},
	{"text": "Построй плот у воды", "kind": "built", "target": "raft", "count": 1},
	{"text": "Отправляйся в плавание!", "kind": "sailed", "target": "raft", "count": 1},
]

# ---------------------------------------------------------------- Время и энергия
const DAY_LENGTH := 480.0  # секунд на полные сутки (ночь идёт вдвое быстрее)
const MAX_ENERGY := 50.0
const ENERGY_REGEN_TIME := 4.0  # секунд на 1 единицу энергии

var inventory: Dictionary = {}
var stats: Dictionary = {"collected": {}, "crafted": {}, "built": {}, "sailed": {}}
var quest_index: int = 0
var energy: float = MAX_ENERGY
var time_of_day: float = 0.3  # 0..1, 0.5 — полдень
var day: int = 1
var _regen_acc := 0.0


func _ready() -> void:
	_setup_input()


func _process(delta: float) -> void:
	var speed := 1.0 if is_day() else 2.0
	time_of_day += delta / DAY_LENGTH * speed
	if time_of_day >= 1.0:
		time_of_day -= 1.0
		day += 1
	time_changed.emit(time_of_day, day)

	if energy < MAX_ENERGY:
		_regen_acc += delta
		if _regen_acc >= ENERGY_REGEN_TIME:
			_regen_acc = 0.0
			add_energy(1)


func is_day() -> bool:
	return time_of_day > 0.23 and time_of_day < 0.77


func clock_text() -> String:
	var minutes := int(time_of_day * 24.0 * 60.0)
	return "День %d · %02d:%02d" % [day, minutes / 60, minutes % 60]


# ---------------------------------------------------------------- Инвентарь
func item_name(id: String) -> String:
	return ITEMS.get(id, {}).get("name", id)


func item_short(id: String) -> String:
	return ITEMS.get(id, {}).get("short", item_name(id))


func count(id: String) -> int:
	return inventory.get(id, 0)


func has_tool(id: String) -> bool:
	return count(id) > 0


func add_item(id: String, amount: int = 1, track := true) -> void:
	inventory[id] = count(id) + amount
	if track:
		_bump("collected", id, amount)
	inventory_changed.emit()
	notified.emit("+%d %s" % [amount, item_name(id)], ITEMS.get(id, {}).get("color", Color.WHITE))


func can_afford(cost: Dictionary) -> bool:
	for id in cost:
		if count(id) < cost[id]:
			return false
	return true


func pay(cost: Dictionary) -> bool:
	if not can_afford(cost):
		return false
	for id in cost:
		inventory[id] = count(id) - cost[id]
		if inventory[id] <= 0:
			inventory.erase(id)
	inventory_changed.emit()
	return true


func craft(recipe: Dictionary) -> bool:
	if not pay(recipe["in"]):
		return false
	for id in recipe["out"]:
		inventory[id] = count(id) + recipe["out"][id]
		_bump("crafted", id, recipe["out"][id])
		notified.emit("Создано: %s ×%d" % [item_name(id), recipe["out"][id]], Color("ffe08a"))
	inventory_changed.emit()
	return true


func eat_best_food() -> bool:
	var best := ""
	for id in ITEMS:
		if ITEMS[id].has("food") and count(id) > 0:
			if best == "" or ITEMS[id]["food"] > ITEMS[best]["food"]:
				best = id
	if best == "":
		notified.emit("Нечего есть — потряси пальму!", Color("ff9d7a"))
		return false
	pay({best: 1})
	add_energy(ITEMS[best]["food"])
	notified.emit("Съеден %s (+%d энергии)" % [item_name(best).to_lower(), ITEMS[best]["food"]], Color("ffe08a"))
	return true


# ---------------------------------------------------------------- Энергия
func use_energy(amount: float) -> bool:
	if energy < amount:
		notified.emit("Нет сил! Съешь что-нибудь (Q) или поспи в хижине.", Color("ff9d7a"))
		return false
	energy -= amount
	energy_changed.emit(energy, MAX_ENERGY)
	return true


func add_energy(amount: float) -> void:
	energy = min(MAX_ENERGY, energy + amount)
	energy_changed.emit(energy, MAX_ENERGY)


# ---------------------------------------------------------------- Статистика и задания
func _bump(kind: String, id: String, amount: int) -> void:
	var d: Dictionary = stats[kind]
	d[id] = d.get(id, 0) + amount
	_check_quests()


func register_built(id: String) -> void:
	_bump("built", id, 1)


func register_sailed() -> void:
	_bump("sailed", "raft", 1)


func current_quest() -> Dictionary:
	if quest_index < QUESTS.size():
		return QUESTS[quest_index]
	return {}


func quest_progress() -> int:
	var q := current_quest()
	if q.is_empty():
		return 0
	return min(stats[q["kind"]].get(q["target"], 0), q["count"])


func _check_quests() -> void:
	var changed := false
	while quest_index < QUESTS.size():
		var q: Dictionary = QUESTS[quest_index]
		if stats[q["kind"]].get(q["target"], 0) >= q["count"]:
			notified.emit("Задание выполнено: %s" % q["text"], Color("8affa0"))
			quest_index += 1
			changed = true
		else:
			break
	quest_changed.emit()
	if changed:
		pass


# ---------------------------------------------------------------- Сохранение
func save_game(extra: Dictionary) -> void:
	var data := {
		"version": 1,
		"inventory": inventory,
		"stats": stats,
		"quest_index": quest_index,
		"energy": energy,
		"time_of_day": time_of_day,
		"day": day,
	}
	data.merge(extra)
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))
		notified.emit("Игра сохранена", Color("bfe3ff"))


func load_game() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return {}
	inventory = {}
	for k in data.get("inventory", {}):
		inventory[k] = int(data["inventory"][k])
	stats = {"collected": {}, "crafted": {}, "built": {}, "sailed": {}}
	var s: Dictionary = data.get("stats", {})
	for kind in stats:
		for k in s.get(kind, {}):
			stats[kind][k] = int(s[kind][k])
	quest_index = int(data.get("quest_index", 0))
	energy = float(data.get("energy", MAX_ENERGY))
	time_of_day = float(data.get("time_of_day", 0.3))
	day = int(data.get("day", 1))
	inventory_changed.emit()
	quest_changed.emit()
	energy_changed.emit(energy, MAX_ENERGY)
	return data


func reset() -> void:
	inventory = {}
	stats = {"collected": {}, "crafted": {}, "built": {}, "sailed": {}}
	quest_index = 0
	energy = MAX_ENERGY
	time_of_day = 0.3
	day = 1
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


# ---------------------------------------------------------------- Управление
func _setup_input() -> void:
	var keys := {
		"move_forward": [KEY_W, KEY_UP],
		"move_back": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"jump": [KEY_SPACE],
		"sprint": [KEY_SHIFT],
		"interact": [KEY_E],
		"eat": [KEY_Q],
		"craft_menu": [KEY_C],
		"build_menu": [KEY_B],
		"rotate_build": [KEY_R],
		"help": [KEY_F1, KEY_H],
		"save": [KEY_F5],
		"load": [KEY_F9],
		"new_game": [KEY_F10],
	}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for k in keys[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)
	if not InputMap.has_action("attack"):
		InputMap.add_action("attack")
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("attack", mb)
