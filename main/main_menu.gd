extends Control

@onready var main_buttons_panel = $MainButtonsPanel
@onready var category_select_panel = $CategorySelectPanel
@onready var level_select_panel = $LevelSelectPanel

@onready var category_scroll = $CategorySelectPanel/VBox/ScrollContainer
@onready var level_scroll = $LevelSelectPanel/VBox/ScrollContainer

@onready var category_grid_container = $CategorySelectPanel/VBox/ScrollContainer/CategoryGridContainer
@onready var level_grid_container = $LevelSelectPanel/VBox/ScrollContainer/GridContainer
@onready var level_header_title = $LevelSelectPanel/VBox/HeaderTitle

var current_category_title: String = "Living Room"

# Smooth scrolling state for Category & Level grids
var cat_target_scroll: float = 0.0
var cat_scroll_vel: float = 0.0
var cat_is_dragging: bool = false
var cat_has_dragged: bool = false
var cat_drag_start_pos: Vector2 = Vector2.ZERO
var cat_last_drag_time: int = 0

var lvl_target_scroll: float = 0.0
var lvl_scroll_vel: float = 0.0
var lvl_is_dragging: bool = false
var lvl_has_dragged: bool = false
var lvl_drag_start_pos: Vector2 = Vector2.ZERO
var lvl_last_drag_time: int = 0

func _ready():
	AdManager.show_banner()
	
	# Play menu background music (crossfades from game music if returning)
	if MusicManager:
		MusicManager.play_menu_music()
	
	if category_scroll:
		category_scroll.gui_input.connect(_on_category_scroll_gui_input)
	if level_scroll:
		level_scroll.gui_input.connect(_on_level_scroll_gui_input)
		
	if GameManager and GameManager.return_to_level_select:
		GameManager.return_to_level_select = false
		main_buttons_panel.visible = false
		category_select_panel.visible = false
		
		# Open level select directly for the active category
		var cat_id = GameManager.selected_category_id if GameManager.selected_category_id != "" else "drawing_room"
		var cat_title = cat_id.replace("_", " ").capitalize()
		level_header_title.text = cat_title.to_upper() + " - LEVELS"
		populate_level_grid()
		level_select_panel.visible = true
	else:
		main_buttons_panel.visible = true
		category_select_panel.visible = false
		level_select_panel.visible = false

	_setup_extra_ui()

	# Ant War style launch automation
	get_tree().create_timer(0.6).timeout.connect(func():
		if not is_instance_valid(self):
			return
		if PopupManager:
			if PopupManager.can_claim_daily_reward():
				PopupManager.show_daily_reward_popup(self)
			elif PopupManager.has_method("show_random_support_popup"):
				PopupManager.show_random_support_popup(self)
	)

func _process(delta: float) -> void:
	# 1. Smooth Category Scroll processing
	if category_select_panel and category_select_panel.visible and category_scroll:
		var max_c = max(0, category_grid_container.size.y - category_scroll.size.y)
		if not cat_is_dragging:
			if abs(cat_scroll_vel) > 3.0:
				cat_target_scroll = clamp(cat_target_scroll + cat_scroll_vel * delta, 0.0, max_c)
				cat_scroll_vel = lerp(cat_scroll_vel, 0.0, 1.0 - exp(-7.0 * delta))
			else:
				cat_scroll_vel = 0.0
		cat_target_scroll = clamp(cat_target_scroll, 0.0, max_c)
		category_scroll.scroll_vertical = int(round(lerp(float(category_scroll.scroll_vertical), cat_target_scroll, 1.0 - exp(-22.0 * delta))))

	# 2. Smooth Level Select Scroll processing
	if level_select_panel and level_select_panel.visible and level_scroll:
		var max_l = max(0, level_grid_container.size.y - level_scroll.size.y)
		if not lvl_is_dragging:
			if abs(lvl_scroll_vel) > 3.0:
				lvl_target_scroll = clamp(lvl_target_scroll + lvl_scroll_vel * delta, 0.0, max_l)
				lvl_scroll_vel = lerp(lvl_scroll_vel, 0.0, 1.0 - exp(-7.0 * delta))
			else:
				lvl_scroll_vel = 0.0
		lvl_target_scroll = clamp(lvl_target_scroll, 0.0, max_l)
		level_scroll.scroll_vertical = int(round(lerp(float(level_scroll.scroll_vertical), lvl_target_scroll, 1.0 - exp(-22.0 * delta))))

