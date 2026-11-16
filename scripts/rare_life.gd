class_name RareLife
extends Node3D
## Редкие существа — коллекция «Редкие встречи». У каждого своё условие, о каждом ходит слух (RUMORS):
##  - белая бабочка (snow_moth)  — днём, пока идёт дождь и пару минут после; ловится сачком; на любом тёплом острове;
##  - лунная рыба (moon_fish)    — на удочку ночью в полнолуние (не в лунке);
##  - светящийся краб (glow_crab) — ночью на берегу Туманного острова; подойти шагом и рассмотреть (бегом — зароется);
##  - золотой жук (gold_beetle)   — в полдень на клумбе или цветах в лагере острова крушения; ловится сачком;
##  - морская черепаха (sea_turtle) — на рассвете на берегу острова крушения; подойти шагом (бегом — уйдёт в море).
## Не встретил сегодня — встретишь в другой раз: условия повторяются. После встречи существа приходят и дальше.

const COL := "rare_life"
const FULL_MOON := 0.07          # насколько фаза может отличаться от полнолуния (0.5)
const MOON_FISH_CHANCE := 0.35
const RAIN_AFTER := 150.0        # сек после дождя, пока летает белая бабочка
const FLOWERS := ["flowerbed", "flower_tub", "flower_barrow", "flower_arch"]
## Слухи: что говорят жители (гости у костра), пока существо не встречено.
const RUMORS := {
	"snow_moth": ["marta", "После дождя над травой летает бабочка, белая как соль. Я видела, честное слово. Сачок у тебя есть?"],
	"moon_fish": ["stepa", "В полнолуние ночью клюёт рыба, которая светится. Я за жизнь поймал одну. И ту отпустил."],
	"glow_crab": ["renata", "На Туманном по ночам у воды ходит краб со светом на спине. Подойдёшь бегом — зароется. Я проверяла."],
	"gold_beetle": ["vera", "В полдень на цветах иногда сидит жук, золотой, как монета. Любит клумбы. У тебя ведь есть клумбы?"],
	"sea_turtle": ["misha", "А на рассвете на наш берег выходит черепаха! Огромная! Только не беги к ней, она стесняется."],
}

var island: Island
var main: Node
var moth: Moth
var crab: Shy
var turtle: Shy
var beetle: Beetle
var _rain_until := -1.0


func _ready() -> void:
	add_to_group("rare_life")
	if island == null:
		return
	if Game.location != "eye":
		moth = Moth.new()
		moth.island = island
		add_child(moth)
	if Game.location == "fog":
		crab = Shy.new()
		crab.setup("glow_crab", island, _shore_spot(0.7, 0.35, 0.75))
		add_child(crab)
	if Game.location == "home":
		turtle = Shy.new()
		turtle.setup("sea_turtle", island, _shore_spot(2.1, 0.3, 0.7))
		add_child(turtle)
		beetle = Beetle.new()
		add_child(beetle)


## Точка на берегу: от середины острова под углом a идём к воде и встаём на песок высотой lo..hi.
func _shore_spot(a: float, lo: float, hi: float) -> Vector3:
	for k in 24:
		var ang := a + k * 0.26
		var dir := Vector3(cos(ang), 0, sin(ang))
		var r := island.radius * 0.35
		while r < island.radius * 1.6 and island.height_at(dir.x * r, dir.z * r) > hi:
			r += 0.4
		var p := dir * r
		var h := island.height_at(p.x, p.z)
		if h >= lo and h <= hi:
			return Vector3(p.x, h, p.z)
	return Vector3(island.wreck_point.x, 0.5, island.wreck_point.z)


static func met(id: String) -> bool:
	return WorldLife.has(COL, id)


static func meet(id: String) -> bool:
	Game.bump("rare", id)
	return WorldLife.collect(COL, id)


static func moon_phase() -> float:
	return fposmod(WorldEnv.MOON_START + (float(Game.day - 1) + Game.time_of_day) / WorldEnv.MOON_CYCLE, 1.0)


static func full_moon() -> bool:
	return absf(moon_phase() - 0.5) <= FULL_MOON


## Рыбалка (зовёт FishingSpot.catch): ночью в полнолуние иногда попадается лунная рыба.
static func on_catch(ice: bool, roll := -1.0) -> bool:
	if ice or Game.is_day() or not full_moon():
		return false
	if (roll if roll >= 0.0 else randf()) >= MOON_FISH_CHANCE:
		return false
	meet("moon_fish")
	return true


