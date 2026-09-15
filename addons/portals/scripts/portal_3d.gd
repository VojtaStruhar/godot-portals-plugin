@tool
@icon("uid://ct62bsuel5hyc")
class_name Portal3D extends Node3D

## Seamless 3D portal
##
## To get started, create two Portal3D instances and set their [member exit_portal] to each other.
## This creates a linked portal pair that you can look through. Make your player to collide with
## [member teleport_collision_mask] and you will be able to walk back and forth through the portal.
## [br][br]
## To integrate portals into your game, you can make use of the [signal on_teleport] and 
## [signal on_teleport_receive] signals. You can link a portal a different one by chaning its 
## [member exit_portal] during gameplay. The next level is to make use of the portal's callbacks,
## mainly the [member ON_TELEPORT_CALLBACK]. If you need to raycast through a portal, then the 
## [method forward_raycast] method might come in handy! When it comes to optimization, you can use
## the [method activate] and [method deactivate] methods to control which portals are consuming 
## resources.
## [br][br]
## [b]TIP:[/b] If you change the default value of some property, it will not get synchronized into existing 
## portal instances due to how Godot handles custom inspectors. For easier defaults management, 
## I recommend creating a scene with Portal3D as a root and re-using that.


#region Public API

## Emitted when this portal teleports something. Also see [signal on_teleport_receive]
signal on_teleport(node: Node3D)

## Emitted when this portal [i]receives[/i] a teleported node. Whoever had [b]this[/b] portal as
## its [member exit_portal] triggered a teleport!
signal on_teleport_receive(node: Node3D)

## Activates the portal, making it visible and teleporting again. THe assumption is that it was 
## previously deactivated by [method deactivate] or [member start_deactivated]. Recreates internal
## viewports if needed.
func activate() -> void:
	process_mode = Node.PROCESS_MODE_INHERIT
	
	if portal_viewport == null:
		# Viewports have been destroyed
		_setup_cameras()
	
	show()
	

## Disables all processing (this includes teleportation) and hides the portal. Optionally destroys
## the viewports, freeing up memory. [br][br]
## Setting [member start_deactivated] to [code]true[/code] avoid viewport allocation at the start of 
## the game. [br][br]
## Deactivated portal has to be explicitly activated by calling [method activate].
func deactivate(destroy_viewports: bool = false) -> void:
	hide()
	_watchlist_teleportables.clear()
	
	if destroy_viewports:
		if portal_viewport:
			portal_viewport.queue_free()
			portal_viewport = null
			portal_camera = null
	
	process_mode = Node.PROCESS_MODE_DISABLED

## Helper method for checking for raycast collisions through portals. If your [RayCast3D] node hits
## a portal collider, pass the [RayCast3D] node to this function to find out what's on the other
## side of the portal! [br][br]
## Uses [method PhysicsDirectSpaceState3D.intersect_ray] under the hood.[br][br]
## Also see [method forward_raycast_query].
func forward_raycast(raycast: RayCast3D) -> Dictionary:
	var start := to_exit_position(raycast.get_collision_point())
	var goal := to_exit_position(raycast.to_global(raycast.target_position))
	
	var query = PhysicsRayQueryParameters3D.create(
		start,
		goal,
		raycast.collision_mask,
		[self.teleport_area, exit_portal.teleport_area]
	)
	query.collide_with_areas = raycast.collide_with_areas
	query.collide_with_bodies = raycast.collide_with_bodies
	query.hit_back_faces = raycast.hit_back_faces
	query.hit_from_inside = raycast.hit_from_inside
	
	return get_world_3d().direct_space_state.intersect_ray(query)

## When doing raycasts with [method PhysicsDirectSpaceState3D.intersect_ray] and you hit a portal
## that you want to go through, pass the [PhysicsRayQueryParameters3D] you are using to this 
## function. It will calculate the ray's continuation and execute the raycast again, returning the 
## result dictionary. [br][br]
## If you are using [RayCast3D] for raycasting, see [method forward_raycast].
func forward_raycast_query(params: PhysicsRayQueryParameters3D) -> Dictionary:
	var start := to_exit_position(params.from)
	var end := to_exit_position(params.to)
	start = exit_portal.line_intersection(start, end)
	
	var excludes = [self.teleport_area, exit_portal.teleport_area]
	excludes.append_array(params.exclude)
	
	var query = PhysicsRayQueryParameters3D.create(
		start, end, params.collision_mask, excludes
	)
	query.collide_with_areas = params.collide_with_areas
	query.collide_with_bodies = params.collide_with_bodies
	query.hit_back_faces = params.hit_back_faces
	query.hit_from_inside = params.hit_from_inside

	return get_world_3d().direct_space_state.intersect_ray(query)


