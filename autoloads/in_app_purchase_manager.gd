extends Node

# Backward compatibility wrapper around BillingManager
static var is_ads_removed: bool = false:
	get:
		var bm = Engine.get_main_loop().root.get_node_or_null("/root/BillingManager") if Engine.get_main_loop() else null
		if bm and bm.has_method("is_remove_ads_owned"):
			return bm.is_remove_ads_owned()
		var gm = Engine.get_main_loop().root.get_node_or_null("/root/GameManager") if Engine.get_main_loop() else null
		return gm != null and gm.ads_removed

func _ready() -> void:
	if BillingManager:
		BillingManager.remove_ads_purchase_changed.connect(func(owned):
			is_ads_removed = owned
		)

func purchase_remove_ads() -> bool:
	if BillingManager:
		return BillingManager.purchase_remove_ads()
	return false

static func load_purchase_state() -> void:
	pass

static func save_purchase_state() -> void:
	pass
