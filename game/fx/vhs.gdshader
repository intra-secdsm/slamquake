shader_type canvas_item;
// VHS playback look for instant replays: wobble, tracking glitches, colour bleed,
// scanlines, tape noise and a soft vignette.

uniform sampler2D screen : hint_screen_texture, filter_linear;
uniform float strength : hint_range(0.0, 1.0) = 1.0;

float rand(vec2 co) { return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453); }

void fragment() {
	vec2 uv = SCREEN_UV;
	float t = TIME;
	float line = floor(uv.y * 240.0);
	uv.x += (rand(vec2(line, floor(t * 30.0))) - 0.5) * 0.0025 * strength;
	uv.x += sin(uv.y * 25.0 + t * 2.7) * 0.0012 * strength;
	float band_y = fract(t * 0.21);
	float band = smoothstep(0.03, 0.0, abs(uv.y - band_y));
	uv.x += band * 0.012 * strength * (rand(vec2(t, line)) - 0.3);
	vec3 col;
	float bleed = 0.0035 * strength;
	col.r = texture(screen, uv + vec2(bleed, 0.0)).r;
	col.g = texture(screen, uv).g;
	col.b = texture(screen, uv - vec2(bleed, 0.0)).b;
	float l = dot(col, vec3(0.3, 0.59, 0.11));
	col = mix(col, vec3(l) * vec3(1.05, 1.0, 0.92), 0.3 * strength);
	col *= 0.86 + 0.14 * sin(SCREEN_UV.y * 1100.0);
	col += (rand(SCREEN_UV * vec2(t * 3.1, t * 1.7)) - 0.5) * 0.09 * strength;
	col += band * 0.12 * strength;
	vec2 v = SCREEN_UV - 0.5;
	col *= 1.0 - dot(v, v) * 0.9 * strength;
	COLOR = vec4(col, 1.0);
}
