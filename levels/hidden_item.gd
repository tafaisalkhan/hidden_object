extends TextureButton

@export var target_hud_position: Vector2 = Vector2(50, 50)
@export var item_id: String = ""

var found = false
var is_target: bool = true
var is_background: bool = false
var custom_modulate: Color = Color.WHITE

func _ready():
	pressed.connect(_on_pressed)
	focus_mode = Control.FOCUS_ALL
	
	if texture_normal:
		if item_id == "":
			item_id = texture_normal.resource_path.get_file().get_basename().to_lower()
			
		# Centered stretch mode lets us expand button hitboxes without magnifying the actual image
		stretch_mode = TextureButton.STRETCH_KEEP_CENTERED
		update_hitbox_initial()
		
	update_visual_modulation()

func update_hitbox_initial():
	if not texture_normal:
		return
	var tex_size = texture_normal.get_size()
	var min_button_w = max(tex_size.x, 64.0 / max(scale.x, 0.01))
	var min_button_h = max(tex_size.y, 64.0 / max(scale.y, 0.01))
	var expanded_size = Vector2(min_button_w, min_button_h)
	
	var delta_size = expanded_size - tex_size
	position -= (delta_size / 2.0) * scale
	
	custom_minimum_size = expanded_size
	size = expanded_size
	pivot_offset = expanded_size / 2.0

func update_hitbox():
	if not texture_normal:
		return
	var tex_size = texture_normal.get_size()
	var min_button_w = max(tex_size.x, 64.0 / max(scale.x, 0.01))
	var min_button_h = max(tex_size.y, 64.0 / max(scale.y, 0.01))
	var new_expanded_size = Vector2(min_button_w, min_button_h)
	
	if size != new_expanded_size:
		var old_center = position + (size / 2.0) * scale
		size = new_expanded_size
		custom_minimum_size = new_expanded_size
		pivot_offset = new_expanded_size / 2.0
		position = old_center - (new_expanded_size / 2.0) * scale

func get_original_position() -> Vector2:
	if texture_normal:
		return position + (size - texture_normal.get_size()) / 2.0 * scale
	return position

var dragging = false
var drag_offset = Vector2.ZERO

## Drag-to-pan protection: if the user moves more than this many pixels
## between press and release, treat it as a pan gesture, not a tap.
const DRAG_CANCEL_THRESHOLD: float = 24.0
var _was_dragged:  bool    = false
var _press_pos:    Vector2 = Vector2.ZERO

func _gui_input(event):
	var main_scene = get_tree().current_scene
	var is_edit_mode = main_scene.get("edit_mode") if main_scene else false

	# ── Gameplay mode: track press/drag to cancel accidental item clicks ───────
	if not is_edit_mode:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_was_dragged = false
				_press_pos   = event.global_position
			else:
				# Suppress background tap penalty in drag_scroll
				var viewport_ctrl = main_scene.find_child("ViewportControl", true, false) if main_scene else null
				if viewport_ctrl and viewport_ctrl.has_method("mark_item_clicked"):
					viewport_ctrl.mark_item_clicked()
				if _was_dragged:
					accept_event()   # swallow the release so pressed signal is not emitted
		elif event is InputEventScreenTouch:
			if event.pressed:
				_was_dragged = false
				_press_pos   = event.global_position
			else:
				var viewport_ctrl = main_scene.find_child("ViewportControl", true, false) if main_scene else null
				if viewport_ctrl and viewport_ctrl.has_method("mark_item_clicked"):
					viewport_ctrl.mark_item_clicked()
				if _was_dragged:
					accept_event()
		elif event is InputEventMouseMotion or event is InputEventScreenDrag:
			if event.global_position.distance_to(_press_pos) > DRAG_CANCEL_THRESHOLD:
				_was_dragged = true
		return

	# ── Edit mode: drag, scale, rotate ───────────────────────────────────────
	if is_background:
		# Background items are unselectable and undraggable
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				grab_focus()
				dragging = true
				if get_parent():
					drag_offset = get_parent().get_local_mouse_position() - position
				accept_event()
			else:
				if dragging:
					dragging = false
					accept_event()
		elif event.is_pressed() and dragging:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				scale += Vector2(0.05, 0.05)
				scale = Vector2(clamp(scale.x, 0.1, 4.0), clamp(scale.y, 0.1, 4.0))
				update_hitbox()
				accept_event()
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				scale -= Vector2(0.05, 0.05)
				scale = Vector2(clamp(scale.x, 0.1, 4.0), clamp(scale.y, 0.1, 4.0))
				update_hitbox()
				accept_event()
	elif event is InputEventScreenTouch:
		if event.pressed:
			grab_focus()
			dragging = true
			if get_parent():
				drag_offset = get_parent().get_local_mouse_position() - position
			accept_event()
		else:
			if dragging:
				dragging = false
				accept_event()

