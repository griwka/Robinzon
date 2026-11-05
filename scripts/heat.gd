class_name Heat
extends Node
## Жар на Острове Вулкана — зеркало холода с Ледяного острова.
##
## Шкала жара (Game.heat, 0..100) растёт у лавы: чем ближе, тем быстрее. Огнеупорные рукавицы — вдвое медленнее,
## мазь от ожогов (Q) — ещё медленнее целую минуту. На стене кратера тоже жарко (там лезут — силы и жар сразу).
## Вдали от лавы жар спадает сам, у горячих источников — сразу.
## Полная шкала — никто не обжигается: жар отбрасывает героя назад, от лавы (а со стены — сбрасывает вниз).

const RATE := 40.0            # в секунду у самой лавы
const COOL := 22.0            # в секунду вдали от лавы
const WALL_HEAT := 0.25       # «лава рядом» на стене кратера
const SALVE_K := 0.35

var main: Node
var player: Node3D
var near_lava := 0.0
var _push_cd := 0.0
var _warned := false


func _ready() -> void:
	name = "Heat"
	add_to_group("heat")
	Game.heat = 0.0


func _process(delta: float) -> void:
	if get_tree().paused or player == null:
		return
	tick(delta)
	if main and main.get("hud"):
		main.hud.set_heat(Game.heat, Game.location == "volcano" and (Game.heat > 0.5 or near_lava > 0.0), _state())


func _state() -> String:
	if Game.salve_t > 0.0:
		return "мазь"
	if Game.heat >= 99.0:
		return "горячо!"
	return ""


## Сила жара в точке (0..1): самый горячий из источников.
func heat_here(p: Vector3) -> float:
	var h := 0.0
	for s in get_tree().get_nodes_in_group("lava"):
		h = maxf(h, float(s.heat_at(p)))
	return h


func _cool_here(p: Vector3) -> bool:
	for c in get_tree().get_nodes_in_group("cool_spot"):
		if c.cool_at(p):
			return true
	return false


func mult() -> float:
	var m := 1.0
	if Game.has_tool("fire_gloves"):
		m *= 0.5
	if Game.salve_t > 0.0:
		m *= SALVE_K
	return m


func tick(delta: float) -> void:
	_push_cd -= delta
	Game.salve_t = maxf(0.0, Game.salve_t - delta)
	var p := player.global_position
	near_lava = heat_here(p)
	var pl := player as Player
	if pl and pl.climbing and pl.climbing.hot:
		near_lava = maxf(near_lava, WALL_HEAT)
	if near_lava > 0.0:
		Game.heat = minf(100.0, Game.heat + RATE * near_lava * mult() * delta)
	elif _cool_here(p):
		Game.heat = maxf(0.0, Game.heat - 80.0 * delta)
	else:
		Game.heat = maxf(0.0, Game.heat - COOL * delta)
	if Game.heat > 70.0 and not _warned:
		_warned = true
		Game.notified.emit("Жжёт! Отойди от лавы" + (" или намажься мазью (Q)" if Game.count("burn_salve") > 0 else ""), Color("ffb070"))
	if Game.heat < 40.0:
		_warned = false
	if Game.heat >= 100.0 and _push_cd <= 0.0:
		push_back()


## Жар отбрасывает героя от ближайшей лавы (со стены — вниз). Без вреда.
func push_back() -> void:
	_push_cd = 1.2
	var p := player.global_position
	var best: Node = null
	var bh := 0.0
	for s in get_tree().get_nodes_in_group("lava"):
		var h := float(s.heat_at(p))
		if h > bh:
			bh = h
			best = s
	var pl := player as Player
	var dir := Vector3.ZERO
	if best:
		dir = best.push_dir(p)
	if pl and pl.climbing:
		dir = (pl._climb_side as Vector3)
		pl._stop_climb(dir * 2.5)
	elif pl:
		pl.velocity = dir * 8.0 + Vector3(0, 3.5, 0)
		pl.add_trauma(0.3)
	Game.heat = 80.0
	Audio.play("steam", -2.0, 0.1)
	Game.notified.emit("Слишком горячо! Жар отбросил тебя назад", Color("ff9d7a"))


## Намазаться мазью от ожогов (Q на Вулкане, когда жарко): жар спадает и минуту растёт втрое медленнее.
static func use_salve() -> bool:
	if Game.location != "volcano" or Game.sellable("burn_salve") <= 0:
		return false
	Game.pay({"burn_salve": 1})
	Game.salve_t = float(Data.ITEMS["burn_salve"].get("cool", 60.0))
	Game.heat = maxf(0.0, Game.heat - 40.0)
	Game.notified.emit("Мазь от ожогов: минуту жар почти не страшен", Color("bfe8b0"))
	Audio.play("pickup", -3.0)
	return true
