extends CharacterBody3D


@onready var camera: Camera3D = $PlayerCamera

var SPEED = 4.0
const JUMP_VELOCITY = 4.5
const MOUSE_SENSITIVITY = 0.004

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			rotate_y(-event.screen_relative.x * MOUSE_SENSITIVITY)
			camera.rotate_x(-event.screen_relative.y * MOUSE_SENSITIVITY)
			camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-80), deg_to_rad(80))

func _physics_process(delta: float) -> void:
	
	var right:Vector3 = (global_transform.basis.x * Vector3(1, 0, 1)).normalized()
	var forward:Vector3 = (-global_transform.basis.z * Vector3(1, 0, 1)).normalized()
	var has_input = false

	velocity.x = 0
	velocity.z = 0

	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
		has_input = true
		velocity -= right
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		has_input = true
		velocity += right
	if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W):
		has_input = true
		velocity += forward
	if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
		has_input = true
		velocity -= forward
	
	if has_input:
		var normalized_horizontal_velocity = Vector2(velocity.x, velocity.z).normalized()
		velocity.x = normalized_horizontal_velocity.x * SPEED
		velocity.z = normalized_horizontal_velocity.y * SPEED
	
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	
	move_and_slide()
