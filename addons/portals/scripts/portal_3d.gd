@tool
class_name Portal3D extends Node3D 

## Configurator node that manages the setup of a 3D portal.
##
## This node is a tool script that provides configuration options to the user. It's only purpose
## is to manage the portal setup in editor. During gameplay, it moves portal cameras around and
## provides API to interact with the portal system.

@export var portal_size: Vector2 = Vector2(2.0, 2.5):
	set(v):
		portal_size = v
		if caused_by_user_interaction(): _on_portal_size_changed()

## The width of the frame portal. Adjusts the near clip distance of the camera looking through THIS portal.
@export_range(0.0, 10.0, 0.01) var portal_frame_width: float = 0.0

@export var exit_portal: Portal3D:
	set(v):
		exit_portal = v
		update_configuration_warnings()

# TODO: Make this optional, only display when the other's portal exit_portal is null.
@export_tool_button("Pair Portals?", "SliderJoint3D")
var _tb_pair_portals: Callable = _editor_pair_portals

@export var player_camera: Camera3D

@export var portals_see_portals: bool = false

@export_flags_3d_render var portal_render_layer: int = 1 << 7:
	set(v):
		portal_render_layer = v
		if caused_by_user_interaction():
			portal_mesh.layers = v

@export var is_teleport: bool = false:
	set(v):
		is_teleport = v
		if caused_by_user_interaction(): _editor_setup_teleport()

@export_flags_3d_physics var teleport_collision_mask: int = 0


## These thing don't need to be exported. I just want to see them in editor.
@export_group("Internals")

@export var portal_thickness: float = 0.1:
	set(v):
		portal_thickness = v
		if caused_by_user_interaction(): _on_portal_size_changed()

@export var portal_mesh: MeshInstance3D

@export var teleport_area: Area3D
@export var teleport_collision: CollisionShape3D

## Camera that looks through the exit portal. If exit portal is null, the camera doesn't exist either.
@export var portal_camera: Camera3D
@export var portal_viewport: SubViewport

## When teleporting, the portal checks if the teleported object is less than [b]this[/b] near.
## Prevents false negatives when multiple portals are on top of each other.
@export var _teleport_tolerance: float = 0.2

## These physics bodies are being watched by the portal. The value in dictionary
## is their dot product from last frame. As soon as the dot product changes signs,
## the body crossed the portal and should be teleported.
var watchlist_bodies: Dictionary[Node3D, float] = {}

@export_tool_button("Debug Button", "Popup") 
var _tb_debug_action: Callable = _debug_action

@export_tool_button("Rerun Setup", "History")
var _tb_rerun_setup: Callable = _editor_rerun_setup

func _debug_action() -> void:
	print("Number of children: " + str(get_child_count(true)))
	print("Node metadata: ")
	for meta in get_meta_list():
		print("  - " + meta + ": " + str(get_meta(meta)))
	

#region Editor Configuration Stuff

const PORTAL_SHADER = preload("uid://bhdb2skdxehes")

func _editor_rerun_setup():
	assert(Engine.is_editor_hint())
	
	if portal_mesh:
		print("[%s] Recreating portal meshes" % name)
		portal_mesh.name += "__DELETING"
		portal_mesh.queue_free()
		portal_mesh = null
	
	_editor_ready()

## _ready(), but only in editor.
func _editor_ready() -> void:
	add_to_group("portals", true)
	
	process_priority = 100
	process_physics_priority = 100
	
	if portal_mesh == null:
		portal_mesh = MeshInstance3D.new()
		portal_mesh.name = self.name + "_Mesh"
		portal_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		portal_mesh.layers = portal_render_layer
		
		var p := BoxMesh.new()
		p.size = Vector3(portal_size.x, portal_size.y, portal_thickness)
		portal_mesh.mesh = p
		
		var mat: ShaderMaterial = ShaderMaterial.new()
		mat.shader = PORTAL_SHADER
		portal_mesh.material_override = mat
		
		add_child_in_editor(self, portal_mesh)
	
	self.group_node(self)

func _editor_pair_portals():
	if exit_portal == null:
		push_error("[%s] _editor_pair_portals called, but 'exit_portal' is null" % name)
		return
	
	exit_portal.exit_portal = self

