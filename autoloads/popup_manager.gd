extends Node

const GAME_FONT: Font = preload("res://assets/fonts/LuckiestGuy-Regular.ttf")

const DAILY_REWARDS := [
	{"coins": 20, "label": "20 COINS"},
	{"coins": 30, "label": "30 COINS"},
	{"coins": 40, "label": "40 COINS"},
	{"coins": 50, "label": "50 COINS"},
	{"coins": 60, "label": "60 COINS"},
	{"coins": 80, "label": "80 COINS"},
	{"coins": 150, "label": "150 COINS\nGRAND PRIZE"}
]

const DAILY_SAVE_PATH := "user://hiddenobject_daily_streak.cfg"
const PLAY_STORE_URL := "https://play.google.com/store/apps/details?id=com.finddifference.inimage"

var support_popup_shown_this_session := false
var coin_animation_enabled: bool = true

func open_popup_animated(popup_root: Control, bg: Control) -> void:
	popup_root.pivot_offset = popup_root.size * 0.5
	popup_root.scale = Vector2.ZERO
	if bg:
		bg.modulate.a = 0.0
	var tw := popup_root.create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.set_parallel(true)
	tw.tween_property(popup_root, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if bg:
		tw.tween_property(bg, "modulate:a", 1.0, 0.22)

func close_popup_animated(popup_root: Control, bg: Control, on_done: Callable = Callable()) -> void:
	popup_root.pivot_offset = popup_root.size * 0.5
	var tw := popup_root.create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.set_parallel(true)
	tw.tween_property(popup_root, "scale", Vector2.ZERO, 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if bg:
		tw.tween_property(bg, "modulate:a", 0.0, 0.20)
	tw.chain().tween_callback(func():
		if on_done.is_valid():
			on_done.call()
		if is_instance_valid(popup_root):
			popup_root.queue_free()
		if is_instance_valid(bg):
			bg.queue_free()
	)

func _wire_button_juice(btn: Button) -> void:
	btn.pivot_offset = btn.size * 0.5
	btn.button_down.connect(func():
		btn.pivot_offset = btn.size * 0.5
		var tw := btn.create_tween()
		tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.tween_property(btn, "scale", Vector2(0.95, 0.95), 0.06).set_trans(Tween.TRANS_QUAD)
	)
	btn.button_up.connect(func():
		var tw := btn.create_tween()
		tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.tween_property(btn, "scale", Vector2.ONE, 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	)

# =================== SKY BLUE THEME STYLES ===================

func style_game_dialog(panel: Panel, border_color := Color("#29a8ec")) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#f0faff") # Crisp luminous sky blue card
	sb.border_color = border_color # Sky blue border
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(24)
	sb.shadow_size = 14
	sb.shadow_offset = Vector2(0, 8)
	sb.shadow_color = Color(0.04, 0.16, 0.28, 0.40)
	sb.anti_aliasing = true
	panel.add_theme_stylebox_override("panel", sb)

func _button_style_3d(fill: Color, border: Color, shadow_size: int = 7, shadow_y: int = 5) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(4)
	style.set_corner_radius_all(20)
	style.shadow_color = Color(0.04, 0.16, 0.28, 0.40)
	style.shadow_size = shadow_size
	style.shadow_offset = Vector2(0, shadow_y)
	style.anti_aliasing = true
	return style

func style_skyblue_button(btn: Button) -> void:
	var fill := Color("#1ea4e9") # Vibrant Sky Blue
	var dark := Color("#026aa7") # Deep oceanic shadow
	btn.add_theme_stylebox_override("normal", _button_style_3d(fill, dark, 7, 5))
	btn.add_theme_stylebox_override("hover", _button_style_3d(fill.lightened(0.12), dark, 9, 6))
	btn.add_theme_stylebox_override("pressed", _button_style_3d(fill.darkened(0.12), dark, 2, 2))
	btn.add_theme_font_override("font", GAME_FONT)
	btn.add_theme_font_size_override("font_size", 22)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_shadow_color", Color(0.02, 0.1, 0.2, 0.5))
	btn.add_theme_constant_override("shadow_offset_x", 1)
	btn.add_theme_constant_override("shadow_offset_y", 2)
	_wire_button_juice(btn)

func style_gold_button(btn: Button) -> void:
	var fill := Color("#fbc02d") # Warm sun gold
	var dark := Color("#b26a00")
	btn.add_theme_stylebox_override("normal", _button_style_3d(fill, dark, 7, 5))
	btn.add_theme_stylebox_override("hover", _button_style_3d(fill.lightened(0.12), dark, 9, 6))
	btn.add_theme_stylebox_override("pressed", _button_style_3d(fill.darkened(0.12), dark, 2, 2))
	btn.add_theme_font_override("font", GAME_FONT)
	btn.add_theme_font_size_override("font_size", 22)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_shadow_color", Color(0.2, 0.1, 0.0, 0.5))
	btn.add_theme_constant_override("shadow_offset_x", 1)
	btn.add_theme_constant_override("shadow_offset_y", 1)
	_wire_button_juice(btn)

func style_secondary_button(btn: Button) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#d8f0fc") # Soft sky tint
	sb.border_color = Color("#90caf9") # Delicate sky border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(16)
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb)
	btn.add_theme_font_override("font", GAME_FONT)
	btn.add_theme_font_size_override("font_size", 16)
	btn.add_theme_color_override("font_color", Color("#0d47a1")) # Deep royal blue text
	_wire_button_juice(btn)

func make_game_close_button(pos: Vector2) -> Button:
	var btn := Button.new()
	btn.text = "✕"
	btn.position = pos
	btn.size = Vector2(42, 42)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#ef5350")
	sb.border_color = Color("#c62828")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(21)
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb)
	btn.add_theme_font_override("font", GAME_FONT)
	btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_color_override("font_color", Color.WHITE)
	_wire_button_juice(btn)
	return btn

func _create_dimmer(parent: Node) -> ColorRect:
	var dimmer := ColorRect.new()
	dimmer.color = Color(0.06, 0.18, 0.32, 0.76) # Atmospheric sky-navy dimmer
	dimmer.size = parent.get_viewport().get_visible_rect().size
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(dimmer)
	return dimmer

# =================== RANDOM SUPPORT POPUP ===================
func show_random_support_popup(parent: Node) -> void:
	if support_popup_shown_this_session:
		return
	support_popup_shown_this_session = true
	var pool := ["rate", "share", "coffee", "no_ads"]
	var choice: String = pool[randi() % pool.size()]
	match choice:
		"rate": show_rate_popup(parent)
		"share": show_share_popup(parent)
		"coffee": show_support_coffee_popup(parent)
		"no_ads": show_no_ads_today_popup(parent)

# =================== 1. RATE POPUP ===================
func show_rate_popup(parent: Node) -> void:
	var bg := _create_dimmer(parent)
	var panel := Panel.new()
	panel.size = Vector2(460, 420)
	panel.position = (parent.get_viewport().get_visible_rect().size - panel.size) * 0.5
	style_game_dialog(panel, Color("#29a8ec"))
	parent.add_child(panel)

	var close_btn := make_game_close_button(Vector2(panel.size.x - 56, 14))
	close_btn.pressed.connect(func(): close_popup_animated(panel, bg))
	panel.add_child(close_btn)

	var eyebrow := Label.new()
	eyebrow.text = "YOUR FEEDBACK MATTERS"
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eyebrow.position = Vector2(20, 24)
	eyebrow.size = Vector2(420, 20)
	eyebrow.add_theme_font_override("font", GAME_FONT)
	eyebrow.add_theme_font_size_override("font_size", 14)
	eyebrow.add_theme_color_override("font_color", Color("#0288d1"))
	panel.add_child(eyebrow)

	var title := Label.new()
	title.text = "Enjoying Difference Find?"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(20, 48)
	title.size = Vector2(420, 44)
	title.add_theme_font_override("font", GAME_FONT)
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color("#0d47a1"))
	panel.add_child(title)

	var stars := Label.new()
	stars.text = "★ ★ ★ ★ ★"
	stars.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stars.position = Vector2(20, 96)
	stars.size = Vector2(420, 32)
	stars.add_theme_font_size_override("font_size", 28)
	stars.add_theme_color_override("font_color", Color("#fbc02d"))
	panel.add_child(stars)

	var desc := Label.new()
	desc.text = "Your rating helps us craft new mystery detective rooms!\nRate us 5 stars on Google Play to support future updates."
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc.position = Vector2(30, 140)
	desc.size = Vector2(400, 70)
	desc.add_theme_font_override("font", GAME_FONT)
	desc.add_theme_font_size_override("font_size", 15)
	desc.add_theme_color_override("font_color", Color("#37474f"))
	panel.add_child(desc)

	var rate_btn := Button.new()
	rate_btn.text = "★ RATE 5 STARS ★"
	rate_btn.size = Vector2(350, 58)
	rate_btn.position = Vector2(55, 230)
	style_gold_button(rate_btn)
	rate_btn.pressed.connect(func():
		var ad_mgr = parent.get_node_or_null("/root/AdManager")
		if ad_mgr and ad_mgr.has_method("request_rate_app"):
			ad_mgr.request_rate_app()
		else:
			OS.shell_open(PLAY_STORE_URL)
		close_popup_animated(panel, bg)
	)
	panel.add_child(rate_btn)

	var later_btn := Button.new()
	later_btn.text = "Maybe Later"
	later_btn.size = Vector2(220, 46)
	later_btn.position = Vector2(120, 320)
	style_secondary_button(later_btn)
	later_btn.pressed.connect(func(): close_popup_animated(panel, bg))
	panel.add_child(later_btn)

	open_popup_animated(panel, bg)

