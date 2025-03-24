class_name AtExport

## Helper class for defining custom export inspector.
##
## Instead of [code]@export var foo: int = 0[/code] you could return
## [code]AtExport.int_("foo")[/code] in your [method Object._get_property_list]

static func _base(propname: String, type: int) -> Dictionary:
	return {
		"name": propname,
		"type": type,
		"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	}

static func button(propname: String, button_text: String, button_icon: String = "Callable") -> Dictionary:
	var result := _base(propname, TYPE_CALLABLE)
	
	assert(not button_text.contains(","), "Button text cannot contain a comma")
	
	result["hint"] = PROPERTY_HINT_TOOL_BUTTON
	result["hint_string"] = button_text + "," + button_icon
	
	return result

static func bool_(propname: String) -> Dictionary:
	return _base(propname, TYPE_BOOL)

static func color(propname: String) -> Dictionary:
	return _base(propname, TYPE_COLOR)

static func color_no_alpha(propname: String) -> Dictionary:
	var result := _base(propname, TYPE_COLOR)
	result["hint"] = PROPERTY_HINT_COLOR_NO_ALPHA
	return result

## Following two lines are equivalent: [br]
## [codeblock]
## @export var height: float
## AtExport.float_("height")
## [/codeblock]
static func float_(propname: String) -> Dictionary:
	return _base(propname, TYPE_FLOAT)

static func float_range(propname: String, min: float, max: float, step: float = 0.01, extra_hints: Array[String] = []) -> Dictionary:
	var result := float_(propname)
	var hint_string = "%f,%f,%f" % [min, max, step]
	
	if extra_hints.size() > 0:
		for h in extra_hints:
			hint_string += ("," + h)
	
	result["hint"] = PROPERTY_HINT_RANGE
	result["hint_string"] = hint_string
	
	return result

static func int_(propname: String) -> Dictionary:
	return _base(propname, TYPE_INT)

static func int_flags(propname: String, options: Array[String]) -> Dictionary:
	var result := int_(propname)
	result["hint"] = PROPERTY_HINT_FLAGS
	result["hint_string"] = ",".join(options)
	return result

static func int_physics_3d(propname: String) -> Dictionary:
	var result := int_(propname)
	result["hint"] = PROPERTY_HINT_LAYERS_3D_PHYSICS
	return result


static func int_render_3d(propname: String) -> Dictionary:
	var result := int_(propname)
	result["hint"] = PROPERTY_HINT_LAYERS_3D_RENDER
	return result



static func enum_(propname: String, parent_and_enum: StringName, enum_class: Variant) -> Dictionary:
	var result := int_(propname)
	
	result["class_name"] = parent_and_enum
	result["hint"] = PROPERTY_HINT_ENUM
	result["hint_string"] = ",".join(enum_class.keys())
	result["usage"] |= PROPERTY_USAGE_CLASS_IS_ENUM
	
	return result


static func group(group_name: String, prefix: String = "") -> Dictionary:
	var result := _base(group_name, TYPE_NIL)
	# Overwrite the usage!
	result["usage"] = PROPERTY_USAGE_GROUP
	result["hint_string"] = prefix
	return result

static func group_end() -> Dictionary:
	return group("")

static func node(propname: String, node_class: StringName) -> Dictionary:
	var result = _base(propname, TYPE_OBJECT)
	result["hint"] = PROPERTY_HINT_NODE_TYPE
	result["class_name"] = node_class
	result["hint_string"] = node_class
	return result

static func string(propname: String) -> Dictionary:
	return _base(propname, TYPE_STRING)

static func subgroup(subgroup_name: String, prefix: String = "") -> Dictionary:
	var result := _base(subgroup_name, TYPE_NIL)
	# Overwrite the usage!
	result["usage"] = PROPERTY_USAGE_SUBGROUP
	result["hint_string"] = prefix
	return result

static func subgroup_end() -> Dictionary:
	return subgroup("")
