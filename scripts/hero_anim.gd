class_name HeroAnim
extends RefCounted
## Движения героя: клипы из Blender (assets/models/hero_anims.glb, tools/blender/anim.py) и AnimationTree,
## который плавно смешивает их.
##
## Дерево — «смеситель поз»: время каждого клипа ставит игра (шаг — по фазе шага, удар — по времени удара,
## прыжок — по скорости падения), а не часы анимации. Поэтому шаги совпадают со звуком шагов, удар — с откликом
## предмета, а поза в любой момент известна точно (это нужно автотесту инструмента в руке).
##
## Слои снизу вверх: стоит → ходьба → бег → вода (на месте / плывёт) → прыжок → приземление →
## инструмент в правой руке (только кости руки) → работа: ноги и бёдра (если стоит на месте) и верх тела → сон.

const SRC := "res://assets/models/hero_anims.glb"
const BONES := "Armature/Skeleton3D:"
const ARM_R := ["ShoulderR", "UpperArmR", "ForearmR", "HandR", "ToolR"]
const UPPER := ["Spine", "Chest", "Neck", "Skull", "ShoulderL", "UpperArmL", "ForearmL", "HandL",
	"ShoulderR", "UpperArmR", "ForearmR", "HandR", "ToolR"]
const LOWER := ["Hips", "ThighL", "ShinL", "FootL", "ThighR", "ShinR", "FootR"]
## клипы-источники: имя узла → клип по умолчанию
const CLIPS := {"idle": "idle", "walk": "walk", "run": "run", "float": "float", "swim": "swim", "air": "air", "land": "land",
	"carry": "carry", "work_low": "hands", "work_up": "hands", "sleep": "sleep"}
## слои: [имя, нижний слой, что подмешиваем, какие кости (пусто — все)]
const LAYERS := [
	["walk", "idle", "walk", []], ["run", "L_walk", "run", []], ["swimmove", "float", "swim", []],
	["water", "L_run", "L_swimmove", []], ["air", "L_water", "air", []], ["land", "L_air", "land", []],
	["carry", "L_land", "carry", ARM_R], ["work_low", "L_carry", "work_low", LOWER], ["work_up", "L_work_low", "work_up", UPPER],
	["sleep", "L_work_up", "sleep", []],
]
## чем работаем → клип
const WORK := {"stone_axe": "hit_axe", "iron_axe": "hit_axe", "pickaxe": "hit_pick", "iron_pickaxe": "hit_pick", "ice_pick": "hit_pick",
	"machete": "hit_machete", "iron_machete": "hit_machete", "shovel": "hit_shovel", "watering_can": "hit_can", "net": "hit_net",
	"fishing_rod": "hit_rod", "ice_drill": "hit_drill", "weed": "weed"}

var player: AnimationPlayer
var tree: AnimationTree
var _len := {}            # клип → длина
var _node := {}           # имя узла-источника → AnimationNodeAnimation
var _work_up: AnimationNodeBlend2
var _tool_moves := true
var _changed := false     # сменился клип или набор костей: дерево после этого сбрасывает свои настройки


func setup(root: Node3D) -> bool:
	if not ResourceLoader.exists(SRC):
		return false
	var src: Node = (load(SRC) as PackedScene).instantiate()
	var found := src.find_children("*", "AnimationPlayer", true, false)
	if found.is_empty():
		src.free()
		return false
	var lib: AnimationLibrary = (found[0] as AnimationPlayer).get_animation_library("")
	src.free()
	for a in lib.get_animation_list():
		_len[str(a)] = lib.get_animation(a).length
	player = AnimationPlayer.new()
	player.name = "AnimationPlayer"
	root.add_child(player)
	player.add_animation_library("", lib)
	var bt := AnimationNodeBlendTree.new()
	for nm: String in CLIPS:
		var an := AnimationNodeAnimation.new()
		an.animation = CLIPS[nm]
		bt.add_node("A_" + nm, an)
		bt.add_node(nm, AnimationNodeTimeSeek.new())
		bt.connect_node(nm, 0, "A_" + nm)
		_node[nm] = an
	var last := ""
	for l: Array in LAYERS:
		var b := AnimationNodeBlend2.new()
		var bones: Array = l[3]
		if not bones.is_empty():
			b.filter_enabled = true
			for bone: String in bones:
				b.set_filter_path(NodePath(BONES + bone), true)
		last = "L_" + str(l[0])
		bt.add_node(last, b)
		bt.connect_node(last, 0, str(l[1]))
		bt.connect_node(last, 1, str(l[2]))
		if l[0] == "work_up":
			_work_up = b
	bt.connect_node("output", 0, last)
	tree = AnimationTree.new()
	tree.name = "AnimationTree"
	tree.tree_root = bt
	tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	root.add_child(tree)
	tree.anim_player = NodePath("../AnimationPlayer")
	tree.active = true
	return true


## Какой клип играет узел-источник ("carry" — как несут, "work_up" / "work_low" — работа).
func use(node: String, clip: String) -> void:
	var an: AnimationNodeAnimation = _node[node]
	if an.animation != StringName(clip) and _len.has(clip):
		an.animation = clip
		_changed = true


## Клип работы; tool_moves — инструмент ведёт сам клип (удар), иначе он остаётся в руке как был (сбор руками).
func work(kind: String, tool_moves: bool) -> void:
	var clip: String = WORK.get(kind, "hands")
	use("work_up", clip)
	use("work_low", clip)
	if tool_moves != _tool_moves:
		_tool_moves = tool_moves
		_work_up.set_filter_path(NodePath(BONES + "ToolR"), tool_moves)
		_changed = true


## Поставить позу: at — момент каждого клипа 0..1 (имя узла-источника → доля), mix — сила слоёв 0..1.
func pose(at: Dictionary, mix: Dictionary) -> void:
	# после смены клипа дерево при первом же расчёте сбрасывает настройки — тогда ставим позу ещё раз
	for pass_i in (2 if _changed else 1):
		for nm: String in at:
			var an: AnimationNodeAnimation = _node[nm]
			tree.set("parameters/%s/seek_request" % nm, clampf(float(at[nm]), 0.0, 1.0) * float(_len[str(an.animation)]))
		for nm: String in mix:
			tree.set("parameters/L_%s/blend_amount" % nm, clampf(float(mix[nm]), 0.0, 1.0))
		tree.advance(0.0)
	_changed = false
