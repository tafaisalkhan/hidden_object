extends Node

const PRODUCT_REMOVE_ADS: String = "remove_ads"
const SAVE_PATH: String = "user://settings.cfg"

static var is_ads_removed: bool = false
static var instance: Node


func _enter_tree() -> void:
	print("[InAppPurchaseManager] _enter_tree")
	instance = self
	load_purchase_state()


func _ready() -> void:
	print("[InAppPurchaseManager] _ready start, is_ads_removed=", is_ads_removed)
	if is_ads_removed:
		SignalHub.emit_on_ads_removed()
	_init_billing_service()
	print("[InAppPurchaseManager] _ready done")


static func load_purchase_state() -> void:
	var cfg = ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		is_ads_removed = cfg.get_value("iap", "remove_ads", false)
	else:
		is_ads_removed = false


static func save_purchase_state() -> void:
	var cfg = ConfigFile.new()
	cfg.load(SAVE_PATH) # Load existing settings if any
	cfg.set_value("iap", "remove_ads", is_ads_removed)
	cfg.save(SAVE_PATH)


func _init_billing_service() -> void:
	if Engine.has_singleton("GodotGooglePlayBilling"):
		var billing = Engine.get_singleton("GodotGooglePlayBilling")
		billing.connected.connect(func():
			billing.querySkuDetails([PRODUCT_REMOVE_ADS], "inapp")
			billing.queryPurchases("inapp") # Automatic startup check for owned purchases
		)
		billing.purchases_updated.connect(_on_purchases_updated)
		if billing.has_signal("query_purchases_response"):
			billing.query_purchases_response.connect(_on_purchases_updated)
		billing.startConnection()


func _on_purchases_updated(purchases: Array) -> void:
	for purchase in purchases:
		if (purchase.get("sku", "") == PRODUCT_REMOVE_ADS or purchase.get("product_id", "") == PRODUCT_REMOVE_ADS) and (purchase.get("purchase_state", 0) == 1 or purchase.get("is_acknowledged", false)):
			_set_ads_removed_active()


static func purchase_remove_ads(on_completed: Callable = Callable()) -> void:
	if is_ads_removed:
		AdManager.show_toast("Ads already removed!")
		if on_completed.is_valid(): on_completed.call(true)
		return
		
	if Engine.has_singleton("GodotGooglePlayBilling"):
		var billing = Engine.get_singleton("GodotGooglePlayBilling")
		billing.purchase(PRODUCT_REMOVE_ADS)
	else:
		# Editor / Desktop Simulator for testing IAP purchase flow
		_show_simulated_iap_modal(on_completed)


static func restore_purchases(on_completed: Callable = Callable()) -> void:
	print("Restoring IAP Purchases...")
	if Engine.has_singleton("GodotGooglePlayBilling"):
		var billing = Engine.get_singleton("GodotGooglePlayBilling")
		billing.queryPurchases("inapp")
	else:
		# Editor / Desktop Simulator restore test
		_set_ads_removed_active()
		AdManager.show_toast("Purchases restored successfully!")
		
	if on_completed.is_valid():
		on_completed.call(is_ads_removed)


static func _set_ads_removed_active() -> void:
	is_ads_removed = true
	save_purchase_state()
	SignalHub.emit_on_ads_removed()
	AdManager.show_toast("Ads successfully removed! Thank you!")


static func _show_simulated_iap_modal(callback: Callable) -> void:
	var tree = Engine.get_main_loop() as SceneTree
	if not tree or not tree.root: return
	
	var overlay = ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.02, 0.03, 0.08, 0.96)
	overlay.z_index = 250
	
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(box)
	
	var tag = Label.new()
	tag.text = "IN-APP PURCHASE STORE"
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1))
	tag.add_theme_font_size_override("font_size", 20)
	box.add_child(tag)
	
	var title = Label.new()
	title.text = "REMOVE ALL ADS ($4.99)"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(0.2, 1.0, 0.5))
	box.add_child(title)
	
	var desc = Label.new()
	desc.text = "Permanently remove all Interstitial Ads!\n(Rewarded Video Ads remain optional for extra hints)"
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_font_size_override("font_size", 16)
	desc.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
	box.add_child(desc)
	
	var btn_hbox = HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 16)
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(btn_hbox)
	
	var buy_btn = Button.new()
	buy_btn.text = "BUY NOW ($4.99)"
	buy_btn.custom_minimum_size = Vector2(180, 48)
	btn_hbox.add_child(buy_btn)
	
	var cancel_btn = Button.new()
	cancel_btn.text = "CANCEL"
	cancel_btn.custom_minimum_size = Vector2(120, 48)
	btn_hbox.add_child(cancel_btn)
	
	buy_btn.pressed.connect(func():
		overlay.queue_free()
		_set_ads_removed_active()
		if callback.is_valid(): callback.call(true)
	)
	
	cancel_btn.pressed.connect(func():
		overlay.queue_free()
		if callback.is_valid(): callback.call(false)
	)
	
	tree.root.add_child(overlay)
