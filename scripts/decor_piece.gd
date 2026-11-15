class_name DecorPiece
extends Building
## Украшение лагеря («вечная игра» после финала): мебель, коврики, гирлянды, фонарики, клумбы, дорожки, заборчики,
## вывески. Данные — Data.BUILDINGS с "decor": true: cozy — очки уюта, flat — по нему ходят, posts — два столба
## (под ним проходят), glow — вечером светится (узлы Lamp* в модели). E — маленькое дело (посидеть, прочитать,
## завести патефон) или «Убрать»: материалы возвращаются целиком, так что лагерь можно переставлять сколько угодно.

const SAY := {
	"camp_table": "Ты присел к столику. Кружка ещё тёплая.",
	"camp_stool": "Ты присел на табурет. Ноги гудят — значит, день был не зря.",
	"rocking_chair": "Ты качаешься в кресле. Скрип-скрип. Море шумит в такт.",
	"camp_shelf": "Миски, кувшины, банка с мёдом. Всё на своих местах.",
	"decor_chest": "Сундук пустой. Зато красивый.",
	"wash_stand": "Ты умылся. Вода холодная — проснулся сразу.",
	"bird_feeder": "В кормушке возятся птицы. На тебя не смотрят: заняты.",
	"weather_vane": "Железная чайка поворачивается носом к ветру.",
	"wind_chime": "Ракушки тихо стучат друг о друга. Ветер сегодня ленивый.",
	"log_stack": "Дрова сухие. Хватит на много вечеров.",
	"sign_camp": "На доске выжжено: «Лагерь „Чайка“. Основан в день крушения. Гостям рады».",
	"stone_lantern": "Свеча внутри горит ровно, ветер её не достаёт.",
	"flower_barrow": "Тачка своё отвозила. Теперь в ней живут цветы.",
}
const LAMP_COLOR := Color(1.0, 0.78, 0.42)

var _lights: Array[OmniLight3D] = []
var _bulbs: Array[MeshInstance3D] = []
var _lamp_t := 0.0
var _rock_t := 0.0
var playing := false     # патефон играет


func cfg() -> Dictionary:
	return Data.BUILDINGS[id]


func _make_visual() -> void:
	super._make_visual()
	if not cfg().get("glow", false):
		return
	# вечером зажигаются сами: в каждой точке Lamp* модели — тёплый свет и светящийся огонёк
	var bulb_mat := StandardMaterial3D.new()
	bulb_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bulb_mat.albedo_color = Color(2.4, 1.8, 0.9)
	var lamps := visual.find_children("Lamp*", "Node3D", true, false)
	for i in lamps.size():
		var lp := lamps[i] as Node3D
		var bulb := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.05
		sm.height = 0.1
		sm.radial_segments = 8
		sm.rings = 4
		bulb.mesh = sm
		bulb.material_override = bulb_mat
		bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		bulb.position = lp.position
		bulb.name = "Glow%d" % i
		visual.add_child(bulb)
		_bulbs.append(bulb)
		if lamps.size() > 3 and i % 3 != 1:
			continue   # у гирлянды светит каждый третий огонёк: много источников света — тяжело
		var l := OmniLight3D.new()
		l.light_color = LAMP_COLOR
		l.omni_range = 5.0
		l.omni_attenuation = 1.5
		l.light_specular = 0.1
		l.position = lp.position
		l.name = "LampLight%d" % i
		visual.add_child(l)
		_lights.append(l)
	_update_lamps()


func _make_collision() -> void:
	var r: float = cfg()["radius"]
	if cfg().get("flat", false):
		_add_cyl(r * 0.9, 0.1)
		collision_layer = 8          # коврики и дорожки: по ним ходят
		return
	if cfg().has("posts"):
		var off: float = cfg()["posts"]
		for sx in [-1.0, 1.0]:      # гирлянды, арка, калитка: мешают только столбы
			_add_box(Vector3(0.2, 2.2, 0.2), Vector3(sx * off, 1.1, 0), 0.0)
		return
	if id in ["picket_fence", "bamboo_fence"]:
		_add_box(Vector3(1.3, 0.9, 0.15), Vector3(0, 0.45, 0), 0.0)
		return
	_add_cyl(r * 0.7, 0.9)
	Models.add_trimesh(self, visual)


## Коврики и дорожки не мешают ставить на них другое (столик на коврике).
func block_radius() -> float:
	return 0.0 if cfg().get("flat", false) else float(cfg()["radius"])


## Building._ready по этому методу узнаёт, что с постройкой можно взаимодействовать.
func _custom_interact() -> void:
	pass


func night() -> float:
	return WorldEnv.night_amount(Game.time_of_day)


