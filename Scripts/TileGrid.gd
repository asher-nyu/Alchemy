@tool
extends Node2D

@export var tile_texture: Texture2D:
	set(value):
		tile_texture = value
		if Engine.is_editor_hint() and is_inside_tree():
			call_deferred("generate_grid")

@export var grid_size: Vector2i = Vector2i(9, 9):
	set(value):
		grid_size = value
		if Engine.is_editor_hint() and is_inside_tree():
			call_deferred("generate_grid")

@export var cell_size: float = 60.0:
	set(value):
		cell_size = value
		if Engine.is_editor_hint() and is_inside_tree():
			call_deferred("generate_grid")

@export var grid_offset: Vector2 = Vector2(100, 100):
	set(value):
		grid_offset = value
		if Engine.is_editor_hint() and is_inside_tree():
			call_deferred("generate_grid")

@export var tile_scale: float = 0.22:
	set(value):
		tile_scale = value
		if Engine.is_editor_hint() and is_inside_tree():
			call_deferred("generate_grid")

@export var regenerate: bool = false:
	set(value):
		if value and is_inside_tree():
			generate_grid()

func _ready():
	generate_grid()

func generate_grid():
	print("TileGrid: generate_grid() called")
	print("TileGrid: Engine.is_editor_hint() = %s" % Engine.is_editor_hint())
	print("TileGrid: is_inside_tree() = %s" % is_inside_tree())
	
	if not tile_texture:
		print("TileGrid: ERROR - No tile texture assigned!")
		return
	
	print("TileGrid: Texture loaded: %s" % tile_texture)
	print("TileGrid: Texture size: %s" % tile_texture.get_size())
	
	# Clear any existing children
	var children_count = get_child_count()
	print("TileGrid: Clearing %d existing children" % children_count)
	for child in get_children():
		if Engine.is_editor_hint():
			child.queue_free()
		else:
			child.queue_free()
	
	print("TileGrid: Generating %dx%d grid with cell_size=%f at offset=%s, scale=%f" % [grid_size.x, grid_size.y, cell_size, grid_offset, tile_scale])
	
	# Generate grid of tiles
	var tile_count = 0
	for col in range(grid_size.x):
		for row in range(grid_size.y):
			var tile = Sprite2D.new()
			tile.texture = tile_texture
			tile.position = Vector2(
				grid_offset.x + (col * cell_size),
				grid_offset.y + (row * cell_size)
			)
			# Scale tiles to fit nicely in cells
			tile.scale = Vector2(tile_scale, tile_scale)
			tile.name = "Tile_%d_%d" % [col, row]
			tile.modulate = Color(1, 1, 1, 1)  # Ensure visible
			tile.visible = true
			tile.z_index = 0  # Same level as background, but added after so renders on top
			
			add_child(tile)
			
			# Set owner so tiles appear in editor
			if Engine.is_editor_hint() and get_tree():
				var root = get_tree().edited_scene_root
				if root:
					tile.owner = root
			
			tile_count += 1
			
			if tile_count <= 3:
				print("TileGrid: Created tile %d at position %s" % [tile_count, tile.position])
	
	print("TileGrid: Successfully created %d tiles" % tile_count)
	print("TileGrid: Current child count: %d" % get_child_count())
