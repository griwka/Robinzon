class_name VolcanoTemple
extends Node3D
## Огненный храм Хранителей: вход вырезан в стене кратера (на востоке).
##
## Перед входом — лавовое поле: три огненных ручья дугами вокруг входа (концы упираются в стену кратера).
## Перейти можно только по каменным мосткам — на каждом ручье есть одно место с колышками (BridgeSpot).
## Снаружи поле закрыто базальтовыми столбами (кольцо в Island.RINGS, их ломает железная кирка).
## У самой двери — головоломка «Огненный монолит»: из трещины в скале течёт лава, четыре каменных
## жёлоба надо повернуть так, чтобы каждый смотрел на следующий, а последний — в чашу. Потом — рычаг.
## Узел стоит у входа, на земле; локальные оси: «вперёд» (+out) — от кратера наружу, «вправо» (+side).

const CHANNELS := [[4.6, 0.0], [6.6, 0.55], [8.6, -0.5]]   # [радиус ручья, угол места под мосток от «вперёд»]
const CHANNEL_W := 1.5
# головоломка: точки (вправо, вперёд) — трещина, жёлоба 1–4, чаша; направления: 0 — вперёд, 1 — вправо, 2 — назад, 3 — влево
const SOURCE := Vector2(-2.4, -0.3)
const CHUTES := [Vector2(-2.4, 1.0), Vector2(-2.4, 2.4), Vector2(0.0, 2.4), Vector2(2.4, 2.4)]
const BOWL := Vector2(2.4, 1.0)
const TARGET := [0, 1, 1, 2]
const START := [2, 3, 0, 1]
const COLD := [Vector2(0.0, 1.1), Vector2(-1.2, 3.2), Vector2(1.3, 3.3)]

var island: Island
var crater: VolcanoCrater
var out := Vector3.FORWARD
var side := Vector3.RIGHT
var chutes: Array[Chute] = []
var spots: Array[BridgeSpot] = []
var door: Node3D
var bowl_fire: Node3D
var _body: StaticBody3D
var _reached := false
var _flow: Node3D


func _ready() -> void:
	add_to_group("temple")
	add_to_group("obstacle")
	out = Vector3(global_position.x - crater.global_position.x, 0, global_position.z - crater.global_position.z).normalized()
	side = Vector3(-out.z, 0, out.x)
	_body = StaticBody3D.new()
	_body.collision_layer = 2
	add_child(_body)
	_build_facade()
	_build_channels()
	_build_puzzle()
	if Game.flags.get("monolith_solved", false):
		_open(false)


func block_radius() -> float:
	return 3.6


## Локальная точка на земле по координатам (вправо, вперёд). У самой стены (вперёд < 0.3) рельеф уже
## поднимается к краю кратера — там берём высоту входа.
func at(rf: Vector2, lift := 0.0) -> Vector3:
	var p := side * rf.x + out * rf.y
	var w := global_position + p
	var h := island.height_at(w.x, w.z) - global_position.y if rf.y > 0.3 else 0.0
	return Vector3(p.x, h + lift, p.z)


func _model(name_: String, pos: Vector3, yaw := 0.0) -> Node3D:
	var m := Models.glb(name_)
	if m == null:
		return null
	m.position = pos
	m.rotation.y = yaw
	add_child(m)
	return m


# ------------------------------------------------------------------ вход
func _build_facade() -> void:
	var yaw := atan2(out.x, out.z)
	_model("temple_facade", at(Vector2(0, -0.95)), yaw)
	door = _model("temple_door", at(Vector2(0, -0.75)), yaw)
	var tp := StoryPlace.new()
	tp.id = "temple"
	tp.position = at(Vector2(0, -0.2), 0.2)
	add_child(tp)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color("ff9a4a")
	lamp.light_energy = 1.4
	lamp.omni_range = 6.0
	lamp.position = at(Vector2(0, 0.5), 2.6)
	add_child(lamp)


func _open(animate: bool) -> void:
	if door:
		if animate:
			create_tween().tween_property(door, "position:y", door.position.y - 3.6, 2.5).set_trans(Tween.TRANS_SINE)
			Audio.play("rumble", -2.0, 0.0)
		else:
			door.position.y -= 3.6
	_show_flow()


