
extends CharacterBody2D

var run_sound = AudioStreamPlayer.new()
var attack_sound = AudioStreamPlayer.new()
var hero_death_sound = AudioStreamPlayer.new()
var hero_jump_sound = AudioStreamPlayer.new()
var hero_hurt_sound = AudioStreamPlayer.new()

# --- CAMERA DRAG SYSTEM ---
var dragging = false
var drag_start = Vector2.ZERO
var camera_start = Vector2.ZERO
var camera_offset = Vector2.ZERO
var camera_base_position = Vector2.ZERO

var is_dying: bool = false


const SPEED = 400.0
const JUMP_VELOCITY = -700.0
const AIR_CONTROL = 0.8

# Instant death system
const HAZARD_LAYER = 1  # Physics layer for deadly tiles
const DEATH_Y = 3000    # Death if player falls below this Y position

# Attack properties
var can_attack = true
var is_attacking = false
var base_attack_damage = 25  # Base damage (changed from attack_damage)
var attack_damage = 25  # Current damage 
var attack_range = 210.0
const ATTACK_COOLDOWN = 0.5
const ATTACK_ANIMATION_TIME = 0.3
const PunchEffect = preload("res://punch_effect.tscn")

@onready var animated_sprite = $AnimatedSprite2D
@onready var camera = $Camera2D2
@onready var health_label = $Camera2D2/UI/HealthLabel

var energy_label: Label = null
var original_color = Color.WHITE

var level_to_load: String = ""

# Danger warning indicator
var danger_indicator: Label = null
var danger_pulse_tween: Tween = null
const DANGER_DETECTION_RANGE = 300.0  # 10 feet in pixels (approximately)


func _ready():
	
	level_to_load = get_scene_file_path()
	
	if "level_4" in level_to_load.to_lower():
		attack_range = 300.0
	
	original_color = animated_sprite.modulate
	
	# Connect to PotionManager signals
	PotionManager.health_changed.connect(_on_health_changed)
	PotionManager.player_died.connect(_on_player_died)
	PotionManager.energy_changed.connect(_on_energy_changed)
	PotionManager.ultimate_activated.connect(_on_ultimate_activated)
	PotionManager.ultimate_deactivated.connect(_on_ultimate_deactivated)
	
	_sync_ultimate_visuals()
	
	# Setup audio
	add_child(run_sound)
	run_sound.stream = load("res://assets/Audio Pack/run.wav")
	run_sound.pitch_scale = 1.2
	
	add_child(attack_sound)
	attack_sound.stream = load("res://assets/Audio Pack/attack.mp3")
	
	add_child(hero_death_sound)
	hero_death_sound.stream = load("res://assets/Audio Pack/hero_death_2.mp3")
	
	add_child(hero_jump_sound)
	hero_jump_sound.stream = load("res://assets/Audio Pack/jump2.mp3")
	
	add_child(hero_hurt_sound)
	hero_hurt_sound.stream = load("res://assets/Audio Pack/hero_hurt_sound.mp3")
	
	# Setup UI labels
	if health_label:
		var parent = health_label.get_parent()
		
		health_label.visible = true
		health_label.position = Vector2(10, 10)
		health_label.add_theme_font_size_override("font_size", 48)
		health_label.add_theme_color_override("font_color", Color.RED)
	
	# Create energy label
	create_energy_label()
	
	# Create danger warning indicator
	create_danger_indicator()
	
	if camera:
		camera.enabled = true
		camera.make_current()
		camera_offset = camera.position
		camera_base_position = camera.position
	
	# Initial UI update
	update_health_display()
	update_energy_display()
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
	
	# Trigger She-Hulk Mode with the S key
	if Input.is_key_pressed(KEY_S):
		PotionManager.activate_ultimate()
	
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
	check_for_nearby_enemies()
	
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
					_on_player_died()
					return


