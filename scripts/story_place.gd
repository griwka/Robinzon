class_name StoryPlace
extends StaticBody3D
## Сюжетное место в глубине острова: старый лагерь Лёвы, шлюпка «Альбатроса», древний маяк.
## Добраться можно, только расчистив путь нужными инструментами. Осмотр даёт находки и страницу журнала.

const PLACES := {
	"fort_gate": {"model": "", "name": "Ворота форта", "radius": 0.0, "needs": "fort_key",
		"loot": {}, "pages": 0,
		"lines": [["narrator", "Ключ проворачивается туго, с хрустом ржавчины. Створки расходятся, и в лицо пахнет сыростью и старым камнем."]]},
	"gatehouse": {"model": "gatehouse", "name": "Караулка", "radius": 1.5,
		"loot": {"rope": 2, "coins": 8}, "pages": 0, "journal": "journal_fort", "journal_pages": 1,
		"lines": [["player", "Стол, обрывки карт, огарок свечи. И страница, исписанная знакомым почерком."]]},
	"frescoes": {"model": "", "name": "Древние рисунки", "radius": 0.0, "needs_flag": "cellar_drained",
		"loot": {}, "pages": 0, "journal": "journal_fort", "journal_pages": 2,
		"lines": [["narrator", "Охра на камне: люди у башен с огнём. Над ними шторм — и он отступает кругами. Рядом — карта пяти островов и шестого, в центре, обведённого красным."],
			["narrator", "Под рисунками, на сухой плите, — две страницы Лёвы, придавленные камнем."]]},
	"fort_tower": {"model": "lighthouse_ruin", "name": "Башня форта", "radius": 1.9, "flag": "lit_fort_tower",
		"loot": {}, "pages": 0, "fuel": {"wood": 10, "lamp_oil": 2},
		"lines": [["player", "Ещё один маяк — чёрный камень, чаша наверху. Пепел свежий: огонь погасили недавно. Нарочно."]]},
	"treehouse": {"model": "treehouse_ruin", "name": "Развалины дома Лёвы", "radius": 1.3,
		"loot": {}, "pages": 0, "restore": {"plank": 10, "rope": 4, "copper_nails": 10, "leaf": 8},
		"restored_model": "treehouse", "restored_name": "Дом Лёвы",
		"lines": [["player", "Каркас, провалившаяся крыша и обрывки брезента. На балке вырезано: «Л. + М. = лучший суп на архипелаге». Ха."]]},
	"lyova_chest": {"model": "chest", "name": "Сундук Лёвы", "radius": 0.5, "needs": "lyova_key",
		"loot": {"coins": 10}, "pages": 0, "journal": "journal_banyan", "journal_pages": 3,
		"lines": [["narrator", "Ключ поворачивается с тихим щелчком. Внутри — компас, засушенная синяя бабочка и три исписанные страницы."]]},
	"banyan_roots": {"model": "", "name": "Корни Великого Баньяна", "radius": 0.0,
		"loot": {"liana": 2}, "pages": 0,
		"lines": [["player", "На коре вырезаны зарубки — ровные, через каждые полметра. Кто-то считал дни. Очень много дней."],
			["parrot", "Лёва! Это Лёва так считает. Палочка — день, крестик — неделя."]]},
	"fire_bowl": {"model": "", "name": "Чаша огня", "radius": 0.0,
		"loot": {}, "pages": 0,
		"lines": [["player", "Отсюда виден весь архипелаг. И мой маяк — крошечная искра на западе."]]},
	"wreck": {"model": "", "name": "Обломки «Чайки»", "radius": 0.0,
		"loot": {"scrap": 1, "rope": 1}, "pages": 0,
		"lines": [["player", "Среди досок — погнутая полоса металла от обшивки. Если наточить о камень, выйдет лезвие."]]},
	"old_camp": {"model": "old_camp", "name": "Старый лагерь Лёвы", "radius": 1.6,
		"loot": {"rope": 3, "seed_cabbage": 2, "sapling_mango": 1}, "pages": 1,
		"lines": [["player", "Рухнувшая палатка, остывший очаг... На подставке — размокший журнал. Это почерк Лёвы."],
			["parrot", "Лагерь! Здесь Лёва жил, когда команда ушла к форту. Румба помнит этот запах... мокрый брезент."]]},
	"lifeboat": {"model": "lifeboat", "name": "Шлюпка «Альбатроса»", "radius": 1.8,
		"loot": {"sail": 1, "rope": 2, "plank": 4}, "pages": 1,
		"lines": [["player", "На борту облупившиеся буквы: «АЛЬБАТРОС-2». Под скамейкой — свёрнутый парус и ещё одна страница."],
			["parrot", "Лёва хотел уплыть на ней. Потом передумал. Сказал: «Сначала свет»."]]},
	"lighthouse": {"model": "lighthouse_ruin", "name": "Древний маяк", "radius": 1.9,
		"loot": {}, "pages": 1, "fuel": {"wood": 10, "fiber": 6},
		"lines": [["player", "Чёрный камень тёплый на ощупь, хотя солнце давно ушло за тучи. В чаше наверху — старый пепел."],
			["parrot", "Маяк... Румба знает это слово. Лёва повторял его каждую ночь."]]},
	# ---------------------------------------------------------------- глава 4
	"stepa_boat": {"model": "stepa_boat_wreck", "name": "Бот Стёпы", "radius": 1.6,
		"loot": {}, "pages": 0, "restore": {"plank": 10, "brick": 6, "copper_nails": 10, "wool_cloth": 2},
		"restored_model": "stepa_boat", "restored_name": "Бот Стёпы",
		"lines": [["stepa", "Вот он. Обшивка рассохлась, парус сгнил. Доски, гвозди, шерстяная ткань на парус. И кирпичи в трюм — для тяжести, чтобы волна не перевернула."]]},
	"seaplane": {"model": "seaplane", "name": "Старый гидросамолёт", "radius": 2.4,
		"loot": {"scrap": 3}, "pages": 0,
		"lines": [["player", "Ржавое крыло торчит из воды. На борту едва видны буквы: «Ветер-3». Самолёт здесь очень давно."],
			["parrot", "Железная птица. Мёртвая. Румба не любит мёртвых птиц."]]},
	"graves": {"model": "graves", "name": "Четыре камня", "radius": 1.6,
		"loot": {}, "pages": 0,
		"lines": [["player", "Четыре камня, на каждом выбито имя и год — тысяча девятьсот пятьдесят восьмой. Метеорологи. Их было пятеро... а камней четыре."],
			["parrot", "Пятого нет. Пятый ушёл. Румба... Румба не знает, почему так думает."]]},
	"generator": {"model": "generator_broken", "name": "Генератор", "radius": 0.9,
		"loot": {}, "pages": 0, "restore": {"battery_charged": 2, "copper_wire": 3, "fuse": 2},
		"restored_model": "generator", "restored_name": "Генератор",
		"lines": [["player", "Генератор метеорологов. Провода обгорели, предохранители выбиты. Тимур говорил: два заряда, проволока и два предохранителя."]]},
	"station_logs": {"model": "station_desk", "name": "Стол метеорологов", "radius": 0.9,
		"loot": {"radio_tube": 2}, "pages": 0, "journal": "journal_station", "journal_pages": 3,
		"lines": [["narrator", "Железный стол, приборы под слоем пыли. В ящике — толстый журнал в клеёнке и две радиолампы, завёрнутые в вату."]]},
	"radio": {"model": "radio_broken", "name": "Радиостанция", "radius": 0.9,
		"loot": {}, "pages": 0, "restore": {"radio_tube": 2, "copper_wire": 4, "battery_charged": 2},
		"restored_model": "radio", "restored_name": "Радиостанция",
		"lines": [["player", "Радиостанция. Две лампы лопнули от молнии, провода сгорели. Нужно две радиолампы, проволока и заряд."]]},
	"radio_record": {"model": "", "name": "Запись Лёвы", "radius": 0.0, "needs_flag": "restored_radio",
		"locked_hint": "Запись Лёвы — сначала почини радиостанцию",
		"loot": {}, "pages": 0, "journal": "journal_storm", "journal_pages": 3, "sound": "radio",
		"lines": [["narrator", "Ты нажимаешь клавишу. Шипение, треск, далёкий гром... и голос, который ты узнал бы из тысячи. Рядом с рацией — три листка, исписанных рукой Лёвы."]]},
	"storm_tower": {"model": "storm_tower_ruin", "name": "Башня громов", "radius": 2.0, "flag": "lit_storm_tower",
		"loot": {}, "pages": 0, "restore": {"copper_wire": 6, "glass": 4, "scrap": 4}, "fuel": {}, "needs_storm": true,
		"restored_model": "storm_tower", "restored_name": "Башня громов",
		"lines": [["player", "Чёрная башня, а наверху — медный шпиль, позеленевший от времени. От шпиля к чаше когда-то шла медная жила. Теперь она оборвана."]]},
	# ---------------------------------------------------------------- глава 5
	# ледяные ларцы: сундук вмёрз в лёд; рядом ставят жаровню (brazier), лёд тает melt секунд
	"ice_chest_1": {"model": "ice_chest", "name": "Ледяной ларец на уступе", "radius": 0.7, "brazier": {"wood": 5}, "melt": 10.0,
		"climb": true, "loot": {"coins": 8}, "pages": 0, "journal": "star_maps", "journal_pages": 1,
		"lines": [["narrator", "Лёд стекает с крышки ручьями. Внутри — сухой ящик, обёрнутый клеёнкой, и лист, исписанный рукой Лёвы."]]},
	"ice_chest_2": {"model": "ice_chest", "name": "Ларец под водопадом", "radius": 0.7, "brazier": {"wood": 5}, "melt": 10.0,
		"loot": {"coins": 8}, "pages": 0, "journal": "star_maps", "journal_pages": 1,
		"lines": [["narrator", "Под замёрзшим водопадом тихо, как в комнате. Ларец оттаял. Внутри — лист с рисунком созвездия."]]},
	"ice_chest_3": {"model": "ice_chest", "name": "Ларец у соснового бора", "radius": 0.7, "brazier": {"wood": 5}, "melt": 10.0,
		"loot": {"coins": 8, "resin": 2}, "pages": 0, "journal": "star_maps", "journal_pages": 1,
		"lines": [["narrator", "Пахнет смолой и мокрым деревом. В ларце — два куска смолы, завёрнутые в тряпку, и ещё один лист расчётов."]]},
	"sextant": {"model": "sextant_broken", "name": "Секстант Ингрид", "radius": 0.6,
		"loot": {}, "pages": 0, "restore": {"glass": 2, "scrap": 2, "copper_wire": 1},
		"restored_model": "sextant", "restored_name": "Секстант",
		"lines": [["player", "Медная дуга, зеркальце треснуло, винты погнуты. На ручке нацарапано: «И. Л. — 1998». Стекло, железо и проволока — и он снова будет мерить."]]},
	"ice_tower": {"model": "ice_tower_frozen", "name": "Холодное сердце", "radius": 2.2, "flag": "lit_ice_tower",
		"loot": {}, "pages": 0, "restore": {"wood": 12, "resin": 4, "lamp_oil": 2}, "fuel": {},
		"restored_model": "ice_tower", "restored_name": "Холодное сердце",
		"lines": [["player", "Маяк вмёрз в лёд целиком, как муха в янтарь. Если сколоть лёд у входа и сложить в чашу дрова со смолой и маслом, огонь, может быть, примется."],
			["parrot", "Холодное сердце. Румба слышал это имя. Румба не помнит где."]]},
	# ---------------------------------------------------------------- глава 6
	"hot_spring": {"model": "", "name": "Горячие источники", "radius": 0.0,
		"loot": {"aloe": 2}, "pages": 0,
		"lines": [["narrator", "Три каменные чаши, вода в них голубая и горячая. Пар пахнет мятой. На краю сушатся пучки трав и стоит жестяная кружка."]]},
	"temple": {"model": "", "name": "Огненный храм", "radius": 0.0, "needs_flag": "monolith_solved",
		"locked_hint": "Дверь храма закрыта каменной плитой. Пусти лаву по жёлобам в чашу",
		"loot": {"obsidian": 2}, "pages": 0, "journal": "journal_volcano", "journal_pages": 3,
		"lines": [["narrator", "Внутри жарко и тихо. Стены покрыты рисунками, в глубине — древняя кузня с каменным горном. На наковальне — три листа, придавленные куском обсидиана."]]},
	"volcano_tower": {"model": "volcano_tower_ruin", "name": "Огонь кратера", "radius": 2.0, "flag": "lit_volcano_tower",
		"loot": {}, "pages": 0, "restore": {"iron_ingot": 4, "stone": 6}, "fuel": {},
		"restored_model": "volcano_tower", "restored_name": "Огонь кратера",
		"lines": [["player", "Башня из красного камня на самом краю. От озера лавы к её чаше шёл каменный жёлоб — он прогорел и обвалился. Заслонка заржавела."],
			["parrot", "Тут Лёва обжёгся. Румба чует. Пахнет Лёвой и горелым."]]},
	# ---------------------------------------------------------------- глава 7
	# «Альбатрос»: части корабля чинят с мостков у борта; сам корабль (и что на нём уже починено) рисует StiltCamp
	"albatros": {"model": "", "name": "Палуба «Альбатроса»", "radius": 0.0,
		"loot": {"ship_rope": 1}, "pages": 0,
		"lines": [["narrator", "По сходням — на палубу. Доски скрипят и пружинят. Всё поросло мхом, на реях дремлют светлячки."]]},
	"albatros_hull": {"model": "", "name": "Корпус «Альбатроса»", "radius": 0.0,
		"loot": {}, "pages": 0, "restore": {"mangrove_plank": 20, "resin": 6, "iron_nails": 20, "copper_nails": 20},
		"restored_name": "Корпус «Альбатроса» (починен)",
		"lines": [["gosha", "Пробоины. Гниль. Борт держится на честном слове. Моём."]]},
	"albatros_mast": {"model": "", "name": "Мачта «Альбатроса»", "radius": 0.0,
		"loot": {}, "pages": 0, "restore": {"wood": 4, "ship_rope": 6, "ship_sail": 3},
		"restored_name": "Мачта и паруса",
		"lines": [["stepa", "Мачту сломало в ту ночь, когда его сорвало с якоря. Обломок я узнаю из тысячи."]]},
	"albatros_helm": {"model": "", "name": "Руль «Альбатроса»", "radius": 0.0,
		"loot": {}, "pages": 0, "restore": {"iron_ingot": 2, "plank": 4},
		"restored_name": "Руль",
		"lines": [["gosha", "Штурвал цел. Перо руля сгнило. Нужны оковка и доски."]]},
	"albatros_lights": {"model": "", "name": "Ходовые огни", "radius": 0.0,
		"loot": {}, "pages": 0, "restore": {"glass": 4, "copper_wire": 2, "firefly_lantern": 1},
		"restored_name": "Ходовые огни",
		"lines": [["misha", "Фонари побились. Но если в них посадить светлячков... Красиво же будет!"]]},
	"albatros_radio": {"model": "", "name": "Корабельная рация", "radius": 0.0,
		"loot": {}, "pages": 0, "restore": {"radio_tube": 2, "battery_charged": 2},
		"restored_name": "Корабельная рация",
		"lines": [["misha", "Это моя рация. Я по ней стучал «живы, туман». Ей нужны лампы. Мои давно сели."]]},
	"fog_tower": {"model": "fog_tower_ruin", "name": "Потерянный маяк", "radius": 2.0, "flag": "lit_fog_tower",
		"needs_flag": "shadows_solved", "locked_hint": "Потерянный маяк — проход закрыт гладкой скалой",
		"loot": {}, "pages": 0, "restore": {"iron_ingot": 4, "obsidian": 2, "brick": 6}, "fuel": {"lamp_oil": 4, "firefly": 10},
		"restored_model": "fog_tower", "restored_name": "Потерянный маяк",
		"lines": [["narrator", "Башня из серого камня, заросшая мхом до самого верха. Чаши нет: её сняли, аккуратно, давным-давно."],
			["parrot", "Седьмой. Румба знает. Румба всегда знал, что их семь."]]},
	# ---------------------------------------------------------------- глава 8
	"grandfather_house": {"model": "grandfather_house", "name": "Домик в саду", "radius": 2.0,
		"loot": {}, "pages": 0,
		"lines": [["narrator", "За кустами — сад. Старые яблони, заросшие грядки, скамейка, которую кто-то чинил много раз."],
			["parrot", "Румба... знает этот дом."],
			["narrator", "В доме — насест для птицы, на стене — фото. Молодой мужчина в лётной куртке, на плече у него красный попугай."]]},
	"grandfather_letters": {"model": "letters_box", "name": "Коробка писем", "radius": 0.5,
		"needs_flag": "poi_grandfather_house", "locked_hint": "Коробка на крыльце. Сначала загляни в дом",
		"loot": {"grandfather_letters": 1}, "pages": 0,
		"lines": [["narrator", "Старый деревянный ящик, а в нём — письма. Пачки, перевязанные бечёвкой. Шестьдесят пять штук."]]},
	"keepers_book": {"model": "keepers_book", "name": "Книга Хранителей", "radius": 0.7,
		"needs_flag": "poi_grandfather_letters", "locked_hint": "Тяжёлая книга на каменном столе. Румба тянет за рукав: сначала — сад деда",
		"loot": {}, "pages": 0, "journal": "keepers_book", "journal_pages": 5,
		"lines": [["narrator", "Каменный стол, на нём — книга в кожаном переплёте, толстая, как кирпич. Страницы пахнут морем и дымом."]]},
}

