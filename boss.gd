extends CharacterBody2D

# BOSS STATS
@export var max_health: int = 1000
@export var current_health: int = 1000
@export var fly_speed: float = 150.0
@export var dive_speed: float = 300.0

# ATTACK SETTINGS
@export var fireball_damage: int = 15
@export var fireball_interval: float = 2.0
@export var dive_duration: float = 5.0
@export var dive_melee_damage: int = 30

# DISTANCE MANAGEMENT
@export var distance_in_front: float = 400.0  # How far in front of player to hover
@export var height_above_player: float = 200.0  # How high above player's GROUND position

# ENEMY SPAWNING
@export var enemy_scenes: Array[PackedScene] = []
@export var max_enemies_per_wave: int = 3

# PROJECTILE
@export var fireball_scene: PackedScene

# Internal state
var player: CharacterBody2D = null
var is_diving: bool = false
var player_ground_y: float = 0.0  # Player's Y position when on ground

@onready var sprite = $AnimatedSprite2D
@onready var collision_shape = $CollisionShape2D

func _ready() -> void:
	add_to_group("Enemy")
	player = get_tree().get_first_node_in_group("Player")
	
	# Initialize player's ground position
	if player:
		player_ground_y = player.global_position.y
	
	# Play the flying animation
	if sprite and sprite.sprite_frames:
		if sprite.sprite_frames.has_animation("fly"):
			sprite.play("fly")
		elif sprite.sprite_frames.has_animation("default"):
			sprite.play("default")
	
	# Start attack patterns
	fireball_loop()   # Shoot fireballs every 2 seconds
	dive_loop()       # Dive attack every 10 seconds

func _physics_process(delta: float) -> void:
	if not player:
		return
	
	# Face the player
	if player.global_position.x < global_position.x:
		sprite.flip_h = true
	else:
		sprite.flip_h = false
	
	if is_diving:
		# When diving, come down to player's level but maintain horizontal distance
		dive_maintain_distance()
		move_and_slide()
	else:
		# When flying, maintain position in front and above
		maintain_distance()
		move_and_slide()

func maintain_distance() -> void:
	"""Hover 400px in front and 200px above player's GROUND position"""
	
	# Track player's ground Y position (when they're standing, not jumping)
	if player.is_on_floor():
		player_ground_y = player.global_position.y
	
	# Determine which side to hover on
	var horizontal_offset = distance_in_front
	if player.global_position.x > global_position.x:
		# Player is to the right, hover to the left of player
		horizontal_offset = -distance_in_front
	
	# Target position: 400px in front (X), 200px above ground position (Y)
	var target_x = player.global_position.x + horizontal_offset
	var target_y = player_ground_y - height_above_player  # Above player's GROUND position
	var target_position = Vector2(target_x, target_y)
	
	# Move toward target position smoothly
	var direction = (target_position - global_position).normalized()
	var distance = global_position.distance_to(target_position)
	
	# Smooth movement - faster when far, slower when close
	if distance > 50:
		velocity = direction * fly_speed
	else:
		velocity = direction * fly_speed * 0.5

func dive_maintain_distance() -> void:
	"""When diving: come down to player's ground level, but stay 400px in front"""
	
	# Track player's ground Y position
	if player.is_on_floor():
		player_ground_y = player.global_position.y
	
	# Determine which side to be on
	var horizontal_offset = distance_in_front
	if player.global_position.x > global_position.x:
		horizontal_offset = -distance_in_front
	
	# Target: 400px in front (X), at player's GROUND level (Y) - not above!
	var target_x = player.global_position.x + horizontal_offset
	var target_y = player_ground_y  # Same level as player when on ground
	var target_position = Vector2(target_x, target_y)
	
	# Move toward target aggressively
	var direction = (target_position - global_position).normalized()
	velocity = direction * dive_speed

