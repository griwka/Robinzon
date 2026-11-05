class_name MapScreen
extends Node
## Карта острова (клавиша M). Герой — картограф: карта дорисовывается там, где он побывал.
## Рельеф и берег берутся из Island.height_at, джунгли — из живых преград (расчищенное светлеет),
## поверх — лагерь, сюжетные места, жители, рыбалка, цель задания и сам герой.
## Открытые клетки сохраняются для каждого острова (loc_data["explored"]).

const GRID := 64           # клеток тумана по стороне
const IMG := 320           # пикселей рельефа по стороне
const REVEAL_R := 15.0     # насколько далеко «видно» вокруг героя, м
const VIEW := 600.0        # размер карты на экране

var hud: HUD
var island: Island
var player: Player
var guide: QuestGuide
var panel: PanelContainer
var canvas: Control
var legend: Label

var span := 140.0                         # сторона квадрата карты в метрах
var explored := PackedByteArray()
var _terrain_tex: ImageTexture
var _fog_tex: ImageTexture
var _fog_dirty := true
var _t := 0.0
var _base: Image             # рельеф без зарослей — не меняется, считается один раз в фоне
var _base_task := -1


func setup(h: HUD, isl: Island, p: Player, g: QuestGuide) -> void:
	hud = h
	island = isl
	player = p
	guide = g
	span = ceilf(island.radius * 2.75)
	if explored.size() != GRID * GRID:
		explored.resize(GRID * GRID)
		explored.fill(0)
	_build_window()
	# рельеф карты — 100 тысяч точек; считаем в фоне, чтобы M открывалась без заминки
	_base_task = WorkerThreadPool.add_task(func(): _base = _relief_image(), false, "map relief")


func _exit_tree() -> void:
	# фоновый рельеф должен досчитаться до того, как остров уйдёт (перезагрузка сцены, плавание)
	if _base_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_base_task)
		_base_task = -1


# ------------------------------------------------------------------ Открытые места
func to_save() -> String:
	return Marshalls.raw_to_base64(explored)


func from_save(s: String) -> void:
	var raw := Marshalls.base64_to_raw(s)
	if raw.size() == GRID * GRID:
		explored = raw
		_fog_dirty = true


func _cell(x: float, z: float) -> Vector2i:
	return Vector2i(int((x / span + 0.5) * GRID), int((z / span + 0.5) * GRID))


func is_explored(x: float, z: float) -> bool:
	var c := _cell(x, z)
	if c.x < 0 or c.y < 0 or c.x >= GRID or c.y >= GRID:
		return false
	return explored[c.y * GRID + c.x] != 0


func reveal(pos: Vector3, radius := REVEAL_R) -> void:
	var c := _cell(pos.x, pos.z)
	var rc := int(ceil(radius / span * GRID))
	for j in range(c.y - rc, c.y + rc + 1):
		for i in range(c.x - rc, c.x + rc + 1):
			if i < 0 or j < 0 or i >= GRID or j >= GRID:
				continue
			var cx := ((i + 0.5) / GRID - 0.5) * span
			var cz := ((j + 0.5) / GRID - 0.5) * span
			if Vector2(cx - pos.x, cz - pos.z).length() > radius:
				continue
			if explored[j * GRID + i] == 0:
				explored[j * GRID + i] = 1
				_fog_dirty = true


func explored_share() -> float:
	var land := 0
	var seen := 0
	for j in GRID:
		for i in GRID:
			var x := ((i + 0.5) / GRID - 0.5) * span
			var z := ((j + 0.5) / GRID - 0.5) * span
			if island.height_at(x, z) > 0.2:
				land += 1
				if explored[j * GRID + i] != 0:
					seen += 1
	return float(seen) / maxf(1.0, float(land))


func _process(delta: float) -> void:
	_t += delta
	if player and player.controls_enabled and _t > 0.25:
		_t = 0.0
		reveal(player.global_position)
	if panel and panel.visible:
		canvas.queue_redraw()


# ------------------------------------------------------------------ Картинка рельефа
const C_DEEP := Color("3f8fd0")
const C_SHALLOW := Color("74cfe6")
const C_SAND := Color("f3dc9c")
const C_GRASS := Color("9fd062")
const C_HILL := Color("7fb24e")
const C_ROCK := Color("b9ad94")
const C_JUNGLE := Color("4c8f3c")
const C_PAPER := Color("f1e2bd")
const C_INK := Color("5a3a1c")


