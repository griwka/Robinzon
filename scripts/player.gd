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
const CARRY_ANGLE := PI - 0.5   # наклон инструмента в руке, когда его несут (не во время удара)
var back_tool: Node3D     # инструмент за спиной, когда руки свободны
var _hand_id := ""
var _back_id := ""
var _walk_phase := 0.0
var _swing_t := 0.0
var swing_kind := "hands"   # чем работаем сейчас: инструмент или "hands" (рвать, подбирать, говорить)
var pose_hold := -1.0       # для скриншотов: застывшая фаза удара 0..1
var _swing_lean := 0.0
var _swing_twist := 0.0
var _swing_crouch := 0.0
var _whoosh_done := false
var _head_lag := Vector3.ZERO
var _lean := Vector2.ZERO
var _was_on_floor := true
var _squash := 1.0
var _body_y := 0.45
var stamina := STAMINA_MAX
var climbing: Climbable = null
var build_aim := false               # строим: камера смотрит на точку перед героем, чтобы он не заслонял место
var force_indoor := false             # внутри башни (Великий маяк): камера ближе, как в бункере
var ext_push := Vector3.ZERO          # ветер на открытом балконе толкает героя
var near_climb: Climbable = null
const GRASS_SLOW := 0.6
var in_grass := false          # идём сквозь густую траву или папоротник — медленнее
var near_climb_down := false   # стоим у верха подъёма — Пробел: спуститься по нему (с балкона маяка, яруса, ледника)
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
	collision_mask = 1 | 2 | 4 | ResourceNode.CAP_LAYER   # + «крышки» над преградами: на них не запрыгнуть
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
	Game.held_changed.connect(_update_tool)
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
		# кисть — на конце руки, в 0.41 м под плечом (узел HandR в модели стоит не там — у ступней)
		hand_tool.position = Vector3(0.05, -0.41, -0.04)
		arm_r.add_child(hand_tool)
		_make_back_tool()
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
	_make_back_tool()

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


## Крепление за спиной: инструмент висит наискосок, рукоять у плеча.
func _make_back_tool() -> void:
	back_tool = Node3D.new()
	back_tool.name = "BackTool"
	back_tool.position = Vector3(-0.16, 0.36, 0.3)
	back_tool.rotation = Vector3(0.0, 0.0, PI - 0.95)
	body_pivot.add_child(back_tool)


