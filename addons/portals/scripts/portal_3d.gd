@tool
class_name Portal3D extends Node3D

## Configurator node that manages the setup of a 3D portal.
##
## This node is a tool script that provides configuration options to the user. It's only purpose
## is to manage the portal setup in editor. During gameplay, it moves portal cameras around and
## provides API to interact with the portal system.

## Emitted when this portal triggers a teleport.
signal on_teleport(body_or_area: Node3D)

## Emitted when this portal [i]receives[/i] a teleported node. Whoever had [b]thi[/b] portal as
## its [member exit_portal] triggered a teleport!
signal on_teleport_receive(body_or_area: Node3D)

var portal_size: Vector2 = Vector2(2.0, 2.5):
	set(v):
		portal_size = v
		if caused_by_user_interaction():
			_on_portal_size_changed()
			update_configuration_warnings()
			if exit_portal:
				exit_portal.update_configuration_warnings()


var exit_portal: Portal3D:
	set(v):
		exit_portal = v
		update_configuration_warnings()
		notify_property_list_changed()

var _tb_pair_portals: Callable = _editor_pair_portals
var player_camera: Camera3D

## The width of the frame portal. Adjusts the near clip distance of the camera looking through 
## THIS portal.
var portal_frame_width: float = 0
var portals_see_portals: bool = false

var portal_render_layer: int = 1 << 7:
	set(v):
		portal_render_layer = v
		if caused_by_user_interaction():
			portal_mesh.layers = v

var max_viewport_width: int = ProjectSettings.get_setting("display/window/size/viewport_width")

var is_teleport: bool:
	set(v):
		is_teleport = v
		if caused_by_user_interaction():
			_setup_teleport()
			notify_property_list_changed()

## Dictates from which direction an object has to enter the portal to be teleported.
enum TeleportDirection {
	## Corresponds to portal's FORWARD direction (-Z)
	FRONT,
	## Corresponds to portal's BACK direction (+Z)
	BACK,
	## Teleports stuff coming from either side.
	FRONT_AND_BACK
}

## If the portal is also a teleport, it will only teleport things coming from
## this direction.
var teleport_direction: TeleportDirection = TeleportDirection.FRONT_AND_BACK

## When a [RigidBody3D] goes through the portal, give its new normalized velocity a 
## little boost. Makes stuff flying out of portals more fun. [br][br]
## Recommended values: 1 to 3
var rb_velocity_boost: float = 0.0

var teleport_collision_mask: int = 1 << 7

## When teleporting, the portal checks if the teleported object is less than [b]this[/b] near.
## Prevents false negatives when multiple portals are on top of each other.
var teleport_tolerance: float = 0.5

#region INTERNALS

@export_storage var portal_thickness: float = 0.05:
	set(v):
		portal_thickness = v
		if caused_by_user_interaction(): _on_portal_size_changed()

@export_storage var portal_mesh_path: NodePath
var portal_mesh: MeshInstance3D:
	get(): 
		return null if portal_mesh_path == NodePath("") else get_node(portal_mesh_path)
	set(v): assert(false, "Proxy variable, use 'portal_mesh_path' instead")
	
@export_storage var teleport_area_path: NodePath
var teleport_area: Area3D:
	get(): 
		return null if teleport_area_path == NodePath("") else get_node(teleport_area_path)
	set(v): assert(false, "Proxy variable, use 'teleport_area_path' instead")

@export_storage var teleport_collider_path: NodePath
var teleport_collision: CollisionShape3D:
	get(): 
		return null if teleport_collider_path == NodePath("") else get_node(teleport_collider_path)
	set(v): assert(false, "Proxy variable, use 'teleport_collider_path' instead")



## Camera that looks through the exit portal. If exit portal is null, the camera doesn't exist 
## either.
var portal_camera: Camera3D = null
var portal_viewport: SubViewport = null


## These physics bodies are being watched by the portal. The value in dictionary
## is their dot product from last frame. As soon as the dot product changes signs,
## the body crossed the portal and should be teleported.
var _watchlist_teleportables: Dictionary[Node3D, float] = {}


var _tb_debug_action: Callable = _debug_action


func _debug_action() -> void:
	print("[%s] DEBUG")
	print({"portal_mesh_path": portal_mesh_path, "portal_mesh": portal_mesh})

#region Public API
func activate() -> void:
	portal_viewport.disable_3d = false
	portal_mesh.show()
	
	if is_teleport:
		teleport_area.monitoring = true

func deactivate() -> void:
	portal_viewport.disable_3d = true
	portal_mesh.hide()
	
	if is_teleport:
		teleport_area.monitoring = false


