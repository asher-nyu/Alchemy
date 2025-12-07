extends Area2D

@export var current_level_number: int = 1
@export var next_scene: String = "res://match3.tscn"  # Always goes to match-3
@export var door_locked_color: Color = Color(0.5, 0.5, 0.5, 1.0)
@export var door_unlocked_color: Color = Color(1.0, 1.0, 1.0, 1.0)

var portal_sound = AudioStreamPlayer.new()
var is_unlocked: bool = false
var player_in_range: bool = false
var input_cooldown: float = 1.0  # Cooldown after level load
var time_since_ready: float = 0.0

@onready var sprite = $Sprite2D if has_node("Sprite2D") else null
@onready var animated_sprite = $AnimatedSprite2D if has_node("AnimatedSprite2D") else null
@onready var label = $Label if has_node("Label") else null

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	add_to_group("door")
	
	add_child(portal_sound)
	portal_sound.stream = load("res://assets/Audio Pack/portal.wav")
	
	# Doors are now always unlocked - no need to kill enemies
	is_unlocked = true
	player_in_range = false
	set_door_unlocked()
	
	print("Door ready (always unlocked). Current level: ", current_level_number, " → Next scene: ", next_scene)

func _process(delta):
	# Track time since ready for input cooldown
	time_since_ready += delta
	
	# Check for door entry input (using Input.is_action_just_pressed instead of _input)
	if player_in_range and is_unlocked and time_since_ready >= input_cooldown:
		if Input.is_action_just_pressed("ui_accept"):
			var player = get_tree().get_first_node_in_group("Player")
			if player and is_instance_valid(player):
				enter_door()
	
	# Show message if player is near (door is always unlocked now)
	if player_in_range:
		if time_since_ready >= input_cooldown:
			show_message("Press ENTER to enter")
		else:
			show_message("Door ready...")

func set_door_unlocked():
	"""Set the door to unlocked state with visual feedback."""
	is_unlocked = true
	
	# Visual feedback - door is always unlocked
	if sprite:
		sprite.modulate = door_unlocked_color
	if animated_sprite:
		animated_sprite.modulate = door_unlocked_color

func _on_body_entered(body):
	if body.is_in_group("Player"):
		# Don't trigger if scene is reloading
		await get_tree().create_timer(0.5).timeout
		if is_instance_valid(body) and body.is_in_group("Player"):
			player_in_range = true
			print("Player near door. Unlocked: ", is_unlocked)

func _on_body_exited(body):
	if body.is_in_group("Player"):
		player_in_range = false
		hide_message()

func _exit_tree():
	# Clean up when scene changes
	player_in_range = false

# Removed _input to prevent global input capturing that interferes with player attacks
# Door entry is now handled in _process() using Input.is_action_just_pressed

func enter_door():
	"""Player enters the door - go to match-3 and set next level."""
	if not is_unlocked:
		print("Door is locked! Kill all enemies first!")
		return
	
	print("Entering door from level %d → %s" % [current_level_number, next_scene])
	print("DEBUG: Has LevelManager: ", has_node("/root/LevelManager"))
	
	if has_node("/root/LevelManager"):
		LevelManager.set_next_level(current_level_number)
		
		# Set GlobalPuzzleData to know where to go after match-3
		var next_level = LevelManager.get_next_level()
		GlobalPuzzleData.next_level_scene = next_level
	
	# Play portal sound
	if portal_sound:
		portal_sound.play()
		await portal_sound.finished
	
	# Go to match-3
	print("DEBUG: Changing scene now")
	var tree = get_tree()
	if tree:
		tree.change_scene_to_file(next_scene)
	else:
		print("ERROR: SceneTree is null!")
	
func show_message(text: String):
	"""Show a message above the door."""
	if not label:
		create_label()
	
	if label:
		label.text = text
		label.visible = true

func hide_message():
	"""Hide the message."""
	if label:
		label.visible = false

func create_label():
	"""Create a label for door messages if it doesn't exist."""
	if label:
		return
	
	label = Label.new()
	label.name = "Label"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# Position above door
	label.position = Vector2(-100, -80)
	label.size = Vector2(200, 40)
	
	# Style
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color.YELLOW)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 3)
	
	label.visible = false
	add_child(label)
