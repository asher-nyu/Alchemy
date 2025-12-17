extends StaticBody2D

@onready var sprite = $Sprite2D
@onready var collision_shape = $CollisionShape2D

var cage_closed_texture = preload("res://assets/cage_closed.png")
var cage_broken_texture = preload("res://assets/cage_broken.png")

var hits_remaining = 3
var is_broken = false
var interaction_label: Label = null

const PUNCH_RANGE = 260.0  # Distance player can punch from

var punch_cage_sound = AudioStreamPlayer.new()

signal cage_broken

func _ready():
	sprite.texture = cage_closed_texture
	create_interaction_label()
	add_child(punch_cage_sound)
	punch_cage_sound.stream = load("res://assets/Audio Pack/punch_cage_sound.wav")

func create_interaction_label():
	interaction_label = Label.new()
	interaction_label.text = "Smash the cage!\n(SPACE / ENTER)"
	var custom_font := load("Alchemy.otf") as FontFile
	interaction_label.add_theme_font_override("font", custom_font)
	interaction_label.position = Vector2(-89.778, -210)
	interaction_label.visible = false
	interaction_label.add_theme_font_size_override("font_size", 24)
	interaction_label.add_theme_color_override("font_color", Color.YELLOW)
	add_child(interaction_label)

func _process(_delta):
	if is_broken:
		return
	
	# Find player and check distance
	var player = get_tree().get_first_node_in_group("Player")
	if player:
		var distance = global_position.distance_to(player.global_position)
		
		if distance <= PUNCH_RANGE:
			# Player is close enough
			if not interaction_label.visible:
				update_label_text()
				interaction_label.visible = true
			
			# Check for punch input
			if Input.is_action_just_pressed("ui_accept"):
				take_hit()
		else:
			# Player is too far
			if interaction_label.visible:
				interaction_label.visible = false

func take_hit():
	
	if punch_cage_sound and not punch_cage_sound.playing:
		punch_cage_sound.play()

	hits_remaining -= 1
	
	# Shake effect
	var original_pos = sprite.position
	var tween = create_tween()
	tween.tween_property(sprite, "position", original_pos + Vector2(10, 0), 0.05)
	tween.tween_property(sprite, "position", original_pos + Vector2(-10, 0), 0.05)
	tween.tween_property(sprite, "position", original_pos, 0.05)
	
	
	if hits_remaining <= 0:
		break_cage()
	else:
		update_label_text()

func update_label_text():
	if interaction_label:
		interaction_label.text = "Smash the cage! (%d hits left)\n(SPACE / ENTER)" % hits_remaining

func break_cage():
	is_broken = true
	sprite.texture = cage_broken_texture
	
	# Remove collision so player can walk through
	if collision_shape:
		collision_shape.disabled = true
	
	if interaction_label:
		interaction_label.visible = false
	
	# Particle effect when cage breaks
	create_break_particles()
	
	cage_broken.emit()

func create_break_particles():
	for i in range(15):
		var particle = ColorRect.new()
		particle.size = Vector2(8, 8)
		particle.color = Color(0.8, 0.7, 0.2)
		particle.position = global_position + Vector2(randf() * 100 - 50, randf() * 100 - 50)
		get_parent().add_child(particle)
		
		var tween = create_tween()
		var target = particle.position + Vector2(randf() * 150 - 75, randf() * 150 - 75)
		tween.tween_property(particle, "position", target, 1.0)
		tween.tween_property(particle, "modulate:a", 0.0, 1.0)
		tween.tween_callback(particle.queue_free)
