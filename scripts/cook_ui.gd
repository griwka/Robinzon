class_name CookUI
extends RefCounted
## Окна кулинарии: «Котелок» (положить 2–4 продукта и сварить, знакомые блюда — одной кнопкой)
## и раздел «Кулинарная книга» в окне коллекций. Рисуется помощниками HUD — выглядит как остальные окна.

var hud: HUD
var panel: PanelContainer
var pot: Array[String] = []    # что уже лежит в котелке (по одной штуке на место)
var last := ""                 # что получилось в прошлый раз (строка под котелком)
var _queued := false


func _init(h: HUD) -> void:
	hud = h
	panel = hud._make_window("Котелок", 700)
	Game.inventory_changed.connect(_on_changed)


func open() -> void:
	pot.clear()
	last = ""
	fill()
	hud._open(panel)


func _on_changed() -> void:
	if panel.visible and not _queued:
		_queued = true
		_refill.call_deferred()


func _refill() -> void:
	_queued = false
	if panel.visible:
		fill()
		hud._fit(panel)


func _placed(id: String) -> int:
	return pot.count(id)


func pot_dict() -> Dictionary:
	var d := {}
	for id in pot:
		d[id] = int(d.get(id, 0)) + 1
	return d


func put(id: String) -> void:
	if pot.size() >= Cooking.MAX_UNITS:
		Game.notified.emit("В котелок помещается только %d продукта" % Cooking.MAX_UNITS, Color("ff9d7a"))
		return
	if Cooking.free_count(id) - _placed(id) <= 0:
		if Game.reserved(id) > 0:
			Game.notified.emit("Это нужно для задания — не трогаю", Color("ff9d7a"))
		return
	pot.append(id)
	Audio.play("click", -6.0, 0.05)
	_refill()


func take(i: int) -> void:
	if i >= 0 and i < pot.size():
		pot.remove_at(i)
		Audio.play("click", -6.0, 0.05)
		_refill()


func boil() -> void:
	var got := Cooking.cook(pot_dict())
	if got == "":
		return
	last = got
	pot.clear()
	_refill()


func fill() -> void:
	var body := hud._clear(panel)
	var note := hud._label("Положи в котелок от 2 до 4 продуктов и вари. Получится блюдо — рецепт запишется в кулинарную книгу (K). Не получится — выйдет каша-неудача: её тоже можно съесть.", 15, HUD.INK, false)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(640, 0)
	body.add_child(note)

	# сам котелок: четыре места и кнопка
	var rh := hud._row()
	var h: HBoxContainer = rh[1]
	for i in Cooking.MAX_UNITS:
		if i < pot.size():
			var cell := hud._item_slot(pot[i], 1, false, 76)
			cell.tooltip_text = "%s — нажми, чтобы вынуть" % Game.item_name(pot[i])
			var slot := cell.get_child(0) as PanelContainer
			slot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			var idx: int = i
			slot.gui_input.connect(func(ev: InputEvent):
				if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
					take(idx))
			h.add_child(cell)
		else:
			var empty := PanelContainer.new()
			empty.custom_minimum_size = Vector2(76, 76)
			var sb := hud._box(Color(0.3, 0.19, 0.1, 0.35), HUD.ROW_EDGE, 12, 3, 3)
			sb.shadow_size = 0
			empty.add_theme_stylebox_override("panel", sb)
			empty.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			h.add_child(empty)
	var side := VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(side)
	var guess := "Положи хотя бы два продукта"
	if pot.size() >= Cooking.MIN_UNITS:
		var res := Cooking.match_dish(pot_dict())
		var res_id: String = res.get("id", "")
		if res_id != "" and (Cooking.known(res_id) or Cooking.recipe(res_id).is_empty()):
			guess = "Получится: %s" % Game.item_name(res_id)
		else:
			guess = "Что выйдет — узнаем, когда сварим"
	elif last != "":
		guess = "Получилось: %s" % Game.item_name(last)
	var gl := hud._label(guess, 17)
	gl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	gl.custom_minimum_size = Vector2(230, 0)
	side.add_child(gl)
	var b := Button.new()
	b.text = "Варить"
	b.custom_minimum_size = Vector2(150, 46)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.disabled = pot.size() < Cooking.MIN_UNITS
	b.pressed.connect(boil)
	side.add_child(b)
	body.add_child(rh[0])

	# продукты в сумке
	body.add_child(hud._label("Продукты в сумке — нажми, чтобы положить:", 18, HUD.WOOD, false))
	var grid := GridContainer.new()
	grid.columns = 8
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	for id in Data.ITEMS:
		if not Cooking.is_ingredient(id):
			continue
		var n: int = Cooking.free_count(id) - _placed(id)
		if n <= 0:
			continue
		var cell := hud._item_slot(id, n, false, 74)
		var slot := cell.get_child(0) as PanelContainer
		slot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var iid: String = id
		slot.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				put(iid))
		grid.add_child(cell)
	if grid.get_child_count() == 0:
		grid.queue_free()
		body.add_child(hud._label("Продуктов нет. Собери урожай, фрукты, налови рыбы — и возвращайся.", 15, HUD.INK, false))
	else:
		body.add_child(grid)

	# знакомые блюда — одной кнопкой
	var rows: Array = []
	for r in Cooking.RECIPES:
		if Cooking.known(r["id"]):
			rows.append([r["id"], r["in"], 1])
	for c in Cooking.classic_recipes():
		if Game.recipe_unlocked(c):
			var oid: String = c["out"].keys()[0]
			rows.append([oid, c["in"], int(c["out"][oid])])
	if rows.is_empty():
		return
	body.add_child(hud._label("Знакомые блюда:", 18, HUD.WOOD, false))
	for row in rows:
		var did: String = row[0]
		var cost: Dictionary = row[1]
		var rr := hud._row()
		var hh: HBoxContainer = rr[1]
		hh.add_child(hud._card_icon(did, 56))
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hh.add_child(info)
		info.add_child(hud._label("%s ×%d   (+%d сытости)" % [Game.item_name(did), int(row[2]), int(Data.ITEMS[did].get("food", 0))], 19))
		var bt := Cooking.buff_text(did)
		if bt != "":
			info.add_child(hud._label(bt, 14, Color("d8f5b0")))
		info.add_child(hud._cost_row(cost))
		var cb := Button.new()
		cb.text = "Сварить"
		cb.custom_minimum_size = Vector2(120, 44)
		cb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var ok := true
		for id in cost:
			if Cooking.free_count(id) < int(cost[id]):
				ok = false
		cb.disabled = not ok
		cb.pressed.connect(func():
			var got := Cooking.cook_known(did)
			if got != "":
				last = got
				pot.clear()
				_refill())
		hh.add_child(cb)
		body.add_child(rr[0])


