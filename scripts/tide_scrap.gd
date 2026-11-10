class_name TideScrap
extends Node
## Остров крушения: волны время от времени выносят на берег обломки «Чайки» — кучки ржавого железа.
##
## Только на сухом песке у воды (не в траве, не в воде), только на свободном месте: не на грядке и не у постройки,
## не на другом предмете и не прямо под ногами у героя. Не чаще раза в INTERVAL секунд и не больше MAX сразу.
## Кучка, которую разобрали, больше не появляется на том же месте — следующую вынесет волна где-нибудь ещё.
## Так у игрока всегда есть железо на новое мачете (инструменты ломаются), ещё до Грозового острова.

const INTERVAL := 240.0     # сек игры между волнами
const MAX := 3              # больше кучек на берегу сразу не бывает
const SAND_LO := 0.4        # ниже — мокрый песок и вода
const SAND_HI := 0.8        # выше — трава

var island: Island
var holder: Node3D
var _t := 0.0
var _seed := 0


func _ready() -> void:
	name = "TideScrap"
	add_to_group("tide_scrap")
	# с самого начала на берегу уже лежат две кучки (обломки после крушения) — когда постройки уже расставлены
	_first.call_deferred()


func _first() -> void:
	for i in 2:
		wash_ashore(false)


func _process(delta: float) -> void:
	if get_tree().paused or not Game.playing:
		return
	_t += delta
	if _t < INTERVAL:
		return
	_t = 0.0
	if count() < MAX:
		wash_ashore(true)


func count() -> int:
	var n := 0
	for c in holder.get_children():
		if c is ResourceNode and (c as ResourceNode).washed and (c as ResourceNode).active:
			n += 1
	return n


## Подходит ли точка: сухой песок, ровно, свободно.
func spot_ok(p: Vector3) -> bool:
	var h := island.height_at(p.x, p.z)
	if h < SAND_LO or h > SAND_HI:
		return false
	# ровно: на склоне кучка висела бы
	for d in [Vector2(0.8, 0), Vector2(-0.8, 0), Vector2(0, 0.8), Vector2(0, -0.8)]:
		if absf(island.height_at(p.x + d.x, p.z + d.y) - h) > 0.35:
			return false
	var q := Vector2(p.x, p.z)
	for b in get_tree().get_nodes_in_group("building"):
		var bn := b as Node3D
		var br: float = float(Data.BUILDINGS.get(str(b.get("id")), {}).get("radius", 1.0))
		if q.distance_to(Vector2(bn.global_position.x, bn.global_position.z)) < br + 1.6:
			return false
	for o in get_tree().get_nodes_in_group("obstacle"):
		var on := o as Node3D
		if q.distance_to(Vector2(on.global_position.x, on.global_position.z)) < 1.8:
			return false
	for o in get_tree().get_nodes_in_group("interactable"):
		var on := o as Node3D
		if q.distance_to(Vector2(on.global_position.x, on.global_position.z)) < 1.4:
			return false
	var pl := get_tree().get_first_node_in_group("player") as Node3D
	if pl and q.distance_to(Vector2(pl.global_position.x, pl.global_position.z)) < 5.0:
		return false   # не возникает прямо на глазах и под ногами
	if q.distance_to(Vector2(island.wreck_point.x, island.wreck_point.z)) < 3.5:
		return false   # у причала (плот) не мешает
	return true


## Найти место на берегу: идём от середины острова к воде и чуть назад — на сухой песок.
func find_spot() -> Vector3:
	var rng := RandomNumberGenerator.new()
	_seed += 1
	rng.seed = Time.get_ticks_usec() + _seed * 7919
	for attempt in 60:
		var a := rng.randf() * TAU
		var dir := Vector3(cos(a), 0, sin(a))
		var r := island.radius * 0.35
		while r < island.radius * 1.6 and island.height_at(dir.x * r, dir.z * r) > SAND_LO:
			r += 0.4
		# от кромки воды — шаг-другой на берег, в полосу сухого песка
		for back in [0.8, 1.6, 2.4, 3.2]:
			var p: Vector3 = dir * (r - float(back))
			p.y = island.height_at(p.x, p.z)
			if spot_ok(p):
				return p
	return Vector3.INF


## Волна вынесла кучку железа. noisy — шорох прибоя и брызги (когда это видно в игре).
func wash_ashore(noisy: bool) -> bool:
	var p := find_spot()
	if p == Vector3.INF:
		return false
	var r := ResourceNode.new()
	r.kind = "scrap_pile"
	r.rng_seed = 9000 + _seed
	r.washed = true
	r.yaw = -100.0
	r.position = Vector3(p.x, p.y - 0.03, p.z)
	holder.add_child(r)
	if noisy:
		FX.splash(holder, Vector3(p.x, 0.0, p.z))
	return true
