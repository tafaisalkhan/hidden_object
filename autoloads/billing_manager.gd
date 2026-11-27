extends Node

signal billing_connected(connected: bool)
signal coin_purchase_changed(product_id: String, coin_amount: int)
signal remove_ads_purchase_changed(owned: bool)
signal prices_updated()
signal restore_completed(restored_count: int)

const REMOVE_ADS_PRODUCT_ID := "remove_ads"
const COFFEE_PRODUCT_ID := "cofee"

const PRODUCT_COIN_AMOUNTS := {
	"coins_1000": {"coins": 1000, "price": "$0.99"},
	"coins_2000": {"coins": 2000, "price": "$1.29"},
	"coins_3000": {"coins": 3000, "price": "$1.99"},
	"cofee": {"coins": 0, "price": "$1.99"},
	"remove_ads": {"coins": 0, "price": "$4.99"}
}
const PRODUCTS := PRODUCT_COIN_AMOUNTS

var remove_ads_owned: bool = false:
	set(value):
		if remove_ads_owned == value and (GameManager == null or GameManager.ads_removed == value):
			return
		remove_ads_owned = value
		if GameManager:
			GameManager.ads_removed = value
			GameManager.save_game()
		if InAppPurchaseManager:
			InAppPurchaseManager.is_ads_removed = value
			InAppPurchaseManager.save_purchase_state()
		if value and AdManager and AdManager.has_method("on_ads_removed_changed"):
			AdManager.on_ads_removed_changed()
		remove_ads_purchase_changed.emit(value)
		if value and SignalHub:
			SignalHub.emit_on_ads_removed()

var product_prices: Dictionary = {
	"coins_1000": "$0.99",
	"coins_2000": "$1.29",
	"coins_3000": "$1.99",
	"cofee": "$1.99",
	"remove_ads": "$4.99"
}

var plugin: Object = null
var _using_app_plugin: bool = false
var _restore_callback: Callable = Callable()

func _ready() -> void:
	if GameManager and GameManager.ads_removed:
		remove_ads_owned = true
	if Engine.has_singleton("AppPlugin"):
		plugin = Engine.get_singleton("AppPlugin")
		_using_app_plugin = true
		_connect_app_plugin_signals()
		if plugin.has_method("billing_start"):
			plugin.billing_start()
	elif Engine.has_singleton("GodotGooglePlayBilling"):
		plugin = Engine.get_singleton("GodotGooglePlayBilling")
		_using_app_plugin = false
		_connect_legacy_signals()
		if plugin.has_method("startConnection"):
			plugin.startConnection()
	elif Engine.has_singleton("SpiderBilling"):
		plugin = Engine.get_singleton("SpiderBilling")
		_using_app_plugin = false
		_connect_legacy_signals()
	else:
		billing_connected.emit(false)

func _connect_app_plugin_signals() -> void:
	if plugin == null:
		return
	if plugin.has_signal("billing_connected"):
		plugin.connect("billing_connected", Callable(self, "_on_app_billing_connected"))
	if plugin.has_signal("billing_error"):
		plugin.connect("billing_error", Callable(self, "_on_app_billing_error"))
	if plugin.has_signal("billing_prices"):
		plugin.connect("billing_prices", Callable(self, "_on_app_billing_prices"))
	if plugin.has_signal("purchase_success"):
		plugin.connect("purchase_success", Callable(self, "_on_app_purchase_success"))
	if plugin.has_signal("purchase_pending"):
		plugin.connect("purchase_pending", Callable(self, "_on_app_purchase_pending"))
	if plugin.has_signal("purchase_failed"):
		plugin.connect("purchase_failed", Callable(self, "_on_app_purchase_failed"))
	if plugin.has_signal("restore_finished"):
		plugin.connect("restore_finished", Callable(self, "_on_app_restore_finished"))

func _connect_legacy_signals() -> void:
	if plugin == null:
		return
	if plugin.has_signal("connected"):
		plugin.connect("connected", Callable(self, "_on_billing_connected"))
	if plugin.has_signal("purchases_updated"):
		plugin.connect("purchases_updated", Callable(self, "_on_purchases_updated"))
	if plugin.has_signal("sku_details_query_completed"):
		plugin.connect("sku_details_query_completed", Callable(self, "_on_sku_details_query_completed"))

func _on_app_billing_connected() -> void:
	billing_connected.emit(true)

func _on_app_billing_error(message: String) -> void:
	print("[BillingManager] ", message)
	if _restore_callback.is_valid():
		_notify_user(message)
		var cb := _restore_callback
		_restore_callback = Callable()
		cb.call(is_remove_ads_owned())

func _on_app_billing_prices(json_str: String) -> void:
	var parsed = JSON.parse_string(json_str)
	if parsed is Dictionary:
		for k in parsed.keys():
			var price_val := str(parsed[k])
			if not price_val.is_empty():
				product_prices[str(k)] = price_val
		prices_updated.emit()

func _on_app_purchase_success(product_id: String, restored: bool) -> void:
	_grant_product(product_id, restored)

func _on_app_purchase_pending(_product_id: String) -> void:
	_notify_user("Purchase is pending Google Play confirmation...")

func _on_app_purchase_failed(_product_id: String, message: String) -> void:
	if not message.is_empty():
		_notify_user(message)

func _on_app_restore_finished(restored_count: int) -> void:
	restore_completed.emit(restored_count)
	if restored_count > 0 or is_remove_ads_owned():
		_notify_user("Purchases restored successfully!")
	else:
		_notify_user("No previous purchases found on this Google account.")
	if _restore_callback.is_valid():
		var cb := _restore_callback
		_restore_callback = Callable()
		cb.call(is_remove_ads_owned())