# ── Main Menu Actions ────────────────────────────────────────────────────────

func _on_start_button_pressed():
	populate_category_grid()
	main_buttons_panel.visible = false
	category_select_panel.visible = true

func _on_settings_button_pressed():
	if PopupManager:
		PopupManager.show_settings_popup(self)

# ── Category / Game Type Select Grid Logic ────────────────────────────────────

func populate_category_grid():
	for child in category_grid_container.get_children():
		child.queue_free()
		
	var categories = [
		{
			"id": "drawing_room",
			"title": "Drawing Room",
			"is_unlocked": true,
			"background": "res://assets/levels/drawing_room/menuBackground.png"
		},
		{
			"id": "basement",
			"title": "Basement",
			"is_unlocked": true,
			"background": "res://assets/levels/basement/background.png"
		},
		{
			"id": "kitchen",
			"title": "Kitchen",
			"is_unlocked": true,
			"background": "res://assets/levels/kitchen/background.png"
		},
		{
			"id": "study_room",
			"title": "Study Room",
			"is_unlocked": true,
			"background": "res://assets/levels/study_room/backgroud.png"
		},
		{
			"id": "bed_room",
			"title": "Bed Room",
			"is_unlocked": true,
			"background": "res://assets/levels/bed_room/background.png"
		},
		{
			"id": "dining_room",
			"title": "Dining Room",
			"is_unlocked": true,
			"background": "res://assets/levels/dining_room/background.png"
		},
		{
			"id": "store_room",
			"title": "Store Room",
			"is_unlocked": true,
			"background": "res://assets/levels/store_room/background.png"
		}
	]
	
	for cat_info in categories:
		var card = create_category_card(cat_info)
		category_grid_container.add_child(card)

func _on_category_scroll_gui_input(event: InputEvent):
	_handle_smooth_scroll_input(event, "cat")

func _on_level_scroll_gui_input(event: InputEvent):
	_handle_smooth_scroll_input(event, "lvl")

func _handle_smooth_scroll_input(event: InputEvent, type: String):
	var is_cat = (type == "cat")
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			if is_cat: cat_target_scroll -= 80.0
			else: lvl_target_scroll -= 80.0
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			if is_cat: cat_target_scroll += 80.0
			else: lvl_target_scroll += 80.0
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if is_cat:
					cat_is_dragging = true
					cat_has_dragged = false
					cat_drag_start_pos = event.global_position
					cat_scroll_vel = 0.0
					cat_last_drag_time = Time.get_ticks_msec()
				else:
					lvl_is_dragging = true
					lvl_has_dragged = false
					lvl_drag_start_pos = event.global_position
					lvl_scroll_vel = 0.0
					lvl_last_drag_time = Time.get_ticks_msec()
			else:
				if is_cat: cat_is_dragging = false
				else: lvl_is_dragging = false

	elif event is InputEventMouseMotion:
		if is_cat and cat_is_dragging:
			var dy = event.relative.y
			if abs(event.global_position.y - cat_drag_start_pos.y) > 10.0:
				cat_has_dragged = true
			cat_target_scroll -= dy
			var dt = max(1, Time.get_ticks_msec() - cat_last_drag_time)
			cat_scroll_vel = -dy / (float(dt) / 1000.0)
			cat_last_drag_time = Time.get_ticks_msec()
			get_viewport().set_input_as_handled()
		elif not is_cat and lvl_is_dragging:
			var dy = event.relative.y
			if abs(event.global_position.y - lvl_drag_start_pos.y) > 10.0:
				lvl_has_dragged = true
			lvl_target_scroll -= dy
			var dt = max(1, Time.get_ticks_msec() - lvl_last_drag_time)
			lvl_scroll_vel = -dy / (float(dt) / 1000.0)
			lvl_last_drag_time = Time.get_ticks_msec()
			get_viewport().set_input_as_handled()

