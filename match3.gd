extends Node2D

var click_sound_player = AudioStreamPlayer.new()
var collect_sound_player = AudioStreamPlayer.new()
var match_start = AudioStreamPlayer.new()
var sparkle_sound_player = AudioStreamPlayer.new()
var swap_fail_sound = AudioStreamPlayer.new()


# Grid settings
const GRID_WIDTH = 9
const GRID_HEIGHT = 9
const TILE_SIZE = 300  
const TILE_SPACING = 2
const SCALE_FACTOR = 0.5
const GRID_OFFSET_X = 2174
const GRID_OFFSET_Y = 397

# Token types
enum TokenType {
	ROCK = -1,
	GINGER = 0,
	GARLIC = 1,
	MINT = 2
}

# Collected tokens
var collected_tokens = []

# 2D arrays
var grid = []
var tile_sprites = []

# Textures
var tile_bg_texture: Texture2D

# Selection
var selected_tile = null
var is_swapping = false

# Camera reference
var camera: Camera2D

# Score
var score = 0

# Potions
var pick_potions = 0
const MAX_POTIONS = 3
const POTION_CIRCLE_POSITIONS = [
	Vector2(300, 1080),
	Vector2(800, 1080),
	Vector2(1300, 1080)
]
var potion_sprites_in_circles = []

# Cascade protection
var cascade_depth = 0
const MAX_CASCADE_DEPTH = 10

# Preloaded scenes and classes
var token_scene = preload("res://token.tscn")
var pink_potion_scene = preload("res://pink_potion.tscn")
var match_detector = MatchDetector.new()
var grid_refiller = GridRefiller.new()

func _ready():
	

	
	click_sound_player.stream = load("res://assets/Audio Pack/click.mp3")
	add_child(click_sound_player)
	
	collect_sound_player.stream = load("res://assets/Audio Pack/collect.wav")
	add_child(collect_sound_player)
	
	match_start.stream = load("res://assets/Audio Pack/match_start.wav")
	add_child(match_start)
	
	sparkle_sound_player.stream = load("res://assets/Audio Pack/sparkle.wav")
	add_child(sparkle_sound_player)
	
	swap_fail_sound.stream = load("res://assets/Audio Pack/swap_fail_sound.wav")
	add_child(swap_fail_sound)
	
	camera = get_viewport().get_camera_2d()
	
	load_textures()
	initialize_collected_tokens()
	initialize_potion_circles()
	create_grid_with_tokens()

func load_textures():
	tile_bg_texture = load("res://assets/tile_bg.png")

func initialize_collected_tokens():
	collected_tokens = Inventory.get_collected_tokens()  

func initialize_potion_circles():
	potion_sprites_in_circles.clear()
	for i in range(MAX_POTIONS):
		potion_sprites_in_circles.append(null)

func create_grid_with_tokens():
	grid = []
	tile_sprites = []
	for x in range(GRID_WIDTH):
		grid.append([])
		tile_sprites.append([])
		for y in range(GRID_HEIGHT):
			grid[x].append(null)
			tile_sprites[x].append(null)
	
	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			var token_type = grid_refiller.get_valid_token(grid, x, y, collected_tokens, GRID_WIDTH, GRID_HEIGHT)
			grid[x][y] = token_type
			var pos = get_tile_position(x, y)
			create_background_tile(pos)
			create_token_sprite(x, y, token_type, pos)
			if match_start:
				match_start.play()

func get_tile_position(x: int, y: int) -> Vector2:
	var effective_tile_size = TILE_SIZE * SCALE_FACTOR
	var spacing_offset_x = x * TILE_SPACING
	var spacing_offset_y = y * TILE_SPACING
	return Vector2(
		GRID_OFFSET_X + x * effective_tile_size + spacing_offset_x + effective_tile_size / 2,
		GRID_OFFSET_Y + y * effective_tile_size + spacing_offset_y + effective_tile_size / 2
	)

func create_background_tile(pos: Vector2):
	var bg_tile = Sprite2D.new()
	bg_tile.texture = tile_bg_texture
	bg_tile.centered = true
	bg_tile.scale = Vector2(SCALE_FACTOR, SCALE_FACTOR)
	bg_tile.position = pos
	bg_tile.z_index = 0
	add_child(bg_tile)

