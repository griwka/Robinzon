class_name HUD
extends CanvasLayer
## Интерфейс: энергия, часы, задание, панель предметов, подсказки, окна крафта/строительства/помощи.
## Стиль — "деревянные" панели и зелёные кнопки, как в классических мобильных фермах.

signal build_selected(id: String)
signal panels_changed(any_open: bool)
signal new_game_requested

const WOOD := Color("7a4e2a")
const WOOD_DARK := Color("3f2614")
const WOOD_LIGHT := Color("a8784a")
const PAPER := Color("f6e7c1")
const GREEN := Color("6dbb3a")
const GREEN_DARK := Color("3f7d1f")

var station_check: Callable  # func(station_id) -> bool

var root: Control
var energy_bar: ProgressBar
var energy_label: Label
var clock_label: Label
var quest_title: Label
var quest_progress: Label
var hotbar: HBoxContainer
var hint_label: Label
var toasts: VBoxContainer
var crosshair: Control
var craft_panel: PanelContainer
var craft_list: VBoxContainer
var craft_station_label: Label
var build_panel: PanelContainer
var build_list: VBoxContainer
var help_panel: PanelContainer
var victory_panel: PanelContainer
var fade_rect: ColorRect
var _craft_station := ""


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
	craft_panel = _make_window("Крафт", 620)
	craft_station_label = Label.new()
	craft_station_label.add_theme_color_override("font_color", WOOD_DARK)
	craft_panel.get_child(0).add_child(craft_station_label)
	craft_list = VBoxContainer.new()
	craft_list.add_theme_constant_override("separation", 8)
	craft_panel.get_child(0).add_child(craft_list)
	build_panel = _make_window("Строительство", 620)
	build_list = VBoxContainer.new()
	build_list.add_theme_constant_override("separation", 8)
	build_panel.get_child(0).add_child(build_list)
	_build_help()
	_build_victory()
	fade_rect = ColorRect.new()
	fade_rect.color = Color(0.02, 0.03, 0.08, 0)
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fade_rect)

	Game.inventory_changed.connect(_on_inventory_changed)
	Game.energy_changed.connect(_on_energy)
	Game.notified.connect(toast)
	Game.quest_changed.connect(_update_quest)
	Game.time_changed.connect(func(_t, _d): clock_label.text = Game.clock_text())
	_on_inventory_changed()
	_on_energy(Game.energy, Game.MAX_ENERGY)
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
	t.default_font_size = 18
	t.set_color("font_color", "Label", Color.WHITE)
	t.set_color("font_outline_color", "Label", Color(0.15, 0.08, 0.03))
	t.set_constant("outline_size", "Label", 5)
	t.set_stylebox("panel", "PanelContainer", _box(WOOD, WOOD_DARK))
	t.set_stylebox("normal", "Button", _box(GREEN, GREEN_DARK, 10, 3, 8))
	t.set_stylebox("hover", "Button", _box(GREEN.lightened(0.15), GREEN_DARK, 10, 3, 8))
	t.set_stylebox("pressed", "Button", _box(GREEN.darkened(0.15), GREEN_DARK, 10, 3, 8))
	t.set_stylebox("disabled", "Button", _box(Color("9c8a74"), Color("6b5c4a"), 10, 3, 8))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(1, 1, 1, 0.6))
	t.set_color("font_outline_color", "Button", Color(0.1, 0.25, 0.05))
	t.set_constant("outline_size", "Button", 4)
	t.set_font_size("font_size", "Button", 18)
	var bar_bg := _box(WOOD_DARK, WOOD_DARK, 8, 2, 0)
	var bar_fg := _box(Color("ffcf3d"), Color("c98d10"), 8, 2, 0)
	bar_bg.shadow_size = 0
	bar_fg.shadow_size = 0
	t.set_stylebox("background", "ProgressBar", bar_bg)
	t.set_stylebox("fill", "ProgressBar", bar_fg)
	return t