# =================== 2. SHARE POPUP ===================
func show_share_popup(parent: Node) -> void:
	var bg := _create_dimmer(parent)
	var panel := Panel.new()
	panel.size = Vector2(460, 420)
	panel.position = (parent.get_viewport().get_visible_rect().size - panel.size) * 0.5
	style_game_dialog(panel, Color("#29a8ec"))
	parent.add_child(panel)

	var close_btn := make_game_close_button(Vector2(panel.size.x - 56, 14))
	close_btn.pressed.connect(func(): close_popup_animated(panel, bg))
	panel.add_child(close_btn)

	var eyebrow := Label.new()
	eyebrow.text = "SPREAD THE MYSTERY"
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eyebrow.position = Vector2(20, 24)
	eyebrow.size = Vector2(420, 20)
	eyebrow.add_theme_font_override("font", GAME_FONT)
	eyebrow.add_theme_font_size_override("font_size", 14)
	eyebrow.add_theme_color_override("font_color", Color("#0288d1"))
	panel.add_child(eyebrow)

	var title := Label.new()
	title.text = "Share With Friends 🔗"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(20, 48)
	title.size = Vector2(420, 44)
	title.add_theme_font_override("font", GAME_FONT)
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color("#0d47a1"))
	panel.add_child(title)

	var desc := Label.new()
	desc.text = "Challenge your friends to spot the hidden differences!\nShare the game link and see who solves it fastest."
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc.position = Vector2(30, 105)
	desc.size = Vector2(400, 75)
	desc.add_theme_font_override("font", GAME_FONT)
	desc.add_theme_font_size_override("font_size", 15)
	desc.add_theme_color_override("font_color", Color("#37474f"))
	panel.add_child(desc)

	var share_btn := Button.new()
	share_btn.text = "🔗 SHARE GAME LINK"
	share_btn.size = Vector2(350, 58)
	share_btn.position = Vector2(55, 220)
	style_skyblue_button(share_btn)
	share_btn.pressed.connect(func():
		var ad_mgr = parent.get_node_or_null("/root/AdManager")
		if ad_mgr and ad_mgr.has_method("request_share_game"):
			ad_mgr.request_share_game()
		else:
			DisplayServer.clipboard_set(PLAY_STORE_URL)
		close_popup_animated(panel, bg)
	)
	panel.add_child(share_btn)

	var close_btn2 := Button.new()
	close_btn2.text = "Close"
	close_btn2.size = Vector2(200, 46)
	close_btn2.position = Vector2(130, 315)
	style_secondary_button(close_btn2)
	close_btn2.pressed.connect(func(): close_popup_animated(panel, bg))
	panel.add_child(close_btn2)

	open_popup_animated(panel, bg)

