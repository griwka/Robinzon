class_name CozyLife
extends Node
## «Вечная игра» после финала: кулинария и уют лагеря. Узел живёт в главной сцене (его создаёт main.gd).
## Здесь: открытие нового после финала (и в старых сохранениях), время действия пользы от блюд,
## строка под часами (польза блюд и уют), окно котелка, счёт уюта, вечерние гости у костра.
##
## Уют — сумма очков украшений (Data.BUILDINGS[id]["cozy"] и OLD_COZY) в CAMP_R метрах от костра на острове крушения.
## Одинаковые вещи подряд дают всё меньше (REPEAT), так что лагерь выгоднее делать разным, а не ставить 30 факелов.
## Ступени уюта (LEVELS) дают мягкие бонусы: меньше голода за ночь, у костра быстрее возвращаются силы,
## вечером чаще заходят гости и чаще приносят подарок. Ничего не отнимается и ничто не торопит.

const CAMP_R := 14.0
## Прежние постройки тоже считаются.
const OLD_COZY := {"torch": 1, "fence": 1, "flowerbed": 2, "bench": 2, "hammock": 3, "scarecrow": 1, "shell_path": 1,
	"long_table": 3, "well": 2, "hut": 2, "cook_pot": 2}
const REPEAT := [1.0, 0.6, 0.35, 0.2]     # первая такая вещь, вторая, третья, четвёртая; дальше — REPEAT_REST
const REPEAT_REST := 0.1
const LEVELS := [0, 8, 20, 36, 56, 80]    # сколько очков нужно для ступени 0..5
const LEVEL_NAMES := ["Пусто", "Обжито", "Приятно", "Уютно", "Очень уютно", "Как дома"]
const LEVEL_NOTES := ["", "вечером к костру иногда заходят гости", "гости заходят чаще, за ночь меньше проголодаешься",
	"у костра силы возвращаются быстрее", "гости чаще приносят подарки", "гости приходят каждый вечер"]
const NIGHT_PER_LEVEL := 0.08             # за каждую ступень сытость за ночь тает на 8 % меньше
const REST_LEVEL := 3                     # с этой ступени у костра быстрее возвращаются силы
const REST_MULT := 1.15
const COME_CHANCE := [0.0, 0.5, 0.65, 0.8, 0.9, 1.0]     # придёт ли гость вечером — по ступени
const GIFT_BASE := 0.25                   # шанс подарка: GIFT_BASE + GIFT_PER_LEVEL × ступень
const GIFT_PER_LEVEL := 0.1
const GIFT_MAX_VALUE := 15                # подарок не дороже стольких монет по прейскуранту (проверяет валидатор)
const EVENING_FROM := 0.70                # гость приходит на закате…
const MORNING := 0.25                     # …и уходит утром

## Вечерние гости: по две реплики на выбор и маленькие подарки [предмет, сколько].
const GUESTS := {
	"marta": {"lines": [
			["Я на запах пришла. У тебя тут пахнет домом.", "Сиди, сиди. Я просто погреюсь и посмотрю, как ты живёшь."],
			["Хороший у тебя лагерь. Здесь хочется снять фартук.", "Знаешь, я три года готовила для огня. А теперь — для людей. Так лучше."]],
		"gifts": [["egg", 2], ["cheese", 1], ["seed_tomato", 2]]},
	"stepa": {"lines": [
			["Не думал, что скажу это. Но у тебя тут уютно.", "Я посижу. Молча. Это у меня так выглядит хорошее настроение."],
			["Костёр сложен правильно. Кто учил? Сам? Ну-ну.", "В форте по вечерам тихо. А тут тихо по-другому. По-хорошему."]],
		"gifts": [["fish", 2], ["rope", 2]]},
	"timur": {"lines": [
			["ПРИВЕТ! Ой. Привет. Я всё ещё учусь говорить тихо.", "У тебя тут так спокойно, что даже рация молчит. Я проверял."],
			["Я принёс новости: новостей нет. Это лучшие новости за три года.", "Можно я посижу у огня? У меня дома только лампочки."]],
		"gifts": [["coffee", 3], ["battery", 1]]},
	"ingrid": {"lines": [
			["Я шла по звёздам. Пришла к твоему костру. Звёзды не ошибаются.", "Здесь тепло. Я отмечу это место на карте. Словом «дом»."],
			["Сорок шагов от берега до костра. Я посчитала. Хорошее число.", "На севере ценят тех, кто держит огонь. У тебя получается."]],
		"gifts": [["cloudberry", 2], ["seed_cloudberry", 1]]},
	"vera": {"lines": [
			["Дай посмотрю на тебя. Ешь хорошо? Спишь? Ну вот и славно.", "Уютное место лечит не хуже трав. Это я тебе как врач говорю."],
			["Я ненадолго. Просто хотела увидеть, что у тебя всё хорошо.", "Цветы у тебя красивые. Не рви все на чай, оставь пчёлам."]],
		"gifts": [["aloe", 3], ["honey", 1]]},
	"renata": {"lines": [
			["Вахта кончилась. Можно я сяду к твоему огню?", "На корабле я всегда знала, где чьё место. Здесь место есть для всех."],
			["У тебя порядок. Я это уважаю.", "Капитан говорил: дом — это где тебя ждут с огнём. Он был прав."]],
		"gifts": [["wool", 1], ["candle", 2]]},
	"misha": {"lines": [
			["А можно к вам? Я тихо! Ну, почти тихо.", "У тебя фонарики! И коврик! Когда вырасту, сделаю себе такой же лагерь."],
			["Я нашёл на берегу кое-что. Это тебе. Нет, сначала посижу.", "Румба сказал, что у тебя самый лучший костёр. Румба не врёт."]],
		"gifts": [["shell", 3], ["banana", 3]]},
	"gosha": {"lines": [
			["...Можно?", "Хорошо сделано. Крепко."],
			["Шёл мимо.", "Посижу. Тут хорошо."]],
		"gifts": [["iron_nails", 5], ["plank", 3]]},
	"lyova": {"lines": [
			["Я в детстве строил шалаши, а ты их разбирал. Теперь ты строишь лучше меня.", "Посидим? Как раньше. Только без комаров и без мамы с ужином."],
			["Три года я смотрел на один огонь. А твой — совсем другой. Тёплый.", "Спасибо, что приплыл за мной. Я, кажется, ещё не говорил это вслух."]],
		"gifts": [["mango", 2], ["seed_watermelon", 1]]},
}

