class_name FX
## Маленькие визуальные эффекты: щепки, сердечки, всплывающие значки.


static func burst(parent: Node3D, pos: Vector3, color: Color, amount := 12) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = true
	p.amount = amount
	p.lifetime = 0.6
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 4.0
	p.gravity = Vector3(0, -12, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	var m := BoxMesh.new()
	m.size = Vector3(0.08, 0.08, 0.08)
	m.material = Models.unshaded(color)
	p.mesh = m
	parent.add_child(p)
	p.position = pos
	parent.get_tree().create_timer(1.5).timeout.connect(p.queue_free)


## Сердечки над животным, которое погладили.
static func hearts(parent: Node3D, pos: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = true
	p.amount = 5
	p.lifetime = 1.2
	p.explosiveness = 0.7
	p.direction = Vector3.UP
	p.spread = 25.0
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 1.6
	p.gravity = Vector3(0, 0.3, 0)
	var m := SphereMesh.new()
	m.radius = 0.07
	m.height = 0.12
	m.material = Models.unshaded(Color("ff5a8a"))
	p.mesh = m
	parent.add_child(p)
	p.position = pos
	parent.get_tree().create_timer(2.0).timeout.connect(p.queue_free)


## Парящий значок над объектом (созрело / голодны / есть разговор): облачко с иконкой.
static func marker(parent: Node3D, height: float) -> Node3D:
	var root := Node3D.new()
	root.name = "Marker"
	root.position.y = height
	var bubble := Sprite3D.new()
	bubble.name = "Bubble"
	bubble.texture = icon_texture("bubble")
	bubble.pixel_size = 0.0055
	bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bubble.shaded = false
	bubble.render_priority = 1
	bubble.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(bubble)
	var icon := Sprite3D.new()
	icon.name = "Icon"
	icon.pixel_size = 0.0036
	icon.offset = Vector2(0, 8)
	icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	icon.shaded = false
	icon.render_priority = 2
	icon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(icon)
	parent.add_child(root)
	root.visible = false
	return root


static var _tex_cache: Dictionary = {}


static func icon_texture(id: String) -> Texture2D:
	if _tex_cache.has(id):
		return _tex_cache[id]
	var path := "res://assets/icons/%s.png" % id
	var t: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_tex_cache[id] = t
	return t


static func set_marker(m: Node3D, visible: bool, icon := "") -> void:
	if m == null:
		return
	m.visible = visible
	if visible:
		(m.get_node("Icon") as Sprite3D).texture = icon_texture(icon)
