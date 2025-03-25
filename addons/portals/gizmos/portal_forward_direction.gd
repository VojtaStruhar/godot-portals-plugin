extends EditorNode3DGizmoPlugin

func _init() -> void:
	var forward_color = Color.HOT_PINK
	create_material("forward", forward_color, false, false, false)
	

func _get_gizmo_name() -> String:
	return "PortalForwardDirectionGizmo"

func _has_gizmo(for_node_3d: Node3D) -> bool:
	return for_node_3d is Portal3D

func _redraw(gizmo: EditorNode3DGizmo) -> void:
	var portal = gizmo.get_node_3d() as Portal3D
	assert(portal != null, "This gizmo works only for Portal3D")
	var active: bool = portal in EditorInterface.get_selection().get_selected_nodes()
	
	gizmo.clear()
	
	var lines: Array[Vector3] = [
		Vector3.ZERO, Vector3(0, 0, 1)
	]
	if active:
		var offset = 0.005
		lines.append_array([
			Vector3(offset, offset, 0), Vector3(offset, offset, 1),
		])
	
	gizmo.add_lines(
		PackedVector3Array(lines),
		get_material("forward", gizmo)
	)
