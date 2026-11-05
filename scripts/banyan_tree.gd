class_name BanyanTree
extends Node3D
## Великий Баньян: ствол, три яруса-площадки на разной высоте, лианы между ними, чаша огня наверху
## и Мелани на втором ярусе. Ярусы — по спирали вокруг ствола, каждая лиана висит над нижним ярусом.

const DECKS := [   # [высота над корнями, угол вокруг ствола]
	[6.5, 0.0],
	[13.0, 0.75],
	[21.0, 1.5],
]
const DECK_R := 5.6   # расстояние центра яруса от оси ствола

var decks: Array[Node3D] = []
var _reached: Dictionary = {}
var bowl_fire: Node3D


func _ready() -> void:
	add_to_group("obstacle")
	var model := Models.glb("banyan_giant")
	if model:
		add_child(model)
		for gi in model.find_children("*", "GeometryInstance3D", true, false):
			(gi as GeometryInstance3D).visibility_range_end = 0.0
	var body := StaticBody3D.new()
	body.collision_layer = 4
	add_child(body)
	var cs := CollisionShape3D.new()
	var c := CylinderShape3D.new()
	c.radius = 3.6
	c.height = 30.0
	cs.shape = c
	cs.position.y = 15.0
	body.add_child(cs)
	# ярусы
	for i in DECKS.size():
		var h: float = DECKS[i][0]
		var a: float = DECKS[i][1]
		var d := _deck_center(i)
		var deck := Models.glb("deck")
		var holder := Node3D.new()
		holder.position = d
		holder.rotation.y = -a   # длинная сторона — по касательной к стволу
		add_child(holder)
		if deck:
			holder.add_child(deck)
		var dcs := CollisionShape3D.new()
		var b := BoxShape3D.new()
		b.size = Vector3(5.0, 0.3, 4.0)
		dcs.shape = b
		dcs.position = d + Vector3(0, -0.1, 0)
		dcs.rotation.y = -a
		body.add_child(dcs)
		decks.append(holder)
	# лианы: с земли на 1-й ярус и между ярусами
	_add_liana(Vector3(cos(DECKS[0][1]) * (DECK_R + 2.3), 0.0, sin(DECKS[0][1]) * (DECK_R + 2.3)), DECKS[0][0], _deck_center(0))
	for i in range(1, DECKS.size()):
		var a_mid: float = (DECKS[i - 1][1] + DECKS[i][1]) * 0.5
		var base := Vector3(cos(a_mid) * (DECK_R + 0.6), DECKS[i - 1][0], sin(a_mid) * (DECK_R + 0.6))
		_add_liana(base, DECKS[i][0], _deck_center(i))
	# чаша огня на верхнем ярусе — огонь, который увидел маяк
	var top := _deck_center(2)
	var fb := Models.glb("fire_bowl")
	if fb:
		fb.position = top + Vector3(0, 0.05, 0)
		add_child(fb)
	bowl_fire = Node3D.new()
	bowl_fire.position = top + Vector3(0, 1.2, 0)
	add_child(bowl_fire)
	for spec in [[0.55, 1.4, Color("ff8a1e")], [0.3, 0.9, Color("ffe066")]]:
		var f := MeshInstance3D.new()
		f.mesh = Models.cyl(0.0, spec[0], spec[1], 8)
		f.material_override = Models.unshaded(spec[2])
		f.position.y = spec[1] * 0.4
		f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		bowl_fire.add_child(f)
	var l := OmniLight3D.new()
	l.light_color = Color("ffb35c")
	l.light_energy = 4.0
	l.omni_range = 28.0
	bowl_fire.add_child(l)
	# Мелани на втором ярусе
	var mel := NPCPerson.new()
	mel.npc_id = "melanie"
	mel.position = _deck_center(1) + Vector3(0, 0.08, 0)
	mel.rotation.y = -DECKS[1][1] + PI
	add_child(mel)
	# места для осмотра: корни и чаша огня
	for spec in [["banyan_roots", Vector3(cos(0.0) * 4.3, 0.2, sin(0.0) * 4.3)], ["fire_bowl", top + Vector3(0, 0.6, 0)]]:
		var sp := StoryPlace.new()
		sp.id = spec[0]
		sp.position = spec[1]
		add_child(sp)


func _deck_center(i: int) -> Vector3:
	var h: float = DECKS[i][0]
	var a: float = DECKS[i][1]
	return Vector3(cos(a) * DECK_R, h, sin(a) * DECK_R)


func _add_liana(bottom: Vector3, top_h: float, exit: Vector3) -> void:
	var cl := Climbable.new()
	cl.bottom = bottom
	cl.top = Vector3(bottom.x, top_h, bottom.z)
	cl.exit = exit + Vector3(0, 0.3, 0)
	add_child(cl)


func block_radius() -> float:
	return 4.5


func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	bowl_fire.scale.y = 0.9 + 0.15 * abs(sin(t * 6.0))
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if p == null:
		return
	for i in DECKS.size():
		var id := "deck%d" % (i + 1)
		if _reached.has(id):
			continue
		var d := to_global(_deck_center(i))
		if Vector2(p.global_position.x - d.x, p.global_position.z - d.z).length() < 2.8 and abs(p.global_position.y - d.y) < 1.2:
			_reached[id] = true
			Game.bump("reached", id)
			Game.notified.emit("Ярус %d" % (i + 1), Color("bfe3ff"))
