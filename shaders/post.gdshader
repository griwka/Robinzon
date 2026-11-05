// Постобработка (поверх 3D, под интерфейсом), один проход:
// 1) адаптивная резкость (как AMD CAS): усиливает мелкие детали, но почти не трогает уже резкие края —
//    поэтому вокруг контуров нет светлых ореолов и «лесенка» не усиливается;
// 2) цветокоррекция: тени чуть холоднее (сиреневые), света теплее, приглушённым цветам — немного сочности;
// 3) мягкая тёплая виньетка по углам — взгляд собирается к центру.
shader_type canvas_item;

uniform sampler2D screen : hint_screen_texture, filter_linear;
uniform float sharpness : hint_range(0.0, 1.0) = 0.5;  // 0 — без резкости
uniform vec3 shadow_tint = vec3(-0.018, -0.006, 0.03);
uniform vec3 highlight_tint = vec3(0.012, 0.008, -0.018);
uniform float vibrance = 0.18;
uniform float vignette = 0.22;

void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE;
	vec2 uv = SCREEN_UV;
	vec3 c = texture(screen, uv).rgb;
	if (sharpness > 0.001) {
		vec3 n = texture(screen, uv + vec2(0.0, -px.y)).rgb;
		vec3 s = texture(screen, uv + vec2(0.0, px.y)).rgb;
		vec3 e = texture(screen, uv + vec2(px.x, 0.0)).rgb;
		vec3 w = texture(screen, uv + vec2(-px.x, 0.0)).rgb;
		vec3 mn = min(c, min(min(n, s), min(e, w)));
		vec3 mx = max(c, max(max(n, s), max(e, w)));
		vec3 amp = sqrt(clamp(min(mn, 1.0 - mx) / max(mx, vec3(1e-4)), 0.0, 1.0));
		vec3 k = amp * (-1.0 / mix(8.0, 4.5, sharpness));
		c = clamp((c + (n + s + e + w) * k) / (1.0 + 4.0 * k), 0.0, 1.0);
	}
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c += shadow_tint * (1.0 - l) * (1.0 - l);
	c += highlight_tint * l * l;
	float sat = max(c.r, max(c.g, c.b)) - min(c.r, min(c.g, c.b));
	c = mix(vec3(l), c, 1.0 + vibrance * (1.0 - sat));
	vec2 q = uv - 0.5;
	q.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x * 0.62;
	float v = smoothstep(1.05, 0.45, length(q) * 1.35);
	c = mix(c * vec3(0.84, 0.8, 0.88), c, mix(1.0, v, clamp(vignette * 4.0, 0.0, 1.0)));
	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
