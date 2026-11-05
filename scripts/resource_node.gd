class_name ResourceNode
extends StaticBody3D
## Ресурс на острове: пальма, куст, валун, камешек, плавник, ракушка.
## Добывается ударами (ЛКМ / E), после добычи исчезает и со временем вырастает снова.

# respawn = 0 — преграда: расчищается навсегда (сохраняется), открывая путь вглубь острова.
const KINDS := {
	"palm": {"hp": 3, "tool": "stone_axe", "drops": {"wood": 3, "leaf": 2}, "respawn": 160.0,
		"verb": "Срубить пальму", "radius": 0.4, "height": 5.0},
	"bush": {"hp": 1, "tool": "", "drops": {"fiber": 2}, "respawn": 45.0,
		"verb": "Собрать волокно", "radius": 0.7, "height": 1.2},
	"rock": {"hp": 4, "tool": "pickaxe", "drops": {"stone": 5}, "respawn": 0.0,
		"verb": "Разбить валун", "radius": 1.0, "height": 1.4},
	"pebble": {"hp": 1, "tool": "", "drops": {"stone": 1}, "respawn": 50.0,
		"verb": "Подобрать камень", "radius": 0.25, "height": 0.3},
	"driftwood": {"hp": 1, "tool": "", "drops": {"wood": 2}, "respawn": 70.0,
		"verb": "Собрать плавник", "radius": 0.4, "height": 0.4},
	"shell": {"hp": 1, "tool": "", "drops": {"shell": 1}, "respawn": 60.0,
		"verb": "Подобрать ракушку", "radius": 0.2, "height": 0.2},
	# --- заросли и преграды
	"tall_grass": {"hp": 1, "tool": "", "drops": {"fiber": 1}, "respawn": 0.0,
		"verb": "Вырвать высокую траву", "radius": 0.75, "height": 1.2},
	"fern": {"hp": 1, "tool": "", "drops": {"fiber": 1, "leaf": 1}, "respawn": 0.0,
		"verb": "Убрать папоротник", "radius": 0.8, "height": 0.9},
	"thicket": {"hp": 2, "tool": "machete", "drops": {"fiber": 3}, "respawn": 0.0,
		"verb": "Прорубить колючие заросли", "radius": 1.1, "height": 1.5},
	"bamboo": {"hp": 3, "tool": "machete", "drops": {"bamboo": 3}, "respawn": 0.0,
		"verb": "Срубить бамбук", "radius": 0.9, "height": 4.0},
	"jungle_tree": {"hp": 6, "tool": "stone_axe", "drops": {"wood": 6}, "respawn": 0.0,
		"verb": "Срубить дерево-гигант", "radius": 1.3, "height": 7.0},
	"fallen_log": {"hp": 3, "tool": "stone_axe", "drops": {"wood": 4}, "respawn": 0.0,
		"verb": "Разрубить поваленный ствол", "radius": 0.8, "height": 0.8, "long": 1.6},
	"cliff": {"hp": 6, "tool": "pickaxe", "drops": {"stone": 8}, "respawn": 0.0,
		"verb": "Разбить каменную гряду", "radius": 1.0, "height": 2.2, "long": 1.9},
	"clay": {"hp": 1, "tool": "shovel", "drops": {"clay": 2}, "respawn": 60.0,
		"verb": "Накопать глины", "radius": 0.7, "height": 0.2},
	"liana_curtain": {"hp": 2, "tool": "machete", "drops": {"liana": 2, "fiber": 1}, "respawn": 0.0,
		"verb": "Разрубить завесу лиан", "radius": 0.5, "height": 2.6, "long": 1.35},
}
const MODEL_NAMES := {"tall_grass": ["tall_grass"], "fern": ["fern_a", "fern_b"], "thicket": ["thicket"],
	"bamboo": ["bamboo_clump"], "jungle_tree": ["jungle_tree_a", "jungle_tree_b"], "fallen_log": ["fallen_log"],
	"cliff": ["cliff_a", "cliff_b"], "liana_curtain": ["liana_curtain"], "clay": ["clay_pit"]}
const BUSH_SEEDS := ["seed_carrot", "seed_carrot", "seed_potato", "seed_corn", "seed_cabbage"]

