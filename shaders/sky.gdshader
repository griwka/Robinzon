// Рисованное небо: плавный переход от горизонта к зениту, мягкий ореол и диск солнца, луна и звёзды ночью.
// Это небо ещё и подсвечивает тени (ambient из неба): сверху голубоватым, снизу тёплым «отражённым» светом
// от песка и травы. Для этой подсветки (AT_CUBEMAP_PASS) рисуется только гладкий градиент — без диска и звёзд.
// Цвета меняет main.gd по времени суток.
shader_type sky;

uniform vec3 top_color : source_color = vec3(0.24, 0.56, 0.91);
uniform vec3 horizon_color : source_color = vec3(0.75, 0.89, 0.96);
uniform vec3 ground_color : source_color = vec3(0.79, 0.73, 0.54);   // «пол» неба (на экране его закрывает море)
// заливка теней — отдельная, мягче и сиреневее видимого неба: так тени уютные, а не серо-синие
uniform vec3 amb_top : source_color = vec3(0.62, 0.61, 0.82);
uniform vec3 amb_horizon : source_color = vec3(0.66, 0.64, 0.78);
uniform vec3 amb_ground : source_color = vec3(0.68, 0.58, 0.42);   // отражённый от песка и травы тёплый свет
uniform vec3 sun_color : source_color = vec3(1.0, 0.95, 0.84);
uniform vec3 sun_dir = vec3(0.3, 0.8, 0.5);    // направление НА солнце
uniform vec3 moon_dir = vec3(-0.3, 0.6, -0.7);
uniform float sun_visible : hint_range(0.0, 1.0) = 1.0;
uniform float night : hint_range(0.0, 1.0) = 0.0;
uniform float horizon_glow : hint_range(0.0, 1.0) = 0.0;   // тёплая полоса у горизонта на закате

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float h = d.y;
	// небо: у горизонта светлее, к зениту — глубже; кривая подобрана «под рисунок»
	float t = smoothstep(0.0, 1.0, pow(clamp(h, 1e-4, 1.0), 0.55));
	vec3 col = mix(horizon_color, top_color, t);
	// ниже горизонта — «пол»: в подсветке это тёплый отражённый свет, на экране его закрывает море
	col = mix(col, ground_color, smoothstep(0.0, -0.22, h));
	vec3 sd = normalize(sun_dir);
	float sun_dot = dot(d, sd);
	// закатная полоса — со стороны солнца сильнее
	float band = exp(-abs(h) * 9.0) * horizon_glow * (0.45 + 0.55 * clamp(sun_dot * 0.5 + 0.5, 0.0, 1.0));
	col += sun_color * band * 0.55;
	if (AT_CUBEMAP_PASS) {
		vec3 amb = mix(amb_horizon, amb_top, smoothstep(0.0, 0.8, h));
		amb = mix(amb, amb_ground, smoothstep(0.02, -0.35, h));
		COLOR = amb + sun_color * band * 0.25;
	} else {
		// ореол и чёткий диск солнца (ярче 1 — его подхватывает свечение)
		float sdp = max(sun_dot, 1e-4);
		float halo = pow(sdp, 18.0) * 0.28 + pow(sdp, 220.0) * 0.6;
		col += sun_color * halo * sun_visible;
		float disc = smoothstep(0.9988, 0.99915, sun_dot);
		col = mix(col, sun_color * 4.0, disc * sun_visible * step(-0.02, h));
		// ночь: звёзды (чем выше, тем больше) и луна с мягким ореолом
		if (night > 0.01) {
			vec3 sp = d * 420.0;
			vec3 cell = floor(sp);
			float dot_r = length(fract(sp) - 0.5);
			float star = step(0.9972, hash13(cell)) * smoothstep(0.42, 0.12, dot_r) * smoothstep(0.02, 0.35, h);
			float tw = 0.6 + 0.4 * hash13(cell + 7.0);
			col += vec3(0.9, 0.93, 1.0) * star * tw * night * 1.4;
			vec3 md = normalize(moon_dir);
			float md_dot = dot(d, md);
			col += vec3(0.55, 0.65, 0.95) * pow(max(md_dot, 1e-4), 40.0) * 0.35 * night;
			float moon = smoothstep(0.99935, 0.99955, md_dot);
			// серп: вычитаем сдвинутый диск
			float bite = smoothstep(0.99935, 0.99955, dot(d, normalize(md + vec3(0.012, 0.008, 0.0))));
			col = mix(col, vec3(1.0, 0.97, 0.86) * 2.2, clamp(moon - bite * 0.85, 0.0, 1.0) * night);
		}
		COLOR = col;
	}
}
