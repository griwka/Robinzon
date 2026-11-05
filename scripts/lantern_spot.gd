class_name LanternSpot
extends Node3D
## Метка под тыквенный фонарь: колышек с тряпочкой. Фонарь можно поставить только на метку.
## На тропе к сигнальному камню (группа lantern_spot) — разгоняют туман; у стоячих камней (shadow_spot) —
## дают тени для головоломки. pebbles — сколько камешков лежит у метки (номер для подсказки).

var group := "lantern_spot"
var pebbles := 0
var used := false
var marker: Node3D


func _ready() -> void:
	add_to_group(group)
	marker = Models.glb("lantern_mark")
	if marker:
		add_child(marker)
	for i in pebbles:
		var m := MeshInstance3D.new()
		m.mesh = Models.sphere(0.06, 8, 5)
		m.material_override = Models.mat(Color("eef0f2"), false)
		m.position = Vector3(-0.25 + i * 0.13, 0.03, 0.45)
		m.scale = Vector3(1.0, 0.6, 1.0)
		add_child(m)


## Занята ли метка фонарём (то же имя, что у мест под мостки, — Building зовёт его одинаково).
func set_bridged(on: bool) -> void:
	used = on
	if marker:
		marker.visible = not on
