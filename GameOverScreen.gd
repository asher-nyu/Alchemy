extends Node

var level_to_load: String = ""  # This will store the level path to reload
var can_restart: bool = false  # Prevent immediate restart

func _ready():
	# Find the start button and disable auto-focus to prevent accidental activation
	var button = get_node_or_null("BottomPanel/StartButton")
	if button:
		button.focus_mode = Control.FOCUS_NONE  # Disable keyboard focus
	
	# Add a short delay before allowing restart
	await get_tree().create_timer(0.5).timeout
	can_restart = true

func _on_start_button_pressed() -> void:
	if not can_restart:
		return
	
	if has_node("/root/PotionManager"):
		PotionManager.reset_health()
		
	if has_node("/root/Inventory"):
		Inventory.reset_game()
		
	get_tree().change_scene_to_file(level_to_load)
