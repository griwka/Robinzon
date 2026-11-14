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
const HOTBAR_MATERIALS := ["wood", "stone", "fiber", "leaf", "rope", "plank", "bamboo"]

var station_check: Callable

var root: Control
var clock_label: Label
var storm_label: Label
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
var shop_panel: PanelContainer
var coin_label: Label
var _shop_id := ""
var _shop_tab := "buy"
var dialogue_panel: PanelContainer
var dlg_name: Label
var dlg_text: Label
var _type_tw: Tween   # текст реплики «печатается» по буквам
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
	col_panel = _make_window("Коллекции и разговоры", 640)
	journal_panel = _make_window("Журнал", 620)
	help_panel = _make_window("Как играть", 600)
	choice_panel = _make_window("Выбор", 460)
	shop_panel = _make_window("Лавка", 640)
	_build_help()
	_build_wheel()
	_build_dialogue()
	fade_rect = ColorRect.new()
	fade_rect.color = Color(0.02, 0.03, 0.08, 0)
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fade_rect)

	Game.inventory_changed.connect(_on_inventory_changed)
	Game.held_changed.connect(_on_inventory_changed)
	Game.wear_changed.connect(_on_inventory_changed)
	Game.notified.connect(toast)
	Game.quest_changed.connect(_update_quest)
	Game.dialogue_requested.connect(show_dialogue)
	Game.shop_requested.connect(open_shop)
	Game.choice_requested.connect(show_choices)
	Game.wheel_requested.connect(show_wheel)
	Game.collection_changed.connect(func(_c, _i, _n): if col_panel.visible: _fill_collections())
	Game.time_changed.connect(func(_t, _d):
		clock_label.text = Game.clock_text()
		update_hunger()
		_update_storm())
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
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	p.add_child(h)
	clock_label = _label(Game.clock_text(), 20)
	h.add_child(clock_label)
	storm_label = _label("", 20, Color("bfe3ff"))
	storm_label.visible = false
	h.add_child(storm_label)
	var k := HBoxContainer.new()
	k.add_theme_constant_override("separation", 4)
	h.add_child(k)
	k.add_child(_item_icon("coins", 28))
	coin_label = _label("0", 20, Color("f3e2b8"))
	k.add_child(coin_label)
	# сытость: пять ступеней, каждая — свой отрезок шкалы
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 3)
	hb.mouse_filter = Control.MOUSE_FILTER_PASS
	h.add_child(hb)
	var hi := _item_icon("fruit_salad", 30)
	hb.add_child(hi)
	for i in 5:
		var seg := ProgressBar.new()
		seg.show_percentage = false
		seg.max_value = 20.0
		seg.custom_minimum_size = Vector2(26, 16)
		seg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		seg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var bg := _box(WOOD_DARK, WOOD_DARK, 5, 2, 0)
		bg.shadow_size = 0
		var fg := _box(Color("8fd45a"), Color("4f8f2a"), 5, 2, 0)
		fg.shadow_size = 0
		seg.add_theme_stylebox_override("background", bg)
		seg.add_theme_stylebox_override("fill", fg)
		hb.add_child(seg)
		_hunger_segs.append(seg)
		_hunger_fills.append(fg)
	hunger_label = _label("", 17, Color("fff6dc"))
	hb.add_child(hunger_label)
	_hunger_box = hb
	update_hunger()


var hunger_label: Label
var _hunger_box: Control
var _hunger_segs: Array = []
var _hunger_fills: Array = []
var _hunger_shown := -1.0
const HUNGER_COLORS := [Color("8fd45a"), Color("c6dc5a"), Color("f2c24a"), Color("f2913a"), Color("e8543a")]


## Шкала сытости: пять отрезков (по 20), цвет — по ступени; подпись — когда уже хочется есть.
func update_hunger() -> void:
	if _hunger_segs.is_empty() or absf(Game.hunger - _hunger_shown) < 0.05:
		return
	_hunger_shown = Game.hunger
	var st := Game.hunger_stage()
	var col: Color = HUNGER_COLORS[st]
	for i in 5:
		(_hunger_segs[i] as ProgressBar).value = clampf(Game.hunger - i * 20.0, 0.0, 20.0)
		(_hunger_fills[i] as StyleBoxFlat).bg_color = col
		(_hunger_fills[i] as StyleBoxFlat).border_color = col.darkened(0.35)
	hunger_label.text = Game.HUNGER_STAGES[st] if st >= 2 else ""
	hunger_label.add_theme_color_override("font_color", col.lightened(0.25))
	_hunger_box.tooltip_text = "Сытость: %s (%d%%) — %s. Поесть — Q или клик по еде в сумке (Tab)" % [
		Game.HUNGER_STAGES[st].to_lower(), int(Game.hunger), Game.HUNGER_NOTE[st]]


## Значок тучи: гроза близко / идёт (только на Грозовом острове).
func _update_storm() -> void:
	if storm_label == null:
		return
	var v := Game.storm
	storm_label.visible = v > 0.0 or Game.storm_force
	if Game.storm_active():
		storm_label.text = "Гроза! Молнии бьют"
		storm_label.modulate = Color(1, 1, 1, 0.75 + 0.25 * sin(Time.get_ticks_msec() / 150.0))
	else:
		storm_label.text = "Гроза близко — под навес!"
		storm_label.modulate = Color.WHITE


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


var pointer_label: Label   # куда идти по заданию (QuestPointer)


## Строка-указатель под заданием: «➜ Старый лагерь Лёвы — 34 м, на западе» ("" — спрятать).
func set_pointer(text: String) -> void:
	if pointer_label == null:
		pointer_label = _label("", 16, Color("bfe8ff"))
		pointer_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		pointer_label.custom_minimum_size = Vector2(330, 0)
		quest_box.add_child(pointer_label)
	pointer_label.text = text
	pointer_label.visible = text != ""


