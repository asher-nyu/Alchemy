extends Area2D

@export var next_scene: String = "res://match3.tscn"

func _ready():
	body_entered.connect(_on_body_entered)
	add_to_group("door")

func _on_body_entered(body):
	if body.is_in_group("Player"):
		get_tree().change_scene_to_file(next_scene)