## В руке — выбранный инструмент (клавиши 1–0 или взят сам, когда понадобился). Топор, мачете или кирка,
## которых нет в руке, висят за спиной.
func _update_tool() -> void:
	var want := Game.held_tool()
	var back := ""
	for id in ["stone_axe", "machete", "pickaxe", "iron_pickaxe"]:
		if Game.has_tool(id) and id != want:
			back = id
			break
	if want != _hand_id:
		_hand_id = want
		for c in hand_tool.get_children():
			c.queue_free()
		if want != "":
			hand_tool.add_child(Models.tool_model(want))
	if back_tool and back != _back_id:
		_back_id = back
		for c in back_tool.get_children():
			c.queue_free()
		if back != "":
			back_tool.add_child(Models.tool_model(back))


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
		elif near_climb_down:
			_start_climb_down(near_climb)
			return
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
	if in_grass:
		speed *= GRASS_SLOW   # густая трава не стена, но идти сквозь неё труднее
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

	# в открытое море не уплыть: на глубине нельзя плыть дальше от острова. Назад к берегу и вдоль него —
	# можно всегда (раньше на глубине обнулялось всё движение, и прыгнувший в воду герой застревал)
	var isl := get_tree().get_first_node_in_group("island") as Island
	if isl and global_position.y < 0.2:   # на мостках над водой — можно
		var hv := Vector3(velocity.x, 0, velocity.z)
		var ahead := global_position + hv * 0.25
		if isl.height_at(ahead.x, ahead.z) < -0.9:
			var out := Vector3(global_position.x - isl.global_position.x, 0, global_position.z - isl.global_position.z)
			if out.length() > 0.01:
				out = out.normalized()
				var away := hv.dot(out)
				if away > 0.0:
					velocity.x -= out.x * away
					velocity.z -= out.z * away
	# в воде — медленнее и всплываем. Вода — только над морским дном: под землёй (бункер на Грозовом острове
	# уходит ниже уровня моря) никакой воды нет, иначе героя тянет к потолку
	if in_water():
		velocity.x *= 0.92
		velocity.z *= 0.92
		velocity.y = maxf(velocity.y, 1.5)
	move_and_slide()

	if not is_on_floor():
		_fall_speed = maxf(_fall_speed, -velocity.y)
	if is_on_floor() and not _was_on_floor:
		_squash = 0.75 if _fall_speed < 8.0 else 0.62  # приземление — сплющиваемся
		Audio.play("step_sand", -5.0, 0.05)
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
	_update_highlight()

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
	var focus := global_position + Vector3(0, 1.4, 0)
	if build_aim:
		# при строительстве — в центре экрана место в трёх шагах впереди, герой внизу кадра
		var ahead := 3.2 - 1.4 * clampf((-camera_pitch - 0.5) / 0.6, 0.0, 1.0)   # смотрим сверху — сдвиг меньше, герой в кадре
		focus += -Basis(Vector3.UP, camera_yaw).z * ahead + Vector3(0, -0.6, 0)
	cam_rig.global_position = cam_rig.global_position.lerp(focus, 1.0 - exp(-(6.0 if build_aim else 11.0) * delta))
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
	if now - _popup_t > 0.9:
		_popup_stack = 0
	_popup_t = now
	FX.popup(get_parent(), global_position + Vector3(0, 1.85 + _popup_stack * 0.3, 0), id, amount)   # сразу над головой
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
		var step := "step_snow" if on_snow else ("step_sand" if on_sand else "step_grass")
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

	# работа руками и инструментом: у каждого инструмента свой замах (см. _work_pose)
	_swing_lean = 0.0
	_swing_twist = 0.0
	_swing_crouch = 0.0
	var working := _swing_t > 0.0 or pose_hold >= 0.0
	if working:
		var t := pose_hold if pose_hold >= 0.0 else 1.0 - _swing_t / SWING_TIME
		_work_pose(swing_kind, t)
	else:
		_whoosh_done = false
		if _hand_id != "":
			arm_r.rotation.x = -0.3 + swing * 0.25   # несём инструмент: рука чуть вперёд, рукоять вверх
		else:
			arm_r.rotation.x = swing * 0.8
		arm_r.rotation.y = 0.0
		arm_r.rotation.z = 0.12 + (0.6 if not is_on_floor() else 0.0)
		arm_l.rotation.y = 0.0
		# когда инструмент несут — он стоймя (наклон задаём от корпуса, а не от кисти: рукоять вверх, землю не цепляет)
		if hand_tool and _hand_id != "":
			hand_tool.global_basis = model.global_basis.orthonormalized() * Basis.from_euler(Vector3(_carry_pitch(_hand_id), 0.0, -0.25 if _hand_id != "watering_can" else 0.0))

	# покачивание тела и "резиновая" голова с запаздыванием
	body_pivot.position.y = _body_y + abs(sin(_walk_phase)) * 0.06 * moving
	var local_vel := model.global_transform.basis.inverse() * velocity
	_lean = _lean.lerp(Vector2(local_vel.z, local_vel.x) * 0.04, 6.0 * delta)
	body_pivot.rotation.x = _lean.x + _swing_lean   # наклон вперёд при беге и при ударе
	body_pivot.rotation.z = -_lean.y  # крен в сторону движения
	body_pivot.rotation.y = _swing_twist
	body_pivot.position.y -= _swing_crouch
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


## Значение по ключевым кадрам [[t, v], ...] с мягкими переходами.
static func _keys(t: float, k: Array) -> float:
	if t <= float(k[0][0]):
		return float(k[0][1])
	for i in range(1, k.size()):
		var t1: float = k[i][0]
		if t <= t1:
			var t0: float = k[i - 1][0]
			var f := smoothstep(0.0, 1.0, (t - t0) / maxf(t1 - t0, 0.0001))
			return lerpf(float(k[i - 1][1]), float(k[i][1]), f)
	return float(k[k.size() - 1][1])


