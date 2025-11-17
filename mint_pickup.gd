extends Control

@onready var sprite: TextureRect = $Sprite

func _ready():
	# Setup the sprite
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite.custom_minimum_size = Vector2(64, 64)
	sprite.position = Vector2(-32, -32)  # Center it
	
	# Start animation
	animate_to_corner()

func animate_to_corner():
	var target_pos = Vector2(150, 600)
	
	scale = Vector2(0.1, 0.1)
	
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Pop in with spin
	tween.tween_property(self, "scale", Vector2(2.0, 2.0), 0.3)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	
	# Spin
	tween.tween_property(self, "rotation", TAU, 0.9)\
		.set_ease(Tween.EASE_OUT)
	
	# Fly to corner
	tween.tween_property(self, "position", target_pos, 0.6)\
		.set_delay(0.3).set_ease(Tween.EASE_IN_OUT)
	
	# Shrink to final size
	tween.tween_property(self, "scale", Vector2(0.5, 0.5), 0.6)\
		.set_delay(0.3).set_ease(Tween.EASE_IN)
	
	# Reset rotation to 0 at the end
	tween.tween_property(self, "rotation", 0.0, 0.1)\
		.set_delay(0.9)
	
	# Mint stays in corner permanently
	await tween.finished

func set_start_position(world_pos: Vector2, camera: Camera2D):
	# Convert world position to screen position
	var screen_center = get_viewport_rect().size / 2
	var offset = world_pos - camera.global_position
	var screen_pos = screen_center + (offset * camera.zoom)
	position = screen_pos
