extends Control

var pulse_time = 0.0

func _ready():
	# Fill parent boundaries and ignore mouse events
	anchors_preset = Control.PRESET_FULL_RECT
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Set default size to match parent size on next frame if size is zero
	if size == Vector2.ZERO and get_parent() is Control:
		size = get_parent().size

func _process(delta):
	# Center pivot offset continuously as size changes
	pivot_offset = size / 2.0
	
	# Pulsing scale animation
	pulse_time += delta * 5.0
	var pulse = 1.0 + sin(pulse_time) * 0.08
	scale = Vector2(pulse, pulse)
	
	queue_redraw()

func _draw():
	var center = size / 2.0
	# Draw radius slightly larger than item dimensions
	var radius = max(size.x, size.y) / 2.0 + 15.0
	
	# 1. Soft red glow ring
	draw_arc(center, radius, 0.0, TAU, 64, Color(1.0, 0.25, 0.25, 0.35), 10.0, true)
	# 2. Sharp vibrant red outline ring
	draw_arc(center, radius, 0.0, TAU, 64, Color(1.0, 0.25, 0.25, 1.0), 4.0, true)
	# 3. Inner soft white/pink highlight ring
	draw_arc(center, radius - 4.0, 0.0, TAU, 64, Color(1.0, 0.6, 0.6, 0.8), 1.5, true)
