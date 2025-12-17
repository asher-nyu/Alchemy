extends Area2D

var direction: Vector2 = Vector2.RIGHT
var speed: float = 800.0
var damage: int = 25

@onready var sprite = $AnimatedSprite2D
@onready var lifetime_timer: Timer = Timer.new()

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	
	# Play the fireball animation
	if sprite and sprite.sprite_frames:
		sprite.play("default")
	
	# Setup and start lifetime timer instead of SceneTreeTimer
	add_child(lifetime_timer)
	lifetime_timer.wait_time = 5.0
	lifetime_timer.one_shot = true
	lifetime_timer.timeout.connect(queue_free)  # Connect signal to free the node
	lifetime_timer.start()

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
