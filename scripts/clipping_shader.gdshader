shader_type spatial;

uniform vec3 clip_normal = vec3(1, 1, 0);
uniform vec3 clip_point = vec3(0, 0, 0);

varying vec3 vpos;

void vertex() {
	vpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	ALBEDO = vec3(vpos); // Just for show

	if (dot(vpos - clip_point, clip_normal) < 0.0) {
		ALPHA = 0.0;
	}
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
