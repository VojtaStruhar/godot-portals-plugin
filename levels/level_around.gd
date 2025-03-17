extends Node3D

@onready var portal_activator_a: Area3D = $PortalActivator_A
@onready var player: CharacterBody3D = $Player


func _ready() -> void:
	# Initial portal setup. No events are triggered at this point, so do it manually.
	portal_activator_a._on_body_exited(player)
