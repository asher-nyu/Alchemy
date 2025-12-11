extends CanvasLayer

@onready var banner := $Panel
@onready var player := $"../Player"
@onready var guide_button := $GuideButton
var can_dismiss := false
var blocked_keys := [
KEY_W, KEY_A, KEY_S, KEY_D,
KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT,
KEY_SPACE, KEY_ENTER
]
var block_input := true
var guide_pause_mode := false
var tap_sound = AudioStreamPlayer.new()

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	set_process_input(true)
	
	add_child(tap_sound)
	tap_sound.stream = load("res://assets/Audio Pack/tap.wav")
	
	var current_scene_path = get_tree().current_scene.scene_file_path
	var is_level_1 = current_scene_path.ends_with("level_1.tscn")
	if is_level_1:
		guide_button.hide()
		banner.visible = true
		var end_pos = banner.position
		var start_pos = banner.position + Vector2(0, -120)
		banner.position = start_pos
		banner.modulate.a = 0.0
		var tween := create_tween()
		tween.tween_property(banner, "position", end_pos, 0.4)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(banner, "modulate:a", 1.0, 0.4)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_callback(func():
			can_dismiss = true
			# Disable player input
			if player.has_method("set_input_enabled"):
				player.set_input_enabled(false)
			else:
				player.set_physics_process(false)
				player.set_process(false)
		)
	else:
		banner.visible = false
		var start_pos = guide_button.position + Vector2(60, 0)
		var end_pos = guide_button.position
		guide_button.position = start_pos
		guide_button.show()
		var tween := create_tween()
		tween.tween_property(guide_button, "position", end_pos, 0.4)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _input(event: InputEvent) -> void:
	_process_guide_freeze(event)
	# Only allow Shift to dismiss
	if can_dismiss and event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.keycode == KEY_SHIFT:
			can_dismiss = false
			_fade_out_and_hide()
			var start_pos = guide_button.position + Vector2(60, 0)
			var end_pos = guide_button.position
			guide_button.position = start_pos
			guide_button.show()
			var tween := create_tween()
			tween.tween_property(guide_button, "position", end_pos, 0.4)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			# Re-enable player input
			if player.has_method("set_input_enabled"):
				player.set_input_enabled(true)
			else:
				player.set_physics_process(true)
				player.set_process(true)

func _fade_out_and_hide() -> void:
	var tween := create_tween()
	tween.tween_property(banner, "modulate:a", 0.0, 0.7)
	tween.tween_callback(banner.hide)

func show_guide() -> void:
	guide_pause_mode = true
	can_dismiss = false
	get_tree().paused = true
	var end_pos = banner.position
	var start_pos = banner.position + Vector2(0, -120)
	banner.position = start_pos
	banner.modulate.a = 0.0
	banner.show()
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(banner, "position", end_pos, 0.4)\
	.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(banner, "modulate:a", 1.0, 0.4)\
	.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func():
		can_dismiss = true
	)

func _on_guide_button_pressed() -> void:
	
	if tap_sound and not tap_sound.playing:
			tap_sound.play()
			
	guide_button.disabled = true  # Prevent multiple clicks
	var start_pos = guide_button.position
	var end_pos = guide_button.position + Vector2(60, 0)
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(guide_button, "position", end_pos, 0.4)\
	.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(guide_button, "modulate:a", 0.0, 0.4)\
	.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func():
		guide_button.hide()
		guide_button.modulate.a = 1.0  # Reset alpha for next show
		guide_button.position = start_pos  # Reset position for next show
		guide_button.disabled = false
	)
	show_guide()

func _process_guide_freeze(event: InputEvent) -> void:
	# If not in guide freeze mode, skip this
	if not guide_pause_mode:
		return
	# Always block ALL input except SHIFT
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		# SHIFT → close banner + unpause + resume game
		if event.keycode == KEY_SHIFT:
			guide_pause_mode = false
			get_tree().paused = false
			_fade_out_and_hide()
			var start_pos = guide_button.position + Vector2(60, 0)
			var end_pos = guide_button.position
			guide_button.position = start_pos
			guide_button.show()
			var tween := create_tween()
			tween.tween_property(guide_button, "position", end_pos, 0.4)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			# Reset dismissal state
			can_dismiss = false
			# Re-enable player movement
			if player.has_method("set_input_enabled"):
				player.set_input_enabled(true)
			else:
				player.set_physics_process(true)
				player.set_process(true)
			# VERY IMPORTANT: consume event
			get_viewport().set_input_as_handled()
			return
		# Any other key → block
		get_viewport().set_input_as_handled()
		return
	# All non-keyboard or released keys → block
	get_viewport().set_input_as_handled()
