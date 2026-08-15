extends CanvasLayer

signal collapsed_toggled(collapsed: bool)

var is_collapsed: bool = false
var is_animating: bool = false

@onready var scroll_container = $MarginContainer/ScrollContainer
@onready var item_container = $MarginContainer/ScrollContainer/HBoxContainer
@onready var bg_panel = $BackgroundPanel
@onready var margin_container = $MarginContainer
@onready var toggle_btn = $ToggleBtn

var total_items_count: int = 0
var found_items_count: int = 0

# Smooth horizontal scroll state
var hud_target_scroll: float = 0.0
var hud_scroll_vel: float = 0.0
var hud_is_dragging: bool = false
var hud_drag_start_pos: Vector2 = Vector2.ZERO
var hud_last_drag_time: int = 0

func setup_items(item_textures: Array):
	# Clear old items
	for child in item_container.get_children():
		child.queue_free()
		
	for tex in item_textures:
		if not tex:
			continue
		var item_name = tex.resource_path.get_file().get_basename().to_lower()
		
		# TextureRect (Silhouette Icon)
		var tex_rect = TextureRect.new()
		tex_rect.name = item_name
		tex_rect.texture = tex
		tex_rect.set_meta("tex_path", tex.resource_path)
		tex_rect.set_meta("base_name", item_name)
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.custom_minimum_size = Vector2(80, 80) # Sized to 80x80
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.modulate = Color(1.0, 1.0, 1.0, 1.0) # Bright full color initially
		tex_rect.mouse_filter = Control.MOUSE_FILTER_PASS
		
		item_container.add_child(tex_rect)

func _ready():
	SignalHub.item_found.connect(_on_item_found)
	SignalHub.items_progress_updated.connect(_on_items_progress_updated)
	if scroll_container:
		scroll_container.gui_input.connect(_on_scroll_gui_input)
	if toggle_btn:
		toggle_btn.pressed.connect(_on_toggle_pressed)
		_setup_btn_effects(toggle_btn)

func _process(delta: float) -> void:
	if not scroll_container or not item_container:
		return
	var max_h = max(0, item_container.size.x - scroll_container.size.x)
	if not hud_is_dragging:
		if abs(hud_scroll_vel) > 3.0:
			hud_target_scroll = clamp(hud_target_scroll + hud_scroll_vel * delta, 0.0, max_h)
			hud_scroll_vel = lerp(hud_scroll_vel, 0.0, 1.0 - exp(-7.0 * delta))
		else:
			hud_scroll_vel = 0.0
	hud_target_scroll = clamp(hud_target_scroll, 0.0, max_h)
	scroll_container.scroll_horizontal = int(round(lerp(float(scroll_container.scroll_horizontal), hud_target_scroll, 1.0 - exp(-22.0 * delta))))

func _on_scroll_gui_input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_LEFT] and event.pressed:
			hud_target_scroll -= 80.0
			get_viewport().set_input_as_handled()
		elif event.button_index in [MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_RIGHT] and event.pressed:
			hud_target_scroll += 80.0
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				hud_is_dragging = true
				hud_drag_start_pos = event.global_position
				hud_last_drag_time = Time.get_ticks_msec()
				hud_scroll_vel = 0.0
			else:
				hud_is_dragging = false
	elif event is InputEventMouseMotion and hud_is_dragging:
		var dx = event.relative.x
		hud_target_scroll -= dx
		var now = Time.get_ticks_msec()
		var dt = clamp((now - hud_last_drag_time) / 1000.0, 0.001, 0.1)
		hud_last_drag_time = now
		hud_scroll_vel = lerp(hud_scroll_vel, -dx / dt, 0.45)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch:
		if event.pressed:
			hud_is_dragging = true
			hud_drag_start_pos = event.position
			hud_last_drag_time = Time.get_ticks_msec()
			hud_scroll_vel = 0.0
		else:
			hud_is_dragging = false
	elif event is InputEventScreenDrag:
		if not hud_is_dragging:
			hud_is_dragging = true
			hud_drag_start_pos = event.position
			hud_last_drag_time = Time.get_ticks_msec()
		var dx = event.relative.x
		hud_target_scroll -= dx
		var now = Time.get_ticks_msec()
		var dt = clamp((now - hud_last_drag_time) / 1000.0, 0.001, 0.1)
		hud_last_drag_time = now
		hud_scroll_vel = lerp(hud_scroll_vel, -dx / dt, 0.45)
		get_viewport().set_input_as_handled()

