extends CanvasLayer

@onready var score_label = $MarginContainer/HBoxContainer/ScoreContainer/ScoreLabel
@onready var lives_label = $MarginContainer/HBoxContainer/HeartsContainer/LivesLabel
@onready var heart_icon = $MarginContainer/HBoxContainer/HeartsContainer/HeartIcon
@onready var exit_btn = $MarginContainer/HBoxContainer/HeartsContainer/ExitBtn
@onready var coins_btn = $MarginContainer/HBoxContainer/CoinsBtn

var last_lives: int = -1

func _ready():
	SignalHub.score_updated.connect(_on_score_updated)
	SignalHub.lives_updated.connect(_on_lives_updated)
	SignalHub.coins_updated.connect(_on_coins_updated)
	if exit_btn:
		exit_btn.pressed.connect(_on_exit_pressed)
	if coins_btn:
		coins_btn.pressed.connect(_on_coins_btn_pressed)
		_update_coins_display()

func _update_coins_display():
	if coins_btn:
		var coins_val: int = GameManager.coins if GameManager else 0
		coins_btn.text = " %d +" % coins_val

func _on_coins_btn_pressed():
	var store_scene = load("res://scenes/ui_screens/store_ui.tscn")
	if store_scene:
		var store = store_scene.instantiate()
		get_tree().current_scene.add_child(store)

func _on_exit_pressed():
	AdManager.set_gameplay_active(false)
	if GameManager:
		GameManager.return_to_level_select = true
	get_tree().change_scene_to_file("res://main/main_menu.tscn")

func _on_score_updated(new_score: int):
	score_label.text = "Score: " + str(new_score)

func _on_lives_updated(new_lives: int):
	lives_label.text = "x " + str(new_lives)
	
	if last_lives != -1 and new_lives < last_lives:
		_animate_heart_shake()
	last_lives = new_lives

func _on_coins_updated(new_balance: int):
	if coins_btn:
		coins_btn.text = " %d +" % new_balance
		pulse_coin_button()

func pulse_coin_button() -> void:
	if coins_btn:
		coins_btn.pivot_offset = coins_btn.size * 0.5
		var tw = coins_btn.create_tween()
		tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.tween_property(coins_btn, "scale", Vector2(1.25, 1.25), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(coins_btn, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

func _animate_heart_shake():
	if not heart_icon:
		return
	
	heart_icon.modulate = Color(1, 0.2, 0.2, 1)
	
	var tween = create_tween()
	var orig_pos = heart_icon.position
	
	for i in range(4):
		var offset_x = randf_range(-4, 4)
		var offset_y = randf_range(-4, 4)
		tween.tween_property(heart_icon, "position", orig_pos + Vector2(offset_x, offset_y), 0.04)
	
	tween.tween_property(heart_icon, "position", orig_pos, 0.04)
	tween.tween_property(heart_icon, "modulate", Color(1, 1, 1, 1), 0.15)
