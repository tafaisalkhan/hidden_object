extends Control

# ── Zoom constraints ──────────────────────────────────────────────────────────
@export var min_zoom:     float = 0.5
@export var max_zoom:     float = 3.0
@export var normal_zoom:  float = 1.0
@export var smooth_speed: float = 15.0

# ── HUD heights ───────────────────────────────────────────────────────────────
const TOP_HUD_H:    float = 75.0
var   bottom_hud_h: float = 130.0

# ── Camera state ──────────────────────────────────────────────────────────────
var current_zoom:        float   = 1.0
var target_camera_pos:   Vector2 = Vector2.ZERO
var is_camera_tweening:  bool    = false
var is_actively_dragging: bool   = false

# ── PC mouse drag ─────────────────────────────────────────────────────────────
var mouse_drag_active: bool    = false
var mouse_has_moved:   bool    = false
var mouse_start_pos:   Vector2 = Vector2.ZERO

# ── Mobile single-touch drag ──────────────────────────────────────────────────
var dragging:         bool    = false
var drag_touch_index: int     = -1
var drag_has_moved:   bool    = false
var touch_start_pos:  Vector2 = Vector2.ZERO

# ── Pinch-to-zoom ─────────────────────────────────────────────────────────────
var touch_positions:          Dictionary = {}
var touch_mode_active:        bool       = false
var was_pinch_active:         bool       = false
var start_pinch_dist:         float      = 0.0
var start_zoom:               float      = 1.0
var start_pinch_center_world: Vector2    = Vector2.ZERO

# ── Inertia & Smoothing ──────────────────────────────────────────────────────
var drag_velocity:   Vector2 = Vector2.ZERO
var last_drag_time:  int     = 0
var last_motion_pos: Vector2 = Vector2.ZERO

static var suppress_wrong_click_until_ms: int = 0

static func mark_item_clicked() -> void:
	suppress_wrong_click_until_ms = Time.get_ticks_msec() + 300

@onready var camera:          Camera2D = $"../GameCamera"
@onready var level_container: Control  = $LevelContainer


# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	if camera:
		camera.position_smoothing_enabled = false
	var bottom_hud = $"../BottomHUD"
	if bottom_hud and bottom_hud.has_signal("collapsed_toggled"):
		bottom_hud.collapsed_toggled.connect(_on_hud_collapsed)
	get_viewport().size_changed.connect(_on_viewport_size_changed)


func _on_viewport_size_changed() -> void:
	reset_zoom()


func _on_hud_collapsed(collapsed: bool) -> void:
	bottom_hud_h      = 35.0 if collapsed else 130.0
	target_camera_pos = clamp_camera_position(target_camera_pos, current_zoom)


# ─────────────────────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	if not camera:
		return
	if touch_positions.size() >= 2:
		_update_pinch()
	if not is_camera_tweening:
		if is_actively_dragging:
			# High-responsiveness subpixel damping while actively dragging
			var drag_follow_weight = 1.0 - exp(-32.0 * delta)
			camera.position = camera.position.lerp(target_camera_pos, drag_follow_weight)
			camera.zoom     = camera.zoom.lerp(Vector2(current_zoom, current_zoom), drag_follow_weight)
		else:
			# Kinetic momentum gliding on release with gentle decay
			if drag_velocity.length() > 4.0:
				target_camera_pos = clamp_camera_position(target_camera_pos + drag_velocity * delta, current_zoom)
				drag_velocity = drag_velocity.lerp(Vector2.ZERO, 1.0 - exp(-6.0 * delta))
			else:
				drag_velocity = Vector2.ZERO

			var settle_weight = 1.0 - exp(-smooth_speed * delta)
			camera.position = camera.position.lerp(target_camera_pos, settle_weight)
			camera.zoom     = camera.zoom.lerp(Vector2(current_zoom, current_zoom), settle_weight)


