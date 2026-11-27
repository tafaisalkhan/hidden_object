extends Node

# ── Music & SFX Manager Autoload ──────────────────────────────────────────────
# Plays distinct background music per room & sublevel during gameplay,
# and menu music on menus. Also plays one-shot sound effects for game events.

# ── Audio Players ─────────────────────────────────────────────────────────────
var menu_player: AudioStreamPlayer
var game_player: AudioStreamPlayer
var current_track_id: String = ""

# ── Crossfade settings ────────────────────────────────────────────────────────
const FADE_DURATION: float = 0.8
const MENU_VOLUME_DB: float = -6.0
const GAME_VOLUME_DB: float = -4.0
const SFX_VOLUME_DB: float = -4.0

var menu_tween: Tween = null
var game_tween: Tween = null

# Ordered track rotation list so every sublevel (Level 1..10) plays a different track!
const ROOM_ORDER: Array[String] = [
	"drawing_room",
	"kitchen",
	"study_room",
	"bed_room",
	"dining_room",
	"basement",
	"store_room",
]

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

	# Seamless continuous loop reconnection for both players
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
	if current_track_id == "menu" and menu_player.playing and is_equal_approx(menu_player.volume_db, MENU_VOLUME_DB):
		return
	current_track_id = "menu"
	var track_to_play = menu_track
	if not ResourceLoader.exists(track_to_play):
		track_to_play = "res://assets/music/menu_theme.wav"
	if not ResourceLoader.exists(track_to_play):
		track_to_play = "res://assets/menu/menu_theme.wav"
	_play_track(menu_player, track_to_play, MENU_VOLUME_DB, 1.0)
	_fade_out(game_player)


## Play dedicated background music for each room.
## Each room has its authentic atmospheric soundtrack (kitchen.wav, drawing_room.wav, basement.wav, etc.)
func play_game_music(category_id: String = "", sublevel_id: String = ""):
	if not GameManager.music_enabled:
		stop_all()
		return
		
	if category_id == "" and GameManager and GameManager.selected_level_id != "":
		category_id = GameManager.selected_level_id
	if category_id == "":
		category_id = "drawing_room"

	if sublevel_id == "" and GameManager and GameManager.selected_sublevel_id != "":
		sublevel_id = GameManager.selected_sublevel_id
		
	var key = _normalize_room_key(category_id)
	var sub_key = sublevel_id.to_lower().strip_edges()
	var sub_num: int = 1
	if sub_key.begins_with("sub"):
		sub_num = maxi(1, int(sub_key.substr(3)))

	var composite_id: String = key if sub_key.is_empty() else ("%s_%s" % [key, sub_key])
	if current_track_id == composite_id and game_player.playing and is_equal_approx(game_player.volume_db, GAME_VOLUME_DB):
		return

	current_track_id = composite_id

	var resolved := resolve_track_for_level(key, sub_num)
	var track_to_play: String = str(resolved["path"])
	var pitch_val: float = float(resolved["pitch"])

	if ResourceLoader.exists(track_to_play):
		_play_track(game_player, track_to_play, GAME_VOLUME_DB, pitch_val)
		_fade_out(menu_player)
	else:
		_fade_out(menu_player)
		_fade_out(game_player)


func _normalize_room_key(raw_id: String) -> String:
	var key = raw_id.to_lower().strip_edges()
	if key == "drawingroom": return "drawing_room"
	if key == "bedroom": return "bed_room"
	if key == "diningroom": return "dining_room"
	if key == "storeroom": return "store_room"
	if key == "studyroom": return "study_room"
	return key


func resolve_track_for_level(room_key: String, sub_num: int = 1) -> Dictionary:
	# 1. Custom sublevel-specific audio file check
	var custom_wav := "res://assets/music/%s_sub%d.wav" % [room_key, sub_num]
	if ResourceLoader.exists(custom_wav):
		return {"path": custom_wav, "pitch": 1.0, "track_key": "%s_sub%d" % [room_key, sub_num]}
	var custom_mp3 := "res://assets/music/%s_sub%d.mp3" % [room_key, sub_num]
	if ResourceLoader.exists(custom_mp3):
		return {"path": custom_mp3, "pitch": 1.0, "track_key": "%s_sub%d" % [room_key, sub_num]}

	# 2. Consistent dedicated room soundtrack (kitchen -> kitchen.wav, basement -> basement.wav, etc.)
	var key = _normalize_room_key(room_key)
	if category_tracks.has(key):
		var path = str(category_tracks[key])
		if ResourceLoader.exists(path):
			return {"path": path, "pitch": 1.0, "track_key": key}

	return {"path": "res://assets/music/drawing_room.wav", "pitch": 1.0, "track_key": "drawing_room"}


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

