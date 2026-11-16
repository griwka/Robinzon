class_name RuneStones
extends Node
## Древние знаки: на каждом острове (кроме Ока шторма) стоят три камня тех, кто строил маяки. На каждом — знак
## и стрелка. Стрелки всех трёх смотрят в одну точку между камнями. Найдёшь все три — в этой точке становится
## заметен просевший бугорок: там зарыт тайник (нужна лопата). В тайнике — немного полезного и знак острова
## в коллекцию «Знаки строителей». Все семь знаков открывают украшение «Камень со знаками».
##
## Места выбираются по зерну острова — всегда одни и те же. Найденное хранится во флагах:
## rune_<остров>_<n> — камень осмотрен, rune_cache_<остров> — тайник выкопан.

const ISLANDS := ["home", "banyan", "fort", "storm", "ice", "volcano", "fog"]
const VARIANTS := ["rune_stone_a", "rune_stone_b", "rune_stone_c"]
## Что лежит в тайнике острова (вещи, не монеты; каждый тайник — один раз).
const LOOT := {
	"home": {"seed_watermelon": 2, "shell": 3},
	"banyan": {"honey": 2, "liana": 3},
	"fort": {"brick": 4, "lamp_oil": 1},
	"storm": {"battery": 1, "glass": 2},
	"ice": {"ice": 3, "cloudberry": 3},
	"volcano": {"obsidian": 2, "iron_ingot": 1},
	"fog": {"candle": 3, "firefly": 2},
}
const LOOT_MAX_VALUE := 40      # тайник не дороже стольких монет по прейскуранту (проверяет валидатор)
const STONE_LINES := [
	"На камне выбит знак, под ним — стрелка. Она куда-то показывает.",
	"Второй камень. Знак другой, а стрелка смотрит в другую сторону. Или в ту же точку?",
	"Третий камень. Три стрелки сходятся в одном месте между камнями. Земля там будто просела.",
]

var island: Island
var stones: Array[RuneStone] = []
var cache: RuneCache
var center := Vector3.INF


func _ready() -> void:
	add_to_group("rune_stones")
	if island == null or not Game.location in ISLANDS:
		return
	var spots := find_spots(island)
	if spots.is_empty():
		return
	center = spots[0]
	for i in 3:
		var s := RuneStone.new()
		s.index = i
		s.owner_node = self
		var p: Vector3 = spots[i + 1]
		s.position = p
		# лицом (и стрелкой) к месту тайника
		s.rotation.y = atan2(center.x - p.x, center.z - p.z)
		island.add_child(s)
		stones.append(s)
	_refresh_cache()


static func flag(loc: String, i: int) -> String:
	return "rune_%s_%d" % [loc, i]


static func found_count(loc: String) -> int:
	var n := 0
	for i in 3:
		if Game.flags.get(flag(loc, i), false):
			n += 1
	return n


static func cache_open(loc: String) -> bool:
	return Game.flags.get("rune_cache_" + loc, false)


## Точка подходит для камня или тайника: суша, не круто, не у сюжетного места, не в лагере.
static func _land_ok(isl: Island, p: Vector2, lo: float, hi: float) -> bool:
	var h := isl.height_at(p.x, p.y)
	if h < lo or h > hi:
		return false
	for d in [Vector2(1.2, 0), Vector2(-1.2, 0), Vector2(0, 1.2), Vector2(0, -1.2)]:
		if absf(isl.height_at(p.x + d.x, p.y + d.y) - h) > 0.5:
			return false
	if isl._near_poi(p, 10.0):
		return false
	if p.distance_to(Vector2(isl.camp_center.x, isl.camp_center.z)) < 13.0:
		return false
	if p.distance_to(Vector2(isl.wreck_point.x, isl.wreck_point.z)) < 8.0:
		return false
	for f in [isl.flat]:
		if not f.is_empty() and p.distance_to(f[0]) < float(f[1]) + 6.0:
			return false       # плато с крепостью, станцией, ледником — не там
	return true


## Места на острове: [тайник, камень 1, камень 2, камень 3] или пусто, если не нашлось.
static func find_spots(isl: Island) -> Array:
	var g := RandomNumberGenerator.new()
	g.seed = hash("runes:%s:%d" % [isl.loc, isl.seed_value])     # близкие числа-зёрна дают похожие ряды, поэтому — хеш строки
	for attempt in 400:
		var a := g.randf() * TAU
		var r := g.randf_range(isl.radius * 0.3, isl.radius * 0.72)
		var c := Vector2(cos(a) * r, sin(a) * r)
		if not _land_ok(isl, c, 1.1, 7.0):
			continue
		var out: Array = [Vector3(c.x, isl.height_at(c.x, c.y), c.y)]
		var base := g.randf() * TAU
		var ok := true
		for i in 3:
			var placed := false
			for tries in 12:
				var sa := base + TAU * i / 3.0 + g.randf_range(-0.45, 0.45)
				var sr := g.randf_range(7.0, 11.0)
				var p := c + Vector2(cos(sa), sin(sa)) * sr
				if _land_ok(isl, p, 0.9, 8.0):
					out.append(Vector3(p.x, isl.height_at(p.x, p.y), p.y))
					placed = true
					break
			if not placed:
				ok = false
				break
		if ok:
			return out
	return []


