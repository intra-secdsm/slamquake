shader_type spatial;
// Eyeballs. Vertex color R = angle from the eye's forward axis / 90 degrees.

uniform vec3 iris_color : source_color = vec3(0.25, 0.4, 0.6);
uniform float iris_size = 0.38;
uniform float pupil_size = 0.15;

void fragment() {
	float a = COLOR.r;
	float aa = fwidth(a);
	float iris = 1.0 - smoothstep(iris_size - aa, iris_size + aa, a);
	float pupil = 1.0 - smoothstep(pupil_size - aa, pupil_size + aa, a);
	vec3 col = mix(vec3(0.92, 0.9, 0.86), iris_color * mix(0.7, 1.15, a / iris_size), iris);
	col = mix(col, vec3(0.02), pupil);
	ALBEDO = col;
	ROUGHNESS = 0.08;
	SPECULAR = 0.7;
}
