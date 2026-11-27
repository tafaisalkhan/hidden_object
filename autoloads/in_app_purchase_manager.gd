extends Node

const PRODUCT_REMOVE_ADS: String = "remove_ads"
const SAVE_PATH: String = "user://settings.cfg"

static var is_ads_removed: bool = false
static var instance: Node


func _enter_tree() -> void:
	instance = self
	load_purchase_state()


func _ready() -> void:
	if GameManager and GameManager.ads_removed:
		is_ads_removed = true
		save_purchase_state()
	elif is_ads_removed and GameManager:
		GameManager.ads_removed = true
		GameManager.save_game()

	if SignalHub:
		SignalHub.ads_removed.connect(func():
			is_ads_removed = true
			save_purchase_state()
		)

	if is_ads_removed and SignalHub:
		SignalHub.emit_on_ads_removed()


static func load_purchase_state() -> void:
	var cfg = ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		is_ads_removed = bool(cfg.get_value("iap", "remove_ads", false))
	else:
		is_ads_removed = false


static func save_purchase_state() -> void:
	var cfg = ConfigFile.new()
	cfg.load(SAVE_PATH)
	cfg.set_value("iap", "remove_ads", is_ads_removed)
	cfg.save(SAVE_PATH)


static func purchase_remove_ads(on_completed: Callable = Callable()) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var bm: Node = tree.root.get_node_or_null("BillingManager") if (tree and tree.root) else null

	if is_ads_removed or (bm != null and bm.has_method("is_remove_ads_owned") and bm.is_remove_ads_owned()):
		is_ads_removed = true
		AdManager.show_toast("Ads are already permanently removed!")
		if on_completed.is_valid():
			on_completed.call(true)
		return

	if bm != null and bm.has_method("purchase_remove_ads"):
		if on_completed.is_valid() and bm.has_signal("remove_ads_purchase_changed"):
			var one_shot: Callable
			one_shot = func(owned: bool):
				if bm.remove_ads_purchase_changed.is_connected(one_shot):
					bm.remove_ads_purchase_changed.disconnect(one_shot)
				on_completed.call(owned)
			bm.remove_ads_purchase_changed.connect(one_shot)
		bm.purchase_remove_ads()
		return

	if OS.get_name() != "Android":
		_set_ads_removed_active()
		if on_completed.is_valid():
			on_completed.call(true)
	else:
		AdManager.show_toast("Google Play Billing unavailable.")
		if on_completed.is_valid():
			on_completed.call(false)


static func restore_purchases(on_completed: Callable = Callable()) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var bm: Node = tree.root.get_node_or_null("BillingManager") if (tree and tree.root) else null
	if bm != null and bm.has_method("restore_purchases"):
		bm.restore_purchases(on_completed)
		return
	if on_completed.is_valid():
		on_completed.call(is_ads_removed)


static func _set_ads_removed_active() -> void:
	is_ads_removed = true
	save_purchase_state()
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.root:
		var gm = tree.root.get_node_or_null("GameManager")
		if gm:
			gm.ads_removed = true
			gm.save_game()
		var bm = tree.root.get_node_or_null("BillingManager")
		if bm:
			bm.remove_ads_owned = true
	SignalHub.emit_on_ads_removed()
	AdManager.show_toast("Ads permanently removed! Thank you!")
