class_name WorldEnv
extends Node3D
## Свет и атмосфера мира — всё, что отвечает за «картинку», в одном месте:
## солнце и луна, рисованное небо со звёздами (оно же заливает тени мягким светом), дымка вдали, свечение огня,
## мягкое затенение в углах (SSAO), постобработка (резкость, цветокоррекция, виньетка)
## и общие параметры шейдеров (направление солнца и луны, позиция игрока, ветер, дождь, сила огней).
## Цвета — из Palette по времени суток и погоде; качество эффектов — из меню настроек.
##
## Сутки идут непрерывно: солнце и луна движутся по настоящим дугам небесной сферы (широта ~32°,
## в полдень солнце на 58°), вместе с ними вращается звёздное небо (Полярная звезда стоит на месте).
## Главный свет с тенями один (Sun): днём это солнце, ночью — луна; передача происходит в сумерках,
## когда оба почти не светят, — без скачка. Фаза луны меняется день ото дня (цикл MOON_CYCLE суток).
##
## Сознательно выключено:
## - SSR (отражения в экранном пространстве): в мультяшном стиле нет зеркальных поверхностей, а вода
##   рисуется своим шейдером — SSR дал бы только шум и потерю кадров;
## - SDFGI / VoxelGI (глобальное освещение): тяжёлые, «протекают» светом на процедурном острове и спорят
##   с нарисованной палитрой теней. Мягкую заливку теней даёт небо, а контакт с землёй — SSAO.

const SKY_SHADER := preload("res://shaders/sky.gdshader")
const POST_SHADER := preload("res://shaders/post.gdshader")
const MAX_SUN_ELEV := 58.0   # солнце не встаёт в зенит — тени и объём есть даже в полдень
const NOON_AZ := -35.0       # откуда светит полуденное солнце (как и прежде — тени привычные)
const SUN_RA := 17.5         # где солнце среди звёзд (ч): в полночь на юге — Орион
const MOON_CYCLE := 10.0     # суток от новолуния до новолуния
const MOON_START := 0.46     # фаза в первый день (0.5 — полнолуние)
const MOON_E := 0.25         # сила лунного света в полнолуние
const MOON_COLOR := Color("8aa4ff")
const EVENING_STAR_RA := 20.6   # вечерняя звезда — чуть восточнее солнца: видна в вечерних сумерках
## постройки, в которых ночью горит тёплый огонёк: id -> [высота, сила, радиус]
const NIGHT_LAMPS := {"hut": [1.25, 1.5, 6.0], "tent": [0.55, 0.9, 4.0]}

var env: Environment
var sky_mat: ShaderMaterial
var sun: DirectionalLight3D   # главный свет: днём — солнце, ночью — луна
var post: ColorRect
var island: Island
var player: Node3D
var rain := 0.0              # 0..1 — задаёт погода
var flash := 0.0             # 0..1 — вспышка молнии (Грозовой остров)
var indoor := false          # игрок в бункере: ни неба, ни солнца — только лампы и фонарь
var pal: Dictionary = Palette.DAY
var to_sun := Vector3(0.3, 0.8, 0.5)    # направление на солнце (и под горизонтом)
var to_moon := Vector3(-0.3, 0.6, -0.7)
var moon_phase := MOON_START            # 0 — новолуние, 0.5 — полнолуние
var night_amt := 0.0                    # 0 — день, 1 — глубокая ночь
var _frost := -1.0
var _applied := ""
var _moon_fixed := -1.0                 # --moon=0..1 — фаза для скриншотов
var _sky_t := 0.0
var _lamps := {}                        # id постройки -> OmniLight3D
var _lamp_scan := 0.0
# оси небесной сферы над островом (считаются один раз)
var _q := Vector3.ZERO    # точка небесного экватора на юге
var _w := Vector3.ZERO    # запад
var _p := Vector3.ZERO    # северный полюс мира
# упрощённый рендерер (Compatibility, для старых ПК) считает заливку из неба ярче — приглушаем
var _compat := RenderingServer.get_current_rendering_method() == "gl_compatibility"


