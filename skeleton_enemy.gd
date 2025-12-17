extends CharacterBody2D

var enemy_attack_sound = AudioStreamPlayer.new()
var enemy_death_sound = AudioStreamPlayer.new()

# Movement constants
const PATROL_SPEED = 50.0
const GRAVITY = 980.0

# Detection ranges
const ATTACK_RANGE = 200.0

# Patrol behavior
const PATROL_DISTANCE = 400.0
var spawn_position: Vector2
var patrol_direction = 1

# State machine
enum State { PATROL, ATTACK, STUNNED }
var current_state = State.PATROL

# Attack properties
var attack_damage = 10
var attack_cooldown = 1.5  # Time between attacks
var attack_timer = 0.0
var can_deal_damage = false  

# Knockback properties
var knockback_force = 400.0  # How hard the enemy is pushed back
var knockback_duration = 0.3 # How long the knockback lasts
var is_being_knocked_back = false

# Health system
var max_health = 50
var current_health = 50

# Preload garlic pickup scene
var garlic_pickup_scene = preload("res://garlic_pickup.tscn")

# References
@onready var animated_sprite = $AnimatedSprite2D
@onready var attack_detector = $AttackDetector
var player: CharacterBody2D = null

func _ready():
	
	add_child(enemy_attack_sound)
	enemy_attack_sound.stream = load("res://assets/Audio Pack/enemy_attack_1.mp3")
	
	add_child(enemy_death_sound)
	enemy_death_sound.stream = load("res://assets/Audio Pack/enemy_death_sound_1.mp3")
	
	spawn_position = global_position
	current_health = max_health
	
	# Add to Enemy group so player can target us
	add_to_group("Enemy")
	
	# Setup attack detector
	if attack_detector:
		attack_detector.position = Vector2.ZERO
		
		var collision_shape = null
		for child in attack_detector.get_children():
			if child is CollisionShape2D:
				collision_shape = child
				child.position = Vector2.ZERO
				break
		
		if not collision_shape:
			collision_shape = CollisionShape2D.new()
			collision_shape.position = Vector2.ZERO
			var circle = CircleShape2D.new()
			circle.radius = ATTACK_RANGE
			collision_shape.shape = circle
			attack_detector.add_child(collision_shape)
		
		attack_detector.collision_layer = 2
		attack_detector.collision_mask = 1
		attack_detector.monitoring = true
		attack_detector.monitorable = true
		
		attack_detector.body_entered.connect(_on_body_entered_range)
		attack_detector.body_exited.connect(_on_body_left_range)
	
	if animated_sprite:
		animated_sprite.frame_changed.connect(_on_animation_frame_changed)

func _physics_process(delta: float) -> void:
	# Update attack timer
	if attack_timer > 0:
		attack_timer -= delta
	
	# Apply gravity
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	
	# If being knocked back, don't process normal behavior
	if is_being_knocked_back:
		move_and_slide()
		return
	
	# State machine
	match current_state:
		State.PATROL:
			patrol_behavior()
		State.ATTACK:
			attack_behavior()
		State.STUNNED:
			velocity.x = 0  
	
	move_and_slide()
	update_animation()

func patrol_behavior():
	var distance_from_spawn = global_position.x - spawn_position.x
	
	if distance_from_spawn > PATROL_DISTANCE:
		patrol_direction = -1
	elif distance_from_spawn < -PATROL_DISTANCE:
		patrol_direction = 1
	
	if is_on_wall():
		patrol_direction *= -1
	
	velocity.x = patrol_direction * PATROL_SPEED

func attack_behavior():
	if not player:
		current_state = State.PATROL
		return
	
	var distance_to_player = global_position.distance_to(player.global_position)
	
	if distance_to_player > ATTACK_RANGE * 1.5:
		current_state = State.PATROL
		return
	
	# STOP MOVING
	velocity.x = 0
	
	# Face the player
	var direction = sign(player.global_position.x - global_position.x)
	animated_sprite.flip_h = direction > 0  # Using reversed flip logic
	
	if attack_timer <= 0:
		# The animation will trigger the damage via _on_animation_frame_changed
		can_deal_damage = true
		attack_timer = attack_cooldown
		
		if enemy_attack_sound:
			enemy_attack_sound.play()

func _on_animation_frame_changed():
	# Only deal damage on the correct frame of the attack animation
	if animated_sprite.animation == "attack" and can_deal_damage:
		if animated_sprite.frame == 6:  
			deal_damage_to_player()
			can_deal_damage = false  # Only deal damage once per attack

