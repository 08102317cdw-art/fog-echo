shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;
uniform sampler2D colormap : source_color, filter_linear_mipmap;
uniform sampler2D grime_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D rust_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform float ow_mix = 0.0;
uniform float desat = 0.55;
varying vec3 v_wpos;
void vertex() { v_wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec3 c = texture(colormap, UV).rgb;
	float l = dot(c, vec3(0.3, 0.59, 0.11));
	c = mix(c, vec3(l), desat) * 0.8;
	float g = texture(grime_tex, v_wpos.xz * 0.37 + v_wpos.y * 0.21).r;
	float g2 = texture(grime_tex, v_wpos.xy * 0.9 + v_wpos.z * 0.5).r;
	c *= 0.55 + 0.6 * g;
	vec3 r = texture(rust_tex, v_wpos.xy * 0.5 + v_wpos.zy * 0.3).rgb;
	float rustm = smoothstep(0.55, 0.75, g2) * 0.5 + smoothstep(0.6, 0.0, v_wpos.y) * 0.3;
	c = mix(c, r * 0.8, clamp(rustm + ow_mix * 0.8, 0.0, 1.0));
	ALBEDO = c;
	ROUGHNESS = mix(0.35, 0.95, clamp(g * 0.6 + rustm + ow_mix * 0.5, 0.0, 1.0));
	METALLIC = 0.35 * (1.0 - rustm);
}
