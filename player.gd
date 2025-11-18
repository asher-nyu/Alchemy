
extends CharacterBody2D

var run_sound = AudioStreamPlayer.new()
var attack_sound = AudioStreamPlayer.new()
var hero_death_sound = AudioStreamPlayer.new()
var hero_jump_sound = AudioStreamPlayer.new()

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
@onready var potion_label = $Camera2D2/UI/PotionLabel

var inventory_ui = null
var potion_slots = []  # Keep track of slots for click detection

var original_color = Color.WHITE

func _ready():
	print("PLAYER: _ready() called!")
	
	original_color = animated_sprite.modulate
	
	# Connect to PotionManager signals
	PotionManager.health_changed.connect(_on_health_changed)
	PotionManager.potion_used.connect(_on_potion_used)
	PotionManager.potion_count_changed.connect(_on_potion_count_changed)
	PotionManager.player_died.connect(_on_player_died)
	PotionManager.strength_activated.connect(_on_strength_activated)
	PotionManager.strength_deactivated.connect(_on_strength_deactivated)
	
	# Try to find the InventoryUI node
	inventory_ui = get_node_or_null("Camera2D2/UI/InventoryUI")
	print("PLAYER: inventory_ui = ", inventory_ui)
	
	if inventory_ui:
		print("PLAYER: InventoryUI FOUND!")
		print("PLAYER: InventoryUI visible = ", inventory_ui.visible)
		inventory_ui.visible = true
		inventory_ui.z_index = 1000
		setup_existing_inventory_ui()
	else:
		print("PLAYER: InventoryUI NOT FOUND! Creating it...")
		create_inventory_ui()
	
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
	
	if potion_label:
		potion_label.visible = true
		potion_label.add_theme_font_size_override("font_size", 48)
		potion_label.add_theme_color_override("font_color", Color.CYAN)
	
	# Initial UI update
	update_health_display()
	update_potion_display()
	update_potion_icons()
	add_to_group("Player")

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	# Handle inventory hotkeys - 1, 2, 3 keys for potions
	if Input.is_physical_key_pressed(KEY_1):
		PotionManager.use_potion_from_slot(0) 
	elif Input.is_physical_key_pressed(KEY_2):
		PotionManager.use_potion_from_slot(1)  
	elif Input.is_physical_key_pressed(KEY_3):
		PotionManager.use_potion_from_slot(2)  
	
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

func setup_existing_inventory_ui():
	var hbox = inventory_ui.get_node_or_null("HBoxContainer")
	if not hbox:
		return
	
	potion_slots.clear()
	
	for i in range(3):
		var slot = hbox.get_node_or_null("Slot" + str(i + 1))
		if slot:
			potion_slots.append(slot)
			slot.mouse_filter = Control.MOUSE_FILTER_STOP
			slot.gui_input.connect(_on_slot_gui_input.bind(i)) 
			slot.mouse_entered.connect(_on_slot_mouse_entered.bind(slot))
			slot.mouse_exited.connect(_on_slot_mouse_exited.bind(slot))
			print("PLAYER: Connected slot %d" % i)

func create_inventory_ui():
	"""Create the InventoryUI programmatically."""
	var ui_layer = null
	
	# Find UI layer
	for child in camera.get_children():
		if child.name == "UI":
			ui_layer = child
			break
	
	if not ui_layer:
		print("PLAYER: ERROR - UI layer not found!")
		return
	
	print("PLAYER: Creating InventoryUI programmatically...")
	inventory_ui = Control.new()
	inventory_ui.name = "InventoryUI"
	
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
	inventory_ui.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Create dark semi-transparent background
	var bg = ColorRect.new()
	bg.name = "Background"
	bg.color = Color(0.1, 0.1, 0.1, 0.9)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inventory_ui.add_child(bg)
	
	var title = Label.new()
	title.name = "Title"
	title.text = "INVENTORY"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1, 1, 0, 1))
	title.position = Vector2(0, 10)
	title.size = Vector2(300, 30)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inventory_ui.add_child(title)
	
	var hbox = HBoxContainer.new()
	hbox.name = "HBoxContainer"
	hbox.position = Vector2(15, 50)
	hbox.size = Vector2(270, 100)
	hbox.add_theme_constant_override("separation", 10)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inventory_ui.add_child(hbox)
	
	potion_slots.clear()
	
	for i in range(3):
		var slot = Panel.new()
		slot.name = "Slot" + str(i + 1)
		slot.custom_minimum_size = Vector2(85, 95)
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		
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
		
		slot.gui_input.connect(_on_slot_gui_input.bind(i)) 
		slot.mouse_entered.connect(_on_slot_mouse_entered.bind(slot))
		slot.mouse_exited.connect(_on_slot_mouse_exited.bind(slot))
		
		potion_slots.append(slot)
		
		var key_label = Label.new()
		key_label.name = "KeyLabel"
		key_label.text = str(i + 1)
		key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		key_label.add_theme_font_size_override("font_size", 22)
		key_label.add_theme_color_override("font_color", Color(1, 1, 0, 1))
		key_label.position = Vector2(0, 5)
		key_label.size = Vector2(85, 25)
		key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(key_label)
		
		# Potion icon
		var icon = TextureRect.new()
		icon.name = "PotionIcon"
		icon.texture = load("res://assets/pink_potion.png")
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.position = Vector2(10, 35)
		icon.size = Vector2(65, 55)
		icon.visible = false
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(icon)
		
		hbox.add_child(slot)
	
	# Add to UI layer
	ui_layer.add_child(inventory_ui)

