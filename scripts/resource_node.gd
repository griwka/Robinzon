class_name ResourceNode
extends StaticBody3D
## Ресурс на острове: пальма, куст, валун, камешек, коряга, ракушка.
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
		"verb": "Подобрать корягу", "radius": 0.4, "height": 0.4},
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
	# --- Грозовой остров
	"heather": {"hp": 1, "tool": "", "drops": {"fiber": 1}, "respawn": 0.0,
		"verb": "Вырвать вереск", "radius": 0.7, "height": 0.9},
	"blueberry": {"hp": 1, "tool": "", "drops": {"blueberry": 2}, "respawn": 55.0,
		"verb": "Собрать чернику", "radius": 0.6, "height": 0.7},
	"crooked_tree": {"hp": 4, "tool": "stone_axe", "drops": {"wood": 4}, "respawn": 0.0,
		"verb": "Срубить кривое дерево", "radius": 0.8, "height": 4.0},
	"scrap_pile": {"hp": 2, "tool": "", "drops": {"scrap": 1}, "respawn": 80.0,
		"verb": "Разобрать кучу ржавого железа", "radius": 0.8, "height": 0.8},
	"sand": {"hp": 1, "tool": "shovel", "drops": {"sand": 2}, "respawn": 50.0,
		"verb": "Накопать песка", "radius": 0.7, "height": 0.2},
	"rockfall": {"hp": 5, "tool": "pickaxe", "drops": {"stone": 5}, "respawn": 0.0,
		"verb": "Разобрать обвал", "radius": 0.9, "height": 1.8, "long": 1.7},
	# --- Ледяной остров
	"moss": {"hp": 1, "tool": "", "drops": {"fiber": 1}, "respawn": 0.0,
		"verb": "Сорвать мох", "radius": 0.6, "height": 0.6},
	"lingonberry": {"hp": 1, "tool": "", "drops": {"lingonberry": 2, "fiber": 1}, "respawn": 60.0,
		"verb": "Собрать бруснику", "radius": 0.55, "height": 0.6},
	"pine": {"hp": 3, "tool": "stone_axe", "drops": {"wood": 3, "resin": 1}, "respawn": 150.0,
		"verb": "Срубить сосну (дрова и смола)", "radius": 0.5, "height": 5.0},
	"ice_block": {"hp": 2, "tool": "ice_pick", "drops": {"ice": 2}, "respawn": 90.0,
		"verb": "Наколоть льда", "radius": 0.7, "height": 1.1},
	"ice_wall": {"hp": 4, "tool": "ice_pick", "drops": {"ice": 2}, "respawn": 0.0,
		"verb": "Разбить ледяную стену", "radius": 0.9, "height": 2.4, "long": 1.75},
	# --- Остров Вулкана
	"aloe": {"hp": 1, "tool": "", "drops": {"aloe": 2}, "respawn": 60.0,
		"verb": "Нарвать алоэ", "radius": 0.5, "height": 0.7},
	"coffee_bush": {"hp": 1, "tool": "", "drops": {"coffee": 2}, "respawn": 70.0,
		"verb": "Собрать кофейные ягоды", "radius": 0.6, "height": 1.3},
	"charred_tree": {"hp": 3, "tool": "stone_axe", "drops": {"charcoal": 2, "wood": 1}, "respawn": 140.0,
		"verb": "Наколоть угля из горелого дерева", "radius": 0.5, "height": 3.6},
	"ore_vein": {"hp": 3, "tool": "pickaxe", "drops": {"ore": 2}, "respawn": 110.0,
		"verb": "Добыть руду", "radius": 0.8, "height": 1.2},
	"obsidian_rock": {"hp": 3, "tool": "iron_pickaxe", "drops": {"obsidian": 2}, "respawn": 100.0,
		"verb": "Отколоть обсидиан", "radius": 0.7, "height": 1.1},
	"basalt": {"hp": 5, "tool": "iron_pickaxe", "drops": {"stone": 4}, "respawn": 0.0,
		"verb": "Разбить базальтовые столбы", "radius": 0.9, "height": 2.6, "long": 1.5},
	# --- Туманный остров
	"mangrove": {"hp": 3, "tool": "stone_axe", "drops": {"mangrove_wood": 2}, "respawn": 150.0,
		"verb": "Срубить мангр (доски не гниют)", "radius": 0.7, "height": 4.5},
}
const MODEL_NAMES := {"tall_grass": ["tall_grass"], "fern": ["fern_a", "fern_b"], "thicket": ["thicket"],
	"bamboo": ["bamboo_clump"], "jungle_tree": ["jungle_tree_a", "jungle_tree_b"], "fallen_log": ["fallen_log"],
	"cliff": ["cliff_a", "cliff_b"], "liana_curtain": ["liana_curtain"], "clay": ["clay_pit"],
	"heather": ["heather_a", "heather_b"], "blueberry": ["blueberry_bush"], "crooked_tree": ["crooked_tree_a", "crooked_tree_b"],
	"scrap_pile": ["scrap_pile"], "sand": ["sand_pit"], "rockfall": ["rockfall"],
	"moss": ["moss_a", "moss_b"], "lingonberry": ["lingonberry_bush"], "pine": ["pine_a", "pine_b"],
	"ice_block": ["ice_block"], "ice_wall": ["ice_wall_a", "ice_wall_b"],
	"aloe": ["aloe_plant"], "coffee_bush": ["coffee_bush"], "charred_tree": ["charred_tree_a", "charred_tree_b"],
	"ore_vein": ["ore_vein"], "obsidian_rock": ["obsidian_rock"], "basalt": ["basalt_a", "basalt_b"],
	"mangrove": ["mangrove_a", "mangrove_b"]}
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
var _base_yaw := 0.0


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
		"tall_grass", "fern", "thicket", "bamboo", "jungle_tree", "fallen_log", "cliff", "liana_curtain", "clay", \
				"heather", "blueberry", "crooked_tree", "scrap_pile", "sand", "rockfall", \
				"moss", "lingonberry", "pine", "ice_block", "ice_wall", \
				"aloe", "coffee_bush", "charred_tree", "ore_vein", "obsidian_rock", "basalt", "mangrove":
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
	_base_yaw = visual.rotation.y
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
	if kind in ["pebble", "shell", "driftwood", "clay", "sand", "blueberry", "lingonberry", "aloe"]:
		collision_layer = 8  # мелочь не мешает ходить