# --- ATTACK SYSTEM ---
func perform_attack():
	can_attack = false
	is_attacking = true
	
	# Get ultimate multiplier and apply to damage
	var multiplier = PotionManager.get_attack_multiplier()
	attack_damage = int(base_attack_damage * multiplier)
	
	# --- PUNCH EFFECT HERE ---
	var effect = PunchEffect.instantiate()

	# Position offset based on direction (adjust 40 to match your sprite size)
	var offset = Vector2(0, 0)
	if animated_sprite.flip_h:  # If facing left
		offset.x = -offset.x

	effect.position = offset  # Changed: just offset, not global_position + offset
	effect.flip_h = animated_sprite.flip_h  # Match player direction
	add_child(effect)
	# --- END PUNCH EFFECT ---
	
	# Play attack animation
	if animated_sprite.sprite_frames.has_animation("attack"):
		animated_sprite.play("attack")
	
	# Find enemies in range
	var enemies = get_tree().get_nodes_in_group("Enemy")
	
	var hit_something = false
	var total_damage_dealt = 0
	
	for enemy in enemies:
		if enemy and is_instance_valid(enemy) and enemy.current_health > 0:
			var distance = global_position.distance_to(enemy.global_position)
			
			if distance <= attack_range:
				if enemy.has_method("take_damage"):
					# Store old health to calculate actual damage dealt
					var old_health = enemy.current_health
					enemy.take_damage(attack_damage, global_position)
					var damage_dealt = old_health - enemy.current_health
					total_damage_dealt += damage_dealt
					hit_something = true

	if hit_something:
		attack_sound.play()
		# Add energy from damage dealt
		PotionManager.add_energy_from_damage_dealt(total_damage_dealt)
		
		# Only consume ultimate charge if the punch actually connected
		if PotionManager.is_ultimate_mode_active():
			PotionManager.consume_ultimate_charge()
			
	# Wait for attack animation to finish
	await get_tree().create_timer(ATTACK_ANIMATION_TIME).timeout
	is_attacking = false
	
	# Attack cooldown
	await get_tree().create_timer(ATTACK_COOLDOWN - ATTACK_ANIMATION_TIME).timeout
	can_attack = true


func take_damage(amount: int) -> void:
	# If the death sequence is already in progress, ignore further damage
	# and definitely don't start any new hurt sounds.
	if is_dying:
		return

	# Preserve current color/scale so She-Hulk mode and other tints survive the flash
	var current_modulate = animated_sprite.modulate
	var current_scale = animated_sprite.scale

	# Flash + slight squash/stretch
	animated_sprite.modulate = Color(1, 0.3, 0.3)           # bright red flash
	animated_sprite.scale = current_scale * Vector2(1.1, 0.9)

	# Play hurt sound ONLY if we're not in the middle of dying and it's not already playing
	if hero_hurt_sound and not hero_hurt_sound.playing and not is_dying:
		hero_hurt_sound.play()

	# Camera shake
	shake_camera(16.0, 0.15)

	# HUD bump (optional)
	bump_health_label()

	# Short hit flash duration – longer than your original 0.1 so it’s noticeable
	await get_tree().create_timer(0.15).timeout

	# If we started dying during the wait (e.g. from some other fatal event),
	# restore visuals and skip applying further damage.
	if is_dying:
		animated_sprite.modulate = current_modulate
		animated_sprite.scale = current_scale
		return

	# Restore visual state (keeps She-Hulk green etc.)
	animated_sprite.modulate = current_modulate
	animated_sprite.scale = current_scale

	# Apply gameplay damage through PotionManager (this may trigger _on_player_died → die())
	PotionManager.take_damage(amount)


# --- DAMAGE INCREASE SYSTEM ---
func increase_damage(amount: int):
	"""Permanently increase the player's base attack damage."""
	base_attack_damage += amount
	attack_damage = base_attack_damage

# --- SIGNAL HANDLERS ---
func _on_health_changed(current: int, maximum: int):
	update_health_display()

func _on_energy_changed(current: int, maximum: int):
	update_energy_display()

func _on_ultimate_activated(attacks_remaining: int):
	# Visual feedback - player glows during ultimate
	animated_sprite.modulate = Color(0.3, 1.0, 0.3, 1.0)  # Tint the sprite She-Hulk green
	update_energy_display()

