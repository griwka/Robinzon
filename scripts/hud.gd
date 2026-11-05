class_name HUD
extends CanvasLayer
## Интерфейс: часы, задание, панель предметов, подсказки, диалоги и окна
## (крафт, строительство, инвентарь, коллекции, журнал, помощь, выбор).
## Стиль — "деревянные" панели, бумага и зелёные кнопки, как в классических островных играх.

signal build_selected(id: String, variant: String)
signal panels_changed(any_open: bool)
signal new_game_requested

const WOOD := Color("7a4e2a")
const WOOD_DARK := Color("3f2614")
const WOOD_LIGHT := Color("a8784a")
const PAPER := Color("f8ebc8")
const INK := Color("4a2c14")
const GREEN := Color("6dbb3a")
const GREEN_DARK := Color("3f7d1f")
const CARD := Color("f6e3b8")        # светлая карточка предмета (пергамент)
const CARD_EDGE := Color("b88552")
const ROW := Color("c99a5e")         # строка в окне — тёплое светлое дерево
const ROW_EDGE := Color("8a5a30")
const HOTBAR_ORDER := ["machete", "stone_axe", "pickaxe", "watering_can", "net", "wood", "stone", "fiber", "leaf", "rope", "plank", "bamboo"]

var station_check: Callable

var root: Control
var clock_label: Label
var quest_box: VBoxContainer
var hotbar: HBoxContainer
var hint_label: Label
var toasts: VBoxContainer
var crosshair: Control
var windows: Array[PanelContainer] = []
var craft_panel: PanelContainer
var build_panel: PanelContainer
var inv_panel: PanelContainer
var col_panel: PanelContainer
var journal_panel: PanelContainer
var help_panel: PanelContainer
var choice_panel: PanelContainer
var dialogue_panel: PanelContainer
var dlg_name: Label
var dlg_text: Label
var dlg_portrait: PanelContainer
var dlg_letter: Label
var dlg_face: TextureRect
var fade_rect: ColorRect
var _dlg_queue: Array = []   # [[lines, on_done], ...]
var _dlg_lines: Array = []
var _dlg_done: Callable
var _build_tab := "дом"


func _ready() -> void:
	layer = 10
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = _make_theme()
	add_child(root)
	_build_status()
	_build_quest()
	_build_hotbar()
	_build_toasts()
	craft_panel = _make_window("Крафт", 640)
	build_panel = _make_window("Строительство", 660)
	inv_panel = _make_window("Инвентарь", 700)
	col_panel = _make_window("Коллекции", 640)
	journal_panel = _make_window("Журнал", 620)
	help_panel = _make_window("Как играть", 600)
	choice_panel = _make_window("Выбор", 460)
	_build_help()
	_build_dialogue()
	fade_rect = ColorRect.new()
	fade_rect.color = Color(0.02, 0.03, 0.08, 0)
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fade_rect)

	Game.inventory_changed.connect(_on_inventory_changed)
	Game.notified.connect(toast)
	Game.quest_changed.connect(_update_quest)
	Game.dialogue_requested.connect(show_dialogue)
	Game.collection_changed.connect(func(_c, _i, _n): if col_panel.visible: _fill_collections())
	Game.time_changed.connect(func(_t, _d): clock_label.text = Game.clock_text())
	_on_inventory_changed()
	_update_quest()


# ================================================================== Тема
func _box(bg: Color, border: Color, radius := 14, bw := 4, pad := 14) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(pad)
	s.shadow_color = Color(0, 0, 0, 0.25)
	s.shadow_size = 4
	s.shadow_offset = Vector2(0, 3)
	return s


