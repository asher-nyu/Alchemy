extends Area2D

@export var damage_per_tick: int = 5      # how much damage to deal
@export var tick_interval: float = 1.0    # seconds between damage ticks

var player: Node = null
var damage_timer: Timer


func _ready():
	# Listen for bodies entering/leaving the spike
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	# Create a timer that will fire every tick_interval seconds
	damage_timer = Timer.new()
	damage_timer.wait_time = tick_interval
	damage_timer.one_shot = false
	damage_timer.autostart = false
	add_child(damage_timer)

	damage_timer.timeout.connect(_on_damage_tick)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("Player"):
		player = body

		# Deal damage immediately
		_apply_damage()

		# Then start ticking damage over time
		damage_timer.start()


func _on_body_exited(body: Node) -> void:
	if body == player:
		damage_timer.stop()
		player = null


func _on_damage_tick() -> void:
	_apply_damage()


func _apply_damage() -> void:
	# Safety checks in case the player died/was freed while on the spikes
	if not player or not is_instance_valid(player):
		damage_timer.stop()
		player = null
		return

	if player.has_method("take_damage"):
		player.take_damage(damage_per_tick)
