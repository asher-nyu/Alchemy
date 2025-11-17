extends CharacterBody2D

var run_sound = AudioStreamPlayer.new()
var attack_sound = AudioStreamPlayer.new()
var hero_death_sound = AudioStreamPlayer.new()
var hero_jump_sound = AudioStreamPlayer.new()



const SPEED = 400.0
const JUMP_VELOCITY = -800.0
const AIR_CONTROL = 0.8

@export var max_health: int = 100
var current_health: int = max_health

# Attack properties
var can_attack = true
var is_attacking = false
var attack_damage = 25
var attack_range = 300.0
const ATTACK_COOLDOWN = 0.5
const ATTACK_ANIMATION_TIME = 0.3

# Potion usage cooldown
var can_use_potion = true
const POTION_COOLDOWN = 0.3

@onready var animated_sprite = $AnimatedSprite2D
@onready var camera = $Camera2D3
@onready var health_label = $Camera2D3/UI/HealthLabel
@onready var potion_label = $Camera2D3/UI/PotionLabel

func _ready():
	
	add_child(run_sound)
	run_sound.stream = load("res://assets/Audio Pack/run.wav")
	run_sound.pitch_scale = 1.2  # make it faster
	
	add_child(attack_sound)
	attack_sound.stream = load("res://assets/Audio Pack/attack.mp3")
	
	add_child(hero_death_sound)
	hero_death_sound.stream = load("res://assets/Audio Pack/hero-death.mp3")
	
	add_child(hero_jump_sound)
	hero_jump_sound.stream = load("res://assets/Audio Pack/jump.mp3")


	
	current_health = max_health
	
	if health_label:
		var parent = health_label.get_parent()
		
		# Force set properties to make it visible
		health_label.visible = true
		health_label.text = "HP: 100/100"
		health_label.position = Vector2(10, 10)
		
		# Try to make it bigger and more obvious
		health_label.add_theme_font_size_override("font_size", 48)
		health_label.add_theme_color_override("font_color", Color.RED)  # Bright red so you can't miss it
	
	if camera:
		camera.enabled = true
		camera.make_current()
	
	# Setup potion label if it exists
	if potion_label:
		potion_label.visible = true
		potion_label.add_theme_font_size_override("font_size", 48)
		potion_label.add_theme_color_override("font_color", Color.CYAN)
	
	update_health_display()
	update_potion_display()
	add_to_group("Player")

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	# Handle potion hotkeys - 1, 2, 3 keys
	if can_use_potion:
		if Input.is_physical_key_pressed(KEY_1):
			use_potion_from_slot(1)
		elif Input.is_physical_key_pressed(KEY_2):
			use_potion_from_slot(2)
		elif Input.is_physical_key_pressed(KEY_3):
			use_potion_from_slot(3)
	
	# Handle attack input - ENTER KEY
	if Input.is_action_just_pressed("ui_accept") and can_attack:
		perform_attack()
	
	if Input.is_action_just_pressed("ui_up") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		if hero_jump_sound and not hero_jump_sound.playing:
			hero_jump_sound.play()
	
	var direction := Input.get_axis("ui_left", "ui_right")
	
	if direction != 0 and is_on_floor():
		if not run_sound.playing:
			run_sound.play()
			# Connect signal only if not already connected
			if not run_sound.is_connected("finished", Callable(run_sound, "play")):
				run_sound.connect("finished", Callable(run_sound, "play"))  # restart when done
	else:
		if run_sound.playing:
			run_sound.stop()
			# Disconnect signal only if it's connected
			if run_sound.is_connected("finished", Callable(run_sound, "play")):
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
	
	if not is_attacking:
		if not is_on_floor():
			animated_sprite.play("jump")
		elif direction != 0:
			animated_sprite.play("run")
		else:
			animated_sprite.play("idle")

# --- ATTACK SYSTEM ---
func perform_attack():
	can_attack = false
	is_attacking = true
	
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
					enemy.take_damage(attack_damage)
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
	current_health = max(current_health - amount, 0)
	update_health_display()
	
	# Visual feedback - flash sprite red
	animated_sprite.modulate = Color.RED
	await get_tree().create_timer(0.1).timeout
	animated_sprite.modulate = Color.WHITE
	
	
	if current_health <= 0:
		die()

