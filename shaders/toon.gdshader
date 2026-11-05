// Мультяшный шейдер в стиле "рисованной" графики:
// - чёткая граница света и тени (без размытого градиента),
// - вторая светлая полоса на освещённой стороне (объём),
// - маленький резкий блик и ободок по краю,
// - тени окрашены в тёплый фиолетовый (задаётся в окружении), а не просто серые.
shader_type spatial;
render_mode cull_back;

uniform vec4 albedo : source_color = vec4(1.0);
uniform bool use_vertex_color = false;
uniform float rim_amount : hint_range(0.0, 1.0) = 0.25;
uniform float gloss : hint_range(0.0, 1.0) = 0.15;
uniform float wind_strength = 0.0;   // > 0 — качается на ветру
uniform float near_fade = 0.0;       // > 0 — растворяется возле камеры (листва)

varying vec3 v_color;

void vertex() {
	v_color = use_vertex_color ? COLOR.rgb : vec3(1.0);
	if (wind_strength > 0.0) {
		vec3 world = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
		float h = max(VERTEX.y, 0.0);
		VERTEX.x += sin(TIME * 1.6 + world.x * 0.3 + world.z * 0.2) * wind_strength * h * 0.04;
		VERTEX.z += cos(TIME * 1.3 + world.z * 0.3) * wind_strength * h * 0.03;
	}
}

void fragment() {
	if (near_fade > 0.0) {
		float fade = smoothstep(2.0, 5.0, length(VERTEX));
		float dither = fract(dot(floor(FRAGCOORD.xy), vec2(0.5, 0.25)) * 2.0);
		if (fade < 1.0 && dither > fade) {
			discard;
		}
	}
	ALBEDO = albedo.rgb * v_color;
	// ободок: светлая линия по краю силуэта на освещённой стороне
	float fres = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	EMISSION = ALBEDO * step(0.72, fres) * rim_amount * 0.35;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	if (LIGHT_IS_DIRECTIONAL) {
		float sh = smoothstep(0.35, 0.65, ATTENUATION);
		float lit = smoothstep(0.0, 0.03, ndl) * sh;
		float top = smoothstep(0.55, 0.58, ndl) * sh;     // вторая полоса — объём
		DIFFUSE_LIGHT += LIGHT_COLOR / PI * (lit * 0.82 + top * 0.18);
		vec3 h = normalize(VIEW + LIGHT);
		float spec = smoothstep(0.955, 0.965, dot(NORMAL, h)) * lit;
		SPECULAR_LIGHT += LIGHT_COLOR / PI * spec * gloss * 2.0;
	} else {
		// костры и факелы: мягкий тёплый круг
		float lit = smoothstep(0.0, 0.15, ndl) * ATTENUATION;
		DIFFUSE_LIGHT += LIGHT_COLOR / PI * lit;
	}
}
