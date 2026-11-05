class_name Building
extends StaticBody3D
## Постройка игрока. Базовый класс: модель, коллизия, анимация появления, простые действия.
## Сложные постройки (грядка, дерево, загон) — наследники с собственным состоянием.

signal sail_requested
signal sleep_requested
signal craft_requested(station: String)
signal choice_requested(title: String, options: Array)

const ACTIONS := ["campfire", "workbench", "tent", "hut", "hammock", "torch", "raft", "bench", "canoe"]

var id := "campfire"
var variant := ""
var visual: Node3D
var _light: OmniLight3D
var _t := 0.0
var lit := true
var marker: Node3D
var _last_wt := -1.0


func setup(building_id: String, v := "") -> void:
	id = building_id
	variant = v


func _ready() -> void:
	add_to_group("building")
	add_to_group("station_" + id)
	if id in ACTIONS or has_method("_custom_interact"):
		add_to_group("interactable")
	collision_layer = 4
	collision_mask = 0
	_make_visual()
	_light = visual.get_node_or_null("Light") if visual else null
	_make_collision()
	if visual:
		visual.scale = Vector3(0.01, 0.01, 0.01)
		var tw := create_tween()
		tw.tween_property(visual, "scale", Vector3.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _make_visual() -> void:
	visual = Models.building(id)
	add_child(visual)


func _make_collision() -> void:
	var r: float = Data.BUILDINGS[id]["radius"]
	match id:
		"hut":
			for side in 4:
				var a := side * PI / 2.0
				var dir := Vector3(sin(a), 0, cos(a))
				var right := Vector3(cos(a), 0, -sin(a))
				var offsets := [-1.05, 1.05] if side == 0 else [0.0]
				for o in offsets:
					_add_box(Vector3(1.1 if side == 0 else 3.2, 2.2, 0.25), dir * 1.55 + right * o + Vector3(0, 1.1, 0), a)
		"tent":
			_add_box(Vector3(1.6, 1.3, 2.2), Vector3(0, 0.65, 0), 0.0)
		"raft":
			_add_box(Vector3(2.2, 0.4, 3.0), Vector3(0, 0.2, 0), 0.0)
		"canoe":
			_add_box(Vector3(1.0, 0.4, 3.0), Vector3(0, 0.2, 0), 0.0)
		"goat_pen", "sheep_pen", "pig_sty", "garden_bed", "torch", "flowerbed", "shell_path":
			_add_cyl(r * 0.6, 0.6)
			collision_layer = 8  # не мешают ходить
		"coop":
			_add_box(Vector3(1.3, 1.6, 1.1), Vector3(0, 0.8, 0), 0.0)
		"fence":
			_add_box(Vector3(1.3, 0.8, 0.15), Vector3(0, 0.4, 0), 0.0)
		_:
			_add_cyl(r * 0.8, 2.0)


func _add_box(size: Vector3, pos: Vector3, rot_y: float) -> void:
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	cs.shape = b
	cs.position = pos
	cs.rotation.y = rot_y
	add_child(cs)


func _add_cyl(radius: float, height: float) -> void:
	var cs := CollisionShape3D.new()
	var c := CylinderShape3D.new()
	c.radius = radius
	c.height = height
	cs.shape = c
	cs.position.y = height * 0.5
	add_child(cs)


func block_radius() -> float:
	return Data.BUILDINGS[id]["radius"]


## Скорость течения игрового времени для этой постройки (учитывает сон).
func world_dt() -> float:
	var wt := Game.world_time
	if _last_wt < 0.0:
		_last_wt = wt
	var dt := wt - _last_wt
	_last_wt = wt
	return dt


func _process(delta: float) -> void:
	_t += delta
	if _light and lit:
		_light.light_energy = (2.0 if id == "campfire" else 1.4) * (0.85 + 0.15 * sin(_t * 11.0) * sin(_t * 7.3))
		var fire := visual.get_node_or_null("Fire")
		if fire:
			fire.scale = Vector3(1, 0.85 + 0.2 * abs(sin(_t * 9.0)), 1)
	if id in ["raft", "canoe"]:
		visual.position.y = sin(_t * 1.4) * 0.06
		visual.rotation.z = sin(_t * 1.1) * 0.03
	if marker and marker.visible:
		marker.position.y = marker_height() + sin(_t * 3.0) * 0.08
		marker.rotation.y += delta


func marker_height() -> float:
	return 1.6


func interact_point() -> Vector3:
	return global_position + Vector3(0, 0.6, 0)


func tool_hint() -> String:
	return ""


func get_hint() -> String:
	match id:
		"campfire": return "Костёр — готовить еду"
		"workbench": return "Верстак — открыть крафт"
		"tent", "hut": return "%s — поспать до утра" % Data.BUILDINGS[id]["name"]
		"hammock": return "Гамак — вздремнуть до утра"
		"torch": return "Факел — " + ("погасить" if lit else "зажечь")
		"raft": return "Плот — отправиться в плавание!"
		"canoe": return "Каноэ — плыть"
		"bench": return "Скамейка — присесть отдохнуть"
	return Data.BUILDINGS[id]["name"]


func interact(_player: Node) -> void:
	match id:
		"campfire": craft_requested.emit("campfire")
		"workbench": craft_requested.emit("workbench")
		"tent", "hut", "hammock": sleep_requested.emit()
		"raft", "canoe": sail_requested.emit()
		"bench": Game.notified.emit("Ты присел на скамейку. Шумит прибой, кричат чайки...", Color("ffe08a"))
		"torch":
			lit = not lit
			_light.visible = lit
			visual.get_node("Flame").visible = lit


# Сохранение состояния (переопределяют наследники)
func get_state() -> Dictionary:
	return {}


func apply_state(_d: Dictionary) -> void:
	pass