## Поза работы в фазе t (0 — начало, 1 — конец). Удар (момент, когда предмет откликается) — около t = 0.45–0.55.
## arm.x < 0 — рука вперёд/вверх, arm.z > 0 у правой — в сторону; наклон корпуса < 0 — вперёд, поворот > 0 — влево.
## Инструмент направляем от корпуса: pitch — куда смотрит головка (0 — вниз, PI/2 — вперёд, PI — вверх,
## больше PI — за спину), yaw — поворот вбок (> 0 — влево), spin — вращение вокруг своей оси.
func _work_pose(kind: String, t: float) -> void:
	var c := _carry_pitch(_hand_id)
	var pitch := c
	var yaw := 0.0
	var spin := 0.0
	match kind:
		"stone_axe":
			# рубка: замах из-за правого плеча, удар сверху вниз двумя руками, корпус подаётся вперёд
			arm_r.rotation.x = _keys(t, [[0.0, -0.3], [0.32, -2.95], [0.5, -0.6], [0.7, -0.45], [1.0, -0.3]])
			arm_r.rotation.z = _keys(t, [[0.0, 0.12], [0.32, 0.4], [0.5, 0.0], [1.0, 0.12]])
			arm_l.rotation.x = _keys(t, [[0.0, 0.0], [0.32, -2.5], [0.5, -0.7], [1.0, 0.0]])
			arm_l.rotation.z = _keys(t, [[0.0, -0.12], [0.32, 0.25], [0.5, 0.3], [1.0, -0.12]])
			pitch = _keys(t, [[0.0, c], [0.32, PI * 1.28], [0.5, PI * 0.42], [0.7, PI * 0.36], [1.0, c]])
			yaw = _keys(t, [[0.0, 0.0], [0.32, -0.35], [0.5, 0.05], [1.0, 0.0]])
			_swing_lean = _keys(t, [[0.0, 0.0], [0.32, 0.16], [0.5, -0.3], [0.7, -0.22], [1.0, 0.0]])
			_swing_twist = _keys(t, [[0.0, 0.0], [0.32, -0.3], [0.5, 0.12], [1.0, 0.0]])
			_swing_crouch = _keys(t, [[0.0, 0.0], [0.5, 0.06], [1.0, 0.0]])
		"pickaxe", "iron_pickaxe", "ice_pick":
			# кирка тяжелее: долгий прямой замах над головой, удар отвесно вниз, глубокий наклон
			arm_r.rotation.x = _keys(t, [[0.0, -0.3], [0.38, -3.05], [0.52, -0.45], [0.75, -0.35], [1.0, -0.3]])
			arm_l.rotation.x = _keys(t, [[0.0, 0.0], [0.38, -2.8], [0.52, -0.55], [1.0, 0.0]])
			arm_l.rotation.z = _keys(t, [[0.0, -0.12], [0.38, 0.15], [0.52, 0.3], [1.0, -0.12]])
			pitch = _keys(t, [[0.0, c], [0.38, PI * 1.35], [0.52, PI * 0.36], [0.75, PI * 0.3], [1.0, c]])
			_swing_lean = _keys(t, [[0.0, 0.0], [0.38, 0.22], [0.52, -0.4], [0.75, -0.32], [1.0, 0.0]])
			_swing_crouch = _keys(t, [[0.0, 0.0], [0.52, 0.1], [1.0, 0.0]])
		"machete":
			# мачете: рука отводится вправо на уровне груди, клинок рубит поперёк справа налево
			arm_r.rotation.x = _keys(t, [[0.0, -0.3], [0.3, -1.45], [0.5, -1.35], [0.75, -0.9], [1.0, -0.3]])
			arm_r.rotation.z = _keys(t, [[0.0, 0.12], [0.3, 1.2], [0.5, -0.5], [0.75, -0.4], [1.0, 0.12]])
			arm_l.rotation.x = _keys(t, [[0.0, 0.0], [0.3, -0.5], [0.5, -0.2], [1.0, 0.0]])
			pitch = _keys(t, [[0.0, c], [0.3, PI * 0.55], [0.5, PI * 0.5], [0.75, PI * 0.45], [1.0, c]])
			yaw = _keys(t, [[0.0, 0.0], [0.3, -1.35], [0.5, 0.95], [0.75, 0.8], [1.0, 0.0]])
			_swing_twist = _keys(t, [[0.0, 0.0], [0.3, -0.45], [0.5, 0.4], [0.75, 0.3], [1.0, 0.0]])
			_swing_lean = _keys(t, [[0.0, 0.0], [0.5, -0.12], [1.0, 0.0]])
		"shovel":
			# лопата: вонзить вниз, нажать, поддеть и откинуть землю
			arm_r.rotation.x = _keys(t, [[0.0, -0.3], [0.25, -1.1], [0.45, -0.5], [0.7, -1.25], [1.0, -0.3]])
			arm_l.rotation.x = _keys(t, [[0.0, 0.0], [0.25, -1.3], [0.45, -0.7], [0.7, -1.4], [1.0, 0.0]])
			arm_l.rotation.z = _keys(t, [[0.0, -0.12], [0.25, 0.3], [1.0, -0.12]])
			pitch = _keys(t, [[0.0, c], [0.25, PI * 0.3], [0.45, PI * 0.12], [0.7, PI * 0.55], [1.0, c]])
			_swing_lean = _keys(t, [[0.0, 0.0], [0.25, -0.15], [0.45, -0.38], [0.7, -0.05], [1.0, 0.0]])
			_swing_crouch = _keys(t, [[0.0, 0.0], [0.45, 0.12], [0.7, 0.03], [1.0, 0.0]])
		"watering_can":
			# лейка: поднять перед собой, наклонить носиком вниз, подержать, вернуть
			arm_r.rotation.x = _keys(t, [[0.0, -0.3], [0.25, -1.25], [0.85, -1.2], [1.0, -0.3]])
			arm_r.rotation.z = _keys(t, [[0.0, 0.12], [0.25, -0.1], [1.0, 0.12]])
			pitch = _keys(t, [[0.0, c], [0.25, 0.0], [0.42, -0.85], [0.8, -0.85], [0.95, 0.0], [1.0, c]])
			_swing_lean = _keys(t, [[0.0, 0.0], [0.4, -0.12], [1.0, 0.0]])
			if t > 0.42 and not _whoosh_done:
				_whoosh_done = true
				FX.burst(self, -model.global_basis.z * 0.9 + Vector3(0, 0.45, 0), Color("7fc8f0"), 12)   # брызги из носика
		"net":
			# сачок: широкий взмах дугой справа сверху вниз — «накрыть»
			arm_r.rotation.x = _keys(t, [[0.0, -0.3], [0.3, -2.7], [0.55, -1.05], [0.8, -0.8], [1.0, -0.3]])
			arm_r.rotation.z = _keys(t, [[0.0, 0.12], [0.3, 0.9], [0.55, -0.3], [1.0, 0.12]])
			pitch = _keys(t, [[0.0, c], [0.3, PI * 1.12], [0.55, PI * 0.42], [0.8, PI * 0.36], [1.0, c]])
			yaw = _keys(t, [[0.0, 0.0], [0.3, -0.6], [0.55, 0.45], [1.0, 0.0]])
			_swing_twist = _keys(t, [[0.0, 0.0], [0.3, -0.3], [0.55, 0.3], [1.0, 0.0]])
			_swing_lean = _keys(t, [[0.0, 0.0], [0.55, -0.2], [1.0, 0.0]])
		"fishing_rod":
			# заброс: удилище назад за плечо и резко вперёд
			arm_r.rotation.x = _keys(t, [[0.0, -0.3], [0.35, -2.9], [0.5, -1.2], [0.7, -1.0], [1.0, -0.3]])
			pitch = _keys(t, [[0.0, c], [0.35, PI * 1.22], [0.5, PI * 0.62], [0.75, PI * 0.58], [1.0, c]])
			_swing_lean = _keys(t, [[0.0, 0.0], [0.35, 0.15], [0.5, -0.15], [1.0, 0.0]])
		"ice_drill":
			# бур: обе руки на рукояти, бур отвесно вниз и крутится, корпус налегает сверху
			arm_r.rotation.x = _keys(t, [[0.0, -0.3], [0.15, -0.95], [0.85, -0.95], [1.0, -0.3]])
			arm_l.rotation.x = _keys(t, [[0.0, 0.0], [0.15, -0.95], [0.85, -0.95], [1.0, 0.0]])
			arm_l.rotation.z = _keys(t, [[0.0, -0.12], [0.15, 0.35], [0.85, 0.35], [1.0, -0.12]])
			pitch = _keys(t, [[0.0, c], [0.15, 0.0], [0.85, 0.0], [1.0, c]])
			spin = t * TAU * 3.0
			_swing_lean = _keys(t, [[0.0, 0.0], [0.15, -0.3], [0.85, -0.3], [1.0, 0.0]])
			_swing_crouch = _keys(t, [[0.0, 0.0], [0.2, 0.08], [0.8, 0.08], [1.0, 0.0]])
		_:
			# руками: наклониться, взять и потянуть на себя (инструмент в руке остаётся как был)
			arm_r.rotation.x = _keys(t, [[0.0, 0.0], [0.35, -1.15], [0.6, -0.55], [1.0, 0.0]])
			arm_l.rotation.x = _keys(t, [[0.0, 0.0], [0.38, -1.05], [0.62, -0.5], [1.0, 0.0]])
			arm_r.rotation.z = 0.12
			arm_l.rotation.z = -0.12
			_swing_lean = _keys(t, [[0.0, 0.0], [0.35, -0.4], [0.6, -0.12], [1.0, 0.0]])
			_swing_crouch = _keys(t, [[0.0, 0.0], [0.35, 0.1], [0.7, 0.0]])
	# свист замаха у рубящих инструментов — перед самым ударом
	if kind in ["stone_axe", "pickaxe", "iron_pickaxe", "ice_pick", "machete", "net", "fishing_rod"] and t > 0.34 and not _whoosh_done:
		_whoosh_done = true
		Audio.play("whoosh", -9.0, 0.12)
	if hand_tool and _hand_id != "":
		hand_tool.global_basis = model.global_basis.orthonormalized() * Basis.from_euler(Vector3(pitch, yaw, 0.0)) * Basis(Vector3.UP, spin)