# =================== 3. BUY COFFEE POPUP ($1.49) ===================
func show_support_coffee_popup(parent: Node) -> void:
	var bg := _create_dimmer(parent)
	var panel := Panel.new()
	panel.size = Vector2(460, 430)
	panel.position = (parent.get_viewport().get_visible_rect().size - panel.size) * 0.5
	style_game_dialog(panel, Color("#29a8ec"))
	parent.add_child(panel)

	var close_btn := make_game_close_button(Vector2(panel.size.x - 56, 14))
	close_btn.pressed.connect(func(): close_popup_animated(panel, bg))
	panel.add_child(close_btn)

	var eyebrow := Label.new()
	eyebrow.text = "DEVELOPER SUPPORT"
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eyebrow.position = Vector2(20, 24)
	eyebrow.size = Vector2(420, 20)
	eyebrow.add_theme_font_override("font", GAME_FONT)
	eyebrow.add_theme_font_size_override("font_size", 14)
	eyebrow.add_theme_color_override("font_color", Color("#0288d1"))
	panel.add_child(eyebrow)

	var title := Label.new()
	title.text = "Buy Us A Coffee ☕"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(20, 48)
	title.size = Vector2(420, 44)
	title.add_theme_font_override("font", GAME_FONT)
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color("#0d47a1"))
	panel.add_child(title)

	var desc := Label.new()
	desc.text = "Support the development of Difference Find!\nGet +300 Bonus Coins as a warm thank-you gift."
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc.position = Vector2(30, 105)
	desc.size = Vector2(400, 75)
	desc.add_theme_font_override("font", GAME_FONT)
	desc.add_theme_font_size_override("font_size", 15)
	desc.add_theme_color_override("font_color", Color("#37474f"))
	panel.add_child(desc)

	var buy_btn := Button.new()
	buy_btn.text = "☕ BUY COFFEE ($1.49)"
	buy_btn.size = Vector2(350, 58)
	buy_btn.position = Vector2(55, 220)
	style_gold_button(buy_btn)
	buy_btn.pressed.connect(func():
		var billing = parent.get_node_or_null("/root/BillingManager")
		if billing and billing.has_method("purchase_coffee"):
			billing.purchase_coffee()
		close_popup_animated(panel, bg)
	)
	panel.add_child(buy_btn)

	var close_btn2 := Button.new()
	close_btn2.text = "No Thanks"
	close_btn2.size = Vector2(200, 46)
	close_btn2.position = Vector2(130, 315)
	style_secondary_button(close_btn2)
	close_btn2.pressed.connect(func(): close_popup_animated(panel, bg))
	panel.add_child(close_btn2)

	open_popup_animated(panel, bg)

