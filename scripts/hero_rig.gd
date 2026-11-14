class_name HeroRig
extends RefCounted
## Скелет героя (кости — tools/blender/rig.py): позы считаются в пространстве модели и раскладываются по костям.
##
## Два режима:
##  - обычные движения (стоит, идёт, бьёт инструментом) ставит дерево анимаций (HeroAnim); здесь поверх него —
##    мелкие поправки от движения (read_pose → turn → apply) и плавные переходы (snapshot / fade);
##  - climb() — лазание: руки и ноги ставятся на опору обратной кинематикой (двухсуставный IK: плечо — локоть —
##    кисть, бедро — колено — стопа). Опора не скользит: пока рука держится, она стоит на месте, а тело идёт мимо;
##    потом рука отпускает и перехватывает выше (вниз — то же в обратную сторону).
##
## Оси модели: +Y вверх, герой смотрит в −Z, левая сторона — x < 0.

const ORDER := ["Hips", "Spine", "Chest", "Neck", "Skull",
	"ShoulderL", "UpperArmL", "ForearmL", "HandL", "ShoulderR", "UpperArmR", "ForearmR", "HandR", "ToolR",
	"ThighL", "ShinL", "FootL", "ThighR", "ShinR", "FootR"]
const PALM := 0.06          # от запястья до середины ладони
const ELBOW_BACK := Vector3(0, 0, 1)     # куда смотрит локоть в позе покоя (назад)
const KNEE_FWD := Vector3(0, 0, -1)      # куда смотрит колено в позе покоя (вперёд)

var skel: Skeleton3D
var id := {}             # имя кости → номер
var parent := {}         # имя кости → имя родителя ("" у корня)
var kids := {}           # имя кости → все потомки
var rest := {}           # поза покоя в пространстве модели
var rest_local := {}     # поза покоя относительно родителя
var _g := {}             # поза этого кадра в пространстве модели (что не задано — идёт за родителем)
var _from := {}          # снимок позы костей [место, поворот] — от него идёт плавный переход (snapshot)
var fade := 0.0          # 1 → 0: сколько ещё осталось от снимка (переход из лазания в обычные движения)


func setup(root: Node3D) -> bool:
	var found := root.find_children("*", "Skeleton3D", true, false)
	if found.is_empty():
		return false
	skel = found[0]
	for nm: String in ORDER:
		var i := skel.find_bone(nm)
		if i < 0:
			push_warning("HeroRig: в модели нет кости " + nm)
			return false
		id[nm] = i
		var p := skel.get_bone_parent(i)
		parent[nm] = skel.get_bone_name(p) if p >= 0 else ""
		rest[nm] = skel.get_bone_global_rest(i)
		rest_local[nm] = skel.get_bone_rest(i)
		kids[nm] = []
	for nm: String in ORDER:
		var p: String = parent[nm]
		while p != "":
			(kids[p] as Array).append(nm)
			p = parent[p]
	return true


## Узел-«сустав» на месте кости: он идёт за костью (joint_at) — на таких узлах висит инструмент за спиной,
## по ним автотест меряет, не входит ли инструмент в тело.
func joint(node_name: String, bone: String, under: Node3D) -> Node3D:
	var n := Node3D.new()
	n.name = node_name
	n.position = (rest[bone] as Transform3D).origin
	under.add_child(n)
	return n


## Где сейчас сустав, который в покое стоит в начале кости at_bone без поворота и жёстко держится за кость bone.
func joint_at(bone: String, at_bone: String) -> Transform3D:
	return g(bone) * (rest[bone] as Transform3D).affine_inverse() * Transform3D(Basis.IDENTITY, (rest[at_bone] as Transform3D).origin)


## Запомнить позу костей: от неё пойдёт плавный переход в новую (apply(w) или fade).
func snapshot() -> void:
	for nm: String in ORDER:
		var i: int = id[nm]
		_from[nm] = [skel.get_bone_pose_position(i), skel.get_bone_pose_rotation(i)]


## Взять позу, которую поставило дерево анимаций, — чтобы поправить её (turn, ik) и разложить обратно (apply).
func read_pose() -> void:
	_g.clear()
	for nm: String in ORDER:
		_g[nm] = skel.get_bone_global_pose(id[nm])


# ------------------------------------------------------------------ поза кадра
func begin() -> void:
	_g.clear()


## Поза кости в пространстве модели: заданная в этом кадре или та, что получается за родителем.
func g(bone: String) -> Transform3D:
	if _g.has(bone):
		return _g[bone]
	var p: String = parent[bone]
	var t: Transform3D = rest_local[bone] if p == "" else g(p) * (rest_local[bone] as Transform3D)
	_g[bone] = t
	return t


