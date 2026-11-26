extends CanvasLayer

@onready var score_label = $MarginContainer/HBoxContainer/ScoreContainer/ScoreLabel
@onready var lives_label = $MarginContainer/HBoxContainer/HeartsContainer/LivesLabel
@onready var heart_icon = $MarginContainer/HBoxContainer/HeartsContainer/HeartIcon
@onready var exit_btn = $MarginContainer/HBoxContainer/HeartsContainer/ExitBtn

var last_lives: int = -1

func _ready():
	SignalHub.score_updated.connect(_on_score_updated)
	SignalHub.lives_updated.connect(_on_lives_updated)
	SignalHub.coins_updated.connect(_on_coins_updated)
	if exit_btn:
		exit_btn.pressed.connect(_on_exit_pressed)
	_setup_coins_button()

func _setup_coins_button():
	var hbox = $MarginContainer/HBoxContainer
	var coin_btn = Button.new()
	coin_btn.name = "CoinsBtn"
	var coins_val: int = GameManager.coins if GameManager else 0
	coin_btn.icon = preload("res://assets/main/coin_icon.png")
	coin_btn.expand_icon = true
	coin_btn.text = " %d +" % coins_val
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.09, 0.17, 0.90) # Midnight navy
	sb.border_color = Color("#ffd54f") # Rich metallic gold border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	coin_btn.add_theme_stylebox_override("normal", sb)
	var sb_hov = sb.duplicate() as StyleBoxFlat
	sb_hov.bg_color = Color(0.12, 0.18, 0.28, 0.95)
	coin_btn.add_theme_stylebox_override("hover", sb_hov)
	coin_btn.add_theme_stylebox_override("pressed", sb)
	coin_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	coin_btn.add_theme_font_override("font", preload("res://assets/fonts/LuckiestGuy-Regular.ttf"))
	coin_btn.add_theme_font_size_override("font_size", 18)
	coin_btn.add_theme_color_override("font_color", Color("#ffd54f"))
	coin_btn.custom_minimum_size = Vector2(120, 44)
	coin_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	coin_btn.pressed.connect(func():
		var store_scene = load("res://scenes/ui_screens/store_ui.tscn")
		if store_scene:
			var store = store_scene.instantiate()
			get_tree().current_scene.add_child(store)
	)
	hbox.add_child(coin_btn)

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
		_play_heart_pulse()
	last_lives = new_lives

func _on_coins_updated(new_coins: int):
	var btn = $MarginContainer/HBoxContainer.get_node_or_null("CoinsBtn")
	if btn:
		btn.text = " %d +" % new_coins
		pulse_coin_button()

func pulse_coin_button():
	var btn = $MarginContainer/HBoxContainer.get_node_or_null("CoinsBtn")
	if btn:
		btn.pivot_offset = btn.size * 0.5
		var tw = btn.create_tween()
		tw.tween_property(btn, "scale", Vector2(1.25, 1.25), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(btn, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

func _play_heart_pulse():
	heart_icon.pivot_offset = heart_icon.size / 2.0
	var tween = create_tween()
	tween.tween_property(heart_icon, "scale", Vector2(1.4, 1.4), 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(heart_icon, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
