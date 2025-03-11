#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

// Main viewport image (read/write)
layout(rgba8, binding = 0) uniform image2D main_image;

// Portal texture (read-only)
layout(rgba8, binding = 1) uniform image2D portal_texture;

// Portal corners (screen-space, 0-1)
layout(std430, binding = 2) buffer Corners {
    vec4 corners[4];
};

// Point-in-quad test using barycentric coordinates
bool point_in_quad(vec2 p, vec4[4] quad) {
    vec2 v0 = quad[0].xy;
    vec2 v1 = quad[1].xy;
    vec2 v2 = quad[2].xy;
    vec2 v3 = quad[3].xy;

    vec2 a = v1 - v0;
    vec2 b = v3 - v0;
    vec2 c = p - v0;

    float d00 = dot(a, a);
    float d01 = dot(a, b);
    float d11 = dot(b, b);
    float d20 = dot(c, a);
    float d21 = dot(c, b);

    float denom = d00 * d11 - d01 * d01;
    float v = (d11 * d20 - d01 * d21) / denom;
    float w = (d00 * d21 - d01 * d20) / denom;
    float u = 1.0 - v - w;

    return (u >= 0.0 && v >= 0.0 && w >= 0.0 && u <= 1.0 && v <= 1.0 && w <= 1.0);
}

void main() {
    ivec2 coords = ivec2(gl_GlobalInvocationID.xy);
    ivec2 image_size = imageSize(main_image);

    // Skip if out of bounds
    if (coords.x >= image_size.x || coords.y >= image_size.y) {
        return;
    }

    // Convert to normalized screen-space coordinates (0-1)
    vec2 uv = vec2(coords) / vec2(image_size);

    // Check if this pixel is inside the portal quad
    if (point_in_quad(uv, corners)) {
        // Map UV to portal texture integer coordinates
        ivec2 portal_size = imageSize(portal_texture);
        vec2 portal_uv = (uv - corners[0].xy) / (corners[2].xy - corners[0].xy); // Normalized UV
        ivec2 portal_coords = ivec2(portal_uv * vec2(portal_size)); // Convert to pixel coords

        // Clamp to valid range
        portal_coords = clamp(portal_coords, ivec2(0), portal_size - 1);

        // Read from portal texture
        vec4 portal_color = imageLoad(portal_texture, portal_coords);

        // Write to main image
        imageStore(main_image, coords, portal_color);
    }
}