extends Camera3D

## Camera with flying script attached to it.
class_name Freecam3D

##
## Camera with toggleable freecam mode for prototyping when creating levels, shaders, lighting, etc.
##
## Usage: Run your game, press <TAB> and fly around freely. Uses Minecraft-like controls.
##

## Customize your own toggle key to avoid collisions with your current mappings.
@export var toggle_key: Key = KEY_TAB
## Speed up / down by scrolling the mouse whell down / up
@export var invert_speed_controls: bool = false

@export var overlay_text: bool = true

## Pivot node for camera looking around
@onready var pivot := Node3D.new()
## Main parent for camera overlay.
@onready var screen_overlay := VBoxContainer.new()
## Container for the chat-like event log.
@onready var event_log := VBoxContainer.new()

const MAX_SPEED := 4
const MIN_SPEED := 0.1
const ACCELERATION := 0.1
const MOUSE_SENSITIVITY := 0.002

## Whether or not the camera can move.
var movement_active := false:
	set(val):
		movement_active = val
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED if movement_active else Input.MOUSE_MODE_VISIBLE)
		display_message("[Movement ON]" if movement_active else "[Movement OFF]")

## The current maximum speed. Lower or higher it by scrolling the mouse wheel.
var target_speed := MIN_SPEED
## Movement velocity.
var velocity := Vector3.ZERO


## Sets up pivot and UI overlay elements.
func _setup_nodes() -> void:
	self.add_sibling(pivot)
	pivot.position = position
	pivot.rotation = rotation
	pivot.name = "FreecamPivot"
	self.reparent(pivot)
	self.position = Vector3.ZERO
	self.rotation = Vector3.ZERO
	# UI stuff
	screen_overlay.add_theme_constant_override("Separation", 8)
	self.add_child(screen_overlay)
	screen_overlay.add_child(_make_label("Debug Camera"))
	screen_overlay.add_spacer(false)
	
	screen_overlay.add_child(event_log)
	screen_overlay.visible = overlay_text


func _ready() -> void:
	_setup_nodes.call_deferred()
	_add_keybindings()


func _process(delta: float) -> void:
	
	if Input.is_action_just_released("__debug_camera_toggle"):
		movement_active = not movement_active
	
	if movement_active:
		var dir = Vector3.ZERO
		if Input.is_action_pressed("__debug_camera_forward"): 	dir.z -= 1
		if Input.is_action_pressed("__debug_camera_back"): 		dir.z += 1
		if Input.is_action_pressed("__debug_camera_left"): 		dir.x -= 1
		if Input.is_action_pressed("__debug_camera_right"): 	dir.x += 1
		if Input.is_action_pressed("__debug_camera_up"): 		dir.y += 1
		if Input.is_action_pressed("__debug_camera_down"): 		dir.y -= 1
		
		dir = dir.normalized()
		dir = dir.rotated(Vector3.UP, pivot.rotation.y)
		
		velocity = lerp(velocity, dir * target_speed, ACCELERATION)
		pivot.position += velocity


func _input(event: InputEvent) -> void:
	if movement_active:
		# Turn around
		if event is InputEventMouseMotion:
			pivot.rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
			rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
			rotation.x = clamp(rotation.x, -PI/2, PI/2)
		
		var speed_up = func():
			target_speed = clamp(target_speed + 0.15, MIN_SPEED, MAX_SPEED)
			display_message("[Speed up] " + str(target_speed))
			
		var slow_down = func():
			target_speed = clamp(target_speed - 0.15, MIN_SPEED, MAX_SPEED)
			display_message("[Slow down] " + str(target_speed))
		
		# Speed up and down with the mouse wheel
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
				slow_down.call() if invert_speed_controls else speed_up.call()
				
			if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
				speed_up.call() if invert_speed_controls else slow_down.call()


## Pushes new message label into "chat" and removes the old ones if necessary
func display_message(text: String) -> void:
	while event_log.get_child_count() >= 3:
		event_log.remove_child(event_log.get_child(0))
	
	event_log.add_child(_make_label(text))


func _make_label(text: String) -> Label:
	var l = Label.new()
	l.text = text
	return l


func _add_keybindings() -> void:
	var actions = InputMap.get_actions()
	if "__debug_camera_forward" not in actions: _add_key_input_action("__debug_camera_forward", KEY_W)
	if "__debug_camera_back" 	not in actions: _add_key_input_action("__debug_camera_back", KEY_S)
	if "__debug_camera_left" 	not in actions: _add_key_input_action("__debug_camera_left", KEY_A)
	if "__debug_camera_right" 	not in actions: _add_key_input_action("__debug_camera_right", KEY_D)
	if "__debug_camera_up" 		not in actions: _add_key_input_action("__debug_camera_up", KEY_SPACE)
	if "__debug_camera_down" 	not in actions: _add_key_input_action("__debug_camera_down", KEY_SHIFT)
	if "__debug_camera_toggle" 	not in actions: _add_key_input_action("__debug_camera_toggle", toggle_key)


func _add_key_input_action(name: String, key: Key) -> void:
	var ev = InputEventKey.new()
	ev.physical_keycode = key
	
	InputMap.add_action(name)
	InputMap.action_add_event(name, ev)

