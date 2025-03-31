/// World space point on the clip plane.
instance uniform vec3 clip_point = vec3(0, 0, 0);
/// Clipping plane normal. Doesn't have to be normalized.
instance uniform vec3 clip_normal = vec3(0, 1, 0);
/// Used to communicate the world vertex position to fragment shader.
varying vec3 clip_vertex_position;