func _terrain_image() -> Image:
	if _base_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_base_task)
		_base_task = -1
	if _base == null:
		_base = _relief_image()
	var img: Image = _base.duplicate()
	_paint_jungle(img)
	return img


## Рельеф и берег (только чтение высот — можно в фоновом потоке).
func _relief_image() -> Image:
	var img := Image.create(IMG, IMG, false, Image.FORMAT_RGBA8)
	var light := Vector3(-0.6, 0.75, -0.4).normalized()
	for j in IMG:
		for i in IMG:
			var x := ((i + 0.5) / IMG - 0.5) * span
			var z := ((j + 0.5) / IMG - 0.5) * span
			var h := island.height_at(x, z)
			var col: Color
			if h < -1.6:
				col = C_DEEP
			elif h < 0.05:
				col = C_DEEP.lerp(C_SHALLOW, clampf((h + 1.6) / 1.6, 0.0, 1.0))
			elif h < 1.05:
				col = C_SAND
			elif h < 4.5:
				col = C_GRASS.lerp(C_HILL, clampf((h - 1.05) / 3.5, 0.0, 1.0))
			else:
				col = C_HILL.lerp(C_ROCK, clampf((h - 6.5) / 4.0, 0.0, 1.0))
			if h > 0.05:
				# рисованная светотень по склонам
				var n := island.normal_at(x, z)
				var k := clampf(n.dot(light), 0.0, 1.0)
				col = col.darkened(0.22 * (1.0 - k)).lightened(0.08 * k)
				# береговая линия — тонкий тёмный контур
				if h < 0.35:
					col = col.lerp(C_INK, 0.35)
			img.set_pixel(i, j, col)
	return img


## Джунгли: живые преграды — тёмные пятна; расчищенное светлеет.
func _paint_jungle(img: Image) -> void:
	var px := float(IMG) / span
	for n in get_tree().get_nodes_in_group("obstacle"):
		if not (n is ResourceNode):
			continue
		var r := n as ResourceNode
		if not r.active or r.kind in ["pebble", "shell", "driftwood", "clay"]:
			continue
		var col := C_JUNGLE
		match r.kind:
			"cliff", "rock": col = Color("8f8676")
			"bamboo": col = Color("8fb040")
			"tall_grass", "fern": col = Color("6fae48")
			"palm": col = Color("5aa046")
		# на карте рисуем крону, а не ствол
		var crown: float = {"palm": 1.7, "jungle_tree": 2.3, "bamboo": 1.3}.get(r.kind, float(ResourceNode.KINDS[r.kind]["radius"]) * 1.2)
		var rad := maxf(1.0, crown * px)
		_blob(img, (r.global_position.x / span + 0.5) * IMG, (r.global_position.z / span + 0.5) * IMG, rad, col)


func _blob(img: Image, cx: float, cy: float, rad: float, col: Color) -> void:
	var ri := int(ceil(rad))
	for j in range(int(cy) - ri, int(cy) + ri + 1):
		for i in range(int(cx) - ri, int(cx) + ri + 1):
			if i < 0 or j < 0 or i >= IMG or j >= IMG:
				continue
			var d := Vector2(i + 0.5 - cx, j + 0.5 - cy).length()
			if d <= rad:
				var a := clampf(rad - d + 0.5, 0.0, 1.0) * 0.85
				img.set_pixel(i, j, img.get_pixel(i, j).lerp(col, a))


func _fog_image() -> Image:
	# плотность тумана по клеткам, дважды размытая — край «недорисованной» карты получается мягким
	var a := PackedFloat32Array()
	a.resize(GRID * GRID)
	for k in GRID * GRID:
		a[k] = 0.0 if explored[k] != 0 else 1.0
	for pass_i in 2:
		var b := PackedFloat32Array()
		b.resize(GRID * GRID)
		for j in GRID:
			for i in GRID:
				var sum := 0.0
				var n := 0
				for dj in [-1, 0, 1]:
					for di in [-1, 0, 1]:
						var x: int = clampi(i + di, 0, GRID - 1)
						var y: int = clampi(j + dj, 0, GRID - 1)
						sum += a[y * GRID + x]
						n += 1
				b[j * GRID + i] = sum / n
		a = b
	var img := Image.create(GRID, GRID, false, Image.FORMAT_RGBA8)
	for j in GRID:
		for i in GRID:
			img.set_pixel(i, j, Color(C_PAPER.r, C_PAPER.g, C_PAPER.b, smoothstep(0.15, 0.85, a[j * GRID + i])))
	return img


