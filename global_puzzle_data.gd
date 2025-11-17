extends Node
# Which level to go to after puzzle completion
var next_level_scene: String = ""

func puzzle_completed():
	print("Puzzle completed!")
	print("Going to next level: ", next_level_scene)
	
	# Go to the next level
	if next_level_scene != "":
		get_tree().call_deferred("change_scene_to_file", next_level_scene)
	else:
		get_tree().call_deferred("change_scene_to_file", "res://level_2.tscn")

func reset_puzzle_data():
	next_level_scene = ""
