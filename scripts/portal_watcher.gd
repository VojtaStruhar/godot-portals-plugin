extends TextureRect


@export var portal: Portal3D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if portal:
		await RenderingServer.frame_post_draw
		texture = portal.portal_viewport.get_texture()
		
		var label = Label.new()
		label.text = portal.name
		label.anchor_left = 0
		label.anchor_top = 0
		self.add_child(label)
