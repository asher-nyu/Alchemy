extends Node

var level_to_load: String = ""
var can_restart: bool = false

func _ready():
	var button = get_node_or_null("BottomPanel/StartButton")
	if button:
		button.focus_mode = Control.FOCUS_NONE
	
	await get_tree().create_timer(0.5).timeout
	can_restart = true

func _on_start_button_pressed() -> void:
	if not can_restart:
		return
	
	can_restart = false  
	
	
	# Restore health to what it was when entering the level
	if has_node("/root/LevelManager"):
		LevelManager.restore_health_snapshot()
		LevelManager.reset_enemy_kills()
	
	await get_tree().process_frame
	
	get_tree().change_scene_to_file(level_to_load)
