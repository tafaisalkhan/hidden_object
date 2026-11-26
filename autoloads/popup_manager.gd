extends Node

const GAME_FONT: Font = preload("res://assets/fonts/LuckiestGuy-Regular.ttf")
const COIN_TEXTURE: Texture2D = preload("res://assets/main/coin_icon.png")
const BUTTON_TEX: Texture2D = preload("res://assets/main/button.png")

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

# =================== GAME THEME STYLES (MIDNIGHT NAVY & GOLD) ===================

func style_game_dialog(panel: Panel, border_color := Color("#ffd54f")) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.09, 0.17, 0.96) # Dark fantasy midnight navy
	sb.border_color = border_color # Rich gold border
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(24)
	sb.shadow_size = 18
	sb.shadow_offset = Vector2(0, 10)
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.65)
	sb.anti_aliasing = true
	panel.add_theme_stylebox_override("panel", sb)

func style_primary_button(btn: Button, font_size: int = 22, font_color := Color.WHITE) -> void:
	var sb_norm := StyleBoxTexture.new()
	sb_norm.texture = BUTTON_TEX
	sb_norm.texture_margin_left = 15.0
	sb_norm.texture_margin_top = 15.0
	sb_norm.texture_margin_right = 15.0
	sb_norm.texture_margin_bottom = 15.0

	var sb_hov := StyleBoxTexture.new()
	sb_hov.texture = BUTTON_TEX
	sb_hov.texture_margin_left = 15.0
	sb_hov.texture_margin_top = 15.0
	sb_hov.texture_margin_right = 15.0
	sb_hov.texture_margin_bottom = 15.0
	sb_hov.modulate_color = Color(1.1, 1.1, 1.2, 1.0)

	var sb_press := StyleBoxTexture.new()
	sb_press.texture = BUTTON_TEX
	sb_press.texture_margin_left = 15.0
	sb_press.texture_margin_top = 15.0
	sb_press.texture_margin_right = 15.0
	sb_press.texture_margin_bottom = 15.0
	sb_press.modulate_color = Color(0.7, 0.7, 0.8, 1.0)

	btn.add_theme_stylebox_override("normal", sb_norm)
	btn.add_theme_stylebox_override("hover", sb_hov)
	btn.add_theme_stylebox_override("pressed", sb_press)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.add_theme_font_override("font", GAME_FONT)
	btn.add_theme_font_size_override("font_size", font_size)
	btn.add_theme_color_override("font_color", font_color)
	btn.add_theme_color_override("font_outline_color", Color(0.0823529, 0.12549, 0.243137, 1))
	btn.add_theme_constant_override("outline_size", 6)
	_wire_button_juice(btn)

func style_skyblue_button(btn: Button) -> void:
	style_primary_button(btn, 22, Color.WHITE)

func style_gold_button(btn: Button) -> void:
	style_primary_button(btn, 22, Color("#fff9c4"))

func style_secondary_button(btn: Button) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.18, 0.28, 0.85) # Slate navy glass
	sb.border_color = Color(0.4, 0.5, 0.65, 0.7) # Soft border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(16)
	btn.add_theme_stylebox_override("normal", sb)

	var sb_hov := sb.duplicate() as StyleBoxFlat
	sb_hov.bg_color = Color(0.18, 0.25, 0.38, 0.95)
	sb_hov.border_color = Color(0.6, 0.7, 0.85, 1.0)
	btn.add_theme_stylebox_override("hover", sb_hov)
	btn.add_theme_stylebox_override("pressed", sb)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.add_theme_font_override("font", GAME_FONT)
	btn.add_theme_font_size_override("font_size", 16)
	btn.add_theme_color_override("font_color", Color("#dce6f2"))
	_wire_button_juice(btn)

func make_game_close_button(pos: Vector2) -> Button:
	var btn := Button.new()
	btn.text = "✕"
	btn.position = pos
	btn.size = Vector2(42, 42)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.85, 0.22, 0.22, 0.9)
	sb.border_color = Color("#ffd54f") # Rich gold border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(21)
	btn.add_theme_stylebox_override("normal", sb)
	var sb_hov := sb.duplicate() as StyleBoxFlat
	sb_hov.bg_color = Color(0.95, 0.30, 0.30, 1.0)
	btn.add_theme_stylebox_override("hover", sb_hov)
	btn.add_theme_stylebox_override("pressed", sb)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.add_theme_font_override("font", GAME_FONT)
	btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_color_override("font_color", Color.WHITE)
	_wire_button_juice(btn)
	return btn

