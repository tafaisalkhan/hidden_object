extends Node

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

func _ready():
	SignalHub.item_found.connect(_on_item_found)
	SignalHub.game_over.connect(_on_game_over)

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
	# Levels 2..10 remain locked per policy (do not increment unlocked_level_num)

func get_next_sublevel_id() -> String:
	# Levels 2..10 remain locked
	return ""
