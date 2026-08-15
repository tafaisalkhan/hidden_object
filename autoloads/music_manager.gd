extends Node

# ── Music & SFX Manager Autoload ──────────────────────────────────────────────
# Plays background music per category during gameplay and menu music on menus.
# Also plays one-shot sound effects for game events.

# ── Audio Players ─────────────────────────────────────────────────────────────
var menu_player: AudioStreamPlayer
var game_player: AudioStreamPlayer
var current_track_id: String = ""

# ── Crossfade settings ────────────────────────────────────────────────────────
const FADE_DURATION: float = 1.2
const MENU_VOLUME_DB: float = -8.0
const GAME_VOLUME_DB: float = -6.0
const SFX_VOLUME_DB: float = -4.0

# ── Track mapping: category_id → audio file path ─────────────────────────────
var category_tracks: Dictionary = {
	"drawing_room":  "res://assets/music/drawing_room.wav",
	"kitchen":       "res://assets/music/kitchen.wav",
	"basement":      "res://assets/music/basement.wav",
	"bed_room":      "res://assets/music/bed_room.wav",
	"dining_room":   "res://assets/music/dining_room.wav",
	"store_room":    "res://assets/music/store_room.wav",
	"study_room":    "res://assets/music/study_room.wav",
}

# Menu / splash screen music
var menu_track: String = "res://assets/music/menu_theme.wav"

# ── SFX file paths ────────────────────────────────────────────────────────────
# Place these .wav files in res://assets/sfx/
var sfx_paths: Dictionary = {
	"win":         "res://assets/sfx/win.wav",
	"lose":        "res://assets/sfx/lose.wav",
	"item_found":  "res://assets/sfx/item_found.wav",
	"wrong_click": "res://assets/sfx/wrong_click.wav",
	"button":      "res://assets/sfx/button.wav",
	"star_fill":   "res://assets/sfx/star_fill.wav",
}

# Preloaded SFX cache
var sfx_cache: Dictionary = {}


func _ready():
	# Create music players for crossfading
	menu_player = AudioStreamPlayer.new()
	menu_player.bus = "Master"
	menu_player.volume_db = MENU_VOLUME_DB
	menu_player.name = "MenuPlayer"
	add_child(menu_player)

	game_player = AudioStreamPlayer.new()
	game_player.bus = "Master"
	game_player.volume_db = GAME_VOLUME_DB
	game_player.name = "GamePlayer"
	add_child(game_player)

	# Preload all available SFX
	for key in sfx_paths:
		var path = sfx_paths[key]
		if ResourceLoader.exists(path):
			sfx_cache[key] = load(path)


# ── Public API: Music ─────────────────────────────────────────────────────────

## Play the menu/splash background music. Crossfades from game music if playing.
func play_menu_music():
	if not GameManager.music_enabled:
		stop_all()
		return
	if current_track_id == "menu":
		return
	current_track_id = "menu"
	_play_track(menu_player, menu_track, MENU_VOLUME_DB)
	_fade_out(game_player)


## Play the category-specific background music for gameplay.
func play_game_music(category_id: String = ""):
	if not GameManager.music_enabled:
		stop_all()
		return
	if category_id == "":
		category_id = GameManager.selected_category_id if GameManager else "drawing_room"

	var track_id = "game_" + category_id
	if current_track_id == track_id:
		return
	current_track_id = track_id

	var track_path = category_tracks.get(category_id, "")
	if track_path == "" or not ResourceLoader.exists(track_path):
		track_path = menu_track
	if not ResourceLoader.exists(track_path):
		return

	_play_track(game_player, track_path, GAME_VOLUME_DB)
	_fade_out(menu_player)


## Stop all music with a fade out.
func stop_all():
	current_track_id = ""
	_fade_out(menu_player)
	_fade_out(game_player)


## Call this when music_enabled setting is toggled.
func on_music_setting_changed():
	if not GameManager.music_enabled:
		stop_all()


# ── Public API: Sound Effects ─────────────────────────────────────────────────

## Play a one-shot sound effect by name.
## Names: "win", "lose", "item_found", "wrong_click", "button", "star_fill"
func play_sfx(sfx_name: String, volume_db: float = SFX_VOLUME_DB):
	if not GameManager.sound_enabled:
		return
	var stream = sfx_cache.get(sfx_name, null)
	if stream == null:
		return
	# Use a fresh player so multiple SFX can overlap
	var player = AudioStreamPlayer.new()
	player.bus = "Master"
	player.volume_db = volume_db
	player.stream = stream
	add_child(player)
	player.play()
	player.finished.connect(func(): player.queue_free())


# ── Internal ──────────────────────────────────────────────────────────────────

func _play_track(player: AudioStreamPlayer, path: String, target_db: float):
	if not ResourceLoader.exists(path):
		return
	var stream = load(path)
	if stream == null:
		return
	if player.stream == stream and player.playing:
		return
	player.stream = stream
	player.volume_db = -40.0
	player.play()
	var tween = create_tween()
	tween.tween_property(player, "volume_db", target_db, FADE_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _fade_out(player: AudioStreamPlayer):
	if not player.playing:
		return
	var tween = create_tween()
	tween.tween_property(player, "volume_db", -40.0, FADE_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		player.stop()
	)