func create_category_card(cat_info: Dictionary) -> Control:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(380, 200)
	btn.clip_contents = true
	btn.gui_input.connect(func(event): _on_category_scroll_gui_input(event))
	
	var is_unlocked = cat_info["is_unlocked"]
	
	# Solid sleek card background
	var color_rect = ColorRect.new()
	color_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	color_rect.color = Color(0.12, 0.18, 0.32, 1.0)
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(color_rect)
	
	# Image preview with overlay
	var bg_tex = TextureRect.new()
	bg_tex.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg_tex.texture = load(cat_info["background"])
	bg_tex.modulate = Color(0.7, 0.7, 0.7, 0.6)
	btn.add_child(bg_tex)
	
	# Bottom banner for title
	var banner = ColorRect.new()
	banner.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	banner.size.y = 55
	banner.position.y = 145
	banner.color = Color(0.06, 0.1, 0.2, 0.85)
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(banner)
	
	var label = Label.new()
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.text = cat_info["title"]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("outline_size", 6)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_child(label)
	
	if not is_unlocked:
		btn.disabled = true
		
		var lock_overlay = ColorRect.new()
		lock_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		lock_overlay.color = Color(0.02, 0.04, 0.08, 0.8)
		lock_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(lock_overlay)
		
		var lock_vbox = VBoxContainer.new()
		lock_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
		lock_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		lock_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lock_overlay.add_child(lock_vbox)
		
		var lock_icon = Label.new()
		lock_icon.text = "🔒"
		lock_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lock_icon.add_theme_font_size_override("font_size", 38)
		lock_vbox.add_child(lock_icon)
		
		var lock_text = Label.new()
		lock_text.text = "LOCKED"
		lock_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lock_text.add_theme_font_size_override("font_size", 14)
		lock_text.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))
		lock_vbox.add_child(lock_text)
	else:
		btn.disabled = false
		var cat_title = cat_info["title"]
		var cat_id = cat_info["id"]
		btn.pressed.connect(func():
			if not cat_has_dragged:
				_on_category_selected(cat_title, cat_id)
		)
		
	return btn

func _on_category_selected(cat_title: String, cat_id: String = "living_room"):
	current_category_title = cat_title
	if GameManager:
		GameManager.selected_category_id = cat_id
	level_header_title.text = cat_title.to_upper() + " - LEVELS"
	populate_level_grid()
	category_select_panel.visible = false
	level_select_panel.visible = true

func _on_category_back_pressed():
	category_select_panel.visible = false
	main_buttons_panel.visible = true

# ── Level Select Grid Logic (10 Levels per category) ─────────────────────────

func populate_level_grid():
	for child in level_grid_container.get_children():
		child.queue_free()
		
	var levels = get_10_levels()
	for level_info in levels:
		var card = create_level_card(level_info)
		level_grid_container.add_child(card)

func get_10_levels() -> Array:
	var levels = []
	var unlocked_num = GameManager.unlocked_level_num if GameManager else 1
	var completed_dict = GameManager.completed_levels if GameManager else {}
	
	var cat_id = GameManager.selected_category_id if (GameManager and GameManager.selected_category_id != "") else "drawing_room"
	
	for i in range(1, 11):
		var sub_id = "sub" + str(i)
		var title = "Level " + str(i)
		var full_id = cat_id + "_" + sub_id
		
		var is_unlocked = (i <= unlocked_num)
		var is_completed = completed_dict.has(full_id)
		
		levels.append({
			"id": sub_id,
			"num": i,
			"title": title,
			"is_unlocked": is_unlocked,
			"is_completed": is_completed
		})
		
	return levels