## Как инструмент держат, когда его несут: рукоять вниз, головка вверх у плеча; лейку — за ручку, носиком вперёд.
static func _carry_pitch(id: String) -> float:
	return 0.0 if id == "watering_can" else CARRY_ANGLE


## Герой в море: ниже уровня воды, но над дном (не под землёй, не в бункере).
func in_water() -> bool:
	if global_position.y >= -0.6:
		return false
	var isl := get_tree().get_first_node_in_group("island")
	if isl == null:
		return false
	return isl.height_at(global_position.x, global_position.z) < global_position.y + 0.3


# ------------------------------------------------------------------ Лазание
func _find_climb() -> void:
	near_climb = null
	near_climb_down = false
	for c in get_tree().get_nodes_in_group("climb"):
		var b: Vector3 = c.world_bottom()
		var t: Vector3 = c.world_top()
		if Vector2(global_position.x - b.x, global_position.z - b.z).length() < 1.35 \
				and global_position.y > b.y - 0.7 and global_position.y < t.y - 0.8:
			near_climb = c
			return
	# у верха: там, где сходят с подъёма, можно и спуститься обратно (иначе с балкона за перилами не слезть)
	for c in get_tree().get_nodes_in_group("climb"):
		var t: Vector3 = c.world_top()
		var e: Vector3 = c.world_exit()
		if global_position.y < t.y - 1.4 or global_position.y > t.y + 0.8:
			continue
		if Vector2(global_position.x - e.x, global_position.z - e.z).length() < 0.8 \
				or Vector2(global_position.x - t.x, global_position.z - t.z).length() < 1.4:
			near_climb = c
			near_climb_down = true
			return


