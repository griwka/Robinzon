class_name Animal
extends Node3D
## Домашнее животное: бродит вокруг дома, клюёт/жуёт, его можно погладить.

var kind := "chicken"
var home := Vector3.ZERO
var radius := 1.5
var model: Node3D
var body: Node3D
var head: Node3D
var _target := Vector3.ZERO
var _wait := 0.0
var _t := 0.0
var _island: Island
var _pet_cooldown := 0.0
var _voice_t := randf_range(6.0, 20.0)


func _ready() -> void:
	add_to_group("interactable")
	match kind:
		"chicken": model = Models.chicken()
		"goat": model = Models.goat()
		_:
			model = Models.glb(kind)
			if model == null:
				model = Models.goat()
	add_child(model)
	body = model.get_node("Body")
	head = body.get_node("Head")
	_island = get_tree().get_first_node_in_group("island")
	_t = randf() * 10.0
	_pick_target()


func _pick_target() -> void:
	var a := randf() * TAU
	var r := sqrt(randf()) * radius
	_target = home + Vector3(cos(a) * r, 0, sin(a) * r)
	_wait = randf_range(0.5, 3.0)


func _process(delta: float) -> void:
	_t += delta
	_pet_cooldown -= delta
	_voice_t -= delta
	if _voice_t <= 0.0:
		_voice_t = randf_range(10.0, 25.0)
		Audio.play({"chicken": "cluck", "pig": "oink", "goose": "honk"}.get(kind, "bleat"), -9.0, 0.15, global_position)
	var speed := 0.7 if kind in ["chicken", "goose"] else 0.5
	var to := _target - global_position
	to.y = 0
	var moving := false
	if _wait > 0.0:
		_wait -= delta
	elif to.length() > 0.1:
		var step := to.normalized() * speed * delta
		global_position += step
		model.rotation.y = lerp_angle(model.rotation.y, atan2(-to.x, -to.z), 8.0 * delta)
		moving = true
	else:
		_pick_target()
	if _island:
		global_position.y = _island.height_at(global_position.x, global_position.z)
	# анимация
	if moving:
		body.position.y = abs(sin(_t * (14.0 if kind == "chicken" else 9.0))) * 0.05
		body.rotation.z = sin(_t * 12.0) * 0.06
		head.rotation.x = 0.0
	else:
		body.position.y = 0.0
		body.rotation.z = 0.0
		# клюёт зёрнышки / жуёт травку
		var peck := sin(_t * (6.0 if kind == "chicken" else 2.0))
		head.rotation.x = maxf(0.0, peck) * (0.9 if kind == "chicken" else 0.4)


func happy() -> void:
	if not is_inside_tree() or model == null:
		return
	FX.hearts(self, Vector3(0, 1.0, 0))
	var tw := create_tween()
	tw.tween_property(model, "position:y", 0.3, 0.12)
	tw.tween_property(model, "position:y", 0.0, 0.15)


func interact_point() -> Vector3:
	return global_position + Vector3(0, 0.4, 0)


func tool_hint() -> String:
	return ""


func get_hint() -> String:
	return "Погладить %s" % {"chicken": "курочку", "goat": "козу", "sheep": "овечку", "pig": "поросёнка"}.get(kind, "зверя")


func interact(_player: Node) -> void:
	if _pet_cooldown > 0.0:
		return
	_pet_cooldown = 1.0
	happy()
	Audio.play({"chicken": "cluck", "pig": "oink"}.get(kind, "bleat"), -2.0, 0.12, global_position)
	Game.bump("petted", kind)
	var lines := {"chicken": ["Ко-ко-ко!", "Курочка довольно кудахчет", "Курица смотрит на тебя одним глазом"],
		"goat": ["Ме-е-е!", "Коза жуёт и не обращает внимания", "Коза бодает тебя в руку — ещё!"],
		"sheep": ["Бе-е-е!", "Овечка тёплая и мягкая, как облако", "Овечка жмурится от удовольствия"],
		"pig": ["Хрю!", "Поросёнок радостно виляет хвостиком", "Поросёнок тычется пятачком тебе в ладонь"]}
	var l: Array = lines[kind]
	Game.notified.emit(l[randi() % l.size()], Color("ffe08a"))
