extends Button

var cooldown_time: float = 0.0

func _ready():
	pressed.connect(_on_pressed)

func _process(delta):
	# Handle autonomous cooldown countdown internally
	if cooldown_time > 0.0:
		cooldown_time -= delta
		if cooldown_time <= 0.0:
			text = "Hint 💡"
		else:
			text = "🎬 Hint (" + str(int(ceil(cooldown_time))) + "s)"

func _on_pressed():
	var main_scene = get_tree().current_scene
	var is_edit = main_scene.get("edit_mode") if main_scene else false
	if is_edit:
		return # Disable hints during editing
		
	if not main_scene or not main_scene.has_method("trigger_hint"):
		return
		
	if cooldown_time <= 0.0:
		# Free hint available
		if main_scene.trigger_hint():
			cooldown_time = 15.0
	else:
		# Cooldown active: Offer instant hint via Rewarded Video Ad!
		AdManager.show_rewarded_ad(func():
			if is_instance_valid(main_scene) and main_scene.has_method("trigger_hint"):
				main_scene.trigger_hint()
				cooldown_time = 0.0
		)
