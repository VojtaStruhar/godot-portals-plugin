extends Control

@export_dir var levels_directory: String 
@onready var v_box_container: VBoxContainer = $VBoxContainer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if levels_directory:
		var dir = DirAccess.open(levels_directory)
		for file in dir.get_files():
			if not file.ends_with(".tscn"): continue
			
			var b = Button.new()
			b.text = file.replace(".tscn", "").capitalize()
			b.pressed.connect(func(): get_tree().change_scene_to_file(levels_directory + "/" + file))
			v_box_container.add_child(b)
			
	
