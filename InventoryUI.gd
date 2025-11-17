extends Control

var slot1_icon = null
var slot2_icon = null
var slot3_icon = null

var pink_potion_texture: Texture2D
var green_potion_texture: Texture2D
var blue_potion_texture: Texture2D

func _ready():
	visible = true
	modulate = Color(1, 1, 1, 1)
	z_index = 1000
	
	slot1_icon = get_node_or_null("HBoxContainer/Slot1/PotionIcon")
	slot2_icon = get_node_or_null("HBoxContainer/Slot2/PotionIcon")
	slot3_icon = get_node_or_null("HBoxContainer/Slot3/PotionIcon")

	
	if ResourceLoader.exists("res://assets/pink_potion.png"):
		pink_potion_texture = load("res://assets/pink_potion.png")
		print("InventoryUI: Pink potion texture loaded!")
	else:
		print("InventoryUI: ERROR - Could not find pink_potion.png!")
	
	if ResourceLoader.exists("res://assets/green_potion.png"):
		green_potion_texture = load("res://assets/green_potion.png")
		print("InventoryUI: Green potion texture loaded!")
	else:
		print("InventoryUI: ERROR - Could not find green_potion.png!")
	
	if ResourceLoader.exists("res://assets/blue_potion.png"):
		blue_potion_texture = load("res://assets/blue_potion.png")
		print("InventoryUI: Blue potion texture loaded!")
	else:
		print("InventoryUI: Warning - Could not find blue_potion.png!")
	
	# Initialize inventory display
	update_inventory_display()
	print("InventoryUI: Inventory initialized with %d potions" % Inventory.get_health_potions())
	print("========================================")
	
	# Connect to inventory changes
	if Inventory:
		Inventory.potions_changed.connect(_on_potions_changed)

func _process(_delta):
	if not visible:
		print("WARNING: InventoryUI became invisible!")
		visible = true

func _on_potions_changed(new_count):
	update_inventory_display()

func get_potion_texture(potion_type: int) -> Texture2D:
	match potion_type:
		Inventory.PotionType.PINK:
			return pink_potion_texture
		Inventory.PotionType.GREEN:
			return green_potion_texture
		Inventory.PotionType.BLUE:
			return blue_potion_texture
		_:
			return pink_potion_texture  # Default fallback

func update_inventory_display():
	var potion_slots = Inventory.get_potion_slots()
	print("InventoryUI: Updating display - %d potions" % potion_slots.size())
	
	# Update slot 1
	if slot1_icon:
		if potion_slots.size() >= 1:
			var potion_type = potion_slots[0]
			var texture = get_potion_texture(potion_type)
			slot1_icon.visible = true
			slot1_icon.texture = texture
			print("  Slot 1: VISIBLE - %s potion" % Inventory.get_potion_type_name(potion_type))
		else:
			slot1_icon.visible = false
			print("  Slot 1: hidden")
	
	# Update slot 2
	if slot2_icon:
		if potion_slots.size() >= 2:
			var potion_type = potion_slots[1]
			var texture = get_potion_texture(potion_type)
			slot2_icon.visible = true
			slot2_icon.texture = texture
			print("  Slot 2: VISIBLE - %s potion" % Inventory.get_potion_type_name(potion_type))
		else:
			slot2_icon.visible = false
			print("  Slot 2: hidden")
	
	# Update slot 3
	if slot3_icon:
		if potion_slots.size() >= 3:
			var potion_type = potion_slots[2]
			var texture = get_potion_texture(potion_type)
			slot3_icon.visible = true
			slot3_icon.texture = texture
			print("  Slot 3: VISIBLE - %s potion" % Inventory.get_potion_type_name(potion_type))
		else:
			slot3_icon.visible = false
			print("  Slot 3: hidden")
