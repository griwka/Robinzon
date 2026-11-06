class_name GameMenu
extends CanvasLayer
## Главное меню (над медленно облетающей остров камерой), меню паузы и настройки.

signal continue_pressed
signal new_game_pressed
signal resume_pressed
signal save_pressed
signal to_main_menu_pressed

var hud: HUD   # берём у HUD стили, чтобы всё выглядело одинаково
var root: Control
var main_box: Control
var pause_box: Control
var settings_box: PanelContainer
var confirm_box: PanelContainer
var continue_btn: Button
var ending_label: Label
var _settings_back: Callable


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = hud.root.theme
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_main()
	_build_pause()
	_build_settings()
	_build_confirm()
	hide_all()


func _button(text: String, cb: Callable, color := HUD.GREEN) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(340, 62)
	b.add_theme_font_size_override("font_size", 26)
	if color != HUD.GREEN:
		b.add_theme_stylebox_override("normal", hud._box(color, color.darkened(0.45), 12, 4, 10))
		b.add_theme_stylebox_override("hover", hud._box(color.lightened(0.12), color.darkened(0.45), 12, 4, 10))
	b.pressed.connect(cb)
	return b


# ------------------------------------------------------------------ Главное меню
func _build_main() -> void:
	main_box = Control.new()
	main_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(main_box)
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.05, 0.02, 0.0, 0.18)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_box.add_child(shade)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	v.position = Vector2(110, -250)
	v.add_theme_constant_override("separation", 14)
	main_box.add_child(v)
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 10)
	v.add_child(title_row)
	var title := hud._label("Затерянный\nостров", 92, Color("ffe08a"))
	title.add_theme_constant_override("outline_size", 22)
	title.add_theme_constant_override("line_spacing", -18)
	title_row.add_child(title)
	var face := TextureRect.new()
	face.texture = FX.icon_texture("portrait_parrot")
	face.custom_minimum_size = Vector2(170, 170)
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.size_flags_vertical = Control.SIZE_SHRINK_END
	face.rotation = 0.12
	title_row.add_child(face)
	var sub := hud._label("Уютная жизнь на необитаемом острове", 24, Color("fff6dc"))
	sub.add_theme_constant_override("outline_size", 10)
	v.add_child(sub)
	# отметка о пройденных финалах (хранится в настройках — переживает новую игру)
	ending_label = hud._label("", 22, Color("bfe8ff"))
	ending_label.add_theme_constant_override("outline_size", 9)
	v.add_child(ending_label)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 24)
	v.add_child(gap)
	continue_btn = _button("Продолжить", func(): continue_pressed.emit())
	v.add_child(continue_btn)
	v.add_child(_button("Новая игра", _on_new_game, Color("e0a23a")))
	v.add_child(_button("Настройки", func(): open_settings(show_main.bind(continue_btn.visible)), HUD.WOOD_LIGHT))
	v.add_child(_button("Выход", func(): get_tree().quit(), Color("b9573b")))
	var ver := hud._label("v1.0 · все восемь глав", 16, Color("fff6dc"))
	ver.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	ver.position = Vector2(-190, -40)
	main_box.add_child(ver)


func _on_new_game() -> void:
	if FileAccess.file_exists(Game.save_path):
		confirm_box.visible = true
	else:
		new_game_pressed.emit()


func show_main(has_save: bool) -> void:
	hide_all()
	continue_btn.visible = has_save
	var names := {"sea": "«Открытое море»", "keeper": "«Хранитель огня»"}
	var seen: Array[String] = []
	for e in str(Game.settings.get("endings", "")).split(",", false):
		if names.has(e):
			seen.append(names[e])
	ending_label.text = ("★ Пройдено: финал " if seen.size() == 1 else "★ Пройдены финалы: ") + " и ".join(seen) if not seen.is_empty() else ""
	ending_label.visible = not seen.is_empty()
	main_box.visible = true


# ------------------------------------------------------------------ Пауза
func _build_pause() -> void:
	pause_box = Control.new()
	pause_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(pause_box)
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.04, 0.02, 0.0, 0.45)
	pause_box.add_child(shade)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", hud._box(HUD.PAPER, HUD.WOOD, 18, 8, 26))
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	pause_box.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	var t := hud._label("Пауза", 40)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	v.add_child(_button("Продолжить", func(): resume_pressed.emit()))
	v.add_child(_button("Сохранить игру", func(): save_pressed.emit(), HUD.WOOD_LIGHT))
	v.add_child(_button("Настройки", func(): open_settings(show_pause), HUD.WOOD_LIGHT))
	v.add_child(_button("Главное меню", func(): to_main_menu_pressed.emit(), Color("e0a23a")))
	v.add_child(_button("Выйти из игры", func():
		save_pressed.emit()
		get_tree().quit(), Color("b9573b")))


func show_pause() -> void:
	hide_all()
	pause_box.visible = true


# ------------------------------------------------------------------ Настройки
func _build_settings() -> void:
	settings_box = PanelContainer.new()
	settings_box.add_theme_stylebox_override("panel", hud._box(HUD.PAPER, HUD.WOOD, 18, 8, 26))
	settings_box.set_anchors_preset(Control.PRESET_CENTER)
	settings_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	settings_box.grow_vertical = Control.GROW_DIRECTION_BOTH
	settings_box.custom_minimum_size = Vector2(620, 0)
	root.add_child(settings_box)


