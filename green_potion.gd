extends Sprite2D

func initialize(start_pos: Vector2):
	position = start_pos
	z_index = 100
	modulate.a = 0.0
	scale = Vector2(0.7,0.7)
	centered = true
	
	# Load texture
	if ResourceLoader.exists("res://assets/green_potion.png"):
		texture = load("res://assets/green_potion.png")

func animate_to_circle(target_pos: Vector2):
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Fade in
	tween.tween_property(self, "modulate:a", 1.0, 0.3)
	
	# Move to circle with bounce
	tween.tween_property(self, "position", target_pos, 1.0).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# Scale pulse effect
	var original_scale = scale
	tween.tween_property(self, "scale", original_scale * 1.3, 0.3)
	tween.chain().tween_property(self, "scale", original_scale, 0.7).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	
	await tween.finished

func pulse_forever():
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(self, "scale", scale * 1.2, 0.5)
	tween.tween_property(self, "scale", scale, 0.5)
