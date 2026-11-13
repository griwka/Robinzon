// Мультяшная вода: чёткие полосы цвета по глубине, белая кромка прибоя, бегущие к берегу волны-полоски,
// сетка солнечных бликов на мелководье (каустика) и искрящаяся дорожка от солнца (ночью — от луны).
// Все границы сглажены на ширину пикселя — полосы не дрожат и не рвутся «лесенкой».
shader_type spatial;
render_mode cull_disabled, depth_draw_always, shadows_disabled, unshaded;

uniform vec4 shallow_color : source_color = vec4(0.42, 0.93, 0.90, 1.0);
uniform vec4 mid_color : source_color = vec4(0.17, 0.74, 0.88, 1.0);
uniform vec4 deep_color : source_color = vec4(0.07, 0.50, 0.80, 1.0);
uniform vec4 foam_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform sampler2D height_map : filter_linear, repeat_disable;
uniform sampler2D noise_tex : filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 map_origin = vec2(-100.0, -100.0);
uniform float map_size = 200.0;
uniform float height_min = -6.0;
uniform float height_max = 14.0;
uniform float brightness = 1.0;   // меняется со временем суток
uniform vec3 tint = vec3(1.0);    // оттенок: ночью вода синее (WorldEnv)

global uniform vec3 g_sun_dir;
global uniform vec4 g_moon_dir;   // xyz — на луну, w — сила лунной дорожки
global uniform float g_rain;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float wave = sin(world_pos.x * 0.12 + TIME * 0.9) * 0.06 + cos(world_pos.z * 0.1 + TIME * 1.1) * 0.06;
	VERTEX.y += wave;
}

float aastep(float edge, float x) {
	float w = max(fwidth(x), 1e-4) * 0.75;
	return smoothstep(edge - w, edge + w, x);
}

void fragment() {
	vec2 uv = (world_pos.xz - map_origin) / map_size;
	float h = height_min;
	if (uv.x > 0.0 && uv.y > 0.0 && uv.x < 1.0 && uv.y < 1.0) {
		h = mix(height_min, height_max, texture(height_map, uv).r);
	}
	float depth = max(-h, 0.0);
	float wob = (texture(noise_tex, world_pos.xz * 0.03 + TIME * 0.01).r - 0.5) * 0.8;

	vec3 col = deep_color.rgb;
	col = mix(col, mid_color.rgb, 1.0 - aastep(3.2, depth + wob));
	col = mix(col, shallow_color.rgb, 1.0 - aastep(1.3, depth + wob * 0.6));

	// каустика: светлая сеточка там, где сходятся два бегущих узора шума (только на мелководье)
	float c1 = texture(noise_tex, world_pos.xz * 0.085 + TIME * vec2(0.012, 0.008)).r;
	float c2 = texture(noise_tex, world_pos.xz * 0.1 - TIME * vec2(0.009, 0.014) + 0.37).r;
	float caus = 1.0 - aastep(0.035, abs(c1 - c2));
	col = mix(col, vec3(0.86, 1.0, 0.96), caus * (1.0 - smoothstep(0.4, 1.6, depth)) * 0.35);

	// полоски волн, бегущие к берегу
	float shore = 1.0 - aastep(2.4, depth);
	float ph = fract(depth * 0.9 - TIME * 0.25 + wob * 0.4);
	float stripes = aastep(0.86, ph) * (1.0 - aastep(0.985, ph));
	// белая кромка прибоя
	float edge = 1.0 - aastep(0.22 + sin(TIME * 1.5 + world_pos.x * 0.4) * 0.06, depth);
	// блики-штрихи на глубокой воде
	float glint = aastep(0.8, texture(noise_tex, world_pos.xz * vec2(0.08, 0.25) + vec2(TIME * 0.02, 0.0)).r)
		* aastep(0.75, texture(noise_tex, world_pos.xz * 0.05 - TIME * 0.015).r);
	float foam = max(edge, stripes * shore * 0.85);
	col = mix(col, foam_color.rgb, clamp(foam + glint * 0.7, 0.0, 1.0));

	// солнечная дорожка: искры там, где отражение солнца попадает в глаз
	vec3 v = normalize(CAMERA_POSITION_WORLD - world_pos);
	vec3 r = reflect(-normalize(g_sun_dir), vec3(0.0, 1.0, 0.0));
	float sun_path = pow(max(dot(r, v), 1e-4), 60.0) * smoothstep(-0.05, 0.15, g_sun_dir.y);
	float sparkle = aastep(0.62, texture(noise_tex, world_pos.xz * 0.22 + TIME * vec2(0.03, -0.02)).r);
	col += vec3(1.0, 0.95, 0.85) * sun_path * sparkle * 2.5 * (1.0 - g_rain);
	// дорожка к низкому светилу: узкая по сторонам и длинная к горизонту (как от волн)
	vec2 vh = v.xz;
	float vhl = length(vh);
	vh = vhl > 1e-4 ? vh / vhl : vec2(0.0, 1.0);
	float low_sun = (1.0 - smoothstep(0.04, 0.32, g_sun_dir.y)) * smoothstep(-0.04, 0.03, g_sun_dir.y);
	vec2 sh = -g_sun_dir.xz;
	float shl = length(sh);
	if (low_sun > 0.001 && shl > 1e-4) {
		float az = 1.0 - dot(vh, sh / shl);
		float gold = exp(-az * 160.0) * low_sun;
		col += vec3(1.0, 0.72, 0.4) * gold * sparkle * 1.6 * (1.0 - g_rain);
	}
	vec2 mh = -g_moon_dir.xz;
	float mhl = length(mh);
	if (g_moon_dir.w > 0.001 && mhl > 1e-4) {
		float az = 1.0 - dot(vh, mh / mhl);
		float silver = exp(-az * 220.0) * (0.35 + 0.65 * (1.0 - smoothstep(0.05, 0.55, g_moon_dir.y)));
		col += vec3(0.72, 0.82, 1.0) * silver * sparkle * 1.5 * g_moon_dir.w * (1.0 - g_rain);
	}

	ALBEDO = col * brightness * tint;
	ALPHA = mix(0.78, 0.96, aastep(1.3, depth));
	ALPHA = max(ALPHA, foam);
}
