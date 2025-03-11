extends CompositorEffect
class_name PortalCompositorEffect

# Inputs to be set from the outside
@export var portal_texture: Texture2D  # The texture from the portal camera's SubViewport
@export var portal_corners: Array[Vector4] = [Vector4(0, 0, 0, 0), Vector4(1, 0, 0, 0), 
											  Vector4(1, 1, 0, 0), Vector4(0, 1, 0, 0)]  # Default quad

var rd: RenderingDevice
var shader: RID
var pipeline: RID
var uniform_set: RID
var portal_texture_uniform: RDUniform
var corners_uniform: RDUniform

func _init():
	# Enable the effect for post-transparent pass
	effect_callback_type = EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	# Set up the compute shader immediately
	setup_compute_shader()

func _notification(what):
	if what == NOTIFICATION_PREDELETE:  # Value = 1
		cleanup()

func setup_compute_shader():
	rd = RenderingServer.get_rendering_device()
	if not rd:
		push_error("No RenderingDevice available!")
		return

	# Load the compute shader code
	var shader_file = load("uid://b02i17c2x41fe")
	var shader_spirv = shader_file.get_spirv()
	shader = rd.shader_create_from_spirv(shader_spirv)
	pipeline = rd.compute_pipeline_create(shader)

	# Initial uniform set setup
	update_uniforms()

func update_uniforms():
	if not rd or not shader:
		return

	# Portal texture uniform
	portal_texture_uniform = RDUniform.new()
	portal_texture_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	portal_texture_uniform.binding = 1
	portal_texture_uniform.add_id(portal_texture.get_rid() if portal_texture else PlaceholderTexture2D.new().get_rid())

	# Portal corners uniform
	var corners_buffer = PackedFloat32Array()
	for corner in portal_corners:
		corners_buffer.append_array([corner.x, corner.y, corner.z, corner.w])
	var corners_bytes = corners_buffer.to_byte_array()
	var corners_buffer_rid = rd.storage_buffer_create(corners_bytes.size(), corners_bytes)
	corners_uniform = RDUniform.new()
	corners_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	corners_uniform.binding = 2
	corners_uniform.add_id(corners_buffer_rid)

	# Initial uniform set (without input image, added in _render_callback)
	uniform_set = rd.uniform_set_create([portal_texture_uniform, corners_uniform], shader, 0)

func _render_callback(p_effect_callback_type: int, p_render_data: RenderData):
	if not rd or p_effect_callback_type != EFFECT_CALLBACK_TYPE_POST_TRANSPARENT or not shader.is_valid():
		return

	# Get the render scene buffers
	var render_scene_buffers: RenderSceneBuffersRD = p_render_data.get_render_scene_buffers()
	if not render_scene_buffers:
		return

	# Get the render size
	var size = render_scene_buffers.get_internal_size()
	if size.x == 0 or size.y == 0:
		return

	# Calculate workgroup sizes
	var x_groups = (size.x - 1) / 8 + 1  # Matches local_size_x = 8 in shader
	var y_groups = (size.y - 1) / 8 + 1
	var z_groups = 1

	# Loop through views (for stereo rendering support)
	var view_count = render_scene_buffers.get_view_count()
	for view in range(view_count):
		# Get the RID for the color image (main viewport render target)
		var input_image = render_scene_buffers.get_color_layer(view)

		# Create the uniform for the main image
		var input_uniform = RDUniform.new()
		input_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
		input_uniform.binding = 0
		input_uniform.add_id(input_image)

		# Combine all uniforms into a cached uniform set
		var full_uniform_set = UniformSetCacheRD.get_cache(shader, 0, [
			input_uniform, 
			portal_texture_uniform, 
			corners_uniform
		])

		# Run the compute shader
		var compute_list = rd.compute_list_begin()
		rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
		rd.compute_list_bind_uniform_set(compute_list, full_uniform_set, 0)
		rd.compute_list_dispatch(compute_list, x_groups, y_groups, z_groups)
		rd.compute_list_end()

func cleanup():
	if rd:
		if uniform_set.is_valid():
			rd.free_rid(uniform_set)
		if shader.is_valid():
			rd.free_rid(shader)
		if pipeline.is_valid():
			rd.free_rid(pipeline)

# Public method to update portal data dynamically
func set_portal_data(texture: Texture2D, corners: Array[Vector4]):
	portal_texture = texture
	portal_corners = corners
	update_uniforms()
