class_name IceGlacier
extends Node3D
## Ледник Ледяного острова: столовая гора, обведённая отвесным ледяным обрывом (~7 м).
##
## Наверху: купол обсерватории, телескоп со звёздным кругом (головоломка «stars»), стол с секстантом
## и штурман Ингрид. Подняться можно в одном месте — по ледяной стене напротив лагеря (нужны ледоруб и перчатки).
## Внизу у этой стены, поперёк тропы, спит морж: пока его не накормить, к стене не подойти.
## Сзади, с северной стороны, — замёрзший водопад и ледяной ларец под ним.
## Узел стоит в точке (x, 0, z) центра ледника, так что локальная высота = мировая.

const WALL_R := 8.6        # радиус ледяного обрыва (середина стенки)
const SEGS := 16           # кусков обрыва по кругу
const PARAPET := 1.1       # снежный бортик наверху: с ледника не свалиться
const STARS_TARGET := [0, 2, 5]   # Парус — на 1-е деление, Рыба — на 3-е, Глаз — напротив Рыбы (6-е)
const STARS_START := [3, 5, 1]

var island: Island
var site := Vector3.ZERO    # мировая точка центра ледника (y — высота вершины)
var foot := Vector3.ZERO    # подножие стены, по которой лезут
var top := 12.0
var fwd := Vector3.FORWARD  # от центра к подножию (к лагерю)
var right := Vector3.RIGHT
var walrus: NPCPerson
var climb: Climbable
var dial: StarDial
var _body: StaticBody3D
var _reached := false
var _walrus_moved := false
var _snore_t := 3.0


func _ready() -> void:
	add_to_group("obstacle")
	add_to_group("glacier")
	top = site.y
	fwd = Vector3(foot.x - site.x, 0, foot.z - site.z).normalized()
	right = Vector3(-fwd.z, 0, fwd.x)
	_body = StaticBody3D.new()
	_body.collision_layer = 1
	add_child(_body)
	_build_wall()
	_build_top()
	_build_foot()
	_build_waterfall()
	if island:
		island.poi_extra["glacier_top"] = top_point()
		island.poi_extra["ingrid"] = to_global(_on_top(1.6, -2.2))
		island.poi_extra["walrus"] = to_global(fwd * (WALL_R + 4.0) + Vector3(0, _ground(fwd * (WALL_R + 4.0)), 0))


func block_radius() -> float:
	return WALL_R + 1.0


## Точка на леднике: f — вперёд (к лагерю), r — вправо, в метрах от центра.
func _on_top(f: float, r: float) -> Vector3:
	return fwd * f + right * r + Vector3(0, top, 0)


func _ground(p: Vector3) -> float:
	var w := to_global(Vector3(p.x, 0, p.z))
	return island.height_at(w.x, w.z) if island else 0.0


func _model(name_: String, pos: Vector3, yaw := 0.0, scale_ := Vector3.ONE) -> Node3D:
	var m := Models.glb(name_)
	if m == null:
		return null
	m.position = pos
	m.rotation.y = yaw
	m.scale = scale_
	add_child(m)
	return m


func _box(size: Vector3, center: Vector3, yaw := 0.0) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	cs.shape = b
	cs.position = center
	cs.rotation.y = yaw
	_body.add_child(cs)
	return cs


# ------------------------------------------------------------------ обрыв
func _build_wall() -> void:
	var a_climb := atan2(fwd.z, fwd.x)
	var chord := TAU * WALL_R / SEGS
	for i in SEGS:
		var a := a_climb + TAU * i / SEGS
		var out := Vector3(cos(a), 0, sin(a))
		var p := out * WALL_R
		# низ стенки — чуть ниже земли снаружи, верх — бортик над ледником (у места подъёма — вровень)
		var low := minf(_ground(out * (WALL_R + 1.2)), _ground(out * (WALL_R + 0.6))) - 1.0
		var hi := top + (0.0 if i == 0 else PARAPET)
		_box(Vector3(chord * 1.12, hi - low, 0.9), p + Vector3(0, (hi + low) * 0.5, 0), -a - PI / 2)
		# модель обрыва: 8 м в высоту от низа; растягиваем до вершины (+ снежный бортик)
		_model("glacier_wall", Vector3(p.x, low, p.z), PI / 2 - a, Vector3(1.0, (top + 0.9 - low) / 8.0, 1.0))


