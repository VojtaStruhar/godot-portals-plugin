extends EditorNode3DGizmoPlugin

func _init() -> void:
	var exit_outline_color = PortalSettings.get_setting("gizmo_exit_outline_color")
	create_material("outline", exit_outline_color, false, true, false)

func _get_gizmo_name() -> String:
	return "PortalExitOutlineGizmo"

func _has_gizmo(for_node_3d: Node3D) -> bool:
	return for_node_3d is Portal3D

func _redraw(gizmo: EditorNode3DGizmo) -> void:
	var portal = gizmo.get_node_3d() as Portal3D
	assert(portal != null, "This gizmo works only for Portal3D")
	gizmo.clear()
	
	if portal not in EditorInterface.get_selection().get_selected_nodes():
		return
	
	var ep: Portal3D = portal.exit_portal
	if ep == null:
		return
	
	
	var extents = Vector3(ep.portal_size.x, ep.portal_size.y, ep._portal_thickness) / 2
	
	var lines: Array[Vector3] = [
		# Front rect
		extents, extents * Vector3(1, -1, 1),
		extents, extents * Vector3(-1, 1, 1),
		extents * Vector3(1, -1, 1), extents * Vector3(-1, -1, 1),
		extents * Vector3(-1, 1, 1), extents * Vector3(-1, -1, 1),
		
		# Back rect
		- extents, -extents * Vector3(1, -1, 1),
		- extents, -extents * Vector3(-1, 1, 1),
		- extents * Vector3(1, -1, 1), -extents * Vector3(-1, -1, 1),
		- extents * Vector3(-1, 1, 1), -extents * Vector3(-1, -1, 1),
		
		# Short Z connections
		extents * Vector3(1, 1, 1), extents * Vector3(1, 1, -1),
		extents * Vector3(1, -1, 1), extents * Vector3(1, -1, -1),
		extents * Vector3(-1, 1, 1), extents * Vector3(-1, 1, -1),
		extents * Vector3(-1, -1, 1), extents * Vector3(-1, -1, -1),
	]
	
	# Double each line for visual thickness
	#for i in range(lines.size()):
		#lines.append(lines[i] + (lines[i].normalized() * 0.005))
	
	for i in range(lines.size()):
		lines[i] = portal.to_local(ep.to_global(lines[i]))
	
	gizmo.add_lines(
		PackedVector3Array(lines),
		get_material("outline", gizmo)
	)
