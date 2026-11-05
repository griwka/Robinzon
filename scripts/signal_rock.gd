class_name SignalRock
extends Node3D
## Сигнальный камень в болоте Туманного острова: большой валун, на нём два года горит огонь Миши.
## От лагеря к нему ведёт тропа с пятью метками под тыквенные фонари (LanternSpot). Когда на всех пяти горит
## свет, туман на тропе уходит и Миша перестаёт прятаться (флаг trail_lit).

var island: Island
var trail_from := Vector3.ZERO   # откуда идёт тропа (лагерь на берегу)
var spots: Array[LanternSpot] = []


func _ready() -> void:
	add_to_group("signal_rock")
	add_to_group("fog_light")
	var m := Models.glb("signal_rock")
	if m:
		add_child(m)
	var body := StaticBody3D.new()
	body.collision_layer = 4
	var cs := CollisionShape3D.new()
	var c := CylinderShape3D.new()
	c.radius = 1.3
	c.height = 2.0
	cs.shape = c
	cs.position.y = 1.0
	body.add_child(cs)
	add_child(body)
	var fp := m.find_child("FirePoint", true, false) as Node3D if m else null
	Models.flame(self, fp.position if fp else Vector3(0, 2.1, 0), 0.8, 2.6, 10.0)
	var misha := NPCPerson.new()
	misha.npc_id = "misha"
	var to_trail := Vector3(trail_from.x - global_position.x, 0, trail_from.z - global_position.z).normalized()
	var mp := to_trail * 2.0
	mp.y = island.height_at(global_position.x + mp.x, global_position.z + mp.z) - global_position.y
	misha.position = mp
	misha.rotation.y = atan2(to_trail.x, to_trail.z)
	add_child(misha)
	island.poi_extra["misha"] = global_position + mp
	# пять меток вдоль тропы от лагеря к камню
	var a := trail_from
	var b := global_position
	for i in 5:
		var t := 0.18 + i * 0.16
		var p := a.lerp(b, t)
		var side := Vector3(-(b - a).z, 0, (b - a).x).normalized() * (1.3 if i % 2 == 0 else -1.3)
		p += side
		p.y = island.height_at(p.x, p.z)
		var sp := LanternSpot.new()
		sp.group = "lantern_spot"
		sp.position = p - global_position
		add_child(sp)
		spots.append(sp)


## fog_light: радиус пустоты в тумане вокруг сигнального огня.
var fog_radius: float:
	get:
		return 5.5


func lit_count() -> int:
	var n := 0
	for s in spots:
		if s.used:
			n += 1
	return n


func _process(_delta: float) -> void:
	if not Game.flags.get("trail_lit", false) and lit_count() >= 5:
		Game.flags["trail_lit"] = true
		Game.notified.emit("Тропа к сигнальному камню освещена. Туман отступил", Color("ffe08a"))
