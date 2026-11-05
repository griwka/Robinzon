// Контур "вывернутая оболочка": тёмно-коричневая обводка, как у рисованных персонажей.
shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;

uniform vec4 color : source_color = vec4(0.20, 0.11, 0.06, 1.0);
uniform float width = 0.025;

void vertex() {
	VERTEX += NORMAL * width;
}

void fragment() {
	ALBEDO = color.rgb;
}