func put(bone: String, t: Transform3D) -> void:
	_g[bone] = t
	for k: String in kids[bone]:
		_g.erase(k)


## Повернуть кость вокруг её начала. Углы — в осях модели, но считаются от того, как уже повёрнут родитель
## (x > 0 — назад, x < 0 — вперёд; y > 0 — влево; z > 0 — правый бок вверх).
func turn(bone: String, euler: Vector3) -> void:
	var t := g(bone)
	var rb: Basis = (rest[bone] as Transform3D).basis
	var c := t.basis * rb.inverse()
	put(bone, Transform3D(c * Basis.from_euler(euler) * rb, t.origin))


## То же, что turn, но для позы, взятой у дерева анимаций (read_pose): всё, что растёт из кости, поворачивается
## вместе с ней и остаётся в своей позе (turn и put, наоборот, возвращают потомков в позу покоя).
func turn_all(bone: String, euler: Vector3) -> void:
	var old := g(bone)
	var rb: Basis = (rest[bone] as Transform3D).basis
	var c := old.basis * rb.inverse()
	var now := Transform3D(c * Basis.from_euler(euler) * rb, old.origin)
	var d := now * old.affine_inverse()
	for k: String in kids[bone]:
		_g[k] = d * g(k)
	_g[bone] = now


static func _frame(along: Vector3, hint: Vector3) -> Basis:
	var y := along.normalized()
	var x := hint - y * hint.dot(y)
	if x.length() < 1e-4:
		x = y.cross(Vector3.RIGHT) if absf(y.x) < 0.9 else y.cross(Vector3.UP)
	x = x.normalized()
	return Basis(x, y, x.cross(y))


## Направить кость из from в to; hint — в какую сторону смотрит сгиб (локоть, колено), hint_rest — куда он смотрел в покое.
func aim(bone: String, tip_rest: Vector3, from: Vector3, to: Vector3, hint: Vector3, hint_rest: Vector3) -> void:
	var r: Transform3D = rest[bone]
	var d := to - from
	if d.length() < 1e-5:
		d = tip_rest - r.origin
	put(bone, Transform3D(_frame(d, hint) * _frame(tip_rest - r.origin, hint_rest).inverse() * r.basis, from))


## Двухсуставный IK: конец цепочки (кисть, стопа) — в точку target, сгиб — в сторону pole.
## tip — насколько дальше начала последней кости лежит точка касания (середина ладони).
func ik(upper: String, lower: String, end: String, target: Vector3, pole: Vector3, hint_rest: Vector3, tip := 0.0) -> void:
	var a := g(upper).origin
	var ru: Vector3 = (rest[upper] as Transform3D).origin
	var rl: Vector3 = (rest[lower] as Transform3D).origin
	var re: Vector3 = (rest[end] as Transform3D).origin
	var l1 := ru.distance_to(rl)
	var l2 := rl.distance_to(re) + tip
	var d := target - a
	var dist := clampf(d.length(), absf(l1 - l2) + 0.01, l1 + l2 - 0.003)
	var dir := d.normalized() if d.length() > 1e-5 else Vector3.DOWN
	var ca := clampf((l1 * l1 + dist * dist - l2 * l2) / (2.0 * l1 * dist), -1.0, 1.0)
	var pp := pole - dir * pole.dot(dir)
	if pp.length() < 1e-4:
		pp = dir.cross(Vector3.RIGHT)
	pp = pp.normalized()
	var mid := a + dir * (l1 * ca) + pp * (l1 * sqrt(maxf(0.0, 1.0 - ca * ca)))
	aim(upper, rl, a, mid, pp, hint_rest)
	aim(lower, re, mid, a + dir * dist, pp, hint_rest)


## Разложить позу по костям. w < 1 — смешать со снимком прежней позы (snapshot): плавный переход.
func apply(w := 1.0) -> void:
	for nm: String in ORDER:
		var p: String = parent[nm]
		var loc: Transform3D = g(nm) if p == "" else g(p).affine_inverse() * g(nm)
		var q := loc.basis.orthonormalized().get_rotation_quaternion()
		var o := loc.origin
		if w < 1.0 and _from.has(nm):
			var was: Array = _from[nm]
			q = (was[1] as Quaternion).slerp(q, w)
			o = (was[0] as Vector3).lerp(o, w)
		var i: int = id[nm]
		skel.set_bone_pose_position(i, o)
		skel.set_bone_pose_rotation(i, q)


