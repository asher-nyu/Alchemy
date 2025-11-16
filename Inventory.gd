extends Node

# Use the same TokenType enum as the match-3 system
enum TokenType {
	ROCK = -1,
	GINGER = 0,
	GARLIC = 1,
	MINT = 2,
	PEPPER = 3
}

var garlic_count: int = 0
var mint_count: int = 0
var pepper_count: int = 0
var collected_tokens: Array = []  # This will be used by match-3 GridRefiller
var health_potions: int = 0  # Health potions collected from match-3
var jump_potions: int = 0    # Jump potions from mint matches
var hulk_potions: int = 0    # Hulk potions from pepper matches

signal garlic_changed(new_count: int)
signal mint_changed(new_count: int)
signal pepper_changed(new_count: int)
signal token_collected(token_type: int)
signal potions_changed(new_count: int)
signal jump_potions_changed(new_count: int)
signal hulk_potions_changed(new_count: int)

func add_garlic(amount: int = 1):
	garlic_count += amount
	
	# Add GARLIC token type to collected_tokens if not already there
	if not collected_tokens.has(TokenType.GARLIC):
		collected_tokens.append(TokenType.GARLIC)
		token_collected.emit(TokenType.GARLIC)
	
	garlic_changed.emit(garlic_count)

func add_mint(amount: int = 1):
	mint_count += amount
	
	# Add MINT token type to collected_tokens if not already there
	if not collected_tokens.has(TokenType.MINT):
		collected_tokens.append(TokenType.MINT)
		token_collected.emit(TokenType.MINT)
	
	mint_changed.emit(mint_count)

func add_pepper(amount: int = 1):
	pepper_count += amount
	
	# Add PEPPER token type to collected_tokens if not already there
	if not collected_tokens.has(TokenType.PEPPER):
		collected_tokens.append(TokenType.PEPPER)
		token_collected.emit(TokenType.PEPPER)
	
	pepper_changed.emit(pepper_count)

func add_token_type(token_type: int):
	if not collected_tokens.has(token_type):
		collected_tokens.append(token_type)
		token_collected.emit(token_type)

func get_token_name(token_type: int) -> String:
	match token_type:
		TokenType.ROCK:
			return "ROCK"
		TokenType.GINGER:
			return "GINGER"
		TokenType.GARLIC:
			return "GARLIC"
		TokenType.MINT:
			return "MINT"
		TokenType.PEPPER:
			return "PEPPER"
		_:
			return "UNKNOWN"

func remove_garlic(amount: int = 1) -> bool:
	if garlic_count >= amount:
		garlic_count -= amount
		garlic_changed.emit(garlic_count)
		return true
	return false

func get_garlic_count() -> int:
	return garlic_count

func get_mint_count() -> int:
	return mint_count

func get_pepper_count() -> int:
	return pepper_count

func get_collected_tokens() -> Array:
	return collected_tokens

func has_token_type(token_type: int) -> bool:
	return collected_tokens.has(token_type)

func add_health_potions(amount: int = 1):
	var max_potions = 3
	health_potions = min(health_potions + amount, max_potions)
	potions_changed.emit(health_potions)

func add_jump_potions(amount: int = 1):
	var max_potions = 3
	jump_potions = min(jump_potions + amount, max_potions)
	jump_potions_changed.emit(jump_potions)

func add_hulk_potions(amount: int = 1):
	var max_potions = 3
	hulk_potions = min(hulk_potions + amount, max_potions)
	hulk_potions_changed.emit(hulk_potions)

func get_health_potions() -> int:
	return health_potions

func get_jump_potions() -> int:
	return jump_potions

func get_hulk_potions() -> int:
	return hulk_potions

func use_health_potion() -> bool:
	if health_potions > 0:
		health_potions -= 1
		potions_changed.emit(health_potions)
		return true
	return false

func use_jump_potion() -> bool:
	if jump_potions > 0:
		jump_potions -= 1
		jump_potions_changed.emit(jump_potions)
		return true
	return false

func use_hulk_potion() -> bool:
	if hulk_potions > 0:
		hulk_potions -= 1
		hulk_potions_changed.emit(hulk_potions)
		return true
	return false
