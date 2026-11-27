extends Node

const GAME_FONT: Font = preload("res://assets/fonts/LuckiestGuy-Regular.ttf")
const COIN_TEXTURE: Texture2D = preload("res://assets/main/coin_icon.png")
const BUTTON_TEX: Texture2D = preload("res://assets/main/button.png")

const DAILY_REWARDS := [
	{"coins": 50, "label": "50 COINS"},
	{"coins": 75, "label": "75 COINS"},
	{"coins": 100, "label": "100 COINS"},
	{"coins": 150, "label": "150 COINS"},
	{"coins": 200, "label": "200 COINS"},
	{"coins": 250, "label": "250 COINS"},
	{"coins": 500, "label": "500 COINS\nGRAND PRIZE"}
]

const DAILY_SAVE_PATH := "user://hiddenobject_daily_streak.cfg"
const PLAY_STORE_URL := "https://play.google.com/store/apps/details?id=com.hiddenobject"

var support_popup_shown_this_session := false
var update_popup_shown_this_session := false
var coin_animation_enabled: bool = true
var _active_toast_layer: CanvasLayer = null

func _ready() -> void:
	if AdManager and AdManager.has_signal("in_app_update_available"):
		AdManager.in_app_update_available.connect(func(available: bool):
			if available and not update_popup_shown_this_session:
				update_popup_shown_this_session = true
				show_in_app_update_popup()
		)
	if SignalHub:
		SignalHub.item_found.connect(func(_item_name: String):
			add_daily_challenge_progress(1)
		)

func show_toast(message: String, duration: float = 2.6) -> void:
	if message.is_empty() or not get_tree() or not get_tree().root:
		return
	if is_instance_valid(_active_toast_layer):
		_active_toast_layer.queue_free()

	var layer := CanvasLayer.new()
	layer.layer = 260
	_active_toast_layer = layer

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	margin.offset_top = -120.0
	margin.offset_bottom = -32.0
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(margin)

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(center)

	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.09, 0.18, 0.96)
	sb.border_color = Color("#ffd54f")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(18)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 10
	sb.shadow_offset = Vector2(0, 4)
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var lbl := Label.new()
	lbl.text = message
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_override("font", GAME_FONT)
	lbl.add_theme_font_size_override("font_size", 17)
	lbl.add_theme_color_override("font_color", Color("#fff8e1"))
	lbl.add_theme_color_override("font_outline_color", Color(0.05, 0.08, 0.16, 1.0))
	lbl.add_theme_constant_override("outline_size", 4)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(lbl)

	panel.modulate.a = 0.0
	layer.ready.connect(func():
		var tw := panel.create_tween()
		tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.tween_property(panel, "modulate:a", 1.0, 0.18)
		tw.tween_interval(duration)
		tw.tween_property(panel, "modulate:a", 0.0, 0.25)
		tw.tween_callback(func():
			if is_instance_valid(layer):
				layer.queue_free()
		)
	)
	get_tree().root.add_child.call_deferred(layer)

func open_popup_animated(popup_root: Control, bg: Control) -> void:
	var target_size := popup_root.size if popup_root.size != Vector2.ZERO else popup_root.custom_minimum_size
	popup_root.pivot_offset = target_size * 0.5
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
	var target_size := popup_root.size if popup_root.size != Vector2.ZERO else popup_root.custom_minimum_size
	popup_root.pivot_offset = target_size * 0.5
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
	sb.bg_color = Color(0.06, 0.09, 0.17, 0.96)
	sb.border_color = border_color
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
	sb.bg_color = Color(0.12, 0.18, 0.28, 0.85)
	sb.border_color = Color(0.4, 0.5, 0.65, 0.7)
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
	btn.text = "X"
	btn.position = pos
	btn.size = Vector2(42, 42)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.85, 0.22, 0.22, 0.9)
	sb.border_color = Color("#ffd54f")
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
	dimmer.color = Color(0.047, 0.082, 0.161, 0.88)
	dimmer.size = parent.get_viewport().get_visible_rect().size
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(dimmer)
	return dimmer

# =================== RANDOM SUPPORT POPUP ===================
func show_random_support_popup(parent: Node) -> void:
	if support_popup_shown_this_session:
		return
	support_popup_shown_this_session = true
	var pool: Array[String] = ["rate", "share", "coffee"]
	if AdManager == null or not AdManager.is_ad_free():
		pool.append("no_ads")
	var choice: String = pool[randi() % pool.size()]
	match choice:
		"rate": show_rate_popup(parent)
		"share": show_share_popup(parent)
		"coffee": show_support_coffee_popup(parent)
		"no_ads": show_no_ads_today_popup(parent)

# =================== POPUP INSTANTIATION SUITE ===================

func show_rate_popup(parent: Node = null) -> void:
	_spawn_popup_scene("res://scenes/popups/rate_popup.tscn", parent)

func show_share_popup(parent: Node = null) -> void:
	_spawn_popup_scene("res://scenes/popups/share_popup.tscn", parent)

func show_support_coffee_popup(parent: Node = null) -> void:
	_spawn_popup_scene("res://scenes/popups/coffee_popup.tscn", parent)

func show_no_ads_today_popup(parent: Node = null) -> void:
	_spawn_popup_scene("res://scenes/popups/no_ads_popup.tscn", parent)

func show_daily_reward_popup(parent: Node = null) -> void:
	_spawn_popup_scene("res://scenes/popups/daily_reward_popup.tscn", parent)