@export var kind := "bush"
var rng_seed := 0
var uid := ""   # постоянный номер преграды — чтобы сохранить, что её расчистили
var yaw := -100.0   # < -50 — случайный поворот
var hp := 1
var active := true
var visual: Node3D
var coconut_ready := true
var _base_scale := Vector3.ONE


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("obstacle")
	collision_layer = 2
	collision_mask = 0
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var cfg: Dictionary = KINDS[kind]
	hp = cfg["hp"]
	match kind:
		"tall_grass", "fern", "thicket", "bamboo", "jungle_tree", "fallen_log", "cliff", "liana_curtain", "clay":
			var names: Array = MODEL_NAMES[kind]
			visual = Models.glb(names[rng.randi() % names.size()])
			if visual == null:
				visual = Models.bush(rng)
		"palm": visual = Models.palm(rng)
		"bush": visual = Models.bush(rng)
		"rock": visual = Models.rock(rng, true)
		"pebble": visual = Models.rock(rng, false)
		"driftwood": visual = Models.driftwood(rng)
		"shell": visual = Models.shell(rng)
	visual.rotation.y = rng.randf() * TAU if yaw < -50.0 else yaw
	add_child(visual)
	_setup_visibility()
	_base_scale = visual.scale
	var cs := CollisionShape3D.new()
	if cfg.has("long"):
		# вытянутые преграды (ствол, гряда) — коробка вдоль модели
		var bx := BoxShape3D.new()
		bx.size = Vector3(cfg["long"] * 2.0, cfg["height"], cfg["radius"] * 1.6)
		cs.shape = bx
		cs.rotation.y = visual.rotation.y
	else:
		var shape := CylinderShape3D.new()
		shape.radius = cfg["radius"]
		shape.height = cfg["height"]
		cs.shape = shape
	cs.position.y = cfg["height"] * 0.5
	add_child(cs)
	if kind in ["pebble", "shell", "driftwood", "clay"]:
		collision_layer = 8  # мелочь не мешает ходить


func _setup_visibility() -> void:
	# дальние мелкие объекты не рисуем и не даём им тени — так тысяча растений не тормозит
	var far := 90.0 if kind in ["jungle_tree", "palm", "cliff", "bamboo"] else 55.0
	for mi in visual.find_children("*", "GeometryInstance3D", true, false):
		var gi := mi as GeometryInstance3D
		gi.visibility_range_end = far
		gi.visibility_range_end_margin = 6.0
		gi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		if kind in ["tall_grass", "fern", "pebble", "shell", "driftwood"]:
			gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func is_obstacle() -> bool:
	return KINDS[kind]["respawn"] <= 0.0


func block_radius() -> float:
	return KINDS[kind]["radius"] if active else 0.0


func interact_point() -> Vector3:
	return global_position + Vector3(0, 0.5, 0)


func tool_hint() -> String:
	return KINDS[kind]["tool"]


func get_hint() -> String:
	var cfg: Dictionary = KINDS[kind]
	if kind == "palm" and not Game.has_tool("stone_axe"):
		return "Потрясти пальму (листья и кокосы)" if coconut_ready else "Кокосы ещё не выросли. Нужен топор, чтобы рубить"
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
	hp -= 1
	_hit_fx(player)
	if hp <= 0:
		for id in cfg["drops"]:
			Game.add_item(id, cfg["drops"][id])
		match kind:
			"palm":
				if coconut_ready and randf() < 0.6:
					Game.add_item("coconut", 1)
			"bush":
				if randf() < 0.22:
					Game.add_item(BUSH_SEEDS[randi() % BUSH_SEEDS.size()], 1)
			"shell":
				if randf() < 0.45:
					Game.add_collectible("shells")
		_deplete()


func _shake_palm() -> void:
	if not coconut_ready:
		return
	coconut_ready = false
	Audio.play("shake", -2.0, 0.1, global_position)
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
	get_tree().create_timer(60.0).timeout.connect(func():
		coconut_ready = true
		if crown and crown.get_node_or_null("Coconuts"):
			crown.get_node("Coconuts").visible = true)


const HIT_SOUND := {"palm": "chop", "driftwood": "chop", "rock": "rock", "pebble": "rock", "bush": "rustle", "shell": "pickup",
	"jungle_tree": "chop", "fallen_log": "chop", "bamboo": "chop", "cliff": "rock", "thicket": "rustle", "fern": "rustle", "tall_grass": "rustle", "liana_curtain": "rustle", "clay": "plant"}


func _hit_fx(_player: Node) -> void:
	Audio.play(HIT_SOUND.get(kind, "pickup"), -2.0, 0.12, global_position)
	var tw := create_tween()
	var dir := 1.0 if randf() < 0.5 else -1.0
	tw.tween_property(visual, "rotation:z", 0.12 * dir, 0.05)
	tw.tween_property(visual, "rotation:z", -0.06 * dir, 0.08)
	tw.tween_property(visual, "rotation:z", 0.0, 0.1)
	var colors := {"palm": Color("c9a26b"), "bush": Color("4fae3c"), "rock": Color("a0a4a8"), "cliff": Color("a0a4a8"),
		"jungle_tree": Color("c9a26b"), "fallen_log": Color("c9a26b"), "bamboo": Color("c9c46a"),
		"thicket": Color("3c7a40"), "fern": Color("4f9a4a"), "tall_grass": Color("8fa850")}
	FX.burst(self, Vector3(0, minf(KINDS[kind]["height"] * 0.3, 1.2), 0), colors.get(kind, Color("e9d8b0")))


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
	if is_obstacle():
		Game.bump("cleared", kind)
		if uid != "":
			Game.cleared[uid] = true
		tw.tween_callback(queue_free)
		return
	get_tree().create_timer(KINDS[kind]["respawn"]).timeout.connect(func(): _respawn(saved_layer))


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
