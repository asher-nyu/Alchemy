extends Node2D

@onready var boss = $Boss
@onready var door = $door 

func _ready():
	
	if has_node("/root/LevelManager"):
		LevelManager.save_health_snapshot()
		
	if boss:
		boss.boss_defeated.connect(_on_boss_defeated)
	
func _on_boss_defeated():
	if door:
		door.unlock_door()
