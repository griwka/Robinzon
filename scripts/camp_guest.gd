class_name CampGuest
extends StaticBody3D
## Вечерний гость у костра («вечная игра»): житель заходит в уютный лагерь, говорит пару реплик и иногда
## приносит маленький подарок. Не поговорил — ничего не теряешь: утром гость уходит, завтра придёт другой.
## Кто, что говорит и что дарит — CozyLife.GUESTS. Создаёт и убирает гостя CozyLife.

var guest_id := "marta"
var target := Vector3.ZERO      # место у костра
var fire := Vector3.ZERO        # сам костёр (к нему гость стоит лицом)
var talked := false
var leaving := false
var model: Node3D
var head: Node3D
var _t := 0.0
var _away := Vector3.ZERO


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("camp_guest")
	collision_layer = 4
	model = Models.glb(NPCPerson.MODELS.get(guest_id, guest_id))
	if model:
		add_child(model)
		var body := model.get_node_or_null("Body")
		head = body.get_node_or_null("Head") if body else null
	var cs := CollisionShape3D.new()
	var c := CapsuleShape3D.new()
	c.radius = 0.35
	c.height = 1.7
	cs.shape = c
	cs.position.y = 0.85
	add_child(cs)
	_away = global_position


func who() -> String:
	return Data.SPEAKERS.get(guest_id, {}).get("name", guest_id)


func arrived() -> bool:
	return Vector2(global_position.x - target.x, global_position.z - target.z).length() < 0.15


func _process(delta: float) -> void:
	_t += delta
	var goal := _away if leaving else target
	var d := Vector3(goal.x - global_position.x, 0, goal.z - global_position.z)
	if d.length() > 0.15:
		# идёт: спокойным шагом, чуть покачиваясь
		var step := d.normalized() * minf(d.length(), 1.6 * delta)
		global_position += step
		var isl := get_tree().get_first_node_in_group("island") as Island
		if isl:
			global_position.y = isl.height_at(global_position.x, global_position.z)
		rotation.y = lerp_angle(rotation.y, atan2(d.x, d.z), 6.0 * delta)
		if model:
			model.position.y = absf(sin(_t * 7.0)) * 0.04
	else:
		if leaving:
			queue_free()
			return
		if model:
			model.position.y = 0.0
		var look := fire - global_position
		var p := get_tree().get_first_node_in_group("player") as Node3D
		if p and p.global_position.distance_to(global_position) < 4.0:
			look = p.global_position - global_position
		rotation.y = lerp_angle(rotation.y, atan2(look.x, look.z), 3.0 * delta)
	if head:
		head.rotation.z = sin(_t * 0.8) * 0.1


func interact_point() -> Vector3:
	return global_position + Vector3(0, 1.2, 0)


func tool_hint() -> String:
	return ""


func get_hint() -> String:
	return "%s — %s" % [who(), "посидеть вместе у костра" if talked else "поговорить"]


func interact(_player: Node) -> void:
	CozyLife.talk_to_guest(self)


## Гость уходит домой (утром).
func leave() -> void:
	leaving = true
	remove_from_group("interactable")
