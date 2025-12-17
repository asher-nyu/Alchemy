extends AnimatedSprite2D

@onready var blocker_body: StaticBody2D = $StaticBody2D
@onready var blocker_shape: CollisionShape2D = $StaticBody2D/CollisionShape2D
@onready var trigger: Area2D = $Area2D
@onready var trigger_shape: CollisionShape2D = $Area2D/CollisionShape2D

var portal_sound: AudioStreamPlayer = AudioStreamPlayer.new()

const PORTAL_ANIM := "open"

var armed: bool = false
var transitioning: bool = false

func _ready() -> void:
	add_child(portal_sound)
	portal_sound.stream = load("res://assets/Audio Pack/portal2.wav")

	# Start as a wall
	armed = false
	transitioning = false

	if blocker_shape:
		blocker_shape.disabled = false

	trigger.monitoring = false
	trigger.monitorable = true

	set_physics_process(false)

func arm_portal() -> void:
	if armed:
		return
	armed = true

	if blocker_shape:
		blocker_shape.disabled = true

	trigger.monitoring = true
	set_physics_process(true)

func _physics_process(_dt: float) -> void:
	if not armed or transitioning:
		return
	if trigger_shape == null or trigger_shape.shape == null:
		return

	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = trigger_shape.shape
	q.transform = trigger_shape.global_transform
	q.collision_mask = trigger.collision_mask
	q.collide_with_bodies = true
	q.collide_with_areas = true

	var hits: Array = get_world_2d().direct_space_state.intersect_shape(q, 16)

	for h in hits:
		var collider: Object = h.get("collider") as Object
		if collider == null:
			continue

		if collider is CharacterBody2D:
			_start_transition(collider as CharacterBody2D)
			return

		if collider is Area2D:
			var parent := (collider as Area2D).get_parent()
			if parent is CharacterBody2D:
				_start_transition(parent as CharacterBody2D)
				return

func _get_anim_raw_duration(anim_name: String) -> float:
	# duration at speed_scale = 1.0 (no speed_scale applied)
	var sf: SpriteFrames = sprite_frames
	if sf == null or not sf.has_animation(anim_name):
		return 0.0

	var frame_count := sf.get_frame_count(anim_name)
	var total := 0.0
	for i in range(frame_count):
		total += sf.get_frame_duration(anim_name, i)

	var speed := sf.get_animation_speed(anim_name)
	if speed > 0.0:
		total /= speed

	return total

func _start_transition(player: CharacterBody2D) -> void:
	if transitioning:
		return
	transitioning = true
	trigger.monitoring = false

	# Duration = portal sound length (so everything ends together)
	var duration := 0.25
	if portal_sound.stream != null:
		var l := portal_sound.stream.get_length()
		if l > 0.05:
			duration = l

	# Stop “resistance” immediately
	player.collision_layer = 0
	player.collision_mask = 0
	player.velocity = Vector2.ZERO
	player.set_process_input(false)
	player.set_physics_process(false)
	player.set_process(false)

	# Start sound NOW
	portal_sound.stop()
	portal_sound.play(0.0)

	# Start player "suck" animation NOW + sync speed to sound duration
	var p_sprite := player.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if p_sprite != null and p_sprite.sprite_frames != null and p_sprite.sprite_frames.has_animation("portal_suck"):
		_sync_anim_to_duration(p_sprite, "portal_suck", duration)
		p_sprite.play("portal_suck")

	# Pull only X (keep Y unchanged) + fade over the SAME duration
	var target_pos := Vector2(global_position.x, player.global_position.y)

	player.modulate.a = 1.0
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(player, "global_position", target_pos, duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(player, "modulate:a", 0.0, duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	await t.finished

	# Optional safety: only wait for finished if it’s still playing
	if portal_sound.playing:
		await portal_sound.finished

	LevelManager.go_to_next_level()
	

func _anim_duration(anim_sprite: AnimatedSprite2D, anim_name: String) -> float:
	var sf: SpriteFrames = anim_sprite.sprite_frames
	if sf == null or not sf.has_animation(anim_name):
		return 0.0

	var frame_count: int = sf.get_frame_count(anim_name)
	var total: float = 0.0
	for i in range(frame_count):
		total += sf.get_frame_duration(anim_name, i)

	var speed: float = sf.get_animation_speed(anim_name)
	if speed > 0.0:
		total /= speed

	var s: float = anim_sprite.speed_scale
	if s <= 0.001:
		s = 1.0

	return total / s

func _sync_anim_to_duration(anim_sprite: AnimatedSprite2D, anim_name: String, target_seconds: float) -> void:
	if target_seconds <= 0.01:
		return

	var current: float = _anim_duration(anim_sprite, anim_name) # seconds at current speed_scale
	if current <= 0.01:
		return

	# Convert to "raw" duration at speed_scale = 1.0
	var s: float = anim_sprite.speed_scale
	if s <= 0.001:
		s = 1.0

	var raw: float = current * s

	# duration = raw / speed_scale  => speed_scale = raw / target
	var new_speed: float = raw / target_seconds
	new_speed = clampf(new_speed, 0.05, 10.0)

	anim_sprite.speed_scale = new_speed
