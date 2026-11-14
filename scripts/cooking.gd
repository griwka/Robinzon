class_name Cooking
extends RefCounted
## Кулинария «вечной игры» (после финала): котелок в лагере, рецепты открываются пробами.
## В котелок кладут 2–4 продукта. Совпало с рецептом — блюдо и запись в кулинарную книгу,
## не совпало — «каша-неудача» (съедобна, но не продаётся). Ничего не пропадает зря и ничто не торопит.
## Блюда — обычные предметы из Data.ITEMS (блок «кулинария»): сытость, цена, мягкая польза на время.
## Книга хранится в Game.flags["cookbook"], действующая польза — в Game.flags["buffs"] (секунды).

const MIN_UNITS := 2
const MAX_UNITS := 4
const FLOP := "kitchen_flop"

## Что можно положить в котелок кроме еды (у этих продуктов нет сытости).
const EXTRA := ["truffle", "ice", "aloe", "leaf"]

## Рецепты котелка: что класть и подсказка для кулинарной книги (пока рецепт не найден).
const RECIPES := [
	{"id": "veg_stew", "in": {"potato": 1, "carrot": 1, "tomato": 1}, "hint": "Три овоща с грядки: по одному"},
	{"id": "corn_chowder", "in": {"corn": 2, "milk": 1}, "hint": "Кукуруза и что-то от козы"},
	{"id": "cabbage_soup", "in": {"cabbage": 1, "potato": 1, "carrot": 1}, "hint": "Капуста и два корнеплода"},
	{"id": "tomato_omelette", "in": {"egg": 2, "tomato": 1, "milk": 1}, "hint": "Яйца, молоко и красный овощ"},
	{"id": "banana_pancakes", "in": {"banana": 2, "egg": 1, "milk": 1}, "hint": "Тесто на яйце и молоке, а в нём — фрукт с пальмы"},
	{"id": "mango_dessert", "in": {"mango": 2, "milk": 1, "honey": 1}, "hint": "Сладкий фрукт с Баньяна, молоко и мёд"},
	{"id": "coconut_fish", "in": {"fish": 2, "coconut": 1, "lemon": 1}, "hint": "Рыба, орех с пальмы и что-то кислое"},
	{"id": "fish_pie", "in": {"fish": 2, "egg": 1, "corn": 1}, "hint": "Рыба, яйцо и зерно вместо муки"},
	{"id": "fish_veg", "in": {"fish": 2, "carrot": 1, "tomato": 1}, "hint": "Рыба и два овоща: рыжий и красный"},
	{"id": "stuffed_pepper", "in": {"pepper": 2, "cheese": 1, "tomato": 1}, "hint": "Острое, а внутри — сыр и томат"},
	{"id": "pumpkin_soup", "in": {"pumpkin": 1, "milk": 1, "carrot": 1}, "hint": "Всё рыжее с грядки и молоко"},
	{"id": "pumpkin_pie", "in": {"pumpkin": 1, "egg": 1, "honey": 1}, "hint": "Тыква, яйцо и сладкое от пчёл"},
	{"id": "truffle_potato", "in": {"truffle": 1, "potato": 2, "milk": 1}, "hint": "Находка поросёнка, картошка и молоко"},
	{"id": "truffle_omelette", "in": {"truffle": 1, "egg": 2, "cheese": 1}, "hint": "Находка поросёнка, яйца и сыр"},
	{"id": "berry_compote", "in": {"blueberry": 2, "lingonberry": 1, "honey": 1}, "hint": "Две лесные ягоды и мёд"},
	{"id": "lemonade", "in": {"lemon": 2, "honey": 1, "ice": 1}, "hint": "Кислое, сладкое и холодное"},
	{"id": "watermelon_ice", "in": {"watermelon": 1, "ice": 1, "lemon": 1}, "hint": "Самая большая ягода, лёд и лимон"},
	{"id": "aloe_drink", "in": {"aloe": 2, "lemon": 1, "honey": 1}, "hint": "Колючее растение Веры, лимон и мёд"},
	{"id": "cabbage_pie", "in": {"cabbage": 1, "egg": 2}, "hint": "Капуста и пара яиц"},
	{"id": "corn_cakes", "in": {"corn": 2, "egg": 1}, "hint": "Кукуруза и одно яйцо"},
	{"id": "spicy_corn", "in": {"corn": 2, "pepper": 1}, "hint": "Кукуруза и то, от чего горит язык"},
	{"id": "honey_carrot", "in": {"carrot": 2, "honey": 1}, "hint": "Морковь и мёд"},
	{"id": "milk_coffee", "in": {"roasted_coffee": 1, "milk": 1}, "hint": "Жареный кофе и молоко"},
	{"id": "cloudberry_pie", "in": {"cloudberry": 2, "egg": 1, "honey": 1}, "hint": "Северная ягода, яйцо и мёд"},
	{"id": "cheese_salad", "in": {"cheese": 1, "tomato": 1, "cabbage": 1}, "hint": "Сыр и два овоща для салата"},
	{"id": "tropical_shake", "in": {"banana": 1, "mango": 1, "coconut": 1, "milk": 1}, "hint": "Три фрукта с пальм и деревьев и молоко"},
]

