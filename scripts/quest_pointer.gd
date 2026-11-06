class_name QuestPointer
extends Node3D
## Указатель цели задания: если текущий пункт — найти место, зажечь или отстроить его, дойти куда-то
## или поговорить с жителем, который на этом острове, — над целью висит метка «!», видная сквозь лес,
## а в панели задания написано, куда идти и сколько метров. Цели на других островах не показываются:
## туда сначала надо приплыть (это сказано в тексте задания).

const SIDES := ["на востоке", "на юго-востоке", "на юге", "на юго-западе", "на западе", "на северо-западе", "на севере", "на северо-востоке"]

var main: Node
var hud: HUD
var _t := 0.0
var _bob := 0.0
var _mark: Node3D
var target_name := ""
var target_pos := Vector3.ZERO
var has_target := false


func _ready() -> void:
	name = "QuestPointer"
	_mark = Node3D.new()
	add_child(_mark)
	var bubble := Sprite3D.new()
	bubble.texture = FX.icon_texture("bubble")
	var icon := Sprite3D.new()
	icon.texture = FX.icon_texture("exclaim")
	icon.offset = Vector2(0, 8)
	for s in [bubble, icon]:
		var sp: Sprite3D = s
		sp.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sp.shaded = false
		sp.no_depth_test = true          # видно сквозь деревья и скалы
		sp.fixed_size = true             # одинакового размера вблизи и издалека
		sp.pixel_size = 0.00042 if sp == bubble else 0.00029
		sp.render_priority = 3 if sp == icon else 2
		sp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_mark.add_child(sp)
	_mark.visible = false
	Game.quest_changed.connect(func(): _t = 0.0)


func _process(delta: float) -> void:
	_t -= delta
	if _t <= 0.0:
		_t = 0.5
		_find()
	_bob += delta
	if has_target:
		_mark.global_position = target_pos + Vector3(0, 3.2 + sin(_bob * 2.5) * 0.15, 0)
		var p: Node3D = main.player
		var d := Vector2(target_pos.x - p.global_position.x, target_pos.z - p.global_position.z)
		_mark.visible = d.length() > 3.0
		var text := ""
		if d.length() > 6.0:
			# 0 — восток (+X), дальше по часовой при взгляде сверху: юг — +Z, запад — −X, север — −Z
			var sector := int(round(atan2(d.y, d.x) / (PI / 4.0))) % 8
			if sector < 0:
				sector += 8
			text = "➜ %s — %d м, %s" % [target_name, int(d.length()), SIDES[sector]]
		else:
			text = "➜ %s — рядом" % target_name
		hud.set_pointer(text)
	else:
		_mark.visible = false
		hud.set_pointer("")


## Ищем на этом острове цель первого невыполненного пункта задания.
func _find() -> void:
	has_target = false
	var q := Game.current_quest()
	if q.is_empty() or not Game.quest_started:
		return
	for t in q["tasks"]:
		if Game.task_progress(t) >= t["count"]:
			continue
		if t.has("where") and t["where"] != Game.location:
			continue
		var n := _node_for(t)
		if n != null:
			has_target = true
			target_pos = n.global_position
			return


func _node_for(t: Dictionary) -> Node3D:
	var kind: String = t["kind"]
	var tgt: String = t["target"]
	if kind in ["found", "lit", "restored"]:
		for n in get_tree().get_nodes_in_group("obstacle") + get_tree().get_nodes_in_group("interactable"):
			if n is StoryPlace and (n.id == tgt or (tgt == "ice_chest" and n.id.begins_with("ice_chest") and not Game.flags.get("poi_" + n.id, false))):
				target_name = StoryPlace.PLACES[n.id]["name"]
				return n
			if n is SupplyCrate and tgt == "crate":
				target_name = "Ящик с припасами"
				return n
		return null
	if kind == "talk" or (kind == "delivered" and t.has("to")):
		if t.get("radio", false):
			return null
		var who: String = t.get("to", tgt) if kind == "delivered" else tgt
		if who == "parrot":
			return null   # у Румбы свой значок «!» над головой
		for n in get_tree().get_nodes_in_group("interactable"):
			if n is NPCPerson and n.npc_id == who:
				target_name = Data.SPEAKERS.get(who, {}).get("name", who)
				return n
		return null
	if kind == "reached" and main.island.poi_extra.has(tgt):
		target_name = {"stilt_camp": "Лагерь на сваях", "temple_gate": "Вход в храм", "eye_tower": "Великий маяк"}.get(tgt, "Цель")
		_tmp_point = main.island.poi_extra[tgt]
		return _point_node()
	return null


var _tmp_point := Vector3.ZERO
var _point: Node3D


func _point_node() -> Node3D:
	if _point == null:
		_point = Node3D.new()
		add_child(_point)
	_point.global_position = _tmp_point
	return _point