func create_level_card(level_info: Dictionary) -> Control:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(220, 140)
	btn.clip_contents = true
	btn.gui_input.connect(func(event): _on_level_scroll_gui_input(event))
	
	var is_unlocked = level_info["is_unlocked"]
	var is_completed = level_info.get("is_completed", false)
	
	# Solid sleek card background
	var color_rect = ColorRect.new()
	color_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	color_rect.color = Color(0.12, 0.18, 0.32, 1.0)
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(color_rect)
	
	# Container for Level Title, Stars and Coins
	var content_vbox = VBoxContainer.new()
	content_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	content_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	content_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(content_vbox)
	
	# Level Label
	var label = Label.new()
	label.text = level_info["title"]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_vbox.add_child(label)
	
	# 3 Star graphics using fillstart.png / emptystart.png
	var stars_hbox = HBoxContainer.new()
	stars_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	stars_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stars_hbox.add_theme_constant_override("separation", 6)
	
	var fill_tex = preload("res://assets/main/fillstart.png")
	var empty_tex = preload("res://assets/main/emptystart.png")
	
	for s in range(3):
		var star_rect = TextureRect.new()
		star_rect.custom_minimum_size = Vector2(28, 28)
		star_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		star_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		star_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		star_rect.texture = fill_tex if is_completed else empty_tex
		stars_hbox.add_child(star_rect)
		
	content_vbox.add_child(stars_hbox)
	
	if not is_unlocked:
		btn.disabled = true
		
		var lock_overlay = ColorRect.new()
		lock_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		lock_overlay.color = Color(0.02, 0.04, 0.08, 0.75)
		lock_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(lock_overlay)
		
		var lock_vbox = VBoxContainer.new()
		lock_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
		lock_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		lock_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lock_overlay.add_child(lock_vbox)
		
		var lock_icon = Label.new()
		lock_icon.text = "🔒"
		lock_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lock_icon.add_theme_font_size_override("font_size", 36)
		lock_vbox.add_child(lock_icon)
	else:
		btn.disabled = false
		var sub_id = level_info["id"]
		btn.pressed.connect(func():
			if not lvl_has_dragged:
				_on_level_selected(sub_id)
		)
		
	return btn

func _on_level_selected(sub_id: String):
	if GameManager:
		GameManager.selected_level_id = GameManager.selected_category_id
		GameManager.selected_sublevel_id = sub_id
	get_tree().change_scene_to_file("res://main/main.tscn")

func _on_level_select_back_pressed():
	level_select_panel.visible = false
	main_buttons_panel.visible = false
	populate_category_grid()
	category_select_panel.visible = true

# ── Extra Store, Daily Challenge, & Popup Suite Helpers ──────────────────────

func _setup_extra_ui() -> void:
	var coin_btn = get_node_or_null("TopBar/RightHBox/MenuCoinsBtn")
	if coin_btn:
		var coins_val: int = GameManager.coins if GameManager else 0
		coin_btn.text = " %d +" % coins_val

	if SignalHub:
		SignalHub.coins_updated.connect(func(new_bal):
			var btn = get_node_or_null("TopBar/RightHBox/MenuCoinsBtn")
			if is_instance_valid(btn):
				btn.text = " %d +" % new_bal
				pulse_coin_button()
		)

func pulse_coin_button() -> void:
	var btn = get_node_or_null("TopBar/RightHBox/MenuCoinsBtn")
	if btn:
		btn.pivot_offset = btn.size * 0.5
		var tw = btn.create_tween()
		tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.tween_property(btn, "scale", Vector2(1.25, 1.25), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(btn, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

func _open_store() -> void:
	if PopupManager:
		PopupManager.show_store_popup(self)

func _on_daily_challenge_pressed() -> void:
	if PopupManager:
		PopupManager.show_daily_challenge_popup(self)

func _on_daily_gifts_pressed() -> void:
	if PopupManager:
		PopupManager.show_daily_reward_popup(self)
