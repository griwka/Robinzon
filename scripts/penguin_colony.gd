class_name PenguinColony
extends Node3D
## Пингвины у замёрзшей бухты на западе Ледяного острова.
## На берегу — стая пингвинов и кормушка (сюда относят рыбу по заданию), у воды — ледяной припай
## с тремя лунками: ледовым буром сверлишь лунку, дальше рыбачишь удочкой. Рыба подо льдом — северная.

const COUNT := 7

var island: Island
var holes: Array[FishingSpot] = []


func _ready() -> void:
	add_to_group("penguins")
	var out := Vector3(position.x, 0, position.z).normalized()   # к морю
	var side := Vector3(-out.z, 0, out.x)
	# кормушка — та точка, куда «отдают» рыбу
	var feeder := NPCPerson.new()
	feeder.npc_id = "penguins"
	feeder.rotation.y = atan2(out.x, out.z)
	add_child(feeder)
	# пингвины бродят вокруг
	for i in COUNT:
		var a := Animal.new()
		a.kind = "penguin"
		a.home = global_position - out * 1.2
		a.radius = 3.2
		a.position = position - out * 1.2 + side * randf_range(-2.5, 2.5) + out * randf_range(-1.5, 1.0)
		get_parent().add_child.call_deferred(a)
	# кромка воды и припай
	var r := Vector2(position.x, position.z).length()
	var shore := r
	while shore < r + 30.0 and island and island.height_at(out.x * shore, out.z * shore) > 0.0:
		shore += 0.25
	var s0 := out * (shore - r)    # кромка воды, в локальных координатах
	var deep := 0.6
	while deep < 4.0 and island and _h(s0 + out * (deep + 0.25)) > -0.8:
		deep += 0.25
	var shelf := s0 + out * (deep * 0.5)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	add_child(body)
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(8.0, 0.5, deep + 1.4)
	cs.shape = b
	cs.position = Vector3(shelf.x, -0.2 - position.y, shelf.z)   # верх припая — чуть над водой
	cs.rotation.y = atan2(out.x, out.z)
	body.add_child(cs)
	var m := Models.glb("ice_shelf")
	if m:
		m.position = Vector3(shelf.x, -0.04 - position.y, shelf.z)   # верх припая — на 8 см над водой
		m.rotation.y = atan2(out.x, out.z)
		m.scale = Vector3(1.15, 1.0, (deep + 1.6) / 4.0)
		add_child(m)
	# лунки — на припае, в мелкой части
	var k := 0
	for t in [-2.4, 0.0, 2.4]:
		var hp: Vector3 = s0 + out * clampf(deep * 0.55, 0.8, 2.6) + side * t
		var fs := FishingSpot.new()
		fs.ice = true
		fs.hole_id = "ice_hole_%d" % k
		fs.position = Vector3(hp.x, 0.06 - position.y, hp.z)
		add_child(fs)
		holes.append(fs)
		k += 1


func _h(local_p: Vector3) -> float:
	var w := global_position + local_p
	return island.height_at(w.x, w.z)
