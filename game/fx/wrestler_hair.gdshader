shader_type spatial;
// Stylized hair: base colour with fine strand streaks and a soft sheen.

uniform vec3 hair_color : source_color = vec3(0.15, 0.1, 0.06);

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	float streak = sin(local_pos.x * 420.0 + sin(local_pos.y * 60.0) * 2.0) * 0.5 + 0.5;
	ALBEDO = hair_color * mix(0.9, 1.08, streak);
	ROUGHNESS = 0.5;
	SPECULAR = 0.45;
	ANISOTROPY = 0.6;
	RIM = 0.3;
	RIM_TINT = 0.5;
}