func _setup_visibility() -> void:
	# дальние мелкие объекты не рисуем и не даём им тени — так тысяча растений не тормозит
	var far := 90.0 if kind in ["jungle_tree", "palm", "cliff", "bamboo", "crooked_tree", "rockfall", "pine", "ice_wall", "charred_tree", "basalt", "mangrove"] else 55.0
	for mi in visual.find_children("*", "GeometryInstance3D", true, false):
		var gi := mi as GeometryInstance3D
		gi.visibility_range_end = far
		gi.visibility_range_end_margin = 6.0
		gi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		if kind in ["tall_grass", "fern", "pebble", "shell", "driftwood", "heather", "sand", "moss"]:
			gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func is_obstacle() -> bool:
	return KINDS[kind]["respawn"] <= 0.0


func block_radius() -> float:
	return KINDS[kind]["radius"] if active else 0.0


func interact_point() -> Vector3:
	return global_position + Vector3(0, 0.5, 0)


func tool_hint() -> String:
	return KINDS[kind]["tool"]


## Своя подсказка (пальма: что будет — потрясти или срубить — зависит от того, что в руке) или "".
func key_hint() -> String:
	if kind == "palm" and Game.has_tool("stone_axe"):
		var key := Game.hold_slots().find("stone_axe") + 1
		var k := str(key % 10)
		if Game.held_tool() == "stone_axe":
			return "[ЛКМ / E]  Срубить пальму   ·   [%s]  убрать топор — потрясти" % k
		if coconut_ready:
			return "[ЛКМ / E]  Потрясти пальму   ·   [%s]  взять топор — срубить" % k
		return "Кокосы ещё не выросли   ·   [%s]  взять топор — срубить" % k
	return ""


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
	# пальму трясут пустыми руками (или с другим инструментом), рубят — с топором в руке
	if kind == "palm" and Game.held_tool() != "stone_axe":
		if coconut_ready:
			_shake_palm()
		else:
			Game.notified.emit("Кокосы ещё не выросли — загляни попозже" + ("" if not Game.has_tool("stone_axe") else ". Срубить — возьми топор"), Color("ffe08a"))
		return
	if cfg["tool"] != "" and not Game.has_tool(cfg["tool"]):
		Game.notified.emit("Нужен инструмент: %s" % Game.item_name(cfg["tool"]), Color("ff9d7a"))
		return
	if cfg["tool"] != "" and Game.frozen():
		Game.notified.emit("Руки замёрзли и не держат %s. Сначала согрейся у огня" % Game.item_name(cfg["tool"]).to_lower(), Color("bfe3ff"))
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
			"basalt", "obsidian_rock", "ore_vein":
				if randf() < 0.3:
					Game.add_collectible("volcano_stones")
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
	"jungle_tree": "chop", "fallen_log": "chop", "bamboo": "chop", "cliff": "rock", "thicket": "rustle", "fern": "rustle", "tall_grass": "rustle", "liana_curtain": "rustle", "clay": "plant",
	"heather": "rustle", "blueberry": "rustle", "crooked_tree": "chop", "scrap_pile": "metal", "sand": "plant", "rockfall": "rock",
	"moss": "rustle", "lingonberry": "rustle", "pine": "chop", "ice_block": "ice", "ice_wall": "ice",
	"aloe": "rustle", "coffee_bush": "rustle", "charred_tree": "chop", "ore_vein": "metal", "obsidian_rock": "ice", "basalt": "rock",
	"mangrove": "chop"}


