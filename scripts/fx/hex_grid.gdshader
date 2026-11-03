shader_type canvas_item;
// Title backdrop: dark hexagon tiles with neon edges that pulse between two colours.
// A soft wave rolls out from the centre; each tile gets a little random phase.

uniform vec4 color_a : source_color = vec4(0.1, 0.95, 1.0, 1.0);
uniform vec4 color_b : source_color = vec4(0.2, 1.0, 0.35, 1.0);
uniform vec4 base_color : source_color = vec4(0.02, 0.03, 0.06, 1.0);
uniform float cell_px = 60.0;      // tile width in pixels
uniform float pulse_speed = 2.1;   // radians per second (~3 s per pulse)
uniform float wave_scale = 6.0;    // how many wave rings fit across the screen

varying vec2 local_px;

void vertex() {
	local_px = VERTEX;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Offset (centre-relative) inside the nearest pointy-top hexagon, plus that hexagon's id.
vec4 hex_cell(vec2 p) {
	vec2 r = vec2(1.0, 1.7320508);
	vec2 h = r * 0.5;
	vec2 a = mod(p, r) - h;
	vec2 b = mod(p - h, r) - h;
	vec2 gv = dot(a, a) < dot(b, b) ? a : b;
	return vec4(gv, p - gv);
}

float hex_dist(vec2 p) {
	p = abs(p);
	return max(dot(p, vec2(0.5, 0.8660254)), p.x);
}

void fragment() {
	vec4 cell = hex_cell(local_px / cell_px);
	float edge = 0.5 - hex_dist(cell.xy);           // 0 on the edge, 0.5 at the middle
	float line = smoothstep(0.045, 0.0, edge);
	float glow = exp(-edge * 14.0);

	float t = TIME * pulse_speed;
	float ring = length((UV - 0.5) * vec2(1.6, 1.0)) * wave_scale;
	float pulse = 0.5 + 0.5 * sin(t - ring + hash(cell.zw) * 1.5);
	float hue = 0.5 + 0.5 * sin(t * 0.35 + cell.z * 0.15 - cell.w * 0.1);
	vec3 neon = mix(color_a.rgb, color_b.rgb, hue);

	float light = (0.25 + 0.75 * pulse) * (line * 0.85 + glow * 0.3);
	float fill = 0.04 + 0.05 * pulse;               // faint tint inside each tile
	float vignette = 1.0 - 0.45 * length(UV - 0.5);
	COLOR = vec4(base_color.rgb + neon * (light + fill) * vignette, 1.0);
}
