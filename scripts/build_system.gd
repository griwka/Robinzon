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
var ghost: Node3D
var ghost_rot := 0.0
var valid := false
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


func start(id: String) -> void:
	cancel(false)
	active_id = id
	ghost = Models.building(id)
	for l in ghost.find_children("*", "OmniLight3D", true, false):
		l.queue_free()
	add_child(ghost)


func cancel(emit := true) -> void:
	if ghost:
		ghost.queue_free()
		ghost = null
	active_id = ""
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
	pos.x = snappedf(pos.x, 0.5)
	pos.z = snappedf(pos.z, 0.5)
	pos.y = island.height_at(pos.x, pos.z)
	var cfg: Dictionary = Game.BUILDINGS[active_id]
	if cfg.get("shore", false):
		pos.y = maxf(pos.y, 0.0)
	ghost.global_position = pos
	ghost.rotation.y = ghost_rot
	valid = _check_valid(pos, cfg)
	_set_ghost_mat(_ok_mat if valid else _bad_mat)


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
	for b in get_tree().get_nodes_in_group("building"):
		var br: float = Game.BUILDINGS[b.id]["radius"]
		if Vector2(b.global_position.x, b.global_position.z).distance_to(p2) < r + br:
			return false
	for n in get_tree().get_nodes_in_group("interactable"):
		if n is ResourceNode and n.active:
			var nr: float = ResourceNode.KINDS[n.kind]["radius"]
			if Vector2(n.global_position.x, n.global_position.z).distance_to(p2) < r + nr + 0.2:
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
		Game.notified.emit("Здесь строить нельзя", Color("ff9d7a"))
		return
	var cfg: Dictionary = Game.BUILDINGS[active_id]
	if not Game.pay(cfg["cost"]):
		Game.notified.emit("Не хватает ресурсов", Color("ff9d7a"))
		return
	var b := spawn_building(active_id, ghost.global_position, ghost_rot)
	Game.register_built(active_id)
	Game.notified.emit("Построено: %s" % cfg["name"], Color("8affa0"))
	var id := active_id
	cancel(false)
	placed.emit(b)
	# если хватает на ещё одну такую же (например, факелы) — остаёмся в режиме
	if id in ["torch", "shell_deco"] and Game.can_afford(Game.BUILDINGS[id]["cost"]):
		start(id)


func spawn_building(id: String, pos: Vector3, rot: float) -> Building:
	var b := Building.new()
	b.setup(id)
	b.position = pos
	b.rotation.y = rot
	buildings_root.add_child(b)
	return b
