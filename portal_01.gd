extends Area2D

@export var current_level_number: int = 1
@export var next_scene: String = "res://match3.tscn"
@export var door_locked_color: Color = Color(0.5, 0.5, 0.5, 1.0)
@export var door_unlocked_color: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var requires_boss_defeat: bool = false 

var portal_sound = AudioStreamPlayer.new()
var is_unlocked: bool = false
var player_in_range: bool = false
var input_cooldown: float = 1.0
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
	
	# Check if this door requires boss defeat
	if requires_boss_defeat:
		is_unlocked = false
		set_door_locked()
	else:
		is_unlocked = true
		set_door_unlocked()
	
	player_in_range = false
	
func unlock_door():
	"""Called when boss is defeated"""
	is_unlocked = true
	set_door_unlocked()

func set_door_locked():
	"""Set the door to locked state"""
	is_unlocked = false
	if sprite:
		sprite.modulate = door_locked_color
	if animated_sprite:
		animated_sprite.modulate = door_locked_color

func _process(delta):
	time_since_ready += delta
	
	if player_in_range and time_since_ready >= input_cooldown:
		if Input.is_action_just_pressed("ui_accept"):
			if not is_unlocked:
				show_message("LOCKED! Defeat the boss!")
				return
			
			var player = get_tree().get_first_node_in_group("Player")
			if player and is_instance_valid(player):
				enter_door()
	
	# Show appropriate message
	if player_in_range:
		if not is_unlocked:
			show_message("LOCKED! Defeat the boss!")
		elif time_since_ready >= input_cooldown:
			show_message("Press ENTER to enter")
		else:
			show_message("Door ready...")

func set_door_unlocked():
	"""Set the door to unlocked state with visual feedback."""
	is_unlocked = true
	
	if sprite:
		sprite.modulate = door_unlocked_color
	if animated_sprite:
		animated_sprite.modulate = door_unlocked_color

func _on_body_entered(body):
	if body.is_in_group("Player"):
		await get_tree().create_timer(0.5).timeout
		if is_instance_valid(body) and body.is_in_group("Player"):
			player_in_range = true


func _on_body_exited(body):
	if body.is_in_group("Player"):
		player_in_range = false
		hide_message()

func _exit_tree():
	player_in_range = false

func enter_door():
	"""Player enters the door - go to match-3 and set next level."""
	if not is_unlocked:
		
		return
	
	
	
	if has_node("/root/LevelManager"):
		LevelManager.set_next_level(current_level_number)
		var next_level = LevelManager.get_next_level()
		GlobalPuzzleData.next_level_scene = next_level
	
	if portal_sound:
		portal_sound.play()
		await portal_sound.finished
	
	var tree = get_tree()
	if tree:
		tree.change_scene_to_file(next_scene)

func show_message(text: String):
	if not label:
		create_label()
	
	if label:
		label.text = text
		label.visible = true

func hide_message():
	if label:
		label.visible = false

func create_label():
	if label:
		return
	
	label = Label.new()
	label.name = "Label"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.position = Vector2(-100, -80)
	label.size = Vector2(200, 40)
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color.YELLOW)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 3)
	label.visible = false
	add_child(label)
