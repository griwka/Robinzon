class_name GreatLighthouse
extends Node3D
## Великий маяк на Оке шторма — последнее и самое большое лазание в игре.
##
## Три участка: по внешней стене (каменные выступы) до первого балкона, по старой лестнице внутри башни до второго,
## и снова снаружи — до вершины, где горит Великий огонь и сидит Лёва. Наверху дует ветер: порывами.
## В порыв на внешней стене лучше прижаться и не лезть (силы тают втрое быстрее), на балконах ветер толкает к перилам.
## На стене есть уступы — на них можно повисеть и отдышаться. Сорваться не страшно: внизу балкон или трава.
## Узел стоит в центре основания башни, на плато; toward — направление на лагерь (там начинается подъём).

const H := [9.0, 18.0, 28.0]          # высота балконов: первый, второй, вершина
const DECK_R := [6.2, 6.0, 5.2]       # радиус балконов (и площадки на вершине)
const R_BASE := 4.0                   # башня до первого балкона
const R_MID := 3.85                   # средняя часть — полая, с лестницей внутри
const R_IN := 3.3
const R_TOP := 3.5                    # верхняя часть
const REST := 3.0                     # уступы для отдыха на внешних стенах

## Порыв ветра 0..1 (его читает герой, когда лезет по внешней стене) и куда он дует.
static var gust := 0.0
static var gust_dir := Vector3.RIGHT

var island: Island
var toward := Vector3.BACK
var climbs: Array[Climbable] = []
var fire_node: GreatFire
var lyova: NPCPerson
var _a1 := 0.0
var _reached := {}
var _phase := 0           # 0 — тихо, 1 — ветер крепнет, 2 — порыв
var _phase_t := 6.0
var _book: StoryPlace


