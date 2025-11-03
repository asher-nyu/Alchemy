
# Piece properties
var color: int
var grid_x: int
var grid_y: int
var is_matched: bool = false

@onready var sprite: Sprite2D = $Sprite2D

# Signals
signal piece_clicked(piece)

func _ready():
	# Connect input signal
	input_event.connect(_on_input_event)

func _on_input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		emit_signal("piece_clicked", self)

func setup(piece_color: int, x: int, y: int):
	"""Initialize the piece"""
	color = piece_color
	grid_x = x
	grid_y = y
	update_sprite()

func update_sprite():
	"""Set the sprite based on color"""
	match color:
		0:  # GINGER
			sprite.texture = load("res://assets/ginger.png")
		1:  # GARLIC
			sprite.texture = load("res://assets/garlic.png")
		2:  # MINT
			sprite.texture = load("res://assets/mint.png")
		-1:  # ROCK
			sprite.texture = load("res://assets/rocks.png")

func move_to_position(target_pos: Vector2, duration: float = 0.3):
	"""Animate piece movement"""
	var tween = create_tween()
	tween.tween_property(self, "position", target_pos, duration)
	return tween

func set_selected(selected: bool):
	"""Highlight when selected"""
	if selected:
		sprite.modulate = Color(1.5, 1.5, 1.5)
	else:
		sprite.modulate = Color.WHITE

func dim():
	"""Dim when matched"""
	is_matched = true
	sprite.modulate = Color(0.5, 0.5, 0.5)

func destroy():
	"""Remove piece"""
	queue_free()
