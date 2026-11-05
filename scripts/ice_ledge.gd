class_name IceLedge
extends Node3D
## Ледяной уступ на востоке Ледяного острова: глыба голубого льда в три с половиной метра.
## Наверху — ледяной ларец Лёвы (ice_chest_1). Залезть можно по передней стене с зарубками —
## с ледорубом и в перчатках. Узел повёрнут так, что передняя стена (+Z) смотрит к лагерю.

const H := 3.6       # высота уступа над землёй
const HALF := 1.7    # полуширина глыбы


func _ready() -> void:
	add_to_group("obstacle")
	var body := StaticBody3D.new()
	body.collision_layer = 1
	add_child(body)
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(HALF * 2.0, H + 1.0, HALF * 2.0)
	cs.shape = b
	cs.position.y = (H - 1.0) * 0.5
	body.add_child(cs)
	var m := Models.glb("ice_ledge")
	if m:
		m.position.y = -0.6
		m.scale = Vector3(1.0, (H + 0.6) / 4.2, 1.0)
		add_child(m)
	var cl := Climbable.new()
	cl.ice = true
	cl.rest_step = 1.8
	cl.ladder_yaw = 0.0
	cl.bottom = Vector3(0.0, 0.0, HALF + 0.12)
	cl.top = Vector3(0.0, H + 1.1, HALF + 0.12)
	cl.exit = Vector3(0.0, H + 0.2, HALF - 0.7)
	add_child(cl)
	var chest := StoryPlace.new()
	chest.id = "ice_chest_1"
	chest.position = Vector3(0.0, H, -0.5)
	add_child(chest)


func block_radius() -> float:
	return HALF + 0.8


## Для автотеста: мировая точка на верху уступа.
func top_point() -> Vector3:
	return to_global(Vector3(0.6, H + 0.4, 0.4))