#endregion

#region Editor Configuration Stuff

const PORTAL_SHADER = preload("uid://bhdb2skdxehes")

## _ready(), but only in editor.
func _editor_ready() -> void:
	add_to_group(PortalSettings.get_setting("portals_group_name"), true)
	
	process_priority = 100
	process_physics_priority = 100
	
	_setup_mesh()
	
	self.group_node(self)


func _editor_pair_portals():
	if exit_portal == null:
		push_error("[%s] _editor_pair_portals called, but 'exit_portal' is null" % name)
		return
	
	exit_portal.exit_portal = self
	notify_property_list_changed()

func _setup_teleport():
	if is_teleport == false:
		if teleport_area:
			teleport_area.queue_free()
			teleport_area_path = NodePath("")
		if teleport_collision:
			teleport_collision.queue_free()
			teleport_collider_path = NodePath("")
		return
	
	var area = Area3D.new()
	area.name = "TeleportArea"
	
	add_child_in_editor(self, area)
	teleport_area_path = get_path_to(area)
	
	var collider = CollisionShape3D.new()
	collider.name = "Collider"
	var box = BoxShape3D.new()
	box.size.x = portal_size.x
	box.size.y = portal_size.y
	collider.shape = box
	
	add_child_in_editor(teleport_area, collider)
	teleport_collider_path = get_path_to(collider)


func _on_portal_size_changed() -> void:
	if portal_mesh == null:
		printerr("Portal has no mesh!!!")
		return
	
	var p: BoxMesh = portal_mesh.mesh
	p.size = Vector3(portal_size.x, portal_size.y, portal_thickness)
	
	if is_teleport and teleport_collision:
		var box: BoxShape3D = teleport_collision.shape
		box.size.x = portal_size.x
		box.size.y = portal_size.y
	
#endregion

#region GAMEPLAY RUNTIME STUFF

func _ready() -> void:
	if Engine.is_editor_hint():
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
	
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = PORTAL_SHADER
	portal_mesh.material_override = mat
	portal_mesh.material_override.set_shader_parameter("albedo", portal_viewport.get_texture())
	
	if is_teleport:
		assert(teleport_area, "Teleport area should be already set up from editor")
		teleport_area.area_entered.connect(self._on_teleport_area_entered)
		teleport_area.area_exited.connect(self._on_teleport_area_exited)
		teleport_area.body_entered.connect(self._on_teleport_body_entered)
		teleport_area.body_exited.connect(self._on_teleport_body_exited)
		teleport_area.collision_mask = teleport_collision_mask
	
	get_viewport().size_changed.connect(_on_window_resize)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	
	if is_teleport:
		_process_teleports()
		
	_process_cameras()
	

func _process_cameras() -> void:
	# NOTE: Camera transformations
	if portal_camera != null && player_camera != null && exit_portal != null:
		portal_camera.global_transform = self.to_exit_transform(player_camera.global_transform)
		portal_camera.near = _calculate_near_plane()
		
		# Prevent flickering
		var pv_size: Vector2i = portal_viewport.size
		var half_height: float = player_camera.near * tan(deg_to_rad(player_camera.fov * 0.5))
		var half_width: float = half_height * pv_size.x / float(pv_size.y)
		var near_diagonal: float = Vector3(half_width, half_height, player_camera.near).length()
		# TODO: This doesn't change much. Update it directly?
		portal_thickness = near_diagonal
		_on_portal_size_changed()
		
		var player_in_front_of_portal: bool = forward_distance(player_camera) > 0
		portal_mesh.position = (
			Vector3.FORWARD * near_diagonal * (0.5 if player_in_front_of_portal else -0.5)
		)


func _process_teleports() -> void:
	for body in _watchlist_teleportables.keys():
		body = body as Node3D # Conversion just for type hints
		var last_fw_angle: float = _watchlist_teleportables.get(body)
		var current_fw_angle: float = forward_distance(body)
		
		var should_teleport: bool = false
		match teleport_direction:
			TeleportDirection.FRONT:
				should_teleport = last_fw_angle > 0 and current_fw_angle <= 0
			TeleportDirection.BACK:
				should_teleport = last_fw_angle < 0 and current_fw_angle >= 0
			TeleportDirection.FRONT_AND_BACK:
				should_teleport = sign(last_fw_angle) != sign(current_fw_angle)
			_:
				assert(false, "This match statement should be exhaustive")
		
		if should_teleport and abs(current_fw_angle) < teleport_tolerance:
			# NOTE: BODIES don't have to specify teleport_root, they are usually the roots. 
			var teleportable_path = body.get_meta("teleport_root", ".")
			var teleportable: Node3D = body.get_node(teleportable_path)
			teleportable.global_transform = self.to_exit_transform(teleportable.global_transform)
			
			if teleportable is RigidBody3D:
				teleportable.linear_velocity = to_exit_direction(teleportable.linear_velocity)
				teleportable.apply_central_impulse(
					teleportable.linear_velocity.normalized() * rb_velocity_boost
				)
			
			_watchlist_teleportables.erase(body)
			
			on_teleport.emit(teleportable)
			exit_portal.on_teleport_receive.emit(teleportable)
		else:
			_watchlist_teleportables.set(body, current_fw_angle)

