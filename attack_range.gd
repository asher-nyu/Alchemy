extends Node2D

@export var ring_color: Color = Color(0.8, 0.1, 0.1, 0.5)  # translucent red
@export var thickness: float = 4.0
@export var segments: int = 32

var _visible_ring: bool = false
var _radius: float = 100.0
var _angle: float = PI / 2  # semi-circle (90 degrees)

func _ready():
	visible = false
	set_process(false)

func show_range(radius: float, angle: float = PI / 2):
	_radius = radius
	_angle = angle
	_visible_ring = true
	visible = true
	set_process(true)
	queue_redraw()  # <-- use this instead of update()

func hide_range():
	_visible_ring = false
	visible = false
	set_process(false)
	queue_redraw()  # <-- use this instead of update()

func _process(delta: float):
	if owner and owner is Node2D:
		global_position = owner.global_position
	rotation = PI if owner.flip_h else 0

func _draw():
	if not _visible_ring:
		return

	var half_angle = _angle / 2
	var start_angle = -half_angle
	var end_angle = half_angle

	var prev = Vector2(cos(start_angle), sin(start_angle)) * _radius
	for i in range(1, segments + 1):
		var t = float(i) / float(segments)
		var a = lerp(start_angle, end_angle, t)
		var p = Vector2(cos(a), sin(a)) * _radius
		draw_line(prev, p, ring_color, thickness)
		prev = p
