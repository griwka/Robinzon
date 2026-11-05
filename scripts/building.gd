class_name Building
extends StaticBody3D
## Постройка игрока. Поведение при взаимодействии зависит от типа.

signal sail_requested
signal sleep_requested
signal craft_requested(station: String)

var id := "campfire"
var visual: Node3D
var _light: OmniLight3D
var _flicker_t := 0.0
var lit := true


func setup(building_id: String) -> void:
	id = building_id


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("building")
	add_to_group("station_" + id)
	collision_layer = 4
	collision_mask = 0
	visual = Models.building(id)
	add_child(visual)
	_light = visual.get_node_or_null("Light")
	var r: float = Game.BUILDINGS[id]["radius"]
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = r * (0.6 if id == "hut" else 0.8)
	shape.height = 2.0
	cs.shape = shape
	cs.position.y = 1.0
	if id == "hut":
		# хижина — четыре стены, чтобы можно было зайти внутрь
		cs.queue_free()
		for side in 4:
			var a := side * PI / 2.0
			var dir := Vector3(sin(a), 0, cos(a))
			var right := Vector3(cos(a), 0, -sin(a))
			var offsets := [-1.05, 1.05] if side == 0 else [0.0]  # side 0 — дверной проём
			for o in offsets:
				var wall := CollisionShape3D.new()
				var b := BoxShape3D.new()
				b.size = Vector3(1.1 if side == 0 else 3.2, 2.2, 0.25)
				wall.shape = b
				wall.position = dir * 1.55 + right * o + Vector3(0, 1.1, 0)
				wall.rotation.y = a
				add_child(wall)
	elif id == "raft":
		shape.height = 0.4
		cs.position.y = 0.2
		add_child(cs)
	else:
		add_child(cs)
	if id in ["torch", "shell_deco"]:
		collision_layer = 8  # не мешают ходить
	# анимация появления
	visual.scale = Vector3(0.01, 0.01, 0.01)
	var tw := create_tween()
	tw.tween_property(visual, "scale", Vector3.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	_flicker_t += delta
	if _light and lit:
		_light.light_energy = (2.0 if id == "campfire" else 1.4) * (0.85 + 0.15 * sin(_flicker_t * 11.0) * sin(_flicker_t * 7.3))
		var fire := visual.get_node_or_null("Fire")
		if fire:
			fire.scale = Vector3(1, 0.85 + 0.2 * abs(sin(_flicker_t * 9.0)), 1)
	if id == "raft":
		visual.position.y = sin(_flicker_t * 1.4) * 0.06
		visual.rotation.z = sin(_flicker_t * 1.1) * 0.03


func interact_point() -> Vector3:
	return global_position + Vector3(0, 0.6, 0)


func get_hint() -> String:
	match id:
		"campfire": return "Костёр — готовить еду"
		"workbench": return "Верстак — открыть крафт"
		"hut": return "Хижина — поспать до утра"
		"torch": return "Факел — " + ("погасить" if lit else "зажечь")
		"raft": return "Плот — отправиться в плавание!"
		"shell_deco": return "Ракушечная клумба"
	return Game.BUILDINGS[id]["name"]


func interact(_player: Node) -> void:
	match id:
		"campfire": craft_requested.emit("campfire")
		"workbench": craft_requested.emit("workbench")
		"hut": sleep_requested.emit()
		"raft": sail_requested.emit()
		"torch":
			lit = not lit
			_light.visible = lit
			visual.get_node("Flame").visible = lit