# =================== 4. REMOVE ADS POPUP ($4.99) ===================
func show_no_ads_today_popup(parent: Node) -> void:
	var bg := _create_dimmer(parent)
	var panel := Panel.new()
	panel.size = Vector2(460, 430)
	panel.position = (parent.get_viewport().get_visible_rect().size - panel.size) * 0.5
	style_game_dialog(panel, Color("#29a8ec"))
	parent.add_child(panel)

	var close_btn := make_game_close_button(Vector2(panel.size.x - 56, 14))
	close_btn.pressed.connect(func(): close_popup_animated(panel, bg))
	panel.add_child(close_btn)

	var eyebrow := Label.new()
	eyebrow.text = "UNINTERRUPTED EXPERIENCE"
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eyebrow.position = Vector2(20, 24)
	eyebrow.size = Vector2(420, 20)
	eyebrow.add_theme_font_override("font", GAME_FONT)
	eyebrow.add_theme_font_size_override("font_size", 14)
	eyebrow.add_theme_color_override("font_color", Color("#0288d1"))
	panel.add_child(eyebrow)

	var title := Label.new()
	title.text = "Remove All Ads 🚫"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(20, 48)
	title.size = Vector2(420, 44)
	title.add_theme_font_override("font", GAME_FONT)
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color("#0d47a1"))
	panel.add_child(title)

	var desc := Label.new()
	desc.text = "Enjoy pure detective rooms without banners or interstitials!\nOne-time purchase unlocks permanently ad-free gameplay."
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc.position = Vector2(30, 105)
	desc.size = Vector2(400, 75)
	desc.add_theme_font_override("font", GAME_FONT)
	desc.add_theme_font_size_override("font_size", 15)
	desc.add_theme_color_override("font_color", Color("#37474f"))
	panel.add_child(desc)

	var buy_btn := Button.new()
	buy_btn.text = "🚫 REMOVE ADS ($4.99)"
	buy_btn.size = Vector2(350, 58)
	buy_btn.position = Vector2(55, 220)
	style_skyblue_button(buy_btn)
	buy_btn.pressed.connect(func():
		var billing = parent.get_node_or_null("/root/BillingManager")
		if billing and billing.has_method("purchase_remove_ads"):
			billing.purchase_remove_ads()
		close_popup_animated(panel, bg)
	)
	panel.add_child(buy_btn)

	var close_btn2 := Button.new()
	close_btn2.text = "Keep Ads"
	close_btn2.size = Vector2(200, 46)
	close_btn2.position = Vector2(130, 315)
	style_secondary_button(close_btn2)
	close_btn2.pressed.connect(func(): close_popup_animated(panel, bg))
	panel.add_child(close_btn2)

	open_popup_animated(panel, bg)