static var level_now := 0        # ступень уюта лагеря сейчас (остров крушения)
static var score_now := 0
static var resting := false      # герой у костра в уютном лагере

var main: Node            # главная сцена (Main)
var cook_ui: CookUI
var _buff_label: Label
var _cozy_label: Label
var _check_t := 0.0
var _guest: CampGuest


func _ready() -> void:
	add_to_group("cozy_life")
	var wl := WorldLife.new()      # находки с моря, знаки на камнях, редкие существа
	wl.main = main
	add_child(wl)
	level_now = 0
	score_now = 0
	resting = false
	migrate()


func hud() -> HUD:
	return main.get("hud") as HUD if main else null


func _process(delta: float) -> void:
	if Game.playing and not get_tree().paused:
		Cooking.tick(delta)
	_check_t -= delta
	if _check_t <= 0.0:
		_check_t = 1.0
		migrate()             # финал выбран только что — открыть котелок и украшения
		_update_cozy()
		_update_guest()
		_update_labels()


## Старые сохранения и только что выбранный финал: открыть всё новое. Ничего не отнимает и не меняет в прежнем.
static func migrate() -> void:
	Cooking.unlock_postgame()
	if Game.ended():
		for id in Data.BUILDINGS:
			if Data.BUILDINGS[id].get("decor", false) and not Data.BUILDINGS[id].get("secret", false):
				Game.unlocked[id] = true


# ------------------------------------------------------------------ Уют
static func cozy_of(id: String) -> int:
	return int(Data.BUILDINGS.get(id, {}).get("cozy", OLD_COZY.get(id, 0)))


## Очки уюта за набор построек (список id): одинаковые подряд дают всё меньше.
static func score_of(ids: Array) -> int:
	var seen := {}
	var total := 0.0
	for id in ids:
		var pts := cozy_of(str(id))
		if pts <= 0:
			continue
		var n: int = seen.get(id, 0)
		seen[id] = n + 1
		total += pts * (REPEAT[n] if n < REPEAT.size() else REPEAT_REST)
	return int(round(total))


static func level_of(score: int) -> int:
	var lv := 0
	for i in LEVELS.size():
		if score >= int(LEVELS[i]):
			lv = i
	return lv


## Костёр лагеря (ближайший к поляне у места крушения) или null.
func camp_fire() -> Node3D:
	if main == null or Game.location != "home":
		return null
	var isl: Island = main.get("island")
	var best: Node3D = null
	for b in get_tree().get_nodes_in_group("station_campfire"):
		var n := b as Node3D
		if n.is_queued_for_deletion():
			continue
		if best == null or n.global_position.distance_to(isl.camp_center) < best.global_position.distance_to(isl.camp_center):
			best = n
	return best


