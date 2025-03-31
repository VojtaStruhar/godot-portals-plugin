if (clip_active && dot(clip_vertex_position - clip_point, clip_normal) < 0.0) {
	ALPHA = 0.0;
}