# =================== 5. 7-DAY CONSECUTIVE DAILY REWARDS ===================
func show_daily_reward_popup(parent: Node) -> void:
	var streak: int = _load_streak()
	var can_claim: bool = _can_claim_today()

	var bg := _create_dimmer(parent)
	var panel := Panel.new()
	panel.size = Vector2(480, 620)
	panel.position = (parent.get_viewport().get_visible_rect().size - panel.size) * 0.5
	style_game_dialog(panel, Color("#29a8ec"))
	parent.add_child(panel)

	var close_btn := make_game_close_button(Vector2(panel.size.x - 56, 14))
	close_btn.pressed.connect(func(): close_popup_animated(panel, bg))
	panel.add_child(close_btn)

	var eyebrow := Label.new()
	eyebrow.text = "DAILY REWARD CALENDAR"
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eyebrow.position = Vector2(20, 24)
	eyebrow.size = Vector2(440, 20)
	eyebrow.add_theme_font_override("font", GAME_FONT)
	eyebrow.add_theme_font_size_override("font_size", 14)
	eyebrow.add_theme_color_override("font_color", Color("#0288d1"))
	panel.add_child(eyebrow)

	var title := Label.new()
	title.text = "7-Day Consecutive Gifts 🎁"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(20, 48)
	title.size = Vector2(440, 38)
	title.add_theme_font_override("font", GAME_FONT)
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color("#0d47a1"))
	panel.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Log in every day to collect free coins for hints!"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.position = Vector2(20, 86)
	subtitle.size = Vector2(440, 22)
	subtitle.add_theme_font_override("font", GAME_FONT)
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", Color("#455a64"))
	panel.add_child(subtitle)

	var cards_container := Control.new()
	cards_container.position = Vector2(20, 116)
	cards_container.size = Vector2(440, 390)
	panel.add_child(cards_container)

	for i in range(7):
		var item: Dictionary = DAILY_REWARDS[i]
		var card := Panel.new()
		var is_grand_prize: bool = (i == 6)
		var is_today: bool = (i == streak) and can_claim
		var is_claimed: bool = (i < streak) or (i == streak and not can_claim)

		if i < 4:
			card.size = Vector2(100, 134)
			card.position = Vector2(i * 112, 0)
		elif i == 4:
			card.size = Vector2(100, 134)
			card.position = Vector2(0, 146)
		elif i == 5:
			card.size = Vector2(100, 134)
			card.position = Vector2(112, 146)
		elif i == 6:
			card.size = Vector2(212, 134)
			card.position = Vector2(224, 146)

		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(18)
		if is_today:
			sb.bg_color = Color("#ffffff")
			sb.set_border_width_all(3)
			sb.border_color = Color("#0288d1") # Vibrant sky blue
			sb.shadow_size = 10
			sb.shadow_color = Color(0.02, 0.54, 0.85, 0.35)
		elif is_claimed:
			sb.bg_color = Color("#e1f5fe")
			sb.set_border_width_all(2)
			sb.border_color = Color("#29b6f6")
		elif is_grand_prize:
			sb.bg_color = Color("#fffde7")
			sb.set_border_width_all(2)
			sb.border_color = Color("#fbc02d")
		else:
			sb.bg_color = Color("#e8f4fc")
			sb.set_border_width_all(2)
			sb.border_color = Color("#cbe5f6")
		card.add_theme_stylebox_override("panel", sb)

		var c_width: float = card.size.x

		var day_lbl := Label.new()
		day_lbl.text = "DAY %d" % (i + 1)
		day_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		day_lbl.position = Vector2(0, 8)
		day_lbl.size = Vector2(c_width, 18)
		day_lbl.add_theme_font_override("font", GAME_FONT)
		day_lbl.add_theme_font_size_override("font_size", 12)
		day_lbl.add_theme_color_override("font_color", Color("#0288d1") if is_today else Color("#546e7a"))
		card.add_child(day_lbl)

		# BIG COIN ICON (36px)
		var icon_lbl := Label.new()
		icon_lbl.text = "🪙" if not is_claimed else "✓"
		icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_lbl.position = Vector2(0, 28)
		icon_lbl.size = Vector2(c_width, 42)
		icon_lbl.add_theme_font_size_override("font_size", 36 if not is_claimed else 30)
		if is_claimed:
			icon_lbl.add_theme_color_override("font_color", Color("#0288d1"))
		card.add_child(icon_lbl)

		var reward_lbl := Label.new()
		reward_lbl.text = item["label"]
		reward_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		reward_lbl.position = Vector2(4, 76)
		reward_lbl.size = Vector2(c_width - 8, 48)
		reward_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		reward_lbl.add_theme_font_override("font", GAME_FONT)
		reward_lbl.add_theme_font_size_override("font_size", 12)
		reward_lbl.add_theme_color_override("font_color", Color("#0d47a1") if is_today else Color("#455a64"))
		card.add_child(reward_lbl)

		cards_container.add_child(card)

	var claim_btn := Button.new()
	claim_btn.size = Vector2(350, 58)
	claim_btn.position = Vector2(65, 530)
	if can_claim:
		var current_reward: Dictionary = DAILY_REWARDS[streak]
		claim_btn.text = "CLAIM %s 🎁" % current_reward["label"].replace("\nGRAND PRIZE", "")
		style_skyblue_button(claim_btn)
		claim_btn.pressed.connect(func():
			_record_claim(streak)
			var coins_to_add: int = int(current_reward["coins"])
			var target_btn: Control = parent.get_node_or_null("MenuCoinsBtn")
			if not target_btn:
				target_btn = parent.get_node_or_null("UpperHUD/MarginContainer/HBoxContainer/CoinsBtn")
			var spawn_pos: Vector2 = claim_btn.global_position + claim_btn.size * 0.5
			var target_pos: Vector2 = target_btn.global_position + target_btn.size * 0.5 if target_btn else Vector2(1150, 40)
			
			play_flying_coins_effect(parent, spawn_pos, target_pos, func():
				if GameManager:
					GameManager.add_coins(coins_to_add)
				if parent.has_method("update_coins_display"):
					parent.update_coins_display()
				close_popup_animated(panel, bg)
			)
		)
	else:
		claim_btn.text = "COME BACK TOMORROW"
		style_secondary_button(claim_btn)
		claim_btn.pressed.connect(func(): close_popup_animated(panel, bg))
	panel.add_child(claim_btn)

	open_popup_animated(panel, bg)

