class_name SkyStars
## Яркие звёзды и созвездия ночного неба (настоящие: прямое восхождение в часах, склонение в градусах,
## звёздная величина). Небо над островом — как в северных широтах около 32°: Полярная звезда невысоко
## на севере, Большая Медведица и Кассиопея кружат вокруг неё, в полночь на юге — Орион с Сириусом.
## Плюс «вечерняя звезда» (Венера) недалеко от солнца: первой загорается в сумерках.
## WorldEnv передаёт всё это в небо (shaders/sky.gdshader) один раз; вращает небо он же.

const BLUE := Color(0.78, 0.86, 1.0)
const WHITE := Color(1.0, 0.98, 0.95)
const WARM := Color(1.0, 0.88, 0.7)
const RED := Color(1.0, 0.72, 0.52)

## имя, RA (ч), Dec (°), звёздная величина, цвет
const STARS := [
	# Большая Медведица (Ковш)
	["dubhe", 11.062, 61.75, 1.8, WARM], ["merak", 11.031, 56.38, 2.4, WHITE], ["phecda", 11.897, 53.69, 2.4, WHITE],
	["megrez", 12.257, 57.03, 3.3, WHITE], ["alioth", 12.900, 55.96, 1.8, WHITE], ["mizar", 13.399, 54.93, 2.2, WHITE],
	["alkaid", 13.792, 49.31, 1.9, BLUE],
	# Полярная и Малая Медведица (ковшик)
	["polaris", 2.530, 89.26, 2.0, WARM], ["kochab", 14.845, 74.16, 2.1, RED], ["pherkad", 15.345, 71.83, 3.0, WHITE],
	["yildun", 17.537, 86.59, 4.3, WHITE], ["eps_umi", 16.766, 82.04, 4.2, WHITE], ["zeta_umi", 15.734, 77.79, 4.3, WHITE],
	["eta_umi", 16.292, 75.76, 4.9, WHITE],
	# Кассиопея (буква W)
	["caph", 0.153, 59.15, 2.3, WHITE], ["schedar", 0.675, 56.54, 2.2, WARM], ["navi", 0.945, 60.72, 2.5, BLUE],
	["ruchbah", 1.430, 60.24, 2.7, WHITE], ["segin", 1.907, 63.67, 3.4, BLUE],
	# Орион
	["betelgeuse", 5.919, 7.41, 0.5, RED], ["rigel", 5.242, -8.20, 0.1, BLUE], ["bellatrix", 5.419, 6.35, 1.6, BLUE],
	["saiph", 5.796, -9.67, 2.1, BLUE], ["alnitak", 5.679, -1.94, 1.8, BLUE], ["alnilam", 5.603, -1.20, 1.7, BLUE],
	["mintaka", 5.533, -0.30, 2.2, BLUE], ["meissa", 5.585, 9.93, 3.4, BLUE],
	# вокруг Ориона: Сириус, Процион, Альдебаран, Плеяды, Капелла, Близнецы
	["sirius", 6.752, -16.72, -1.46, BLUE], ["procyon", 7.655, 5.22, 0.34, WHITE], ["aldebaran", 4.599, 16.51, 0.85, RED],
	["alcyone", 3.791, 24.105, 2.9, BLUE], ["atlas", 3.819, 24.053, 3.6, BLUE], ["electra", 3.747, 24.113, 3.7, BLUE],
	["maia", 3.763, 24.368, 3.9, BLUE], ["merope", 3.772, 23.948, 4.2, BLUE], ["taygeta", 3.754, 24.467, 4.3, BLUE],
	["capella", 5.278, 46.0, 0.08, WARM], ["pollux", 7.755, 28.03, 1.14, WARM], ["castor", 7.577, 31.89, 1.58, WHITE],
	# Лебедь (Северный крест), Лира, Орёл — летний треугольник (видны вечером на западе)
	["deneb", 20.690, 45.28, 1.25, WHITE], ["sadr", 20.370, 40.26, 2.2, WARM], ["gienah", 20.770, 33.97, 2.5, WARM],
	["delta_cyg", 19.750, 45.13, 2.9, BLUE], ["albireo", 19.512, 27.96, 3.1, WARM],
	["vega", 18.616, 38.78, 0.03, BLUE], ["altair", 19.846, 8.87, 0.77, WHITE],
	# Лев и Арктур — встают под утро
	["regulus", 10.140, 11.97, 1.35, BLUE], ["denebola", 11.818, 14.57, 2.1, WHITE], ["algieba", 10.333, 19.84, 2.0, WARM],
	["arcturus", 14.261, 19.18, -0.05, WARM],
]

const LINES := [
	["dubhe", "merak"], ["merak", "phecda"], ["phecda", "megrez"], ["megrez", "dubhe"], ["megrez", "alioth"],
	["alioth", "mizar"], ["mizar", "alkaid"],
	["polaris", "yildun"], ["yildun", "eps_umi"], ["eps_umi", "zeta_umi"], ["zeta_umi", "eta_umi"], ["eta_umi", "pherkad"],
	["pherkad", "kochab"], ["kochab", "zeta_umi"],
	["caph", "schedar"], ["schedar", "navi"], ["navi", "ruchbah"], ["ruchbah", "segin"],
	["betelgeuse", "bellatrix"], ["meissa", "betelgeuse"], ["meissa", "bellatrix"], ["betelgeuse", "alnitak"],
	["bellatrix", "mintaka"], ["alnitak", "alnilam"], ["alnilam", "mintaka"], ["alnitak", "saiph"], ["mintaka", "rigel"],
	["deneb", "sadr"], ["sadr", "albireo"], ["delta_cyg", "sadr"], ["sadr", "gienah"],
	["regulus", "algieba"], ["algieba", "denebola"], ["denebola", "regulus"],
	["castor", "pollux"],
]


## Направление на звезду в небесных координатах (x — к точке весны, z — к северному полюсу мира).
static func cel(ra_h: float, dec_deg: float) -> Vector3:
	var a := ra_h / 24.0 * TAU
	var d := deg_to_rad(dec_deg)
	return Vector3(cos(d) * cos(a), cos(d) * sin(a), sin(d))


## Яркость по звёздной величине (0..~3.5): Сириус и Венера — ярче всех, звёзды 4-й величины — едва видны.
static func brightness(mag: float) -> float:
	return clampf(0.55 * pow(2.512, (2.2 - mag) * 0.55), 0.25, 2.8)


## Всё для неба: направления и цвета звёзд, концы и нормали линий. evening_ra — где вечерняя звезда.
static func build(evening_ra: float) -> Dictionary:
	var dirs := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := {}
	for s in STARS:
		var v := cel(float(s[1]), float(s[2]))
		idx[s[0]] = v
		dirs.append(v)
		var c: Color = s[4]
		cols.append(Color(c.r, c.g, c.b, brightness(float(s[3]))))
	# вечерняя звезда: очень яркая, тёплая, не мерцает (яркость > 3 — без мерцания)
	dirs.append(cel(evening_ra, -6.0))
	cols.append(Color(1.0, 0.96, 0.86, 3.2))
	var la := PackedVector3Array()
	var lb := PackedVector3Array()
	var ln := PackedVector3Array()
	for l in LINES:
		var a: Vector3 = idx[l[0]]
		var b: Vector3 = idx[l[1]]
		var n := a.cross(b)
		if n.length() < 1e-6:
			continue
		la.append(a)
		lb.append(b)
		ln.append(n.normalized())
	return {"dirs": dirs, "cols": cols, "la": la, "lb": lb, "ln": ln}
