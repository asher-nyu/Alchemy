extends Node

# Tracks which level the player just completed and where to go next
var current_level: int = 1
var next_level_path: String = "res://level_2.tscn"

# Track enemies killed for bonus match-3 moves
var enemies_killed_this_level: int = 0

# Health snapshot system
var health_on_level_entry: int = 100
var max_health_on_level_entry: int = 100

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
			next_level_path = "res://queen_rescue.tscn"
		5:
			next_level_path = "res://VictoryScreen.tscn"
	

func get_next_level() -> String:
	return next_level_path

func go_to_match3():
	get_tree().change_scene_to_file("res://match3.tscn")

func go_to_next_level():
	get_tree().change_scene_to_file(next_level_path)

func add_enemy_kill():
	"""Call this when an enemy dies to grant bonus match-3 moves"""
	enemies_killed_this_level += 1
	

func get_bonus_moves() -> int:
	"""Get the number of bonus moves earned from killing enemies"""
	return enemies_killed_this_level

func reset_enemy_kills():
	"""Reset the enemy kill counter (called when starting a new level or after match-3)"""
	enemies_killed_this_level = 0

func reset_all():
	current_level = 1
	next_level_path = "res://level_2.tscn"
	enemies_killed_this_level = 0
	
func save_health_snapshot():
	if has_node("/root/PotionManager"):
		health_on_level_entry = PotionManager.get_current_health()
		max_health_on_level_entry = PotionManager.get_max_health()

func restore_health_snapshot():
	
	if has_node("/root/PotionManager"):
		PotionManager.max_health = max_health_on_level_entry
		PotionManager.current_health = health_on_level_entry
		PotionManager.health_changed.emit(PotionManager.current_health, PotionManager.max_health)
		