## Готовая картинка карты (для тестов и скриншотов): рельеф, туман и значки не нужны.
func render_image(with_fog := true) -> Image:
	var img := _terrain_image()
	if with_fog:
		var fog := _fog_image()
		fog.resize(IMG, IMG, Image.INTERPOLATE_CUBIC)
		img.blend_rect(fog, Rect2i(0, 0, IMG, IMG), Vector2i.ZERO)
	return img


# ------------------------------------------------------------------ Окно
func _build_window() -> void:
	panel = hud._make_window("Карта острова", int(VIEW) + 40)
	var v: VBoxContainer = panel.get_node("V")
	(v.get_node("Scroll") as Control).visible = false
	canvas = Control.new()
	canvas.custom_minimum_size = Vector2(VIEW, VIEW)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	canvas.draw.connect(_draw_map)
	v.add_child(canvas)
	legend = hud._label("", 15, HUD.INK, false)
	legend.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	legend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(legend)


func is_open() -> bool:
	return panel != null and panel.visible


func open() -> void:
	reveal(player.global_position)
	_terrain_tex = ImageTexture.create_from_image(_terrain_image())
	_fog_dirty = true
	var title := panel.get_node("V/Head/Title") as Label
	title.text = "Карта: %s" % Data.LOCATIONS[Game.location]["name"]
	var total := 0
	var got := 0
	for f in get_tree().get_nodes_in_group("obstacle"):
		if f is FindSpot:
			total += 1
			got += 1 if f.found() else 0
	legend.text = "Открыто %d%% острова · находок %d из %d.  Тёмная зелень — джунгли, светлое — расчищено.  ★ — цель задания" % [int(explored_share() * 100.0), got, total]
	hud._open(panel)


func _w2m(p: Vector3) -> Vector2:
	return Vector2((p.x / span + 0.5) * VIEW, (p.z / span + 0.5) * VIEW)


