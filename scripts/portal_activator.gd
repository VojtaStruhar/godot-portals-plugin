extends Area3D

## Portal in POSITIVE X direction
@export var portal_left: Portal3D

## Portal in NEGATIVE X direction
@export var portal_right: Portal3D

func _on_area_exited(area: Area3D) -> void:
	print("%s exited" % area.name)


func _on_body_exited(body: Node3D) -> void:
	var left = global_basis.x.normalized().dot(global_position - body.global_position) < 0
	print("%s exited" % body.name, " to the ", "left" if left else "right")
	if left:
		portal_left.activate()
		portal_right.deactivate()
	else:
		portal_left.deactivate()
		portal_right.activate()