## This method will be called on a teleported node if [member TeleportInteractions.CALLBACK]
## is checked in [member teleport_interactions]. The portal will try to call the method 
## [code]on_teleport[/code] on any object being teleported by it.[br][br]
## Example:
## [codeblock]
## func on_teleport(portal: Portal3D) -> void:
##     print("Teleported by %s!" % portal.name)
## [/codeblock]
const ON_TELEPORT_CALLBACK: StringName = &"on_teleport"

## This method will be called on a node that will get into close proximity of a portal that has 
## [member TeleportInteractions.DUPLICATE_MESHES] turned on. The method is expected to return an
## array of [MeshInstance3D]s.[br][br]
## Example:
## [codeblock]
## @onready var character_mesh: MeshInstance = $CharacterMesh
## 
## func get_teleportable_meshes() -> Array[MeshInstance3D]:
##     return [character_mesh]
## [/codeblock]
##
## The returned meshes require a special material. Check out the plugin's README for more 
## information!
const DUPLICATE_MESHES_CALLBACK: StringName = &"get_teleportable_meshes"

## By default, object triggering the teleport gets teleported. You can override this with a 
## metadata property that contains a [NodePath]. If the metadata property is set, then the node at 
## the node path will be teleported instead. Setting this to ancestor nodes is recommended.[br][br]
## Example:
## [codeblock]
## func _ready() -> void:
##     self.set_meta("teleport_root", ^"..") # parent
## [/codeblock]
## Or you can set the metadata property via the inspector!
const TELEPORT_ROOT_META: StringName = &"teleport_root"
	

#endregion

## Size of the portal rectangle, height and width.
var portal_size: Vector2 = Vector2(2.0, 2.5):
	set(v):
		portal_size = v
		if _caused_by_user_interaction():
			_on_portal_size_changed()
			update_configuration_warnings()
			if exit_portal:
				exit_portal.update_configuration_warnings()

## The exit of this particular portal. Portal camera renders what it sees through this
## [member exit_portal] and teleports take you here. This is a [b]required[/b] property, it
## can never be [code]null[/code].
## [br][br]
## You can change this property during gameplay to switch the portal to a different destination.
## To disable a portal, see [method deactivate].
## [br][br]
## [b]TIP:[/b] Commonly, two portals have set each other as [member exit_portal], which
## allows you to travel back and forth. But you can experiment with one-way portals too!
var exit_portal: Portal3D:
	set(v):
		exit_portal = v
		update_configuration_warnings()
		notify_property_list_changed()

var _tb_pair_portals: Callable = _editor_pair_portals.bind()
var _tb_sync_portal_sizes: Callable = _editor_sync_portal_sizes.bind()

## Manually override what's the main camera of the scene. By default it's inferred as the camera
## rendering the parent viewport of the portal. You might have to specify this, if your game uses 
## multiple [SubViewport]s.
var player_camera: Camera3D

## The portal camera sets its [member Camera3D.near] as close to the portal as possible, in an 
## effort to clip objects close behind the portal. This value offsets the [member portal_camera]'s 
## near clip plane. Might be useful, if the portal has a thick frame around it.
var portal_frame_width: float = 0

## Options for different sizes of the internal viewports. It helps to reduce the memory usage
## by not rendering the portals at full resolution. Viewports are resized on window resize.
enum PortalViewportSizeMode {
	## Render at full window resolution.
	FULL,
	## The portal will be [b]at most[/b] this wide. Height is calculated from window aspect ratio.
	MAX_WIDTH_ABSOLUTE,
	## Portal viewport will be a fraction of full window size.
	FRACTIONAL
}

## Size mode to use for the portal viewport size. Only set this via the inspector.
var viewport_size_mode: PortalViewportSizeMode = PortalViewportSizeMode.FULL:
	set(v):
		viewport_size_mode = v
		notify_property_list_changed()
var _viewport_size_max_width_absolute: int = ProjectSettings.get_setting("display/window/size/viewport_width")
var _viewport_size_fractional: float = 0.5


## Hints the direction from which you expect the portal to be viewed.[br][br] 
## Use cases: one-way portals, visual-only portals (with [member is_teleport] set to 
## [code]false[/code]), or portals that are flush with a wall.
enum ViewDirection {
	## Portal is expected to be viewed from either side (default)
	FRONT_AND_BACK,
	## Corresponds to portal's FORWARD direction (-Z)
	ONLY_FRONT,
	## Corresponds to portal's BACK direction (+Z)
	ONLY_BACK,
}

## The direction from which you expect the portal to be viewed. Restricting this restricts the
## way the portal mesh is shifted around when player looks at the portal from different sides.[br]
## Restrict this if the portal can be seen from the sides and has no portal frame around it to 
## cover the shifting mesh.[br][br]
## Also see [member teleport_direction]
var view_direction: ViewDirection = ViewDirection.FRONT_AND_BACK


