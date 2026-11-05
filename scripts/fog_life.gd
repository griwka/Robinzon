class_name FogLife
extends Node3D
## Светлячки Туманного острова: мигающие зелёные огоньки над болотом. Ловятся сачком (по одному),
## через полминуты на острове загорается новый. Иногда в сачок попадает ночной мотылёк — в коллекцию.

const COUNT := 14

var island: Island


func _ready() -> void:
	for i in COUNT:
		var b := Bug.new()
		b.life = self
		add_child(b)
		b.relocate()


## Случайное место на суше, где растёт трава (а не на пляже и не на холме).
func random_spot() -> Vector3:
	for k in 60:
		var x := randf_range(-island.radius, island.radius)
		var z := randf_range(-island.radius, island.radius)
		var h := island.height_at(x, z)
		if h > 0.6 and h < 4.0:
			return Vector3(x, h + randf_range(0.8, 1.6), z)
	return island.camp_center + Vector3(randf_range(-4, 4), 1.2, randf_range(-4, 4))


class Bug extends Node3D:
	var life: FogLife
	var model: Node3D
	var anchor := Vector3.ZERO
	var _t := 0.0
	var active := true

	func _ready() -> void:
		add_to_group("interactable")
		add_to_group("firefly")
		model = Models.glb("firefly")
		if model == null:
			var mi := MeshInstance3D.new()
			mi.mesh = Models.sphere(0.06, 8, 5)
			mi.material_override = Models.flame_mat(Color("f4ffb0"), Color("b8ff5a"), 3.0)
			model = mi
		add_child(model)
		_t = randf() * 10.0

	func relocate() -> void:
		anchor = life.random_spot()
		global_position = anchor
		active = true
		visible = true
		if not is_in_group("interactable"):
			add_to_group("interactable")

	func _process(delta: float) -> void:
		_t += delta
		if not active:
			return
		global_position = anchor + Vector3(sin(_t * 0.9) * 0.6, sin(_t * 1.7) * 0.25, cos(_t * 0.7) * 0.6)
		model.scale = Vector3.ONE * (0.75 + 0.35 * maxf(0.0, sin(_t * 3.0)))

	func interact_point() -> Vector3:
		return global_position

	func tool_hint() -> String:
		return "net"

	func get_hint() -> String:
		return "Светлячок — поймать сачком" if Game.has_tool("net") else "Светлячок (нужен сачок)"

	func interact(_player: Node) -> void:
		if not active:
			return
		if not Game.has_tool("net"):
			Game.notified.emit("Нужен сачок", Color("ff9d7a"))
			return
		active = false
		visible = false
		remove_from_group("interactable")
		Game.add_item("firefly", 1)
		Game.bump("caught", "firefly")
		FX.burst(get_parent(), global_position, Color("e8ff7a"), 10)
		if randf() < 0.25:
			Game.add_collectible("moths")
		get_tree().create_timer(30.0, false).timeout.connect(relocate)
