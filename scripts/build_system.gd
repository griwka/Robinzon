class_name BuildSystem
extends Node3D
## Режим строительства: полупрозрачный "призрак" постройки следует за прицелом,
## зелёный — можно ставить, красный — нельзя. ЛКМ — поставить, R — повернуть, ПКМ/Esc — отмена.

signal placed(building: Building)
signal cancelled

var island: Island
var player: Player
var buildings_root: Node3D
var active_id := ""
var active_variant := ""
var ghost: Node3D
var ghost_rot := 0.0
var valid := false
var reason := ""   # почему здесь нельзя строить (показывается в подсказке)
## Где засчитывается постройка по заданию: "near" в пункте задания — "camp" (поляна у лагеря)
## или id постройки (рядом с ней), "near_r" — радиус в метрах.
const CAMP_R := 8.0
var _ok_mat: StandardMaterial3D
var _bad_mat: StandardMaterial3D


func _ready() -> void:
	_ok_mat = _ghost_mat(Color(0.4, 1.0, 0.5, 0.45))
	_bad_mat = _ghost_mat(Color(1.0, 0.35, 0.3, 0.45))


func _ghost_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	return m


func is_active() -> bool:
	return active_id != ""


func cost_of(id: String, variant := "") -> Dictionary:
	if id == "fruit_tree":
		return {"sapling_" + variant: 1}
	return Data.BUILDINGS[id]["cost"]


func start(id: String, variant := "") -> void:
	cancel(false)
	active_id = id
	active_variant = variant
	ghost = Models.building(id)
	for l in ghost.find_children("*", "OmniLight3D", true, false):
		l.queue_free()
	add_child(ghost)


func cancel(emit := true) -> void:
	if ghost:
		ghost.queue_free()
		ghost = null
	active_id = ""
	active_variant = ""
	if emit:
		cancelled.emit()


func _set_ghost_mat(m: Material) -> void:
	for mi in ghost.find_children("*", "MeshInstance3D", true, false):
		mi.material_override = m


func _process(_delta: float) -> void:
	if not is_active():
		return
	var cam := player.camera
	var vp := get_viewport()
	var center := vp.get_visible_rect().size * 0.5
	var from := cam.project_ray_origin(center)
	var to := from + cam.project_ray_normal(center) * 30.0
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var pos: Vector3
	if hit:
		pos = hit.position
	else:
		# луч ушёл в небо/воду — ставим перед игроком
		pos = player.global_position - Basis(Vector3.UP, player.model.rotation.y).z * 3.0
	# прицел упал под ноги герою — отодвигаем постройку вперёд, чтобы её было видно и герой не стоял внутри
	var from_p := Vector3(pos.x - player.global_position.x, 0, pos.z - player.global_position.z)
	var min_d: float = float(Data.BUILDINGS[active_id].get("radius", 1.0)) + 1.0
	if from_p.length() < min_d:
		var fw := -Basis(Vector3.UP, player.camera_yaw).z
		pos = player.global_position + fw * min_d
	pos.x = snappedf(pos.x, 0.5)
	pos.z = snappedf(pos.z, 0.5)
	pos.y = island.height_at(pos.x, pos.z)
	var cfg: Dictionary = Data.BUILDINGS[active_id]
	if cfg.get("shore", false):
		pos.y = maxf(pos.y, 0.0)
	var snap_rot := ghost_rot
	if cfg.get("spot", false):
		# мосток — только на отмеченном месте: призрак прилипает к ближайшим колышкам
		var groups: Array = cfg["spot"] if cfg["spot"] is Array else ["bridge_spot"]
		var sp := free_spot(pos, 4.0, groups)
		valid = sp != null and sp.global_position.distance_to(player.global_position) < 12.0
		if sp:
			pos = sp.global_position
			snap_rot = sp.rotation.y
		ghost.global_position = pos
		ghost.rotation.y = snap_rot
		_set_ghost_mat(_ok_mat if valid else _bad_mat)
		return
	ghost.global_position = pos
	ghost.rotation.y = ghost_rot
	reason = ""
	valid = _check_valid(pos, cfg)
	if valid:
		reason = quest_place_problem(active_id, pos)
		valid = reason == ""
	_set_ghost_mat(_ok_mat if valid else _bad_mat)


