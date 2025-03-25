@tool
extends EditorPlugin

const ExitOutlinesGizmo = preload("uid://pk5ua52g54m1") # gizmos/portal_exit_outline.gd
var exit_outline_gizmo

const ForwardDirGizmo = preload("uid://cacoywhcpn4ja") # gizmos/portal_forward_direction.gd
var forward_dir_gizmo

func _enter_tree() -> void:
	PortalSettings.init_setting("default_portal_layer", 1 << 7)
	PortalSettings.add_info(AtExport.int_render_3d("default_portal_layer"))
	
	PortalSettings.init_setting("default_teleport_mask", 1 << 7)
	PortalSettings.add_info(AtExport.int_physics_3d("default_teleport_mask"))
	
	PortalSettings.init_setting("gizmo_exit_outline_active", true, true)
	PortalSettings.add_info(AtExport.bool_("gizmo_exit_outline_active"))
	
	PortalSettings.init_setting("gizmo_exit_outline_color", Color.DEEP_SKY_BLUE, true) 
	PortalSettings.add_info(AtExport.color_no_alpha("gizmo_exit_outline_color"))
	
	PortalSettings.init_setting("portals_group_name", "portals")
	PortalSettings.add_info(AtExport.string("portals_group_name"))
	
	if PortalSettings.get_setting("gizmo_exit_outline_active"):
		exit_outline_gizmo = ExitOutlinesGizmo.new()
		add_node_3d_gizmo_plugin(exit_outline_gizmo)
	
	forward_dir_gizmo = ForwardDirGizmo.new()
	add_node_3d_gizmo_plugin(forward_dir_gizmo)

func _exit_tree() -> void:
	if exit_outline_gizmo:
		remove_node_3d_gizmo_plugin(exit_outline_gizmo)
	
	remove_node_3d_gizmo_plugin(forward_dir_gizmo)
