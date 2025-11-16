extends Area2D

@export var kill_delay := 0.5

func _ready():
	connect("body_entered", Callable(self, "_on_body_entered"))

func _on_body_entered(body):
	if body.is_in_group("Player"):
		# Prevent retrigger
		set_monitoring(false)
		disconnect("body_entered", Callable(self, "_on_body_entered"))

		# Start pixel death
		body.start_pixel_death(kill_delay)