func _ready() -> void:
	add_to_group("great_lighthouse")
	add_to_group("obstacle")
	_a1 = atan2(toward.z, toward.x)
	var model := Models.glb("great_lighthouse")
	if model:
		model.rotation.y = -_a1 + PI * 0.5   # в модели подъём (люк, выступы) — со стороны +Z
		add_child(model)
		for gi in model.find_children("*", "GeometryInstance3D", true, false):
			(gi as GeometryInstance3D).visibility_range_end = 0.0
	var body := StaticBody3D.new()
	body.collision_layer = 4
	add_child(body)
	# нижняя часть — сплошная
	_cyl(body, R_BASE, H[0], H[0] * 0.5)
	# средняя — кольцо стен с дверью на первом балконе
	var door_a := _a1 + PI * 0.5
	for i in 18:
		var a := TAU * i / 18.0
		if absf(wrapf(a - door_a, -PI, PI)) < 0.3:
			continue
		var cs := CollisionShape3D.new()
		var b := BoxShape3D.new()
		b.size = Vector3(0.55, H[1] - H[0], TAU * R_MID / 18.0 + 0.12)
		cs.shape = b
		cs.position = _dir(a) * (R_MID - 0.27) + Vector3(0, (H[0] + H[1]) * 0.5, 0)
		cs.rotation.y = -a
		body.add_child(cs)
	# верхняя — сплошная
	_cyl(body, R_TOP, H[2] - H[1], (H[1] + H[2]) * 0.5)
	# балконы (пол среднего яруса — это и есть первый балкон) и перила по краю
	for i in 3:
		_cyl(body, DECK_R[i], 0.4, H[i] - 0.2)
		var n := 28
		for k in n:
			var a := TAU * k / n
			var cs := CollisionShape3D.new()
			var b := BoxShape3D.new()
			b.size = Vector3(0.18, 1.2, TAU * DECK_R[i] / n + 0.05)
			cs.shape = b
			cs.position = _dir(a) * (DECK_R[i] - 0.1) + Vector3(0, H[i] + 0.6, 0)
			cs.rotation.y = -a
			body.add_child(cs)
	# чаша Великого огня — посреди вершины
	fire_node = GreatFire.new()
	fire_node.tower = self
	fire_node.position = Vector3(0, H[2], 0)
	add_child(fire_node)
	# Лёва сидит у огня
	if not Game.ended():
		lyova = NPCPerson.new()
		lyova.npc_id = "lyova"
		lyova.position = _dir(_a1 + PI * 0.75) * 3.6 + Vector3(0, H[2], 0)
		lyova.rotation.y = atan2(-_dir(_a1 + PI * 0.75).x, -_dir(_a1 + PI * 0.75).z)
		add_child(lyova)
	# подъём
	var c1 := _climb(_a1, R_BASE + 0.02, 0.0, H[0], _dir(_a1 + 0.42) * 5.1 + Vector3(0, H[0] + 0.3, 0))
	var lad := Climbable.new()
	var la := _a1 + PI
	lad.ladder = true
	lad.ladder_yaw = atan2(-_dir(la).x, -_dir(la).z)
	lad.bottom = _dir(la) * (R_IN - 0.25) + Vector3(0, H[0], 0)
	lad.top = Vector3(lad.bottom.x, H[1], lad.bottom.z)
	lad.exit = _dir(la + 0.4) * 4.9 + Vector3(0, H[1] + 0.3, 0)
	add_child(lad)
	climbs.append(lad)
	var c3 := _climb(_a1 - PI * 0.5, R_TOP + 0.02, H[1], H[2], _dir(_a1 - PI * 0.5 + 0.3) * 4.3 + Vector3(0, H[2] + 0.3, 0))
	# уступы для отдыха на внешних стенах
	for c in [c1, c3]:
		var y := REST
		while y < c.top.y - c.bottom.y - 1.0:
			var lm := Models.glb("tower_ledge")
			if lm:
				lm.position = c.bottom + Vector3(0, y - 0.05, 0)
				lm.rotation.y = c.ladder_yaw
				add_child(lm)
			y += REST
	# светильники в башне: внутри темно
	for k in 3:
		var l := OmniLight3D.new()
		l.light_color = Color("ffc070")
		l.light_energy = 1.1
		l.omni_range = 5.0
		l.position = _dir(_a1 + k * TAU / 3.0 + 0.6) * (R_IN - 0.5) + Vector3(0, H[0] + 2.4 + k * 2.6, 0)
		add_child(l)
	# Книга Хранителей — на каменном столе у подножия, рядом с началом подъёма
	_book = StoryPlace.new()
	_book.id = "keepers_book"
	_book.position = _dir(_a1 - 0.55) * (R_BASE + 2.2)
	_book.rotation.y = atan2(toward.x, toward.z)
	add_child(_book)
	island.poi_extra["eye_tower"] = to_global(_dir(_a1) * (R_BASE + 2.0))
	island.poi_extra["eye_top"] = to_global(_dir(_a1 + PI * 0.3) * 4.0 + Vector3(0, H[2] + 0.2, 0))
	island.poi_extra["lyova"] = island.poi_extra["eye_top"]


func _dir(a: float) -> Vector3:
	return Vector3(cos(a), 0, sin(a))


func _cyl(body: StaticBody3D, r: float, h: float, y: float) -> void:
	var cs := CollisionShape3D.new()
	var c := CylinderShape3D.new()
	c.radius = r
	c.height = h
	cs.shape = c
	cs.position.y = y
	body.add_child(cs)


func _climb(a: float, r: float, y0: float, y1: float, exit: Vector3) -> Climbable:
	var c := Climbable.new()
	c.ladder_yaw = atan2(_dir(a).x, _dir(a).z)
	c.bottom = _dir(a) * r + Vector3(0, y0, 0)
	c.top = Vector3(c.bottom.x, y1, c.bottom.z)
	c.exit = exit
	c.rest_step = REST
	c.wind = y0 > 1.0 or y1 > 6.0
	c.holds = "tower_holds"
	add_child(c)
	climbs.append(c)
	return c


func block_radius() -> float:
	return DECK_R[0] + 0.5


