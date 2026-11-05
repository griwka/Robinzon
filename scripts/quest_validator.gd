class_name QuestValidator
## Проверка сюжета «на бумаге»: идём по всем заданиям всех глав по порядку, копим открытия
## (постройки, рецепты, лавки, товары) и для каждого пункта задания проверяем, что всё нужное
## к этому моменту действительно можно достать. Так ловятся задания, которые технически невыполнимы:
## рецепт ещё не открыт, товар не продаётся, ресурса нет ни в природе, ни в лавке, ни в награде.
## Ещё считает экономику: сколько монет нужно заработать в каждой главе.

const KNOWN_KINDS := ["talk", "collected", "crafted", "built", "planted", "harvested", "watered", "fed", "product",
	"caught", "sailed", "cleared", "found", "lit", "reached", "collection", "delivered", "sold", "bought", "restored"]
const NPCS := ["parrot", "marta", "kesha"]
const DECKS := ["deck1", "deck2", "deck3"]

var unlocked := {}
var given := {}        # предметы из наград и находок (разовые)
var errors: Array[String] = []
var report: Array[String] = []
var _where := ""


func run(chapters: Array = Data.CHAPTERS) -> Array[String]:
	errors.clear()
	report.clear()
	for ci in chapters.size():
		var ch: Dictionary = chapters[ci]
		var spend := 0
		var earn := 0
		for q in ch["quests"]:
			_where = "%s → «%s»" % [ch["title"], q["title"]]
			for line in q.get("intro", []) + q.get("outro", []):
				if not Data.SPEAKERS.has(line[0]):
					_err("неизвестный говорящий «%s»" % line[0])
			for t in q["tasks"]:
				_check_task(t)
				if t["kind"] == "bought" and t["target"] != "any":
					spend += _min_price(t["target"]) * int(t["count"])
				# находка сразу доступна для следующих пунктов того же задания
				if t["kind"] in ["found", "restored"] and StoryPlace.PLACES.has(t["target"]):
					for id in StoryPlace.PLACES[t["target"]]["loot"]:
						given[id] = true
				if t["kind"] == "found" and t["target"] == "crate":
					for id in SupplyCrate.LOOT:
						given[id] = true
			var rw: Dictionary = q.get("reward", {})
			for id in rw.get("unlock", []):
				if not _unlock_exists(id):
					_err("награда открывает несуществующее «%s»" % id)
				unlocked[id] = true
			for id in rw.get("items", {}):
				given[id] = true
				if id == "coins":
					earn += int(rw["items"][id])
		report.append("%s: купить в лавках на %d монет, в наградах %d — остальное (%d) зарабатывается хозяйством"
			% [ch["title"], spend, earn, maxi(0, spend - earn)])
	_check_pages(chapters)
	return errors


## Страницы журналов выдаются строго по сюжету — их должно хватать на всю коллекцию.
func _check_pages(chapters: Array) -> void:
	var got := {}
	for ch in chapters:
		for q in ch["quests"]:
			for t in q["tasks"]:
				if t["kind"] == "found" and t["target"] == "crate":
					got["journal"] = got.get("journal", 0) + 1
				elif t["kind"] in ["found", "restored"] and StoryPlace.PLACES.has(t["target"]):
					var cfg: Dictionary = StoryPlace.PLACES[t["target"]]
					got["journal"] = got.get("journal", 0) + int(cfg.get("pages", 0))
					if cfg.has("journal"):
						got[cfg["journal"]] = got.get(cfg["journal"], 0) + int(cfg.get("journal_pages", 0))
			got["journal"] = got.get("journal", 0) + int(q.get("reward", {}).get("pages", 0))
	for cid in Data.COLLECTIONS:
		var col: Dictionary = Data.COLLECTIONS[cid]
		if col.get("ordered", false):
			_where = "Коллекция «%s»" % col["name"]
			var need: int = col["items"].size()
			if got.get(cid, 0) < need:
				_err("по сюжету выдаётся %d страниц из %d — коллекцию не собрать" % [got.get(cid, 0), need])
			report.append("%s: страниц по сюжету %d из %d" % [col["name"], got.get(cid, 0), need])