## The [member portal_mesh] setting for [member VisualInstance3D.layers], so that the portal 
## cameras don't see other portals.
var portal_render_layer: int = 1 << 19:
	set(v):
		portal_render_layer = v
		if _caused_by_user_interaction():
			portal_mesh.layers = v

## If [code]true[/code], the portal is also a teleport. If [code]false[/code], the portal is 
## visual-only.
## [br][br]
## You are expected to toggle this in the editor. For runtime teleport toggling, see 
## [method activate] and [method deactivate].
var is_teleport: bool = true:
	set(v):
		is_teleport = v
		if _caused_by_user_interaction():
			_setup_teleport()
			notify_property_list_changed()

## Dictates from which direction an object has to enter the portal to be teleported.
enum TeleportDirection {
	## Corresponds to portal's FORWARD direction (-Z)
	FRONT,
	## Corresponds to portal's BACK direction (+Z)
	BACK,
	## Teleports stuff coming from either side. (default)
	FRONT_AND_BACK
}

## Portal will only teleport things coming from this direction.
var teleport_direction: TeleportDirection = TeleportDirection.FRONT_AND_BACK

## When a [RigidBody3D] goes through the portal, give its new normalized velocity a 
## little boost. Makes stuff flying out of portals more fun. [br][br]
## Recommended values: 1 to 3
var rigidbody_boost: float = 0.0

## When teleporting, the portal checks if the teleported object is less than [b]this[/b] near.
## Prevents false negatives when multiple portals are on top of each other.
var teleport_tolerance: float = 0.5

## Flags for everything that happens when a something is teleported.
enum TeleportInteractions {
	## The portal will try to call [constant ON_TELEPORT_CALLBACK] method on the teleported
	## node. You need to implement this function with a script.
	CALLBACK = 1 << 0,
	## When the player is teleported, his X and Z rotations are tweened to zero. Resets unwanted
	## from going through a tilted portal. If checked, this will happen BEFORE the callback.
	PLAYER_UPRIGHT = 1 << 1,
	## Duplicate meshes present on the teleported object, resulting in a [i]smooth teleport[/i] 
	## from a 3rd point of view. [br]
	## To use this feature, implement a method named [constant DUPLICATE_MESHES_CALLBACK] on the 
	## teleported body, which returns an array of mesh instances that should be duplicated. 
	## Every one of those meshes also needs to implement a special shader material to clip it along 
	## the portal plane. 
	## See shaderinclude at [code]addons/portals/materials/portalclip_mesh.gdshaderinc[/code]
	DUPLICATE_MESHES = 1 << 2
}

## See [enum TeleportInteractions] for options.
var teleport_interactions: int = TeleportInteractions.CALLBACK \
									| TeleportInteractions.PLAYER_UPRIGHT


## Any [CollisionObject3D]s detected by this mask will be registered by the portal and teleported, 
## when they cross the portal boundary.
var teleport_collision_mask: int = 1 << 15

## If the portal is not immediately visible on scene start, you can start it in [i]disabled 
## mode[/i]. This just means it will not create the appropriate subviewports, saving memory. 
## It will also not be processed.[br][br]
## You have to call [method activate] on it to wake it up! Also see [method disable]
var start_deactivated: bool = false

#region INTERNALS

@export_storage var _portal_thickness: float = 0.05:
	set(v):
		_portal_thickness = v
		if _caused_by_user_interaction(): _on_portal_size_changed()

@export_storage var _portal_mesh_path: NodePath
## Mesh used to visualize the portal surface. Created when the portal is added to the scene 
## [b]in the editor[/b].
var portal_mesh: MeshInstance3D:
	get():
		return get_node(_portal_mesh_path) if _portal_mesh_path else null
	set(v): assert(false, "Proxy variable, use '_portal_mesh_path' instead")
	
@export_storage var _teleport_area_path: NodePath
## When a teleportable object comes near the portal, it's registered by this area and watched 
## every frame to trigger the teleport. [br][br] Created by toggling [member is_teleport] in editor.
var teleport_area: Area3D:
	get():
		return get_node(_teleport_area_path) if _teleport_area_path else null
	set(v): assert(false, "Proxy variable, use '_teleport_area_path' instead")

@export_storage var _teleport_collider_path: NodePath
## Collider for [member teleport_area].
var teleport_collider: CollisionShape3D:
	get():
		return get_node(_teleport_collider_path) if _teleport_collider_path else null
	set(v): assert(false, "Proxy variable, use '_teleport_collider_path' instead")


## Camera that looks through the exit portal and renders to [member portal_viewport]. 
## Created in [method Node._ready]
var portal_camera: Camera3D = null

