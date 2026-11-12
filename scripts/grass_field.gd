class_name GrassField
extends Node3D
## Мелкая трава, цветы и травка острова — пучками (MultiMesh), кусками по 10 × 10 м: дальние куски
## не рисуются, а убрать траву в одном месте — дёшево.
##
## Траву можно расчистить: подошёл, ЛКМ / E — вырвал руками (держи кнопку — дальше), с мачете в руке —
## скосил шире. Остров делится на клетки 1 × 1 м; расчищенные клетки хранятся в сохранении (Game.grass —
## битовая карта на остров), трава там больше не вырастает, а земля становится ровным ухоженным газоном
## (маска clear_mask в шейдере земли). Постройка сама расчищает траву под собой.

const CELL := 1.0
const CHUNK := 10.0
const HALF := 100.0          # Island.SIZE / 2: остров — от −100 до 100 м
const RES := 200             # клеток по стороне (и пикселей маски)
const HAND_R := 0.95         # руками — круг вокруг точки перед героем
const BLADE_R := 1.6         # мачете — шире
const FIBER_EVERY := 14      # за столько вырванных пучков — одно волокно

var island: Island
var loc := ""
var _chunks := {}            # Vector2i -> {слой: MultiMeshInstance3D}
var _pending := {}           # Vector2i -> {слой: [[Transform3D...], [Color...], [клетка...]]}
var _cells := {}             # клетка -> [[MultiMesh, индекс, Transform3D], ...] — что ещё растёт в клетке
var _bits: PackedByteArray   # расчищенные клетки (1 бит на клетку)
var _mask: Image
var _mask_tex: ImageTexture
var _anim: Array = []        # [MultiMesh, индекс, Transform3D, t] — пучки, которые сейчас «уходят» в землю
var _fiber_acc := 0
var spot: Spot


func _init() -> void:
	name = "GrassField"


func setup(isl: Island) -> void:
	island = isl
	loc = isl.loc
	_bits = Game.grass_bits(loc)
	_mask = Image.create(RES, RES, false, Image.FORMAT_R8)
	for i in RES * RES:
		if _bits[i >> 3] & (1 << (i & 7)):
			_mask.set_pixel(i % RES, i / RES, Color(1, 0, 0))
	_mask_tex = ImageTexture.create_from_image(_mask)
	spot = Spot.new()
	spot.field = self
	add_child(spot)


func mask_texture() -> ImageTexture:
	return _mask_tex


static func cell_of(x: float, z: float) -> int:
	var ix := clampi(int(floor((x + HALF) / CELL)), 0, RES - 1)
	var iz := clampi(int(floor((z + HALF) / CELL)), 0, RES - 1)
	return iz * RES + ix


func is_cleared(x: float, z: float) -> bool:
	var c := cell_of(x, z)
	return (_bits[c >> 3] & (1 << (c & 7))) != 0


## Добавить пучок (до commit). Пучки в расчищенных клетках не добавляются — там трава не растёт.
func add(layer: String, xf: Transform3D, col: Color) -> void:
	var p := xf.origin
	if is_cleared(p.x, p.z):
		return
	var ck := Vector2i(int(floor((p.x + HALF) / CHUNK)), int(floor((p.z + HALF) / CHUNK)))
	var ch: Dictionary = _pending.get(ck, {})
	if not ch.has(layer):
		ch[layer] = [[], [], []]
	var arr: Array = ch[layer]
	(arr[0] as Array).append(xf)
	(arr[1] as Array).append(col)
	(arr[2] as Array).append(cell_of(p.x, p.z))
	_pending[ck] = ch


## Собрать куски слоя в MultiMesh.
func commit(layer: String, mesh: Mesh, material: Material, far := 62.0) -> void:
	for ck in _pending:
		var ch: Dictionary = _pending[ck]
		if not ch.has(layer):
			continue
		var arr: Array = ch[layer]
		var xfs: Array = arr[0]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = mesh
		mm.instance_count = xfs.size()
		for i in xfs.size():
			mm.set_instance_transform(i, xfs[i])
			mm.set_instance_color(i, arr[1][i])
			var c: int = arr[2][i]
			if not _cells.has(c):
				_cells[c] = []
			(_cells[c] as Array).append([mm, i, xfs[i]])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "%s_%d_%d" % [layer, ck.x, ck.y]
		mmi.multimesh = mm
		mmi.material_override = material
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_end = far
		mmi.visibility_range_end_margin = 6.0
		add_child(mmi)
		var have: Dictionary = _chunks.get(ck, {})
		have[layer] = mmi
		_chunks[ck] = have
		ch.erase(layer)