func create_token_sprite(x: int, y: int, token_type: int, pos: Vector2):
	var token = token_scene.instantiate()
	token.initialize(token_type, pos, x, y)
	add_child(token)
	tile_sprites[x][y] = token

func _input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if is_swapping:
			return
		
		var world_pos = get_world_position_from_mouse(event.position)
		var grid_pos = get_grid_position_from_world(world_pos)
		
		if grid_pos != null:
			handle_tile_click(int(grid_pos.x), int(grid_pos.y))

func get_world_position_from_mouse(screen_pos: Vector2) -> Vector2:
	if camera:
		var zoom = camera.zoom
		var cam_pos = camera.get_screen_center_position()
		var viewport_size = get_viewport().get_visible_rect().size
		var world_pos = (screen_pos - viewport_size / 2) / zoom + cam_pos
		return world_pos
	else:
		return screen_pos

func get_grid_position_from_world(world_pos: Vector2):
	var effective_tile_size = TILE_SIZE * SCALE_FACTOR
	var local_x = world_pos.x - GRID_OFFSET_X
	var local_y = world_pos.y - GRID_OFFSET_Y
	var tile_with_spacing = effective_tile_size + TILE_SPACING
	var grid_x = int(local_x / tile_with_spacing)
	var grid_y = int(local_y / tile_with_spacing)
	
	if grid_x >= 0 and grid_x < GRID_WIDTH and grid_y >= 0 and grid_y < GRID_HEIGHT:
		var tile_local_x = local_x - (grid_x * tile_with_spacing)
		var tile_local_y = local_y - (grid_y * tile_with_spacing)
		if tile_local_x >= 0 and tile_local_x < effective_tile_size and tile_local_y >= 0 and tile_local_y < effective_tile_size:
			return Vector2(grid_x, grid_y)
	return null

func handle_tile_click(x: int, y: int):
	if selected_tile == null:
		select_tile(x, y)
	else:
		if selected_tile.x == x and selected_tile.y == y:
			deselect_tile()
		elif are_adjacent(selected_tile.x, selected_tile.y, x, y):
			swap_tiles(selected_tile.x, selected_tile.y, x, y)
		else:
			deselect_tile()
			select_tile(x, y)

func select_tile(x: int, y: int):
	selected_tile = {"x": x, "y": y}
	tile_sprites[x][y].highlight()
	if click_sound_player:
		click_sound_player.play()

func deselect_tile():
	if selected_tile:
		tile_sprites[selected_tile.x][selected_tile.y].unhighlight()
		selected_tile = null

func are_adjacent(x1: int, y1: int, x2: int, y2: int) -> bool:
	var dx = abs(x1 - x2)
	var dy = abs(y1 - y2)
	return (dx == 1 and dy == 0) or (dx == 0 and dy == 1)

func swap_tiles(x1: int, y1: int, x2: int, y2: int):
	is_swapping = true
	deselect_tile()
	cascade_depth = 0
	
	# Perform the swap
	var temp = grid[x1][y1]
	grid[x1][y1] = grid[x2][y2]
	grid[x2][y2] = temp
	
	var temp_sprite = tile_sprites[x1][y1]
	tile_sprites[x1][y1] = tile_sprites[x2][y2]
	tile_sprites[x2][y2] = temp_sprite
	
	# Animate the swap
	await animate_swap(x1, y1, x2, y2)
	if swap_fail_sound:
		swap_fail_sound.play()
	
	# Check if this swap created a match
	var has_match = match_detector.check_match_at_position(grid, x1, y1, GRID_WIDTH, GRID_HEIGHT) or match_detector.check_match_at_position(grid, x2, y2, GRID_WIDTH, GRID_HEIGHT)
	
	if not has_match:
		# Swap back in the grid
		var temp2 = grid[x1][y1]
		grid[x1][y1] = grid[x2][y2]
		grid[x2][y2] = temp2
		
		var temp_sprite2 = tile_sprites[x1][y1]
		tile_sprites[x1][y1] = tile_sprites[x2][y2]
		tile_sprites[x2][y2] = temp_sprite2
		
		# Animate back to original positions
		await animate_swap(x1, y1, x2, y2)
		is_swapping = false
		return
	
	# Valid match - process matches
	await process_all_matches()
	is_swapping = false

