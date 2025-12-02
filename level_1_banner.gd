extends CanvasLayer

@onready var banner := $Panel
@onready var player := $"../Player"
var can_dismiss := false
var blocked_keys := [
	KEY_W, KEY_A, KEY_S, KEY_D,
	KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT,
	KEY_SPACE, KEY_ENTER
]

var block_input := true

func _ready() -> void:
	banner.visible = true
	var start_pos = banner.position + Vector2(0, -120)
	var end_pos = banner.position
	banner.position = start_pos
	banner.modulate.a = 0.0

	set_process_input(true)

	var tween := create_tween()
	tween.tween_property(banner, "position", end_pos, 0.4)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(banner, "modulate:a", 1.0, 0.4)
	tween.tween_callback(func():
		can_dismiss = true
		# Disable player input
		if player.has_method("set_input_enabled"):
			player.set_input_enabled(false)
		else:
			player.set_physics_process(false)
			player.set_process(false)
	)

func _input(event: InputEvent) -> void:
	# Only allow Shift to dismiss
	if can_dismiss and event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.keycode == KEY_SHIFT:
			can_dismiss = false
			_fade_out_and_hide()
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
