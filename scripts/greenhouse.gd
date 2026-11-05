class_name Greenhouse
extends Building
## Теплица: стеклянный домик с четырьмя грядками внутри. Под стеклом растёт всё и в мороз
## (на Ледяном острове до оттепели), и на четверть быстрее — на любом острове. Внутри тепло.
## Грядки — обычные GardenBed, но сохраняются вместе с теплицей (её состоянием).

const BEDS := [Vector3(-1.25, 0, -0.85), Vector3(-1.25, 0, 0.85), Vector3(1.25, 0, -0.85), Vector3(1.25, 0, 0.85)]

var beds: Array[GardenBed] = []
var _pending: Array = []


func _ready() -> void:
	super()
	for p in BEDS:
		var bed := GardenBed.new()
		bed.setup("garden_bed")
		bed.in_greenhouse = true
		bed.position = p
		bed.rotation.y = PI / 2
		add_child(bed)
		bed.remove_from_group("building")   # сохраняется в состоянии теплицы
		beds.append(bed)
	_apply_pending()


func _make_collision() -> void:
	# стеклянные стены с дверью спереди (+Z): внутрь можно войти
	var hx := 2.15
	var hz := 1.95
	_add_box(Vector3(hx * 2.0, 2.4, 0.15), Vector3(0, 1.2, -hz), 0.0)
	_add_box(Vector3(0.15, 2.4, hz * 2.0), Vector3(-hx, 1.2, 0), 0.0)
	_add_box(Vector3(0.15, 2.4, hz * 2.0), Vector3(hx, 1.2, 0), 0.0)
	for sx in [-1, 1]:
		_add_box(Vector3(hx - 0.55, 2.4, 0.15), Vector3(sx * (hx + 0.55) * 0.5, 1.2, hz), 0.0)


func get_state() -> Dictionary:
	var list := []
	for b in beds:
		list.append(b.get_state())
	return {"beds": list}


func apply_state(d: Dictionary) -> void:
	_pending = d.get("beds", [])
	if is_inside_tree():
		_apply_pending()


func _apply_pending() -> void:
	for i in mini(_pending.size(), beds.size()):
		beds[i].apply_state(_pending[i])
	_pending = []