func _err(msg: String) -> void:
	errors.append("%s: %s" % [_where, msg])


func _unlock_exists(id: String) -> bool:
	if Data.BUILDINGS.has(id):
		return true
	for r in Data.RECIPES:
		if r["id"] == id:
			return true
	if id.begins_with("shop_"):
		return Data.SHOPS.has(id.substr(5))
	if id.begins_with("buy_"):
		for sh in Data.SHOPS.values():
			for e in sh["buy"]:
				if e.get("unlock", "") == id:
					return true
	return false


func _min_price(id: String) -> int:
	var best := 999999
	for sh in Data.SHOPS.values():
		for e in sh["buy"]:
			if e["item"] == id:
				best = mini(best, e["price"])
	return best if best < 999999 else 0


# ------------------------------------------------------------------ откуда берётся предмет
func can_get(id: String, depth := 0) -> bool:
	if depth > 8:
		return false
	if given.has(id):
		return true
	if not Data.ITEMS.has(id):
		return false
	# природа: ресурсы на островах (с нужным инструментом)
	for k in ResourceNode.KINDS:
		var cfg: Dictionary = ResourceNode.KINDS[k]
		if cfg["drops"].has(id) and (cfg["tool"] == "" or can_get(cfg["tool"], depth + 1)):
			return true
	if id in ["leaf", "coconut"]:
		return true   # пальму можно трясти без инструментов
	for t in Data.TREES.values():
		if t["fruit"] == id:
			return true   # дикие деревья
	if Data.CROPS.has(id) and can_get("seed_" + id, depth + 1):
		return true
	if id in ResourceNode.BUSH_SEEDS:
		return true
	for b in Data.PENS:
		var pen: Dictionary = Data.PENS[b]
		if pen["product"] == id and _building_ok(b, depth + 1):
			var feed_ok := true
			for f in pen["feed"]:
				feed_ok = feed_ok and can_get(f, depth + 1)
			if feed_ok:
				return true
	for r in Data.RECIPES:
		if r["out"].has(id) and (not r.get("unlock", false) or unlocked.has(r["id"])):
			var ok := true
			for i in r["in"]:
				ok = ok and can_get(i, depth + 1)
			if ok:
				return true
	if id == "coins":
		for sh in Data.SHOPS:
			if unlocked.has("shop_" + sh):
				for p in Data.SELL_PRICES:
					if can_get(p, depth + 1):
						return true
		return false
	if _in_shop(id) and can_get("coins", depth + 1):
		return true
	return false


func _in_shop(id: String) -> bool:
	for sh in Data.SHOPS:
		if not unlocked.has("shop_" + sh):
			continue
		for e in Data.SHOPS[sh]["buy"]:
			if e["item"] == id and (not e.has("unlock") or unlocked.has(e["unlock"])):
				return true
	return false


func _building_ok(id: String, depth := 0) -> bool:
	if not Data.BUILDINGS.has(id):
		return false
	var b: Dictionary = Data.BUILDINGS[id]
	if b.get("unlock", false) and not unlocked.has(id):
		return false
	for c in b["cost"]:
		if not can_get(c, depth + 1):
			return false
	return true


func _recipe(id: String) -> Dictionary:
	for r in Data.RECIPES:
		if r["out"].has(id):
			return r
	return {}


