class_name StiltCamp
extends Node3D
## Лагерь выживших на сваях в лагуне Туманного острова и «Альбатрос» рядом с ним.
##
## Помост на сваях (часть — над водой), три хижины, лампы; Рената, Гоша, Петя и Паша (и Стёпа, когда приплывёт).
## От помоста к борту «Альбатроса» идут мостки; на их конце — сюжетные места корабля: подняться на палубу
## и пять частей (корпус, мачта и паруса, руль, огни, рация). Корабль сам показывает, что уже починено.
## Узел стоит у кромки воды; «вперёд» (out) — в лагуну, side — вдоль берега.

const DECK_TOP := 0.55
const PARTS := ["albatros_hull", "albatros_mast", "albatros_helm", "albatros_lights", "albatros_radio"]

var island: Island
var out := Vector3.FORWARD
var side := Vector3.RIGHT
var ship: AlbatrosShip
var _reached := false


func _ready() -> void:
	add_to_group("stilt_camp")
	add_to_group("fog_light")
	out = Vector3(global_position.x, 0, global_position.z).normalized()
	side = Vector3(-out.z, 0, out.x)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	add_child(body)
	var yaw := atan2(out.x, out.z)
	# помост 10 × 9 м, верх — на DECK_TOP над водой
	var deck_c := out * 3.0
	_box(body, Vector3(10.0, 0.6, 9.0), deck_c + Vector3(0, DECK_TOP - 0.3 - global_position.y, 0), yaw)
	_model("stilt_platform", deck_c + Vector3(0, DECK_TOP - global_position.y, 0), yaw)
	# мостки к кораблю
	var pier_c := out * 9.5
	_box(body, Vector3(2.2, 0.6, 5.0), pier_c + Vector3(0, DECK_TOP - 0.3 - global_position.y, 0), yaw)
	_model("stilt_pier", pier_c + Vector3(0, DECK_TOP - global_position.y, 0), yaw)
	# хижины и жители
	for spec in [[Vector2(-3.0, 4.6), PI], [Vector2(3.2, 4.4), PI], [Vector2(-3.4, 1.3), PI * 0.5]]:
		var rf: Vector2 = spec[0]
		_model("stilt_hut", side * rf.x + out * rf.y + Vector3(0, DECK_TOP - global_position.y, 0), yaw + float(spec[1]))
		_box(body, Vector3(2.4, 2.4, 2.2), side * rf.x + out * rf.y + Vector3(0, DECK_TOP + 1.2 - global_position.y, 0), yaw)
	var who := [["renata", Vector2(0.0, 3.0)], ["gosha", Vector2(1.6, 7.6)], ["petya", Vector2(-1.4, 1.6)], ["pasha", Vector2(-0.4, 1.4)]]
	if Game.flags.get("stepa_at_fog", false):
		who.append(["stepa", Vector2(2.0, 2.0)])
	for w in who:
		var n := NPCPerson.new()
		n.npc_id = w[0]
		var rf: Vector2 = w[1]
		n.position = side * rf.x + out * rf.y + Vector3(0, DECK_TOP - global_position.y, 0)
		n.rotation.y = yaw + PI
		add_child(n)
		island.poi_extra[w[0]] = to_global(n.position)
	for p in [Vector2(-4.5, 0.8), Vector2(4.5, 0.8), Vector2(0, 7.2)]:
		var lamp := OmniLight3D.new()
		lamp.light_color = Color("ffc070")
		lamp.light_energy = 1.3
		lamp.omni_range = 6.0
		lamp.position = side * p.x + out * p.y + Vector3(0, DECK_TOP + 2.0 - global_position.y, 0)
		add_child(lamp)
	# корабль у мостков, бортом к ним
	ship = AlbatrosShip.new()
	ship.camp = self
	ship.position = out * 15.5 + side * 1.0 + Vector3(0, -global_position.y, 0)
	ship.rotation.y = yaw   # длинной стороной вдоль берега, бортом к мосткам
	add_child(ship)
	# сюжетные места — на конце мостков
	var ids := ["albatros", "albatros_hull", "albatros_mast", "albatros_helm", "albatros_lights", "albatros_radio"]
	for i in ids.size():
		var sp := StoryPlace.new()
		sp.id = ids[i]
		sp.position = side * (-0.8 + (i % 2) * 1.6) + out * (7.8 + (i / 2) * 1.6) + Vector3(0, DECK_TOP - global_position.y, 0)
		add_child(sp)
	var wheel := Helm.new()
	wheel.camp = self
	wheel.position = out * 11.6 + Vector3(0, DECK_TOP - global_position.y, 0)
	add_child(wheel)
	island.poi_extra["stilt_camp"] = to_global(out * 3.0 + Vector3(0, DECK_TOP + 0.3 - global_position.y, 0))


var fog_radius: float:
	get:
		return 9.0


func _box(body: StaticBody3D, size: Vector3, pos: Vector3, yaw: float) -> void:
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	cs.shape = b
	cs.position = pos
	cs.rotation.y = yaw
	body.add_child(cs)


func _model(name_: String, pos: Vector3, yaw := 0.0) -> Node3D:
	var m := Models.glb(name_)
	if m == null:
		return null
	m.position = pos
	m.rotation.y = yaw
	add_child(m)
	return m


## Мировая точка на помосте (для автотеста).
func deck_point() -> Vector3:
	return to_global(out * 3.0 + Vector3(0, DECK_TOP + 0.4 - global_position.y, 0))


