extends CanvasLayer

@onready var frame_box: Control = $Dimmer/Center/FrameBox
@onready var buy_btn: Button = $Dimmer/Center/FrameBox/Panel/VBox/BuyBtn
@onready var close_btn: Button = $Dimmer/Center/FrameBox/CloseBtn

func _ready() -> void:
	close_btn.pressed.connect(_close)
	buy_btn.pressed.connect(_on_buy_pressed)
	_refresh_price()
	if BillingManager:
		if BillingManager.has_signal("prices_updated"):
			BillingManager.prices_updated.connect(_refresh_price)
		BillingManager.coin_purchase_changed.connect(func(prod_id: String, _coins: int):
			if prod_id == "cofee" and is_instance_valid(self):
				if PopupManager and PopupManager.has_method("play_flying_coins_effect"):
					PopupManager.play_flying_coins_effect(self, buy_btn.global_position + buy_btn.size * 0.5, Vector2.ZERO, func():
						if is_instance_valid(self):
							_close()
					)
				else:
					_close()
		)
	_animate_in()

func _refresh_price() -> void:
	var price := "$1.99"
	if BillingManager and BillingManager.has_method("get_product_price"):
		price = BillingManager.get_product_price("cofee", "$1.99")
	buy_btn.text = "BUY COFFEE • %s" % price

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

func _on_buy_pressed() -> void:
	if BillingManager:
		BillingManager.purchase_coffee()
		if OS.get_name() == "Android":
			_close()
	else:
		_close()