## Что стоит рядом с костром (id построек в CAMP_R метрах).
func camp_ids() -> Array:
	var fire := camp_fire()
	var out: Array = []
	if fire == null:
		return out
	for b in get_tree().get_nodes_in_group("building"):
		var n := b as Node3D
		if n.is_queued_for_deletion() or n == fire:
			continue
		if Vector2(n.global_position.x - fire.global_position.x, n.global_position.z - fire.global_position.z).length() <= CAMP_R:
			out.append(str(b.get("id")))
	return out


func _update_cozy() -> void:
	if Game.location != "home" or not Game.ended():
		level_now = 0
		score_now = 0
		resting = false
		return
	var fire := camp_fire()
	score_now = score_of(camp_ids())
	level_now = level_of(score_now)
	Game.flags["cozy_level"] = level_now     # нужно ночью (сон) и в сохранении
	var p: Node3D = main.get("player")
	resting = fire != null and level_now >= REST_LEVEL and p != null and p.global_position.distance_to(fire.global_position) < 6.0
	var best := int(Game.flags.get("cozy_best", 0))
	if level_now > best:
		Game.flags["cozy_best"] = level_now
		Game.notified.emit("Лагерь стал уютнее: «%s» — %s" % [LEVEL_NAMES[level_now], LEVEL_NOTES[level_now]], Color("b6f29a"))
		Audio.play("quest", -6.0, 0.05)


## Во сколько раз меньше тает сытость за ночь сна (1.0 — как обычно): тёплая еда и уютный лагерь.
static func night_hunger() -> float:
	var k := Cooking.WARM_NIGHT if Cooking.has_buff("warm") else 1.0
	if Game.location == "home" and Game.ended():
		k *= 1.0 - NIGHT_PER_LEVEL * clampi(int(Game.flags.get("cozy_level", 0)), 0, LEVELS.size() - 1)
	return maxf(0.3, k)


## У костра в уютном лагере силы возвращаются быстрее (зовёт Cooking.regen_mult).
static func rest_mult() -> float:
	return REST_MULT if resting else 1.0


# ------------------------------------------------------------------ Вечерние гости
static func guest_ids() -> Array:
	var out: Array = []
	for id in GUESTS:
		if id == "lyova" and not Game.flags.get("ending_open_sea", false):
			continue      # в финале «Хранитель огня» Лёва дома, за штормом
		out.append(id)
	return out


static func evening() -> bool:
	return Game.time_of_day >= EVENING_FROM or Game.time_of_day < MORNING


## Кто зайдёт сегодня вечером при такой ступени уюта ("" — никто). Один и тот же ответ весь день.
static func guest_today(level: int) -> String:
	if level <= 0:
		return ""
	var g := RandomNumberGenerator.new()
	g.seed = Game.day * 7907 + 31
	if g.randf() >= float(COME_CHANCE[clampi(level, 0, COME_CHANCE.size() - 1)]):
		return ""
	var ids := guest_ids()
	return str(ids[g.randi_range(0, ids.size() - 1)])


## Подарок сегодняшнего гостя: [предмет, сколько] или пусто.
static func gift_today(id: String, level: int) -> Array:
	var g := RandomNumberGenerator.new()
	g.seed = Game.day * 6151 + 17
	if g.randf() >= GIFT_BASE + GIFT_PER_LEVEL * level:
		return []
	var gifts: Array = GUESTS[id]["gifts"]
	return gifts[g.randi_range(0, gifts.size() - 1)]


func _guest_rec() -> Dictionary:
	var r = Game.flags.get("guest", {})
	return r if typeof(r) == TYPE_DICTIONARY else {}


## Вечер гостя: тот день, когда он пришёл (после полуночи день уже следующий, а вечер — тот же).
func _guest_evening_on() -> bool:
	var r := _guest_rec()
	if r.is_empty():
		return false
	var d := int(r.get("day", -1))
	return (d == Game.day and Game.time_of_day >= EVENING_FROM) or (d == Game.day - 1 and Game.time_of_day < MORNING)


func _update_guest() -> void:
	if Game.location != "home" or not Game.ended() or not Game.playing:
		return
	var fire := camp_fire()
	if _guest != null and not is_instance_valid(_guest):
		_guest = null
	# утро или костра больше нет — гость уходит
	if _guest != null and not _guest.leaving and (not _guest_evening_on() or fire == null):
		_guest.leave()
		_guest = null
		return
	if _guest != null or fire == null:
		return
	if _guest_evening_on():
		_spawn_guest(str(_guest_rec()["id"]), fire, false)     # сохранились вечером — гость на месте
		return
	if Game.time_of_day < EVENING_FROM or int(Game.flags.get("guest_roll_day", -1)) == Game.day:
		return
	Game.flags["guest_roll_day"] = Game.day      # один раз за вечер
	var id := guest_today(level_now)
	if id == "":
		return
	Game.flags["guest"] = {"id": id, "day": Game.day, "talked": false}
	_spawn_guest(id, fire, true)
	Game.notified.emit("К костру кто-то идёт: %s" % Data.SPEAKERS.get(id, {}).get("name", id), Color("ffe08a"))


