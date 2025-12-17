

extends Node2D

var click_sound_player = AudioStreamPlayer.new()
var collect_sound_player = AudioStreamPlayer.new()
var match_start = AudioStreamPlayer.new()
var sparkle_sound_player = AudioStreamPlayer.new()
var swap_fail_sound = AudioStreamPlayer.new()
var custom_font := load("Alchemy.otf") as FontFile
var transition_started := false

# Grid settings
const GRID_WIDTH = 9
const GRID_HEIGHT = 9
const TILE_SIZE = 300  
const TILE_SPACING = 2
const SCALE_FACTOR = 0.5
var GRID_OFFSET_X: float = 0.0
var GRID_OFFSET_Y: float = 0.0

# Token types
enum TokenType {
	ROCK = -1,
	GINGER = 0,
	GARLIC = 1,
	MINT = 2,
	PEPPER = 3
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

# Move limit
var moves_made = 0
const BASE_MOVES = 5
var bonus_moves = 0  # Bonus moves from killing enemies
var max_moves = BASE_MOVES  # Total moves available

# Cascade protection
var cascade_depth = 0
const MAX_CASCADE_DEPTH = 10

# UI for moves
var moves_label: Label = null

var token_scene = preload("res://token.tscn")
var match_detector = MatchDetector.new()
var grid_refiller = GridRefiller.new()

# Game state
var game_ended = false

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
	
	# Calculate grid position based on camera center
	var effective_tile_size = TILE_SIZE * SCALE_FACTOR
	var tile_pitch = effective_tile_size + TILE_SPACING

	var grid_width = (GRID_WIDTH - 1) * tile_pitch + effective_tile_size
	var grid_height = (GRID_HEIGHT - 1) * tile_pitch + effective_tile_size

	var center = camera.get_screen_center_position()  # world coords of screen center
	GRID_OFFSET_X = center.x - grid_width / 2.0
	GRID_OFFSET_Y = center.y - grid_height / 2.0
	
	# Get bonus moves from enemies killed
	if has_node("/root/LevelManager"):
		bonus_moves = LevelManager.get_bonus_moves()
		max_moves = BASE_MOVES + bonus_moves
	else:
		max_moves = BASE_MOVES
	
	load_textures()
	initialize_collected_tokens()
	create_moves_ui(center)
	create_grid_with_tokens()

func load_textures():
	tile_bg_texture = load("res://assets/tile_bg.png")

func initialize_collected_tokens():
	collected_tokens = Inventory.get_collected_tokens()

func create_moves_ui(screen_center: Vector2):
	moves_label = Label.new()
	moves_label.name = "MovesLabel"
	moves_label.add_theme_font_override("font", custom_font)
	
	moves_label.add_theme_font_size_override("font_size", 72)
	moves_label.add_theme_color_override("font_color", Color.YELLOW)
	moves_label.z_index = 1000
		
	add_child(moves_label)
	update_moves_display()
	
	var label_x := GRID_OFFSET_X + 10
	var label_y := GRID_OFFSET_Y - 150.0
	moves_label.global_position = Vector2(label_x, label_y)

func update_moves_display():
	if moves_label:
		var remaining = max_moves - moves_made
		
		# Show bonus moves if any
		if bonus_moves > 0:
			moves_label.text = "Moves: %d/%d (+%d bonus)" % [remaining, max_moves, bonus_moves]
		else:
			moves_label.text = "Moves: %d/%d" % [remaining, max_moves]
		
		# Change color based on remaining moves
		if remaining <= 1:
			moves_label.add_theme_color_override("font_color", Color.RED)
		elif remaining <= 2:
			moves_label.add_theme_color_override("font_color", Color.ORANGE)
		else:
			moves_label.add_theme_color_override("font_color", Color.YELLOW)

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
	
	if game_ended or moves_made >= max_moves:
		return
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
	
	# Valid match - increment moves counter
	moves_made += 1
	update_moves_display()
	
	if moves_made >= max_moves:
		is_swapping = true  # keep locked

		await process_all_matches()
		await get_tree().create_timer(1.5).timeout
		end_game_and_transition()
		return
	
	# Process matches normally
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

func show_floating_text(text: String, color: Color, positions: Array):
	"""Show floating text at the average position of the matched tiles"""
	if positions.size() == 0:
		return
	
	# Calculate center position of the match
	var avg_x = 0.0
	var avg_y = 0.0
	for pos in positions:
		avg_x += pos.x
		avg_y += pos.y
	avg_x /= positions.size()
	avg_y /= positions.size()
	
	var world_pos = get_tile_position(int(avg_x), int(avg_y))
	
	# Create floating label
	var label = Label.new()
	label.text = text
	label.position = world_pos
	label.add_theme_font_override("font", custom_font)
	label.add_theme_font_size_override("font_size", 80)
	label.add_theme_color_override("font_color", color)
	label.z_index = 500
	
	# Add outline for better visibility
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 8)
	
	add_child(label)
	
	# Animate the text floating up and fading out
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", world_pos.y - 200, 1.5).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 1.5).set_delay(0.5)
	tween.tween_property(label, "scale", Vector2(1.3, 1.3), 0.3).set_ease(Tween.EASE_OUT)
	
	await tween.finished
	label.queue_free()

