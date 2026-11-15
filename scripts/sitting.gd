class_name Sitting
extends Node
## Герой сидит на скамейке, в кресле-качалке или на табурете и смотрит на пейзаж.
## Сел (E у скамейки) — герой опускается на сиденье, колени согнуты, руки на коленях; камера становится ниже и ближе
## и смотрит туда же, куда он. Мышью можно оглядеться, колёсиком — приблизить. Встать — WASD, Пробел или E.
## Пока сидишь, силы возвращаются, как на земле. Ничего не тратится и ничто не торопит.
##
## player.gd не меняется: пока герой сидит, его обычная обработка движения выключена (set_physics_process(false)),
## а позу, камеру и место ставит этот узел. Поза — поверх клипа «стоит» через HeroRig (read_pose → ik → apply).

## Где сиденье у постройки (в её осях): высота, сдвиг вперёд (+Z — куда смотрит сидящий), шаг в сторону для второго места.
const SEATS := {
	"bench": {"h": 0.49, "z": 0.02, "say": "Ты присел на скамейку. Шумит прибой, кричат чайки..."},
	"rocking_chair": {"h": 0.48, "z": 0.03, "rock": true, "say": "Ты качаешься в кресле. Скрип-скрип. Море шумит в такт."},
	"camp_stool": {"h": 0.5, "z": 0.0, "say": "Ты присел на табурет. Ноги гудят — значит, день был не зря."},
}
const VIEW_PITCH := -0.16      # камера почти на уровне глаз: видно горизонт
const VIEW_DIST := 4.6
const STAND_KEYS := ["move_forward", "move_back", "move_left", "move_right", "jump", "interact"]

static var current: Sitting = null

var player: Player
var seat: Node3D
var cfg: Dictionary
var _t := 0.0
var _in := 0.0                # 0 → 1: садится
var _was := {}                # камера до того, как сел
var _from := Vector3.ZERO     # где стоял
var _from_yaw := 0.0
var _grace := 0.35            # сразу после «сесть» клавиша E ещё нажата — не вставать


static func can_sit(id: String) -> bool:
	return SEATS.has(id)


static func on(node: Node) -> bool:
	return current != null and is_instance_valid(current) and current.seat == node


static func sitting_now() -> bool:
	return current != null and is_instance_valid(current)


## Посадить героя. Возвращает true, если сел (запасная модель без скелета не садится — тогда просто текст).
static func sit(who: Node, on_seat: Node3D, id: String) -> bool:
	var p := who as Player
	if p == null or not SEATS.has(id) or sitting_now() or p.climbing != null:
		return false
	if p.rig == null or p.anim == null:
		return false
	var s := Sitting.new()
	s.player = p
	s.seat = on_seat
	s.cfg = SEATS[id]
	current = s
	p.get_parent().add_child(s)
	return true


func seat_point() -> Vector3:
	return seat.global_transform * Vector3(0, 0, float(cfg["z"]))


func face_yaw() -> float:
	return seat.global_rotation.y + PI      # модель героя смотрит в −Z, сиденье — в +Z


func _ready() -> void:
	process_physics_priority = 10
	_was = {"yaw": player.camera_yaw, "pitch": player.camera_pitch, "dist": player.camera_distance}
	_from = player.global_position
	_from_yaw = player.model.rotation.y
	player.set_physics_process(false)
	player.velocity = Vector3.ZERO
	player.rig.snapshot()
	# камера — за спиной сидящего, смотрит туда же, куда он
	player.camera_yaw = face_yaw()
	player.camera_pitch = VIEW_PITCH
	player.camera_distance = VIEW_DIST
	Audio.play("click", -8.0, 0.05)
	Game.notified.emit(str(cfg["say"]), Color("ffe08a"))
	Game.notified.emit("Мышь — оглядеться. Встать — WASD или Пробел", Color("e8dcc0"))


func _physics_process(delta: float) -> void:
	if not is_instance_valid(seat) or seat.is_queued_for_deletion() or not is_instance_valid(player):
		stand()
		return
	_t += delta
	_in = minf(1.0, _in + delta / 0.45)
	_grace = maxf(0.0, _grace - delta)
	var k := smoothstep(0.0, 1.0, _in)
	# место и поворот: плавно с того места, где стоял, на сиденье
	var sp := seat_point()
	player.global_position = _from.lerp(sp, k)
	player.model.rotation.y = lerp_angle(_from_yaw, face_yaw(), k)
	player.velocity = Vector3.ZERO
	player.stamina = minf(Player.STAMINA_MAX, player.stamina + 30.0 * delta * Game.hunger_regen())
	_pose(k)
	if has_meta("side"):      # для снимков: вид со стороны, чтобы было видно, как герой сидит
		player.camera_yaw = face_yaw() + 2.3
		player.camera_pitch = -0.3
		player.camera_distance = 5.0
	player._update_camera(delta)
	if _grace <= 0.0 and player.controls_enabled:
		for a in STAND_KEYS:
			if Input.is_action_just_pressed(a):
				stand()
				return


