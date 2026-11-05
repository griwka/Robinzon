// Лава: тёмная застывшая корка с горящими трещинами, под ней медленно течёт жар.
// Ярче 1 — её подхватывает свечение экрана. Тени не отбрасывает и свет не принимает: сама светится.
// Пятна корки и трещины — из шумовой текстуры, сдвигаются со временем (flow — куда течёт).
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec4 crust : source_color = vec4(0.23, 0.12, 0.09, 1.0);
uniform vec4 hot : source_color = vec4(1.0, 0.42, 0.08, 1.0);
uniform vec4 core : source_color = vec4(1.0, 0.85, 0.35, 1.0);
uniform float energy = 2.6;
uniform vec2 flow = vec2(0.03, 0.01);

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float aastep(float edge, float x) {
	float w = max(fwidth(x), 1e-4) * 0.75;
	return smoothstep(edge - w, edge + w, x);
}

void fragment() {
	vec2 p = wpos.xz;
	float a = texture(noise_tex, p * 0.09 + flow * TIME).r;
	float b = texture(noise_tex, p * 0.21 - flow.yx * TIME * 1.7 + 3.1).r;
	float m = a * 0.65 + b * 0.35;
	// корка — островками, между ними горит; на стыках — яркие прожилки
	float crust_k = aastep(0.52, m);
	float vein = 1.0 - aastep(0.035, abs(m - 0.52));
	float pulse = 0.85 + 0.15 * sin(TIME * 1.6 + a * 9.0);
	vec3 glow = mix(hot.rgb, core.rgb, aastep(0.62, b)) * energy * pulse;
	vec3 c = mix(glow, crust.rgb, crust_k);
	c = mix(c, core.rgb * energy * 1.2, vein * crust_k * 0.8);
	ALBEDO = c;
}