var id := "old_camp"
var visual: Node3D
var _solids: Array[CollisionShape3D] = []
var fire: Node3D


func _ready() -> void:
	var cfg0: Dictionary = PLACES[id]
	if cfg0.has("fuel") or not Game.flags.get("poi_" + id, false) or (cfg0.has("restore") and not Game.flags.get("restored_" + id, false)):
		add_to_group("interactable")
	add_to_group("obstacle")
	collision_layer = 4
	var cfg: Dictionary = PLACES[id]
	visual = Models.glb(cfg["model"]) if cfg["model"] != "" else Node3D.new()
	add_child(visual)
	if cfg["radius"] <= 0.0:
		remove_from_group("obstacle")
		return
	var cs := CollisionShape3D.new()
	var c := CylinderShape3D.new()
	c.radius = cfg["radius"]
	c.height = 5.0 if cfg.has("fuel") else 2.5
	cs.shape = c
	cs.position.y = c.height * 0.5
	add_child(cs)
	_solids = Models.add_trimesh(self, visual)   # башни, крыши, борта выше цилиндра — тоже твёрдые
	if cfg.has("restore") and Game.flags.get("restored_" + id, false):
		_swap_model(false)
	if cfg.has("fuel") and Game.flags.get(_lit_flag(), false):
		light_fire(false)
	if cfg.has("brazier") and Game.flags.has("melt_" + id):
		_place_brazier(false)


