extends Node

@export var aiming_node: Node3D
@export var fire_offset: float = 1.5
@export var fire_force: float = 5
@export_range(1, 100, 1, "suffix:s") var projectile_lifetime: float = 15
@export var projectile_scene: PackedScene

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("fire"):
		var bullet: RigidBody3D = projectile_scene.instantiate()
		get_tree().current_scene.add_child(bullet)
		bullet.global_transform = aiming_node.global_transform
		var forward = -aiming_node.global_basis.z.normalized()
		bullet.global_position += forward * fire_offset
		bullet.rotation_degrees = Vector3(randf(), randf(), randf()) * 180
		bullet.apply_central_impulse(forward * fire_force)
		
		var t = Timer.new()
		t.wait_time = projectile_lifetime
		t.autostart = true
		t.timeout.connect(bullet.queue_free)
		bullet.add_child.call_deferred(t)
		
