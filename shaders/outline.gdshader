// Контур "вывернутая оболочка" с постоянной толщиной в пикселях:
// чёткая обводка на любом расстоянии (вдали чуть тоньше), как в рисованной графике.
// Цвет — тёплый тёмно-коричневый; у одноцветных предметов слегка окрашен в их цвет (tint, base_tint):
// у зелёного — темно-зелёная, у дерева — тёмно-бурая. Так мягче и уютнее, чем чисто чёрная.
// Цвет вершин (COLOR) здесь НЕ читаем: у части сеток в моделях его нет, и на некоторых драйверах
// там оказывается мусор (NaN) — свечение раздувает такой пиксель в белое пятно.
shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;

uniform vec4 color : source_color = vec4(0.20, 0.11, 0.06, 1.0);
uniform vec4 base_tint : source_color = vec4(1.0);   // цвет предмета
uniform float tint = 0.0;      // 0 — чисто коричневый, 1 — тёмный оттенок самого предмета
uniform float width = 0.025;   // запасной вариант (в метрах), если толщина в пикселях выключена
uniform float pixels = 1.8;    // толщина контура в пикселях

varying vec3 v_col;

void vertex() {
	v_col = clamp(base_tint.rgb, 0.0, 1.0);
	vec4 clip = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	// у отдельных вершин моделей нормаль нулевой длины: normalize дал бы NaN и «горящий» пиксель
	vec3 nv = MODELVIEW_NORMAL_MATRIX * NORMAL;
	float nl = length(nv);
	vec3 n = nl > 1e-5 ? nv / nl : vec3(0.0, 0.0, 1.0);
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
	// тёмный оттенок предмета: та же «краска», но в несколько раз темнее и чуть насыщеннее
	vec3 own = v_col * sqrt(v_col) * 0.22;   // v^1.5 без pow: pow(0, 1.5) на части драйверов даёт NaN
	ALBEDO = mix(color.rgb, own, tint);
}