func animate_swap(x1: int, y1: int, x2: int, y2: int):
	var pos1 = get_tile_position(x1, y1)
	var pos2 = get_tile_position(x2, y2)
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(tile_sprites[x1][y1], "position", pos1, 0.3)
	tween.tween_property(tile_sprites[x2][y2], "position", pos2, 0.3)
	
	await tween.finished

func process_all_matches():
	var matches = match_detector.find_all_matches(grid, GRID_WIDTH, GRID_HEIGHT)
	
	if matches.size() == 0:
		cascade_depth = 0
		return
	
	# Safety check: prevent infinite loops
	cascade_depth += 1
	if cascade_depth > MAX_CASCADE_DEPTH:
		cascade_depth = 0
		is_swapping = false
		return
	
	# Check for garlic matches and award pick potions
	var garlic_matches = match_detector.check_for_garlic_matches(matches, grid, GRID_WIDTH, GRID_HEIGHT)
	if garlic_matches > 0:
		var potions_before = pick_potions
		pick_potions += garlic_matches
		
		# Cap at max potions
		if pick_potions > MAX_POTIONS:
			pick_potions = MAX_POTIONS
		
		# Spawn pink potion visual for each new potion (up to max)
		for i in range(potions_before, pick_potions):
			spawn_pink_potion_in_circle(i)
		
		# Check if player won
		if pick_potions >= MAX_POTIONS:
			cascade_depth = 0
			await get_tree().create_timer(2.0).timeout
			#game_won()
			return
	
	# Add to score
	var points = matches.size() * 10
	score += points
	
	# Animate and remove matched tokens
	await animate_matches(matches)
	
	# Remove the matched tokens from grid
	for match_pos in matches:
		grid[match_pos.x][match_pos.y] = TokenType.ROCK
		if tile_sprites[match_pos.x][match_pos.y]:
			tile_sprites[match_pos.x][match_pos.y].queue_free()
			tile_sprites[match_pos.x][match_pos.y] = null
	
	# Wait a moment before refilling
	await get_tree().create_timer(0.2).timeout
	
	# Refill the grid with new tokens
	for match_pos in matches:
		var new_token = grid_refiller.get_valid_refill_token(grid, match_pos.x, match_pos.y, collected_tokens, GRID_WIDTH, GRID_HEIGHT)
		grid[match_pos.x][match_pos.y] = new_token
		var pos = get_tile_position(match_pos.x, match_pos.y)
		create_token_sprite(match_pos.x, match_pos.y, new_token, pos)
	
	# Check for cascade matches
	await get_tree().create_timer(0.1).timeout
	await process_all_matches()

func animate_matches(matches: Array):
	var tween = create_tween()
	tween.set_parallel(true)
	
	for match_pos in matches:
		var sprite = tile_sprites[match_pos.x][match_pos.y]
		if sprite:
			tween.tween_property(sprite, "scale", Vector2.ZERO, 0.3)
			tween.tween_property(sprite, "modulate:a", 0.0, 0.3)
			if sparkle_sound_player:
				sparkle_sound_player.play()
	
	await tween.finished

func spawn_pink_potion_in_circle(circle_index: int):
	if circle_index >= MAX_POTIONS:
		return
	
	var start_x = GRID_OFFSET_X + (GRID_WIDTH * TILE_SIZE * SCALE_FACTOR) / 2
	var start_y = GRID_OFFSET_Y + (GRID_HEIGHT * TILE_SIZE * SCALE_FACTOR) / 2
	
	var potion = pink_potion_scene.instantiate()
	add_child(potion)
	potion.initialize(Vector2(start_x, start_y))
	await potion.animate_to_circle(POTION_CIRCLE_POSITIONS[circle_index])
	if collect_sound_player:
		collect_sound_player.play()
	
	while potion_sprites_in_circles.size() <= circle_index:
		potion_sprites_in_circles.append(null)
	potion_sprites_in_circles[circle_index] = potion

#func game_won():
	#
	#is_swapping = true
	#
	#for i in range(MAX_POTIONS):
		#if potion_sprites_in_circles[i]:
			#potion_sprites_in_circles[i].pulse_forever()
			#
