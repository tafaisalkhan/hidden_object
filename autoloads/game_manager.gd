extends Node

var score: int = 0
var lives: int = 5
var items_to_find: int = 0
var items_found: int = 0
var wrong_taps: int = 0
var coins: int = 0
var ads_removed: bool = false
var ad_free_until_unix: float = 0.0
var last_awarded_stars: int = 0
var last_awarded_coins: int = 0
const HINT_COST: int = 50

var selected_category_id: String = "drawing_room"
var selected_level_id: String = "drawing_room"
var selected_sublevel_id: String = "sub1"

var sound_enabled: bool = true
var music_enabled: bool = true

const SAVE_PATH: String = "user://save_data.cfg"
const LEGACY_IAP_PATH: String = "user://settings.cfg"
var unlocked_level_num: int = 1
var completed_levels: Dictionary = {}
var return_to_level_select: bool = false
var is_arcade_mode: bool = false
var is_daily_mode: bool = false
var return_to_daily_screen: bool = false
var daily_active_date: String = ""
var daily_first_day: int = -1
var daily_cycle_start_day: int = -1
var daily_history: Dictionary = {}
var daily_completed_ids: Array = []
const DAILY_ROOMS: Array[String] = ["drawing_room", "basement", "kitchen", "study_room", "bed_room", "dining_room", "store_room"]
var arcade_recent_rooms: Array = []
var arcade_recent: Array = []

func _ready():
	SignalHub.item_found.connect(_on_item_found)
	SignalHub.game_over.connect(_on_game_over)
	load_game()

func is_ad_free_active() -> bool:
	if ads_removed:
		return true
	return ad_free_until_unix > Time.get_unix_time_from_system()

func get_ad_free_remaining_sec() -> float:
	return maxf(0.0, ad_free_until_unix - Time.get_unix_time_from_system())

func start_level(total_items: int):
	score = 0
	lives = 5
	wrong_taps = 0
	last_awarded_stars = 0
	last_awarded_coins = 0
	items_found = 0
	items_to_find = total_items
	
	# Delay emitting so HUD can be ready
	call_deferred("_emit_initial_stats")

func _emit_initial_stats():
	SignalHub.score_updated.emit(score)
	SignalHub.lives_updated.emit(lives)
	SignalHub.items_progress_updated.emit(items_found, items_to_find)
	SignalHub.coins_updated.emit(coins)

func _on_item_found(_item_name: String):
	score += 100
	items_found += 1
	SignalHub.score_updated.emit(score)
	SignalHub.items_progress_updated.emit(items_found, items_to_find)
	
	if items_found >= items_to_find:
		SignalHub.game_over.emit(true)

func lose_life():
	wrong_taps += 1
	lives -= 1
	SignalHub.lives_updated.emit(lives)
	Input.vibrate_handheld(150) # Vibrate handheld device for 150ms on wrong click
	if MusicManager:
		MusicManager.play_sfx("wrong_click")
	if lives <= 0:
		SignalHub.game_over.emit(false)

func _on_game_over(success: bool):
	if success:
		complete_current_level()

func complete_current_level():
	last_awarded_stars = get_level_stars()
	last_awarded_coins = get_level_coin_reward()
	coins += last_awarded_coins
	SignalHub.coins_updated.emit(coins)
	if is_daily_mode:
		var entry: Dictionary = daily_history.get(daily_active_date, {})
		entry["started"] = true
		entry["completed"] = true
		entry["score"] = score
		entry["stars"] = last_awarded_stars
		daily_history[daily_active_date] = entry
		var daily_id = str(entry.get("room", "")) + "_" + str(entry.get("sub", ""))
		if not daily_completed_ids.has(daily_id):
			daily_completed_ids.append(daily_id)
		save_game()
		return
	var full_id = selected_category_id + "_" + selected_sublevel_id
	completed_levels[full_id] = max(int(completed_levels.get(full_id, 0)), last_awarded_stars)
	completed_levels[selected_level_id] = max(int(completed_levels.get(selected_level_id, 0)), last_awarded_stars)
	save_game()

func get_level_stars() -> int:
	if wrong_taps == 0:
		return 3
	if wrong_taps <= 2:
		return 2
	return 1