func _make_theme() -> Theme:
	var t := Theme.new()
	var base: FontFile = load("res://assets/fonts/Nunito.ttf")
	if base:
		var fv := FontVariation.new()
		fv.base_font = base
		var ts := TextServerManager.get_primary_interface()
		fv.variation_opentype = {ts.name_to_tag("weight"): 780}
		t.default_font = fv
	t.default_font_size = 18
	t.set_color("font_color", "Label", Color.WHITE)
	t.set_color("font_outline_color", "Label", Color(0.15, 0.08, 0.03))
	t.set_constant("outline_size", "Label", 5)
	t.set_stylebox("panel", "PanelContainer", _box(WOOD, WOOD_DARK))
	t.set_stylebox("normal", "Button", _box(GREEN, GREEN_DARK, 10, 3, 8))
	t.set_stylebox("hover", "Button", _box(GREEN.lightened(0.15), GREEN_DARK, 10, 3, 8))
	t.set_stylebox("pressed", "Button", _box(GREEN.darkened(0.15), GREEN_DARK, 10, 3, 8))
	t.set_stylebox("disabled", "Button", _box(Color("a8977f"), Color("7a6a55"), 10, 3, 8))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(1, 1, 1, 0.65))
	t.set_color("font_outline_color", "Button", Color(0.1, 0.25, 0.05))
	t.set_constant("outline_size", "Button", 4)
	t.set_font_size("font_size", "Button", 18)
	return t


func _label(text: String, size := 18, color := Color.WHITE, outline := true) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if not outline:
		l.add_theme_constant_override("outline_size", 0)
	return l


func _make_window(title: String, width: int) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(width, 0)
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	p.add_theme_stylebox_override("panel", _box(PAPER, WOOD, 18, 8, 20))
	p.visible = false
	var v := VBoxContainer.new()
	v.name = "V"
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	var head := HBoxContainer.new()
	head.name = "Head"
	v.add_child(head)
	var l := _label(title, 30)
	l.name = "Title"
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(l)
	var close := Button.new()
	close.text = "✕"
	close.custom_minimum_size = Vector2(42, 42)
	close.add_theme_stylebox_override("normal", _box(Color("d9573b"), Color("8a2a17"), 10, 3, 6))
	close.add_theme_stylebox_override("hover", _box(Color("e8704f"), Color("8a2a17"), 10, 3, 6))
	close.pressed.connect(close_all)
	head.add_child(close)
	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.custom_minimum_size = Vector2(0, 80)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var body := VBoxContainer.new()
	body.name = "Body"
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	scroll.add_child(body)
	root.add_child(p)
	windows.append(p)
	return p


func _body(p: PanelContainer) -> VBoxContainer:
	return p.get_node("V/Scroll/Body")


func _clear(p: PanelContainer) -> VBoxContainer:
	var b := _body(p)
	for c in b.get_children():
		b.remove_child(c)
		c.queue_free()
	return b


func _fit(p: PanelContainer, max_h := 560.0) -> void:
	# высота прокрутки — по содержимому, но не больше max_h
	await get_tree().process_frame
	var b := _body(p)
	var sc: ScrollContainer = p.get_node("V/Scroll")
	sc.custom_minimum_size.y = minf(b.get_combined_minimum_size().y, max_h)


func _open(p: PanelContainer) -> void:
	Audio.play("open", -4.0, 0.05)
	for w in windows:
		w.visible = false
	p.visible = true
	_fit(p)
	panels_changed.emit(true)


func _row() -> Array:
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", _box(ROW, ROW_EDGE, 12, 3, 10))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	row.add_child(h)
	return [row, h]


## Иконка на светлой карточке (для строк в окнах).
func _card_icon(id: String, size := 60, dark := false) -> Control:
	var card := PanelContainer.new()
	var sb := _box(CARD, CARD_EDGE, 12, 3, 3)
	sb.shadow_size = 2
	card.add_theme_stylebox_override("panel", sb)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	card.add_child(_item_icon(id, size, dark))
	return card


## Нарисованная иконка предмета (или коллекции). Если картинки нет — цветной кружок.
func _item_icon(id: String, size := 40, dark := false) -> Control:
	var tex := FX.icon_texture(id)
	if tex == null:
		return _icon(Game.item(id).get("color", Color.WHITE), size)
	var r := TextureRect.new()
	r.texture = tex
	r.custom_minimum_size = Vector2(size, size)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if dark:
		r.modulate = Color(0.15, 0.1, 0.06, 0.55)  # силуэт ещё не найденного предмета
	return r