func _on_ultimate_deactivated():
	# Return to normal color
	animated_sprite.modulate = original_color
	update_energy_display()

# --- UI UPDATE FUNCTIONS ---
func update_health_display() -> void:
	if health_label:
		health_label.text = PotionManager.get_health_display_text()

func update_energy_display() -> void:
	if energy_label:
		energy_label.text = PotionManager.get_energy_display_text()
		
		# Change color based on She-Hulk energy state
		if PotionManager.is_ultimate_mode_active():
			energy_label.add_theme_color_override("font_color", Color(0.9, 1.0, 0.3))   # Rampaging neon-gamma green
		elif PotionManager.can_activate_ultimate():
			energy_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))   # Charged up, glowing green
		else:
			energy_label.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))   # Base She-Hulk green

func create_energy_label():
	"""Create the energy bar label"""
	var ui_layer = null
	for child in camera.get_children():
		if child.name == "UI":
			ui_layer = child
			break
	
	if not ui_layer:
		return
	
	energy_label = Label.new()
	energy_label.name = "EnergyLabel"
	energy_label.visible = true
	energy_label.position = Vector2(10, 70)
	
	var custom_font := load("Alchemy.otf") as FontFile
	energy_label.add_theme_font_override("font", custom_font)
	energy_label.add_theme_font_size_override("font_size", 48)
	
	ui_layer.add_child(energy_label)

# --- DEATH HANDLING ---	
func _on_player_died():
	die(0.0)

func die(delay: float = 0.0) -> void:
	# Prevent running the death sequence multiple times
	if is_dying:
		return
	is_dying = true

	# Extra delay before starting the death sequence (if you pass > 0)
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout

	# Disable all logic so player can't move / act anymore
	set_process(false)
	set_physics_process(false)
	remove_from_group("Player")
	collision_layer = 0
	collision_mask = 0
	velocity = Vector2.ZERO

	# Hide sprite instantly
	if $AnimatedSprite2D:
		$AnimatedSprite2D.hide()
	
	# Hide danger indicator
	if danger_indicator:
		hide_danger_indicator()

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
			points.append(Vector2(cos(angle) * width / 2, sin(angle) * height / 2))

		part.polygon = points
		part.color = Color(1, 0.2, 0.2)
		part.global_position = global_position + Vector2(randf() * 32 - 16, randf() * 32 - 16)

		var t = create_tween()
		var target_pos = part.global_position + Vector2(randf() * 200 - 100, randf() * 200 - 100)
		t.tween_property(part, "global_position", target_pos, 1.0)
		t.tween_property(part, "modulate:a", 0.0, 1.0)

	# --- AUDIO ORDER: let last hurt finish, then death sound ---

	# If a hurt sound was already playing when we died, let it finish naturally.
	if hero_hurt_sound and hero_hurt_sound.playing:
		await hero_hurt_sound.finished

	# Now play the death sound (if present) and let it finish.
	if hero_death_sound and hero_death_sound.stream:
		hero_death_sound.play()
		await hero_death_sound.finished
	LevelManager.reset_enemy_kills()
	# Reset health before reloading
	PotionManager.reset_all()

	# Load Game Over screen
	var game_over_scene = load("res://GameOverScreen.tscn").instantiate()
	game_over_scene.level_to_load = get_tree().current_scene.get_scene_file_path()
	get_tree().root.add_child(game_over_scene)
	get_tree().current_scene.queue_free()  # Remove the old level



func shake_camera(intensity: float = 16.0, duration: float = 0.15) -> void:
	if not camera:
		return
	
	var original_offset = camera_offset
	var tween := create_tween()
	
	# Quick left-right shake, then back to center
	tween.tween_property(self, "camera_offset",
		original_offset + Vector2(intensity, 0), duration * 0.25)
	tween.tween_property(self, "camera_offset",
		original_offset + Vector2(-intensity, 0), duration * 0.5)
	tween.tween_property(self, "camera_offset",
		original_offset, duration * 0.25)

