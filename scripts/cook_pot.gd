class_name CookPot
extends Building
## Котелок (после финала): кухня в лагере. E — открыть окно готовки (CookUI): положить 2–4 продукта и сварить.
## Правила и рецепты — scripts/cooking.gd.


func _make_visual() -> void:
	super._make_visual()
	# огонь под котелком — в точке FirePoint модели (свет дрожит, как у костра: Building._process)
	var fp := visual.find_child("FirePoint", true, false) as Node3D
	Models.flame(visual, fp.position if fp else Vector3(0, 0.12, 0), 0.5, 1.5, 6.0)


func _make_collision() -> void:
	_add_cyl(0.55, 1.5)


## Building._ready по этому методу узнаёт, что с постройкой можно взаимодействовать.
func _custom_interact() -> void:
	pass


func marker_height() -> float:
	return 2.0


func get_hint() -> String:
	var n := Cooking.known_count()
	return "Котелок — готовить (рецептов в книге: %d из %d)" % [n, Cooking.RECIPES.size()]


func interact(_player: Node) -> void:
	Audio.play("water", -8.0, 0.2, global_position)
	var cl := get_tree().get_first_node_in_group("cozy_life") as CozyLife
	if cl:
		cl.open_cooking()