## Viewport that supplies the albedo texture to portal mesh. Rendered by [member portal_camera].
## Created in [method Node._ready]
var portal_viewport: SubViewport = null

## Metadata about teleported objects. 
## 
## When the portal detects a teleportable body (or area) nearby, it gathers this metadata and 
## starts watching it every frame for teleportation. 
class TeleportableMeta:
	## Forward distance from the portal
	var forward: float = 0
	## True only if the [member Portal3D.player_camera] is a child of the object being teleported.
	## In that case, we consider it the player.
	var is_player: bool = false
	## Meshes that the object gave for duplication. Retrieved by the 
	## [constant Portal3D.DUPLICATE_MESHES_CALLBACK] callback.
	var meshes: Array[MeshInstance3D] = []
	## Cloned [member Portal3D.TeleportableMeta.meshes] with [method Node.duplicate]
	var mesh_clones: Array[MeshInstance3D] = []

# These physics bodies are being watched by the portal. They are registered with their instance IDs
# as the keys of the dictionary. Registering them by their object references becomes unreliable 
# when the teleport candidate gets freed.
var _watchlist_teleportables: Dictionary[int, TeleportableMeta] = {}

#endregion

#region Editor Configuration

const _PORTAL_SHADER: Shader = preload("uid://bhdb2skdxehes")
const _EDITOR_PREVIEW_PORTAL_MATERIAL: StandardMaterial3D = preload("uid://dcfkcyddxkglf")

# _ready(), but only in editor.
func _editor_ready() -> void:
	add_to_group(PortalSettings.get_setting("portals_group_name"), true)
	set_notify_transform(true)
	
	process_priority = 100
	process_physics_priority = 100
	
	_setup_mesh()
	_setup_teleport()
	
	self._group_node(self)

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_TRANSFORM_CHANGED:
			update_gizmos()

func _editor_pair_portals() -> void:
	assert(exit_portal != null, "My own exit has to be set!")
	exit_portal.exit_portal = self
	notify_property_list_changed()

func _editor_sync_portal_sizes() -> void:
	assert(exit_portal != null, "My own exit has to be set!")
	portal_size = exit_portal.portal_size
	notify_property_list_changed()

func _setup_teleport():
	if is_teleport == false:
		if teleport_area:
			teleport_area.queue_free()
			_teleport_area_path = NodePath("")
		if teleport_collider:
			teleport_collider.queue_free()
			_teleport_collider_path = NodePath("")
		return
	
	# Teleport is already set up
	if teleport_area and teleport_collider:
		return
	
	var area = Area3D.new()
	area.name = "TeleportArea"
	
	_add_child_in_editor(self, area)
	_teleport_area_path = get_path_to(area)
	
	var collider = CollisionShape3D.new()
	collider.name = "Collider"
	var box = BoxShape3D.new()
	box.size.x = portal_size.x
	box.size.y = portal_size.y
	collider.shape = box
	
	_add_child_in_editor(teleport_area, collider)
	_teleport_collider_path = get_path_to(collider)


func _on_portal_size_changed() -> void:
	if portal_mesh == null:
		push_error("Failed to update portal size, portal has no mesh")
		return
	
	var p: PortalBoxMesh = portal_mesh.mesh
	p.size = Vector3(portal_size.x, portal_size.y, 1)
	portal_mesh.scale.z = _portal_thickness
	
	if is_teleport and teleport_collider:
		var box: BoxShape3D = teleport_collider.shape
		box.size.x = portal_size.x
		box.size.y = portal_size.y
	
#endregion

#region GAMEPLAY LOGIC

func _ready() -> void:
	if Engine.is_editor_hint():
		_editor_ready.call_deferred()
		return
	
	if player_camera == null:
		player_camera = get_viewport().get_camera_3d()
		assert(player_camera != null, "Player camera is missing!")
	
	
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = _PORTAL_SHADER
	portal_mesh.material_override = mat
	
	if not start_deactivated:
		_setup_cameras()
	else:
		deactivate.call_deferred(true)
	
	if is_teleport:
		assert(teleport_area, "Teleport area should be already set up from editor")
		teleport_area.area_entered.connect(self._on_teleport_area_entered)
		teleport_area.area_exited.connect(self._on_teleport_area_exited)
		teleport_area.body_entered.connect(self._on_teleport_body_entered)
		teleport_area.body_exited.connect(self._on_teleport_body_exited)
		teleport_area.collision_mask = teleport_collision_mask


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	
	if is_teleport:
		_process_teleports()
		
	_process_cameras()
	

