class_name NPCPerson
extends StaticBody3D
## Житель острова (Марта и будущие выжившие с «Альбатроса»): говорит, принимает предметы по заданию.

const IDLE := {
	"marta": [
		"Огонь — как суп: отвернёшься, и всё, пригорел. Или погас.",
		"Лёва ел всё подряд и хвалил. Ужасный критик, золотое сердце.",
		"Румба! Не клюй корзину с манго, я вижу!",
		"Ночью отсюда видно твой маяк. Мне стало спокойнее.",
	],
	"kesha": ["Ук-ук!", "Кешью почёсывает за ухом и косится на твою сумку.", "Кешью делает вид, что спит. Одним глазом."],
	"stepa": [
		"Море тихое — значит, жди беды. Это я тебе как боцман говорю.",
		"Трубку не трогай. Это не трубка, это память.",
		"Рыба клюёт у камней, где вода бурлит. Не у берега, а у камней!",
		"Твой брат пересаливал суп. Марта тебе не говорила? Говорила, конечно.",
	],
	"timur": [
		"ПРИЁМ! А, это ты. Связь — это когда тебя слышат. Остальное — шум.",
		"Если долго слушать эфир, кто-нибудь обязательно ответит. Я проверял. Два года проверяю.",
		"Нога? Пустяки. Упал в шахту с третьего яруса. Зато теперь я точно знаю, сколько там метров!",
		"Гуси меня не слушаются. Зато я их слышу. ВСЕГДА.",
		"Молния бьёт в громоотвод — а у меня мурашки. Красота же!",
	],
	"ingrid": [
		"До заката четыре часа двенадцать минут. Я не считаю. Само считается.",
		"Пингвины встают в шесть. Я — в пять пятьдесят. Кто-то должен быть первым.",
		"Лёва спорил со мной о звёздах. Три раза был неправ, на четвёртый — прав. Я записала.",
		"Тимур звонит каждый вечер. Я не отвечаю. Но слушаю.",
		"Не стой на ветру. Ветер здесь — минус десять сверху.",
	],
	"vera": [
		"Пейте чай. Нет, не этот, этот для черепах. Шучу. Или нет.",
		"Лечу травами, горячей водой и подзатыльниками. Подзатыльники помогают лучше всего.",
		"Малыш опять съел мои тапки. Ему сто сорок лет, а ума как у телёнка.",
		"Тимур звонит каждый вечер и спрашивает про кофе. Я ему не отвечаю. Пусть помучается.",
		"Лава — она как люди: пока остывшая корка, кажется спокойной.",
	],
	"walrus": [
		"Морж приоткрывает один глаз, вздыхает и снова засыпает.",
		"Хр-р-р... Фр-р-р... Усы шевелятся в такт храпу.",
		"Морж смотрит на тебя, как на пустую тарелку.",
	],
	"penguins": [
		"Пингвины выстроились в ряд и смотрят на твою сумку.",
		"Один пингвин поскользнулся. Остальные сделали вид, что так и было задумано.",
		"Пингвины ворчат. Наверное, о погоде. Или о тебе.",
	],
}
const MODELS := {"marta": "marta", "kesha": "monkey", "stepa": "stepa", "timur": "timur", "ingrid": "ingrid",
	"walrus": "walrus", "penguins": "penguin_feeder", "vera": "vera"}
const SHOP := {"marta": "marta", "stepa": "stepa", "timur": "timur", "ingrid": "ingrid", "vera": "vera"}
## Звери: говорит рассказчик, к игроку не поворачиваются, подсказка — своя.
const BEASTS := ["walrus", "penguins"]

var npc_id := "marta"
var model: Node3D
var head: Node3D
var _t := 0.0


