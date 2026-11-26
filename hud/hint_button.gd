extends Button

const HINT_ICON = preload("res://assets/main/hint.png")

var is_hint_animating: bool = false

func _ready() -> void:
	pressed.connect(_on_pressed)
	SignalHub.items_progress_updated.connect(_on_progress_updated)
	SignalHub.coins_updated.connect(_on_coins_updated)
	
	if AdManager and AdManager.has_signal("rewarded_ready_changed"):
		AdManager.rewarded_ready_changed.connect(_on_ad_ready_changed)
	
	refresh_state()

func _on_progress_updated(found_count: int, total_count: int) -> void:
	if found_count >= total_count:
		disabled = true
	else:
		refresh_state()

func _on_coins_updated(_new_coins: int) -> void:
	refresh_state()

func _on_ad_ready_changed(_ready: bool) -> void:
	refresh_state()

func refresh_state() -> void:
	if is_hint_animating:
		disabled = true
		return
		
	var cost: int = GameManager.HINT_COST if GameManager else 50
	var user_coins: int = GameManager.coins if GameManager else 0
	
	icon = HINT_ICON
	
	if user_coins >= cost:
		disabled = false
		text = " %d" % cost
	else:
		# User has less than 50 coins.
		# Check if rewarded ad is ready to show.
		var ad_ready: bool = (AdManager != null and AdManager.is_rewarded_ready())
		if ad_ready:
			disabled = false
			text = "🎬 Free"
		else:
			# Ad not ready and coins < 50: disable button (Rule 1: no ad placeholder)
			disabled = true
			text = " %d" % cost

func _on_pressed() -> void:
	var main_scene = get_tree().current_scene
	if not main_scene or main_scene.get("edit_mode") or not main_scene.has_method("trigger_hint"):
		return
		
	var cost: int = GameManager.HINT_COST if GameManager else 50
	var user_coins: int = GameManager.coins if GameManager else 0
	
	if user_coins >= cost:
		is_hint_animating = true
		disabled = true
		if main_scene.trigger_hint():
			GameManager.spend_coins(cost)
		else:
			is_hint_animating = false
			refresh_state()
		return
		
	# Insufficient coins: run rewarded ad if ready
	if AdManager and AdManager.is_rewarded_ready():
		disabled = true
		AdManager.show_rewarded_ad(func(success: bool):
			if not is_instance_valid(self) or not is_instance_valid(main_scene):
				return
			if success:
				# User gets 50 coins from watching rewarded ad
				GameManager.add_coins(cost)
				is_hint_animating = true
				if main_scene.trigger_hint():
					GameManager.spend_coins(cost)
				else:
					is_hint_animating = false
			refresh_state()
		)
	else:
		refresh_state()