func _process_cameras() -> void:
	if portal_camera == null:
		push_error("%s: No portal camera" % name)
		return
	if player_camera == null:
		push_error("%s: No player camera" % name)
		return
	if exit_portal == null:
		push_error("%s: No exit portal" % name)
		return
	
	# Update camera
	portal_camera.global_transform = self.to_exit_transform(player_camera.global_transform)
	portal_camera.near = _calculate_near_plane()
	portal_camera.fov = player_camera.fov
	
	# Prevent flickering
	var pv_size: Vector2i = portal_viewport.size
	var half_height: float = player_camera.near * tan(deg_to_rad(player_camera.fov * 0.5))
	var half_width: float = half_height * pv_size.x / float(pv_size.y)
	var near_diagonal: float = Vector3(half_width, half_height, player_camera.near).length()
	portal_mesh.scale.z = near_diagonal
	
	var player_in_front_of_portal: bool = forward_distance(player_camera) > 0
	var portal_shift: float = 0
	match view_direction:
		ViewDirection.ONLY_FRONT:
			portal_shift = 1
		ViewDirection.ONLY_BACK:
			portal_shift = -1
		ViewDirection.FRONT_AND_BACK:
			portal_shift = 1 if player_in_front_of_portal else -1
	
	portal_mesh.scale.z *= signf(portal_shift) # Turn the portal towards the player
	

func _process_teleports() -> void:
	for body_id: int in _watchlist_teleportables.keys():
		if not is_instance_id_valid(body_id): # Watched body has been freed
			_erase_tp_metadata(body_id)
			continue
		
		var tp_meta: TeleportableMeta = _watchlist_teleportables.get(body_id)
		var body = instance_from_id(body_id) as Node3D
		var last_fw_angle: float = tp_meta.forward
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
			var teleportable_path = body.get_meta(TELEPORT_ROOT_META, ".")
			var teleportable: Node3D = body.get_node(teleportable_path)
			
			teleportable.global_transform = self.to_exit_transform(teleportable.global_transform)
			
			if teleportable is RigidBody3D:
				teleportable.linear_velocity = to_exit_direction(teleportable.linear_velocity)
				teleportable.apply_central_impulse(
					teleportable.linear_velocity.normalized() * rigidbody_boost
				)
			
			
			on_teleport.emit(teleportable)
			exit_portal.on_teleport_receive.emit(teleportable)
			
			
			if tp_meta.is_player:
				_process_cameras()
				exit_portal._process_cameras()
			
			# Resolve teleport interactions
			if tp_meta.is_player and _check_tp_interaction(TeleportInteractions.PLAYER_UPRIGHT):
				get_tree().create_tween().tween_property(teleportable, "rotation:x", 0, 0.3)
				get_tree().create_tween().tween_property(teleportable, "rotation:z", 0, 0.3)
			
			if _check_tp_interaction(TeleportInteractions.CALLBACK):
				if teleportable.has_method(ON_TELEPORT_CALLBACK):
					teleportable.call(ON_TELEPORT_CALLBACK, self)
			
			# transfer the thing to exit portal
			_transfer_tp_metadata_to_exit(body)
		else:
			tp_meta.forward = current_fw_angle
			for i in tp_meta.mesh_clones.size():
				var mesh = tp_meta.meshes[i]
				var clone = tp_meta.mesh_clones[i]
				clone.global_transform = to_exit_transform(mesh.global_transform)

func _calculate_near_plane() -> float:
	# Adjustment for cube portals. This AABB is basically a plane.
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
	
	var p := PortalBoxMesh.new()
	p.size = Vector3(portal_size.x, portal_size.y, 1)
	mi.mesh = p
	mi.scale.z = _portal_thickness
	
	# Editor-only material. Will be replaced when game starts.
	mi.material_override = _EDITOR_PREVIEW_PORTAL_MATERIAL
	
	_add_child_in_editor(self, mi)
	_portal_mesh_path = get_path_to(mi)

func _setup_cameras() -> void:
	assert(not Engine.is_editor_hint(), "This should never run in editor")
	assert(portal_camera == null)
	assert(portal_viewport == null)
	
	if exit_portal != null:
		portal_viewport = SubViewport.new()
		portal_viewport.name = self.name + "_SubViewport"
		portal_viewport.size = _calculate_viewport_size()
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
		
		# Ensure that portals don't see other portals.
		portal_camera.cull_mask = portal_camera.cull_mask ^ portal_render_layer
		
		portal_viewport.add_child(portal_camera, true)
		portal_camera.global_position = exit_portal.global_position
		
		# Connect the viewport to the mesh. Mesh material setup has to run BEFORE this
		portal_mesh.material_override.set_shader_parameter("albedo", portal_viewport.get_texture())
		
		var vp := get_viewport()
		if not vp.size_changed.is_connected(_on_window_resize):
			vp.size_changed.connect(_on_window_resize)
	else:
		push_error("%s has no exit_portal! Failed to setup cameras." % name)

