// Подсветка предмета, с которым будет действие: тёплое мягкое свечение по контуру, чуть пульсирует.
// Накладывается поверх обычного материала (material_overlay), прибавляется к картинке.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled;

uniform vec4 glow : source_color = vec4(1.0, 0.9, 0.55, 1.0);
uniform float strength = 1.15;

void fragment() {
	float f = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = f * f;
	float pulse = 0.78 + 0.22 * sin(TIME * 4.0);
	ALBEDO = glow.rgb * (rim * strength + 0.12) * pulse;
}
