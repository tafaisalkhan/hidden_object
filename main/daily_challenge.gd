extends Control

const HISTORY_DAYS := 14

func _ready() -> void:
	MusicManager.play_menu_music()
	AdManager.show_banner(false)
	_build_screen()

func _build_screen() -> void:
	var background = TextureRect.new()
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.texture = preload("res://assets/main/background.png")
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var shade = ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.025, 0.065, 0.13, 0.42)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var scroll = ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var margin = MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 26)
	margin.add_theme_constant_override("margin_bottom", 36)
	scroll.add_child(margin)
	var center = CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(center)
	var frame = _make_panel(Color("092a44e8"), Color("f7ca69"))
	frame.custom_minimum_size.x = 690
	center.add_child(frame)
	var frame_margin = MarginContainer.new()
	for side in ["left", "right"]:
		frame_margin.add_theme_constant_override("margin_" + side, 28)
	frame_margin.add_theme_constant_override("margin_top", 24)
	frame_margin.add_theme_constant_override("margin_bottom", 24)
	frame.add_child(frame_margin)
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 13)
	frame_margin.add_child(content)

	var title = _make_label("DAILY CHALLENGE", 40, Color("f7ca69"))
	title.add_theme_font_override("font", preload("res://assets/fonts/LuckiestGuy-Regular.ttf"))
	title.add_theme_color_override("font_outline_color", Color("4b240d"))
	title.add_theme_constant_override("outline_size", 5)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	var today = GameManager.get_today_key()
	var entry = GameManager.get_daily_level(today)
	var status = GameManager.get_daily_status(today)
	var subtitle = _make_label("A NEW HIDDEN OBJECT ROOM EVERY DAY", 17, Color("fff4d7"))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(subtitle)

	var card = _make_panel(Color("123d5e"), Color("e9b95a"))
	content.add_child(card)
	var card_margin = MarginContainer.new()
	card_margin.add_theme_constant_override("margin_left", 25)
	card_margin.add_theme_constant_override("margin_right", 25)
	card_margin.add_theme_constant_override("margin_top", 20)
	card_margin.add_theme_constant_override("margin_bottom", 20)
	card.add_child(card_margin)
	var card_content = VBoxContainer.new()
	card_content.add_theme_constant_override("separation", 10)
	card_margin.add_child(card_content)
	var art = TextureRect.new()
	art.custom_minimum_size.y = 140
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.clip_contents = true
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var art_path = _room_background(entry)
	if art_path != "" and ResourceLoader.exists(art_path):
		art.texture = load(art_path)
	card_content.add_child(art)
	var room_row = HBoxContainer.new()
	card_content.add_child(room_row)
	var room_label = _make_label(str(entry["room"]).replace("_", " ").capitalize() + "  •  Level " + str(entry["sub"]).trim_prefix("sub"), 27, Color.WHITE)
	room_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	room_row.add_child(room_label)
	room_row.add_child(_make_label(today, 18, Color("f7ca69")))
	var status_text = "Ready to play" if status == "ready" else ("Completed  •  " + str(entry.get("stars", 1)) + " stars  •  Score " + str(entry.get("score", 0)) if status == "completed" else "Played  •  Finish it today")
	card_content.add_child(_make_label(status_text, 19, Color("b9d9df")))
	var play = _make_button("PLAY TODAY'S ROOM" if status == "ready" else ("CONTINUE CHALLENGE" if status == "played" else "COMPLETED TODAY"), Color("e7b453"))
	play.disabled = status == "completed"
	play.pressed.connect(_on_play_pressed)
	card_content.add_child(play)

	var heading = _make_label("YOUR DAILY RECORD", 26, Color("f7ca69"))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(heading)
	var today_day = GameManager.get_day_number(today)
	var days_played = today_day - GameManager.daily_first_day + 1
	var record_detail = _make_label("Day " + str(days_played) + " of your adventure", 16, Color("fff4d7"))
	record_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(record_detail)
	var calendar = GridContainer.new()
	calendar.columns = 7
	calendar.add_theme_constant_override("h_separation", 7)
	calendar.add_theme_constant_override("v_separation", 7)
	content.add_child(calendar)
	var first_day = max(GameManager.daily_first_day, today_day - HISTORY_DAYS + 1)
	for day_number in range(first_day, today_day + 1):
		var day_key = Time.get_date_string_from_unix_time(day_number * 86400)
		var day_status = GameManager.get_daily_status(day_key)
		var accent = Color("489ad0")
		if day_status == "completed": accent = Color("61d7aa")
		elif day_status == "played": accent = Color("f7ca69")
		elif day_status == "missed": accent = Color("eb8a95")
		var tile = _make_panel(Color("153b56"), accent)
		tile.custom_minimum_size = Vector2(82, 66)
		calendar.add_child(tile)
		var tile_text = _make_label(day_key.substr(5) + "\n" + day_status.capitalize(), 13, Color.WHITE)
		tile_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tile_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		tile.add_child(tile_text)
	var legend_text = "Your journey starts today. Come back tomorrow for a new room!" if days_played == 1 else "Green: complete   Gold: played   Red: missed"
	var legend = _make_label(legend_text, 16, Color("bde3dd"))
	legend.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(legend)
	var back = _make_button("BACK TO MENU", Color("4db5bd"))
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://main/main_menu.tscn"))
	content.add_child(back)

