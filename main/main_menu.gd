extends Control

@onready var main_buttons_panel = $MainButtonsPanel
@onready var category_select_panel = $CategorySelectPanel
@onready var level_select_panel = $LevelSelectPanel
@onready var settings_panel = $SettingsPanel

@onready var category_scroll = $CategorySelectPanel/VBox/ScrollContainer
@onready var level_scroll = $LevelSelectPanel/VBox/ScrollContainer

@onready var category_grid_container = $CategorySelectPanel/VBox/ScrollContainer/CategoryGridContainer
@onready var level_grid_container = $LevelSelectPanel/VBox/ScrollContainer/GridContainer
@onready var level_header_title = $LevelSelectPanel/VBox/HeaderTitle

@onready var sound_toggle_btn = $SettingsPanel/CenterContainer/VBox/SoundToggleBtn
@onready var music_toggle_btn = $SettingsPanel/CenterContainer/VBox/MusicToggleBtn
@onready var remove_ads_btn = $SettingsPanel/CenterContainer/VBox/RemoveAdsBtn
@onready var restore_purchases_btn = $SettingsPanel/CenterContainer/VBox/RestorePurchasesBtn

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
		settings_panel.visible = false
		
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
		settings_panel.visible = false

	_setup_extra_ui()
	_update_settings_ui()

	get_tree().create_timer(0.6).timeout.connect(func():
		if is_instance_valid(self) and PopupManager and PopupManager._can_claim_today():
			PopupManager.show_daily_reward_popup(self)
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
	_update_settings_ui()
	settings_panel.visible = true

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
	
	# Lock Overlay
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

# ── Settings Logic ───────────────────────────────────────────────────────────

func _update_settings_ui():
	if GameManager:
		sound_toggle_btn.text = "Sound FX: ON" if GameManager.sound_enabled else "Sound FX: OFF"
		music_toggle_btn.text = "Music: ON" if GameManager.music_enabled else "Music: OFF"
	if InAppPurchaseManager:
		if InAppPurchaseManager.is_ads_removed:
			remove_ads_btn.text = "Ads Removed ✓"
			remove_ads_btn.disabled = true
		else:
			remove_ads_btn.text = "🚫 Remove Ads ($4.99)"
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
	if BillingManager:
		BillingManager.purchase_remove_ads()
	_update_settings_ui()

func _on_restore_purchases_pressed():
	if BillingManager and BillingManager.plugin and BillingManager.plugin.has_method("queryPurchases"):
		BillingManager.plugin.queryPurchases("inapp")
	_update_settings_ui()

func _on_settings_close_pressed():
	settings_panel.visible = false


# ── Extra Store, Daily Challenge, & Popup Suite Helpers ───────────────────────

func _setup_extra_ui() -> void:
	# Top Right Coin Pill
	var coin_btn := Button.new()
	coin_btn.name = "MenuCoinsBtn"
	var coins_val: int = GameManager.coins if GameManager else 0
	coin_btn.text = "🪙 %d +" % coins_val
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.18, 0.32, 0.9)
	sb.border_color = Color("#f6d36b")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(16)
	sb.shadow_size = 4
	sb.shadow_offset = Vector2(0, 3)
	sb.shadow_color = Color(0, 0, 0, 0.25)
	coin_btn.add_theme_stylebox_override("normal", sb)
	coin_btn.add_theme_stylebox_override("hover", sb)
	coin_btn.add_theme_font_size_override("font_size", 20)
	coin_btn.custom_minimum_size = Vector2(150, 50)
	coin_btn.position = Vector2(get_viewport_rect().size.x - 170, 20)
	coin_btn.pressed.connect(_open_store)
	add_child(coin_btn)

	if SignalHub:
		SignalHub.coins_updated.connect(func(new_bal):
			if is_instance_valid(coin_btn):
				coin_btn.text = "🪙 %d +" % new_bal
		)

	# Additional menu buttons in MainButtonsPanel/VBoxContainer
	var vbox := get_node_or_null("MainButtonsPanel/VBoxContainer") as VBoxContainer
	if vbox:
		var challenge_btn := _create_menu_button("🏆 Daily Challenge", _on_daily_challenge_pressed)
		var gifts_btn := _create_menu_button("🎁 Daily Gifts", _on_daily_gifts_pressed)
		var store_btn := _create_menu_button("🛒 Store", _open_store)
		
		var settings_btn := get_node_or_null("MainButtonsPanel/VBoxContainer/SettingsButton")
		var settings_idx: int = settings_btn.get_index() if settings_btn else vbox.get_child_count()
		vbox.add_child(challenge_btn)
		vbox.move_child(challenge_btn, settings_idx)
		vbox.add_child(gifts_btn)
		vbox.move_child(gifts_btn, settings_idx + 1)
		vbox.add_child(store_btn)
		vbox.move_child(store_btn, settings_idx + 2)

	# Extra buttons in SettingsPanel
	var settings_vbox := get_node_or_null("SettingsPanel/CenterContainer/VBox") as VBoxContainer
	if settings_vbox:
		var close_btn := get_node_or_null("SettingsPanel/CenterContainer/VBox/SettingsCloseBtn")
		var close_idx: int = close_btn.get_index() if close_btn else settings_vbox.get_child_count()
		var update_btn := _create_settings_button("🚀 Check Update", func():
			if PopupManager:
				PopupManager.show_in_app_update_popup(self)
		)
		var rate_btn := _create_settings_button("★ Rate Us", func():
			if PopupManager:
				PopupManager.show_rate_popup(self)
		)
		var share_btn := _create_settings_button("🔗 Share Game", func():
			if PopupManager:
				PopupManager.show_share_popup(self)
		)
		settings_vbox.add_child(update_btn)
		settings_vbox.move_child(update_btn, close_idx)
		settings_vbox.add_child(rate_btn)
		settings_vbox.move_child(rate_btn, close_idx + 1)
		settings_vbox.add_child(share_btn)
		settings_vbox.move_child(share_btn, close_idx + 2)

func _create_menu_button(label_text: String, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.custom_minimum_size = Vector2(250, 75)
	btn.add_theme_font_size_override("font_size", 28)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.14, 0.22, 0.4, 0.95)
	sb.border_color = Color("#f6d36b")
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(18)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 4)
	sb.shadow_color = Color(0, 0, 0, 0.3)
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb)
	btn.pressed.connect(callback)
	return btn

func _create_settings_button(label_text: String, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.custom_minimum_size = Vector2(280, 50)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.add_theme_font_size_override("font_size", 20)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.14, 0.22, 0.4, 0.95)
	sb.border_color = Color("#f6d36b")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb)
	btn.pressed.connect(callback)
	return btn

func _open_store() -> void:
	var store_scene = load("res://scenes/ui_screens/store_ui.tscn")
	if store_scene:
		var store = store_scene.instantiate()
		add_child(store)

func _on_daily_challenge_pressed() -> void:
	if PopupManager:
		PopupManager.show_daily_challenge_popup(self)

func _on_daily_gifts_pressed() -> void:
	if PopupManager:
		PopupManager.show_daily_reward_popup(self)
