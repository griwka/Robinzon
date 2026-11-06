extends Node
## Глобальное состояние игры (autoload "Game"): инвентарь, задания, открытия, коллекции, время, сохранения.
## Сами данные (предметы, рецепты, задания) — в data.gd.

signal inventory_changed
signal item_gained(id: String, amount: int)   # предмет попал в сумку (для всплывающего значка)
signal notified(text: String, color: Color)
signal quest_changed
signal quest_completed(quest: Dictionary)
signal dialogue_requested(lines: Array, on_done: Callable)
signal collection_changed(col_id: String, item_id: String, is_new: bool)
signal time_changed(time_of_day: float, day: int)
signal shop_requested(shop_id: String)
signal choice_requested(title: String, options: Array)

const SAVE_PATH := "user://save.json"
## Куда сохраняется игра. Автотесты, проверка и скриншоты пишут в отдельный файл и никогда
## не трогают сохранение игрока (у exe и у проекта папка сохранений общая).
var save_path := SAVE_PATH
const SAVE_VERSION := 4
const SETTINGS_PATH := "user://settings.cfg"
const DEFAULT_SETTINGS := {"music": 0.6, "sfx": 0.8, "ambience": 0.7, "mouse": 1.0,
	"shadows": 2, "msaa": 2, "fullscreen": false, "vsync": true, "sharpen": 1, "effects": 2, "shake": true, "endings": ""}
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
var cleared: Dictionary = {}           # номера расчищенных преград (заросли, деревья, гряды)
var location := "home"                 # остров, на котором сейчас игрок
var loc_data: Dictionary = {}          # остров -> {buildings, player} для островов, где мы уже бывали
var time_of_day := 0.3
var day := 1
var world_time := 0.0                  # секунды игрового мира (растения растут по нему)
var settings: Dictionary = DEFAULT_SETTINGS.duplicate()
var skip_menu := false                 # true — после перезагрузки сразу в игру, без главного меню
var storm := 0.0                       # сила грозы 0..1 (задаёт погода на Грозовом острове, не сохраняется)
var storm_force := false               # для автотеста: гроза «идёт» всегда
var warmth := 100.0                    # тепло героя 0..100 (Ледяной остров до оттепели; не сохраняется)
var warm_tea := 0.0                    # сколько секунд ещё греет выпитый чай
var heat := 0.0                        # жар героя 0..100 у лавы (Остров Вулкана; не сохраняется)
var salve_t := 0.0                     # сколько секунд ещё действует мазь от ожогов


## Холодно ли там, где сейчас герой: Ледяной остров, пока не зажжено Холодное сердце.
func cold_active() -> bool:
	return location == "ice" and not flags.get("ice_thawed", false)


## Во сколько раз быстрее остываешь — зависит от одежды (её носят, если она есть в сумке).
func cold_mult() -> float:
	var m := 3.0
	if has_tool("down_jacket"):
		m = 1.0
	elif has_tool("sweater"):
		m = 2.0
	if has_tool("felt_boots") and has_tool("mittens"):
		m *= 0.6
	return m


## Замёрз: тепло кончилось — идёшь медленно, не лазаешь, инструменты не держатся в руках.
func frozen() -> bool:
	return cold_active() and warmth <= 0.0


## Ночь ли сейчас для плавания в туман (с 20:00 до 4:00).
func fog_hours() -> bool:
	return time_of_day > 0.83 or time_of_day < 0.17


## Прибытие на остров (после плавания): пассажиры сходят на берег.
func arrive(loc: String) -> void:
	if loc == "fog" and flags.get("stepa_aboard", false):
		flags.erase("stepa_aboard")
		flags["stepa_at_fog"] = true
		notified.emit("Стёпа сходит на мостки лагеря", Color("ffe08a"))


## Подождать до темноты (у телескопа, у причала перед туманом): время идёт, растения растут.
func wait_until_night(target := 0.82) -> void:
	var delta_days := target - time_of_day
	if delta_days <= 0.0:
		return
	world_time += delta_days * DAY_LENGTH
	time_of_day = target


## Финал уже выбран (глава 8): дальше — «вечная игра».
func ended() -> bool:
	return flags.get("ending_open_sea", false) or flags.get("ending_keeper", false)


## После финала «Открытое море» приходят торговые корабли: урожай и продукты стоят дороже.
func sell_mult() -> float:
	return 1.5 if flags.get("ending_open_sea", false) else 1.0


## «День щедрости» (финал «Хранитель огня»): сегодня Хранитель зажёг лучи — урожай вдвое больше.
func bounty_today() -> bool:
	return flags.get("ending_keeper", false) and int(flags.get("bounty_day", -1)) == day


## Окно в шторме открыто сегодня: у причала дома стоит корабль Лёвы.
func window_open() -> bool:
	return flags.get("ending_keeper", false) and int(flags.get("window_day", -1)) == day