const COLORS := {"palm": Color("c9a26b"), "bush": Color("4fae3c"), "rock": Color("a0a4a8"), "cliff": Color("a0a4a8"),
	"jungle_tree": Color("c9a26b"), "fallen_log": Color("c9a26b"), "bamboo": Color("c9c46a"), "pebble": Color("a0a4a8"),
	"thicket": Color("3c7a40"), "fern": Color("4f9a4a"), "tall_grass": Color("8fa850"), "liana_curtain": Color("5a9a3a"),
	"driftwood": Color("d8c3a0"), "shell": Color("f7d6c4"), "clay": Color("b8623a"),
	"heather": Color("b07ab8"), "blueberry": Color("4a5ab8"), "crooked_tree": Color("8a6a4a"), "scrap_pile": Color("9a7a5a"),
	"sand": Color("ecd29a"), "rockfall": Color("8a8a90"),
	"moss": Color("8fa060"), "lingonberry": Color("d8343a"), "pine": Color("8a6a4a"), "ice_block": Color("cfeefa"), "ice_wall": Color("cfeefa"),
	"aloe": Color("6fbf7a"), "coffee_bush": Color("c8302a"), "charred_tree": Color("3a3634"), "ore_vein": Color("a0624a"),
	"obsidian_rock": Color("3a2a5a"), "basalt": Color("5a5658"), "mangrove": Color("7a5a3a")}
const STONE := ["rock", "cliff", "pebble", "rockfall", "scrap_pile", "ice_block", "ice_wall", "ore_vein", "obsidian_rock", "basalt"]
const WOOD := ["palm", "jungle_tree", "fallen_log", "bamboo", "driftwood", "crooked_tree", "pine", "charred_tree", "mangrove"]
const HEAVY := ["rock", "cliff", "jungle_tree", "palm", "fallen_log", "bamboo", "crooked_tree", "rockfall", "pine", "ice_wall",
	"charred_tree", "basalt", "obsidian_rock"]
var _hit_tw: Tween
var _hitter: Node