# =================== 6. IN-APP UPDATE POPUP ===================
func show_in_app_update_popup(parent: Node) -> void:
	var bg := _create_dimmer(parent)
	var panel := Panel.new()
	panel.size = Vector2(460, 400)
	panel.position = (parent.get_viewport().get_visible_rect().size - panel.size) * 0.5
	style_game_dialog(panel, Color("#29a8ec"))
	parent.add_child(panel)

	var close_btn := make_game_close_button(Vector2(panel.size.x - 56, 14))
	close_btn.pressed.connect(func(): close_popup_animated(panel, bg))
	panel.add_child(close_btn)

	var eyebrow := Label.new()
	eyebrow.text = "NEW UPDATE AVAILABLE"
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eyebrow.position = Vector2(20, 24)
	eyebrow.size = Vector2(420, 20)
	eyebrow.add_theme_font_override("font", GAME_FONT)
	eyebrow.add_theme_font_size_override("font_size", 14)
	eyebrow.add_theme_color_override("font_color", Color("#0288d1"))
	panel.add_child(eyebrow)

	var title := Label.new()
	title.text = "Fresh Mystery Rooms! 🚀"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(20, 50)
	title.size = Vector2(420, 44)
	title.add_theme_font_override("font", GAME_FONT)
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color("#0d47a1"))
	panel.add_child(title)

	var desc := Label.new()
	desc.text = "A brand new version of Difference Find is available on Google Play!\nUpdate now for brand new levels and performance optimizations."
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc.position = Vector2(30, 110)
	desc.size = Vector2(400, 75)
	desc.add_theme_font_override("font", GAME_FONT)
	desc.add_theme_font_size_override("font_size", 15)
	desc.add_theme_color_override("font_color", Color("#37474f"))
	panel.add_child(desc)

	var update_btn := Button.new()
	update_btn.text = "UPDATE NOW 🚀"
	update_btn.size = Vector2(350, 58)
	update_btn.position = Vector2(55, 215)
	style_skyblue_button(update_btn)
	update_btn.pressed.connect(func():
		var ad_mgr = parent.get_node_or_null("/root/AdManager")
		if ad_mgr and ad_mgr.has_method("start_in_app_update"):
			ad_mgr.start_in_app_update()
		else:
			OS.shell_open(PLAY_STORE_URL)
		close_popup_animated(panel, bg)
	)
	panel.add_child(update_btn)

	var later_btn := Button.new()
	later_btn.text = "Maybe Later"
	later_btn.size = Vector2(200, 46)
	later_btn.position = Vector2(130, 310)
	style_secondary_button(later_btn)
	later_btn.pressed.connect(func(): close_popup_animated(panel, bg))
	panel.add_child(later_btn)

	open_popup_animated(panel, bg)

