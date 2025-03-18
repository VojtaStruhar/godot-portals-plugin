@tool
extends EditorPlugin

const ExitOutlinesGizmo = preload("uid://pk5ua52g54m1") # gizmos/portal_exit_outline.gd
var exit_outline_gizmo = ExitOutlinesGizmo.new()

func _enter_tree() -> void:
	# TODO: Create settings for this
	add_node_3d_gizmo_plugin(exit_outline_gizmo)


func _exit_tree() -> void:
	remove_node_3d_gizmo_plugin(exit_outline_gizmo)
