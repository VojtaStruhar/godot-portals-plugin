@tool
extends Node
class_name NormalExports

@export_range(0, 100, 1, "or_greater") var favorite_number: float = 42.0

enum Direction { IN, OUT, IN_AND_OUT }
@export var dir: Direction = Direction.IN_AND_OUT

@export var is_debug: bool = true

@export_tool_button("Debug Action", "Node")
var _tb_debug: Callable = _debug_action

@export var is_teleport: bool = true
@export_group("Teleport stuff", "teleport_")
@export var teleport_tolerance: float = 0.1
@export_subgroup("Extra properties", "teleport_")
@export_flags_3d_physics var teleport_layer: int = 0

@export_group("") # break out of the group

@export var your_name: String = "Vojta"

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
	print_rich("[color=green]Default exports - debug action![/color]")
	for prop in get_property_list():
		if (prop["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE > 0) and (prop["usage"] & PROPERTY_USAGE_EDITOR > 0):
			var usage_report: Array[String] = []
			var i = 0
			for usage in usages:
				if prop["usage"] & usage:
					usage_report.append(usage_names[i])
				i += 1
			
			print("  - ", prop)
			print_rich("    - [i]%s[/i]" % ", ".join(usage_report))
