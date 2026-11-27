extends CanvasLayer

@onready var frame_box: Control = $Dimmer/Center/FrameBox
@onready var close_btn: Button = $Dimmer/Center/FrameBox/CloseBtn
@onready var sound_btn: Button = $Dimmer/Center/FrameBox/Panel/Margin/VBox/AudioRow/SoundToggleBtn
@onready var music_btn: Button = $Dimmer/Center/FrameBox/Panel/Margin/VBox/AudioRow/MusicToggleBtn
@onready var remove_ads_btn: Button = $Dimmer/Center/FrameBox/Panel/Margin/VBox/RemoveAdsBtn
@onready var rate_btn: Button = $Dimmer/Center/FrameBox/Panel/Margin/VBox/SupportRow/RateBtn
@onready var share_btn: Button = $Dimmer/Center/FrameBox/Panel/Margin/VBox/SupportRow/ShareBtn
@onready var coffee_btn: Button = $Dimmer/Center/FrameBox/Panel/Margin/VBox/SupportRow/CoffeeBtn
@onready var updates_btn: Button = $Dimmer/Center/FrameBox/Panel/Margin/VBox/ActionRow/UpdatesBtn
@onready var restore_btn: Button = $Dimmer/Center/FrameBox/Panel/Margin/VBox/ActionRow/RestoreBtn
@onready var bottom_close_btn: Button = $Dimmer/Center/FrameBox/Panel/Margin/VBox/BottomCloseBtn

func _ready() -> void:
	close_btn.pressed.connect(_close)
	bottom_close_btn.pressed.connect(_close)
	sound_btn.pressed.connect(_on_sound_toggle)
	music_btn.pressed.connect(_on_music_toggle)
	remove_ads_btn.pressed.connect(_on_remove_ads_pressed)
	rate_btn.pressed.connect(_on_rate_pressed)
	share_btn.pressed.connect(_on_share_pressed)
	coffee_btn.pressed.connect(_on_coffee_pressed)
	updates_btn.pressed.connect(_on_updates_pressed)
	restore_btn.pressed.connect(_on_restore_pressed)

	if SignalHub:
		SignalHub.ads_removed.connect(_refresh_ui)
	if BillingManager:
		BillingManager.remove_ads_purchase_changed.connect(func(_owned): _refresh_ui())
		if BillingManager.has_signal("prices_updated"):
			BillingManager.prices_updated.connect(_refresh_ui)
		if BillingManager.has_signal("restore_completed"):
			BillingManager.restore_completed.connect(func(_cnt): _refresh_ui())

	_refresh_ui()
	_animate_in()

func _animate_in() -> void:
	var box_size := frame_box.size if frame_box.size != Vector2.ZERO else frame_box.custom_minimum_size
	frame_box.pivot_offset = box_size * 0.5
	frame_box.scale = Vector2(0.7, 0.7)
	frame_box.modulate.a = 0.0
	var tw = create_tween().set_parallel(true)
	tw.tween_property(frame_box, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(frame_box, "modulate:a", 1.0, 0.2)

func _close() -> void:
	var box_size := frame_box.size if frame_box.size != Vector2.ZERO else frame_box.custom_minimum_size
	frame_box.pivot_offset = box_size * 0.5
	var tw = create_tween().set_parallel(true)
	tw.tween_property(frame_box, "scale", Vector2(0.8, 0.8), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(frame_box, "modulate:a", 0.0, 0.15)
	tw.chain().tween_callback(queue_free)

func _refresh_ui() -> void:
	var title_lbl := get_node_or_null("Dimmer/Center/FrameBox/Panel/Margin/VBox/Title") as Label
	if title_lbl:
		var app_ver := str(ProjectSettings.get_setting("application/config/version", "v1.0.9"))
		title_lbl.text = "SETTINGS • %s" % app_ver
	if GameManager:
		sound_btn.text = "Sound: ON" if GameManager.sound_enabled else "Sound: OFF"
		music_btn.text = "Music: ON" if GameManager.music_enabled else "Music: OFF"

	var permanently_owned := false
	if BillingManager and BillingManager.is_remove_ads_owned():
		permanently_owned = true
	elif InAppPurchaseManager and InAppPurchaseManager.is_ads_removed:
		permanently_owned = true

	var price_str := "$4.99"
	if BillingManager and BillingManager.has_method("get_product_price"):
		price_str = BillingManager.get_product_price("remove_ads", "$4.99")

	if permanently_owned:
		remove_ads_btn.text = "Ads Removed ✓"
		remove_ads_btn.disabled = true
	else:
		remove_ads_btn.text = "Remove Ads (%s)" % price_str
		remove_ads_btn.disabled = false

func _on_sound_toggle() -> void:
	if GameManager:
		GameManager.sound_enabled = not GameManager.sound_enabled
		GameManager.save_game()
		_refresh_ui()

func _on_music_toggle() -> void:
	if GameManager:
		GameManager.music_enabled = not GameManager.music_enabled
		GameManager.save_game()
		_refresh_ui()
		if MusicManager:
			if GameManager.music_enabled:
				MusicManager.play_menu_music()
			else:
				MusicManager.stop_all()

func _on_remove_ads_pressed() -> void:
	if BillingManager:
		BillingManager.purchase_remove_ads()
	elif InAppPurchaseManager:
		InAppPurchaseManager.purchase_remove_ads(func(_ok: bool): _refresh_ui())

func _on_rate_pressed() -> void:
	var target_parent := get_parent()
	_close()
	if PopupManager:
		PopupManager.show_rate_popup(target_parent)

func _on_share_pressed() -> void:
	var target_parent := get_parent()
	_close()
	if PopupManager:
		PopupManager.show_share_popup(target_parent)

func _on_coffee_pressed() -> void:
	var target_parent := get_parent()
	_close()
	if PopupManager:
		PopupManager.show_support_coffee_popup(target_parent)

func _on_updates_pressed() -> void:
	var target_parent := get_parent()
	_close()
	if AdManager and AdManager.has_method("check_in_app_update"):
		AdManager.check_in_app_update()
	if PopupManager:
		PopupManager.show_in_app_update_popup(target_parent)

func _on_restore_pressed() -> void:
	if BillingManager and BillingManager.has_method("restore_purchases"):
		BillingManager.restore_purchases(func(_owned: bool):
			if is_instance_valid(self):
				_refresh_ui()
		)
	elif InAppPurchaseManager and InAppPurchaseManager.has_method("restore_purchases"):
		InAppPurchaseManager.restore_purchases(func(_owned: bool):
			if is_instance_valid(self):
				_refresh_ui()
		)