## Виды пользы: подпись и что написать, когда блюдо съедено.
const BUFFS := {
	"regen": {"name": "Бодрость", "note": "силы возвращаются быстрее"},
	"brisk": {"name": "Лёгкий шаг", "note": "идёшь чуть быстрее"},
	"luck": {"name": "Рыбацкая удача", "note": "рыба клюёт быстрее, редкая попадается чаще"},
	"warm": {"name": "Тепло", "note": "за ночь меньше проголодаешься, на морозе греет"},
	"cool": {"name": "Прохлада", "note": "жар у лавы растёт медленнее"},
}
const REGEN_MULT := 1.3     # «Бодрость»: силы возвращаются на 30 % быстрее
const BRISK_MULT := 1.08    # «Лёгкий шаг»: +8 % к скорости ходьбы
const LUCK_BITE := 0.6      # «Рыбацкая удача»: ждать поклёвки на 40 % меньше
const LUCK_RARE := 1.5      # …и редкая рыба в полтора раза чаще
const WARM_NIGHT := 0.5     # «Тепло»: за ночь сытость тает вдвое меньше


# ------------------------------------------------------------------ Рецепты
static func recipe(id: String) -> Dictionary:
	for r in RECIPES:
		if r["id"] == id:
			return r
	return {}


## Блюда из обычных рецептов (костёр, печка, верстак) — их знают с самого начала, а в котелке они тоже получаются.
static func classic_recipes() -> Array:
	var out: Array = []
	for r in Data.RECIPES:
		var out_id: String = r["out"].keys()[0]
		if Data.ITEMS.get(out_id, {}).get("cat", "") != "food":
			continue
		var n := units(r["in"])
		if n >= MIN_UNITS and n <= MAX_UNITS:
			out.append(r)
	return out


static func units(ing: Dictionary) -> int:
	var n := 0
	for id in ing:
		n += int(ing[id])
	return n


