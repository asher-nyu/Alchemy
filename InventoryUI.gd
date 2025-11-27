extends Control

# This UI is no longer used since potions have been removed.
# The inventory system now directly applies stat boosts from match-3 matches.
# This script is kept as a no-op to prevent errors from the player.tscn scene.

func _ready():
	# Hide the inventory UI since potions are removed
	visible = false
	print("InventoryUI: Hidden (potions system removed)")

func update_inventory_display():
	# No-op: Potions have been removed
	pass

func _on_potions_changed(_new_count):
	# No-op: Potions have been removed
	pass
