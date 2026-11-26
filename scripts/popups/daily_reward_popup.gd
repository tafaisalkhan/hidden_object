extends CanvasLayer

@onready var frame_box = $Dimmer/Center/FrameBox
@onready var claim_btn = $Dimmer/Center/FrameBox/Panel/VBox/ClaimBtn
@onready var close_btn = $Dimmer/Center/FrameBox/CloseBtn
@onready var streak_label = $Dimmer/Center/FrameBox/Panel/VBox/StreakLabel

const REWARDS: Array[int] = [50, 75, 100, 150, 200, 250, 500]

func _ready():
	close_btn.pressed.connect(_close)
	claim_btn.pressed.connect(_on_claim_pressed)
	_setup_cards()
	_animate_in()

func _setup_cards():
	var streak: int = PopupManager._load_streak() if PopupManager else 0
	var can_claim: bool = PopupManager._can_claim_today() if PopupManager else true
	var current_day_idx: int = (streak % 7)
	
	streak_label.text = "CURRENT STREAK: %d DAYS" % streak
	
	for i in range(7):
		var card = find_child("Card%d" % (i + 1), true, false)
		if not card: continue
		var day_lbl = card.get_node_or_null("DayLabel")
		var coin_lbl = card.get_node_or_null("CoinLabel")
		var status_lbl = card.get_node_or_null("StatusLabel")
		
		if day_lbl:
			if i == 6:
				day_lbl.text = "DAY 7 - GRAND PRIZE"
			else:
				day_lbl.text = "Day %d" % (i + 1)
				
		if coin_lbl:
			if i == 6:
				coin_lbl.text = "+%d COINS" % REWARDS[i]
			else:
				coin_lbl.text = "+%d" % REWARDS[i]
		
		if i < current_day_idx:
			if status_lbl: status_lbl.text = "CLAIMED ✓"
			card.modulate = Color(0.6, 0.8, 0.6, 0.85)
		elif i == current_day_idx and can_claim:
			if status_lbl: status_lbl.text = "READY! 🎁"
			card.modulate = Color(1.0, 1.0, 1.0, 1.0)
		elif i == current_day_idx and not can_claim:
			if status_lbl: status_lbl.text = "CLAIMED ✓"
			card.modulate = Color(0.6, 0.8, 0.6, 0.85)
		else:
			if status_lbl: status_lbl.text = "LOCKED 🔒"
			card.modulate = Color(0.5, 0.55, 0.65, 0.65)
	
	if can_claim:
		claim_btn.disabled = false
		claim_btn.text = "COLLECT +%d COINS! 🎁" % REWARDS[current_day_idx]
	else:
		claim_btn.disabled = true
		claim_btn.text = "COME BACK TOMORROW ⏰"

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

func _on_claim_pressed():
	if PopupManager and PopupManager.has_method("claim_daily_reward"):
		var reward_coins = PopupManager.claim_daily_reward(self)
		if PopupManager.has_method("play_flying_coins_effect"):
			PopupManager.play_flying_coins_effect(self, claim_btn.global_position + claim_btn.size * 0.5, Vector2.ZERO, func():
				_close()
			)
			return
	_close()