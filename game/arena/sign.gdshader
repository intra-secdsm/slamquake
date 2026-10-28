shader_type spatial;
render_mode cull_disabled;
// Fan-made signs: a coloured board with blocky "lettering". INSTANCE_CUSTOM.a matches the fan holding it.

uniform float excitement : hint_range(0.0, 1.0) = 0.3;
varying vec4 custom;

float hash(float n) { return fract(sin(n) * 43758.5453); }

void vertex() {
	custom = INSTANCE_CUSTOM;
	float r = custom.a;
	float keen = hash(r * 91.7);
	float e = clamp(excitement * (0.55 + keen * 0.9), 0.0, 1.0);
	float ph = r * 6.2831;
	VERTEX.y += max(0.0, sin(TIME * (3.5 + keen * 3.0) + ph)) * 0.14 * smoothstep(0.45, 1.0, e);
	VERTEX.y += sin(TIME * (2.0 + keen) + ph) * 0.05 * e;
}

void fragment() {
	float r = custom.a;
	vec2 uv = UV;
	vec3 board = custom.rgb;
	vec3 ink = hash(r * 7.0) > 0.5 ? vec3(0.02) : vec3(1.0, 0.1, 0.5);
	// two lines of chunky letters
	float line = step(0.18, uv.y) * step(uv.y, 0.42) + step(0.58, uv.y) * step(uv.y, 0.82);
	float cell = floor(uv.x * 7.0) + floor(uv.y * 2.0) * 13.0;
	float letter = step(0.35, hash(cell + r * 50.0)) * step(0.08, uv.x) * step(uv.x, 0.92);
	float stroke = step(0.2, fract(uv.x * 7.0)) * step(fract(uv.x * 7.0), 0.85);
	vec3 col = mix(board, ink, line * letter * stroke);
	ALBEDO = col;
	EMISSION = col * 0.12;
}