# ------------------------------------------------------------------ наверху
func _build_top() -> void:
	Models.add_trimesh(_body, _model("observatory", _on_top(-3.2, 0.0), atan2(fwd.x, fwd.z)))
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 2.9
	cyl.height = 5.0
	cs.shape = cyl
	cs.position = _on_top(-3.2, 0.0) + Vector3(0, 2.5, 0)
	_body.add_child(cs)
	# тёплый угол у двери купола: Ингрид топит печь
	var warm := WarmSpot.new()
	warm.warm_radius = 3.6
	warm.position = _on_top(-0.4, 0.0)
	add_child(warm)
	# фонарь над дверью: тёплый свет на снегу
	var lamp := OmniLight3D.new()
	lamp.light_color = Color("ffc070")
	lamp.light_energy = 1.4
	lamp.omni_range = 6.0
	lamp.position = _on_top(-0.5, 0.6) + Vector3(0, 1.7, 0)
	add_child(lamp)
	# Ингрид у двери
	var ing := NPCPerson.new()
	ing.npc_id = "ingrid"
	ing.position = _on_top(0.4, -2.2)
	ing.rotation.y = atan2(fwd.x, fwd.z)
	add_child(ing)
	# телескоп и звёздный круг
	_model("telescope", _on_top(-0.6, 3.6), atan2(-right.x, -right.z) + 0.6)
	_box(Vector3(1.2, 2.4, 1.2), _on_top(-0.6, 3.6) + Vector3(0, 1.2, 0))
	dial = StarDial.new()
	dial.glacier = self
	dial.position = _on_top(1.8, 2.8)
	dial.rotation.y = atan2(fwd.x, fwd.z)
	add_child(dial)
	# стол с секстантом
	var sx := StoryPlace.new()
	sx.id = "sextant"
	sx.position = _on_top(0.6, -4.4)
	sx.rotation.y = atan2(fwd.x, fwd.z)
	add_child(sx)
	# поленница и сани — для уюта
	Models.add_trimesh(_body, _model("woodpile", _on_top(-1.2, -3.6), atan2(right.x, right.z)))


# ------------------------------------------------------------------ подножие: подъём и морж
func _build_foot() -> void:
	var yaw_out := atan2(fwd.x, fwd.z)
	var foot_y := _ground(fwd * (WALL_R + 1.4))
	climb = Climbable.new()
	climb.ice = true
	climb.ladder_yaw = yaw_out
	climb.bottom = fwd * (WALL_R + 0.62) + Vector3(0, foot_y, 0)
	climb.top = Vector3(climb.bottom.x, top + 1.1, climb.bottom.z)
	climb.exit = _on_top(WALL_R - 1.7, 0.0) + Vector3(0, 0.2, 0)
	climb.rest_step = 2.0
	add_child(climb)
	walrus = NPCPerson.new()
	walrus.npc_id = "walrus"
	add_child(walrus)
	_walrus_moved = Game.flags.get("walrus_moved", false)
	_place_walrus(false)


## Где лежит морж: поперёк тропы у стены — или, сытый, на солнышке в тундре, за ледяным полукольцом
## (там он никому не мешает: не перегородит пробитый проход).
func _walrus_spot(moved: bool) -> Vector3:
	var p := fwd * (WALL_R + 1.55) if not moved else fwd * (WALL_R + 2.0 + 7.5) + right * 2.5
	p.y = _ground(p)
	return p


func _place_walrus(animate: bool) -> void:
	var to := _walrus_spot(_walrus_moved)
	var yaw := atan2(right.x, right.z) if not _walrus_moved else atan2(fwd.x, fwd.z) + 0.6
	climb.locked_hint = "" if _walrus_moved else "Поперёк тропы спит морж. Мимо него не пролезть"
	if not animate:
		walrus.position = to
		walrus.rotation.y = yaw
		return
	var tw := create_tween()
	tw.tween_property(walrus, "position", to, 2.6).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(walrus, "rotation:y", yaw, 1.2)


# ------------------------------------------------------------------ замёрзший водопад и ларец
func _build_waterfall() -> void:
	var back := -fwd
	var yaw := atan2(back.x, back.z)
	var base := back * (WALL_R + 0.55)
	base.y = _ground(back * (WALL_R + 1.4)) - 0.4
	_model("frozen_waterfall", base, yaw, Vector3(1.0, (top + 0.4 - base.y) / 8.0, 1.0))
	var chest := StoryPlace.new()
	chest.id = "ice_chest_2"
	var cp := back * (WALL_R + 2.3)
	cp.y = _ground(cp)
	chest.position = cp
	chest.rotation.y = yaw
	add_child(chest)
	if island:
		island.poi_extra["ice_chest_2"] = to_global(cp)


## Для автотеста и dev_tools: мировая точка на вершине ледника.
func top_point() -> Vector3:
	return to_global(_on_top(2.0, 0.0) + Vector3(0, 0.4, 0))


## Для автотеста: точка у подножия, рядом со стеной.
func foot_point() -> Vector3:
	return to_global(climb.bottom + fwd * 0.6 + Vector3(0, 0.3, 0))


func _process(delta: float) -> void:
	_snore_t -= delta
	if _snore_t <= 0.0:
		_snore_t = randf_range(5.0, 8.0)
		Audio.play("snore", -6.0 if not _walrus_moved else -10.0, 0.05, walrus.global_position)
	if not _walrus_moved and Game.flags.get("walrus_moved", false):
		_walrus_moved = true
		_place_walrus(true)
		Audio.play("snore", -2.0, 0.05, walrus.global_position)
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if p == null or _reached:
		return
	var lp := to_local(p.global_position)
	if Vector2(lp.x, lp.z).length() < WALL_R - 0.3 and lp.y > top - 1.0:
		_reached = true
		Game.bump("reached", "glacier_top")
		Game.notified.emit("Вершина ледника", Color("bfe3ff"))


