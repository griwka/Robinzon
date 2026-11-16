class_name WorldChecks
extends RefCounted
## Проверки «живого мира» для валидатора (зовёт CozyChecks.run в конце): коллекции находок описаны целиком,
## у всего есть иконки и модели, в тайниках и наградах нет монет и нет дорогого, слухи есть про каждое существо.

const MODELS := ["drift_bottle", "drift_glass", "drift_float", "drift_pod", "rune_stone_a", "rune_stone_b", "rune_stone_c",
	"rune_cache", "sign_stone", "glow_crab", "gold_beetle", "sea_turtle"]
const COLS := ["sea_bottles", "sea_glass", "signs", "rare_life"]
const REWARD_MAX := 60       # награда за коллекцию — не дороже стольких монет по прейскуранту


static func _value(items: Dictionary) -> int:
	var v := 0
	for id in items:
		v += int(Data.SELL_PRICES.get(id, 3)) * int(items[id])
	return v


static func run(v: QuestValidator) -> void:
	v._where = "Живой мир"
	for m in MODELS:
		if not ResourceLoader.exists("res://assets/models/%s.glb" % m):
			v._err("нет модели «%s»" % m)
	for cid in COLS:
		if not Data.COLLECTIONS.has(cid):
			v._err("нет коллекции «%s»" % cid)
			continue
		var col: Dictionary = Data.COLLECTIONS[cid]
		if col.get("ordered", false):
			v._err("коллекция «%s» не должна быть «по порядку»: её страницы не выдаются по сюжету" % cid)
		for it in col["items"]:
			if not ResourceLoader.exists("res://assets/icons/%s.png" % it["id"]):
				v._err("у «%s» из коллекции «%s» нет иконки" % [it["id"], col["name"]])
		var rw: Dictionary = col.get("reward", {})
		var items: Dictionary = rw.get("items", {})
		if items.has("coins"):
			v._err("награда за «%s» — монеты, а должна быть вещами" % col["name"])
		for id in items:
			if not Data.ITEMS.has(id):
				v._err("награда за «%s»: нет предмета «%s»" % [col["name"], id])
		if _value(items) > REWARD_MAX:
			v._err("награда за «%s» стоит %d — больше %d" % [col["name"], _value(items), REWARD_MAX])
		for u in rw.get("unlock", []):
			if not Data.BUILDINGS.has(u):
				v._err("награда за «%s» открывает несуществующее «%s»" % [col["name"], u])
	# находки с моря
	for s in SeaDrift.POD_SEEDS:
		if not Data.ITEMS.has(s):
			v._err("в стручке — несуществующие семена «%s»" % s)
	# знаки и тайники
	var worst := 0
	for loc in RuneStones.ISLANDS:
		if not Data.LOCATIONS.has(loc):
			v._err("камни со знаками на несуществующем острове «%s»" % loc)
		if not RuneStones.LOOT.has(loc):
			v._err("у тайника острова «%s» нет содержимого" % loc)
			continue
		var loot: Dictionary = RuneStones.LOOT[loc]
		for id in loot:
			if not Data.ITEMS.has(id):
				v._err("в тайнике «%s» несуществующее «%s»" % [loc, id])
		if loot.has("coins"):
			v._err("в тайнике «%s» монеты — должны быть вещи" % loc)
		worst = maxi(worst, _value(loot))
		if _value(loot) > RuneStones.LOOT_MAX_VALUE:
			v._err("тайник «%s» стоит %d — больше %d" % [loc, _value(loot), RuneStones.LOOT_MAX_VALUE])
		var found := false
		for it in Data.COLLECTIONS.get("signs", {}).get("items", []):
			if it["id"] == "sign_" + loc:
				found = true
		if not found:
			v._err("для острова «%s» нет знака в коллекции «Знаки строителей»" % loc)
	if Data.COLLECTIONS.get("signs", {}).get("items", []).size() != RuneStones.ISLANDS.size():
		v._err("знаков в коллекции не столько же, сколько островов с камнями")
	if not v.can_get("shovel"):
		v._err("тайники копают лопатой, а её негде взять")
	# украшение за знаки
	var ss: Dictionary = Data.BUILDINGS.get("sign_stone", {})
	if ss.is_empty() or not ss.get("secret", false) or not ss.get("decor", false):
		v._err("«Камень со знаками» должен быть украшением с secret: true")
	else:
		for c in ss["cost"]:
			if not v.can_get(c):
				v._err("«Камень со знаками»: материал «%s» негде взять" % c)
		if not ResourceLoader.exists("res://assets/icons/sign_stone.png"):
			v._err("у «Камня со знаками» нет иконки")
	# редкие существа и слухи
	var ids := {}
	for it in Data.COLLECTIONS.get("rare_life", {}).get("items", []):
		ids[it["id"]] = true
		if not RareLife.RUMORS.has(it["id"]):
			v._err("про «%s» нет слуха — игрок о нём не узнает" % it["name"])
	for id in RareLife.RUMORS:
		if not ids.has(id):
			v._err("слух про несуществующее существо «%s»" % id)
		var who: String = RareLife.RUMORS[id][0]
		if not CozyLife.GUESTS.has(who):
			v._err("слух про «%s» рассказывает «%s», а он не заходит к костру" % [id, who])
	for t in ["net", "fishing_rod"]:
		if not v.can_get(t):
			v._err("для редких существ нужен «%s», а его негде взять" % t)
	v.report.append("Живой мир: коллекций %d, тайников %d (самый богатый — %d монет вещами, монет в них нет), редких существ %d"
		% [COLS.size(), RuneStones.ISLANDS.size(), worst, ids.size()])
