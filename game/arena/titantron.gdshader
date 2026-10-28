shader_type canvas_item;
// Titantron backdrop: one animated neon motif per wrestler (Roster.MOTIFS, in that order),
// tinted in their colours, with scanlines. Everything but the grid keeps the band behind the
// caption a little darker so the name always reads.
//   0 grid: synthwave sun over a scrolling grid     1 storm: dark clouds and lightning
//   2 bolts: zig-zag bolts and crackling arcs       3 steel: riveted plates, sweeping sheen
//   4 feathers: neon wings fanning open and shut    5 checker: a turning, sliding chessboard
//   6 waves: curling neon breakers                  7 circuit: traces with travelling pulses
//   8 stars: warp-speed starfield with bursts

uniform vec4 tint : source_color = vec4(1.0, 0.17, 0.84, 1.0);
uniform vec4 tint2 : source_color = vec4(0.0, 0.9, 1.0, 1.0);
uniform int motif = 0;
uniform float energy = 1.0;

const float ASPECT = 1.7778;
const float CAPTION_Y = 0.07;      // centre of the title, in p units (see fragment)


float hash11(float p) {
	p = fract(p * 0.1031);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
}

float hash21(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), u.x),
			mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p = p * 2.03 + vec2(17.1, 9.2);
		a *= 0.5;
	}
	return v;
}

// A sharp-cornered random walk (lightning paths), roughly -0.5..0.5.
float jag(float x, float seed) {
	float v = 0.0;
	float a = 0.55;
	for (int i = 0; i < 4; i++) {
		float c = floor(x);
		v += a * (mix(hash11(c + seed), hash11(c + 1.0 + seed), fract(x)) - 0.5);
		x = x * 2.3 + 0.37;
		seed += 13.7;
		a *= 0.5;
	}
	return v;
}

// A neon line: a bright core `w` wide with a soft halo.
float neon(float d, float w) {
	d = abs(d);
	return smoothstep(w, w * 0.25, d) + 0.5 * exp(-d / (w * 3.5));
}

mat2 rot(float a) {
	return mat2(vec2(cos(a), sin(a)), vec2(-sin(a), cos(a)));
}


vec3 grid(vec2 uv, float t) {
	float horizon = 0.55;
	vec3 col = mix(vec3(0.02, 0.0, 0.05), tint.rgb * 0.35, smoothstep(0.0, horizon, uv.y));
	if (uv.y > horizon) {
		float d = (uv.y - horizon) / (1.0 - horizon);
		vec2 g = vec2((uv.x - 0.5) / (d + 0.05), 1.0 / (d + 0.05) - t * 2.0);
		float lines = max(step(0.92, fract(g.x * 3.0)), step(0.9, fract(g.y * 0.5)));
		col = mix(vec3(0.02, 0.0, 0.06), tint2.rgb, lines * d * 1.5);
	}
	// sun
	vec2 sc = vec2(0.5, horizon - 0.12);
	float sun = smoothstep(0.2, 0.19, distance(uv * vec2(1.78, 1.0), sc * vec2(1.78, 1.0)));
	float bands = step(0.5, fract((uv.y - sc.y) * 28.0 + t * 0.5)) + step(uv.y, sc.y);
	col = mix(col, mix(tint.rgb, vec3(1.0, 0.85, 0.2), 1.0 - uv.y * 1.4), sun * min(bands, 1.0));
	return col;
}


