extends Area2D

@export var next_scene: String = "res://match3.tscn"

var portal_sound = AudioStreamPlayer.new()

func _ready():
	body_entered.connect(_on_body_entered)
	add_to_group("door")
	
	add_child(portal_sound)
	portal_sound.stream = load("res://assets/Audio Pack/portal.wav")

func _on_body_entered(body):
	if body.is_in_group("Player"):
		# Play portal sound
		if portal_sound:
			portal_sound.play()
		
		# Optional: wait for sound to finish before changing scene
		var sound_length = portal_sound.stream.get_length()
		await get_tree().create_timer(sound_length).timeout
		
		get_tree().change_scene_to_file(next_scene)
