// Рисованное небо: плавный переход от горизонта к зениту, ореол и диск солнца, закатная полоса,
// розовый «пояс» напротив солнца в сумерках, ночью — звёзды (тысячи, разной яркости и цвета, мерцают),
// настоящие созвездия, Млечный Путь и луна с фазами и морями.
// Звёзды и Млечный Путь заданы на «небесной сфере» и вращаются вместе с ней вокруг полюса (Полярная звезда
// стоит на месте): cel_a/cel_b/cel_c — перевод направления взгляда в небесные координаты, их считает WorldEnv.
// Это небо ещё и подсвечивает тени (ambient из неба): для этой подсветки (AT_CUBEMAP_PASS) рисуется только
// гладкий градиент — без дисков и звёзд. Цвета и положение светил задаёт WorldEnv по времени суток.
// Без NaN: дробные степени не берём, все нормировки — с проверкой длины.
shader_type sky;

uniform vec3 top_color : source_color = vec3(0.24, 0.56, 0.91);
uniform vec3 horizon_color : source_color = vec3(0.75, 0.89, 0.96);   // горизонт со стороны солнца
uniform vec3 horizon_far : source_color = vec3(0.75, 0.89, 0.96);     // горизонт с другой стороны
uniform vec3 ground_color : source_color = vec3(0.79, 0.73, 0.54);   // «пол» неба (на экране его закрывает море)
// заливка теней — отдельная, мягче и сиреневее видимого неба: так тени уютные, а не серо-синие
uniform vec3 amb_top : source_color = vec3(0.62, 0.61, 0.82);
uniform vec3 amb_horizon : source_color = vec3(0.66, 0.64, 0.78);
uniform vec3 amb_ground : source_color = vec3(0.68, 0.58, 0.42);   // отражённый от песка и травы тёплый свет
uniform vec3 sun_color : source_color = vec3(1.0, 0.95, 0.84);
uniform vec3 sun_dir = vec3(0.3, 0.8, 0.5);    // направление НА солнце (настоящее, и под горизонтом тоже)
uniform vec3 moon_dir = vec3(-0.3, 0.6, -0.7);
uniform float sun_visible : hint_range(0.0, 1.0) = 1.0;
uniform float night : hint_range(0.0, 1.0) = 0.0;          // насколько видны звёзды
uniform float moon_visible : hint_range(0.0, 1.0) = 0.0;   // луна (днём — бледная)
uniform float horizon_glow : hint_range(0.0, 1.0) = 0.0;   // тёплая полоса у горизонта на закате
uniform float star_time = 0.0;                             // время для мерцания
uniform vec3 cel_a = vec3(1.0, 0.0, 0.0);
uniform vec3 cel_b = vec3(0.0, 0.0, 1.0);
uniform vec3 cel_c = vec3(0.0, 1.0, 0.0);
// яркие звёзды созвездий: направление на небесной сфере; цвет (rgb) и яркость (a)
uniform vec3 cs_dir[64];
uniform vec4 cs_col[64];
uniform int cs_count = 0;
// линии созвездий (еле заметные): концы и нормаль к плоскости дуги
uniform vec3 cl_a[48];
uniform vec3 cl_b[48];
uniform vec3 cl_n[48];
uniform int cl_count = 0;
uniform float lines = 0.028;

const float MOON_R = 0.036;   // угловой радиус луны (рад) — крупнее настоящей, по-сказочному

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

vec3 hash33(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.xxy + p.yxx) * p.zyx);
}

float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(mix(hash13(i), hash13(i + vec3(1, 0, 0)), f.x), mix(hash13(i + vec3(0, 1, 0)), hash13(i + vec3(1, 1, 0)), f.x), f.y);
	float b = mix(mix(hash13(i + vec3(0, 0, 1)), hash13(i + vec3(1, 0, 1)), f.x), mix(hash13(i + vec3(0, 1, 1)), hash13(i + vec3(1, 1, 1)), f.x), f.y);
	return mix(a, b, f.z);
}

float fbm(vec3 p) {
	float s = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		s += vnoise(p) * a;
		p = p * 2.03 + 7.1;
		a *= 0.5;
	}
	return s;
}