func _on_items_progress_updated(found_count: int, total_count: int):
	found_items_count = found_count
	total_items_count = total_count
	_update_toggle_btn_text()

func _update_toggle_btn_text():
	if toggle_btn:
		var arrow = "▲" if is_collapsed else "▼"
		toggle_btn.text = arrow + " Items: " + str(found_items_count) + " / " + str(total_items_count)

func _on_toggle_pressed():
	if is_animating:
		return
	is_collapsed = not is_collapsed
	is_animating = true
	
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Slide targets
	var bg_top_target = 0.0 if is_collapsed else -130.0
	var bg_bottom_target = 130.0 if is_collapsed else 0.0
	var btn_top_target = -35.0 if is_collapsed else -165.0
	var btn_bottom_target = 0.0 if is_collapsed else -130.0
	
	# Animate BackgroundPanel
	tween.tween_property(bg_panel, "offset_top", bg_top_target, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(bg_panel, "offset_bottom", bg_bottom_target, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# Animate MarginContainer
	tween.tween_property(margin_container, "offset_top", bg_top_target, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(margin_container, "offset_bottom", bg_bottom_target, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# Animate ToggleBtn
	tween.tween_property(toggle_btn, "offset_top", btn_top_target, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(toggle_btn, "offset_bottom", btn_bottom_target, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# Emit signal to let scroll camera know to update bounds in real-time
	collapsed_toggled.emit(is_collapsed)
	
	tween.chain().tween_callback(func():
		is_animating = false
		_update_toggle_btn_text()
	)

func _setup_btn_effects(btn: Button):
	# Add hover scale effects for a premium feel
	btn.pivot_offset = btn.size / 2.0
	btn.mouse_entered.connect(func():
		var tween = create_tween()
		tween.tween_property(btn, "scale", Vector2(1.08, 1.08), 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	)
	btn.mouse_exited.connect(func():
		var tween = create_tween()
		tween.tween_property(btn, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	)

func find_icon_for_item(item_name: String) -> Control:
	var target_name = item_name.to_lower().strip_edges()
	# 1. Exact match by name
	var direct = item_container.find_child(item_name, false, false)
	if direct and is_instance_valid(direct) and not direct.is_queued_for_deletion():
		return direct
		
	# 2. Iterate children and match meta / prefix / base name
	for child in item_container.get_children():
		if child is Control and is_instance_valid(child) and not child.is_queued_for_deletion():
			var c_name = child.name.to_lower()
			var c_base = child.get_meta("base_name", "").to_lower()
			var c_path = child.get_meta("tex_path", "").to_lower()
			
			if c_name == target_name or c_base == target_name:
				return child
			if target_name != "" and (c_name.begins_with(target_name) or target_name.begins_with(c_name) or target_name.begins_with(c_base) or c_base.begins_with(target_name)):
				return child
			if c_path != "" and (c_path.ends_with("/" + target_name + ".png") or target_name in c_path):
				return child
	return null

func _on_item_found(item_name: String):
	print("--- HUD: Received item_found for: ", item_name, " ---")
	var icon = find_icon_for_item(item_name)
	if icon:
		print("HUD: Found icon for: ", item_name, " (Node name: ", icon.name, ")")
		
		# Animate the icon shrinking and fading out
		var tween = create_tween()
		tween.set_parallel(true)
		icon.pivot_offset = icon.custom_minimum_size / 2.0
		tween.tween_property(icon, "scale", Vector2.ZERO, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tween.tween_property(icon, "modulate:a", 0.0, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		
		# Delete node after animation completes to clean it from the layout list
		tween.chain().tween_callback(icon.queue_free)
	else:
		print("WARNING: HUD could not find icon for item: ", item_name)
