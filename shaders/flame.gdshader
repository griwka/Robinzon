// Язык пламени: яркая сердцевина (ярче 1 — её подхватывает свечение), оранжевые края,
// дрожит и колышется. Тени не отбрасывает, свет не принимает — он сам источник.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

uniform vec4 core : source_color = vec4(1.0, 0.93, 0.55, 1.0);
uniform vec4 edge : source_color = vec4(1.0, 0.42, 0.08, 1.0);
uniform float energy = 3.0;

void vertex() {
	float seed = dot(NODE_POSITION_WORLD, vec3(1.7, 0.0, 2.3));
	float up = max(VERTEX.y + 0.15, 0.0);
	float pulse = 1.0 + sin(TIME * 13.0 + seed) * 0.07 + sin(TIME * 7.3 + seed * 2.0) * 0.05;
	VERTEX.xz *= pulse;
	VERTEX.y *= 1.0 + sin(TIME * 9.0 + seed) * 0.06;
	VERTEX.x += sin(TIME * 8.0 + seed + VERTEX.y * 5.0) * 0.06 * up;
	VERTEX.z += cos(TIME * 6.5 + seed * 1.3 + VERTEX.y * 4.0) * 0.05 * up;
}

void fragment() {
	float f = clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0);
	vec3 c = mix(edge.rgb, core.rgb, smoothstep(0.3, 0.75, f));
	ALBEDO = c * energy;
}
