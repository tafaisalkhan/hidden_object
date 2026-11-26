extends CanvasLayer

@onready var frame_box = $Dimmer/Center/FrameBox
@onready var close_btn = $Dimmer/Center/FrameBox/CloseBtn
@onready var sound_btn = $Dimmer/Center/FrameBox/Panel/Margin/VBox/AudioRow/SoundToggleBtn
@onready var music_btn = $Dimmer/Center/FrameBox/Panel/Margin/VBox/AudioRow/MusicToggleBtn
@onready var remove_ads_btn = $Dimmer/Center/FrameBox/Panel/Margin/VBox/RemoveAdsBtn
@onready var rate_btn = $Dimmer/Center/FrameBox/Panel/Margin/VBox/SupportRow/RateBtn
@onready var share_btn = $Dimmer/Center/FrameBox/Panel/Margin/VBox/SupportRow/ShareBtn
@onready var coffee_btn = $Dimmer/Center/FrameBox/Panel/Margin/VBox/SupportRow/CoffeeBtn
@onready var updates_btn = $Dimmer/Center/FrameBox/Panel/Margin/VBox/ActionRow/UpdatesBtn
@onready var restore_btn = $Dimmer/Center/FrameBox/Panel/Margin/VBox/ActionRow/RestoreBtn
@onready var bottom_close_btn = $Dimmer/Center/FrameBox/Panel/Margin/VBox/BottomCloseBtn

func _ready():
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
		
	_refresh_ui()
	_animate_in()

func _animate_in():
	frame_box.pivot_offset = frame_box.size * 0.5
	frame_box.scale = Vector2(0.7, 0.7)
	frame_box.modulate.a = 0.0
	var tw = create_tween().set_parallel(true)
	tw.tween_property(frame_box, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(frame_box, "modulate:a", 1.0, 0.2)

func _close():
	var tw = create_tween().set_parallel(true)
	tw.tween_property(frame_box, "scale", Vector2(0.8, 0.8), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(frame_box, "modulate:a", 0.0, 0.15)
	tw.chain().tween_callback(queue_free)

func _refresh_ui():
	if GameManager:
		sound_btn.text = "Sound: ON" if GameManager.sound_enabled else "Sound: OFF"
		music_btn.text = "Music: ON" if GameManager.music_enabled else "Music: OFF"
	
	var ads_removed := false
	if BillingManager and BillingManager.is_remove_ads_owned():
		ads_removed = true
	elif InAppPurchaseManager and InAppPurchaseManager.is_ads_removed:
		ads_removed = true
		
	if ads_removed:
		remove_ads_btn.text = "Ads Removed"
		remove_ads_btn.disabled = true
	else:
		remove_ads_btn.text = "Remove Ads ($4.99)"
		remove_ads_btn.disabled = false

func _on_sound_toggle():
	if GameManager:
		GameManager.sound_enabled = not GameManager.sound_enabled
		_refresh_ui()

func _on_music_toggle():
	if GameManager:
		GameManager.music_enabled = not GameManager.music_enabled
		_refresh_ui()
		if MusicManager:
			if GameManager.music_enabled:
				MusicManager.play_menu_music()
			else:
				MusicManager.stop_all()

func _on_remove_ads_pressed():
	if BillingManager:
		BillingManager.purchase_remove_ads()
	elif InAppPurchaseManager:
		InAppPurchaseManager.purchase_remove_ads()

func _on_rate_pressed():
	if PopupManager:
		PopupManager.show_rate_popup(get_parent())

func _on_share_pressed():
	if PopupManager:
		PopupManager.show_share_popup(get_parent())

func _on_coffee_pressed():
	if PopupManager:
		PopupManager.show_support_coffee_popup(get_parent())

func _on_updates_pressed():
	if PopupManager:
		PopupManager.show_in_app_update_popup(get_parent())

func _on_restore_pressed():
	if BillingManager and BillingManager.has_method("_on_billing_connected"):
		BillingManager._on_billing_connected()
	elif InAppPurchaseManager and InAppPurchaseManager.has_method("restore_purchases"):
		InAppPurchaseManager.restore_purchases(func(_success: bool): _refresh_ui())
	_refresh_ui()