func _icon(color: Color, size := 36) -> PanelContainer:
	var icon := PanelContainer.new()
	icon.custom_minimum_size = Vector2(size, size)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sb := _box(color, color.darkened(0.5), size / 2, 3, 0)
	sb.shadow_size = 0
	icon.add_theme_stylebox_override("panel", sb)
	return icon


# ================================================================== Статус и задание
func _build_status() -> void:
	var p := PanelContainer.new()
	p.position = Vector2(16, 16)
	root.add_child(p)
	clock_label = _label(Game.clock_text(), 20)
	p.add_child(clock_label)


func _build_quest() -> void:
	var p := PanelContainer.new()
	p.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	p.position = Vector2(-16, 16)
	p.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	p.custom_minimum_size = Vector2(360, 0)
	root.add_child(p)
	quest_box = VBoxContainer.new()
	quest_box.add_theme_constant_override("separation", 2)
	p.add_child(quest_box)


func _update_quest() -> void:
	for c in quest_box.get_children():
		quest_box.remove_child(c)
		c.queue_free()
	var ch := Game.current_chapter()
	quest_box.add_child(_label(ch["title"], 14, Color("f3e2bd")))
	var q := Game.current_quest()
	if q.is_empty():
		quest_box.add_child(_label("Продолжение следует...", 20, Color("ffe08a")))
		return
	quest_box.add_child(_label(q["title"], 22, Color("ffe08a")))
	if not Game.quest_started:
		quest_box.add_child(_label("...", 16))
		return
	for task in q["tasks"]:
		var p := Game.task_progress(task)
		var done: bool = p >= task["count"]
		var l := _label(("✔ " if done else "• ") + task["text"] + ("" if task["count"] <= 1 else "  %d/%d" % [p, task["count"]]),
			16, Color("b6f29a") if done else Color.WHITE)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(330, 0)
		quest_box.add_child(l)


# ================================================================== Панель предметов
func _build_hotbar() -> void:
	var p := PanelContainer.new()
	p.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BEGIN
	p.position.y = -16
	root.add_child(p)
	hotbar = HBoxContainer.new()
	hotbar.add_theme_constant_override("separation", 6)
	p.add_child(hotbar)

	hint_label = _label("", 22)
	hint_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hint_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hint_label.position.y = -178
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(hint_label)

	crosshair = ColorRect.new()
	crosshair.color = Color(1, 1, 1, 0.85)
	crosshair.size = Vector2(6, 6)
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	crosshair.position -= Vector2(3, 3)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crosshair.visible = false
	root.add_child(crosshair)


func _on_inventory_changed() -> void:
	for c in hotbar.get_children():
		hotbar.remove_child(c)
		c.queue_free()
	var shown := 0
	for id in HOTBAR_ORDER:
		if Game.count(id) > 0:
			hotbar.add_child(_item_slot(id, Game.count(id)))
			shown += 1
	if shown == 0:
		hotbar.add_child(_label("  Инвентарь пуст — исследуй остров!  "))
	var tab := _label(" Tab — всё ", 14, Color("f3e2bd"))
	tab.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hotbar.add_child(tab)
	_update_quest()
	for p in [craft_panel, build_panel, inv_panel]:
		if p and p.visible:
			_refill(p)


## Ячейка предмета: светлая карточка, крупная иконка, количество — бейджем в углу.
## big = true — для окна инвентаря (с подписью под иконкой).
func _item_slot(id: String, n: int, big := false) -> Control:
	var size := 96 if big else 80
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.tooltip_text = Game.item_name(id)
	var slot := PanelContainer.new()
	slot.custom_minimum_size = Vector2(size, size)
	var sb := _box(CARD, CARD_EDGE, 12, 3, 3)
	sb.shadow_size = 3
	slot.add_theme_stylebox_override("panel", sb)
	slot.mouse_filter = Control.MOUSE_FILTER_PASS
	slot.tooltip_text = Game.item_name(id)
	box.add_child(slot)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(size - 6, size - 6)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(holder)
	var icon := _item_icon(id, size - 8)
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.add_child(icon)
	if n > 1 or Game.item(id).get("cat", "") != "tool":
		var badge := PanelContainer.new()
		var bs := _box(WOOD, WOOD_DARK, 9, 2, 0)
		bs.content_margin_left = 6
		bs.content_margin_right = 6
		bs.shadow_size = 0
		badge.add_theme_stylebox_override("panel", bs)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var cnt := _label(str(n), 15)
		badge.add_child(cnt)
		holder.add_child(badge)
		badge.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE)
	if big:
		var nm := _label(Game.item_short(id), 14, INK, false)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.custom_minimum_size = Vector2(size, 0)
		box.add_child(nm)
	return box


