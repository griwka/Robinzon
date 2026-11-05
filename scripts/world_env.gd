class_name WorldEnv
extends Node3D
## Свет и атмосфера мира — всё, что отвечает за «картинку», в одном месте:
## солнце и луна, рисованное небо (оно же заливает тени мягким светом), дымка вдали, свечение огня,
## мягкое затенение в углах (SSAO), постобработка (резкость, цветокоррекция, виньетка)
## и общие параметры шейдеров (направление солнца, позиция игрока, ветер, дождь).
## Цвета — из Palette по времени суток и погоде; качество эффектов — из меню настроек.
##
## Сознательно выключено:
## - SSR (отражения в экранном пространстве): в мультяшном стиле нет зеркальных поверхностей, а вода
##   рисуется своим шейдером — SSR дал бы только шум и потерю кадров;
## - SDFGI / VoxelGI (глобальное освещение): тяжёлые, «протекают» светом на процедурном острове и спорят
##   с нарисованной палитрой теней. Мягкую заливку теней даёт небо, а контакт с землёй — SSAO.

const SKY_SHADER := preload("res://shaders/sky.gdshader")
const POST_SHADER := preload("res://shaders/post.gdshader")
const MAX_SUN_ELEV := 58.0   # солнце не встаёт в зенит — тени и объём есть даже в полдень

var env: Environment
var sky_mat: ShaderMaterial
var sun: DirectionalLight3D
var moon: DirectionalLight3D
var post: ColorRect
var island: Island
var player: Node3D
var rain := 0.0              # 0..1 — задаёт погода
var flash := 0.0             # 0..1 — вспышка молнии (Грозовой остров)
var indoor := false          # игрок в бункере: ни неба, ни солнца — только лампы и фонарь
var pal: Dictionary = Palette.DAY
var _sky_push := 0.0
var _applied := ""
# упрощённый рендерер (Compatibility, для старых ПК) считает заливку из неба ярче — приглушаем
var _compat := RenderingServer.get_current_rendering_method() == "gl_compatibility"


func _ready() -> void:
	name = "WorldEnv"
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = SKY_SHADER
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL   # небо меняется медленно — пересчёт по кусочку за кадр
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
	# свечение — только у того, что ярче белого: языки пламени, искры, солнце, угольки
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
	moon = DirectionalLight3D.new()
	moon.name = "Moon"
	moon.light_color = Color("9fb4ff")
	moon.light_energy = 0.0
	moon.light_specular = 0.2
	add_child(moon)

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


func update(delta: float) -> void:
	_apply_quality()
	if indoor and player and player.global_position.y >= -8.0:
		_restore_outdoor()
	var t := Game.time_of_day
	var elev := sin((t - 0.25) * TAU)
	var p := Palette.at_elevation(elev)
	if rain > 0.001:
		var wet := Palette.mix(Palette.RAIN, Palette.NIGHT, 1.0 - smoothstep(-0.2, 0.15, elev))
		p = Palette.mix(p, wet, rain * 0.85)
	if Game.storm > 0.0:
		# грозовая туча: темно, как вечером, — молнии на этом фоне видно издалека
		p = Palette.mix(p, Palette.NIGHT, 0.55 * Game.storm)
	pal = p
	# солнце идёт с востока на запад по дуге не выше MAX_SUN_ELEV; луна — с другой стороны неба
	var el := asin(clampf(elev, -1.0, 1.0)) * MAX_SUN_ELEV / 90.0
	var day_k := clampf((t - 0.2) / 0.6, 0.0, 1.0)
	var az := deg_to_rad(lerpf(-110.0, 40.0, day_k))
	sun.rotation = Vector3(-el, az, 0.0)
	var night_k := clampf((t - 0.75) / 0.5 if t >= 0.75 else (t + 0.25) / 0.5, 0.0, 1.0)
	var mel := asin(clampf(-elev, -1.0, 1.0)) * 50.0 / 90.0
	moon.rotation = Vector3(-mel, deg_to_rad(lerpf(120.0, 260.0, night_k)), 0.0)
	sun.light_color = p["sun"]
	sun.light_energy = p["sun_e"] if el > -0.02 else 0.0
	sun.visible = sun.light_energy > 0.01
	sun.shadow_opacity = clampf(elev * 9.0 + 0.15, 0.0, 1.0)   # длинные тени держатся до самого горизонта
	moon.light_energy = clampf(-elev * 1.3, 0.0, 0.3) * (1.0 - rain * 0.6)
	moon.visible = moon.light_energy > 0.01
	env.ambient_light_energy = p["amb_e"] * (0.72 if _compat else 1.0) + flash * 1.6
	env.fog_light_color = p["hor"]
	env.fog_density = p["fog"]
	env.glow_intensity = lerpf(0.85, 1.2, clampf(-elev * 3.0, 0.0, 1.0))
	var to_sun := sun.global_transform.basis.z
	var to_moon := moon.global_transform.basis.z
	# небо пересчитывается не каждый кадр: оно меняется медленно, а пересчёт заливки теней не бесплатный
	_sky_push -= delta
	if _sky_push <= 0.0:
		_sky_push = 0.2
		sky_mat.set_shader_parameter("top_color", p["top"])
		sky_mat.set_shader_parameter("horizon_color", p["hor"])
		sky_mat.set_shader_parameter("ground_color", p["amb_ground"])
		sky_mat.set_shader_parameter("amb_top", p["amb_top"])
		sky_mat.set_shader_parameter("amb_horizon", p["amb_hor"])
		sky_mat.set_shader_parameter("amb_ground", p["amb_ground"])
		sky_mat.set_shader_parameter("sun_color", p["sun"])
		sky_mat.set_shader_parameter("sun_dir", to_sun)
		sky_mat.set_shader_parameter("moon_dir", to_moon)
		sky_mat.set_shader_parameter("sun_visible", clampf(el * 8.0 + 0.3, 0.0, 1.0) * (1.0 - rain))
		sky_mat.set_shader_parameter("night", clampf(-elev * 4.0, 0.0, 1.0) * (1.0 - rain))
		sky_mat.set_shader_parameter("horizon_glow", p["band"])
	if island and island.water_mat:
		island.water_mat.set_shader_parameter("brightness", p["water"])
	# общие параметры шейдеров
	RenderingServer.global_shader_parameter_set("g_sun_dir", to_sun if el > -0.03 else to_moon)
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
	pm.set_shader_parameter("vignette", lerpf(0.18, 0.28, clampf(-elev * 3.0, 0.0, 1.0)))
	_apply_indoor()


## Под землёй (бункер Грозового острова): солнце и луна не светят, туман и небо не видны,
## заливка теней почти гаснет — видно только то, что освещают лампы и фонарь.
func _apply_indoor() -> void:
	indoor = player != null and player.global_position.y < -8.0
	if not indoor:
		return
	sun.visible = false
	moon.visible = false
	env.ambient_light_energy = 0.1 + flash * 0.15
	env.fog_density = 0.0
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("0d0b0a")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("6a6a80")


func _restore_outdoor() -> void:
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
