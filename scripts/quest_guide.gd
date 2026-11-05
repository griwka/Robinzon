class_name QuestGuide
extends Node
## Подсказка «куда идти» по текущему заданию: компас вверху экрана (стрелка, название, метры)
## и метка над целью в мире, видная издалека и сквозь заросли.
## Цель ищется сама: среди интерактивных объектов острова — ближайший, который нужен заданию.

const NAMES := {"tall_grass": "Высокая трава", "fern": "Папоротник", "thicket": "Колючие заросли",
	"bamboo": "Бамбук", "jungle_tree": "Дерево-гигант", "fallen_log": "Поваленный ствол", "cliff": "Каменная гряда",
	"rock": "Валун", "liana_curtain": "Завеса лиан", "clay": "Глина", "palm": "Пальма", "bush": "Куст",
	"pebble": "Камешки", "driftwood": "Плавник", "shell": "Ракушки"}
const REFRESH := 0.3

var hud: HUD
var player: Player
var target: Node3D = null
var target_name := ""
var _t := 0.0
var _keys: Array[String] = []

var panel: PanelContainer
var arrow: Control
var label: Label
var beacon: Node3D


func setup(h: HUD, p: Player) -> void:
	hud = h
	player = p
	_build_compass()
	_build_beacon()
	Game.quest_changed.connect(func(): _t = REFRESH)


# ------------------------------------------------------------------ Поиск цели
## Какие пункты задания может закрыть этот объект.
static func keys_for(n: Node) -> Array[String]:
	var out: Array[String] = []
	if n is StoryPlace:
		for k in ["found", "lit", "restored"]:
			out.append(k + ":" + n.id)
	elif n is NPCPerson:
		out.append_array(["talk:" + n.npc_id, "give:" + n.npc_id])
		out.append_array(_trade_keys(NPCPerson.SHOP.get(n.npc_id, "")))
	elif n is NPCParrot:
		out.append("talk:parrot")
		out.append_array(_trade_keys("rumba"))
	elif n is SupplyCrate:
		out.append_array(["found:crate", "collected:crate"])
	elif n is FishingSpot:
		out.append("fished:fish")
	elif n is FortRuin.Lever:
		out.append("solved:cellar")
	elif n is ResourceNode:
		if not n.active:
			return out
		out.append("cleared:" + n.kind)
		for d in ResourceNode.KINDS[n.kind]["drops"]:
			out.append("collected:" + d)
	elif n is FruitTree:
		if n.wild and n.grow >= 1.0:
			out.append("collected:" + Data.TREES[n.tree_type]["fruit"])
	return out


static func _trade_keys(shop: String) -> Array[String]:
	var out: Array[String] = []
	if shop == "" or not Game.shop_open(shop):
		return out
	out.append_array(["sold:any", "sold:" + shop, "bought:any"])
	for e in Game.shop_items(shop):
		out.append("bought:" + e["item"])
	return out


static func name_of(n: Node) -> String:
	if n is StoryPlace:
		return StoryPlace.PLACES[n.id]["name"]
	if n is NPCPerson:
		return Data.SPEAKERS.get(n.npc_id, {}).get("name", n.npc_id)
	if n is NPCParrot:
		return "Попугай Румба"
	if n is SupplyCrate:
		return "Ящик с «Альбатроса»"
	if n is FishingSpot:
		return "Место для рыбалки"
	if n is FortRuin.Lever:
		return "Рычаги в подвале"
	if n is ResourceNode:
		return NAMES.get(n.kind, n.kind)
	if n is FruitTree:
		return Data.TREES[n.tree_type]["name"]
	return ""


## Ближайшая цель для первого пункта задания, у которого цель есть на этом острове.
func _find_target() -> void:
	target = null
	target_name = ""
	_keys = Game.pending_keys()
	if _keys.is_empty():
		return
	var me := player.global_position
	for key in _keys:
		if key.begins_with("reached:deck"):
			var lianas := get_tree().get_nodes_in_group("climb")
			var idx := int(key.substr(12)) - 1
			if idx >= 0 and idx < lianas.size():
				target = lianas[idx]
				target_name = "Лиана на %d-й ярус" % (idx + 1)
				return
			continue
		var best: Node3D = null
		var best_d := INF
		for n in get_tree().get_nodes_in_group("interactable"):
			if not (n is Node3D) or not keys_for(n).has(key):
				continue
			var d := (n as Node3D).global_position.distance_squared_to(me)
			if d < best_d:
				best_d = d
				best = n
		if best:
			target = best
			target_name = name_of(best)
			return