# ------------------------------------------------------------------ Кулинарная книга (окно коллекций)
## Раздел в окне коллекций: найденные рецепты — с составом, ненайденные — «???» и подсказка.
static func fill_book(h: HUD, body: VBoxContainer) -> void:
	if not Game.ended() and Cooking.known_count() == 0:
		return   # до финала котелка нет — раздел не показываем
	var rh := h._row()
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	(rh[1] as HBoxContainer).add_child(info)
	var n := Cooking.known_count()
	var total: int = Cooking.RECIPES.size()
	var done := n >= total
	info.add_child(h._label("Кулинарная книга — %d из %d%s" % [n, total, "  — все рецепты найдены!" if done else ""], 20,
		Color("b6f29a") if done else Color.WHITE))
	info.add_child(h._label("Готовь в котелке из 2–4 продуктов: что получится — запишется сюда", 14, Color("f3e2bd")))
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 10)
	info.add_child(grid)
	for r in Cooking.RECIPES:
		var id: String = r["id"]
		var found := Cooking.known(id)
		var v := VBoxContainer.new()
		v.custom_minimum_size = Vector2(108, 0)
		v.add_child(h._card_icon(id, 60, not found))
		var nm := h._label(Game.item_name(id) if found else "???", 13)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nm.custom_minimum_size = Vector2(108, 0)
		v.add_child(nm)
		var text: String = recipe_text(r["in"]) if found else str(r["hint"])
		var sub := h._label(text, 12, Color("f3e2bd"))
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sub.custom_minimum_size = Vector2(108, 0)
		v.add_child(sub)
		if found:
			var bt := Cooking.buff_text(id)
			v.tooltip_text = "%s\n%s\n+%d сытости%s" % [Game.item_name(id), text, int(Data.ITEMS[id].get("food", 0)), "" if bt == "" else "\n" + bt]
		else:
			v.tooltip_text = "Подсказка: %s" % text
		grid.add_child(v)
	body.add_child(rh[0])


## Состав словами: «рыба ×2, кокос, лимон».
static func recipe_text(ing: Dictionary) -> String:
	var parts: Array[String] = []
	for id in ing:
		var nm := Game.item_short(id).to_lower()
		parts.append(nm if int(ing[id]) == 1 else "%s ×%d" % [nm, int(ing[id])])
	return ", ".join(parts)