## Насколько сейчас ночь (0 — день, 1 — ночь) — по высоте солнца. По ней сменяется музыка.
static func night_amount(t: float) -> float:
	return 1.0 - smoothstep(-0.16, 0.02, cos((t - 0.5) * TAU))


func _ready() -> void:
	name = "WorldEnv"
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = SKY_SHADER
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL   # заливка теней из неба пересчитывается по кусочку за кадр
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	env.sky = sky
	# заливка теней — из неба: сверху сиреневато-голубая, снизу тёплая (отражённый от песка свет)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 1.0
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	# линейный тонмаппинг: цвета палитры выводятся как нарисованы; ярче белого — только огонь и солнце
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.tonemap_exposure = 0.7 if _compat else 0.92   # освещённый песок не упирается в белый: рисунок мазков виден и на солнце
	# дымка вдали: дальние острова и горизонт растворяются в цвете неба — появляется глубина
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_depth_begin = 30.0
	env.fog_depth_end = 360.0
	env.fog_depth_curve = 1.5
	env.fog_sky_affect = 0.0
	env.fog_sun_scatter = 0.12
	# свечение — только у того, что ярче белого: языки пламени, искры, солнце, луна, яркие звёзды
	env.glow_enabled = true
	env.glow_normalized = false
	env.glow_intensity = 0.85
	env.glow_strength = 1.0
	env.glow_bloom = 0.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.glow_hdr_threshold = 1.15
	env.glow_hdr_scale = 2.0
	env.glow_hdr_luminance_cap = 6.0
	var levels := [0.0, 0.7, 1.0, 0.75, 0.45, 0.0, 0.0]
	for i in levels.size():
		env.set_glow_level(i, levels[i])
	# мягкое затенение под предметами и в углах: камни, ящики, грядки «стоят» на земле
	env.ssao_enabled = true
	env.ssao_radius = 1.1
	env.ssao_intensity = 1.6
	env.ssao_power = 1.6
	env.ssao_detail = 0.45
	env.ssao_horizon = 0.06
	env.ssao_sharpness = 0.98
	env.ssao_light_affect = 0.15
	env.ssr_enabled = false
	env.sdfgi_enabled = false
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.04
	env.adjustment_saturation = 1.05
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 70.0
	sun.directional_shadow_split_1 = 0.22       # первая ступень — 15 м вокруг камеры, самые чёткие тени
	sun.directional_shadow_blend_splits = true  # без шва между ступенями
	sun.directional_shadow_fade_start = 0.85
	sun.shadow_bias = 0.1
	sun.shadow_normal_bias = 2.0
	sun.shadow_blur = 0.6                       # фильтр PCF + резкий порог в шейдере = чёткий, но гладкий край
	sun.light_specular = 0.6
	add_child(sun)

	# оси неба: полюс мира поднят над северным горизонтом на широту, экватор проходит через полуденное солнце
	var lat := deg_to_rad(90.0 - MAX_SUN_ELEV)
	var south := Vector3(sin(deg_to_rad(NOON_AZ)), 0.0, cos(deg_to_rad(NOON_AZ)))
	var east := Vector3.UP.cross(south)   # если смотреть на юг, восток слева — как в северном полушарии
	_w = -east
	_q = south * sin(lat) + Vector3.UP * cos(lat)
	_p = Vector3.UP * sin(lat) - south * cos(lat)
	var st := SkyStars.build(EVENING_STAR_RA)
	var dirs: PackedVector3Array = st["dirs"]
	var la: PackedVector3Array = st["la"]
	sky_mat.set_shader_parameter("cs_dir", dirs)
	sky_mat.set_shader_parameter("cs_col", st["cols"])
	sky_mat.set_shader_parameter("cs_count", dirs.size())
	sky_mat.set_shader_parameter("cl_a", la)
	sky_mat.set_shader_parameter("cl_b", st["lb"])
	sky_mat.set_shader_parameter("cl_n", st["ln"])
	sky_mat.set_shader_parameter("cl_count", la.size())
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--moon="):
			_moon_fixed = clampf(float(a.substr(7)), 0.0, 1.0)

	var layer := CanvasLayer.new()
	layer.layer = 1   # поверх 3D, под интерфейсом (HUD — слой 10)
	add_child(layer)
	post = ColorRect.new()
	post.name = "Post"
	post.set_anchors_preset(Control.PRESET_FULL_RECT)
	post.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pm := ShaderMaterial.new()
	pm.shader = POST_SHADER
	post.material = pm
	layer.add_child(post)
	update(0.0)