func _editor_setup_teleport():
	print("[%s] _editor_setup_teleport" % name)
	if is_teleport == false:
		teleport_area.queue_free()
		teleport_area = null
		teleport_collision = null
		return
	
	teleport_area = Area3D.new()
	teleport_area.name = "TeleportArea"
	add_child_in_editor(self, teleport_area)
	
	teleport_collision = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size.x = portal_size.x
	box.size.y = portal_size.y
	teleport_collision.shape = box
	
	add_child_in_editor(teleport_area, teleport_collision)


func _on_portal_size_changed() -> void:
	assert(portal_mesh != null, "Portal should never be null. Setting size to '" + str(portal_size) + "' failed.")
	
	var p: BoxMesh = portal_mesh.mesh
	p.size = Vector3(portal_size.x, portal_size.y, portal_thickness)

#endregion

#region GAMEPLAY RUNTIME STUFF

func _ready() -> void:
	if Engine.is_editor_hint():
		# TODO: Is the deferred necessary here??
		_editor_ready.call_deferred()
		return
	
	if player_camera == null:
		# FIXME: This WILL fail if the root does a SubViewportContainer thing. Maybe.
		# It's probably best to assign this manually.
		push_warning("Inferring player camera from parent viewport.")
		player_camera = get_viewport().get_camera_3d()
		assert(player_camera != null, "Player camera is missing!")
	
	_setup_cameras()
	
	assert(portal_viewport != null, "[%s] Portal should have a viewport!" % name)
	
	portal_mesh.material_override.set_shader_parameter("albedo", portal_viewport.get_texture())
	
	# Configure teleport for action
	if is_teleport:
		assert(teleport_area)
		teleport_area.area_entered.connect(self._on_teleport_area_entered)
		teleport_area.area_exited.connect(self._on_teleport_area_exited)
		teleport_area.body_entered.connect(self._on_teleport_body_entered)
		teleport_area.body_exited.connect(self._on_teleport_body_exited)
		teleport_area.collision_mask = teleport_collision_mask
	
	get_viewport().size_changed.connect(_on_window_resize)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	
	_process_cameras()

func _process_cameras() -> void:
	# NOTE: Camera transformations
	if portal_camera != null && player_camera != null && exit_portal != null:
		portal_camera.global_transform = self.to_exit_transform(player_camera.global_transform)
		portal_camera.near = _calculate_near_plane()
		
		# Prevent flickering
		var half_height: float = player_camera.near * tan(deg_to_rad(player_camera.fov * 0.5))
		var half_width: float = half_height * portal_viewport.size.x / float(portal_viewport.size.y)
		var near_diagonal: float = Vector3(half_width, half_height, player_camera.near).length()
		# TODO: This doesn't change much. Update it directly?
		portal_thickness = near_diagonal
		_on_portal_size_changed()
		var player_in_front_of_portal: bool = forward_angle(player_camera) > 0
		portal_mesh.position = Vector3.FORWARD * near_diagonal * (0.5 if player_in_front_of_portal else -0.5)
		
	
	if is_teleport:
		_process_teleports()

func _process_teleports() -> void:
	for body in watchlist_bodies.keys():
		body = body as Node3D
		var last_fw_angle: float = watchlist_bodies.get(body)
		var current_fw_angle: float = forward_angle(body)
		
		if last_fw_angle > 0 and current_fw_angle <= 0 and abs(current_fw_angle) < _teleport_tolerance:
			# NOTE: BODIES don't have to specify teleport_root, they are usually the roots. 
			var teleportable_path = body.get_meta("teleport_root", ".")
			var teleportable: Node3D = body.get_node(teleportable_path)
			teleportable.global_transform = self.to_exit_transform(teleportable.global_transform)
			
		watchlist_bodies.set(body, current_fw_angle)

