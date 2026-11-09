shader_type spatial;
render_mode unshaded, cull_disabled;
// 室内假窗：雾天为灰白色冷光，里世界为暗红色
uniform float ow_mix = 0.0;
uniform vec3 c0 : source_color = vec3(0.74, 0.77, 0.8);
uniform vec3 c1 : source_color = vec3(0.2, 0.035, 0.02);
uniform float strength = 1.0;
uniform float bars = 1.0;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;

void fragment() {
	vec2 uv = UV;
	float g = 0.72 + 0.38 * (1.0 - uv.y);
	float n = texture(noise_tex, uv * vec2(1.3, 0.9) + vec2(TIME * 0.006, 0.0)).r;
	vec3 c = mix(c0, c1, ow_mix) * g * (0.86 + 0.28 * n) * strength;
	// 十字窗棂
	float fr = max(step(abs(uv.x - 0.5), 0.016), step(abs(uv.y - 0.45), 0.016)) * bars;
	c = mix(c, vec3(0.015), fr);
	ALBEDO = c;
}
