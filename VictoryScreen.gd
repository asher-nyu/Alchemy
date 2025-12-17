extends Control

func _ready() -> void:
	pass

func _on_play_again_button_pressed() -> void:
	
	# Reset PotionManager
	if has_node("/root/PotionManager"):
		PotionManager.reset_all()
		
	
	# Reset LevelManager
	if has_node("/root/LevelManager"):
		LevelManager.reset_all()
	
	
	# Reset Inventory
	if has_node("/root/Inventory"):
		Inventory.reset_game()
		
	await get_tree().process_frame
	
	# Go back to level 1
	get_tree().change_scene_to_file("res://level_1.tscn")

func _on_quit_button_pressed() -> void:
	get_tree().quit()