func _update_quest() -> void:
	for c in quest_box.get_children():
		quest_box.remove_child(c)
		if c != pointer_label:
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
	if pointer_label:
		quest_box.add_child(pointer_label)


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
	# инструменты: четыре ячейки с номерами 1–4, взятый в руку — подсвечен; остальные инструменты — в сумке
	var slots := Game.hold_slots()
	for i in slots.size():
		var cell := _item_slot(slots[i], 1, false, 72)
		var key := _label(str(i + 1), 15, Color("fff6dc"))
		key.position = Vector2(6, 2)
		cell.get_child(0).get_child(0).add_child(key)
		if slots[i] == Game.held_tool():
			var sb := _box(Color("fff2b0"), Color("f2a93a"), 12, 5, 0)
			sb.shadow_size = 3
			(cell.get_child(0) as PanelContainer).add_theme_stylebox_override("panel", sb)
		hotbar.add_child(cell)
		shown += 1
	if not slots.is_empty():
		var sep := VSeparator.new()
		sep.custom_minimum_size = Vector2(8, 0)
		hotbar.add_child(sep)
	for id in HOTBAR_MATERIALS:
		if Game.count(id) > 0:
			var mc := _item_slot(id, Game.count(id), false, 56)
			mc.size_flags_vertical = Control.SIZE_SHRINK_END
			hotbar.add_child(mc)
			shown += 1
	if shown == 0:
		hotbar.add_child(_label("  Инвентарь пуст — исследуй остров!  "))
	var tab := _label(" Tab — всё ", 14, Color("f3e2bd"))
	tab.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hotbar.add_child(tab)
	_update_quest()
	if coin_label:
		coin_label.text = str(Game.count("coins"))
	for p in [craft_panel, build_panel, inv_panel, shop_panel]:
		if p and p.visible:
			_refill(p)


## Подсказка предмета: название, а у вещей с пользой — ещё и что они дают.
func item_tip(id: String) -> String:
	var tip: String = Game.item(id).get("tip", "")
	return Game.item_name(id) if tip == "" else "%s\n%s" % [Game.item_name(id), tip]


## Ячейка предмета: светлая карточка, крупная иконка, количество — бейджем в углу.
## big = true — для окна инвентаря (с подписью под иконкой).
func _item_slot(id: String, n: int, big := false, px := 0) -> Control:
	var size := 96 if big else 80
	if px > 0:
		size = px
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.tooltip_text = item_tip(id)
	var slot := PanelContainer.new()
	slot.custom_minimum_size = Vector2(size, size)
	var sb := _box(CARD, CARD_EDGE, 12, 3, 3)
	sb.shadow_size = 3
	slot.add_theme_stylebox_override("panel", sb)
	slot.mouse_filter = Control.MOUSE_FILTER_PASS
	slot.tooltip_text = item_tip(id)
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
	if Game.WEAR.has(id) and Game.count(id) > 0:
		var hp := Game.tool_hp(id)
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.max_value = 1.0
		bar.value = hp
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var bb := _box(Color(0.22, 0.13, 0.06, 0.9), Color(0.98, 0.93, 0.8, 0.95), 4, 2, 0)
		bb.shadow_size = 0
		var bf := _box(Color("e8543a").lerp(Color("f2c24a"), smoothstep(0.1, 0.4, hp)).lerp(Color("7fd04a"), smoothstep(0.45, 0.8, hp)), Color(0, 0, 0, 0), 3, 0, 0)
		bf.shadow_size = 0
		bar.add_theme_stylebox_override("background", bb)
		bar.add_theme_stylebox_override("fill", bf)
		holder.add_child(bar)
		bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		bar.offset_left = 7
		bar.offset_right = -7
		bar.offset_top = -14
		bar.offset_bottom = -4
		box.tooltip_text = "%s — прочность %d%%" % [Game.item_name(id), int(hp * 100.0)] + ("\n" + Game.item(id)["tip"] if Game.item(id).has("tip") else "")
	if big:
		var nm := _label(Game.item_short(id), 14, INK, false)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.custom_minimum_size = Vector2(size, 0)
		box.add_child(nm)
	return box


var stamina_bar: ProgressBar
var heat_box: PanelContainer
var heat_bar: ProgressBar
var heat_state: Label
var _heat_fill: StyleBoxFlat


## Шкала жара (Остров Вулкана): под часами слева вверху, как шкала тепла на Ледяном.
func set_heat(v: float, shown: bool, state: String) -> void:
	if heat_box == null:
		heat_box = PanelContainer.new()
		heat_box.position = Vector2(16, 70)
		root.add_child(heat_box)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		heat_box.add_child(h)
		h.add_child(_label("Жар", 18, Color("ffc0a0")))
		heat_bar = ProgressBar.new()
		heat_bar.show_percentage = false
		heat_bar.max_value = 100.0
		heat_bar.custom_minimum_size = Vector2(220, 20)
		heat_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var bg := _box(WOOD_DARK, WOOD_DARK, 9, 2, 0)
		_heat_fill = _box(Color("ffb23a"), Color("c8641a"), 9, 2, 0)
		bg.shadow_size = 0
		_heat_fill.shadow_size = 0
		heat_bar.add_theme_stylebox_override("background", bg)
		heat_bar.add_theme_stylebox_override("fill", _heat_fill)
		h.add_child(heat_bar)
		heat_state = _label("", 16, Color("ffd0a0"))
		h.add_child(heat_state)
	heat_box.visible = shown
	if not shown:
		return
	heat_bar.value = v
	var k := clampf(v / 100.0, 0.0, 1.0)
	_heat_fill.bg_color = Color("ffd25a").lerp(Color("e8402a"), smoothstep(0.3, 0.95, k))
	_heat_fill.border_color = _heat_fill.bg_color.darkened(0.3)
	heat_state.text = state
	heat_state.modulate = Color(1, 1, 1, 0.7 + 0.3 * sin(Time.get_ticks_msec() / 120.0)) if v >= 99.0 else Color.WHITE
