extends Node2D

@export var fall_distance_px: float = 370.0
@export var interval_seconds: float = 3.0
@export var gravity: float = 980.0
@export var damage_amount: int = 10  # How much HP the drop removes on hit

var sprite: Sprite2D
var start_y: float
var target_y: float
var vel_y: float = 0.0
var is_falling: bool = false
var drop_sound: AudioStreamPlayer
@onready var interval_timer: Timer = Timer.new()

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
	
	# Setup interval timer (pauses with tree pause)
	add_child(interval_timer)
	interval_timer.wait_time = interval_seconds
	interval_timer.one_shot = true
	interval_timer.timeout.connect(_on_interval_timeout)
	
	# Start the first drop
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
		_end_drop()

func _end_drop() -> void:
	"""Called when drop reaches bottom (no player hit)"""
	sprite.visible = false
	is_falling = false
	vel_y = 0.0
	
	# Play drop sound
	if drop_sound:
		drop_sound.play()
	
	# Start timer for next drop
	interval_timer.start()

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
	
	# Deal damage instead of instant death
	if player and is_instance_valid(player) and player.has_method("take_damage"):
		player.take_damage(damage_amount)
	
	# Start timer for next drop
	interval_timer.start()

func _on_interval_timeout() -> void:
	"""Timer finished: start next drop"""
	_start_next_drop()

func _start_next_drop() -> void:
	sprite.position.y = start_y
	sprite.visible = true
	vel_y = 0.0
	is_falling = true