## Качество эффектов (меню): 0 — низкое, 1 — среднее, 2 — высокое.
func _apply_quality() -> void:
	var fx := int(Game.settings.get("effects", 2))
	var sh := int(Game.settings.get("shadows", 2))
	var key := "%d|%d" % [fx, sh]
	if key == _applied:
		return
	_applied = key
	env.glow_enabled = fx >= 1
	env.ssao_enabled = fx >= 1
	RenderingServer.environment_set_ssao_quality(
		RenderingServer.ENV_SSAO_QUALITY_MEDIUM if fx >= 2 else RenderingServer.ENV_SSAO_QUALITY_LOW,
		true, 0.5, 2, 50.0, 300.0)
	RenderingServer.directional_soft_shadow_filter_set_quality(
		[RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW, RenderingServer.SHADOW_QUALITY_SOFT_LOW,
		RenderingServer.SHADOW_QUALITY_SOFT_LOW][clampi(sh, 0, 2)])


## Направление на светило с часовым углом ha (0 — полдень, на юге) и склонением dec (рад).
func _celestial(ha: float, dec: float) -> Vector3:
	return (_q * cos(ha) + _w * sin(ha)) * cos(dec) + _p * sin(dec)


func update(delta: float) -> void:
	_apply_quality()
	if _frost < 0.0:
		_frost = 1.0 if Game.cold_active() else 0.0
	if indoor and player and player.global_position.y >= -8.0:
		_restore_outdoor()
	var t := Game.time_of_day
	var ha := (t - 0.5) * TAU          # часовой угол солнца
	var elev := cos(ha)                # высота солнца, приведённая к -1..1 (по ней — палитра)
	night_amt = night_amount(t)
	var p := Palette.at_elevation(elev, t > 0.5)
	if rain > 0.001:
		var wet := Palette.mix(Palette.RAIN, Palette.NIGHT, 1.0 - smoothstep(-0.2, 0.15, elev))
		p = Palette.mix(p, wet, rain * 0.85)
	if Game.storm > 0.0:
		# грозовая туча: темно, как вечером, — молнии на этом фоне видно издалека
		p = Palette.mix(p, Palette.NIGHT, 0.55 * Game.storm)
	# мороз: днём небо и тени холодно-голубые (ночью — обычная ночь)
	_frost = move_toward(_frost, 1.0 if Game.cold_active() else 0.0, delta / 6.0)
	if _frost > 0.001:
		p = Palette.mix(p, Palette.mix(Palette.FROST, p, 1.0 - clampf(elev * 4.0 + 0.4, 0.0, 1.0)), 0.5 * _frost)
	pal = p
	var clear := (1.0 - rain) * (1.0 - Game.storm * 0.8)   # ясность: в дождь и грозу звёзд и луны не видно

	# светила: солнце, луна (фаза — по дням) и вращение звёздного неба
	to_sun = _celestial(ha, 0.0)
	moon_phase = _moon_fixed if _moon_fixed >= 0.0 else fposmod(MOON_START + (float(Game.day - 1) + t) / MOON_CYCLE, 1.0)
	var elong := moon_phase * TAU                       # насколько луна отстала от солнца
	to_moon = _celestial(ha - elong, deg_to_rad(4.0) * sin(elong * 0.5 + 1.3))
	var illum := (1.0 - cos(elong)) * 0.5               # освещённая доля диска
	var lst := ha + SUN_RA / 24.0 * TAU                 # звёздное время: какая часть неба на юге
	var cel_a := _q * cos(lst) + _w * sin(lst)
	var cel_b := _q * sin(lst) - _w * cos(lst)

	# главный свет: солнце; в сумерках, когда оно уже не светит, его место занимает луна
	var key_dir: Vector3
	if to_sun.y > -0.07:
		key_dir = to_sun
		sun.light_color = p["sun"]
		sun.light_energy = float(p["sun_e"]) * smoothstep(-0.05, 0.06, to_sun.y)
		sun.light_specular = 0.6
	else:
		key_dir = to_moon
		var mk := (1.0 - smoothstep(-0.17, -0.07, to_sun.y)) * smoothstep(-0.01, 0.14, to_moon.y)
		sun.light_color = MOON_COLOR
		sun.light_energy = MOON_E * (0.3 + 0.7 * illum) * mk * clear
		sun.light_specular = 0.25
	var up := Vector3.UP if absf(key_dir.y) < 0.995 else Vector3.FORWARD
	sun.global_basis = Basis.looking_at(-key_dir, up)
	sun.visible = sun.light_energy > 0.004
	sun.shadow_opacity = lerpf(1.0, 0.8, night_amt)       # лунные тени мягче и прозрачнее
	sun.shadow_blur = lerpf(0.6, 1.4, night_amt)
	var moon_lit := illum * smoothstep(-0.02, 0.12, to_moon.y) * night_amt * clear   # лунная дорожка и ореол

	env.ambient_light_energy = float(p["amb_e"]) * (0.72 if _compat else 1.0) * (1.0 + 0.16 * moon_lit) + flash * 1.6
	env.fog_light_color = (p["hor"] as Color).lerp(p["hor_far"], 0.5)
	env.fog_density = p["fog"]
	env.fog_sun_scatter = 0.12 + 0.22 * float(p["band"])
	env.glow_intensity = lerpf(0.85, 1.25, night_amt)
	env.tonemap_exposure = (0.7 if _compat else 0.92) * lerpf(1.0, 1.06, night_amt)

	# небо: цвета и светила — каждый кадр (солнце и звёзды движутся плавно, без рывков)
	_sky_t += delta
	sky_mat.set_shader_parameter("top_color", p["top"])
	sky_mat.set_shader_parameter("horizon_color", p["hor"])
	sky_mat.set_shader_parameter("horizon_far", p["hor_far"])
	sky_mat.set_shader_parameter("ground_color", p["amb_ground"])
	sky_mat.set_shader_parameter("amb_top", p["amb_top"])
	sky_mat.set_shader_parameter("amb_horizon", p["amb_hor"])
	sky_mat.set_shader_parameter("amb_ground", p["amb_ground"])
	sky_mat.set_shader_parameter("sun_color", p["sun"])
	sky_mat.set_shader_parameter("sun_dir", to_sun)
	sky_mat.set_shader_parameter("moon_dir", to_moon)
	sky_mat.set_shader_parameter("sun_visible", (1.0 - rain) * (1.0 - Game.storm * 0.7))
	sky_mat.set_shader_parameter("night", (1.0 - smoothstep(-0.2, -0.02, elev)) * clear)
	sky_mat.set_shader_parameter("moon_visible", smoothstep(-0.03, 0.02, to_moon.y) * clear * (0.25 + 0.75 * smoothstep(0.0, 0.08, illum)))
	sky_mat.set_shader_parameter("horizon_glow", p["band"])
	sky_mat.set_shader_parameter("star_time", _sky_t)
	sky_mat.set_shader_parameter("cel_a", cel_a)
	sky_mat.set_shader_parameter("cel_b", cel_b)
	sky_mat.set_shader_parameter("cel_c", _p)
	if island and island.water_mat:
		island.water_mat.set_shader_parameter("brightness", p["water"])
		island.water_mat.set_shader_parameter("tint", Color(1, 1, 1).lerp(Color(0.66, 0.78, 1.0), night_amt))
	# общие параметры шейдеров
	RenderingServer.global_shader_parameter_set("g_sun_dir", to_sun)
	RenderingServer.global_shader_parameter_set("g_moon_dir", Vector4(to_moon.x, to_moon.y, to_moon.z, moon_lit))
	RenderingServer.global_shader_parameter_set("g_daylight", smoothstep(-0.12, 0.1, elev))
	# огни (костры, факелы, фонари): днём скромные, в сумерках и ночью — тёплые круги света
	var dark := maxf(night_amt, maxf(Game.storm * 0.7, rain * 0.4))
	if env.volumetric_fog_enabled:
		dark = maxf(dark, 0.55)
	RenderingServer.global_shader_parameter_set("g_lamp", 1.25 if indoor else lerpf(0.55, 1.4, dark))
	if player:
		# листва расступается только перед камерой героя; в меню (облёт острова) — нет
		var cam := get_viewport().get_camera_3d()
		var hero_cam: bool = cam != null and player.get("camera") == cam
		RenderingServer.global_shader_parameter_set("g_player_pos", player.global_position if hero_cam else Vector3(0, -1000, 0))
	var lt: Color = p["light"]
	RenderingServer.global_shader_parameter_set("g_light", Vector3(lt.r, lt.g, lt.b))
	var cl: Color = (p["cloud_lit"] as Color).srgb_to_linear()
	var cs: Color = (p["cloud_shade"] as Color).srgb_to_linear()
	RenderingServer.global_shader_parameter_set("g_cloud_lit", Vector3(cl.r, cl.g, cl.b))
	RenderingServer.global_shader_parameter_set("g_cloud_shade", Vector3(cs.r, cs.g, cs.b))
	RenderingServer.global_shader_parameter_set("g_wind", 1.0 + rain * 0.9)
	RenderingServer.global_shader_parameter_set("g_rain", rain)
	# постобработка
	var pm := post.material as ShaderMaterial
	var sharp := int(Game.settings.get("sharpen", 2))
	pm.set_shader_parameter("sharpness", [0.0, 0.35, 0.65][clampi(sharp, 0, 2)])
	pm.set_shader_parameter("vignette", lerpf(0.18, 0.3, night_amt))
	# в густом тумане (Туманный остров) ночная синева мягче — иначе всё сливается в одно синее пятно
	pm.set_shader_parameter("night", night_amt * (1.0 - rain * 0.5) * (0.45 if env.volumetric_fog_enabled else 1.0))
	pm.set_shader_parameter("golden", float(p["band"]) * (1.0 - rain))
	_update_lamps(delta, dark)
	_apply_indoor()


