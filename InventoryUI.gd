extends Control

var slot1_icon = null
var slot2_icon = null
var slot3_icon = null

var potion_texture: Texture2D

func _ready():
	print("========================================")
	print("InventoryUI: _ready() CALLED!")
	print("InventoryUI: visible = ", visible)
	print("InventoryUI: modulate = ", modulate)
	print("InventoryUI: global_position = ", global_position)
	print("InventoryUI: size = ", size)
	
	# Make absolutely sure we're visible
	visible = true
	modulate = Color(1, 1, 1, 1)
	z_index = 1000
	
	# Try to find slot icons if they exist
	slot1_icon = get_node_or_null("HBoxContainer/Slot1/PotionIcon")
	slot2_icon = get_node_or_null("HBoxContainer/Slot2/PotionIcon")
	slot3_icon = get_node_or_null("HBoxContainer/Slot3/PotionIcon")
	
	print("InventoryUI: slot1_icon = ", slot1_icon)
	print("InventoryUI: slot2_icon = ", slot2_icon)
	print("InventoryUI: slot3_icon = ", slot3_icon)
	
	# Load potion texture
	if ResourceLoader.exists("res://assets/pink_potion.png"):
		potion_texture = load("res://assets/pink_potion.png")
		print("InventoryUI: Potion texture loaded successfully!")
	else:
		print("InventoryUI: ERROR - Could not find pink_potion.png!")
	
	# Configure icons with texture
	if slot1_icon:
		slot1_icon.texture = potion_texture
		slot1_icon.modulate = Color(1, 1, 1, 1)
		print("InventoryUI: slot1_icon configured")
	if slot2_icon:
		slot2_icon.texture = potion_texture
		slot2_icon.modulate = Color(1, 1, 1, 1)
		print("InventoryUI: slot2_icon configured")
	if slot3_icon:
		slot3_icon.texture = potion_texture
		slot3_icon.modulate = Color(1, 1, 1, 1)
		print("InventoryUI: slot3_icon configured")
	
	# Initialize inventory display
	update_inventory_display()
	print("InventoryUI: Inventory initialized with %d potions" % Inventory.get_health_potions())
	print("========================================")
	
	# Connect to inventory changes
	if Inventory:
		Inventory.potions_changed.connect(_on_potions_changed)

func _process(_delta):
	# Debug: continuously check visibility
	if not visible:
		print("WARNING: InventoryUI became invisible!")
		visible = true

func _on_potions_changed(new_count):
	update_inventory_display()

func update_inventory_display():
	var potion_count = Inventory.get_health_potions()
	print("InventoryUI: Updating display - %d potions" % potion_count)
	
	# Update slot 1 (only if it exists)
	if slot1_icon:
		if potion_count >= 1:
			slot1_icon.visible = true
			if potion_texture:
				slot1_icon.texture = potion_texture
			print("  Slot 1: VISIBLE")
		else:
			slot1_icon.visible = false
			print("  Slot 1: hidden")
	
	# Update slot 2 (only if it exists)
	if slot2_icon:
		if potion_count >= 2:
			slot2_icon.visible = true
			if potion_texture:
				slot2_icon.texture = potion_texture
			print("  Slot 2: VISIBLE")
		else:
			slot2_icon.visible = false
			print("  Slot 2: hidden")
	
	# Update slot 3 (only if it exists)
	if slot3_icon:
		if potion_count >= 3:
			slot3_icon.visible = true
			if potion_texture:
				slot3_icon.texture = potion_texture
			print("  Slot 3: VISIBLE")
		else:
			slot3_icon.visible = false
			print("  Slot 3: hidden")