func _ready() -> void:
	add_to_group("interactable")
	collision_layer = 4
	model = Models.glb(MODELS.get(npc_id, npc_id))
	if model:
		add_child(model)
		var body := model.get_node_or_null("Body")
		head = body.get_node_or_null("Head") if body else null
	var cs := CollisionShape3D.new()
	if npc_id == "walrus":
		# морж лежит поперёк тропы: длинная туша
		var bx := BoxShape3D.new()
		bx.size = Vector3(3.0, 1.3, 1.5)
		cs.shape = bx
		cs.position.y = 0.65
	elif npc_id == "penguins":
		var cy := CylinderShape3D.new()
		cy.radius = 0.5
		cy.height = 0.8
		cs.shape = cy
		cs.position.y = 0.4
	else:
		var c := CapsuleShape3D.new()
		c.radius = 0.35 if npc_id != "kesha" else 0.25
		c.height = 1.7 if npc_id != "kesha" else 0.8
		cs.shape = c
		cs.position.y = 0.85
	add_child(cs)


func _process(delta: float) -> void:
	_t += delta
	if head:
		head.rotation.z = sin(_t * 0.8) * 0.12
		head.rotation.x = sin(_t * 1.3) * 0.05
	if npc_id in BEASTS:
		if head and npc_id == "walrus":
			head.rotation.x = sin(_t * 0.7) * 0.06 - 0.05   # дышит во сне
		return
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if p and model and p.global_position.distance_to(global_position) < 6.0:
		var to := p.global_position - global_position
		model.rotation.y = lerp_angle(model.rotation.y, atan2(-to.x, -to.z) - rotation.y, 3.0 * delta)


func interact_point() -> Vector3:
	return global_position + Vector3(0, 0.6 if npc_id in BEASTS else 0.9, 0)


func tool_hint() -> String:
	return ""


func get_hint() -> String:
	if npc_id == "walrus":
		if Game.flags.get("walrus_moved", false):
			return "Морж греется на солнышке"
		return "Морж спит поперёк тропы — %s" % ("покормить рыбой (есть: %d)" % Game.count("fish") if _wants("walrus") else "не проснётся без угощения")
	if npc_id == "penguins":
		return "Кормушка пингвинов — %s" % ("покормить рыбой (есть: %d)" % Game.count("fish") if _wants("penguins") else "пингвины смотрят на тебя")
	return "Поговорить: %s" % Data.SPEAKERS.get(npc_id, {}).get("name", npc_id)


## Ждёт ли этот житель что-то по текущему заданию.
func _wants(who: String) -> bool:
	var q := Game.current_quest()
	if q.is_empty() or not Game.quest_started:
		return false
	for t in q["tasks"]:
		if t["kind"] == "delivered" and t.get("to", "") == who and Game.task_progress(t) < t["count"]:
			return true
	return false


func interact(_player: Node) -> void:
	var q := Game.current_quest()
	if not q.is_empty() and Game.quest_started:
		for t in q["tasks"]:
			if t["kind"] == "talk" and t["target"] == npc_id and Game.task_progress(t) < t["count"]:
				Game.bump("talk", npc_id)
				return
	if Game.deliver_for_quest(npc_id):
		return
	var lines: Array = IDLE.get(npc_id, ["..."])
	var who := "narrator" if npc_id in BEASTS else npc_id
	if npc_id == "walrus" and _wants("walrus"):
		Game.notified.emit("Нужна рыба: морж съест пять штук", Color("ff9d7a"))
		return
	if npc_id == "penguins" and _wants("penguins"):
		Game.notified.emit("Нужна рыба: пингвинам — шесть штук", Color("ff9d7a"))
		return
	var say := func(): Game.dialogue_requested.emit([[who, lines[randi() % lines.size()]]], Callable())
	if SHOP.has(npc_id) and Game.shop_open(SHOP[npc_id]):
		Game.choice_requested.emit(Data.SPEAKERS[npc_id]["name"], [
			{"text": "Торговать", "icon": "coins", "callback": func(): Game.shop_requested.emit(SHOP[npc_id])},
			{"text": "Поговорить", "icon": "portrait_" + npc_id, "callback": say}])
		return
	say.call()