func process_all_matches():
	var matches = match_detector.find_all_matches(grid, GRID_WIDTH, GRID_HEIGHT)
	
	if matches.size() == 0:
		cascade_depth = 0
		return
	
	cascade_depth += 1
	if cascade_depth > MAX_CASCADE_DEPTH:
		cascade_depth = 0
		if not transition_started:
			is_swapping = false
		return
	
	# Get match groups with their sizes and types
	var match_groups = match_detector.get_match_groups(matches, grid, GRID_WIDTH, GRID_HEIGHT)
	
	# Apply stat bonuses based on match type and size
	for group in match_groups:
		var token_type = group["type"]
		var match_size = group["size"]
		var health_bonus = 0
		var damage_bonus = 0
		
		match token_type:
			TokenType.GARLIC:
				# Garlic increases health: 3-match = +10, 4-match = +20, 5+ = +30
				if match_size == 3:
					health_bonus = 10
				elif match_size == 4:
					health_bonus = 20
				elif match_size >= 5:
					health_bonus = 30
				
				if health_bonus > 0:
					PotionManager.heal(health_bonus)
					show_floating_text("+%d HP" % health_bonus, Color.GREEN, group["positions"])
			
			TokenType.MINT:
				# Mint increases max health: 3-match = +5, 4-match = +10, 5+ = +15
				if match_size == 3:
					health_bonus = 5
				elif match_size == 4:
					health_bonus = 10
				elif match_size >= 5:
					health_bonus = 15
				
				if health_bonus > 0:
					var new_max = PotionManager.get_max_health() + health_bonus
					PotionManager.set_max_health(new_max)
					show_floating_text("+%d MAX HP" % health_bonus, Color.CYAN, group["positions"])
			
			TokenType.GINGER:
				# Ginger increases base attack damage: 3-match = +2, 4-match = +5, 5+ = +8
				if match_size == 3:
					damage_bonus = 2
				elif match_size == 4:
					damage_bonus = 5
				elif match_size >= 5:
					damage_bonus = 8
				
				if damage_bonus > 0:
					var player = get_tree().get_first_node_in_group("Player")
					if player and player.has_method("increase_damage"):
						player.increase_damage(damage_bonus)
						show_floating_text("+%d ATK" % damage_bonus, Color.ORANGE_RED, group["positions"])
			
			TokenType.PEPPER:
				# Pepper increases both energy and max health: 3-match = +10 energy +5 max HP, 4-match = +20 energy +10 max HP, 5+ = +30 energy +15 max HP
				var energy_bonus = 0
				if match_size == 3:
					energy_bonus = 10
					health_bonus = 5
				elif match_size == 4:
					energy_bonus = 20
					health_bonus = 10
				elif match_size >= 5:
					energy_bonus = 30
					health_bonus = 15
				
				if energy_bonus > 0 or health_bonus > 0:
					# Add energy
					if energy_bonus > 0:
						PotionManager.add_energy(energy_bonus)
					
					# Increase max health
					if health_bonus > 0:
						var new_max = PotionManager.get_max_health() + health_bonus
						PotionManager.set_max_health(new_max)
					
					show_floating_text("+%d ENERGY +%d MAX HP" % [energy_bonus, health_bonus], Color.RED, group["positions"])
	
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
	
	# After processing all matches, check if there are any valid moves left
	if not game_ended and not has_valid_moves():
		await get_tree().create_timer(1.0).timeout
		end_game_and_transition()

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

func has_valid_moves() -> bool:
	# Check every position for possible swaps that would create a match
	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			# Try swapping with right neighbor
			if x < GRID_WIDTH - 1:
				# Simulate swap
				var temp = grid[x][y]
				grid[x][y] = grid[x + 1][y]
				grid[x + 1][y] = temp
				
				# Check for matches
				var has_match = match_detector.check_match_at_position(grid, x, y, GRID_WIDTH, GRID_HEIGHT) or \
								match_detector.check_match_at_position(grid, x + 1, y, GRID_WIDTH, GRID_HEIGHT)
				
				# Swap back
				temp = grid[x][y]
				grid[x][y] = grid[x + 1][y]
				grid[x + 1][y] = temp
				
				if has_match:
					return true
			
			# Try swapping with bottom neighbor
			if y < GRID_HEIGHT - 1:
				# Simulate swap
				var temp = grid[x][y]
				grid[x][y] = grid[x][y + 1]
				grid[x][y + 1] = temp
				
				# Check for matches
				var has_match = match_detector.check_match_at_position(grid, x, y, GRID_WIDTH, GRID_HEIGHT) or \
								match_detector.check_match_at_position(grid, x, y + 1, GRID_WIDTH, GRID_HEIGHT)
				
				# Swap back
				temp = grid[x][y]
				grid[x][y] = grid[x][y + 1]
				grid[x][y + 1] = temp
				
				if has_match:
					return true
	
	return false

func end_game_and_transition():
	if transition_started:
		return

	transition_started = true
	game_ended = true
	is_swapping = true

	if has_node("/root/LevelManager"):
		LevelManager.reset_enemy_kills()

	GlobalPuzzleData.puzzle_completed()