# ------------------------------------------------------------------ лавовые ручьи и места под мостки
func _build_channels() -> void:
	var a_out := atan2(out.z, out.x)
	var c := global_position
	var height := func(x: float, z: float) -> float: return island.height_at(x, z)
	var skip := func(p: Vector3) -> bool: return crater.inside(p, 0.1)
	for ci in CHANNELS.size():
		var r: float = CHANNELS[ci][0]
		var spot_da: float = CHANNELS[ci][1]
		# дуга идёт в обе стороны, пока не упрётся в стену кратера
		var span := 0.0
		while span < PI and not crater.inside(c + Vector3(cos(a_out + span), 0, sin(a_out + span)) * r, -0.35):
			span += 0.02
		var span2 := 0.0
		while span2 < PI and not crater.inside(c + Vector3(cos(a_out - span2), 0, sin(a_out - span2)) * r, -0.35):
			span2 += 0.02
		var mesh := Lava.arc_mesh(c, r, CHANNEL_W, a_out - span2, a_out + span, height, global_position)
		add_child(Lava.mesh_node(mesh))
		var heat := Lava.Arc.new()
		heat.center = c
		heat.radius = r
		heat.half_width = CHANNEL_W * 0.5
		heat.skip = skip
		add_child(heat)
		# невысокие стенки над лавой — не перейти и не перепрыгнуть; у места под мосток — отдельный кусок
		var spot_a := a_out + spot_da
		var gap := 1.9 / r          # угол куска под мосток
		var step := 1.0 / r
		# два пролёта стенок: от начала дуги до места под мосток и от него до конца
		for part in [[a_out - span2, spot_a - gap * 0.5], [spot_a + gap * 0.5, a_out + span]]:
			var a: float = part[0]
			var a_end: float = part[1]
			var n := maxi(1, int(ceil((a_end - a) / step)))
			for i in n:
				_wall(c, r, a + (a_end - a) * i / n, a + (a_end - a) * (i + 1) / n)
		var blocker := _wall(c, r, spot_a - gap * 0.5, spot_a + gap * 0.5)
		var sp := BridgeSpot.new()
		sp.block = blocker
		var sw := c + Vector3(cos(spot_a), 0, sin(spot_a)) * r
		sw.y = island.height_at(sw.x, sw.z)
		sp.position = sw - global_position
		sp.rotation.y = atan2(cos(spot_a), sin(spot_a))   # мосток вдоль радиуса — поперёк ручья
		add_child(sp)
		spots.append(sp)


func _wall(c: Vector3, r: float, a0: float, a1: float) -> CollisionShape3D:
	var am := (a0 + a1) * 0.5
	var mid := c + Vector3(cos(am), 0, sin(am)) * r
	var h := island.height_at(mid.x, mid.z)
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(maxf(0.2, (a1 - a0) * r * 1.08), 1.3, CHANNEL_W + 0.1)
	cs.shape = b
	cs.position = Vector3(mid.x, h + 0.65, mid.z) - global_position
	cs.rotation.y = -am - PI / 2
	_body.add_child(cs)
	return cs


## Все ли места под мостки уже заняты (для автотеста).
func bridged_count() -> int:
	var n := 0
	for s in spots:
		if s.used:
			n += 1
	return n


# ------------------------------------------------------------------ огненный монолит
func _build_puzzle() -> void:
	var saved: Variant = Game.flags.get("monolith_chutes", START)
	var dirs: Array = (saved as Array).duplicate() if saved is Array and (saved as Array).size() == 4 else START.duplicate()
	if Game.flags.get("monolith_solved", false):
		dirs = TARGET.duplicate()
	_model("lava_crack", at(SOURCE), atan2(out.x, out.z))
	var src := Lava.mesh_node(Lava.strip_mesh(at(SOURCE, 0.08), at(SOURCE + Vector2(0, 0.6), 0.08), 0.45))
	add_child(src)
	for i in CHUTES.size():
		var ch := Chute.new()
		ch.temple = self
		ch.index = i
		ch.dir = int(dirs[i])
		ch.position = at(CHUTES[i])
		add_child(ch)
		chutes.append(ch)
	var bowl := _model("lava_bowl", at(BOWL), 0.0)
	if bowl:
		var bs := CollisionShape3D.new()
		var cy := CylinderShape3D.new()
		cy.radius = 0.6
		cy.height = 1.0
		bs.shape = cy
		bs.position = at(BOWL, 0.5)
		_body.add_child(bs)
	for c in COLD:
		Models.add_trimesh(_body, _model("cold_stone", at(c), randf() * TAU))
	var lever := TempleLever.new()
	lever.temple = self
	lever.position = at(Vector2(1.2, 0.5))
	lever.rotation.y = atan2(out.x, out.z)
	add_child(lever)
	_model("monolith", at(Vector2(1.7, -0.5)), atan2(out.x, out.z))   # плита с рисунком «Солнце в чаше»


## Направление жёлоба в локальных осях храма.
func dir_vec(d: int) -> Vector3:
	return [out, side, -out, -side][d % 4]


func solved() -> bool:
	return Game.flags.get("monolith_solved", false)


## Первый жёлоб, который смотрит не туда (или −1, если все верно).
func first_wrong() -> int:
	for i in chutes.size():
		if chutes[i].dir != int(TARGET[i]):
			return i
	return -1


func save_chutes() -> void:
	var d := []
	for c in chutes:
		d.append(c.dir)
	Game.flags["monolith_chutes"] = d