## Идёт ли сейчас гроза (молнии бьют, громоотводы заряжаются, лазать нельзя).
func storm_active() -> bool:
	return storm_force or storm > 0.5


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a in ["--autotest", "--validate", "--gallery"] or a.begins_with("--shot=") or a.begins_with("--gallery="):
			save_path = "user://save_dev.json"
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
		item_gained.emit(id, amount)
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
	Audio.play("hammer" if recipe["station"] == "forge" else "craft", -3.0)
	for id in recipe["out"]:
		inventory[id] = count(id) + recipe["out"][id]
		inventory_changed.emit()
		if recipe["in"].has(id):
			continue   # приспособление (тигель) вернулось в сумку — это не новая вещь
		notified.emit("Создано: %s ×%d" % [item_name(id), recipe["out"][id]], Color("ffe08a"))
		bump("crafted", id, recipe["out"][id])
	return true


# ======================================================================= Торговля
func shop_open(shop_id: String) -> bool:
	return unlocked.has("shop_" + shop_id)


func shop_items(shop_id: String) -> Array:
	var out := []
	for e in Data.SHOPS[shop_id]["buy"]:
		if not e.has("unlock") or unlocked.has(e["unlock"]):
			out.append(e)
	return out


func buy(shop_id: String, id: String, price: int) -> bool:
	if count("coins") < price:
		notified.emit("Не хватает монет: нужно %d" % price, Color("ff9d7a"))
		return false
	pay({"coins": price})
	add_item(id, 1, false, true)
	notified.emit("Куплено: %s" % item_name(id), Color("ffe08a"))
	Audio.play("pickup", -3.0)
	bump("bought", id)
	bump("bought", "any")
	return true


## Сколько штук можно продать: всё, кроме отложенного для задания.
func sellable(id: String) -> int:
	return maxi(0, count(id) - reserved(id))


func sell(shop_id: String, id: String, n := 1) -> void:
	n = mini(n, sellable(id))
	if n <= 0 or not Data.SELL_PRICES.has(id):
		return
	pay({id: n})
	var got := int(round(Data.SELL_PRICES[id] * n * sell_mult()))
	add_item("coins", got, false, true)
	notified.emit("Продано: %s ×%d  +%d мон." % [item_name(id), n, got], Color("f3e2b8"))
	Audio.play("pickup", -3.0, 0.1)
	bump("sold", shop_id, n)
	bump("sold", "any", n)


# ======================================================================= Еда
## Съесть самое сытное. Возвращает сытность (0 — нечего есть). Еда восстанавливает силы при лазании.
func eat_best_food() -> int:
	var best := ""
	for id in Data.ITEMS:
		if Data.ITEMS[id].has("food") and count(id) - reserved(id) > 0:
			if best == "" or Data.ITEMS[id]["food"] > Data.ITEMS[best]["food"]:
				best = id
	if best == "":
		notified.emit("Нечего есть (то, что нужно для задания, не трогаю) — потряси пальму или банан!", Color("ff9d7a"))
		return 0
	pay({best: 1})
	var v: int = Data.ITEMS[best]["food"]
	notified.emit("Съеден %s: +%d сил" % [item_name(best).to_lower(), v * 2], Color("ffe08a"))
	Audio.play("pickup", -4.0)
	return v


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
## Учесть событие для заданий. Счётчик ведётся и в целом, и отдельно по острову (target@остров).
func bump(kind: String, target: String, amount: int = 1) -> void:
	var d: Dictionary = stats.get(kind, {})
	d[target] = d.get(target, 0) + amount
	var at := target + "@" + location
	d[at] = d.get(at, 0) + amount
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


## Отдать предметы, которые просит текущее задание (например, еду для Марты). Возвращает, что-то отдали ли.
func deliver_for_quest(to := "") -> bool:
	var q := current_quest()
	if q.is_empty() or not quest_started:
		return false
	var gave := false
	for t in q["tasks"]:
		if t["kind"] != "delivered" or (to != "" and t.get("to", to) != to):
			continue
		while task_progress(t) < t["count"] and count(t["target"]) > 0:
			pay({t["target"]: 1})
			notified.emit("Отдано: %s" % item_name(t["target"]), Color("ffe08a"))
			bump("delivered", t["target"])
			gave = true
	return gave


## Сколько штук предмета нужно отложить для текущего задания (не продавать и не съедать).
func reserved(id: String) -> int:
	var q := current_quest()
	if q.is_empty() or not quest_started:
		return 0
	var need := 0
	for t in q["tasks"]:
		if t["kind"] == "delivered" and t["target"] == id:
			need += t["count"] - task_progress(t)
	return need


# Разовые события считаем с нуля (сделал раньше — тоже засчитано), повторяемые — от начала задания.
# cleared — тоже с нуля: преграды конечны, игрок мог расчистить их заранее.
const ZERO_BASE_KINDS := ["talk", "built", "sailed", "collection", "found", "lit", "reached", "bought", "restored", "delivered", "cleared", "solved", "chose"]