# --- ATTACK SYSTEM ---
func perform_attack():
	can_attack = false
	is_attacking = true
	
	# Update attack damage based on strength buff
	attack_damage = int(base_attack_damage * PotionManager.get_damage_multiplier())
	
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

# --- POTION SLOT CLICK HANDLERS ---
func _on_slot_gui_input(event: InputEvent, slot_number: int):
	"""Handle clicks on potion slots."""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("PLAYER: Clicked slot %d!" % slot_number)
		var success = PotionManager.use_potion_from_slot(slot_number)
		if success:
			# Visual feedback - flash the slot
			flash_potion_slot(slot_number + 1)  # Add 1 for display purposes

func _on_slot_mouse_entered(slot: Panel):
	"""Provide hover feedback when mouse enters a slot."""
	# Check if this slot has a potion
	var potion_count = PotionManager.get_potion_count()
	var slot_index = int(slot.name.substr(4)) - 1  
	
	if slot_index < potion_count:
		# Brighten the slot slightly
		var tween = create_tween()
		tween.tween_property(slot, "modulate", Color(1.2, 1.2, 1.2, 1), 0.1)

func _on_slot_mouse_exited(slot: Panel):
	var tween = create_tween()
	tween.tween_property(slot, "modulate", Color(1, 1, 1, 1), 0.1)

func flash_potion_slot(slot_number: int):
	if slot_number < 1 or slot_number > potion_slots.size():
		return
	
	var slot = potion_slots[slot_number - 1]
	if not slot:
		return
	
	# Flash effect (green)
	var tween = create_tween()
	tween.tween_property(slot, "modulate", Color(0.5, 1.5, 0.5, 1), 0.15)
	tween.tween_property(slot, "modulate", Color(1, 1, 1, 1), 0.15)

func _on_strength_activated(duration: float):
	
	# Turn player green
	animated_sprite.modulate = Color(0.3, 1.0, 0.3, 1.0)  # Bright green
	

func _on_strength_deactivated():
	animated_sprite.modulate = original_color

# --- POTION ICON VISIBILITY ---
func update_potion_icons():
	if not inventory_ui:
		return
	
	var hbox = inventory_ui.get_node_or_null("HBoxContainer")
	if not hbox:
		return
	
	var potion_slots_data = Inventory.get_potion_slots()
	
	for i in range(3):
		var slot = hbox.get_node_or_null("Slot" + str(i + 1))
		if slot:
			var icon = slot.get_node_or_null("PotionIcon")
			if icon:
				if i < potion_slots_data.size():
					# Show icon with correct texture
					icon.visible = true
					var potion_type = potion_slots_data[i]
					match potion_type:
						Inventory.PotionType.PINK:
							icon.texture = load("res://assets/pink_potion.png")
						Inventory.PotionType.GREEN:
							icon.texture = load("res://assets/green_potion.png")
						Inventory.PotionType.BLUE:
							if ResourceLoader.exists("res://assets/blue_potion.png"):
								icon.texture = load("res://assets/blue_potion.png")
				else:
					icon.visible = false

# --- POTION MANAGER SIGNAL HANDLERS ---
func _on_health_changed(current: int, maximum: int):
	update_health_display()

func _on_potion_used(potions_remaining: int):
	update_potion_display()
	update_potion_icons()
	print("PLAYER: Potion used! Remaining: %d" % potions_remaining)

func _on_potion_count_changed(new_count: int):
	update_potion_display()
	update_potion_icons()

# --- UI UPDATE FUNCTIONS ---
func update_health_display() -> void:
	if health_label:
		health_label.text = PotionManager.get_health_display_text()

func update_potion_display() -> void:
	if potion_label:
		var base_text = PotionManager.get_potion_display_text()
		var strength_text = PotionManager.get_strength_display_text()
		if strength_text != "":
			potion_label.text = base_text + " | " + strength_text
		else:
			potion_label.text = base_text

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

	# Wait for death sound, then switch scene
	await get_tree().create_timer(hero_death_sound.stream.get_length()).timeout
	get_tree().change_scene_to_file("res://GameOverScreen.tscn")