# ------------------------------------------------------------------ проверка одного пункта
func _check_task(t: Dictionary) -> void:
	var kind: String = t["kind"]
	var tgt: String = t["target"]
	if not kind in KNOWN_KINDS:
		_err("неизвестный тип задания «%s»" % kind)
		return
	if t.has("where") and not Data.LOCATIONS.has(t["where"]):
		_err("неизвестный остров «%s»" % t["where"])
	match kind:
		"talk":
			if not tgt in NPCS:
				_err("не с кем говорить: «%s»" % tgt)
		"collected":
			if not can_get(tgt):
				_err("«%s»: предмет негде достать" % tgt)
		"crafted":
			var r := _recipe(tgt)
			if r.is_empty():
				_err("нет рецепта для «%s»" % tgt)
			elif r.get("unlock", false) and not unlocked.has(r["id"]):
				_err("рецепт «%s» ещё не открыт" % tgt)
			else:
				for i in r["in"]:
					if not can_get(i):
						_err("для «%s» не достать «%s»" % [tgt, i])
		"built":
			if not Data.BUILDINGS.has(tgt):
				_err("нет постройки «%s»" % tgt)
			elif tgt == "fruit_tree":
				if not unlocked.has(tgt) or not (can_get("sapling_banana") or can_get("sapling_lemon") or can_get("sapling_mango")):
					_err("нечего посадить: нет саженцев или дерево не открыто")
			elif not _building_ok(tgt):
				_err("постройку «%s» нельзя построить: не открыта или не хватает материалов" % tgt)
		"planted", "harvested":
			if not can_get("seed_" + tgt):
				_err("нет семян «%s»" % tgt)
			if not _building_ok("garden_bed"):
				_err("грядки ещё не открыты")
		"watered":
			if not can_get("watering_can"):
				_err("нет лейки")
		"fed":
			if not _building_ok(tgt):
				_err("загон «%s» не построить" % tgt)
		"product":
			if not can_get(tgt):
				_err("продукт «%s» не получить" % tgt)
		"caught":
			if not can_get("net"):
				_err("нет сачка")
		"sailed":
			if not (_building_ok("raft") or _building_ok("canoe")):
				_err("не на чем плыть")
		"cleared":
			if not ResourceNode.KINDS.has(tgt):
				_err("нет преграды «%s»" % tgt)
			elif ResourceNode.KINDS[tgt]["tool"] != "" and not can_get(ResourceNode.KINDS[tgt]["tool"]):
				_err("нечем расчистить «%s»" % tgt)
		"found", "lit", "restored":
			if tgt in ["crate", "wreck"]:
				return
			if not StoryPlace.PLACES.has(tgt):
				_err("нет места «%s»" % tgt)
				return
			var cfg: Dictionary = StoryPlace.PLACES[tgt]
			for key in ["restore", "fuel"]:
				for i in cfg.get(key, {}):
					if not can_get(i):
						_err("для «%s» не достать «%s»" % [tgt, i])
			if cfg.has("needs") and not can_get(cfg["needs"]):
				_err("«%s» заперт, а ключа не достать" % tgt)
		"reached":
			if not tgt in DECKS:
				_err("нет яруса «%s»" % tgt)
			elif not can_get("climbing_gloves"):
				_err("на ярус не залезть без перчаток")
		"collection":
			if not Data.COLLECTIONS.has(tgt):
				_err("нет коллекции «%s»" % tgt)
		"delivered":
			if not can_get(tgt):
				_err("нечего отдать: «%s» не достать" % tgt)
			if t.has("to") and not t["to"] in NPCS:
				_err("некому отдать: «%s»" % t["to"])
		"sold":
			var open := false
			for sh in Data.SHOPS:
				if unlocked.has("shop_" + sh) and (tgt == "any" or tgt == sh):
					open = true
			if not open:
				_err("лавка «%s» ещё закрыта" % tgt)
		"bought":
			if tgt == "any":
				var any_open := false
				for sh in Data.SHOPS:
					any_open = any_open or unlocked.has("shop_" + sh)
				if not any_open:
					_err("ни одна лавка не открыта")
			elif not _in_shop(tgt):
				_err("«%s» не продаётся (лавка закрыта или товар не открыт)" % tgt)
			elif not can_get("coins"):
				_err("негде заработать монеты")
