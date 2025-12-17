extends Node

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

var _health_data: Dictionary = {
	"max": 100,
	"current": -1 
}


signal garlic_changed(new_count: int)
signal mint_changed(new_count: int)
signal pepper_changed(new_count: int)
signal token_collected(token_type: int)
signal health_changed(current: int, maximum: int)

func _ready():
	# Initialize health only if it's -1 (never been set)
	if _health_data["current"] == -1:
		_health_data["current"] = _health_data["max"]
		health_changed.emit(_health_data["current"], _health_data["max"])

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
		_:
			return "UNKNOWN"

func remove_garlic(amount: int = 1) -> bool:
	if garlic_count >= amount:
		garlic_count -= amount
		garlic_changed.emit(garlic_count)
		return true
	return false

func remove_pepper(amount: int = 1) -> bool:
	if pepper_count >= amount:
		pepper_count -= amount
		pepper_changed.emit(pepper_count)
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

# Health management functions
func take_damage(amount: int):
	_health_data["current"] = max(0, _health_data["current"] - amount)
	health_changed.emit(_health_data["current"], _health_data["max"])
	
	if _health_data["current"] <= 0:
		return true
	return false

func heal(amount: int):
	_health_data["current"] = min(_health_data["max"], _health_data["current"] + amount)
	health_changed.emit(_health_data["current"], _health_data["max"])

func get_current_health() -> int:
	return _health_data["current"]

func get_max_health() -> int:
	return _health_data["max"]

func set_max_health(value: int):
	_health_data["max"] = value
	_health_data["current"] = min(_health_data["current"], _health_data["max"])
	health_changed.emit(_health_data["current"], _health_data["max"])

func reset_game():
	garlic_count = 0
	mint_count = 0
	pepper_count = 0
	collected_tokens.clear()
	_health_data["current"] = _health_data["max"]
	health_changed.emit(_health_data["current"], _health_data["max"])