## Сколько пучков ещё растёт в круге.
func count_near(p: Vector3, r: float) -> int:
	var n := 0
	for c in _cells_in(p, r):
		n += (_cells.get(c, []) as Array).size()
	return n


func _cells_in(p: Vector3, r: float) -> Array[int]:
	var out: Array[int] = []
	var x0 := int(floor((p.x - r + HALF) / CELL))
	var x1 := int(floor((p.x + r + HALF) / CELL))
	var z0 := int(floor((p.z - r + HALF) / CELL))
	var z1 := int(floor((p.z + r + HALF) / CELL))
	for iz in range(maxi(z0, 0), mini(z1, RES - 1) + 1):
		for ix in range(maxi(x0, 0), mini(x1, RES - 1) + 1):
			var cx := -HALF + (ix + 0.5) * CELL
			var cz := -HALF + (iz + 0.5) * CELL
			if Vector2(cx - p.x, cz - p.z).length() <= r + CELL * 0.35:
				out.append(iz * RES + ix)
	return out


## Расчистить круг: пучки уходят в землю, клетки помечаются расчищенными (сохраняется).
## Возвращает, сколько пучков убрано.
func clear_at(p: Vector3, r: float, quiet := false) -> int:
	var removed := 0
	var changed := false
	for c in _cells_in(p, r):
		if (_bits[c >> 3] & (1 << (c & 7))) == 0:
			_bits[c >> 3] |= 1 << (c & 7)
			_mask.set_pixel(c % RES, c / RES, Color(1, 0, 0))
			changed = true
		var live: Array = _cells.get(c, [])
		for e in live:
			if quiet:
				(e[0] as MultiMesh).set_instance_transform(e[1], Transform3D(Basis.from_scale(Vector3.ZERO), (e[2] as Transform3D).origin))
			else:
				_anim.append([e[0], e[1], e[2], 0.0])
			removed += 1
		_cells.erase(c)
	if changed:
		_mask_tex.update(_mask)
		Game.set_grass_bits(loc, _bits)
	return removed


func _process(delta: float) -> void:
	if _anim.is_empty():
		return
	var keep: Array = []
	for a in _anim:
		var t: float = a[3] + delta * 4.5
		var xf: Transform3D = a[2]
		var mm: MultiMesh = a[0]
		if t >= 1.0:
			mm.set_instance_transform(a[1], Transform3D(Basis.from_scale(Vector3.ZERO), xf.origin))
			continue
		# пучок приседает и съёживается — «выдернули»
		var k := 1.0 - t * t
		mm.set_instance_transform(a[1], Transform3D(xf.basis.scaled(Vector3(k, k * k, k)), xf.origin + Vector3(0, t * 0.12, 0)))
		a[3] = t
		keep.append(a)
	_anim = keep


## Вырвать траву перед героем (вызывает Spot.interact). Мачете в руке — шире.
func pull(player: Node3D, at: Vector3) -> void:
	var blade: bool = Game.held_tool() in ["machete", "iron_machete"]
	var n := clear_at(at, BLADE_R if blade else HAND_R)
	if n <= 0:
		return
	var world := get_parent()
	FX.leaves(world, at + Vector3(0, 0.25, 0), Palette.TUFT_TIP if not island.cold else Island.TUNDRA_TUFT_TIP, mini(4 + n / 3, 12))
	FX.dust(world, at + Vector3(0, 0.05, 0), Color("cdbf8a"), 3, 0.3)
	Audio.play("pull", -6.0, 0.15, at)
	_fiber_acc += n
	if _fiber_acc >= FIBER_EVERY:
		var got := _fiber_acc / FIBER_EVERY
		_fiber_acc -= got * FIBER_EVERY
		Game.add_item("fiber", got)
	if player and player.has_method("add_trauma"):
		player.call("add_trauma", 0.04)


## Цель для героя: точка в траве перед ним. Своей сетки нет — подсветки нет; держишь кнопку — рвёт дальше.
class Spot extends Node3D:
	var field: GrassField

	func _ready() -> void:
		add_to_group("grass_spot")

	func interact_point() -> Vector3:
		return global_position

	func tool_hint() -> String:
		return ""

	func get_hint() -> String:
		if Game.held_tool() in ["machete", "iron_machete"]:
			return "Скосить траву мачете (держи — дальше)"
		return "Вырвать траву (держи — дальше)"

	func interact(player: Node) -> void:
		field.pull(player as Node3D, global_position)
