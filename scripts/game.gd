extends Node
## Глобальное состояние игры (autoload "Game"): инвентарь, задания, открытия, коллекции, время, сохранения.
## Сами данные (предметы, рецепты, задания) — в data.gd.

signal inventory_changed
signal notified(text: String, color: Color)
signal quest_changed
signal quest_completed(quest: Dictionary)
signal dialogue_requested(lines: Array, on_done: Callable)
signal collection_changed(col_id: String, item_id: String, is_new: bool)
signal time_changed(time_of_day: float, day: int)

const SAVE_PATH := "user://save.json"
const SETTINGS_PATH := "user://settings.cfg"
const DEFAULT_SETTINGS := {"music": 0.6, "sfx": 0.8, "ambience": 0.7, "mouse": 1.0,
	"shadows": 2, "msaa": 2, "fullscreen": false, "vsync": true}
const DAY_LENGTH := 600.0  # секунд на сутки (ночь идёт вдвое быстрее)

var inventory: Dictionary = {}
var stats: Dictionary = {}
var unlocked: Dictionary = {}          # id постройки/рецепта -> true
var collections: Dictionary = {}       # col_id -> {item_id: count}
var chapter := 0
var quest_index := 0
var quest_baseline: Dictionary = {}    # "kind:target" -> значение статистики при старте задания
var quest_started := false             # показано ли вступление
var flags: Dictionary = {}             # разные одноразовые события
var time_of_day := 0.3
var day := 1
var world_time := 0.0                  # секунды игрового мира (растения растут по нему)
var settings: Dictionary = DEFAULT_SETTINGS.duplicate()
var skip_menu := false                 # true — после перезагрузки сразу в игру, без главного меню


func _ready() -> void:
	_setup_input()
	reset_state()
	load_settings()
	apply_display()


# ======================================================================= Настройки
func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		for k in DEFAULT_SETTINGS:
			settings[k] = cfg.get_value("settings", k, DEFAULT_SETTINGS[k])


func save_settings() -> void:
	var cfg := ConfigFile.new()
	for k in settings:
		cfg.set_value("settings", k, settings[k])
	cfg.save(SETTINGS_PATH)


func apply_display() -> void:
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if settings["fullscreen"] else DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if settings["vsync"] else DisplayServer.VSYNC_DISABLED)
	get_viewport().msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][int(settings["msaa"])]
	RenderingServer.directional_shadow_atlas_set_size([1024, 2048, 4096][int(settings["shadows"])], true)


func _process(delta: float) -> void:
	var speed := 1.0 if is_day() else 2.0
	time_of_day += delta / DAY_LENGTH * speed
	world_time += delta
	if time_of_day >= 1.0:
		time_of_day -= 1.0
		day += 1
	time_changed.emit(time_of_day, day)


func is_day() -> bool:
	return time_of_day > 0.23 and time_of_day < 0.77


func clock_text() -> String:
	var minutes := int(time_of_day * 24.0 * 60.0)
	return "День %d · %02d:%02d" % [day, minutes / 60, minutes % 60]


## Пропустить время до утра (сон). Растения и животные "проживают" это время.
func sleep_until_morning() -> void:
	var target := 0.27
	var delta_days := target - time_of_day
	if delta_days <= 0.0:
		delta_days += 1.0
		day += 1
	world_time += delta_days * DAY_LENGTH * 0.6
	time_of_day = target


# ======================================================================= Инвентарь
func item(id: String) -> Dictionary:
	return Data.ITEMS.get(id, {})


func item_name(id: String) -> String:
	return item(id).get("name", id)


func item_short(id: String) -> String:
	return item(id).get("short", item_name(id))


func count(id: String) -> int:
	return inventory.get(id, 0)


func has_tool(id: String) -> bool:
	return count(id) > 0


func add_item(id: String, amount: int = 1, track := true, quiet := false) -> void:
	if amount <= 0:
		return
	inventory[id] = count(id) + amount
	inventory_changed.emit()
	if not quiet:
		notified.emit("+%d %s" % [amount, item_name(id)], item(id).get("color", Color.WHITE))
		Audio.play("pickup", -6.0, 0.15)
	if track:
		bump("collected", id, amount)


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


