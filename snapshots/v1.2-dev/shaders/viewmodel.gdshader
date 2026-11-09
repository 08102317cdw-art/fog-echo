shader_type spatial;
// 第一人称武器：把深度拉近相机，避免枪管穿进墙里（反向 Z：w 对应近平面）
render_mode cull_back, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rough_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D metal_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grime_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec4 rough_ch = vec4(0.0, 1.0, 0.0, 0.0);
uniform vec4 metal_ch = vec4(0.0, 0.0, 1.0, 0.0);
uniform float roughness = 1.0;
uniform float metallic = 1.0;
uniform float use_normal = 1.0;
uniform float grime = 0.3;
uniform float depth_pull = 0.9;
uniform float ow_mix = 0.0;

void vertex() {
	POSITION = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	POSITION.z = mix(POSITION.z, POSITION.w, depth_pull);
}

void fragment() {
	vec4 a = texture(albedo_tex, UV) * albedo;
	float g = texture(grime_tex, UV * 1.7).r;
	vec3 col = a.rgb * mix(1.0, 0.6 + 0.4 * g, grime);
	col = mix(col, col * vec3(0.95, 0.78, 0.72), ow_mix * 0.5);
	ALBEDO = col;
	ROUGHNESS = clamp(dot(texture(rough_tex, UV), rough_ch) * roughness + grime * 0.12, 0.04, 1.0);
	METALLIC = clamp(dot(texture(metal_tex, UV), metal_ch) * metallic, 0.0, 1.0);
	if (use_normal > 0.5) {
		NORMAL_MAP = texture(normal_tex, UV).rgb;
	}
}