func _draw_map() -> void:
	if _terrain_tex == null:
		return
	if _fog_dirty or _fog_tex == null:
		_fog_dirty = false
		# мягкий край «недорисованной» карты: маленькая сетка, растянутая с плавной интерполяцией
		var fog := _fog_image()
		fog.resize(IMG, IMG, Image.INTERPOLATE_CUBIC)
		_fog_tex = ImageTexture.create_from_image(fog)
	var rect := Rect2(Vector2.ZERO, Vector2(VIEW, VIEW))
	canvas.draw_texture_rect(_terrain_tex, rect, false)
	canvas.draw_texture_rect(_fog_tex, rect, false)
	canvas.draw_rect(rect, C_INK, false, 3.0)
	var font := canvas.get_theme_default_font()
	# постройки игрока
	for b in get_tree().get_nodes_in_group("building"):
		var bp := _w2m((b as Node3D).global_position)
		var sz := clampf(float(Data.BUILDINGS[b.id]["radius"]) * VIEW / span * 1.6, 4.0, 14.0)
		canvas.draw_rect(Rect2(bp - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), Color("b8763c"))
		canvas.draw_rect(Rect2(bp - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), C_INK, false, 1.5)
	# места и жители
	for n in get_tree().get_nodes_in_group("interactable"):
		var node := n as Node3D
		if node == null:
			continue
		var wp := node.global_position
		var mp := _w2m(wp)
		if n is StoryPlace:
			if not is_explored(wp.x, wp.z) and not Game.flags.get("poi_" + n.id, false):
				continue
			_icon(mp, Color("e8443a") if not Game.flags.get("poi_" + n.id, false) else Color("8a5a32"), 7.0)
			_text(font, mp + Vector2(10, 5), StoryPlace.PLACES[n.id]["name"])
		elif n is NPCPerson or n is NPCParrot:
			if not is_explored(wp.x, wp.z):
				continue
			var who: String = "parrot" if n is NPCParrot else n.npc_id
			_portrait(mp, who)
		elif n is FishingSpot:
			if is_explored(wp.x, wp.z):
				_icon(mp, Color("3f8fd0"), 5.0)
		elif n is SupplyCrate:
			if is_explored(wp.x, wp.z):
				_icon(mp, Color("d39a5c"), 5.0)
	# находки: найденные — значком; ненайденные не выдаём, пусть ищут
	for f in get_tree().get_nodes_in_group("obstacle"):
		if f is FindSpot and f.found():
			var fp := _w2m((f as Node3D).global_position)
			_icon(fp, Color("8fd8b8") if f.kind == "bottle" else Color("e0503a"), 4.5)
	# сюжетные места острова, которые уже открыты, но сейчас без действий (не в группе interactable)
	var px := VIEW / span
	for id in island.poi:
		if id in ["fort", "banyan_roots"]:
			var pp: Vector3 = island.poi[id]
			if not is_explored(pp.x, pp.z):
				continue
			var mc := _w2m(pp)
			if id == "fort":
				canvas.draw_arc(mc, FortRuin.R * px, 0.0, TAU, 48, C_INK, 7.0)
				canvas.draw_arc(mc, FortRuin.R * px, 0.0, TAU, 48, Color("a49a8a"), 4.0)
				_text(font, mc + Vector2(-18, 5), "Форт")
			else:
				canvas.draw_circle(mc, 9.0 * px, Color(0.25, 0.5, 0.2, 0.55))
				canvas.draw_circle(mc, 3.6 * px + 2.0, C_INK)
				canvas.draw_circle(mc, 3.6 * px, Color("8a5a32"))
				_text(font, mc + Vector2(-56, -9.0 * px - 6.0), "Великий Баньян")
		elif Game.flags.get("poi_" + id, false):
			var q: Vector3 = island.poi[id]
			_icon(_w2m(q), Color("8a5a32"), 6.0)
			_text(font, _w2m(q) + Vector2(10, 5), StoryPlace.PLACES[id]["name"])
	# цель задания — звезда, видна даже в тумане
	if guide and guide.has_target():
		var tp := _w2m(guide.target_position())
		var pulse := 1.0 + 0.15 * sin(Time.get_ticks_msec() / 200.0)
		_star(tp, 11.0 * pulse, Color("ffd84a"))
	# герой — стрелка по взгляду
	var pp2 := _w2m(player.global_position)
	var fwd := -Basis(Vector3.UP, player.model.rotation.y).z
	var a := atan2(fwd.x, -fwd.z)
	var tri := PackedVector2Array()
	for v in [Vector2(0, -11), Vector2(8, 8), Vector2(0, 4), Vector2(-8, 8)]:
		tri.append(pp2 + (v as Vector2).rotated(a))
	var ring := PackedVector2Array()
	for v in [Vector2(0, -14), Vector2(10.5, 10), Vector2(0, 5.5), Vector2(-10.5, 10)]:
		ring.append(pp2 + (v as Vector2).rotated(a))
	canvas.draw_colored_polygon(ring, C_INK)
	canvas.draw_colored_polygon(tri, Color("ff8a2a"))
	# роза ветров
	var rc := Vector2(VIEW - 40, 44)
	canvas.draw_circle(rc, 22, Color(1, 1, 1, 0.35))
	canvas.draw_line(rc + Vector2(0, 16), rc + Vector2(0, -16), C_INK, 2.0)
	canvas.draw_line(rc + Vector2(-16, 0), rc + Vector2(16, 0), C_INK, 2.0)
	_text(font, rc + Vector2(-5, -22), "С")


func _icon(p: Vector2, col: Color, r: float) -> void:
	canvas.draw_circle(p, r + 2.0, C_INK)
	canvas.draw_circle(p, r, col)


func _star(p: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in 10:
		var rr := r if k % 2 == 0 else r * 0.45
		var a := -PI / 2 + k * PI / 5.0
		pts.append(p + Vector2(cos(a), sin(a)) * rr)
	var outer := PackedVector2Array()
	for k in 10:
		var rr := (r + 3.0) if k % 2 == 0 else (r * 0.45 + 2.5)
		var a := -PI / 2 + k * PI / 5.0
		outer.append(p + Vector2(cos(a), sin(a)) * rr)
	canvas.draw_colored_polygon(outer, C_INK)
	canvas.draw_colored_polygon(pts, col)


func _portrait(p: Vector2, who: String) -> void:
	var tex := FX.icon_texture("portrait_" + who)
	canvas.draw_circle(p, 15.0, C_INK)
	canvas.draw_circle(p, 13.0, C_PAPER)
	if tex:
		canvas.draw_texture_rect(tex, Rect2(p - Vector2(13, 13), Vector2(26, 26)), false)


func _text(font: Font, p: Vector2, s: String) -> void:
	if font == null:
		return
	canvas.draw_string_outline(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 4, C_PAPER)
	canvas.draw_string(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, C_INK)
