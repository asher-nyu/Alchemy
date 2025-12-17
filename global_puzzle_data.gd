extends Node
# Which level to go to after puzzle completion
var next_level_scene: String = ""

func puzzle_completed():
	
	# Go to the next level
	if next_level_scene != "":
		get_tree().call_deferred("change_scene_to_file", next_level_scene)
	else:
		if has_node("/root/LevelManager"):
			var level_path = LevelManager.get_next_level()
			get_tree().call_deferred("change_scene_to_file", level_path)
		else:
			# Last resort fallback
			get_tree().call_deferred("change_scene_to_file", "res://level_2.tscn")

func reset_puzzle_data():
	next_level_scene = ""
