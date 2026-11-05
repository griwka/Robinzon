class_name Warmth
extends Node
## Холод на Ледяном острове (до оттепели).
##
## Шкала тепла (Game.warmth, 0..100) тает вдали от огня. Скорость зависит от одежды (Game.cold_mult):
## без тёплого ×3, свитер ×2, пуховая куртка ×1, валенки с рукавицами — ещё ×0,6.
## Полная шкала в куртке держится две минуты. Греют: костёр, печка, палатка, хижина, теплица,
## жаровня у ларца, дверь обсерватории, зажжённый маяк. Кружка чая с мёдом — две минуты без холода.
## Тепло кончилось — никто не умирает: идёшь медленно, не лазаешь, инструменты не держатся в руках.
## Через 30 секунд Румба утаскивает тебя к ближайшему огню (экран темнеет, просыпаешься у костра).

const FULL_TIME := 120.0      # сек — полная шкала в куртке (×1)
const WARM_SPEED := 30.0      # единиц в секунду у огня
const RESCUE_AFTER := 30.0    # сек без тепла — и Румба тащит к огню
const SOURCES := {"campfire": 4.2, "stove": 4.6, "tent": 2.6, "hut": 3.4, "greenhouse": 3.0}

var main: Node
var player: Node3D
var near_fire := false
var _zero_t := 0.0
var _warned := false
var _rescuing := false


func _ready() -> void:
	name = "Warmth"
	add_to_group("warmth")
	Game.warmth = 100.0


func _process(delta: float) -> void:
	if get_tree().paused or player == null:
		return
	tick(delta)
	if main and main.get("hud"):
		main.hud.set_warmth(Game.warmth, Game.cold_active(), _state())


func _state() -> String:
	if near_fire:
		return "у огня"
	if Game.warm_tea > 0.0:
		return "чай греет"
	if Game.warmth <= 0.0:
		return "замёрз!"
	return ""


## Один шаг холода (отдельно — чтобы его можно было вызвать из автотеста).
func tick(delta: float) -> void:
	if not Game.cold_active():
		Game.warmth = 100.0
		near_fire = false
		_zero_t = 0.0
		return
	near_fire = warm_here(player.global_position)
	if near_fire:
		Game.warmth = minf(100.0, Game.warmth + WARM_SPEED * delta)
		_zero_t = 0.0
		_warned = false
	elif Game.warm_tea > 0.0:
		Game.warm_tea = maxf(0.0, Game.warm_tea - delta)
	else:
		Game.warmth = maxf(0.0, Game.warmth - 100.0 / FULL_TIME * Game.cold_mult() * delta)
	if Game.warmth < 30.0 and not _warned and not near_fire:
		_warned = true
		Game.notified.emit("Холодно! Тепло на исходе — к огню!", Color("bfe3ff"))
	if Game.warmth <= 0.0 and not near_fire:
		if _zero_t == 0.0:
			Game.notified.emit("Ты замёрз: ноги не идут, пальцы не гнутся. Скорее к огню!", Color("bfe3ff"))
			Audio.play("wind", -2.0, 0.05)
		_zero_t += delta
		if _zero_t >= RESCUE_AFTER and not _rescuing:
			rescue()


## Тепло ли в точке: у огня, в доме, у тёплых мест.
func warm_here(p: Vector3) -> bool:
	for id in SOURCES:
		for b in get_tree().get_nodes_in_group("station_" + id):
			if (b as Node3D).global_position.distance_to(p) < SOURCES[id]:
				return true
	for w in get_tree().get_nodes_in_group("warm_spot"):
		if (w as Node3D).global_position.distance_to(p) < float(w.get("warm_radius")):
			return true
	return false


## Ближайшее тёплое место (куда Румба утащит замёрзшего героя).
func nearest_fire(p: Vector3) -> Vector3:
	var best := Vector3.INF
	for id in SOURCES:
		for b in get_tree().get_nodes_in_group("station_" + id):
			var q := (b as Node3D).global_position
			if best == Vector3.INF or q.distance_to(p) < best.distance_to(p):
				best = q
	if best == Vector3.INF and main and main.get("island"):
		var isl: Island = main.island
		return isl.spawn_point
	return best


## Румба тащит замёрзшего героя к огню.
func rescue() -> void:
	_rescuing = true
	var p := player as Player
	if p:
		p.controls_enabled = false
	var go := func():
		var fire := nearest_fire(player.global_position)
		var to := fire + Vector3(1.8, 0.4, 1.2)
		if main and main.get("island"):
			to.y = (main.island as Island).height_at(to.x, to.z) + 0.4
		player.global_position = to
		if p:
			p.velocity = Vector3.ZERO
			p.cam_rig.global_position = to + Vector3(0, 1.4, 0)
			p.controls_enabled = true
		Game.warmth = 70.0
		_zero_t = 0.0
		_rescuing = false
		var lines: Array = [["parrot", "Румба тащил тебя за воротник! Румба устал. Грейся и больше так не делай!"]]
		if Game.stat("talk", "ingrid") > 0:
			lines.append(["ingrid", "Девятнадцать минут на морозе. Рекорд глупости. Сядь к огню."])
		Game.dialogue_requested.emit(lines, Callable())
	if main and main.get("hud"):
		main.hud.fade_through(go)
	else:
		go.call()


## Выпить кружку чая (клавиша Q на холоде): шкала полная и две минуты не убывает.
static func drink_tea() -> bool:
	if not Game.cold_active() or Game.sellable("honey_tea") <= 0:
		return false
	Game.pay({"honey_tea": 1})
	Game.warmth = 100.0
	Game.warm_tea = float(Data.ITEMS["honey_tea"].get("warm", 120.0))
	Game.notified.emit("Горячий чай с мёдом! Две минуты холод не страшен", Color("ffe08a"))
	Audio.play("pickup", -3.0)
	return true
