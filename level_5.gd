extends Area2D

@onready var player_ref = get_parent().get_node("Player")
@onready var queen_ref  = get_parent().get_node("Queen")
@onready var cage_ref   = get_parent().get_node("Cage")
@onready var camera_ref = get_parent().get_node("Camera2D")
@onready var portal_ref = get_parent().get_node("Portal")

@onready var animated_sprite = $AnimatedSprite2D
@onready var DIALOGUE_FONT: FontFile = load("Alchemy.otf") as FontFile
var cage: StaticBody2D = null
var is_freed = false

var dialogue_layer: CanvasLayer = null
var dialogue_panel: ColorRect = null
var dialogue_label: Label = null
var typing_tween: Tween = null
var continue_button: Button = null
var continue_tween: Tween = null
var _continue_clicked: bool = false

var dialogues_started := false

const CHARS_PER_SEC := 30.0      # faster typing
const MIN_LINGER := 0.8          # time to keep the full line visible after typing
const WORD_LINGER := 0.10        # extra linger per word (small, feels natural)

const QUEEN_FADE_START: float = 3.1  # when fade + portal sound should start

var type_sound: AudioStreamPlayer = AudioStreamPlayer.new()
var _type_sfx_pos: float = 0.0

var click = AudioStreamPlayer.new()
var DivineSpeech = AudioStreamPlayer.new()

var portal_sound: AudioStreamPlayer = AudioStreamPlayer.new()
const PORTAL_SFX_PATH := "res://assets/Audio Pack/portal2.wav"

signal queen_freed

