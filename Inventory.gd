extends Node

# Use the same TokenType enum as the match-3 system
enum TokenType {
	ROCK = -1,
	GINGER = 0,
	GARLIC = 1,
	MINT = 2
}

var garlic_count: int = 0
var collected_tokens: Array = []  # This will be used by match-3 GridRefiller

signal garlic_changed(new_count: int)
signal token_collected(token_type: int)

func add_garlic(amount: int = 1):
	garlic_count += amount
	
	# Add GARLIC token type to collected_tokens if not already there
	if not collected_tokens.has(TokenType.GARLIC):
		collected_tokens.append(TokenType.GARLIC)
		token_collected.emit(TokenType.GARLIC)
	
	garlic_changed.emit(garlic_count)

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

func get_collected_tokens() -> Array:
	return collected_tokens

func has_token_type(token_type: int) -> bool:
	return collected_tokens.has(token_type)
