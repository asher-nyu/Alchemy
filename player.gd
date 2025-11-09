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
@onready var camera = $Camera2D2
@onready var health_label = $Camera2D2/UI/HealthLabel
@onready var potion_label = $Camera2D2/UI/PotionLabel

var inventory_ui = null

func _ready():
	print("PLAYER: _ready() called!")
	
	# Try to find the InventoryUI node
	inventory_ui = get_node_or_null("Camera2D2/UI/InventoryUI")
	print("PLAYER: inventory_ui = ", inventory_ui)
	
	if inventory_ui:
		print("PLAYER: InventoryUI FOUND!")
		print("PLAYER: InventoryUI visible = ", inventory_ui.visible)
		print("PLAYER: InventoryUI position = ", inventory_ui.position)
		print("PLAYER: InventoryUI global_position = ", inventory_ui.global_position)
		inventory_ui.visible = true
		inventory_ui.z_index = 1000
	else:
		print("PLAYER: InventoryUI NOT FOUND! Searching for it...")
		# Try to find it by traversing the tree
		var ui_layer = null
		for child in camera.get_children():
			print("  Camera child: ", child.name)
			if child.name == "UI":
				ui_layer = child
				for ui_child in child.get_children():
					print("    UI child: ", ui_child.name)
					if ui_child.name == "InventoryUI":
						inventory_ui = ui_child
						print("PLAYER: Found InventoryUI by search!")
		
		# If still not found, create it programmatically
		if not inventory_ui and ui_layer:
			print("PLAYER: Creating InventoryUI programmatically...")
			var InventoryUIScript = load("res://InventoryUI.gd")
			inventory_ui = Control.new()
			inventory_ui.name = "InventoryUI"
			inventory_ui.set_script(InventoryUIScript)
			
			# Position at bottom-right
			inventory_ui.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
			inventory_ui.anchor_left = 1.0
			inventory_ui.anchor_top = 1.0
			inventory_ui.anchor_right = 1.0
			inventory_ui.anchor_bottom = 1.0
			inventory_ui.offset_left = -320
			inventory_ui.offset_top = -180
			inventory_ui.offset_right = -20
			inventory_ui.offset_bottom = -20
			inventory_ui.visible = true
			inventory_ui.z_index = 1000
			
			# Create dark semi-transparent background
			var bg = ColorRect.new()
			bg.name = "Background"
			bg.color = Color(0.1, 0.1, 0.1, 0.9)
			bg.set_anchors_preset(Control.PRESET_FULL_RECT)
			inventory_ui.add_child(bg)
			
			# Create title label
			var title = Label.new()
			title.name = "Title"
			title.text = "INVENTORY"
			title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			title.add_theme_font_size_override("font_size", 24)
			title.add_theme_color_override("font_color", Color(1, 1, 0, 1))
			title.position = Vector2(0, 10)
			title.size = Vector2(300, 30)
			inventory_ui.add_child(title)
			
			# Create HBoxContainer for slots
			var hbox = HBoxContainer.new()
			hbox.name = "HBoxContainer"
			hbox.position = Vector2(15, 50)
			hbox.size = Vector2(270, 100)
			hbox.add_theme_constant_override("separation", 10)
			hbox.alignment = BoxContainer.ALIGNMENT_CENTER
			inventory_ui.add_child(hbox)
			
			# Create 3 slots
			for i in range(3):
				var slot = Panel.new()
				slot.name = "Slot" + str(i + 1)
				slot.custom_minimum_size = Vector2(85, 95)
				
				# Create StyleBox for slot border
				var style = StyleBoxFlat.new()
				style.bg_color = Color(0.15, 0.15, 0.15, 1)
				style.border_color = Color(1, 1, 0, 1)
				style.border_width_left = 3
				style.border_width_right = 3
				style.border_width_top = 3
				style.border_width_bottom = 3
				style.corner_radius_top_left = 4
				style.corner_radius_top_right = 4
				style.corner_radius_bottom_left = 4
				style.corner_radius_bottom_right = 4
				slot.add_theme_stylebox_override("panel", style)
				
				# Key label (1, 2, 3)
				var key_label = Label.new()
				key_label.name = "KeyLabel"
				key_label.text = str(i + 1)
				key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				key_label.add_theme_font_size_override("font_size", 22)
				key_label.add_theme_color_override("font_color", Color(1, 1, 0, 1))
				key_label.position = Vector2(0, 5)
				key_label.size = Vector2(85, 25)
				slot.add_child(key_label)
				
				# Potion icon
				var icon = TextureRect.new()
				icon.name = "PotionIcon"
				icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				icon.position = Vector2(12, 30)
				icon.size = Vector2(60, 60)
				icon.visible = false
				slot.add_child(icon)
				
				hbox.add_child(slot)
			
			# Add to UI layer
			ui_layer.add_child(inventory_ui)
			print("PLAYER: InventoryUI created and added!")
	
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
	
	# Handle inventory hotkeys - 1, 2, 3 keys ONLY (not Enter!)
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
			run_sound.connect("finished", Callable(run_sound, "play"))  # restart when done
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
		heal(50)  # Heal 50 HP
		update_potion_display()
		print("Used health potion! Potions remaining: ", Inventory.get_health_potions())

func use_potion_from_slot(slot_number: int) -> void:
	var potion_count = Inventory.get_health_potions()
	
	# Check if this slot has a potion
	if slot_number <= potion_count:
		if current_health < max_health and Inventory.use_health_potion():
			heal(50)  # Heal 50 HP
			update_potion_display()
			print("Used potion from slot %d! Potions remaining: %d" % [slot_number, Inventory.get_health_potions()])
			
			# Start potion cooldown
			can_use_potion = false
			await get_tree().create_timer(POTION_COOLDOWN).timeout
			can_use_potion = true
	else:
		print("No potion in slot %d" % slot_number)