vec3 storm(vec2 p, float t) {
	// most 0.9 s slots get lightning at a random moment, flickering twice; some are
	// sheet lightning inside the clouds, the rest strike down
	float slot = floor(t / 0.9);
	float dt = t - slot * 0.9 - (0.05 + 0.45 * hash11(slot * 3.17));
	float flash = 0.0;
	if (hash11(slot * 7.31) < 0.85 && dt > 0.0) {
		flash = exp(-dt * 12.0) + 0.8 * step(0.1, dt) * exp(-(dt - 0.1) * 7.0);
	}
	vec2 at = vec2((hash11(slot * 1.93) - 0.5) * 1.4, 0.18 + 0.22 * hash11(slot * 2.7));
	// billowing clouds, brighter on the tops of the billows
	vec2 q = vec2(p.x, p.y * 1.5);
	vec2 w = vec2(fbm(q * 1.4 + vec2(t * 0.03, 0.0)), fbm(q * 1.4 + vec2(5.2, 1.3) - vec2(t * 0.025, 0.0)));
	vec2 cq = q * 2.3 + w * 1.5 + vec2(t * 0.07, 0.0);
	float c = fbm(cq);
	float lit = clamp((c - fbm(cq - vec2(0.0, 0.06))) * 9.0, 0.0, 1.0);
	float dens = smoothstep(0.3, 0.7, c);
	vec3 col = mix(tint.rgb * 0.13 + vec3(0.01, 0.01, 0.03), vec3(0.008, 0.005, 0.02), smoothstep(-0.5, 0.3, p.y));
	col = mix(col, tint.rgb * 0.05 + vec3(0.01), dens);
	col += dens * (tint.rgb * 0.22 + tint2.rgb * 0.12) * lit;
	float near = exp(-length((p - at) * vec2(1.0, 1.6)) * 3.0);
	col += (0.25 + dens) * tint2.rgb * flash * (0.15 + 1.8 * near);
	if (flash > 0.01 && hash11(slot * 5.1) > 0.3) {
		float x = at.x + jag(p.y * 4.5, slot) * 0.3;
		float bolt = (neon(p.x - x, 0.007) + 0.4 * exp(-abs(p.x - x) / 0.05)) * step(p.y, at.y);
		// a fork splits off part-way down
		float fy = at.y - 0.12 - 0.2 * hash11(slot + 5.0);
		float side = hash11(slot + 9.0) < 0.5 ? -1.0 : 1.0;
		float fx = x + (fy - p.y) * side * 0.6 + jag(p.y * 9.0, slot + 3.0) * 0.1;
		bolt += 0.7 * neon(p.x - fx, 0.0035) * step(p.y, fy) * smoothstep(fy - 0.35, fy, p.y);
		col += bolt * flash * mix(tint2.rgb, vec3(1.0), 0.6) * 1.8;
	}
	return col;
}


// Signed distance to a lightning-bolt glyph one unit tall, centred on the origin.
float sd_bolt(vec2 p) {
	vec2 v[7] = {vec2(-0.05, 0.5), vec2(0.3, 0.5), vec2(0.05, 0.08), vec2(0.28, 0.08),
			vec2(-0.25, -0.5), vec2(-0.02, -0.06), vec2(-0.25, -0.06)};
	float d = dot(p - v[0], p - v[0]);
	float s = 1.0;
	for (int i = 0; i < 7; i++) {
		int j = i == 0 ? 6 : i - 1;
		vec2 e = v[j] - v[i];
		vec2 w = p - v[i];
		vec2 b = w - e * clamp(dot(w, e) / dot(e, e), 0.0, 1.0);
		d = min(d, dot(b, b));
		bvec3 c = bvec3(p.y >= v[i].y, p.y < v[j].y, e.x * w.y > e.y * w.x);
		if (all(c) || all(not(c))) {
			s = -s;
		}
	}
	return s * sqrt(d);
}

vec3 bolts(vec2 p, float t) {
	float tick = floor(t * 14.0);              // the arcs re-form 14 times a second
	vec3 col = mix(vec3(0.005, 0.01, 0.03), tint.rgb * 0.07, exp(-length(p * vec2(0.7, 1.4)) * 1.5));
	// faint charged stripes drifting across
	col += tint.rgb * 0.035 * smoothstep(0.6, 1.0, sin((p.x + p.y * 0.6) * 40.0 - t * 3.0));
	// a big bolt either side of the name
	vec2 q = vec2(abs(p.x) - 0.66, p.y - 0.03) / 0.8;
	q.x *= sign(p.x);                          // mirrored on the left
	float flick = 0.8 + 0.2 * hash11(tick + step(0.0, p.x) * 50.0);
	float d = sd_bolt(q) * 0.8;
	col += (tint.rgb * 0.22 + tint2.rgb * 0.08) * smoothstep(0.004, -0.004, d) * flick;
	col += mix(tint2.rgb, vec3(1.0), 0.3) * neon(d, 0.005) * flick;
	// crackling arcs above and below the name, ending on the bolts
	for (int i = 0; i < 4; i++) {
		float fi = float(i);
		float y0 = i < 2 ? 0.27 + fi * 0.1 : -0.2 - (fi - 2.0) * 0.12;
		float seed = tick * 7.1 + fi * 31.0;
		float y = y0 + jag(p.x * 3.2 + fi * 4.0, seed) * 0.09 + sin(p.x * 3.0 + t * 2.0 + fi) * 0.02;
		float live = step(0.35, hash11(seed));   // each arc is off now and then
		float ends = smoothstep(0.75, 0.6, abs(p.x));
		col += live * ends * neon(p.y - y, 0.0028) * mix(tint2.rgb, vec3(1.0), 0.5) * (0.6 + 0.4 * hash11(seed + 1.0));
	}
	return col;
}


