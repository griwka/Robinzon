class_name Player
extends CharacterBody3D
## Игрок: чиби-персонаж с "резиновой" анимацией, камера от третьего лица, взаимодействие.

const WALK_SPEED := 4.5
const SPRINT_SPEED := 7.5
const JUMP_VELOCITY := 6.0
const GRAVITY := 18.0
const INTERACT_RANGE := 2.6
const SWING_TIME := 0.38

var camera_yaw := 0.0
var camera_pitch := -0.62
var camera_distance := 9.0
var controls_enabled := true
var can_interact := true  # false в режиме строительства

var target: Node = null  # текущий объект взаимодействия

var cam_rig: Node3D
var cam_pitch_node: Node3D
var spring: SpringArm3D
var camera: Camera3D

var model: Node3D
var body_pivot: Node3D
var head: Node3D
var arm_l: Node3D
var arm_r: Node3D
var leg_l: Node3D
var leg_r: Node3D
var hand_tool: Node3D
var _walk_phase := 0.0
var _swing_t := 0.0
var _head_lag := Vector3.ZERO
var _lean := Vector2.ZERO
var _was_on_floor := true
var _squash := 1.0
var _body_y := 0.45


func _ready() -> void:
	add_to_group("player")
	collision_layer = 16
	collision_mask = 1 | 2 | 4
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.5
	cs.shape = cap
	cs.position.y = 0.75
	add_child(cs)
	floor_snap_length = 0.4
	floor_max_angle = deg_to_rad(50)
	_build_model()
	_build_camera()
	Game.inventory_changed.connect(_update_tool)
	_update_tool()


