// Облака: пухлые «ватные» комки в два тона. Освещённая сторона — светлая, теневая — цвета неба
// (на закате облака розовеют, ночью — синие). Свет не считается: цвета задаёт main.gd через g_cloud_*.
shader_type spatial;
render_mode unshaded, shadows_disabled;

global uniform vec3 g_sun_dir;
global uniform vec3 g_cloud_lit;
global uniform vec3 g_cloud_shade;

varying vec3 wn;

void vertex() {
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = normalize(wn);
	float k = smoothstep(-0.05, 0.12, dot(n, normalize(g_sun_dir)) * 0.6 + n.y * 0.55);
	vec3 c = mix(g_cloud_shade, g_cloud_lit, k);
	float fres = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	c = mix(c, g_cloud_lit, smoothstep(0.72, 0.8, fres) * 0.6);
	ALBEDO = c;
}
