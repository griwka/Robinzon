class_name FruitTree
extends Building
## Фруктовое дерево: саженец вырастает в дерево, плоды созревают и собираются встряхиванием.
## Дикие деревья (wild) растут на острове сами и не сохраняются.

var tree_type := "banana"
var wild := false
var rng_seed := 0
var grow := 0.0
var fruit := 0.0
var sapling_node: Node3D
var tree_node: Node3D


func _custom_interact() -> void:
	pass


func _ready() -> void:
	if variant != "":
		tree_type = variant
	if wild:
		grow = 1.0
		fruit = randf_range(0.5, 1.0)
	super()
	if wild:
		remove_from_group("building")
		add_to_group("obstacle")
	marker = FX.marker(self, marker_height())
	_refresh()


func _make_visual() -> void:
	visual = Node3D.new()
	add_child(visual)
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed if rng_seed != 0 else hash(str(global_position) + tree_type)
	sapling_node = Models.sapling()
	visual.add_child(sapling_node)
	tree_node = Models.fruit_tree(tree_type, rng)
	tree_node.rotation.y = rng.randf() * TAU
	visual.add_child(tree_node)


func _make_collision() -> void:
	_add_cyl(0.3, 2.0)
	collision_layer = 2


func block_radius() -> float:
	return 1.0


func marker_height() -> float:
	return 4.0 if grow >= 1.0 else 1.3


func _process(delta: float) -> void:
	super(delta)
	var dt := world_dt()
	var was_grown := grow >= 1.0
	var was_ripe := fruit >= 1.0
	var cfg: Dictionary = Data.TREES[tree_type]
	if grow < 1.0:
		grow = minf(1.0, grow + dt / cfg["grow"])
	elif fruit < 1.0:
		fruit = minf(1.0, fruit + dt / cfg["regrow"])
	if was_grown != (grow >= 1.0) or was_ripe != (fruit >= 1.0):
		_refresh()
	elif absf(grow - _shown.x) > 0.002 or absf(fruit - _shown.y) > 0.003:
		_grow_visual()


# ------------------------------------------------------------------ плавный рост
# Саженец в горшке подрастает, потом на его месте поднимается деревце и дорастает до взрослого — без скачка.
# Плоды (узел Fruit: каждый плод — свой узел) завязываются маленькими и зелёными и наливаются до спелых.
var _shown := Vector2(-1, -1)
var _fruit_mat: ShaderMaterial
const UNRIPE := Color(0.6, 0.85, 0.48)


func _grow_visual() -> void:
	_shown = Vector2(grow, fruit)
	var sap := clampf(1.0 - (grow - 0.3) / 0.12, 0.0, 1.0)   # саженец уходит, когда деревце поднялось
	sapling_node.visible = sap > 0.01
	sapling_node.scale = Vector3.ONE * (1.0 + minf(grow, 0.3) * 2.0) * lerpf(0.4, 1.0, sap)
	var t := smoothstep(0.26, 1.0, grow)
	tree_node.visible = grow > 0.26
	tree_node.scale = Vector3.ONE * lerpf(0.22, 1.0, t)
	var f := tree_node.get_node_or_null("Fruit") as Node3D
	if f == null:
		return
	var grown := grow >= 1.0
	f.visible = grown and fruit > 0.05
	var k := lerpf(0.25, 1.0, smoothstep(0.05, 0.9, fruit))
	var items: Array = f.get_children().filter(func(c): return c is MeshInstance3D)
	if items.is_empty() and f is MeshInstance3D:
		items = [f]
	if _fruit_mat == null and not items.is_empty():
		_fruit_mat = (Models.model_mat(false).duplicate() as ShaderMaterial)
	for it in items:
		(it as MeshInstance3D).scale = Vector3.ONE * k
		(it as MeshInstance3D).material_override = _fruit_mat
	if _fruit_mat:
		_fruit_mat.set_shader_parameter("albedo", UNRIPE.lerp(Color.WHITE, smoothstep(0.55, 1.0, fruit)))


func _refresh() -> void:
	var grown := grow >= 1.0
	_grow_visual()
	FX.set_marker(marker, grown and fruit >= 1.0 and not wild, Data.TREES[tree_type]["fruit"])
	if marker:
		marker.position.y = marker_height()


func interact_point() -> Vector3:
	return global_position + Vector3(0, 0.8, 0)


func get_hint() -> String:
	var cfg: Dictionary = Data.TREES[tree_type]
	if grow < 1.0:
		return "Саженец: %s, растёт %d%%" % [cfg["name"].to_lower(), int(grow * 100)]
	if fruit >= 1.0:
		return "Потрясти %s" % cfg["name"].to_lower()
	return "%s: плоды созревают %d%%" % [cfg["name"], int(fruit * 100)]


func interact(_player: Node) -> void:
	var cfg: Dictionary = Data.TREES[tree_type]
	if grow < 1.0 or fruit < 1.0:
		Game.notified.emit(get_hint(), Color("ffe08a"))
		return
	var crown := tree_node.get_node_or_null("Crown")
	if crown:
		var tw := create_tween()
		tw.tween_property(crown, "rotation:z", 0.15, 0.08)
		tw.tween_property(crown, "rotation:z", -0.12, 0.12)
		tw.tween_property(crown, "rotation:z", 0.0, 0.2)
	fruit = 0.0
	Audio.play("shake", -3.0, 0.1, global_position)
	Game.add_item(cfg["fruit"], randi_range(cfg["yield"][0], cfg["yield"][1]) * (2 if Game.bounty_today() else 1))
	if wild and randf() < 0.2:
		Game.add_item("sapling_" + tree_type, 1)
	FX.burst(self, Vector3(0, 2.5, 0), Data.ITEMS[cfg["fruit"]]["color"], 10)
	_refresh()


func get_state() -> Dictionary:
	return {"grow": grow, "fruit": fruit}


func apply_state(d: Dictionary) -> void:
	grow = float(d.get("grow", 0.0))
	fruit = float(d.get("fruit", 0.0))
	if is_inside_tree():
		_refresh()