func _make_window(title: String, width: int) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(width, 0)
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	p.add_theme_stylebox_override("panel", _box(PAPER, WOOD, 16, 8, 20))
	p.visible = false
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var l := Label.new()
	l.text = title
	l.add_theme_font_size_override("font_size", 28)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(l)
	var close := Button.new()
	close.text = "✕"
	close.custom_minimum_size = Vector2(40, 40)
	close.add_theme_stylebox_override("normal", _box(Color("d9573b"), Color("8a2a17"), 10, 3, 6))
	close.add_theme_stylebox_override("hover", _box(Color("e8704f"), Color("8a2a17"), 10, 3, 6))
	close.pressed.connect(close_all)
	head.add_child(close)
	root.add_child(p)
	return p


# ================================================================== Статус
func _build_status() -> void:
	var p := PanelContainer.new()
	p.position = Vector2(16, 16)
	root.add_child(p)
	var v := VBoxContainer.new()
	p.add_child(v)
	clock_label = Label.new()
	clock_label.text = Game.clock_text()
	clock_label.add_theme_font_size_override("font_size", 20)
	v.add_child(clock_label)
	var h := HBoxContainer.new()
	v.add_child(h)
	var el := Label.new()
	el.text = "Энергия"
	h.add_child(el)
	energy_bar = ProgressBar.new()
	energy_bar.custom_minimum_size = Vector2(170, 22)
	energy_bar.show_percentage = false
	energy_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(energy_bar)
	energy_label = Label.new()
	h.add_child(energy_label)


func _on_energy(v: float, m: float) -> void:
	energy_bar.max_value = m
	energy_bar.value = v
	energy_label.text = "%d/%d" % [int(v), int(m)]


func _build_quest() -> void:
	var p := PanelContainer.new()
	p.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	p.position = Vector2(-16, 16)
	p.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	p.custom_minimum_size = Vector2(340, 0)
	root.add_child(p)
	var v := VBoxContainer.new()
	p.add_child(v)
	var t := Label.new()
	t.text = "Задание"
	t.add_theme_color_override("font_color", Color("ffe08a"))
	t.add_theme_font_size_override("font_size", 20)
	v.add_child(t)
	quest_title = Label.new()
	quest_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quest_title.custom_minimum_size = Vector2(310, 0)
	v.add_child(quest_title)
	quest_progress = Label.new()
	quest_progress.add_theme_color_override("font_color", Color("c9f59b"))
	v.add_child(quest_progress)


func _update_quest() -> void:
	var q := Game.current_quest()
	if q.is_empty():
		quest_title.text = "Все задания выполнены! Новые острова — в следующих версиях."
		quest_progress.text = ""
		return
	quest_title.text = q["text"]
	quest_progress.text = "%d / %d" % [Game.quest_progress(), q["count"]]


# ================================================================== Предметы
func _build_hotbar() -> void:
	var p := PanelContainer.new()
	p.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BEGIN
	p.position.y = -16
	p.name = "HotbarPanel"
	root.add_child(p)
	hotbar = HBoxContainer.new()
	hotbar.add_theme_constant_override("separation", 6)
	p.add_child(hotbar)

	hint_label = Label.new()
	hint_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hint_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hint_label.position.y = -120
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_font_size_override("font_size", 22)
	root.add_child(hint_label)

	crosshair = ColorRect.new()
	crosshair.color = Color(1, 1, 1, 0.8)
	crosshair.custom_minimum_size = Vector2(6, 6)
	crosshair.size = Vector2(6, 6)
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	crosshair.position -= Vector2(3, 3)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crosshair.visible = false
	root.add_child(crosshair)


func _on_inventory_changed() -> void:
	for c in hotbar.get_children():
		c.queue_free()
	var any := false
	for id in Game.ITEMS:
		var n := Game.count(id)
		if n <= 0:
			continue
		any = true
		hotbar.add_child(_item_slot(id, n))
	if not any:
		var l := Label.new()
		l.text = "  Инвентарь пуст — исследуй остров!  "
		hotbar.add_child(l)
	_update_quest()
	if craft_panel and craft_panel.visible:
		_fill_craft()
	if build_panel and build_panel.visible:
		_fill_build()