func _spawn_guest(id: String, fire: Node3D, walk_in: bool) -> void:
	var isl: Island = main.get("island")
	var g := RandomNumberGenerator.new()
	g.seed = Game.day * 131 + 5
	var a := g.randf() * TAU
	var spot := fire.global_position + Vector3(cos(a), 0, sin(a)) * 1.9
	spot.y = isl.height_at(spot.x, spot.z)
	var from := fire.global_position + Vector3(cos(a), 0, sin(a)) * (CAMP_R + 2.0)
	from.y = isl.height_at(from.x, from.z)
	_guest = CampGuest.new()
	_guest.guest_id = id
	_guest.target = spot
	_guest.fire = fire.global_position
	_guest.talked = bool(_guest_rec().get("talked", false))
	_guest.position = from if walk_in else spot
	main.add_child(_guest)
	if not walk_in:
		_guest._away = from


## Поговорить с гостем: две реплики, иногда — подарок (один раз за вечер).
static func talk_to_guest(guest: CampGuest) -> void:
	var id := guest.guest_id
	var sets: Array = GUESTS[id]["lines"]
	var pick: Array = sets[Game.day % sets.size()]
	if guest.talked:
		Game.dialogue_requested.emit([[id, pick[1]]], Callable())
		return
	guest.talked = true
	var r = Game.flags.get("guest", {})
	if typeof(r) == TYPE_DICTIONARY:
		r["talked"] = true
	Game.bump("guests", "any")
	var gift := gift_today(id, level_now)
	var lines: Array = [[id, pick[0]], [id, pick[1]]]
	var rumor := RareLife.rumor(id)      # слух о редком существе, которого ты ещё не встречал
	if not rumor.is_empty():
		lines.append([id, rumor[1]])
	Game.dialogue_requested.emit(lines, func():
		if not gift.is_empty():
			Game.add_item(str(gift[0]), int(gift[1]), false, true)
			Game.notified.emit("Подарок от гостя: %s ×%d" % [Game.item_name(str(gift[0])), int(gift[1])], Color("b6f29a"))
			Audio.play("pickup", -4.0, 0.1))


# ------------------------------------------------------------------ Окно котелка и строки под часами
func open_cooking() -> void:
	var h := hud()
	if h == null:
		return
	if cook_ui == null:
		cook_ui = CookUI.new(h)
	cook_ui.open()


func cozy_text() -> String:
	if camp_fire() == null:
		return "Уют лагеря: поставь костёр — вокруг него считается уют"
	var s := "Уют лагеря: %s (%d)" % [LEVEL_NAMES[level_now], score_now]
	if level_now + 1 < LEVELS.size():
		s += " — до «%s» ещё %d" % [LEVEL_NAMES[level_now + 1], int(LEVELS[level_now + 1]) - score_now]
	return s


func _update_labels() -> void:
	var h := hud()
	if h == null:
		return
	if _buff_label == null:
		_cozy_label = h._label("", 16, Color("ffe9b0"))
		_cozy_label.position = Vector2(22, 138)
		_cozy_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.root.add_child(_cozy_label)
		_buff_label = h._label("", 16, Color("d8f5b0"))
		_buff_label.position = Vector2(22, 162)
		_buff_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.root.add_child(_buff_label)
	# уют — только дома после финала и только рядом с лагерем
	var show_cozy := false
	if Game.location == "home" and Game.ended() and main != null:
		var isl: Island = main.get("island")
		var p: Node3D = main.get("player")
		var c: Vector3 = isl.camp_center
		var fire := camp_fire()
		if fire:
			c = fire.global_position
		show_cozy = p != null and p.global_position.distance_to(c) < CAMP_R + 6.0
	_cozy_label.visible = show_cozy
	if show_cozy:
		_cozy_label.text = cozy_text()
	var parts: Array[String] = []
	for kind in Cooking.BUFFS:
		var left := Cooking.buff_left(kind)
		if left > 0.0:
			parts.append("%s %s" % [Cooking.BUFFS[kind]["name"], Cooking.time_text(left)])
	if resting:
		parts.append("Отдых у костра")
	_buff_label.text = "   ".join(parts)
	_buff_label.visible = not parts.is_empty()
	_buff_label.position.y = 162.0 if show_cozy else 138.0
