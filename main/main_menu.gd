extends Control

@onready var main_buttons_panel = $MainButtonsPanel
@onready var category_select_panel = $CategorySelectPanel
@onready var level_select_panel = $LevelSelectPanel
var settings_panel: Control = null

@onready var category_scroll = $CategorySelectPanel/VBox/ScrollContainer
@onready var level_scroll = $LevelSelectPanel/VBox/ScrollContainer

@onready var category_grid_container = $CategorySelectPanel/VBox/ScrollContainer/CategoryGridContainer
@onready var level_grid_container = $LevelSelectPanel/VBox/ScrollContainer/GridContainer
@onready var level_header_title = $LevelSelectPanel/VBox/HeaderTitle

var sound_toggle_btn = null
var music_toggle_btn = null
var remove_ads_btn = null
var restore_purchases_btn = null

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

var mode_select_panel: Control

func _ready():
	_build_mode_select_panel()
	SignalHub.ads_removed.connect(_update_settings_ui)
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
		if settings_panel: settings_panel.visible = false
		if GameManager.return_to_daily_screen:
			GameManager.return_to_daily_screen = false
			get_tree().call_deferred("change_scene_to_file", "res://main/daily_challenge.tscn")
			return
		
		if GameManager.is_arcade_mode:
			# Return to mode select screen instead of level select
			main_buttons_panel.visible = false
			if mode_select_panel: mode_select_panel.visible = true
			return
			
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
		if settings_panel: settings_panel.visible = false
		
	# Setup mouse and spider animated critters for the main menu background
	setup_menu_critters()
	_setup_extra_ui()
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
	# Hide critters when not on the absolute main menu screen
	var is_main = main_buttons_panel.visible or (mode_select_panel and mode_select_panel.visible)
	if has_node("CritterSprite"): $CritterSprite.visible = is_main
	if has_node("SpiderLeft"): $SpiderLeft.visible = is_main
	if has_node("SpiderRight"): $SpiderRight.visible = is_main

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

	# 3. Update spider silk threads to remain fixed at screen top
	if has_node("SpiderLeft") and $SpiderLeft.visible:
		var thread_l = $SpiderLeft.get_node_or_null("SilkThread")
		if thread_l:
			var depth = max(0.0, $SpiderLeft.position.y)
			thread_l.position.y = -depth
			thread_l.size.y = depth
	if has_node("SpiderRight") and $SpiderRight.visible:
		var thread_r = $SpiderRight.get_node_or_null("SilkThread")
		if thread_r:
			var depth = max(0.0, $SpiderRight.position.y)
			thread_r.position.y = -depth
			thread_r.size.y = depth

# â”€â”€ Main Menu Actions â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

func _on_start_button_pressed():
	main_buttons_panel.visible = false
	mode_select_panel.visible = true

