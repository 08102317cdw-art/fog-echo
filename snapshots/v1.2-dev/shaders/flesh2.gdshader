shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;
// 雕刻怪物专用：静止位置三平面采样 + 导数凹凸 + 蠕动/皮下虫/呼吸
uniform sampler2D flesh_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D grime_tex : filter_linear_mipmap, repeat_enable;
uniform vec3 skin_pale : source_color = vec3(0.37, 0.31, 0.27);
uniform vec3 skin_dark : source_color = vec3(0.12, 0.075, 0.06);
uniform vec3 bruise_c : source_color = vec3(0.16, 0.085, 0.09);
uniform vec3 vein_c : source_color = vec3(0.11, 0.06, 0.07);
uniform vec3 raw_c : source_color = vec3(0.34, 0.025, 0.02);
uniform vec3 bone_c : source_color = vec3(0.62, 0.54, 0.42);
uniform float writhe = 1.0;
uniform float breathe = 0.0;
uniform vec4 worm_a = vec4(0.0, 1.3, -0.12, 0.0);
uniform vec4 worm_b = vec4(0.0, 1.1, 0.10, 0.0);
uniform float hurt = 0.0;
uniform float blood_amt = 0.7;
uniform float bump = 1.0;
uniform float seed = 0.0;
varying vec3 rp;
varying vec3 on;
varying vec4 vc;
varying float reg;
varying float teeth;

float bumpw(vec3 p, vec3 c, float r) {
	vec3 d = p - c;
	return exp(-dot(d, d) / (r * r));
}

void vertex() {
	rp = vec3(UV.x, UV.y, UV2.x);
	reg = floor(UV2.y + 0.001);
	teeth = clamp(fract(UV2.y + 0.001) * 2.0, 0.0, 1.0);
	vc = COLOR;
	float t = TIME + seed * 7.0;
	float torso = reg < 0.5 ? 1.0 : (reg > 1.5 ? 0.55 : 0.25);
	float w = sin(rp.y * 11.0 + t * 5.3) * cos(rp.x * 9.0 - t * 3.7 + rp.z * 6.0) * 0.010;
	w += sin(rp.y * 27.0 - t * 9.0 + rp.z * 17.0 + rp.x * 5.0) * 0.004;
	w *= writhe * torso * (1.0 - teeth);
	// 皮下有东西在爬
	float wa = bumpw(rp, worm_a.xyz, 0.055) * worm_a.w;
	float wb = bumpw(rp, worm_b.xyz, 0.045) * worm_b.w;
	w += (wa + wb) * 0.028;
	// 胸腔呼吸（不均匀、像风箱）
	float chest = smoothstep(1.0, 1.2, rp.y) * (1.0 - smoothstep(1.42, 1.55, rp.y)) * step(reg, 0.5);
	w += breathe * chest * 0.012 * (0.6 + 0.4 * sin(rp.x * 30.0));
	VERTEX += NORMAL * w;
	on = NORMAL;
}

vec4 tri(sampler2D tx, vec3 p, vec3 bw) {
	return texture(tx, p.zy) * bw.x + texture(tx, p.xz) * bw.y + texture(tx, p.xy) * bw.z;
}