func show_daily_challenge_popup(parent: Node = null) -> void:
	_spawn_popup_scene("res://scenes/popups/daily_challenge_popup.tscn", parent)

func show_store_popup(parent: Node = null) -> void:
	_spawn_popup_scene("res://scenes/popups/store_popup.tscn", parent)

func show_settings_popup(parent: Node = null) -> void:
	_spawn_popup_scene("res://scenes/popups/settings_popup.tscn", parent)

func can_claim_daily_reward() -> bool:
	return _can_claim_today()

func show_in_app_update_popup(parent: Node = null) -> void:
	var target: Node = parent if is_instance_valid(parent) else (get_tree().root if get_tree() else null)
	_spawn_popup_scene("res://scenes/popups/update_popup.tscn", target)

func _spawn_popup_scene(scene_path: String, parent: Node = null) -> Node:
	var target = parent if is_instance_valid(parent) else get_tree().current_scene
	if not is_instance_valid(target) and get_tree().root:
		target = get_tree().root
	var scene = load(scene_path)
	if scene and is_instance_valid(target):
		var inst = scene.instantiate()
		# Prevent duplicate stacking of the exact same popup
		var existing = target.get_node_or_null(NodePath(inst.name))
		if is_instance_valid(existing) and not existing.is_queued_for_deletion():
			inst.free()
			return existing
		target.add_child(inst)
		return inst
	return null

func claim_daily_reward(_caller: Node = null) -> int:
	if not _can_claim_today():
		return 0
	var state := get_streak_state()
	var active_idx: int = int(state["active_idx"])
	var reward_coins: int = [50, 75, 100, 150, 200, 250, 500][active_idx]
	_record_claim(int(state["streak_days"]))
	if GameManager:
		GameManager.add_coins(reward_coins)
	return reward_coins

func get_daily_challenge_progress() -> int:
	var cfg := ConfigFile.new()
	if cfg.load(DAILY_SAVE_PATH) == OK:
		var today_str := _get_today_str()
		if cfg.get_value("challenge", "date", "") == today_str:
			return int(cfg.get_value("challenge", "progress", 0))
	return 0

func add_daily_challenge_progress(amount: int = 1) -> void:
	var cfg := ConfigFile.new()
	cfg.load(DAILY_SAVE_PATH)
	var today_str := _get_today_str()
	if cfg.get_value("challenge", "date", "") != today_str:
		cfg.set_value("challenge", "date", today_str)
		cfg.set_value("challenge", "progress", 0)
		cfg.set_value("challenge", "completed", false)
	var cur = int(cfg.get_value("challenge", "progress", 0)) + amount
	cfg.set_value("challenge", "progress", cur)
	cfg.save(DAILY_SAVE_PATH)

func is_daily_challenge_completed() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(DAILY_SAVE_PATH) == OK:
		var today_str := _get_today_str()
		if cfg.get_value("challenge", "date", "") == today_str:
			return bool(cfg.get_value("challenge", "completed", false))
	return false

func claim_daily_challenge(_caller: Node = null) -> int:
	if is_daily_challenge_completed():
		return 0
	var cfg := ConfigFile.new()
	cfg.load(DAILY_SAVE_PATH)
	var today_str := _get_today_str()
	cfg.set_value("challenge", "date", today_str)
	cfg.set_value("challenge", "completed", true)
	cfg.save(DAILY_SAVE_PATH)
	var reward = 150
	if GameManager:
		GameManager.add_coins(reward)
	return reward

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
	parent.get_tree().root.add_child.call_deferred(overlay)

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

		var mid_point: Vector2 = (burst_pos + to_pos) * 0.5
		var arc_offset := Vector2(randf_range(-140.0, -40.0), randf_range(-180.0, -80.0))
		var ctrl_point: Vector2 = mid_point + arc_offset

		var tw := coin.create_tween()
		tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)

		tw.tween_interval(stagger_delay)
		tw.tween_property(coin, "scale", Vector2(1.2, 1.2), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(coin, "position", burst_pos - Vector2(18, 18), 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(coin, "rotation", randf_range(-0.6, 0.6), 0.16)
		tw.tween_interval(0.04)

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

func get_streak_state() -> Dictionary:
	var cfg := ConfigFile.new()
	var streak_days: int = 0
	var last_date: String = ""
	if cfg.load(DAILY_SAVE_PATH) == OK:
		last_date = str(cfg.get_value("streak", "last_claim_date", ""))
		streak_days = maxi(0, int(cfg.get_value("streak", "current_streak", 0)))
	var today := _get_today_str()
	if last_date == today:
		# Already claimed today: active_idx is the card just claimed today
		var claimed_idx: int = (maxi(1, streak_days) - 1) % 7
		return {"streak_days": maxi(1, streak_days), "can_claim": false, "active_idx": claimed_idx}
	if not last_date.is_empty() and _days_between(last_date, today) > 1:
		streak_days = 0
		cfg.set_value("streak", "current_streak", 0)
		cfg.save(DAILY_SAVE_PATH)
	return {"streak_days": streak_days, "can_claim": true, "active_idx": streak_days % 7}

func _load_streak() -> int:
	var state := get_streak_state()
	return int(state["active_idx"])

func _can_claim_today() -> bool:
	var state := get_streak_state()
	return bool(state["can_claim"])

func _record_claim(previous_streak_days: int) -> void:
	var cfg := ConfigFile.new()
	cfg.load(DAILY_SAVE_PATH)
	var new_streak: int = previous_streak_days + 1
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
