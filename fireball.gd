extends Area2D

var direction: Vector2 = Vector2.RIGHT
var speed: float = 400.0
var damage: int = 15

@onready var sprite = $AnimatedSprite2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	
	# Play the fireball animation
	if sprite and sprite.sprite_frames:
		sprite.play("default")
	
	# Auto-destroy after 5 seconds
	await get_tree().create_timer(5.0).timeout
	queue_free()

func launch(dir: Vector2, dmg: int) -> void:
	direction = dir.normalized()
	damage = dmg
	
	# Rotate sprite to face direction
	rotation = direction.angle()

func _process(delta: float) -> void:
	position += direction * speed * delta

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		if body.has_method("take_damage"):
			body.take_damage(damage)
		queue_free()
	
	# Explode on walls
	elif body is TileMap:
		queue_free()
