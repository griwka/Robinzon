class_name Building
extends StaticBody3D
## Постройка игрока. Базовый класс: модель, коллизия, анимация появления, простые действия.
## Сложные постройки (грядка, дерево, загон) — наследники с собственным состоянием.

signal sail_requested
signal sleep_requested
signal craft_requested(station: String)
signal choice_requested(title: String, options: Array)

const ACTIONS := ["campfire", "workbench", "tent", "hut", "hammock", "torch", "raft", "bench", "canoe", "boat", "shelter", "stove"]

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
		"boat":
			_add_box(Vector3(1.8, 0.6, 4.2), Vector3(0, 0.3, 0), 0.0)
		"shelter":
			# под навесом можно стоять: мешают только столбы
			for sx in [-1, 1]:
				for sz in [-1, 1]:
					_add_box(Vector3(0.2, 2.4, 0.2), Vector3(sx * 1.05, 1.2, sz * 1.05), 0.0)
		"lightning_rod":
			_add_cyl(0.25, 4.0)
		"stove":
			_add_box(Vector3(1.1, 1.6, 0.9), Vector3(0, 0.8, 0), 0.0)
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
		# живой огонь: свет дрожит неравномерно (сумма двух «шумов»), языки пламени колышет шейдер
		var n := sin(_t * 11.0) * sin(_t * 7.3) * 0.6 + sin(_t * 23.0 + 1.7) * 0.4
		_light.light_energy = (2.0 if id == "campfire" else (1.6 if id == "stove" else 1.4)) * (0.86 + 0.14 * n)
	if id in ["raft", "canoe", "boat"]:
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
		"boat": return "Бот Стёпы — плыть"
		"shelter": return "Навес — переждать грозу здесь" if Game.storm_active() else "Навес — под ним гроза не страшна"
		"stove": return "Печка — заварить чай" + (", погреться" if Game.cold_active() else "")
		"bench": return "Скамейка — присесть отдохнуть"
	return Data.BUILDINGS[id]["name"]


func interact(_player: Node) -> void:
	match id:
		"campfire": craft_requested.emit("campfire")
		"stove": craft_requested.emit("stove")
		"workbench": craft_requested.emit("workbench")
		"tent", "hut", "hammock": sleep_requested.emit()
		"raft", "canoe", "boat": sail_requested.emit()
		"shelter": Game.notified.emit("Сухо и спокойно. Дождь стучит по листьям над головой.", Color("ffe08a"))
		"bench": Game.notified.emit("Ты присел на скамейку. Шумит прибой, кричат чайки...", Color("ffe08a"))
		"torch":
			lit = not lit
			_light.visible = lit
			var fire := visual.get_node_or_null("Fire")
			if fire:
				fire.visible = lit
				for p in fire.find_children("*", "CPUParticles3D", true, false):
					(p as CPUParticles3D).emitting = lit
			FX.puff(self, Vector3(0, 1.9, 0), Color("cfc7d6"), 4, 0.3, 0.8, 0.6)


# Сохранение состояния (переопределяют наследники)
func get_state() -> Dictionary:
	return {}


func apply_state(_d: Dictionary) -> void:
	pass
