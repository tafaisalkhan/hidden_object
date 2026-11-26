extends Button

var cooldown_time: float = 0.0

func _ready():
	pressed.connect(_on_pressed)

func _process(delta):
	if cooldown_time > 0.0:
		cooldown_time -= delta
		if cooldown_time <= 0.0:
			text = "💡 Hint"
		else:
			text = "💡 Hint (%ds)" % int(ceil(cooldown_time))
	else:
		if text != "💡 Hint":
			text = "💡 Hint"

func _on_pressed():
	var main_scene = get_tree().current_scene
	var is_edit = main_scene.get("edit_mode") if main_scene else false
	if is_edit:
		return
		
	if not main_scene or not main_scene.has_method("trigger_hint"):
		return
		
	if cooldown_time <= 0.0:
		# Free hint ready
		if main_scene.trigger_hint():
			cooldown_time = 15.0
	else:
		# Cooldown active: Use 50 coins or opt-in rewarded video
		if GameManager and GameManager.spend_coins(50):
			main_scene.trigger_hint()
			cooldown_time = 0.0
		elif AdManager and AdManager.is_rewarded_ready():
			AdManager.show_rewarded_ad(func():
				if is_instance_valid(main_scene) and main_scene.has_method("trigger_hint"):
					main_scene.trigger_hint()
					cooldown_time = 0.0
			)
		else:
			var store_scene = load("res://scenes/ui_screens/store_ui.tscn")
			if store_scene:
				var store = store_scene.instantiate()
				main_scene.add_child(store)