# ------------------------------------------------------------------ лазание
## Мерки лазания по виду опоры. Высоты — от ступней героя (начало модели), глубина — от оси опоры к герою.
##  body — на каком расстоянии от оси висит тело; stride — на сколько поднимается тело за один круг перехватов
##  (обе руки и обе ноги по разу); hand / foot: x — в сторону от оси, depth — глубина точки хвата, lo..hi —
##  от какой до какой высоты опора проходит мимо, пока её держат. Чтобы опора не скользила, доля круга, которую
##  рука держится, равна (hi − lo) / stride — она считается сама.
const CLIMB := {
	"rope": {"body": 0.34, "stride": 0.5, "lean": 0.12,
		"hand": {"x": 0.03, "depth": 0.05, "lo": 0.82, "hi": 1.14, "lift": 0.07},
		"foot": {"x": 0.085, "depth": 0.04, "lo": 0.23, "hi": 0.42, "lift": 0.06},
		"elbow": Vector3(0.7, -0.6, 0.35), "knee": Vector3(0.85, 0.25, -0.45), "toe_in": 0.55, "toe_down": 0.35},
	"wall": {"body": 0.38, "stride": 0.62, "lean": 0.04,
		"hand": {"x": 0.21, "depth": 0.12, "lo": 0.84, "hi": 1.24, "lift": 0.09},
		"foot": {"x": 0.15, "depth": 0.2, "lo": 0.14, "hi": 0.4, "lift": 0.08},
		"elbow": Vector3(0.75, -0.6, 0.25), "knee": Vector3(0.7, 0.3, -0.65), "toe_in": 0.0, "toe_down": 0.15},
	"ladder": {"body": 0.34, "stride": 0.667, "lean": 0.03,
		"hand": {"x": 0.24, "depth": 0.04, "lo": 0.86, "hi": 1.2, "lift": 0.06},
		"foot": {"x": 0.12, "depth": 0.09, "lo": 0.16, "hi": 0.42, "lift": 0.09},
		"elbow": Vector3(0.6, -0.75, 0.3), "knee": Vector3(0.55, 0.3, -0.75), "toe_in": 0.0, "toe_down": 0.0},
}

var climb_w := 0.0          # 0..1 — насколько поза лазания уже «вошла» (плавный переход из стойки)
var _act := 0.0             # 0..1 — лезет ли сейчас (пока стоит на месте — рука в воздухе берётся за опору)
var _look := Vector2.ZERO   # куда смотрит голова: x — вверх (+) или вниз (−), y — в сторону
var _press := 0.0           # прижался к стене (порыв ветра)
var beat := 0               # номер перехвата: меняется, когда очередная рука берётся за опору (звук)
var _breath := 0.0


func climb_start() -> void:
	snapshot()   # в позу лазания входим плавно — из той, в какой герой подошёл
	fade = 0.0
	climb_w = 0.0
	_act = 0.0
	_look = Vector2.ZERO
	_press = 0.0


## Где опора относительно тела в доле круга u (0..1): [высота, насколько рука оторвана от опоры 0..1].
static func _hold(u: float, d: float, lo: float, hi: float) -> Vector2:
	if u < d:
		return Vector2(hi - (hi - lo) * u / d, 0.0)
	var s := (u - d) / (1.0 - d)
	return Vector2(lerpf(lo, hi, s * s * (3.0 - 2.0 * s)), sin(PI * s))