## Поза сидя поверх клипа «стоит»: таз на сиденье, колени согнуты, ступни впереди, руки на коленях.
func _pose(k: float) -> void:
	var rig: HeroRig = player.rig
	player.anim.pose({"idle": fposmod(_t / 4.0, 1.0), "walk": 0.0, "run": 0.0, "float": 0.0, "swim": 0.0, "air": 0.5, "land": 1.0,
			"carry": 0.0, "work_low": 0.0, "work_up": 0.0, "sleep": 0.0},
		{"walk": 0.0, "run": 0.0, "swimmove": 0.0, "water": 0.0, "air": 0.0, "land": 0.0, "carry": 0.0, "work_low": 0.0, "work_up": 0.0, "sleep": 0.0})
	rig.read_pose()
	var hips_rest: Vector3 = (rig.rest["Hips"] as Transform3D).origin
	var h: float = float(cfg["h"])
	var rock := sin(_t * 1.6) * 0.06 if cfg.get("rock", false) else 0.0
	# таз — на сиденье (чуть выше доски), всё тело идёт за ним
	var drop := Vector3(0, (h + 0.07) - hips_rest.y, 0.06) * k
	for nm: String in HeroRig.ORDER:
		var t: Transform3D = rig.g(nm)
		t.origin += drop
		rig._g[nm] = t
	rig.turn_all("Spine", Vector3((0.1 + rock) * k, 0, 0))      # чуть откинулся на спинку
	rig.turn_all("Skull", Vector3(-0.06 * k + sin(_t * 0.5) * 0.03, sin(_t * 0.23) * 0.12 * k, 0))   # смотрит вдаль, иногда оглядывается
	for side in ["L", "R"]:
		var sx := -1.0 if side == "L" else 1.0
		var thigh: Vector3 = rig.g("Thigh" + side).origin
		var th_rest: Vector3 = (rig.rest["Thigh" + side] as Transform3D).origin
		var sh_rest: Vector3 = (rig.rest["Shin" + side] as Transform3D).origin
		var ft_rest: Vector3 = (rig.rest["Foot" + side] as Transform3D).origin
		var l1 := th_rest.distance_to(sh_rest)
		var l2 := sh_rest.distance_to(ft_rest)
		# колено — вперёд от бедра, голень — вниз (ноги короче сиденья — ступни висят, как у ребёнка на лавке)
		var knee := thigh + Vector3(sx * 0.03, -0.02, -l1 * 0.97)
		var foot := knee + Vector3(0, -l2 * 0.96, -l2 * 0.2 + sin(_t * 1.3 + sx) * 0.03)
		foot.y = maxf(foot.y, ft_rest.y)
		var stand_foot: Vector3 = rig.g("Foot" + side).origin
		rig.ik("Thigh" + side, "Shin" + side, "Foot" + side, stand_foot.lerp(foot, k), Vector3(0, 0.35, -1.0), HeroRig.KNEE_FWD)
		# рука на колене
		var hand_now: Vector3 = rig.g("Hand" + side).origin
		var hand := knee + Vector3(sx * 0.02, 0.07, 0.05)
		rig.ik("UpperArm" + side, "Forearm" + side, "Hand" + side, hand_now.lerp(hand, k), Vector3(sx * 0.5, -0.2, 1.0), HeroRig.ELBOW_BACK, HeroRig.PALM)
	rig.apply(k)
	player._sync_joints()
	if cfg.get("rock", false) and seat.get("visual") != null:
		(seat.get("visual") as Node3D).rotation.x = rock * k


## Встать: герой делает шаг вперёд от сиденья, камера возвращается.
func stand() -> void:
	if current == self:
		current = null
	if is_instance_valid(player):
		if is_instance_valid(seat):
			var fwd := seat.global_transform.basis.z
			fwd.y = 0.0
			var p := seat_point() + fwd.normalized() * 0.75
			var isl := get_tree().get_first_node_in_group("island") as Island
			if isl:
				p.y = maxf(isl.height_at(p.x, p.z), seat.global_position.y) + 0.05
			player.global_position = p
			if cfg.get("rock", false) and seat.get("visual") != null:
				(seat.get("visual") as Node3D).rotation.x = 0.0
		player.rig.snapshot()
		player.rig.fade = 1.0        # поза плавно переходит в «стоит»
		player.camera_pitch = float(_was["pitch"])
		player.camera_distance = float(_was["dist"])
		player.velocity = Vector3.ZERO
		player.set_physics_process(true)
	queue_free()
