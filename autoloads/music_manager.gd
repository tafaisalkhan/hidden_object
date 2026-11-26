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
const MENU_VOLUME_DB: float = -6.0
const GAME_VOLUME_DB: float = -4.0
const SFX_VOLUME_DB: float = -4.0

var menu_tween: Tween = null
var game_tween: Tween = null

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
var menu_track: String = "res://assets/music/menu_theme.mp3"

# ── SFX file paths ────────────────────────────────────────────────────────────
# Place these .wav files in res://assets/sfx/
var sfx_paths: Dictionary = {
	"win":         "res://assets/sfx/win.wav",
	"lose":        "res://assets/sfx/loss.wav",
	"loss":        "res://assets/sfx/loss.wav",
	"item_found":  "res://assets/sfx/sparkle.wav",
	"sparkle":     "res://assets/sfx/sparkle.wav",
	"wrong_click": "res://assets/sfx/wrong_click.wav",
	"button":      "res://assets/sfx/button.wav",
	"click":       "res://assets/sfx/button.wav",
	"star_fill":   "res://assets/sfx/star.wav",
	"star":        "res://assets/sfx/star.wav",
	"coin":        "res://assets/sfx/coin.wav",
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

	# Failsafe continuous loop reconnection
	menu_player.finished.connect(func():
		if current_track_id == "menu" and GameManager and GameManager.music_enabled:
			menu_player.play()
	)
	game_player.finished.connect(func():
		if current_track_id != "menu" and current_track_id != "" and GameManager and GameManager.music_enabled:
			game_player.play()
	)

	# Preload all available SFX
	for key in sfx_paths:
		var path = sfx_paths[key]
		if ResourceLoader.exists(path):
			sfx_cache[key] = load(path)
	
	# Auto-wire tap sound for EVERY button in the game
	get_tree().node_added.connect(_on_node_added)
	call_deferred("_connect_all_buttons_in_tree")


# ── Public API: Music ─────────────────────────────────────────────────────────

## Play the menu/splash background music. Crossfades from game music if playing.
func play_menu_music():
	if not GameManager.music_enabled:
		stop_all()
		return
	if current_track_id == "menu":
		return
	current_track_id = "menu"
	var track_to_play = menu_track
	if not ResourceLoader.exists(track_to_play):
		track_to_play = "res://assets/music/menu_theme.wav"
	if not ResourceLoader.exists(track_to_play):
		track_to_play = "res://assets/menu/menu_theme.wav"
	_play_track(menu_player, track_to_play, MENU_VOLUME_DB)
	_fade_out(game_player)


## Play the category-specific background music for gameplay.
func play_game_music(category_id: String = ""):
	if not GameManager.music_enabled:
		stop_all()
		return
		
	if category_id == "" and GameManager and GameManager.selected_level_id != "":
		category_id = GameManager.selected_level_id
	if category_id == "":
		category_id = "drawing_room"
		
	var key = category_id.to_lower().strip_edges()
	# Normalize common aliases
	if key == "drawingroom": key = "drawing_room"
	elif key == "bedroom": key = "bed_room"
	elif key == "diningroom": key = "dining_room"
	elif key == "storeroom": key = "store_room"
	elif key == "studyroom": key = "study_room"
	
	if current_track_id == key and game_player.playing:
		return
		
	current_track_id = key
	
	var track_to_play: String = ""
	if category_tracks.has(key):
		track_to_play = category_tracks[key]
	elif ResourceLoader.exists("res://assets/music/" + key + ".wav"):
		track_to_play = "res://assets/music/" + key + ".wav"
	elif ResourceLoader.exists("res://assets/music/" + key + ".mp3"):
		track_to_play = "res://assets/music/" + key + ".mp3"
	else:
		track_to_play = category_tracks.get("drawing_room", "res://assets/music/drawing_room.wav")
		
	if ResourceLoader.exists(track_to_play):
		_play_track(game_player, track_to_play, GAME_VOLUME_DB)
		_fade_out(menu_player)
	else:
		_fade_out(menu_player)
		_fade_out(game_player)


## Stop all music with a fade out.
func stop_all():
	current_track_id = ""
	_fade_out(menu_player)
	_fade_out(game_player)


## Call this when music_enabled setting is toggled.
func on_music_setting_changed():
	if not GameManager.music_enabled:
		stop_all()
	else:
		var current_scene = get_tree().current_scene
		if current_scene:
			if current_scene.name == "MainMenu" or current_scene.name == "MainMenuScene" or current_scene.name == "main_menu":
				play_menu_music()
			else:
				play_game_music()


# ── Public API: Sound Effects ─────────────────────────────────────────────────

## Play a one-shot sound effect by name.
## Names: "win", "lose", "item_found", "wrong_click", "button", "star_fill"
func play_sfx(sfx_name: String, volume_db: float = SFX_VOLUME_DB, pitch: float = 1.0):
	if not GameManager.sound_enabled:
		return
	var stream = sfx_cache.get(sfx_name, null)
	if stream == null:
		return
	# Use a fresh player so multiple SFX can overlap
	var player = AudioStreamPlayer.new()
	player.bus = "Master"
	player.volume_db = volume_db
	player.pitch_scale = pitch
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
		
	# Enable loop on stream dynamically based on audio format
	if stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		if stream.loop_end <= stream.loop_begin:
			var bytes_per_sample = 2 if stream.format == AudioStreamWAV.FORMAT_16_BITS else 1
			var channels = 2 if stream.stereo else 1
			stream.loop_end = int(stream.data.size() / (bytes_per_sample * channels))
	elif "loop" in stream:
		stream.loop = true
		
	player.stream = stream
	player.volume_db = -40.0
	player.play()
	
	if player == game_player:
		if game_tween and game_tween.is_valid():
			game_tween.kill()
		game_tween = create_tween()
		game_tween.tween_property(player, "volume_db", target_db, FADE_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	elif player == menu_player:
		if menu_tween and menu_tween.is_valid():
			menu_tween.kill()
		menu_tween = create_tween()
		menu_tween.tween_property(player, "volume_db", target_db, FADE_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _fade_out(player: AudioStreamPlayer):
	if not player.playing:
		return
	if player == game_player:
		if game_tween and game_tween.is_valid():
			game_tween.kill()
		game_tween = create_tween()
		game_tween.tween_property(player, "volume_db", -40.0, FADE_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		game_tween.tween_callback(func():
			if player == game_player and current_track_id == "menu":
				player.stop()
		)
	elif player == menu_player:
		if menu_tween and menu_tween.is_valid():
			menu_tween.kill()
		menu_tween = create_tween()
		menu_tween.tween_property(player, "volume_db", -40.0, FADE_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		menu_tween.tween_callback(func():
			if player == menu_player and current_track_id != "menu":
				player.stop()
		)





# â”€â”€ Universal Button Tap Sound Automation â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

func _connect_all_buttons_in_tree() -> void:
	if not is_inside_tree():
		return
	_scan_and_bind_buttons(get_tree().root)

func _scan_and_bind_buttons(node: Node) -> void:
	if node is BaseButton:
		_bind_button(node)
	for child in node.get_children():
		_scan_and_bind_buttons(child)

func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		_bind_button(node)

func _bind_button(btn: BaseButton) -> void:
	# Avoid binding hidden object items (they have their own star/wrong sounds)
	if "item_id" in btn or (btn.get_script() and "hidden_item" in btn.get_script().resource_path):
		return
	var cb = Callable(self, "_on_any_button_pressed")
	if not btn.pressed.is_connected(cb):
		btn.pressed.connect(cb)

func _on_any_button_pressed() -> void:
	play_click()

func play_click() -> void:
	play_sfx("button", -4.0, randf_range(0.97, 1.03))
