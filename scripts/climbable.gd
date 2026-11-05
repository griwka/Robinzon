class_name Climbable
extends Node3D
## Лиана для лазания: вертикальный отрезок от bottom до top (локальные координаты родителя).
## Сверху игрок выходит на площадку exit. Лезть можно только в перчатках лазальщика.

var bottom := Vector3.ZERO
var top := Vector3(0, 5, 0)
var exit := Vector3.ZERO


func _ready() -> void:
	add_to_group("climb")
	var len := top.y - bottom.y
	var segs := int(ceil(len))
	for i in segs:
		var m := Models.glb("liana")
		if m == null:
			break
		m.position = bottom + Vector3(0, i * len / segs, 0)
		m.scale = Vector3(1.4, len / segs, 1.4)
		m.rotation.y = i * 1.7
		add_child(m)


func world_bottom() -> Vector3:
	return get_parent().to_global(bottom)


func world_top() -> Vector3:
	return get_parent().to_global(top)


func world_exit() -> Vector3:
	return get_parent().to_global(exit)