func _on_play_pressed() -> void:
	if GameManager.start_daily_level():
		get_tree().change_scene_to_file("res://main/main.tscn")

func _room_background(entry: Dictionary) -> String:
	var room = str(entry["room"])
	var room_previews = {
		"drawing_room": "res://assets/levels/drawing_room/menuBackground.png",
		"basement": "res://assets/levels/basement/background.png",
		"kitchen": "res://assets/levels/kitchen/background.png",
		"study_room": "res://assets/levels/study_room/backgroud.png",
		"bed_room": "res://assets/levels/bed_room/background.png",
		"dining_room": "res://assets/levels/dining_room/background.png",
		"store_room": "res://assets/levels/store_room/background.png"
	}
	var preview = str(room_previews.get(room, ""))
	if preview != "" and ResourceLoader.exists(preview):
		return preview
	var path = "res://levels/" + str(entry["room"]) + "/sublevels.json"
	if not FileAccess.file_exists(path):
		return ""
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if data is Dictionary:
		var level: Dictionary = data.get(str(entry["sub"]), {})
		return str(level.get("background", ""))
	return ""

func _make_label(value: String, font_size: int, color: Color) -> Label:
	var label = Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _make_panel(fill: Color, border: Color) -> PanelContainer:
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2 if border.a > 0 else 0)
	style.set_corner_radius_all(18)
	panel.add_theme_stylebox_override("panel", style)
	return panel

func _make_button(value: String, accent: Color) -> Button:
	var button = Button.new()
	button.text = value
	button.add_theme_font_override("font", preload("res://assets/fonts/LuckiestGuy-Regular.ttf"))
	button.custom_minimum_size = Vector2(0, 60)
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_color_override("font_color", Color("0b2135"))
	button.add_theme_color_override("font_hover_color", Color("081b2d"))
	button.add_theme_color_override("font_disabled_color", Color("aab3be"))
	button.add_theme_color_override("font_outline_color", Color("fff2d1"))
	button.add_theme_constant_override("outline_size", 1)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var box = StyleBoxFlat.new()
		box.bg_color = accent
		if state == "hover": box.bg_color = accent.lightened(0.14)
		if state == "pressed": box.bg_color = accent.darkened(0.17)
		if state == "disabled": box.bg_color = Color("60717a")
		box.border_color = Color("fff0bc") if state != "disabled" else Color("89939a")
		box.set_border_width_all(3)
		box.set_corner_radius_all(14)
		box.shadow_color = Color(0, 0, 0, 0.3)
		box.shadow_size = 5
		box.content_margin_left = 20
		box.content_margin_right = 20
		button.add_theme_stylebox_override(state, box)
	return button
