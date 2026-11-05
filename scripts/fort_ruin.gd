class_name FortRuin
extends Node3D
## Старый форт на плато: кольцо стен (16 секций) с воротами в сторону берега, внутри —
## погасшая башня-маяк, разрушенная караулка и затопленный подвал с тремя рычагами и древними рисунками.
## Ворота закрыты, пока не открыть их ключом боцмана. Вход в подвал завален камнями (кирка).
## Рычаги нужно тянуть в порядке Луна → Звезда → Солнце, иначе вода вернётся.

const R := 11.0           # радиус стен
const SEGMENTS := 16
const ORDER := ["moon", "star", "sun"]

var island: Island
var gate_dir := Vector3.FORWARD
var side_dir := Vector3.RIGHT
var _body: StaticBody3D
var _gate_blocker: CollisionShape3D
var _doors: Array[Node3D] = []
var _pool: MeshInstance3D
var _pool_shape: CollisionShape3D
var _pulled: Array[String] = []
var levers: Array = []
var _gate_open := false


func _ready() -> void:
	add_to_group("obstacle")
	var to_camp := island.camp_center - global_position
	to_camp.y = 0
	gate_dir = to_camp.normalized()
	side_dir = Vector3(-gate_dir.z, 0, gate_dir.x)
	_body = StaticBody3D.new()
	_body.collision_layer = 4
	add_child(_body)
	_build_walls()
	_build_inside()
	_build_cellar()
	if Game.flags.get("poi_fort_gate", false):
		open_gate(false)
	if Game.flags.get("cellar_drained", false):
		_drain(false)


func block_radius() -> float:
	return R + 1.5


func _ground(local: Vector3) -> Vector3:
	var w := global_position + local
	return Vector3(local.x, island.height_at(w.x, w.z) - global_position.y, local.z)


func _add_box(size: Vector3, local: Vector3, yaw: float) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	cs.shape = b
	cs.position = local + Vector3(0, size.y * 0.5, 0)
	cs.rotation.y = yaw
	_body.add_child(cs)
	return cs


# ------------------------------------------------------------------ стены и ворота
func _build_walls() -> void:
	var ga := atan2(gate_dir.z, gate_dir.x)
	for i in SEGMENTS:
		var a := ga + TAU * i / SEGMENTS
		var pos := _ground(Vector3(cos(a), 0, sin(a)) * R)
		var yaw := -a - PI / 2
		var m := Models.glb("fort_gate" if i == 0 else "fort_wall")
		if m:
			m.position = pos
			m.rotation.y = yaw
			add_child(m)
		if i == 0:
			for nm in ["DoorL", "DoorR"]:
				var d := m.find_child(nm, true, false) as Node3D if m else null
				if d:
					_doors.append(d)
			# столбы ворот
			for sx in [-1, 1]:
				var t: Vector3 = Vector3(cos(a + PI / 2), 0, sin(a + PI / 2)) * 1.95 * sx
				_add_box(Vector3(0.6, 3.5, 1.2), pos + t, yaw)
			_gate_blocker = _add_box(Vector3(3.4, 3.2, 0.6), pos, yaw)
			# место, где применяется ключ, — снаружи у ворот
			var sp := StoryPlace.new()
			sp.id = "fort_gate"
			sp.position = pos + gate_dir * 1.6
			add_child(sp)
		else:
			_add_box(Vector3(4.4, 3.0, 0.9), pos, yaw)


func open_gate(animate: bool) -> void:
	if _gate_open:
		return
	_gate_open = true
	if _gate_blocker:
		_gate_blocker.disabled = true
	for i in _doors.size():
		var d := _doors[i]
		var target := (1.6 if i == 0 else -1.6)
		if animate:
			create_tween().tween_property(d, "rotation:y", target, 1.2).set_trans(Tween.TRANS_QUAD)
			Audio.play("build", 0.0, 0.0)
		else:
			d.rotation.y = target


# ------------------------------------------------------------------ двор: башня и караулка
func _build_inside() -> void:
	var tower := StoryPlace.new()
	tower.id = "fort_tower"
	tower.position = _ground(-gate_dir * 6.0)
	add_child(tower)
	var gh := StoryPlace.new()
	gh.id = "gatehouse"
	gh.position = _ground(gate_dir * 6.5 + side_dir * 4.5)
	gh.rotation.y = atan2(gate_dir.x, gate_dir.z)
	add_child(gh)
	# немного зарослей во дворе — форт заброшен
	var g := RandomNumberGenerator.new()
	g.seed = 77
	for k in 10:
		var a := g.randf() * TAU
		var r := g.randf_range(3.0, 8.5)
		var p := Vector3(cos(a), 0, sin(a)) * r
		if p.distance_to(-gate_dir * 6.0) < 3.2 or p.distance_to(-side_dir * 6.0) < 4.6 \
				or p.distance_to(gate_dir * 6.5 + side_dir * 4.5) < 2.8 or p.distance_to(gate_dir * 9.0) < 2.5:
			continue
		var uid := "fort:yard_%d" % k
		if Game.cleared.has(uid):
			continue
		var n := ResourceNode.new()
		n.kind = ["tall_grass", "fern", "thicket"][k % 3]
		n.rng_seed = 900 + k
		n.uid = uid
		n.position = _ground(p)
		add_child(n)