func _calculate_near_plane() -> float:
	# Adjustment for cube portals. This AABB is basically a plane.
	# TODO: May or may not be a little broken now that portal mesh moves a little
	var _aabb: AABB = AABB(
		Vector3(-exit_portal.portal_size.x / 2, -exit_portal.portal_size.y / 2, 0),
		Vector3(exit_portal.portal_size.x, exit_portal.portal_size.y, 0)
	)
	
	var corner_1:Vector3 = exit_portal.to_global(Vector3(_aabb.position.x, _aabb.position.y, 0))
	var corner_2:Vector3 = exit_portal.to_global(Vector3(_aabb.position.x + _aabb.size.x, _aabb.position.y, 0))
	var corner_3:Vector3 = exit_portal.to_global(Vector3(_aabb.position.x + _aabb.size.x, _aabb.position.y + _aabb.size.y, 0))
	var corner_4:Vector3 = exit_portal.to_global(Vector3(_aabb.position.x, _aabb.position.y + _aabb.size.y, 0))

	# Calculate the distance along the exit camera forward vector at which each of the portal corners projects
	var camera_forward:Vector3 = -portal_camera.global_transform.basis.z.normalized()

	var d_1:float = (corner_1 - portal_camera.global_position).dot(camera_forward)
	var d_2:float = (corner_2 - portal_camera.global_position).dot(camera_forward)
	var d_3:float = (corner_3 - portal_camera.global_position).dot(camera_forward)
	var d_4:float = (corner_4 - portal_camera.global_position).dot(camera_forward)
	
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
		portal_viewport.size = self.get_settings_window_size()
		exit_portal.add_child(portal_viewport, true)
		
		# Disable tonemapping on portal cameras
		var adjusted_env: Environment = player_camera.environment.duplicate() \
			if player_camera.environment \
			else player_camera.get_world_3d().environment.duplicate()
		adjusted_env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
		adjusted_env.tonemap_exposure = 1
		
		portal_camera = Camera3D.new()
		portal_camera.name = self.name + "_Camera3D"
		portal_camera.environment = adjusted_env
		if portals_see_portals == false:
			portal_camera.cull_mask = portal_camera.cull_mask ^ portal_render_layer
			
		portal_viewport.add_child(portal_camera, true)
		portal_camera.global_position = exit_portal.global_position
	else:
		push_warning("[%s] No exit_portal!" % name)

#endregion

#region Event handlers

func _on_teleport_area_entered(area: Area3D) -> void:
	print("[%s] teleport_area_entered: %s" % [name, area.name])
	# TODO

func _on_teleport_area_exited(area: Area3D) -> void:
	print("[%s] teleport_area_exited: %s" % [name, area.name])
	# TODO

func _on_teleport_body_entered(body: Node3D) -> void:
	#if body.has_meta("teleport_root"):
	watchlist_bodies.set(body, forward_angle(body))

func _on_teleport_body_exited(body: Node3D) -> void:
	watchlist_bodies.erase(body)

func _on_window_resize() -> void:
	portal_viewport.size = get_viewport().size

#endregion

#region UTILS

## [b]Crucial[/b] piece of a portal - transforming where objects should appear 
## on the other side. Used for both cameras and teleports.
func to_exit_transform(g_transform: Transform3D) -> Transform3D:
	var relative_to_portal: Transform3D = portal_mesh.global_transform.affine_inverse() * g_transform
	var flipped: Transform3D = relative_to_portal.rotated(Vector3.UP, PI)
	# CRITICAL: This produces a SLIGHT offset now (visible on lines on the ground)
	var relative_to_target = exit_portal.global_transform * flipped
	return relative_to_target

## Calculates the dot product of portal's forward vector with the global 
## position of [param node]. Used for detecting teleports.
## [br]
## The result is positive when the node is in front of the portal.
func forward_angle(node: Node3D) -> float:
	var portal_front: Vector3 = self.global_transform.basis.z.normalized()
	var node_relative: Vector3 = (node.global_transform.origin - global_transform.origin).normalized()
	return portal_front.dot(node_relative)

## Helper function meant to be used in editor. Adds [param node] as a child to 
## [param parent]. Forces a readable name and sets the child's owner to the same
## as parent's.
func add_child_in_editor(parent: Node, node: Node) -> void:
	parent.add_child(node, true)
	# self.owner should be the editor scene root. Just pass that
	node.owner = self.owner

## Used to conditionally run property setters.
## [br]
## Setters fire both on editor set and when the scene starts up (the engine is
## assigning exported members). This should prevent the second case.
func caused_by_user_interaction() -> bool:
	return Engine.is_editor_hint() and is_node_ready()

## Editor helper function. Locks node in 3D editor view.
static func lock_node(node: Node3D) -> void:
	node.set_meta("_edit_lock_", true)


## Editor helper function. Groups nodes in 3D editor view.
static func group_node(node: Node) -> void:
	node.set_meta("_edit_group_", true)

## Fetches window size from [ProjectSettings].
static func get_settings_window_size() -> Vector2:
	return Vector2(
		ProjectSettings.get_setting("display/window/size/viewport_width"),
		ProjectSettings.get_setting("display/window/size/viewport_height")
	)

#endregion

# ---------- GODOT ENGINE INTEGRATIONS --------------

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: Array[String] = []
	
	if exit_portal == null:
		warnings.append("Exit portal is null")
	
	return PackedStringArray(warnings)
