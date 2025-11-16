extends Node2D

@export var fall_distance_px: float = 1150.0
@export var interval_seconds: float = 3
@export var gravity: float = 980.0

var sprite: Sprite2D
var start_y: float
var target_y: float
var vel_y: float = 0.0
var is_falling: bool = false
var drop_sound: AudioStreamPlayer

func _ready() -> void:
	# Find the first Sprite2D child
	for child in get_children():
		if child is Sprite2D:
			sprite = child
			break
	if not sprite:
		push_error("NO SPRITE2D FOUND! Add a Sprite2D child.")
		return

	start_y = sprite.position.y
	target_y = start_y + fall_distance_px

	# Create AudioStreamPlayer for drop sound
	drop_sound = AudioStreamPlayer.new()
	add_child(drop_sound)
	drop_sound.stream = load("res://assets/Audio Pack/drop.wav")

	_start_next_drop()


func _process(delta: float) -> void:
	if not is_falling:
		return

	# Apply gravity
	vel_y += gravity * delta
	sprite.position.y += vel_y * delta

	# Collision with player
	var player = get_tree().get_first_node_in_group("Player")
	if player:
		var drop_size = sprite.texture.get_size() * sprite.scale
		var drop_rect = Rect2(sprite.global_position - drop_size * 0.5, drop_size)
		var player_rect = player.get_hitbox_rect()

		if drop_rect.intersects(player_rect):
			await _player_hit(player)
			return

	# Reached bottom
	if sprite.position.y >= target_y:
		sprite.visible = false
		is_falling = false
		vel_y = 0.0

		# Play drop sound at every drop end
		if drop_sound:
			drop_sound.play()

		# Schedule next drop
		get_tree().create_timer(interval_seconds).timeout.connect(_start_next_drop)


# Handles player being hit by drop
func _player_hit(player) -> void:
	is_falling = false

	# Hide player and drop immediately
	player.visible = false
	sprite.visible = false
	player.set_process(false)
	player.set_physics_process(false)

	# Play drop sound (optional, can play together)
	if drop_sound:
		drop_sound.play()

	# Play player death sound from the player node
	if player.hero_death_sound:
		player.hero_death_sound.play()
		var sound_length = player.hero_death_sound.stream.get_length()
		await get_tree().create_timer(sound_length).timeout

	# Then Game Over
	get_tree().change_scene_to_file("res://GameOverScreen.tscn")


func _start_next_drop() -> void:
	sprite.position.y = start_y
	sprite.visible = true
	vel_y = 0.0
	is_falling = true
