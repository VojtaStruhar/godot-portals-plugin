extends Node3D

const BallScene := preload("uid://cdr0bql7jj43n")

@onready var trophy: Node3D = $Trophy
@onready var trophy_pickup_area: Area3D = $Trophy/PickupArea

@onready var congratulatory_light: Light3D = $SpotLight3D
@onready var red_portal_1: Portal3D = $RedPortal_1
@onready var red_portal_2: Portal3D = $RedPortal_2
@onready var ball_spawner: Node3D = $BallSpawner


func _ready() -> void:
	trophy_pickup_area.body_entered.connect(congratulate)


func congratulate(_body: Node3D) -> void:
	trophy.hide()
	congratulatory_light.show()
	red_portal_1.activate()
	red_portal_2.activate()
	for i in range(3):
		await get_tree().create_timer(0.1, true, true).timeout
		var ball: RigidBody3D = BallScene.instantiate()
		add_child(ball)
		ball.global_position = ball_spawner.global_position
