extends AnimatedSprite2D

func _ready():
	play("default")
	animation_finished.connect(_on_animation_finished)

func set_direction(facing_left: bool):
	flip_h = facing_left

func _on_animation_finished():
	queue_free()