var stamina_bar: ProgressBar


## Полоска сил — видна, только когда силы не полные (как в PEAK).
func set_stamina(v: float, m: float) -> void:
	if stamina_bar == null:
		stamina_bar = ProgressBar.new()
		stamina_bar.show_percentage = false
		stamina_bar.custom_minimum_size = Vector2(260, 18)
		stamina_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		stamina_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
		stamina_bar.position.y = -212
		var bg := _box(WOOD_DARK, WOOD_DARK, 9, 2, 0)
		var fg := _box(Color("ffcf3d"), Color("c98d10"), 9, 2, 0)
		bg.shadow_size = 0
		fg.shadow_size = 0
		stamina_bar.add_theme_stylebox_override("background", bg)
		stamina_bar.add_theme_stylebox_override("fill", fg)
		root.add_child(stamina_bar)
	stamina_bar.max_value = m
	stamina_bar.value = v
	stamina_bar.visible = v < m - 0.5
	stamina_bar.modulate = Color(1, 0.5, 0.45) if v < m * 0.25 else Color.WHITE


func set_hint(text: String) -> void:
	hint_label.text = text


func set_crosshair(v: bool) -> void:
	crosshair.visible = v


# ================================================================== Сообщения
func _build_toasts() -> void:
	toasts = VBoxContainer.new()
	toasts.position = Vector2(20, 80)
	toasts.add_theme_constant_override("separation", 4)
	toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(toasts)


func toast(text: String, color := Color.WHITE) -> void:
	var l := _label(text, 20, color)
	toasts.add_child(l)
	if toasts.get_child_count() > 7:
		toasts.get_child(0).queue_free()
	var tw := l.create_tween()
	tw.tween_interval(3.0)
	tw.tween_property(l, "modulate:a", 0.0, 0.8)
	tw.tween_callback(l.queue_free)


# ================================================================== Диалоги
func _build_dialogue() -> void:
	dialogue_panel = PanelContainer.new()
	dialogue_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	dialogue_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	dialogue_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	dialogue_panel.position.y = -130
	dialogue_panel.custom_minimum_size = Vector2(820, 150)
	dialogue_panel.add_theme_stylebox_override("panel", _box(PAPER, WOOD, 18, 8, 18))
	dialogue_panel.visible = false
	root.add_child(dialogue_panel)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 18)
	dialogue_panel.add_child(h)
	dlg_portrait = _icon(Color.RED, 96)
	h.add_child(dlg_portrait)
	dlg_face = TextureRect.new()
	dlg_face.custom_minimum_size = Vector2(110, 110)
	dlg_face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	dlg_face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	h.add_child(dlg_face)
	h.move_child(dlg_face, 0)
	dlg_letter = _label("Р", 44)
	dlg_letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dlg_letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dlg_portrait.add_child(dlg_letter)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	dlg_name = _label("", 22, Color("e07a2e"))
	v.add_child(dlg_name)
	dlg_text = _label("", 20, INK, false)
	dlg_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dlg_text.custom_minimum_size = Vector2(560, 60)
	v.add_child(dlg_text)
	var next := Button.new()
	next.text = "Далее  ▶"
	next.size_flags_horizontal = Control.SIZE_SHRINK_END
	next.pressed.connect(advance_dialogue)
	v.add_child(next)


func show_dialogue(lines: Array, on_done: Callable) -> void:
	if lines.is_empty():
		if on_done.is_valid():
			on_done.call()
		return
	_dlg_queue.append([lines, on_done])
	if not dialogue_panel.visible:
		_next_block()


