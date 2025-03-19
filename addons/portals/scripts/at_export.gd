class_name AtExport

## Helper class for defining custom export inspector.
##
## Instead of [code]@export var foo: int = 0[/code] you could return
## [code]AtExport.int_("foo")[/code] in your [method Object._get_property_list]

static func _base(name: String, type: int) -> Dictionary:
	return {
		"name": name,
		"type": type,
		"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	}

static func bool_(name: String) -> Dictionary:
	return _base(name, TYPE_BOOL)

static func int_(name: String) -> Dictionary:
	return _base(name, TYPE_INT)

static func int_physics_3d(name: String) -> Dictionary:
	var result := int_(name)
	result["hint"] = PROPERTY_HINT_LAYERS_3D_PHYSICS
	return result

static func float_(name: String) -> Dictionary:
	return _base(name, TYPE_FLOAT)

static func string(name: String) -> Dictionary:
	return _base(name, TYPE_STRING)


static func float_range(name: String, min: float, max: float, step: float = 0.01, extra_hints: Array[String] = []) -> Dictionary:
	var result := float_(name)
	var hint_string = "%f,%f,%f" % [min, max, step]
	
	if extra_hints.size() > 0:
		for h in extra_hints:
			hint_string += ("," + h)
	
	result["hint"] = PROPERTY_HINT_RANGE
	result["hint_string"] = hint_string
	
	return result

static func enum_(name: String, parent_and_enum: StringName, enum_class: Variant) -> Dictionary:
	var result := int_(name)
	
	result["class_name"] = parent_and_enum
	result["hint"] = PROPERTY_HINT_ENUM
	result["hint_string"] = ",".join(enum_class.keys())
	result["usage"] |= PROPERTY_USAGE_CLASS_IS_ENUM
	
	return result

static func button(name: String, button_text: String, button_icon: String = "Callable") -> Dictionary:
	var result := _base(name, TYPE_CALLABLE)
	
	assert(not button_text.contains(","), "Button text cannot contain a comma")
	
	result["hint"] = PROPERTY_HINT_TOOL_BUTTON
	result["hint_string"] = button_text + "," + button_icon
	
	return result

static func group(group_name: String, prefix: String = "") -> Dictionary:
	var result := _base(group_name, TYPE_NIL)
	# Overwrite the usage!
	result["usage"] = PROPERTY_USAGE_GROUP
	result["hint_string"] = prefix
	return result

static func group_end() -> Dictionary:
	return group("")

static func subgroup(group_name: String, prefix: String = "") -> Dictionary:
	var result := _base(group_name, TYPE_NIL)
	# Overwrite the usage!
	result["usage"] = PROPERTY_USAGE_SUBGROUP
	result["hint_string"] = prefix
	return result

static func subgroup_end() -> Dictionary:
	return subgroup("")
