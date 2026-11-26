extends Node

func _ready():
	print("\n=======================================================")
	print("--- Running Hidden Object Monetization & Anti-Suspension Verification ---")
	print("=======================================================")
	var passed := 0
	var total := 0

	# Test 1: GameManager & Economy
	total += 1
	var gm = get_node_or_null("/root/GameManager")
	if gm != null:
		var init_coins: int = gm.coins
		gm.add_coins(50)
		var has_added: bool = (gm.coins == init_coins + 50)
		var spent: bool = gm.spend_coins(30)
		var has_spent: bool = spent and (gm.coins == init_coins + 20)
		if has_added and has_spent:
			print("[PASS] Test 1: GameManager economy & coin tracking functional")
			passed += 1
		else:
			print("[FAIL] Test 1: Coin math incorrect")
	else:
		print("[FAIL] Test 1: GameManager not found in root")

	# Test 2: BillingManager Products
	total += 1
	var bm = get_node_or_null("/root/BillingManager")
	if bm != null:
		var has_1000: bool = bm.PRODUCTS.has("coins_1000")
		var has_2000: bool = bm.PRODUCTS.has("coins_2000")
		var has_3000: bool = bm.PRODUCTS.has("coins_3000")
		var has_coffee: bool = bm.PRODUCTS.has("cofee")
		var has_remove_ads: bool = bm.PRODUCTS.has("remove_ads")
		if has_1000 and has_2000 and has_3000 and has_coffee and has_remove_ads:
			print("[PASS] Test 2: BillingManager has all 5 standardized products")
			passed += 1
		else:
			print("[FAIL] Test 2: Missing billing products")
	else:
		print("[FAIL] Test 2: BillingManager not found in root")

	# Test 3: AdManager 10 Anti-Suspension Rules
	total += 1
	var adm = get_node_or_null("/root/AdManager")
	if adm != null:
		var rule2_ok: bool = (adm.on_level_completed(1) == false) # Rule 2: Never Level 1
		adm.set_gameplay_active(true)
		var rule6_ok: bool = (adm.can_show_interstitial_now() == false) # Rule 6: No ads during gameplay
		adm.set_gameplay_active(false)
		
		# Reset tracking
		adm.levels_since_interstitial = 0
		adm.last_interstitial_unix_sec = -9999.0
		
		if rule2_ok and rule6_ok:
			print("[PASS] Test 3: AdManager enforces Rule 2 (No Lvl 1 ad) and Rule 6 (Gameplay suppression)")
			passed += 1
		else:
			print("[FAIL] Test 3: Anti-suspension rule check failed")
	else:
		print("[FAIL] Test 3: AdManager not found in root")

	# Test 4: StoreUI Scene Instantiation
	total += 1
	var store_scene = load("res://scenes/ui_screens/store_ui.tscn")
	if store_scene:
		var store = store_scene.instantiate()
		add_child(store)
		var items_container = store.get_node_or_null("Center/FrameBox/Panel/Layout/Scroll/Items")
		if items_container and items_container.get_child_count() == 5:
			print("[PASS] Test 4: StoreUI instantiated successfully with 5 items")
			passed += 1
		else:
			print("[FAIL] Test 4: StoreUI child count mismatch")
		store.queue_free()
	else:
		print("[FAIL] Test 4: Failed to load store_ui.tscn")

	# Test 5: PopupManager Streak Logic
	total += 1
	var pm = get_node_or_null("/root/PopupManager")
	if pm != null:
		var days: int = pm._days_between("2026-11-20", "2026-11-26")
		if days == 6:
			print("[PASS] Test 5: PopupManager 7-day streak calendar logic verified")
			passed += 1
		else:
			print("[FAIL] Test 5: Days calculation mismatch: %d" % days)
	else:
		print("[FAIL] Test 5: PopupManager not found in root")

	print("\n=== VERIFICATION RESULT: %d/%d PASSED ===" % [passed, total])
	if passed == total:
		print("ALL CHECKS PASSED PERFECTLY!\n")
		get_tree().quit(0)
	else:
		print("SOME CHECKS FAILED.\n")
		get_tree().quit(1)