vec3 steel(vec2 p, float t) {
	vec2 cs = vec2(0.44, 0.34);                // plate size
	vec2 g = p / cs;
	float row = floor(g.y);
	g.x += mod(row, 2.0) * 0.5;                // staggered rows
	vec2 cell = floor(g);
	vec2 f = fract(g);
	float id = hash21(cell);
	vec2 lp = f * cs;                          // position on the plate
	// brushed metal
	float brush = noise(vec2(g.x * 4.0 + id * 10.0, g.y * 150.0)) * 0.6 + noise(vec2(g.x * 11.0, g.y * 330.0)) * 0.4;
	vec3 col = vec3(0.12, 0.125, 0.14) * (0.8 + 0.35 * id) * (0.85 + 0.3 * brush);
	// bevels lit from the top left, dark seams glowing with light from behind
	vec2 e = min(lp, cs - lp);
	float edge = min(e.x, e.y);
	float bev = smoothstep(0.022, 0.0, edge);
	float lit = (lp.y > cs.y - 0.022 || lp.x < 0.022) ? 1.0 : -1.0;
	col *= 1.0 + bev * lit * 0.55;
	float seam = smoothstep(0.006, 0.002, edge);
	col = mix(col, vec3(0.01), seam);
	col += tint.rgb * 0.5 * exp(-edge / 0.006) * (0.75 + 0.25 * sin(t * 2.0 + id * 6.0));
	// rivets along the plate edges
	float sp = 0.072;
	float inset = 0.03;
	vec2 r1 = vec2(clamp(inset + round((lp.x - inset) / sp) * sp, inset, cs.x - inset), lp.y < cs.y * 0.5 ? inset : cs.y - inset);
	vec2 r2 = vec2(lp.x < cs.x * 0.5 ? inset : cs.x - inset, clamp(inset + round((lp.y - inset) / sp) * sp, inset, cs.y - inset));
	vec2 rv = length(lp - r1) < length(lp - r2) ? lp - r1 : lp - r2;
	float rr = length(rv) / 0.0105;
	if (rr < 1.0) {
		vec3 n = vec3(rv / 0.0105, sqrt(1.0 - rr * rr));
		float l = clamp(dot(n, normalize(vec3(-0.5, 0.6, 0.65))), 0.0, 1.0);
		col = vec3(0.07, 0.075, 0.085) + vec3(0.32) * l * l + tint2.rgb * 0.25 * pow(l, 12.0);
	} else {
		col *= 1.0 - 0.5 * smoothstep(1.6, 1.0, rr) * step(0.0, -rv.y + rv.x * 0.3);   // drop shadow
	}
	// a sheen sweeping across every few seconds
	float pos = fract(t / 3.6) * 3.6 - 1.6;
	float sheen = exp(-pow((p.x + p.y * 0.55 - pos) * 4.5, 2.0));
	col += sheen * (vec3(0.22) + tint2.rgb * 0.25) * (0.55 + brush * 0.7);
	return col;
}