func block_radius() -> float:
	return PLACES[id]["radius"] + 1.0


func interact_point() -> Vector3:
	return global_position + Vector3(0, 0.8, 0)


func _process_hide() -> void:
	pass


func tool_hint() -> String:
	return ""


func _cost_text(cost: Dictionary) -> String:
	var parts: Array[String] = []
	for k in cost:
		parts.append("%s %d/%d" % [Game.item_name(k), Game.count(k), cost[k]])
	return ", ".join(parts)


func _lit_flag() -> String:
	return PLACES[id].get("flag", "lighthouse_lit" if id == "lighthouse" else "lit_" + id)


func get_hint() -> String:
	var cfg: Dictionary = PLACES[id]
	if cfg.has("brazier") and not Game.flags.get("poi_" + id, false):
		if not Game.flags.has("melt_" + id):
			return "%s — вмёрз в лёд. Поставить жаровню (дрова %d/%d)" % [cfg["name"], Game.count("wood"), int(cfg["brazier"]["wood"])]
		if melt_left() > 0.0:
			return "Лёд тает... ещё ~%d c" % int(ceil(melt_left()))
		return "Открыть: %s" % cfg["name"]
	if cfg.has("needs_flag") and not Game.flags.get(cfg["needs_flag"], false):
		return cfg.get("locked_hint", "%s — за водой, не подойти. Сначала спусти воду" % cfg["name"])
	if cfg.has("needs") and not Game.flags.get("poi_" + id, false) and not Game.has_tool(cfg["needs"]) and Game.count(cfg["needs"]) == 0:
		return "%s — заперт (нужен: %s)" % [cfg["name"], Game.item_name(cfg["needs"])]
	if cfg.has("restore") and not Game.flags.get("restored_" + id, false):
		return "Отстроить: %s (нужно: %s)" % [cfg["name"], _cost_text(cfg["restore"])]
	if not Game.flags.get("poi_" + id, false):
		return "Осмотреть: %s" % cfg["name"]
	if cfg.has("fuel") and not Game.flags.get(_lit_flag(), false):
		if cfg.get("needs_storm", false):
			return "%s — зажечь может только молния. Жди грозу" % cfg.get("restored_name", cfg["name"]) if not Game.storm_active() \
				else "Гроза! Молния бьёт в шпиль — зажечь Башню громов"
		return "Зажечь огонь (нужно: %s)" % _cost_text(cfg["fuel"])
	return cfg.get("restored_name", cfg["name"]) if Game.flags.get("restored_" + id, false) else cfg["name"]


