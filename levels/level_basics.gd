extends Node3D


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("toggle_portals"):
		print("Toggling %d portals" % get_tree().get_node_count_in_group("portals"))
		for p in get_tree().get_nodes_in_group("portals"):
			if p is Portal3D:
				if p.portal_mesh.visible:
					p.portal_mesh.hide()
				else:
					p.portal_mesh.show()
