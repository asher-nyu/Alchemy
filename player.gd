
extends CharacterBody2D

var run_sound = AudioStreamPlayer.new()
var attack_sound = AudioStreamPlayer.new()
var hero_death_sound = AudioStreamPlayer.new()
var hero_jump_sound = AudioStreamPlayer.new()

# --- CAMERA DRAG SYSTEM ---
var dragging = false
var drag_start = Vector2.ZERO
var camera_start = Vector2.ZERO
var camera_offset = Vector2.ZERO
var camera_base_position = Vector2.ZERO



const SPEED = 400.0
const JUMP_VELOCITY = -400.0
const AIR_CONTROL = 0.8

# Instant death system
const HAZARD_LAYER = 1  # Physics layer for deadly tiles
const DEATH_Y = 3000    # Death if player falls below this Y position

# Attack properties
var can_attack = true
var is_attacking = false
var base_attack_damage = 25  # Base damage (changed from attack_damage)
var attack_damage = 25  # Current damage 
var attack_range = 230.0
const ATTACK_COOLDOWN = 0.5
const ATTACK_ANIMATION_TIME = 0.3

@onready var animated_sprite = $AnimatedSprite2D
@onready var camera = $Camera2D2
@onready var health_label = $Camera2D2/UI/HealthLabel

var original_color = Color.WHITE

func _ready():
	print("PLAYER: _ready() called!")
	
	original_color = animated_sprite.modulate
	
	# Connect to PotionManager signals (for health only)
	PotionManager.health_changed.connect(_on_health_changed)
	PotionManager.player_died.connect(_on_player_died)
	
	# Setup audio
	add_child(run_sound)
	run_sound.stream = load("res://assets/Audio Pack/run.wav")
	run_sound.pitch_scale = 1.2
	
	add_child(attack_sound)
	attack_sound.stream = load("res://assets/Audio Pack/attack.mp3")
	
	add_child(hero_death_sound)
	hero_death_sound.stream = load("res://assets/Audio Pack/hero-death.mp3")
	
	add_child(hero_jump_sound)
	hero_jump_sound.stream = load("res://assets/Audio Pack/jump.mp3")
	
	# Setup UI labels
	if health_label:
		var parent = health_label.get_parent()
		print("   Parent (UI) visible: ", parent.visible if parent else "No parent")
		
		health_label.visible = true
		health_label.position = Vector2(10, 10)
		health_label.add_theme_font_size_override("font_size", 48)
		health_label.add_theme_color_override("font_color", Color.RED)
	
	if camera:
		camera.enabled = true
		camera.make_current()
		camera_offset = camera.position
		camera_base_position = camera.position
	
	# Initial UI update
	update_health_display()
	add_to_group("Player")


func _input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			dragging = true
			drag_start = event.position
			camera_start = camera_offset
		else:
			dragging = false
			camera_offset = camera_base_position

	elif event is InputEventMouseMotion and dragging:
		var delta = drag_start - event.position
		camera_offset = camera_start + delta
				
func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	if Input.is_action_just_pressed("ui_accept") and can_attack:
		perform_attack()
	
	if Input.is_action_just_pressed("ui_up") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		if hero_jump_sound and not hero_jump_sound.playing:
			hero_jump_sound.play()
	
	var direction: float = Input.get_axis("ui_left", "ui_right")
	
	if direction != 0 and is_on_floor():
		if not run_sound.playing:
			run_sound.play()
			run_sound.connect("finished", Callable(run_sound, "play"))
	else:
		if run_sound.playing:
			run_sound.stop()
			run_sound.disconnect("finished", Callable(run_sound, "play"))
		
	if direction != 0:
		if is_on_floor():
			velocity.x = direction * SPEED
		else:
			velocity.x = move_toward(velocity.x, direction * SPEED, SPEED * AIR_CONTROL * delta * 60)
		animated_sprite.flip_h = direction < 0
	else:
		if is_on_floor():
			velocity.x = move_toward(velocity.x, 0, SPEED)
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED * 0.1 * delta * 60)
	
	move_and_slide()
	
	check_for_hazards()
	
	# Check if player fell off the map
	if global_position.y > DEATH_Y:
		_on_player_died()
	
	if not is_attacking:
		if not is_on_floor():
			animated_sprite.play("jump")
		elif direction != 0:
			animated_sprite.play("run")
		else:
			animated_sprite.play("idle")
			
	if camera:
		camera.position = camera_offset
		
