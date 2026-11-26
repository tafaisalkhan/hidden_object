extends CanvasLayer

@onready var frame_box = $Dimmer/Center/FrameBox
@onready var action_btn = $Dimmer/Center/FrameBox/Panel/VBox/ActionBtn
@onready var close_btn = $Dimmer/Center/FrameBox/CloseBtn
@onready var desc_lbl = $Dimmer/Center/FrameBox/Panel/VBox/Description
@onready var progress_lbl = $Dimmer/Center/FrameBox/Panel/VBox/ProgressLabel
@onready var progress_bar = $Dimmer/Center/FrameBox/Panel/VBox/ProgressBar

const CHALLENGE_TARGET := 10
const CHALLENGE_REWARD := 150

func _ready():
	close_btn.pressed.connect(_close)
	action_btn.pressed.connect(_on_action_pressed)
	_setup_challenge_status()
	_animate_in()

func _setup_challenge_status():
	var completed = PopupManager.is_daily_challenge_completed() if PopupManager else false
	var current_count = PopupManager.get_daily_challenge_progress() if PopupManager else 0
	
	progress_bar.max_value = CHALLENGE_TARGET
	progress_bar.value = clamp(current_count, 0, CHALLENGE_TARGET)
	progress_lbl.text = "%d / %d Objects Found" % [progress_bar.value, CHALLENGE_TARGET]
	
	if completed:
		action_btn.disabled = true
		action_btn.text = "CHALLENGE COMPLETED! ✓"
		desc_lbl.text = "Incredible work, Detective! You completed today's challenge.\nNew mission available tomorrow!"
	elif current_count >= CHALLENGE_TARGET:
		action_btn.disabled = false
		action_btn.text = "CLAIM +%d COINS! 🎁" % CHALLENGE_REWARD
		desc_lbl.text = "Goal accomplished! Tap below to claim your reward."
	else:
		action_btn.disabled = false
		action_btn.text = "PLAY CHALLENGE NOW"
		desc_lbl.text = "Find %d hidden objects across any room today to earn a huge +%d coin bonus!" % [CHALLENGE_TARGET, CHALLENGE_REWARD]

func _animate_in():
	frame_box.pivot_offset = frame_box.size * 0.5
	frame_box.scale = Vector2(0.7, 0.7)
	frame_box.modulate.a = 0.0
	var tw = create_tween().set_parallel(true)
	tw.tween_property(frame_box, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(frame_box, "modulate:a", 1.0, 0.2)

func _close():
	var tw = create_tween().set_parallel(true)
	tw.tween_property(frame_box, "scale", Vector2(0.8, 0.8), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(frame_box, "modulate:a", 0.0, 0.15)
	tw.chain().tween_callback(queue_free)

func _on_action_pressed():
	var current_count = PopupManager.get_daily_challenge_progress() if PopupManager else 0
	if current_count >= CHALLENGE_TARGET:
		if PopupManager and PopupManager.has_method("claim_daily_challenge"):
			PopupManager.claim_daily_challenge(self)
			if PopupManager.has_method("play_flying_coins_effect"):
				PopupManager.play_flying_coins_effect(self, action_btn.global_position + action_btn.size * 0.5, Vector2.ZERO, func():
					_close()
				)
				return
		_close()
	else:
		# Launch play mode
		_close()
		var tree = get_tree()
		if tree.current_scene and tree.current_scene.has_method("_on_start_button_pressed"):
			tree.current_scene._on_start_button_pressed()
