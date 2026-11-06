class_name Player
extends CharacterBody3D
## Игрок: чиби-персонаж с "резиновой" анимацией, камера от третьего лица, взаимодействие.

const WALK_SPEED := 4.5
const SPRINT_SPEED := 7.5
const JUMP_VELOCITY := 6.0
const GRAVITY := 18.0
const INTERACT_RANGE := 2.6
const SWING_TIME := 0.38
const STAMINA_MAX := 100.0
const CLIMB_SPEED := 2.3

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
var stamina := STAMINA_MAX
var climbing: Climbable = null
var force_indoor := false             # внутри башни (Великий маяк): камера ближе, как в бункере
var ext_push := Vector3.ZERO          # ветер на открытом балконе толкает героя
var near_climb: Climbable = null
var _climb_side := Vector3.FORWARD
var _climb_phase := 0.0
# ощущение от управления: тряска камеры, бег, приземление, вода, всплывающие значки
const FOV := 52.0
var trauma := 0.0              # 0..1, тряска = trauma² (мелкие толчки почти не видны, сильные — заметны)
var _shake_t := 0.0
var _shake := FastNoiseLite.new()
var _fall_speed := 0.0
var _in_water := false
var _popup_stack := 0
var _popup_t := 0.0


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
	Game.inventory_changed.connect(update_clothes)
	Game.item_gained.connect(_on_item_gained)
	_update_tool()
	update_clothes()
	_shake.seed = 17
	_shake.frequency = 0.9


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


# ------------------------------------------------------------------ Тёплая одежда (Ледяной остров)
var _clothes: Array[Node3D] = []
var _clothes_key := ""


