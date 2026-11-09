shader_type canvas_item;
// 全屏后处理：胶片颗粒、暗角、色调、色差、静电干扰、受伤、复古像素与淡入淡出
uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;
uniform float time_s = 0.0;
uniform float grain = 0.085;
uniform float vignette = 0.55;
uniform float saturation = 0.72;
uniform vec3 tint : source_color = vec3(1.0, 0.98, 0.94);
uniform float gamma = 1.0;
uniform float contrast = 1.06;
uniform float noise_amt = 0.0;
uniform float damage = 0.0;
uniform float lowhp = 0.0;
uniform float fade = 0.0;
uniform vec3 fade_color : source_color = vec3(0.0);
uniform float ca = 0.0012;
uniform float white_flash = 0.0;
uniform float warp = 0.0;
uniform float pixel = 1.0;

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec2 res = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 uv = SCREEN_UV;
	if (pixel > 1.0) {
		uv = (floor(uv * res / pixel) + 0.5) * pixel / res;
	}
	float line = floor(uv.y * 220.0);
	float tq = floor(time_s * 24.0);
	float tear = step(1.0 - 0.18 * noise_amt, hash(vec2(line * 0.37, tq)));
	uv.x += (hash(vec2(line, tq)) - 0.5) * 0.02 * noise_amt * tear;
	uv += vec2(sin(uv.y * 14.0 + time_s * 2.3), cos(uv.x * 11.0 + time_s * 1.7)) * 0.004 * warp;
	vec2 d = uv - 0.5;
	float caa = ca + 0.004 * noise_amt + 0.007 * damage + 0.003 * warp;
	vec3 col;
	col.r = texture(screen_tex, uv + d * caa).r;
	col.g = texture(screen_tex, uv).g;
	col.b = texture(screen_tex, uv - d * caa).b;
	col = pow(max(col, vec3(0.0)), vec3(1.0 / gamma));
	float l = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(l), col, saturation) * tint;
	col = (col - 0.5) * contrast + 0.5;
	vec2 px = floor(FRAGCOORD.xy / max(pixel, 1.0));
	float n = hash(px + fract(time_s * 13.37) * 1000.0) - 0.5;
	float n2 = hash(floor(px * 0.5) + fract(time_s * 7.13) * 500.0) - 0.5;
	col += (n * 0.7 + n2 * 0.3) * grain * (0.55 + 0.9 * (1.0 - clamp(l, 0.0, 1.0)));
	float sn = hash(px * 1.37 + fract(time_s * 91.0) * 300.0);
	col = mix(col, vec3(sn * 0.8), noise_amt * 0.2);
	float v = smoothstep(0.9, 0.18, length(d * vec2(1.3, 1.0)));
	col *= mix(1.0 - vignette, 1.0, v);
	float edge = 1.0 - v;
	col = mix(col, vec3(0.3, 0.0, 0.0), clamp(edge * (lowhp * (0.55 + 0.45 * sin(time_s * 5.5)) * 0.7 + damage * 0.9), 0.0, 1.0));
	col = mix(col, vec3(1.0), white_flash);
	col = mix(col, fade_color, fade);
	COLOR = vec4(clamp(col, 0.0, 1.0), 1.0);
}
