class_name QuestValidator
## Проверка сюжета «на бумаге»: идём по всем заданиям всех глав по порядку, копим открытия
## (постройки, рецепты, лавки, товары) и для каждого пункта задания проверяем, что всё нужное
## к этому моменту действительно можно достать. Так ловятся задания, которые технически невыполнимы:
## рецепт ещё не открыт, товар не продаётся, ресурса нет ни в природе, ни в лавке, ни в награде.
## Ещё считает экономику: сколько монет нужно заработать в каждой главе.

const KNOWN_KINDS := ["talk", "collected", "crafted", "built", "planted", "harvested", "watered", "fed", "product",
	"caught", "sailed", "cleared", "found", "lit", "reached", "collection", "delivered", "sold", "bought", "restored",
	"fished", "solved", "chose"]
const NPCS := ["parrot", "marta", "kesha", "stepa", "timur", "ingrid", "walrus", "penguins", "vera",
	"misha", "renata", "gosha", "petya", "pasha", "lyova"]
const PUZZLES := ["cellar", "stars", "monolith", "shadows"]
const ALBATROS_PARTS := ["albatros_hull", "albatros_mast", "albatros_helm", "albatros_lights", "albatros_radio"]
const DECKS := ["deck1", "deck2", "deck3",
	"bunker1", "bunker2", "bunker3", "bunker4", "bunker5", "bunker6", "bunker7", "glacier_top", "temple_gate", "crater_top", "stilt_camp",
	"eye_deck1", "eye_deck2", "eye_deck3"]
## Ледяные ларцы: задание «found ice_chest ×3» — это три места ice_chest_1..3.
const ICE_CHESTS := ["ice_chest_1", "ice_chest_2", "ice_chest_3"]

var unlocked := {}
var given := {}        # предметы из наград и находок (разовые)
var solved_seen := {}
var restored_seen := {}
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
				if t["kind"] == "solved":
					solved_seen[t["target"]] = true
				if t["kind"] == "restored":
					restored_seen[t["target"]] = true
				# подарок за разговор (пирог Марты, бинты Веры) — сразу в сумке
				for id in t.get("give", {}):
					given[id] = true
				if t["kind"] == "bought" and t["target"] != "any":
					spend += _min_price(t["target"]) * int(t["count"])
				# находка сразу доступна для следующих пунктов того же задания
				if t["kind"] in ["found", "restored"] and StoryPlace.PLACES.has(t["target"]):
					for id in StoryPlace.PLACES[t["target"]]["loot"]:
						given[id] = true
				if t["kind"] == "found" and t["target"] == "crate":
					for id in SupplyCrate.LOOT:
						given[id] = true
				if t["kind"] == "found" and t["target"] == "ice_chest":
					for c in ICE_CHESTS:
						for id in StoryPlace.PLACES[c]["loot"]:
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
	_check_crops()
	return errors


## Грядки: каждая культура окупает свой пакетик, а семян с грядки в среднем меньше одного (лавка нужна).
## В отчёт — выгода в монетах за минуту роста (без полива).
func _check_crops() -> void:
	_where = "Грядки"
	for c in Data.CROPS:
		var cfg: Dictionary = Data.CROPS[c]
		var price := _min_price("seed_" + c)
		var sell: int = Data.SELL_PRICES.get(c, 0)
		var avg := (float(cfg["yield"][0]) + float(cfg["yield"][1])) * 0.5
		var back: float = cfg["seed_back"]
		if back >= 1.0:
			_err("«%s»: семена возвращаются всегда — покупать их незачем" % c)
		if price > 0 and sell > 0:
			var profit := avg * sell - price * (1.0 - back)
			if profit <= 0.0:
				_err("«%s»: урожай не окупает пакетик семян" % c)
			report.append("%s: %.1f мон/мин (пакетик %d, урожай %.1f × %d, семечко назад %d%%)"
				% [cfg["name"], profit / float(cfg["time"]) * 60.0, price, avg, sell, int(back * 100.0)])


