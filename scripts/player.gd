extends CharacterBody3D


@onready var camera: Camera3D = $PlayerCamera

const SPEED = 5.0
const JUMP_VELOCITY = 4.5
const MOUSE_SENSITIVITY = 0.005

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			rotate_y(-event.screen_relative.x * MOUSE_SENSITIVITY)
			camera.rotate_x(-event.screen_relative.y * MOUSE_SENSITIVITY)
			camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-80), deg_to_rad(80))

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		
		
	var right:Vector3 = (global_transform.basis.x * Vector3(1, 0, 1)).normalized()
	var forward:Vector3 = (global_transform.basis.z * Vector3(1, 0, 1)).normalized()

	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
		global_translate(-right * SPEED * delta)
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		global_translate(right * SPEED * delta)
	if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W):
		global_translate(-forward * SPEED * delta)
	if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
		global_translate(forward * SPEED * delta)

	move_and_slide()