func _input(event):
	var main_scene = get_tree().current_scene
	var is_edit_mode = main_scene.get("edit_mode") if main_scene else false
	if not is_edit_mode:
		return
		
	# 1. Handle continuous drag motion & release when dragging is active
	if dragging:
		if event is InputEventMouseMotion or event is InputEventScreenDrag:
			if get_parent():
				position = get_parent().get_local_mouse_position() - drag_offset
			get_viewport().set_input_as_handled()
			return
		elif (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed) or (event is InputEventScreenTouch and not event.pressed):
			dragging = false
			get_viewport().set_input_as_handled()
			return
			
	# 2. Keyboard shortcuts when element has focus or is being edited
	if not (has_focus() or dragging):
		return
		
	# Q/E keys to rotate, U/Y keys to scale, F key to toggle findable/distractor, B key for background, Z key for layering
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
			update_hitbox()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_Y:
			scale -= Vector2(0.05, 0.05)
			scale = Vector2(clamp(scale.x, 0.1, 4.0), clamp(scale.y, 0.1, 4.0))
			update_hitbox()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F:
			is_target = not is_target
			update_visual_modulation()
			print(item_id, " is_target toggled to: ", is_target)
			
			# Rebuild the bottom HUD in real-time
			var main_scene_ref = get_tree().current_scene
			if main_scene_ref and main_scene_ref.has_method("rebuild_hud_items"):
				main_scene_ref.rebuild_hud_items()
				
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_B:
			if event.shift_pressed:
				# Capital B: Remove background effect
				remove_background_effect()
			else:
				# Lowercase b: Make background effect
				set_background_effect()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_C:
			# Cycle custom modulate tints
			var colors = [
				Color(1.0, 1.0, 1.0, 1.0), # White
				Color(0.6, 0.6, 0.6, 1.0), # Grey
				Color(0.4, 0.4, 0.4, 1.0), # Dark Grey
				Color(1.0, 0.6, 0.6, 1.0), # Light Red
				Color(0.6, 1.0, 0.6, 1.0), # Light Green
				Color(0.6, 0.6, 1.0, 1.0), # Light Blue
				Color(0.8, 0.6, 0.4, 1.0), # Wood/Brown
				Color(1.0, 1.0, 0.6, 1.0), # Yellow
				Color(1.0, 1.0, 1.0, 0.3)  # Semi-Transparent (Glass/Ghost)
			]
			var idx = colors.find(custom_modulate)
			if idx == -1:
				idx = 0
			var next_idx = (idx + 1) % colors.size()
			custom_modulate = colors[next_idx]
			print(item_id, " custom modulate color set to: ", custom_modulate)
			update_visual_modulation()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_Z:
			# Cycle z_index from 1 to 15 for precise layering
			var next_z = z_index + 1
			if next_z > 15:
				next_z = 1
			z_index = next_z
			print(item_id, " layer (z_index) set to: ", z_index)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_N:
			# N key: Remove all elements from background (reset all to selectable targets)
			var level_cont = get_parent()
			if level_cont:
				for child in level_cont.get_children():
					if child.has_method("_gui_input") and child.name != "Bed" and child.name != "Character":
						child.is_background = false
						child.is_target = true
						child.mouse_filter = Control.MOUSE_FILTER_STOP
						if child.has_method("update_visual_modulation"):
							child.update_visual_modulation()
				if main_scene and main_scene.has_method("rebuild_hud_items"):
					main_scene.rebuild_hud_items()
				print("All elements removed from background! (Reset to selectable targets)")
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_DELETE or event.keycode == KEY_BACKSPACE:
			# Deleting the item
			print("Deleting item: ", item_id)
			is_target = false # Exclude from HUD rebuild
			queue_free()
			if main_scene and main_scene.has_method("rebuild_hud_items"):
				main_scene.call_deferred("rebuild_hud_items")
			get_viewport().set_input_as_handled()

