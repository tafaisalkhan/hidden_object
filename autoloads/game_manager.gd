extends Node

const SAVE_PATH: String = "user://hidden_object_data.cfg"

var score: int = 0
var lives: int = 3
var items_to_find: int = 0
var items_found: int = 0

var selected_category_id: String = "drawing_room"
var selected_level_id: String = "drawing_room"
var selected_sublevel_id: String = "sub1"

var sound_enabled: bool = true
var music_enabled: bool = true

var unlocked_level_num: int = 1
var completed_levels: Dictionary = {}
var return_to_level_select: bool = false

# --- Economy & Daily Challenge ---
var coins: int = 100
var ads_removed: bool = false
var daily_streak: int = 0
var last_daily_claim_date: String = ""
var last_daily_challenge_date: String = ""
var is_daily_challenge_mode: bool = false

func _ready():
	load_data()
	SignalHub.item_found.connect(_on_item_found)
	SignalHub.game_over.connect(_on_game_over)

func load_data() -> void:
	var cfg = ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		coins = cfg.get_value("economy", "coins", 100)
		ads_removed = cfg.get_value("economy", "ads_removed", false)
		daily_streak = cfg.get_value("daily", "streak", 0)
		last_daily_claim_date = cfg.get_value("daily", "last_claim_date", "")
		last_daily_challenge_date = cfg.get_value("daily", "last_challenge_date", "")
		sound_enabled = cfg.get_value("settings", "sound_enabled", true)
		music_enabled = cfg.get_value("settings", "music_enabled", true)
		completed_levels = cfg.get_value("progression", "completed_levels", {})

func save_data() -> void:
	var cfg = ConfigFile.new()
	cfg.load(SAVE_PATH)
	cfg.set_value("economy", "coins", coins)
	cfg.set_value("economy", "ads_removed", ads_removed)
	cfg.set_value("daily", "streak", daily_streak)
	cfg.set_value("daily", "last_claim_date", last_daily_claim_date)
	cfg.set_value("daily", "last_challenge_date", last_daily_challenge_date)
	cfg.set_value("settings", "sound_enabled", sound_enabled)
	cfg.set_value("settings", "music_enabled", music_enabled)
	cfg.set_value("progression", "completed_levels", completed_levels)
	cfg.save(SAVE_PATH)

func add_coins(amount: int) -> void:
	coins += amount
	save_data()
	SignalHub.coins_updated.emit(coins)

func spend_coins(amount: int) -> bool:
	if coins >= amount:
		coins -= amount
		save_data()
		SignalHub.coins_updated.emit(coins)
		return true
	return false

func start_level(total_items: int):
	score = 0
	lives = 3
	items_found = 0
	items_to_find = total_items
	
	# Delay emitting so HUD can be ready
	call_deferred("_emit_initial_stats")

func _emit_initial_stats():
	SignalHub.score_updated.emit(score)
	SignalHub.lives_updated.emit(lives)
	SignalHub.items_progress_updated.emit(items_found, items_to_find)
	SignalHub.coins_updated.emit(coins)

func _on_item_found(item_name: String):
	score += 100
	items_found += 1
	SignalHub.score_updated.emit(score)
	SignalHub.items_progress_updated.emit(items_found, items_to_find)
	
	if MusicManager:
		MusicManager.play_sfx("item_found")
	
	if items_found >= items_to_find:
		SignalHub.game_over.emit(true)

func lose_life():
	lives -= 1
	SignalHub.lives_updated.emit(lives)
	if MusicManager:
		MusicManager.play_sfx("wrong_click")
	if lives <= 0:
		SignalHub.game_over.emit(false)

func _on_game_over(success: bool):
	if success:
		complete_current_level()

func complete_current_level():
	var full_id = selected_category_id + "_" + selected_sublevel_id
	completed_levels[full_id] = 3
	completed_levels[selected_level_id] = 3
	add_coins(10) # 10 coins per completed level
	save_data()

func get_next_sublevel_id() -> String:
	return ""
