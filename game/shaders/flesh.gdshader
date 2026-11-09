shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;
uniform sampler2D grime_tex : filter_linear_mipmap, repeat_enable;
uniform vec3 skin_a : source_color = vec3(0.34, 0.21, 0.18);
uniform vec3 skin_b : source_color = vec3(0.10, 0.04, 0.035);
uniform vec3 vein : source_color = vec3(0.42, 0.05, 0.04);
uniform float writhe = 1.0;
uniform float hurt = 0.0;
uniform float wet = 0.6;
varying vec3 lp;
void vertex() {
	lp = VERTEX;
	float w = sin(VERTEX.y * 9.0 + TIME * 6.0) * cos(VERTEX.x * 7.0 - TIME * 4.3) * 0.016;
	w += sin(VERTEX.y * 21.0 - TIME * 11.0 + VERTEX.z * 13.0) * 0.006;
	VERTEX += NORMAL * w * writhe;
}
void fragment() {
	float g = texture(grime_tex, lp.xy * 1.3 + lp.z * 0.7).r;
	float g2 = texture(grime_tex, lp.zy * 2.9 + 0.37).r;
	vec3 c = mix(skin_b, skin_a, smoothstep(0.2, 0.8, g));
	c = mix(c, vein, smoothstep(0.6, 0.78, g2) * 0.7);
	c = mix(c, vec3(0.5, 0.02, 0.01), hurt);
	ALBEDO = c;
	ROUGHNESS = mix(0.18, 0.7, g2 * (1.0 - wet * 0.5));
	SPECULAR = 0.7;
	RIM = 0.4;
	RIM_TINT = 0.7;
	BACKLIGHT = vec3(0.18, 0.04, 0.03);
}