## Рычаг: пустить лаву. Верно — лава бежит в чашу и дверь открывается; нет — застывает у неверного жёлоба.
func pull_lever() -> void:
	if solved():
		Game.notified.emit("Лава течёт в чашу. Дверь открыта", Color("ffd0a0"))
		return
	var k := first_wrong()
	if k >= 0:
		Audio.play("steam", -2.0, 0.1)
		FX.puff(self, chutes[k].position + Vector3(0, 0.6, 0), Color("cfc7d6"), 8, 0.6, 1.6, 1.0)
		Game.notified.emit("Лава застыла у %d-го жёлоба: он смотрит не туда" % (k + 1), Color("ff9d7a"))
		return
	Game.flags["monolith_solved"] = true
	Audio.play("rare", 0.0, 0.0)
	_open(true)
	Game.bump("solved", "monolith")


func _show_flow() -> void:
	if _flow:
		return
	_flow = Node3D.new()
	add_child(_flow)
	var pts: Array[Vector2] = [SOURCE]
	pts.append_array(CHUTES)
	pts.append(BOWL)
	for i in pts.size() - 1:
		_flow.add_child(Lava.mesh_node(Lava.strip_mesh(at(pts[i], 0.12), at(pts[i + 1], 0.12), 0.35)))
	bowl_fire = Models.flame(self, at(BOWL, 0.9), 0.7, 2.0, 8.0)


func _process(_delta: float) -> void:
	if _reached:
		return
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if p == null:
		return
	var lp := to_local(p.global_position)
	if Vector2(lp.x, lp.z).length() < 3.2 and absf(lp.y) < 2.5:
		_reached = true
		Game.bump("reached", "temple_gate")
		Game.notified.emit("Вход в Огненный храм", Color("ffd0a0"))


# ------------------------------------------------------------------ части головоломки
## Каменный жёлоб на поворотном камне: E — повернуть на четверть круга.
class Chute extends StaticBody3D:
	var temple: VolcanoTemple
	var index := 0
	var dir := 0
	var visual: Node3D

	func _ready() -> void:
		add_to_group("interactable")
		collision_layer = 4
		visual = Models.glb("lava_chute")
		if visual == null:
			visual = Node3D.new()
		add_child(visual)
		_face(false)
		var cs := CollisionShape3D.new()
		var c := CylinderShape3D.new()
		c.radius = 0.45
		c.height = 0.8
		cs.shape = c
		cs.position.y = 0.4
		add_child(cs)

	func _face(animate: bool) -> void:
		var v := temple.dir_vec(dir)
		var yaw := atan2(v.x, v.z)
		if animate:
			var tw := create_tween()
			tw.tween_property(visual, "rotation:y", lerp_angle(visual.rotation.y, yaw, 1.0), 0.3).set_trans(Tween.TRANS_BACK)
		else:
			visual.rotation.y = yaw

	func interact_point() -> Vector3:
		return global_position + Vector3(0, 0.5, 0)

	func tool_hint() -> String:
		return ""

	func get_hint() -> String:
		if temple.solved():
			return "Жёлоб %d — по нему течёт лава" % (index + 1)
		return "Жёлоб %d — повернуть" % (index + 1)

	func interact(_player: Node) -> void:
		if temple.solved():
			return
		dir = (dir + 1) % 4
		temple.save_chutes()
		Audio.play("rock", -4.0, 0.1, global_position)
		_face(true)


## Рычаг у чаши: пустить лаву по жёлобам.
class TempleLever extends StaticBody3D:
	var temple: VolcanoTemple

	func _ready() -> void:
		add_to_group("interactable")
		collision_layer = 4
		var m := Models.glb("lever")
		if m:
			add_child(m)
		var cs := CollisionShape3D.new()
		var b := BoxShape3D.new()
		b.size = Vector3(0.4, 1.0, 0.4)
		cs.shape = b
		cs.position.y = 0.5
		add_child(cs)

	func interact_point() -> Vector3:
		return global_position + Vector3(0, 0.7, 0)

	func tool_hint() -> String:
		return ""

	func get_hint() -> String:
		return "Рычаг — пустить лаву по жёлобам" if not temple.solved() else "Рычаг — лава уже течёт"

	func interact(_player: Node) -> void:
		var h := get_node_or_null("lever/Handle") as Node3D
		if h == null:
			h = find_child("Handle", true, false) as Node3D
		if h:
			var tw := create_tween()
			tw.tween_property(h, "rotation:x", 0.8, 0.15)
			tw.tween_property(h, "rotation:x", 0.0, 0.4)
		temple.pull_lever()


## Место под каменный мосток над лавой: колышки с верёвкой. Мосток можно поставить только сюда.
class BridgeSpot extends Node3D:
	var block: CollisionShape3D
	var used := false
	var marker: Node3D

	func _ready() -> void:
		add_to_group("bridge_spot")
		marker = Models.glb("bridge_marker")
		if marker:
			add_child(marker)

	func set_bridged(on: bool) -> void:
		used = on
		if block:
			block.disabled = on
		if marker:
			marker.visible = not on
