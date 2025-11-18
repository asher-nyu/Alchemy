extends Node2D

@export var fall_distance_px: float = 370.0
@export var interval_seconds: float = 3.0
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
		
		# Get player's collision shape for hitbox
		var player_hitbox = _get_player_hitbox(player)
		
		if drop_rect.intersects(player_hitbox):
			_player_hit(player)
			return
	
	# Reached bottom
	if sprite.position.y >= target_y:
		sprite.visible = false
		is_falling = false
		vel_y = 0.0
		
		# Play drop sound
		if drop_sound:
			drop_sound.play()
		
		# Schedule next drop
		await get_tree().create_timer(interval_seconds).timeout
		_start_next_drop()

func _get_player_hitbox(player) -> Rect2:
	# Assuming player has a CollisionShape2D
	for child in player.get_children():
		if child is CollisionShape2D:
			var shape = child.shape
			if shape is RectangleShape2D:
				var size = shape.size
				var pos = player.global_position + child.position - size / 2
				return Rect2(pos, size)
			elif shape is CapsuleShape2D:
				var radius = shape.radius
				var height = shape.height
				var size = Vector2(radius * 2, height)
				var pos = player.global_position + child.position - size / 2
				return Rect2(pos, size)
	
	# Fallback: use a default size around player position
	return Rect2(player.global_position - Vector2(20, 40), Vector2(40, 80))

func _player_hit(player) -> void:
	is_falling = false
	
	# Hide the drop immediately
	if sprite:
		sprite.visible = false

	# Play drop sound
	if drop_sound:
		drop_sound.play()
	
	# Call player's death method
	if player.has_method("_on_player_died"):
		player._on_player_died()
	
	# Schedule next drop
	await get_tree().create_timer(interval_seconds).timeout
	_start_next_drop()

func _start_next_drop() -> void:
	sprite.position.y = start_y
	sprite.visible = true
	vel_y = 0.0
	is_falling = true
