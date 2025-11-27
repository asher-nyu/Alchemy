extends Node

var health_potion_sound = AudioStreamPlayer.new()

# Player health management
var max_health: int = 100
var current_health: int = 100

# Signals for UI updates
signal health_changed(current: int, maximum: int)
signal player_died()

func _ready():
	add_child(health_potion_sound)
	health_potion_sound.stream = load("res://assets/Audio Pack/health_potion_sound.wav")
	
	# Initialize health
	current_health = max_health
	health_changed.emit(current_health, max_health)

# ==================== HEALTH MANAGEMENT ====================

func get_current_health() -> int:
	return current_health

func get_max_health() -> int:
	return max_health

func set_max_health(value: int):
	max_health = value
	current_health = min(current_health, max_health)
	health_changed.emit(current_health, max_health)

func take_damage(amount: int) -> bool:
	var old_health = current_health
	current_health = max(0, current_health - amount)
	
	health_changed.emit(current_health, max_health)
	
	if current_health <= 0 and old_health > 0:
		player_died.emit()
		return true
	
	return false

func heal(amount: int):
	if health_potion_sound and not health_potion_sound.playing:
			health_potion_sound.play()
			
	current_health = min(max_health, current_health + amount)
	health_changed.emit(current_health, max_health)

func is_at_full_health() -> bool:
	return current_health >= max_health

func get_health_percentage() -> float:
	if max_health == 0:
		return 0.0
	return float(current_health) / float(max_health)

# ==================== RESET/INITIALIZATION ====================

func reset_health():
	current_health = max_health
	health_changed.emit(current_health, max_health)

func reset_all():
	current_health = max_health
	health_changed.emit(current_health, max_health)

# ==================== UTILITY FUNCTIONS ====================

func get_health_display_text() -> String:
	return "HP: %d/%d" % [current_health, max_health]
