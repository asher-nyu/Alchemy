extends Sprite2D

enum TokenType {
	ROCK = -1,
	GINGER = 0,
	GARLIC = 1,
	MINT = 2,
	PEPPER = 3  
}

var token_type: int
var grid_x: int
var grid_y: int

func initialize(type: int, pos: Vector2, x: int, y: int):
	token_type = type
	grid_x = x
	grid_y = y
	position = pos
	centered = true
	z_index = 1
	
	# Load texture based on type
	match token_type:
		TokenType.ROCK:
			texture = load("res://assets/rocks.png")
			scale = Vector2(0.5, 0.5)
		TokenType.GINGER:
			texture = load("res://assets/ginger.png")
			scale = Vector2(4, 4)
		TokenType.GARLIC:
			texture = load("res://assets/garlic.png")
			scale = Vector2(4, 4)
		TokenType.MINT:
			texture = load("res://assets/mint.png")
			scale = Vector2(4, 4)
		TokenType.PEPPER:  
			texture = load("res://assets/pepper.png")
			scale = Vector2(4, 4)
	
	name = "Token_%d_%d_%s" % [x, y, get_token_name()]

func get_token_name() -> String:
	match token_type:
		TokenType.ROCK:
			return "Rock"
		TokenType.GINGER:
			return "Ginger"
		TokenType.GARLIC:
			return "Garlic"
		TokenType.MINT:
			return "Mint"
		TokenType.PEPPER:  
			return "Pepper"
		_:
			return "Unknown"

func highlight():
	modulate = Color(1.5, 1.5, 1.5)

func unhighlight():
	modulate = Color.WHITE
