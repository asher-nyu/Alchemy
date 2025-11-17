extends Node

# Player health management
var max_health: int = 100
var current_health: int = 100

# Potion properties
const HEALTH_POTION_HEAL_AMOUNT: int = 10
const POTION_USE_COOLDOWN: float = 0.3

# Green potion (strength) properties
const STRENGTH_DURATION: float = 5.0  # 10 seconds of strength
const STRENGTH_MULTIPLIER: float = 2.0  # 2x damage
var is_strength_active: bool = false
var strength_timer: Timer = null

# Cooldown tracking
var can_use_potion: bool = true
var cooldown_timer: Timer = null

# Signals for UI updates
signal health_changed(current: int, maximum: int)
signal potion_used(potions_remaining: int)
signal potion_count_changed(new_count: int)
signal player_died()
signal strength_activated(duration: float)
signal strength_deactivated()

func _ready():
	# Create cooldown timer
	cooldown_timer = Timer.new()
	cooldown_timer.one_shot = true
	cooldown_timer.wait_time = POTION_USE_COOLDOWN
	cooldown_timer.timeout.connect(_on_cooldown_finished)
	add_child(cooldown_timer)
	
	# Create strength timer
	strength_timer = Timer.new()
	strength_timer.one_shot = true
	strength_timer.wait_time = STRENGTH_DURATION
	strength_timer.timeout.connect(_on_strength_finished)
	add_child(strength_timer)
	
	# Connect to Inventory signals if they exist
	if Inventory.has_signal("potions_changed"):
		Inventory.potions_changed.connect(_on_inventory_potions_changed)
	
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
	current_health = min(max_health, current_health + amount)
	health_changed.emit(current_health, max_health)

func is_at_full_health() -> bool:
	return current_health >= max_health

func get_health_percentage() -> float:
	if max_health == 0:
		return 0.0
	return float(current_health) / float(max_health)

# ==================== POTION USAGE ====================

func use_health_potion() -> bool:
	# Check if we can use a potion
	if not can_use_potion:
		return false
	
	# Check if player is already at full health
	if is_at_full_health():
		print("PotionManager: Already at full health!")
		return false
	
	# Check if we have potions in inventory
	var potion_count = Inventory.get_health_potions()
	if potion_count <= 0:
		print("PotionManager: No potions available!")
		return false
	
	# Consume potion from inventory
	if not Inventory.use_health_potion():
		print("PotionManager: Failed to consume potion from inventory!")
		return false
	
	# Heal the player
	heal(HEALTH_POTION_HEAL_AMOUNT)
	
	# Start cooldown
	start_cooldown()
	
	# Emit signal
	var remaining = Inventory.get_health_potions()
	potion_used.emit(remaining)
	
	
	return true

func use_potion_from_slot(slot_number: int) -> bool:
	if not can_use_potion:
		print("PotionManager: Potion on cooldown!")
		return false
	
	# Get the potion type in this slot
	var potion_type = Inventory.get_potion_in_slot(slot_number)
	if potion_type == -1:
		print("PotionManager: No potion in slot %d" % slot_number)
		return false
	
	# Check potion type and apply effect
	match potion_type:
		Inventory.PotionType.PINK:
			return use_pink_potion(slot_number)
		Inventory.PotionType.GREEN:
			return use_green_potion(slot_number)
		Inventory.PotionType.BLUE:
			return use_blue_potion(slot_number)
		_:
			print("PotionManager: Unknown potion type!")
			return false

func use_pink_potion(slot_index: int) -> bool:
	if is_at_full_health():
		print("PotionManager: Already at full health!")
		return false
	
	# Consume potion from inventory
	if not Inventory.use_potion_from_slot(slot_index):
		print("PotionManager: Failed to consume pink potion from inventory!")
		return false
	
	# Heal the player
	heal(HEALTH_POTION_HEAL_AMOUNT)
	
	# Start cooldown
	start_cooldown()
	
	# Emit signal
	var remaining = Inventory.get_health_potions()
	potion_used.emit(remaining)
	
	print("PotionManager: Used pink potion! Healed for %d HP. Potions remaining: %d" % [HEALTH_POTION_HEAL_AMOUNT, remaining])
	
	return true

func use_green_potion(slot_index: int) -> bool:
	# Check if strength is already active
	if is_strength_active:
		print("PotionManager: Strength already active!")
		return false
	
	# Consume potion from inventory
	if not Inventory.use_potion_from_slot(slot_index):
		print("PotionManager: Failed to consume green potion from inventory!")
		return false
	
	# Activate strength buff
	activate_strength()
	
	# Start cooldown
	start_cooldown()
	
	# Emit signal
	var remaining = Inventory.get_health_potions()
	potion_used.emit(remaining)
	return true

func use_blue_potion(slot_index: int) -> bool:
	print("PotionManager: not yet")
	return false

# ==================== COOLDOWN MANAGEMENT ====================

func start_cooldown():
	can_use_potion = false
	cooldown_timer.start()

func _on_cooldown_finished():
	can_use_potion = true

func is_potion_ready() -> bool:
	return can_use_potion

func get_cooldown_remaining() -> float:
	if cooldown_timer.is_stopped():
		return 0.0
	return cooldown_timer.time_left

# ==================== INVENTORY INTEGRATION ====================

func _on_inventory_potions_changed(new_count: int):
	potion_count_changed.emit(new_count)

func get_potion_count() -> int:
	return Inventory.get_health_potions()

# ==================== RESET/INITIALIZATION ====================

func reset_health():
	current_health = max_health
	health_changed.emit(current_health, max_health)

func reset_all():
	current_health = max_health
	can_use_potion = true
	is_strength_active = false
	if cooldown_timer and not cooldown_timer.is_stopped():
		cooldown_timer.stop()
	if strength_timer and not strength_timer.is_stopped():
		strength_timer.stop()
	health_changed.emit(current_health, max_health)

# ==================== UTILITY FUNCTIONS ====================

func get_health_display_text() -> String:
	return "HP: %d/%d" % [current_health, max_health]

func get_potion_display_text() -> String:
	return "Potions: %d" % get_potion_count()

func get_strength_display_text() -> String:
	if is_strength_active:
		return "💪 STRENGTH: %.1fs" % get_strength_time_remaining()
	return ""

# ==================== STRENGTH BUFF SYSTEM ====================

func activate_strength():
	is_strength_active = true
	strength_timer.start()
	strength_activated.emit(STRENGTH_DURATION)
	print("PotionManager: Strength buff activated! Damage multiplier: %.1fx" % STRENGTH_MULTIPLIER)

func _on_strength_finished():
	is_strength_active = false
	strength_deactivated.emit()

func is_strength_buff_active() -> bool:
	return is_strength_active

func get_damage_multiplier() -> float:
	if is_strength_active:
		return STRENGTH_MULTIPLIER
	return 1.0

func get_strength_time_remaining() -> float:
	if strength_timer.is_stopped():
		return 0.0
	return strength_timer.time_left
