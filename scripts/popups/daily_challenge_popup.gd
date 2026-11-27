extends CanvasLayer

@onready var frame_box: Control = $Dimmer/Center/FrameBox
@onready var action_btn: Button = $Dimmer/Center/FrameBox/Panel/VBox/ActionBtn
@onready var close_btn: Button = $Dimmer/Center/FrameBox/CloseBtn
@onready var desc_lbl: Label = $Dimmer/Center/FrameBox/Panel/VBox/Description
@onready var progress_lbl: Label = $Dimmer/Center/FrameBox/Panel/VBox/ProgressLabel
@onready var progress_bar: ProgressBar = $Dimmer/Center/FrameBox/Panel/VBox/ProgressBar

const CHALLENGE_TARGET := 10
const CHALLENGE_REWARD := 150
var _claiming: bool = false

func _ready() -> void:
	close_btn.pressed.connect(_close)
	action_btn.pressed.connect(_on_action_pressed)
	_setup_challenge_status()
	_animate_in()

func _setup_challenge_status() -> void:
	var completed: bool = PopupManager.is_daily_challenge_completed() if PopupManager else false
	var current_count: int = PopupManager.get_daily_challenge_progress() if PopupManager else 0

	progress_bar.max_value = CHALLENGE_TARGET
	progress_bar.value = clampi(current_count, 0, CHALLENGE_TARGET)
	progress_lbl.text = "%d / %d Objects Found" % [int(progress_bar.value), CHALLENGE_TARGET]

	if completed:
		action_btn.disabled = true
		action_btn.text = "CHALLENGE COMPLETED! ✓"
		desc_lbl.text = "Incredible work, Detective! You completed today's challenge.\nNew mission available tomorrow!"
	elif current_count >= CHALLENGE_TARGET:
		action_btn.disabled = false
		action_btn.text = "CLAIM +%d COINS!" % CHALLENGE_REWARD
		desc_lbl.text = "Goal accomplished! Tap below to claim your reward."
	else:
		action_btn.disabled = false
		action_btn.text = "PLAY CHALLENGE NOW"
		desc_lbl.text = "Find %d hidden objects across any room today to earn a huge +%d coin bonus!" % [CHALLENGE_TARGET, CHALLENGE_REWARD]

func _animate_in() -> void:
	var box_size := frame_box.size if frame_box.size != Vector2.ZERO else frame_box.custom_minimum_size
	frame_box.pivot_offset = box_size * 0.5
	frame_box.scale = Vector2(0.7, 0.7)
	frame_box.modulate.a = 0.0
	var tw = create_tween().set_parallel(true)
	tw.tween_property(frame_box, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(frame_box, "modulate:a", 1.0, 0.2)

func _close() -> void:
	var box_size := frame_box.size if frame_box.size != Vector2.ZERO else frame_box.custom_minimum_size
	frame_box.pivot_offset = box_size * 0.5
	var tw = create_tween().set_parallel(true)
	tw.tween_property(frame_box, "scale", Vector2(0.8, 0.8), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(frame_box, "modulate:a", 0.0, 0.15)
	tw.chain().tween_callback(queue_free)

func _on_action_pressed() -> void:
	if _claiming:
		return
	var current_count: int = PopupManager.get_daily_challenge_progress() if PopupManager else 0
	var completed: bool = PopupManager.is_daily_challenge_completed() if PopupManager else false
	if completed:
		return
	if current_count >= CHALLENGE_TARGET:
		_claiming = true
		action_btn.disabled = true
		if PopupManager and PopupManager.has_method("claim_daily_challenge"):
			var reward: int = PopupManager.claim_daily_challenge(self)
			_setup_challenge_status()
			if reward > 0 and PopupManager.has_method("play_flying_coins_effect"):
				PopupManager.play_flying_coins_effect(self, action_btn.global_position + action_btn.size * 0.5, Vector2.ZERO, func():
					if is_instance_valid(self):
						_close()
				)
				return
		_close()
	else:
		var tree := get_tree()
		_close()
		if tree:
			tree.change_scene_to_file("res://main/daily_challenge.tscn")
