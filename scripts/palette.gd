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
## top/hor — видимое небо; amb_* — заливка теней (сверху, у горизонта, снизу — отражённый от земли свет);
## sun — цвет и sun_e сила солнца; fog — плотность дымки вдали; water — яркость воды;
## band — тёплая полоса у горизонта; cloud_* — облака; light — множитель для дыма, пыли и брызг.
const DAY := {
	"top": Color("3f8fe6"), "hor": Color("bfe5f6"), "sun": Color("fff0d6"), "sun_e": 0.72,
	"amb_top": Color("9f9bd2"), "amb_hor": Color("a9a3c6"), "amb_ground": Color("ad946c"), "amb_e": 1.0,
	"fog": 0.32, "water": 1.0, "band": 0.0,
	"cloud_lit": Color("ffffff"), "cloud_shade": Color("bcc7ec"), "light": Color(1.0, 1.0, 1.0),
}
const SUNSET := {
	"top": Color("4b5db2"), "hor": Color("ffb37c"), "sun": Color("ffb47e"), "sun_e": 0.6,
	"amb_top": Color("8c84c6"), "amb_hor": Color("ad94a8"), "amb_ground": Color("8b735f"), "amb_e": 1.0,
	"fog": 0.42, "water": 0.86, "band": 1.0,
	"cloud_lit": Color("ffcfa3"), "cloud_shade": Color("8f7fbb"), "light": Color(1.0, 0.88, 0.8),
}
const NIGHT := {
	"top": Color("0b1736"), "hor": Color("27426f"), "sun": Color("9fb4ff"), "sun_e": 0.0,
	"amb_top": Color("44528c"), "amb_hor": Color("3a4672"), "amb_ground": Color("2a2c3e"), "amb_e": 1.0,
	"fog": 0.38, "water": 0.46, "band": 0.0,
	"cloud_lit": Color("5d70a8"), "cloud_shade": Color("2c3a68"), "light": Color(0.36, 0.42, 0.62),
}

## Дождь: всё темнее, холоднее и дымчатее (смешивается с текущим временем суток).
const RAIN := {
	"top": Color("7d8ea6"), "hor": Color("b5c0cc"), "sun": Color("dfe6ef"), "sun_e": 0.25,
	"amb_top": Color("8b93b0"), "amb_hor": Color("9298ad"), "amb_ground": Color("7c7a78"), "amb_e": 1.0,
	"fog": 0.7, "water": 0.8, "band": 0.0,
	"cloud_lit": Color("d9dfe8"), "cloud_shade": Color("8a94ab"), "light": Color(0.78, 0.8, 0.86),
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


## Палитра на момент суток: elev — высота солнца (-1..1).
static func at_elevation(elev: float) -> Dictionary:
	if elev > 0.25:
		return DAY
	if elev > 0.0:
		return mix(SUNSET, DAY, smoothstep(0.0, 0.25, elev))
	if elev > -0.2:
		return mix(NIGHT, SUNSET, smoothstep(-0.2, 0.0, elev))
	return NIGHT