## Слух от жителя: [кто, реплика] про ещё не встреченное существо или пусто.
static func rumor(speaker: String) -> Array:
	for id in RUMORS:
		if RUMORS[id][0] == speaker and not met(id):
			return RUMORS[id]
	return []


func rain_now() -> float:
	var w = main.get("weather") if main else null
	return float(w.get("rain")) if w != null else 0.0


## Летает ли сейчас белая бабочка.
func moth_time() -> bool:
	return Game.is_day() and not Game.cold_active() and Game.world_time < _rain_until


static func beetle_time() -> bool:
	return Game.time_of_day > 0.44 and Game.time_of_day < 0.60


static func turtle_time() -> bool:
	return Game.time_of_day > 0.235 and Game.time_of_day < 0.34


static func crab_time() -> bool:
	return not Game.is_day()


func _process(_delta: float) -> void:
	if rain_now() > 0.3:
		_rain_until = Game.world_time + RAIN_AFTER
	if moth:
		moth.set_shown(moth_time())
	if crab:
		crab.set_shown(crab_time())
	if turtle:
		turtle.set_shown(turtle_time())
	if beetle:
		beetle.update(beetle_time())


## Белая бабочка: порхает над поляной, ловится сачком.
class Moth extends Node3D:
	var island: Island
	var anchor := Vector3.ZERO
	var model: Node3D
	var shown := false
	var _t := 0.0

	func _ready() -> void:
		model = Models.butterfly(Color("fbfbf4"))
		add_child(model)
		visible = false
		_t = randf() * 50.0
		_move()

	func _move() -> void:
		var pl := get_tree().get_first_node_in_group("player") as Node3D
		var c := pl.global_position if pl else island.camp_center
		for i in 40:
			var x := c.x + randf_range(-16, 16)
			var z := c.z + randf_range(-16, 16)
			var h := island.height_at(x, z)
			if h > 1.0 and h < 8.0:
				anchor = Vector3(x, h, z)
				return
		anchor = island.camp_center

	func set_shown(v: bool) -> void:
		if v == shown:
			return
		shown = v
		visible = v
		if v:
			_move()
			add_to_group("interactable")
		else:
			remove_from_group("interactable")

	func _process(delta: float) -> void:
		if not shown:
			return
		_t += delta
		var prev := position
		position = anchor + Vector3(sin(_t * 0.6) * 2.2, 1.2 + sin(_t * 1.7) * 0.45, cos(_t * 0.45) * 2.2)
		var v := position - prev
		if v.length() > 0.0001:
			model.rotation.y = atan2(-v.x, -v.z)
		var flap := sin(_t * 20.0) * 0.9
		model.get_node("WingL").rotation.z = flap
		model.get_node("WingR").rotation.z = -flap

	func interact_point() -> Vector3:
		return global_position - Vector3(0, 0.6, 0)

	func tool_hint() -> String:
		return "net"

	func get_hint() -> String:
		return "Белая бабочка — поймать" if Game.has_tool("net") else "Белая бабочка (нужен сачок)"

	func interact(_player: Node) -> void:
		if not Game.has_tool("net"):
			Game.notified.emit("Нужен сачок — его делают на верстаке", Color("ff9d7a"))
			return
		FX.burst(get_parent(), position, Color("ffffff"), 10)
		Audio.play("rustle", -6.0, 0.2)
		RareLife.meet("snow_moth")
		Game.notified.emit("Ты рассмотрел её и отпустил. Она улетела к деревьям", Color("e8dcc0"))
		_move()