func play_sfx(sfx_name: String, volume_db: float = SFX_VOLUME_DB, pitch: float = 1.0):
	if not GameManager.sound_enabled:
		return
	var stream = sfx_cache.get(sfx_name, null)
	if stream == null:
		return
	var player = AudioStreamPlayer.new()
	player.bus = "Master"
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.stream = stream
	add_child(player)
	player.play()
	player.finished.connect(func(): player.queue_free())


# ── Internal ──────────────────────────────────────────────────────────────────

func _play_track(player: AudioStreamPlayer, path: String, target_db: float, pitch_scale_val: float = 1.0):
	if not ResourceLoader.exists(path):
		return
	var stream = load(path)
	if stream == null:
		return

	# Immediately kill any active fade-out/in tween on this player
	if player == menu_player and menu_tween and menu_tween.is_valid():
		menu_tween.kill()
		menu_tween = null
	elif player == game_player and game_tween and game_tween.is_valid():
		game_tween.kill()
		game_tween = null

	# If the stream is already loaded and playing, just bring volume back to target_db smoothly!
	if player.stream == stream and is_equal_approx(player.pitch_scale, pitch_scale_val) and player.playing:
		var tw := create_tween()
		tw.tween_property(player, "volume_db", target_db, FADE_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		if player == menu_player:
			menu_tween = tw
		else:
			game_tween = tw
		return
		
	# Enable accurate full-length loop on stream based on audio format
	if stream is AudioStreamWAV:
		var total_frames: int = int(round(stream.get_length() * float(stream.mix_rate)))
		if total_frames <= 0:
			var bytes_per_sample = 2 if stream.format == AudioStreamWAV.FORMAT_16_BITS else 1
			var channels = 2 if stream.stereo else 1
			total_frames = int(stream.data.size() / (bytes_per_sample * channels))
		stream.loop_begin = 0
		stream.loop_end = total_frames
		if stream.format in [AudioStreamWAV.FORMAT_8_BITS, AudioStreamWAV.FORMAT_16_BITS, AudioStreamWAV.FORMAT_IMA_ADPCM]:
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		else:
			# For QOA (format 3), keep LOOP_DISABLED so player.finished cleanly restarts full 30s track
			stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	elif "loop" in stream:
		stream.loop = true
		
	player.stop()
	player.stream = stream
	player.pitch_scale = pitch_scale_val
	player.volume_db = -32.0
	player.play()
	
	var tw2 := create_tween()
	tw2.tween_property(player, "volume_db", target_db, FADE_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if player == menu_player:
		menu_tween = tw2
	else:
		game_tween = tw2


func _fade_out(player: AudioStreamPlayer):
	if not player.playing:
		return
	if player == game_player:
		if game_tween and game_tween.is_valid():
			game_tween.kill()
		game_tween = create_tween()
		game_tween.tween_property(player, "volume_db", -45.0, FADE_DURATION * 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		game_tween.tween_callback(func():
			if player == game_player and current_track_id == "menu":
				player.stop()
		)
	elif player == menu_player:
		if menu_tween and menu_tween.is_valid():
			menu_tween.kill()
		menu_tween = create_tween()
		menu_tween.tween_property(player, "volume_db", -45.0, FADE_DURATION * 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		menu_tween.tween_callback(func():
			if player == menu_player and current_track_id != "menu":
				player.stop()
		)


# ── Universal Button Tap Sound Automation ────────────────────────────────────

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
	if "item_id" in btn or (btn.get_script() and "hidden_item" in btn.get_script().resource_path):
		return
	var cb = Callable(self, "_on_any_button_pressed")
	if not btn.pressed.is_connected(cb):
		btn.pressed.connect(cb)

func _on_any_button_pressed() -> void:
	play_click()

func play_click() -> void:
	play_sfx("button", -4.0, randf_range(0.97, 1.03))
