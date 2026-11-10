class_name GameMenu
extends CanvasLayer
## Главное меню (над медленно облетающей остров камерой), меню паузы и настройки.

signal continue_pressed
signal new_game_pressed
signal resume_pressed
signal save_pressed
signal to_main_menu_pressed
signal to_camp_pressed                # «Вернуться в лагерь»: если герой где-то застрял
signal load_slot_pressed(n: int)      # загрузить игру из ячейки n
signal save_slot_pressed(n: int)      # сохранить текущую игру в ячейку n
signal new_game_slot_pressed(n: int)  # начать новую игру в ячейке n

var hud: HUD   # берём у HUD стили, чтобы всё выглядело одинаково
var root: Control
var main_box: Control
var pause_box: Control
var settings_box: PanelContainer
var confirm_box: PanelContainer
var confirm_label: Label
var confirm_yes: Button
var _confirm_cb: Callable
var slots_box: PanelContainer
var slots_shade: ColorRect
var _slots_mode := "load"     # load — загрузить, save — сохранить в ячейку, new — новая игра
var _slots_back: Callable
var continue_btn: Button
var load_btn: Button
var save_btn: Button
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
	_build_slots()
	_build_confirm()
	hide_all()


func _button(text: String, cb: Callable, color := HUD.GREEN) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(340, 54)
	b.add_theme_font_size_override("font_size", 24)
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
	load_btn = _button("Загрузить игру", func(): open_slots("load", show_main.bind(continue_btn.visible)), HUD.WOOD_LIGHT)
	v.add_child(load_btn)
	v.add_child(_button("Новая игра", _on_new_game, Color("e0a23a")))
	v.add_child(_button("Настройки", func(): open_settings(show_main.bind(continue_btn.visible)), HUD.WOOD_LIGHT))
	v.add_child(_button("Выход", func(): get_tree().quit(), Color("b9573b")))
	var ver := hud._label("v1.0 · все восемь глав", 16, Color("fff6dc"))
	ver.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	ver.position = Vector2(-190, -40)
	main_box.add_child(ver)


## Новая игра: если сохранений ещё нет — сразу в первую ячейку, иначе выбрать ячейку.
func _on_new_game() -> void:
	if not Game.any_slot_used():
		new_game_slot_pressed.emit(1)
	else:
		open_slots("new", show_main.bind(continue_btn.visible))


func show_main(has_save: bool) -> void:
	hide_all()
	continue_btn.visible = has_save
	continue_btn.text = "Продолжить" if not has_save else "Продолжить  ·  ячейка %d" % Game.slot
	load_btn.visible = Game.any_slot_used()
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
	save_btn = _button("Сохранить игру", func(): save_pressed.emit(), HUD.WOOD_LIGHT)
	v.add_child(save_btn)
	v.add_child(_button("Сохранить в другую ячейку", func(): open_slots("save", show_pause), HUD.WOOD_LIGHT))
	v.add_child(_button("Загрузить игру", func(): open_slots("load", show_pause), HUD.WOOD_LIGHT))
	v.add_child(_button("Вернуться в лагерь", func(): to_camp_pressed.emit(), HUD.WOOD_LIGHT))
	v.add_child(_button("Настройки", func(): open_settings(show_pause), HUD.WOOD_LIGHT))
	v.add_child(_button("Главное меню", func(): to_main_menu_pressed.emit(), Color("e0a23a")))
	v.add_child(_button("Выйти из игры", func():
		save_pressed.emit()
		get_tree().quit(), Color("b9573b")))


func show_pause() -> void:
	hide_all()
	save_btn.text = "Сохранить  ·  ячейка %d" % Game.slot
	pause_box.visible = true


# ------------------------------------------------------------------ Ячейки сохранения
func _build_slots() -> void:
	slots_shade = ColorRect.new()   # в паузе игра под списком затемнена, как под меню паузы
	slots_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	slots_shade.color = Color(0.04, 0.02, 0.0, 0.45)
	root.add_child(slots_shade)
	slots_box = PanelContainer.new()
	slots_box.add_theme_stylebox_override("panel", hud._box(HUD.PAPER, HUD.WOOD, 18, 8, 22))
	slots_box.set_anchors_preset(Control.PRESET_CENTER)
	slots_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	slots_box.grow_vertical = Control.GROW_DIRECTION_BOTH
	slots_box.custom_minimum_size = Vector2(760, 0)
	root.add_child(slots_box)


## Открыть список ячеек: mode — load / save / new; back — куда вернуться по «Назад».
func open_slots(mode: String, back: Callable) -> void:
	hide_all()
	_slots_mode = mode
	_slots_back = back
	_fill_slots()
	slots_shade.visible = get_tree().paused
	slots_box.visible = true


