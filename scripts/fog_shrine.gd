class_name FogShrine
extends Node3D
## Святилище на скалистом холме Туманного острова: кольцо из шести стоячих камней, гладкая скала-«экран»
## и за ней — Потерянный маяк. Головоломка «Тени на скалах»: у каждого камня — метка под тыквенный фонарь
## (с камешками: 1…6). Если поставить фонари на верные три метки (1, 3, 5), тени камней складываются на скале
## в знак Ока — круг с точкой, и скала расходится. Фонарь у камней можно забрать и переставить.
## Узел стоит в центре кольца; «назад» (back) — к скале и маяку.

const STONES := 6
const RING_R := 3.3
const SPOT_R := 5.2
const RIGHT := [0, 2, 4]   # метки с 1, 3 и 5 камешками

var island: Island
var back := Vector3.BACK
var spots: Array[LanternSpot] = []
var door: Node3D
var _solved_shown := false


func _ready() -> void:
	add_to_group("fog_shrine")
	var side := Vector3(-back.z, 0, back.x)
	var body := StaticBody3D.new()
	body.collision_layer = 4
	add_child(body)
	for i in STONES:
		var a := atan2(back.z, back.x) + PI * 0.5 + i * PI / (STONES - 1)   # полукругом перед скалой
		var dir := Vector3(cos(a), 0, sin(a))
		var sp := dir * RING_R
		sp.y = _ground(sp)
		var st := Models.glb("standing_stone")
		if st:
			st.position = sp
			st.rotation.y = atan2(dir.x, dir.z) + (i % 2) * 0.2
			add_child(st)
		var cs := CollisionShape3D.new()
		var c := CylinderShape3D.new()
		c.radius = 0.45
		c.height = 2.6
		cs.shape = c
		cs.position = sp + Vector3(0, 1.3, 0)
		body.add_child(cs)
		var ls := LanternSpot.new()
		ls.group = "shadow_spot"
		ls.pebbles = i + 1
		var lp := dir * SPOT_R
		lp.y = _ground(lp)
		ls.position = lp
		ls.rotation.y = atan2(dir.x, dir.z)
		add_child(ls)
		spots.append(ls)
	# скала-экран за кругом, с плитой-проходом
	var rp := back * 4.6
	rp.y = _ground(rp)
	var rock := Models.glb("screen_rock")
	if rock:
		rock.position = rp
		rock.rotation.y = atan2(-back.x, -back.z)
		add_child(rock)
		door = rock.find_child("Door", true, false) as Node3D
	var rcs := CollisionShape3D.new()
	var rb := BoxShape3D.new()
	rb.size = Vector3(5.0, 3.6, 1.0)
	rcs.shape = rb
	rcs.position = rp + Vector3(0, 1.8, 0)
	rcs.rotation.y = atan2(-back.x, -back.z)
	body.add_child(rcs)
	var hint := Plaque.new()
	hint.shrine = self
	hint.position = rp - back * 0.8
	add_child(hint)
	# Потерянный маяк — за скалой
	var tp := back * 9.0
	tp.y = _ground(tp)
	var tw := StoryPlace.new()
	tw.id = "fog_tower"
	tw.position = tp
	add_child(tw)
	if island:
		island.poi_extra["fog_tower"] = to_global(tp)
		island.poi_extra["fog_shrine"] = to_global(Vector3(0, _ground(Vector3.ZERO), 0) - back * 6.0)
	if Game.flags.get("shadows_solved", false):
		_open(false)


func _ground(lp: Vector3) -> float:
	var w := global_position + Vector3(lp.x, 0, lp.z)
	return island.height_at(w.x, w.z) - global_position.y


func solved() -> bool:
	return Game.flags.get("shadows_solved", false)


## Верно ли стоят фонари: на трёх нужных метках — свет, на остальных — нет.
func check() -> bool:
	for i in spots.size():
		if spots[i].used != (i in RIGHT):
			return false
	return true


func _open(animate: bool) -> void:
	_solved_shown = true
	if door:
		if animate:
			create_tween().tween_property(door, "position:y", door.position.y - 3.4, 2.5).set_trans(Tween.TRANS_SINE)
		else:
			door.position.y -= 3.4


func _process(_delta: float) -> void:
	if not solved() and check():
		Game.flags["shadows_solved"] = true
		Audio.play("rare", 0.0, 0.0)
		_open(true)
		Game.bump("solved", "shadows")
	elif solved() and not _solved_shown:
		_open(false)


## Резьба на скале: знак Ока и подсказка (что выбито под ним).
class Plaque extends StaticBody3D:
	var shrine: FogShrine

	func _ready() -> void:
		add_to_group("interactable")
		collision_layer = 8

	func interact_point() -> Vector3:
		return global_position + Vector3(0, 1.2, 0)

	func tool_hint() -> String:
		return ""

	func get_hint() -> String:
		return "Скала-экран — проход открыт" if shrine.solved() else "Скала-экран — рассмотреть резьбу"

	func interact(_player: Node) -> void:
		if shrine.solved():
			Game.notified.emit("Тени сложились в знак Ока. Проход к маяку открыт", Color("ffe08a"))
			return
		Game.dialogue_requested.emit([["narrator", "На гладкой скале выбит знак Ока: круг с точкой. Под ним — три маленьких огонька, а под огоньками камешки: один, три и пять."],
			["parrot", "У камней — метки, и у каждой лежат камешки. Румба считает: один, два, три... Ставь свет там, где выбито!"]], Callable())