func target_position() -> Vector3:
	if target == null or not is_instance_valid(target):
		return Vector3.ZERO
	if target is Climbable:
		return (target as Climbable).world_bottom()
	return target.global_position


func has_target() -> bool:
	return target != null and is_instance_valid(target)


# ------------------------------------------------------------------ Компас
func _build_compass() -> void:
	panel = PanelContainer.new()
	var sb := hud._box(HUD.WOOD, HUD.WOOD_DARK, 14, 3, 8)
	sb.content_margin_left = 12
	sb.content_margin_right = 16
	panel.add_theme_stylebox_override("panel", sb)
	panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.position.y = 18
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.root.add_child(panel)
	hud.root.move_child(panel, 0)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	panel.add_child(h)
	arrow = Control.new()
	arrow.custom_minimum_size = Vector2(34, 34)
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arrow.draw.connect(_draw_arrow)
	h.add_child(arrow)
	label = hud._label("", 19)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(label)
	panel.visible = false


func _draw_arrow() -> void:
	var c := arrow.size * 0.5
	var rot := arrow.get_meta("rot", 0.0) as float
	var pts := PackedVector2Array([Vector2(0, -15), Vector2(11, 10), Vector2(0, 4), Vector2(-11, 10)])
	var out := PackedVector2Array()
	for p in pts:
		out.append(c + p.rotated(rot))
	var ring := PackedVector2Array()
	for p in pts:
		ring.append(c + (p * 1.18).rotated(rot))
	arrow.draw_colored_polygon(ring, HUD.WOOD_DARK)
	arrow.draw_colored_polygon(out, Color("ffd84a"))


# ------------------------------------------------------------------ Метка в мире
func _build_beacon() -> void:
	beacon = Node3D.new()
	beacon.name = "QuestBeacon"
	var bubble := Sprite3D.new()
	bubble.texture = FX.icon_texture("bubble")
	bubble.fixed_size = true
	bubble.pixel_size = 0.00034
	bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bubble.no_depth_test = true
	bubble.shaded = false
	bubble.render_priority = 10
	bubble.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beacon.add_child(bubble)
	var icon := Sprite3D.new()
	icon.texture = FX.icon_texture("exclaim")
	icon.fixed_size = true
	icon.pixel_size = 0.00022
	icon.offset = Vector2(0, 8)
	icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	icon.no_depth_test = true
	icon.shaded = false
	icon.render_priority = 11
	icon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beacon.add_child(icon)
	beacon.visible = false
	add_child(beacon)


## Высота метки над целью: над деревьями и маяками — выше.
func _beacon_height() -> float:
	if target is StoryPlace:
		return 6.5 if StoryPlace.PLACES[target.id].has("fuel") else 2.8
	if target is ResourceNode:
		return ResourceNode.KINDS[target.kind]["height"] + 0.8
	if target is FruitTree:
		return 4.6
	if target is Climbable:
		return 2.2
	if target is NPCParrot:
		return 1.2
	return 2.4


# ------------------------------------------------------------------ Кадр
func _process(delta: float) -> void:
	_t += delta
	if _t >= REFRESH:
		_t = 0.0
		_find_target()
	var show := has_target() and hud.visible and not hud.any_open() and player.camera.current
	var tp := target_position()
	var to := tp - player.global_position
	var dist := Vector2(to.x, to.z).length()
	if show and dist < 3.0:
		show = false   # уже на месте
	panel.visible = show
	# у попугая и жителей свой значок «!» — второй не нужен
	var own_marker: bool = has_target() and target.get("marker") is Node3D and (target.get("marker") as Node3D).visible
	beacon.visible = show and not own_marker
	if not show:
		return
	beacon.global_position = tp + Vector3(0, _beacon_height() + sin(Time.get_ticks_msec() / 300.0) * 0.12, 0)
	# стрелка: направление на цель относительно взгляда камеры
	var cam_fwd := -player.camera.global_transform.basis.z
	var a_cam := atan2(cam_fwd.x, -cam_fwd.z)
	var a_tgt := atan2(to.x, -to.z)
	arrow.set_meta("rot", wrapf(a_tgt - a_cam, -PI, PI))
	arrow.queue_redraw()
	label.text = "%s · %d м" % [target_name, int(round(dist))] if target_name != "" else "%d м" % int(round(dist))
