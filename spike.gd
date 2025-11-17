extends Area2D

@export var kill_delay := 0.5

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if body.is_in_group("Player"):
		# Prevent retrigger
		set_monitoring(false)
		
		if body.has_method("die"):
			body.die()