# ------------------------------------------------------------------ звёздный круг
## Три кольца на каменной тумбе у телескопа. Ночью их поворачивают так, чтобы созвездия совпали
## с расчётами Лёвы: Парус — на 1-е деление, Рыба — на 3-е, Глаз — напротив Рыбы (6-е).
class StarDial extends StaticBody3D:
	const NAMES := ["Парус", "Рыба", "Глаз"]
	var glacier: IceGlacier
	var rings: Array[Node3D] = []
	var pos: Array = []

	func _ready() -> void:
		add_to_group("interactable")
		collision_layer = 4
		var base := Models.glb("star_dial")
		if base:
			add_child(base)
		var cs := CollisionShape3D.new()
		var c := CylinderShape3D.new()
		c.radius = 0.6
		c.height = 1.1
		cs.shape = c
		cs.position.y = 0.55
		add_child(cs)
		var saved: Variant = Game.flags.get("stars_rings", STARS_START)
		pos = (saved as Array).duplicate() if saved is Array and (saved as Array).size() == 3 else STARS_START.duplicate()
		if Game.flags.get("stars_solved", false):
			pos = STARS_TARGET.duplicate()
		for i in 3:
			var r := Models.glb("star_ring_%d" % (i + 1))
			if r == null:
				r = Node3D.new()
			r.position = Vector3(0, 1.02 + i * 0.012, 0)
			r.rotation.y = -int(pos[i]) * TAU / 6.0
			add_child(r)
			rings.append(r)

	func interact_point() -> Vector3:
		return global_position + Vector3(0, 0.9, 0)

	func tool_hint() -> String:
		return ""

	func solved() -> bool:
		return Game.flags.get("stars_solved", false)

	func get_hint() -> String:
		if solved():
			return "Звёздный круг — созвездия сведены"
		if Game.is_day():
			return "Звёздный круг — звёзд не видно, приходи ночью"
		return "Звёздный круг — повернуть кольца"

	func interact(_player: Node) -> void:
		if solved():
			Game.notified.emit("Три созвездия сходятся в одной точке — за Тихой водой", Color("bfe3ff"))
			return
		if Game.is_day():
			Game.choice_requested.emit("Звёздный круг", [
				{"text": "Подождать до темноты", "icon": "sym_moon", "callback": _wait_night},
				{"text": "Отойти", "icon": "sym_star", "callback": func(): pass}])
			return
		_menu()

	func _wait_night() -> void:
		var main := get_tree().current_scene
		if main and main.get("hud"):
			main.hud.fade_through(func():
				Game.wait_until_night()
				Game.notified.emit("Стемнело. Над ледником высыпали звёзды", Color("bfe3ff")))
		else:
			Game.wait_until_night()

	func _menu() -> void:
		var opts := []
		for i in 3:
			opts.append({"text": "Повернуть «%s»  (сейчас деление %d из 6)" % [NAMES[i], int(pos[i]) + 1],
				"icon": ["sym_star", "sym_moon", "sym_sun"][i], "callback": _turn.bind(i)})
		opts.append({"text": "Отойти", "icon": "sym_star", "callback": func(): pass})
		Game.choice_requested.emit("Звёздный круг: Парус, Рыба, Глаз", opts)

	func _turn(i: int) -> void:
		pos[i] = (int(pos[i]) + 1) % 6
		Game.flags["stars_rings"] = pos.duplicate()
		Audio.play("click", -2.0, 0.1)
		create_tween().tween_property(rings[i], "rotation:y", -int(pos[i]) * TAU / 6.0, 0.35).set_trans(Tween.TRANS_BACK)
		if check():
			return
		_menu.call_deferred()

	## Проверить кольца; если совпали — головоломка решена.
	func check() -> bool:
		for i in 3:
			if int(pos[i]) != int(STARS_TARGET[i]):
				return false
		Game.flags["stars_solved"] = true
		Audio.play("rare", 0.0, 0.0)
		FX.burst(self, Vector3(0, 1.2, 0), Color("cfe4ff"), 24)
		var l := OmniLight3D.new()
		l.light_color = Color("cfe4ff")
		l.light_energy = 2.0
		l.omni_range = 5.0
		l.position = Vector3(0, 1.6, 0)
		add_child(l)
		Game.bump("solved", "stars")
		return true


# ------------------------------------------------------------------ тёплое место
## Невидимая точка, у которой тепло (дверь обсерватории, жаровня у ларца, зажжённый маяк).
class WarmSpot extends Node3D:
	var warm_radius := 3.0

	func _ready() -> void:
		add_to_group("warm_spot")