func _on_billing_connected() -> void:
	billing_connected.emit(true)
	if plugin != null and _using_app_plugin and plugin.has_method("billing_restore"):
		plugin.billing_restore()
		return
	if plugin != null and plugin.has_method("querySkuDetails"):
		plugin.querySkuDetails(PRODUCT_COIN_AMOUNTS.keys(), "inapp")
	if plugin != null and plugin.has_method("queryPurchases"):
		plugin.queryPurchases("inapp")

func get_product_price(product_id: String, fallback: String = "") -> String:
	if product_prices.has(product_id):
		return str(product_prices[product_id])
	if PRODUCT_COIN_AMOUNTS.has(product_id):
		return str(PRODUCT_COIN_AMOUNTS[product_id]["price"])
	return fallback

func is_remove_ads_owned() -> bool:
	return remove_ads_owned or (GameManager != null and GameManager.ads_removed) or (InAppPurchaseManager != null and InAppPurchaseManager.is_ads_removed)

func purchase_product(product_id: String) -> bool:
	if product_id == REMOVE_ADS_PRODUCT_ID and is_remove_ads_owned():
		_notify_user("Ads are already permanently removed!")
		return true

	if plugin != null:
		if _using_app_plugin and plugin.has_method("billing_purchase"):
			plugin.billing_purchase(product_id)
			return true
		elif plugin.has_method("purchase"):
			var response = plugin.purchase(product_id)
			return response == OK or response == null or response == true

	# Desktop / Editor environment
	if OS.get_name() != "Android":
		_notify_user("Google Play Store is only available on Android. Purchases must be made through Google Play.")
		return false

	_notify_user("Google Play Store billing is unavailable on this device.")
	return false

func purchase_coffee() -> bool:
	return purchase_product(COFFEE_PRODUCT_ID)

func purchase_remove_ads() -> bool:
	return purchase_product(REMOVE_ADS_PRODUCT_ID)

func restore_purchases(on_completed: Callable = Callable()) -> void:
	_restore_callback = on_completed
	if plugin != null:
		if _using_app_plugin and plugin.has_method("billing_restore"):
			_notify_user("Checking Google Play purchases...")
			plugin.billing_restore()
			return
		elif plugin.has_method("queryPurchases"):
			_notify_user("Checking Google Play purchases...")
			plugin.queryPurchases("inapp")
			if _restore_callback.is_valid():
				var cb := _restore_callback
				_restore_callback = Callable()
				cb.call(is_remove_ads_owned())
			return

	if OS.get_name() != "Android":
		if GameManager:
			GameManager.load_game()
			if GameManager.ads_removed:
				remove_ads_owned = true
		if is_remove_ads_owned():
			_notify_user("Purchases restored: Ads Removed active!")
		else:
			_notify_user("No previous purchases found.")
		restore_completed.emit(1 if is_remove_ads_owned() else 0)
		if _restore_callback.is_valid():
			var cb := _restore_callback
			_restore_callback = Callable()
			cb.call(is_remove_ads_owned())
		return

	_notify_user("Google Play Store is not connected.")
	if _restore_callback.is_valid():
		var cb := _restore_callback
		_restore_callback = Callable()
		cb.call(is_remove_ads_owned())

func _grant_product(product_id: String, restored: bool = false) -> void:
	if product_id == REMOVE_ADS_PRODUCT_ID:
		remove_ads_owned = true
		if not restored:
			_notify_user("Ads permanently removed! Thank you!")
	elif product_id == COFFEE_PRODUCT_ID:
		coin_purchase_changed.emit(product_id, 0)
		_notify_user("Thank you so much for the coffee! Your support helps us build more games!")
	elif PRODUCT_COIN_AMOUNTS.has(product_id):
		var amount: int = int(PRODUCT_COIN_AMOUNTS[product_id]["coins"])
		if GameManager:
			GameManager.add_coins(amount)
		coin_purchase_changed.emit(product_id, amount)
		_notify_user("+%d Coins added to your wallet!" % amount)

func _notify_user(message: String) -> void:
	if PopupManager and PopupManager.has_method("show_toast"):
		PopupManager.show_toast(message)

func _on_purchases_updated(purchases: Array) -> void:
	for purchase in purchases:
		var sku: String = str(purchase.get("sku", ""))
		if sku.is_empty() and purchase.has("products"):
			var prods: Array = purchase.get("products", [])
			if not prods.is_empty():
				sku = str(prods[0])
		if sku == REMOVE_ADS_PRODUCT_ID:
			_grant_product(REMOVE_ADS_PRODUCT_ID, false)
		elif sku == COFFEE_PRODUCT_ID:
			_grant_product(COFFEE_PRODUCT_ID, false)
			if plugin != null and plugin.has_method("consumePurchase"):
				plugin.consumePurchase(purchase.get("purchase_token", ""))
		elif PRODUCT_COIN_AMOUNTS.has(sku):
			_grant_product(sku, false)
			if plugin != null and plugin.has_method("consumePurchase"):
				plugin.consumePurchase(purchase.get("purchase_token", ""))

func _on_sku_details_query_completed(sku_details: Array) -> void:
	for detail in sku_details:
		var sku: String = str(detail.get("sku", ""))
		var price: String = str(detail.get("price", ""))
		if not sku.is_empty() and not price.is_empty():
			product_prices[sku] = price
	prices_updated.emit()