vec3 feathers(vec2 p, float t) {
	vec3 col = mix(vec3(0.004, 0.012, 0.01), tint.rgb * 0.09, smoothstep(-0.5, 0.5, p.y));
	// two wings spread out from under the name, rising and falling about the shoulder
	float flap = sin(t * 1.5);
	vec2 sh = vec2(0.06, -0.16);
	vec2 q = vec2(abs(p.x), p.y) - sh;
	q = rot(flap * 0.07) * q;
	for (int k = 0; k < 9; k++) {              // from the body out; outer feathers lie on top
		float fi = float(k) / 8.0;
		vec2 base = vec2(fi * 0.72, fi * 0.36 + sin(fi * 3.1416) * 0.05);  // along the wing's leading edge
		float ang = radians(-100.0 + fi * 88.0 + flap * 7.0 * fi);        // hanging down, out at the tip
		float len = 0.2 + fi * 0.3;
		vec2 dir = vec2(cos(ang), sin(ang));
		vec2 fq = q - base;
		float u = dot(fq, dir) / len;          // along the feather, 0..1
		float v = dot(fq, vec2(-dir.y, dir.x));
		float w = (0.032 + 0.03 * fi) * sqrt(max(0.0, 1.0 - pow(u, 6.0))) * smoothstep(0.0, 0.3, u);
		float de = abs(v) - w;
		if (u > 0.0 && u < 1.0 && de < 0.0) {
			float barbs = 0.65 + 0.35 * sin((u * len - abs(v) * 0.8) * 190.0);
			float run = exp(-pow((u - fract(t * 0.6 + fi * 0.4)) * 6.0, 2.0));   // light running out
			col = mix(tint.rgb * 0.22, tint2.rgb * 0.4, u) * barbs + tint2.rgb * 0.3 * run;
		}
		float rim = neon(de, 0.0028) * step(0.0, u) * step(u, 1.0);
		float shaft = neon(v, 0.0018) * step(0.0, u) * step(u, 0.95);
		col += (rim + 0.5 * shaft) * mix(tint2.rgb, vec3(1.0), 0.3) * 0.8;
	}
	// the leading edge of each wing
	vec2 lq = q;
	float edge = lq.y - (lq.x / 0.72 * 0.36 + sin(clamp(lq.x / 0.72, 0.0, 1.0) * 3.1416) * 0.05);
	col += neon(edge, 0.004) * step(0.0, lq.x) * step(lq.x, 0.72) * mix(tint2.rgb, vec3(1.0), 0.4);
	return col;
}


vec3 checker(vec2 p, float t) {
	// a board seen from above at an angle, turning slowly and sliding past
	float depth = 1.0 / (1.0 - p.y * 0.95);
	vec2 b = vec2(p.x * depth, depth * 1.3) * rot(t * 0.1) + vec2(t * 0.2, t * 0.32);
	vec2 sq = b * 2.6;
	vec2 cell = floor(sq);
	vec2 f = fract(sq);
	float light = mod(cell.x + cell.y, 2.0);
	vec2 e = min(f, 1.0 - f);
	float edge = min(e.x, e.y) / (fwidth(sq.x) + fwidth(sq.y) + 1e-4);
	vec3 col = mix(vec3(0.012, 0.01, 0.03) + tint2.rgb * 0.03, tint.rgb * 0.38, light);
	col *= 0.85 + 0.15 * hash21(cell);
	col += tint2.rgb * 0.9 * neon(edge, 1.2) * 0.35;
	// glints running across the white squares
	float glint = exp(-pow((f.x + f.y - fract(t * 0.6 + hash21(cell) * 3.0) * 6.0 + 2.0) * 3.0, 2.0));
	col += light * glint * tint2.rgb * 0.25;
	return col * mix(1.0, 0.3, smoothstep(1.1, 2.0, depth));   // fades into the distance
}


vec3 waves(vec2 p, float t) {
	vec3 col = mix(tint.rgb * 0.16, vec3(0.0, 0.006, 0.025), smoothstep(-0.1, 0.5, p.y));
	col += tint.rgb * 0.3 * exp(-pow(p.y * 8.0, 2.0)) * smoothstep(1.0, 0.0, abs(p.x));   // glow on the horizon
	for (int L = 0; L < 3; L++) {              // back to front
		float fl = float(L);
		float scale = 0.5 + fl * 0.2;          // wavelength
		float base = -0.1 - fl * 0.13;         // water level
		float amp = 0.05 + fl * 0.022;
		float shift = t * (0.07 + fl * 0.05) + fl * 0.37;
		// curl each crest forward with a swirl about a point just under it
		float n = round(p.x / scale - shift);
		float R = amp * 1.5;
		vec2 c = vec2((n + shift) * scale + R * 0.25, base + amp - R * 0.55);
		vec2 cq = p - c;
		vec2 pw = c + rot(3.4 * exp(-dot(cq, cq) / (R * R))) * cq;
		float ph = 6.2832 * (pw.x / scale - shift);
		float y = base + amp * cos(ph);
		float d = (pw.y - y) / sqrt(1.0 + pow(amp * 6.2832 / scale * sin(ph), 2.0));
		vec3 ink = mix(tint.rgb, tint2.rgb, 0.3 + 0.3 * fl);
		if (d < 0.0) {
			col = mix(ink * (0.12 + 0.05 * fl), vec3(0.0, 0.005, 0.02), clamp(-d / 0.18, 0.0, 1.0));
		}
		col += neon(d, 0.0032) * mix(ink, vec3(1.0), 0.25) * (0.6 + 0.2 * fl);
		// spray glinting off the crests
		float sp = hash21(floor(p * 80.0) + fl * 7.0);
		col += step(0.97, sp) * smoothstep(0.035, 0.0, abs(d)) * vec3(0.9) * (0.5 + 0.5 * sin(t * 9.0 + sp * 40.0));
	}
	return col;
}