func _on_pressed():
	print("--- Clicked item: ", item_id, " (is_target: ", is_target, ", found: ", found, ") ---")
	var main_scene = get_tree().current_scene
	var is_edit_mode = main_scene.get("edit_mode") if main_scene else false
	
	var viewport_ctrl = main_scene.find_child("ViewportControl", true, false) if main_scene else null
	if viewport_ctrl and viewport_ctrl.has_method("mark_item_clicked"):
		viewport_ctrl.mark_item_clicked()

	# Cancel if in edit mode, already found, or the press was actually a drag
	if is_edit_mode or found or _was_dragged:
		print("Aborting click: is_edit_mode=", is_edit_mode, ", found=", found, ", _was_dragged=", _was_dragged)
		return
		
	if is_background:
		print("Clicked a background decoration item, ignoring.")
		return
		
	if not is_target:
		print("Clicked a distractor! Triggering life loss and indicator...")
		GameManager.lose_life()
		if main_scene and main_scene.has_method("spawn_wrong_click_indicator"):
			var level_container = main_scene.find_child("LevelContainer", true, false)
			if level_container:
				var local_pos = level_container.get_local_mouse_position()
				main_scene.call_deferred("spawn_wrong_click_indicator", local_pos)
		
		# Premium shake & red flash feedback
		var tween = create_tween()
		var orig_modulate = modulate
		var orig_pos = position
		tween.tween_property(self, "modulate", Color(1.5, 0.4, 0.4, 1.0), 0.1)
		tween.parallel().tween_property(self, "position", orig_pos + Vector2(-6, 0), 0.05)
		tween.tween_property(self, "position", orig_pos + Vector2(6, 0), 0.05)
		tween.tween_property(self, "position", orig_pos, 0.05)
		tween.tween_property(self, "modulate", orig_modulate, 0.2)
		return

	found = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE # Prevent further clicks safely
	if MusicManager:
		MusicManager.play_sfx("sparkle", -1.0, randf_range(0.97, 1.03))
	

	
	# Dynamically target the corresponding silhouette in the BottomHUD
	var fly_target = target_hud_position
	var bottom_hud = null
	if main_scene:
		bottom_hud = main_scene.find_child("BottomHUD", true, false)
		if bottom_hud:
			var target_node = null
			if bottom_hud.has_method("find_icon_for_item"):
				target_node = bottom_hud.find_icon_for_item(item_id)
			if not target_node:
				var container = bottom_hud.find_child("HBoxContainer", true, false)
				if container:
					target_node = container.find_child(item_id, false, false)
			
			if target_node:
				# Target the center of the silhouette in screen space
				fly_target = target_node.global_position + (target_node.size / 2.0) * target_node.scale
				print("Target node found in HUD! Target position: ", fly_target)
			else:
				print("WARNING: Could not find HUD silhouette node for item: ", item_id)
		else:
			print("WARNING: BottomHUD not found in scene")
	
	# Convert global position from camera-transformed world space to screen space
	var old_global_pos = get_global_transform_with_canvas().origin
	var canvas_scale = get_global_transform_with_canvas().get_scale()
	var center_canvas_pos = old_global_pos + (size / 2.0) * canvas_scale
	var old_scale = scale
	var trail_particles = null
	
	if bottom_hud:
		get_parent().remove_child(self)
		bottom_hud.add_child(self)
		global_position = old_global_pos
		scale = old_scale
		
		# 1. Spawn initial click spark burst (CPUParticles2D)
		var burst_particles = CPUParticles2D.new()
		burst_particles.global_position = center_canvas_pos
		burst_particles.amount = 30
		burst_particles.lifetime = 0.8
		burst_particles.one_shot = true
		burst_particles.explosiveness = 0.9
		burst_particles.spread = 180.0
		burst_particles.gravity = Vector2(0, 100) # Fall down
		burst_particles.initial_velocity_min = 50.0
		burst_particles.initial_velocity_max = 100.0
		burst_particles.scale_amount_min = 4.0
		burst_particles.scale_amount_max = 8.0
		burst_particles.color = Color(1.0, 0.9, 0.4, 1.0) # Golden sparks
		
		bottom_hud.add_child(burst_particles)
		burst_particles.emitting = true
		
		# Auto-free click burst
		var burst_timer = get_tree().create_timer(burst_particles.lifetime + 0.1)
		burst_timer.timeout.connect(burst_particles.queue_free)
		
		# 2. Spawn a continuous sparkle trail (CPUParticles2D) attached to the flying item
		trail_particles = CPUParticles2D.new()
		trail_particles.amount = 60
		trail_particles.lifetime = 0.6
		trail_particles.local_coords = false # Follow position in world space to create trail!
		trail_particles.spread = 360.0
		trail_particles.gravity = Vector2(0, 20) # Gentle falling trail
		trail_particles.initial_velocity_min = 10.0
		trail_particles.initial_velocity_max = 25.0
		trail_particles.scale_amount_min = 2.0
		trail_particles.scale_amount_max = 5.0
		trail_particles.color = Color(1.0, 0.95, 0.6, 1.0) # Light golden sparkles
		
		# Create gradient fade out
		var grad = Gradient.new()
		grad.set_color(0, Color(1.0, 0.95, 0.6, 1.0))
		grad.set_color(1, Color(1.0, 0.95, 0.6, 0.0))
		trail_particles.color_ramp = grad
		
		add_child(trail_particles)
		trail_particles.position = size / 2.0 # Center on the button
		trail_particles.emitting = true
	
	var tween = create_tween()
	
	# Phase 1: Emit/Scan Pulse Effect (Scale up to 2.0 and flash glow)
	tween.set_parallel(true)
	tween.tween_property(self, "scale", old_scale * 2.0, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate", Color(2.5, 2.5, 2.5, 1.0), 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# Phase 1.5: Shaking sequence
	var start_pos = position
	tween.chain().set_parallel(false)
	tween.tween_property(self, "position", start_pos + Vector2(-15, 5), 0.05).set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(self, "position", start_pos + Vector2(15, -5), 0.05).set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(self, "position", start_pos + Vector2(-12, -8), 0.05).set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(self, "position", start_pos + Vector2(12, 8), 0.05).set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(self, "position", start_pos + Vector2(-8, 5), 0.05).set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(self, "position", start_pos + Vector2(8, -5), 0.05).set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(self, "position", start_pos, 0.05).set_trans(Tween.TRANS_LINEAR)
	
	# Phase 2: Slow flight towards bottom HUD
	tween.chain().set_parallel(true)
	tween.tween_property(self, "global_position", fly_target - (pivot_offset * old_scale * 0.1), 1.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "scale", Vector2.ZERO, 1.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 0.0), 1.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	
	# On arrival: stop emitting trail, reparent it so it doesn't vanish instantly, notify HUD, and free item
	tween.chain().tween_callback(func():
		SignalHub.item_found.emit(item_id)
		if trail_particles and is_instance_valid(trail_particles):
			trail_particles.emitting = false
			# Reparent trail to bottom HUD so it survives self-destruction
			var trail_global_pos = trail_particles.global_position
			remove_child(trail_particles)
			if bottom_hud and is_instance_valid(bottom_hud):
				bottom_hud.add_child(trail_particles)
				trail_particles.global_position = trail_global_pos
			
			# Auto-free trail after it fades out
			var trail_timer = get_tree().create_timer(trail_particles.lifetime + 0.1)
			trail_timer.timeout.connect(trail_particles.queue_free)
			
		queue_free()
	)

func set_background_effect():
	is_background = true
	is_target = false
	dragging = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	release_focus()
	update_visual_modulation()
	print(item_id, " is now background (unselectable & undraggable). Hover over it and press Shift+B to restore.")
	var main_scene_ref = get_tree().current_scene
	if main_scene_ref and main_scene_ref.has_method("rebuild_hud_items"):
		main_scene_ref.rebuild_hud_items()

func remove_background_effect():
	is_background = false
	is_target = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	update_visual_modulation()
	grab_focus()
	print(item_id, " background effect removed (is_background = false, is_target = true, selectable and draggable again).")
	var main_scene_ref = get_tree().current_scene
	if main_scene_ref and main_scene_ref.has_method("rebuild_hud_items"):
		main_scene_ref.rebuild_hud_items()

func update_visual_modulation():
	var main_scene = get_tree().current_scene
	var in_edit = main_scene.get("edit_mode") if main_scene else false
	
	if is_background:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	else:
		mouse_filter = Control.MOUSE_FILTER_STOP
		
	if in_edit:
		if is_background:
			# Distinct blue/purple tint for static background decoration items in Edit Mode
			modulate = Color(0.6, 0.6, 1.2, 0.75) * custom_modulate
		elif is_target:
			# Combined modulate: Green outline * custom modulate color
			modulate = Color(0.7, 1.3, 0.7, 1.0) * custom_modulate
		else:
			modulate = custom_modulate
	else:
		# Play mode: All items (including background items) render in full solid natural colors
		modulate = custom_modulate

func play_jewel_sound():
	if MusicManager:
		MusicManager.play_sfx("sparkle", -1.0, randf_range(0.97, 1.03))