func _build_mode_select_panel():
	mode_select_panel = Control.new()
	mode_select_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	mode_select_panel.visible = false
	add_child(mode_select_panel)
	
	# Transparent overlay to just block clicks underneath if needed
	var overlay = ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.02, 0.06, 0.13, 0.82)
	mode_select_panel.add_child(overlay)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	mode_select_panel.add_child(center)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	center.add_child(vbox)

	var title = Label.new()
	title.text = "CHOOSE YOUR ADVENTURE"
	title.add_theme_font_override("font", preload("res://assets/fonts/LuckiestGuy-Regular.ttf"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", Color(1, 0.8, 0.2))
	vbox.add_child(title)

	var template_btn = $MainButtonsPanel/VBoxContainer/StartButton

	var story_btn = template_btn.duplicate(0)
	_style_mode_button(story_btn, "STORY MODE", Color("36c6bd"))
	story_btn.pressed.connect(func():
		GameManager.is_daily_mode = false
		GameManager.is_arcade_mode = false
		mode_select_panel.visible = false
		populate_category_grid()
		category_select_panel.visible = true
	)
	vbox.add_child(story_btn)



	var completed_dict = GameManager.completed_levels if GameManager else {}
	var all_completed = (
		completed_dict.has("drawing_room_sub10") and 
		completed_dict.has("basement_sub5") and 
		completed_dict.has("kitchen_sub5") and 
		completed_dict.has("study_room_sub5") and 
		completed_dict.has("bed_room_sub5") and 
		completed_dict.has("dining_room_sub5") and 
		completed_dict.has("store_room_sub5")
	)

	var arcade_btn = template_btn.duplicate(0)
	_style_mode_button(arcade_btn, "ARCADE MODE", Color("ec809c"))
	if all_completed:
		arcade_btn.pressed.connect(_start_arcade_mode)
	else:
		arcade_btn.text = "ARCADE MODE (LOCKED)"
		arcade_btn.disabled = true
	vbox.add_child(arcade_btn)

	var back_btn = template_btn.duplicate(0)
	_style_mode_button(back_btn, "BACK", Color("e8d7ff"))
	back_btn.pressed.connect(func(): mode_select_panel.visible = false; main_buttons_panel.visible = true)
	vbox.add_child(back_btn)

func _style_mode_button(button: Button, label: String, accent: Color) -> void:
	button.text = label
	button.add_theme_font_override("font", preload("res://assets/fonts/LuckiestGuy-Regular.ttf"))
	button.custom_minimum_size = Vector2(530, 76)
	button.add_theme_font_size_override("font_size", 28)
	button.add_theme_color_override("font_color", accent.lightened(0.45))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color("b5bac8"))
	button.add_theme_color_override("font_outline_color", Color("291a43"))
	button.add_theme_constant_override("outline_size", 5)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var box = StyleBoxTexture.new()
		box.texture = preload("res://assets/main/button.png")
		box.texture_margin_left = 15
		box.texture_margin_right = 15
		box.texture_margin_top = 15
		box.texture_margin_bottom = 15
		if state == "hover": box.modulate_color = Color("ffffff")
		if state == "pressed": box.modulate_color = Color("c5b3d8")
		if state == "disabled": box.modulate_color = Color("555a70")
		if state == "focus": box.modulate_color = Color.TRANSPARENT
		button.add_theme_stylebox_override(state, box)

func _on_settings_button_pressed():
	if PopupManager:
		PopupManager.show_settings_popup(self)

# â”€â”€ Category / Game Type Select Grid Logic â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

func is_category_unlocked(cat_id: String, completed_dict: Dictionary) -> bool:
	match cat_id:
		"drawing_room":
			return true
		"basement":
			return int(completed_dict.get("drawing_room_sub10", 0)) > 0
		"kitchen":
			return int(completed_dict.get("basement_sub5", 0)) > 0
		"study_room":
			return int(completed_dict.get("kitchen_sub5", 0)) > 0
		"bed_room":
			return int(completed_dict.get("study_room_sub5", 0)) > 0
		"dining_room":
			return int(completed_dict.get("bed_room_sub5", 0)) > 0
		"store_room":
			return int(completed_dict.get("dining_room_sub5", 0)) > 0
		_:
			return false

func populate_category_grid():
	for child in category_grid_container.get_children():
		child.queue_free()
		
	var completed_dict = GameManager.completed_levels if GameManager else {}

	var categories = [
		{
			"id": "drawing_room",
			"title": "Drawing Room",
			"is_unlocked": is_category_unlocked("drawing_room", completed_dict),
			"background": "res://assets/levels/drawing_room/menuBackground.png"
		},
		{
			"id": "basement",
			"title": "Basement",
			"is_unlocked": is_category_unlocked("basement", completed_dict),
			"background": "res://assets/levels/basement/background.png"
		},
		{
			"id": "kitchen",
			"title": "Kitchen",
			"is_unlocked": is_category_unlocked("kitchen", completed_dict),
			"background": "res://assets/levels/kitchen/background.png"
		},
		{
			"id": "study_room",
			"title": "Study Room",
			"is_unlocked": is_category_unlocked("study_room", completed_dict),
			"background": "res://assets/levels/study_room/backgroud.png"
		},
		{
			"id": "bed_room",
			"title": "Bed Room",
			"is_unlocked": is_category_unlocked("bed_room", completed_dict),
			"background": "res://assets/levels/bed_room/background.png"
		},
		{
			"id": "dining_room",
			"title": "Dining Room",
			"is_unlocked": is_category_unlocked("dining_room", completed_dict),
			"background": "res://assets/levels/dining_room/background.png"
		},
		{
			"id": "store_room",
			"title": "Store Room",
			"is_unlocked": is_category_unlocked("store_room", completed_dict),
			"background": "res://assets/levels/store_room/background.png"
		},
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
					cat_last_drag_time = Time.get_ticks_msec()
					cat_scroll_vel = 0.0
				else:
					lvl_is_dragging = true
					lvl_has_dragged = false
					lvl_drag_start_pos = event.global_position
					lvl_last_drag_time = Time.get_ticks_msec()
					lvl_scroll_vel = 0.0
			else:
				if is_cat: cat_is_dragging = false
				else: lvl_is_dragging = false
				
	elif event is InputEventMouseMotion:
		if is_cat and cat_is_dragging:
			var dy = event.relative.y
			if event.global_position.distance_to(cat_drag_start_pos) > 6.0:
				cat_has_dragged = true
			cat_target_scroll -= dy
			var now = Time.get_ticks_msec()
			var dt = clamp((now - cat_last_drag_time) / 1000.0, 0.001, 0.1)
			cat_last_drag_time = now
			cat_scroll_vel = lerp(cat_scroll_vel, -dy / dt, 0.45)
			get_viewport().set_input_as_handled()
		elif not is_cat and lvl_is_dragging:
			var dy = event.relative.y
			if event.global_position.distance_to(lvl_drag_start_pos) > 6.0:
				lvl_has_dragged = true
			lvl_target_scroll -= dy
			var now = Time.get_ticks_msec()
			var dt = clamp((now - lvl_last_drag_time) / 1000.0, 0.001, 0.1)
			lvl_last_drag_time = now
			lvl_scroll_vel = lerp(lvl_scroll_vel, -dy / dt, 0.45)
			get_viewport().set_input_as_handled()
			
	elif event is InputEventScreenTouch:
		if event.pressed:
			if is_cat:
				cat_is_dragging = true
				cat_has_dragged = false
				cat_drag_start_pos = event.position
				cat_last_drag_time = Time.get_ticks_msec()
				cat_scroll_vel = 0.0
			else:
				lvl_is_dragging = true
				lvl_has_dragged = false
				lvl_drag_start_pos = event.position
				lvl_last_drag_time = Time.get_ticks_msec()
				lvl_scroll_vel = 0.0
		else:
			if is_cat: cat_is_dragging = false
			else: lvl_is_dragging = false
			
	elif event is InputEventScreenDrag:
		var dy = event.relative.y
		if is_cat:
			if not cat_is_dragging:
				cat_is_dragging = true
				cat_has_dragged = false
				cat_drag_start_pos = event.position
				cat_last_drag_time = Time.get_ticks_msec()
			if event.position.distance_to(cat_drag_start_pos) > 6.0:
				cat_has_dragged = true
			cat_target_scroll -= dy
			var now = Time.get_ticks_msec()
			var dt = clamp((now - cat_last_drag_time) / 1000.0, 0.001, 0.1)
			cat_last_drag_time = now
			cat_scroll_vel = lerp(cat_scroll_vel, -dy / dt, 0.45)
			get_viewport().set_input_as_handled()
		else:
			if not lvl_is_dragging:
				lvl_is_dragging = true
				lvl_has_dragged = false
				lvl_drag_start_pos = event.position
				lvl_last_drag_time = Time.get_ticks_msec()
			if event.position.distance_to(lvl_drag_start_pos) > 6.0:
				lvl_has_dragged = true
			lvl_target_scroll -= dy
			var now = Time.get_ticks_msec()
			var dt = clamp((now - lvl_last_drag_time) / 1000.0, 0.001, 0.1)
			lvl_last_drag_time = now
			lvl_scroll_vel = lerp(lvl_scroll_vel, -dy / dt, 0.45)
			get_viewport().set_input_as_handled()

func create_category_card(cat_info: Dictionary) -> Control:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(380, 180)
	btn.clip_contents = true
	btn.gui_input.connect(func(event): _on_category_scroll_gui_input(event))
	
	var is_unlocked = cat_info["is_unlocked"]
	
	# Background Image or Placeholder
	if cat_info["background"] != "" and ResourceLoader.exists(cat_info["background"]):
		var tex_rect = TextureRect.new()
		tex_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tex_rect.texture = load(cat_info["background"])
		btn.add_child(tex_rect)
	else:
		var color_rect = ColorRect.new()
		color_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		color_rect.color = Color(0.12, 0.18, 0.32, 1.0)
		color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(color_rect)
	
	# Title Banner at bottom
	var dark_bar = ColorRect.new()
	dark_bar.anchor_top = 0.65
	dark_bar.anchor_right = 1.0
	dark_bar.anchor_bottom = 1.0
	dark_bar.color = Color(0, 0, 0, 0.75)
	dark_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(dark_bar)
	
	var label = Label.new()
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.text = cat_info["title"]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("outline_size", 5)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dark_bar.add_child(label)
	
	# Lock Overlay with professional vector padlock
	if not is_unlocked:
		btn.disabled = true
		
		var lock_overlay = ColorRect.new()
		lock_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		lock_overlay.color = Color(0.02, 0.04, 0.08, 0.78)
		lock_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(lock_overlay)
		
		var lock_center = CenterContainer.new()
		lock_center.set_anchors_preset(Control.PRESET_FULL_RECT)
		lock_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lock_overlay.add_child(lock_center)
		
		var lock_vbox = VBoxContainer.new()
		lock_vbox.add_theme_constant_override("separation", 6)
		lock_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		lock_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lock_center.add_child(lock_vbox)
		
		var lock_tex = TextureRect.new()
		lock_tex.texture = preload("res://assets/main/lock_icon.svg")
		lock_tex.custom_minimum_size = Vector2(48, 56)
		lock_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		lock_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		lock_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lock_vbox.add_child(lock_tex)
		
		var lock_text = Label.new()
		lock_text.text = "LOCKED"
		lock_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lock_text.add_theme_font_override("font", preload("res://assets/fonts/LuckiestGuy-Regular.ttf"))
		lock_text.add_theme_font_size_override("font_size", 16)
		lock_text.add_theme_color_override("font_color", Color(1, 0.82, 0.3, 1))
		lock_text.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		lock_text.add_theme_constant_override("outline_size", 4)
		lock_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	GameManager.is_arcade_mode = false
	current_category_title = cat_title
	if GameManager:
		GameManager.selected_category_id = cat_id
		
	if cat_id == "arcade":
		_start_arcade_mode()
		return
		
	level_header_title.text = cat_title.to_upper() + " - LEVELS"
	populate_level_grid()
	category_select_panel.visible = false
	level_select_panel.visible = true

func _start_arcade_mode():
	GameManager.pick_next_arcade_level()
	get_tree().change_scene_to_file("res://main/main.tscn")

func _on_category_back_pressed():
	category_select_panel.visible = false
	if mode_select_panel: mode_select_panel.visible = true

# â”€â”€ Level Select Grid Logic (10 Levels per category) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

func populate_level_grid():
	for child in level_grid_container.get_children():
		child.queue_free()
		
	var levels = get_10_levels()
	for level_info in levels:
		var card = create_level_card(level_info)
		level_grid_container.add_child(card)

func get_10_levels() -> Array:
	var levels = []
	var completed_dict = GameManager.completed_levels if GameManager else {}
	
	var cat_id = GameManager.selected_category_id if (GameManager and GameManager.selected_category_id != "") else "drawing_room"
	
	var max_levels = 10
	if cat_id != "drawing_room":
		max_levels = 5
		
	for i in range(1, max_levels + 1):
		var sub_id = "sub" + str(i)
		var title = "Level " + str(i)
		var full_id = cat_id + "_" + sub_id
		
		# Level 1 of a category is unlocked ONLY if the category itself is unlocked.
		# Subsequent levels unlock if and only if the previous level is completed (> 0 stars).
		var is_unlocked = false
		if i == 1:
			is_unlocked = is_category_unlocked(cat_id, completed_dict)
		else:
			var prev_id = cat_id + "_sub" + str(i - 1)
			is_unlocked = int(completed_dict.get(prev_id, 0)) > 0
			
		var earned_stars = int(completed_dict.get(full_id, 0))
		var is_completed = earned_stars > 0
		
		levels.append({
			"id": sub_id,
			"num": i,
			"title": title,
			"is_unlocked": is_unlocked,
			"is_completed": is_completed,
			"stars": earned_stars
		})
		
	return levels

func create_level_card(level_info: Dictionary) -> Control:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(220, 140)
	btn.clip_contents = true
	btn.gui_input.connect(func(event): _on_level_scroll_gui_input(event))
	
	var is_unlocked = level_info["is_unlocked"]
	var is_completed = level_info.get("is_completed", false)
	var earned_stars = int(level_info.get("stars", 0))
	
	# Solid sleek card background (no image background)
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
	
	var star_tex = preload("res://assets/main/victory-star.png")
	
	for s in range(3):
		var star_rect = TextureRect.new()
		star_rect.custom_minimum_size = Vector2(28, 28)
		star_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		star_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		star_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		star_rect.texture = star_tex
		if s < earned_stars:
			star_rect.modulate = Color(1.0, 1.0, 1.0, 1.0)
		else:
			star_rect.modulate = Color(0.18, 0.22, 0.35, 0.55)
		stars_hbox.add_child(star_rect)
		
	content_vbox.add_child(stars_hbox)
	
	if not is_unlocked:
		btn.disabled = true
		
		var lock_overlay = ColorRect.new()
		lock_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		lock_overlay.color = Color(0.02, 0.04, 0.08, 0.78)
		lock_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(lock_overlay)
		
		var lock_center = CenterContainer.new()
		lock_center.set_anchors_preset(Control.PRESET_FULL_RECT)
		lock_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lock_overlay.add_child(lock_center)
		
		var lock_vbox = VBoxContainer.new()
		lock_vbox.add_theme_constant_override("separation", 4)
		lock_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		lock_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lock_center.add_child(lock_vbox)
		
		var lock_tex = TextureRect.new()
		lock_tex.texture = preload("res://assets/main/lock_icon.svg")
		lock_tex.custom_minimum_size = Vector2(36, 42)
		lock_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		lock_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		lock_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lock_vbox.add_child(lock_tex)
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

# â”€â”€ Settings Logic â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

func _update_settings_ui():
	if GameManager:
		if sound_toggle_btn:
			sound_toggle_btn.text = "Sound FX: ON" if GameManager.sound_enabled else "Sound FX: OFF"
		if music_toggle_btn:
			music_toggle_btn.text = "Music: ON" if GameManager.music_enabled else "Music: OFF"
	if InAppPurchaseManager and remove_ads_btn:
		if InAppPurchaseManager.is_ads_removed:
			remove_ads_btn.text = "Ads Removed"
			remove_ads_btn.disabled = true
		else:
			remove_ads_btn.text = "Remove Ads ($4.99)"
			remove_ads_btn.disabled = false

func _on_sound_toggle_pressed():
	if GameManager:
		GameManager.sound_enabled = not GameManager.sound_enabled
		sound_toggle_btn.text = "Sound FX: ON" if GameManager.sound_enabled else "Sound FX: OFF"

func _on_music_toggle_pressed():
	if GameManager:
		GameManager.music_enabled = not GameManager.music_enabled
		music_toggle_btn.text = "Music: ON" if GameManager.music_enabled else "Music: OFF"
		if MusicManager:
			if GameManager.music_enabled:
				MusicManager.play_menu_music()
			else:
				MusicManager.stop_all()

func _on_remove_ads_pressed():
	InAppPurchaseManager.purchase_remove_ads(func(success: bool):
		_update_settings_ui()
	)

func _on_restore_purchases_pressed():
	InAppPurchaseManager.restore_purchases(func(success: bool):
		_update_settings_ui()
	)

func _on_settings_close_pressed():
	settings_panel.visible = false

func setup_menu_critters():
	if has_node("CritterSprite") and has_node("CritterAnimationPlayer"):
		var mouse_sprite = $CritterSprite
		mouse_sprite.scale = Vector2(0.12, 0.12) # Scale down 724x724 frame to ~87x87 px
		mouse_sprite.visible = true
		mouse_sprite.z_index = 0
		_animate_menu_mouse(mouse_sprite, $CritterAnimationPlayer)
		
	# Setup Spiders
	if has_node("SpiderLeft") and has_node("SpiderRight") and has_node("SpiderAnimationPlayer"):
		var spider_left = $SpiderLeft
		var spider_right = $SpiderRight
		var spider_anim = $SpiderAnimationPlayer
		
		# Set size & visibility (271.5x724 frame scaled by 0.12)
		spider_left.scale = Vector2(0.12, 0.12)
		spider_right.scale = Vector2(0.12, 0.12)
		spider_left.visible = true
		spider_right.visible = true
		spider_left.z_index = 0
		spider_right.z_index = 0
		
		# Add silk threads to the spiders
		var thread_left = ColorRect.new()
		thread_left.name = "SilkThread"
		thread_left.size = Vector2(2, 800)
		thread_left.color = Color(0.85, 0.85, 0.85, 0.35)
		thread_left.position = Vector2(-1, -800)
		spider_left.add_child(thread_left)
		
		var thread_right = ColorRect.new()
		thread_right.name = "SilkThread"
		thread_right.size = Vector2(2, 800)
		thread_right.color = Color(0.85, 0.85, 0.85, 0.35)
		thread_right.position = Vector2(-1, -800)
		spider_right.add_child(thread_right)
		
		# Start crawling animation
		spider_anim.play("crawl")
		
		# Animate movements
		_animate_menu_spider(spider_left, 150, 0.0)
		_animate_menu_spider(spider_right, 1130, 4.0)

func _animate_menu_mouse(sprite: Sprite2D, anim: AnimationPlayer):
	var start_pos_left = Vector2(-100, 620)
	var idle_pos_left = Vector2(320, 620)
	var end_pos_right = Vector2(1380, 620)
	
	var start_pos_right = Vector2(1380, 620)
	var idle_pos_right = Vector2(960, 620)
	var end_pos_left = Vector2(-100, 620)
	
	sprite.position = start_pos_left
	anim.play("run")
	sprite.flip_h = false
	
	var step1 = func():
		sprite.position = start_pos_left
		sprite.flip_h = false
		anim.play("run")
		var t = create_tween()
		t.tween_property(sprite, "position", idle_pos_left, 2.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		t.tween_callback(func():
			anim.play("idle")
			get_tree().create_timer(3.0).timeout.connect(func():
				anim.play("run")
				var t2 = create_tween()
				t2.tween_property(sprite, "position", end_pos_right, 2.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
				t2.tween_callback(func():
					get_tree().create_timer(5.0).timeout.connect(func():
						sprite.position = start_pos_right
						sprite.flip_h = true
						anim.play("run")
						var t3 = create_tween()
						t3.tween_property(sprite, "position", idle_pos_right, 2.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
						t3.tween_callback(func():
							anim.play("idle")
							get_tree().create_timer(3.0).timeout.connect(func():
								anim.play("run")
								var t4 = create_tween()
								t4.tween_property(sprite, "position", end_pos_left, 2.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
								t4.tween_callback(func():
									get_tree().create_timer(5.0).timeout.connect(sprite.get_meta("step1"))
								)
							)
						)
					)
				)
			)
		)
	
	sprite.set_meta("step1", step1)
	step1.call()

func _animate_menu_spider(sprite: Sprite2D, x_pos: float, start_delay: float):
	sprite.position = Vector2(x_pos, -150)
	sprite.flip_v = false
	
	var start_step = func():
		sprite.position = Vector2(x_pos, -150)
		sprite.flip_v = false
		
		var t = create_tween()
		t.tween_property(sprite, "position", Vector2(x_pos, 180), 2.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		t.tween_callback(func():
			get_tree().create_timer(2.5).timeout.connect(func():
				sprite.flip_v = true
				var t2 = create_tween()
				t2.tween_property(sprite, "position", Vector2(x_pos, -150), 2.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
				t2.tween_callback(func():
					get_tree().create_timer(6.0).timeout.connect(sprite.get_meta("start_step"))
				)
			)
		)
		
	sprite.set_meta("start_step", start_step)
	
	if start_delay > 0.0:
		get_tree().create_timer(start_delay).timeout.connect(start_step)
	else:
		start_step.call()


# â”€â”€ Extra Store, Daily Challenge, & Popup Suite Helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

func _setup_extra_ui() -> void:
	var challenge_btn = get_node_or_null("MainButtonsPanel/VBoxContainer/SecondaryRow/DailyChallengeButton")
	if challenge_btn and not challenge_btn.pressed.is_connected(_on_daily_challenge_pressed):
		challenge_btn.pressed.connect(_on_daily_challenge_pressed)

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
	get_tree().change_scene_to_file("res://main/daily_challenge.tscn")

func _on_daily_gifts_pressed() -> void:
	if PopupManager:
		PopupManager.show_daily_reward_popup(self)
