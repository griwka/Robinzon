class_name Pickup
extends StaticBody3D
## Предмет на земле, который можно подобрать: выроненное при ударе молнии или «стекляшка молнии»
## (оплавленный песок) для коллекции. Висит над землёй значком и чуть покачивается.

var item_id := ""          # что вернуть в сумку
var amount := 1
var collection := ""       # или: из какой коллекции выпадет находка
var _t := 0.0
var _icon: Sprite3D


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("pickup")
	collision_layer = 8
	var cs := CollisionShape3D.new()
	var s := SphereShape3D.new()
	s.radius = 0.35
	cs.shape = s
	cs.position.y = 0.35
	add_child(cs)
	if collection != "":
		var m := Models.glb("fulgurite")
		if m:
			add_child(m)
	_icon = Sprite3D.new()
	_icon.texture = FX.icon_texture(item_id if item_id != "" else "fulg_twig")
	_icon.pixel_size = 0.0035
	_icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_icon.shaded = false
	_icon.position.y = 0.9 if collection != "" else 0.5
	_icon.modulate = Color(1, 1, 1, 0.9)
	add_child(_icon)
	if collection != "":
		_icon.scale = Vector3.ONE * 0.6


func _process(delta: float) -> void:
	_t += delta
	_icon.position.y = (0.9 if collection != "" else 0.5) + sin(_t * 2.5) * 0.08


func interact_point() -> Vector3:
	return global_position + Vector3(0, 0.4, 0)


func tool_hint() -> String:
	return ""


func get_hint() -> String:
	if collection != "":
		return "Подобрать оплавленный песок («стекляшку молнии»)"
	return "Подобрать: %s ×%d" % [Game.item_name(item_id), amount]


func interact(_player: Node) -> void:
	if collection != "":
		Game.add_collectible(collection)
	else:
		Game.add_item(item_id, amount, false)
	FX.poof(get_parent(), global_position + Vector3(0, 0.3, 0), Color("f1e6c8"), 0.5)
	queue_free()