func _update_pinch() -> void:
	var keys  := touch_positions.keys()
	var p1:    Vector2 = touch_positions[keys[0]]
	var p2:    Vector2 = touch_positions[keys[1]]
	var dist:  float   = p1.distance_to(p2)
	if start_pinch_dist <= 0.0:
		return
	var new_zoom: float = clamp(start_zoom * dist / start_pinch_dist, min_zoom, max_zoom)
	current_zoom        = new_zoom
	var sc:     Vector2 = get_viewport().get_visible_rect().size / 2.0
	target_camera_pos   = clamp_camera_position(
		start_pinch_center_world - ((p1 + p2) / 2.0 - sc) / new_zoom, new_zoom)


# ── Public API ────────────────────────────────────────────────────────────────
func reset_zoom() -> void:
	dragging             = false
	drag_touch_index     = -1
	mouse_drag_active    = false
	is_actively_dragging = false
	touch_positions.clear()
	touch_mode_active    = false
	was_pinch_active     = false
	start_pinch_dist     = 0.0

	var fit: float = calculate_fit_zoom()
	min_zoom     = calculate_min_zoom()
	max_zoom     = max(fit * 3.5, 3.0)
	current_zoom = fit

	if camera and level_container:
		var bg:     Vector2 = get_background_size()
		var origin: Vector2 = level_container.global_position
		target_camera_pos   = _center_camera(origin, bg, fit)
		camera.zoom         = Vector2(fit, fit)
		camera.position     = target_camera_pos


func zoom_by_button(zoom_in: bool) -> void:
	if not camera:
		return
	var step:  float = max(current_zoom * 0.2, 0.08)
	var new_z: float = clamp(current_zoom + (step if zoom_in else -step), min_zoom, max_zoom)
	if new_z != current_zoom:
		current_zoom      = new_z
		target_camera_pos = clamp_camera_position(target_camera_pos, new_z)


# ── Background helpers ────────────────────────────────────────────────────────
func get_background_size() -> Vector2:
	var ms = get_tree().current_scene
	if ms and "original_bg_size" in ms and ms.original_bg_size != Vector2.ZERO:
		return ms.original_bg_size
	return level_container.size if level_container else Vector2.ZERO


func calculate_fit_zoom() -> float:
	var bg: Vector2 = get_background_size()
	if bg == Vector2.ZERO or bg.x <= 0.0 or bg.y <= 0.0:
		return 1.0
	var screen:     Vector2 = get_viewport().get_visible_rect().size
	var gameplay_h: float   = screen.y - TOP_HUD_H - bottom_hud_h
	# Initial fill: completely covers screen without empty space
	return max(screen.x / bg.x, gameplay_h / bg.y)


func calculate_min_zoom() -> float:
	var bg: Vector2 = get_background_size()
	if bg == Vector2.ZERO or bg.x <= 0.0 or bg.y <= 0.0:
		return 0.3
	var screen:     Vector2 = get_viewport().get_visible_rect().size
	var gameplay_h: float   = screen.y - TOP_HUD_H - bottom_hud_h
	# Allow zooming out to see the entire room image and all items comfortably
	return min(screen.x / bg.x, gameplay_h / bg.y) * 0.9


# ── Camera math ───────────────────────────────────────────────────────────────
func _center_camera(origin: Vector2, bg: Vector2, zoom: float) -> Vector2:
	var cx: float = origin.x + bg.x / 2.0
	var cy: float = origin.y + bg.y / 2.0 + (bottom_hud_h - TOP_HUD_H) / (2.0 * zoom)
	return clamp_camera_position(Vector2(cx, cy), zoom)


