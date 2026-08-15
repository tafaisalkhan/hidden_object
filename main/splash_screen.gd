extends Control

@onready var splash_texture = $SplashImage
@onready var spinner = $BottomLoadingContainer/SpinnerHBox/Spinner
@onready var loading_label = $BottomLoadingContainer/SpinnerHBox/LoadingLabel
@onready var progress_bar = $BottomLoadingContainer/ProgressBar

var spinner_angle: float = 0.0
var is_loading_finished: bool = false

func _ready():
	# Ensure clear background matches
	RenderingServer.set_default_clear_color(Color(0.04, 0.06, 0.12, 1.0))
	
	# Start menu background music
	if MusicManager:
		MusicManager.play_menu_music()
	
	if spinner:
		spinner.draw.connect(_on_spinner_draw)
	
	# Start with transparent splash for a smooth fade-in
	modulate.a = 0.0
	progress_bar.value = 0.0
	
	var tween = create_tween()
	# 1. Fade in screen
	tween.tween_property(self, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# 2. Animate loading bar to 100%
	tween.tween_property(progress_bar, "value", 100.0, 2.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	# 3. Short hold
	tween.tween_interval(0.3)
	# 4. Fade out
	tween.tween_property(self, "modulate:a", 0.0, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_callback(_on_splash_completed)

func _process(delta: float) -> void:
	if not is_loading_finished and is_instance_valid(spinner):
		spinner_angle += delta * 6.0 # Rotate ~340 deg/sec
		spinner.queue_redraw()

func _on_spinner_draw():
	if not is_instance_valid(spinner): return
	var center = spinner.size / 2.0
	var radius = min(center.x, center.y) - 4.0
	if radius <= 0: return
	
	# Background faint track
	spinner.draw_arc(center, radius, 0.0, TAU, 32, Color(0.2, 0.4, 0.7, 0.3), 3.0, true)
	# Glowing active spinning arc
	var start_a = spinner_angle
	var end_a = spinner_angle + PI * 1.2
	spinner.draw_arc(center, radius, start_a, end_a, 24, Color(0.2, 0.85, 1.0, 0.95), 3.5, true)

func _gui_input(event):
	# Allow player to tap to skip splash after brief initial load
	if event is InputEventMouseButton and event.pressed and progress_bar.value > 30.0:
		_on_splash_completed()
	elif event is InputEventScreenTouch and event.pressed and progress_bar.value > 30.0:
		_on_splash_completed()

func _on_splash_completed():
	if is_loading_finished: return
	is_loading_finished = true
	get_tree().change_scene_to_file("res://main/main_menu.tscn")