#endregion

#region Event handlers

func _on_teleport_area_entered(area: Area3D) -> void:
	if _watchlist_teleportables.has(area.get_instance_id()):
		# Already on watchlist
		return
	
	_construct_tp_metadata(area)

func _on_teleport_body_entered(body: Node3D) -> void:
	if _watchlist_teleportables.has(body.get_instance_id()):
		# Already on watchlist
		return
	
	_construct_tp_metadata(body)

func _on_teleport_area_exited(area: Area3D) -> void:
	_erase_tp_metadata(area.get_instance_id())

func _on_teleport_body_exited(body: Node3D) -> void:
	_erase_tp_metadata(body.get_instance_id())

func _on_window_resize() -> void:
	if portal_viewport:
		portal_viewport.size = _calculate_viewport_size()

#endregion

#region UTILS

func _construct_tp_metadata(node: Node3D) -> void:
	var teleportable = node.get_node(node.get_meta(TELEPORT_ROOT_META, ".")) # Usually the node itself
	
	var meta = TeleportableMeta.new()
	meta.forward = forward_distance(node)
	meta.is_player = (teleportable == player_camera) or teleportable.is_ancestor_of(player_camera)

	## This is a workaround to prevent flickering when traversing portals.
	## There is a bit of lag when restarting RTT when the exit portal becomes physically visible.
	## Ensuring both portals are updated regardless of visibility while in the portals prevents flickering.
	## More info: https://github.com/VojtaStruhar/godot-portals-plugin/pull/4
	if meta.is_player:
		_set_portal_pair_update_mode(SubViewport.UPDATE_ALWAYS)

	if _check_tp_interaction(TeleportInteractions.DUPLICATE_MESHES) \
	and teleportable.has_method(DUPLICATE_MESHES_CALLBACK):
		meta.meshes = teleportable.call(DUPLICATE_MESHES_CALLBACK)
		for m: MeshInstance3D in meta.meshes:
			var dupe = m.duplicate(0)
			dupe.name = m.name + "_Clone"
			meta.mesh_clones.append(dupe)
			self.add_child(dupe, true)

			var skeleton_node = m.get_node_or_null(m.skeleton)
			if skeleton_node:
				dupe.skeleton = dupe.get_path_to(skeleton_node)

		_enable_mesh_clipping(meta, self)
	
	_watchlist_teleportables.set(node.get_instance_id(), meta)

func _erase_tp_metadata(node_id: int) -> void:
	var meta = _watchlist_teleportables.get(node_id)
	if meta != null:
		meta = meta as TeleportableMeta
		
		if meta.is_player:
			_set_portal_pair_update_mode(SubViewport.UPDATE_WHEN_VISIBLE)
			
		for m in meta.meshes: _disable_mesh_clipping(m)
		for c in meta.mesh_clones: c.queue_free()
		
	_watchlist_teleportables.erase(node_id)


func _transfer_tp_metadata_to_exit(for_body: Node3D) -> void:
	if not exit_portal.is_teleport:
		return # One-way teleport scenario
	
	var body_id = for_body.get_instance_id()
	var tp_meta = _watchlist_teleportables[body_id]
	assert(tp_meta != null, "Attempted to trasfer teleport metadata for a node that is not being watched.")
	
	tp_meta.forward = exit_portal.forward_distance(for_body)
	_enable_mesh_clipping(tp_meta, exit_portal) # Switch, the main mesh is clipped by exit portal!
	
	exit_portal._watchlist_teleportables.set(body_id, tp_meta)
	
	if tp_meta.is_player and exit_portal.exit_portal != self:
		# Not a portal pair - the transition isn't seamless anyways. Flip the update 
		# mode of this portal "manually" and enable the next portal pair, since `_construct_tp_metadata`
		# will not get called there. Usually portals are symmetric, though.
		portal_viewport.set_update_mode(SubViewport.UPDATE_WHEN_VISIBLE)
		exit_portal._set_portal_pair_update_mode(SubViewport.UPDATE_ALWAYS)
	
	# NOTE: Not using '_erase_tp_metadata' here, as it also frees the cloned meshes!
	_watchlist_teleportables.erase(body_id)


func _enable_mesh_clipping(meta: TeleportableMeta, along_portal: Portal3D) -> void:
	for mi: MeshInstance3D in meta.meshes:
		var clip_normal = signf(meta.forward) * along_portal.global_basis.z
		mi.set_instance_shader_parameter("portal_clip_active", true)
		mi.set_instance_shader_parameter("portal_clip_point", along_portal.global_position)
		mi.set_instance_shader_parameter("portal_clip_normal", clip_normal)
	
	var exit = along_portal.exit_portal
	for clone: MeshInstance3D in meta.mesh_clones:
		var clip_normal = signf(meta.forward) * exit.global_basis.z
		clone.set_instance_shader_parameter("portal_clip_active", true)
		clone.set_instance_shader_parameter("portal_clip_point", exit.global_position)
		clone.set_instance_shader_parameter("portal_clip_normal", clip_normal)