var warm_box: PanelContainer
var warm_bar: ProgressBar
var warm_state: Label
var _warm_fill: StyleBoxFlat


## Шкала тепла (Ледяной остров до оттепели): под часами слева вверху. state — «у огня», «чай греет», «замёрз!».
func set_warmth(v: float, shown: bool, state: String) -> void:
	if warm_box == null:
		warm_box = PanelContainer.new()
		warm_box.position = Vector2(16, 70)
		root.add_child(warm_box)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		warm_box.add_child(h)
		h.add_child(_label("Тепло", 18, Color("ffe0b8")))
		warm_bar = ProgressBar.new()
		warm_bar.show_percentage = false
		warm_bar.max_value = 100.0
		warm_bar.custom_minimum_size = Vector2(220, 20)
		warm_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var bg := _box(WOOD_DARK, WOOD_DARK, 9, 2, 0)
		_warm_fill = _box(Color("ff9a3a"), Color("c8641a"), 9, 2, 0)
		bg.shadow_size = 0
		_warm_fill.shadow_size = 0
		warm_bar.add_theme_stylebox_override("background", bg)
		warm_bar.add_theme_stylebox_override("fill", _warm_fill)
		h.add_child(warm_bar)
		warm_state = _label("", 16, Color("bfe3ff"))
		h.add_child(warm_state)
	warm_box.visible = shown
	if not shown:
		return
	warm_bar.value = v
	# от тёплого оранжевого к морозно-голубому
	var k := clampf(v / 100.0, 0.0, 1.0)
	_warm_fill.bg_color = Color("8fd0f5").lerp(Color("ff9a3a"), smoothstep(0.15, 0.7, k))
	_warm_fill.border_color = _warm_fill.bg_color.darkened(0.3)
	warm_state.text = state
	warm_state.modulate = Color(1, 1, 1, 0.7 + 0.3 * sin(Time.get_ticks_msec() / 160.0)) if v <= 0.0 else Color.WHITE


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


var target_dot: Control


