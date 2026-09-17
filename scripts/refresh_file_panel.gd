@tool
class_name _RefreshFilePanel extends EditorScript

func _run() -> void:
	var fs := EditorInterface.get_resource_filesystem()
	if not fs.is_scanning():
		fs.scan()