void fragment() {
	vec3 n = normalize(on);
	vec3 bw = pow(abs(n), vec3(4.0));
	bw /= (bw.x + bw.y + bw.z);
	vec3 p = rp + vec3(seed * 0.31, 0.0, seed * 0.17);
	vec4 f1 = tri(flesh_tex, p * 2.1, bw);
	vec4 f2 = tri(flesh_tex, p * 6.3 + 0.37, bw);
	float g = tri(grime_tex, p * 1.7 + 0.11, bw).r;
	float wound = vc.r;
	float ao = vc.g;
	float infl = vc.b;
	float stretch = vc.a;
	float head = step(1.5, reg);
	float leg = step(0.5, reg) * (1.0 - head);
	// 底色：病态灰粉皮肤，斑驳
	float mot = smoothstep(0.15, 0.85, f1.r * 0.65 + f2.r * 0.35);
	vec3 c = mix(skin_dark, skin_pale, 0.2 + 0.8 * mot);
	c = mix(c, c * vec3(0.92, 0.95, 1.05) * 1.12, head * 0.6); // 脸更苍白
	// 淤青 / 尸斑
	float br = smoothstep(0.45, 0.85, f1.a) * (0.65 + 0.35 * g);
	c = mix(c, bruise_c, br * 0.5);
	c = mix(c, vec3(0.30, 0.30, 0.16), smoothstep(0.75, 0.95, f1.a) * 0.25);
	// 血管：皮下撑开处与苍白处更明显，缓慢搏动
	float pulse = 0.75 + 0.25 * sin(TIME * 3.2 + rp.y * 6.0);
	float vein = smoothstep(0.42, 0.8, f2.g) * (0.35 + 0.65 * max(stretch, mot * 0.6)) * pulse;
	c = mix(c, vein_c, clamp(vein * 0.8, 0.0, 0.6));
	// 撑开皮肤：更薄更亮，带红色拉伸纹
	c = mix(c, c * 1.1 + vec3(0.015, 0.0, 0.0), stretch * 0.35);
	c = mix(c, vein_c, stretch * smoothstep(0.35, 0.7, f1.g) * 0.4);
	// 发炎边缘
	c = mix(c, vec3(0.2, 0.045, 0.035), smoothstep(0.1, 0.8, infl) * 0.75);
	// 血迹流痕：从胸口裂口、嘴、伤口往下淌
	float streak = smoothstep(0.55, 0.8, texture(flesh_tex, vec2(p.x * 7.0 + p.z * 3.0, p.y * 0.35)).r);
	float under_slit = (1.0 - smoothstep(0.05, 0.13, abs(rp.x))) * smoothstep(0.75, 1.0, rp.y) * (1.0 - smoothstep(1.2, 1.3, rp.y)) * step(rp.z, -0.02);
	float under_mouth = (1.0 - smoothstep(0.03, 0.08, abs(rp.x))) * smoothstep(1.35, 1.55, rp.y) * (1.0 - smoothstep(1.62, 1.66, rp.y)) * step(rp.z, -0.06);
	float bl = clamp(streak * (under_slit + under_mouth) * 1.2 + smoothstep(0.0, 0.5, infl) * streak, 0.0, 1.0) * blood_amt;
	bl = max(bl, smoothstep(0.62, 0.9, g) * 0.35 * blood_amt);
	c = mix(c, vec3(0.12, 0.012, 0.008), bl * 0.8);
	c *= mix(0.72, 1.0, g);
	// 脚和小腿：泥污
	float dirt = (1.0 - smoothstep(0.05, 0.45, rp.y)) * (0.55 + 0.45 * g);
	c = mix(c, vec3(0.07, 0.055, 0.045), dirt * 0.8);
	// 伤口 / 裂口内腔：湿红生肉
	float wd = smoothstep(0.15, 0.7, wound);
	vec3 raw = mix(raw_c * 0.3, raw_c, f2.r) * (0.4 + 0.6 * ao);
	raw = mix(raw, vec3(0.5, 0.25, 0.2), smoothstep(0.7, 0.95, f2.b) * 0.3);
	c = mix(c, raw, wd);
	// 骨刺/牙：发黄的骨头，根部染血
	vec3 bone = bone_c * (0.75 + 0.35 * f2.r);
	bone = mix(bone, vec3(0.25, 0.04, 0.03), (1.0 - smoothstep(0.3, 0.8, teeth)) * 0.7);
	c = mix(c, bone, smoothstep(0.2, 0.6, teeth));
	// 受击闪红
	c = mix(c, vec3(0.45, 0.02, 0.015), hurt);
	c *= mix(0.35, 1.0, ao);
	ALBEDO = c;
	// 粗糙度：整体油湿，伤口与血液更亮
	float rough = mix(0.45, 0.78, f2.b * 0.6 + g * 0.4);
	rough = mix(rough, 0.32, stretch * 0.6);
	rough = mix(rough, 0.12, max(wd, bl * 0.7));
	rough = mix(rough, 0.4, teeth);
	rough = mix(rough, 0.85, dirt);
	ROUGHNESS = rough;
	SPECULAR = 0.42;
	AO = ao;
	AO_LIGHT_AFFECT = 0.4;
	// 导数凹凸：皱纹/毛孔/伤口边缘
	float h = f1.b * 0.6 + f2.b * 0.4 - wd * 0.6 + teeth * 0.2;
	vec3 dpdx = dFdx(VERTEX);
	vec3 dpdy = dFdy(VERTEX);
	float dhx = dFdx(h);
	float dhy = dFdy(h);
	vec3 N0 = normalize(NORMAL);
	vec3 r1 = cross(dpdy, N0);
	vec3 r2 = cross(N0, dpdx);
	float det = dot(dpdx, r1);
	vec3 grad = sign(det) * (dhx * r1 + dhy * r2);
	float bs = 0.0035 * bump * (1.0 - dirt * 0.5);
	NORMAL = normalize(abs(det) * N0 - grad * bs);
	RIM = 0.3;
	RIM_TINT = 0.6;
	BACKLIGHT = vec3(0.16, 0.035, 0.03) * (0.4 + stretch + head * 0.3);
}
