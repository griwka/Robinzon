class_name FishingSpot
extends Node3D
## Место для рыбалки: бурлящая вода у берега.
## E с удочкой — закинуть. Ждёшь 1.5–4 c, поплавок ныряет — жми E за 1.2 c, иначе рыба сорвётся.
## Подсечь раньше поклёвки — спугнуть. Иногда вместо обычной рыбы попадается редкая (в коллекцию).

enum { IDLE, WAITING, BITE }

const BITE_WINDOW := 1.2
var state := IDLE
var ice := false        # лунка во льду (Ледяной остров): сначала просверлить ледовым буром
var hole_id := ""       # номер лунки — чтобы помнить, что её уже просверлили
var _hole: Node3D
var _timer := 0.0
var _t := 0.0
var bubbles: CPUParticles3D
var bobber: MeshInstance3D
var marker: Node3D


func _ready() -> void:
	add_to_group("interactable")
	if ice:
		_hole = Models.glb("ice_hole")
		if _hole:
			add_child(_hole)
			_refresh_hole()
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
	bubbles.mesh = FX._quad(FX.particle_mat(0.0, 0.45))   # пузырьки темнеют ночью вместе с миром
	bubbles.scale_amount_min = 0.1
	bubbles.scale_amount_max = 0.16
	bubbles.color = Color("eefcff")
	bubbles.position.y = 0.05
	add_child(bubbles)
	if ice:
		bubbles.emitting = drilled()
		bubbles.amount = 6
	bobber = MeshInstance3D.new()
	var bm := SphereMesh.new()
	bm.radius = 0.1
	bm.height = 0.2
	bobber.mesh = bm
	bobber.material_override = Models.mat(Color("e0553a"), true)
	bobber.visible = false
	add_child(bobber)


func interact_point() -> Vector3:
	return global_position + Vector3(0, 0.3, 0)


func drilled() -> bool:
	return not ice or Game.flags.get("drilled_" + hole_id, false)


func _refresh_hole() -> void:
	if _hole:
		var cap := _hole.find_child("Cap", true, false) as Node3D
		if cap:
			cap.visible = not drilled()


func tool_hint() -> String:
	return "fishing_rod" if drilled() else "ice_drill"


func get_hint() -> String:
	if not drilled():
		return "Просверлить лунку во льду" if Game.has_tool("ice_drill") else "Толстый лёд (нужен ледовый бур)"
	if not Game.has_tool("fishing_rod"):
		return ("Лунка во льду" if ice else "Бурлящая вода") + " (нужна удочка)"
	match state:
		WAITING: return "Ждём поклёвки... (E — смотать)"
		BITE: return "КЛЮЁТ! Жми E!"
	return "Закинуть удочку"


func interact(_player: Node) -> void:
	if not drilled():
		if not Game.has_tool("ice_drill"):
			Game.notified.emit("Лёд толстый — нужен ледовый бур (у Ингрид)", Color("ff9d7a"))
			return
		Game.flags["drilled_" + hole_id] = true
		Audio.play("ice", -2.0, 0.1, global_position)
		FX.burst(self, Vector3(0, 0.2, 0), Color("dff4ff"), 16)
		bubbles.emitting = true
		_refresh_hole()
		Game.notified.emit("Лунка готова. Теперь — удочку", Color("bfe3ff"))
		return
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
	if ice:
		Game.bump("fished", "ice_fish")
	FX.burst(get_parent(), global_position + Vector3(0, 0.3, 0), Color("bfe8ff"), 14)
	Audio.play("harvest", -2.0, 0.1)
	if randf() < (0.35 if ice else 0.3):
		Game.add_collectible("north_fish" if ice else "fish")


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
