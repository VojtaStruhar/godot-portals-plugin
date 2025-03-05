@tool
class_name Portal3D extends Node3D 

## Configurator node that manages the setup of a 3D portal.
##
## This node is a tool script that provides configuration options to the user. It's only purpose
## is to manage the portal setup in editor. During gameplay, it moves portal cameras around and
## provides API to interact with the portal system.

@export var portal_size: Vector2 = Vector2(2.0, 2.5):
	set = _on_portal_size_changed

## The width of the frame portal. Adjusts the near clip distance of the camera looking through THIS portal.
@export var portal_frame_width: float = 0.4

@export var exit_portal: Portal3D

# TODO: Make this optional, only display when the other's portal exit_portal is null.
@export_tool_button("Pair Portals?", "MeshInstance2D")
var _tb_pair_portals: Callable = func(): exit_portal.exit_portal = self

@export var player_camera: Camera3D

@export_group("Internals")

@export var portal_mesh: MeshInstance3D

## Camera that looks through the exit portal. If exit portal is null, the camera doesn't exist either.
@export var portal_camera: Camera3D
@export 
var portal_viewport: SubViewport
@export_tool_button("Debug Button", "Popup") 
var _tb_debug_action: Callable = _debug_action

func _debug_action() -> void:
	print("Number of children: " + str(get_child_count(true)))
	

# ------------ IN-EDITOR CONFIGURATION STUFF --------------

const PORTAL_SHADER = preload("uid://bhdb2skdxehes")

## _ready(), but only in editor.
func _editor_ready() -> void:
	print(name + ": _editor_ready")
	if portal_mesh == null:
		portal_mesh = MeshInstance3D.new()
		portal_mesh.name = "PortalMeshInstance"
		var p = PlaneMesh.new()
		p.orientation = PlaneMesh.FACE_Z
		p.size = portal_size
		portal_mesh.mesh = p
		
		add_child(portal_mesh, true)
		portal_mesh.owner = self.owner  # Owner should be the scene root.
		
		self.lock_node(portal_mesh)


func _on_portal_size_changed(new_size: Vector2) -> void:
	portal_size = new_size
	if portal_mesh == null:
		push_error("Portal should never be null. Setting size to '" + str(new_size) + "' failed.")
		return
	
	var p = portal_mesh.mesh as PlaneMesh
	p.size = new_size

# ------------- GAMEPLAY RUNTIME STUFF ----------------

func _ready() -> void:
	if Engine.is_editor_hint():
		_editor_ready.call_deferred()
		return
	
	if player_camera:
		# FIXME: This WILL fail if the root does a SubViewportContainer thing. Maybe.
		# It's probably best to assign this manually.
		player_camera = get_viewport().get_camera_3d()
	
	_setup_cameras()
	
	var mat: ShaderMaterial = ShaderMaterial.new()
	print("Portal shader: ", PORTAL_SHADER)
	mat.shader = PORTAL_SHADER
	mat.set_shader_parameter("albedo", portal_viewport.get_texture())
	portal_mesh.material_override = mat


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	if portal_camera != null && player_camera != null && exit_portal != null:
		var player_to_home = portal_mesh.global_transform.affine_inverse() * player_camera.global_transform
		var flipped = player_to_home.rotated(Vector3.UP, PI)
		var relative_to_target = exit_portal.portal_mesh.global_transform * flipped
		
		portal_camera.global_transform = relative_to_target
		portal_camera.near = _calculate_near_plane()


func _calculate_near_plane() -> float:
	var _mesh_aabb: AABB = exit_portal.portal_mesh.get_aabb()
	
	var corner_1:Vector3 = exit_portal.to_global(Vector3(_mesh_aabb.position.x, _mesh_aabb.position.y, 0))
	var corner_2:Vector3 = exit_portal.to_global(Vector3(_mesh_aabb.position.x + _mesh_aabb.size.x, _mesh_aabb.position.y, 0))
	var corner_3:Vector3 = exit_portal.to_global(Vector3(_mesh_aabb.position.x + _mesh_aabb.size.x, _mesh_aabb.position.y + _mesh_aabb.size.y, 0))
	var corner_4:Vector3 = exit_portal.to_global(Vector3(_mesh_aabb.position.x, _mesh_aabb.position.y + _mesh_aabb.size.y, 0))

	# Calculate the distance along the exit camera forward vector at which each of the portal corners projects
	var camera_forward:Vector3 = -portal_camera.global_transform.basis.z.normalized()

	var d_1:float = (corner_1 - exit_portal.global_position).dot(camera_forward)
	var d_2:float = (corner_2 - exit_portal.global_position).dot(camera_forward)
	var d_3:float = (corner_3 - exit_portal.global_position).dot(camera_forward)
	var d_4:float = (corner_4 - exit_portal.global_position).dot(camera_forward)
	
	# The near clip distance is the shortest distance which still contains all the corners
	return max(0.01, min(d_1, d_2, d_3, d_4) - exit_portal.portal_frame_width)


func _setup_cameras() -> void:
	if Engine.is_editor_hint(): 
		push_error(name + "._setup_cameras: This should never run in editor!")
		return
	
	if portal_camera:
		print_debug("[%s] Freeing existing portal camera" % name)
		portal_camera.queue_free()
		portal_camera = null
	if portal_viewport:
		print_debug("[%s] Freeing existing subviewport" % name)
		portal_viewport.queue_free()
		portal_viewport = null
	
	if exit_portal != null:
		portal_viewport = SubViewport.new()
		portal_viewport.name = self.name + "_SubViewport"
		portal_viewport.size = Vector2(
			ProjectSettings.get_setting("display/window/size/viewport_width"),
			ProjectSettings.get_setting("display/window/size/viewport_height")
		)
		exit_portal.add_child(portal_viewport, true)
		portal_viewport.owner = self.owner
		
		# Disable tonemapping on portal cameras
		var adjusted_env: Environment = player_camera.environment.duplicate() \
			if player_camera.environment \
			else player_camera.get_world_3d().environment.duplicate()
		adjusted_env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
		adjusted_env.tonemap_exposure = 1
		
		portal_camera = Camera3D.new()
		portal_camera.name = self.name + "_Camera3D"
		portal_camera.environment = adjusted_env
		portal_viewport.add_child(portal_camera, true)
		portal_camera.owner = self.owner
		portal_camera.global_position = exit_portal.global_position
		

# ------------------- UTILS ---------------------------

static func lock_node(node: Node3D) -> void:
	node.set_meta("_edit_lock_", true)