func heal(amount: int) -> void:
	current_health = min(current_health + amount, max_health)
	update_health_display()

func die() -> void:
	await get_tree().create_timer(1.0).timeout
	
	# Play death sound
	if hero_death_sound:
		hero_death_sound.play()
		
		var hero_sound_length = hero_death_sound.stream.get_length()
		await get_tree().create_timer(hero_sound_length).timeout
	
	get_tree().change_scene_to_file("res://GameOverScreen.tscn")

	

func update_health_display() -> void:
	if health_label:
		health_label.text = "HP: %d/%d" % [current_health, max_health]

func update_potion_display() -> void:
	if potion_label:
		var potion_count = Inventory.get_health_potions()
		potion_label.text = "Potions: %d" % potion_count

func use_health_potion() -> void:
	if current_health < max_health and Inventory.use_health_potion():
		heal(50)
		update_potion_display()

func use_potion_from_slot(slot_number: int) -> void:
	var potion_count = Inventory.get_health_potions()
	
	if slot_number <= potion_count:
		if current_health < max_health and Inventory.use_health_potion():
			heal(50)
			update_potion_display()
			
			# Start potion cooldown
		can_use_potion = false
		await get_tree().create_timer(POTION_COOLDOWN).timeout
		can_use_potion = true

func melt_into_lava(target_x: float, lava_y: float) -> void:
	# Stop movement
	velocity = Vector2.ZERO
	set_process(false)
	set_physics_process(false)

	# Play death sound
	if hero_death_sound:
		hero_death_sound.play()

	var melt_time = 1.5
	var timer = 0.0
	var start_pos = global_position
	var start_scale = scale

	while timer < melt_time:
		var t = timer / melt_time
		# Keep x the same, sink y toward lava surface
		global_position.x = start_pos.x
		global_position.y = lerp(start_pos.y, lava_y, t)
		# Shrink vertically only
		scale.y = start_scale.y * (1.0 - t)
		timer += get_process_delta_time()
		await get_tree().process_frame

	# Fully disappear
	visible = false

	# Wait for death sound
	if hero_death_sound:
		var sound_length = hero_death_sound.stream.get_length()
		await get_tree().create_timer(sound_length).timeout

	# Restart scene
	get_tree().change_scene_to_file("res://GameOverScreen.tscn")
	

func start_pixel_death(delay: float = 1.0) -> void:
	# Stop movement and input
	set_process(false)
	set_physics_process(false)
	velocity = Vector2.ZERO

	# Hide main sprite
	if $AnimatedSprite2D:
		$AnimatedSprite2D.hide()

	# Play death sound once
	if hero_death_sound and not hero_death_sound.playing:
		hero_death_sound.play()

	# Bold pixel particles
	var pixels = 20
	for i in range(pixels):
		var part = Polygon2D.new()
		get_parent().add_child(part)

		# Random oval shape
		var width = randf_range(16, 32)
		var height = randf_range(8, 24)
		var segments = 16
		var points = []
		for j in range(segments):
			var angle = (float(j) / segments) * TAU
			points.append(Vector2(cos(angle) * width / 2, sin(angle) * height / 2))
		part.polygon = points

		part.color = Color(1, 0.2, 0.2)
		part.global_position = global_position + Vector2(randf()*32-16, randf()*32-16)

		# Tween particles
		var t = create_tween()
		var target_pos = part.global_position + Vector2(randf()*200-100, randf()*200-100)
		t.tween_property(part, "global_position", target_pos, delay)
		t.tween_property(part, "modulate:a", 0.0, delay)
		t.play()

	# Wait for effect + death sound
	await get_tree().create_timer(delay).timeout
	if hero_death_sound:
		var sound_length = hero_death_sound.stream.get_length()
		await get_tree().create_timer(sound_length).timeout
		get_tree().change_scene_to_file("res://GameOverScreen.tscn")

func get_hitbox_rect() -> Rect2:
	# Simple rectangular hitbox for the player
	var size = Vector2(50, 80)  # Adjust if needed
	return Rect2(global_position - size * 0.5, size)
