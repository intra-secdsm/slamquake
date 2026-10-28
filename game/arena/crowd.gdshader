shader_type spatial;
// Instanced fans. INSTANCE_CUSTOM: rgb = shirt colour, a = per-fan random (phase, keenness).
// UV.x marks the body part (0 legs, 1 shirt/arms, 2 skin); UV.y the arm side (-1/+1, 0 = not an arm).

uniform float excitement : hint_range(0.0, 1.0) = 0.3;
uniform float flash = 0.0;          // brief brightening for big moments

varying vec4 custom;
varying float part;

float hash(float n) { return fract(sin(n) * 43758.5453); }

void vertex() {
	custom = INSTANCE_CUSTOM;
	part = UV.x;
	float r = custom.a;
	float ph = r * 6.2831;
	float keen = hash(r * 91.7);
	float e = clamp(excitement * (0.55 + keen * 0.9), 0.0, 1.0);
	float side = UV.y;
	if (abs(side) > 0.5) {
		vec3 pivot = vec3(0.24 * side, 1.36, 0.0);
		float wave = 0.5 + 0.5 * sin(TIME * (3.0 + keen * 2.5) + ph + side * 1.3);
		float lift = smoothstep(0.25, 0.75, e) * (0.55 + 0.45 * wave);
		float ang = mix(0.12, 2.8, lift);
		vec3 p = VERTEX - pivot;
		float cs = cos(ang), sn = sin(ang);
		p = vec3(p.x + side * 0.08 * lift, p.y * cs + p.z * sn, -p.y * sn + p.z * cs);
		VERTEX = p + pivot;
	}
	float bounce = max(0.0, sin(TIME * (3.5 + keen * 3.0) + ph)) * 0.14 * smoothstep(0.45, 1.0, e);
	VERTEX.y += bounce;
	VERTEX.x += sin(TIME * 0.7 + ph) * 0.025 * VERTEX.y;
}

void fragment() {
	float r = custom.a;
	vec3 pants = mix(vec3(0.05, 0.06, 0.12), vec3(0.25, 0.22, 0.2), hash(r * 13.1));
	vec3 skin = mix(vec3(0.95, 0.72, 0.58), vec3(0.35, 0.22, 0.14), hash(r * 37.3));
	vec3 col = part < 0.5 ? pants : (part < 1.5 ? custom.rgb : skin);
	ALBEDO = col;
	ROUGHNESS = 0.8;
	EMISSION = col * (0.06 + flash * 0.5);
}
