class_name SeaDrift
extends Node
## Море что-то приносит: раз в несколько минут волна оставляет на сухом песке находку — бутылку с запиской,
## обкатанное морем стекло, чужой поплавок или стручок с семенами. Подобрал — хорошо, не подобрал — лежит,
## пока не подберёшь; больше MAX находок сразу на берегу не бывает. Работает на всех островах, кроме Ока шторма.
## Находки не сохраняются (как обломки TideScrap): после загрузки море принесёт новые.

const INTERVAL := 300.0     # сек игры между находками
const MAX := 2
const SAND_LO := 0.4
const SAND_HI := 0.85
## Что приносит и как часто (вес).
const KINDS := {"bottle": 3.0, "glass": 3.0, "float": 2.0, "pod": 2.0}
const POD_SEEDS := ["seed_carrot", "seed_corn", "seed_tomato", "seed_pumpkin", "seed_potato"]

var island: Island
var _t := 0.0
var _n := 0


func _ready() -> void:
	add_to_group("sea_drift")
	if enabled():
		_first.call_deferred()


func enabled() -> bool:
	return island != null and Game.location != "eye"


func _first() -> void:
	wash_ashore(false)      # одна находка уже ждёт на берегу


func _process(delta: float) -> void:
	if not enabled() or get_tree().paused or not Game.playing:
		return
	_t += delta
	if _t < INTERVAL:
		return
	_t = 0.0
	if count() < MAX:
		wash_ashore(true)


func count() -> int:
	return get_tree().get_nodes_in_group("drift_find").size()


func spot_ok(p: Vector3) -> bool:
	var h := island.height_at(p.x, p.z)
	if h < SAND_LO or h > SAND_HI:
		return false
	for d in [Vector2(0.8, 0), Vector2(-0.8, 0), Vector2(0, 0.8), Vector2(0, -0.8)]:
		if absf(island.height_at(p.x + d.x, p.z + d.y) - h) > 0.35:
			return false
	var q := Vector2(p.x, p.z)
	for g in ["building", "obstacle", "interactable"]:
		for o in get_tree().get_nodes_in_group(g):
			var on := o as Node3D
			if on != null and q.distance_to(Vector2(on.global_position.x, on.global_position.z)) < 1.8:
				return false
	var pl := get_tree().get_first_node_in_group("player") as Node3D
	if pl and q.distance_to(Vector2(pl.global_position.x, pl.global_position.z)) < 6.0:
		return false       # не возникает прямо на глазах
	return true


func find_spot() -> Vector3:
	var rng := RandomNumberGenerator.new()
	_n += 1
	rng.seed = Time.get_ticks_usec() + _n * 7919
	for attempt in 60:
		var a := rng.randf() * TAU
		var dir := Vector3(cos(a), 0, sin(a))
		var r := island.radius * 0.35
		while r < island.radius * 1.6 and island.height_at(dir.x * r, dir.z * r) > SAND_LO:
			r += 0.4
		for back in [0.8, 1.6, 2.4, 3.2]:
			var p: Vector3 = dir * (r - float(back))
			p.y = island.height_at(p.x, p.z)
			if spot_ok(p):
				return p
	return Vector3.INF


static func pick_kind(roll: float) -> String:
	var total := 0.0
	for k in KINDS:
		total += float(KINDS[k])
	var r := roll * total
	for k in KINDS:
		r -= float(KINDS[k])
		if r <= 0.0:
			return k
	return "glass"


## Волна оставила находку. kind — что именно ("" — случайно). Возвращает узел или null (нет места).
func wash_ashore(noisy: bool, kind := "") -> DriftFind:
	var p := find_spot()
	if p == Vector3.INF:
		return null
	var f := DriftFind.new()
	f.kind = kind if kind != "" else pick_kind(randf())
	f.position = p
	f.rotation.y = randf() * TAU
	island.add_child(f)
	if noisy:
		FX.splash(island, Vector3(p.x, 0.0, p.z))
	return f


## Находка на песке.
class DriftFind extends StaticBody3D:
	var kind := "glass"
	var _t := 0.0
	var _model: Node3D

	func _ready() -> void:
		add_to_group("interactable")
		add_to_group("drift_find")
		collision_layer = 8
		var cs := CollisionShape3D.new()
		var s := SphereShape3D.new()
		s.radius = 0.35
		cs.shape = s
		cs.position.y = 0.25
		add_child(cs)
		_model = Models.glb("drift_" + kind)
		if _model:
			add_child(_model)

	func _process(delta: float) -> void:
		_t += delta

	func interact_point() -> Vector3:
		return global_position + Vector3(0, 0.3, 0)

	func tool_hint() -> String:
		return ""

	func get_hint() -> String:
		match kind:
			"bottle": return "Бутылка, выброшенная морем — подобрать"
			"glass": return "Что-то блестит в песке — подобрать"
			"float": return "Чужой поплавок — подобрать"
			"pod": return "Стручок с семенами — подобрать"
		return "Подобрать"

	func interact(_player: Node) -> void:
		take()

	## Подобрать находку. Возвращает, что получено (для автотеста): id вещи или коллекции.
	func take() -> String:
		var got := ""
		match kind:
			"bottle":
				var next := WorldLife.next_missing("sea_bottles")
				if next != "":
					WorldLife.collect("sea_bottles", next)
					got = next
				else:
					# все записки прочитаны — бутылка пустая, но стекло пригодится
					Game.add_item("glass", 1, false)
					Game.notified.emit("Бутылка пустая. Зато стекло целое", Color("bfe8f0"))
					got = "glass"
			"glass":
				Game.add_collectible("sea_glass")
				got = "sea_glass"
			"float":
				Game.add_item("rope", 1, false)
				Game.add_item("wood", 1, false)
				Game.notified.emit("Поплавок с обрывком сети. Чей-то улов ушёл", Color("ffe08a"))
				got = "rope"
			"pod":
				var seed_id: String = SeaDrift.POD_SEEDS[randi() % SeaDrift.POD_SEEDS.size()]
				Game.add_item(seed_id, 1, false)
				Game.notified.emit("В стручке — семена. Море принесло их издалека", Color("b6f29a"))
				got = seed_id
		Game.bump("drift", "any")
		FX.poof(get_parent(), global_position + Vector3(0, 0.3, 0), Color("f1e6c8"), 0.5)
		remove_from_group("drift_find")
		queue_free()
		return got