func _hit_fx(player: Node) -> void:
	_hitter = player
	Audio.play(HIT_SOUND.get(kind, "pickup"), -2.0, 0.12, global_position)
	# отклик: предмет сплющивается и пружинит обратно, качается и коротко вспыхивает
	if _hit_tw and _hit_tw.is_valid():
		_hit_tw.kill()
	var dir := 1.0 if randf() < 0.5 else -1.0
	visual.scale = _base_scale * Vector3(1.1, 0.88, 1.1)
	_hit_tw = create_tween()
	_hit_tw.tween_property(visual, "scale", _base_scale, 0.32).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_hit_tw.parallel().tween_property(visual, "rotation:z", 0.12 * dir, 0.05)
	_hit_tw.chain().tween_property(visual, "rotation:z", 0.0, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	FX.flash(visual, 0.85, 0.16)
	var cfg: Dictionary = KINDS[kind]
	var h := minf(float(cfg["height"]) * 0.3, 1.2)
	var side := Vector3.ZERO
	if player is Node3D:
		side = (player as Node3D).global_position - global_position
		side.y = 0.0
		side = side.normalized() * float(cfg["radius"]) * 0.8 if side.length() > 0.01 else Vector3.ZERO
	var at := Vector3(0, h, 0) + side
	var col: Color = COLORS.get(kind, Color("e9d8b0"))
	if kind in STONE:
		FX.sparks(self, at, 8)
		FX.burst(self, at, col, 8)
	elif kind in WOOD:
		FX.burst(self, at, col, 10)
		if kind in ["palm", "jungle_tree", "crooked_tree", "pine"]:
			FX.leaves(self, Vector3(0, float(cfg["height"]) * 0.8, 0), Color("4f7a4a") if kind == "pine" else Color("4f9a4a"), 5)
	else:
		FX.leaves(self, at, col, 7)
		FX.puff(self, at, col.lerp(Color("f4ead2"), 0.6), 3, 0.35, 0.9, 0.5)
	if player and player.has_method("add_trauma"):
		player.add_trauma(0.13 if kind in HEAVY else 0.05)
	if kind in HEAVY:
		FX.hitstop(self, 0.035)


func _deplete() -> void:
	active = false
	remove_from_group("interactable")
	var saved_layer := collision_layer
	collision_layer = 0
	if _hit_tw and _hit_tw.is_valid():
		_hit_tw.kill()
	var cfg: Dictionary = KINDS[kind]
	var col: Color = COLORS.get(kind, Color("e9d8b0"))
	var big := kind in HEAVY or kind in ["thicket", "liana_curtain"]
	var tw := create_tween()
	if kind in ["palm", "jungle_tree", "crooked_tree", "pine", "charred_tree", "mangrove"]:
		# дерево валится от игрока, бьётся о землю: пыль кольцом, глухой удар, тряска
		var away := Vector3.FORWARD
		if _hitter is Node3D:
			away = global_position - (_hitter as Node3D).global_position
			away.y = 0.0
			away = away.normalized() if away.length() > 0.01 else Vector3.FORWARD
		var axis := Vector3.UP.cross(away).normalized()
		var fallen := Basis(axis, PI / 2.2) * visual.transform.basis
		tw.tween_property(visual, "transform:basis", fallen, 0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(func():
			FX.ring(self, away * float(cfg["height"]) * 0.55 + Vector3(0, 0.1, 0), Color("e6dcc0"), 1.4, 16)
			Audio.play("thud", -2.0, 0.1, global_position)
			if _hitter and _hitter.has_method("add_trauma"):
				_hitter.add_trauma(0.35))
		tw.tween_interval(0.15)
		tw.tween_property(visual, "scale", Vector3(0.01, 0.01, 0.01), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	else:
		# «пуф»: чуть раздувается и схлопывается в облачко
		tw.tween_property(visual, "scale", _base_scale * 1.12, 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(visual, "scale", Vector3(0.01, 0.01, 0.01), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		var size := clampf(float(cfg["radius"]) * 1.2, 0.5, 1.6)
		FX.poof(self, Vector3(0, float(cfg["height"]) * 0.35, 0), col, size)
		if big:
			if kind in STONE:
				Audio.play("thud", -6.0, 0.15, global_position)
			if _hitter and _hitter.has_method("add_trauma"):
				_hitter.add_trauma(0.22)
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
	visual.transform.basis = Basis(Vector3.UP, _base_yaw)
	visual.visible = true
	visual.scale = Vector3(0.01, 0.01, 0.01)
	var tw := create_tween()
	tw.tween_property(visual, "scale", _base_scale, 1.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	collision_layer = layer
	active = true
	add_to_group("interactable")
