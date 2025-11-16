extends Control

var slot1_icon = null
var slot2_icon = null
var slot3_icon = null

var potion_texture: Texture2D

func _ready():
	visible = true
	modulate = Color(1, 1, 1, 1)
	z_index = 1000
	
	slot1_icon = get_node_or_null("HBoxContainer/Slot1/PotionIcon")
	slot2_icon = get_node_or_null("HBoxContainer/Slot2/PotionIcon")
	slot3_icon = get_node_or_null("HBoxContainer/Slot3/PotionIcon")
	
	if ResourceLoader.exists("res://assets/pink_potion.png"):
		potion_texture = load("res://assets/pink_potion.png")
	
	if slot1_icon:
		slot1_icon.texture = potion_texture
		slot1_icon.modulate = Color(1, 1, 1, 1)
	if slot2_icon:
		slot2_icon.texture = potion_texture
		slot2_icon.modulate = Color(1, 1, 1, 1)
	if slot3_icon:
		slot3_icon.texture = potion_texture
		slot3_icon.modulate = Color(1, 1, 1, 1)
	
	update_inventory_display()
	
	if Inventory:
		Inventory.potions_changed.connect(_on_potions_changed)

func _process(_delta):
	if not visible:
		visible = true

func _on_potions_changed(new_count):
	update_inventory_display()

func update_inventory_display():
	var potion_count = Inventory.get_health_potions()
	
	if slot1_icon:
		if potion_count >= 1:
			slot1_icon.visible = true
			if potion_texture:
				slot1_icon.texture = potion_texture
		else:
			slot1_icon.visible = false
	
	if slot2_icon:
		if potion_count >= 2:
			slot2_icon.visible = true
			if potion_texture:
				slot2_icon.texture = potion_texture
		else:
			slot2_icon.visible = false
	
	if slot3_icon:
		if potion_count >= 3:
			slot3_icon.visible = true
			if potion_texture:
				slot3_icon.texture = potion_texture
		else:
			slot3_icon.visible = false
