extends Control

@export var levels_scenes: Array[PackedScene] = []
@onready var levels_container: VBoxContainer = %LevelsContainer


func _ready() -> void:
	Input.mouse_mode = Input.MouseMode.MOUSE_MODE_VISIBLE
	
	for level_scene in levels_scenes:
		var b = Button.new()
		b.text = level_scene.resource_path.get_file().replace(".tscn", "").capitalize()
		b.pressed.connect(func(): 
			print("[Level] " + b.text)
			get_tree().change_scene_to_packed(level_scene)
		)
		levels_container.add_child(b)


func _on_quit_button_pressed() -> void:
	get_tree().quit()