## Сколько секунд ещё тает лёд у ларца с жаровней (по игровому времени — сон тоже считается).
func melt_left() -> float:
	var cfg: Dictionary = PLACES[id]
	if not Game.flags.has("melt_" + id):
		return float(cfg.get("melt", 0.0))
	return maxf(0.0, float(cfg.get("melt", 0.0)) - (Game.world_time - float(Game.flags["melt_" + id])))


func interact(_player: Node) -> void:
	var cfg: Dictionary = PLACES[id]
	if cfg.has("brazier") and not Game.flags.get("poi_" + id, false):
		if not Game.flags.has("melt_" + id):
			if Game.pay(cfg["brazier"]):
				Game.flags["melt_" + id] = Game.world_time
				_place_brazier(true)
				Game.notified.emit("Жаровня горит. Лёд начал таять", Color("ffe08a"))
			else:
				Game.notified.emit("Для жаровни нужно дров: %d" % int(cfg["brazier"]["wood"]), Color("ff9d7a"))
			return
		if melt_left() > 0.0:
			Game.notified.emit(get_hint(), Color("ffe08a"))
			return
		var lid := visual.find_child("Lid", true, false) as Node3D
		if lid:
			create_tween().tween_property(lid, "rotation:x", -1.6, 0.4)
		if id.begins_with("ice_chest"):
			Game.bump("found", "ice_chest")
	if cfg.has("needs_flag") and not Game.flags.get(cfg["needs_flag"], false):
		Game.notified.emit(cfg.get("locked_hint", "Не подойти — мешает вода"), Color("ff9d7a"))
		return
	if cfg.has("needs") and Game.count(cfg["needs"]) == 0 and not Game.flags.get("poi_" + id, false):
		Game.notified.emit("Заперто. Нужен: %s" % Game.item_name(cfg["needs"]), Color("ff9d7a"))
		return
	if cfg.has("restore") and not Game.flags.get("restored_" + id, false):
		if not Game.flags.get("poi_" + id, false):
			Game.flags["poi_" + id] = true
			Game.dialogue_requested.emit(cfg["lines"], Callable())
			return
		if Game.pay(cfg["restore"]):
			Game.flags["restored_" + id] = true
			_swap_model(true)
			Audio.play("build", 0.0, 0.0)
			FX.burst(self, Vector3(0, 1.5, 0), Color("ffe08a"), 24)
			Game.notified.emit("Отстроено: %s" % cfg["restored_name"], Color("8affa0"))
			Game.bump("restored", id)
			if not cfg.has("fuel"):
				remove_from_group("interactable")
		else:
			Game.notified.emit("Не хватает: %s" % _cost_text(cfg["restore"]), Color("ff9d7a"))
		return
	if not Game.flags.get("poi_" + id, false):
		Game.flags["poi_" + id] = true
		Audio.play(cfg.get("sound", "rare"), -2.0)
		FX.burst(self, Vector3(0, 1.0, 0), Color("ffe08a"), 18)
		Game.dialogue_requested.emit(cfg["lines"], Callable())
		for k in cfg["loot"]:
			Game.add_item(k, cfg["loot"][k], false)
		for i in int(cfg["pages"]):
			Game.add_collectible("journal")
		for i in int(cfg.get("journal_pages", 0)):
			Game.add_collectible(cfg["journal"])
		if id == "lyova_chest":
			var lid := visual.find_child("Lid", true, false) as Node3D
			if lid:
				create_tween().tween_property(lid, "rotation:x", -1.6, 0.4)
		Game.bump("found", id)
		if id == "fort_gate":
			var fort := get_parent() as FortRuin
			if fort:
				fort.open_gate(true)
		if not cfg.has("fuel") and not cfg.has("restore"):
			remove_from_group("interactable")
		return
	if cfg.has("fuel") and not Game.flags.get(_lit_flag(), false):
		if cfg.get("needs_storm", false) and not Game.storm_active():
			Game.notified.emit("Огонь зажжёт только молния. Дождись грозы и подойди к башне", Color("ffe08a"))
			return
		if Game.pay(cfg["fuel"]):
			Game.flags[_lit_flag()] = true
			light_fire(true)
			Game.bump("lit", id)
		else:
			Game.notified.emit("Нужно топливо: %s" % _cost_text(cfg["fuel"]), Color("ff9d7a"))


