extends CharacterBody2D

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

@onready var animated_sprite = $AnimatedSprite2D
@onready var camera = $Camera2D2
@onready var health_label = $Camera2D2/UI/HealthLabel

func _ready():
	current_health = max_health
	
	if health_label:
		
		# Check parent visibility
		var parent = health_label.get_parent()
		print("   Parent (UI) visible: ", parent.visible if parent else "No parent")
		
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
	
	update_health_display()
	add_to_group("Player")

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	# Handle attack input - ENTER KEY
	if Input.is_action_just_pressed("ui_accept") and can_attack:
		perform_attack()
	
	if Input.is_action_just_pressed("ui_up") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	
	var direction := Input.get_axis("ui_left", "ui_right")
	
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
		if enemy and is_instance_valid(enemy):
			var distance = global_position.distance_to(enemy.global_position)
			
			if distance <= attack_range:
				if enemy.has_method("take_damage"):
					enemy.take_damage(attack_damage)
					hit_something = true
	
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
	get_tree().reload_current_scene()
	

func update_health_display() -> void:
	if health_label:
		health_label.text = "HP: %d/%d" % [current_health, max_health]
