shader_type spatial;
// Wrestler skin + "painted" attire. Attire regions are defined in rest-pose body space
// (exported by blender/wrestle_gen/body.py), so they stay put while animating and can be
// changed live (create-a-wrestler) without new geometry. Edges are anti-aliased over the
// rest-space size of a pixel, so paint apps stay crisp up close and don't shimmer far away.

uniform vec3 skin_color : source_color = vec3(0.80, 0.56, 0.42);
uniform vec3 trunks_color : source_color = vec3(0.85, 0.05, 0.35);
uniform vec3 trim_color : source_color = vec3(1.0, 0.85, 0.1);
uniform vec3 boots_color : source_color = vec3(0.08, 0.08, 0.1);
uniform vec3 pads_color : source_color = vec3(0.85, 0.05, 0.35);
uniform vec3 tights_color : source_color = vec3(0.1, 0.1, 0.12);
uniform vec3 brow_color : source_color = vec3(0.12, 0.08, 0.05);
uniform vec3 shirt_color : source_color = vec3(0.95);
uniform vec3 stripe_color : source_color = vec3(0.05);
uniform vec3 top_color : source_color = vec3(0.85, 0.05, 0.35);
uniform vec3 pattern_color : source_color = vec3(1.0, 0.85, 0.1);
uniform vec3 paint_color : source_color = vec3(0.95);
uniform vec3 paint_color2 : source_color = vec3(0.05);
uniform vec3 mask_color : source_color = vec3(0.1, 0.75, 0.35);
uniform vec3 mask_trim : source_color = vec3(1.0, 0.85, 0.1);
uniform vec3 tattoo_color : source_color = vec3(0.08, 0.1, 0.2);

uniform float feminine = 0.0;  // 0..1: finer brows, lip colour, lash lines
uniform float waist = 1.06;
uniform float trunks_bottom = 0.86;
uniform float boot_top = 0.40;
uniform float boots = 1.0;     // 0 = barefoot
uniform float tights = 0.0;
uniform float singlet = 0.0;   // one-piece: trunks colour up over the chest with shoulder straps
uniform float top = 0.0;       // sports top over the chest
uniform float kneepads = 1.0;
uniform float wristbands = 1.0;
uniform float elbowpads = 0.0;
uniform float shirt = 0.0;
uniform float stripes = 0.0;   // vertical stripes around the shirt (0 = plain)
// on trunks, tights and singlet: 0 none, 1 stripe, 2 flames, 3 stars, 4 bolt, 5 split
uniform int pattern_style : hint_range(0, 5) = 0;
// face paint: 0 none, 1 warrior, 2 skull, 3 half, 4 stripes, 5 star, 6 cyber
uniform int paint_style : hint_range(0, 6) = 0;
// luchador mask: 0 none, 1 classic, 2 wings, 3 half (hero mask)
uniform int mask_style : hint_range(0, 3) = 0;
// tattoo (left side): 0 none, 1 armband, 2 sleeve, 3 chest
uniform int tattoo_style : hint_range(0, 3) = 0;
uniform float skin_roughness = 0.42;
uniform float rim_strength = 0.35;
uniform vec3 aura_color : source_color = vec3(1.0, 0.78, 0.15);
uniform float aura = 0.0;      // SPECIAL banked: glowing edges

varying vec3 rest;       // rest position: x = own left, y = back, z = up (metres)
varying float limb_t;    // 0..1 along arm or leg chain
varying vec4 region;     // arm, leg, head+neck, torso

float band(float x, float lo, float hi, float w) {
	return smoothstep(lo - w, lo + w, x) * (1.0 - smoothstep(hi - w, hi + w, x));
}

// Coverage of the inside (d < 0) of a distance field in metres, anti-aliased over px metres.
float fill(float d, float px) {
	return clamp(0.5 - d / px, 0.0, 1.0);
}

// A stroke of half-width hw along a distance field's zero line; it fades out instead of
// shimmering once it gets thinner than a pixel.
float stroke(float d, float hw, float px) {
	return fill(abs(d) - max(hw, 0.5 * px), px) * min(1.0, 2.0 * hw / px);
}

