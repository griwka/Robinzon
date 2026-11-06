// Луч маяка: светящийся полупрозрачный столб, ярче к середине (по взгляду) и мягче к концам.
// Прибавляется к картинке (blend_add), поэтому не темнит небо и тучи за собой.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, shadows_disabled, depth_draw_never;

uniform vec4 color : source_color = vec4(1.0, 0.85, 0.5, 1.0);
uniform float energy = 1.0;
uniform float fade = 1.0;

void fragment() {
	float f = clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0);
	float core = f * f;
	float ends = smoothstep(0.0, 0.12, UV.y) * smoothstep(1.0, 0.88, UV.y);
	float shimmer = 0.85 + 0.15 * sin(TIME * 2.0 + UV.y * 40.0);
	ALBEDO = color.rgb * energy * core * ends * shimmer * fade;
}