## Страницы журналов выдаются строго по сюжету — их должно хватать на всю коллекцию.
func _check_pages(chapters: Array) -> void:
	var got := {}
	for ch in chapters:
		for q in ch["quests"]:
			for t in q["tasks"]:
				if t["kind"] == "found" and t["target"] == "crate":
					got["journal"] = got.get("journal", 0) + 1
				elif t["kind"] in ["found", "restored"] and (StoryPlace.PLACES.has(t["target"]) or t["target"] == "ice_chest"):
					for pid in (ICE_CHESTS if t["target"] == "ice_chest" else [t["target"]]):
						var cfg: Dictionary = StoryPlace.PLACES[pid]
						got["journal"] = got.get("journal", 0) + int(cfg.get("pages", 0))
						if cfg.has("journal"):
							got[cfg["journal"]] = got.get(cfg["journal"], 0) + int(cfg.get("journal_pages", 0))
			got["journal"] = got.get("journal", 0) + int(q.get("reward", {}).get("pages", 0))
			var col: Dictionary = q.get("reward", {}).get("collect", {})
			for cid in col:
				got[cid] = got.get(cid, 0) + int(col[cid])
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
	if id == "fish" and can_get("fishing_rod", depth + 1):
		return true
	if id == "firefly" and can_get("net", depth + 1):
		return true   # светлячков ловят сачком на Туманном острове
	for t in Data.TREES.values():
		if t["fruit"] == id:
			return true   # дикие деревья
	if Data.CROPS.has(id) and can_get("seed_" + id, depth + 1):
		return true
	if id in ResourceNode.BUSH_SEEDS:
		return true
	for b in Data.PENS:
		var pen: Dictionary = Data.PENS[b]
		if (pen["product"] == id or pen.get("bonus", {}).has(id)) and _building_ok(b, depth + 1):
			var feed_ok := true
			for f in pen["feed"]:
				feed_ok = feed_ok and can_get(f, depth + 1)
			if feed_ok:
				return true
	for r in Data.RECIPES:
		if r["out"].has(id) and (not r.get("unlock", false) or unlocked.has(r["id"])):
			var ok: bool = r["station"] == "" or _building_ok(r["station"], depth + 1)
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
			if t.get("radio", false) and not can_get("radio_set"):
				_err("с «%s» — по рации, а рации ещё нет" % tgt)
			for line in t.get("say", []):
				if not Data.SPEAKERS.has(line[0]):
					_err("неизвестный говорящий «%s»" % line[0])
		"chose":
			if tgt != "ending":
				_err("выбирать можно только финал, а не «%s»" % tgt)
			if not given.has("pie") or not given.has("bandages"):
				_err("к выбору не дойти: нет подарков для Лёвы")
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
			if t.has("near") and t["near"] != "camp" and not Data.BUILDINGS.has(t["near"]):
				_err("«рядом с %s» — такой постройки нет" % t["near"])
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
		"fished":
			if not can_get("fishing_rod"):
				_err("нечем ловить рыбу — нет удочки")
			if tgt == "ice_fish" and not can_get("ice_drill"):
				_err("подо льдом не порыбачить — нет ледового бура")
		"solved":
			if not tgt in PUZZLES:
				_err("нет головоломки «%s»" % tgt)
		"sailed":
			if not (_building_ok("raft") or _building_ok("canoe")):
				_err("не на чем плыть")
			if tgt == "albatros":
				for part in ALBATROS_PARTS:
					if not restored_seen.has(part):
						_err("«Альбатрос» не выйти в море: не починено «%s»" % part)
			if Data.LOCATIONS.has(tgt):
				var flag: String = Data.LOCATIONS[tgt].get("unlock_flag", "")
				if flag.begins_with("restored_") and not restored_seen.has(flag.substr(9)):
					_err("на «%s» не доплыть: «%s» ещё не починен" % [tgt, flag.substr(9)])
		"cleared":
			if not ResourceNode.KINDS.has(tgt):
				_err("нет преграды «%s»" % tgt)
			elif ResourceNode.KINDS[tgt]["tool"] != "" and not can_get(ResourceNode.KINDS[tgt]["tool"]):
				_err("нечем расчистить «%s»" % tgt)
		"found", "lit", "restored":
			if tgt in ["crate", "wreck"]:
				return
			if tgt == "ice_chest":
				for c in ICE_CHESTS:
					if not StoryPlace.PLACES.has(c):
						_err("нет ларца «%s»" % c)
						continue
					for i in StoryPlace.PLACES[c].get("brazier", {}):
						if not can_get(i):
							_err("ларец «%s» не растопить: не достать «%s»" % [c, i])
					if StoryPlace.PLACES[c].get("climb", false) and not (can_get("ice_pick") and can_get("climbing_gloves")):
						_err("к ларцу «%s» не залезть: нужны ледоруб и перчатки" % c)
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
			if cfg.has("needs_flag") and cfg["needs_flag"] == "shadows_solved" and not solved_seen.has("shadows"):
				_err("«%s» за скалой, а головоломку теней ещё не решали" % tgt)
			if cfg.has("needs_flag") and cfg["needs_flag"] == "monolith_solved" and not solved_seen.has("monolith"):
				_err("«%s» за каменной дверью, а головоломку монолита ещё не решали" % tgt)
			if cfg.has("needs_flag") and cfg["needs_flag"] == "cellar_drained" and not solved_seen.has("cellar"):
				_err("«%s» за водой, а головоломку подвала ещё не решали" % tgt)
			if cfg.has("needs_flag") and str(cfg["needs_flag"]).begins_with("restored_") \
					and not restored_seen.has(str(cfg["needs_flag"]).substr(9)):
				_err("«%s» откроется после починки «%s», а её ещё не было" % [tgt, str(cfg["needs_flag"]).substr(9)])
		"reached":
			if not tgt in DECKS:
				_err("нет яруса «%s»" % tgt)
			elif tgt == "glacier_top":
				if not (can_get("ice_pick") and can_get("climbing_gloves")):
					_err("на ледник не залезть: нужны ледоруб и перчатки")
			elif tgt == "temple_gate":
				if not can_get("iron_pickaxe"):
					_err("к храму не пройти: базальт ломает только железная кирка")
				if not _building_ok("stone_bridge"):
					_err("через лаву не перейти: каменные мостки не открыты")
			elif tgt == "stilt_camp":
				pass   # лагерь на сваях открыт: к нему ведут мостки
			elif tgt.begins_with("eye_deck"):
				if not can_get("climbing_gloves"):
					_err("на Великий маяк не залезть без перчаток")
			elif tgt == "crater_top":
				if not can_get("climbing_gloves"):
					_err("на стену кратера не залезть без перчаток")
			elif tgt.begins_with("bunker"):
				# бункер: ярусы 2–3 видны при свете генератора (или фонаря), ниже — только с фонарём
				var k := int(tgt.substr(6))
				if k >= 4 and not can_get("lantern"):
					_err("на ярус «%s» без фонаря не спуститься" % tgt)
				elif k >= 2 and not (restored_seen.has("generator") or can_get("lantern")):
					_err("на ярус «%s» темно: генератор не починен и фонаря нет" % tgt)
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
