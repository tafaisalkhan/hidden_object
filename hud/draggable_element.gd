extends Control

var dragging = false
var drag_offset = Vector2.ZERO

func _ready():
	# Allow Control nodes to capture keyboard inputs when focused
	focus_mode = Control.FOCUS_ALL

func _gui_input(event):
	var main_scene = get_tree().current_scene
	var is_edit_mode = main_scene.get("edit_mode") if main_scene else false
	if not is_edit_mode:
		return
		
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				dragging = true
				grab_focus() # Grab keyboard focus so key events work
				drag_offset = (get_parent().get_global_transform().affine_inverse() * event.global_position) - position
				accept_event()
			else:
				dragging = false
				accept_event()
				
		# 1. Scale item dynamically using mouse wheel
		elif event.is_pressed() and dragging:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				scale += Vector2(0.05, 0.05)
				scale = Vector2(clamp(scale.x, 0.1, 4.0), clamp(scale.y, 0.1, 4.0))
				accept_event()
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				scale -= Vector2(0.05, 0.05)
				scale = Vector2(clamp(scale.x, 0.1, 4.0), clamp(scale.y, 0.1, 4.0))
				accept_event()

func _input(event):
	if not dragging:
		return
		
	if event is InputEventMouseMotion:
		var parent_local = get_parent().get_global_transform().affine_inverse() * event.global_position
		position = parent_local - drag_offset
		get_viewport().set_input_as_handled()
		return
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		dragging = false
		get_viewport().set_input_as_handled()
		return
		
	# 2. Keyboard Rotate (Q = Counter-clockwise, E = Clockwise)
	# 3. Keyboard Scale (U = Scale Up, Y = Scale Down)
	# 4. Keyboard Layering (Z = Toggle behind/front of bed)
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_Q:
			rotation_degrees -= 15
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_E:
			rotation_degrees += 15
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_U:
			scale += Vector2(0.05, 0.05)
			scale = Vector2(clamp(scale.x, 0.1, 4.0), clamp(scale.y, 0.1, 4.0))
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_Y:
			scale -= Vector2(0.05, 0.05)
			scale = Vector2(clamp(scale.x, 0.1, 4.0), clamp(scale.y, 0.1, 4.0))
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_Z:
			# Cycle z_index from 1 to 15 for precise layering
			var next_z = z_index + 1
			if next_z > 15:
				next_z = 1
			z_index = next_z
			print(name, " layer (z_index) set to: ", z_index)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_DELETE or event.keycode == KEY_BACKSPACE:
			# Remove from scene
			print("Deleting element: ", name)
			queue_free()
			get_viewport().set_input_as_handled()
