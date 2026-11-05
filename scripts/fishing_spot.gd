class_name FishingSpot
extends Node3D
## Место для рыбалки: бурлящая вода у берега.
## E с удочкой — закинуть. Ждёшь 1.5–4 c, поплавок ныряет — жми E за 1.2 c, иначе рыба сорвётся.
## Подсечь раньше поклёвки — спугнуть. Иногда вместо обычной рыбы попадается редкая (в коллекцию).

enum { IDLE, WAITING, BITE }

const BITE_WINDOW := 1.2
var state := IDLE
var _timer := 0.0
var _t := 0.0
var bubbles: CPUParticles3D
var bobber: MeshInstance3D
var marker: Node3D


func _ready() -> void:
	add_to_group("interactable")
	bubbles = CPUParticles3D.new()
	bubbles.amount = 14
	bubbles.lifetime = 1.4
	bubbles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	bubbles.emission_sphere_radius = 0.6
	bubbles.direction = Vector3.UP
	bubbles.spread = 15.0
	bubbles.initial_velocity_min = 0.2
	bubbles.initial_velocity_max = 0.5
	bubbles.gravity = Vector3.ZERO
	var m := SphereMesh.new()
	m.radius = 0.06
	m.height = 0.12
	m.material = Models.unshaded(Color("e8fbff"))
	bubbles.mesh = m
	bubbles.position.y = 0.05
	add_child(bubbles)
	bobber = MeshInstance3D.new()
	var bm := SphereMesh.new()
	bm.radius = 0.1
	bm.height = 0.2
	bobber.mesh = bm
	bobber.material_override = Models.unshaded(Color("d9573b"))
	bobber.visible = false
	add_child(bobber)


func interact_point() -> Vector3:
	return global_position + Vector3(0, 0.3, 0)


func tool_hint() -> String:
	return "fishing_rod"


func get_hint() -> String:
	if not Game.has_tool("fishing_rod"):
		return "Бурлящая вода (нужна удочка)"
	match state:
		WAITING: return "Ждём поклёвки... (E — смотать)"
		BITE: return "КЛЮЁТ! Жми E!"
	return "Закинуть удочку"


func interact(_player: Node) -> void:
	if not Game.has_tool("fishing_rod"):
		Game.notified.emit("Нужна удочка", Color("ff9d7a"))
		return
	match state:
		IDLE:
			state = WAITING
			_timer = randf_range(1.5, 4.0)
			bobber.visible = true
			bobber.position = Vector3(0, 0.05, 0)
			Audio.play("water", -8.0, 0.2)
		WAITING:
			state = IDLE
			bobber.visible = false
			Game.notified.emit("Рано — рыба испугалась", Color("ff9d7a"))
		BITE:
			catch()


func catch() -> void:
	state = IDLE
	bobber.visible = false
	Game.add_item("fish", 1)
	Game.bump("fished", "fish")
	FX.burst(get_parent(), global_position + Vector3(0, 0.3, 0), Color("bfe8ff"), 14)
	Audio.play("harvest", -2.0, 0.1)
	if randf() < 0.3:
		Game.add_collectible("fish")


func _process(delta: float) -> void:
	_t += delta
	if state == IDLE:
		return
	_timer -= delta
	if state == WAITING:
		bobber.position.y = 0.05 + sin(_t * 3.0) * 0.03
		if _timer <= 0.0:
			state = BITE
			_timer = BITE_WINDOW
			Audio.play("blip", 0.0, 0.0)
			Game.notified.emit("Клюёт!", Color("ffe08a"))
	elif state == BITE:
		bobber.position.y = -0.12 + sin(_t * 30.0) * 0.05
		if _timer <= 0.0:
			state = IDLE
			bobber.visible = false
			Game.notified.emit("Сорвалась!", Color("ff9d7a"))
