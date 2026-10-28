shader_type canvas_item;
// Titantron backdrop: a scrolling neon grid with a horizon glow and scanlines, tinted per wrestler.

uniform vec4 tint : source_color = vec4(1.0, 0.17, 0.84, 1.0);
uniform vec4 tint2 : source_color = vec4(0.0, 0.9, 1.0, 1.0);
uniform float energy = 1.0;

void fragment() {
	vec2 uv = UV;
	float horizon = 0.55;
	vec3 col = mix(vec3(0.02, 0.0, 0.05), tint.rgb * 0.35, smoothstep(0.0, horizon, uv.y));
	if (uv.y > horizon) {
		float d = (uv.y - horizon) / (1.0 - horizon);
		vec2 g = vec2((uv.x - 0.5) / (d + 0.05), 1.0 / (d + 0.05) - TIME * 2.0);
		float lines = max(step(0.92, fract(g.x * 3.0)), step(0.9, fract(g.y * 0.5)));
		col = mix(vec3(0.02, 0.0, 0.06), tint2.rgb, lines * d * 1.5);
	}
	// sun
	vec2 sc = vec2(0.5, horizon - 0.12);
	float sun = smoothstep(0.2, 0.19, distance(uv * vec2(1.78, 1.0), sc * vec2(1.78, 1.0)));
	float bands = step(0.5, fract((uv.y - sc.y) * 28.0 + TIME * 0.5)) + step(uv.y, sc.y);
	col = mix(col, mix(tint.rgb, vec3(1.0, 0.85, 0.2), 1.0 - uv.y * 1.4), sun * min(bands, 1.0));
	col *= 0.85 + 0.15 * sin(uv.y * 600.0);
	COLOR = vec4(col * energy, 1.0);
}