# ------------------------------------------------------------------ Модель
func _build_model() -> void:
	var g := Models.glb("player")
	if g:
		model = Node3D.new()
		model.name = "Model"
		add_child(model)
		model.add_child(g)
		body_pivot = g.get_node("Body")
		head = body_pivot.get_node("Head")
		arm_l = body_pivot.get_node("ArmL")
		arm_r = body_pivot.get_node("ArmR")
		leg_l = g.get_node("LegL")
		leg_r = g.get_node("LegR")
		_body_y = body_pivot.position.y
		hand_tool = Node3D.new()
		hand_tool.rotation = Vector3(PI / 2, 0, 0)
		var hand := arm_r.find_child("HandR", true, false) as Node3D
		(hand if hand else arm_r).add_child(hand_tool)
		for mi in g.find_children("*", "MeshInstance3D", true, false):
			(mi as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		return
	_build_model_simple()


func _build_model_simple() -> void:
	var skin := Color("f6c9a0")
	var shirt := Color("7f9a4a")   # рваная зелёная рубаха
	var shorts := Color("8a5a32")
	var hair := Color("e07a2e")    # рыжие волосы
	model = Node3D.new()
	model.name = "Model"
	add_child(model)
	body_pivot = Node3D.new()
	body_pivot.position.y = 0.45
	model.add_child(body_pivot)

	# ноги
	for side in [-1, 1]:
		var leg := Node3D.new()
		leg.position = Vector3(0.12 * side, 0.45, 0)
		model.add_child(leg)
		Models.part(leg, Models.capsule(0.09, 0.42), skin, Vector3(0, -0.22, 0))
		Models.part(leg, Models.capsule(0.11, 0.24), shorts, Vector3(0, -0.06, 0))
		Models.part(leg, Models.sphere(0.1, 8, 5), skin, Vector3(0, -0.43, -0.05), Vector3.ZERO, Vector3(1, 0.6, 1.5))
		if side < 0: leg_l = leg
		else: leg_r = leg

	# туловище
	Models.part(body_pivot, Models.capsule(0.24, 0.62), shirt, Vector3(0, 0.3, 0))
	Models.part(body_pivot, Models.cyl(0.25, 0.26, 0.12, 10), shorts, Vector3(0, 0.03, 0))

	# руки
	for side in [-1, 1]:
		var arm := Node3D.new()
		arm.position = Vector3(0.31 * side, 0.52, 0)
		body_pivot.add_child(arm)
		Models.part(arm, Models.capsule(0.075, 0.46), skin, Vector3(0, -0.2, 0))
		Models.part(arm, Models.sphere(0.1, 8, 5), shirt, Vector3(0, -0.02, 0))
		if side < 0: arm_l = arm
		else: arm_r = arm
	hand_tool = Node3D.new()
	hand_tool.position = Vector3(0, -0.4, 0)
	hand_tool.rotation = Vector3(PI / 2, 0, 0)
	arm_r.add_child(hand_tool)

	# голова (большая — чиби-пропорции)
	head = Node3D.new()
	head.position = Vector3(0, 0.95, 0)
	body_pivot.add_child(head)
	Models.part(head, Models.sphere(0.33, 16, 10), skin)
	Models.part(head, Models.sphere(0.35, 14, 8), hair, Vector3(0, 0.08, 0.05), Vector3(-0.2, 0, 0), Vector3(1.02, 0.85, 1.0))
	for i in 5:  # растрёпанная чёлка
		var a := (i - 2) * 0.32
		Models.part(head, Models.cyl(0.0, 0.08, 0.22, 5), hair,
			Vector3(sin(a) * 0.27, 0.2, -cos(a) * 0.24), Vector3(-1.0, a, 0))
	for side in [-1, 1]:
		Models.part(head, Models.sphere(0.06, 8, 6), Color("ffffff"), Vector3(0.12 * side, 0.0, -0.29), Vector3.ZERO, Vector3(1, 1.2, 0.5), false)
		Models.part(head, Models.sphere(0.038, 8, 6), Color("2b6b3a"), Vector3(0.12 * side, -0.005, -0.315), Vector3.ZERO, Vector3(1, 1.2, 0.5), false)
		Models.part(head, Models.sphere(0.05, 6, 4), Color("f29a8a"), Vector3(0.2 * side, -0.1, -0.25), Vector3.ZERO, Vector3(1, 0.6, 0.4), false)
		Models.part(head, Models.sphere(0.07, 6, 4), skin, Vector3(0.33 * side, -0.02, 0), Vector3.ZERO, Vector3(0.5, 1, 1))
	Models.part(head, Models.box(Vector3(0.1, 0.025, 0.02)), Color("a04a3a"), Vector3(0, -0.15, -0.31), Vector3.ZERO, Vector3.ONE, false)


func _update_tool() -> void:
	for c in hand_tool.get_children():
		c.queue_free()
	var want := ""
	if target and target.has_method("tool_hint"):
		want = target.tool_hint()
	if want == "" or not Game.has_tool(want):
		want = "stone_axe" if Game.has_tool("stone_axe") else ""
	if want != "":
		hand_tool.add_child(Models.tool_model(want))


# ------------------------------------------------------------------ Камера
func _build_camera() -> void:
	cam_rig = Node3D.new()
	cam_rig.name = "CameraRig"
	cam_rig.top_level = true
	add_child(cam_rig)
	cam_pitch_node = Node3D.new()
	cam_rig.add_child(cam_pitch_node)
	spring = SpringArm3D.new()
	spring.spring_length = camera_distance
	spring.collision_mask = 1 | 2 | 4  # рельеф, деревья/камни, постройки
	spring.margin = 0.3
	cam_pitch_node.add_child(spring)
	camera = Camera3D.new()
	camera.fov = 52
	camera.far = 900
	spring.add_child(camera)
	cam_rig.global_position = global_position + Vector3(0, 1.4, 0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sens: float = 0.003 * float(Game.settings.get("mouse", 1.0))
		camera_yaw -= event.relative.x * sens
		camera_pitch = clampf(camera_pitch - event.relative.y * sens, -1.3, 0.5)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera_distance = maxf(2.5, camera_distance - 0.5)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera_distance = minf(14.0, camera_distance + 0.5)


# ------------------------------------------------------------------ Движение
func _physics_process(delta: float) -> void:
	var input := Vector2.ZERO
	if controls_enabled:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var cam_basis := Basis(Vector3.UP, camera_yaw)
	var dir := (cam_basis * Vector3(input.x, 0, input.y))
	dir.y = 0
	if dir.length() > 1.0:
		dir = dir.normalized()
	var speed := SPRINT_SPEED if Input.is_action_pressed("sprint") else WALK_SPEED
	if _swing_t > 0.0:
		speed *= 0.4

	var accel := 12.0 if is_on_floor() else 4.0
	velocity.x = lerpf(velocity.x, dir.x * speed, accel * delta)
	velocity.z = lerpf(velocity.z, dir.z * speed, accel * delta)
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	elif controls_enabled and Input.is_action_just_pressed("jump"):
		velocity.y = JUMP_VELOCITY
		_squash = 1.25

	# в открытое море не уплыть: глубина держит у берега
	var isl := get_tree().get_first_node_in_group("island")
	if isl:
		var ahead := global_position + Vector3(velocity.x, 0, velocity.z) * 0.25
		if isl.height_at(ahead.x, ahead.z) < -0.9:
			velocity.x = 0.0
			velocity.z = 0.0
	# в воде — медленнее и всплываем
	if global_position.y < -0.6:
		velocity.x *= 0.92
		velocity.z *= 0.92
		velocity.y = maxf(velocity.y, 1.5)
	move_and_slide()

	if is_on_floor() and not _was_on_floor:
		_squash = 0.75  # приземление — сплющиваемся
		Audio.play("step_sand", -4.0, 0.1)
	_was_on_floor = is_on_floor()

	# поворот модели в сторону движения
	var flat := Vector2(velocity.x, velocity.z)
	if flat.length() > 0.3:
		var target_yaw := atan2(-velocity.x, -velocity.z)
		model.rotation.y = lerp_angle(model.rotation.y, target_yaw, 12.0 * delta)
	elif _swing_t > 0.0 and target:
		var to: Vector3 = target.global_position - global_position
		model.rotation.y = lerp_angle(model.rotation.y, atan2(-to.x, -to.z), 15.0 * delta)

	_animate(delta, flat.length())
	_update_camera(delta)
	_find_target()

	if controls_enabled and can_interact:
		var pressed := Input.is_action_just_pressed("attack") or Input.is_action_just_pressed("interact")
		var held := Input.is_action_pressed("attack") or Input.is_action_pressed("interact")
		# ресурсы можно добывать, удерживая кнопку; постройки — по одному нажатию
		if (target is ResourceNode and held) or (not (target is ResourceNode) and pressed):
			try_interact()
	if _swing_t > 0.0:
		_swing_t -= delta


func _update_camera(delta: float) -> void:
	cam_rig.global_position = cam_rig.global_position.lerp(global_position + Vector3(0, 1.4, 0), 10.0 * delta)
	cam_rig.rotation.y = camera_yaw
	cam_pitch_node.rotation.x = camera_pitch
	spring.spring_length = lerpf(spring.spring_length, camera_distance, 8.0 * delta)


# ------------------------------------------------------------------ Анимация
func _animate(delta: float, speed: float) -> void:
	var moving := clampf(speed / WALK_SPEED, 0.0, 1.6)
	var prev_phase := _walk_phase
	_walk_phase += delta * (4.0 + speed * 1.6)
	# шаги: звук, когда нога касается земли
	if is_on_floor() and moving > 0.3 and int(prev_phase / PI) != int(_walk_phase / PI):
		var isl := get_tree().get_first_node_in_group("island")
		var on_sand: bool = isl != null and isl.height_at(global_position.x, global_position.z) < 1.1
		Audio.play("step_sand" if on_sand else "step_grass", -10.0 + moving * 2.0, 0.15)
	var swing := sin(_walk_phase) * 0.75 * moving
	if not is_on_floor():
		leg_l.rotation.x = lerpf(leg_l.rotation.x, -0.6, 10 * delta)
		leg_r.rotation.x = lerpf(leg_r.rotation.x, 0.4, 10 * delta)
	else:
		leg_l.rotation.x = swing
		leg_r.rotation.x = -swing
	arm_l.rotation.x = -swing * 0.8
	arm_l.rotation.z = -0.12 - (0.6 if not is_on_floor() else 0.0)

	# удар правой рукой
	if _swing_t > 0.0:
		var t := 1.0 - _swing_t / SWING_TIME
		arm_r.rotation.x = lerpf(-2.6, 0.6, smoothstep(0.0, 0.55, t)) if t < 0.7 else lerpf(0.6, 0.0, (t - 0.7) / 0.3)
	else:
		arm_r.rotation.x = swing * 0.8
	arm_r.rotation.z = 0.12 + (0.6 if not is_on_floor() else 0.0)

	# покачивание тела и "резиновая" голова с запаздыванием
	body_pivot.position.y = _body_y + abs(sin(_walk_phase)) * 0.06 * moving
	var local_vel := model.global_transform.basis.inverse() * velocity
	_lean = _lean.lerp(Vector2(local_vel.z, local_vel.x) * 0.04, 6.0 * delta)
	body_pivot.rotation.x = _lean.x   # наклон вперёд при беге
	body_pivot.rotation.z = -_lean.y  # крен в сторону движения
	_head_lag = _head_lag.lerp(Vector3(-local_vel.z * 0.03, 0, local_vel.x * 0.03), 4.0 * delta)
	head.rotation.x = _head_lag.x + sin(_walk_phase * 2.0) * 0.04 * moving
	head.rotation.z = -_head_lag.z

	_squash = lerpf(_squash, 1.0, 10.0 * delta)
	model.scale = Vector3(1.0 / sqrt(_squash), _squash, 1.0 / sqrt(_squash))


# ------------------------------------------------------------------ Взаимодействие
func _find_target() -> void:
	var best: Node = null
	var best_score := INF
	var forward := -Basis(Vector3.UP, model.rotation.y).z
	for n in get_tree().get_nodes_in_group("interactable"):
		var p: Vector3 = n.interact_point()
		var to := p - global_position
		to.y *= 0.5
		var d := to.length()
		var reach := INTERACT_RANGE
		if n is Building and n.id in ["hut", "goat_pen", "coop", "tent"]:
			reach = 3.2
		if n is ResourceNode and n.kind == "rock":
			reach = 3.0
		if d > reach:
			continue
		var facing := forward.dot(Vector3(to.x, 0, to.z).normalized())
		var score := d - facing * 1.2
		if score < best_score:
			best_score = score
			best = n
	if best != target:
		target = best
		_update_tool()


func try_interact() -> void:
	if _swing_t > 0.0 or target == null:
		return
	_swing_t = SWING_TIME
	var t := target
	# эффект удара — в середине замаха
	get_tree().create_timer(SWING_TIME * 0.45).timeout.connect(func():
		if is_instance_valid(t) and t == target:
			t.interact(self))


func get_hint() -> String:
	if target == null:
		return ""
	return "[ЛКМ / E]  " + target.get_hint()