func is_unlocked(id: String, def: Dictionary) -> bool:
	return not def.get("unlock", false) or unlocked.has(id)


func recipe_unlocked(r: Dictionary) -> bool:
	return is_unlocked(r["id"], r)


func craft(recipe: Dictionary) -> bool:
	if not recipe_unlocked(recipe) or not pay(recipe["in"]):
		return false
	Audio.play("craft", -3.0)
	for id in recipe["out"]:
		inventory[id] = count(id) + recipe["out"][id]
		notified.emit("Создано: %s ×%d" % [item_name(id), recipe["out"][id]], Color("ffe08a"))
		inventory_changed.emit()
		bump("crafted", id, recipe["out"][id])
	return true


# ======================================================================= Коллекции
func add_collectible(col_id: String) -> bool:
	var col: Dictionary = Data.COLLECTIONS[col_id]
	var have: Dictionary = collections.get(col_id, {})
	var idx := 0
	if col.get("ordered", false):
		# страницы журнала — строго по порядку и без повторов
		idx = -1
		for i in col["items"].size():
			if not have.has(col["items"][i]["id"]):
				idx = i
				break
		if idx < 0:
			return false
	else:
		# редкие предметы (последние в списке) выпадают реже
		var weights: Array[float] = []
		var total := 0.0
		for i in col["items"].size():
			var w: float = 1.0 / (1.0 + i * 0.8)
			weights.append(w)
			total += w
		var r := randf() * total
		for i in weights.size():
			r -= weights[i]
			if r <= 0.0:
				idx = i
				break
	var it: Dictionary = col["items"][idx]
	var is_new: bool = not have.has(it["id"])
	have[it["id"]] = have.get(it["id"], 0) + 1
	collections[col_id] = have
	notified.emit("%s: %s%s" % [col["name"], it["name"], " (новое!)" if is_new else ""], it["color"])
	collection_changed.emit(col_id, it["id"], is_new)
	Audio.play("rare" if is_new else "pickup", -3.0)
	if it.has("text"):
		dialogue_requested.emit([["journal", it["text"]]], Callable())
	if is_new:
		bump("collection", col_id)
	if is_new and collection_complete(col_id) and not flags.has("col_" + col_id):
		flags["col_" + col_id] = true
		_grant(col["reward"])
		notified.emit("Коллекция «%s» собрана!" % col["name"], Color("8affa0"))
	return is_new


func journal_incomplete() -> bool:
	return not collection_complete("journal")


func collection_complete(col_id: String) -> bool:
	var have: Dictionary = collections.get(col_id, {})
	for it in Data.COLLECTIONS[col_id]["items"]:
		if not have.has(it["id"]):
			return false
	return true


# ======================================================================= Задания
func bump(kind: String, target: String, amount: int = 1) -> void:
	var d: Dictionary = stats.get(kind, {})
	d[target] = d.get(target, 0) + amount
	stats[kind] = d
	_check_quest()


func stat(kind: String, target: String) -> int:
	return stats.get(kind, {}).get(target, 0)


func current_chapter() -> Dictionary:
	return Data.CHAPTERS[min(chapter, Data.CHAPTERS.size() - 1)]


func current_quest() -> Dictionary:
	var qs: Array = current_chapter()["quests"]
	if chapter < Data.CHAPTERS.size() and quest_index < qs.size():
		return qs[quest_index]
	return {}


func task_progress(task: Dictionary) -> int:
	var key: String = task["kind"] + ":" + task["target"]
	var base: int = quest_baseline.get(key, 0)
	return clampi(stat(task["kind"], task["target"]) - base, 0, task["count"])


func quest_done(q: Dictionary) -> bool:
	for t in q["tasks"]:
		if task_progress(t) < t["count"]:
			return false
	return true