func _calculate_near_plane() -> float:
	# Adjustment for cube portals. This AABB is basically a plane.
	# TODO: May or may not be a little broken now that portal mesh moves a little
	var _aabb: AABB = AABB(
		Vector3(-exit_portal.portal_size.x / 2, -exit_portal.portal_size.y / 2, 0),
		Vector3(exit_portal.portal_size.x, exit_portal.portal_size.y, 0)
	)
	var _pos := _aabb.position
	var _size := _aabb.size
	
	var corner_1: Vector3 = exit_portal.to_global(Vector3(_pos.x, _pos.y, 0))
	var corner_2: Vector3 = exit_portal.to_global(Vector3(_pos.x + _size.x, _pos.y, 0))
	var corner_3: Vector3 = exit_portal.to_global(Vector3(_pos.x + _size.x, _pos.y + _size.y, 0))
	var corner_4: Vector3 = exit_portal.to_global(Vector3(_pos.x, _pos.y + _size.y, 0))

	# Calculate the distance along the exit camera forward vector at which each of the portal 
	# corners projects
	var camera_forward: Vector3 = - portal_camera.global_transform.basis.z.normalized()

	var d_1: float = (corner_1 - portal_camera.global_position).dot(camera_forward)
	var d_2: float = (corner_2 - portal_camera.global_position).dot(camera_forward)
	var d_3: float = (corner_3 - portal_camera.global_position).dot(camera_forward)
	var d_4: float = (corner_4 - portal_camera.global_position).dot(camera_forward)
	
	# The near clip distance is the shortest distance which still contains all the corners
	return max(0.01, min(d_1, d_2, d_3, d_4) - exit_portal.portal_frame_width)

func _setup_mesh() -> void:
	if portal_mesh:
		return
	
	var mi = MeshInstance3D.new() 
	
	mi = MeshInstance3D.new()
	mi.name = self.name + "_Mesh"
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.layers = portal_render_layer
	
	var p := BoxMesh.new()
	p.size = Vector3(portal_size.x, portal_size.y, portal_thickness)
	mi.mesh = p
	
	add_child_in_editor(self, mi)
	portal_mesh_path = get_path_to(mi)

func _setup_cameras() -> void:
	assert(not Engine.is_editor_hint(), "This should never run in editor")
	assert(portal_camera == null)
	assert(portal_viewport == null)
	
	if exit_portal != null:
		portal_viewport = SubViewport.new()
		portal_viewport.name = self.name + "_SubViewport"
		portal_viewport.size = Vector2i(max_viewport_width, max_viewport_width / get_aspect_ratio())
		self.add_child(portal_viewport, true)
		
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
	_watchlist_teleportables.set(area, forward_distance(area))


func _on_teleport_area_exited(area: Area3D) -> void:
	_watchlist_teleportables.erase(area)

func _on_teleport_body_entered(body: Node3D) -> void:
	#if body.has_meta("teleport_root"):
	_watchlist_teleportables.set(body, forward_distance(body))

func _on_teleport_body_exited(body: Node3D) -> void:
	_watchlist_teleportables.erase(body)

func _on_window_resize() -> void:
	portal_viewport.size = get_viewport().size

#endregion

#region UTILS

## [b]Crucial[/b] piece of a portal - transforming where objects should appear 
## on the other side. Used for both cameras and teleports.
func to_exit_transform(g_transform: Transform3D) -> Transform3D:
	var relative_to_portal: Transform3D = global_transform.affine_inverse() * g_transform
	var flipped: Transform3D = relative_to_portal.rotated(Vector3.UP, PI)
	var relative_to_target = exit_portal.global_transform * flipped
	return relative_to_target

## Similar to [method to_exit_transform], but this one only transforms a vector.
func to_exit_direction(real: Vector3) -> Vector3:
	var relative_to_portal: Vector3 = global_transform.basis.inverse() * real
	var flipped: Vector3 = relative_to_portal.rotated(Vector3.UP, PI)
	var relative_to_target: Vector3 = exit_portal.global_transform.basis * flipped
	return relative_to_target

