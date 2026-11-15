class_name CozyLife
extends Node
## «Вечная игра» после финала: кулинария и уют лагеря. Узел живёт в главной сцене (его создаёт main.gd).
## Здесь: открытие нового после финала (и в старых сохранениях), время действия пользы от блюд,
## строка с действующей пользой под часами, окно котелка.

var main: Node            # главная сцена (Main)
var cook_ui: CookUI
var _buff_label: Label
var _check_t := 0.0


func _ready() -> void:
	add_to_group("cozy_life")
	migrate()


func hud() -> HUD:
	return main.get("hud") as HUD if main else null


func _process(delta: float) -> void:
	if Game.playing and not get_tree().paused:
		Cooking.tick(delta)
	_check_t -= delta
	if _check_t <= 0.0:
		_check_t = 1.0
		migrate()             # финал выбран только что — открыть котелок
		_update_buff_label()


## Старые сохранения и только что выбранный финал: открыть всё новое. Ничего не отнимает и не меняет в прежнем.
static func migrate() -> void:
	Cooking.unlock_postgame()
	if Game.ended():
		for id in Data.BUILDINGS:
			if Data.BUILDINGS[id].get("decor", false):
				Game.unlocked[id] = true


## Во сколько раз меньше тает сытость за ночь сна (1.0 — как обычно).
static func night_hunger() -> float:
	return Cooking.WARM_NIGHT if Cooking.has_buff("warm") else 1.0


func open_cooking() -> void:
	var h := hud()
	if h == null:
		return
	if cook_ui == null:
		cook_ui = CookUI.new(h)
	cook_ui.open()


## Под часами — что сейчас действует от съеденных блюд и сколько осталось.
func _update_buff_label() -> void:
	var h := hud()
	if h == null:
		return
	if _buff_label == null:
		_buff_label = h._label("", 16, Color("d8f5b0"))
		_buff_label.position = Vector2(22, 138)
		_buff_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.root.add_child(_buff_label)
	var parts: Array[String] = []
	for kind in Cooking.BUFFS:
		var left := Cooking.buff_left(kind)
		if left > 0.0:
			parts.append("%s %s" % [Cooking.BUFFS[kind]["name"], Cooking.time_text(left)])
	_buff_label.text = "   ".join(parts)
	_buff_label.visible = not parts.is_empty()