## Тёплый огонёк в хижинах и палатках: в сумерках загорается, к утру гаснет. Свет пробивается
## сквозь щели стен и окно — дом виден издалека.
func _update_lamps(delta: float, dark: float) -> void:
	_lamp_scan -= delta
	if _lamp_scan <= 0.0:
		_lamp_scan = 1.0
		for k in _lamps.keys():
			if not is_instance_valid(_lamps[k]):
				_lamps.erase(k)
		for id in NIGHT_LAMPS:
			for b in get_tree().get_nodes_in_group("station_" + id):
				var n := b as Node3D
				if n == null or _lamps.has(n.get_instance_id()):
					continue
				var spec: Array = NIGHT_LAMPS[id]
				var l := OmniLight3D.new()
				l.name = "NightLamp"
				l.light_color = Color("ffb662")
				l.omni_range = float(spec[2])
				l.omni_attenuation = 1.6
				l.light_specular = 0.1
				l.shadow_enabled = id == "hut"   # лучи сквозь щели стен
				l.position = Vector3(0, float(spec[0]), 0)
				l.set_meta("energy", float(spec[1]))
				n.add_child(l)
				_lamps[n.get_instance_id()] = l
	var on := smoothstep(0.35, 0.8, dark)
	for k in _lamps:
		var l: OmniLight3D = _lamps[k]
		if not is_instance_valid(l):
			continue
		var ph := float(int(k) % 97)
		l.light_energy = float(l.get_meta("energy")) * on * (0.93 + 0.07 * sin(_sky_t * 5.3 + ph) * sin(_sky_t * 3.1 + ph * 2.0))
		l.visible = l.light_energy > 0.01


## Под землёй (бункер Грозового острова): солнце и луна не светят, туман и небо не видны,
## заливка теней почти гаснет — видно только то, что освещают лампы и фонарь.
func _apply_indoor() -> void:
	indoor = player != null and player.global_position.y < -8.0
	if not indoor:
		return
	sun.visible = false
	env.ambient_light_energy = 0.1 + flash * 0.15
	env.fog_density = 0.0
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("0d0b0a")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("6a6a80")


func _restore_outdoor() -> void:
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
