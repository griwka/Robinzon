// Контур "вывернутая оболочка" с постоянной толщиной в пикселях:
// чёткая тёмно-коричневая обводка на любом расстоянии (вдали чуть тоньше), как в рисованной графике.
shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;

uniform vec4 color : source_color = vec4(0.20, 0.11, 0.06, 1.0);
uniform float width = 0.025;   // запасной вариант (в метрах), если толщина в пикселях выключена
uniform float pixels = 1.8;    // толщина контура в пикселях

void vertex() {
	vec4 clip = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	vec3 n = normalize(MODELVIEW_NORMAL_MATRIX * NORMAL);
	vec2 dir = (PROJECTION_MATRIX * vec4(n, 0.0)).xy;
	float len = length(dir);
	if (len > 1e-5 && pixels > 0.0) {
		dir /= len;
		float px = pixels * clamp(28.0 / max(clip.w, 0.1), 0.55, 1.0);
		clip.xy += dir * px * 2.0 / VIEWPORT_SIZE * clip.w;
	}
	POSITION = clip;
}

void fragment() {
	ALBEDO = color.rgb;
}
