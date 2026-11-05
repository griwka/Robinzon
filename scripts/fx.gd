class_name FX
## Визуальные эффекты: щепки, пыль, искры, листья, брызги, дым, сердечки, всплывающие значки.
## Все частицы — CPUParticles3D (работают на любом рендерере) и сами удаляются после проигрыша.
## Мягкие «комочки» (пыль, дым) рисуются шейдером fx_particle: круглые, в два тона, всегда лицом к камере.

const PARTICLE := preload("res://shaders/fx_particle.gdshader")

static var _pmat: Dictionary = {}
static var _meshes: Dictionary = {}


# ------------------------------------------------------------------ заготовки
## Материал мягкой частицы. glow > 0 — светится (искры, угли), иначе темнеет ночью вместе с миром.
static func particle_mat(glow := 0.0, softness := 0.25, stretch := 1.0) -> ShaderMaterial:
	var key := "%s|%s|%s" % [glow, softness, stretch]
	if _pmat.has(key):
		return _pmat[key]
	var m := ShaderMaterial.new()
	m.shader = PARTICLE
	m.set_shader_parameter("glow", glow)
	m.set_shader_parameter("softness", softness)
	m.set_shader_parameter("stretch", stretch)
	_pmat[key] = m
	return m


static func _quad(mat: Material) -> QuadMesh:
	var key := mat.get_instance_id()
	if _meshes.has(key):
		return _meshes[key]
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	q.material = mat
	_meshes[key] = q
	return q


static func curve(points: Array) -> Curve:
	var c := Curve.new()
	for p in points:
		c.add_point(p)
	return c


static func ramp(colors: Array, offsets: Array) -> Gradient:
	var g := Gradient.new()
	g.colors = PackedColorArray(colors)
	g.offsets = PackedFloat32Array(offsets)
	return g


## Разовый выброс частиц. pos — в координатах parent; сам эффект живёт в корне сцены,
## чтобы не исчезнуть вместе с объектом (срубленное дерево удаляется раньше, чем осядет пыль).
static func emitter(parent: Node, pos: Vector3, amount: int, lifetime: float) -> CPUParticles3D:
	# не one_shot: разовые излучатели CPUParticles3D в этой версии Godot иногда не показываются вовсе.
	# Обычный излучатель с почти мгновенным залпом выключаем до второго залпа — эффект тот же, но надёжно.
	var p := CPUParticles3D.new()
	p.emitting = false        # включим, когда вызывающий настроит сетку и параметры (см. restart ниже)
	p.amount = amount
	p.lifetime = lifetime
	p.explosiveness = 0.95
	p.local_coords = false
	var gp: Vector3 = (parent as Node3D).to_global(pos) if parent is Node3D else pos
	var root: Node = parent.get_tree().current_scene if parent.get_tree().current_scene else parent
	root.add_child(p)
	p.global_position = gp
	p.restart.call_deferred()
	var tree := p.get_tree()
	tree.create_timer(lifetime * 0.8, false).timeout.connect(func():
		if is_instance_valid(p):
			p.emitting = false)
	tree.create_timer(lifetime * 2.0 + 0.6, false).timeout.connect(func():
		if is_instance_valid(p):
			p.queue_free())
	return p


## Мягкая пыль / пар: комочки разлетаются, растут и тают.
static func puff(parent: Node, pos: Vector3, color: Color, amount := 6, size := 0.45, speed := 1.2, life := 0.7) -> CPUParticles3D:
	var p := emitter(parent, pos, amount, life)
	p.mesh = _quad(particle_mat())
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = size * 0.4
	p.direction = Vector3.UP
	p.spread = 80.0
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.damping_min = 2.0
	p.damping_max = 3.5
	p.gravity = Vector3(0, 0.4, 0)
	p.scale_amount_min = size * 0.7
	p.scale_amount_max = size * 1.2
	p.scale_amount_curve = curve([Vector2(0, 0.45), Vector2(0.35, 1.0), Vector2(1, 1.15)])
	p.color_ramp = ramp([Color(color, 0.85), Color(color, 0.7), Color(color, 0.0)], [0.0, 0.55, 1.0])
	p.lifetime_randomness = 0.3
	return p


## Удар по ресурсу: щепки/камешки разлетаются и падают, плюс облачко пыли.
static func burst(parent: Node3D, pos: Vector3, color: Color, amount := 12) -> void:
	var p := emitter(parent, pos, amount, 0.75)
	var m := BoxMesh.new()
	m.size = Vector3(0.09, 0.06, 0.09)
	m.material = Models.mat(color, false)
	p.mesh = m
	p.direction = Vector3.UP
	p.spread = 75.0
	p.initial_velocity_min = 2.2
	p.initial_velocity_max = 4.4
	p.gravity = Vector3(0, -14, 0)
	p.particle_flag_rotate_y = true
	p.angle_min = -180.0
	p.angle_max = 180.0
	p.angular_velocity_min = -500.0
	p.angular_velocity_max = 500.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	p.scale_amount_curve = curve([Vector2(0, 1), Vector2(0.7, 1), Vector2(1, 0)])
	puff(parent, pos, color.lerp(Color("f4ead2"), 0.55), 4, 0.4, 1.0, 0.55)