## Тёплую одежду видно на герое там, где холодно: свитер или куртка, валенки, рукавицы.
## Каждая вещь — модель из Blender с кусками Torso / SleeveL / SleeveR / BootL / BootR / MittenL / MittenR,
## у каждого куска точка вращения — в суставе, так что он просто вешается на нужный сустав.
func update_clothes() -> void:
	var wear: Array[String] = []
	if Game.cold_active():
		if Game.has_tool("down_jacket"):
			wear.append("wear_jacket")
		elif Game.has_tool("sweater"):
			wear.append("wear_sweater")
		if Game.has_tool("felt_boots"):
			wear.append("wear_boots")
		if Game.has_tool("mittens"):
			wear.append("wear_mittens")
	elif Game.location == "volcano" and Game.has_tool("fire_gloves"):
		wear.append("wear_fire_gloves")
	var key := ",".join(wear)
	if key == _clothes_key:
		return
	_clothes_key = key
	for c in _clothes:
		if is_instance_valid(c):
			c.queue_free()
	_clothes.clear()
	if body_pivot == null:
		return
	var joints := {"Torso": body_pivot, "SleeveL": arm_l, "SleeveR": arm_r, "BootL": leg_l, "BootR": leg_r,
		"MittenL": arm_l, "MittenR": arm_r}
	for w in wear:
		var g := Models.glb(w)
		if g == null:
			continue
		for piece_name in joints:
			var piece := g.get_node_or_null(piece_name) as Node3D
			if piece == null:
				continue
			g.remove_child(piece)
			piece.owner = null
			piece.transform = Transform3D.IDENTITY
			(joints[piece_name] as Node3D).add_child(piece)
			_clothes.append(piece)
			for mi in piece.find_children("*", "MeshInstance3D", true, false):
				(mi as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		g.queue_free()


func _update_tool() -> void:
	for c in hand_tool.get_children():
		c.queue_free()
	var want := ""
	if target and is_instance_valid(target) and target.has_method("tool_hint"):
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
	if target != null and not is_instance_valid(target):
		target = null   # объект расчищен и удалён
	if controls_enabled and Input.is_action_just_pressed("eat"):
		# на морозе Q — сначала кружка чая (если тепло на исходе), иначе еда
		if not (Game.warmth < 85.0 and Warmth.drink_tea()) and not (Game.heat > 25.0 and Heat.use_salve()):
			var v := Game.eat_best_food()
			stamina = minf(STAMINA_MAX, stamina + v * 2.0)
	if climbing:
		_climb(delta)
		return
	_find_climb()
	if near_climb and controls_enabled and Input.is_action_just_pressed("jump"):
		if near_climb.locked_hint != "":
			Game.notified.emit(near_climb.locked_hint, Color("ffe08a"))
		elif not near_climb.ladder and Game.storm_active():
			Game.notified.emit("В грозу лианы и скалы мокрые — соскользнёшь. Переждите грозу", Color("ff9d7a"))
		elif near_climb.ice and not (Game.has_tool("ice_pick") and Game.has_tool("climbing_gloves")):
			Game.notified.emit("По льду не залезть голыми руками: нужны ледоруб и перчатки лазальщика", Color("ff9d7a"))
		elif not near_climb.ladder and Game.frozen():
			Game.notified.emit("Пальцы замёрзли и не держат. Сначала согрейся у огня", Color("bfe3ff"))
		elif not near_climb.ladder and not Game.has_tool("climbing_gloves"):
			Game.notified.emit("Голыми руками по лиане не залезть — нужны перчатки лазальщика", Color("ff9d7a"))
		elif stamina < 10.0:
			Game.notified.emit("Нет сил. Отдохни или поешь (Q)", Color("ff9d7a"))
		else:
			_start_climb(near_climb)
			return
	if is_on_floor():
		stamina = minf(STAMINA_MAX, stamina + 30.0 * delta)
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
	if Game.frozen():
		speed = WALK_SPEED * 0.5   # замёрз: еле идёшь

	var accel := 12.0 if is_on_floor() else 4.0
	velocity.x = lerpf(velocity.x, dir.x * speed + ext_push.x, accel * delta)
	velocity.z = lerpf(velocity.z, dir.z * speed + ext_push.z, accel * delta)
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	elif controls_enabled and Input.is_action_just_pressed("jump") and near_climb == null:
		velocity.y = JUMP_VELOCITY
		_squash = 1.25

	# в открытое море не уплыть: глубина держит у берега
	var isl := get_tree().get_first_node_in_group("island")
	if isl:
		var ahead := global_position + Vector3(velocity.x, 0, velocity.z) * 0.25
		if isl.height_at(ahead.x, ahead.z) < -0.9 and global_position.y < 0.2:   # на мостках над водой — можно
			velocity.x = 0.0
			velocity.z = 0.0
	# в воде — медленнее и всплываем
	if global_position.y < -0.6:
		velocity.x *= 0.92
		velocity.z *= 0.92
		velocity.y = maxf(velocity.y, 1.5)
	move_and_slide()

	if not is_on_floor():
		_fall_speed = maxf(_fall_speed, -velocity.y)
	if is_on_floor() and not _was_on_floor:
		_squash = 0.75 if _fall_speed < 8.0 else 0.62  # приземление — сплющиваемся
		Audio.play("step_sand%d" % randi_range(0, 3), -5.0, 0.05)
		var hard := clampf((_fall_speed - 4.0) / 8.0, 0.0, 1.0)
		if _fall_speed > 3.0 and global_position.y > -0.3:
			FX.dust(self, Vector3(0, 0.05, 0), _ground_dust(), int(5 + hard * 8), 0.35 + hard * 0.25)
		if hard > 0.3:
			add_trauma(0.2 * hard)
		_fall_speed = 0.0
	_was_on_floor = is_on_floor()
	# вошли в воду — брызги
	var wet := global_position.y < -0.35
	if wet and not _in_water and velocity.length() > 1.5:
		FX.splash(get_parent(), Vector3(global_position.x, -0.1, global_position.z))
		Audio.play("water", -8.0, 0.2)
	_in_water = wet

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
	# плавное следование, одинаковое при любом FPS (экспоненциальное сглаживание)
	cam_rig.global_position = cam_rig.global_position.lerp(global_position + Vector3(0, 1.4, 0), 1.0 - exp(-11.0 * delta))
	cam_rig.rotation.y = camera_yaw
	# в бункере потолок низкий: камера ближе и почти на уровне глаз, чтобы не упираться в ярус выше
	var indoor := global_position.y < -8.0 or force_indoor
	cam_pitch_node.rotation.x = clampf(camera_pitch, -0.32, 0.35) if indoor else camera_pitch
	var want_dist := minf(camera_distance, 4.2) if indoor else camera_distance
	spring.spring_length = lerpf(spring.spring_length, want_dist, 1.0 - exp(-8.0 * delta))
	# тряска: шум Перлина, сила = trauma², затухает сама
	_shake_t += delta * 28.0
	var k := trauma * trauma
	camera.h_offset = _shake.get_noise_2d(_shake_t, 0.0) * 0.32 * k
	camera.v_offset = _shake.get_noise_2d(_shake_t, 40.0) * 0.26 * k
	camera.rotation.z = _shake.get_noise_2d(_shake_t, 80.0) * 0.045 * k
	trauma = maxf(0.0, trauma - delta * 1.8)
	# на бегу кадр чуть «раскрывается» — скорость чувствуется
	var running := Input.is_action_pressed("sprint") and Vector2(velocity.x, velocity.z).length() > WALK_SPEED + 0.5
	camera.fov = lerpf(camera.fov, FOV + (5.0 if running else 0.0), 1.0 - exp(-4.0 * delta))


## Встряхнуть камеру (удар, падение дерева, тяжёлое приземление). amount ~0.1 — лёгкий толчок, 0.5 — сильный.
func add_trauma(amount: float) -> void:
	if not Game.settings.get("shake", true):
		return
	trauma = minf(1.0, trauma + amount)


func _ground_dust() -> Color:
	var isl := get_tree().get_first_node_in_group("island")
	if isl and isl.height_at(global_position.x, global_position.z) < 1.1:
		return Color("f1dfb0")
	return Color("d9cfa8")


## Предмет попал в сумку — значок «+N» над головой (несколько подряд — стопкой).
func _on_item_gained(id: String, amount: int) -> void:
	if not is_inside_tree() or DisplayServer.get_name() == "headless":
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - _popup_t > 0.6:
		_popup_stack = 0
	_popup_t = now
	FX.popup(get_parent(), global_position + Vector3(0, 2.1 + _popup_stack * 0.42, 0), id, amount)
	_popup_stack = (_popup_stack + 1) % 4


# ------------------------------------------------------------------ Анимация
func _animate(delta: float, speed: float) -> void:
	var moving := clampf(speed / WALK_SPEED, 0.0, 1.6)
	var prev_phase := _walk_phase
	_walk_phase += delta * (4.0 + speed * 1.6)
	# шаги: звук, когда нога касается земли
	if is_on_floor() and moving > 0.3 and int(prev_phase / PI) != int(_walk_phase / PI):
		var isl := get_tree().get_first_node_in_group("island")
		var h_here: float = isl.height_at(global_position.x, global_position.z) if isl else 5.0
		var on_sand: bool = isl != null and h_here < 1.1
		var on_snow: bool = Game.cold_active() and (h_here > Island.SNOW_LINE or global_position.y > h_here + 0.5)
		# у песка и травы по четыре варианта шага — чтобы не звучало одним и тем же звуком
		var step := "step_snow" if on_snow else ("step_sand%d" % randi_range(0, 3) if on_sand else "step_grass%d" % randi_range(0, 3))
		Audio.play(step, -12.0 + moving * 2.0, 0.06)
		if on_sand and moving > 1.2 and global_position.y > -0.3:
			FX.dust(self, Vector3(0, 0.05, 0.1), Color("f1dfb0"), 2, 0.22)
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
	# дрожь на морозе: тепло кончилось — сильно, на исходе — чуть-чуть
	var shiver := 0.0
	if Game.cold_active() and Game.warmth < 25.0:
		shiver = 0.012 if Game.warmth <= 0.0 else 0.005
	model.position.x = sin(_walk_phase * 9.0 + Time.get_ticks_msec() * 0.06) * shiver


# ------------------------------------------------------------------ Лазание
func _find_climb() -> void:
	near_climb = null
	for c in get_tree().get_nodes_in_group("climb"):
		var b: Vector3 = c.world_bottom()
		var t: Vector3 = c.world_top()
		if Vector2(global_position.x - b.x, global_position.z - b.z).length() < 1.0 \
				and global_position.y > b.y - 0.7 and global_position.y < t.y - 0.8:
			near_climb = c
			return


func _start_climb(c: Climbable) -> void:
	climbing = c
	var b := c.world_bottom()
	var side := Vector3(global_position.x - b.x, 0, global_position.z - b.z)
	_climb_side = side.normalized() if side.length() > 0.05 else -Basis(Vector3.UP, model.rotation.y).z * -1.0
	velocity = Vector3.ZERO
	Audio.play("rustle", -4.0)


func _stop_climb(push := Vector3.ZERO) -> void:
	climbing = null
	velocity = push


func _climb(delta: float) -> void:
	var b := climbing.world_bottom()
	var t := climbing.world_top()
	var up := 0.0
	if controls_enabled:
		up = Input.get_action_strength("move_forward") - Input.get_action_strength("move_back")
	var cold_k := 1.3 if Game.cold_active() else 1.0
	stamina -= (9.0 if abs(up) > 0.1 else 2.5) * delta * (0.35 if climbing.ladder else cold_k)
	# порыв ветра на открытой стене: лезть тяжело, лучше прижаться и переждать
	var gusty: bool = climbing.wind and GreatLighthouse.gust > 0.5
	if gusty and abs(up) > 0.1:
		stamina -= 18.0 * delta
	# на зарубке или уступе можно повисеть — силы возвращаются
	if climbing.rest_step > 0.0 and abs(up) < 0.1 and climbing.at_rest(global_position.y - b.y) and not gusty:
		stamina = minf(STAMINA_MAX, stamina + 2.5 * delta * cold_k + 14.0 * delta)
	var y := global_position.y + up * CLIMB_SPEED * delta
	global_position = Vector3(b.x, 0, b.z) + _climb_side * 0.45 + Vector3(0, y, 0)
	model.rotation.y = lerp_angle(model.rotation.y, atan2(_climb_side.x, _climb_side.z), 10.0 * delta)
	# поза лазания: руки и ноги перехватываются по очереди
	_climb_phase += delta * abs(up) * 7.0
	var sw := sin(_climb_phase)
	arm_l.rotation.x = -2.6 + sw * 0.5
	arm_r.rotation.x = -2.6 - sw * 0.5
	leg_l.rotation.x = -0.5 - sw * 0.4
	leg_r.rotation.x = -0.5 + sw * 0.4
	if abs(up) > 0.1 and int(_climb_phase / PI) != int((_climb_phase - delta * 7.0) / PI):
		Audio.play("rustle", -14.0, 0.2)
	_update_camera(delta)
	if y >= t.y - 1.0:
		global_position = climbing.world_exit()
		_stop_climb()
		return
	if y <= b.y + 0.05 and up < 0.0:
		_stop_climb()
		return
	if controls_enabled and Input.is_action_just_pressed("jump"):
		_stop_climb(_climb_side * 3.0 + Vector3(0, 3.0, 0))
		return
	if stamina <= 0.0:
		stamina = 0.0
		Game.notified.emit("Пальцы разжались — сил не хватило!", Color("ff9d7a"))
		_stop_climb(_climb_side * 1.5)


# ------------------------------------------------------------------ Взаимодействие
func _find_target() -> void:
	var best: Node = null
	var best_score := INF
	var forward := -Basis(Vector3.UP, model.rotation.y).z
	var me := global_position
	for n in get_tree().get_nodes_in_group("interactable"):
		# быстрый отсев по расстоянию — объектов на острове больше тысячи
		if (n as Node3D).global_position.distance_squared_to(me) > 49.0:
			continue
		var p: Vector3 = n.interact_point()
		var to := p - global_position
		if absf(to.y) > 3.0:
			continue   # сильно выше или ниже (уступ, ярус) — рукой не достать
		to.y *= 0.5
		var d := to.length()
		var reach := INTERACT_RANGE
		if n is Building and n.id in ["hut", "goat_pen", "coop", "tent"]:
			reach = 3.2
		if n is NPCPerson and n.npc_id == "walrus":
			reach = 3.4
		if n is ResourceNode and n.kind in ["charred_tree", "basalt", "obsidian_rock", "ore_vein", "mangrove"]:
			reach = 3.4
		if n is ResourceNode and n.kind in ["rock", "jungle_tree", "cliff", "fallen_log", "thicket", "bamboo", "crooked_tree", "rockfall", "ice_wall", "pine"]:
			reach = 3.4
		if n is StoryPlace:
			reach = 3.6
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
	if climbing:
		if climbing.wind and GreatLighthouse.gust > 0.5:
			return "Порыв ветра! Прижмись к стене — не лезь, пока не стихнет"
		if climbing.rest_step > 0.0:
			var rest := climbing.at_rest(global_position.y - climbing.world_bottom().y)
			return "W — вверх,  S — вниз,  Пробел — спрыгнуть" + (("   ·   %s: повиси, отдышись" % ("зарубка" if climbing.ice else "уступ")) if rest else ",  Q — поесть")
		return "W — вверх,  S — вниз,  Пробел — спрыгнуть" + ("" if climbing.ladder else ",  Q — поесть")
	if near_climb and (target == null or not is_instance_valid(target)):
		if near_climb.locked_hint != "":
			return near_climb.locked_hint
		if near_climb.ice:
			return "[Пробел]  Лезть по ледяной стене" if Game.has_tool("ice_pick") and Game.has_tool("climbing_gloves") \
				else "Ледяная стена (нужны ледоруб и перчатки лазальщика)"
		if near_climb.holds != "":
			return "[Пробел]  Лезть по выступам стены маяка" if Game.has_tool("climbing_gloves") 				else "Стена маяка (нужны перчатки лазальщика)"
		if near_climb.rock:
			return "[Пробел]  Лезть по выступам базальта (на стене жарко!)" if Game.has_tool("climbing_gloves") \
				else "Стена кратера (нужны перчатки лазальщика)"
		if near_climb.ladder:
			return "[Пробел]  Лезть по лестнице"
		return "[Пробел]  Лезть по лиане" if Game.has_tool("climbing_gloves") else "Лиана (нужны перчатки лазальщика)"
	if target == null or not is_instance_valid(target):
		return ""
	return "[ЛКМ / E]  " + target.get_hint()
