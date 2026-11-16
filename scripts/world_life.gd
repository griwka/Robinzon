class_name WorldLife
extends Node
## «Живой мир»: необязательные находки и загадки на островах, не связанные с сюжетом.
##  - SeaDrift — волны выносят на песок бутылки с записками, морское стекло, поплавки, семена;
##  - RuneStones — три камня со знаками на каждом острове; их стрелки сходятся в точке, где зарыт тайник;
##  - RareLife — редкие существа: белая бабочка после дождя, лунная рыба в полнолуние, светящийся краб,
##    золотой жук на клумбах, морская черепаха на рассвете. О них ходят слухи (их пересказывают гости у костра).
## Ничего не пропадает и не торопит: не нашёл сегодня — найдёшь в другой раз. Наград монетами нет.
## Узел создаёт CozyLife (в главной сцене), состояние — во флагах Game.flags и в коллекциях.

var main: Node
var drift: SeaDrift
var runes: RuneStones
var rare: RareLife


func _ready() -> void:
	add_to_group("world_life")
	_start.call_deferred()      # когда остров и постройки уже расставлены


func _start() -> void:
	if main == null or main.get("island") == null:
		return
	var isl: Island = main.get("island")
	drift = SeaDrift.new()
	drift.island = isl
	add_child(drift)
	runes = RuneStones.new()
	runes.island = isl
	add_child(runes)
	rare = RareLife.new()
	rare.island = isl
	rare.main = main
	add_child(rare)


## Положить в коллекцию определённую вещь (Game.add_collectible выбирает сам — случайно или по порядку).
## Возвращает true, если вещь новая.
static func collect(col_id: String, item_id: String) -> bool:
	var col: Dictionary = Data.COLLECTIONS[col_id]
	var it := {}
	for e in col["items"]:
		if e["id"] == item_id:
			it = e
	if it.is_empty():
		return false
	var have: Dictionary = Game.collections.get(col_id, {})
	var is_new: bool = not have.has(item_id)
	have[item_id] = int(have.get(item_id, 0)) + 1
	Game.collections[col_id] = have
	Game.notified.emit("%s: %s%s" % [col["name"], it["name"], " (новое!)" if is_new else ""], it["color"])
	Game.collection_changed.emit(col_id, item_id, is_new)
	Audio.play("rare" if is_new else "pickup", -3.0)
	if is_new and it.has("text"):
		Game.dialogue_requested.emit([["journal", it["text"]]], Callable())
	if is_new:
		Game.bump("collection", col_id)
	if is_new and Game.collection_complete(col_id) and not Game.flags.has("col_" + col_id):
		Game.flags["col_" + col_id] = true
		Game._grant(col["reward"])
		Game.notified.emit("Коллекция «%s» собрана!" % col["name"], Color("8affa0"))
	return is_new


static func has(col_id: String, item_id: String) -> bool:
	return (Game.collections.get(col_id, {}) as Dictionary).has(item_id)


## Следующая ещё не найденная вещь коллекции ("" — собраны все).
static func next_missing(col_id: String) -> String:
	for e in Data.COLLECTIONS[col_id]["items"]:
		if not has(col_id, e["id"]):
			return e["id"]
	return ""
