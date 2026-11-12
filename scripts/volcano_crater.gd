class_name VolcanoCrater
extends Node3D
## Кратер Острова Вулкана: столовая гора с отвесной стеной из базальтовых столбов (~7 м).
##
## Наверху — кольцо края и озеро лавы в середине (к нему не подойти: жар отбрасывает), над ним — дым.
## На дальнем (северном) краю — маяк Огонь кратера: починить лавовый жёлоб и открыть заслонку.
## Подняться можно в одном месте — со стороны лагеря, по выступам базальта (перчатки лазальщика); на стене жарко.
## Узел стоит в точке (x, 0, z) центра кратера, так что локальная высота = мировая.

const WALL_R := 8.6
const SEGS := 16
const PARAPET := 1.1
const LAKE_R := 3.4

var island: Island
var site := Vector3.ZERO
var foot := Vector3.ZERO
var temple_dir := Vector3.RIGHT   # куда смотрит храм (из центра кратера)
var top := 12.0
var fwd := Vector3.FORWARD
var right := Vector3.RIGHT
var climb: Climbable
var _body: StaticBody3D
var _reached := false
var _rumble_t := 8.0


func _ready() -> void:
	add_to_group("obstacle")
	add_to_group("crater")
	top = site.y
	fwd = Vector3(foot.x - site.x, 0, foot.z - site.z).normalized()
	right = Vector3(-fwd.z, 0, fwd.x)
	_body = StaticBody3D.new()
	_body.collision_layer = 1
	add_child(_body)
	_build_wall()
	_build_top()
	_build_climb()
	if island:
		island.poi_extra["crater_top"] = top_point()
		island.poi_extra["volcano_tower"] = to_global(_on_top(-5.6, 1.5) + Vector3(0, 0.4, 0))


func block_radius() -> float:
	return WALL_R + 1.0


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


func _build_wall() -> void:
	var a_climb := atan2(fwd.z, fwd.x)
	var chord := TAU * WALL_R / SEGS
	for i in SEGS:
		var a := a_climb + TAU * i / SEGS
		var out := Vector3(cos(a), 0, sin(a))
		var p := out * WALL_R
		var low := minf(_ground(out * (WALL_R + 1.2)), _ground(out * (WALL_R + 0.6))) - 1.0
		var hi := top + (0.0 if i == 0 else PARAPET)
		_box(Vector3(chord * 1.12, hi - low, 0.9), p + Vector3(0, (hi + low) * 0.5, 0), -a - PI / 2)
		_model("crater_wall", Vector3(p.x, low, p.z), PI / 2 - a, Vector3(1.0, (top + 0.9 - low) / 8.0, 1.0))


func _build_top() -> void:
	# озеро лавы: светится, к нему не подойти (невысокий бортик), жар отбрасывает
	var lake := Lava.mesh_node(Lava.disk_mesh(LAKE_R))
	lake.position = Vector3(0, top + 0.12, 0)
	add_child(lake)
	_model("lava_rim", Vector3(0, top, 0))
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = LAKE_R + 0.2
	cyl.height = 1.4
	cs.shape = cyl
	cs.position = Vector3(0, top + 0.7, 0)
	_body.add_child(cs)
	var pool := Lava.Pool.new()
	pool.radius = LAKE_R
	pool.position = Vector3(0, top, 0)
	add_child(pool)
	var glow := OmniLight3D.new()
	glow.light_color = Color("ff7a2a")
	glow.light_energy = 2.4
	glow.omni_range = 11.0
	glow.position = Vector3(0, top + 1.5, 0)
	add_child(glow)
	# дым над кратером — видно со всего острова
	var smoke := CPUParticles3D.new()
	smoke.amount = 40
	smoke.lifetime = 9.0
	smoke.preprocess = 9.0
	smoke.local_coords = false
	smoke.mesh = FX._quad(FX.particle_mat(0.0, 0.5))
	smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	smoke.emission_sphere_radius = 2.0
	smoke.direction = Vector3(0.15, 1, 0.05)
	smoke.spread = 12.0
	smoke.gravity = Vector3(0.25, 0.3, 0.0)
	smoke.initial_velocity_min = 1.6
	smoke.initial_velocity_max = 2.4
	smoke.scale_amount_min = 2.2
	smoke.scale_amount_max = 4.0
	smoke.scale_amount_curve = FX.curve([Vector2(0, 0.3), Vector2(0.3, 1.0), Vector2(1, 1.6)])
	smoke.color_ramp = _smoke_ramp()
	smoke.position = Vector3(0, top + 1.0, 0)
	add_child(smoke)
	# маяк — на дальнем краю, лицом к озеру
	var tw := StoryPlace.new()
	tw.id = "volcano_tower"
	tw.position = _on_top(-6.4, 0.0)
	tw.rotation.y = atan2(fwd.x, fwd.z)
	add_child(tw)
	# камни на краю — для вида
	for k in 6:
		var a := TAU * k / 6.0 + 0.5
		var m := _model("basalt_a" if k % 2 == 0 else "basalt_b", Vector3(cos(a) * 6.8, top - 0.05, sin(a) * 6.8), a)
		if m:
			m.scale = Vector3(0.7, 0.6, 0.7)
			Models.add_trimesh(_body, m)


func _smoke_ramp() -> Gradient:
	var g := Gradient.new()
	g.set_color(0, Color(0.38, 0.35, 0.34, 0.0))
	g.add_point(0.15, Color(0.4, 0.37, 0.36, 0.55))
	g.add_point(0.7, Color(0.62, 0.6, 0.6, 0.35))
	g.set_color(g.get_point_count() - 1, Color(0.8, 0.8, 0.82, 0.0))
	return g


func _build_climb() -> void:
	var foot_y := _ground(fwd * (WALL_R + 1.4))
	climb = Climbable.new()
	climb.rock = true
	climb.hot = true
	climb.ladder_yaw = atan2(fwd.x, fwd.z)
	climb.bottom = fwd * (WALL_R + 0.62) + Vector3(0, foot_y, 0)
	climb.top = Vector3(climb.bottom.x, top + 1.1, climb.bottom.z)
	climb.exit = _on_top(WALL_R - 1.7, 0.0) + Vector3(0, 0.2, 0)
	add_child(climb)


func top_point() -> Vector3:
	return to_global(_on_top(6.0, 0.0) + Vector3(0, 0.4, 0))


func foot_point() -> Vector3:
	return to_global(climb.bottom + fwd * 0.6 + Vector3(0, 0.3, 0))


## Внутри ли точка кратера (в плане) — там нет ни лавы у храма, ни преград.
func inside(p: Vector3, margin := 0.0) -> bool:
	var lp := to_local(p)
	return Vector2(lp.x, lp.z).length() < WALL_R + margin


func _process(delta: float) -> void:
	_rumble_t -= delta
	if _rumble_t <= 0.0:
		_rumble_t = randf_range(14.0, 26.0)
		Audio.play("rumble", -12.0, 0.1)
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if p == null or _reached:
		return
	var lp := to_local(p.global_position)
	if Vector2(lp.x, lp.z).length() < WALL_R - 0.3 and lp.y > top - 1.0:
		_reached = true
		Game.bump("reached", "crater_top")
		Game.notified.emit("Край кратера", Color("ffd0a0"))