## Точка на предмете, с которым будет действие (screen — его место на экране; visible = false — спрятать).
func set_target_dot(screen: Vector2, visible_: bool) -> void:
	if target_dot == null:
		target_dot = Control.new()
		target_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ring := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(1.0, 0.95, 0.75, 0.95)
		sb.border_color = Color(0.35, 0.2, 0.08, 0.9)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(9)
		ring.add_theme_stylebox_override("panel", sb)
		ring.custom_minimum_size = Vector2(18, 18)
		ring.size = Vector2(18, 18)
		ring.position = Vector2(-9, -9)
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		target_dot.add_child(ring)
		root.add_child(target_dot)
	target_dot.visible = visible_
	if visible_:
		target_dot.position = screen


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
	# появляется мягко: проявляется и чуть «выпрыгивает»
	l.modulate.a = 0.0
	l.scale = Vector2(0.9, 0.9)
	l.pivot_offset = Vector2(0, 14)
	var tw := l.create_tween()
	tw.tween_property(l, "modulate:a", 1.0, 0.16)
	tw.parallel().tween_property(l, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
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
	# окно диалога появляется мягко
	dialogue_panel.modulate.a = 0.0
	dialogue_panel.pivot_offset = dialogue_panel.size * Vector2(0.5, 1.0)
	dialogue_panel.scale = Vector2(0.96, 0.96)
	var tw := dialogue_panel.create_tween()
	tw.tween_property(dialogue_panel, "modulate:a", 1.0, 0.15)
	tw.parallel().tween_property(dialogue_panel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	panels_changed.emit(true)
	_show_line()


func _show_line() -> void:
	var line: Array = _dlg_lines[0]
	var sp: Dictionary = Data.SPEAKERS.get(line[0], Data.SPEAKERS["narrator"])
	var nm: String = sp["name"]
	# житель на другом острове: его слова приходят по рации, а пока рации нет — их приносит Румба
	var far := speaker_far(str(line[0]))
	if far and not str(line[1]).begins_with("(в рации") and not str(line[1]).begins_with("(по рации"):
		var short := nm.split(",")[0]
		if Game.has_tool("radio_set"):
			nm = short + " — по рации"
			Audio.play("radio", -10.0, 0.05)
		else:
			nm = short + " — весточку принесла Румба"
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
	# текст «печатается» (клик — сразу весь)
	if _type_tw and _type_tw.is_valid():
		_type_tw.kill()
	dlg_text.visible_ratio = 0.0
	_type_tw = dlg_text.create_tween()
	_type_tw.tween_property(dlg_text, "visible_ratio", 1.0, clampf(str(line[1]).length() * 0.016, 0.25, 1.6))
	Audio.play("blip", -6.0, 0.1)
	dlg_text.add_theme_color_override("font_color", INK if nm != "" else Color("6b4524"))


## Говорит ли житель издалека: он человек (или зверь) из команды, а на этом острове его сейчас нет.
func speaker_far(who: String) -> bool:
	if not (who in REMOTE_SPEAKERS) or not is_inside_tree():
		return false
	for n in get_tree().get_nodes_in_group("interactable"):
		if n is NPCPerson and (n as NPCPerson).npc_id == who:
			return false
	return true


const REMOTE_SPEAKERS := ["marta", "stepa", "timur", "ingrid", "vera", "misha", "renata", "gosha", "petya", "pasha", "lyova"]


func advance_dialogue() -> void:
	if not dialogue_panel.visible:
		return
	if dlg_text.visible_ratio < 1.0 and DisplayServer.get_name() != "headless":
		if _type_tw and _type_tw.is_valid():
			_type_tw.kill()
		dlg_text.visible_ratio = 1.0   # первый клик — дописать реплику, второй — дальше
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
	elif p == shop_panel: _fill_shop()


var _craft_station := ""   # окно открыто у станции (печь, костёр…) — её рецепты наверху


func open_craft(station := "") -> void:
	_craft_station = station
	_fill_craft()
	_open(craft_panel)


func _fill_craft() -> void:
	var body := _clear(craft_panel)
	var names := {"": "в руках", "workbench": "у верстака", "campfire": "у костра", "kiln": "у печи для обжига", "stove": "на печке",
		"forge": "в кузнице"}
	var note := _label("Рецепты «у верстака» и «у костра» работают, только если стоять рядом. Грядки, загоны и дома — не здесь, а в строительстве (клавиша B).", 15, INK, false)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(580, 0)
	body.add_child(note)
	# у станции — сначала её рецепты (что можно сделать прямо здесь), потом всё остальное
	var order: Array = []
	if _craft_station != "":
		for r in Data.RECIPES:
			if r["station"] == _craft_station and Game.recipe_unlocked(r):
				order.append(r)
		var head := _label("Здесь, %s:" % names.get(_craft_station, _craft_station), 19, WOOD, false)
		body.add_child(head)
		if order.is_empty():
			body.add_child(_label("Пока нечего — рецепты для этого места откроются по сюжету", 15, INK, false))
	var rest_start := order.size()
	for r in Data.RECIPES:
		if not order.has(r):
			order.append(r)
	for oi in order.size():
		var r: Dictionary = order[oi]
		if oi == rest_start and _craft_station != "":
			body.add_child(_label("Остальные рецепты:", 19, WOOD, false))
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
		info.add_child(_cost_row(r["in"]))
		var b := Button.new()
		var have_it: bool = Game.owned_unique(out_id) and not r["in"].has(out_id)
		b.text = "Есть ✓" if have_it else ("Создать" if near else "Далеко")
		b.custom_minimum_size = Vector2(120, 44)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.disabled = have_it or not near or not Game.can_afford(r["in"])
		b.pressed.connect(func(): Game.craft(r))
		h.add_child(b)
		body.add_child(rh[0])


func _cost_text(cost: Dictionary) -> String:
	var parts: Array[String] = []
	for id in cost:
		parts.append("%s %d/%d" % [Game.item_name(id), Game.count(id), cost[id]])
	return ", ".join(parts)


const HAVE := Color("b6f07a")    # материала хватает
const LACK := Color("ffa38a")    # не хватает


## Цена построчно: каждый материал своим цветом — зелёный, если его хватает, красноватый, если нет.
func _cost_row(cost: Dictionary) -> Control:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 12)
	flow.add_theme_constant_override("v_separation", 0)
	flow.custom_minimum_size = Vector2(420, 0)
	for id in cost:
		var ok: bool = Game.count(id) >= int(cost[id])
		flow.add_child(_label("%s %d/%d%s" % [Game.item_name(id), Game.count(id), cost[id], " ✓" if ok else ""], 15, HAVE if ok else LACK))
	return flow


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
	info.add_child(_cost_row(cost) if not cost.is_empty() else _label("бесплатно", 15, HAVE))
	var b := Button.new()
	b.text = "Посадить" if id == "fruit_tree" else "Строить"   # саженец сажают, а не строят
	b.custom_minimum_size = Vector2(120, 44)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.disabled = not Game.can_afford(cost)
	b.pressed.connect(func():
		close_all()
		build_selected.emit(id, variant))
	h.add_child(b)
	return rh[0]


# ================================================================== Лавка
func open_shop(shop_id: String) -> void:
	_shop_id = shop_id
	(shop_panel.get_node("V/Head/Title") as Label).text = Data.SHOPS[shop_id]["name"]
	_fill_shop()
	_open(shop_panel)


func _fill_shop() -> void:
	var body := _clear(shop_panel)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	body.add_child(top)
	for tab in [["buy", "Купить"], ["sell", "Продать"]]:
		var tb := Button.new()
		tb.text = tab[1]
		tb.custom_minimum_size = Vector2(140, 40)
		if tab[0] != _shop_tab:
			tb.add_theme_stylebox_override("normal", _box(WOOD_LIGHT, WOOD_DARK, 10, 3, 8))
		var t: String = tab[0]
		tb.pressed.connect(func():
			_shop_tab = t
			_fill_shop()
			_fit(shop_panel))
		top.add_child(tb)
	var have := HBoxContainer.new()
	have.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	have.alignment = BoxContainer.ALIGNMENT_END
	have.add_child(_item_icon("coins", 30))
	have.add_child(_label("Монет: %d" % Game.count("coins"), 20, INK, false))
	top.add_child(have)
	if _shop_tab == "buy":
		for e in Game.shop_items(_shop_id):
			var rh := _row()
			var h: HBoxContainer = rh[1]
			h.add_child(_card_icon(e["item"], 48))
			var info := VBoxContainer.new()
			info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			info.add_theme_constant_override("separation", 0)
			info.add_child(_label(Game.item_name(e["item"]), 20))
			var what := _buy_note(e["item"])
			if what != "":
				var wl := _label(what, 15, Color("f3e2bd"))
				wl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				wl.custom_minimum_size = Vector2(300, 0)
				info.add_child(wl)
			h.add_child(info)
			h.add_child(_label("%d" % e["price"], 20, Color("f3e2b8")))
			h.add_child(_item_icon("coins", 26))
			var b := Button.new()
			b.text = "Есть ✓" if Game.owned_unique(e["item"]) else "Купить"
			b.custom_minimum_size = Vector2(110, 42)
			b.disabled = Game.owned_unique(e["item"]) or Game.count("coins") < e["price"]
			var item_id: String = e["item"]
			var price: int = e["price"]
			b.pressed.connect(func(): Game.buy(_shop_id, item_id, price))
			h.add_child(b)
			body.add_child(rh[0])
	else:
		var any := false
		var buyer: Dictionary = Data.BUYERS.get(_shop_id, {})
		if buyer.has("likes"):
			var lk := _label("Особенно берут: %s." % buyer["likes"], 15, INK, false)
			lk.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			lk.custom_minimum_size = Vector2(580, 0)
			body.add_child(lk)
		# сначала то, за что здесь платят лучше всего
		var ids: Array = []
		for sid in Data.SELL_PRICES:
			if Game.count(sid) > 0:
				ids.append(sid)
		ids.sort_custom(func(a: String, b: String) -> bool: return Game.shop_mult(_shop_id, a) > Game.shop_mult(_shop_id, b))
		for id in ids:
			any = true
			var rh := _row()
			var h: HBoxContainer = rh[1]
			h.add_child(_card_icon(id, 48))
			var info := VBoxContainer.new()
			info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			info.add_child(_label("%s ×%d" % [Game.item_name(id), Game.count(id)], 20))
			var res := Game.reserved(id)
			var here := Game.sell_price(_shop_id, id)
			var base_k: float = float(buyer.get("base", 1.0))
			var mood := Game.shop_mult(_shop_id, id) / maxf(0.01, base_k)
			var note := "цена: %d мон." % here
			var note_col := Color("f3e2bd")
			if mood > 1.1:
				note = "★ любят: %d мон. за штуку" % here
				note_col = Color("b6f29a")
			elif mood < 0.9:
				note = "здесь не нужно: %d мон. за штуку" % here
				note_col = Color("c9b79a")
			if res > 0:
				note += "  ·  %d отложено для задания" % res
				note_col = Color("ffd08a")
			info.add_child(_label(note, 15, note_col))
			var better := Game.better_buyer(_shop_id, id)
			if not better.is_empty():
				var bshop: Dictionary = Data.SHOPS[better[0]]
				var who: String = str(Data.SPEAKERS.get(bshop["who"], {}).get("name", bshop["name"])).split(",")[0]
				info.add_child(_label("дороже у: %s — %d мон." % [who, int(better[1])], 14, Color("ffe08a")))
			h.add_child(info)
			var can := Game.sellable(id)
			for spec in [[1, "Продать 1"], [can, "Всё (%d)" % can]]:
				var b := Button.new()
				b.text = spec[1]
				b.custom_minimum_size = Vector2(110, 42)
				b.disabled = can <= 0
				var n: int = spec[0]
				var item_id: String = id
				b.pressed.connect(func(): Game.sell(_shop_id, item_id, n))
				h.add_child(b)
			body.add_child(rh[0])
		if not any:
			body.add_child(_label("Продавать пока нечего. Урожай, фрукты, яйца, молоко, мёд и шерсть — всё покупают.", 17, INK, false))


## Что получаешь за покупку: семена — пакетик на одну грядку и сколько с неё вырастет (и почём продать урожай),
## саженец — дерево, которое плодоносит снова и снова. Иначе — сколько уже есть.
func _buy_note(id: String) -> String:
	var it: Dictionary = Game.item(id)
	var have := Game.count(id)
	var tail := ("  ·  есть: %d" % have) if have > 0 else ""
	if it.get("cat", "") == "seed" and Data.CROPS.has(it.get("crop", "")):
		var crop: String = it["crop"]
		var y: Array = Data.CROPS[crop]["yield"]
		var price: float = float(Game.sell_price(_shop_id, crop))
		var money := ("  ≈ %d–%d мон." % [int(round(price * int(y[0]))), int(round(price * int(y[1])))]) if price > 0.0 else ""
		return "1 пакетик = 1 грядка · урожай %d–%d шт.%s · иногда семечко назад%s" % [int(y[0]), int(y[1]), money, tail]
	if it.get("cat", "") == "sapling" and Data.TREES.has(it.get("tree", "")):
		var t: Dictionary = Data.TREES[it["tree"]]
		return "дерево плодоносит снова и снова: по %d–%d шт.%s" % [int(t["yield"][0]), int(t["yield"][1]), tail]
	if it.has("tip"):
		return str(it["tip"])
	return tail.trim_prefix("  ·  ")


func open_inventory() -> void:
	_fill_inventory()
	_open(inv_panel)


func _fill_inventory() -> void:
	var body := _clear(inv_panel)
	var cats := {"tool": "Инструменты", "quest": "Особые предметы", "livestock": "Живность", "material": "Материалы", "seed": "Семена", "sapling": "Саженцы",
		"crop": "Урожай", "fruit": "Фрукты", "product": "С фермы", "food": "Блюда", "clothes": "Одежда", "medicine": "Лекарства"}
	var any := false
	for cat in cats:
		var grid := GridContainer.new()
		grid.columns = 6
		grid.add_theme_constant_override("h_separation", 6)
		grid.add_theme_constant_override("v_separation", 6)
		for id in Data.ITEMS:
			if Data.ITEMS[id]["cat"] == cat and Game.count(id) > 0:
				var cell := _item_slot(id, Game.count(id), true)
				if Data.ITEMS[id].has("food"):
					var fslot := cell.get_child(0) as PanelContainer
					fslot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
					cell.tooltip_text = "%s — нажми, чтобы съесть (+%d сытости)" % [Game.item_name(id), int(Data.ITEMS[id]["food"])]
					fslot.gui_input.connect(func(ev: InputEvent):
						if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
							if Game.count(id) - Game.reserved(id) <= 0:
								Game.notified.emit("Это нужно для задания — не ем", Color("ff9d7a"))
							else:
								Game.eat_item(id))
				if id in Game.HOLD_TOOLS:
					var slot := cell.get_child(0) as PanelContainer
					slot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
					if id == Game.held_tool():
						slot.add_theme_stylebox_override("panel", _box(Color("fff2b0"), Color("f2a93a"), 12, 5, 3))
					slot.gui_input.connect(func(ev: InputEvent):
						if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
							Game.hold(id)
							Audio.play("click", -6.0, 0.05))
				grid.add_child(cell)
		if grid.get_child_count() > 0:
			any = true
			body.add_child(_label(cats[cat], 18, INK, false))
			if cat == "tool":
				var tip := _label("Нажми на инструмент — герой возьмёт его в руку. Внизу экрана четыре ячейки (клавиши 1–4): туда попадают те, которыми ты пользуешься.", 14, WOOD, false)
				tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				tip.custom_minimum_size = Vector2(640, 0)
				body.add_child(tip)
			body.add_child(grid)
			# что дают вещи с особой пользой (фонарь, перчатки, рукавицы)
			for id in Data.ITEMS:
				if Data.ITEMS[id]["cat"] == cat and Data.ITEMS[id].has("tip") and Game.count(id) > 0:
					var tl := _label("• %s: %s" % [Game.item_name(id), Data.ITEMS[id]["tip"]], 14, WOOD, false)
					tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
					tl.custom_minimum_size = Vector2(640, 0)
					body.add_child(tl)
		else:
			grid.queue_free()
	if not any:
		body.add_child(_label("Пока пусто. Собирай всё, что видишь!", 18, INK, false))


func open_collections() -> void:
	_fill_collections()
	_open(col_panel)


func _fill_collections() -> void:
	var body := _clear(col_panel)
	_fill_replays(body)
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
				rd.pressed.connect(func(): show_dialogue([["journal", txt]], open_collections))
				v.add_child(rd)
			elif found:
				var c := _label("×%d" % have[it["id"]], 13, Color("f3e2bd"))
				c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				v.add_child(c)
			slots.add_child(v)
		body.add_child(rh[0])


# ================================================================== Перечитать разговоры
var _replay_open := false   # список разговоров раскрыт
var _replay_ch := -1   # глава, раскрытая в списке разговоров (-1 — последняя из доступных)


## Какие задания главы уже можно перечитать: пройденные целиком (вступление и концовка)
## и текущее, если его вступление уже показали. Возвращает [[номер задания, пройдено ли], ...].
func replay_quests(ci: int) -> Array:
	var out: Array = []
	if ci > Game.chapter or ci < 0 or ci >= Data.CHAPTERS.size():
		return out
	var qs: Array = Data.CHAPTERS[ci]["quests"]
	for i in qs.size():
		var done: bool = ci < Game.chapter or i < Game.quest_index
		var current: bool = ci == Game.chapter and i == Game.quest_index and Game.quest_started
		if not (done or current):
			continue
		var q: Dictionary = qs[i]
		if q.get("intro", []).is_empty() and q.get("outro", []).is_empty():
			continue
		out.append([i, done])
	return out


## Реплики задания для повтора: вступление, потом (если задание пройдено) концовка.
func replay_lines(ci: int, qi: int) -> Array:
	var q: Dictionary = Data.CHAPTERS[ci]["quests"][qi]
	var lines: Array = []
	lines.append_array(q.get("intro", []))
	var done: bool = ci < Game.chapter or qi < Game.quest_index
	if done:
		lines.append_array(q.get("outro", []))
	return lines


func _fill_replays(body: VBoxContainer) -> void:
	var chapters: Array = []
	for ci in Data.CHAPTERS.size():
		if not replay_quests(ci).is_empty():
			chapters.append(ci)
	if chapters.is_empty():
		return
	var sel: int = _replay_ch if _replay_ch in chapters else int(chapters[chapters.size() - 1])
	var rh := _row()
	var h: HBoxContainer = rh[1]
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(info)
	info.add_child(_label("Разговоры", 20))
	var note := _label("Уже слышанные разговоры можно послушать ещё раз.", 14, Color("f3e2bd"))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(380, 0)
	info.add_child(note)
	var toggle := Button.new()
	toggle.text = "Скрыть" if _replay_open else "Перечитать ▾"
	toggle.custom_minimum_size = Vector2(150, 40)
	toggle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	toggle.pressed.connect(func():
		_replay_open = not _replay_open
		_fill_collections()
		_fit(col_panel))
	h.add_child(toggle)
	if not _replay_open:
		body.add_child(rh[0])
		return
	var tabs := HFlowContainer.new()
	tabs.add_theme_constant_override("h_separation", 6)
	tabs.add_theme_constant_override("v_separation", 6)
	info.add_child(tabs)
	for ci in chapters:
		var tb := Button.new()
		tb.text = "Глава %d" % (int(ci) + 1)
		tb.custom_minimum_size = Vector2(96, 36)
		if ci != sel:
			tb.add_theme_stylebox_override("normal", _box(WOOD_LIGHT, WOOD_DARK, 10, 3, 8))
		var c: int = ci
		tb.pressed.connect(func():
			_replay_ch = c
			_fill_collections()
			_fit(col_panel))
		tabs.add_child(tb)
	info.add_child(_label(str(Data.CHAPTERS[sel]["title"]), 16, Color("ffe08a")))
	for e in replay_quests(sel):
		var qi: int = e[0]
		var q: Dictionary = Data.CHAPTERS[sel]["quests"][qi]
		var b := Button.new()
		b.text = "▶  %s%s" % [q["title"], "" if e[1] else "  (идёт сейчас)"]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 36)
		var chap: int = sel
		b.pressed.connect(func(): show_dialogue(replay_lines(chap, qi), open_collections))
		info.add_child(b)
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
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
Сытость — шкала из пяти отрезков вверху. Проголодался — силы возвращаются медленнее, голоден — идёшь медленнее,
очень голоден — не бежишь. Поесть: Q (подберёт подходящую еду) или клик по еде в сумке.
Инструменты изнашиваются (полоска под ячейкой) и ломаются; новый делается по тому же рецепту. Железные — прочнее и рубят вдвое быстрее.
1–4 — взять инструмент из ячейки внизу (ещё раз — убрать). Нужный инструмент герой берёт и сам; остальные — в сумке (Tab), клик по инструменту берёт его в руку.
У грядки и загона E открывает круг действий: выбери мышью, цифрой или нажми E ещё раз.
Пальма: пустыми руками — потрясти (кокосы), с топором в руке — срубить
C — крафт,  B — строительство,  Tab — инвентарь
J — журнал заданий,  K — коллекции (сверху — «Перечитать» уже слышанные разговоры),  Q — поесть,  T — рация (когда появится)
Продажа: у каждого торговца свои цены. Зелёная звёздочка — он любит этот товар и платит больше; жёлтая строка подсказывает, где дороже.
Фонарь светит ночью, греет на морозе, а ночью на его свет лучше клюёт рыба. Огнеупорные рукавицы носят на любом острове:
колючки и горячие камни им не страшны, жар у лавы растёт вдвое медленнее.
В строительстве: ЛКМ — поставить, R — повернуть, ПКМ — отмена
F5 — сохранить,  F9 — загрузить,  Esc — пауза и настройки