func _ready():
	animated_sprite.play("idle")
	
	cage = get_parent().get_node_or_null("Cage")
	
	if cage:
		cage.cage_broken.connect(_on_cage_broken)
	
	click.stream = load("res://assets/Audio Pack/click.mp3")
	add_child(click)
	
	add_child(DivineSpeech)
	DivineSpeech.stream = load("res://assets/Audio Pack/DivineSpeech.mp3")
	
	add_child(type_sound)
	type_sound.stream = load("res://assets/Audio Pack/type_sound.mp3") as AudioStream
	
	add_child(portal_sound)
	portal_sound.stream = load(PORTAL_SFX_PATH)

	# Make it loop so it can run longer than the file length
	# (Works best with .ogg; mp3 looping can have tiny gaps depending on encoding)
	if type_sound.stream is AudioStreamMP3:
		(type_sound.stream as AudioStreamMP3).loop = true
	elif type_sound.stream is AudioStreamOggVorbis:
		(type_sound.stream as AudioStreamOggVorbis).loop = true
	elif type_sound.stream is AudioStreamWAV:
		(type_sound.stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD

	type_sound.stop()
	_type_sfx_pos = 0.0
	
	LevelManager.set_next_level(5)
	
	if portal_ref and portal_ref is AnimatedSprite2D:
		portal_ref.play("default")
	
	# Setup camera
	if camera_ref:
		camera_ref.enabled = true

func _on_cage_broken():
	await get_tree().create_timer(0.5).timeout
	walk_out_of_cage()

func walk_out_of_cage():
	animated_sprite.play("walk")
	animated_sprite.flip_h = false
	
	var walk_out_tween = create_tween()
	walk_out_tween.tween_property(self, "position", position + Vector2(250, 0), 1.5)
	await walk_out_tween.finished
	
	await wait_for_player()

func wait_for_player():
	"""Wait until player crosses to queen's side of the cage"""
	animated_sprite.play("idle")
	
	var player = get_tree().get_first_node_in_group("Player")
	if not player or not cage:
		await show_all_dialogues()
		return
	
	# Queen is to the right of the cage after walking out
	# Wait until player's x position is greater than cage's x position
	while player.global_position.x < (cage.global_position.x + 550):
		await get_tree().create_timer(0.1).timeout
	
	# Player has crossed to queen's side!
	await show_all_dialogues()

func show_all_dialogues():
	if dialogues_started:
		return
	dialogues_started = true
	
	await show_dialogue("The chains are broken.\nI am free once more.")
	
	var immort_text := "You stepped into fate without fear.\nFrom this moment on, death will not touch you."
	
	# Show the line and HOLD it on screen
	await show_dialogue(immort_text, true)
	
	# Ritual plays while the text stays visible
	await play_immortality_ritual()
	
	# Only after ritual ends: update health UI
	await grant_immortality()
	
	await wait_for_continue_click()
	
	await celebrate_freedom()

func celebrate_freedom():
	is_freed = true
	
	animated_sprite.play("idle")
	
	await show_dialogue(	"This place will soon stir.\nWe should not remain.")
	
	walk_away()
	
func walk_away():
	animated_sprite.play("walk")
	animated_sprite.flip_h = false
	modulate.a = 1.0

	# Fade duration = portal sound length
	var fade_dur: float = _portal_sfx_length(0.6)

	# Total walk time is "lead-in" + fade duration, so fade ends at the same time as walk + sound
	var walk_time: float = QUEEN_FADE_START + fade_dur
	var fade_delay: float = QUEEN_FADE_START

	# Start sound + (optional) synced queen anim exactly at fade start
	_start_queen_fade_fx(fade_delay, fade_dur)

	var walk_tween: Tween = create_tween()
	walk_tween.set_parallel(true)

	walk_tween.tween_property(self, "position", position + Vector2(1050, 0), walk_time)
	walk_tween.tween_property(self, "modulate:a", 0.0, fade_dur).set_delay(fade_delay)

	await walk_tween.finished

	visible = false
	finish_scene()


func _start_queen_fade_fx(delay: float, dur: float) -> void:
	await get_tree().create_timer(delay).timeout

	# Play portal sound at the SAME time fade starts
	if portal_sound:
		portal_sound.stop()
		portal_sound.play(0.0)

	# Optional: sync a queen disappear animation to dur
	var original_speed: float = animated_sprite.speed_scale
	if original_speed <= 0.001:
		original_speed = 1.0

	var fade_anim: String = "walk"
	var sf: SpriteFrames = animated_sprite.sprite_frames
	if sf != null and sf.has_animation("vanish"):
		fade_anim = "vanish"

	_sync_anim_to_duration(animated_sprite, fade_anim, dur)
	animated_sprite.play(fade_anim)

	await get_tree().create_timer(dur).timeout
	animated_sprite.speed_scale = original_speed
	
func finish_scene():
	if dialogue_panel:
		var fade_out := create_tween()
		fade_out.tween_property(dialogue_panel, "modulate:a", 0.0, 0.6)
		await fade_out.finished
		
		dialogue_layer.queue_free()
		dialogue_panel = null
		dialogue_label = null
	
	queen_freed.emit()
	
	var portal = get_parent().get_node_or_null("Portal")
	if portal and portal.has_method("arm_portal"):
		portal.arm_portal()	

func grant_immortality():
	var player: Node = get_tree().get_first_node_in_group("Player")
	if player == null:
		return
	
	var health_label: Label = player.get_node_or_null("Camera2D2/UI/HealthLabel") as Label
	if health_label == null:
		return
	
	# ---- UI update ----
	var immortal_color: Color = Color(0.3, 0.9, 1.0)
	health_label.text = "Health: ETERNAL"
	health_label.add_theme_color_override("font_color", immortal_color)
	
	# Strong, smooth bump on UI
	var original_scale: Vector2 = health_label.scale
	health_label.scale = original_scale * 1.6
	
	var ui_tween: Tween = create_tween()
	ui_tween.set_trans(Tween.TRANS_CUBIC)
	ui_tween.set_ease(Tween.EASE_OUT)
	ui_tween.tween_property(health_label, "scale", original_scale, 0.7)
	
	# ---- Player tint + animation ----
	# Try common player sprite node names first; adjust if yours differs
	var player_sprite: CanvasItem = null
	
	var s1: Node = player.get_node_or_null("AnimatedSprite2D")
	if s1 != null and s1 is CanvasItem:
		player_sprite = s1 as CanvasItem
	else:
		var s2: Node = player.get_node_or_null("Sprite2D")
		if s2 != null and s2 is CanvasItem:
			player_sprite = s2 as CanvasItem
	
	if player_sprite != null:
		var base: Color = player_sprite.modulate
		var flash: Color = Color(1.0, 1.0, 1.0)  # brief “holy flare”
		
		# Quick flare, then settle into permanent immortal tint
		var tint_tween: Tween = create_tween()
		tint_tween.set_trans(Tween.TRANS_SINE)
		tint_tween.set_ease(Tween.EASE_OUT)
		
		tint_tween.tween_property(player_sprite, "modulate", flash, 0.12)
		tint_tween.tween_property(player_sprite, "modulate", immortal_color, 0.55)
		
		# Optional: tiny pulse scale on player sprite (feels powerful)
		var original_p_scale: Vector2 = player_sprite.scale
		player_sprite.scale = original_p_scale * 1.08
		
		var pulse: Tween = create_tween()
		pulse.set_trans(Tween.TRANS_CUBIC)
		pulse.set_ease(Tween.EASE_OUT)
		pulse.tween_property(player_sprite, "scale", original_p_scale, 0.35)
	
	await ui_tween.finished
	
func create_dialogue_ui():
	if dialogue_panel:
		return
	
	dialogue_layer = CanvasLayer.new()
	dialogue_layer.layer = 100
	get_tree().root.add_child(dialogue_layer)
	
	dialogue_panel = ColorRect.new()
	dialogue_panel.color = Color(0.05, 0.05, 0.08, 0.85)
	
	var screen_size = get_viewport().get_visible_rect().size
	dialogue_panel.size = Vector2(screen_size.x, 180)
	dialogue_panel.position = Vector2(0, screen_size.y - 180)
	dialogue_panel.modulate.a = 0.0
	
	dialogue_layer.add_child(dialogue_panel)
	
	var border = ReferenceRect.new()
	border.border_color = Color(0.9, 0.8, 0.5)
	border.border_width = 2.0
	border.size = dialogue_panel.size
	dialogue_panel.add_child(border)
	
	dialogue_label = Label.new()
	var text_width := 760
	dialogue_label.size = Vector2(text_width, dialogue_panel.size.y - 48)
	dialogue_label.position = Vector2(
		(dialogue_panel.size.x - text_width) / 2,
		24
	)
	dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	dialogue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	dialogue_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dialogue_label.add_theme_font_override("font", DIALOGUE_FONT)
	dialogue_label.add_theme_font_size_override("font_size", 22)
	dialogue_label.add_theme_color_override("font_color", Color(0.95, 0.95, 1.0))
	
	dialogue_panel.add_child(dialogue_label)

	# Click-to-continue button (▶)
	continue_button = Button.new()
	continue_button.text = "▶"
	continue_button.flat = true
	continue_button.focus_mode = Control.FOCUS_NONE
	continue_button.mouse_filter = Control.MOUSE_FILTER_STOP
	continue_button.add_theme_font_override("font", DIALOGUE_FONT)
	continue_button.add_theme_font_size_override("font_size", 26)
	continue_button.add_theme_color_override("font_color", Color(0.9, 0.8, 0.5))
	continue_button.size = Vector2(44, 44)
	continue_button.position = Vector2(dialogue_panel.size.x - 60, dialogue_panel.size.y - 56)
	continue_button.visible = false
	continue_button.pressed.connect(_on_continue_pressed)
	dialogue_panel.add_child(continue_button)
	
	var fade_in := create_tween()
	fade_in.tween_property(dialogue_panel, "modulate:a", 1.0, 0.25)
	await fade_in.finished

func show_dialogue(text: String, hold: bool = false):
	animated_sprite.play("idle")
	await get_tree().process_frame
	
	await create_dialogue_ui()
	
	# Stop any previous typing cleanly
	if typing_tween:
		typing_tween.kill()
		typing_tween = null
		_typing_sfx_stop()
	
	if continue_tween:
		continue_tween.kill()
		continue_tween = null
	
	if not dialogue_label:
		return
	
	_continue_clicked = false
	
	dialogue_label.text = text
	
	var char_count: int = text.length()
	if char_count < 1:
		char_count = 1
	
	var typing_time: float = float(char_count) / CHARS_PER_SEC
	
	dialogue_label.visible_characters = 0
	
	# Never show ▶ during typing
	if continue_button:
		continue_button.visible = false
	
	_typing_sfx_start()
	
	typing_tween = create_tween()
	typing_tween.tween_property(dialogue_label, "visible_characters", char_count, typing_time)\
		.set_trans(Tween.TRANS_LINEAR)\
		.set_ease(Tween.EASE_IN_OUT)
	
	while dialogue_label.visible_characters < char_count:
		await get_tree().process_frame
	_typing_sfx_stop()
	
	# Hold means: keep the line up, do NOT wait for click here
	if hold:
		if continue_button:
			continue_button.visible = false
		return
	
	# Now fully typed: blink ▶ and wait for click to proceed
	if continue_button:
		continue_button.visible = true
		continue_button.modulate.a = 1.0
		
		continue_tween = create_tween()
		continue_tween.set_loops()
		continue_tween.tween_property(continue_button, "modulate:a", 0.25, 0.35)
		continue_tween.tween_property(continue_button, "modulate:a", 1.0, 0.35)
	
	while not _continue_clicked:
		await get_tree().process_frame
	
	_continue_clicked = false
	
	if continue_tween:
		continue_tween.kill()
		continue_tween = null
	
	if continue_button:
		continue_button.visible = false		
		
func _get_anim_duration(anim_name: String) -> float:
	var sf: SpriteFrames = animated_sprite.sprite_frames
	if sf == null:
		return 1.0
	if not sf.has_animation(anim_name):
		return 1.0
	
	var frame_count: int = sf.get_frame_count(anim_name)
	var total: float = 0.0
	
	for i in range(frame_count):
		total += sf.get_frame_duration(anim_name, i)
	
	var speed: float = sf.get_animation_speed(anim_name)
	if speed > 0.0:
		total /= speed
	
	# account for AnimatedSprite2D speed_scale
	var s: float = animated_sprite.speed_scale
	if s <= 0.001:
		s = 0.001
	
	return total / s

func play_immortality_ritual():
	var anim: String = "special"
	var sf: SpriteFrames = animated_sprite.sprite_frames
	if sf == null or not sf.has_animation(anim):
		return
	
	# Ensure special isn't looping (or it will never "finish")
	if sf.has_method("set_animation_loop"):
		sf.set_animation_loop(anim, false)
	
	# --- Start DivineSpeech ONCE ---
	var audio_len: float = 0.0
	if DivineSpeech != null and DivineSpeech.stream != null:
		audio_len = DivineSpeech.stream.get_length()
		DivineSpeech.stop()
		DivineSpeech.play(0.0)
	
	# Save current speed_scale so we can restore it later
	var original_speed: float = animated_sprite.speed_scale
	if original_speed <= 0.001:
		original_speed = 1.0
	
	# Get the current duration of one "special" play (this already accounts for current speed_scale)
	var one_play_current: float = _get_anim_duration(anim)
	
	# Convert it to "raw" duration at speed_scale = 1.0
	var one_play_raw: float = one_play_current * animated_sprite.speed_scale
	
	# If we have a valid audio length, sync 3 plays to finish exactly with it
	if audio_len > 0.05:
		var target_one_play: float = audio_len / 3.0
		
		# duration = raw / speed_scale  => speed_scale = raw / target_duration
		var new_speed: float = one_play_raw / target_one_play
		
		# Allow wide range so it truly syncs (tight clamping can break sync)
		if new_speed < 0.05:
			new_speed = 0.05
		if new_speed > 10.0:
			new_speed = 10.0
		
		animated_sprite.speed_scale = new_speed
		
		# Now each play should last ~ target_one_play seconds
		for i in range(3):
			animated_sprite.play(anim)
			await get_tree().create_timer(target_one_play).timeout
	else:
		# Fallback: no audio length known, just play 3 times using animation duration
		var dur: float = _get_anim_duration(anim)
		for i in range(3):
			animated_sprite.play(anim)
			await get_tree().create_timer(dur).timeout
	
	animated_sprite.play("idle")
	animated_sprite.speed_scale = original_speed
	
	if DivineSpeech != null and DivineSpeech.playing:
		if DivineSpeech.has_signal("finished"):
			await DivineSpeech.finished

func _typing_sfx_start():
	if type_sound.stream == null:
		return

	# Always explicitly start when needed
	type_sound.stop()
	type_sound.play(_type_sfx_pos)


func _typing_sfx_stop():
	if type_sound.stream == null:
		return

	if type_sound.playing:
		_type_sfx_pos = type_sound.get_playback_position()

		var len := type_sound.stream.get_length()
		if len > 0.0 and _type_sfx_pos >= len:
			_type_sfx_pos = fmod(_type_sfx_pos, len)

	# Stop is more reliable than stream_paused on HTML5
	type_sound.stop()

func _on_continue_pressed():
	if click and not click.playing:
		click.play()
	_continue_clicked = true

func wait_for_continue_click():
	if continue_button == null:
		return
	
	_continue_clicked = false
	
	if continue_tween:
		continue_tween.kill()
		continue_tween = null
	
	continue_button.visible = true
	continue_button.modulate.a = 1.0
	
	continue_tween = create_tween()
	continue_tween.set_loops()
	continue_tween.tween_property(continue_button, "modulate:a", 0.25, 0.35)
	continue_tween.tween_property(continue_button, "modulate:a", 1.0, 0.35)
	
	while not _continue_clicked:
		await get_tree().process_frame
	
	_continue_clicked = false
	
	if continue_tween:
		continue_tween.kill()
		continue_tween = null
	
	continue_button.visible = false

func _anim_duration(sprite: AnimatedSprite2D, anim_name: String) -> float:
	var sf: SpriteFrames = sprite.sprite_frames
	if sf == null or not sf.has_animation(anim_name):
		return 0.0

	var frame_count: int = sf.get_frame_count(anim_name)
	var total: float = 0.0
	for i in range(frame_count):
		total += sf.get_frame_duration(anim_name, i)

	var speed: float = sf.get_animation_speed(anim_name)
	if speed > 0.0:
		total /= speed

	var s: float = sprite.speed_scale
	if s <= 0.001:
		s = 1.0

	return total / s


func _sync_anim_to_duration(sprite: AnimatedSprite2D, anim_name: String, target_seconds: float) -> void:
	if target_seconds <= 0.01:
		return

	var current: float = _anim_duration(sprite, anim_name)
	if current <= 0.01:
		return

	var s: float = sprite.speed_scale
	if s <= 0.001:
		s = 1.0

	var raw: float = current * s
	var new_speed: float = raw / target_seconds
	new_speed = clampf(new_speed, 0.05, 10.0)

	sprite.speed_scale = new_speed


func _portal_sfx_length(default_len: float = 0.6) -> float:
	if portal_sound == null or portal_sound.stream == null:
		return default_len
	var l: float = portal_sound.stream.get_length()
	return l if l > 0.05 else default_len