vec3 circuit(vec2 p, float t) {
	vec3 col = vec3(0.006, 0.012, 0.014) + tint.rgb * 0.025;
	// a faint dotted board grid
	vec2 dg = fract(p * 40.0) - 0.5;
	col += tint.rgb * 0.05 * smoothstep(0.12, 0.0, length(dg));
	// buses of four traces in bands, jogging up or down at 45 degrees now and then
	float bh = 0.165;
	float band = floor(p.y / bh);
	float yc = (band + 0.5) * bh;
	float hb = hash11(band * 3.7 + 1.0);
	float dir = hb < 0.5 ? 1.0 : -1.0;
	float per = 0.46;
	float xs = p.x + hb * 3.0;
	float k = floor(xs / per);
	float fx = xs - k * per;
	float jog = (hash21(vec2(k, band)) < 0.5 ? -1.0 : 1.0) * 0.035;
	float x1 = 0.05 + 0.12 * hash21(vec2(k, band + 9.0));
	float x2 = x1 + 0.1 + 0.12 * hash21(vec2(k + 3.0, band));
	float ramp1 = clamp((fx - x1) / 0.035, 0.0, 1.0);
	float ramp2 = clamp((fx - x2) / 0.035, 0.0, 1.0);
	float off = jog * (ramp1 - ramp2);
	float slanted = (ramp1 > 0.0 && ramp1 < 1.0) || (ramp2 > 0.0 && ramp2 < 1.0) ? 0.7071 : 1.0;
	for (int i = 0; i < 4; i++) {
		float fi = float(i);
		float ty = yc + (fi - 1.5) * 0.024 + off;
		float d = (p.y - ty) * slanted;
		float present = step(0.18, hash21(vec2(k * 3.0 + fi, band)));   // some traces stop at a pad
		float ph = fract(xs * dir * 1.3 - t * 0.55 + hash11(band * 7.0 + fi) + k * 0.31);
		float pulse = exp(-pow((ph - 0.5) * 22.0, 2.0));
		col += present * neon(d, 0.0028) * mix(tint.rgb * 0.45, mix(tint2.rgb, vec3(1.0), 0.4) * 1.6, pulse);
		// pads where a trace ends
		float padx = (1.0 - present) * (x1 + 0.03) + present * 9.0;
		vec2 pq = vec2(fx - padx, p.y - ty);
		col += neon(length(pq) - 0.009, 0.0025) * tint2.rgb * 0.8;
	}
	// chips between the buses
	vec2 cc = vec2(floor((p.x + 2.0) / 0.38), band);
	if (hash21(cc + 4.0) < 0.35) {
		vec2 cp = vec2(mod(p.x + 2.0, 0.38) - 0.19, p.y - (band + 1.0) * bh);
		vec2 ch = vec2(0.07, 0.022);
		vec2 dd = abs(cp) - ch;
		float body = max(dd.x, dd.y);
		col = mix(col, vec3(0.03, 0.03, 0.04), smoothstep(0.002, 0.0, body));
		col += tint.rgb * 0.5 * neon(body, 0.002);
		float pins = step(abs(cp.x), ch.x - 0.008) * step(0.5, fract(cp.x * 70.0)) * step(abs(abs(cp.y) - ch.y - 0.006), 0.006);
		col += pins * tint2.rgb * 0.5;
	}
	return col;
}