func _start_climb(c: Climbable) -> void:
	climbing = c
	hand_tool.visible = false   # руки заняты
	var b := c.world_bottom()
	var side := Vector3(global_position.x - b.x, 0, global_position.z - b.z)
	_climb_side = side.normalized() if side.length() > 0.05 else -Basis(Vector3.UP, model.rotation.y).z * -1.0
	velocity = Vector3.ZERO
	Audio.play("rustle", -4.0)


## Спуск сверху: повиснуть у верха подъёма с той стороны, где по нему лезут, и дальше — S вниз.
func _start_climb_down(c: Climbable) -> void:
	_start_climb(c)
	var b := c.world_bottom()
	var t := c.world_top()
	var side := Vector3.ZERO
	if c.ladder or c.ice or c.holds != "":
		side = Vector3(sin(c.ladder_yaw), 0, cos(c.ladder_yaw))   # стена и лестница смотрят туда, где висит лезущий
	else:
		var e := c.world_exit()
		side = Vector3(t.x - e.x, 0, t.z - e.z)   # лиана, скала: висим с дальней от схода стороны
	if side.length() > 0.05:
		_climb_side = side.normalized()
	global_position = Vector3(b.x, t.y - 1.2, b.z)
	model.rotation.y = atan2(_climb_side.x, _climb_side.z)


