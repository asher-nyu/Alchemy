
class_name GridRefiller

enum TokenType {
	ROCK = -1,
	GINGER = 0,
	GARLIC = 1,
	MINT = 2
}

func get_valid_token(grid: Array, x: int, y: int, collected_tokens: Array, width: int, height: int) -> int:
	# Reduced rock probability - only 10% chance when less than 2 tokens, 0% otherwise
	# This gives more vegetables while still preventing impossible situations
	var rock_probability = 0.1 if collected_tokens.size() < 2 else 0.0
	if randf() < rock_probability:
		return TokenType.ROCK
	
	var available_tokens = collected_tokens.duplicate()
	var forbidden_tokens = get_forbidden_tokens(grid, x, y, width, height)
	for forbidden in forbidden_tokens:
		available_tokens.erase(forbidden)
	
	# If no available tokens after filtering, use rock to prevent matches
	# This ensures no 3-in-a-row matches are created initially
	if available_tokens.is_empty():
		return TokenType.ROCK
	return available_tokens[randi() % available_tokens.size()]

func get_valid_refill_token(grid: Array, x: int, y: int, collected_tokens: Array, width: int, height: int) -> int:
	
	# Only use rock as last resort if no tokens collected at all
	if collected_tokens.is_empty():
		return TokenType.ROCK
	
	var available_tokens = collected_tokens.duplicate()
	var forbidden_tokens = get_forbidden_tokens_for_refill(grid, x, y, width, height)
	
	for forbidden in forbidden_tokens:
		available_tokens.erase(forbidden)
	
	# If all tokens would create a match, use a rock instead
	# This prevents creating 3-in-a-row matches during refills
	if available_tokens.is_empty():
		return TokenType.ROCK
	
	return available_tokens[randi() % available_tokens.size()]

func get_forbidden_tokens(grid: Array, x: int, y: int, width: int, height: int) -> Array:
	"""Get forbidden tokens during initial generation (only check left and up)"""
	var forbidden = []
	if x >= 2:
		if grid[x-1][y] == grid[x-2][y] and grid[x-1][y] != TokenType.ROCK:
			forbidden.append(grid[x-1][y])
	if y >= 2:
		if grid[x][y-1] == grid[x][y-2] and grid[x][y-1] != TokenType.ROCK:
			forbidden.append(grid[x][y-1])
	return forbidden

func get_forbidden_tokens_for_refill(grid: Array, x: int, y: int, width: int, height: int) -> Array:
	var forbidden = []
	
	# Check horizontal - look at 2 tokens to the left
	if x >= 2:
		if grid[x-1][y] == grid[x-2][y] and grid[x-1][y] != TokenType.ROCK:
			forbidden.append(grid[x-1][y])
	
	# Check horizontal - look at 2 tokens to the right
	if x < width - 2:
		if grid[x+1][y] == grid[x+2][y] and grid[x+1][y] != TokenType.ROCK:
			forbidden.append(grid[x+1][y])
	
	# Check horizontal - look at 1 left and 1 right
	if x >= 1 and x < width - 1:
		if grid[x-1][y] == grid[x+1][y] and grid[x-1][y] != TokenType.ROCK:
			forbidden.append(grid[x-1][y])
	
	# Check vertical - look at 2 tokens above
	if y >= 2:
		if grid[x][y-1] == grid[x][y-2] and grid[x][y-1] != TokenType.ROCK:
			forbidden.append(grid[x][y-1])
	
	# Check vertical - look at 2 tokens below
	if y < height - 2:
		if grid[x][y+1] == grid[x][y+2] and grid[x][y+1] != TokenType.ROCK:
			forbidden.append(grid[x][y+1])
	
	# Check vertical - look at 1 above and 1 below
	if y >= 1 and y < height - 1:
		if grid[x][y-1] == grid[x][y+1] and grid[x][y-1] != TokenType.ROCK:
			forbidden.append(grid[x][y-1])
	
	# Remove duplicates
	var unique_forbidden = []
	for token in forbidden:
		if not unique_forbidden.has(token):
			unique_forbidden.append(token)
	
	return unique_forbidden
