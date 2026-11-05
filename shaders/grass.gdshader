// Пучки травы (MultiMesh): тёмное основание -> светлый кончик, резкая граница цвета, качание на ветру.
shader_type spatial;
render_mode cull_disabled;

uniform vec4 base_color : source_color = vec4(0.26, 0.54, 0.18, 1.0);
uniform vec4 tip_color : source_color = vec4(0.58, 0.82, 0.32, 1.0);

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
	float t = clamp(v_h / 0.5, 0.0, 1.0);
	vec3 c = mix(base_color.rgb, tip_color.rgb, step(0.45, t));
	ALBEDO = c * COLOR.rgb;
}

void light() {
	if (LIGHT_IS_DIRECTIONAL) {
		DIFFUSE_LIGHT += LIGHT_COLOR / PI * smoothstep(0.35, 0.65, ATTENUATION);
	} else {
		DIFFUSE_LIGHT += LIGHT_COLOR / PI * ATTENUATION;
	}
}
