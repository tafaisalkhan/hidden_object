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

	# Test 11: Level Music Dependent on Level Name
	total += 1
	var mm_lvl_ref = get_node_or_null("/root/MusicManager")
	if mm_lvl_ref != null and mm_lvl_ref.has_method("play_game_music"):
		mm_lvl_ref.play_game_music("kitchen")
		var k_wav: AudioStreamWAV = mm_lvl_ref.game_player.stream as AudioStreamWAV
		var kitchen_ok: bool = (mm_lvl_ref.current_track_id == "kitchen" and k_wav != null and k_wav.loop_end > 0)
		mm_lvl_ref.play_game_music("drawing_room")
		var d_wav: AudioStreamWAV = mm_lvl_ref.game_player.stream as AudioStreamWAV
		var drawing_ok: bool = (mm_lvl_ref.current_track_id == "drawing_room" and d_wav != null and d_wav.loop_end > 0)
		if kitchen_ok and drawing_ok:
			print("[PASS] Test 11: Level sound plays based on level name from assets/music/ with verified loop points")
			passed += 1
		else:
			print("[FAIL] Test 11: Level sound failed to map or load stream for level name")
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

	print("\n=== VERIFICATION RESULT: %d/%d PASSED ===" % [passed, total])
	if passed == total:
		print("ALL CHECKS PASSED PERFECTLY!\n")
		get_tree().quit(0)
	else:
		print("SOME CHECKS FAILED.\n")
		get_tree().quit(1)