Грядки: посади семена, полей лейкой — растут вдвое быстрее.
Животные: покорми — через время будут яйца или молоко.
Их можно гладить!
Гроза (Грозовой остров): переждать под навесом, не стоять на вершинах.
Ливень сам поливает грядки, а громоотвод заряжает аккумуляторы.
Холод (Ледяной остров): шкала тепла тает вдали от огня. Греют костёр, печка, палатка,
теплица; куртка держит тепло дольше свитера. Q на морозе — выпить чай с мёдом.
Жар (Остров Вулкана): у лавы растёт шкала жара; полная — отбросит назад. Остужают источники,
огнеупорные рукавицы и мазь от ожогов (Q). Мосток через лаву — только на месте с колышками.
Туман (Туманный остров): плыть туда только ночью. Туман расступается у огня: костёр, фонарь,
фонарь со светлячками, тыквенные фонари на метках.""", 17, INK, false))


func show_help() -> void:
	_open(help_panel)


func any_open() -> bool:
	if dialogue_panel.visible or (credits and credits.visible) or (wheel and wheel.visible):
		return true
	for w in windows:
		if w.visible:
			return true
	return false


func close_all() -> void:
	for w in windows:
		w.visible = false
	if wheel:
		wheel.visible = false
	panels_changed.emit(any_open())


# ================================================================== Круг действий
var wheel: Control
var _wheel_hub: Control
var _wheel_opts: Array = []
var _wheel_btns: Array = []
var _wheel_sel := -1


func _build_wheel() -> void:
	wheel = Control.new()
	wheel.set_anchors_preset(Control.PRESET_FULL_RECT)
	wheel.visible = false
	root.add_child(wheel)
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.05, 0.03, 0.0, 0.28)
	shade.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			close_all())
	wheel.add_child(shade)
	_wheel_hub = Control.new()
	_wheel_hub.set_anchors_preset(Control.PRESET_CENTER)
	wheel.add_child(_wheel_hub)


## Круг действий: в середине — что это и в каком оно состоянии, вокруг — действия.
## options: [{"text", "icon", "callback", "note" (мелкая подпись), "enabled" (по умолчанию true)}].
## Выбор: мышью, цифрой 1..N или E / Enter — подсвеченное (первое доступное). Esc или клик мимо — закрыть.
func show_wheel(title: String, info: String, options: Array) -> void:
	for w in windows:
		w.visible = false
	for c in _wheel_hub.get_children():
		_wheel_hub.remove_child(c)
		c.queue_free()
	_wheel_opts = options
	_wheel_btns = []
	_wheel_sel = -1
	var n := options.size()
	var radius := 200.0 if n <= 4 else 240.0
	# середина
	var hub := PanelContainer.new()
	var hs := _box(PAPER, WOOD, 105, 7, 16)
	hs.shadow_size = 6
	hub.add_theme_stylebox_override("panel", hs)
	hub.custom_minimum_size = Vector2(210, 210)
	hub.position = Vector2(-105, -105)
	hub.mouse_filter = Control.MOUSE_FILTER_STOP
	_wheel_hub.add_child(hub)
	var hv := VBoxContainer.new()
	hv.alignment = BoxContainer.ALIGNMENT_CENTER
	hv.add_theme_constant_override("separation", 4)
	hub.add_child(hv)
	var tl := _label(title, 21, INK, false)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tl.custom_minimum_size = Vector2(160, 0)
	hv.add_child(tl)
	if info != "":
		var il := _label(info, 14, WOOD, false)
		il.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		il.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		il.custom_minimum_size = Vector2(160, 0)
		hv.add_child(il)
	var kl := _label("E — выбрать  ·  Esc — закрыть", 12, WOOD_LIGHT, false)
	kl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hv.add_child(kl)
	# действия по кругу: два — слева и справа, больше — с верхней точки по часовой стрелке
	for i in n:
		var o: Dictionary = options[i]
		var ang := (PI if i == 0 else 0.0) if n == 2 else -PI / 2 + TAU * i / n
		var on: bool = o.get("enabled", true)
		var b := Button.new()
		b.custom_minimum_size = Vector2(168, 132)
		b.size = Vector2(168, 132)
		b.position = Vector2(cos(ang), sin(ang)) * radius * Vector2(1.25, 1.0) - Vector2(84, 66)
		b.disabled = not on
		b.focus_mode = Control.FOCUS_NONE
		for st in ["normal", "hover", "pressed", "disabled"]:
			b.add_theme_stylebox_override(st, _box(CARD, CARD_EDGE, 16, 4, 6))
		b.modulate.a = 1.0 if on else 0.6
		var v := VBoxContainer.new()
		v.set_anchors_preset(Control.PRESET_FULL_RECT)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_theme_constant_override("separation", 0)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(v)
		var ic := _item_icon(str(o.get("icon", "")), 60)
		ic.custom_minimum_size = Vector2(60, 60)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(ic)
		var tx := _label(str(o["text"]), 18, INK, false)
		tx.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(tx)
		var note := str(o.get("note", ""))
		if note != "":
			var nl := _label(note, 13, WOOD if on else Color("b0503a"), false)
			nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			v.add_child(nl)
		var key := _label(str(i + 1), 14, Color("fff6dc"))
		key.position = Vector2(8, 3)
		b.add_child(key)
		b.pressed.connect(_wheel_run.bind(i))
		b.mouse_entered.connect(_wheel_select.bind(i))
		_wheel_hub.add_child(b)
		_wheel_btns.append(b)
		if on and _wheel_sel < 0:
			_wheel_sel = i
	_wheel_select(_wheel_sel)
	wheel.visible = true
	wheel.modulate.a = 0.0
	wheel.create_tween().tween_property(wheel, "modulate:a", 1.0, 0.12)
	Audio.play("open", -6.0, 0.05)
	panels_changed.emit(true)


func _wheel_select(i: int) -> void:
	if i < 0 or i >= _wheel_btns.size() or not _wheel_opts[i].get("enabled", true):
		return
	_wheel_sel = i
	for k in _wheel_btns.size():
		var sel := k == i
		var sb := _box(Color("fff2b0") if sel else CARD, Color("f2a93a") if sel else CARD_EDGE, 16, 6 if sel else 4, 6)
		sb.shadow_size = 5 if sel else 3
		for st in ["normal", "hover", "pressed", "disabled"]:
			(_wheel_btns[k] as Button).add_theme_stylebox_override(st, sb)


func _wheel_run(i: int) -> void:
	if i < 0 or i >= _wheel_opts.size() or not _wheel_opts[i].get("enabled", true):
		return
	var cb: Callable = _wheel_opts[i]["callback"]
	close_all()
	Audio.play("click", -6.0, 0.05)
	cb.call()


# ================================================================== Титры
var credits: Control
var _credits_done: Callable
var _credits_tw: Tween
const CAST := [
	["parrot", "Попугай Румба", "помнил дорогу лучше всех"],
	["marta", "Марта", "держала огонь на Баньяне и всех кормила"],
	["kesha", "Обезьянка Кешью", "присматривала за ключом"],
	["stepa", "Боцман Стёпа", "ругался, но приплыл"],
	["timur", "Радист Тимур", "слышал. Каждую ночь"],
	["ingrid", "Штурман Ингрид", "посчитала всё, даже пингвинов"],
	["walrus", "Морж Борис", "спал поперёк тропы"],
	["penguins", "Пингвины", "смотрели на сумку"],
	["vera", "Доктор Вера", "лечила травами и подзатыльниками"],
	["misha", "Юнга Миша", "стучал в рацию два года"],
	["renata", "Рената", "привела команду домой"],
	["gosha", "Механик Гоша", "починил «Альбатрос»"],
	["petya", "Петя Лукин", "...и рыба"],
	["pasha", "Паша Лукин", "...и часы"],
	["lyova", "Лёва", "держал огонь, пока ты плыл"],
	["player", "Ты", "упрямый человек. Это у вас семейное"],
]


## Титры с портретами всех жителей. Клик, E или Esc — пропустить.
func show_credits(sea: bool, on_done: Callable) -> void:
	_credits_done = on_done
	if credits:
		credits.queue_free()
	credits = Control.new()
	credits.set_anchors_preset(Control.PRESET_FULL_RECT)
	credits.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(credits)
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.05, 0.1, 0.92)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	credits.add_child(bg)
	var v := VBoxContainer.new()
	v.name = "Roll"
	v.add_theme_constant_override("separation", 18)
	v.custom_minimum_size = Vector2(720, 0)
	credits.add_child(v)
	var t := _label("Затерянный остров", 64, Color("ffe08a"))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var e := _label("Финал «%s»" % ("Открытое море" if sea else "Хранитель огня"), 30, Color("bfe8ff"))
	e.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(e)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 30)
	v.add_child(gap)
	for c in CAST:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 18)
		var face := TextureRect.new()
		face.texture = FX.icon_texture("portrait_" + str(c[0]))
		face.custom_minimum_size = Vector2(96, 96)
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		h.add_child(face)
		var col := VBoxContainer.new()
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.add_child(_label(str(c[1]), 30, Color("fff6dc")))
		col.add_child(_label(str(c[2]), 20, Color("d8cfe8")))
		h.add_child(col)
		v.add_child(h)
	for line in ["", "Спасибо, что доплыл.", "Острова ждут: ферма, коллекции, заказы жителей."]:
		var l := _label(line, 26, Color("ffe08a"))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)
	panels_changed.emit(true)
	Audio.play("quest", -4.0, 0.0)
	if DisplayServer.get_name() == "headless":
		close_credits()
		return
	await get_tree().process_frame
	var vs := root.get_viewport_rect().size
	v.position = Vector2((vs.x - v.size.x) * 0.5, vs.y)
	_credits_tw = create_tween()
	_credits_tw.tween_property(v, "position:y", -v.size.y, 28.0)
	_credits_tw.tween_callback(close_credits)


func close_credits() -> void:
	if credits == null or not credits.visible:
		return
	if _credits_tw and _credits_tw.is_valid():
		_credits_tw.kill()
	credits.visible = false
	panels_changed.emit(any_open())
	var cb := _credits_done
	_credits_done = Callable()
	if cb.is_valid():
		cb.call()


func _input(event: InputEvent) -> void:
	if wheel and wheel.visible and event is InputEventKey and event.pressed and not event.echo:
		var kc: int = (event as InputEventKey).physical_keycode
		if kc >= KEY_1 and kc <= KEY_9:
			_wheel_run(kc - KEY_1)
			get_viewport().set_input_as_handled()
			return
		if event.is_action("interact") or event.is_action("ui_accept"):
			_wheel_run(_wheel_sel)
			get_viewport().set_input_as_handled()
			return
	if credits and credits.visible and event.is_pressed() and not event.is_echo() 			and (event is InputEventMouseButton or event.is_action("interact") or event.is_action("ui_cancel") or event.is_action("ui_accept")):
		close_credits()
		get_viewport().set_input_as_handled()


func fade_through(mid: Callable) -> void:
	var tw := create_tween()
	tw.tween_property(fade_rect, "color:a", 1.0, 0.6)
	tw.tween_callback(mid)
	tw.tween_interval(0.5)
	tw.tween_property(fade_rect, "color:a", 0.0, 0.8)
