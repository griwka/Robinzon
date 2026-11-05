// Общий мультяшный шейдер для всех моделей (toon.gdshader и toon_foliage.gdshader подключают этот файл).
// - чёткая граница света и тени (узкая, но сглаженная — без «лесенки»),
// - вторая светлая полоса на освещённой стороне (объём),
// - ободок по краю силуэта только там, куда светит солнце (ночью объекты не «светятся»),
// - маленький резкий блик, рисованная фактура мазками,
// - заливка теней даёт небо (ambient из неба): сверху голубоватая, снизу тёплая — форма читается и в тени.
// С #define FOLIAGE: листья видны с обеих сторон, светятся на просвет, а та листва,
// что закрывает игрока от камеры, «расступается» аккуратной точечной маской.
// Белая вспышка при ударе накладывается сверху (FX.flash, material_overlay) — отдельно от этого шейдера.

uniform vec4 albedo : source_color = vec4(1.0);
uniform bool use_vertex_color = false;
uniform float rim_amount : hint_range(0.0, 1.0) = 0.25;
uniform float gloss : hint_range(0.0, 1.0) = 0.15;
uniform float wind_strength = 0.0;   // > 0 — качается на ветру
uniform float near_fade = 0.0;       // > 0 — листва расступается у камеры и перед игроком
uniform sampler2D painted : repeat_enable, filter_linear_mipmap_anisotropic;  // «рисованная» фактура мазками
uniform float paint_amount = 0.08;   // сила фактуры (0 — гладко)
uniform float emission_energy = 0.0; // > 0 — светится сам (окна, угли)
// вспышка при ударе — не здесь, а через material_overlay (FX.flash): instance uniform ломается в MultiMesh

global uniform vec3 g_player_pos;
global uniform float g_wind;

varying vec3 v_color;
varying vec3 w_pos;
varying vec3 w_nrm;

void vertex() {
	v_color = use_vertex_color ? COLOR.rgb : vec3(1.0);
	if (wind_strength > 0.0) {
		vec3 world = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
		float h = max(VERTEX.y, 0.0);
		float gust = 0.65 + 0.35 * sin(TIME * 0.37 + world.x * 0.045 + world.z * 0.03);
		float k = wind_strength * h * g_wind * gust;
		VERTEX.x += sin(TIME * 1.6 + world.x * 0.3 + world.z * 0.2) * k * 0.04;
		VERTEX.z += cos(TIME * 1.3 + world.z * 0.3) * k * 0.03;
	}
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	w_nrm = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;   // нормируется во fragment (с защитой от нулевой длины)
}

// упорядоченный узор 4×4 — ровная «сеточка» вместо случайных точек
float bayer4(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	float m[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return (m[x + y * 4] + 0.5) / 16.0;
}

void fragment() {
#ifdef FOLIAGE
	// в проходе теней проекция ортогональная — там листву не прячем, иначе под ней исчезнет тень
	bool shadow_pass = PROJECTION_MATRIX[3][3] > 0.5;
	if (near_fade > 0.0 && !shadow_pass) {
		float fade = smoothstep(0.5, 1.8, length(VERTEX));
		vec3 pv = (VIEW_MATRIX * vec4(g_player_pos + vec3(0.0, 0.9, 0.0), 1.0)).xyz;
		// игрок перед камерой и не дальше 60 м (в меню камера облетает остров — там это правило не нужно)
		if (pv.z < -0.5 && pv.z > -60.0 && VERTEX.z > pv.z + 0.9) {   // лист ближе к камере, чем игрок
			// 1) «окошко» вокруг игрока
			vec2 d = VERTEX.xy / -VERTEX.z - pv.xy / -pv.z;
			fade = min(fade, smoothstep(0.085, 0.16, length(d)));
			// 2) листва в ближней к камере части пути до игрока уходит совсем — не закрывает полэкрана
			float dp = -pv.z;
			fade = min(fade, smoothstep(dp * 0.36, dp * 0.52, -VERTEX.z));
		}
		if (fade < 0.999 && bayer4(FRAGCOORD.xy) >= fade) {
			discard;
		}
	}
#endif
	// защита от вырожденных нормалей (нулевой длины) у отдельных вершин моделей: без неё такой пиксель
	// даёт NaN, а свечение раздувает его в белое пятно
	if (!(dot(NORMAL, NORMAL) > 0.25)) {
		NORMAL = vec3(0.0, 0.0, 1.0);
	}
	float nl = length(w_nrm);
	vec3 wn = nl > 1e-4 ? w_nrm / nl : vec3(0.0, 1.0, 0.0);
	vec3 vc = v_color;
	if (!(vc.r >= 0.0 && vc.g >= 0.0 && vc.b >= 0.0 && vc.r <= 4.0 && vc.g <= 4.0 && vc.b <= 4.0)) {
		vc = vec3(1.0);   // у сетки нет цвета вершин и пришёл мусор — лучше белый, чем «горящий» пиксель
	}
	ALBEDO = albedo.rgb * vc;
	if (paint_amount > 0.0) {
		// трипланарная фактура: крупные мазки (резкие ступени тона) + мелкая крапинка
		vec3 bl = wn * wn;
		bl *= bl;   // |n|^4 без pow
		bl /= max(bl.x + bl.y + bl.z, 1e-4);
		float s = 0.55;
		vec3 a = texture(painted, w_pos.zy * s).rgb * bl.x + texture(painted, w_pos.xz * s).rgb * bl.y + texture(painted, w_pos.xy * s).rgb * bl.z;
		float tone = 1.0 + paint_amount * (step(0.6, a.r) * 0.8 - step(a.r, 0.36) * 0.9 + step(0.8, a.g) * 0.5);
		ALBEDO *= tone;
	}
	EMISSION = ALBEDO * emission_energy;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	if (LIGHT_IS_DIRECTIONAL) {
		float sh = smoothstep(0.3, 0.7, ATTENUATION);
		float lit = smoothstep(0.0, 0.045, ndl) * sh;
		float top = smoothstep(0.55, 0.6, ndl) * sh;     // вторая полоса — объём
		DIFFUSE_LIGHT += LIGHT_COLOR / PI * (lit * 0.84 + top * 0.16);
#ifdef FOLIAGE
		// листья на просвет: солнце за кроной — тёплое свечение теневой стороны
		float bv = clamp(dot(-VIEW, LIGHT), 0.0, 1.0);
		float back = bv * bv * bv * (1.0 - smoothstep(0.0, 0.045, ndl));
		DIFFUSE_LIGHT += LIGHT_COLOR / PI * back * 0.4 * sh;
#endif
		// ободок: светлая кромка силуэта там, куда падает свет
		float fres = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
		float rim = smoothstep(0.66, 0.74, fres) * smoothstep(-0.15, 0.25, ndl) * sh;
		DIFFUSE_LIGHT += LIGHT_COLOR / PI * rim * rim_amount * 0.7;
		vec3 hv = VIEW + LIGHT;
		vec3 h = dot(hv, hv) > 1e-6 ? normalize(hv) : NORMAL;
		float spec = smoothstep(0.955, 0.965, dot(NORMAL, h)) * lit;
		SPECULAR_LIGHT += LIGHT_COLOR / PI * spec * gloss * 2.0;
	} else {
		// костры и факелы: мягкий тёплый круг, свет немного «заворачивает» за край
		float lit = smoothstep(-0.25, 0.3, ndl) * ATTENUATION;
		DIFFUSE_LIGHT += LIGHT_COLOR / PI * lit;
	}
}