func _process(_delta: float) -> void:
	if _reached:
		return
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if p == null:
		return
	var lp := p.global_position - global_position
	var f := lp.dot(out)
	var s := lp.dot(side)
	if f > -1.5 and f < 12.0 and absf(s) < 5.2 and p.global_position.y > DECK_TOP - 0.3:
		_reached = true
		Game.bump("reached", "stilt_camp")
		Game.notified.emit("Лагерь на сваях", Color("ffe08a"))


# ------------------------------------------------------------------ «Альбатрос»
## Шхуна «Альбатрос»: до починки корпуса — накренилась, во мху, мачта сломана; дальше — по частям
## (мачта с парусами, руль, огни). Выйдя из лагуны, уходит на рейд.
class AlbatrosShip extends Node3D:
	var camp: StiltCamp
	var hull: Node3D
	var parts := {}
	var _state := ""

	func _ready() -> void:
		add_to_group("albatros")
		_refresh(false)
		if Game.flags.get("albatros_sailed", false):
			position += _away()

	func _away() -> Vector3:
		return camp.out * 26.0

	func _refresh(animate: bool) -> void:
		var key := ""
		for p in StiltCamp.PARTS:
			key += "1" if Game.flags.get("restored_" + p, false) else "0"
		if key == _state:
			return
		_state = key
		var fixed: bool = Game.flags.get("restored_albatros_hull", false)
		var want := "albatros" if fixed else "albatros_wreck"
		if hull == null or hull.name != want:
			if hull:
				hull.queue_free()
			hull = Models.glb(want)
			if hull == null:
				hull = Node3D.new()
			hull.name = want
			add_child(hull)
		var tilt := 0.0 if fixed else 0.14
		if animate:
			create_tween().tween_property(self, "rotation:z", tilt, 2.0).set_trans(Tween.TRANS_SINE)
		else:
			rotation.z = tilt
		for p in [["albatros_mast", "albatros_mast"], ["albatros_helm", "albatros_helm"], ["albatros_lights", "albatros_lights"]]:
			var on: bool = Game.flags.get("restored_" + p[0], false)
			if on and not parts.has(p[0]):
				var m := Models.glb(p[1])
				if m:
					add_child(m)
					parts[p[0]] = m
					if p[0] == "albatros_lights":
						for lp in m.find_children("Lamp*", "Node3D", true, false):
							var l := OmniLight3D.new()
							l.light_color = Color("d8ffa0")
							l.light_energy = 1.4
							l.omni_range = 6.0
							(lp as Node3D).add_child(l)
					if animate:
						m.scale = Vector3(0.05, 0.05, 0.05)
						create_tween().tween_property(m, "scale", Vector3.ONE, 0.8).set_trans(Tween.TRANS_BACK)

	func ready_to_sail() -> bool:
		for p in StiltCamp.PARTS:
			if not Game.flags.get("restored_" + p, false):
				return false
		return true

	var _creak_t := 6.0

	func _process(delta: float) -> void:
		_refresh(true)
		_creak_t -= delta
		if _creak_t <= 0.0:
			_creak_t = randf_range(8.0, 16.0)
			Audio.play("creak", -8.0, 0.1, global_position)
		if not Game.flags.get("albatros_sailed", false):
			var t := Time.get_ticks_msec() / 1000.0
			rotation.x = sin(t * 0.6) * 0.012

	## Вывести корабль из лагуны.
	func sail(animate := true) -> void:
		if Game.flags.get("albatros_sailed", false):
			return
		Game.flags["albatros_sailed"] = true
		if animate:
			create_tween().tween_property(self, "position", position + _away(), 8.0).set_trans(Tween.TRANS_SINE)
			Audio.play("creak", 0.0, 0.0)
			Audio.play("sail", -2.0, 0.0)
		else:
			position += _away()
		Game.bump("sailed", "albatros")



## Штурвал на конце мостков: вывести «Альбатрос», когда всё починено и есть карта.
class Helm extends StaticBody3D:
	var camp: StiltCamp

	func _ready() -> void:
		add_to_group("interactable")
		collision_layer = 8
		var cs := CollisionShape3D.new()
		var c := CylinderShape3D.new()
		c.radius = 0.4
		c.height = 1.2
		cs.shape = c
		cs.position.y = 0.6
		add_child(cs)

	func interact_point() -> Vector3:
		return global_position + Vector3(0, 1.0, 0)

	func tool_hint() -> String:
		return ""

	func get_hint() -> String:
		if Game.flags.get("albatros_sailed", false):
			return "«Альбатрос» стоит на рейде, паруса полны ветра"
		if not camp.ship.ready_to_sail():
			return "Сходни на «Альбатрос» — корабль ещё не готов"
		if not Game.flags.get("fog_cleared", false):
			return "«Альбатрос» готов, но в тихой воде нет ветра"
		if Game.count("sea_chart") == 0:
			return "«Альбатрос» готов — нужна карта края Тихой воды"
		return "Встать за штурвал — вывести «Альбатрос» из лагуны"

	func interact(_player: Node) -> void:
		if camp.ship.ready_to_sail() and Game.flags.get("fog_cleared", false) and Game.count("sea_chart") > 0 \
				and not Game.flags.get("albatros_sailed", false):
			camp.ship.sail(true)
		else:
			Game.notified.emit(get_hint(), Color("ffe08a"))