func _disable_mesh_clipping(mi: MeshInstance3D) -> void:
	mi.set_instance_shader_parameter("portal_clip_active", false)

## [b]Crucial[/b] piece of a portal - transforming where objects should appear 
## on the other side. Used for both cameras and teleports.
func to_exit_transform(g_transform: Transform3D) -> Transform3D:
	var relative_to_portal: Transform3D = global_transform.affine_inverse() * g_transform
	var flipped: Transform3D = relative_to_portal.rotated(Vector3.UP, PI)
	var relative_to_target = exit_portal.global_transform * flipped
	return relative_to_target


## Similar to [method to_exit_transform], but this one uses [member global_basis] for calculations, 
## so it [b]only transforms rotation[/b], since portal scale should aways be 1. Use for transforming
## directions.
func to_exit_direction(real: Vector3) -> Vector3:
	var relative_to_portal: Vector3 = global_basis.inverse() * real
	var flipped: Vector3 = relative_to_portal.rotated(Vector3.UP, PI)
	var relative_to_target: Vector3 = exit_portal.global_basis * flipped
	return relative_to_target


## Similar to [method to_exit_transform], but expects a global position.
func to_exit_position(g_pos: Vector3) -> Vector3:
	var local: Vector3 = global_transform.affine_inverse() * g_pos
	var rotated = local.rotated(Vector3.UP, PI)
	var local_at_exit: Vector3 = exit_portal.global_transform * rotated
	return local_at_exit


## Calculates the dot product of portal's forward vector with the global 
## position of [param node] relative to the portal. Used for detecting teleports.
## [br]
## The result is positive when the node is in front of the portal. The value measures how far in 
## front (or behind) the other node is compared to the portal.
func forward_distance(node: Node3D) -> float:
	var portal_front: Vector3 = self.global_transform.basis.z.normalized()
	var node_relative: Vector3 = (node.global_transform.origin - self.global_transform.origin)
	return portal_front.dot(node_relative)

# Helper function meant to be used in editor. Adds [param node] as a child to 
# [param parent]. Forces a readable name and sets the child's owner to the same
# as parent's.
func _add_child_in_editor(parent: Node, node: Node) -> void:
	parent.add_child(node, true)
	# self.owner is null if this node is the scene root. Supply self.
	node.owner = self if self.owner == null else self.owner

# Used to conditionally run property setters.
# [br]
# Setters fire both on editor set and when the scene starts up (the engine is
# assigning exported members). This should prevent the second case.
func _caused_by_user_interaction() -> bool:
	return Engine.is_editor_hint() and is_node_ready()

# Editor helper function. Groups nodes in 3D editor view.
func _group_node(node: Node) -> void:
	node.set_meta("_edit_group_", true)

func _calculate_viewport_size() -> Vector2i:
	var vp_size: Vector2i = get_viewport().size
	var aspect_ratio: float = float(vp_size.x) / float(vp_size.y)
	
	match viewport_size_mode:
		PortalViewportSizeMode.FULL:
			return vp_size
		PortalViewportSizeMode.MAX_WIDTH_ABSOLUTE:
			var width = min(_viewport_size_max_width_absolute, vp_size.x)
			return Vector2i(width, int(width / aspect_ratio))
		PortalViewportSizeMode.FRACTIONAL:
			return Vector2i(vp_size * _viewport_size_fractional)
	
	push_error("Failed to determine desired viewport size")
	return Vector2i(
		ProjectSettings.get_setting("display/window/size/viewport_width"),
		ProjectSettings.get_setting("display/window/size/viewport_height")
	)

func _check_tp_interaction(flag: int) -> bool:
	return (teleport_interactions & flag) > 0

func _set_portal_pair_update_mode(mode: SubViewport.UpdateMode) -> void:
	assert(is_instance_valid(exit_portal))
	self.portal_viewport.set_update_mode(mode)
	if exit_portal.portal_viewport:
		exit_portal.portal_viewport.set_update_mode(mode)

## Get a point where the portal plane intersects a line. Line [param start] and [param end] 
## are in global coordinates and so is the result. Used for forwarding raycast queries.
func line_intersection(start: Vector3, end: Vector3) -> Vector3:
	var plane_normal = - global_basis.z
	var plane_point = global_position
	
	var line_dir = end - start
	var denom = plane_normal.dot(line_dir)

	if abs(denom) < 1e-6:
		return Vector3.ZERO # No intersection, line is parallel to the plane

	var t = plane_normal.dot(plane_point - start) / denom
	return start + line_dir * t