## Мировая точка на балконе i (0, 1) или на вершине (2) — для автотеста и разработки.
func deck_point(i: int) -> Vector3:
	return to_global(_dir(_a1 + 0.9) * (DECK_R[i] - 1.2) + Vector3(0, H[i] + 0.3, 0))


## Внутри средней части башни (там нет ветра, а камера подходит ближе).
func inside(p: Vector3) -> bool:
	var l := p - global_position
	return Vector2(l.x, l.z).length() < R_IN and l.y > H[0] - 0.5 and l.y < H[1] - 0.2


func _process(delta: float) -> void:
	# первый участок подъёма открыт, когда прочитана Книга (иначе сюжет пойдёт задом наперёд)
	if not climbs.is_empty():
		climbs[0].locked_hint = "" if Game.flags.get("poi_keepers_book", false) or Game.ended() \
			else "Выступы на стене маяка. Румба тянет за рукав: сначала — сад и Книга у подножия"
	_wind(delta)
	var p := get_tree().get_first_node_in_group("player") as Player
	if p == null:
		return
	p.force_indoor = inside(p.global_position)
	var l := p.global_position - global_position
	var flat := Vector2(l.x, l.z).length()
	# ветер толкает на открытых балконах (перила держат)
	p.ext_push = Vector3.ZERO
	if gust > 0.0 and l.y > H[0] - 0.5 and flat > R_IN and flat < DECK_R[0] + 1.0 and p.climbing == null:
		p.ext_push = gust_dir * 2.4 * gust
	for i in 3:
		var id := "eye_deck%d" % (i + 1)
		if _reached.has(id):
			continue
		var on_deck: bool = absf(l.y - H[i]) < 1.3 and flat < DECK_R[i] and (i == 2 or flat > R_MID - 0.1)
		if on_deck:
			_reached[id] = true
			Game.bump("reached", id)
			Game.notified.emit(["Первый балкон", "Второй балкон", "Вершина Великого маяка"][i], Color("bfe3ff"))
			if Game.has_tool("radio_set") and not Game.ended():
				var say: String = ["(в рации) ЕЩЁ ЧУТЬ-ЧУТЬ! Я не вижу, но ВЕРЮ!", "(в рации) Половина! Ингрид говорит, что считать до вершины ещё десять метров. Я говорю — ДЕСЯТЬ МЕТРОВ ВЕРЫ!",
					"(в рации) Ты наверху? НАВЕРХУ?! ...Я сел. Я просто сел и сижу."][i]
				Game.dialogue_requested.emit([["timur", say]], Callable())


## Ветер на высоте: тишина, ветер крепнет (слышно заранее), порыв. Без случайностей во времени — ритм ровный.
func _wind(delta: float) -> void:
	_phase_t -= delta
	if _phase_t <= 0.0:
		_phase = (_phase + 1) % 3
		_phase_t = [6.5, 1.4, 2.6][_phase]
		if _phase == 1:
			var p := get_tree().get_first_node_in_group("player") as Node3D
			if p and p.global_position.y - global_position.y > 4.0:
				Audio.play("gust", -4.0, 0.1)
			gust_dir = _dir(_a1 + PI * 0.5 + sin(Time.get_ticks_msec() * 0.0003) * 0.8)
	var want := 1.0 if _phase == 2 else 0.0
	gust = move_toward(gust, want, delta * (3.0 if want > gust else 1.5))


func _exit_tree() -> void:
	gust = 0.0


