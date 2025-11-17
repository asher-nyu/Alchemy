extends Node

func _ready():
	print("GameOverScreen: Ready")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			_start_game()

func _on_start_button_pressed() -> void:
	_start_game()

func _start_game() -> void:
	
	
	if has_node("/root/PotionManager"):
		PotionManager.reset_health()
		
	if has_node("/root/Inventory"):
		Inventory.reset_game()
		
	get_tree().change_scene_to_file("res://level_1.tscn")