func _fill_settings() -> void:
	for c in settings_box.get_children():
		settings_box.remove_child(c)
		c.queue_free()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	settings_box.add_child(v)
	v.add_child(hud._label("Настройки", 36))
	_slider(v, "Музыка", "music", 0.0, 1.0)
	_slider(v, "Звуки", "sfx", 0.0, 1.0)
	_slider(v, "Природа (прибой, птицы)", "ambience", 0.0, 1.0)
	_slider(v, "Чувствительность мыши", "mouse", 0.3, 2.5)
	_option(v, "Тени", "shadows", ["Низкие", "Средние", "Высокие"])
	_option(v, "Эффекты", "effects", ["Низко", "Средне", "Высоко"])
	_option(v, "Сглаживание", "msaa", ["Выкл", "2x", "4x"])
	_option(v, "Чёткость картинки", "sharpen", ["Выкл", "Мягко", "Чётко"])
	_check(v, "Тряска камеры при ударах", "shake")
	_check(v, "Полный экран", "fullscreen")
	_check(v, "Вертикальная синхронизация", "vsync")
	var back := _button("Готово", func():
		Game.save_settings()
		_settings_back.call())
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(back)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if settings_box.visible:
			Game.save_settings()
			_settings_back.call()
			get_viewport().set_input_as_handled()
		elif confirm_box.visible:
			confirm_box.visible = false
			get_viewport().set_input_as_handled()
		elif pause_box.visible:
			resume_pressed.emit()
			get_viewport().set_input_as_handled()


func _row(v: VBoxContainer, title: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	var l := hud._label(title, 20, HUD.INK, false)
	l.custom_minimum_size = Vector2(300, 0)
	h.add_child(l)
	v.add_child(h)
	return h


func _slider(v: VBoxContainer, title: String, key: String, lo: float, hi: float) -> void:
	var h := _row(v, title)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 0.05
	s.value = float(Game.settings[key])
	s.custom_minimum_size = Vector2(240, 32)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.add_theme_stylebox_override("slider", hud._box(HUD.WOOD_LIGHT, HUD.WOOD_DARK, 8, 2, 4))
	s.add_theme_stylebox_override("grabber_area", hud._box(HUD.GREEN, HUD.GREEN_DARK, 8, 2, 4))
	s.add_theme_stylebox_override("grabber_area_highlight", hud._box(HUD.GREEN.lightened(0.1), HUD.GREEN_DARK, 8, 2, 4))
	s.value_changed.connect(func(val):
		Game.settings[key] = val
		Audio.apply_volumes()
		if key == "sfx":
			Audio.play("pickup", -4.0))
	h.add_child(s)


func _option(v: VBoxContainer, title: String, key: String, items: Array) -> void:
	var h := _row(v, title)
	for i in items.size():
		var b := Button.new()
		b.text = items[i]
		b.custom_minimum_size = Vector2(100, 40)
		if int(Game.settings[key]) != i:
			b.add_theme_stylebox_override("normal", hud._box(HUD.WOOD_LIGHT, HUD.WOOD_DARK, 10, 3, 6))
		b.pressed.connect(func():
			Game.settings[key] = i
			Game.apply_display()
			_fill_settings())
		h.add_child(b)


func _check(v: VBoxContainer, title: String, key: String) -> void:
	var h := _row(v, title)
	var b := Button.new()
	b.text = "Вкл" if Game.settings[key] else "Выкл"
	b.custom_minimum_size = Vector2(100, 40)
	if not Game.settings[key]:
		b.add_theme_stylebox_override("normal", hud._box(HUD.WOOD_LIGHT, HUD.WOOD_DARK, 10, 3, 6))
	b.pressed.connect(func():
		Game.settings[key] = not Game.settings[key]
		Game.apply_display()
		_fill_settings())
	h.add_child(b)


func open_settings(back: Callable) -> void:
	hide_all()
	_settings_back = back
	_fill_settings()
	settings_box.visible = true


# ------------------------------------------------------------------ Подтверждение
func _build_confirm() -> void:
	confirm_box = PanelContainer.new()
	confirm_box.add_theme_stylebox_override("panel", hud._box(HUD.PAPER, HUD.WOOD, 18, 8, 26))
	confirm_box.set_anchors_preset(Control.PRESET_CENTER)
	confirm_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	confirm_box.grow_vertical = Control.GROW_DIRECTION_BOTH
	root.add_child(confirm_box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	confirm_box.add_child(v)
	var l := hud._label("Начать заново?\nТекущее сохранение будет удалено.", 24, HUD.INK, false)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	v.add_child(h)
	var yes := _button("Да, новая игра", func():
		confirm_box.visible = false
		new_game_pressed.emit(), Color("e0a23a"))
	yes.custom_minimum_size = Vector2(260, 56)
	h.add_child(yes)
	var no := _button("Отмена", func(): confirm_box.visible = false, HUD.WOOD_LIGHT)
	no.custom_minimum_size = Vector2(200, 56)
	h.add_child(no)


func hide_all() -> void:
	main_box.visible = false
	pause_box.visible = false
	settings_box.visible = false
	confirm_box.visible = false


func is_open() -> bool:
	return main_box.visible or pause_box.visible or settings_box.visible or confirm_box.visible
