shader_type canvas_item;
// 90s CRT look for the front end: barrel curvature, scanlines, an RGB shadow mask,
// a little bloom and a dark rounded bezel.

uniform sampler2D screen : hint_screen_texture, filter_linear;
uniform float curvature = 0.03;
uniform float scanlines = 0.16;

vec2 barrel(vec2 uv) {
	vec2 c = uv * 2.0 - 1.0;
	c *= 1.0 + curvature * dot(c, c);
	return c * 0.5 + 0.5;
}

void fragment() {
	vec2 uv = barrel(SCREEN_UV);
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	} else {
		vec3 col = texture(screen, uv).rgb;
		vec3 glow = (texture(screen, uv + vec2(0.0008, 0.0)).rgb + texture(screen, uv - vec2(0.0008, 0.0)).rgb) * 0.5;
		col = max(col, glow * 0.7);
		float sl = 0.5 + 0.5 * sin(uv.y * SCREEN_PIXEL_SIZE.y * 0.0 + uv.y * 3.14159 * 360.0);
		col *= 1.0 - scanlines * (1.0 - sl);
		float m = mod(FRAGCOORD.x, 3.0);
		vec3 mask = vec3(m < 1.0 ? 1.08 : 0.94, (m >= 1.0 && m < 2.0) ? 1.08 : 0.94, m >= 2.0 ? 1.08 : 0.94);
		col *= mask;
		vec2 v = uv - 0.5;
		col *= mix(1.0, smoothstep(0.85, 0.35, length(v * vec2(1.0, 1.15))), 0.6);
		COLOR = vec4(col * 1.1, 1.0);
	}
}