# ------------------------------------------------------------------ подвал
func _build_cellar() -> void:
	var c := -side_dir * 6.0          # центр подвала; вход смотрит во двор (+side_dir)
	var cy := atan2(side_dir.x, side_dir.z)
	# стены: задняя и две боковые (низкие)
	for spec in [[c - side_dir * 3.0, 0.0], [c + gate_dir * 3.0, PI / 2], [c - gate_dir * 3.0, PI / 2]]:
		var pos: Vector3 = _ground(spec[0])
		var yaw: float = cy + spec[1] + PI / 2
		var m := Models.glb("fort_wall")
		if m:
			m.position = pos
			m.rotation.y = yaw
			m.scale = Vector3(1.4, 0.5, 0.7)
			add_child(m)
		_add_box(Vector3(6.2, 1.5, 0.6), pos, yaw)
	# завал на входе — две каменные гряды (кирка)
	for sx in [-1, 1]:
		var uid := "fort:rubble_%d" % (sx + 1)
		if Game.cleared.has(uid):
			continue
		var n := ResourceNode.new()
		n.kind = "cliff"
		n.rng_seed = 500 + sx
		n.uid = uid
		n.yaw = cy + PI / 2
		n.position = _ground(c + side_dir * 3.0 + gate_dir * 1.0 * sx)
		add_child(n)
	# вода у дальней стены
	_pool = MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(5.4, 0.5, 2.2)
	_pool.mesh = pm
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.25, 0.6, 0.75, 0.85)
	wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_pool.material_override = wm
	_pool.position = _ground(c - side_dir * 1.6) + Vector3(0, 0.2, 0)
	_pool.rotation.y = cy + PI / 2
	add_child(_pool)
	_pool_shape = _add_box(Vector3(5.4, 1.4, 2.2), _ground(c - side_dir * 1.6), cy + PI / 2)
	# плиты с рисунками на задней стене
	for i in 3:
		var off := gate_dir * (i - 1) * 1.75
		var slab := Models.glb("fresco_slab")
		var sp := _ground(c - side_dir * 2.55 + off)
		if slab:
			slab.position = sp
			slab.rotation.y = cy           # лицом ко входу в подвал
			slab.scale = Vector3(0.52, 0.8, 1.0)
			add_child(slab)
		var pic := Sprite3D.new()
		pic.texture = FX.icon_texture("fresco_" + ["light", "storm", "map"][i])
		pic.pixel_size = 1.6 / 1024.0
		pic.position = sp + Vector3(0, 1.4, 0) + side_dir * 0.3
		pic.rotation.y = cy
		pic.shaded = false
		pic.double_sided = true
		add_child(pic)
	var fr := StoryPlace.new()
	fr.id = "frescoes"
	fr.position = _ground(c - side_dir * 0.4)
	add_child(fr)
	# рычаги (слева направо: Солнце, Луна, Звезда — не по порядку)
	var syms := ["sun", "moon", "star"]
	for i in 3:
		var lv := Lever.new()
		lv.symbol = syms[i]
		lv.fort = self
		lv.position = _ground(c + side_dir * 1.6 + gate_dir * (i - 1) * 1.6)
		lv.rotation.y = cy
		add_child(lv)
		levers.append(lv)


func pull(symbol: String) -> void:
	if Game.flags.get("cellar_drained", false) or symbol in _pulled:
		return
	_pulled.append(symbol)
	Audio.play("rock", -4.0, 0.1)
	var i := _pulled.size() - 1
	if ORDER[i] != symbol:
		# неправильный порядок — вода возвращается, рычаги встают на место
		var pulled_copy := _pulled.duplicate()
		_pulled.clear()
		get_tree().create_timer(0.6).timeout.connect(func():
			Audio.play("water", 0.0, 0.0)
			Game.notified.emit("Вода с шумом вернулась. Порядок неверный — подсказка в журнале (K).", Color("ff9d7a"))
			for lv in levers:
				lv.reset())
		Game.bump("lever_fail", "cellar")
		return
	if _pulled.size() == ORDER.size():
		Game.flags["cellar_drained"] = true
		_drain(true)
		Game.bump("solved", "cellar")


func _drain(animate: bool) -> void:
	if _pool_shape:
		_pool_shape.disabled = true
	for lv in levers:
		lv.set_pulled(true)
	if animate:
		Audio.play("water", 0.0, 0.0)
		var tw := create_tween()
		tw.tween_property(_pool, "position:y", _pool.position.y - 0.45, 2.0)
		tw.tween_callback(func(): _pool.visible = false)
	else:
		_pool.visible = false


class Lever extends StaticBody3D:
	var symbol := "sun"
	var fort: FortRuin
	var handle: Node3D
	var pulled := false

	func _ready() -> void:
		add_to_group("interactable")
		collision_layer = 4
		var m := Models.glb("lever")
		if m:
			add_child(m)
			handle = m.find_child("Handle", true, false) as Node3D
		var cs := CollisionShape3D.new()
		var b := BoxShape3D.new()
		b.size = Vector3(0.5, 0.8, 0.5)
		cs.shape = b
		cs.position.y = 0.4
		add_child(cs)
		var sym := Sprite3D.new()
		sym.texture = FX.icon_texture("sym_" + symbol)
		sym.pixel_size = 0.0027
		sym.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sym.shaded = false
		sym.position.y = 2.1
		add_child(sym)

	func set_pulled(v: bool) -> void:
		pulled = v
		if handle:
			create_tween().tween_property(handle, "rotation:x", 0.9 if v else 0.0, 0.25)

	func reset() -> void:
		set_pulled(false)

	func interact_point() -> Vector3:
		return global_position + Vector3(0, 0.8, 0)

	func tool_hint() -> String:
		return ""

	func get_hint() -> String:
		var names := {"sun": "Солнце", "moon": "Луна", "star": "Звезда"}
		if Game.flags.get("cellar_drained", false):
			return "Рычаг «%s» (вода ушла)" % names[symbol]
		return "Потянуть рычаг «%s»" % names[symbol]

	func interact(_player: Node) -> void:
		if pulled or Game.flags.get("cellar_drained", false):
			return
		set_pulled(true)
		fort.pull(symbol)
