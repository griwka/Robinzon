// Мультяшная вода: чёткие полосы цвета по глубине (без размытия), белая кромка прибоя,
// бегущие к берегу волны-полоски и блики.
shader_type spatial;
render_mode cull_disabled, depth_draw_always, shadows_disabled, unshaded;

uniform vec4 shallow_color : source_color = vec4(0.42, 0.93, 0.90, 1.0);
uniform vec4 mid_color : source_color = vec4(0.17, 0.74, 0.88, 1.0);
uniform vec4 deep_color : source_color = vec4(0.07, 0.50, 0.80, 1.0);
uniform vec4 foam_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform sampler2D height_map : filter_linear, repeat_disable;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec2 map_origin = vec2(-100.0, -100.0);
uniform float map_size = 200.0;
uniform float height_min = -6.0;
uniform float height_max = 14.0;
uniform float brightness = 1.0;   // меняется со временем суток

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float wave = sin(world_pos.x * 0.12 + TIME * 0.9) * 0.06 + cos(world_pos.z * 0.1 + TIME * 1.1) * 0.06;
	VERTEX.y += wave;
}

void fragment() {
	vec2 uv = (world_pos.xz - map_origin) / map_size;
	float h = height_min;
	if (uv.x > 0.0 && uv.y > 0.0 && uv.x < 1.0 && uv.y < 1.0) {
		h = mix(height_min, height_max, texture(height_map, uv).r);
	}
	float depth = max(-h, 0.0);
	float wob = (texture(noise_tex, world_pos.xz * 0.03 + TIME * 0.01).r - 0.5) * 0.8;

	vec3 col = deep_color.rgb;
	col = mix(col, mid_color.rgb, step(depth + wob, 3.2));
	col = mix(col, shallow_color.rgb, step(depth + wob * 0.6, 1.3));

	// полоски волн, бегущие к берегу
	float shore = step(depth, 2.4);
	float stripes = step(0.86, fract(depth * 0.9 - TIME * 0.25 + wob * 0.4));
	// белая кромка прибоя
	float edge = step(depth, 0.22 + sin(TIME * 1.5 + world_pos.x * 0.4) * 0.06);
	// блики-штрихи на глубокой воде
	float glint = step(0.8, texture(noise_tex, world_pos.xz * vec2(0.08, 0.25) + vec2(TIME * 0.02, 0.0)).r)
		* step(0.75, texture(noise_tex, world_pos.xz * 0.05 - TIME * 0.015).r);
	float foam = max(edge, stripes * shore * 0.85);
	col = mix(col, foam_color.rgb, clamp(foam + glint * 0.7, 0.0, 1.0));

	ALBEDO = col * brightness;
	ALPHA = mix(0.78, 0.96, step(1.3, depth));
	ALPHA = max(ALPHA, foam);
}
