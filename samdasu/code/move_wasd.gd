extends CharacterBody2D
@export var speed: float = 20

func _physics_process(delta: float):
	var direction = Input.get_vector("ui_left","ui_right", "ui_up", "ui_down")
	print(direction)
	velocity =direction*speed
	move_and_slide()