## Показать вступление текущего задания (если ещё не показано) и начать отсчёт.
func start_current_quest() -> void:
	var q := current_quest()
	if q.is_empty() or quest_started:
		return
	quest_started = true
	quest_baseline = {}
	for t in q["tasks"]:
		var key: String = t["kind"] + ":" + t["target"]
		# постройки и разговоры считаем с нуля, ресурсы — от момента получения задания
		quest_baseline[key] = 0 if t["kind"] in ["talk", "built", "sailed", "collection"] else stat(t["kind"], t["target"])
	quest_changed.emit()
	dialogue_requested.emit(q.get("intro", []), func(): _check_quest())


func _check_quest() -> void:
	var q := current_quest()
	quest_changed.emit()
	if q.is_empty() or not quest_started:
		return
	if quest_done(q):
		quest_started = false
		quest_index += 1
		_grant(q.get("reward", {}))
		quest_completed.emit(q)
		Audio.play("quest", -2.0, 0.0)
		notified.emit("Задание выполнено: %s" % q["title"], Color("8affa0"))
		quest_changed.emit()
		dialogue_requested.emit(q.get("outro", []), func(): start_current_quest())


func _grant(reward: Dictionary) -> void:
	for id in reward.get("unlock", []):
		unlocked[id] = true
		var b: Dictionary = Data.BUILDINGS.get(id, {})
		if not b.is_empty():
			notified.emit("Открыта постройка: %s" % b["name"], Color("bfe3ff"))
		else:
			for r in Data.RECIPES:
				if r["id"] == id:
					notified.emit("Новый рецепт: %s" % item_name(r["out"].keys()[0]), Color("bfe3ff"))
	for i in int(reward.get("pages", 0)):
		add_collectible("journal")
	var items: Dictionary = reward.get("items", {})
	for id in items:
		add_item(id, items[id], false)


# ======================================================================= Сохранение
func save_game(extra: Dictionary) -> void:
	var data := {
		"version": 2,
		"inventory": inventory, "stats": stats, "unlocked": unlocked.keys(),
		"collections": collections, "chapter": chapter, "quest_index": quest_index,
		"quest_baseline": quest_baseline, "quest_started": quest_started, "flags": flags,
		"time_of_day": time_of_day, "day": day, "world_time": world_time,
	}
	data.merge(extra)
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))
		notified.emit("Игра сохранена", Color("bfe3ff"))


func _int_dict(d) -> Dictionary:
	var out := {}
	if typeof(d) == TYPE_DICTIONARY:
		for k in d:
			out[k] = int(d[k])
	return out


func load_game() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY or int(data.get("version", 0)) < 2:
		return {}
	inventory = _int_dict(data.get("inventory", {}))
	stats = {}
	var s: Dictionary = data.get("stats", {})
	for kind in s:
		stats[kind] = _int_dict(s[kind])
	unlocked = {}
	for id in data.get("unlocked", []):
		unlocked[id] = true
	collections = {}
	var c: Dictionary = data.get("collections", {})
	for k in c:
		collections[k] = _int_dict(c[k])
	chapter = int(data.get("chapter", 0))
	quest_index = int(data.get("quest_index", 0))
	quest_baseline = _int_dict(data.get("quest_baseline", {}))
	quest_started = bool(data.get("quest_started", false))
	flags = data.get("flags", {})
	time_of_day = float(data.get("time_of_day", 0.3))
	day = int(data.get("day", 1))
	world_time = float(data.get("world_time", 0.0))
	inventory_changed.emit()
	quest_changed.emit()
	return data


func reset_state() -> void:
	inventory = {}
	stats = {}
	unlocked = {}
	collections = {}
	chapter = 0
	quest_index = 0
	quest_baseline = {}
	quest_started = false
	flags = {}
	time_of_day = 0.3
	day = 1
	world_time = 0.0


func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


# ======================================================================= Управление
func _setup_input() -> void:
	var keys := {
		"move_forward": [KEY_W, KEY_UP], "move_back": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"jump": [KEY_SPACE], "sprint": [KEY_SHIFT], "interact": [KEY_E],
		"craft_menu": [KEY_C], "build_menu": [KEY_B], "rotate_build": [KEY_R],
		"inventory": [KEY_TAB, KEY_I], "journal": [KEY_J], "collections": [KEY_K],
		"help": [KEY_F1, KEY_H], "save": [KEY_F5], "load": [KEY_F9],
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
