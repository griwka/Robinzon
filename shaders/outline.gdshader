// Контур "вывернутая оболочка": рисует увеличенную копию модели изнанкой наружу.
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque;

uniform vec4 color : source_color = vec4(0.16, 0.1, 0.07, 1.0);
uniform float width = 0.025;

void vertex() {
	VERTEX += NORMAL * width;
}

void fragment() {
	ALBEDO = color.rgb;
}
