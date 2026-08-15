extends CanvasLayer

@onready var zoom_in_btn = $MarginContainer/VBoxContainer/ZoomIn
@onready var zoom_out_btn = $MarginContainer/VBoxContainer/ZoomOut
@onready var reset_btn = $MarginContainer/VBoxContainer/Reset

var drag_scroll: Control

func _ready():
	if get_parent():
		drag_scroll = get_parent().find_child("ViewportControl", true, false)
	if not drag_scroll and get_tree().current_scene:
		drag_scroll = get_tree().current_scene.find_child("ViewportControl", true, false)
	
	if zoom_in_btn:
		zoom_in_btn.pressed.connect(_on_zoom_in_pressed)
		_setup_button_effects(zoom_in_btn)
	if zoom_out_btn:
		zoom_out_btn.pressed.connect(_on_zoom_out_pressed)
		_setup_button_effects(zoom_out_btn)
	if reset_btn:
		reset_btn.pressed.connect(_on_reset_pressed)
		_setup_button_effects(reset_btn)

func _on_zoom_in_pressed():
	if drag_scroll and drag_scroll.has_method("zoom_by_button"):
		drag_scroll.zoom_by_button(true)

func _on_zoom_out_pressed():
	if drag_scroll and drag_scroll.has_method("zoom_by_button"):
		drag_scroll.zoom_by_button(false)

func _on_reset_pressed():
	if drag_scroll and drag_scroll.has_method("reset_zoom"):
		drag_scroll.reset_zoom()

func _setup_button_effects(btn: Button):
	# Add nice hover and press visual transitions for a premium game feel
	btn.pivot_offset = btn.size / 2.0
	
	btn.mouse_entered.connect(func():
		var tween = create_tween()
		tween.tween_property(btn, "scale", Vector2(1.1, 1.1), 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	)
	
	btn.mouse_exited.connect(func():
		var tween = create_tween()
		tween.tween_property(btn, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	)
	
	btn.button_down.connect(func():
		var tween = create_tween()
		tween.tween_property(btn, "scale", Vector2(0.9, 0.9), 0.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	)
	
	btn.button_up.connect(func():
		var tween = create_tween()
		var target_scale = Vector2(1.1, 1.1) if btn.is_hovered() else Vector2.ONE
		tween.tween_property(btn, "scale", target_scale, 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	)
