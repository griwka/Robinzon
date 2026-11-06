class_name EyeIsland
extends Node3D
## Сад деда на Оке шторма: одичавшие яблони, заросшие грядки, скамейка, которую чинили много раз,
## домик с насестом для попугая и коробка писем на крыльце. Вокруг — кольцо зарослей (Island.RINGS).
## Здесь же — команда на берегу у «Альбатроса» и праздничный стол (по желанию, обед у Марты).
## Узел стоит в центре сада; front — направление на лагерь (домик смотрит туда).

var island: Island
var front := Vector3.BACK


func _ready() -> void:
	add_to_group("eye_garden")
	var side := Vector3(-front.z, 0, front.x)
	var yaw := atan2(front.x, front.z)
	# домик деда и коробка писем на крыльце
	var house := StoryPlace.new()
	house.id = "grandfather_house"
	house.position = _ground(-front * 2.4)
	house.rotation.y = yaw
	add_child(house)
	var letters := StoryPlace.new()
	letters.id = "grandfather_letters"
	letters.position = _ground(-front * 0.2 + side * 1.3)
	letters.rotation.y = yaw
	add_child(letters)
	_decor("perch", -front * 0.6 - side * 2.0, yaw + 0.3, 0.0)
	# яблони, скамейка, заросшие грядки
	for spec in [[Vector2(-3.6, 1.6), 0.0], [Vector2(3.8, 0.4), 1.7], [Vector2(-2.4, 4.4), 3.1], [Vector2(3.0, 4.0), 4.4]]:
		var v: Vector2 = spec[0]
		_decor("apple_tree", side * v.x + front * v.y, float(spec[1]), 0.35)
	_decor("grandpa_bench", side * 1.2 + front * 3.4, yaw + PI, 0.0)
	for k in 3:
		_decor("wild_bed", side * (-2.2 + k * 2.0) + front * 1.6, yaw + PI * 0.5, 0.0)
	island.poi_extra["grandfather_house"] = to_global(front * 1.0)


func _ground(local: Vector3) -> Vector3:
	var g := to_global(local)
	return Vector3(local.x, island.height_at(g.x, g.z) - global_position.y, local.z)


func _decor(model: String, local: Vector3, yaw: float, trunk_r: float) -> void:
	var m := Models.glb(model)
	if m == null:
		return
	m.position = _ground(local)
	m.rotation.y = yaw
	add_child(m)
	if trunk_r > 0.0:
		var body := StaticBody3D.new()
		body.collision_layer = 2
		var cs := CollisionShape3D.new()
		var c := CylinderShape3D.new()
		c.radius = trunk_r
		c.height = 3.0
		cs.shape = c
		cs.position.y = 1.5
		body.add_child(cs)
		m.add_child(body)


# ================================================================== берег
const CREW := ["marta", "stepa", "ingrid", "vera", "renata", "misha", "gosha", "petya", "pasha"]


## Команда на берегу у лагеря и «Альбатрос» на якоре (пока финал не выбран).
static func spawn_shore(main: Node3D, isl: Island) -> void:
	var to_sea := isl.wreck_point - isl.camp_center
	to_sea.y = 0.0
	to_sea = to_sea.normalized()
	var side := Vector3(-to_sea.z, 0, to_sea.x)
	var ship := Node3D.new()
	ship.name = "AlbatrosAnchored"
	ship.position = Vector3(isl.wreck_point.x, 0.0, isl.wreck_point.z) + to_sea * 16.0 + side * 6.0
	ship.rotation.y = atan2(side.x, side.z)
	main.add_child(ship)
	for part in ["albatros", "albatros_mast", "albatros_helm", "albatros_lights"]:
		var m := Models.glb(part)
		if m:
			ship.add_child(m)
	if Game.ended():
		ship.visible = false   # «Альбатрос» ушёл домой
		return
	var c := isl.camp_center + to_sea * 1.5
	for i in CREW.size():
		var a := -1.2 + 2.4 * i / float(CREW.size() - 1)
		var p := c + (side * sin(a) - to_sea * cos(a)) * 4.6
		p.y = isl.height_at(p.x, p.z)
		var n := NPCPerson.new()
		n.npc_id = CREW[i]
		n.position = p
		n.rotation.y = atan2(p.x - c.x, p.z - c.z)   # лицом к костру (жители смотрят в −Z)
		main.add_child(n)
		isl.poi_extra[CREW[i]] = p


## Праздничный стол перед выбором (по желанию: обед из лавки Марты, 60 монет).
static func feast() -> void:
	if not Game.pay({"feast": 1}):
		return
	Game.flags["feast_done"] = true
	Audio.play("cheer", -2.0, 0.0)
	Game.dialogue_requested.emit([
		["narrator", "Марта расстилает на чёрных камнях скатерть. Пирог, похлёбка, варенье, жареная рыба семью способами."],
		["marta", "Ешьте. Кто пересолит — выйдет. Это я про всех."],
		["stepa", "За тех, кто держал огонь. И за тех, кто его искал."],
		["ingrid", "До заката сорок минут. Я не считаю. ...Ладно, считаю."],
		["vera", "Миша, это третья тарелка. Ешь, ешь. Это я как врач."],
		["misha", "Четвёртая!"],
		["renata", "Два года мы ели стоя. Сегодня — сидя. Все вместе."],
		["gosha", "...Вкусно."],
		["petya", "Паша, передай..."],
		["pasha", "...соль. Держи."],
		["timur", "(в рации) Я СЛЫШУ, КАК ВЫ ЖУЁТЕ! Оставьте мне кусочек!"],
		["parrot", "Румба взял рыбу. Румба не брал рыбу. Это была другая рыба."],
	], Callable())