func _stop_climb(push := Vector3.ZERO) -> void:
	climbing = null
	hand_tool.visible = true
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
	# по лиане — вплотную, обхватив её; по стене и лестнице — чуть дальше
	var rope := not (climbing.ice or climbing.rock or climbing.ladder or climbing.holds != "")
	global_position = Vector3(b.x, 0, b.z) + _climb_side * (0.3 if rope else 0.45) + Vector3(0, y, 0)
	model.rotation.y = lerp_angle(model.rotation.y, atan2(_climb_side.x, _climb_side.z), 10.0 * delta)
	# поза лазания: руки над головой сходятся к лиане и перехватывают её по очереди,
	# ноги согнуты и по очереди упираются; корпус ровный, чуть покачивается в такт
	_climb_phase += delta * abs(up) * 7.0
	var sw := sin(_climb_phase)
	var inward := 0.26 if rope else 0.08
	arm_l.rotation = Vector3(-2.75 - sw * 0.45, 0.0, inward)
	arm_r.rotation = Vector3(-2.75 + sw * 0.45, 0.0, -inward)
	leg_l.rotation.x = -0.6 + sw * 0.35
	leg_r.rotation.x = -0.6 - sw * 0.35
	body_pivot.rotation = Vector3(0.0, 0.0, sw * 0.05)
	body_pivot.position.y = _body_y + absf(sw) * 0.03
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
	var grass := false
	var moving := Vector2(velocity.x, velocity.z).length() > 0.8
	for n in get_tree().get_nodes_in_group("interactable"):
		# быстрый отсев по расстоянию — объектов на острове больше тысячи
		if (n as Node3D).global_position.distance_squared_to(me) > 49.0:
			continue
		# стоим в густой траве? (она не мешает пройти, но замедляет)
		if n is ResourceNode and (n as ResourceNode).kind in ResourceNode.SOFT:
			var gp: Vector3 = (n as Node3D).global_position
			var gr: float = ResourceNode.KINDS[(n as ResourceNode).kind]["radius"] + 0.2
			if absf(gp.y - me.y) < 1.2 and Vector2(gp.x - me.x, gp.z - me.z).length_squared() < gr * gr:
				grass = true
				if moving:
					(n as ResourceNode).brush()
		# бабочек и светлячков без сачка не ловят — не делаем их целью
		if (n is Critters.Butterfly or n.is_in_group("firefly")) and not Game.has_tool("net"):
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
	in_grass = grass
	if best != target:
		target = best
		_update_tool()


# ------------------------------------------------------------------ Подсветка цели
const HIGHLIGHT := preload("res://shaders/highlight.gdshader")
static var _hl_mat: ShaderMaterial
var _hl_node: Node = null
var _hl_meshes: Array = []


