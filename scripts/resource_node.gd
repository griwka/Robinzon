class_name ResourceNode
extends StaticBody3D
## Ресурс на острове: пальма, куст, валун, камешек, плавник, ракушка.
## Добывается ударами (ЛКМ / E), после добычи исчезает и со временем вырастает снова.

const KINDS := {
	"palm": {"hp": 4, "tool": "stone_axe", "drops": {"wood": 3, "leaf": 2}, "respawn": 150.0,
		"verb": "Срубить пальму", "radius": 0.35, "height": 5.0},
	"bush": {"hp": 2, "tool": "", "drops": {"fiber": 2}, "respawn": 50.0,
		"verb": "Собрать волокно", "radius": 0.7, "height": 1.2},
	"rock": {"hp": 5, "tool": "pickaxe", "drops": {"stone": 5}, "respawn": 200.0,
		"verb": "Разбить валун", "radius": 1.0, "height": 1.4},
	"pebble": {"hp": 1, "tool": "", "drops": {"stone": 1}, "respawn": 60.0,
		"verb": "Подобрать камень", "radius": 0.25, "height": 0.3},
	"driftwood": {"hp": 2, "tool": "", "drops": {"wood": 2}, "respawn": 90.0,
		"verb": "Собрать плавник", "radius": 0.4, "height": 0.4},
	"shell": {"hp": 1, "tool": "", "drops": {"shell": 1}, "respawn": 80.0,
		"verb": "Подобрать ракушку", "radius": 0.2, "height": 0.2},
}

@export var kind := "bush"
var rng_seed := 0
var hp := 1
var active := true
var visual: Node3D
var coconut_ready := true
var _base_scale := Vector3.ONE


func _ready() -> void:
	add_to_group("interactable")
	collision_layer = 2
	collision_mask = 0
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var cfg: Dictionary = KINDS[kind]
	hp = cfg["hp"]
	match kind:
		"palm": visual = Models.palm(rng)
		"bush": visual = Models.bush(rng)
		"rock": visual = Models.rock(rng, true)
		"pebble": visual = Models.rock(rng, false)
		"driftwood": visual = Models.driftwood(rng)
		"shell": visual = Models.shell(rng)
	visual.rotation.y = rng.randf() * TAU
	add_child(visual)
	_base_scale = visual.scale
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = cfg["radius"]
	shape.height = cfg["height"]
	cs.shape = shape
	cs.position.y = cfg["height"] * 0.5
	add_child(cs)
	# маленькие предметы не мешают ходить
	if kind in ["pebble", "shell", "driftwood"]:
		collision_layer = 8


func interact_point() -> Vector3:
	return global_position + Vector3(0, 0.5, 0)


func get_hint() -> String:
	var cfg: Dictionary = KINDS[kind]
	if kind == "palm" and not Game.has_tool("stone_axe"):
		if coconut_ready:
			return "Потрясти пальму (листья и кокосы)"
		return "Кокосы ещё не выросли · нужен топор, чтобы рубить"
	if cfg["tool"] != "" and not Game.has_tool(cfg["tool"]):
		return "%s — нужен инструмент: %s" % [cfg["verb"], Game.item_name(cfg["tool"])]
	return cfg["verb"]


func interact(player: Node) -> void:
	if not active:
		return
	var cfg: Dictionary = KINDS[kind]
	if kind == "palm" and not Game.has_tool("stone_axe"):
		_shake_palm()
		return
	if cfg["tool"] != "" and not Game.has_tool(cfg["tool"]):
		Game.notified.emit("Нужен инструмент: %s" % Game.item_name(cfg["tool"]), Color("ff9d7a"))
		return
	if not Game.use_energy(1):
		return
	hp -= 1
	_hit_fx(player)
	if hp <= 0:
		for id in cfg["drops"]:
			Game.add_item(id, cfg["drops"][id])
		if kind == "palm" and coconut_ready and randf() < 0.6:
			Game.add_item("coconut", 1)
		_deplete()


func _shake_palm() -> void:
	if not coconut_ready:
		return
	if not Game.use_energy(1):
		return
	coconut_ready = false
	var crown := visual.get_node_or_null("Crown")
	if crown:
		var tw := create_tween()
		tw.tween_property(crown, "rotation:z", 0.25, 0.08)
		tw.tween_property(crown, "rotation:z", -0.2, 0.12)
		tw.tween_property(crown, "rotation:z", 0.0, 0.2)
		var cocos := crown.get_node_or_null("Coconuts")
		if cocos:
			cocos.visible = false
	Game.add_item("leaf", 1)
	if randf() < 0.75:
		Game.add_item("coconut", 1)
	get_tree().create_timer(70.0).timeout.connect(func():
		coconut_ready = true
		if crown and crown.get_node_or_null("Coconuts"):
			crown.get_node("Coconuts").visible = true)


func _hit_fx(player: Node) -> void:
	var tw := create_tween()
	var dir := 1.0 if randf() < 0.5 else -1.0
	tw.tween_property(visual, "rotation:z", 0.12 * dir, 0.05)
	tw.tween_property(visual, "rotation:z", -0.06 * dir, 0.08)
	tw.tween_property(visual, "rotation:z", 0.0, 0.1)
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = true
	p.amount = 12
	p.lifetime = 0.6
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 4.0
	p.gravity = Vector3(0, -12, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	var m := BoxMesh.new()
	m.size = Vector3(0.08, 0.08, 0.08)
	p.mesh = m
	var mat := StandardMaterial3D.new()
	var colors := {"palm": Color("c9a26b"), "bush": Color("4fae3c"), "rock": Color("a0a4a8")}
	mat.albedo_color = colors.get(kind, Color("d9c7a0"))
	m.material = mat
	add_child(p)
	p.position = Vector3(0, min(KINDS[kind]["height"] * 0.3, 1.2), 0)
	get_tree().create_timer(1.5).timeout.connect(p.queue_free)


func _deplete() -> void:
	active = false
	remove_from_group("interactable")
	var saved_layer := collision_layer
	collision_layer = 0
	var tw := create_tween()
	if kind == "palm":
		tw.tween_property(visual, "rotation:x", PI / 2.2, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(visual, "scale", Vector3(0.01, 0.01, 0.01), 0.3)
	else:
		tw.tween_property(visual, "scale", Vector3(0.01, 0.01, 0.01), 0.25)
	tw.tween_callback(func(): visual.visible = false)
	get_tree().create_timer(KINDS[kind]["respawn"]).timeout.connect(func():
		_respawn(saved_layer))


func _respawn(layer: int) -> void:
	hp = KINDS[kind]["hp"]
	visual.rotation.x = 0
	visual.visible = true
	visual.scale = Vector3(0.01, 0.01, 0.01)
	var tw := create_tween()
	tw.tween_property(visual, "scale", _base_scale, 1.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	collision_layer = layer
	active = true
	add_to_group("interactable")
