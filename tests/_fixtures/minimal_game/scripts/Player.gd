extends CharacterBody2D

@export var speed: float = 200.0

var velocity_debug: Vector2 = Vector2.ZERO


func _physics_process(delta: float) -> void:
	velocity_debug = velocity
	if velocity.length() > 0.001:
		move_and_slide()
