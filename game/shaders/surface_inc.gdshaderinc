// 表/里世界通用表面着色器（雾世界 -> 里世界 噪声剥落过渡）
uniform sampler2D tex_a : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D nor_a : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_b : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D nor_b : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D blood_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D peel_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D grime_tex : filter_linear_mipmap, repeat_enable;
uniform float scale_a = 0.5;
uniform float scale_b = 0.5;
uniform vec3 tint_a : source_color = vec3(1.0);
uniform vec3 tint_b : source_color = vec3(0.62, 0.48, 0.42);
uniform float rough_a = 1.0;
uniform float rough_b = 1.0;
uniform float metal_b = 0.0;
uniform float normal_depth = 1.0;
uniform float blood = 0.35;
uniform float grime = 0.35;
uniform float ow_mix = 0.0;
uniform bool box_map = false;
uniform bool opac_a_on = false;
uniform bool opac_b_on = false;
uniform float emission_a = 0.0;
varying vec3 v_wpos;
varying vec3 v_wnrm;

void vertex() {
	v_wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

vec2 surf_uv(vec2 uv) {
	if (box_map) {
		vec3 n = abs(v_wnrm);
		if (n.y > n.x && n.y > n.z) { return v_wpos.xz; }
		if (n.x > n.z) { return vec2(v_wpos.z, -v_wpos.y); }
		return vec2(v_wpos.x, -v_wpos.y);
	}
	return uv;
}

void fragment() {
	vec2 uv = surf_uv(UV);
	vec2 ua = uv * scale_a;
	vec4 ca = texture(tex_a, ua);
	vec3 alb = ca.rgb * tint_a;
	float rough = opac_a_on ? rough_a : ca.a * rough_a;
	vec3 nm = texture(nor_a, ua).rgb;
	float alpha = opac_a_on ? ca.a : 1.0;
	float g = texture(grime_tex, v_wpos.xz * 0.043 + vec2(v_wpos.y * 0.021, v_wpos.y * 0.033)).r;
	alb *= mix(1.0, 0.55 + 0.7 * g, grime);
	// 墙脚积灰
	alb *= mix(1.0, 0.75, grime * (1.0 - smoothstep(0.0, 0.6, v_wpos.y)) * (1.0 - abs(v_wnrm.y)));
	float met = 0.0;
	float edge = 0.0;
	float m = 0.0;
	if (ow_mix > 0.001) {
		float pn = texture(peel_tex, v_wpos.xz * 0.061 + vec2(v_wpos.y * 0.047, v_wpos.y * 0.029)).r;
		pn = pn * 0.8 + 0.2 * texture(peel_tex, v_wpos.zx * 0.23 + v_wpos.y * 0.11).r;
		float t = ow_mix * 1.3 - 0.15;
		m = smoothstep(pn - 0.03, pn + 0.03, t);
		float live = 1.0 - step(0.999, ow_mix);
		edge = smoothstep(0.05, 0.0, abs(t - pn)) * live;
		vec2 ub = uv * scale_b;
		vec4 cb = texture(tex_b, ub);
		vec3 albb = cb.rgb * tint_b;
		vec4 bl = texture(blood_tex, uv * 0.23 + vec2(0.31, 0.17));
		albb = mix(albb, bl.rgb, bl.a * blood);
		alb = mix(alb, albb, m);
		rough = mix(rough, (opac_b_on ? 0.55 : cb.a) * rough_b, m);
		nm = mix(nm, texture(nor_b, ub).rgb, m);
		met = metal_b * m;
		alpha = mix(alpha, opac_b_on ? cb.a : 1.0, m);
		alb = mix(alb, vec3(0.015, 0.01, 0.008), smoothstep(0.11, 0.02, abs(t - pn)) * 0.85 * live);
	}
	ALBEDO = alb;
	ROUGHNESS = clamp(rough, 0.04, 1.0);
	METALLIC = met;
	NORMAL_MAP = nm;
	NORMAL_MAP_DEPTH = normal_depth;
	EMISSION = vec3(1.0, 0.33, 0.06) * edge * 3.5 + alb * emission_a * (1.0 - m);
#ifdef CUTOUT
	ALPHA = alpha;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
#endif
}
