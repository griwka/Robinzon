class_name StormStation
extends Node3D
## Метеостанция на вершине Грозового острова и бункер под ней.
##
## Наверху: домик с мачтой антенны и флюгером, радист Тимур и люк в бункер.
## Бункер — древняя каменная шахта Хранителей в 7 ярусов глубоко под островом (y ≈ −16…−43).
## Ярусы чередуются: нечётные — у северной стены, чётные — у южной, каждый на 4,5 м ниже предыдущего.
## Вниз — спрыгнуть с края в проёме перил, вверх — по железной лестнице.
## - ярус 1: генератор (сюжетное место); пока он не починен, проём вниз перегорожен цепью — там темно;
## - ярусы 1–3 освещают лампы, когда генератор работает;
## - ниже третьего — только фонарь: без него проём на 3-м ярусе закрыт;
## - ярус 6 — стол метеорологов с журналом, ярус 7 — радиорубка.
## Узел стоит в точке (x, 0, z) станции, так что локальная высота = мировая.

const TOP_Y := -16.0       # пол первого яруса
const STEP := 4.5          # между ярусами
const DECKS := 7
const HALF := 6.0          # шахта 12 × 12 м
const EDGE := 0.5          # ярусы заходят за середину шахты на 0,5 м
const ROOF := 4.0          # потолок над первым ярусом

var site := Vector3.ZERO   # мировая точка станции на вершине
var _reached := {}
var _lamps: Array[OmniLight3D] = []
var _gates := {}           # номер яруса -> CollisionShape3D цепи в проёме
var _gate_visuals := {}
var _body: StaticBody3D


func _ready() -> void:
	add_to_group("obstacle")
	add_to_group("bunker")
	_body = StaticBody3D.new()
	_body.collision_layer = 1   # стены шахты держат и героя, и камеру
	add_child(_body)
	_build_surface()
	_build_shaft()
	_update_gates()


func block_radius() -> float:
	return 5.5


# ------------------------------------------------------------------ наверху
func _build_surface() -> void:
	var s := Vector3(0, site.y, 0)
	var house := Models.glb("met_station")
	if house:
		house.position = s
		add_child(house)
		var hb := StaticBody3D.new()
		hb.collision_layer = 4
		var cs := CollisionShape3D.new()
		var b := BoxShape3D.new()
		b.size = Vector3(3.2, 2.8, 2.6)
		cs.shape = b
		cs.position = Vector3(0, 1.4, 0)
		hb.add_child(cs)
		house.add_child(hb)
		Models.add_trimesh(hb, house)   # мачта антенны на крыше, будка с градусниками, шкаф — тоже твёрдые
	# люк в бункер — в паре шагов от домика
	var hatch := Hatch.new()
	hatch.station = self
	hatch.down = true
	hatch.position = s + Vector3(3.6, 0.0, 1.6)
	add_child(hatch)
	# радист Тимур у двери станции
	var t := NPCPerson.new()
	t.npc_id = "timur"
	t.position = s + Vector3(-1.2, 0.0, 2.4)
	t.rotation.y = PI
	add_child(t)


func surface_exit() -> Vector3:
	return to_global(Vector3(0, site.y, 0) + Vector3(3.6, 0.4, 3.2))


# ------------------------------------------------------------------ шахта
func deck_y(k: int) -> float:
	return TOP_Y - (k - 1) * STEP


## Центр яруса k (1..7) в локальных координатах.
func deck_center(k: int) -> Vector3:
	if k == DECKS:
		return Vector3(0, deck_y(k), 0)
	var north := k % 2 == 1
	return Vector3(0, deck_y(k), (-HALF + EDGE) * 0.5 if north else (HALF - EDGE) * 0.5)


## Для автотеста и dev_tools: мировая точка яруса по id «bunkerN».
func deck_point(target: String) -> Vector3:
	var k := int(target.substr(6))
	return to_global(deck_center(k) + Vector3(1.5, 0.3, 0))


func _box(size: Vector3, center: Vector3) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	cs.shape = b
	cs.position = center
	_body.add_child(cs)
	return cs


func _model(name_: String, pos: Vector3, yaw := 0.0, scale_ := Vector3.ONE) -> Node3D:
	var m := Models.glb(name_)
	if m == null:
		return null
	m.position = pos
	m.rotation.y = yaw
	m.scale = scale_
	add_child(m)
	return m