#endregion

#region GODOT EDITOR INTEGRATIONS

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: Array[String] = []
	
	var global_scale = global_basis.get_scale()
	if not global_scale.is_equal_approx(Vector3.ONE):
		warnings.append(
			("Portals should NOT be scaled. Global portal scale is %v, " % global_scale) +
			"but should be (1.0, 1.0, 1.0). Make sure the portal and any of portal parents " +
			"aren't scaled."
			)
	
	if exit_portal == null:
		warnings.append("Exit portal is null")
	
	if exit_portal != null:
		if not portal_size.is_equal_approx(exit_portal.portal_size):
			warnings.append(
				"Portal size should be the same as exit portal's (it's %s, but should be %s)" %
				[portal_size, exit_portal.portal_size]
			)
	
	return PackedStringArray(warnings)

func _get_property_list() -> Array[Dictionary]:
	var config: Array[Dictionary] = []
	
	config.append(AtExport.vector2("portal_size"))
	
	if exit_portal != null and not portal_size.is_equal_approx(exit_portal.portal_size):
		config.append(
			AtExport.button("_tb_sync_portal_sizes", "Take Exit Portal's Size", "Vector2"))
	
	config.append(AtExport.node("exit_portal", "Portal3D"))
	
	if exit_portal != null and exit_portal.exit_portal == null:
		config.append(AtExport.button("_tb_pair_portals", "Pair Portals", "SliderJoint3D"))
	
	
	config.append(AtExport.group("Rendering"))
	config.append(AtExport.node("player_camera", "Camera3D"))
	config.append(AtExport.float_range("portal_frame_width", 0.0, 10.0, 0.01))
	
	config.append(AtExport.enum_(
		"viewport_size_mode", &"Portal3D.PortalViewportSizeMode", PortalViewportSizeMode))
		
	if viewport_size_mode == PortalViewportSizeMode.MAX_WIDTH_ABSOLUTE:
		config.append(AtExport.int_range("_viewport_size_max_width_absolute", 2, 4096))
	elif viewport_size_mode == PortalViewportSizeMode.FRACTIONAL:
		config.append(AtExport.float_range("_viewport_size_fractional", 0, 1))
	
	config.append(AtExport.enum_("view_direction", &"Portal3D.ViewDirection", ViewDirection))
	
	config.append(AtExport.int_render_3d("portal_render_layer"))
	
	config.append(AtExport.group_end())
	
	# TELEPORT GROUP
	config.append(AtExport.group("Teleport"))
	config.append(AtExport.bool_("is_teleport", true))
	config.append(
		AtExport.enum_("teleport_direction", &"Portal3D.TeleportDirection", TeleportDirection))
	config.append(AtExport.float_range("rigidbody_boost", 0, 5, 0.1, ["or_greater"]))
	config.append(AtExport.float_range("teleport_tolerance", 0.0, 5.0, 0.1, ["or_greater"]))
	var opts: Array = TeleportInteractions.keys().map(func(s): return s.capitalize())
	config.append(AtExport.int_flags("teleport_interactions", opts))
	config.append(AtExport.int_physics_3d("teleport_collision_mask"))
	config.append(AtExport.group_end())
	
	# ADVANCED GROUP
	config.append(AtExport.group("Advanced"))
	config.append(AtExport.bool_("start_deactivated"))
	
	return config

func _property_can_revert(property: StringName) -> bool:
	return property in [
		&"portal_size",
		&"player_camera",
		&"portal_frame_width",
		&"_viewport_size_max_width_absolute",
		&"view_direction",
		&"portal_render_layer",
		&"teleport_direction",
		&"rigidbody_boost",
		&"teleport_tolerance",
		&"teleport_interactions",
		&"teleport_collision_mask",
		&"start_deactivated",
	]

func _property_get_revert(property: StringName) -> Variant:
	match property:
		&"portal_size":
			return Vector2(2, 2.5)
		&"portal_frame_width":
			return 0.0
		&"_viewport_size_max_width_absolute":
			return ProjectSettings.get_setting("display/window/size/viewport_width")
		&"view_direction":
			return ViewDirection.FRONT_AND_BACK
		&"portal_render_layer":
			return 1 << 19
		&"teleport_direction":
			return TeleportDirection.FRONT_AND_BACK
		&"rigidbody_boost":
			return 0.0
		&"teleport_tolerance":
			return 0.5
		&"teleport_interactions":
			return TeleportInteractions.CALLBACK | TeleportInteractions.PLAYER_UPRIGHT
		&"teleport_collision_mask":
			return 1 << 15
		&"start_deactivated":
			return false
	return null

#endregion
