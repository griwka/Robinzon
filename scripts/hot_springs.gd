class_name HotSprings
extends Node3D
## Горячие источники Острова Вулкана: три каменные чаши с бирюзовой водой и паром,
## рядом — лечебница доктора Веры (домик с пучками трав) и сама Вера на крыльце.
## У источников прохладно и спокойно: жар спадает сразу (группа «cool_spot»).

var island: Island


func _ready() -> void:
	add_to_group("obstacle")
	add_to_group("cool_spot")
	var m := Models.glb("hot_springs")
	if m:
		add_child(m)
	var body := StaticBody3D.new()
	body.collision_layer = 8   # в чаши можно зайти
	add_child(body)
	# пар над чашами
	for p in [Vector3(-1.4, 0.4, 0.2), Vector3(1.3, 0.4, -0.4), Vector3(0.2, 0.4, 1.6)]:
		var st := CPUParticles3D.new()
		st.amount = 10
		st.lifetime = 3.0
		st.preprocess = 3.0
		st.mesh = FX._quad(FX.particle_mat(0.0, 0.6))
		st.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		st.emission_sphere_radius = 0.6
		st.direction = Vector3.UP
		st.spread = 15.0
		st.gravity = Vector3(0.05, 0.25, 0.0)
		st.initial_velocity_min = 0.25
		st.initial_velocity_max = 0.5
		st.scale_amount_min = 0.5
		st.scale_amount_max = 1.0
		st.scale_amount_curve = FX.curve([Vector2(0, 0.2), Vector2(0.4, 1.0), Vector2(1, 1.5)])
		st.color = Color(1, 1, 1, 0.35)
		st.position = p
		add_child(st)
	var spring := StoryPlace.new()
	spring.id = "hot_spring"
	spring.position = Vector3(0, 0.2, 0)
	add_child(spring)
	# лечебница и Вера
	var to_c := Vector3(-position.x, 0, -position.z).normalized()
	var side := Vector3(-to_c.z, 0, to_c.x)
	var hp := side * 5.2 + to_c * 0.5
	hp.y = _ground(hp)
	var clinic := Models.glb("clinic")
	if clinic:
		clinic.position = hp
		clinic.rotation.y = atan2(-side.x, -side.z)
		add_child(clinic)
		var hb := StaticBody3D.new()
		hb.collision_layer = 4
		var cs := CollisionShape3D.new()
		var b := BoxShape3D.new()
		b.size = Vector3(3.0, 2.6, 2.6)
		cs.shape = b
		cs.position.y = 1.3
		hb.add_child(cs)
		clinic.add_child(hb)
	var vera := NPCPerson.new()
	vera.npc_id = "vera"
	var vp := side * 3.0 + to_c * 1.6
	vp.y = _ground(vp)
	vera.position = vp
	vera.rotation.y = atan2(-side.x, -side.z)
	add_child(vera)
	if island:
		island.poi_extra["vera"] = to_global(vp)


func _ground(local_p: Vector3) -> float:
	var w := position + local_p
	return island.height_at(w.x, w.z) - position.y if island else 0.0


## Прохладно ли в точке (в воде источников и рядом).
func cool_at(p: Vector3) -> bool:
	return Vector2(p.x - global_position.x, p.z - global_position.z).length() < 3.6