func bump_health_label():
	if not health_label:
		return
	
	var original_scale = health_label.scale
	var tween := create_tween()
	
	health_label.scale = original_scale * 1.2
	tween.tween_property(health_label, "scale", original_scale, 0.15)

# --- DANGER WARNING SYSTEM ---
func create_danger_indicator():
	
	danger_indicator = Label.new()
	danger_indicator.name = "DangerIndicator"
	danger_indicator.text = "!"
	danger_indicator.visible = false
	danger_indicator.position = Vector2(0, -50)  # Above player's head, closer
	danger_indicator.z_index = 100
	
	var custom_font := load("Alchemy.otf") as FontFile
	if custom_font:
		danger_indicator.add_theme_font_override("font", custom_font)
	danger_indicator.add_theme_font_size_override("font_size", 24)  # Even smaller
	danger_indicator.add_theme_color_override("font_color", Color.RED)
	danger_indicator.add_theme_color_override("font_outline_color", Color.BLACK)
	danger_indicator.add_theme_constant_override("outline_size", 2)  # Smaller outline
	
	# Center the text
	danger_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	danger_indicator.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	add_child(danger_indicator)

func check_for_nearby_enemies():
	if not danger_indicator or is_dying:
		return
	
	var enemies = get_tree().get_nodes_in_group("Enemy")
	var enemy_nearby = false
	
	for enemy in enemies:
		if enemy and is_instance_valid(enemy):
			# Check if enemy is alive (skip dead enemies)
			# All enemies in the Enemy group should have current_health property
			if enemy.current_health <= 0:
				continue
			
			var distance = global_position.distance_to(enemy.global_position)
			if distance <= DANGER_DETECTION_RANGE:
				enemy_nearby = true
				break
	
	# Show or hide indicator with animation
	if enemy_nearby and not danger_indicator.visible:
		show_danger_indicator()
	elif not enemy_nearby and danger_indicator.visible:
		hide_danger_indicator()

func show_danger_indicator():
	"""Show the danger indicator with animation"""
	if not danger_indicator or danger_indicator.visible:
		return
	
	danger_indicator.visible = true
	danger_indicator.modulate.a = 0.0
	danger_indicator.scale = Vector2(0.5, 0.5)
	
	# Animate in
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(danger_indicator, "modulate:a", 1.0, 0.2)
	tween.tween_property(danger_indicator, "scale", Vector2(1.2, 1.2), 0.2).set_ease(Tween.EASE_OUT)
	
	# Continuous pulsing animation (only create if not already running)
	# Smaller pulse range for smaller indicator
	if not danger_pulse_tween or not danger_pulse_tween.is_valid():
		danger_pulse_tween = create_tween()
		danger_pulse_tween.set_loops()
		danger_pulse_tween.tween_property(danger_indicator, "scale", Vector2(1.2, 1.2), 0.5).set_ease(Tween.EASE_IN_OUT)
		danger_pulse_tween.tween_property(danger_indicator, "scale", Vector2(1.0, 1.0), 0.5).set_ease(Tween.EASE_IN_OUT)

func hide_danger_indicator():
	"""Hide the danger indicator with animation"""
	if not danger_indicator or not danger_indicator.visible:
		return
	
	# Stop pulse animation
	if danger_pulse_tween and danger_pulse_tween.is_valid():
		danger_pulse_tween.kill()
		danger_pulse_tween = null
	
	var tween = create_tween()
	tween.tween_property(danger_indicator, "modulate:a", 0.0, 0.2)
	tween.tween_property(danger_indicator, "scale", Vector2(0.5, 0.5), 0.2)
	tween.tween_callback(func(): danger_indicator.visible = false)

func _sync_ultimate_visuals() -> void:
	if PotionManager.is_ultimate_mode_active():
		animated_sprite.modulate = Color(0.3, 1.0, 0.3, 1.0)
	else:
		animated_sprite.modulate = original_color

	update_energy_display()
