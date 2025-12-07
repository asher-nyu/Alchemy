extends Node

# Tracks which level the player just completed and where to go next

var current_level: int = 1
var next_level_path: String = "res://level_2.tscn"

# Track enemies killed for bonus match-3 moves
var enemies_killed_this_level: int = 0

func set_next_level(level_number: int):
	"""Call this when entering a door to set where match-3 should lead."""
	current_level = level_number
	
	match level_number:
		1:
			next_level_path = "res://level_2.tscn"
		2:
			next_level_path = "res://level_3.tscn"
		3:
			next_level_path = "res://level_4.tscn"
		4:
			next_level_path = "res://level_5.tscn"
		_:
			next_level_path = "res://level_1.tscn"  # Loop back or game over
	
	print("LevelManager: Next level set to ", next_level_path)

func get_next_level() -> String:
	return next_level_path

func go_to_match3():
	get_tree().change_scene_to_file("res://match3.tscn")

func go_to_next_level():
	get_tree().change_scene_to_file(next_level_path)

func add_enemy_kill():
	"""Call this when an enemy dies to grant bonus match-3 moves"""
	enemies_killed_this_level += 1
	print("LevelManager: Enemy killed! Total: %d (bonus moves for match-3)" % enemies_killed_this_level)

func get_bonus_moves() -> int:
	"""Get the number of bonus moves earned from killing enemies"""
	return enemies_killed_this_level

func reset_enemy_kills():
	"""Reset the enemy kill counter (called when starting a new level or after match-3)"""
	enemies_killed_this_level = 0