func _swap_model(animate: bool) -> void:
	var cfg: Dictionary = PLACES[id]
	if not cfg.has("restored_model"):
		return   # своей модели нет (части «Альбатроса» — их рисует сам корабль)
	var m := Models.glb(cfg["restored_model"])
	if m == null:
		return
	visual.queue_free()
	visual = m
	add_child(m)
	for o in _solids:
		o.queue_free()
	_solids = Models.add_trimesh(self, m)
	if animate:
		m.scale = Vector3(0.05, 0.05, 0.05)
		create_tween().tween_property(m, "scale", Vector3.ONE, 0.6).set_trans(Tween.TRANS_BACK)


var brazier: Node3D
var _ice_block: Node3D


## Жаровня у ларца: ставится рядом, горит, пока лёд не растает (и потом тоже — для уюта).
func _place_brazier(animate: bool) -> void:
	if brazier:
		return
	brazier = Models.glb("brazier")
	if brazier == null:
		brazier = Node3D.new()
	brazier.position = Vector3(1.1, 0, 0.5)
	add_child(brazier)
	var point := brazier.find_child("FirePoint", true, false) as Node3D
	Models.flame(brazier, point.position if point else Vector3(0, 0.75, 0), 0.6, 1.6, 7.0)
	if animate:
		brazier.scale = Vector3(0.05, 0.05, 0.05)
		create_tween().tween_property(brazier, "scale", Vector3.ONE, 0.4).set_trans(Tween.TRANS_BACK)
		Audio.play("build", -4.0, 0.05)


