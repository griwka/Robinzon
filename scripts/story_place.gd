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
}

var id := "old_camp"
var visual: Node3D
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
	if cfg.has("fuel") and Game.flags.get(_lit_flag(), false):
		light_fire(false)
	if cfg.has("restore") and Game.flags.get("restored_" + id, false):
		_swap_model(false)


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
	if cfg.has("needs_flag") and not Game.flags.get(cfg["needs_flag"], false):
		return "%s — за водой, не подойти. Сначала спусти воду" % cfg["name"]
	if cfg.has("needs") and not Game.flags.get("poi_" + id, false) and not Game.has_tool(cfg["needs"]) and Game.count(cfg["needs"]) == 0:
		return "%s — заперт (нужен: %s)" % [cfg["name"], Game.item_name(cfg["needs"])]
	if cfg.has("restore") and not Game.flags.get("restored_" + id, false):
		return "Отстроить: %s (нужно: %s)" % [cfg["name"], _cost_text(cfg["restore"])]
	if not Game.flags.get("poi_" + id, false):
		return "Осмотреть: %s" % cfg["name"]
	if cfg.has("fuel") and not Game.flags.get(_lit_flag(), false):
		return "Зажечь огонь (нужно: %s)" % _cost_text(cfg["fuel"])
	return cfg["name"]


func interact(_player: Node) -> void:
	var cfg: Dictionary = PLACES[id]
	if cfg.has("needs_flag") and not Game.flags.get(cfg["needs_flag"], false):
		Game.notified.emit("Не подойти — мешает вода", Color("ff9d7a"))
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
			remove_from_group("interactable")
		else:
			Game.notified.emit("Не хватает: %s" % _cost_text(cfg["restore"]), Color("ff9d7a"))
		return
	if not Game.flags.get("poi_" + id, false):
		Game.flags["poi_" + id] = true
		Audio.play("rare", -2.0)
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
		if Game.pay(cfg["fuel"]):
			Game.flags[_lit_flag()] = true
			light_fire(true)
			Game.bump("lit", id)
		else:
			Game.notified.emit("Нужно топливо: %s" % _cost_text(cfg["fuel"]), Color("ff9d7a"))


func _swap_model(animate: bool) -> void:
	var cfg: Dictionary = PLACES[id]
	var m := Models.glb(cfg["restored_model"])
	if m == null:
		return
	visual.queue_free()
	visual = m
	add_child(m)
	if animate:
		m.scale = Vector3(0.05, 0.05, 0.05)
		create_tween().tween_property(m, "scale", Vector3.ONE, 0.6).set_trans(Tween.TRANS_BACK)


func light_fire(animate: bool) -> void:
	if fire:
		return
	fire = Node3D.new()
	var point := visual.find_child("FirePoint", true, false) as Node3D
	fire.position = point.position if point else Vector3(0, 5.5, 0)
	visual.add_child(fire)
	for spec in [[0.6, 1.6, Color("ff8a1e")], [0.35, 1.1, Color("ffe066")]]:
		var f := MeshInstance3D.new()
		f.mesh = Models.cyl(0.0, spec[0], spec[1], 8)
		f.material_override = Models.unshaded(spec[2])
		f.position.y = spec[1] * 0.4
		f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		fire.add_child(f)
	var l := OmniLight3D.new()
	l.light_color = Color("ffb35c")
	l.light_energy = 4.0
	l.omni_range = 30.0
	l.position.y = 1.0
	fire.add_child(l)
	if animate:
		fire.scale = Vector3(0.05, 0.05, 0.05)
		create_tween().tween_property(fire, "scale", Vector3.ONE, 1.5).set_trans(Tween.TRANS_BACK)
		Audio.play("quest", 0.0, 0.0)


func _process(_delta: float) -> void:
	if fire:
		var t := Time.get_ticks_msec() / 1000.0
		fire.scale.y = 0.9 + 0.15 * abs(sin(t * 7.0))
