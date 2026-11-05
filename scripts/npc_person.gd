class_name NPCPerson
extends StaticBody3D
## Житель острова (Мелани и будущие выжившие с «Альбатроса»): говорит, принимает предметы по заданию.

const IDLE := {
	"melanie": [
		"Огонь — как суп: отвернёшься, и всё, пригорел. Или погас.",
		"Лёва ел всё подряд и хвалил. Ужасный критик, золотое сердце.",
		"Румба! Не клюй корзину с манго, я вижу!",
		"Ночью отсюда видно твой маяк. Мне стало спокойнее.",
	],
}

var npc_id := "melanie"
var model: Node3D
var head: Node3D
var _t := 0.0


func _ready() -> void:
	add_to_group("interactable")
	collision_layer = 4
	model = Models.glb(npc_id)
	if model:
		add_child(model)
		var body := model.get_node_or_null("Body")
		head = body.get_node_or_null("Head") if body else null
	var cs := CollisionShape3D.new()
	var c := CapsuleShape3D.new()
	c.radius = 0.35
	c.height = 1.7
	cs.shape = c
	cs.position.y = 0.85
	add_child(cs)


func _process(delta: float) -> void:
	_t += delta
	if head:
		head.rotation.z = sin(_t * 0.8) * 0.12
		head.rotation.x = sin(_t * 1.3) * 0.05
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if p and model and p.global_position.distance_to(global_position) < 6.0:
		var to := p.global_position - global_position
		model.rotation.y = lerp_angle(model.rotation.y, atan2(-to.x, -to.z) - rotation.y, 3.0 * delta)


func interact_point() -> Vector3:
	return global_position + Vector3(0, 0.9, 0)


func tool_hint() -> String:
	return ""


func get_hint() -> String:
	return "Поговорить: %s" % Data.SPEAKERS.get(npc_id, {}).get("name", npc_id)


func interact(_player: Node) -> void:
	var q := Game.current_quest()
	if not q.is_empty() and Game.quest_started:
		for t in q["tasks"]:
			if t["kind"] == "talk" and t["target"] == npc_id and Game.task_progress(t) < t["count"]:
				Game.bump("talk", npc_id)
				return
	if Game.deliver_for_quest():
		return
	var lines: Array = IDLE.get(npc_id, ["..."])
	Game.dialogue_requested.emit([[npc_id, lines[randi() % lines.size()]]], Callable())
