extends Node

signal billing_connected(connected: bool)
signal coin_purchase_changed(product_id: String, coin_amount: int)
signal remove_ads_purchase_changed(owned: bool)

const REMOVE_ADS_PRODUCT_ID := "remove_ads"
const COFFEE_PRODUCT_ID := "cofee"

const PRODUCT_COIN_AMOUNTS := {
	"coins_1000": {"coins": 1000, "price": "$0.99"},
	"coins_2000": {"coins": 2000, "price": "$1.29"},
	"coins_3000": {"coins": 3000, "price": "$1.99"},
	"cofee": {"coins": 300, "price": "$1.49"},
	"remove_ads": {"coins": 0, "price": "$4.99"}
}
const PRODUCTS := PRODUCT_COIN_AMOUNTS

var remove_ads_owned: bool = false:
	set(value):
		remove_ads_owned = value
		if GameManager:
			if "ads_removed" in GameManager:
				GameManager.ads_removed = value
			if GameManager.has_method("save_data"):
				GameManager.save_data()
			elif GameManager.has_method("save_game"):
				GameManager.save_game()
		remove_ads_purchase_changed.emit(value)
		SignalHub.emit_on_ads_removed()

var product_prices: Dictionary = {
	"coins_1000": "$0.99",
	"coins_2000": "$1.29",
	"coins_3000": "$1.99",
	"cofee": "$1.49",
	"remove_ads": "$4.99"
}

var plugin: Object = null

func _ready() -> void:
	if GameManager and "ads_removed" in GameManager:
		remove_ads_owned = GameManager.ads_removed
	if Engine.has_singleton("GodotGooglePlayBilling"):
		plugin = Engine.get_singleton("GodotGooglePlayBilling")
		_connect_signals()
		plugin.startConnection()
	elif Engine.has_singleton("SpiderBilling"):
		plugin = Engine.get_singleton("SpiderBilling")
		_connect_signals()
	else:
		billing_connected.emit(false)

func _connect_signals() -> void:
	if plugin == null:
		return
	if plugin.has_signal("connected"):
		plugin.connect("connected", Callable(self, "_on_billing_connected"))
	if plugin.has_signal("purchases_updated"):
		plugin.connect("purchases_updated", Callable(self, "_on_purchases_updated"))
	if plugin.has_signal("sku_details_query_completed"):
		plugin.connect("sku_details_query_completed", Callable(self, "_on_sku_details_query_completed"))

func _on_billing_connected() -> void:
	billing_connected.emit(true)
	if plugin != null and plugin.has_method("querySkuDetails"):
		plugin.querySkuDetails(PRODUCT_COIN_AMOUNTS.keys(), "inapp")
	if plugin != null and plugin.has_method("queryPurchases"):
		plugin.queryPurchases("inapp")

func is_remove_ads_owned() -> bool:
	return remove_ads_owned or (GameManager != null and GameManager.ads_removed)

func purchase_product(product_id: String) -> bool:
	if plugin != null and plugin.has_method("purchase"):
		var response = plugin.purchase(product_id)
		return response == OK or response == null or response == true
	# Desktop / debug simulation fallback
	if OS.is_debug_build() or OS.get_name() != "Android":
		_grant_product(product_id)
		return true
	return false

func purchase_coffee() -> bool:
	return purchase_product(COFFEE_PRODUCT_ID)

func purchase_remove_ads() -> bool:
	return purchase_product(REMOVE_ADS_PRODUCT_ID)

func _grant_product(product_id: String) -> void:
	if product_id == REMOVE_ADS_PRODUCT_ID:
		remove_ads_owned = true
		if AdManager and AdManager.has_method("hide_banner"):
			AdManager.hide_banner()
	elif product_id == COFFEE_PRODUCT_ID:
		if GameManager:
			GameManager.add_coins(300)
		coin_purchase_changed.emit(product_id, 300)
	elif PRODUCT_COIN_AMOUNTS.has(product_id):
		var amount: int = PRODUCT_COIN_AMOUNTS[product_id]["coins"]
		if GameManager:
			GameManager.add_coins(amount)
		coin_purchase_changed.emit(product_id, amount)

func _on_purchases_updated(purchases: Array) -> void:
	for purchase in purchases:
		var sku: String = str(purchase.get("sku", ""))
		if sku.is_empty() and purchase.has("products"):
			var prods: Array = purchase.get("products", [])
			if not prods.is_empty():
				sku = str(prods[0])
		if sku == REMOVE_ADS_PRODUCT_ID:
			remove_ads_owned = true
		elif sku == COFFEE_PRODUCT_ID:
			if GameManager:
				GameManager.add_coins(300)
			coin_purchase_changed.emit(sku, 300)
			if plugin != null and plugin.has_method("consumePurchase"):
				plugin.consumePurchase(purchase.get("purchase_token", ""))
		elif PRODUCT_COIN_AMOUNTS.has(sku):
			var amount: int = PRODUCT_COIN_AMOUNTS[sku]["coins"]
			if GameManager:
				GameManager.add_coins(amount)
			coin_purchase_changed.emit(sku, amount)
			if plugin != null and plugin.has_method("consumePurchase"):
				plugin.consumePurchase(purchase.get("purchase_token", ""))

func _on_sku_details_query_completed(sku_details: Array) -> void:
	for detail in sku_details:
		var sku: String = str(detail.get("sku", ""))
		var price: String = str(detail.get("price", ""))
		if not sku.is_empty() and not price.is_empty():
			product_prices[sku] = price