// слой звёзд: ячейки на сфере радиуса R, в части ячеек — звезда (вероятность prob)
vec3 star_layer(vec3 c, float R, float prob, float size, float bright, float vis) {
	vec3 sp = c * R;
	vec3 cell = floor(sp);
	vec3 h = hash33(cell);
	if (h.x > prob) {
		return vec3(0.0);
	}
	float b = h.y * h.y;           // много тусклых, мало ярких
	b = b * b * 0.85 + 0.15;
	// яркие звёзды загораются раньше, тусклые — уже в темноте
	float appear = smoothstep(0.75 - b * 0.6, 1.0 - b * 0.55, vis);
	vec3 pos = cell + 0.5 + (hash33(cell + 17.0) - 0.5) * 0.36;
	vec3 dv = sp - pos;
	float r2 = dot(dv, dv) / (size * size);
	float core = exp(-r2);
	float tw = 0.72 + 0.28 * sin(star_time * (1.7 + h.z * 3.1) + h.y * 40.0);
	vec3 tint = h.z < 0.25 ? vec3(0.78, 0.86, 1.0) : (h.z > 0.85 ? vec3(1.0, 0.86, 0.66) : vec3(1.0, 0.98, 0.94));
	return tint * core * b * bright * tw * appear;
}

void sky() {
	vec3 d = EYEDIR;
	float dl = length(d);
	d = dl > 1e-5 ? d / dl : vec3(0.0, 1.0, 0.0);
	float h = d.y;
	float sl = length(sun_dir);
	vec3 sd = sl > 1e-5 ? sun_dir / sl : vec3(0.0, 1.0, 0.0);
	float sun_dot = dot(d, sd);
	// со стороны солнца (по горизонтали): 1 — к солнцу, 0 — от него
	vec2 dh = d.xz;
	vec2 shz = sd.xz;
	float dhl = length(dh);
	float shl = length(shz);
	float side = (dhl > 1e-4 && shl > 1e-4) ? dot(dh / dhl, shz / shl) * 0.5 + 0.5 : 0.5;
	// небо: у горизонта светлее, к зениту — глубже; кривая подобрана «под рисунок»
	float hp = clamp(h, 0.0, 1.0);
	float t = smoothstep(0.0, 1.0, sqrt(hp) * (0.86 + 0.14 * hp));
	vec3 hor = mix(horizon_far, horizon_color, side * side * (3.0 - 2.0 * side));
	vec3 col = mix(hor, top_color, t);
	// ниже горизонта — «пол»: в подсветке это тёплый отражённый свет, на экране его закрывает море
	col = mix(col, ground_color, smoothstep(0.0, -0.22, h));
	// закатная полоса — со стороны солнца сильнее
	float band = exp(-abs(h) * 8.0) * horizon_glow * (0.3 + 0.7 * side);
	col += sun_color * band * 0.5;
	if (AT_CUBEMAP_PASS) {
		vec3 amb = mix(amb_horizon, amb_top, smoothstep(0.0, 0.8, h));
		amb = mix(amb, amb_ground, smoothstep(0.02, -0.35, h));
		COLOR = amb + sun_color * band * 0.25;
	} else {
		// розовый «пояс» над горизонтом напротив солнца — бывает в ясные сумерки
		float belt = smoothstep(0.02, 0.12, h) * (1.0 - smoothstep(0.14, 0.36, h)) * (1.0 - side) * horizon_glow;
		col = mix(col, vec3(0.98, 0.66, 0.72), belt * 0.28);
		// ореол и диск солнца (ярче 1 — его подхватывает свечение)
		float glow_wide = exp(-(1.0 - sun_dot) * 5.0) * (0.12 + horizon_glow * 0.35);
		float halo = exp(-(1.0 - sun_dot) * 18.0) * 0.26 + exp(-(1.0 - sun_dot) * 220.0) * 0.6;
		float above = smoothstep(-0.03, 0.01, h);
		col += sun_color * (glow_wide * smoothstep(-0.25, 0.0, sd.y) + halo * sun_visible * above);
		float disc = smoothstep(0.99875, 0.99915, sun_dot);
		col = mix(col, sun_color * 4.0, disc * sun_visible * above);

		// небесная сфера: направление взгляда в небесных координатах (вращается с ночью)
		vec3 c = vec3(dot(d, cel_a), dot(d, cel_b), dot(d, cel_c));
		float ml = length(moon_dir);
		vec3 md = ml > 1e-5 ? moon_dir / ml : vec3(0.0, 1.0, 0.0);
		float m_dot = dot(d, md);
		float moon_mask = 1.0;   // за диском луны звёзд не видно
		if (night > 0.003) {
			float airmass = smoothstep(-0.01, 0.3, h);   // у горизонта звёзды тонут в дымке
			float vis = night;
			vec3 stars = vec3(0.0);
			// Млечный Путь: полоса вдоль плоскости Галактики, клочковатая, с тёмной «трещиной»
			vec3 gnp = vec3(-0.8677, -0.1981, 0.4560);
			vec3 gc = vec3(-0.0549, -0.8735, -0.4838);
			float gl = dot(c, gnp);
			float core_k = clamp(dot(c, gc) * 0.5 + 0.5, 0.0, 1.0);
			float n1 = fbm(c * 5.0);
			float n2 = fbm(c * 13.0 + 3.0);
			float width = 0.2 + 0.1 * core_k;
			float mw = exp(-gl * gl / (width * width)) * (0.6 + 0.4 * n1) * (0.55 + 0.45 * core_k);
			float rift = exp(-(gl - 0.03) * (gl - 0.03) / 0.0016) * smoothstep(0.45, 0.65, n2) * 0.45;
			mw = max(mw - rift * mw, 0.0);
			vec3 mw_col = mix(vec3(0.52, 0.6, 0.95), vec3(0.95, 0.85, 0.78), core_k * core_k);
			stars += mw_col * mw * 0.12 * smoothstep(0.35, 0.9, vis);
			// россыпь звёзд: густой тусклый слой и редкий яркий (а в Млечном Пути — ещё гуще)
			stars += star_layer(c, 150.0, 0.028 + mw * 0.05, 0.2, 1.0, vis);
			stars += star_layer(c, 90.0, 0.012, 0.13, 1.5, vis);
			stars += star_layer(c, 48.0, 0.012, 0.075, 2.4, vis);
			// созвездия: яркие звёзды с мягким ореолом (свечение экрана добавит лучистости)
			float cl_vis = smoothstep(0.25, 0.85, vis);
			for (int i = 0; i < cs_count; i++) {
				vec3 dv = c - cs_dir[i];
				float r2 = dot(dv, dv);
				if (r2 < 0.0025) {
					vec4 sc = cs_col[i];
					float b = sc.a;
					float s = 0.0011 + 0.0007 * b;
					float pt = exp(-r2 / (s * s)) + exp(-r2 / (s * s * 9.0)) * 0.12 * b;
					float tw = sc.a > 3.0 ? 1.0 : 0.8 + 0.2 * sin(star_time * (2.3 + float(i) * 0.37) + float(i) * 5.1);
					float appear = smoothstep(0.8 - b * 0.18, 1.0 - b * 0.15, vis + 0.15);
					stars += sc.rgb * pt * b * tw * appear;
				}
			}
			// линии созвездий — чуть заметные, только глубокой ночью
			if (lines > 0.0) {
				float ln = 0.0;
				for (int i = 0; i < cl_count; i++) {
					float off = abs(dot(c, cl_n[i]));
					if (off < 0.003) {
						vec3 a = cl_a[i];
						vec3 b = cl_b[i];
						if (dot(cross(a, c), cl_n[i]) > 0.0 && dot(cross(c, b), cl_n[i]) > 0.0) {
							float gap = min(length(c - a), length(c - b));
							ln = max(ln, (1.0 - smoothstep(0.0003, 0.0011, off)) * smoothstep(0.007, 0.014, gap));
						}
					}
				}
				stars += vec3(0.62, 0.72, 1.0) * ln * lines * cl_vis;
			}
			// диск луны закрывает звёзды
			moon_mask = 1.0 - smoothstep(cos(MOON_R * 1.12), cos(MOON_R * 1.02), m_dot);
			col += stars * vis * airmass * moon_mask;
		}
		// луна: шар, освещённый настоящим солнцем, — фаза и наклон серпа получаются сами;
		// моря — тёмные пятна на своих местах, кратеры — мелкая крапинка, тёмная часть чуть видна (пепельный свет)
		float lit_frac = clamp(dot(-md, sd) * 0.5 + 0.5, 0.0, 1.0);   // 1 — полнолуние
		if (moon_visible > 0.003) {
			// мягкий ореол вокруг луны (сильнее в полнолуние) — без резкой границы
			float mh = exp(-(1.0 - m_dot) * 900.0) * 0.12 + exp(-(1.0 - m_dot) * 60.0) * 0.05;
			col += vec3(0.62, 0.72, 1.0) * mh * moon_visible * night * (0.15 + 0.85 * lit_frac * lit_frac);
		}
		if (moon_visible > 0.003 && m_dot > cos(MOON_R * 1.3)) {
			vec3 up = vec3(0.0, 1.0, 0.0);
			vec3 mu = cross(md, up);
			float lu = length(mu);
			mu = lu > 1e-4 ? mu / lu : vec3(1.0, 0.0, 0.0);
			vec3 mv = cross(mu, md);
			vec2 q = vec2(dot(d, mu), dot(d, mv)) / MOON_R;
			float r2 = dot(q, q);
			if (r2 < 1.08) {
				float z = sqrt(max(1.0 - r2, 0.0));
				vec3 n = mu * q.x + mv * q.y - md * z;
				float lam = dot(n, sd);
				float lit = smoothstep(-0.04, 0.12, lam);
				// моря (примерно как на настоящей Луне)
				float mare = 0.0;
				mare = max(mare, 1.0 - smoothstep(0.18, 0.32, length(q - vec2(-0.32, 0.42))));   // Дождей
				mare = max(mare, 1.0 - smoothstep(0.1, 0.2, length(q - vec2(0.14, 0.4))));      // Ясности
				mare = max(mare, 1.0 - smoothstep(0.12, 0.24, length(q - vec2(0.3, 0.12))));    // Спокойствия
				mare = max(mare, 1.0 - smoothstep(0.06, 0.13, length(q - vec2(0.66, 0.3))));    // Кризисов
				mare = max(mare, 1.0 - smoothstep(0.2, 0.38, length((q - vec2(-0.6, -0.02)) * vec2(1.0, 0.7))));   // Океан Бурь
				mare = max(mare, 1.0 - smoothstep(0.1, 0.2, length(q - vec2(-0.14, -0.38))));   // Облаков
				mare = max(mare, 1.0 - smoothstep(0.07, 0.15, length(q - vec2(0.52, -0.12))));  // Изобилия
				mare = max(mare, (1.0 - smoothstep(0.05, 0.1, abs(q.y - 0.72))) * (1.0 - smoothstep(0.3, 0.55, abs(q.x))));   // Холода
				vec3 mp = vec3(q * 3.0, z * 3.0);
				mare *= 0.55 + 0.45 * vnoise(mp * 2.0);
				float crat = vnoise(mp * 6.0) * 0.5 + vnoise(mp * 13.0) * 0.5;
				float tycho = 1.0 - smoothstep(0.02, 0.06, length(q - vec2(-0.12, -0.7)));
				float alb = 1.0 - mare * 0.5 - (crat - 0.5) * 0.22 + tycho * 0.2;
				vec3 lit_col = vec3(1.0, 0.95, 0.84) * alb * 1.22;
				vec3 dark_col = vec3(0.07, 0.09, 0.15) * (0.7 + 0.3 * alb);   // пепельный свет
				float edge = 1.0 - smoothstep(0.94, 1.06, r2);   // мягкий край диска
				// ночью диск непрозрачный (с пепельным светом), днём — только освещённая часть, бледная
				float day_k = 1.0 - night;
				vec3 mc = mix(dark_col, lit_col, lit);
				float a = edge * moon_visible * mix(1.0, lit * 0.55, day_k);
				col = mix(col, mix(mc, lit_col, day_k), a);
			}
		}
		COLOR = col;
	}
}
