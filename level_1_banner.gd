extends CanvasLayer

func _ready():
	var banner = $Panel
	banner.visible = true

	# Slide in from above
	var start_pos = banner.position + Vector2(0, -120)
	var end_pos = banner.position
	banner.position = start_pos
	banner.modulate.a = 0.0  # start invisible

	var tween = create_tween()
	# Slide in and fade in
	tween.tween_property(banner, "position", end_pos, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(banner, "modulate:a", 1.0, 0.4)

	# Wait on screen
	tween.tween_interval(3.0)  # show for 3 seconds

	# Fade out
	tween.tween_property(banner, "modulate:a", 0.0, 0.7)
	tween.connect("finished", Callable(banner, "hide"))