func light_fire(animate: bool) -> void:
	if fire:
		return
	var point := visual.find_child("FirePoint", true, false) as Node3D
	var at: Vector3 = point.position if point else Vector3(0, 5.5, 0)
	fire = Models.flame(visual, at, 2.0, 4.0, 30.0)
	if id == "storm_tower":
		# огонь, зажжённый молнией, — бело-голубой
		var l := visual.get_node_or_null("Light") as OmniLight3D
		if l:
			l.light_color = Color("cfe4ff")
		if animate:
			get_tree().call_group("weather", "strike_at", global_position + Vector3(0, 13.0, 0))
	if id == "volcano_tower":
		var l := visual.get_node_or_null("Light") as OmniLight3D
		if l:
			l.light_color = Color("ff6a2a")
	if id == "fog_tower":
		Game.flags["fog_cleared"] = true
	if id == "ice_tower":
		Game.flags["ice_thawed"] = true
		if animate:   # при загрузке остров и так строится уже оттаявшим
			get_tree().call_group("island", "thaw", true)
	if animate:
		fire.scale = Vector3(0.05, 0.05, 0.05)
		create_tween().tween_property(fire, "scale", Vector3.ONE, 1.5).set_trans(Tween.TRANS_BACK)
		Audio.play("quest", 0.0, 0.0)


func _process(_delta: float) -> void:
	if brazier and visual and not Game.flags.get("poi_" + id, false):
		# лёд вокруг ларца оседает, пока горит жаровня
		if _ice_block == null:
			_ice_block = visual.find_child("Ice", true, false) as Node3D
		if _ice_block:
			var k := clampf(melt_left() / float(PLACES[id].get("melt", 1.0)), 0.0, 1.0)
			_ice_block.scale = Vector3(lerpf(0.75, 1.0, k), k, lerpf(0.75, 1.0, k))
			_ice_block.visible = k > 0.02
	elif _ice_block and Game.flags.get("poi_" + id, false):
		_ice_block.visible = false
	if fire:
		# пламя колышется само (шейдер), а свет чуть мерцает
		var l := visual.get_node_or_null("Light") as OmniLight3D
		if l:
			var t := Time.get_ticks_msec() / 1000.0
			l.light_energy = 4.0 * (0.88 + 0.12 * sin(t * 9.0) * sin(t * 5.7))