func _item_slot(id: String, n: int) -> Control:
	var col: Color = Game.ITEMS[id]["color"]
	var slot := PanelContainer.new()
	slot.custom_minimum_size = Vector2(80, 76)
	slot.add_theme_stylebox_override("panel", _box(WOOD_LIGHT, WOOD_DARK, 10, 3, 4))
	slot.tooltip_text = Game.item_name(id)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 0)
	slot.add_child(v)
	var icon := PanelContainer.new()
	icon.custom_minimum_size = Vector2(36, 36)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.add_theme_stylebox_override("panel", _box(col, col.darkened(0.45), 18, 3, 0))
	v.add_child(icon)
	var short := Label.new()
	short.text = Game.item_short(id)
	short.add_theme_font_size_override("font_size", 12)
	short.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(short)
	var cnt := Label.new()
	cnt.text = "×%d" % n
	cnt.add_theme_font_size_override("font_size", 16)
	cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(cnt)
	return slot


func set_hint(text: String) -> void:
	hint_label.text = text


func set_crosshair(v: bool) -> void:
	crosshair.visible = v


# ================================================================== Сообщения
func _build_toasts() -> void:
	toasts = VBoxContainer.new()
	toasts.position = Vector2(20, 140)
	toasts.add_theme_constant_override("separation", 4)
	toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(toasts)


func toast(text: String, color := Color.WHITE) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", 20)
	toasts.add_child(l)
	if toasts.get_child_count() > 7:
		toasts.get_child(0).queue_free()
	var tw := l.create_tween()
	tw.tween_interval(2.5)
	tw.tween_property(l, "modulate:a", 0.0, 0.8)
	tw.tween_callback(l.queue_free)


# ================================================================== Крафт
func open_craft(station := "") -> void:
	close_all(false)
	_craft_station = station
	_fill_craft()
	craft_panel.visible = true
	panels_changed.emit(true)


func _fill_craft() -> void:
	for c in craft_list.get_children():
		c.queue_free()
	var names := {"": "в руках", "workbench": "у верстака", "campfire": "у костра"}
	craft_station_label.text = "Рецепты с пометкой «у верстака» / «у костра» доступны, только если стоять рядом."
	craft_station_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for r in Game.RECIPES:
		var station: String = r["station"]
		var near: bool = station == "" or (station_check.is_valid() and station_check.call(station))
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", _box(WOOD, WOOD_DARK, 10, 3, 10))
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		row.add_child(h)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(info)
		var title := Label.new()
		var out_id: String = r["out"].keys()[0]
		title.text = "%s ×%d   (%s)" % [Game.item_name(out_id), r["out"][out_id], names.get(station, station)]
		title.add_theme_font_size_override("font_size", 20)
		info.add_child(title)
		var cost := Label.new()
		cost.text = _cost_text(r["in"])
		cost.add_theme_font_size_override("font_size", 15)
		cost.add_theme_color_override("font_color", Color("c9f59b") if Game.can_afford(r["in"]) else Color("ffb199"))
		info.add_child(cost)
		var b := Button.new()
		b.text = "Создать" if near else "Далеко"
		b.custom_minimum_size = Vector2(120, 44)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.disabled = not near or not Game.can_afford(r["in"])
		b.pressed.connect(func(): Game.craft(r))
		h.add_child(b)
		craft_list.add_child(row)


func _cost_text(cost: Dictionary) -> String:
	var parts: Array[String] = []
	for id in cost:
		parts.append("%s %d/%d" % [Game.item_name(id), Game.count(id), cost[id]])
	return ", ".join(parts)


# ================================================================== Строительство
func open_build() -> void:
	close_all(false)
	_fill_build()
	build_panel.visible = true
	panels_changed.emit(true)


