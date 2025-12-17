extends Node

var health_potion_sound = AudioStreamPlayer.new()

# Player health management
var max_health: int = 100
var current_health: int = 100

# Energy/Ultimate system
var max_energy: int = 100  
var current_energy: int = 0
const ENERGY_PER_DAMAGE_DEALT: int = 1  # Energy gained per point of damage dealt
const ENERGY_PER_DAMAGE_TAKEN: int = 2  # Energy gained per point of damage taken
const ULTIMATE_ATTACKS_COUNT: int = 5   # Number of boosted attacks
const ULTIMATE_DAMAGE_MULTIPLIER: float = 3.0  # 3x damage during ultimate
var ultimate_attacks_remaining: int = 0
var is_ultimate_active: bool = false
var ultimate_sound = AudioStreamPlayer.new()

# Signals for UI updates
signal health_changed(current: int, maximum: int)
signal player_died()
signal energy_changed(current: int, maximum: int)
signal ultimate_activated(attacks_count: int)
signal ultimate_deactivated()

func _ready():
	add_child(health_potion_sound)
	health_potion_sound.stream = load("res://assets/Audio Pack/health_potion_sound.wav")
	
	add_child(ultimate_sound)
	ultimate_sound.stream = load("res://assets/Audio Pack/she_hulk_potion_sound.mp3")
	
	# Initialize health
	current_health = max_health
	health_changed.emit(current_health, max_health)
	
	# Initialize energy
	current_energy = 0
	energy_changed.emit(current_energy, max_energy)

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
	
	# Gain energy from taking damage
	add_energy(amount * ENERGY_PER_DAMAGE_TAKEN)
	
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

# ==================== ENERGY/ULTIMATE SYSTEM ====================

func add_energy(amount: int):
	"""Add energy (from dealing or taking damage)"""
	if is_ultimate_active:
		return  # Don't gain energy during ultimate
	
	current_energy = min(max_energy, current_energy + amount)
	energy_changed.emit(current_energy, max_energy)
	
	# Auto-activate if full (optional - can be commented out for manual only)
	# if current_energy >= max_energy:
	#	activate_ultimate()

func add_energy_from_damage_dealt(damage_dealt: int):
	"""Call this when the player deals damage"""
	add_energy(damage_dealt * ENERGY_PER_DAMAGE_DEALT)

func can_activate_ultimate() -> bool:
	"""Check if ultimate can be activated"""
	return current_energy >= max_energy and not is_ultimate_active

func activate_ultimate() -> bool:
	"""Activate the ultimate mode - boosts next 5 attacks"""
	if not can_activate_ultimate():
		return false
	
	is_ultimate_active = true
	ultimate_attacks_remaining = ULTIMATE_ATTACKS_COUNT
	current_energy = 0  # Consume all energy
	
	# Play ultimate sound
	if ultimate_sound and not ultimate_sound.playing:
		ultimate_sound.play()
	
	energy_changed.emit(current_energy, max_energy)
	ultimate_activated.emit(ULTIMATE_ATTACKS_COUNT)
	
	return true

func get_attack_multiplier() -> float:
	"""Get the current damage multiplier for attacks"""
	if is_ultimate_active and ultimate_attacks_remaining > 0:
		return ULTIMATE_DAMAGE_MULTIPLIER
	return 1.0

func consume_ultimate_charge():
	"""Call this when the player performs an attack during ultimate"""
	if not is_ultimate_active or ultimate_attacks_remaining <= 0:
		return
	
	ultimate_attacks_remaining -= 1
	
	if ultimate_attacks_remaining <= 0:
		deactivate_ultimate()
	else:
		# Notify UI of remaining attacks
		ultimate_activated.emit(ultimate_attacks_remaining)

func deactivate_ultimate():
	"""End the ultimate mode"""
	if not is_ultimate_active:
		return
	
	is_ultimate_active = false
	ultimate_attacks_remaining = 0
	ultimate_deactivated.emit()

func get_energy_percentage() -> float:
	if max_energy == 0:
		return 0.0
	return float(current_energy) / float(max_energy)

func is_ultimate_mode_active() -> bool:
	return is_ultimate_active

func get_ultimate_attacks_remaining() -> int:
	return ultimate_attacks_remaining

# ==================== RESET/INITIALIZATION ====================

func reset_health():
	current_health = max_health
	health_changed.emit(current_health, max_health)

func reset_all():
	current_health = 100
	max_health = 100
	current_energy = 0
	is_ultimate_active = false
	ultimate_attacks_remaining = 0
	health_changed.emit(current_health, max_health)
	energy_changed.emit(current_energy, max_energy)

# ==================== UTILITY FUNCTIONS ====================

func get_health_display_text() -> String:
	return "Health: %d/%d" % [current_health, max_health]

func get_energy_display_text() -> String:
	if is_ultimate_active:
		return "ULTIMATE: %d hits left!" % ultimate_attacks_remaining
	else:
		return "Energy: %d/%d" % [current_energy, max_energy]
