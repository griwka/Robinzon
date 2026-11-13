class_name Palette
## Единая палитра игры. Отсюда берут цвета земля, трава, вода, небо, облака, заливка теней и эффекты —
## поэтому трава у корней совпадает с землёй, облака окрашиваются как небо, а дым ночью темнеет вместе с миром.
## Менять общий «вкус» картинки — здесь.

# ------------------------------------------------------------------ земля
const SAND := Color("f9db8c")
const SAND_DARK := Color("ebc277")
const SAND_LIGHT := Color("fde7a8")
const WET_SAND := Color("d9ab69")
const GRASS := Color("74a849")
const GRASS_LIGHT := Color("8cb857")
const GRASS_DARK := Color("5a8f3f")
const GRASS_WARM := Color("9db955")    # солнечные проплешины
const ROCK := Color("a59f98")
const ROCK_DARK := Color("88827c")
const DIRT := Color("c9a273")
const DIRT_DARK := Color("ad885d")
const SEABED := Color("6fc7b8")

# трава-пучки: основание = цвет земли (сливается с газоном), кончики светлее
const TUFT_BASE := Color("6a9f45")
const TUFT_TIP := Color("a0bf63")

# обводка — тёплый тёмно-коричневый, как у рисованных иллюстраций
const OUTLINE := Color("331c0f")

# ------------------------------------------------------------------ небо и свет по времени суток
## Ключевые точки суток (по высоте солнца). Между ними цвета смешиваются плавно — без скачков:
## день → золотой час → закат → синие сумерки → поздние сумерки → ночь (утром — то же назад, но рассвет
## розовее и дымчатее заката).
## top/hor — видимое небо (hor — горизонт со стороны солнца, hor_far — с другой стороны);
## amb_* — заливка теней (сверху, у горизонта, снизу — отражённый от земли свет);
## sun — цвет и sun_e сила солнца; fog — плотность дымки вдали; water — яркость воды;
## band — тёплая полоса у горизонта (и розовый «пояс» напротив солнца); cloud_* — облака;
## light — множитель для дыма, пыли и брызг.
const DAY := {
	"top": Color("3f8fe6"), "hor": Color("c4e6f4"), "hor_far": Color("bfe2f6"), "sun": Color("ffedd0"), "sun_e": 0.74,
	"amb_top": Color("a29cd0"), "amb_hor": Color("aea5c4"), "amb_ground": Color("b0956a"), "amb_e": 1.0,
	"fog": 0.32, "water": 1.0, "band": 0.0,
	"cloud_lit": Color("ffffff"), "cloud_shade": Color("bec6ea"), "light": Color(1.0, 1.0, 1.0),
}
## Золотой час: солнце низко, всё тёплое и мягкое.
const GOLDEN := {
	"top": Color("4f86d6"), "hor": Color("ffdcab"), "hor_far": Color("c6d2ec"), "sun": Color("ffd49c"), "sun_e": 0.72,
	"amb_top": Color("a49ccc"), "amb_hor": Color("c4a5a6"), "amb_ground": Color("b08a62"), "amb_e": 1.0,
	"fog": 0.36, "water": 0.95, "band": 0.45,
	"cloud_lit": Color("ffe2bd"), "cloud_shade": Color("b2a4cc"), "light": Color(1.0, 0.94, 0.85),
}
## Закат: солнце касается моря.
const SUNSET := {
	"top": Color("4a5db2"), "hor": Color("ffa463"), "hor_far": Color("c99ab4"), "sun": Color("ff9d5c"), "sun_e": 0.6,
	"amb_top": Color("9086c6"), "amb_hor": Color("c48f94"), "amb_ground": Color("93715a"), "amb_e": 1.0,
	"fog": 0.42, "water": 0.86, "band": 1.0,
	"cloud_lit": Color("ffb486"), "cloud_shade": Color("8a76b6"), "light": Color(1.0, 0.84, 0.74),
}
## Рассвет: розовее, прохладнее и дымчатее заката.
const SUNRISE := {
	"top": Color("5868bc"), "hor": Color("ffb497"), "hor_far": Color("aeb0d8"), "sun": Color("ffb184"), "sun_e": 0.56,
	"amb_top": Color("9690cc"), "amb_hor": Color("c49aaa"), "amb_ground": Color("907866"), "amb_e": 1.0,
	"fog": 0.5, "water": 0.86, "band": 0.9,
	"cloud_lit": Color("ffc6ae"), "cloud_shade": Color("998ac2"), "light": Color(1.0, 0.88, 0.82),
}
## Синие сумерки: солнце только что ушло, у горизонта догорает оранжевая полоса.
const BLUE := {
	"top": Color("2a3b8c"), "hor": Color("e08a70"), "hor_far": Color("5f5c9c"), "sun": Color("ff8a66"), "sun_e": 0.0,
	"amb_top": Color("6870b0"), "amb_hor": Color("8072a0"), "amb_ground": Color("524a5c"), "amb_e": 1.0,
	"fog": 0.4, "water": 0.68, "band": 0.6,
	"cloud_lit": Color("e4967f"), "cloud_shade": Color("51508e"), "light": Color(0.72, 0.66, 0.78),
}
## Поздние сумерки: небо уже ночное, только край у горизонта светлее.
const DUSK := {
	"top": Color("16255c"), "hor": Color("56508e"), "hor_far": Color("2e3c76"), "sun": Color("9fb4ff"), "sun_e": 0.0,
	"amb_top": Color("5260a0"), "amb_hor": Color("4e5288"), "amb_ground": Color("34344e"), "amb_e": 1.0,
	"fog": 0.38, "water": 0.54, "band": 0.18,
	"cloud_lit": Color("6e6cab"), "cloud_shade": Color("303672"), "light": Color(0.48, 0.5, 0.7),
}
## Ночь: уютная синяя, не чёрная и не серая.
const NIGHT := {
	"top": Color("0d1b42"), "hor": Color("29437a"), "hor_far": Color("223a6e"), "sun": Color("9fb4ff"), "sun_e": 0.0,
	"amb_top": Color("4a5c9e"), "amb_hor": Color("3f4e82"), "amb_ground": Color("2e324e"), "amb_e": 1.0,
	"fog": 0.36, "water": 0.42, "band": 0.0,
	"cloud_lit": Color("4c6098"), "cloud_shade": Color("24315e"), "light": Color(0.38, 0.44, 0.66),
}