# ============ ATTACK 1: FIREBALL (Every 2 seconds) ============
func fireball_loop() -> void:
	while current_health > 0:
		await get_tree().create_timer(fireball_interval).timeout
		
		# Don't shoot while diving
		if not is_diving:
			shoot_fireball()

func shoot_fireball() -> void:
	if not fireball_scene:
		return
	
	if not player:
		return
	
	# Create fireball
	var fireball = fireball_scene.instantiate()
	get_parent().add_child(fireball)
	fireball.global_position = global_position
	
	# Aim at player
	var direction = (player.global_position - global_position).normalized()
	
	if fireball.has_method("launch"):
		fireball.launch(direction, fireball_damage)

# ============ ATTACK 2: DIVE ATTACK (Every 10 seconds, lasts 5 seconds) ============
func dive_loop() -> void:
	while current_health > 0:
		await get_tree().create_timer(10.0).timeout
		dive_attack()

func dive_attack() -> void:
	is_diving = true
	
	# Enable melee damage
	collision_layer = 1
	collision_mask = 1
	
	# Dive for 5 seconds - will chase player directly via _physics_process
	await get_tree().create_timer(dive_duration).timeout
	
	is_diving = false
	
	# Fly back to hover position: 400px in front, 200px above player's ground position
	if player:
		var horizontal_offset = distance_in_front
		if player.global_position.x > global_position.x:
			horizontal_offset = -distance_in_front
		
		var return_x = player.global_position.x + horizontal_offset
		var return_y = player_ground_y - height_above_player  # Above player's ground!
		var return_position = Vector2(return_x, return_y)
		
		var tween = create_tween()
		tween.tween_property(self, "global_position", return_position, 2.0)

# ============ COLLISION DAMAGE ============
func _on_body_entered(body: Node2D) -> void:
	"""Deal damage when diving into player"""
	if is_diving and body.is_in_group("Player"):
		if body.has_method("take_damage"):
			body.take_damage(dive_melee_damage)

# ============ DAMAGE & DEATH ============
func take_damage(amount: int, knockback_source: Vector2 = Vector2.ZERO) -> void:
	current_health -= amount
	
	# Apply knockback if source is provided
	if knockback_source != Vector2.ZERO:
		var knockback_direction = (global_position - knockback_source).normalized()
		var knockback_force = 400.0  # Adjust for stronger/weaker knockback
		velocity = knockback_direction * knockback_force
	
	# Flash red
	modulate = Color(1, 0.3, 0.3)
	await get_tree().create_timer(0.1).timeout
	modulate = Color(1, 1, 1)
	
	# Phase changes - shoot faster and dive more often
	if current_health <= max_health * 0.5 and current_health > max_health * 0.25:
		fireball_interval = 1.5
		fly_speed = 200.0
		
	elif current_health <= max_health * 0.25:
		fireball_interval = 1.0
		fly_speed = 250.0
		dive_speed = 400.0
	
	# Death
	if current_health <= 0:
		die()

func die() -> void:
	# Death explosion effect - particles scatter outward
	for i in range(20):  # More particles for better effect
		var particle = ColorRect.new()
		particle.size = Vector2(20, 20)
		particle.color = Color(1, 0.5, 0)  # Orange
		get_parent().add_child(particle)
		particle.global_position = global_position
		
		# Random direction for each particle
		var angle = randf() * TAU  # Random angle in full circle
		var distance = randf_range(100, 300)  # How far to scatter
		var target_pos = global_position + Vector2(cos(angle), sin(angle)) * distance
		
		# Animate particle flying outward
		var tween = create_tween()
		tween.set_parallel(true)  # Run all animations at once
		
		# Move outward
		tween.tween_property(particle, "global_position", target_pos, 0.8)
		
		# Fade out
		tween.tween_property(particle, "modulate:a", 0.0, 0.8)
		
		# Shrink
		tween.tween_property(particle, "scale", Vector2(0.1, 0.1), 0.8)
		
		# Delete when done
		tween.tween_callback(particle.queue_free)
	
	queue_free()
