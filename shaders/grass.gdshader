// Трава (MultiMesh): цвет от основания к кончику, качание на ветру.
shader_type spatial;
render_mode diffuse_toon, specular_disabled, cull_disabled;

uniform vec4 base_color : source_color = vec4(0.22, 0.55, 0.18, 1.0);
uniform vec4 tip_color : source_color = vec4(0.62, 0.86, 0.32, 1.0);

varying float v_h;

void vertex() {
	v_h = VERTEX.y;
	vec3 world = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float sway = sin(TIME * 2.0 + world.x * 0.4 + world.z * 0.3) * 0.12 * VERTEX.y;
	VERTEX.x += sway;
	VERTEX.z += sway * 0.5;
	NORMAL = vec3(0.0, 1.0, 0.0);
}

void fragment() {
	ALBEDO = mix(base_color.rgb, tip_color.rgb, clamp(v_h / 0.5, 0.0, 1.0)) * COLOR.rgb;
	ROUGHNESS = 1.0;
}
