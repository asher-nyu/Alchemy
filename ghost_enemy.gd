extends CharacterBody2D

var enemy_attack_sound = AudioStreamPlayer.new()
var enemy_death_sound = AudioStreamPlayer.new()

const PATROL_SPEED = 40.0  # Slightly faster than skeleton
const FLOAT_SPEED = 30.0   
const GRAVITY = 200.0      
const FLOAT_AMPLITUDE = 50.0

const ATTACK_RANGE = 250.0 

# Patrol behavior
const PATROL_DISTANCE = 500.0  
var spawn_position: Vector2
var patrol_direction = 1
var float_offset = 0.0

# State machine
enum State { PATROL, ATTACK }
var current_state = State.PATROL

# Attack properties
var attack_damage = 15 
var attack_cooldown = 1.8
var attack_timer = 0.0

# Health system
var max_health = 70
var current_health = 40

# Preload mint pickup scene
var mint_pickup_scene = preload("res://mint_pickup.tscn")

@onready var animated_sprite = $AnimatedSprite2D
@onready var attack_detector = $AttackDetector
var player: CharacterBody2D = null

func _ready():
	add_child(enemy_attack_sound)
	enemy_attack_sound.stream = load("res://assets/Audio Pack/enemy_attack_3.mp3")
	
	add_child(enemy_death_sound)
	enemy_death_sound.stream = load("res://assets/Audio Pack/enemy_death_sound_3.mp3")
	
	spawn_position = global_position
	current_health = max_health
	
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

func _physics_process(delta: float) -> void:
	if attack_timer > 0:
		attack_timer -= delta
	
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	
	# Floating motion
	float_offset += delta * 2.0
	var float_y = sin(float_offset) * FLOAT_AMPLITUDE
	
	match current_state:
		State.PATROL:
			patrol_behavior()
		State.ATTACK:
			attack_behavior()
	
	# Apply floating offset to position after movement
	velocity.y += float_y * delta * 0.5
	
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
	
	# Ghost slowly drifts toward player
	var direction_to_player = (player.global_position - global_position).normalized()
	velocity.x = direction_to_player.x * PATROL_SPEED * 0.5
	
	# Face the player
	#var direction = sign(player.global_position.x - global_position.x)
	#animated_sprite.flip_h = direction > 0
	
	if attack_timer <= 0:
		deal_damage_to_player()
		attack_timer = attack_cooldown
		
		if enemy_attack_sound:
			enemy_attack_sound.play()

func deal_damage_to_player():
	if player and player.has_method("take_damage"):
		player.take_damage(attack_damage)

func update_animation():
	if not animated_sprite:
		return
	
	# 1) Decide which way we should face
	var dir_x := 0.0
	
	if current_state == State.ATTACK and player:
		# Face the player in attack state
		dir_x = player.global_position.x - global_position.x
	else:
		# Otherwise face the direction we're moving
		dir_x = velocity.x
	
	if dir_x != 0:
		animated_sprite.flip_h = dir_x > 0
	
	# 2) Play the correct animation
	match current_state:
		State.PATROL:
			# Ghost always floating - use idle animation
			if animated_sprite.animation != "idle":
				animated_sprite.play("idle")
		
		State.ATTACK:
			if animated_sprite.sprite_frames.has_animation("attack"):
				if animated_sprite.animation != "attack":
					animated_sprite.play("attack")
			else:
				if animated_sprite.animation != "idle":
					animated_sprite.play("idle")
					
func _on_body_entered_range(body):
	if body.is_in_group("Player"):
		player = body
		current_state = State.ATTACK

func _on_body_left_range(body):
	if body == player:
		player = null
		current_state = State.PATROL

func take_damage(amount: int, attacker_position: Vector2 = Vector2.ZERO):
	if current_health <= 0:
		return
	
	current_health -= amount
	if animated_sprite:
		animated_sprite.modulate = Color(0.5, 1.0, 1.0, 1.5)  
		await get_tree().create_timer(0.1).timeout
		if is_instance_valid(self):
			animated_sprite.modulate = Color.WHITE
	
	if current_health <= 0:
		die()

func die():
	set_physics_process(false)
	current_state = State.PATROL
	velocity = Vector2.ZERO
	
	collision_layer = 0
	collision_mask = 0
	
	spawn_mint_pickup()
	
	if animated_sprite and animated_sprite.sprite_frames.has_animation("dead"):
		animated_sprite.play("dead")

	if enemy_death_sound:
		enemy_death_sound.play()
		
	var sound_length = enemy_death_sound.stream.get_length()
	await get_tree().create_timer(sound_length).timeout
		
# Add mint to inventory
	Inventory.add_mint(1)
	
	# Track kill for bonus match-3 moves
	if has_node("/root/LevelManager"):
		LevelManager.add_enemy_kill()
	
	queue_free()

func spawn_mint_pickup():
	var player_node = get_tree().get_first_node_in_group("Player")
	if not player_node or not player_node.has_node("Camera2D2/UI"):
		return
	
	var ui_layer = player_node.get_node("Camera2D2/UI")
	var camera = player_node.get_node("Camera2D2")
	
	var mint = mint_pickup_scene.instantiate()
	ui_layer.add_child(mint)
	
	mint.set_start_position(global_position, camera)
