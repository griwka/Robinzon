class_name IslandTrailPoint
extends Node3D
## Следы Лёвы на Баньяне и в бункере, кладка у дома Стёпы.

const QUESTS := {"apiary_trace": "trade", "hut_masonry": "stepa_wall", "archive_chalk": "logs"}

var puzzle: String
var hint: String
var discovery: String
var leads_on := false
var visual: Node3D


static func place(parent: Node3D, at: Vector3, id: String, action: String, result: String, model := "") -> IslandTrailPoint:
	var point := IslandTrailPoint.new()
	point.position = at
	point.puzzle = id
	point.hint = action
	point.discovery = result
	if model != "":
		point.visual = Models.glb(model)
		if point.visual:
			point.add_child(point.visual)
	parent.add_child(point)
	return point


func _ready() -> void:
	Game.quest_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	var done := Game.stat("solved", puzzle) > 0
	var active: bool = Game.quest_started and Game.current_quest().get("id", "") == QUESTS[puzzle] and not done
	if active and not is_in_group("interactable"):
		add_to_group("interactable")
	elif not active and is_in_group("interactable"):
		remove_from_group("interactable")
	if puzzle == "hut_masonry" and visual:
		# В прежних сохранениях восемь переданных кирпичей уже завершали ремонт.
		var repaired := done or (not active and Game.stat("delivered", "brick") >= 8)
		visual.scale = Vector3(0.48, 0.21 if repaired else 0.08, 0.42)


func interact_point() -> Vector3:
	return global_position + Vector3.UP * 0.35


func get_hint() -> String:
	return hint


func interact(_player: Node) -> void:
	if not is_in_group("interactable"):
		return
	if puzzle == "hut_masonry" and Game.stat("delivered", "brick") < 8:
		Game.notified.emit("Стёпа держит стену. Сначала принеси ему все восемь кирпичей.", Color("ffe08a"))
		return
	if puzzle == "archive_chalk" and not Game.has_light():
		Game.notified.emit("В темноте мел сливается с деревом. Включи фонарь (5).", Color("ffe08a"))
		return
	Game.notified.emit(discovery, Color("bfe3ff"))
	if not leads_on:
		Game.bump("solved", puzzle)
