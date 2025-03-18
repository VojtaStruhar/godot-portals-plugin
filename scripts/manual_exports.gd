@tool
extends Node
class_name ManualExports

var favorite_number: float = 42.0

enum Direction { IN, OUT, IN_AND_OUT }
var dir: Direction = Direction.IN_AND_OUT

var is_debug: bool = true:
	set(v):
		is_debug = v
		notify_property_list_changed()

var _tb_debug: Callable = _debug_action


var usages = [
	PROPERTY_USAGE_NONE,
	PROPERTY_USAGE_STORAGE,
	PROPERTY_USAGE_EDITOR,
	PROPERTY_USAGE_INTERNAL,
	PROPERTY_USAGE_CHECKABLE,
	PROPERTY_USAGE_CHECKED,
	PROPERTY_USAGE_GROUP,
	PROPERTY_USAGE_CATEGORY,
	PROPERTY_USAGE_SUBGROUP,
	PROPERTY_USAGE_CLASS_IS_BITFIELD,
	PROPERTY_USAGE_NO_INSTANCE_STATE,
	PROPERTY_USAGE_RESTART_IF_CHANGED,
	PROPERTY_USAGE_SCRIPT_VARIABLE,
	PROPERTY_USAGE_STORE_IF_NULL,
	PROPERTY_USAGE_UPDATE_ALL_IF_MODIFIED,
	PROPERTY_USAGE_SCRIPT_DEFAULT_VALUE,
	PROPERTY_USAGE_CLASS_IS_ENUM,
	PROPERTY_USAGE_NIL_IS_VARIANT,
	PROPERTY_USAGE_ARRAY,
	PROPERTY_USAGE_ALWAYS_DUPLICATE,
	PROPERTY_USAGE_NEVER_DUPLICATE,
	PROPERTY_USAGE_HIGH_END_GFX,
	PROPERTY_USAGE_NODE_PATH_FROM_SCENE_ROOT,
	PROPERTY_USAGE_RESOURCE_NOT_PERSISTENT,
	PROPERTY_USAGE_KEYING_INCREMENTS,
	PROPERTY_USAGE_DEFERRED_SET_RESOURCE,
	PROPERTY_USAGE_EDITOR_INSTANTIATE_OBJECT,
	PROPERTY_USAGE_EDITOR_BASIC_SETTING,
	PROPERTY_USAGE_READ_ONLY,
	PROPERTY_USAGE_SECRET,
	PROPERTY_USAGE_DEFAULT # This is redundant
]
var usage_names = [
	"NONE",
	"STORAGE",
	"EDITOR",
	"INTERNAL",
	"CHECKABLE",
	"CHECKED",
	"GROUP",
	"CATEGORY",
	"SUBGROUP",
	"CLASS_IS_BITFIELD",
	"NO_INSTANCE_STATE",
	"RESTART_IF_CHANGED",
	"SCRIPT_VARIABLE",
	"STORE_IF_NULL",
	"UPDATE_ALL_IF_MODIFIED",
	"SCRIPT_DEFAULT_VALUE",
	"CLASS_IS_ENUM",
	"NIL_IS_VARIANT",
	"ARRAY",
	"ALWAYS_DUPLICATE",
	"NEVER_DUPLICATE",
	"HIGH_END_GFX",
	"NODE_PATH_FROM_SCENE_ROOT",
	"RESOURCE_NOT_PERSISTENT",
	"KEYING_INCREMENTS",
	"DEFERRED_SET_RESOURCE",
	"EDITOR_INSTANTIATE_OBJECT",
	"EDITOR_BASIC_SETTING",
	"READ_ONLY",
	"SECRET",
	"DEFAULT"
	]

func _debug_action() -> void:
	print_rich("[color=orange]Manual exports - debug action![/color]")
	for prop in get_property_list():
		if prop["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE and prop["usage"] & PROPERTY_USAGE_DEFAULT:
			var usage_report: Array[String] = []
			var i = 0
			for usage in usages:
				if prop["usage"] & usage:
					usage_report.append(usage_names[i])
				i += 1
			
			print("  - ", prop)
			print_rich("    - [i]%s[/i]" % ", ".join(usage_report))
			



func _get_property_list() -> Array[Dictionary]:
	var config: Array[Dictionary] = []
	
	config.append({
		"name": "favorite_number",
		"type": TYPE_FLOAT,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "0.0,100.0,1.0",
		"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})
	config.append({
		"name": "dir",
		"type": TYPE_INT,
		"class_name": &"ManualExports.Direction",
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": ",".join(Direction.keys()),
		"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_CLASS_IS_ENUM | PROPERTY_USAGE_SCRIPT_VARIABLE
	})
	config.append({
		"name": "is_debug",
		"type": TYPE_BOOL,
		"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})
	if is_debug:
		config.append({
			"name": "_tb_debug",
			"type": TYPE_CALLABLE,
			"hint": PROPERTY_HINT_TOOL_BUTTON,
			"hint_string": "Debug Action",
			"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})
	
	return config

func _property_can_revert(property: StringName) -> bool:
	return property in [
		&"favorite_number",
		&"dir"
	]

func _property_get_revert(property: StringName) -> Variant:
	return {
		&"favorite_number": 42.0,
		&"dir": Direction.IN_AND_OUT
	}[property]