func _create_dimmer(parent: Node) -> ColorRect:
	var dimmer := ColorRect.new()
	dimmer.color = Color(0.047, 0.082, 0.161, 0.88) # Rich dark navy dimmer matching main menu and game over HUD
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
	style_game_dialog(panel, Color("#ffd54f"))
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
	eyebrow.add_theme_color_override("font_color", Color("#81d4fa"))
	panel.add_child(eyebrow)

	var title := Label.new()
	title.text = "Enjoying Difference Find?"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(20, 48)
	title.size = Vector2(420, 44)
	title.add_theme_font_override("font", GAME_FONT)
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color("#ffd54f"))
	title.add_theme_color_override("font_outline_color", Color(0.0823529, 0.12549, 0.243137, 1))
	title.add_theme_constant_override("outline_size", 6)
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
	desc.add_theme_color_override("font_color", Color("#e0e8f5"))
	desc.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	desc.add_theme_constant_override("outline_size", 2)
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
	style_game_dialog(panel, Color("#ffd54f"))
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
	eyebrow.add_theme_color_override("font_color", Color("#81d4fa"))
	panel.add_child(eyebrow)

	var title := Label.new()
	title.text = "Share With Friends 🔗"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(20, 48)
	title.size = Vector2(420, 44)
	title.add_theme_font_override("font", GAME_FONT)
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color("#ffd54f"))
	title.add_theme_color_override("font_outline_color", Color(0.0823529, 0.12549, 0.243137, 1))
	title.add_theme_constant_override("outline_size", 6)
	panel.add_child(title)

	var desc := Label.new()
	desc.text = "Challenge your friends to spot the hidden differences!\nShare the game link and see who solves it fastest."
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc.position = Vector2(30, 105)
	desc.size = Vector2(400, 75)
	desc.add_theme_font_override("font", GAME_FONT)
	desc.add_theme_font_size_override("font_size", 15)
	desc.add_theme_color_override("font_color", Color("#e0e8f5"))
	desc.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	desc.add_theme_constant_override("outline_size", 2)
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
	style_game_dialog(panel, Color("#ffd54f"))
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
	eyebrow.add_theme_color_override("font_color", Color("#81d4fa"))
	panel.add_child(eyebrow)

	var title := Label.new()
	title.text = "Buy Us A Coffee ☕"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(20, 48)
	title.size = Vector2(420, 44)
	title.add_theme_font_override("font", GAME_FONT)
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color("#ffd54f"))
	title.add_theme_color_override("font_outline_color", Color(0.0823529, 0.12549, 0.243137, 1))
	title.add_theme_constant_override("outline_size", 6)
	panel.add_child(title)

	var desc := Label.new()
	desc.text = "Support the development of Difference Find!\nGet +300 Bonus Coins as a warm thank-you gift."
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc.position = Vector2(30, 105)
	desc.size = Vector2(400, 75)
	desc.add_theme_font_override("font", GAME_FONT)
	desc.add_theme_font_size_override("font_size", 15)
	desc.add_theme_color_override("font_color", Color("#e0e8f5"))
	desc.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	desc.add_theme_constant_override("outline_size", 2)
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
	style_game_dialog(panel, Color("#ffd54f"))
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
	eyebrow.add_theme_color_override("font_color", Color("#81d4fa"))
	panel.add_child(eyebrow)

	var title := Label.new()
	title.text = "Remove All Ads 🚫"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(20, 48)
	title.size = Vector2(420, 44)
	title.add_theme_font_override("font", GAME_FONT)
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color("#ffd54f"))
	title.add_theme_color_override("font_outline_color", Color(0.0823529, 0.12549, 0.243137, 1))
	title.add_theme_constant_override("outline_size", 6)
	panel.add_child(title)

	var desc := Label.new()
	desc.text = "Enjoy pure detective rooms without banners or interstitials!\nOne-time purchase unlocks permanently ad-free gameplay."
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc.position = Vector2(30, 105)
	desc.size = Vector2(400, 75)
	desc.add_theme_font_override("font", GAME_FONT)
	desc.add_theme_font_size_override("font_size", 15)
	desc.add_theme_color_override("font_color", Color("#e0e8f5"))
	desc.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	desc.add_theme_constant_override("outline_size", 2)
	panel.add_child(desc)

	var buy_btn := Button.new()
	buy_btn.text = "🚫 REMOVE ADS ($4.99)"
	buy_btn.size = Vector2(350, 58)
	buy_btn.position = Vector2(55, 220)
	style_primary_button(buy_btn, 22, Color("#fff9c4"))
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
	style_game_dialog(panel, Color("#ffd54f"))
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
	eyebrow.add_theme_color_override("font_color", Color("#81d4fa"))
	panel.add_child(eyebrow)

	var title := Label.new()
	title.text = "7-Day Consecutive Gifts 🎁"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(20, 48)
	title.size = Vector2(440, 38)
	title.add_theme_font_override("font", GAME_FONT)
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color("#ffd54f"))
	title.add_theme_color_override("font_outline_color", Color(0.0823529, 0.12549, 0.243137, 1))
	title.add_theme_constant_override("outline_size", 6)
	panel.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Log in every day to collect free coins for hints!"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.position = Vector2(20, 86)
	subtitle.size = Vector2(440, 22)
	subtitle.add_theme_font_override("font", GAME_FONT)
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", Color("#b0bec5"))
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
			sb.bg_color = Color(0.18, 0.26, 0.40, 1.0)
			sb.set_border_width_all(3)
			sb.border_color = Color("#ffd54f") # Brilliant gold border
			sb.shadow_size = 12
			sb.shadow_color = Color(1.0, 0.85, 0.2, 0.35)
		elif is_claimed:
			sb.bg_color = Color(0.10, 0.14, 0.22, 0.9)
			sb.set_border_width_all(2)
			sb.border_color = Color("#4fc3f7")
		elif is_grand_prize:
			sb.bg_color = Color(0.20, 0.18, 0.10, 0.95)
			sb.set_border_width_all(2)
			sb.border_color = Color("#ffd54f")
		else:
			sb.bg_color = Color(0.09, 0.13, 0.21, 0.9)
			sb.set_border_width_all(2)
			sb.border_color = Color(0.25, 0.35, 0.50, 0.8)
		card.add_theme_stylebox_override("panel", sb)

		var c_width: float = card.size.x

		var day_lbl := Label.new()
		day_lbl.text = "DAY %d" % (i + 1)
		day_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		day_lbl.position = Vector2(0, 8)
		day_lbl.size = Vector2(c_width, 18)
		day_lbl.add_theme_font_override("font", GAME_FONT)
		day_lbl.add_theme_font_size_override("font_size", 12)
		day_lbl.add_theme_color_override("font_color", Color("#ffd54f") if is_today else Color("#90a4ae"))
		card.add_child(day_lbl)

		# BIG COIN ICON / BADGE
		if not is_claimed:
			var coin_rect := TextureRect.new()
			coin_rect.texture = COIN_TEXTURE
			coin_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			coin_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			coin_rect.custom_minimum_size = Vector2(40, 40)
			coin_rect.size = Vector2(40, 40)
			coin_rect.position = Vector2((c_width - 40.0) * 0.5, 28)
			card.add_child(coin_rect)
		else:
			var icon_lbl := Label.new()
			icon_lbl.text = "✓"
			icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			icon_lbl.position = Vector2(0, 28)
			icon_lbl.size = Vector2(c_width, 42)
			icon_lbl.add_theme_font_size_override("font_size", 32)
			icon_lbl.add_theme_color_override("font_color", Color("#4fc3f7"))
			card.add_child(icon_lbl)

		var reward_lbl := Label.new()
		reward_lbl.text = item["label"]
		reward_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		reward_lbl.position = Vector2(4, 76)
		reward_lbl.size = Vector2(c_width - 8, 48)
		reward_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		reward_lbl.add_theme_font_override("font", GAME_FONT)
		reward_lbl.add_theme_font_size_override("font_size", 12)
		reward_lbl.add_theme_color_override("font_color", Color.WHITE if is_today else Color("#b0bec5"))
		card.add_child(reward_lbl)

		cards_container.add_child(card)

	var claim_btn := Button.new()
	claim_btn.size = Vector2(350, 58)
	claim_btn.position = Vector2(65, 530)
	if can_claim:
		var current_reward: Dictionary = DAILY_REWARDS[streak]
		claim_btn.text = "CLAIM %s 🎁" % current_reward["label"].replace("\nGRAND PRIZE", "")
		style_gold_button(claim_btn)
		claim_btn.pressed.connect(func():
			_record_claim(streak)
			var coins_to_add: int = int(current_reward["coins"])
			var spawn_pos: Vector2 = claim_btn.global_position + claim_btn.size * 0.5
			var target_pos: Vector2 = get_top_hud_coins_position(parent)
			
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
	style_game_dialog(panel, Color("#ffd54f"))
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
	eyebrow.add_theme_color_override("font_color", Color("#81d4fa"))
	panel.add_child(eyebrow)

	var title := Label.new()
	title.text = "Fresh Mystery Rooms! 🚀"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(20, 50)
	title.size = Vector2(420, 44)
	title.add_theme_font_override("font", GAME_FONT)
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color("#ffd54f"))
	title.add_theme_color_override("font_outline_color", Color(0.0823529, 0.12549, 0.243137, 1))
	title.add_theme_constant_override("outline_size", 6)
	panel.add_child(title)

	var desc := Label.new()
	desc.text = "A brand new version of Difference Find is available on Google Play!\nUpdate now for brand new levels and performance optimizations."
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc.position = Vector2(30, 110)
	desc.size = Vector2(400, 75)
	desc.add_theme_font_override("font", GAME_FONT)
	desc.add_theme_font_size_override("font_size", 15)
	desc.add_theme_color_override("font_color", Color("#e0e8f5"))
	desc.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	desc.add_theme_constant_override("outline_size", 2)
	panel.add_child(desc)

	var update_btn := Button.new()
	update_btn.text = "UPDATE NOW 🚀"
	update_btn.size = Vector2(350, 58)
	update_btn.position = Vector2(55, 215)
	style_gold_button(update_btn)
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
	style_game_dialog(panel, Color("#ffd54f"))
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
	eyebrow.add_theme_color_override("font_color", Color("#81d4fa"))
	panel.add_child(eyebrow)

	var title := Label.new()
	title.text = "Daily Challenge 🏆"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(20, 48)
	title.size = Vector2(420, 44)
	title.add_theme_font_override("font", GAME_FONT)
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color("#ffd54f"))
	title.add_theme_color_override("font_outline_color", Color(0.0823529, 0.12549, 0.243137, 1))
	title.add_theme_constant_override("outline_size", 6)
	panel.add_child(title)

	var desc := Label.new()
	desc.text = "Complete today's mystery challenge to earn 100 Bonus Coins! 🪙\nEnjoy 100% free retries: 0 coins deducted if you fail."
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc.position = Vector2(30, 105)
	desc.size = Vector2(400, 75)
	desc.add_theme_font_override("font", GAME_FONT)
	desc.add_theme_font_size_override("font_size", 15)
	desc.add_theme_color_override("font_color", Color("#e0e8f5"))
	desc.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	desc.add_theme_constant_override("outline_size", 2)
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