func _next_block() -> void:
	if _dlg_queue.is_empty():
		dialogue_panel.visible = false
		panels_changed.emit(any_open())
		return
	var block: Array = _dlg_queue.pop_front()
	_dlg_lines = block[0].duplicate()
	_dlg_done = block[1]
	for w in windows:
		w.visible = false
	dialogue_panel.visible = true
	panels_changed.emit(true)
	_show_line()


func _show_line() -> void:
	var line: Array = _dlg_lines[0]
	var sp: Dictionary = Data.SPEAKERS.get(line[0], Data.SPEAKERS["narrator"])
	var nm: String = sp["name"]
	dlg_name.text = nm
	var face := FX.icon_texture("portrait_" + str(line[0]))
	dlg_face.texture = face
	dlg_face.visible = face != null
	dlg_portrait.visible = nm != "" and face == null
	dlg_letter.text = nm.left(1) if line[0] != "parrot" else "Р"
	var c: Color = sp["color"]
	var sb := _box(c, c.darkened(0.5), 48, 4, 0)
	sb.shadow_size = 0
	dlg_portrait.add_theme_stylebox_override("panel", sb)
	dlg_text.text = line[1]
	Audio.play("blip", -6.0, 0.1)
	dlg_text.add_theme_color_override("font_color", INK if nm != "" else Color("6b4524"))


func advance_dialogue() -> void:
	if not dialogue_panel.visible:
		return
	_dlg_lines.pop_front()
	if _dlg_lines.is_empty():
		var cb := _dlg_done
		_dlg_done = Callable()
		dialogue_panel.visible = false
		if cb.is_valid():
			cb.call()
		if not dialogue_panel.visible:
			_next_block()
	else:
		_show_line()


func dialogue_open() -> bool:
	return dialogue_panel.visible


# ================================================================== Окна
func _refill(p: PanelContainer) -> void:
	if p == craft_panel: _fill_craft()
	elif p == build_panel: _fill_build()
	elif p == inv_panel: _fill_inventory()
	elif p == col_panel: _fill_collections()
	elif p == journal_panel: _fill_journal()


func open_craft(_station := "") -> void:
	_fill_craft()
	_open(craft_panel)


func _fill_craft() -> void:
	var body := _clear(craft_panel)
	var names := {"": "в руках", "workbench": "у верстака", "campfire": "у костра"}
	var note := _label("Рецепты «у верстака» и «у костра» работают, только если стоять рядом.", 15, INK, false)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(580, 0)
	body.add_child(note)
	for r in Data.RECIPES:
		if not Game.recipe_unlocked(r):
			continue
		var station: String = r["station"]
		var near: bool = station == "" or (station_check.is_valid() and station_check.call(station))
		var rh := _row()
		var h: HBoxContainer = rh[1]
		var out_id: String = r["out"].keys()[0]
		h.add_child(_card_icon(out_id, 60))
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(info)
		info.add_child(_label("%s ×%d   (%s)" % [Game.item_name(out_id), r["out"][out_id], names.get(station, station)], 20))
		info.add_child(_label(_cost_text(r["in"]), 15, Color("c9f59b") if Game.can_afford(r["in"]) else Color("ffb199")))
		var b := Button.new()
		b.text = "Создать" if near else "Далеко"
		b.custom_minimum_size = Vector2(120, 44)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.disabled = not near or not Game.can_afford(r["in"])
		b.pressed.connect(func(): Game.craft(r))
		h.add_child(b)
		body.add_child(rh[0])


func _cost_text(cost: Dictionary) -> String:
	var parts: Array[String] = []
	for id in cost:
		parts.append("%s %d/%d" % [Game.item_name(id), Game.count(id), cost[id]])
	return ", ".join(parts)


func open_build() -> void:
	_fill_build()
	_open(build_panel)