# =================== 7. DAILY CHALLENGE POPUP ===================
func show_daily_challenge_popup(parent: Node) -> void:
	var bg := _create_dimmer(parent)
	var panel := Panel.new()
	panel.size = Vector2(460, 430)
	panel.position = (parent.get_viewport().get_visible_rect().size - panel.size) * 0.5
	style_game_dialog(panel, Color("#29a8ec"))
	parent.add_child(panel)

	var close_btn := make_game_close_button(Vector2(panel.size.x - 56, 14))
	close_btn.pressed.connect(func(): close_popup_animated(panel, bg))
	panel.add_child(close_btn)

	var eyebrow := Label.new()
	eyebrow.text = "TODAY'S SPECIAL MISSION"
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eyebrow.position = Vector2(20, 24)
	eyebrow.size = Vector2(420, 20)
	eyebrow.add_theme_font_override("font", GAME_FONT)
	eyebrow.add_theme_font_size_override("font_size", 14)
	eyebrow.add_theme_color_override("font_color", Color("#0288d1"))
	panel.add_child(eyebrow)

	var title := Label.new()
	title.text = "Daily Challenge 🏆"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(20, 48)
	title.size = Vector2(420, 44)
	title.add_theme_font_override("font", GAME_FONT)
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color("#0d47a1"))
	panel.add_child(title)

	var desc := Label.new()
	desc.text = "Complete today's mystery challenge to earn 100 Bonus Coins! 🪙\nEnjoy 100% free retries: 0 coins deducted if you fail."
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc.position = Vector2(30, 105)
	desc.size = Vector2(400, 75)
	desc.add_theme_font_override("font", GAME_FONT)
	desc.add_theme_font_size_override("font_size", 15)
	desc.add_theme_color_override("font_color", Color("#37474f"))
	panel.add_child(desc)

	var play_btn := Button.new()
	play_btn.text = "START CHALLENGE 🏆"
	play_btn.size = Vector2(350, 58)
	play_btn.position = Vector2(55, 220)
	style_gold_button(play_btn)
	play_btn.pressed.connect(func():
		close_popup_animated(panel, bg, func():
			if GameManager:
				GameManager.is_daily_challenge_mode = true
				GameManager.selected_category_id = "drawing_room"
				GameManager.selected_sublevel_id = "sub1"
			parent.get_tree().change_scene_to_file("res://main/main.tscn")
		)
	)
	panel.add_child(play_btn)

	var close_btn2 := Button.new()
	close_btn2.text = "Close"
	close_btn2.size = Vector2(200, 46)
	close_btn2.position = Vector2(130, 315)
	style_secondary_button(close_btn2)
	close_btn2.pressed.connect(func(): close_popup_animated(panel, bg))
	panel.add_child(close_btn2)

	open_popup_animated(panel, bg)