## Calculates the dot product of portal's forward vector with the global 
## position of [param node] relative to the portal. Used for detecting teleports.
## [br]
## The result is positive when the node is in front of the portal. The value measures how far in 
## front (or behind) the other node is compared to the portal.
func forward_distance(node: Node3D) -> float:
	var portal_front: Vector3 = self.global_transform.basis.z.normalized()
	var node_relative: Vector3 = (node.global_transform.origin - self.global_transform.origin)
	return portal_front.dot(node_relative)

## Helper function meant to be used in editor. Adds [param node] as a child to 
## [param parent]. Forces a readable name and sets the child's owner to the same
## as parent's.
func add_child_in_editor(parent: Node, node: Node) -> void:
	parent.add_child(node, true)
	# self.owner is null if this node is the scene root. Supply self.
	node.owner = self if self.owner == null else self.owner

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


func get_aspect_ratio() -> float:
	var vp = get_viewport()
	assert(vp != null, "Oops, no viewport. Fall back on project window settings?")
	return float(vp.size.x) / float(vp.size.y)

#endregion

# ---------- GODOT ENGINE INTEGRATIONS --------------

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: Array[String] = []
	
	if not scale.is_equal_approx(Vector3.ONE):
		warnings.append(
			"Portals should NOT be scaled. Set portal scaling to (1, 1, 1) and " +
			"reload the scene. Use the 'portal_size' property for sizing.")
	
	if exit_portal == null:
		warnings.append("Exit portal is null")
	
	if exit_portal != null:
		if not portal_size.is_equal_approx(exit_portal.portal_size):
			warnings.append(
				"Portal size should be the same as exit portal's (it's %s and %s)" %
				[portal_size, exit_portal.portal_size]
			)
	
	return PackedStringArray(warnings)

func _get_property_list() -> Array[Dictionary]:
	var config: Array[Dictionary] = []
	
	config.append(AtExport.vector2("portal_size"))
	config.append(AtExport.node("exit_portal", "Portal3D"))
	if exit_portal != null and exit_portal.exit_portal == null:
		config.append(AtExport.button("_tb_pair_portals", "Pair Portals", "SliderJoint3D"))
	
	
	config.append(AtExport.group("Rendering"))
	config.append(AtExport.float_range("portal_frame_width", 0.0, 10.0, 0.01))
	config.append(AtExport.node("player_camera", "Camera3D"))
	config.append(AtExport.bool_("portals_see_portals"))
	config.append(AtExport.int_render_3d("portal_render_layer")) # TODO: Rename to `portal_layer`
	config.append(AtExport.int_range("max_viewport_width", 2, 4096, 1))
	config.append(AtExport.group_end())
	
	
	config.append(AtExport.bool_("is_teleport"))
	
	if is_teleport:
		config.append(AtExport.group("Teleport"))
		
		config.append(
			AtExport.enum_("teleport_direction", &"Portal3D.TeleportDirection", TeleportDirection))
		config.append(AtExport.float_range("rb_velocity_boost", 0, 5, 0.1, ["or_greater"]))
		config.append(AtExport.int_physics_3d("teleport_collision_mask"))
		config.append(AtExport.float_range("teleport_tolerance", 0.0, 5.0, 0.1, ["or_greater"]))
		config.append(AtExport.group_end())
	
	config.append(AtExport.button("_tb_debug_action", "Debug Button", "Popup"))
	
	return config

func _property_can_revert(property: StringName) -> bool:
	return property in [
		&"portal_size",
		&"portal_frame_width",
		&"player_camera",
		&"portals_see_portals",
		&"portal_render_layer",
		&"max_viewport_width",
		&"teleport_direction",
		&"rb_velocity_boost",
		&"teleport_collision_mask",
		&"teleport_tolerance",
	]

func _property_get_revert(property: StringName) -> Variant:
	match property:
		&"portal_size": return Vector2(2, 2.5)
		&"portal_frame_width": return 0.0
		&"portals_see_portals": return false
		&"portal_render_layer": return PortalSettings.get_setting("default_portal_layer")
		&"max_viewport_width":
			return int(ProjectSettings.get_setting("display/window/size/viewport_width"))
		&"teleport_direction": return TeleportDirection.FRONT_AND_BACK
		&"rb_velocity_boost": return 0.0
		&"teleport_collision_mask": return PortalSettings.get_setting("default_teleport_mask")
		&"teleport_tolerance": return 0.5
	
	return null