## Camera2D: world(wx,wy) → screen(sx,sy)
##   sy = screen.y/2 + (wy - cy) * zoom
## bg top  at screen TOP_HUD_H     → cy_min = origin.y + (screen.y/2 - TOP_HUD_H) / zoom
## bg bot  at screen.y-bottom_hud  → cy_max = origin.y + bg.y - (screen.y/2 - bottom_hud_h) / zoom
func clamp_camera_position(target_pos: Vector2, target_zoom: float) -> Vector2:
	var bg: Vector2 = get_background_size()
	if bg == Vector2.ZERO or not level_container:
		return target_pos

	var screen: Vector2 = get_viewport().get_visible_rect().size
	var origin: Vector2 = level_container.global_position
	var out:    Vector2 = target_pos

	# Horizontal
	var vis_w: float = screen.x / target_zoom
	if vis_w >= bg.x:
		out.x = origin.x + bg.x / 2.0
	else:
		out.x = clamp(target_pos.x,
			origin.x + screen.x / (2.0 * target_zoom),
			origin.x + bg.x - screen.x / (2.0 * target_zoom))

	# Vertical
	var gameplay_h: float = screen.y - TOP_HUD_H - bottom_hud_h
	var vis_h:      float = gameplay_h / target_zoom
	if vis_h >= bg.y:
		out.y = origin.y + bg.y / 2.0 + (bottom_hud_h - TOP_HUD_H) / (2.0 * target_zoom)
	else:
		var min_y: float = origin.y + (screen.y / 2.0 - TOP_HUD_H)     / target_zoom
		var max_y: float = origin.y + bg.y - (screen.y / 2.0 - bottom_hud_h) / target_zoom
		out.y = clamp(target_pos.y, min_y, max_y)

	return out


# ── Helpers ───────────────────────────────────────────────────────────────────
func _in_gameplay(screen_pos: Vector2) -> bool:
	var h: float = get_viewport().get_visible_rect().size.y
	return screen_pos.y >= TOP_HUD_H and screen_pos.y <= h - bottom_hud_h


func _has_hint_overlay() -> bool:
	if not level_container:
		return false
	for c in level_container.get_children():
		if c.name == "HintOverlay":
			return true
	return false


