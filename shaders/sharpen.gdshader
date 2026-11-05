// Постобработка: лёгкое повышение резкости (unsharp mask) и чуть больше локального контраста.
// Убирает «мыльность» от сглаживания и тонких текстур; интерфейс рисуется поверх и не затрагивается.
shader_type canvas_item;

uniform sampler2D screen : hint_screen_texture, filter_linear;
uniform float strength = 0.45;

void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE;
	vec3 c = texture(screen, SCREEN_UV).rgb;
	vec3 blur = (texture(screen, SCREEN_UV + vec2(px.x, 0.0)).rgb + texture(screen, SCREEN_UV - vec2(px.x, 0.0)).rgb
		+ texture(screen, SCREEN_UV + vec2(0.0, px.y)).rgb + texture(screen, SCREEN_UV - vec2(0.0, px.y)).rgb) * 0.25;
	COLOR = vec4(clamp(c + (c - blur) * strength * 2.0, 0.0, 1.0), 1.0);
}