# =================== FLYING COIN BURST ANIMATION TO TOP HUD ===================
func get_top_hud_coins_position(node: Node) -> Vector2:
	if is_instance_valid(node) and node.get_tree() and node.get_tree().root:
		var root = node.get_tree().root
		var upper_btn = root.find_child("CoinsBtn", true, false)
		if is_instance_valid(upper_btn) and upper_btn is Control and upper_btn.is_visible_in_tree():
			return upper_btn.global_position + upper_btn.size * 0.5
		var menu_btn = root.find_child("MenuCoinsBtn", true, false)
		if is_instance_valid(menu_btn) and menu_btn is Control and menu_btn.is_visible_in_tree():
			return menu_btn.global_position + menu_btn.size * 0.5
	if is_instance_valid(node) and node.get_viewport():
		var vp_size = node.get_viewport().get_visible_rect().size
		return Vector2(vp_size.x - 90, 42)
	return Vector2(1190, 42)

func pulse_top_hud_coins(node: Node) -> void:
	if not is_instance_valid(node) or not node.get_tree() or not node.get_tree().root:
		return
	var root = node.get_tree().root
	var upper_hud = root.find_child("UpperHUD", true, false)
	if is_instance_valid(upper_hud) and upper_hud.has_method("pulse_coin_button"):
		upper_hud.pulse_coin_button()
		return
	var menu_btn = root.find_child("MenuCoinsBtn", true, false)
	if is_instance_valid(menu_btn) and menu_btn is Control:
		menu_btn.pivot_offset = menu_btn.size * 0.5
		var tw = menu_btn.create_tween()
		tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.tween_property(menu_btn, "scale", Vector2(1.25, 1.25), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(menu_btn, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

func play_flying_coins_effect(parent: Node, from_pos: Vector2, to_pos: Vector2 = Vector2.ZERO, on_complete: Callable = Callable()) -> void:
	if not coin_animation_enabled or not is_instance_valid(parent):
		if on_complete.is_valid():
			on_complete.call()
		return

	if to_pos == Vector2.ZERO:
		to_pos = get_top_hud_coins_position(parent)

	var num_coins: int = 12
	var overlay := CanvasLayer.new()
	overlay.layer = 250
	parent.get_tree().root.add_child(overlay)

	var completed_coins: int = 0

	for i in range(num_coins):
		var coin := TextureRect.new()
		coin.texture = COIN_TEXTURE
		coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		coin.custom_minimum_size = Vector2(36, 36)
		coin.size = Vector2(36, 36)
		coin.pivot_offset = Vector2(18, 18)
		coin.position = from_pos - Vector2(18, 18)
		coin.scale = Vector2.ZERO
		coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.add_child(coin)

		var angle: float = (float(i) / float(num_coins)) * TAU + randf_range(-0.25, 0.25)
		var dist: float = randf_range(55.0, 95.0)
		var burst_pos: Vector2 = from_pos + Vector2(cos(angle), sin(angle)) * dist
		var stagger_delay: float = float(i) * 0.03

		# Curved arc control point towards to_pos
		var mid_point: Vector2 = (burst_pos + to_pos) * 0.5
		var arc_offset := Vector2(randf_range(-140.0, -40.0), randf_range(-180.0, -80.0))
		var ctrl_point: Vector2 = mid_point + arc_offset

		var tw := coin.create_tween()
		tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)

		# 1. Stagger delay
		tw.tween_interval(stagger_delay)

		# 2. Explosive radial burst
		tw.tween_property(coin, "scale", Vector2(1.2, 1.2), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(coin, "position", burst_pos - Vector2(18, 18), 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(coin, "rotation", randf_range(-0.6, 0.6), 0.16)

		# 3. Short anticipation hover
		tw.tween_interval(0.04)

		# 4. Smooth curved flight to Top HUD using quadratic bezier interpolation
		var flight_duration: float = 0.44
		tw.tween_method(func(t: float):
			if not is_instance_valid(coin):
				return
			var one_minus_t: float = 1.0 - t
			var cur_pos: Vector2 = one_minus_t * one_minus_t * burst_pos + 2.0 * one_minus_t * t * ctrl_point + t * t * to_pos
			coin.position = cur_pos - Vector2(18, 18)
			coin.rotation += 0.25
			if t > 0.7:
				var s: float = lerp(1.2, 0.4, (t - 0.7) / 0.3)
				coin.scale = Vector2(s, s)
		, 0.0, 1.0, flight_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

		# 5. Land at Top HUD
		tw.tween_callback(func():
			if is_instance_valid(coin):
				coin.queue_free()
			
			pulse_top_hud_coins(parent)
			if i % 3 == 0 and MusicManager and MusicManager.has_method("play_sfx"):
				MusicManager.play_sfx("item_found")

			completed_coins += 1
			if completed_coins >= num_coins:
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
