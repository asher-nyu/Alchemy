extends Node

var level_to_load: String = ""  # This will store the level path to reload

func _on_start_button_pressed() -> void:
	
	if has_node("/root/PotionManager"):
		PotionManager.reset_health()
		
	if has_node("/root/Inventory"):
		Inventory.reset_game()
		
	get_tree().change_scene_to_file(level_to_load)
