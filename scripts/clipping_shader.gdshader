shader_type spatial;
render_mode world_vertex_coords;

uniform vec3 clip_normal = vec3(1, 1, 0);
uniform vec3 clip_point = vec3(0, 0, 0);

varying vec3 vpos;

void vertex() {
	vpos = VERTEX;
}

void fragment() {
	ALBEDO = vec3(vpos);
	if (dot(vpos - clip_point, clip_normal) < 0.0) {
		discard;
	}
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
