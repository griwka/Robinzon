// Земля острова: рисованный узор вместо однотонной заливки.
// Песок — светлый с крапинками, мокрая кромка у воды, трава — двухтонные пятна,
// камень — на крутых склонах. Все границы резкие, как в 2D-рисунке.
shader_type spatial;
render_mode cull_back;

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec4 sand : source_color = vec4(0.98, 0.86, 0.55, 1.0);
uniform vec4 sand_dark : source_color = vec4(0.90, 0.74, 0.43, 1.0);
uniform vec4 wet_sand : source_color = vec4(0.86, 0.69, 0.42, 1.0);
uniform vec4 grass : source_color = vec4(0.40, 0.70, 0.24, 1.0);
uniform vec4 grass_light : source_color = vec4(0.50, 0.78, 0.28, 1.0);
uniform vec4 grass_dark : source_color = vec4(0.29, 0.56, 0.20, 1.0);
uniform vec4 rock : source_color = vec4(0.62, 0.60, 0.58, 1.0);
uniform vec4 rock_dark : source_color = vec4(0.50, 0.48, 0.47, 1.0);
uniform vec4 dirt : source_color = vec4(0.73, 0.60, 0.41, 1.0);
uniform vec4 dirt_dark : source_color = vec4(0.64, 0.51, 0.35, 1.0);
uniform vec3 camp_pos = vec3(0.0, -100.0, 0.0);
uniform float camp_radius = 5.5;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float n(vec2 p) {
	return texture(noise_tex, p).r;
}

void fragment() {
	float h = world_pos.y;
	vec2 p = world_pos.xz;
	float big = n(p * 0.012);
	float mid = n(p * 0.05 + 3.1);
	float fine = n(p * 0.35 + 7.7);
	float edge_noise = (mid - 0.5) * 0.5;

	// песок с крапинками
	vec3 col = sand.rgb;
	col = mix(col, sand_dark.rgb, step(0.62, mid));
	col = mix(col, sand_dark.rgb * 0.92, step(0.78, fine));
	// мокрая полоса у воды
	col = mix(col, wet_sand.rgb, step(h, 0.32 + edge_noise * 0.3));

	// трава с пятнами
	float g = step(1.05 + edge_noise, h);
	vec3 gcol = grass.rgb;
	gcol = mix(gcol, grass_light.rgb, step(0.58, big + (mid - 0.5) * 0.3));
	gcol = mix(gcol, grass_dark.rgb, step(0.66, mid) * step(big, 0.5));
	gcol = mix(gcol, grass_light.rgb * 1.05, step(0.82, fine) * 0.6);
	// кромка травы чуть темнее — "обводка" газона
	float rim = step(1.05 + edge_noise, h) - step(1.22 + edge_noise, h);
	gcol = mix(gcol, grass_dark.rgb * 0.9, rim);
	col = mix(col, gcol, g);

	// камень на склонах и вершине
	float slope = 1.0 - world_normal.y;
	float r = max(step(0.30 + edge_noise * 0.2, slope), step(10.5 + edge_noise * 3.0, h)) * step(0.6, h);
	vec3 rcol = mix(rock.rgb, rock_dark.rgb, step(0.55, mid));
	col = mix(col, rcol, r);

	// вытоптанная площадка лагеря
	float cd = length(world_pos.xz - camp_pos.xz) + (mid - 0.5) * 2.5;
	float camp = step(cd, camp_radius) * step(0.9, h);
	vec3 dcol = mix(dirt.rgb, dirt_dark.rgb, step(0.6, fine));
	dcol = mix(dcol, dirt_dark.rgb * 0.9, step(camp_radius - 0.45, cd));
	col = mix(col, dcol, camp);

	ALBEDO = col;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	if (LIGHT_IS_DIRECTIONAL) {
		float sh = smoothstep(0.35, 0.65, ATTENUATION);
		float lit = smoothstep(0.0, 0.05, ndl) * sh;
		DIFFUSE_LIGHT += LIGHT_COLOR / PI * lit;
	} else {
		DIFFUSE_LIGHT += LIGHT_COLOR / PI * smoothstep(0.0, 0.2, ndl) * ATTENUATION;
	}
}
