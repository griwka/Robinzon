// Стена шторма вокруг Ока: кружащиеся тучи на внутренней стороне огромного цилиндра.
// Два слоя шума едут вокруг с разной скоростью, внизу — пена у воды, вверху — мягкий край.
// Вспышки молний — uniform flash (их задаёт eye_storm.gd). fade — растворение (финал «Открытое море»).
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never;

uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform vec4 dark : source_color = vec4(0.17, 0.2, 0.29, 1.0);
uniform vec4 light : source_color = vec4(0.55, 0.6, 0.72, 1.0);
uniform vec4 glow : source_color = vec4(0.85, 0.9, 1.0, 1.0);
uniform float flash = 0.0;
uniform float fade = 1.0;
uniform float speed = 0.004;

// модель стены — цилиндр радиусом 1 и высотой 1 (масштаб задаёт игра): координаты по углу и высоте
varying vec3 lp;

void vertex() {
	lp = VERTEX;
}

void fragment() {
	vec2 uv = vec2(atan(lp.z, lp.x) / 6.2831853 + 0.5, clamp(lp.y, 0.0, 1.0));
	float a = texture(noise_tex, vec2(uv.x * 3.0 + TIME * speed, uv.y * 1.2 + TIME * speed * 0.3)).r;
	float b = texture(noise_tex, vec2(uv.x * 7.0 - TIME * speed * 1.8, uv.y * 2.6 + 0.37)).r;
	float c = texture(noise_tex, vec2(uv.x * 13.0 + TIME * speed * 3.1, uv.y * 5.0 + 0.71)).r;
	float n = a * 0.55 + b * 0.3 + c * 0.15;
	// полосы туч закручены: по высоте сдвиг
	float band = smoothstep(0.35, 0.75, n + sin(uv.y * 9.0 + uv.x * 18.0 + TIME * 0.05) * 0.08);
	vec3 col = mix(dark.rgb, light.rgb, band);
	col = mix(col, glow.rgb, flash * smoothstep(0.45, 0.8, n) * 0.9);
	// низ темнее (пена и дождь у воды), верх светлее
	col *= mix(0.75, 1.05, smoothstep(0.0, 0.6, uv.y));
	ALBEDO = col;
	float edge = smoothstep(0.0, 0.05, uv.y) * smoothstep(1.0, 0.72, uv.y + (1.0 - n) * 0.12);
	ALPHA = clamp(edge * fade, 0.0, 1.0);
}