## Пока задание просит построить это в определённом месте (палатку — на поляне у лагеря,
## костёр — у палатки), строить можно только там. Возвращает, что не так, или "".
func quest_place_problem(id: String, pos: Vector3) -> String:
	var q := Game.current_quest()
	if q.is_empty() or not Game.quest_started:
		return ""
	for t in q["tasks"]:
		if t["kind"] != "built" or t["target"] != id or not t.has("near") or Game.task_progress(t) >= t["count"]:
			continue
		if t.has("where") and t["where"] != Game.location:
			continue
		var p2 := Vector2(pos.x, pos.z)
		var near: String = t["near"]
		var r: float = t.get("near_r", CAMP_R if near == "camp" else 4.5)
		if near == "camp":
			if p2.distance_to(Vector2(island.camp_center.x, island.camp_center.z)) > r:
				return "Для задания: ставь на поляне у лагеря, рядом с обломками лодки"
			continue
		var ok := false
		for b in get_tree().get_nodes_in_group("building"):
			if b.id == near and Vector2(b.global_position.x, b.global_position.z).distance_to(p2) < r:
				ok = true
		if not ok:
			return "Для задания: ставь рядом с постройкой «%s»" % Data.BUILDINGS[near]["name"]
	return ""


## Свободное место под мосток рядом с точкой (или null).
func free_spot(pos: Vector3, within: float, groups: Array = ["bridge_spot"]) -> Node3D:
	var best: Node3D = null
	var all: Array = []
	for g in groups:
		all.append_array(get_tree().get_nodes_in_group(g))
	for s in all:
		var sp := s as Node3D
		if sp.get("used"):
			continue
		var d := Vector2(sp.global_position.x - pos.x, sp.global_position.z - pos.z).length()
		if d < within and (best == null or d < Vector2(best.global_position.x - pos.x, best.global_position.z - pos.z).length()):
			best = sp
	return best


func _check_valid(pos: Vector3, cfg: Dictionary) -> bool:
	var r: float = cfg["radius"]
	if pos.distance_to(player.global_position) > 12.0:
		return false
	if cfg.get("shore", false):
		# плот: центр у кромки воды
		var h := island.height_at(pos.x, pos.z)
		if h > 0.4 or h < -1.5:
			return false
	else:
		if island.height_at(pos.x, pos.z) < 0.35:
			return false
		# не слишком крутой склон
		var hs: Array[float] = []
		for a in 6:
			var ang := TAU * a / 6.0
			hs.append(island.height_at(pos.x + cos(ang) * r, pos.z + sin(ang) * r))
		if hs.max() - hs.min() > 0.9:
			return false
	var p2 := Vector2(pos.x, pos.z)
	for group in ["building", "obstacle"]:
		for b in get_tree().get_nodes_in_group(group):
			if not b.has_method("block_radius"):
				continue
			var br: float = b.block_radius()
			if br > 0.0 and Vector2(b.global_position.x, b.global_position.z).distance_to(p2) < r + br + 0.1:
				return false
	if not cfg.get("shore", false) and Vector2(player.global_position.x, player.global_position.z).distance_to(p2) < r + 0.35:
		return false
	return true


func _unhandled_input(event: InputEvent) -> void:
	if not is_active():
		return
	if event.is_action_pressed("rotate_build"):
		ghost_rot += PI / 4.0
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			get_viewport().set_input_as_handled()
			_try_place()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			get_viewport().set_input_as_handled()
			cancel()
	elif event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		cancel()


func _try_place() -> void:
	if not valid:
		Game.notified.emit(reason if reason != "" else "Здесь строить нельзя", Color("ff9d7a"))
		return
	var cfg: Dictionary = Data.BUILDINGS[active_id]
	if not Game.pay(cost_of(active_id, active_variant)):
		Game.notified.emit("Не хватает ресурсов", Color("ff9d7a"))
		return
	var id := active_id
	var v := active_variant
	var b := spawn_building(id, ghost.global_position, ghost.rotation.y, v)
	Game.notified.emit("Построено: %s" % cfg["name"], Color("8affa0"))
	Audio.play("build", -2.0, 0.05)
	cancel(false)
	placed.emit(b)
	Game.bump("built", id)
	# дешёвые вещи (факелы, заборы, дорожки) можно ставить подряд
	if id in ["torch", "fence", "shell_path", "flowerbed", "garden_bed"] and Game.can_afford(cost_of(id, v)):
		start(id, v)


## Создать постройку нужного класса.
func spawn_building(id: String, pos: Vector3, rot: float, variant := "", state := {}) -> Building:
	var b: Building
	match id:
		"garden_bed": b = GardenBed.new()
		"fruit_tree": b = FruitTree.new()
		"coop", "goat_pen", "beehive", "sheep_pen", "pig_sty", "goose_house", "lightning_rod": b = AnimalPen.new()
		"greenhouse": b = Greenhouse.new()
		"tortoise_pen": b = AnimalPen.new()
		_: b = Building.new()
	b.setup(id, variant)
	b.position = pos
	b.rotation.y = rot
	buildings_root.add_child(b)
	if not state.is_empty():
		b.apply_state(state)
	return b
