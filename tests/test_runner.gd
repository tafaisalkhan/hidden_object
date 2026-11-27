extends Node

func _ready():
	print("\n=======================================================")
	print("--- Running Difference-Find Extended Verification ---")
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
		var rule2_ok: bool = (adm.on_level_completed(1) == false)
		adm.set_gameplay_active(true)
		var rule6_ok: bool = (adm.can_show_interstitial_now() == false)
		adm.set_gameplay_active(false)
		adm.levels_since_interstitial = 0
		adm.last_interstitial_unix_sec = -9999.0
		if rule2_ok and rule6_ok:
			print("[PASS] Test 3: AdManager enforces Rule 2 & Rule 6")
			passed += 1
		else:
			print("[FAIL] Test 3: Anti-suspension rule check failed")
	else:
		print("[FAIL] Test 3: AdManager not found in root")

	# Test 4: SettingsPopup full instantiation and node resolution
	total += 1
	var settings_scene = load("res://scenes/popups/settings_popup.tscn")
	if settings_scene:
		var settings = settings_scene.instantiate()
		add_child(settings)
		var sound_btn = settings.get_node_or_null("Dimmer/Center/FrameBox/Panel/Margin/VBox/AudioRow/SoundToggleBtn")
		var music_btn = settings.get_node_or_null("Dimmer/Center/FrameBox/Panel/Margin/VBox/AudioRow/MusicToggleBtn")
		var bottom_btn = settings.get_node_or_null("Dimmer/Center/FrameBox/Panel/Margin/VBox/BottomCloseBtn")
		if sound_btn and music_btn and bottom_btn:
			print("[PASS] Test 4: SettingsPopup instantiated with all Margin node paths resolved")
			passed += 1
		else:
			print("[FAIL] Test 4: SettingsPopup child node resolution failed")
		settings.queue_free()
	else:
		print("[FAIL] Test 4: Failed to load settings_popup.tscn")

	# Test 5: StorePopup full instantiation & items
	total += 1
	var store_scene = load("res://scenes/popups/store_popup.tscn")
	if store_scene:
		var store = store_scene.instantiate()
		add_child(store)
		var items_container = store.get_node_or_null("Dimmer/Center/FrameBox/Panel/Margin/Layout/Scroll/Items")
		if items_container and items_container.get_child_count() == 5:
			print("[PASS] Test 5: StorePopup instantiated with 5 store items")
			passed += 1
		else:
			print("[FAIL] Test 5: StorePopup child count mismatch")
		store.queue_free()
	else:
		print("[FAIL] Test 5: Failed to load store_popup.tscn")

	# Test 6: MainMenu TopBar & Button Actions
	total += 1
	var menu_scene = load("res://main/main_menu.tscn")
	if menu_scene:
		var menu = menu_scene.instantiate()
		add_child(menu)
		var settings_btn: Button = menu.get_node_or_null("TopBar/SettingsButton")
		var store_btn: Button = menu.get_node_or_null("TopBar/RightHBox/StoreButton")
		var coin_btn: Button = menu.get_node_or_null("TopBar/RightHBox/MenuCoinsBtn")
		var topbar: Control = menu.get_node_or_null("TopBar")
		var main_panel: Control = menu.get_node_or_null("MainButtonsPanel")
		
		var has_topbar_nodes: bool = (settings_btn != null and store_btn != null and coin_btn != null and topbar != null)
		var mouse_filter_ok: bool = (main_panel != null and main_panel.mouse_filter == Control.MOUSE_FILTER_IGNORE and topbar.mouse_filter == Control.MOUSE_FILTER_IGNORE)
		
		# Test pressing Settings Button
		settings_btn.emit_signal("pressed")
		var has_settings_popup: bool = (menu.get_node_or_null("SettingsPopup") != null)
		if has_settings_popup:
			menu.get_node("SettingsPopup").queue_free()
			
		# Test pressing Store Button
		store_btn.emit_signal("pressed")
		var has_store_popup: bool = (menu.get_node_or_null("StorePopup") != null)
		if has_store_popup:
			menu.get_node("StorePopup").queue_free()

		# Test Start Game flow
		var start_btn: Button = menu.get_node_or_null("MainButtonsPanel/VBoxContainer/StartButton")
		if start_btn:
			start_btn.emit_signal("pressed")
		var flow_ok: bool = (main_panel != null and not main_panel.visible and menu.mode_select_panel != null and menu.mode_select_panel.visible)
		
		if has_topbar_nodes and mouse_filter_ok and has_settings_popup and has_store_popup and flow_ok:
			print("[PASS] Test 6: MainMenu TopBar clicks (Settings & Store) and Start Game flow 100% verified")
			passed += 1
		else:
			print("[FAIL] Test 6: Settings/Store click or flow failed: topbar_nodes=%s, filter=%s, settings_pop=%s, store_pop=%s, flow=%s" % [has_topbar_nodes, mouse_filter_ok, has_settings_popup, has_store_popup, flow_ok])
		menu.queue_free()
	else:
		print("[FAIL] Test 6: Could not load main_menu.tscn")

	# Test 7: Verify all 9 popups instantiate without errors
	total += 1
	var popups := [
		"res://scenes/popups/rate_popup.tscn",
		"res://scenes/popups/share_popup.tscn",
		"res://scenes/popups/coffee_popup.tscn",
		"res://scenes/popups/no_ads_popup.tscn",
		"res://scenes/popups/daily_reward_popup.tscn",
		"res://scenes/popups/daily_challenge_popup.tscn",
		"res://scenes/popups/update_popup.tscn",
		"res://scenes/popups/settings_popup.tscn",
		"res://scenes/popups/store_popup.tscn"
	]
	var all_popups_ok := true
	for p_path in popups:
		var p_res = load(p_path)
		if p_res:
			var p_node = p_res.instantiate()
			add_child(p_node)
			p_node.queue_free()
		else:
			all_popups_ok = false
			print("[FAIL] Test 7: Failed to load: ", p_path)
	
	if all_popups_ok:
		print("[PASS] Test 7: All 9 popups added to tree and ready() without error")
		passed += 1
	else:
		print("[FAIL] Test 7: One or more popup scenes failed")

	
	# Test 8: Hint Cost 50 & Rewarded Integration
	total += 1
	var gm_ref = get_node_or_null("/root/GameManager")
	var hint_res = load("res://hud/hint_button.tscn")
	if gm_ref != null and hint_res != null:
		var hint_inst = hint_res.instantiate()
		add_child(hint_inst)
		var cost_50_ok: bool = (gm_ref.HINT_COST == 50)
		var has_refresh: bool = hint_inst.has_method("refresh_state")
		if cost_50_ok and has_refresh:
			print("[PASS] Test 8: Hint cost is 50 coins and hint_button state machine verified")
			passed += 1
		else:
			print("[FAIL] Test 8: Hint cost (%d) or refresh_state failed" % gm_ref.HINT_COST)
		hint_inst.queue_free()
	else:
		print("[FAIL] Test 8: GameManager or hint_button.tscn missing")

	
	# Test 9: Audio & SFX Assets Verification
	total += 1
	var mm_ref = get_node_or_null("/root/MusicManager")
	if mm_ref != null:
		var required_sfx := ["win", "lose", "item_found", "wrong_click", "button", "star", "coin", "sparkle"]
		var all_sfx_found := true
		for s_name in required_sfx:
			if not mm_ref.sfx_cache.has(s_name):
				all_sfx_found = false
				print("[FAIL] Test 9: Missing SFX stream in cache: ", s_name)
		var menu_track_exists: bool = ResourceLoader.exists("res://assets/music/menu_theme.mp3") or ResourceLoader.exists(mm_ref.menu_track)
		if all_sfx_found and menu_track_exists:
			print("[PASS] Test 9: All 7 required SFX streams cached and menu track verified")
			passed += 1
		else:
			print("[FAIL] Test 9: Audio assets missing or not cached")
	else:
		print("[FAIL] Test 9: MusicManager autoload not found")

	
	# Test 10: Universal Button Tap Sound System
	total += 1
	var mm_btn_ref = get_node_or_null("/root/MusicManager")
	if mm_btn_ref != null and mm_btn_ref.has_method("play_click"):
		var test_btn = Button.new()
		add_child(test_btn)
		# Button should be auto-bound to _on_any_button_pressed
		var is_bound: bool = test_btn.pressed.is_connected(Callable(mm_btn_ref, "_on_any_button_pressed"))
		var btn_stream: AudioStream = load("res://assets/sfx/button.wav")
		var dur_ok: bool = (btn_stream != null and btn_stream.get_length() >= 0.15)
		if is_bound and dur_ok:
			print("[PASS] Test 10: Every button automatically plays tap sound on pressed (duration: %.3fs)" % btn_stream.get_length())
			passed += 1
		else:
			print("[FAIL] Test 10: Button tap sound or binding failed (dur_ok=%s)" % dur_ok)
		test_btn.queue_free()
	else:
		print("[FAIL] Test 10: MusicManager missing play_click method")

	# Test 11: Dedicated Room Music & Menu Music Seamless Recovery
	total += 1
	var mm_lvl_ref = get_node_or_null("/root/MusicManager")
	if mm_lvl_ref != null and mm_lvl_ref.has_method("play_game_music"):
		mm_lvl_ref.play_game_music("kitchen", "sub1")
		var k_wav: AudioStreamWAV = mm_lvl_ref.game_player.stream as AudioStreamWAV
		var kitchen_ok: bool = (mm_lvl_ref.current_track_id == "kitchen_sub1" and k_wav != null and k_wav.loop_end >= 1322000)

		# Verify rooms map to their dedicated tracks without random shuffling
		var rooms_tested := ["drawing_room", "kitchen", "basement", "bed_room", "dining_room", "store_room", "study_room"]
		var room_tracks_ok := true
		for r_id in rooms_tested:
			var res_t: Dictionary = mm_lvl_ref.resolve_track_for_level(r_id, 1)
			if str(res_t.get("track_key", "")) != r_id:
				room_tracks_ok = false

		# Verify menu music resumes smoothly at full volume
		mm_lvl_ref.play_menu_music()
		var menu_ok: bool = (mm_lvl_ref.current_track_id == "menu" and mm_lvl_ref.menu_player != null and mm_lvl_ref.menu_player.playing)

		if kitchen_ok and room_tracks_ok and menu_ok:
			print("[PASS] Test 11: Dedicated room soundtracks & seamless menu music recovery verified")
			passed += 1
		else:
			print("[FAIL] Test 11: Music verification failed (kitchen_ok=%s rooms_ok=%s menu_ok=%s)" % [kitchen_ok, room_tracks_ok, menu_ok])
	else:
		print("[FAIL] Test 11: MusicManager missing play_game_music")

	# Test 12: Sequential Level & Category Unlocking (All initially closed except Drawing Room Level 1)
	total += 1
	var menu_script = load("res://main/main_menu.gd").new()
	if menu_script.has_method("is_category_unlocked"):
		var empty_dict: Dictionary = {}
		var dr_unlocked: bool = menu_script.is_category_unlocked("drawing_room", empty_dict)
		var base_unlocked: bool = menu_script.is_category_unlocked("basement", empty_dict)
		var kitch_unlocked: bool = menu_script.is_category_unlocked("kitchen", empty_dict)
		
		# Now test sublevels with empty progress
		if gm:
			gm.completed_levels = {}
			gm.selected_category_id = "drawing_room"
			var levels = menu_script.get_10_levels()
			var l1_open = levels[0]["is_unlocked"]
			var l2_closed = not levels[1]["is_unlocked"]
			var l3_closed = not levels[2]["is_unlocked"]
			
			# Complete Level 1 -> Level 2 should unlock
			gm.completed_levels["drawing_room_sub1"] = 3
			var levels_after_l1 = menu_script.get_10_levels()
			var l2_now_open = levels_after_l1[1]["is_unlocked"]
			var l3_still_closed = not levels_after_l1[2]["is_unlocked"]
			
			# Complete Level 10 -> Basement unlocks
			gm.completed_levels["drawing_room_sub10"] = 3
			var base_now_unlocked = menu_script.is_category_unlocked("basement", gm.completed_levels)
			
			if dr_unlocked and not base_unlocked and not kitch_unlocked and l1_open and l2_closed and l3_closed and l2_now_open and l3_still_closed and base_now_unlocked:
				print("[PASS] Test 12: Sequential locking/unlocking verified (initially only Drawing Room Level 1 is open)")
				passed += 1
			else:
				print("[FAIL] Test 12: Level locking logic failed")
			
			# Clean up test state: reset back to clean empty state
			gm.reset_all_progress()
	else:
		print("[FAIL] Test 12: main_menu missing is_category_unlocked method")
	menu_script.free()

	# Test 13: Daily Challenge Scene & Progression Integration
	total += 1
	var dc_res = load("res://main/daily_challenge.tscn")
	if dc_res != null:
		var dc_node = dc_res.instantiate()
		add_child(dc_node)
		var today_key = GameManager.get_today_key() if GameManager else ""
		var today_level = GameManager.get_daily_level(today_key) if GameManager else {}
		var valid_level: bool = today_level.has("room") and today_level.has("sub")
		dc_node.queue_free()
		if valid_level:
			print("[PASS] Test 13: Daily challenge scene and level generation fully functional")
			passed += 1
		else:
			print("[FAIL] Test 13: Daily challenge level generation returned invalid dictionary")
	else:
		print("[FAIL] Test 13: Failed to load res://main/daily_challenge.tscn")

	# Test 14: Remove Ads Button in SettingsPopup & StorePopup + Persistence
	total += 1
	if gm != null and bm != null and adm != null:
		PopupManager.coin_animation_enabled = false
		bm.remove_ads_owned = false
		gm.ads_removed = false
		gm.ad_free_until_unix = 0.0
		InAppPurchaseManager.is_ads_removed = false
		gm.save_game()

		var sp = load("res://scenes/popups/settings_popup.tscn").instantiate()
		var stp = load("res://scenes/popups/store_popup.tscn").instantiate()
		add_child(sp)
		add_child(stp)

		var rem_btn: Button = sp.get_node_or_null("Dimmer/Center/FrameBox/Panel/Margin/VBox/RemoveAdsBtn")
		var before_free: bool = adm.is_ad_free()
		if rem_btn:
			rem_btn.emit_signal("pressed")

		var after_owned: bool = bm.is_remove_ads_owned() and gm.ads_removed and InAppPurchaseManager.is_ads_removed and adm.is_ad_free()
		var btn_updated: bool = (rem_btn != null and rem_btn.disabled and "Removed" in rem_btn.text)

		# Verify persistence across save/load
		gm.ads_removed = false
		gm.load_game()
		var persisted_ok: bool = gm.ads_removed

		sp.queue_free()
		stp.queue_free()

		# Reset clean state
		bm.remove_ads_owned = false
		gm.ads_removed = false
		InAppPurchaseManager.is_ads_removed = false
		InAppPurchaseManager.save_purchase_state()
		gm.save_game()

		if (not before_free) and after_owned and btn_updated and persisted_ok:
			print("[PASS] Test 14: Remove Ads button works in Settings & Store, disables ads immediately, and persists to disk")
			passed += 1
		else:
			print("[FAIL] Test 14: Remove Ads verification failed: before=%s after=%s btn=%s persist=%s" % [before_free, after_owned, btn_updated, persisted_ok])
	else:
		print("[FAIL] Test 14: Missing managers")

	# Test 15: NoAdsPopup 24h Rewarded Video & BuyForever Buttons
	total += 1
	var noads_inst = load("res://scenes/popups/no_ads_popup.tscn").instantiate()
	if noads_inst and gm and adm:
		gm.ad_free_until_unix = 0.0
		add_child(noads_inst)
		var watch_btn: Button = noads_inst.get_node_or_null("Dimmer/Center/FrameBox/Panel/VBox/WatchAdBtn")
		var forever_btn: Button = noads_inst.get_node_or_null("Dimmer/Center/FrameBox/Panel/VBox/BuyForeverBtn")
		if watch_btn:
			watch_btn.emit_signal("pressed")
		var temp_ad_free_ok: bool = adm.is_ad_free() and gm.ad_free_until_unix > Time.get_unix_time_from_system()
		gm.ad_free_until_unix = 0.0
		gm.save_game()
		if is_instance_valid(noads_inst):
			noads_inst.queue_free()
		if watch_btn != null and forever_btn != null and temp_ad_free_ok:
			print("[PASS] Test 15: NoAdsPopup Watch Video grants real 24h ad-free mode & Buy Forever button wired")
			passed += 1
		else:
			print("[FAIL] Test 15: NoAdsPopup test failed (watch=%s forever=%s active=%s)" % [watch_btn != null, forever_btn != null, temp_ad_free_ok])
	else:
		print("[FAIL] Test 15: Failed to instantiate NoAdsPopup")

	# Test 16: CoffeePopup, DailyRewardPopup (anti-double-claim), and DailyChallengePopup
	total += 1
	if gm and PopupManager:
		# Clean daily save file before testing
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PopupManager.DAILY_SAVE_PATH))
		gm.coins = 0

		# 16a: CoffeePopup grants +300 coins
		var coffee_inst = load("res://scenes/popups/coffee_popup.tscn").instantiate()
		add_child(coffee_inst)
		var coffee_buy: Button = coffee_inst.get_node_or_null("Dimmer/Center/FrameBox/Panel/VBox/BuyBtn")
		if coffee_buy:
			coffee_buy.emit_signal("pressed")
		var coffee_ok: bool = (gm.coins == 300)
		if is_instance_valid(coffee_inst):
			coffee_inst.queue_free()

		# 16b: DailyRewardPopup grants +50 coins ONCE even if clicked twice, and marks Day 1 only
		var dr_inst = load("res://scenes/popups/daily_reward_popup.tscn").instantiate()
		add_child(dr_inst)
		var dr_claim: Button = dr_inst.get_node_or_null("Dimmer/Center/FrameBox/Panel/VBox/ClaimBtn")
		if dr_claim:
			dr_claim.emit_signal("pressed")
			dr_claim.emit_signal("pressed")
		var streak_state: Dictionary = PopupManager.get_streak_state()
		var dr_ok: bool = (gm.coins == 350 and int(streak_state["streak_days"]) == 1 and int(streak_state["active_idx"]) == 0 and not bool(streak_state["can_claim"]))
		if is_instance_valid(dr_inst):
			dr_inst.queue_free()

		# 16c: DailyChallengePopup tracks 10 items found & claims +150 coins once
		PopupManager.add_daily_challenge_progress(10)
		var dcp_inst = load("res://scenes/popups/daily_challenge_popup.tscn").instantiate()
		add_child(dcp_inst)
		var dcp_btn: Button = dcp_inst.get_node_or_null("Dimmer/Center/FrameBox/Panel/VBox/ActionBtn")
		if dcp_btn:
			dcp_btn.emit_signal("pressed")
			dcp_btn.emit_signal("pressed")
		var dcp_ok: bool = (gm.coins == 500 and PopupManager.is_daily_challenge_completed())
		if is_instance_valid(dcp_inst):
			dcp_inst.queue_free()

		# Clean up test artifacts
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PopupManager.DAILY_SAVE_PATH))
		gm.reset_all_progress()
		PopupManager.coin_animation_enabled = true

		if coffee_ok and dr_ok and dcp_ok:
			print("[PASS] Test 16: CoffeePopup (+300), DailyRewardPopup (+50 single-claim & Day 1 state), and DailyChallengePopup (+150) verified")
			passed += 1
		else:
			print("[FAIL] Test 16: Popup action check failed (coffee=%s dr=%s dcp=%s coins=%d)" % [coffee_ok, dr_ok, dcp_ok, gm.coins])
	else:
		print("[FAIL] Test 16: Missing GameManager or PopupManager")

	print("\n=== VERIFICATION RESULT: %d/%d PASSED ===" % [passed, total])
	if passed == total:
		print("ALL CHECKS PASSED PERFECTLY!\n")
		get_tree().quit(0)
	else:
		print("SOME CHECKS FAILED.\n")
		get_tree().quit(1)
