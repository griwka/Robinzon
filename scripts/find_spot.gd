class_name FindSpot
extends StaticBody3D
## Находка, которой нет в заданиях, — награда за то, что заглянул подальше:
## бутылка с запиской на пляже или тайник команды «Альбатроса» в чаще.
## Над ненайденной находкой поблёскивают искорки. Найденное отмечается флагом find_<остров>_<номер>
## и остаётся на карте. Монет в находках нет: монеты зарабатываются хозяйством.

const LOOT := {
	"bottle": [{"seed_tomato": 2, "fiber": 3}, {"seed_cabbage": 2, "shell": 2}, {"seed_watermelon": 1, "rope": 1},
		{"seed_corn": 2, "leaf": 3}],
	"stash": [{"rope": 3, "plank": 3, "seed_watermelon": 1}, {"plank": 4, "sapling_lemon": 1},
		{"rope": 2, "seed_tomato": 3, "sapling_banana": 1}],
}

## Записки — простыми словами, по одной на находку. Порядок: сначала бутылки, потом тайники.
const NOTES := {
	"home": [
		[["narrator", "В бутылке записка, буквы расплылись: «Кто найдёт — нас шестеро, мы живы. Еды хватает. Шторм не выпускает. Ждите нас дома»."]],
		[["narrator", "Обрывок карты: пять островов по кругу и шестой в центре, обведённый три раза. Подписи нет."]],
		[["narrator", "«Румба опять звал Лёву во сне. Ночью видели огонь на востоке. Лёва говорит — это добрый знак. — М.»"]],
		[["player", "Ящик прикопан у корней, рядом шест с красной тряпкой. Команда «Альбатроса» прятала здесь запасы на чёрный день."]],
		[["player", "Ещё один тайник. На крышке ножом: «Не трогать до зимы». Здесь, похоже, зимы не бывает."]],
	],
	"banyan": [
		[["narrator", "«Марта, если найдёшь, — я ушёл к форту. Корзину с манго не ищи, её съел Кешью. — Л.»"]],
		[["narrator", "Рецепт на мокрой бумаге: «Суп из того, что есть. Соль — по вкусу Лёвы, то есть много»."]],
		[["narrator", "Детский рисунок углём: дерево до неба, на ветках дом, а сверху огонь. Внизу: «Мы тут живём»."]],
		[["player", "Тайник под корнями: доски, верёвка, саженцы в мокрой тряпке. Кто-то готовился строить надолго."]],
		[["player", "На крышке тайника нацарапано: «Для того, кто придёт после нас». Кажется, это я."]],
	],
	"fort": [
		[["narrator", "«Боцман запер ворота. Говорит, так безопаснее. Половина команды с ним не согласна. — Г.»"]],
		[["narrator", "Список вахт, размытый морем. Против одной фамилии приписано: «ушёл на плоту, не вернулся»."]],
		[["narrator", "«Если маяки — это стена, то кто-то должен её держать. Не хочу, чтобы это был Лёва». Подпись стёрлась."]],
		[["player", "Тайник у старой стены: доски и верёвка, аккуратно уложенные. Боцманская работа — узлы как на картинке."]],
		[["player", "В тайнике — саженец и записка: «Посади, когда всё кончится». Почерк Стёпы."]],
	],
}

var kind := "bottle"
var index := 0
var loc := "home"
var visual: Node3D
var sparkle: CPUParticles3D


func flag() -> String:
	return "find_%s_%d" % [loc, index]


func found() -> bool:
	return Game.flags.get(flag(), false)


func _ready() -> void:
	add_to_group("obstacle")
	collision_layer = 8   # мелочь: под ногами не мешает
	visual = Models.glb("message_bottle" if kind == "bottle" else "crew_stash")
	if visual == null:
		visual = Node3D.new()
	if kind == "bottle":
		visual.scale = Vector3.ONE * 1.6   # мелкая — пусть будет заметнее на песке
	add_child(visual)
	var cs := CollisionShape3D.new()
	var c := CylinderShape3D.new()
	c.radius = 0.35 if kind == "bottle" else 0.55
	c.height = 0.5
	cs.shape = c
	cs.position.y = 0.25
	add_child(cs)
	if kind == "stash":
		collision_layer = 2
	if found():
		_show_found(false)
		return
	add_to_group("interactable")
	sparkle = CPUParticles3D.new()
	sparkle.amount = 6
	sparkle.lifetime = 1.6
	sparkle.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	sparkle.emission_sphere_radius = 0.35
	sparkle.direction = Vector3.UP
	sparkle.spread = 20.0
	sparkle.gravity = Vector3(0, 0.25, 0)
	sparkle.initial_velocity_min = 0.1
	sparkle.initial_velocity_max = 0.3
	sparkle.scale_amount_min = 0.6
	sparkle.scale_amount_max = 1.2
	var m := SphereMesh.new()
	m.radius = 0.035
	m.height = 0.07
	m.radial_segments = 6
	m.rings = 3
	m.material = Models.unshaded(Color("fff4b0"))
	sparkle.mesh = m
	sparkle.position.y = 0.35 if kind == "bottle" else 0.6
	add_child(sparkle)


func block_radius() -> float:
	return 0.6 if kind == "stash" else 0.35


func interact_point() -> Vector3:
	return global_position + Vector3(0, 0.3, 0)


func tool_hint() -> String:
	return ""


func get_hint() -> String:
	return "Подобрать бутылку с запиской" if kind == "bottle" else "Открыть тайник команды «Альбатроса»"


func interact(_player: Node) -> void:
	if found():
		return
	Game.flags[flag()] = true
	remove_from_group("interactable")
	Audio.play("rare", -2.0)
	FX.burst(self, Vector3(0, 0.4, 0), Color("ffe08a"), 14)
	var notes: Array = NOTES.get(loc, NOTES["home"])
	Game.dialogue_requested.emit(notes[index % notes.size()], Callable())
	var pool: Array = LOOT[kind]
	var loot: Dictionary = pool[index % pool.size()]
	for id in loot:
		Game.add_item(id, loot[id], false)
	if kind == "bottle" and randf() < 0.5:
		Game.add_collectible("shells")
	Game.bump("found", "find_" + kind)
	_show_found(true)


func _show_found(animate: bool) -> void:
	if sparkle:
		sparkle.queue_free()
		sparkle = null
	if kind == "bottle":
		# бутылку забрали с собой
		if animate:
			var tw := create_tween()
			tw.tween_property(visual, "scale", Vector3(0.01, 0.01, 0.01), 0.3)
			tw.tween_callback(func(): visual.visible = false)
		else:
			visual.visible = false
		collision_layer = 0
		return
	var lid := visual.find_child("Lid", true, false) as Node3D
	if lid:
		if animate:
			create_tween().tween_property(lid, "rotation:x", -1.7, 0.4).set_trans(Tween.TRANS_BACK)
		else:
			lid.rotation.x = -1.7
