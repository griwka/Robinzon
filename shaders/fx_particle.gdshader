// Частицы-«комочки»: дым, пыль, пар, брызги. Всегда смотрят в камеру, круглые, с мягким краем в 2 тона
// (как нарисованные), цвет и прозрачность — из частиц (COLOR). Ночью сами темнеют вместе с миром (g_light),
// а светящиеся (glow > 0) — наоборот, яркие: искры, угольки, светлячки.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_mix;

uniform float glow = 0.0;          // 0 — обычная частица, > 0 — светится (множитель яркости)
uniform float softness = 0.25;     // ширина мягкого края
uniform float stretch = 1.0;       // > 1 — вытянутая по скорости черта (дождь, искры)

global uniform vec3 g_light;

varying vec4 v_col;

vec3 to_linear(vec3 c) {
	return mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, step(c, vec3(0.04045)));
}

void vertex() {
	v_col = clamp(COLOR, vec4(0.0), vec4(1.0));
	// разворот к камере с сохранением размера частицы
	float s = length(MODEL_MATRIX[0].xyz);
	mat4 bb = mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	vec3 v = VERTEX * s;
	v.y *= stretch;
	MODELVIEW_MATRIX = VIEW_MATRIX * bb;
	VERTEX = v;
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	float r = length(UV - 0.5) * 2.0;
	float body = 1.0 - smoothstep(1.0 - softness, 1.0, r);
	// светлое «ядро» сверху-слева — объём без освещения
	float hi = 1.0 - smoothstep(0.35, 0.55, length(UV - vec2(0.38, 0.36)) * 2.0);
	vec3 c = to_linear(v_col.rgb) * (1.0 + hi * 0.18);
	if (glow > 0.0) {
		c *= glow;
	} else {
		c *= g_light;
	}
	ALBEDO = c;
	ALPHA = clamp(body * v_col.a, 0.0, 1.0);
}