float hash2(vec2 p) {
	vec3 p3 = fract(p.xyx * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec2 rot(vec2 p, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec2(c * p.x - s * p.y, s * p.x + c * p.y);
}

// Approximate distance to an ellipse with radii r (< 0 inside).
float ellipse(vec2 p, vec2 r) {
	float k0 = length(p / r);
	return k0 * (k0 - 1.0) / max(length(p / (r * r)), 1e-6);
}

float segment(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	return length(pa - ba * clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0));
}

// Distance to a five-point star pointing up: outer radius r, inner radius r * rf.
float star5(vec2 p, float r, float rf) {
	vec2 k1 = vec2(0.809017, -0.587785);
	vec2 k2 = vec2(-0.809017, -0.587785);
	vec2 q = vec2(abs(p.x), p.y);
	q -= 2.0 * max(dot(k1, q), 0.0) * k1;
	q -= 2.0 * max(dot(k2, q), 0.0) * k2;
	q.x = abs(q.x);
	q.y -= r;
	vec2 ba = rf * vec2(-k1.y, k1.x) - vec2(0.0, 1.0);
	float h = clamp(dot(q, ba) / dot(ba, ba), 0.0, r);
	return length(q - ba * h) * sign(q.y * ba.x - q.x * ba.y);
}

// Flame licks / tribal thorns rising from a solid base below v = 0. u counts licks along the
// base (the pattern repeats every n), cw is one lick's width and v the height above the base,
// both in metres. Licks are up to h tall, taper to sharp tips and curl sideways by curl widths.
float licks(float u, float v, float cw, float h, float curl, float n) {
	float k = clamp(v / h, 0.0, 1.0);
	float x = u - curl * k * k;
	float lh = h * (0.62 + 0.38 * hash2(vec2(mod(floor(x), n), n)));
	float hw = 0.5 * pow(1.0 - clamp(v / lh, 0.0, 1.0), 1.3);
	float lick = max((abs(fract(x) - 0.5) - hw) * cw, v - lh);
	return min(lick, v - 0.06 * h);
}

// Upper edge of a tank-style garment on the torso (singlet, top): a neckline scooped down to
// neck_z between two shoulder straps, and armholes dropping to arm_z at the sides.
// Distance in metres, < 0 below the edge.
float tank(vec3 p, float neck_z, float arm_z) {
	vec2 q = vec2(abs(p.x), p.z);
	float scoop = ellipse(q - vec2(0.0, 1.66), vec2(0.082, 1.66 - neck_z));
	float armhole = ellipse(q - vec2(0.31, 1.66), vec2(0.18, 1.66 - arm_z));
	return max(-scoop, -armhole);
}

// One wing feather fanning back from o at angle a: a blade len long and wid at its widest,
// curving up towards its tip.
float feather(vec2 p, vec2 o, float a, float len, float wid) {
	vec2 q = rot(p - o, -a);
	float s = clamp(q.x / len, 0.0, 1.0);
	float hw = wid * smoothstep(0.0, 0.1, s) * pow(1.0 - s, 0.7);
	return max(abs(q.y - 0.18 * len * s * s) - hw, max(-q.x, q.x - len));
}

void vertex() {
	rest = vec3((UV.x - 0.5) * 4.0, ((1.0 - UV2.y) - 0.5) * 4.0, (1.0 - UV.y) * 4.0);
	limb_t = UV2.x;
	region = COLOR;
}

void fragment() {
	vec3 p = rest;
	float z = p.z;
	float ax = abs(p.x);
	// rest-space metres per pixel, for anti-aliasing
	float px = max(length(dFdx(p)), length(dFdy(p))) + 1e-5;
	float w = max(0.003, 0.5 * px);
	float arm = smoothstep(0.4, 0.6, region.r);
	float leg = smoothstep(0.4, 0.6, region.g);
	float head = smoothstep(0.4, 0.6, region.b);
	float lower = (1.0 - arm) * (1.0 - head);
	// head surface coordinates: arc length round the head from the face's centre line
	// (+ = own left), and its mirror image for symmetric designs
	float hu = 0.1 * atan(p.x, -p.y);
	vec2 hp = vec2(abs(hu), z);

	vec3 col = skin_color;
	float rough = skin_roughness;
	float spec = 0.5;
	float sss = 0.35;
	float paint = 0.0;   // matte face paint coverage
	float plate = 0.0;   // metal face plate coverage
	vec3 glow = vec3(0.0);

	// eyebrows: two arched strokes above the eye sockets
	float arch = 1.826 + mix(0.010, 0.013, feminine) * sin(clamp((ax - 0.012) / 0.045, 0.0, 1.0) * 3.14159);
	float brow = head * step(p.y, -0.07) * band(ax, 0.012, 0.056, max(0.002, 0.5 * px))
		* band(z, arch - mix(0.006, 0.0025, feminine), arch + mix(0.004, 0.003, feminine), max(0.0015, 0.5 * px));
	col = mix(col, brow_color, brow);

	// mouth: a slightly downturned line with a soft lower lip
	float mz = 1.7275 - 0.006 * (ax / 0.024) * (ax / 0.024);
	float mouth = head * step(p.y, -0.085) * (1.0 - smoothstep(0.02, 0.026, ax));
	col = mix(col, skin_color * vec3(0.45, 0.28, 0.26), mouth * stroke(z - mz, 0.0016, px));
	col = mix(col, skin_color * vec3(0.85, 0.66, 0.62), mouth * band(z, mz - 0.010, mz - 0.003, 0.002) * 0.6);
	if (feminine > 0.0) {
		// tinted lips and dark lash lines along the upper lids, flicked at the outer corners
		float lips = fill(ellipse(vec2(p.x, z - mz + 0.0012), vec2(0.0225, 0.0062)), px);
		col = mix(col, skin_color * vec3(0.72, 0.36, 0.38), mouth * lips * 0.8 * feminine);
		float le = (ax - 0.033) / 0.017;
		float lash = stroke(z - 1.7908 - 0.0045 * (1.0 - le * le) - 0.006 * smoothstep(0.6, 1.25, le) * le,
			0.0007 + 0.0006 * smoothstep(0.0, 1.0, le), px);
		col = mix(col, brow_color * 0.5, head * step(p.y, -0.07) * lash * step(abs(le), 1.3) * feminine);
	}

	// face paint (head only; a mask goes over it)
	if (paint_style > 0) {
		// the face: jaw line to hairline, forward of the ears
		float jaw = 1.664 + 2.6 * hp.x * hp.x;
		float face = head * fill(max(max(jaw - z, z - 1.872), hp.x - 0.118), px);
		if (paint_style == 1) {
			// warrior: a bold stripe under each eye sweeping back across the cheek to a point,
			// with a thinner accent stripe below it
			float s1z = 1.7695 - 0.16 * (hp.x - 0.02);
			float s1 = max(abs(z - s1z) - 0.0068 * (1.0 - smoothstep(0.05, 0.125, hp.x)), 0.013 - hp.x);
			float s2 = max(abs(z - s1z + 0.0175) - 0.004 * (1.0 - smoothstep(0.045, 0.112, hp.x)), 0.022 - hp.x);
			float a1 = head * fill(s1, px);
			float a2 = head * fill(s2, px);
			col = mix(col, paint_color, a1);
			col = mix(col, paint_color2, a2);
			paint = max(a1, a2);
		} else if (paint_style == 2) {
			// skull: pale face, dark eye sockets and nose, stitched teeth and hollow cheeks
			col = mix(col, paint_color, face);
			float sockets = ellipse(rot(hp - vec2(0.034, 1.7935), -0.18), vec2(0.0235, 0.0195));
			float nose = max(dot(vec2(ax, z - 1.777), vec2(0.894, 0.447)), 1.745 - z);
			float tz = z - mz;
			float teeth = max(stroke(tz, 0.0011, px), stroke((fract(p.x / 0.0085 + 0.5) - 0.5) * 0.0085, 0.0008, px)
				* step(abs(tz), 0.011)) * fill(ax - 0.034, px);
			float cheeks = fill(ellipse(hp - vec2(0.06, 1.727), vec2(0.016, 0.024)), px + 0.012);
			col = mix(col, paint_color2, face * cheeks * 0.4);
			col = mix(col, paint_color2, face * max(max(fill(sockets, px), fill(nose, px)), teeth));
			paint = face;
		} else if (paint_style == 3) {
			// half: the left half of the face, with an accent line down the middle and round the eye
			float half_face = face * fill(-p.x, px);
			col = mix(col, paint_color, half_face);
			float ring = stroke(ellipse(vec2(hu, z) - vec2(0.033, 1.7925), vec2(0.022, 0.018)), 0.0018, px);
			col = mix(col, paint_color2, face * max(stroke(p.x, 0.0018, px), ring));
			paint = half_face;
		} else if (paint_style == 4) {
			// stripes from forehead to chin: one through each eye, a thinner one on each cheek
			float taper = smoothstep(jaw, jaw + 0.05, z);
			float a1 = face * fill(abs(hp.x - 0.033) - 0.0062 * taper, px);
			float a2 = face * fill(abs(hp.x - 0.071) - 0.0042 * taper, px);
			col = mix(col, paint_color, a1);
			col = mix(col, paint_color2, a2);
			paint = max(a1, a2);
		} else if (paint_style == 5) {
			// star over the left eye, outlined
			float sd = star5(vec2(hu, z) - vec2(0.033, 1.797), 0.037, 0.45);
			col = mix(col, paint_color2, head * fill(sd - 0.0028, px));
			col = mix(col, paint_color, head * fill(sd, px));
			paint = head * fill(sd - 0.0028, px);
		} else {
			// cyber: metal plates over the right eye, temple and cheekbone, with glowing circuit
			// traces running off them and a glowing ring round the eye
			vec2 c = vec2(-hu, z);
			float plate = max(max(0.012 - c.x, c.x - 0.128), max(1.748 - z, z - 1.876));
			plate = max(plate, dot(c - vec2(0.012, 1.795), vec2(-0.8, -0.6)));
			float outline = max(max(0.012 - c.x, c.x - 0.128), max(1.748 - z, z - 1.876));
			outline = max(outline, dot(c - vec2(0.012, 1.795), vec2(-0.8, -0.6)));
			plate = head * fill(outline, px);
			float seams = max(stroke(z - 1.836, 0.0007, px), stroke(c.x - 0.079, 0.0007, px) * step(1.836, z));
			seams = max(seams, stroke(c.x - 0.104, 0.0007, px) * step(z, 1.836));
			float rivets = fill(min(min(length(c - vec2(0.02, 1.866)), length(c - vec2(0.118, 1.866))),
				min(length(c - vec2(0.118, 1.758)), length(c - vec2(0.068, 1.758)))) - 0.0022, px);
			col = mix(col, paint_color, plate);
			col = mix(col, paint_color * 0.3, plate * max(seams, rivets * 0.6));
			float tr = min(min(segment(c, vec2(0.05, 1.75), vec2(0.05, 1.73)), segment(c, vec2(0.05, 1.73), vec2(0.066, 1.714))),
				min(segment(c, vec2(0.092, 1.75), vec2(0.092, 1.738)), segment(c, vec2(0.092, 1.738), vec2(0.106, 1.724))));
			tr = min(tr, min(segment(c, vec2(0.014, 1.856), vec2(-0.014, 1.856)), segment(c, vec2(0.126, 1.80), vec2(0.152, 1.80))));
			tr = min(tr, segment(c, vec2(0.152, 1.80), vec2(0.16, 1.784)));
			float pads = min(min(length(c - vec2(0.066, 1.714)), length(c - vec2(0.106, 1.724))),
				min(length(c - vec2(-0.014, 1.856)), length(c - vec2(0.16, 1.784))));
			float circuit = head * max(stroke(tr, 0.001, px), fill(pads - 0.0032, px));
			float ring = head * stroke(ellipse(c - vec2(0.033, 1.7925), vec2(0.0185, 0.0152)), 0.0016, px);
			col = mix(col, paint_color2, max(circuit, ring));
			glow += paint_color2 * (circuit * 1.2 + ring * 2.5);
			paint = max(circuit, ring);
		}
	}

	// tattoo (left arm or pec), slightly faded like ink under the skin
	if (tattoo_style > 0) {
		float ink;
		if (tattoo_style == 3) {
			// chest: a tribal sun over the left pec
			vec2 c = vec2(p.x, z) - vec2(0.088, 1.425);
			float rho = length(c);
			float rays = licks(atan(c.y, c.x) / TAU * 9.0, rho - 0.017, TAU * rho / 9.0, 0.033, 0.4, 9.0);
			ink = fill(min(rho - 0.0115, max(rays, 0.017 - rho)), px + 0.001) * smoothstep(-0.05, -0.08, p.y) * (1.0 - arm);
		} else {
			// left arm frame: s along the arm from the shoulder joint, u round it from the top
			vec3 axis = vec3(0.7648, -0.0476, -0.6424);
			vec3 q = p - vec3(0.21, 0.03, 1.52);
			float s = dot(q, axis);
			vec3 rv = q - s * axis;
			float ar = length(rv);
			float u = atan(dot(rv, vec3(-0.036, -0.998, 0.031)), dot(rv, vec3(0.6424, 0.0, 0.7648))) / TAU;
			float d;
			if (tattoo_style == 1) {
				// armband: a band round the upper arm with thorns curling off both edges
				float v = abs(s - 0.17) - 0.008;
				d = licks(u * 6.0 + step(0.17, s) * 0.5, v, TAU * ar / 6.0, 0.032, 0.35, 6.0);
			} else {
				// sleeve: a shoulder cap with spikes up over the shoulder, long licks down to the
				// elbow and licks rising from a band above the wrist, interlocking with them
				float cw = TAU * ar / 5.0;
				float down = max(licks(u * 5.0, s - 0.06, cw, 0.22, 0.6, 5.0), -s);
				float spikes = max(licks(u * 5.0 + 0.5, -s, cw, 0.045, 0.3, 5.0), s - 0.01);
				float up = max(licks(u * 5.0 + 0.5, 0.49 - s, cw, 0.2, -0.6, 5.0), s - 0.515);
				d = min(min(down, spikes), up);
			}
			ink = fill(d, px + 0.001) * step(0.0, p.x) * fill(ar - 0.1, px);
		}
		col = mix(col, mix(tattoo_color, col, 0.22), ink * 0.88);
	}

	// pattern on the trunks/singlet (upper) and tights
	float upper = step(trunks_bottom, z);
	float pat = 0.0;
	if (pattern_style == 1 || pattern_style == 4) {
		// stripe / lightning bolt down the outside of each hip and leg
		float yy = p.y - 0.012;
		float d;
		if (pattern_style == 1) {
			d = abs(yy) - 0.022;
		} else {
			// zig-zag of long diagonals and short steep returns
			float per = 0.11;
			float k = fract(z / per);
			float long_leg = step(k, 0.68);
			float yc = long_leg > 0.5 ? mix(-0.02, 0.02, k / 0.68) : mix(0.02, -0.02, (k - 0.68) / 0.32);
			float slope = 0.04 / (per * mix(0.32, 0.68, long_leg));
			d = abs(yy - yc) / sqrt(1.0 + slope * slope) - 0.012;
		}
		pat = fill(d, px) * fill(0.1 - ax, px);
	} else if (pattern_style == 2) {
		// flames licking up from the bottom edge of the trunks/singlet and of the tights,
		// counted round each leg (mirrored left/right)
		vec2 c = vec2(ax - mix(0.135, 0.118, smoothstep(0.3, 0.8, z)), p.y - 0.005);
		float u = atan(c.y, c.x) / TAU * 10.0;
		float cw = TAU * length(c) / 10.0;
		float v = z - mix(boot_top, trunks_bottom, upper);
		float h = mix(0.14, 0.1, upper);
		float f = min(licks(u, v, cw, h, 0.45, 10.0), licks(u + 0.5, v, cw, 0.55 * h, 0.45, 10.0));
		pat = fill(f, px);
	} else if (pattern_style == 3) {
		// scattered stars: cells counted round the body (trunks/singlet) or round each leg (tights)
		vec2 c = upper > 0.5 ? vec2(p.x, p.y - 0.01) : vec2(ax - mix(0.135, 0.118, smoothstep(0.3, 0.8, z)), p.y - 0.005);
		float n = upper > 0.5 ? 16.0 : 7.0;
		float ch = 0.065;
		vec2 g = vec2((upper > 0.5 ? atan(c.x, -c.y) : atan(c.y, c.x)) / TAU * n, z / ch);
		vec2 id = vec2(mod(floor(g.x), n), floor(g.y));
		float cw = TAU * length(c) / n;
		vec2 jit = (vec2(hash2(id), hash2(id + 17.0)) - 0.5) * 0.3;
		float r = min(0.021, 0.3 * min(cw, ch)) * (0.75 + 0.35 * hash2(id + 5.0));
		vec2 q = rot((fract(g) - 0.5 - jit) * vec2(cw, ch), hash2(id + 9.0) * 1.2566);
		pat = fill(star5(q, r, 0.45), px) * step(0.22, hash2(id + 31.0));
	} else if (pattern_style == 5) {
		// split down the middle: left half in the pattern colour
		pat = fill(-p.x, px);
	}

	float tight_m = leg * band(z, boot_top, trunks_bottom, w) * tights;
	col = mix(col, mix(tights_color, pattern_color, pat), tight_m);

	// trunks, or a singlet: trunks colour up over the chest with straps, trimmed at the edges
	float trunks_m = lower * band(z, trunks_bottom, waist, w);
	float tank_d = tank(p, 1.395, 1.33);
	float singlet_m = singlet * lower * fill(trunks_bottom - z, px) * fill(tank_d, px);
	float upper_m = max(trunks_m, singlet_m);
	col = mix(col, mix(trunks_color, pattern_color, pat), upper_m);
	float trim_m = lower * band(z, waist - 0.028, waist, w) * (1.0 - singlet);
	trim_m = max(trim_m, singlet_m * max(stroke(tank_d + 0.0045, 0.0045, px), band(z, trunks_bottom, trunks_bottom + 0.009, w)));
	col = mix(col, trim_color, trim_m);

	// sports top: a chest band with straps and a trim-coloured elastic hem, cut generously
	// below the chest so it also covers a bust
	float top_m = 0.0;
	if (top > 0.0) {
		float hem = mix(1.285, 1.25, feminine);
		top_m = top * lower * fill(max(tank(p, 1.45, 1.345), hem - z), px);
		col = mix(col, top_color, top_m);
		col = mix(col, trim_color, top_m * band(z, hem, hem + 0.018, w));
	}

	// boots, or bare feet with toe creases
	float boot_m = boots * leg * (1.0 - smoothstep(boot_top - w, boot_top + w, z));
	float sole_m = boot_m * (1.0 - smoothstep(0.022, 0.028, z));
	col = mix(col, boots_color, boot_m);
	col = mix(col, vec3(0.04), sole_m);
	if (boots < 0.5) {
		float tx = ax - 0.111;
		float gaps = min(min(abs(tx - 0.024), abs(tx - 0.039)), min(abs(tx - 0.052), abs(tx - 0.064)));
		float toes = leg * stroke(gaps, 0.0008, px) * smoothstep(-0.152, -0.17, p.y) * step(0.02, z);
		col = mix(col, skin_color * 0.62, toes * 0.8);
	}

	float knee_m = leg * band(z, 0.46, 0.62, w) * kneepads;
	col = mix(col, pads_color, knee_m);

	float wrist_m = arm * band(limb_t, 0.67, 0.75, max(0.004, px)) * wristbands;
	float elbow_m = arm * band(limb_t, 0.36, 0.45, max(0.004, px)) * elbowpads;
	col = mix(col, pads_color, max(wrist_m, elbow_m));

	// shirt: torso above the waist plus short sleeves
	float torso = 1.0 - arm - leg - head;
	float shirt_m = shirt * max(clamp(torso, 0.0, 1.0) * step(waist - 0.01, z), arm * (1.0 - smoothstep(0.24, 0.26, limb_t)));
	shirt_m *= 1.0 - head;
	float stripe = 0.0;
	if (stripes > 0.0) {
		// half of each period round a ~0.17 m torso, measured in metres for anti-aliasing
		float ang = atan(p.x, -p.y) / TAU + 0.5;
		stripe = fill((abs(fract(ang * stripes - 0.25) - 0.5) - 0.25) * TAU * 0.17 / stripes, px);
	}
	col = mix(col, mix(shirt_color, stripe_color, stripe), shirt_m);

	// luchador mask over the head (and the neck down to the collar), outlined in the trim colour
	float mask_m = 0.0;
	if (mask_style > 0) {
		float eye = ellipse(rot(hp - vec2(0.033, 1.7925), -0.17), vec2(0.0195, 0.0128));
		float mouth_hole = ellipse(vec2(hu, z - 1.7245), vec2(0.024, 0.0135));
		float cover;
		float bottom;   // distance to the mask's lower edge (< 0 = covered)
		float trim;
		if (mask_style == 3) {
			// half: upper face and scalp, edged across the nose and under the eyes, then sweeping
			// down past the ears to the nape
			bottom = 1.765 + 0.1 * min(hp.x, 0.07) - 0.45 * clamp(hp.x - 0.08, 0.0, 0.18) - z;
			cover = head * fill(max(bottom, -eye), px);
			trim = max(stroke(bottom + 0.0035, 0.0035, px), fill(eye - 0.0045, px));
		} else {
			float hang = atan(ax, -p.y);
			bottom = 1.572 + 0.03 * sin(hang) * sin(hang) - z;
			float hole = min(eye, mouth_hole);
			cover = (1.0 - arm) * smoothstep(0.25, 0.45, region.b) * fill(max(bottom, -hole), px);
			trim = max(fill(hole - 0.0045, px), stroke(bottom + 0.003, 0.003, px));
			if (mask_style == 1) {
				// classic: a centre stripe from a point on the forehead over the scalp to the nape
				float tip = p.y < 0.0 ? (1.83 + 2.4 * ax - z) * 0.385 : -1.0;
				trim = max(trim, fill(max(ax - 0.011, tip), px));
			} else {
				// wings: swept-back feathers from the outer corner of each eye over the temples,
				// longest along the top edge
				vec2 o = vec2(0.046, 1.801);
				float f = min(min(feather(hp, o, 0.62, 0.15, 0.012), feather(hp, o, 0.42, 0.135, 0.011)),
					min(feather(hp, o, 0.22, 0.115, 0.01), feather(hp, o, 0.03, 0.09, 0.009)));
				trim = max(trim, fill(f, px));
			}
		}
		mask_m = cover;
		col = mix(col, mix(mask_color, mask_trim, trim), mask_m);
	}

	float cloth = clamp(tight_m + upper_m + top_m + boot_m + knee_m + wrist_m + elbow_m + shirt_m + mask_m, 0.0, 1.0);
	rough = mix(rough, 0.55, paint);                // matte greasepaint
	rough = mix(rough, 0.28, plate);
	rough = mix(rough, 0.35, max(upper_m, top_m));  // shiny spandex
	rough = mix(rough, 0.55, boot_m + knee_m);
	rough = mix(rough, 0.3, mask_m);                // satin mask
	sss = mix(sss, 0.0, max(cloth, max(paint * 0.6, plate)));
	spec = mix(spec, 0.4, cloth);

	ALBEDO = col;
	ROUGHNESS = rough;
	METALLIC = 0.85 * plate * (1.0 - mask_m);
	SPECULAR = spec;
	SSS_STRENGTH = sss;
	RIM = rim_strength;
	RIM_TINT = 0.6;
	float edge = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	EMISSION = aura_color * aura * (edge * 6.0 + 0.15) + glow * (1.0 - mask_m);
}
