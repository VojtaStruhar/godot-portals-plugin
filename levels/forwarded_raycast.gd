extends RayCast3D

const CALLBACK: StringName = &"shift_colors"

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == 1 and event.pressed:
			if is_colliding():
				var c = get_collider() as Node3D
				if c == null: return
				var p = c.get_parent()
				if p is Portal3D:
					print("Forwarding raycast...")
					c = p.forward_raycast(self)
				
				if c:
					prints("Raycast hit:", c.name)
				if c and c.has_method(CALLBACK):
					c.call(CALLBACK)
				
