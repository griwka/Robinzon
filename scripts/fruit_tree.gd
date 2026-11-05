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
		sapling_node.scale = Vector3.ONE * (1.0 + grow * 0.8)
	elif fruit < 1.0:
		fruit = minf(1.0, fruit + dt / cfg["regrow"])
	if was_grown != (grow >= 1.0) or was_ripe != (fruit >= 1.0):
		if grow >= 1.0 and not was_grown:
			tree_node.scale = Vector3(0.3, 0.3, 0.3)
			create_tween().tween_property(tree_node, "scale", Vector3.ONE, 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_refresh()


func _refresh() -> void:
	var grown := grow >= 1.0
	sapling_node.visible = not grown
	tree_node.visible = grown
	var f := tree_node.get_node_or_null("Fruit")
	if f:
		f.visible = grown and fruit >= 1.0
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
	Game.add_item(cfg["fruit"], randi_range(cfg["yield"][0], cfg["yield"][1]))
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
