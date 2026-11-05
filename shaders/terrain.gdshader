// Земля острова: рисованный узор вместо однотонной заливки.
// Песок — светлый, с пятнами, крапинкой и лёгкой рябью от ветра; мокрая кромка у воды и бирюзовое дно;
// трава — пятнами (солнечные проплешины, тёмные островки), камень — на крутых склонах, утоптанная земля в лагере.
// Все границы чёткие, как в 2D-рисунке, но сглажены на ширину пикселя (aastep) — без «лесенки» и мерцания.
// Цвета задаёт island.gd из Palette (одна палитра с травой и моделями).
shader_type spatial;
render_mode cull_back;

uniform sampler2D noise_tex : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D painted : filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 sand : source_color = vec4(0.98, 0.86, 0.55, 1.0);
uniform vec4 sand_dark : source_color = vec4(0.92, 0.76, 0.47, 1.0);
uniform vec4 sand_light : source_color = vec4(0.99, 0.91, 0.66, 1.0);
uniform vec4 wet_sand : source_color = vec4(0.85, 0.67, 0.41, 1.0);
uniform vec4 seabed : source_color = vec4(0.44, 0.78, 0.72, 1.0);
uniform vec4 grass : source_color = vec4(0.45, 0.66, 0.29, 1.0);
uniform vec4 grass_light : source_color = vec4(0.56, 0.74, 0.33, 1.0);
uniform vec4 grass_dark : source_color = vec4(0.35, 0.56, 0.25, 1.0);
uniform vec4 grass_warm : source_color = vec4(0.62, 0.73, 0.33, 1.0);
uniform vec4 rock : source_color = vec4(0.65, 0.62, 0.6, 1.0);
uniform vec4 rock_dark : source_color = vec4(0.53, 0.51, 0.49, 1.0);
uniform vec4 dirt : source_color = vec4(0.79, 0.64, 0.45, 1.0);
uniform vec4 dirt_dark : source_color = vec4(0.68, 0.53, 0.36, 1.0);
uniform vec3 camp_pos = vec3(0.0, -100.0, 0.0);
uniform float camp_radius = 5.5;

global uniform float g_rain;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float n(vec2 p) {
	return texture(noise_tex, p).r;
}

// ступенька с краем шириной в пиксель: граница чёткая, но без зубцов
float aastep(float edge, float x) {
	float w = max(fwidth(x), 1e-4) * 0.75;
	return smoothstep(edge - w, edge + w, x);
}

void fragment() {
	float h = world_pos.y;
	vec2 p = world_pos.xz;
	float big = n(p * 0.012);
	float mid = n(p * 0.05 + 3.1);
	float fine = n(p * 0.35 + 7.7);
	float edge_noise = (mid - 0.5) * 0.5;

	// песок: пятна, лёгкая рябь от ветра на светлых местах, мелкая крапинка
	vec3 col = sand.rgb;
	float dark_patch = aastep(0.62, mid);
	col = mix(col, sand_dark.rgb, dark_patch * 0.85);
	float ripple = sin(dot(p, vec2(0.55, 0.32)) * 3.2 + mid * 9.0);
	col = mix(col, sand_light.rgb, aastep(0.86, ripple) * (1.0 - dark_patch) * 0.6);
	col = mix(col, sand_dark.rgb * 0.93, aastep(0.8, fine) * 0.75);
	// мокрая полоса у воды и бирюзовое дно под водой
	col = mix(col, wet_sand.rgb, 1.0 - aastep(0.32 + edge_noise * 0.3, h));
	col = mix(col, seabed.rgb, 1.0 - aastep(-0.3, h));

	// трава с пятнами
	float g = aastep(1.05 + edge_noise, h);
	vec3 gcol = grass.rgb;
	gcol = mix(gcol, grass_warm.rgb, aastep(0.6, big + (mid - 0.5) * 0.35) * 0.75);
	gcol = mix(gcol, grass_dark.rgb, aastep(0.68, mid) * (1.0 - aastep(0.5, big)) * 0.8);
	gcol = mix(gcol, grass_light.rgb, aastep(0.84, fine) * 0.5);
	// кромка газона чуть темнее — как обводка
	float rim = g * (1.0 - aastep(1.2 + edge_noise, h));
	gcol = mix(gcol, grass_dark.rgb * 0.92, rim * 0.9);
	col = mix(col, gcol, g);

	// камень на склонах и вершине
	float slope = 1.0 - world_normal.y;
	float r = max(aastep(0.3 + edge_noise * 0.2, slope), aastep(10.5 + edge_noise * 3.0, h)) * aastep(0.6, h);
	vec3 rcol = mix(rock.rgb, rock_dark.rgb, aastep(0.55, mid));
	col = mix(col, rcol, r);

	// вытоптанная площадка лагеря
	float cd = length(world_pos.xz - camp_pos.xz) + (mid - 0.5) * 2.5;
	float camp = (1.0 - aastep(camp_radius, cd)) * aastep(0.9, h);
	vec3 dcol = mix(dirt.rgb, dirt_dark.rgb, aastep(0.6, fine) * 0.7);
	dcol = mix(dcol, dirt_dark.rgb * 0.92, aastep(camp_radius - 0.45, cd));
	col = mix(col, dcol, camp);

	// та же «кисть», что у моделей: земля и предметы нарисованы одной фактурой
	float pt = texture(painted, p * 0.16).r;
	col *= 1.0 + 0.06 * (aastep(0.6, pt) - (1.0 - aastep(0.36, pt)));
	// в дождь земля темнеет (камень — меньше)
	col *= 1.0 - g_rain * (0.2 - r * 0.08);
	ALBEDO = col;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	if (LIGHT_IS_DIRECTIONAL) {
		float sh = smoothstep(0.3, 0.7, ATTENUATION);
		float lit = smoothstep(0.0, 0.06, ndl) * sh;
		DIFFUSE_LIGHT += LIGHT_COLOR / PI * lit;
	} else {
		DIFFUSE_LIGHT += LIGHT_COLOR / PI * smoothstep(-0.2, 0.3, ndl) * ATTENUATION;
	}
}
