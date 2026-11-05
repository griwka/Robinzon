// Крылья бабочек: яркий цвет без затенения, двусторонние.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
uniform vec4 color : source_color = vec4(1.0, 0.9, 0.3, 1.0);
uniform vec4 spot : source_color = vec4(0.1, 0.1, 0.1, 1.0);
void fragment() {
	float d = length(UV - vec2(0.6, 0.5));
	ALBEDO = mix(color.rgb, spot.rgb, step(d, 0.14));
	ALBEDO = mix(ALBEDO, color.rgb * 0.55, step(0.47, max(abs(UV.x - 0.5), abs(UV.y - 0.5))));
}