func deal_damage_to_player():
	if player and player.has_method("take_damage"):
		player.take_damage(attack_damage)

func update_animation():
	if not animated_sprite:
		return
	
	match current_state:
		State.STUNNED:
			# Play hurt animation if available, otherwise idle
			if animated_sprite.sprite_frames.has_animation("hurt"):
				if animated_sprite.animation != "hurt":
					animated_sprite.play("hurt")
			else:
				if animated_sprite.animation != "idle":
					animated_sprite.play("idle")
		
		State.PATROL:
			# Face the direction of movement during patrol
			if velocity.x > 0:
				animated_sprite.flip_h = false   # Facing right (flipped)
			elif velocity.x < 0:
				animated_sprite.flip_h = true  # Facing left (not flipped)
			
			# Play movement animation
			if abs(velocity.x) > 0:
				if animated_sprite.animation != "run":
					animated_sprite.play("run")
			else:
				if animated_sprite.animation != "idle":
					animated_sprite.play("idle")
		
		State.ATTACK:
			# Face player during attack
			var direction = sign(player.global_position.x - global_position.x) if player else 1
			animated_sprite.flip_h = direction < 0 
			
			if animated_sprite.animation != "attack":
				animated_sprite.play("attack")

func _on_body_entered_range(body):
	if body.is_in_group("Player"):
		player = body
		current_state = State.ATTACK
		if animated_sprite:
			animated_sprite.play("attack")

func _on_body_left_range(body):
	if body == player:
		player = null
		current_state = State.PATROL

func take_damage(amount: int, attacker_position: Vector2 = Vector2.ZERO):
	# Don't take damage if already dead
	if current_health <= 0:
		return
	
	current_health -= amount
	
	# Apply knockback if we know where the attacker is
	if attacker_position != Vector2.ZERO:
		apply_knockback(attacker_position)
	
	# Flash white when hit
	if animated_sprite:
		animated_sprite.modulate = Color.WHITE * 2
		await get_tree().create_timer(0.1).timeout
		if is_instance_valid(self):  # Check if still exists
			animated_sprite.modulate = Color.WHITE
	
	# Die if health depleted
	if current_health <= 0:
		die()

func apply_knockback(attacker_position: Vector2):
	var knockback_direction = (global_position - attacker_position).normalized()
	
	# Apply horizontal knockback force
	velocity.x = knockback_direction.x * knockback_force
	
	velocity.y = -200
	
	# Enter stunned state
	is_being_knocked_back = true
	var previous_state = current_state
	current_state = State.STUNNED
	
	await get_tree().create_timer(knockback_duration).timeout
	
	if is_instance_valid(self):
		is_being_knocked_back = false
		# Only return to patrol if we were patrolling before
		if previous_state == State.PATROL:
			current_state = State.PATROL
		# If we were attacking, check if player is still in range
		elif previous_state == State.ATTACK:
			if player and global_position.distance_to(player.global_position) <= ATTACK_RANGE * 1.5:
				current_state = State.ATTACK
			else:
				current_state = State.PATROL
				player = null

func die():
	# Stop all behavior immediately
	set_physics_process(false)
	current_state = State.PATROL
	velocity = Vector2.ZERO
	
	# Disable collision so player can walk through
	collision_layer = 0
	collision_mask = 0
	
	# Spawn garlic pickup visual
	spawn_garlic_pickup()
	
	# Play death animation if available
	if animated_sprite and animated_sprite.sprite_frames.has_animation("dead"):
		animated_sprite.play("dead")

	# Play death sound
	if enemy_death_sound:
		enemy_death_sound.play()
		
	# Wait until the sound finishes before freeing the enemy
	var sound_length = enemy_death_sound.stream.get_length()
	await get_tree().create_timer(sound_length).timeout
		
	# Add to inventory
	Inventory.add_garlic(1)
	
	# Track kill for bonus match-3 moves
	if has_node("/root/LevelManager"):
		LevelManager.add_enemy_kill()
	
	# Remove from scene
	queue_free()

func spawn_garlic_pickup():
	# Get player's UI layer
	var player_node = get_tree().get_first_node_in_group("Player")
	if not player_node or not player_node.has_node("Camera2D2/UI"):
		return
	
	var ui_layer = player_node.get_node("Camera2D2/UI")
	var camera = player_node.get_node("Camera2D2")
	
	var garlic = garlic_pickup_scene.instantiate()
	ui_layer.add_child(garlic)
	
	garlic.set_start_position(global_position, camera)