## Поза лазания. y_rel — высота героя над низом опоры, up — куда лезет (−1..1), kind — "rope" / "wall" / "ladder",
## dist — на сколько герой отстоит от оси опоры, seg — высота одного куска модели опоры (у лестницы на нём три ступеньки),
## pressed — прижаться (порыв ветра).
func climb(delta: float, y_rel: float, up: float, kind: String, dist: float, seg := 1.0, pressed := false) -> void:
	var c: Dictionary = CLIMB[kind]
	var hand: Dictionary = c["hand"]
	var foot: Dictionary = c["foot"]
	var stride: float = c["stride"] * (seg if kind == "ladder" else 1.0)
	var moving := absf(up) > 0.1
	climb_w = minf(1.0, climb_w + delta / 0.2)
	_act = move_toward(_act, 1.0 if moving else 0.0, delta / 0.12)
	_press = move_toward(_press, 1.0 if pressed else 0.0, delta / 0.25)
	_breath += delta
	# куда смотрит: вверх — когда лезет вверх, вниз через плечо — когда спускается
	var want := Vector2(0.16, 0.0)
	if up > 0.1:
		want = Vector2(0.34, 0.0)
	elif up < -0.1:
		want = Vector2(-0.3, 0.55)
	if pressed:
		want = Vector2(-0.25, 0.3)
	_look = _look.lerp(want, 1.0 - exp(-7.0 * delta))

	var d_h := clampf((float(hand["hi"]) - float(hand["lo"])) / stride, 0.2, 0.8)
	var d_f := clampf((float(foot["hi"]) - float(foot["lo"])) / stride, 0.2, 0.8)
	var ph := y_rel / stride
	# руки — по очереди; ноги — крест-накрест с руками (правая нога шагает вместе с левой рукой)
	var o_hl := 0.0
	var o_hr := 0.5
	var o_fr := o_hl + (d_f - d_h) * 0.5
	if kind == "ladder":
		# ступни встают на ступеньки: ступенька — каждые seg / 3, первая на seg / 6 от низа; правая нога — на чётных
		o_fr = (float(foot["hi"]) - 0.09 - seg / 6.0) / stride
		o_hl = o_fr - (d_f - d_h) * 0.5
		o_hr = o_hl + 0.5
	var o_fl := o_fr + 0.5
	beat = int(floor((ph + o_hl) * 2.0))
	var hl := _hold(fposmod(ph + o_hl, 1.0), d_h, hand["lo"], hand["hi"])
	var hr := _hold(fposmod(ph + o_hr, 1.0), d_h, hand["lo"], hand["hi"])
	var fl := _hold(fposmod(ph + o_fl, 1.0), d_f, foot["lo"], foot["hi"])
	var fr := _hold(fposmod(ph + o_fr, 1.0), d_f, foot["lo"], foot["hi"])

	# тело: качается к руке, которая держит; плечо тянущейся руки идёт вверх и вперёд
	var wave := sin(TAU * (ph + o_hl)) * (0.35 + 0.65 * _act)     # > 0 — тянется правая рука
	var bob := cos(2.0 * TAU * (ph + o_hl)) * 0.02 * _act + sin(_breath * 2.1) * 0.004
	var za := -dist                                       # ось опоры
	var zb := za + float(c["body"]) - 0.05 * _press       # тело
	var lean: float = float(c["lean"]) - 0.06 * _press
	begin()
	var hips: Transform3D = rest["Hips"]
	put("Hips", Transform3D(Basis.from_euler(Vector3(lean * 0.4, -wave * 0.1, -wave * 0.08)) * hips.basis,
		hips.origin + Vector3(-wave * 0.035, bob, zb)))
	turn("Spine", Vector3(lean * 0.3, wave * 0.08, wave * 0.07))
	turn("Chest", Vector3(lean * 0.3, wave * 0.16, wave * 0.12))
	turn("Neck", Vector3(_look.x * 0.35, _look.y * 0.4, 0.0))
	turn("Skull", Vector3(_look.x * 0.65 + sin(_breath * 1.3) * 0.015, _look.y * 0.6, -wave * 0.05))
	# плечи поданы вперёд, к опоре; плечо тянущейся руки приподнято
	turn("ShoulderL", Vector3(0.0, -0.5, -0.12 - maxf(0.0, -wave) * 0.22 - hl.y * 0.1))
	turn("ShoulderR", Vector3(0.0, 0.5, 0.12 + maxf(0.0, wave) * 0.22 + hr.y * 0.1))

	var el: Vector3 = c["elbow"]
	var kn: Vector3 = c["knee"]
	for side in [-1.0, 1.0]:
		var s := "L" if side < 0.0 else "R"
		# рука
		var h: Vector2 = hl if side < 0.0 else hr
		var lift := h.y * _act * float(hand["lift"])
		var hx: float = hand["x"]
		var tgt := Vector3(side * (hx + lift * 0.9), h.x, za + float(hand["depth"]) + lift)
		ik("UpperArm" + s, "Forearm" + s, "Hand" + s, tgt, Vector3(el.x * side, el.y, el.z), ELBOW_BACK, PALM)
		# нога: пока ищет опору — колено выше и в сторону
		var f: Vector2 = fl if side < 0.0 else fr
		var fl_ := f.y * _act * float(foot["lift"])
		var fx: float = foot["x"]
		var ft := Vector3(side * (fx + fl_ * 0.8), f.x + fl_ * 0.25, za + float(foot["depth"]) + fl_)
		ik("Thigh" + s, "Shin" + s, "Foot" + s, ft, Vector3(kn.x * side, kn.y, kn.z), KNEE_FWD)
		# стопа: носком к опоре (на лиане — носки внутрь, обхватывая её)
		var fb: Basis = (rest["Foot" + s] as Transform3D).basis
		var foot_rot := Basis.from_euler(Vector3(-float(c["toe_down"]) - f.y * _act * 0.3, side * float(c["toe_in"]), 0.0))
		put("Foot" + s, Transform3D(foot_rot * fb, g("Foot" + s).origin))
	apply(climb_w * climb_w * (3.0 - 2.0 * climb_w))