func _task_target(task: Dictionary) -> String:
	return task["target"] + ("@" + task["where"] if task.has("where") else "")


func task_progress(task: Dictionary) -> int:
	var tgt := _task_target(task)
	var key: String = task["kind"] + ":" + tgt
	var base: int = quest_baseline.get(key, 0)
	var p := clampi(stat(task["kind"], tgt) - base, 0, task["count"])
	# инструмент уже есть (сделан раньше или подарен) — «смастери» засчитывается
	if task["kind"] in ["crafted", "collected", "bought"] and item(task["target"]).get("cat", "") in ["tool", "clothes"] and has_tool(task["target"]):
		p = task["count"]
	# «собери N» засчитывается и тем, что уже лежит в сумке (ресурс мог кончиться на острове раньше задания)
	if task["kind"] == "collected" and not task.has("where"):
		p = maxi(p, mini(count(task["target"]), task["count"]))
	return p


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
		var tgt := _task_target(t)
		var key: String = t["kind"] + ":" + tgt
		var zero: bool = t["kind"] in ZERO_BASE_KINDS and not t.get("fresh", false)
		quest_baseline[key] = 0 if zero else stat(t["kind"], tgt)
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
		if quest_index >= current_chapter()["quests"].size() and chapter + 1 < Data.CHAPTERS.size():
			chapter += 1
			quest_index = 0
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
		elif id.begins_with("buy_"):
			notified.emit("В лавке новый товар: %s" % item_name(id.substr(4)), Color("bfe3ff"))
		elif id.begins_with("shop_"):
			notified.emit("Открыта лавка: %s" % Data.SHOPS[id.substr(5)]["name"], Color("bfe3ff"))
		else:
			for r in Data.RECIPES:
				if r["id"] == id:
					notified.emit("Новый рецепт: %s" % item_name(r["out"].keys()[0]), Color("bfe3ff"))
	for f in reward.get("flags", []):
		flags[f] = true
	for i in int(reward.get("pages", 0)):
		add_collectible("journal")
	var col: Dictionary = reward.get("collect", {})
	for cid in col:
		for i in int(col[cid]):
			add_collectible(cid)
	var items: Dictionary = reward.get("items", {})
	for id in items:
		add_item(id, items[id], false)


# ======================================================================= Сохранение
func save_game(extra: Dictionary) -> void:
	var data := {
		"version": SAVE_VERSION,
		"inventory": inventory, "stats": stats, "unlocked": unlocked.keys(),
		"collections": collections, "chapter": chapter, "quest_index": quest_index,
		"quest_baseline": quest_baseline, "quest_started": quest_started, "flags": flags, "cleared": cleared.keys(),
		"time_of_day": time_of_day, "day": day, "world_time": world_time,
		"location": location,
	}
	# данные текущего острова кладём к остальным островам
	loc_data[location] = extra.duplicate()
	data["locations"] = loc_data
	var f := FileAccess.open(save_path, FileAccess.WRITE)
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
	if not FileAccess.file_exists(save_path):
		return {}
	var f := FileAccess.open(save_path, FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY or int(data.get("version", 0)) < SAVE_VERSION:
		return {}   # сохранение старой версии (другой сюжет) — начинаем заново
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
	cleared = {}
	for k in data.get("cleared", []):
		cleared[k] = true
	time_of_day = float(data.get("time_of_day", 0.3))
	day = int(data.get("day", 1))
	world_time = float(data.get("world_time", 0.0))
	location = data.get("location", "home")
	# глава дописана после того, как игрок её закончил: открываем следующую
	if quest_index >= Data.CHAPTERS[mini(chapter, Data.CHAPTERS.size() - 1)]["quests"].size() and chapter + 1 < Data.CHAPTERS.size():
		chapter += 1
		quest_index = 0
		quest_started = false
	if stat("built", "canoe") > 0:
		flags["fort_route"] = true   # сохранения до v0.7: каноэ уже есть — путь к форту открыт
	loc_data = data.get("locations", {})
	if loc_data.is_empty() and data.has("buildings"):
		loc_data["home"] = {"buildings": data["buildings"], "player": data.get("player", [])}
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
	cleared = {}
	location = "home"
	loc_data = {}
	time_of_day = 0.3
	day = 1
	world_time = 0.0


func delete_save() -> void:
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))


# ======================================================================= Управление
func _setup_input() -> void:
	var keys := {
		"move_forward": [KEY_W, KEY_UP], "move_back": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"jump": [KEY_SPACE], "sprint": [KEY_SHIFT], "interact": [KEY_E],
		"craft_menu": [KEY_C], "build_menu": [KEY_B], "rotate_build": [KEY_R],
		"inventory": [KEY_TAB, KEY_I], "journal": [KEY_J], "collections": [KEY_K],
		"help": [KEY_F1, KEY_H], "save": [KEY_F5], "load": [KEY_F9], "eat": [KEY_Q], "radio": [KEY_T],
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
