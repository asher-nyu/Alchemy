class_name MatchDetector

enum TokenType {
	ROCK = -1,
	GINGER = 0,
	GARLIC = 1,
	MINT = 2
}

func check_match_at_position(grid: Array, x: int, y: int, width: int, height: int) -> bool:
	var token_type = grid[x][y]
	
	# Rocks and empty spaces can't match
	if token_type == TokenType.ROCK:
		return false
	
	# Check horizontal match
	var horizontal_count = 1
	# Check left
	var check_x = x - 1
	while check_x >= 0 and grid[check_x][y] == token_type:
		horizontal_count += 1
		check_x -= 1
	# Check right
	check_x = x + 1
	while check_x < width and grid[check_x][y] == token_type:
		horizontal_count += 1
		check_x += 1
	
	if horizontal_count >= 3:
		return true
	
	# Check vertical match
	var vertical_count = 1
	# Check up
	var check_y = y - 1
	while check_y >= 0 and grid[x][check_y] == token_type:
		vertical_count += 1
		check_y -= 1
	# Check down
	check_y = y + 1
	while check_y < height and grid[x][check_y] == token_type:
		vertical_count += 1
		check_y += 1
	
	if vertical_count >= 3:
		return true
	
	return false

func find_all_matches(grid: Array, width: int, height: int) -> Array:
	
	var matches = []
	
	# Check horizontal matches
	for y in range(height):
		for x in range(width - 2):
			var token_type = grid[x][y]
			if token_type != TokenType.ROCK:
				if grid[x + 1][y] == token_type and grid[x + 2][y] == token_type:
					# Found a horizontal match of at least 3
					matches.append(Vector2i(x, y))
					matches.append(Vector2i(x + 1, y))
					matches.append(Vector2i(x + 2, y))
					
					# Check if the match extends beyond 3
					var offset = 3
					while x + offset < width and grid[x + offset][y] == token_type:
						matches.append(Vector2i(x + offset, y))
						offset += 1
	
	# Check vertical matches
	for x in range(width):
		for y in range(height - 2):
			var token_type = grid[x][y]
			if token_type != TokenType.ROCK:
				if grid[x][y + 1] == token_type and grid[x][y + 2] == token_type:
					# Found a vertical match of at least 3
					matches.append(Vector2i(x, y))
					matches.append(Vector2i(x, y + 1))
					matches.append(Vector2i(x, y + 2))
					
					# Check if the match extends beyond 3
					var offset = 3
					while y + offset < height and grid[x][y + offset] == token_type:
						matches.append(Vector2i(x, y + offset))
						offset += 1
	
	# Remove duplicates
	return remove_duplicate_positions(matches)

func remove_duplicate_positions(positions: Array) -> Array:
	"""Remove duplicate Vector2i positions from array"""
	var unique = []
	for pos in positions:
		var found = false
		for existing in unique:
			if existing.x == pos.x and existing.y == pos.y:
				found = true
				break
		if not found:
			unique.append(pos)
	return unique

func check_for_garlic_matches(matches: Array, grid: Array, width: int, height: int) -> int:
	var garlic_match_count = 0
	var processed_positions = []
	
	# First, filter matches to only include garlic positions
	var garlic_matches = []
	for match_pos in matches:
		if grid[match_pos.x][match_pos.y] == TokenType.GARLIC:
			garlic_matches.append(match_pos)
	
	if garlic_matches.size() == 0:
		return 0
	
	# Check horizontal garlic groups
	for y in range(height):
		var consecutive = []
		for x in range(width):
			var pos = Vector2i(x, y)
			if is_position_in_array(pos, garlic_matches) and not is_position_in_array(pos, processed_positions):
				consecutive.append(pos)
			else:
				# End of consecutive run
				if consecutive.size() >= 3:
					garlic_match_count += 1
					for p in consecutive:
						processed_positions.append(p)
				consecutive = []
		
		# Check end of row
		if consecutive.size() >= 3:
			garlic_match_count += 1
			for p in consecutive:
				processed_positions.append(p)
	
	# Check vertical garlic groups
	for x in range(width):
		var consecutive = []
		for y in range(height):
			var pos = Vector2i(x, y)
			if is_position_in_array(pos, garlic_matches) and not is_position_in_array(pos, processed_positions):
				consecutive.append(pos)
			else:
				# End of consecutive run
				if consecutive.size() >= 3:
					garlic_match_count += 1
					for p in consecutive:
						processed_positions.append(p)
				consecutive = []
		
		# Check end of column
		if consecutive.size() >= 3:
			garlic_match_count += 1
			for p in consecutive:
				processed_positions.append(p)
	
	return garlic_match_count

func is_position_in_array(pos: Vector2i, positions: Array) -> bool:
	for p in positions:
		if p.x == pos.x and p.y == pos.y:
			return true
	return false
