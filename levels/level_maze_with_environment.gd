class_name LevelMazeWithEnvironment
extends LevelMaze

@export var update_portals_when_environments_change := true

@onready var _world_env : WorldEnvironment = %WorldEnvironment

signal environment_changed()

func toggle_environment_changes() -> void:
	var current_env := _world_env.environment
	
	match current_env.ambient_light_source:
		Environment.AmbientSource.AMBIENT_SOURCE_BG:
			current_env.ambient_light_source = Environment.AmbientSource.AMBIENT_SOURCE_COLOR
			current_env.ambient_light_color = Color.FUCHSIA
			
		Environment.AmbientSource.AMBIENT_SOURCE_COLOR:
			current_env.ambient_light_source = Environment.AMBIENT_SOURCE_BG
	
	environment_changed.emit()
	
func setup_auto_portal_env_auto_update(node: Node) -> void:
	if node is Portal3D:
		environment_changed.connect(func(): 
			if update_portals_when_environments_change:
				node.request_environement_reset()
		)
	for child in node.get_children():
		setup_auto_portal_env_auto_update(child)
	
func update_status_hud() -> void:
	%Label_Status.text = ("Portals auto-update environment: %s" % ("yes" if update_portals_when_environments_change else "no")).capitalize()
	
func _ready() -> void:
	super()
	setup_auto_portal_env_auto_update(self)
	update_status_hud()
	
func _process(_delta: float) -> void:
	
	if Input.is_action_just_pressed("toggle_environment_changes"):
		toggle_environment_changes()
		
	if Input.is_action_just_pressed("toggle_portals_env_auto_update"):
		update_portals_when_environments_change = not update_portals_when_environments_change
		update_status_hud()
	
