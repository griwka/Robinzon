// Стилизованная вода: глубина берётся из карты высот острова (работает на любом рендерере),
// у берега — светлая бирюза и анимированные полосы пены.
shader_type spatial;
render_mode diffuse_toon, specular_toon, cull_disabled, depth_draw_always, shadows_disabled;

uniform vec4 shallow_color : source_color = vec4(0.30, 0.90, 0.85, 1.0);
uniform vec4 deep_color : source_color = vec4(0.05, 0.42, 0.72, 1.0);
uniform vec4 foam_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform sampler2D height_map : filter_linear, repeat_disable; // высоты острова
uniform vec2 map_origin = vec2(-100.0, -100.0);
uniform float map_size = 200.0;
uniform float height_min = -6.0;
uniform float height_max = 14.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float wave = sin(world_pos.x * 0.12 + TIME * 0.9) * 0.07 + cos(world_pos.z * 0.1 + TIME * 1.1) * 0.07;
	VERTEX.y += wave;
	world_pos.y += wave;
}

void fragment() {
	vec2 uv = (world_pos.xz - map_origin) / map_size;
	float h = height_min;
	if (uv.x > 0.0 && uv.y > 0.0 && uv.x < 1.0 && uv.y < 1.0) {
		h = mix(height_min, height_max, texture(height_map, uv).r);
	}
	float depth = clamp(-h, 0.0, 10.0);
	float t = smoothstep(0.0, 4.5, depth);
	vec3 col = mix(shallow_color.rgb, deep_color.rgb, t);

	// Полосы пены, бегущие к берегу
	float shore = smoothstep(2.2, 0.0, depth);
	float stripes = step(0.82, fract(depth * 1.3 - TIME * 0.35 + sin(world_pos.x * 0.3) * 0.08));
	float edge = smoothstep(0.35, 0.05, depth);
	float foam = max(edge, stripes * shore * 0.8);
	// Мелкие блики по всей воде
	float sparkle = step(0.985, sin(world_pos.x * 1.7 + TIME * 1.5) * sin(world_pos.z * 1.9 - TIME * 1.2));
	col = mix(col, foam_color.rgb, clamp(foam + sparkle * 0.6, 0.0, 1.0));

	ALBEDO = col;
	ROUGHNESS = 0.2;
	SPECULAR = 0.5;
	ALPHA = mix(0.72, 0.97, t);
	ALPHA = max(ALPHA, foam);
}