## Пыль под ногами: шаг по песку, приземление, установка постройки.
static func dust(parent: Node, pos: Vector3, color := Color("eadcb8"), amount := 5, size := 0.35) -> void:
	var p := puff(parent, pos, color, amount, size, 0.9, 0.6)
	p.direction = Vector3(0, 0.3, 0)
	p.spread = 180.0
	p.flatness = 0.6


## Кольцо пыли по земле (поставили постройку, упало дерево).
static func ring(parent: Node, pos: Vector3, color := Color("eadcb8"), radius := 1.0, amount := 14) -> void:
	var p := puff(parent, pos, color, amount, 0.45 + radius * 0.15, 1.6, 0.8)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = Vector3.UP
	p.emission_ring_radius = radius
	p.emission_ring_inner_radius = radius * 0.8
	p.emission_ring_height = 0.05
	p.direction = Vector3(0, 0.25, 0)
	p.spread = 180.0
	p.flatness = 0.85
	p.radial_accel_min = 1.5
	p.radial_accel_max = 3.0


## Объект расчищен: большое облачко «пуф».
static func poof(parent: Node, pos: Vector3, color: Color, size := 1.0) -> void:
	puff(parent, pos, color.lerp(Color("f6efe0"), 0.6), int(8 + size * 4), 0.55 * size, 1.8 * size, 0.8)


## Искры от камня: короткие яркие чёрточки, светятся.
static func sparks(parent: Node, pos: Vector3, amount := 9) -> void:
	var p := emitter(parent, pos, amount, 0.35)
	p.mesh = _quad(particle_mat(4.0, 0.5, 2.6))
	p.direction = Vector3.UP
	p.spread = 85.0
	p.initial_velocity_min = 3.5
	p.initial_velocity_max = 6.5
	p.gravity = Vector3(0, -16, 0)
	p.scale_amount_min = 0.05
	p.scale_amount_max = 0.09
	p.scale_amount_curve = curve([Vector2(0, 1), Vector2(1, 0.1)])
	p.color_ramp = ramp([Color("fff6c8"), Color("ffc24a"), Color(1.0, 0.5, 0.15, 0.0)], [0.0, 0.5, 1.0])


## Листья: кружатся и медленно опускаются.
static func leaves(parent: Node, pos: Vector3, color: Color, amount := 7) -> void:
	var p := emitter(parent, pos, amount, 1.4)
	var m := QuadMesh.new()
	m.size = Vector2(0.16, 0.09)
	var lm := Models.mat(color, false)
	m.material = lm
	p.mesh = m
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.4
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 3.0
	p.gravity = Vector3(0, -2.5, 0)
	p.damping_min = 1.5
	p.damping_max = 2.5
	p.particle_flag_rotate_y = true
	p.angle_min = -180.0
	p.angle_max = 180.0
	p.angular_velocity_min = -360.0
	p.angular_velocity_max = 360.0
	p.scale_amount_min = 0.8
	p.scale_amount_max = 1.4
	p.scale_amount_curve = curve([Vector2(0, 1), Vector2(0.8, 1), Vector2(1, 0)])


## Брызги воды: капли вверх и белый всплеск.
static func splash(parent: Node, pos: Vector3, amount := 10) -> void:
	var p := emitter(parent, pos, amount, 0.6)
	p.mesh = _quad(particle_mat(0.0, 0.35))
	p.direction = Vector3.UP
	p.spread = 35.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 3.8
	p.gravity = Vector3(0, -12, 0)
	p.scale_amount_min = 0.08
	p.scale_amount_max = 0.16
	p.color_ramp = ramp([Color(1, 1, 1, 0.95), Color(0.8, 0.95, 1.0, 0.0)], [0.6, 1.0])
	ring(parent, pos, Color("e8fbff"), 0.35, 8)


## Сердечки над животным, которое погладили.
static func hearts(parent: Node3D, pos: Vector3) -> void:
	var p := emitter(parent, pos, 5, 1.2)
	p.explosiveness = 0.7
	p.direction = Vector3.UP
	p.spread = 25.0
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 1.6
	p.gravity = Vector3(0, 0.3, 0)
	p.scale_amount_curve = curve([Vector2(0, 0.3), Vector2(0.2, 1.1), Vector2(0.8, 1.0), Vector2(1, 0)])
	var m := SphereMesh.new()
	m.radius = 0.07
	m.height = 0.12
	m.material = Models.unshaded(Color("ff5a8a"))
	p.mesh = m