# ─────────────────────────────────────────────────────────────────────────────
# _unhandled_input
#
# WHY only _unhandled_input (no _input override):
#   TextureButton._gui_input accepts InputEventMouseButton (press/release),
#   which marks them handled → neither _input nor _unhandled_input sees them.
#   BUT InputEventMouseMotion is NOT accepted by TextureButton internally,
#   so mouse MOTION events DO reach _unhandled_input even while over items.
#
# KEY TRICK – button_mask on motion events:
#   event.button_mask tells us which buttons are currently held RIGHT NOW.
#   If left button is held but we never saw the press (item consumed it),
#   we retroactively start the drag on the FIRST motion event.
#   → zero perceptible delay, works at ANY zoom level.
# ─────────────────────────────────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if not camera:
		return
	var ms = get_tree().current_scene
	if ms and ms.get("edit_mode"):
		return

	# Detect touch device
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		touch_mode_active = true

	var sc: Vector2 = get_viewport().get_visible_rect().size / 2.0

	# ══════════════════════════════════════════════════════════════════════════
	# PC – MOUSE
	# ══════════════════════════════════════════════════════════════════════════
	if not touch_mode_active:
		# ── Wheel zoom ────────────────────────────────────────────────────────
		if event is InputEventMouseButton and event.pressed and \
		   event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and \
		   _in_gameplay(event.position):
			var step:  float = calculate_fit_zoom() * 0.1
			var old_z: float = current_zoom
			var new_z: float = clamp(
				old_z + (step if event.button_index == MOUSE_BUTTON_WHEEL_UP else -step),
				min_zoom, max_zoom)
			if new_z != old_z:
				current_zoom = new_z
				var off: Vector2 = event.position - sc
				target_camera_pos = clamp_camera_position(
					target_camera_pos + off / old_z - off / new_z, new_z)
			get_viewport().set_input_as_handled()
			return

		# ── Left button PRESS ────────────────────────────────────────────────
		if event is InputEventMouseButton and \
		   event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if _in_gameplay(event.position):
				mouse_drag_active    = true
				mouse_has_moved      = false
				mouse_start_pos      = event.position
				is_actively_dragging = true
			return

		# ── Left button RELEASE ──────────────────────────────────────────────
		if event is InputEventMouseButton and \
		   event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			is_actively_dragging = false
			if mouse_drag_active:
				if mouse_has_moved:
					get_viewport().set_input_as_handled()
					mouse_drag_active = false
			return

		# ── Mouse MOTION ──────────────────────────────────────────────────────
		if event is InputEventMouseMotion:
			if event.button_mask & MOUSE_BUTTON_MASK_LEFT:
				if not mouse_drag_active and _in_gameplay(event.position):
					mouse_drag_active    = true
					mouse_has_moved      = false
					mouse_start_pos      = event.position
					is_actively_dragging = true

				if mouse_drag_active:
					if event.position.distance_to(mouse_start_pos) > 5.0:
						mouse_has_moved = true
					target_camera_pos = clamp_camera_position(
						target_camera_pos - event.relative / current_zoom, current_zoom)
					get_viewport().set_input_as_handled()
			else:
				if mouse_drag_active:
					mouse_drag_active    = false
					is_actively_dragging = false
			return

	# ══════════════════════════════════════════════════════════════════════════
	# MOBILE – TOUCH
	# ══════════════════════════════════════════════════════════════════════════
	# ── Touch PRESS ───────────────────────────────────────────────────────────
	if event is InputEventScreenTouch:
		if event.pressed:
			if not _in_gameplay(event.position):
				return
			touch_positions[event.index] = event.position
			if touch_positions.size() == 1:
				drag_touch_index     = event.index
				dragging             = true
				drag_has_moved       = false
				touch_start_pos      = event.position
				is_actively_dragging = true
			elif touch_positions.size() == 2:
				was_pinch_active     = true
				is_actively_dragging = true
				dragging             = false
				var keys = touch_positions.keys()
				var p1: Vector2 = touch_positions[keys[0]]
				var p2: Vector2 = touch_positions[keys[1]]
				start_pinch_dist         = p1.distance_to(p2)
				start_zoom               = current_zoom
				start_pinch_center_world = target_camera_pos + ((p1 + p2) / 2.0 - sc) / current_zoom
		else:  # Touch RELEASE
			touch_positions.erase(event.index)
			if touch_positions.size() < 2:
				start_pinch_dist = 0.0
			if touch_positions.is_empty():
				is_actively_dragging = false

			if event.index == drag_touch_index:
				if not touch_positions.is_empty():
					drag_touch_index = touch_positions.keys()[0]
				else:
					dragging         = false
					drag_touch_index = -1
					if was_pinch_active or drag_has_moved:
						get_viewport().set_input_as_handled()
						was_pinch_active = false
						drag_has_moved = false

	# ── Touch DRAG ────────────────────────────────────────────────────────────
	elif event is InputEventScreenDrag:
		touch_positions[event.index] = event.position

		if not dragging and drag_touch_index == -1 and touch_positions.size() == 1:
			if _in_gameplay(event.position):
				drag_touch_index     = event.index
				dragging             = true
				drag_has_moved       = false
				touch_start_pos      = event.position
				is_actively_dragging = true

		if dragging and event.index == drag_touch_index and touch_positions.size() == 1:
			if event.position.distance_to(touch_start_pos) > 8.0:
				drag_has_moved = true
			target_camera_pos = clamp_camera_position(
				target_camera_pos - event.relative / current_zoom, current_zoom)
			get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not camera:
		return
	var ms = get_tree().current_scene
	if ms and ms.get("edit_mode"):
		return

	# If an item was clicked recently, do not treat this tap as a wrong background click
	if Time.get_ticks_msec() < suppress_wrong_click_until_ms:
		mouse_drag_active = false
		dragging = false
		was_pinch_active = false
		drag_has_moved = false
		return

	if not touch_mode_active:
		if event is InputEventMouseButton and \
		   event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			if mouse_drag_active and not mouse_has_moved and not _has_hint_overlay():
				GameManager.lose_life()
				if ms and ms.has_method("spawn_wrong_click_indicator"):
					var wp = level_container.get_global_transform_with_canvas().affine_inverse() * event.position
					ms.call_deferred("spawn_wrong_click_indicator", wp)
			mouse_drag_active = false
			get_viewport().set_input_as_handled()
	else:
		if event is InputEventScreenTouch and not event.pressed:
			if not was_pinch_active and not drag_has_moved and not _has_hint_overlay():
				GameManager.lose_life()
				if ms and ms.has_method("spawn_wrong_click_indicator"):
					var wp = level_container.get_global_transform_with_canvas().affine_inverse() * event.position
					ms.call_deferred("spawn_wrong_click_indicator", wp)
			was_pinch_active = false
			drag_has_moved = false
			get_viewport().set_input_as_handled()
