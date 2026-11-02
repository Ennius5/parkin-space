shader_type canvas_item;
// Low-bitrate video look for CctvFilter: blocks, smeared colour, banding, edge fuzz, scanlines, vignette.

uniform sampler2D screen : hint_screen_texture, filter_linear;
uniform float strength : hint_range(0.0, 1.0) = 0.6;
uniform float block = 8.0;      // block size in 720p viewport pixels
uniform float time_step = 0.0;  // changes ~12 times a second, drives the fuzz

vec3 to_ycc(vec3 c) {
	float y = dot(c, vec3(0.299, 0.587, 0.114));
	return vec3(y, (c.b - y) * 0.565, (c.r - y) * 0.713);
}

vec3 to_rgb(vec3 v) {
	float r = v.x + 1.403 * v.z;
	float b = v.x + 1.770 * v.y;
	float g = (v.x - 0.299 * r - 0.114 * b) / 0.587;
	return vec3(r, g, b);
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 res = 1.0 / SCREEN_PIXEL_SIZE;
	float vp = res.y / 720.0;            // real pixels per viewport pixel
	vec2 px = SCREEN_UV * res;
	float bs = block * vp;
	vec2 cell = floor(px / bs);
	vec2 centre = (cell + 0.5) * bs;

	// Block mean from four taps.
	float q = bs * 0.25;
	vec3 mean = (texture(screen, (centre + vec2(-q, -q)) / res).rgb
		+ texture(screen, (centre + vec2(q, -q)) / res).rgb
		+ texture(screen, (centre + vec2(-q, q)) / res).rgb
		+ texture(screen, (centre + vec2(q, q)) / res).rgb) * 0.25;
	vec3 here = texture(screen, SCREEN_UV).rgb;

	// Brightness: quantised block level plus coarsely quantised detail -> flat blocks, banding, seams.
	float levels = mix(256.0, 14.0, strength);
	float y_mean = floor(to_ycc(mean).x * levels + 0.5) / levels;
	float detail = to_ycc(here).x - to_ycc(mean).x;
	float step_d = mix(0.004, 0.09, strength);
	float y = y_mean + floor(detail / step_d + 0.5) * step_d;

	// Colour: read from a wider, horizontally smeared area (chroma subsampling).
	float cw = 3.0 * vp * (0.5 + strength);
	vec2 cpx = (floor(px / (2.0 * vp)) + 0.5) * 2.0 * vp;
	vec3 chroma_src = (texture(screen, (cpx + vec2(-cw, 0.0)) / res).rgb
		+ texture(screen, cpx / res).rgb * 2.0
		+ texture(screen, (cpx + vec2(cw, 0.0)) / res).rgb) * 0.25;
	vec2 cc = to_ycc(chroma_src).yz;

	// Fuzz around sharp edges inside a block (mosquito noise), flickering with time_step.
	float edge = clamp(abs(detail) * 4.0, 0.0, 1.0);
	float n = hash(floor(px / (2.0 * vp)) + time_step) - 0.5;
	y += n * edge * 0.12 * strength;

	vec3 col = mix(here, clamp(to_rgb(vec3(y, cc)), 0.0, 1.0), clamp(strength * 1.5, 0.0, 1.0));

	// CCTV dressing: faint scanlines and a vignette.
	float scan = 1.0 - 0.06 * strength * step(0.5, fract(px.y / (3.0 * vp)));
	vec2 d = SCREEN_UV - 0.5;
	float vig = 1.0 - smoothstep(0.35, 0.8, length(d * vec2(res.x / res.y, 1.0) * 0.8)) * 0.55 * strength;
	COLOR = vec4(col * scan * vig, 1.0);
}
