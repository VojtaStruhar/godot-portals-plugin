@tool
extends EditorPlugin

const project_settings_prefix: String = "addons/portals/"

const settings: Dictionary = {
	"default_teleport_layer": 1 << 4
}

func _enter_tree() -> void:
	for key in settings.keys():
		var qual_key = project_settings_prefix + key
		if not ProjectSettings.has_setting(qual_key):
			print("Creating project setting: ", key)
			ProjectSettings.set_setting(qual_key, settings[key])
			ProjectSettings.set_initial_value(qual_key, settings[key])
	


func _exit_tree() -> void:
	# Clean-up of the plugin goes here.
	pass
