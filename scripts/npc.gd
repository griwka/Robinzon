class_name NPCParrot
extends StaticBody3D
## Попугай Румба — проводник по сюжету. Сидит на мачте разбитой лодки.

const IDLE_LINES := [
	"Карр! Не забывай поливать грядки!",
	"Говорят, на вершине горы видно соседние острова...",
	"Бананы! Бананы! Это я так, вспомнил.",
	"Ночью у костра так уютно. Почти как в гнезде.",
	"Ракушки бывают редкие. Жемчужину я видел только раз!",
	"Куры любят кукурузу. Я тоже. Но я не курица!",
]

var model: Node3D
var head: Node3D
var body: Node3D
var marker: Node3D
var _t := 0.0
var _squawk_t := 8.0


func _ready() -> void:
	add_to_group("interactable")
	collision_layer = 4
	model = Models.parrot()
	add_child(model)
	body = model.get_node("Body")
	head = body.get_node("Head")
	var cs := CollisionShape3D.new()
	var s := SphereShape3D.new()
	s.radius = 0.3
	cs.shape = s
	cs.position.y = 0.3
	add_child(cs)
	marker = FX.marker(self, 1.0)
	Game.quest_changed.connect(_update_marker)
	_update_marker()


func _talk_pending() -> bool:
	var q := Game.current_quest()
	if q.is_empty() or not Game.quest_started:
		return false
	for t in q["tasks"]:
		if t["kind"] == "talk" and Game.task_progress(t) < t["count"]:
			return true
	return false


func _update_marker() -> void:
	FX.set_marker(marker, _talk_pending(), "exclaim")


func _process(delta: float) -> void:
	_t += delta
	head.rotation.z = sin(_t * 0.9) * 0.25
	head.rotation.x = sin(_t * 1.7) * 0.1
	body.position.y = abs(sin(_t * 2.0)) * 0.02
	var flap := maxf(0.0, sin(_t * 0.6)) > 0.97
	var wl := body.get_node("WingL")
	var wr := body.get_node("WingR")
	wl.rotation.z = (-0.9 if flap else 0.0) + sin(_t * 30.0) * (0.4 if flap else 0.0)
	wr.rotation.z = -wl.rotation.z
	if marker.visible:
		marker.position.y = 1.0 + sin(_t * 3.0) * 0.08
	# смотрит на игрока и иногда кричит
	var p := get_tree().get_first_node_in_group("player") as Node3D
	_squawk_t -= delta
	if _squawk_t <= 0.0:
		_squawk_t = randf_range(12.0, 30.0)
		Audio.play("squawk", -8.0, 0.15, global_position)
	if p:
		var to := p.global_position - global_position
		model.rotation.y = lerp_angle(model.rotation.y, atan2(-to.x, -to.z), 2.0 * delta)


func interact_point() -> Vector3:
	return global_position + Vector3(0, -1.0, 0)


func tool_hint() -> String:
	return ""


func get_hint() -> String:
	return "Поговорить с попугаем Румбой"


func interact(_player: Node) -> void:
	Audio.play("squawk", -2.0, 0.1)
	if _talk_pending():
		Game.bump("talk", "parrot")
		return
	var q := Game.current_quest()
	var lines := [["parrot", IDLE_LINES[randi() % IDLE_LINES.size()]]]
	if not q.is_empty():
		for t in q["tasks"]:
			if Game.task_progress(t) < t["count"]:
				lines.append(["parrot", "Сейчас главное — %s. Карр!" % t["text"].to_lower()])
				break
	Game.bump("talk", "parrot_idle")
	if Game.shop_open("rumba"):
		Game.choice_requested.emit("Попугай Румба", [
			{"text": "Торговать", "icon": "coins", "callback": func(): Game.shop_requested.emit("rumba")},
			{"text": "Поговорить", "icon": "portrait_parrot", "callback": func(): Game.dialogue_requested.emit(lines, Callable())}])
		return
	Game.dialogue_requested.emit(lines, Callable())
