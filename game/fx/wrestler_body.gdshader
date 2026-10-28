shader_type spatial;
// Wrestler skin + "painted" attire. Attire regions are defined in rest-pose body space
// (exported by blender/wrestle_gen/body.py), so they stay put while animating and can be
// changed live (create-a-wrestler) without new geometry.

uniform vec3 skin_color : source_color = vec3(0.80, 0.56, 0.42);
uniform vec3 trunks_color : source_color = vec3(0.85, 0.05, 0.35);
uniform vec3 trim_color : source_color = vec3(1.0, 0.85, 0.1);
uniform vec3 boots_color : source_color = vec3(0.08, 0.08, 0.1);
uniform vec3 pads_color : source_color = vec3(0.85, 0.05, 0.35);
uniform vec3 tights_color : source_color = vec3(0.1, 0.1, 0.12);
uniform vec3 brow_color : source_color = vec3(0.12, 0.08, 0.05);
uniform vec3 shirt_color : source_color = vec3(0.95);
uniform vec3 stripe_color : source_color = vec3(0.05);

uniform float waist = 1.06;
uniform float trunks_bottom = 0.86;
uniform float boot_top = 0.40;
uniform float tights = 0.0;
uniform float kneepads = 1.0;
uniform float wristbands = 1.0;
uniform float elbowpads = 0.0;
uniform float shirt = 0.0;
uniform float stripes = 0.0;   // vertical stripes around the shirt (0 = plain)
uniform float skin_roughness = 0.42;
uniform float rim_strength = 0.35;

varying vec3 rest;       // rest position: x = own left, y = back, z = up (metres)
varying float limb_t;    // 0..1 along arm or leg chain
varying vec4 region;     // arm, leg, head+neck, torso

float band(float x, float lo, float hi, float w) {
	return smoothstep(lo - w, lo + w, x) * (1.0 - smoothstep(hi - w, hi + w, x));
}

void vertex() {
	rest = vec3((UV.x - 0.5) * 4.0, ((1.0 - UV2.y) - 0.5) * 4.0, (1.0 - UV.y) * 4.0);
	limb_t = UV2.x;
	region = COLOR;
}

void fragment() {
	float w = 0.003;
	float z = rest.z;
	float arm = smoothstep(0.4, 0.6, region.r);
	float leg = smoothstep(0.4, 0.6, region.g);
	float head = smoothstep(0.4, 0.6, region.b);
	float lower = (1.0 - arm) * (1.0 - head);

	vec3 col = skin_color;
	float rough = skin_roughness;
	float spec = 0.5;
	float sss = 0.35;

	// eyebrows: two arched strokes above the eye sockets
	float bx = abs(rest.x);
	float arch = 1.826 + 0.010 * sin(clamp((bx - 0.012) / 0.045, 0.0, 1.0) * 3.14159);
	float brow = head * step(rest.y, -0.07) * band(bx, 0.012, 0.056, 0.002) * band(z, arch - 0.006, arch + 0.004, 0.0015);
	col = mix(col, brow_color, brow);

	// mouth: a slightly downturned line with a soft lower lip
	float mz = 1.7275 - 0.006 * (bx / 0.024) * (bx / 0.024);
	float mouth = head * step(rest.y, -0.085) * (1.0 - smoothstep(0.02, 0.026, bx));
	col = mix(col, skin_color * vec3(0.45, 0.28, 0.26), mouth * band(z, mz - 0.0016, mz + 0.0016, 0.0008));
	col = mix(col, skin_color * vec3(0.85, 0.66, 0.62), mouth * band(z, mz - 0.010, mz - 0.003, 0.002) * 0.6);

	float tight_m = leg * band(z, boot_top, trunks_bottom, w) * tights;
	col = mix(col, tights_color, tight_m);

	float trunks_m = lower * band(z, trunks_bottom, waist, w);
	float trim_m = lower * band(z, waist - 0.028, waist, w);
	col = mix(col, trunks_color, trunks_m);
	col = mix(col, trim_color, trim_m);

	float boot_m = leg * (1.0 - smoothstep(boot_top - w, boot_top + w, z));
	float sole_m = boot_m * (1.0 - smoothstep(0.022, 0.028, z));
	col = mix(col, boots_color, boot_m);
	col = mix(col, vec3(0.04), sole_m);

	float knee_m = leg * band(z, 0.46, 0.62, w) * kneepads;
	col = mix(col, pads_color, knee_m);

	float wrist_m = arm * band(limb_t, 0.67, 0.75, 0.004) * wristbands;
	float elbow_m = arm * band(limb_t, 0.36, 0.45, 0.004) * elbowpads;
	col = mix(col, pads_color, max(wrist_m, elbow_m));

	// shirt: torso above the waist plus short sleeves
	float torso = 1.0 - arm - leg - head;
	float shirt_m = shirt * max(clamp(torso, 0.0, 1.0) * step(waist - 0.01, z), arm * (1.0 - smoothstep(0.24, 0.26, limb_t)));
	shirt_m *= 1.0 - head;
	float ang = atan(rest.x, -rest.y) / 6.28318 + 0.5;
	float stripe = stripes > 0.0 ? step(0.5, fract(ang * stripes)) : 0.0;
	col = mix(col, mix(shirt_color, stripe_color, stripe), shirt_m);

	float cloth = clamp(tight_m + trunks_m + boot_m + knee_m + wrist_m + elbow_m + shirt_m, 0.0, 1.0);
	rough = mix(rough, 0.35, trunks_m);           // shiny spandex
	rough = mix(rough, 0.55, boot_m + knee_m);
	sss = mix(sss, 0.0, cloth);
	spec = mix(spec, 0.4, cloth);

	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = spec;
	SSS_STRENGTH = sss;
	RIM = rim_strength;
	RIM_TINT = 0.6;
}