func _fill_slots() -> void:
	for c in slots_box.get_children():
		slots_box.remove_child(c)
		c.queue_free()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	slots_box.add_child(v)
	var title := hud._label(str({"load": "Загрузить игру", "save": "Сохранить в ячейку", "new": "Новая игра — выбери ячейку"}[_slots_mode]), 32, HUD.INK, false)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var in_game := get_tree().paused
	for n in range(1, Game.SLOTS + 1):
		var info := Game.slot_info(n)
		var current := in_game and n == Game.slot
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", hud._box(Color("fff6dc") if not current else Color("e6f5c8"), HUD.WOOD_LIGHT, 12, 3, 10))
		v.add_child(row)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		row.add_child(h)
		var num := hud._label(str(n), 34, HUD.WOOD, false)
		num.custom_minimum_size = Vector2(36, 0)
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		h.add_child(num)
		var txt := VBoxContainer.new()
		txt.add_theme_constant_override("separation", 0)
		txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(txt)
		var empty := info.is_empty()
		var usable := not empty and not info.has("old") and not info.has("broken")
		var top := "Пусто"
		var sub := ""
		if info.has("old"):
			top = "Сохранение старой версии"
			sub = "загрузить нельзя — сюжет с тех пор поменялся"
		elif info.has("broken"):
			top = "Сохранение повреждено"
		elif usable:
			top = str(info["chapter"])
			sub = ("играешь сейчас  ·  " if current else "") + "%s  ·  день %d  ·  %s" % [info["island"], int(info["day"]), info["when"]]
		var l1 := hud._label(top, 21, HUD.INK if not empty else HUD.WOOD_LIGHT, false)
		l1.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l1.custom_minimum_size = Vector2(380, 0)
		txt.add_child(l1)
		if sub != "":
			txt.add_child(hud._label(sub, 16, HUD.WOOD, false))
		var act: Button = null
		match _slots_mode:
			"load":
				if usable:
					act = _small_button("Загрузить", _ask_load.bind(n), HUD.GREEN)
			"save":
				act = _small_button("Сохранить сюда", _ask_save.bind(n, not empty and not current), HUD.GREEN)
			"new":
				act = _small_button("Начать здесь", _ask_new.bind(n, not empty), Color("e0a23a"))
		if act:
			h.add_child(act)
		if _slots_mode == "load" and not empty and not current:
			h.add_child(_small_button("Удалить", _ask_delete.bind(n), Color("b9573b"), 110))
	var back := _button("Назад", func(): _slots_back.call(), HUD.WOOD_LIGHT)
	back.custom_minimum_size = Vector2(240, 54)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(back)


func _small_button(text: String, cb: Callable, color: Color, w := 180) -> Button:
	var b := _button(text, cb, color)
	b.custom_minimum_size = Vector2(w, 48)
	b.add_theme_font_size_override("font_size", 20)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return b


func _ask_load(n: int) -> void:
	if get_tree().paused:   # из игры: несохранённое пропадёт — переспросим
		ask("Загрузить ячейку %d?\nВсё, что не сохранено в текущей игре, пропадёт." % n, "Загрузить",
			func(): load_slot_pressed.emit(n))
	else:
		load_slot_pressed.emit(n)


func _ask_save(n: int, overwrite: bool) -> void:
	var go := func():
		save_slot_pressed.emit(n)
		_fill_slots()
		slots_box.visible = true
	if overwrite:
		ask("Сохранить в ячейку %d?\nТо, что там лежит, заменится текущей игрой." % n, "Сохранить", go)
	else:
		go.call()


func _ask_new(n: int, overwrite: bool) -> void:
	if overwrite:
		ask("Начать новую игру в ячейке %d?\nСохранение в ней будет удалено." % n, "Да, новая игра",
			func(): new_game_slot_pressed.emit(n))
	else:
		new_game_slot_pressed.emit(n)


func _ask_delete(n: int) -> void:
	ask("Удалить сохранение в ячейке %d?\nВернуть его будет нельзя." % n, "Удалить", func():
		Game.delete_slot(n)
		_fill_slots()
		slots_box.visible = true)


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
		elif slots_box.visible:
			_slots_back.call()
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
	confirm_label = hud._label("", 24, HUD.INK, false)
	confirm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(confirm_label)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(h)
	confirm_yes = _button("Да", func():
		confirm_box.visible = false
		_confirm_cb.call(), Color("e0a23a"))
	confirm_yes.custom_minimum_size = Vector2(260, 56)
	h.add_child(confirm_yes)
	var no := _button("Отмена", func(): confirm_box.visible = false, HUD.WOOD_LIGHT)
	no.custom_minimum_size = Vector2(200, 56)
	h.add_child(no)


## Переспросить: окно поверх текущего; «Отмена» просто закрывает его.
func ask(text: String, yes_text: String, cb: Callable) -> void:
	confirm_label.text = text
	confirm_yes.text = yes_text
	_confirm_cb = cb
	confirm_box.visible = true
	confirm_box.move_to_front()


func hide_all() -> void:
	main_box.visible = false
	pause_box.visible = false
	settings_box.visible = false
	confirm_box.visible = false
	slots_box.visible = false
	slots_shade.visible = false


func is_open() -> bool:
	return main_box.visible or pause_box.visible or settings_box.visible or confirm_box.visible or slots_box.visible
