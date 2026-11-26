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

	# Test 5: PopupManager Streak Logic & Flying Coin Animation
	total += 1
	var pm = get_node_or_null("/root/PopupManager")
	if pm != null:
		var days: int = pm._days_between("2026-11-20", "2026-11-26")
		var target_pos: Vector2 = pm.get_top_hud_coins_position(self)
		var has_target: bool = (target_pos.x > 0 and target_pos.y > 0)
		
		# Test flying coin burst execution
		var coin_anim_done := false
		pm.play_flying_coins_effect(self, Vector2(640, 360), target_pos, func():
			coin_anim_done = true
		)
		
		if days == 6 and has_target:
			print("[PASS] Test 5: PopupManager streak logic and Top HUD coin flight targeting verified")
			passed += 1
		else:
			print("[FAIL] Test 5: Streak or coin target mismatch")
	else:
		print("[FAIL] Test 5: PopupManager not found in root")

	# Test 6: Verify MainMenu & UpperHUD Nodes exist natively in scene files
	total += 1
	var menu_scene = load("res://main/main_menu.tscn")
	var hud_scene = load("res://hud/upper_hud.tscn")
	if menu_scene and hud_scene:
		var menu = menu_scene.instantiate()
		var hud = hud_scene.instantiate()
		var has_store_btn = menu.get_node_or_null("MainButtonsPanel/VBoxContainer/StoreButton") != null
		var has_gifts_btn = menu.get_node_or_null("MainButtonsPanel/VBoxContainer/DailyGiftsButton") != null
		var has_challenge_btn = menu.get_node_or_null("MainButtonsPanel/VBoxContainer/DailyChallengeButton") != null
		var has_menu_coins = menu.get_node_or_null("MenuCoinsBtn") != null
		var has_coffee_btn = menu.get_node_or_null("SettingsPanel/CenterContainer/VBox/CoffeeBtn") != null
		var has_rate_btn = menu.get_node_or_null("SettingsPanel/CenterContainer/VBox/RateUsBtn") != null
		var has_share_btn = menu.get_node_or_null("SettingsPanel/CenterContainer/VBox/ShareBtn") != null
		var has_hud_coins = hud.get_node_or_null("MarginContainer/HBoxContainer/CoinsBtn") != null
		
		if has_store_btn and has_gifts_btn and has_challenge_btn and has_menu_coins and has_coffee_btn and has_rate_btn and has_share_btn and has_hud_coins:
			print("[PASS] Test 6: MainMenu & UpperHUD persistent buttons verified in scene tree")
			passed += 1
		else:
			print("[FAIL] Test 6: Missing one or more persistent buttons in scene tree")
		menu.queue_free()
		hud.queue_free()
	else:
		print("[FAIL] Test 6: Could not load main_menu.tscn or upper_hud.tscn")

	# Test 7: Verify all 7 standalone popup scenes instantiate properly
	total += 1
	var popups := [
		"res://scenes/popups/rate_popup.tscn",
		"res://scenes/popups/share_popup.tscn",
		"res://scenes/popups/coffee_popup.tscn",
		"res://scenes/popups/no_ads_popup.tscn",
		"res://scenes/popups/daily_reward_popup.tscn",
		"res://scenes/popups/daily_challenge_popup.tscn",
		"res://scenes/popups/update_popup.tscn"
	]
	var all_popups_ok := true
	for p_path in popups:
		var p_res = load(p_path)
		if p_res:
			var p_node = p_res.instantiate()
			if not p_node:
				all_popups_ok = false
			p_node.queue_free()
		else:
			all_popups_ok = false
			print("[FAIL] Test 7: Failed to load: ", p_path)
	
	if all_popups_ok:
		print("[PASS] Test 7: All 7 standalone popup scenes loaded and instantiated successfully")
		passed += 1
	else:
		print("[FAIL] Test 7: One or more popup scenes failed to instantiate")

	print("\n=== VERIFICATION RESULT: %d/%d PASSED ===" % [passed, total])
	if passed == total:
		print("ALL CHECKS PASSED PERFECTLY!\n")
		get_tree().quit(0)
	else:
		print("SOME CHECKS FAILED.\n")
		get_tree().quit(1)
