extends Node

const MAIN_MENU_UID = "uid://dfuudoym2pnvu"

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("quit"):
		print("Quitting to main menu")
		get_tree().change_scene_to_file(MAIN_MENU_UID)
