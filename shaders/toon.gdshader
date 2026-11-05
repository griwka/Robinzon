// Мультяшный шейдер: жёсткая граница света/тени + мягкий ободок (rim).
// Используется для всех объектов мира. Цвет задаётся uniform-ом или цветом вершин.
shader_type spatial;
render_mode diffuse_toon, specular_toon;

uniform vec4 albedo : source_color = vec4(1.0);
uniform bool use_vertex_color = false;
uniform float rim_amount : hint_range(0.0, 1.0) = 0.35;
uniform float specular_amount : hint_range(0.0, 1.0) = 0.1;
uniform float wind_strength = 0.0; // > 0 — объект качается на ветру (листья)

varying vec3 v_color;

void vertex() {
	v_color = use_vertex_color ? COLOR.rgb : vec3(1.0);
	if (wind_strength > 0.0) {
		vec3 world = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
		float h = max(VERTEX.y, 0.0);
		float sway = sin(TIME * 1.6 + world.x * 0.3 + world.z * 0.2);
		VERTEX.x += sway * wind_strength * h * 0.04;
		VERTEX.z += cos(TIME * 1.3 + world.z * 0.3) * wind_strength * h * 0.03;
	}
}

void fragment() {
	// листья рядом с камерой растворяются "сеточкой", чтобы не закрывать обзор
	if (wind_strength > 0.5) {
		float d = length(VERTEX);
		float fade = smoothstep(2.0, 5.0, d);
		float dither = fract(dot(floor(FRAGCOORD.xy), vec2(0.5, 0.25)) * 2.0);
		if (fade < 1.0 && dither > fade) {
			discard;
		}
	}
	ALBEDO = albedo.rgb * v_color;
	ROUGHNESS = 0.85;
	SPECULAR = specular_amount;
	RIM = rim_amount;
	RIM_TINT = 0.6;
}
