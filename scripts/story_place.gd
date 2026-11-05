class_name StoryPlace
extends StaticBody3D
## Сюжетное место в глубине острова: старый лагерь Лёвы, шлюпка «Альбатроса», древний маяк.
## Добраться можно, только расчистив путь нужными инструментами. Осмотр даёт находки и страницу журнала.

const PLACES := {
	"wreck": {"model": "", "name": "Обломки «Чайки»", "radius": 0.0,
		"loot": {"scrap": 1, "rope": 1}, "pages": 0,
		"lines": [["player", "Среди досок — погнутая полоса металла от уключины. Если наточить о камень, выйдет лезвие."]]},
	"old_camp": {"model": "old_camp", "name": "Старый лагерь Лёвы", "radius": 1.6,
		"loot": {"rope": 3, "seed_cabbage": 2, "sapling_mango": 1}, "pages": 1,
		"lines": [["player", "Рухнувшая палатка, остывший очаг... На пюпитре — размокший журнал. Это почерк Лёвы."],
			["parrot", "Лагерь! Здесь Лёва жил, когда команда ушла к форту. Румба помнит этот запах... мокрый брезент."]]},
	"lifeboat": {"model": "lifeboat", "name": "Шлюпка «Альбатроса»", "radius": 1.8,
		"loot": {"sail": 1, "rope": 2, "plank": 4}, "pages": 1,
		"lines": [["player", "На борту облупившиеся буквы: «АЛЬБАТРОС-2». Под банкой — свёрнутый парус и ещё одна страница."],
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
	if id == "lighthouse" or not Game.flags.get("poi_" + id, false):
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
	c.height = 2.5 if id != "lighthouse" else 5.0
	cs.shape = c
	cs.position.y = c.height * 0.5
	add_child(cs)
	if id == "lighthouse" and Game.flags.get("lighthouse_lit", false):
		light_fire(false)


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


func get_hint() -> String:
	var cfg: Dictionary = PLACES[id]
	if not Game.flags.get("poi_" + id, false):
		return "Осмотреть: %s" % cfg["name"]
	if id == "lighthouse" and not Game.flags.get("lighthouse_lit", false):
		return "Зажечь маяк (нужно: %s)" % _cost_text(cfg["fuel"])
	return cfg["name"]


func interact(_player: Node) -> void:
	var cfg: Dictionary = PLACES[id]
	if not Game.flags.get("poi_" + id, false):
		Game.flags["poi_" + id] = true
		Audio.play("rare", -2.0)
		FX.burst(self, Vector3(0, 1.0, 0), Color("ffe08a"), 18)
		Game.dialogue_requested.emit(cfg["lines"], Callable())
		for k in cfg["loot"]:
			Game.add_item(k, cfg["loot"][k], false)
		for i in int(cfg["pages"]):
			Game.add_collectible("journal")
		Game.bump("found", id)
		if id != "lighthouse":
			remove_from_group("interactable")
		return
	if id == "lighthouse" and not Game.flags.get("lighthouse_lit", false):
		if Game.pay(cfg["fuel"]):
			Game.flags["lighthouse_lit"] = true
			light_fire(true)
			Game.bump("lit", "lighthouse")
		else:
			Game.notified.emit("Нужно топливо: %s" % _cost_text(cfg["fuel"]), Color("ff9d7a"))


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
