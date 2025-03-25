extends EditorNode3DGizmoPlugin

func _init() -> void:
	var forward_color = PortalSettings.get_setting("gizmo_forward_color")
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
		var arrow_spread = 0.05
		lines.append_array([
			Vector3(0, 0, 1), Vector3(arrow_spread, -arrow_spread, 0.9),
			Vector3(0, 0, 1), Vector3(-arrow_spread, arrow_spread, 0.9),
		])
		
		var offset = 0.005
		for i in range(lines.size()):
			var p = lines[i]
			lines.append(Vector3(p.x + offset, p.y + offset, p.z))
	
	gizmo.add_lines(
		PackedVector3Array(lines),
		get_material("forward", gizmo)
	)