func get_level_coin_reward() -> int:
	return 20

func add_coins(amount: int) -> void:
	coins += amount
	save_game()
	SignalHub.coins_updated.emit(coins)

func spend_coins(amount: int) -> bool:
	if amount < 0 or coins < amount:
		return false
	coins -= amount
	save_game()
	SignalHub.coins_updated.emit(coins)
	return true

func get_next_sublevel_id() -> String:
	if selected_sublevel_id.begins_with("sub"):
		var num_str = selected_sublevel_id.substr(3)
		var num = int(num_str)
		var max_levels = 10
		if selected_category_id != "drawing_room":
			max_levels = 5
		if num > 0 and num < max_levels:
			return "sub" + str(num + 1)
	return ""

func save_data() -> void:
	save_game()

func save_game() -> void:
	var cfg = ConfigFile.new()
	cfg.set_value("settings", "sound_enabled", sound_enabled)
	cfg.set_value("settings", "music_enabled", music_enabled)
	cfg.set_value("iap", "ads_removed", ads_removed)
	cfg.set_value("iap", "ad_free_until_unix", ad_free_until_unix)
	cfg.set_value("progress", "completed_levels", completed_levels)
	cfg.set_value("progress", "coins", coins)
	cfg.set_value("progress", "arcade_recent", arcade_recent)
	cfg.set_value("daily", "first_day", daily_first_day)
	cfg.set_value("daily", "cycle_start_day", daily_cycle_start_day)
	cfg.set_value("daily", "history", daily_history)
	cfg.set_value("daily", "completed_ids", daily_completed_ids)
	var err = cfg.save(SAVE_PATH)
	if err == OK:
		print("[GameManager] Game progress saved successfully!")
	else:
		print("[GameManager] Failed to save game progress! Err: ", err)

func load_game() -> void:
	var cfg = ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		sound_enabled = bool(cfg.get_value("settings", "sound_enabled", true))
		music_enabled = bool(cfg.get_value("settings", "music_enabled", true))
		ads_removed = bool(cfg.get_value("iap", "ads_removed", false))
		ad_free_until_unix = float(cfg.get_value("iap", "ad_free_until_unix", 0.0))
		completed_levels = cfg.get_value("progress", "completed_levels", {})
		coins = int(cfg.get_value("progress", "coins", 0))
		arcade_recent = cfg.get_value("progress", "arcade_recent", [])
		daily_first_day = int(cfg.get_value("daily", "first_day", -1))
		daily_cycle_start_day = int(cfg.get_value("daily", "cycle_start_day", -1))
		daily_history = cfg.get_value("daily", "history", {})
		daily_completed_ids = cfg.get_value("daily", "completed_ids", [])
		print("[GameManager] Game progress loaded successfully. Completed levels count: ", completed_levels.size())
	else:
		completed_levels = {}
		print("[GameManager] No saved game progress found (starting fresh).")

	# Migrate legacy settings.cfg IAP flag if present
	if not ads_removed:
		var legacy_cfg = ConfigFile.new()
		if legacy_cfg.load(LEGACY_IAP_PATH) == OK:
			if bool(legacy_cfg.get_value("iap", "remove_ads", false)):
				ads_removed = true
				save_game()

	if daily_first_day < 0:
		daily_first_day = get_day_number(get_today_key())
		save_game()
	if daily_cycle_start_day < 0:
		daily_cycle_start_day = daily_first_day
		save_game()

func reset_all_progress() -> void:
	completed_levels = {}
	coins = 0
	arcade_recent = []
	daily_history = {}
	daily_completed_ids = []
	save_game()
	print("[GameManager] Progress reset to initial clean state.")

func get_today_key() -> String:
	return Time.get_date_string_from_system()

func get_day_number(date_key: String) -> int:
	return int(Time.get_unix_time_from_datetime_string(date_key + "T12:00:00") / 86400.0)