func _fill_build() -> void:
	for c in build_list.get_children():
		c.queue_free()
	for id in Game.BUILDINGS:
		var cfg: Dictionary = Game.BUILDINGS[id]
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", _box(WOOD, WOOD_DARK, 10, 3, 10))
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		row.add_child(h)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(info)
		var title := Label.new()
		title.text = cfg["name"]
		title.add_theme_font_size_override("font_size", 20)
		info.add_child(title)
		var desc := Label.new()
		desc.text = cfg["desc"]
		desc.add_theme_font_size_override("font_size", 14)
		desc.add_theme_color_override("font_color", Color("f3e2bd"))
		info.add_child(desc)
		var cost := Label.new()
		cost.text = _cost_text(cfg["cost"])
		cost.add_theme_font_size_override("font_size", 15)
		cost.add_theme_color_override("font_color", Color("c9f59b") if Game.can_afford(cfg["cost"]) else Color("ffb199"))
		info.add_child(cost)
		var b := Button.new()
		b.text = "Строить"
		b.custom_minimum_size = Vector2(120, 44)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.disabled = not Game.can_afford(cfg["cost"])
		b.pressed.connect(func():
			close_all()
			build_selected.emit(id))
		h.add_child(b)
		build_list.add_child(row)


# ================================================================== Помощь / победа
func _build_help() -> void:
	help_panel = _make_window("Как играть", 560)
	var l := Label.new()
	l.text = """WASD — ходить,  Shift — бег,  Пробел — прыжок
Мышь — камера,  колёсико — приблизить/отдалить
ЛКМ или E — собирать / рубить / использовать (можно удерживать)
Q — съесть лучшую еду (восстанавливает энергию)
C — крафт,  B — строительство
В режиме строительства: ЛКМ — поставить, R — повернуть, ПКМ — отмена
F5 — сохранить,  F9 — загрузить,  F10 — новая игра
F1 / H — эта справка,  Esc — освободить мышь / закрыть окно

Совет: у пальм без топора можно трясти кокосы.
Каждое действие тратит 1 энергию, она медленно восстанавливается сама."""
	l.add_theme_font_size_override("font_size", 17)
	help_panel.get_child(0).add_child(l)
	var ng := Button.new()
	ng.text = "Начать заново"
	ng.add_theme_stylebox_override("normal", _box(Color("d9573b"), Color("8a2a17"), 10, 3, 8))
	ng.pressed.connect(func(): new_game_requested.emit())
	help_panel.get_child(0).add_child(ng)


func _build_victory() -> void:
	victory_panel = _make_window("Ты отплываешь!", 560)
	var l := Label.new()
	l.text = """Плот готов, парус наполнился ветром.
Вдали видны другие острова — ледяной, вулканический, туманный...

Это конец прототипа. В следующих версиях: путешествия
между островами, ферма с животными, коллекции и гости-соседи."""
	l.add_theme_font_size_override("font_size", 18)
	victory_panel.get_child(0).add_child(l)
	var b := Button.new()
	b.text = "Остаться на острове"
	b.pressed.connect(close_all)
	victory_panel.get_child(0).add_child(b)


func show_help() -> void:
	close_all(false)
	help_panel.visible = true
	panels_changed.emit(true)


func show_victory() -> void:
	close_all(false)
	victory_panel.visible = true
	panels_changed.emit(true)


func any_open() -> bool:
	return craft_panel.visible or build_panel.visible or help_panel.visible or victory_panel.visible


func close_all(emit := true) -> void:
	for p in [craft_panel, build_panel, help_panel, victory_panel]:
		p.visible = false
	if emit:
		panels_changed.emit(false)


func fade_through(mid: Callable) -> void:
	var tw := create_tween()
	tw.tween_property(fade_rect, "color:a", 1.0, 0.6)
	tw.tween_callback(mid)
	tw.tween_interval(0.5)
	tw.tween_property(fade_rect, "color:a", 0.0, 0.8)
