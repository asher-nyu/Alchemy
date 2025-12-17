extends CharacterBody2D

signal boss_defeated

# BOSS STATS
@export var max_health: int = 300
@export var current_health: int = 300
@export var fly_speed: float = 150.0
@export var dive_speed: float = 300.0

# ATTACK SETTINGS
@export var fireball_damage: int = 25
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

var boss_flapping_sound: AudioStreamPlayer = AudioStreamPlayer.new()
var boss_hurt_sound: AudioStreamPlayer = AudioStreamPlayer.new()
var boss_die_sound: AudioStreamPlayer = AudioStreamPlayer.new()
var fireball_shoot_sound: AudioStreamPlayer = AudioStreamPlayer.new()

var is_dying: bool = false
var return_tween: Tween = null

@onready var sprite = $AnimatedSprite2D
@onready var collision_shape = $CollisionShape2D

@onready var fireball_timer: Timer = Timer.new()
@onready var dive_timer: Timer = Timer.new()
@onready var dive_duration_timer: Timer = Timer.new()  # For the dive duration await


func _ready() -> void:
	add_to_group("Enemy")
	player = get_tree().get_first_node_in_group("Player")
	
	# Initialize player's ground position
	if player:
		player_ground_y = player.global_position.y
	
	add_child(boss_flapping_sound)
	boss_flapping_sound.stream = load("res://assets/Audio Pack/boss_flapping_sound.wav") 
	boss_flapping_sound.pitch_scale = 0.3
	
	add_child(boss_hurt_sound)
	boss_hurt_sound.stream = load("res://assets/Audio Pack/boss_hurt_sound.wav") 
	
	add_child(boss_die_sound)
	boss_die_sound.stream = load("res://assets/Audio Pack/boss_die_sound.wav") 
	
	add_child(fireball_shoot_sound)
	fireball_shoot_sound.stream = load("res://assets/Audio Pack/fireball_shoot_sound.mp3")

	# Play the flying animation
	if sprite and sprite.sprite_frames:
		if sprite.sprite_frames.has_animation("fly"):
			sprite.play("fly")
		elif sprite.sprite_frames.has_animation("default"):
			sprite.play("default")
	
	# Setup fireball timer
	add_child(fireball_timer)
	fireball_timer.wait_time = fireball_interval
	fireball_timer.one_shot = true  # We'll restart it manually in the loop

	# Setup dive loop timer (every 10s)
	add_child(dive_timer)
	dive_timer.wait_time = 10.0
	dive_timer.one_shot = true

	# Setup dive duration timer (5s during dive)
	add_child(dive_duration_timer)
	dive_duration_timer.wait_time = dive_duration
	dive_duration_timer.one_shot = true
	
	# Start attack patterns
	fireball_loop()   # Shoot fireballs every 2 seconds
	dive_loop()       # Dive attack every 10 seconds

func _physics_process(delta: float) -> void:
	if not player:
		return
		
	if not is_dying:
		if not boss_flapping_sound.playing:
			boss_flapping_sound.play()
			
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
		fireball_timer.start()
		await fireball_timer.timeout
		if not is_diving:
			shoot_fireball()

func shoot_fireball() -> void:
	if not fireball_scene:
		return
	
	if not player:
		return
		
	if fireball_shoot_sound:
		fireball_shoot_sound.play()
		
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
		dive_timer.start()
		await dive_timer.timeout
		dive_attack()

func dive_attack() -> void:
	is_diving = true

	# Enable melee damage
	collision_layer = 1
	collision_mask = 1

	# Dive for 5 seconds - will chase player directly via _physics_process
	dive_duration_timer.start()
	await dive_duration_timer.timeout

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
	# If the death sequence is already in progress, ignore further damage
	if is_dying or current_health <= 0:
		return
	
	var old_health = current_health
	current_health -= amount
	
	# Apply knockback if source is provided
	if knockback_source != Vector2.ZERO:
		var knockback_direction = (global_position - knockback_source).normalized()
		var knockback_force = 400.0
		velocity = knockback_direction * knockback_force
	
	# Phase changes - check if we crossed a threshold
	# Phase 2: 50% health (250 HP)
	if old_health > max_health * 0.5 and current_health <= max_health * 0.5:
		
		fireball_interval = 1.0
		fireball_timer.wait_time = 1.0
		fly_speed = 200.0
		dive_timer.wait_time = 7.0
	
	# Phase 3: 25% health (125 HP)
	if old_health > max_health * 0.25 and current_health <= max_health * 0.25:
		
		fireball_interval = 0.5
		fireball_timer.wait_time = 0.5
		fly_speed = 250.0
		dive_speed = 400.0
		dive_timer.wait_time = 5.0
	
	
	# Death
	if current_health <= 0:
		die()
		return
	
	# --- HURT EFFECT (similar style to player.gd) ---
	var original_modulate := modulate
	var original_scale := scale
	
	modulate = Color(1, 0.3, 0.3) # flash red
	scale = original_scale * Vector2(1.1, 0.9) # slight squash
	
	# HURT SOUND: only if not dying and not already playing
	if boss_hurt_sound and not boss_hurt_sound.playing and not is_dying:
		boss_hurt_sound.play()
	
	await get_tree().create_timer(0.12).timeout
	
	# If we started dying during the wait, restore visuals and stop
	if is_dying:
		modulate = original_modulate
		scale = original_scale
		return
	
	# Restore visuals (boss still alive)
	modulate = original_modulate
	scale = original_scale

func die() -> void:
	# Prevent running the death sequence multiple times
	if is_dying:
		return
	is_dying = true
	boss_defeated.emit()
	
	# Turn off logic & collisions
	is_diving = false
	set_physics_process(false)
	set_process(false)
	collision_layer = 0
	collision_mask = 0
	velocity = Vector2.ZERO
	
	# Stop flapping loop (boss is no longer alive)
	if boss_flapping_sound and boss_flapping_sound.playing:
		boss_flapping_sound.stop()
	
	# Kill the return tween if it's still active (so boss stops drifting)
	if return_tween and is_instance_valid(return_tween):
		return_tween.kill()
		return_tween = null
	
	# Freeze animation on current frame
	if sprite:
		sprite.stop()
	
	# Optional: strong camera shake on boss death
	if player and player.has_method("shake_camera"):
		player.shake_camera(28.0, 0.35)
	
	# --- DRAMATIC FALL + SQUASH BEFORE EXPLOSION ---
	var original_pos := global_position
	var original_scale := scale
	
	var fall_tween := create_tween()
	fall_tween.set_parallel(false)
	
	# Small downward drop
	fall_tween.tween_property(self, "global_position", original_pos + Vector2(0, 40), 0.25)
	# Squash + stretch while falling
	fall_tween.tween_property(self, "scale", original_scale * Vector2(1.25, 0.7), 0.25)
	
	await fall_tween.finished
	
	# Snap scale back a bit before explosion so it looks snappy
	scale = original_scale * Vector2(1.05, 0.9)
	
	# Stop hurt sound if playing to avoid overlap
	if boss_hurt_sound and boss_hurt_sound.playing:
		boss_hurt_sound.stop()
	
	# Reparent and play die sound before hiding
	if boss_die_sound and boss_die_sound.stream:
		boss_die_sound.reparent(get_parent())
		boss_die_sound.play()
	
	# Hide the boss visually right after starting the explosion and playing sound
	visible = false
	
	# Free immediately; sounds continue if reparented
	queue_free()