static func _same(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		return false
	for id in a:
		if int(b.get(id, 0)) != int(a[id]):
			return false
	return true


## На сколько продуктов набор отличается от рецепта (лишние + недостающие).
static func _distance(a: Dictionary, b: Dictionary) -> int:
	var d := 0
	for id in a:
		d += maxi(0, int(a[id]) - int(b.get(id, 0)))
	for id in b:
		d += maxi(0, int(b[id]) - int(a.get(id, 0)))
	return d


## Что получится из такого набора: {"id": блюдо, "n": сколько} или пусто (каша-неудача).
static func match_dish(ing: Dictionary) -> Dictionary:
	for r in RECIPES:
		if _same(ing, r["in"]):
			return {"id": r["id"], "n": 1}
	for r in classic_recipes():
		if _same(ing, r["in"]) and Game.recipe_unlocked(r):
			var out_id: String = r["out"].keys()[0]
			return {"id": out_id, "n": int(r["out"][out_id])}
	return {}


## Можно ли положить это в котелок.
static func is_ingredient(id: String) -> bool:
	if id == FLOP:
		return false
	return Data.ITEMS.get(id, {}).has("food") or id in EXTRA


## Сколько штук свободно для котелка (отложенное для задания не трогаем).
static func free_count(id: String) -> int:
	return maxi(0, Game.count(id) - Game.reserved(id))


# ------------------------------------------------------------------ Кулинарная книга
static func book() -> Dictionary:
	var b = Game.flags.get("cookbook", {})
	if typeof(b) != TYPE_DICTIONARY:
		b = {}
	if not Game.flags.has("cookbook") or typeof(Game.flags["cookbook"]) != TYPE_DICTIONARY:
		Game.flags["cookbook"] = b
	return b


static func known(id: String) -> bool:
	return book().has(id)


static func known_count() -> int:
	var n := 0
	for r in RECIPES:
		if known(r["id"]):
			n += 1
	return n


# ------------------------------------------------------------------ Готовка
## Сварить из набора продуктов {id: сколько}. Возвращает id того, что получилось ("" — варить нельзя).
static func cook(ing: Dictionary) -> String:
	var n := units(ing)
	if n < MIN_UNITS or n > MAX_UNITS:
		Game.notified.emit("В котелок кладут от %d до %d продуктов" % [MIN_UNITS, MAX_UNITS], Color("ff9d7a"))
		return ""
	for id in ing:
		if not is_ingredient(id) or free_count(id) < int(ing[id]):
			Game.notified.emit("Не хватает: %s" % Game.item_name(id), Color("ff9d7a"))
			return ""
	if not Game.pay(ing):
		return ""
	var res := match_dish(ing)
	if res.is_empty():
		Game.add_item(FLOP, 1, true, true)
		Game.bump("cooked", FLOP)
		Audio.play("craft", -5.0, 0.1)
		Game.notified.emit("Получилась каша-неудача. Есть можно. %s" % _near_hint(ing), Color("ffd0a0"))
		return FLOP
	var id: String = res["id"]
	Game.add_item(id, int(res["n"]), true, true)
	Game.bump("cooked", id)
	Game.bump("cooked", "any")
	var is_new := recipe(id).size() > 0 and not known(id)
	if is_new:
		book()[id] = Game.day
		Audio.play("quest", -4.0, 0.05)
		Game.notified.emit("Новый рецепт: %s! Записан в кулинарную книгу (K)" % Game.item_name(id), Color("b6f29a"))
		Game.bump("recipes", "found")
	else:
		Audio.play("craft", -3.0, 0.05)
		Game.notified.emit("Готово: %s ×%d" % [Game.item_name(id), int(res["n"])], Color("ffe08a"))
	return id


## Подсказка после неудачи: если до какого-то ненайденного рецепта не хватило совсем чуть-чуть.
static func _near_hint(ing: Dictionary) -> String:
	var best := 99
	for r in RECIPES:
		if not known(r["id"]):
			best = mini(best, _distance(ing, r["in"]))
	if best == 1:
		return "Но почти вышло: один продукт лишний или одного не хватило."
	if best == 2:
		return "Что-то в этом есть: попробуй заменить один продукт."
	return "Попробуй другое сочетание."


## Сварить знакомое блюдо одной кнопкой (рецепт уже в книге или это обычный рецепт).
static func cook_known(id: String) -> String:
	var r := recipe(id)
	if not r.is_empty() and known(id):
		return cook(r["in"])
	for c in classic_recipes():
		if c["out"].keys()[0] == id and Game.recipe_unlocked(c):
			return cook(c["in"])
	return ""


# ------------------------------------------------------------------ Польза блюд
static func buffs() -> Dictionary:
	var b = Game.flags.get("buffs", {})
	if typeof(b) != TYPE_DICTIONARY:
		b = {}
	if not Game.flags.has("buffs") or typeof(Game.flags["buffs"]) != TYPE_DICTIONARY:
		Game.flags["buffs"] = b
	return b


static func buff_left(kind: String) -> float:
	var b = Game.flags.get("buffs", {})
	if typeof(b) != TYPE_DICTIONARY:
		return 0.0
	return float(b.get(kind, 0.0))


static func has_buff(kind: String) -> bool:
	return buff_left(kind) > 0.0


## Время идёт только в игре (зовёт CozyLife._process); сон пользу не снимает.
static func tick(delta: float) -> void:
	var b = Game.flags.get("buffs", {})
	if typeof(b) != TYPE_DICTIONARY or b.is_empty():
		return
	for kind in b.keys():
		var left := float(b[kind]) - delta
		if left <= 0.0:
			b.erase(kind)
			if BUFFS.has(kind):
				Game.notified.emit("%s прошла" % BUFFS[kind]["name"] if kind != "warm" else "Тепло от еды прошло", Color("e8dcc0"))
		else:
			b[kind] = left


## Блюдо съедено (зовёт Game.eat_item): включить его пользу. Время не складывается, а обновляется до большего.
static func on_eaten(id: String) -> void:
	var it: Dictionary = Data.ITEMS.get(id, {})
	var kind: String = it.get("buff", "")
	if kind == "" or not BUFFS.has(kind):
		return
	var t: float = float(it.get("buff_t", 120.0))
	var b := buffs()
	b[kind] = maxf(float(b.get(kind, 0.0)), t)
	if kind == "warm":
		Game.warm_tea = maxf(Game.warm_tea, t)      # на морозе греет, как чай
	elif kind == "cool":
		Game.salve_t = maxf(Game.salve_t, t)        # у лавы — как мазь
	Game.notified.emit("%s: %s (%s)" % [BUFFS[kind]["name"], BUFFS[kind]["note"], time_text(t)], Color("b6f29a"))


static func time_text(t: float) -> String:
	var s := int(ceil(t))
	return "%d:%02d" % [s / 60, s % 60]


static func regen_mult() -> float:
	return REGEN_MULT if has_buff("regen") else 1.0


static func speed_mult() -> float:
	return BRISK_MULT if has_buff("brisk") else 1.0


static func bite_mult() -> float:
	return LUCK_BITE if has_buff("luck") else 1.0


static func rare_mult() -> float:
	return LUCK_RARE if has_buff("luck") else 1.0


## Клавиша Q не должна съедать блюдо с пользой, пока есть простая еда: у таких блюд «штраф» при выборе.
static func q_penalty(id: String) -> float:
	return 40.0 if Data.ITEMS.get(id, {}).has("buff") else 0.0


## Строка для подсказки предмета: что даёт блюдо.
static func buff_text(id: String) -> String:
	var it: Dictionary = Data.ITEMS.get(id, {})
	var kind: String = it.get("buff", "")
	if kind == "" or not BUFFS.has(kind):
		return ""
	return "%s — %s, %s" % [BUFFS[kind]["name"], BUFFS[kind]["note"], time_text(float(it.get("buff_t", 120.0)))]


## После финала открывается котелок (и в старых сохранениях тоже — зовут CozyLife и Game.load_game).
static func unlock_postgame() -> void:
	if Game.ended():
		Game.unlocked["cook_pot"] = true