func _fill_build() -> void:
	var body := _clear(build_panel)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	body.add_child(tabs)
	for tab in ["дом", "ферма", "декор"]:
		var tb := Button.new()
		tb.text = tab.capitalize()
		tb.custom_minimum_size = Vector2(130, 40)
		if tab != _build_tab:
			tb.add_theme_stylebox_override("normal", _box(WOOD_LIGHT, WOOD_DARK, 10, 3, 8))
		tb.pressed.connect(func():
			_build_tab = tab
			_fill_build()
			_fit(build_panel))
		tabs.add_child(tb)
	for id in Data.BUILDINGS:
		var cfg: Dictionary = Data.BUILDINGS[id]
		if cfg.get("tab", "дом") != _build_tab:
			continue
		var unlocked := Game.is_unlocked(id, cfg)
		if not unlocked:
			body.add_child(_locked_row(cfg["name"]))
			continue
		if id == "fruit_tree":
			var any := false
			for sid in Data.ITEMS:
				if Data.ITEMS[sid].get("cat", "") == "sapling" and Game.count(sid) > 0:
					any = true
					var tree: String = Data.ITEMS[sid]["tree"]
					body.add_child(_build_row(Data.TREES[tree]["name"], cfg["desc"], {sid: 1}, id, tree))
			if not any:
				body.add_child(_build_row(cfg["name"], "Нужен саженец. Их дарит Румба, иногда роняют дикие деревья.", {"sapling_banana": 1}, id, "banana"))
			continue
		body.add_child(_build_row(cfg["name"], cfg["desc"], cfg["cost"], id, ""))


func _locked_row(title: String) -> Control:
	var rh := _row()
	var h: HBoxContainer = rh[1]
	rh[0].modulate = Color(1, 1, 1, 0.6)
	h.add_child(_icon(Color("6b5c4a"), 40))
	h.add_child(_label("%s — откроется по сюжету" % title, 18, Color("e8dcc0")))
	return rh[0]


func _build_row(title: String, desc: String, cost: Dictionary, id: String, variant: String) -> Control:
	var rh := _row()
	var h: HBoxContainer = rh[1]
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(info)
	info.add_child(_label(title, 20))
	var d := _label(desc, 14, Color("f3e2bd"))
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(430, 0)
	info.add_child(d)
	info.add_child(_label(_cost_text(cost) if not cost.is_empty() else "бесплатно", 15,
		Color("c9f59b") if Game.can_afford(cost) else Color("ffb199")))
	var b := Button.new()
	b.text = "Строить"
	b.custom_minimum_size = Vector2(120, 44)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.disabled = not Game.can_afford(cost)
	b.pressed.connect(func():
		close_all()
		build_selected.emit(id, variant))
	h.add_child(b)
	return rh[0]


func open_inventory() -> void:
	_fill_inventory()
	_open(inv_panel)


func _fill_inventory() -> void:
	var body := _clear(inv_panel)
	var cats := {"tool": "Инструменты", "material": "Материалы", "seed": "Семена", "sapling": "Саженцы",
		"crop": "Урожай", "fruit": "Фрукты", "product": "С фермы", "food": "Блюда"}
	var any := false
	for cat in cats:
		var grid := GridContainer.new()
		grid.columns = 6
		grid.add_theme_constant_override("h_separation", 6)
		grid.add_theme_constant_override("v_separation", 6)
		for id in Data.ITEMS:
			if Data.ITEMS[id]["cat"] == cat and Game.count(id) > 0:
				grid.add_child(_item_slot(id, Game.count(id), true))
		if grid.get_child_count() > 0:
			any = true
			body.add_child(_label(cats[cat], 18, INK, false))
			body.add_child(grid)
		else:
			grid.queue_free()
	if not any:
		body.add_child(_label("Пока пусто. Собирай всё, что видишь!", 18, INK, false))


func open_collections() -> void:
	_fill_collections()
	_open(col_panel)