func _update_lamps() -> void:
	var k := smoothstep(0.25, 0.7, night())
	for l in _lights:
		l.visible = k > 0.02
		l.light_energy = 1.1 * k
	for b in _bulbs:
		b.visible = k > 0.02
		b.scale = Vector3.ONE * (0.6 + 0.4 * k)


func _process(delta: float) -> void:
	super._process(delta)
	if not _bulbs.is_empty():
		_lamp_t -= delta
		if _lamp_t <= 0.0:
			_lamp_t = 0.5
			_update_lamps()
	if _rock_t > 0.0 and visual:
		_rock_t = maxf(0.0, _rock_t - delta)
		visual.rotation.x = sin(_t * 3.2) * 0.07 * minf(1.0, _rock_t)
	if id == "weather_vane" and visual:
		var vane := visual.find_child("Vane", true, false) as Node3D
		if vane:
			vane.rotation.y = sin(_t * 0.4) * 0.5 + sin(_t * 1.7) * 0.08


func marker_height() -> float:
	return 1.4


func interact_point() -> Vector3:
	return global_position + Vector3(0, 0.1 if cfg().get("flat", false) else 0.6, 0)


func get_hint() -> String:
	var nm: String = cfg()["name"]
	match id:
		"rocking_chair", "camp_stool": return "%s — %s" % [nm, "встать (WASD или Пробел)" if Sitting.on(self) else "посидеть"]
		"gramophone": return "%s — %s" % [nm, "остановить" if playing else "завести"]
		"sign_camp", "sign_arrows": return "%s — прочитать" % nm
		"wash_stand": return "%s — умыться" % nm
		"wind_chime": return "%s — тронуть" % nm
	return "%s (уют +%d)" % [nm, int(cfg().get("cozy", 0))]


## Маленькое дело у украшения. Возвращает то, что показано игроку (для автотеста).
func act() -> String:
	var text: String = SAY.get(id, "")
	match id:
		"rocking_chair":
			_rock_t = 6.0
		"gramophone":
			playing = not playing
			if playing:
				Audio.play("quest", -5.0, 0.0, global_position)
				FX.puff(self, Vector3(0, 1.3, 0), Color("ffe08a"), 5, 0.3, 0.9, 0.8)
				text = "Пластинка шуршит, и над лагерем плывёт старый вальс."
			else:
				text = "Патефон замолчал. Слышно море."
		"wind_chime":
			Audio.play("blip", -6.0, 0.3, global_position)
		"wash_stand":
			Audio.play("water", -6.0, 0.15, global_position)
		"sign_arrows":
			var parts: Array[String] = []
			for loc in Data.LOCATIONS:
				if loc == Game.location:
					continue
				var c: Dictionary = Data.LOCATIONS[loc]
				if c.has("unlock_flag") and not Game.flags.get(c["unlock_flag"], false):
					continue
				parts.append(str(c["name"]))
			text = "Стрелки показывают: %s." % ", ".join(parts) if not parts.is_empty() else "Стрелки пока пустые: других островов ты не знаешь."
	if text == "":
		text = "%s. С ним в лагере уютнее." % cfg()["name"]
	Game.notified.emit(text, Color("ffe08a"))
	return text


## Убрать украшение: всё, что на него ушло, возвращается в сумку.
func remove_piece() -> void:
	var cost: Dictionary = cfg()["cost"]
	for item_id in cost:
		Game.add_item(item_id, int(cost[item_id]), false, true)
	Game.notified.emit("Убрано: %s. Материалы вернулись в сумку" % cfg()["name"], Color("bfe3ff"))
	Audio.play("build", -6.0, 0.1)
	FX.puff(get_parent(), global_position + Vector3(0, 0.3, 0), Color("e6dcc0"), 8, 0.4, 0.8, 0.6)
	remove_from_group("building")
	queue_free()


func interact(_player: Node) -> void:
	var nm: String = cfg()["name"]
	if Sitting.on(self):
		return      # уже сидим: встать — WASD, Пробел или E (Sitting)
	var opts := []
	if Sitting.can_sit(id):
		opts.append({"text": "Посидеть", "icon": id, "callback": func():
			if not Sitting.sit(_player, self, id):
				act()})
	if (SAY.has(id) or id in ["gramophone", "sign_arrows"]) and not Sitting.can_sit(id):
		var label: String = {"rocking_chair": "Посидеть", "gramophone": "Остановить" if playing else "Завести", "sign_camp": "Прочитать",
			"sign_arrows": "Прочитать", "wash_stand": "Умыться", "wind_chime": "Тронуть"}.get(id, "Посмотреть")
		opts.append({"text": label, "icon": id, "callback": func(): act()})
	opts.append({"text": "Убрать (материалы вернутся в сумку)", "icon": "sym_moon", "callback": remove_piece})
	opts.append({"text": "Оставить как есть", "icon": "sym_sun", "callback": func(): pass})
	Game.choice_requested.emit(nm, opts)