## Дождь: всё темнее, холоднее и дымчатее (смешивается с текущим временем суток).
const RAIN := {
	"top": Color("7d8ea6"), "hor": Color("b5c0cc"), "hor_far": Color("aab6c4"), "sun": Color("dfe6ef"), "sun_e": 0.25,
	"amb_top": Color("8b93b0"), "amb_hor": Color("9298ad"), "amb_ground": Color("7c7a78"), "amb_e": 1.0,
	"fog": 0.7, "water": 0.8, "band": 0.0,
	"cloud_lit": Color("d9dfe8"), "cloud_shade": Color("8a94ab"), "light": Color(0.78, 0.8, 0.86),
}


## Мороз (Ледяной остров до оттепели): чистое бледно-голубое небо, холодное солнце, голубые тени.
const FROST := {
	"top": Color("6aa8e8"), "hor": Color("dcecf8"), "hor_far": Color("d4e6f6"), "sun": Color("fff6ea"), "sun_e": 0.68,
	"amb_top": Color("a8b8e0"), "amb_hor": Color("b8c4e0"), "amb_ground": Color("c8d0dc"), "amb_e": 1.0,
	"fog": 0.4, "water": 0.92, "band": 0.0,
	"cloud_lit": Color("ffffff"), "cloud_shade": Color("c8d4ee"), "light": Color(0.96, 0.98, 1.0),
}


static func mix(a: Dictionary, b: Dictionary, k: float) -> Dictionary:
	var out := {}
	for key in a:
		var va: Variant = a[key]
		var vb: Variant = b[key]
		if va is Color:
			out[key] = (va as Color).lerp(vb as Color, k)
		else:
			out[key] = lerpf(float(va), float(vb), k)
	return out


## Палитра на момент суток: elev — высота солнца (-1..1, 0 — солнце на горизонте),
## evening — вечер (true) или утро (false): закат золотой, рассвет розовый.
static func at_elevation(elev: float, evening := true) -> Dictionary:
	var keys: Array = [[-0.32, NIGHT], [-0.18, DUSK], [-0.07, BLUE], [0.0, SUNSET if evening else SUNRISE],
		[0.13, GOLDEN], [0.34, DAY]]
	if elev <= -0.32:
		return NIGHT
	if elev >= 0.34:
		return DAY
	for i in range(1, keys.size()):
		var hi: float = keys[i][0]
		if elev <= hi:
			var lo: float = keys[i - 1][0]
			return mix(keys[i - 1][1], keys[i][1], smoothstep(lo, hi, elev))
	return DAY