## Предмет, с которым будет действие, светится по контуру (подсветку снимаем, когда цель сменилась).
func _update_highlight() -> void:
	var want: Node = target if target != null and is_instance_valid(target) and not build_aim else null
	if want != _hl_node:
		for m in _hl_meshes:
			if is_instance_valid(m) and (m as MeshInstance3D).material_overlay == _hl_mat:
				(m as MeshInstance3D).material_overlay = null
		_hl_meshes.clear()
		_hl_node = want
		if want:
			if _hl_mat == null:
				_hl_mat = ShaderMaterial.new()
				_hl_mat.shader = HIGHLIGHT
			for m in want.find_children("*", "MeshInstance3D", true, false):
				# только сам предмет: большие плоскости (вода у места рыбалки и т. п.) не подсвечиваем
				if (m as MeshInstance3D).get_aabb().size.length() < 14.0:
					_hl_meshes.append(m)
	# вспышка от удара (FX.flash) на время занимает тот же слот — потом возвращаем подсветку
	for m in _hl_meshes:
		if is_instance_valid(m) and (m as MeshInstance3D).material_overlay == null:
			(m as MeshInstance3D).material_overlay = _hl_mat


## Жест без цели: герой делает движение работы (полил из круга действий — взмах лейкой).
func gesture(kind := "hands") -> void:
	swing_kind = kind
	_whoosh_done = false
	_swing_t = SWING_TIME


func try_interact() -> void:
	if _swing_t > 0.0 or target == null:
		return
	# у грядки и загона дел несколько — открываем круг действий (если выбирать не из чего, действуем сразу)
	if target.has_method("wheel_request") and target.wheel_request(self):
		return
	# умный выбор: нужный инструмент есть в сумке — герой сам берёт его в руку (подсветка ячейки переходит).
	# Пальму не трогаем: с пустыми руками её трясут, с топором — рубят, это решает игрок.
	var need := ""
	if target.has_method("tool_hint"):
		need = target.tool_hint()
	if need in Game.HOLD_TOOLS and Game.has_tool(need) and not (target is ResourceNode and (target as ResourceNode).kind == "palm"):
		Game.hold(need)
	# чем работаем: нужным инструментом (он уже в руке), топором по пальме — если он в руке, иначе руками
	swing_kind = "hands"
	if need != "" and Game.held_tool() == need:
		swing_kind = need
	_whoosh_done = false
	_swing_t = SWING_TIME
	var t := target
	# эффект удара — в середине замаха
	get_tree().create_timer(SWING_TIME * 0.45).timeout.connect(func():
		if is_instance_valid(t) and t == target:
			t.interact(self))


## Подсказка про подъём рядом (лиана, стена, лестница) — её видно всегда, даже если рядом есть чем заняться.
func _climb_hint() -> String:
	if near_climb.locked_hint != "":
		return near_climb.locked_hint
	if near_climb_down:
		var what := "по лестнице" if near_climb.ladder else ("по ледяной стене" if near_climb.ice else ("по выступам" if near_climb.holds != "" or near_climb.rock else "по лиане"))
		var need := near_climb.ladder or Game.has_tool("climbing_gloves") and (not near_climb.ice or Game.has_tool("ice_pick"))
		return ("[Пробел]  Спуститься " + what) if need else ("Спуститься " + what + " (нужны перчатки лазальщика)")
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


func get_hint() -> String:
	if climbing:
		if climbing.wind and GreatLighthouse.gust > 0.5:
			return "Порыв ветра! Прижмись к стене — не лезь, пока не стихнет"
		if climbing.rest_step > 0.0:
			var rest := climbing.at_rest(global_position.y - climbing.world_bottom().y)
			return "W — вверх,  S — вниз,  Пробел — спрыгнуть" + (("   ·   %s: повиси, отдышись" % ("зарубка" if climbing.ice else "уступ")) if rest else ",  Q — поесть")
		return "W — вверх,  S — вниз,  Пробел — спрыгнуть" + ("" if climbing.ladder else ",  Q — поесть")
	# подъём рядом: подсказку про него показываем всегда — и отдельной строкой, если рядом есть ещё и дело
	var climb := _climb_hint() if near_climb else ""
	if target == null or not is_instance_valid(target):
		return climb
	var act := (target as ResourceNode).key_hint() if target is ResourceNode and (target as ResourceNode).key_hint() != "" else "[ЛКМ / E]  " + str(target.get_hint())
	return act if climb == "" else climb + "\n" + act