## Камень осмотрели.
func stone_found(s: RuneStone) -> void:
	var loc := Game.location
	if Game.flags.get(flag(loc, s.index), false):
		Game.notified.emit("Знак ты уже видел. Стрелка под ним смотрит всё туда же", Color("e8dcc0"))
		return
	Game.flags[flag(loc, s.index)] = true
	var n := found_count(loc)
	Game.bump("runes", "stone")
	Audio.play("rare", -5.0, 0.05)
	FX.burst(island, s.global_position + Vector3(0, 1.0, 0), Color("ffe9b0"), 10)
	Game.dialogue_requested.emit([["narrator", STONE_LINES[clampi(n - 1, 0, 2)]]], Callable())
	_refresh_cache()


## Тайник виден, когда найдены все три камня и он ещё не выкопан.
func _refresh_cache() -> void:
	var loc := Game.location
	var want := found_count(loc) >= 3 and not cache_open(loc) and center != Vector3.INF
	if want and cache == null:
		cache = RuneCache.new()
		cache.owner_node = self
		cache.position = center
		island.add_child(cache)
		# заросли и мелкая трава на месте тайника не мешают копать
		for o in get_tree().get_nodes_in_group("obstacle"):
			if o is ResourceNode and (o as Node3D).global_position.distance_to(center) < 1.6:
				o.queue_free()     # тихо, без щепок и добычи: кольца преград у сюжетных мест сюда не попадают (_land_ok)
		if island.grass_field:
			island.grass_field.clear_at(center, 1.4, true)
	elif not want and cache != null:
		cache.queue_free()
		cache = null


## Выкопать тайник. Возвращает true, если получилось.
func dig() -> bool:
	var loc := Game.location
	if cache_open(loc) or found_count(loc) < 3:
		return false
	if not Game.has_tool("shovel"):
		Game.notified.emit("Земля просела, под ней что-то есть. Нужна лопата", Color("ff9d7a"))
		return false
	Game.flags["rune_cache_" + loc] = true
	Game.use_tool("shovel")
	Audio.play("build", -3.0, 0.1)
	FX.dust(island, center + Vector3(0, 0.1, 0), Color("8a6a48"), 12, 0.5)
	var loot: Dictionary = LOOT.get(loc, {})
	for id in loot:
		Game.add_item(id, int(loot[id]), false)
	WorldLife.collect("signs", "sign_" + loc)
	Game.bump("runes", "cache")
	_refresh_cache()
	return true


## Камень со знаком.
class RuneStone extends StaticBody3D:
	var index := 0
	var owner_node: RuneStones
	var visual: Node3D

	func _ready() -> void:
		add_to_group("interactable")
		add_to_group("rune_stone")
		collision_layer = 4
		visual = Models.glb(RuneStones.VARIANTS[index % RuneStones.VARIANTS.size()])
		if visual:
			add_child(visual)
		var cs := CollisionShape3D.new()
		var c := CylinderShape3D.new()
		c.radius = 0.5
		c.height = 1.6
		cs.shape = c
		cs.position.y = 0.8
		add_child(cs)
		_clear.call_deferred()

	## Камень стоит на чистом месте: заросли вплотную убираем (иначе его не видно и к нему не подойти).
	func _clear() -> void:
		for o in get_tree().get_nodes_in_group("obstacle"):
			if o is ResourceNode and (o as Node3D).global_position.distance_to(global_position) < 1.5:
				o.queue_free()

	func block_radius() -> float:
		return 0.8

	func interact_point() -> Vector3:
		return global_position + Vector3(0, 0.9, 0)

	func tool_hint() -> String:
		return ""

	func get_hint() -> String:
		if Game.flags.get(RuneStones.flag(Game.location, index), false):
			return "Камень со знаком — стрелка показывает на место между камнями"
		return "Старый камень со знаком — рассмотреть"

	func interact(_player: Node) -> void:
		owner_node.stone_found(self)


## Просевший бугорок на месте тайника.
class RuneCache extends StaticBody3D:
	var owner_node: RuneStones
	var visual: Node3D

	func _ready() -> void:
		add_to_group("interactable")
		add_to_group("rune_cache")
		collision_layer = 8
		visual = Models.glb("rune_cache")
		if visual:
			add_child(visual)
		var cs := CollisionShape3D.new()
		var s := SphereShape3D.new()
		s.radius = 0.6
		cs.shape = s
		cs.position.y = 0.2
		add_child(cs)

	func interact_point() -> Vector3:
		return global_position + Vector3(0, 0.3, 0)

	func tool_hint() -> String:
		return "shovel"

	func get_hint() -> String:
		return "Просевшая земля — копать" if Game.has_tool("shovel") else "Просевшая земля (нужна лопата)"

	func interact(_player: Node) -> void:
		owner_node.dig()
