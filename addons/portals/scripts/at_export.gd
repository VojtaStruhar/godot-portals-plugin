class_name AtExport

## Helper class for defining custom export inspector.
##
## Instead of [code]@export var foo: int = 0[/code] you could return
## [code]AtExport.int_("foo")[/code] in your [method Object._get_property_list]

static func int_() -> Dictionary:
	return {}
