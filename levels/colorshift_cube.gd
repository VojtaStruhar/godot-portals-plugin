extends StaticBody3D

@onready var cube_mesh: MeshInstance3D = $CubeMesh

func shift_colors() -> void:
	var color = Color.from_hsv(randf(), 0.5, 0.79)
	print_rich("[color=%s]Shifting colors[/color]" % color.to_html(false))
	var t = create_tween().set_trans(Tween.TRANS_CUBIC)
	t.tween_property(cube_mesh.material_override, "albedo_color", color, 0.2)
