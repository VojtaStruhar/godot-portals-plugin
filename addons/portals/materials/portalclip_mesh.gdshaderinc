#define PORTALCLIP_UNIFORMS \
instance uniform bool portal_clip_active = false;\
instance uniform vec3 portal_clip_point = vec3(0, 0, 0);\
instance uniform vec3 portal_clip_normal = vec3(0, 1, 0);\
varying vec3 portal_clip_vertex_position;\

#define PORTALCLIP_VERTEX \
portal_clip_vertex_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;\

#define PORTALCLIP_FRAGMENT \
if (portal_clip_active && dot(portal_clip_vertex_position - portal_clip_point, portal_clip_normal) < 0.0) ALPHA = 0.0;
