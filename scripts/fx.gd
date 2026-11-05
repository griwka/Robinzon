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


## Парящий значок над объектом (созрело / голодны). Возвращает узел, чтобы им управлять.
static func marker(parent: Node3D, height: float) -> Node3D:
	# Цветной шарик в белой и коричневой обводке — читается с любого ракурса.
	var root := Node3D.new()
	root.name = "Marker"
	root.position.y = height
	for layer in [[0.3, Color("6b4524")], [0.25, Color("fff6dc")]]:
		var shell := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = layer[0]
		sm.height = layer[0] * 2.0
		shell.mesh = sm
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.cull_mode = BaseMaterial3D.CULL_FRONT
		m.albedo_color = layer[1]
		shell.material_override = m
		shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(shell)
	var dot := MeshInstance3D.new()
	dot.name = "Icon"
	var d := SphereMesh.new()
	d.radius = 0.19
	d.height = 0.38
	dot.mesh = d
	dot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(dot)
	parent.add_child(root)
	root.visible = false
	return root


static func set_marker(m: Node3D, visible: bool, color := Color.WHITE) -> void:
	if m == null:
		return
	m.visible = visible
	if visible:
		(m.get_node("Icon") as MeshInstance3D).material_override = Models.unshaded(color)