# ================================================================== Великий огонь
## Чаша Великого огня. До линзы огонь низкий и синий; с линзой — золотой, и луч уходит вверх.
## Здесь делают выбор (задание «Выбор»). После финала «Хранитель огня» — ритуал «зажечь лучи» и окно в шторме.
class GreatFire extends StaticBody3D:
	var tower: GreatLighthouse
	var visual: Node3D
	var fire: Node3D
	var beam: MeshInstance3D
	var _state := ""

	func _ready() -> void:
		add_to_group("interactable")
		add_to_group("great_fire")
		collision_layer = 4
		visual = Models.glb("great_fire")
		if visual == null:
			visual = Node3D.new()
		add_child(visual)
		var cs := CollisionShape3D.new()
		var c := CylinderShape3D.new()
		c.radius = 2.2
		c.height = 1.3
		cs.shape = c
		cs.position.y = 0.65
		add_child(cs)
		refresh(false)

	func _point() -> Vector3:
		var p := visual.find_child("FirePoint", true, false) as Node3D
		return p.position if p else Vector3(0, 1.0, 0)

	## Огонь по сюжету: синий, золотой (линза стоит, Хранитель держит) или погас (финал «Открытое море»).
	func refresh(animate: bool) -> void:
		var want := "blue"
		if Game.flags.get("ending_open_sea", false):
			want = "out"
		elif Game.flags.get("eye_lens", false):
			want = "gold"
		if want == _state:
			return
		_state = want
		if fire:
			remove_child(fire)
			fire.queue_free()
			fire = null
			var old := get_node_or_null("Light")
			if old:
				remove_child(old)
				old.queue_free()
		if beam:
			beam.queue_free()
			beam = null
		if want == "out":
			return
		fire = Models.flame(self, _point(), 2.6 if want == "gold" else 1.6, 5.0 if want == "gold" else 2.5, 30.0 if want == "gold" else 14.0)
		if want == "blue":
			for f in fire.get_children():
				if f is MeshInstance3D:
					(f as MeshInstance3D).material_override = Models.flame_mat(Color("d8f0ff"), Color("3a7ae8"), 3.0)
			var l := get_node_or_null("Light") as OmniLight3D
			if l:
				l.light_color = Color("7ab0ff")
		else:
			beam = MeshInstance3D.new()
			var m := CylinderMesh.new()
			m.top_radius = 1.4
			m.bottom_radius = 0.7
			m.height = 160.0
			m.radial_segments = 16
			m.cap_top = false
			m.cap_bottom = false
			beam.mesh = m
			beam.material_override = EyeStorm.beam_mat(Color("ffd27a"), 1.4)
			beam.position = _point() + Vector3(0, 81.0, 0)
			beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(beam)
		if animate:
			fire.scale = Vector3(0.05, 0.05, 0.05)
			create_tween().tween_property(fire, "scale", Vector3.ONE, 1.6).set_trans(Tween.TRANS_BACK)

	func interact_point() -> Vector3:
		return global_position + Vector3(0, 1.0, 0)

	func tool_hint() -> String:
		return ""

	func _choosing() -> bool:
		var q := Game.current_quest()
		return not q.is_empty() and Game.quest_started and q["id"] == "choice"

	func get_hint() -> String:
		if _choosing():
			return "Великий огонь — сделать выбор"
		if Game.flags.get("ending_open_sea", false):
			return "Остывшая чаша. Отсюда видно море — до самого края"
		if Game.flags.get("ending_keeper", false):
			return "Великий огонь — тёплый, как ладонь"
		if Game.flags.get("eye_lens", false):
			return "Великий огонь горит золотым"
		return "Великий огонь — низкий, синий, неровный"

	func interact(_player: Node) -> void:
		if _choosing():
			_offer_choice()
			return
		if Game.flags.get("ending_keeper", false):
			_keeper_menu()
			return
		Game.notified.emit(get_hint(), Color("ffe08a"))

	func _offer_choice() -> void:
		Game.choice_requested.emit("Великий огонь", [
			{"text": "Погасить огонь — отпустить шторм. Все поедут домой", "icon": "sail", "callback": func():
				_confirm("Да — погасить Великий огонь. Шторм уйдёт навсегда, острова станут обычными", "sea")},
			{"text": "Стать Хранителем — вписать своё имя в Книгу", "icon": "sym_sun", "callback": func():
				_confirm("Да — встать к огню вместо Лёвы. Шторм останется, острова — живыми", "keeper")},
			{"text": "Подумать ещё", "icon": "sym_moon", "callback": func(): pass},
		])

	func _confirm(text: String, ending: String) -> void:
		Game.choice_requested.emit("Ты уверен?", [
			{"text": text, "icon": "sail" if ending == "sea" else "sym_sun", "callback": func(): choose(ending)},
			{"text": "Нет, подумаю ещё", "icon": "sym_moon", "callback": func(): pass},
		])

	## Сделать выбор: сцена у огня, затем флаг финала (его ждёт задание «Выбор»).
	func choose(ending: String) -> void:
		var lines: Array = SCENE_SEA if ending == "sea" else SCENE_KEEPER
		Game.dialogue_requested.emit(lines, func():
			Game.flags["ending_open_sea" if ending == "sea" else "ending_keeper"] = true
			Game.flags["ending_day"] = Game.day
			Game.unlocked["shop_lyova"] = true
			refresh(true)
			if ending == "sea":
				Audio.play("fire_out", 0.0, 0.0)
			else:
				Audio.play("quest", 0.0, 0.0)
			Game.bump("chose", "ending"))

	const SCENE_SEA := [
		["narrator", "Ты кладёшь ладонь на край чаши. Камень тёплый."],
		["narrator", "Огонь опускается медленно, будто кивает. Семь маяков гаснут один за другим, мягко, без дыма."],
		["narrator", "Шторм вокруг Ока замирает, светлеет и распадается на облака. Облака уходят за горизонт."],
		["narrator", "Утром во все стороны — море. Просто море, до самого края."],
		["lyova", "Дед бы ругался. А потом сел бы на скамейку и смотрел. Как я сейчас."],
	]
	const SCENE_KEEPER := [
		["narrator", "Ты берёшь перо и пишешь своё имя в пустую строку Книги. Под именем деда. Под именем брата."],
		["narrator", "Огонь становится тёплым, как ладонь. Ты чувствуешь все семь маяков, как чувствуешь пальцы."],
		["lyova", "Ты уверен?"],
		["player", "Нет. Но я не один. Дед был один. Ты был один. А у меня — деревня, Марта и попугай, который врёт про рыбу."],
		["parrot", "Румба не врёт. Румба преувеличивает."],
		["narrator", "Ты открываешь окно в шторме. «Альбатрос» уходит домой: Лёва, Рената, Гоша, Лукины, Миша и Вера."],
		["narrator", "Остаются те, кто сам захотел. Марта: «Моя чаша — мой дом». Стёпа: «Кто-то должен ругаться». Тимур: «Антенну не брошу». Ингрид: «Пингвины»."],
		["lyova", "Раз в год. Окно. Я приплыву. Обещаю. Не пересаливай суп."],
	]

	## Хранитель у огня (после финала Б): зажечь лучи («день щедрости») и открыть окно для корабля Лёвы.
	func _keeper_menu() -> void:
		var opts := []
		if Game.bounty_today():
			opts.append({"text": "Лучи уже горят: сегодня день щедрости", "icon": "sym_sun", "callback": func(): pass})
		else:
			opts.append({"text": "Зажечь лучи — сегодня урожай будет вдвое больше", "icon": "sym_sun", "callback": func():
				Game.flags["bounty_day"] = Game.day
				Audio.play("quest", -2.0, 0.0)
				get_tree().call_group("eye_storm", "pulse")
				Game.notified.emit("День щедрости! Сегодня грядки дают вдвое больше", Color("8affa0"))})
		if Game.window_open():
			opts.append({"text": "Окно в шторме открыто: корабль Лёвы у причала дома", "icon": "sail", "callback": func(): pass})
		else:
			opts.append({"text": "Открыть окно в шторме — позвать корабль Лёвы", "icon": "sail", "callback": func():
				Game.flags["window_day"] = Game.day
				Audio.play("sail", -2.0, 0.0)
				get_tree().call_group("eye_storm", "open_window")
				Game.notified.emit("Окно открыто. Сегодня корабль Лёвы ждёт у причала твоего острова", Color("8affa0"))})
		Game.choice_requested.emit("Великий огонь", opts)
