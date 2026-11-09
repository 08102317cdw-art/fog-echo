shader_type spatial;
// 叠加在 Poly Haven 道具上的污渍 / 锈 / 血迹（乘法混合）
render_mode blend_mul, unshaded, cull_back, depth_draw_never, fog_disabled, shadows_disabled;
uniform sampler2D grime_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D blood_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform float amount = 0.5;
uniform float blood = 0.0;
uniform float ow_mix = 0.0;
varying vec3 wp;
varying vec3 wn;
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
float tri(sampler2D t, vec3 p, vec3 bl, float s) {
	return texture(t, p.zy * s).r * bl.x + texture(t, p.xz * s).r * bl.y + texture(t, p.xy * s).r * bl.z;
}
void fragment() {
	vec3 bl = pow(abs(wn), vec3(4.0));
	bl /= (bl.x + bl.y + bl.z + 1e-4);
	float g = tri(grime_tex, wp, bl, 0.7);
	float g2 = tri(grime_tex, wp + vec3(3.7, 1.3, 5.1), bl, 2.3);
	float a = amount * mix(1.0, 1.6, ow_mix);
	vec3 m = mix(vec3(1.0), vec3(0.62, 0.55, 0.47), clamp(g * a * 1.3, 0.0, 1.0));
	m *= mix(vec3(1.0), vec3(0.8, 0.72, 0.64), clamp(g2 * a, 0.0, 1.0));
	// 里世界：锈色与血迹
	float b = tri(blood_tex, wp * 0.5 + vec3(1.3, 0.0, 2.1), bl, 0.9);
	float bm = smoothstep(0.45, 0.7, b) * (blood + ow_mix * 0.6);
	m *= mix(vec3(1.0), vec3(0.42, 0.09, 0.06), clamp(bm, 0.0, 0.85));
	m *= mix(vec3(1.0), vec3(0.78, 0.6, 0.5), ow_mix * 0.6);
	// 远处淡出，避免雾中出现黑色剪影
	float d = length(VERTEX);
	m = mix(m, vec3(1.0), smoothstep(10.0, 22.0, d));
	ALBEDO = m;
}
