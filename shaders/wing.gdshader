// Крылья бабочек: яркий цвет без затенения, двусторонние. Ночью темнеют вместе с миром (g_light).
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
uniform vec4 color : source_color = vec4(1.0, 0.9, 0.3, 1.0);
uniform vec4 spot : source_color = vec4(0.1, 0.1, 0.1, 1.0);
global uniform vec3 g_light;
void fragment() {
	float d = length(UV - vec2(0.6, 0.5));
	float w = fwidth(d) * 0.75;
	ALBEDO = mix(color.rgb, spot.rgb, 1.0 - smoothstep(0.14 - w, 0.14 + w, d));
	float e = max(abs(UV.x - 0.5), abs(UV.y - 0.5));
	float we = fwidth(e) * 0.75;
	ALBEDO = mix(ALBEDO, color.rgb * 0.55, smoothstep(0.47 - we, 0.47 + we, e));
	ALBEDO *= g_light;
}
