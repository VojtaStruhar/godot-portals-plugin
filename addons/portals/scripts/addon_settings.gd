class_name PortalSettings


static func _qual_name(setting: String) -> String:
	return "addons/portals/" + setting

static func init_setting(setting: String, 
						 default_value: Variant, 
						 requires_restart: bool = false) -> void:
	setting = _qual_name(setting)
	
	if not ProjectSettings.has_setting(setting):
		ProjectSettings.set_setting(setting, default_value)
		ProjectSettings.set_initial_value(setting, default_value)
		ProjectSettings.set_restart_if_changed(setting, requires_restart)


## See companion class [AtExport], it has some utilities which might be helpful!
static func add_info(config: Dictionary) -> void:
	var qual_name = _qual_name(config["name"])
	
	config["name"] = qual_name
	# In case this is coming from AtExport, which is geared towards inspector properties
	config.erase("usage") 
	
	ProjectSettings.add_property_info(config)

static func get_setting(setting: String) -> Variant:
	setting = _qual_name(setting)
	return ProjectSettings.get_setting(setting)
