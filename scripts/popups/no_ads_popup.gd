extends CanvasLayer

@onready var frame_box: Control = $Dimmer/Center/FrameBox
@onready var watch_ad_btn: Button = $Dimmer/Center/FrameBox/Panel/VBox/WatchAdBtn
@onready var buy_forever_btn: Button = $Dimmer/Center/FrameBox/Panel/VBox/BuyForeverBtn
@onready var close_btn: Button = $Dimmer/Center/FrameBox/CloseBtn

func _ready() -> void:
	close_btn.pressed.connect(_close)
	watch_ad_btn.pressed.connect(_on_watch_ad_pressed)
	buy_forever_btn.pressed.connect(_on_buy_forever_pressed)

	if AdManager and AdManager.has_signal("rewarded_ready_changed"):
		AdManager.rewarded_ready_changed.connect(func(_ready_flag: bool):
			_refresh_buttons()
		)
	if BillingManager:
		BillingManager.remove_ads_purchase_changed.connect(func(owned: bool):
			if owned:
				_close()
		)
		if BillingManager.has_signal("prices_updated"):
			BillingManager.prices_updated.connect(_refresh_buttons)
	if SignalHub:
		SignalHub.ads_removed.connect(func():
			if BillingManager and BillingManager.is_remove_ads_owned():
				_close()
		)

	_refresh_buttons()
	_animate_in()

func _refresh_buttons() -> void:
	# AdMob Rule 6: Rewarded video button only shown/enabled when ad is actually loaded
	var rewarded_ok: bool = (AdManager != null and AdManager.is_rewarded_ready())
	watch_ad_btn.visible = rewarded_ok
	watch_ad_btn.disabled = not rewarded_ok

	var price_str := "$4.99"
	if BillingManager and BillingManager.has_method("get_product_price"):
		price_str = BillingManager.get_product_price("remove_ads", "$4.99")

	if BillingManager and BillingManager.is_remove_ads_owned():
		buy_forever_btn.text = "ADS REMOVED ✓"
		buy_forever_btn.disabled = true
	else:
		buy_forever_btn.text = "REMOVE FOREVER • %s" % price_str
		buy_forever_btn.disabled = false

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

func _on_watch_ad_pressed() -> void:
	if not AdManager or not AdManager.is_rewarded_ready():
		_refresh_buttons()
		return
	watch_ad_btn.disabled = true
	AdManager.show_rewarded_ad(func(success: bool):
		if not is_instance_valid(self):
			return
		if success:
			AdManager.grant_temporary_ad_removal(86400.0)
			_close()
		else:
			_refresh_buttons()
	)

func _on_buy_forever_pressed() -> void:
	if BillingManager:
		BillingManager.purchase_remove_ads()
