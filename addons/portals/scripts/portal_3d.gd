@tool
class_name Portal3D extends Node3D 

## Configurator node that manages the setup of a 3D portal.
##
## This node is a tool script that provides configuration options to the user. It's only purpose
## is to manage the portal setup in editor. During gameplay, it moves portal cameras around and
## provides API to interact with the portal system.

@export var portal_size: Vector2 = Vector2(2.0, 2.5):
	set = _on_portal_size_changed

@export var exit_portal: Portal3D:
	set = _on_exit_portal_set

# TODO: Make this optional
@export_tool_button("Pair Portals?", "MeshInstance2D")
var _tb_pair_portals: Callable = func(): exit_portal.exit_portal = self



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


## _ready(), but only in editor.
func _editor_ready() -> void:
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


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_exit_portal_set(new_exit_portal: Portal3D) -> void:
	if portal_camera:
		print_debug("Freeing existing portal camera")
		portal_camera.queue_free()
		portal_camera = null
	if portal_viewport:
		print_debug("Freeing existing subviewport")
		portal_viewport.queue_free()
		portal_viewport = null
	
	exit_portal = new_exit_portal
	
	if exit_portal != null:
		portal_viewport = SubViewport.new()
		portal_viewport.name = self.name + "_SubViewport"
		portal_viewport.size = Vector2(
			ProjectSettings.get_setting("display/window/size/viewport_width"),
			ProjectSettings.get_setting("display/window/size/viewport_height")
		)
		exit_portal.add_child(portal_viewport, true)
		portal_viewport.owner = self.owner
		
		portal_camera = Camera3D.new()
		portal_camera.name = self.name + "_Camera3D"
		portal_viewport.add_child(portal_camera, true)
		portal_camera.owner = self.owner
		portal_camera.global_position = exit_portal.global_position
		

func _on_portal_size_changed(new_size: Vector2) -> void:
	portal_size = new_size
	if portal_mesh == null:
		push_error("Portal should never be null. Setting size to '" + str(new_size) + "' failed.")
		return
	
	var p = portal_mesh.mesh as PlaneMesh
	p.size = new_size

func _ready() -> void:
	if Engine.is_editor_hint():
		_editor_ready.call_deferred()
		return


# ------------------- UTILS ---------------------------

static func lock_node(node: Node3D) -> void:
	node.set_meta("_edit_lock_", true)
