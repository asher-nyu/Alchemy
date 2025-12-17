extends Node

func _on_start_button_pressed() -> void:
	
	if has_node("/root/PotionManager"):
		PotionManager.reset_health()
		
	if has_node("/root/Inventory"):
		Inventory.reset_game()
		
	get_tree().change_scene_to_file("res://level_1.tscn")