# =================== FLYING COIN BURST ANIMATION ===================
func play_flying_coins_effect(parent: Node, from_pos: Vector2, to_pos: Vector2, on_complete: Callable = Callable()) -> void:
	if not coin_animation_enabled:
		if on_complete.is_valid():
			on_complete.call()
		return

	var num_coins: int = 8
	var overlay := CanvasLayer.new()
	overlay.layer = 200
	parent.add_child(overlay)

	for i in range(num_coins):
		var coin_lbl := Label.new()
		coin_lbl.text = "🪙"
		coin_lbl.add_theme_font_size_override("font_size", 34)
		coin_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		coin_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		coin_lbl.custom_minimum_size = Vector2(40, 40)
		coin_lbl.position = from_pos - Vector2(20, 20)
		coin_lbl.scale = Vector2.ZERO
		overlay.add_child(coin_lbl)

		var burst := Vector2(randf_range(-70, 70), randf_range(-50, 30))
		var delay: float = float(i) * 0.04
		var tw := coin_lbl.create_tween()
		tw.tween_interval(delay)
		tw.tween_property(coin_lbl, "scale", Vector2(1.25, 1.25), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(coin_lbl, "position", from_pos + burst, 0.12)
		tw.tween_property(coin_lbl, "position", to_pos - Vector2(20, 20), 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(coin_lbl, "scale", Vector2(0.5, 0.5), 0.38)

		var is_last: bool = (i == num_coins - 1)
		tw.tween_callback(func():
			if is_instance_valid(coin_lbl):
				coin_lbl.queue_free()
			if is_last:
				if is_instance_valid(overlay):
					overlay.queue_free()
				if on_complete.is_valid():
					on_complete.call()
		)

# =================== DAILY STREAK HELPERS ===================
func _get_today_str() -> String:
	var dt := Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [dt.year, dt.month, dt.day]

func _load_streak() -> int:
	var cfg := ConfigFile.new()
	if cfg.load(DAILY_SAVE_PATH) == OK:
		var last_date: String = cfg.get_value("streak", "last_claim_date", "")
		var streak: int = int(cfg.get_value("streak", "current_streak", 0))
		var today := _get_today_str()
		if last_date == today:
			return streak % 7
		if not last_date.is_empty():
			var days_diff := _days_between(last_date, today)
			if days_diff > 1:
				streak = 0
				cfg.set_value("streak", "current_streak", 0)
				cfg.save(DAILY_SAVE_PATH)
		return streak % 7
	return 0

func _can_claim_today() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(DAILY_SAVE_PATH) == OK:
		var last_date: String = cfg.get_value("streak", "last_claim_date", "")
		return last_date != _get_today_str()
	return true

func _record_claim(claimed_streak_index: int) -> void:
	var cfg := ConfigFile.new()
	cfg.load(DAILY_SAVE_PATH)
	var new_streak: int = (claimed_streak_index + 1) % 7
	cfg.set_value("streak", "current_streak", new_streak)
	cfg.set_value("streak", "last_claim_date", _get_today_str())
	cfg.save(DAILY_SAVE_PATH)

func _days_between(date1_str: String, date2_str: String) -> int:
	var p1 := date1_str.split("-")
	var p2 := date2_str.split("-")
	if p1.size() != 3 or p2.size() != 3:
		return 999
	var d1 := Time.get_unix_time_from_datetime_dict({"year": int(p1[0]), "month": int(p1[1]), "day": int(p1[2]), "hour": 0, "minute": 0, "second": 0})
	var d2 := Time.get_unix_time_from_datetime_dict({"year": int(p2[0]), "month": int(p2[1]), "day": int(p2[2]), "hour": 0, "minute": 0, "second": 0})
	return int(round((d2 - d1) / 86400.0))