func _build_shaft() -> void:
	var bottom := deck_y(DECKS) - 0.6
	var top := TOP_Y + ROOF
	var h := top - bottom
	# стены и потолок
	for side in 4:
		var yaw := side * PI / 2.0
		var n := Vector3(sin(yaw), 0, cos(yaw))
		_box(Vector3(12.8 if side % 2 == 0 else 0.6, h, 0.6 if side % 2 == 0 else 12.8), n * (HALF + 0.3) + Vector3(0, bottom + h * 0.5, 0))
		# куски стены по 4,5 м чуть растянуты по высоте, чтобы дойти до потолка и зайти в него на 10 см
		# (иначе под потолком оставалась щель: 7 кусков — 31,5 м на шахту 31,6 м)
		var levels := int(floor(h / STEP + 0.05))
		var ws := (h + 0.1) / (levels * STEP)
		for i in levels:
			_model("bunker_wall", n * HALF + Vector3(0, bottom + i * STEP * ws, 0), yaw + PI, Vector3(1, ws, 1))
	_box(Vector3(12.8, 0.6, 12.8), Vector3(0, top + 0.3, 0))
	_model("bunker_ceiling", Vector3(0, top, 0))
	for k in range(1, DECKS + 1):
		_build_deck(k)
	# лестницы: с яруса k+1 вверх на ярус k
	for k in range(1, DECKS):
		var north := k % 2 == 1
		var x := 3.6 if k % 2 == 1 else -3.6
		var z_bottom := (EDGE + 0.45) if north else -(EDGE + 0.45)
		var z_exit := -0.6 if north else 0.6
		var cl := Climbable.new()
		cl.ladder = true
		cl.ladder_yaw = 0.0 if north else PI
		cl.bottom = Vector3(x, deck_y(k + 1), z_bottom)
		cl.top = Vector3(x, deck_y(k) + 1.1, z_bottom)
		cl.exit = Vector3(x, deck_y(k), z_exit)
		add_child(cl)
	# выход наверх с первого яруса
	var up := Hatch.new()
	up.station = self
	up.down = false
	up.position = Vector3(-4.6, deck_y(1), -4.6)
	add_child(up)
	_model("ladder", Vector3(-4.6, deck_y(1), -5.4), 0.0, Vector3(1, 3.6, 1))
	# сюжетные места
	var gen := StoryPlace.new()
	gen.id = "generator"
	gen.position = Vector3(-2.0, deck_y(1), -4.4)
	add_child(gen)
	var desk := StoryPlace.new()
	desk.id = "station_logs"
	desk.position = Vector3(-2.2, deck_y(6), 4.2)
	desk.rotation.y = PI
	add_child(desk)
	var radio := StoryPlace.new()
	radio.id = "radio"
	radio.position = Vector3(0.0, deck_y(7), -4.8)
	add_child(radio)
	var rec := StoryPlace.new()
	rec.id = "radio_record"
	rec.position = Vector3(1.4, deck_y(7) + 0.3, -4.0)
	add_child(rec)


func _build_deck(k: int) -> void:
	var y := deck_y(k)
	var north := k % 2 == 1
	var full := k == DECKS
	var z0 := -HALF if (north or full) else -EDGE
	var z1 := HALF if (not north or full) else EDGE
	var depth := z1 - z0
	var cz := (z0 + z1) * 0.5
	_box(Vector3(12.0, 0.4, depth), Vector3(0, y - 0.2, cz))
	_model("bunker_deck", Vector3(0, y, cz), 0.0, Vector3(1, 1, depth / 6.5))
	if full:
		pass
	else:
		# перила по краю, с проёмом рядом с верхом лестницы (там спрыгивают вниз)
		var edge_z := z1 if north else z0
		var gap_x := 1.6 if k % 2 == 1 else -1.6
		var segs := [[-HALF, gap_x - 0.8], [gap_x + 0.8, HALF]]
		for sg in segs:
			var a: float = sg[0]
			var b: float = sg[1]
			if b - a < 0.2:
				continue
			_box(Vector3(b - a, 1.2, 0.15), Vector3((a + b) * 0.5, y + 0.6, edge_z))
			var n := int(round(b - a))
			for i in n:
				_model("bunker_rail", Vector3(a + 0.5 + i * (b - a) / n, y, edge_z), 0.0 if north else PI, Vector3((b - a) / n, 1, 1))
		# у ярусов 1 и 3 проём закрыт цепью, пока внизу нечем светить
		if k in [1, 3]:
			_gates[k] = _box(Vector3(1.6, 1.4, 0.3), Vector3(gap_x, y + 0.7, edge_z))
			_gate_visuals[k] = _model("bunker_chain", Vector3(gap_x, y, edge_z), 0.0 if north else PI)
			var sign := DarkGate.new()
			sign.station = self
			sign.deck = k
			sign.position = Vector3(gap_x, y + 0.2, edge_z + (-0.6 if north else 0.6))
			add_child(sign)
	# лампы ярусов 1–3 (горят от генератора)
	if k <= 3:
		var lamp_pos := Vector3(0.0, y + 3.0, cz)
		_model("bunker_lamp", lamp_pos)
		var l := OmniLight3D.new()
		l.position = lamp_pos + Vector3(0, -0.3, 0)
		l.light_color = Color("ffd9a0")
		l.light_energy = 2.2
		l.omni_range = 10.0
		l.shadow_enabled = false
		add_child(l)
		_lamps.append(l)
	# обстановка
	var props := {2: [["bunker_shelves", Vector3(-4.0, 0, 4.8), PI], ["bunker_crates", Vector3(3.8, 0, 4.2), 0.4]],
		3: [["bunker_crates", Vector3(-4.2, 0, -4.4), 0.2], ["bunker_shelves", Vector3(2.0, 0, -5.2), 0.0]],
		4: [["bunker_crates", Vector3(4.0, 0, 4.4), 1.2]],
		5: [["bunker_shelves", Vector3(-3.0, 0, -5.2), 0.0], ["bunker_crates", Vector3(4.2, 0, -4.0), 2.0]],
		6: [["bunker_shelves", Vector3(2.4, 0, 5.2), PI]],
		1: [["bunker_crates", Vector3(4.2, 0, -4.6), 0.3]]}
	for pr in props.get(k, []):
		var m := _model(pr[0], (pr[1] as Vector3) + Vector3(0, y, 0), pr[2])
		Models.add_trimesh(_body, m)   # в полки и ящики не входят


