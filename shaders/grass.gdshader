// Пучки травы (MultiMesh): основание цвета газона (пучок «вырастает» из земли, а не лежит тёмным пятном),
// к кончику — светлее, граница тонов чёткая. Качается на ветру порывами; вдали плавно уходит в землю
// (меньше мельтешения и меньше работы видеокарте). Цвета задаёт island.gd из Palette.
shader_type spatial;
render_mode cull_disabled;

uniform vec4 base_color : source_color = vec4(0.42, 0.62, 0.27, 1.0);
uniform vec4 tip_color : source_color = vec4(0.66, 0.8, 0.38, 1.0);
uniform float fade_from = 38.0;
uniform float fade_to = 55.0;

global uniform float g_wind;
global uniform float g_lamp;   // сила огней по времени суток (WorldEnv)
global uniform vec3 g_player_pos;

varying float v_h;

void vertex() {
	v_h = VERTEX.y;
	vec3 world = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float dist = length(world - CAMERA_POSITION_WORLD);
	float shrink = 1.0 - smoothstep(fade_from, fade_to, dist);
	VERTEX.y *= shrink;
	float gust = 0.6 + 0.4 * sin(TIME * 0.45 + world.x * 0.06 + world.z * 0.04);
	float sway = sin(TIME * 2.0 + world.x * 0.4 + world.z * 0.3) * 0.12 * VERTEX.y * g_wind * gust;
	VERTEX.x += sway;
	VERTEX.z += sway * 0.5;
	// трава приминается под ногами игрока
	vec3 away = world - g_player_pos;
	away.y = 0.0;
	float near = 1.0 - smoothstep(0.3, 0.9, length(away));
	vec2 push = normalize(away.xz + vec2(0.001)) * near * VERTEX.y * 0.9;
	VERTEX += inverse(mat3(MODEL_MATRIX)) * vec3(push.x, 0.0, push.y);
	VERTEX.y *= 1.0 - near * 0.45;
	NORMAL = vec3(0.0, 1.0, 0.0);
}

void fragment() {
	float t = clamp(v_h / 0.5, 0.0, 1.0);
	vec3 c = mix(base_color.rgb, tip_color.rgb, smoothstep(0.42, 0.5, t));
	ALBEDO = c * COLOR.rgb;
}

void light() {
	if (LIGHT_IS_DIRECTIONAL) {
		DIFFUSE_LIGHT += LIGHT_COLOR / PI * smoothstep(0.3, 0.7, ATTENUATION);
	} else {
		DIFFUSE_LIGHT += LIGHT_COLOR / PI * ATTENUATION * g_lamp;
	}
}
