extends Node

func _ready():
	# Save health when entering this level
	if has_node("/root/LevelManager"):
		LevelManager.save_health_snapshot()