## Дым и угольки над огнём — постоянный эффект (костёр, факел, маяк). scale — размер огня.
static func fire_smoke(parent: Node3D, pos: Vector3, scale := 1.0) -> void:
	var smoke := CPUParticles3D.new()
	smoke.name = "Smoke"
	smoke.amount = int(10 * clampf(scale, 0.6, 2.5))
	smoke.lifetime = 3.2
	smoke.local_coords = false
	smoke.mesh = _quad(particle_mat(0.0, 0.4))
	smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	smoke.emission_sphere_radius = 0.15 * scale
	smoke.direction = Vector3.UP
	smoke.spread = 12.0
	smoke.initial_velocity_min = 0.6 * scale
	smoke.initial_velocity_max = 1.0 * scale
	smoke.gravity = Vector3(0.25, 0.25, 0.1)
	smoke.damping_min = 0.2
	smoke.damping_max = 0.4
	smoke.scale_amount_min = 0.35 * scale
	smoke.scale_amount_max = 0.55 * scale
	smoke.scale_amount_curve = curve([Vector2(0, 0.4), Vector2(1, 2.2)])
	smoke.color_ramp = ramp([Color(0.62, 0.6, 0.68, 0.0), Color(0.62, 0.6, 0.68, 0.32), Color(0.7, 0.7, 0.78, 0.0)], [0.0, 0.15, 1.0])
	smoke.position = pos + Vector3(0, 0.5 * scale, 0)
	parent.add_child(smoke)
	var embers := CPUParticles3D.new()
	embers.name = "Embers"
	embers.amount = int(8 * clampf(scale, 0.6, 2.5))
	embers.lifetime = 1.4
	embers.local_coords = false
	embers.mesh = _quad(particle_mat(5.0, 0.5))
	embers.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	embers.emission_sphere_radius = 0.2 * scale
	embers.direction = Vector3.UP
	embers.spread = 25.0
	embers.initial_velocity_min = 1.0 * scale
	embers.initial_velocity_max = 2.0 * scale
	embers.gravity = Vector3(0, 0.6, 0)
	embers.tangential_accel_min = -1.5
	embers.tangential_accel_max = 1.5
	embers.scale_amount_min = 0.035
	embers.scale_amount_max = 0.06
	embers.scale_amount_curve = curve([Vector2(0, 1), Vector2(0.7, 0.8), Vector2(1, 0)])
	embers.color_ramp = ramp([Color("fff0a0"), Color("ff9a30"), Color(1.0, 0.35, 0.1, 0.0)], [0.0, 0.5, 1.0])
	embers.position = pos + Vector3(0, 0.3 * scale, 0)
	parent.add_child(embers)


## Всплывающий значок «+2 🪵» над головой: предмет попал в сумку.
static func popup(parent: Node3D, pos: Vector3, icon_id: String, amount: int) -> void:
	var root := Node3D.new()
	parent.add_child(root)
	root.global_position = pos
	var tex := icon_texture(icon_id)
	if tex:
		var s := Sprite3D.new()
		s.texture = tex
		s.pixel_size = 0.0034
		s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		s.shaded = false
		s.no_depth_test = true
		s.render_priority = 3
		s.position.x = -0.16
		root.add_child(s)
	var lb := Label3D.new()
	lb.text = "+%d" % amount
	lb.font_size = 56
	lb.outline_size = 14
	lb.modulate = Color("fff6dc")
	lb.outline_modulate = Color("5a3320")
	lb.pixel_size = 0.0045
	lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lb.no_depth_test = true
	lb.render_priority = 4
	lb.position.x = 0.22 if tex else 0.0
	root.add_child(lb)
	root.scale = Vector3.ONE * 0.3
	var tw := root.create_tween()
	tw.tween_property(root, "scale", Vector3.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(root, "global_position", pos + Vector3(0, 0.9, 0), 1.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(root, "scale", Vector3.ONE * 0.01, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(root.queue_free)


## «Стоп-кадр» на долю секунды при сильном ударе — удар ощущается весомым.
static func hitstop(node: Node, duration := 0.045) -> void:
	if DisplayServer.get_name() == "headless" or Engine.time_scale < 1.0 or not node.is_inside_tree():
		return
	Engine.time_scale = 0.05
	node.get_tree().create_timer(duration, true, false, true).timeout.connect(func(): Engine.time_scale = 1.0)


## Белая вспышка на объекте (удар): поверх его сеток на миг кладётся светлая полупрозрачная «плёнка»
## (material_overlay) — у каждого объекта своя, общие материалы не трогаем. Работает на любом рендерере.
static func flash(node: Node, strength := 1.0, time := 0.16) -> void:
	if node == null or not is_instance_valid(node):
		return
	var geo: Array = node.find_children("*", "MeshInstance3D", true, false)
	if node is MeshInstance3D:
		geo.append(node)
	if geo.is_empty():
		return
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1.0, 0.97, 0.9, 0.62 * strength)
	for g in geo:
		(g as MeshInstance3D).material_overlay = m
	var tw := node.create_tween()
	tw.tween_property(m, "albedo_color:a", 0.0, time).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		for g in geo:
			if is_instance_valid(g) and (g as MeshInstance3D).material_overlay == m:
				(g as MeshInstance3D).material_overlay = null)


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
	var was := m.visible
	m.visible = visible
	if visible:
		(m.get_node("Icon") as Sprite3D).texture = icon_texture(icon)
		if not was:   # появился — мягко «выпрыгивает»
			m.scale = Vector3.ONE * 0.2
			m.create_tween().tween_property(m, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


static func clear_caches() -> void:
	_pmat.clear()
	_meshes.clear()
	_tex_cache.clear()
