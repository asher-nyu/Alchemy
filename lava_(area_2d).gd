

extends Area2D

func _ready():
	connect("body_entered", Callable(self, "_on_body_entered"))

func _on_body_entered(body):
	if body.is_in_group("Player"):
		# Pass the player's current x, but lava's y
		var lava_y = $LavaSprite2D.global_position.y  # lava surface
		body.melt_into_lava(body.global_position.x, lava_y)
