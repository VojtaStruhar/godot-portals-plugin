extends Control

@export_dir var levels_directory: String 
@onready var levels_container: VBoxContainer = %LevelsContainer


func _ready() -> void:
	Input.mouse_mode = Input.MouseMode.MOUSE_MODE_VISIBLE
	
	if levels_directory:
		var dir = DirAccess.open(levels_directory)
		for file in dir.get_files():
			if not file.ends_with(".tscn"): continue
			
			var b = Button.new()
			b.text = file.replace(".tscn", "").capitalize()
			b.pressed.connect(func(): get_tree().change_scene_to_file(levels_directory + "/" + file))
			levels_container.add_child(b)


func _on_quit_button_pressed() -> void:
	get_tree().quit()
