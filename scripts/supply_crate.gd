class_name SupplyCrate
extends StaticBody3D
## Ящик с разбитого корабля, выброшенный на берег. Открывается один раз.

const LOOT := {"seed_potato": 2, "seed_cabbage": 2, "seed_tomato": 1, "rope": 2, "plank": 2}

var visual: Node3D


func _ready() -> void:
	collision_layer = 4
	var opened: bool = Game.flags.get("crate_opened", false)
	visual = Models.supply_crate(opened)
	add_child(visual)
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(1.0, 0.8, 0.7)
	cs.shape = b
	cs.position.y = 0.4
	add_child(cs)
	if not opened:
		add_to_group("interactable")


func interact_point() -> Vector3:
	return global_position + Vector3(0, 0.5, 0)


func tool_hint() -> String:
	return ""


func get_hint() -> String:
	return "Открыть ящик, выброшенный морем"


func interact(_player: Node) -> void:
	if Game.flags.get("crate_opened", false):
		return
	Game.flags["crate_opened"] = true
	remove_from_group("interactable")
	var lid := visual.get_node("Lid")
	var tw := create_tween()
	tw.tween_property(lid, "position", Vector3(0, 0.45, 0.55), 0.3)
	tw.parallel().tween_property(lid, "rotation:x", 1.3, 0.3)
	FX.burst(self, Vector3(0, 0.8, 0), Color("ffe08a"), 16)
	Audio.play("rare", -2.0)
	for id in LOOT:
		Game.add_item(id, LOOT[id], false)
	Game.add_collectible("journal")
	Game.bump("collected", "crate")
