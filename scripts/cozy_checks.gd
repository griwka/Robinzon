class_name CozyChecks
extends RefCounted
## Проверки кулинарии и уюта для валидатора (QuestValidator.run зовёт CozyChecks.run(self) в самом конце,
## когда «пройдены» все главы): рецепты достижимы, блюда не дороже своих продуктов больше чем на треть,
## украшения можно построить, у каждого есть модель и иконка, подарки гостей и заказы на блюда не льют монеты рекой.

const DISH_MARKUP := 1.3        # блюдо стоит не больше, чем его продукты × 1.3 (с округлением вверх)
const ORDER_MAX := 80           # заказ на блюдо с доски — не больше стольких монет


static func _price(id: String) -> int:
	return int(Data.SELL_PRICES.get(id, 0))


## Каждый материал постройки можно достать (каждый проверяем отдельно, с нуля: цепочка «гвозди → кузница → руда → кирка»
## длинная, а у QuestValidator.can_get есть предел глубины).
static func _can_build(v: QuestValidator, id: String) -> bool:
	for c in Data.BUILDINGS[id]["cost"]:
		if not v.can_get(c):
			return false
	return true


static func run(v: QuestValidator) -> void:
	# после финала: судно Лёвы, котелок и украшения открыты (GreatFire.choose и CozyLife.migrate)
	v.unlocked["shop_lyova"] = true
	v.unlocked["cook_pot"] = true
	for id in Data.BUILDINGS:
		if Data.BUILDINGS[id].get("decor", false):
			v.unlocked[id] = true

	# ---- кулинария
	v._where = "Кулинария"
	if not _can_build(v, "cook_pot"):
		v._err("котелок нельзя построить: чего-то из материалов не достать")
	var ratio := 0.0
	var seen := {}
	for r in Cooking.RECIPES:
		var id: String = r["id"]
		var it: Dictionary = Data.ITEMS.get(id, {})
		if it.get("cat", "") != "food" or not it.has("food"):
			v._err("блюдо «%s» не описано в Data.ITEMS как еда" % id)
			continue
		if not Data.SELL_PRICES.has(id):
			v._err("у блюда «%s» нет цены" % id)
			continue
		if it.has("buff") and not Cooking.BUFFS.has(it["buff"]):
			v._err("у блюда «%s» неизвестная польза «%s»" % [id, it["buff"]])
		var n := Cooking.units(r["in"])
		if n < Cooking.MIN_UNITS or n > Cooking.MAX_UNITS:
			v._err("рецепт «%s»: продуктов %d, а в котелок кладут 2–4" % [id, n])
		var sum := 0
		var keys: Array = r["in"].keys()
		keys.sort()
		var sig := ""
		for k in keys:
			sig += "%s×%d " % [k, int(r["in"][k])]
			if not Cooking.is_ingredient(k):
				v._err("рецепт «%s»: «%s» нельзя положить в котелок" % [id, k])
			elif not v.can_get(k):
				v._err("рецепт «%s»: продукт «%s» негде взять" % [id, k])
			sum += _price(k) * int(r["in"][k])
		if seen.has(sig):
			v._err("рецепты «%s» и «%s» — из одного и того же набора" % [id, seen[sig]])
		seen[sig] = id
		if sum <= 0:
			v._err("рецепт «%s»: продукты ничего не стоят" % id)
			continue
		if _price(id) > int(ceil(sum * DISH_MARKUP)):
			v._err("блюдо «%s» стоит %d при продуктах на %d — выгоднее, чем положено (не больше ×%.1f)" % [id, _price(id), sum, DISH_MARKUP])
		if _price(id) < sum:
			v._err("блюдо «%s» стоит %d — дешевле своих продуктов (%d)" % [id, _price(id), sum])
		ratio += float(_price(id)) / sum
	for c in Cooking.classic_recipes():
		var ck: Array = c["in"].keys()
		ck.sort()
		var csig := ""
		for k in ck:
			csig += "%s×%d " % [k, int(c["in"][k])]
		if seen.has(csig):
			v._err("рецепт котелка «%s» совпадает с обычным рецептом «%s»" % [seen[csig], c["id"]])
	if Data.SELL_PRICES.has(Cooking.FLOP):
		v._err("каша-неудача не должна продаваться")
	for o in OrderBoard.POOL:
		if not Cooking.recipe(o[1]).is_empty():
			var rw := int(ceil(_price(o[1]) * int(o[2]) * 1.8)) + 5
			if rw > ORDER_MAX:
				v._err("заказ на «%s» ×%d даёт %d монет — больше %d" % [o[1], int(o[2]), rw, ORDER_MAX])
	v.report.append("Кулинария: рецептов %d, блюдо дороже своих продуктов в среднем в %.2f раза (не больше ×%.1f)"
		% [Cooking.RECIPES.size(), ratio / maxi(1, Cooking.RECIPES.size()), DISH_MARKUP])

	# ---- украшения
	v._where = "Уют"
	var all_ids: Array = []
	for id in Data.BUILDINGS:
		var b: Dictionary = Data.BUILDINGS[id]
		if not b.get("decor", false):
			continue
		all_ids.append(id)
		if int(b.get("cozy", 0)) <= 0:
			v._err("украшение «%s» не даёт уюта" % id)
		if b.get("tab", "") != "декор":
			v._err("украшение «%s» не на вкладке «Декор»" % id)
		if not _can_build(v, id):
			v._err("украшение «%s» нельзя поставить: чего-то из материалов не достать" % id)
		if not ResourceLoader.exists("res://assets/models/%s.glb" % id):
			v._err("у украшения «%s» нет модели" % id)
		if not ResourceLoader.exists("res://assets/icons/%s.png" % id):
			v._err("у украшения «%s» нет иконки" % id)
	if all_ids.size() < 20 or all_ids.size() > 30:
		v._err("украшений %d, а нужно 20–30" % all_ids.size())
	var top: int = CozyLife.LEVELS[CozyLife.LEVELS.size() - 1]
	var once := CozyLife.score_of(all_ids)
	if once < top:
		v._err("высшая ступень уюта (%d) недостижима: все украшения по разу дают %d" % [top, once])
	var spam: Array = []
	for i in 30:
		spam.append("torch")
	if CozyLife.level_of(CozyLife.score_of(spam)) > 1:
		v._err("30 факелов дают ступень уюта выше первой — однообразие не должно быть выгодным")

	# ---- гости и подарки
	var worst := 0
	for gid in CozyLife.GUESTS:
		if not Data.SPEAKERS.has(gid):
			v._err("гость «%s» не описан в Data.SPEAKERS" % gid)
		if not ResourceLoader.exists("res://assets/models/%s.glb" % NPCPerson.MODELS.get(gid, gid)):
			v._err("у гостя «%s» нет модели" % gid)
		for set_ in CozyLife.GUESTS[gid]["lines"]:
			if (set_ as Array).size() != 2:
				v._err("у гостя «%s» реплик не две" % gid)
		for g in CozyLife.GUESTS[gid]["gifts"]:
			if not Data.ITEMS.has(g[0]):
				v._err("гость «%s» дарит несуществующее «%s»" % [gid, g[0]])
				continue
			if g[0] == "coins":
				v._err("гость «%s» дарит монеты — подарки только вещами" % gid)
			var val := maxi(_price(g[0]), v._min_price(g[0])) * int(g[1])
			worst = maxi(worst, val)
			if val > CozyLife.GIFT_MAX_VALUE:
				v._err("подарок гостя «%s» («%s» ×%d) стоит %d — больше %d" % [gid, g[0], int(g[1]), val, CozyLife.GIFT_MAX_VALUE])
	var top_chance: float = CozyLife.GIFT_BASE + CozyLife.GIFT_PER_LEVEL * (CozyLife.LEVELS.size() - 1)
	if top_chance > 0.8:
		v._err("шанс подарка на высшей ступени %.2f — больше 0.8" % top_chance)
	v.report.append("Уют: украшений %d, все по разу — %d очков (высшая ступень — %d); подарок гостя — не дороже %d монет, не чаще раза в день"
		% [all_ids.size(), once, top, worst])