func _fill_collections() -> void:
	var body := _clear(col_panel)
	for cid in Data.COLLECTIONS:
		var col: Dictionary = Data.COLLECTIONS[cid]
		var have: Dictionary = Game.collections.get(cid, {})
		var rh := _row()
		var h: HBoxContainer = rh[1]
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(info)
		var done := Game.collection_complete(cid)
		info.add_child(_label(col["name"] + ("  — собрана!" if done else ""), 20, Color("b6f29a") if done else Color.WHITE))
		info.add_child(_label(col["source"], 14, Color("f3e2bd")))
		var slots := HBoxContainer.new()
		slots.add_theme_constant_override("separation", 8)
		info.add_child(slots)
		for it in col["items"]:
			var v := VBoxContainer.new()
			v.custom_minimum_size = Vector2(86 if col.get("ordered", false) else 100, 0)
			var found: bool = have.has(it["id"])
			v.add_child(_card_icon(it["id"], 64, not found))
			var nm := _label(it["name"] if found else "???", 13)
			nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			v.add_child(nm)
			if found and it.has("text"):
				var rd := Button.new()
				rd.text = "Читать"
				rd.add_theme_font_size_override("font_size", 14)
				var txt: String = it["text"]
				rd.pressed.connect(func(): show_dialogue([["journal", txt]], Callable()))
				v.add_child(rd)
			elif found:
				var c := _label("×%d" % have[it["id"]], 13, Color("f3e2bd"))
				c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				v.add_child(c)
			slots.add_child(v)
		body.add_child(rh[0])


func open_journal() -> void:
	_fill_journal()
	_open(journal_panel)


func _fill_journal() -> void:
	var body := _clear(journal_panel)
	var ch := Game.current_chapter()
	body.add_child(_label(ch["title"], 22, INK, false))
	var qs: Array = ch["quests"]
	for i in qs.size():
		var q: Dictionary = qs[i]
		var state := "✔ " if i < Game.quest_index else ("▶ " if i == Game.quest_index else "   ")
		var color := Color("3f7d1f") if i < Game.quest_index else (Color("b4561e") if i == Game.quest_index else Color("9a8a70"))
		var title: String = q["title"] if i <= Game.quest_index else "???"
		body.add_child(_label(state + title, 18, color, false))
	var more := _label("Дальше: остров Великого Баньяна, Старый форт, Грозовой остров...", 15, Color("6b4524"), false)
	more.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	more.custom_minimum_size = Vector2(560, 0)
	body.add_child(more)


func show_choices(title: String, options: Array) -> void:
	var body := _clear(choice_panel)
	(choice_panel.get_node("V/Head/Title") as Label).text = title
	for o in options:
		var rh := _row()
		var h: HBoxContainer = rh[1]
		h.add_child(_card_icon(o["icon"], 48) if o.has("icon") else _icon(o.get("color", Color.WHITE), 36))
		var b := Button.new()
		b.text = o["text"]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cb: Callable = o["callback"]
		b.pressed.connect(func():
			close_all()
			cb.call())
		h.add_child(b)
		body.add_child(rh[0])
	_open(choice_panel)


func _build_help() -> void:
	var body := _body(help_panel)
	body.add_child(_label("""WASD — ходить,  Shift — бег,  Пробел — прыжок
Мышь — камера,  колёсико — приблизить/отдалить
ЛКМ или E — собирать / рубить / использовать
C — крафт,  B — строительство,  Tab — инвентарь
J — журнал заданий,  K — коллекции
В строительстве: ЛКМ — поставить, R — повернуть, ПКМ — отмена
F5 — сохранить,  F9 — загрузить,  Esc — пауза и настройки

Грядки: посади семена, полей лейкой — растут вдвое быстрее.
Животные: покорми — через время будут яйца или молоко.
Их можно гладить!""", 17, INK, false))


func show_help() -> void:
	_open(help_panel)


func any_open() -> bool:
	if dialogue_panel.visible:
		return true
	for w in windows:
		if w.visible:
			return true
	return false


func close_all() -> void:
	for w in windows:
		w.visible = false
	panels_changed.emit(any_open())


func fade_through(mid: Callable) -> void:
	var tw := create_tween()
	tw.tween_property(fade_rect, "color:a", 1.0, 0.6)
	tw.tween_callback(mid)
	tw.tween_interval(0.5)
	tw.tween_property(fade_rect, "color:a", 0.0, 0.8)