# --- HAZARD DETECTION ---
func check_for_hazards():
	# Loop through all collisions from the last move_and_slide()
	for i in range(get_slide_collision_count()):
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		
		# Check if we hit a TileMap
		if collider is TileMap:
			# Get the exact point where we collided
			var collision_point = collision.get_position()
			
			var tile_pos = collider.local_to_map(collider.to_local(collision_point))
			
			var tile_data = collider.get_cell_tile_data(0, tile_pos)
			
			if tile_data:
				# If tile has collision polygons on HAZARD_LAYER (Layer 1)
				if tile_data.get_collision_polygons_count(HAZARD_LAYER) > 0:
					print("💀 Player touched deadly tile at position: ", tile_pos)
					_on_player_died()
					return


# --- ATTACK SYSTEM ---
func perform_attack():
	can_attack = false
	is_attacking = true
	
	# Use current base attack damage
	attack_damage = base_attack_damage
	
	# Play attack animation
	if animated_sprite.sprite_frames.has_animation("attack"):
		animated_sprite.play("attack")
	
	# Find enemies in range
	var enemies = get_tree().get_nodes_in_group("Enemy")
	
	var hit_something = false
	
	for enemy in enemies:
		if enemy and is_instance_valid(enemy) and enemy.current_health > 0:
			var distance = global_position.distance_to(enemy.global_position)
			
			if distance <= attack_range:
				if enemy.has_method("take_damage"):
				# Pass player's position for knockback calculation
					enemy.take_damage(attack_damage, global_position)
					hit_something = true

	if hit_something:
		attack_sound.play()
		
	# Wait for attack animation to finish
	await get_tree().create_timer(ATTACK_ANIMATION_TIME).timeout
	is_attacking = false
	
	# Attack cooldown
	await get_tree().create_timer(ATTACK_COOLDOWN - ATTACK_ANIMATION_TIME).timeout
	can_attack = true

# --- HEALTH SYSTEM ---
func take_damage(amount: int) -> void:
	# Visual feedback
	var current_modulate = animated_sprite.modulate
	animated_sprite.modulate = Color.RED
	await get_tree().create_timer(0.1).timeout
	animated_sprite.modulate = current_modulate 
	
	# Apply damage through PotionManager
	PotionManager.take_damage(amount)

# --- DAMAGE INCREASE SYSTEM ---
func increase_damage(amount: int):
	"""Permanently increase the player's base attack damage."""
	base_attack_damage += amount
	attack_damage = base_attack_damage
	print("PLAYER: Attack damage increased by %d! New damage: %d" % [amount, attack_damage])

# --- HEALTH SIGNAL HANDLERS ---
func _on_health_changed(current: int, maximum: int):
	update_health_display()

# --- UI UPDATE FUNCTIONS ---
func update_health_display() -> void:
	if health_label:
		health_label.text = PotionManager.get_health_display_text()

# --- DEATH HANDLING ---	
func _on_player_died():
	die(0.0)
func die(delay: float = 0.0) -> void:
	# Disable all logic
	set_process(false)
	set_physics_process(false)
	remove_from_group("Player")
	collision_layer = 0
	collision_mask = 0
	velocity = Vector2.ZERO

	# Hide sprite instantly
	if $AnimatedSprite2D:
		$AnimatedSprite2D.hide()

	# Play death sound
	if hero_death_sound and not hero_death_sound.playing:
		hero_death_sound.play()

	# Blood pixel effect (instant)
	var pixels = 20
	for i in range(pixels):
		var part = Polygon2D.new()
		get_parent().add_child(part)

		var width = randf_range(16, 32)
		var height = randf_range(8, 24)
		var segments = 16
		var points = []

		for j in range(segments):
			var angle = (float(j) / segments) * TAU
			points.append(Vector2(cos(angle)*width/2, sin(angle)*height/2))

		part.polygon = points
		part.color = Color(1,0.2,0.2)
		part.global_position = global_position + Vector2(randf()*32-16, randf()*32-16)

		var t = create_tween()
		var target_pos = part.global_position + Vector2(randf()*200-100, randf()*200-100)
		t.tween_property(part, "global_position", target_pos, 1.0)
		t.tween_property(part, "modulate:a", 0.0, 1.0)

	# Wait for death sound, then respawn on same level
	await get_tree().create_timer(hero_death_sound.stream.get_length()).timeout
	
	# Reset health before reloading
	PotionManager.reset_all()
	
	# Reload the current level
	get_tree().reload_current_scene()
