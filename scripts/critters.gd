class_name Critters
extends Node3D
## Живность для уюта: бабочки днём (ловятся сачком), крабы на пляже, светлячки ночью.

var island: Island
var player: Node3D
var crabs: Array[Node3D] = []
var crab_data: Array = []
var fireflies: CPUParticles3D


func setup(isl: Island, p: Node3D) -> void:
	island = isl
	player = p
	var g := RandomNumberGenerator.new()
	g.seed = 99
	# бабочки
	var colors: Array = []
	for it in Data.COLLECTIONS["butterflies"]["items"]:
		colors.append(it["color"])
	for i in 16:
		var b := Butterfly.new()
		b.island = island
		b.palette = colors
		add_child(b)
		b.relocate()
	# крабы
	var n := 0
	var tries := 0
	while n < 9 and tries < 3000:
		tries += 1
		var x := g.randf_range(-70, 70)
		var z := g.randf_range(-70, 70)
		var h := island.height_at(x, z)
		if h < 0.15 or h > 0.8:
			continue
		var c := Models.crab()
		add_child(c)
		c.position = Vector3(x, h, z)
		c.rotation.y = g.randf() * TAU
		crabs.append(c)
		crab_data.append({"origin": Vector3(x, h, z), "phase": g.randf() * TAU, "speed": g.randf_range(0.4, 0.8)})
		n += 1
	# светлячки
	fireflies = CPUParticles3D.new()
	fireflies.amount = 60
	fireflies.lifetime = 6.0
	fireflies.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	fireflies.emission_box_extents = Vector3(18, 1.5, 18)
	fireflies.direction = Vector3.UP
	fireflies.spread = 180.0
	fireflies.gravity = Vector3.ZERO
	fireflies.initial_velocity_min = 0.1
	fireflies.initial_velocity_max = 0.4
	fireflies.scale_amount_curve = _blink_curve()
	var m := SphereMesh.new()
	m.radius = 0.05
	m.height = 0.1
	m.material = Models.unshaded(Color("e8ff7a"))
	fireflies.mesh = m
	fireflies.local_coords = false
	add_child(fireflies)


func _blink_curve() -> Curve:
	var c := Curve.new()
	c.add_point(Vector2(0, 0))
	c.add_point(Vector2(0.2, 1))
	c.add_point(Vector2(0.5, 0.3))
	c.add_point(Vector2(0.7, 1))
	c.add_point(Vector2(1, 0))
	return c


func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for i in crabs.size():
		var d: Dictionary = crab_data[i]
		var c := crabs[i]
		var off := sin(t * d["speed"] + d["phase"]) * 1.5
		var right := Vector3(cos(c.rotation.y), 0, -sin(c.rotation.y))
		c.position = d["origin"] + right * off
		c.position.y = island.height_at(c.position.x, c.position.z)
		c.rotation.z = sin(t * 12.0 + i) * 0.08
	var night := not Game.is_day()
	fireflies.emitting = night
	if player:
		fireflies.global_position = player.global_position + Vector3(0, 1.2, 0)


class Butterfly extends Node3D:
	var island: Island
	var palette: Array = []
	var anchor := Vector3.ZERO
	var model: Node3D
	var _t := 0.0
	var _hidden_until := 0.0
	var active := true

	func _ready() -> void:
		add_to_group("interactable")
		_t = randf() * 100.0

	func relocate() -> void:
		if model:
			model.queue_free()
		model = Models.butterfly(palette[randi() % palette.size()])
		add_child(model)
		for i in 60:
			var x := randf_range(-45, 45)
			var z := randf_range(-45, 45)
			var h := island.height_at(x, z)
			if h > 1.3 and h < 7.0:
				anchor = Vector3(x, h, z)
				return

	func _process(delta: float) -> void:
		_t += delta
		var visible_now := Game.is_day() and Game.world_time >= _hidden_until
		visible = visible_now
		if visible_now != active:
			active = visible_now
			if active:
				add_to_group("interactable")
			else:
				remove_from_group("interactable")
		if not visible_now:
			return
		var prev := position
		position = anchor + Vector3(sin(_t * 0.7) * 1.8, 1.1 + sin(_t * 1.9) * 0.4, cos(_t * 0.5) * 1.8)
		var v := position - prev
		if v.length() > 0.0001:
			model.rotation.y = atan2(-v.x, -v.z)
		var flap := sin(_t * 22.0) * 0.9
		model.get_node("WingL").rotation.z = flap
		model.get_node("WingR").rotation.z = -flap

	func interact_point() -> Vector3:
		return global_position - Vector3(0, 0.6, 0)

	func tool_hint() -> String:
		return "net"

	func get_hint() -> String:
		return "Поймать бабочку" if Game.has_tool("net") else "Бабочка (нужен сачок)"

	func interact(_player: Node) -> void:
		if not Game.has_tool("net"):
			Game.notified.emit("Нужен сачок — его делают на верстаке", Color("ff9d7a"))
			return
		if not active:
			return
		FX.burst(get_parent(), position, Color("fff6dc"), 8)
		Game.add_collectible("butterflies")
		Game.bump("caught", "butterfly")
		_hidden_until = Game.world_time + 40.0
		relocate()
