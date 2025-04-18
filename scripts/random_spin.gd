extends MeshInstance3D

@export var how_much: Vector3 = Vector3.ZERO

func _ready() -> void:
	if how_much.is_equal_approx(Vector3.ZERO):
		how_much = Vector3(
			randf() * 2 - 1, 
			randf() * 2 - 1, 
			randf() * 2 - 1, 
		)

func _process(delta: float) -> void:
	rotate_x(how_much.x * delta)
	rotate_y(how_much.y * delta)
	rotate_z(how_much.z * delta)
