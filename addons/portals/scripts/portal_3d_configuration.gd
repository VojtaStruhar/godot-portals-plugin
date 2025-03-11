@tool
class_name Portal3DConfig extends Resource

signal should_refresh_visualization

var parent: Node3D = null

@export var portal_size: Vector2 = Vector2(2.0, 2.5)

@export var portal_thickness: float = 0.1

@export_range(0.0, 10.0, 0.01, "or_greater") var frame_thickness: float = 0.0

@export var is_teleport: bool = false

@export_flags_3d_physics var teleport_collision: int = 0

@export var sees_other_portals: bool = false

@export_flags_3d_render var portal_render_layer: int = 0