func get_daily_level(date_key: String) -> Dictionary:
	var eligible: Array[String] = []
	for room in DAILY_ROOMS:
		var max_levels := 10 if room == "drawing_room" else 5
		for number in range(1, max_levels + 1):
			eligible.append(room + "_sub" + str(number))
	var existing: Dictionary = daily_history.get(date_key, {})
	if existing.has("room") and existing.has("sub"):
		var existing_id := str(existing["room"]) + "_" + str(existing["sub"])
		if eligible.has(existing_id):
			return existing
	var remaining: Array[String] = []
	for candidate in eligible:
		if not daily_completed_ids.has(candidate):
			remaining.append(candidate)
	if remaining.is_empty():
		daily_completed_ids.clear()
		daily_cycle_start_day = get_day_number(date_key)
	var assigned: Array = []
	for old_date in daily_history.keys():
		if get_day_number(str(old_date)) < daily_cycle_start_day:
			continue
		var old_entry = daily_history[old_date]
		if old_entry is Dictionary and old_entry.has("room") and old_entry.has("sub"):
			var old_id := str(old_entry["room"]) + "_" + str(old_entry["sub"])
			if eligible.has(old_id):
				assigned.append(old_id)
	var fresh: Array = []
	var unfinished: Array = []
	for candidate in eligible:
		if not daily_completed_ids.has(candidate):
			unfinished.append(candidate)
			if not assigned.has(candidate):
				fresh.append(candidate)
	var rng = RandomNumberGenerator.new()
	rng.seed = int(get_day_number(date_key)) * 10007 + 42
	var pool = fresh if not fresh.is_empty() else (unfinished if not unfinished.is_empty() else eligible)
	var daily_id: String = pool[rng.randi_range(0, pool.size() - 1)]
	var parts = daily_id.split("_sub")
	var entry: Dictionary = {
		"room": parts[0],
		"sub": "sub" + parts[1],
		"started": false,
		"completed": false,
		"score": 0
	}
	daily_history[date_key] = entry
	save_game()
	return entry

func get_daily_status(date_key: String) -> String:
	var day = get_day_number(date_key)
	var today = get_day_number(get_today_key())
	if day < daily_first_day or day > today:
		return "unavailable"
	var entry: Dictionary = daily_history.get(date_key, {})
	if entry.get("completed", false):
		return "completed"
	if entry.get("started", false):
		return "played"
	if day < today:
		return "missed"
	return "ready"

func start_daily_level() -> bool:
	var date_key = get_today_key()
	var entry = get_daily_level(date_key)
	if entry.get("completed", false):
		return false
	entry["started"] = true
	daily_history[date_key] = entry
	daily_active_date = date_key
	selected_category_id = entry["room"]
	selected_level_id = entry["room"]
	selected_sublevel_id = entry["sub"]
	is_arcade_mode = false
	is_daily_mode = true
	save_game()
	return true


func pick_next_arcade_level():
	is_daily_mode = false
	randomize()
	var all_rooms = ["drawing_room", "basement", "kitchen", "study_room", "bed_room", "dining_room", "store_room"]
	
	# Exclude recently played game types so they don't repeat for a while (tracks last 4)
	var allowed_rooms = []
	for r in all_rooms:
		if not arcade_recent_rooms.has(r):
			allowed_rooms.append(r)
			
	if allowed_rooms.size() == 0:
		allowed_rooms = all_rooms.duplicate()
		
	allowed_rooms.shuffle()
	
	var chosen = null
	
	for r in allowed_rooms:
		var room_pool = []
		var max_sub = 10 if r == "drawing_room" else 5
		for i in range(1, max_sub + 1):
			var full_id = r + "_sub" + str(i)
			if not arcade_recent.has(full_id):
				room_pool.append({"room": r, "sub": "sub" + str(i), "full": full_id})
		
		if room_pool.size() > 0:
			chosen = room_pool.pick_random()
			break
			
	if chosen == null:
		chosen = {"room": "drawing_room", "sub": "sub1", "full": "drawing_room_sub1"}
	
	arcade_recent.append(chosen["full"])
	if arcade_recent.size() > 15:
		arcade_recent.pop_front()
		
	arcade_recent_rooms.append(chosen["room"])
	if arcade_recent_rooms.size() > 4:
		arcade_recent_rooms.pop_front()
		
	save_game()
	
	selected_category_id = chosen["room"]
	selected_level_id = chosen["room"]
	selected_sublevel_id = chosen["sub"]
	is_arcade_mode = true