func light_ok(k: int) -> bool:
	if k == 1:
		return Game.flags.get("restored_generator", false) or Game.has_light()
	return Game.has_light()


func _update_gates() -> void:
	for k in _gates:
		var open := light_ok(k)
		(_gates[k] as CollisionShape3D).disabled = open
		if _gate_visuals.get(k):
			(_gate_visuals[k] as Node3D).visible = not open
	var lit: bool = Game.flags.get("restored_generator", false)
	for l in _lamps:
		l.visible = lit


func _process(_delta: float) -> void:
	_update_gates()
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if p == null or p.global_position.y > TOP_Y + 3.0:
		return
	var lp := to_local(p.global_position)
	for k in range(1, DECKS + 1):
		var id := "bunker%d" % k
		if _reached.has(id):
			continue
		if abs(lp.y - deck_y(k)) < 1.3 and abs(lp.x) < HALF and abs(lp.z - deck_center(k).z) < 3.6:
			_reached[id] = true
			Game.bump("reached", id)
			Game.notified.emit("Ярус бункера %d" % k, Color("bfe3ff"))


func teleport(down: bool) -> void:
	var p := get_tree().get_first_node_in_group("player") as Player
	if p == null:
		return
	Audio.play("open", -2.0, 0.05)
	var to := to_global(Vector3(-3.4, deck_y(1) + 0.4, -3.6)) if down else surface_exit()
	p.global_position = to
	p.velocity = Vector3.ZERO
	p.cam_rig.global_position = to + Vector3(0, 1.4, 0)
	p.camera_yaw = PI if down else 0.0
	if down and not Game.flags.get("restored_generator", false) and not Game.has_light():
		Game.notified.emit("Темно. Только у люка виден генератор метеорологов", Color("ffe08a"))


# ------------------------------------------------------------------ люк
class Hatch extends StaticBody3D:
	var station: StormStation
	var down := true

	func _ready() -> void:
		add_to_group("interactable")
		collision_layer = 4
		var m := Models.glb("bunker_hatch" if down else "bunker_hatch_inner")
		if m:
			add_child(m)
		var cs := CollisionShape3D.new()
		var b := BoxShape3D.new()
		b.size = Vector3(1.4, 0.4, 1.4)
		cs.shape = b
		cs.position.y = 0.2
		add_child(cs)

	func interact_point() -> Vector3:
		return global_position + Vector3(0, 0.5, 0)

	func tool_hint() -> String:
		return ""

	func get_hint() -> String:
		return "Спуститься в бункер" if down else "Подняться наверх, к станции"

	func interact(_player: Node) -> void:
		station.teleport(down)


# ------------------------------------------------------------------ табличка у закрытого проёма
class DarkGate extends Node3D:
	var station: StormStation
	var deck := 1

	func _ready() -> void:
		add_to_group("interactable")

	func interact_point() -> Vector3:
		return global_position + Vector3(0, 0.6, 0)

	func tool_hint() -> String:
		return ""

	func get_hint() -> String:
		if station.light_ok(deck):
			return "Проём вниз — спрыгни на ярус ниже"
		if deck == 1:
			return "Внизу темно, хоть глаз выколи. Почини генератор или " + ("включи фонарь (5)" if Game.gear_owned("light") else "сделай фонарь")
		return "Ниже света нет совсем. " + ("Включи фонарь (5)" if Game.gear_owned("light") else "Без фонаря не спуститься")

	func interact(_player: Node) -> void:
		Game.notified.emit(get_hint(), Color("ffe08a"))
