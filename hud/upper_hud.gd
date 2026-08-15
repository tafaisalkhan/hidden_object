extends CanvasLayer

@onready var score_label = $MarginContainer/HBoxContainer/ScoreContainer/ScoreLabel
@onready var lives_label = $MarginContainer/HBoxContainer/HeartsContainer/LivesLabel
@onready var heart_icon = $MarginContainer/HBoxContainer/HeartsContainer/HeartIcon
@onready var exit_btn = $MarginContainer/HBoxContainer/HeartsContainer/ExitBtn

var last_lives: int = -1

func _ready():
	SignalHub.score_updated.connect(_on_score_updated)
	SignalHub.lives_updated.connect(_on_lives_updated)
	if exit_btn:
		exit_btn.pressed.connect(_on_exit_pressed)

func _on_exit_pressed():
	if GameManager:
		GameManager.return_to_level_select = true
	get_tree().change_scene_to_file("res://main/main_menu.tscn")

func _on_score_updated(new_score: int):
	score_label.text = "Score: " + str(new_score)

func _on_lives_updated(new_lives: int):
	lives_label.text = "x " + str(new_lives)
	
	# If lives decreased, pulse the heart icon
	if last_lives != -1 and new_lives < last_lives:
		_play_heart_pulse()
		
	last_lives = new_lives

func _play_heart_pulse():
	# Ensure pivot is centered for a clean scaling animation
	heart_icon.pivot_offset = heart_icon.size / 2.0
	
	var tween = create_tween()
	# Scale up quickly
	tween.tween_property(heart_icon, "scale", Vector2(1.4, 1.4), 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# Bounce back to normal
	tween.tween_property(heart_icon, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