vec3 stars(vec2 p, float t) {
	vec3 col = mix(vec3(0.004, 0.0, 0.02), tint.rgb * 0.06, exp(-length(p) * 2.0));
	float n = fbm(p * 2.2 + vec2(t * 0.02, 0.0));
	col += tint.rgb * 0.12 * smoothstep(0.45, 0.85, n) + tint2.rgb * 0.06 * smoothstep(0.62, 0.9, n);
	// warp-speed starfield: layers rushing out from the middle, streaking as they near
	vec2 out_dir = normalize(p + vec2(1e-4));
	for (int i = 0; i < 4; i++) {
		float fi = float(i);
		float z = fract(fi * 0.25 + t * 0.12);
		float scale = mix(11.0, 0.9, z);
		float fade = smoothstep(0.0, 0.3, z) * smoothstep(1.0, 0.8, z);
		vec2 sp = p * scale + fi * 7.3;
		vec2 cell = floor(sp);
		vec2 d = fract(sp) - 0.5 - (hash22(cell + fi * 31.0) - 0.5) * 0.7;
		float bright = hash21(cell * 1.7 + fi);
		vec2 dd = vec2(dot(d, out_dir) / (1.0 + z * 3.0), dot(d, vec2(-out_dir.y, out_dir.x)));
		float s = smoothstep(0.045, 0.0, length(dd)) + 0.3 * exp(-length(dd) * 25.0);
		col += s * step(0.4, bright) * fade * mix(vec3(1.0), tint2.rgb, bright) * (0.8 + 0.4 * sin(t * 7.0 + bright * 30.0));
	}
	// bursts: two staggered slots, each popping somewhere new above or below the name
	for (int k = 0; k < 2; k++) {
		float tt = t + float(k) * 0.65;
		float slot = floor(tt / 1.3);
		float age = tt - slot * 1.3;
		vec2 h = hash22(vec2(slot, float(k) * 13.0 + 1.0));
		vec2 c = vec2((h.x - 0.5) * 1.5, h.y < 0.5 ? 0.3 + h.y * 0.3 : -0.18 - (h.y - 0.5) * 0.5);
		vec2 q = p - c;
		float r = length(q);
		float fade = exp(-age * 2.4);
		float ring = neon(r - 0.22 * (1.0 - exp(-age * 4.0)), 0.004) * fade + exp(-r * 9.0) * fade * 0.25;
		float flare = (exp(-abs(q.y) * 260.0) * exp(-abs(q.x) * 7.0) + exp(-abs(q.x) * 260.0) * exp(-abs(q.y) * 7.0))
				* exp(-age * 3.0);
		float core = exp(-r * 35.0) * exp(-age * 4.0);
		// sparks flying out
		float a = atan(q.y, q.x);
		float ray = floor(a / 6.2832 * 14.0 + 0.5);
		float spark_r = age * (0.25 + 0.12 * hash11(ray + slot));
		vec2 sc = vec2(cos(ray / 14.0 * 6.2832), sin(ray / 14.0 * 6.2832)) * spark_r;
		float spark = exp(-length(q - sc) * 90.0) * fade;
		col += ring * tint.rgb * 2.5 + (flare + core) * mix(tint2.rgb, vec3(1.0), 0.6) * 2.0 + spark * tint2.rgb * 3.0;
	}
	return col;
}


void fragment() {
	vec2 uv = UV;
	vec2 p = vec2((uv.x - 0.5) * ASPECT, 0.5 - uv.y);    // centred, y up, |y| <= 0.5
	float t = TIME;
	vec3 col;
	if (motif == 1) {
		col = storm(p, t);
	} else if (motif == 2) {
		col = bolts(p, t);
	} else if (motif == 3) {
		col = steel(p, t);
	} else if (motif == 4) {
		col = feathers(p, t);
	} else if (motif == 5) {
		col = checker(p, t);
	} else if (motif == 6) {
		col = waves(p, t);
	} else if (motif == 7) {
		col = circuit(p, t);
	} else if (motif == 8) {
		col = stars(p, t);
	} else {
		col = grid(uv, t);
	}
	if (motif != 0) {
		col *= 1.0 - 0.4 * exp(-pow((p.y - CAPTION_Y) / 0.14, 2.0)) * smoothstep(1.0, 0.45, abs(p.x));
	}
	col *= 0.85 + 0.15 * sin(uv.y * 600.0);
	COLOR = vec4(col * energy, 1.0);
}