## Пугливое существо на берегу (светящийся краб, морская черепаха): подойти можно только шагом.
class Shy extends StaticBody3D:
	var id := ""
	var island: Island
	var home := Vector3.ZERO
	var model: Node3D
	var shown := false
	var hidden_until := 0.0      # спугнули — прячется до этого времени
	var _t := 0.0
	var _light: OmniLight3D

	func setup(creature: String, isl: Island, at: Vector3) -> void:
		id = creature
		island = isl
		home = at

	func _ready() -> void:
		collision_layer = 8
		position = home
		model = Models.glb(id)
		if model:
			add_child(model)
		var cs := CollisionShape3D.new()
		var s := SphereShape3D.new()
		s.radius = 0.45 if id == "sea_turtle" else 0.3
		cs.shape = s
		cs.position.y = 0.25
		add_child(cs)
		if id == "glow_crab":
			_light = OmniLight3D.new()
			_light.light_color = Color("8affd0")
			_light.light_energy = 1.4
			_light.omni_range = 3.5
			_light.position.y = 0.35
			add_child(_light)
		visible = false

	func set_shown(v: bool) -> void:
		v = v and Game.world_time >= hidden_until
		if v == shown:
			return
		shown = v
		visible = v
		if v:
			position = home
			add_to_group("interactable")
		else:
			remove_from_group("interactable")

	## Спугнули: существо прячется (краб — на минуту, черепаха — до следующего утра).
	func scare() -> void:
		hidden_until = Game.world_time + (60.0 if id == "glow_crab" else 400.0)
		FX.dust(get_parent(), global_position + Vector3(0, 0.1, 0), Color("eadcb8"), 8, 0.4)
		if id == "sea_turtle":
			FX.splash(get_parent(), Vector3(global_position.x, 0.0, global_position.z))
		Game.notified.emit("Светящийся краб зарылся в песок. К нему — только шагом" if id == "glow_crab"
			else "Черепаха ушла в воду. Она не любит, когда к ней бегут", Color("e8dcc0"))
		set_shown(false)

	func _process(delta: float) -> void:
		if not shown:
			return
		_t += delta
		# бродит туда-сюда вдоль кромки воды
		var k := sin(_t * (0.5 if id == "glow_crab" else 0.18))
		var side := Vector3(-home.z, 0, home.x).normalized()
		position = home + side * k * (1.6 if id == "glow_crab" else 1.0)
		position.y = island.height_at(position.x, position.z)
		rotation.y = atan2(side.x, side.z) + (0.0 if cos(_t * (0.5 if id == "glow_crab" else 0.18)) > 0.0 else PI)
		if _light:
			_light.light_energy = 1.2 + sin(_t * 2.3) * 0.4
		var pl := get_tree().get_first_node_in_group("player") as CharacterBody3D
		if pl and pl.global_position.distance_to(global_position) < 8.0:
			if Vector2(pl.velocity.x, pl.velocity.z).length() > Player.WALK_SPEED + 0.6:
				scare()

	func interact_point() -> Vector3:
		return global_position + Vector3(0, 0.3, 0)

	func tool_hint() -> String:
		return ""

	func get_hint() -> String:
		return "Светящийся краб — рассмотреть" if id == "glow_crab" else "Морская черепаха — посмотреть"

	func interact(_player: Node) -> void:
		RareLife.meet(id)
		Game.notified.emit("Краб замер и светится ровно, будто позирует" if id == "glow_crab"
			else "Черепаха смотрит на тебя, моргает и не торопясь идёт дальше", Color("e8dcc0"))


## Золотой жук: в полдень сидит на одной из клумб лагеря. Нет клумб — негде сидеть.
class Beetle extends StaticBody3D:
	var model: Node3D
	var shown := false
	var host: Node3D
	var _t := 0.0

	func _ready() -> void:
		collision_layer = 8
		model = Models.glb("gold_beetle")
		if model:
			add_child(model)
		var cs := CollisionShape3D.new()
		var s := SphereShape3D.new()
		s.radius = 0.3
		cs.shape = s
		add_child(cs)
		visible = false

	func find_flowers() -> Node3D:
		var best: Node3D = null
		for b in get_tree().get_nodes_in_group("building"):
			if str(b.get("id")) in RareLife.FLOWERS and not (b as Node).is_queued_for_deletion():
				best = b as Node3D
		return best

	func update(time_ok: bool) -> void:
		var want := time_ok
		if want and (host == null or not is_instance_valid(host) or host.is_queued_for_deletion()):
			host = find_flowers()
		want = want and host != null and is_instance_valid(host)
		if want:
			global_position = host.global_position + Vector3(0.12, 0.62 if str(host.get("id")) != "flowerbed" else 0.42, 0.1)
		if want == shown:
			return
		shown = want
		visible = want
		if want:
			add_to_group("interactable")
		else:
			remove_from_group("interactable")

	func _process(delta: float) -> void:
		_t += delta
		if shown and model:
			model.rotation.y = sin(_t * 0.7) * 0.8

	func interact_point() -> Vector3:
		return global_position

	func tool_hint() -> String:
		return "net"

	func get_hint() -> String:
		return "Золотой жук — поймать" if Game.has_tool("net") else "Золотой жук (нужен сачок)"

	func interact(_player: Node) -> void:
		if not Game.has_tool("net"):
			Game.notified.emit("Нужен сачок — его делают на верстаке", Color("ff9d7a"))
			return
		Audio.play("rustle", -6.0, 0.2)
		RareLife.meet("gold_beetle")
		Game.notified.emit("Жук посидел на ладони, блеснул и вернулся на цветок", Color("e8dcc0"))
