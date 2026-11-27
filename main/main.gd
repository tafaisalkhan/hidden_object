extends Node

@export var level_id: String = "kitchen"
@export var sublevel_id: String = "sub1"

var enable_difficulty_alpha = false
var edit_mode = false
var original_bg_size: Vector2 = Vector2.ZERO
var active_json_path: String = ""

# Ad cycle configuration variables
var ad_cycle_timer: float = 10.0
var ad_cycle_state: String = "initial_wait" # "initial_wait", "showing", "hidden_wait"

@onready var bottom_hud = $BottomHUD
@onready var upper_hud = $UpperHUD
@onready var level_container = $ViewportControl/LevelContainer
@onready var game_over_hud = $GameOverHUD
@onready var continue_btn = $GameOverHUD/CenterContainer/VBoxContainer/HBoxContainer/ContinueBtn
@onready var retry_btn = $GameOverHUD/CenterContainer/VBoxContainer/HBoxContainer/RetryBtn
@onready var menu_btn = $GameOverHUD/CenterContainer/VBoxContainer/HBoxContainer/MenuBtn

func _ready():
	# Set a beautiful dark navy clear color to match the game's theme
	# (Prevents Godot's default gray color from showing outside the background image boundaries)
	RenderingServer.set_default_clear_color(Color(0.0823529, 0.12549, 0.243137, 1.0))
	
	SignalHub.game_over.connect(_on_game_over)
	SignalHub.ads_removed.connect(func(): _set_ad_placeholder_visible(false))
	continue_btn.pressed.connect(_on_continue_pressed)
	retry_btn.pressed.connect(_on_retry_pressed)
	menu_btn.pressed.connect(_on_menu_pressed)
	
	# AdMob Anti-Suspension Rule 5 & 7: No banners or timer-based ad refresh during active gameplay
	if AdManager:
		AdManager.set_gameplay_active(true)
	_set_ad_placeholder_visible(false)
	
	if has_node("DebugHUD"):
		$DebugHUD.visible = false
	if has_node("ZoomUI"):
		$ZoomUI.visible = false
	
	if GameManager:
		if GameManager.selected_level_id != "":
			level_id = GameManager.selected_level_id
		if GameManager.selected_sublevel_id != "":
			sublevel_id = GameManager.selected_sublevel_id
	
	load_level(level_id)


func _process(_delta: float) -> void:
	# AdMob Policy Compliance: Never cycle or display banner ads during active gameplay
	pass


func _set_ad_placeholder_visible(visible: bool) -> void:
	if AdManager and AdManager.is_ad_free():
		visible = false
	elif InAppPurchaseManager and InAppPurchaseManager.is_ads_removed:
		visible = false
		
	if has_node("AdPlaceholder"):
		$AdPlaceholder.visible = visible
		
	if has_node("BottomHUD"):
		$BottomHUD.offset = Vector2(0, -90.0 if visible else 0.0)
		
	if has_node("ViewportControl"):
		var base_bottom_offset = -130.0
		var ad_height_offset = -90.0 if visible else 0.0
		$ViewportControl.offset_bottom = base_bottom_offset + ad_height_offset
		
	if not visible and AdManager:
		AdManager.hide_banner()

func load_level(id: String):
	level_id = id
	# Hide game over overlay on load
	if game_over_hud:
		game_over_hud.visible = false
	if MusicManager:
		MusicManager.play_game_music(level_id, sublevel_id)

	# Clear old level
	for child in level_container.get_children():
		child.queue_free()

	# Target JSON path for this specific level
	var target_json_path = "res://levels/" + id + "/sublevels.json"
	var load_path = target_json_path
	
	# Fallback to drawing_room template if target level JSON does not exist yet
	if not FileAccess.file_exists(load_path):
		load_path = "res://levels/drawing_room/sublevels.json"
		
	active_json_path = target_json_path
		
	var file = FileAccess.open(load_path, FileAccess.READ)
	if not file:
		print("Failed to load sublevels JSON: ", load_path)
		return
	
	var json = JSON.parse_string(file.get_as_text())
	file.close()
	
	if not json or not json.has(sublevel_id):
		print("Sublevel not found: ", sublevel_id, " in JSON: ", load_path)
		return
		
	var level_data = json[sublevel_id]
	enable_difficulty_alpha = level_data.get("enable_difficulty_alpha", false)
	
	# Load Background
	var bg_tex = load(level_data["background"])
	if bg_tex:
		var bg_size = bg_tex.get_size()
		original_bg_size = bg_size
		
		# Set size of the LevelContainer so the ScrollContainer knows the boundaries
		level_container.custom_minimum_size = bg_size
		level_container.size = bg_size
		
		# Reset zoom and clear cached base size now that original_bg_size is set
		var viewport_control = $ViewportControl
		if viewport_control:
			viewport_control.reset_zoom()
		
		# Background as TextureRect
		var bg_rect = TextureRect.new()
		bg_rect.name = "Background"
		bg_rect.texture = bg_tex
		bg_rect.size = bg_size
		bg_rect.mouse_filter = Control.MOUSE_FILTER_PASS # Allow drag events to pass through
		bg_rect.z_index = level_data.get("background_z_index", 1)
		level_container.add_child(bg_rect)
		
		# Bed as TextureRect
		if level_data.has("bed"):
			var bed_tex = load(level_data["bed"])
			var bed = TextureRect.new()
			bed.name = "Bed"
			bed.texture = bed_tex
			bed.mouse_filter = Control.MOUSE_FILTER_IGNORE # Ignore mouse so we can drag behind it
			
			var b_pos = level_data.get("bed_position", {"x": 701.9, "y": 652.2})
			var b_scale = level_data.get("bed_scale", {"x": 1.336, "y": 1.409})
			bed.position = Vector2(b_pos["x"], b_pos["y"])
			bed.scale = Vector2(b_scale["x"], b_scale["y"])
			bed.z_index = level_data.get("bed_z_index", 3)
			
			# Attach dynamic drag behavior script
			var drag_script = preload("res://hud/draggable_element.gd")
			bed.set_script(drag_script)
			
			level_container.add_child(bed)
			
		# Character as TextureRect
		if level_data.has("character"):
			var char_tex = load(level_data["character"])
			var character = TextureRect.new()
			character.name = "Character"
			character.texture = char_tex
			character.mouse_filter = Control.MOUSE_FILTER_IGNORE # Ignore mouse
			
			var c_pos = level_data.get("character_position", {"x": 709.9, "y": 451.8})
			var c_scale = level_data.get("character_scale", {"x": 0.607, "y": 0.756})
			character.position = Vector2(c_pos["x"], c_pos["y"])
			character.scale = Vector2(c_scale["x"], c_scale["y"])
			character.z_index = level_data.get("character_z_index", 2)
			
			# Attach dynamic drag behavior script
			var drag_script = preload("res://hud/draggable_element.gd")
			character.set_script(drag_script)
			
			level_container.add_child(character)
	
	# Load items
	var items_textures = []
	var hidden_item_scene = preload("res://levels/hidden_item.tscn")
	
	for item_data in level_data["items"]:
		var tex = load(item_data["texture"])
		var is_background = item_data.get("is_background", false)
		var is_target = item_data.get("is_target", true) if not is_background else false
		if is_target:
			items_textures.append(tex)
		
		var item_inst = hidden_item_scene.instantiate()
		item_inst.texture_normal = tex
		item_inst.item_id = item_data["id"]
		item_inst.is_target = is_target
		item_inst.is_background = item_data.get("is_background", false)
		
		# Position, scale, and rotate the item
		item_inst.position = Vector2(item_data["position"]["x"], item_data["position"]["y"])
		item_inst.scale = Vector2(item_data["scale"]["x"], item_data["scale"]["y"])
		item_inst.rotation_degrees = item_data.get("rotation", 0)
		item_inst.z_index = item_data.get("z_index", 4)
		
		# Parse custom modulate color
		item_inst.custom_modulate = Color.html(item_data.get("modulate", "ffffff"))
		
		# Apply mouse filters based on background state
		if is_background:
			item_inst.mouse_filter = Control.MOUSE_FILTER_IGNORE
		else:
			item_inst.mouse_filter = Control.MOUSE_FILTER_STOP
			
		level_container.add_child(item_inst)
		
	# Setup HUD
	bottom_hud.setup_items(items_textures)
	GameManager.start_level(items_textures.size())
	
	# Ensure Edit Mode starts OFF on reload
	toggle_edit_mode(false)

func _on_edit_mode_btn_pressed():
	toggle_edit_mode(!edit_mode)

func _on_save_btn_pressed():
	save_layout()
	if has_node("DebugHUD/HBoxContainer/SaveBtn"):
		var save_btn = $DebugHUD/HBoxContainer/SaveBtn
		save_btn.text = "✅ Saved! ✓"
		var timer = get_tree().create_timer(1.5)
		timer.timeout.connect(func():
			if is_instance_valid(save_btn):
				save_btn.text = "💾 Save Layout"
		)

func toggle_edit_mode(active: bool):
	edit_mode = active
	
	var edit_mode_btn = $DebugHUD/HBoxContainer/EditModeBtn if has_node("DebugHUD/HBoxContainer/EditModeBtn") else null
	var save_btn = $DebugHUD/HBoxContainer/SaveBtn if has_node("DebugHUD/HBoxContainer/SaveBtn") else null
	
	if edit_mode_btn:
		edit_mode_btn.text = "⚙️ Edit Items: ON" if edit_mode else "⚙️ Edit Items: OFF"
	if save_btn:
		save_btn.visible = edit_mode
		save_btn.text = "💾 Save Layout"
		
	if upper_hud:
		upper_hud.visible = not active
	if bottom_hud:
		bottom_hud.visible = not active
		
	for child in level_container.get_children():
		if child.name == "Background":
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE if edit_mode else Control.MOUSE_FILTER_PASS
			continue
		
		if edit_mode:
			if child.get("is_background") == true:
				child.mouse_filter = Control.MOUSE_FILTER_IGNORE
			else:
				child.mouse_filter = Control.MOUSE_FILTER_STOP
			if child.has_method("update_visual_modulation") and child.name != "Bed" and child.name != "Character":
				child.update_visual_modulation()
		else:
			if child.name == "Bed" or child.name == "Character" or child.get("is_background") == true:
				child.mouse_filter = Control.MOUSE_FILTER_IGNORE
			else:
				child.mouse_filter = Control.MOUSE_FILTER_STOP
			if child.has_method("update_visual_modulation") and child.name != "Bed" and child.name != "Character":
				child.update_visual_modulation()

func save_layout():
	var json_path = active_json_path
	if json_path == "":
		json_path = "res://levels/" + level_id + "/sublevels.json"
		
	# Ensure the target level directory exists
	var dir_path = "res://levels/" + level_id
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)
		
	var read_path = json_path
	if not FileAccess.file_exists(read_path):
		read_path = "res://levels/drawing_room/sublevels.json"
		
	var file = FileAccess.open(read_path, FileAccess.READ)
	if not file:
		print("Failed to load sublevels JSON template for saving: ", read_path)
		return
		
	var json_data = JSON.parse_string(file.get_as_text())
	file.close()
	
	if not json_data or not json_data.has(sublevel_id):
		print("Sublevel ID not found in JSON: ", sublevel_id)
		return
		
	var level_data = json_data[sublevel_id]
	level_data["enable_difficulty_alpha"] = enable_difficulty_alpha
	
	var new_items_list = []
	var has_bed = false
	var has_character = false
	
	for child in level_container.get_children():
		if child.name == "Background":
			continue
			
		var actual_pos = child.position
		if child.has_method("get_original_position"):
			actual_pos = child.get_original_position()
			
		var pos_dict = {
			"x": int(round(actual_pos.x)),
			"y": int(round(actual_pos.y))
		}
		
		if child.name == "Bed":
			has_bed = true
			level_data["bed_position"] = pos_dict
			level_data["bed_scale"] = {"x": snapped(child.scale.x, 0.01), "y": snapped(child.scale.y, 0.01)}
			level_data["bed_z_index"] = child.z_index
		elif child.name == "Character":
			has_character = true
			level_data["character_position"] = pos_dict
			level_data["character_scale"] = {"x": snapped(child.scale.x, 0.01), "y": snapped(child.scale.y, 0.01)}
			level_data["character_z_index"] = child.z_index
		elif child.has_method("_gui_input"): # It's a hidden item button
			var tex_path = ""
			if child.texture_normal:
				tex_path = child.texture_normal.resource_path
				
			var item_dict = {
				"id": child.item_id,
				"is_target": child.is_target,
				"is_background": child.is_background,
				"modulate": child.custom_modulate.to_html(true),
				"position": pos_dict,
				"rotation": int(round(child.rotation_degrees)),
				"scale": {"x": snapped(child.scale.x, 0.01), "y": snapped(child.scale.y, 0.01)},
				"texture": tex_path,
				"z_index": child.z_index
			}
			new_items_list.append(item_dict)
			
	# Update items list in database
	level_data["items"] = new_items_list
	
	# Clean up bed/character keys if deleted in Edit Mode
	if not has_bed:
		level_data.erase("bed")
		level_data.erase("bed_position")
		level_data.erase("bed_scale")
		level_data.erase("bed_z_index")
	if not has_character:
		level_data.erase("character")
		level_data.erase("character_position")
		level_data.erase("character_scale")
		level_data.erase("character_z_index")
					
	# Save updated JSON back to disk
	file = FileAccess.open(json_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(json_data, "\t"))
		file.close()
		print("Layout saved successfully to: ", json_path)
	else:
		print("Failed to save to: ", json_path)

func _on_game_over(win: bool):
	var title = get_node_or_null("GameOverHUD/CenterContainer/VBoxContainer/Title")
	var score_info = get_node_or_null("GameOverHUD/CenterContainer/VBoxContainer/ScoreInfo")
	var reward_row = get_node_or_null("GameOverHUD/CenterContainer/VBoxContainer/CoinRewardRow")
	var reward_label = get_node_or_null("GameOverHUD/CenterContainer/VBoxContainer/CoinRewardRow/RewardLabel")
	var star1 = get_node_or_null("GameOverHUD/CenterContainer/VBoxContainer/StarsContainer/Star1")
	var star2 = get_node_or_null("GameOverHUD/CenterContainer/VBoxContainer/StarsContainer/Star2")
	var star3 = get_node_or_null("GameOverHUD/CenterContainer/VBoxContainer/StarsContainer/Star3")
	var win_particles = get_node_or_null("GameOverHUD/WinParticles")
	var coin_wallet = get_node_or_null("GameOverHUD/CoinWallet")
	var coin_count = get_node_or_null("GameOverHUD/CoinWallet/CoinCount")
	
	var star_tex = preload("res://assets/main/victory-star.png")
	
	if star1 and star2 and star3:
		star1.texture = star_tex
		star2.texture = star_tex
		star3.texture = star_tex
		star1.modulate = Color(0.18, 0.22, 0.35, 0.55)
		star2.modulate = Color(0.18, 0.22, 0.35, 0.55)
		star3.modulate = Color(0.18, 0.22, 0.35, 0.55)
	
	if win:
		if title:
			title.text = "DAILY CHALLENGE COMPLETE!" if GameManager.is_daily_mode else "LEVEL COMPLETED!"
			title.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4, 1.0)) # Soft green
		
		# Play win sound
		if MusicManager:
			MusicManager.play_sfx("win")
		
		# Show Continue and Play Again buttons
		if continue_btn:
			continue_btn.visible = true
			if GameManager and GameManager.is_daily_mode:
				continue_btn.text = "Daily Calendar"
			elif GameManager and GameManager.is_arcade_mode:
				continue_btn.text = "Next Arcade Level ➔"
			else:
				var next_sub = GameManager.get_next_sublevel_id() if GameManager else ""
				if next_sub != "":
					continue_btn.text = "Continue ➔"
				else:
					continue_btn.text = "Select Level"
		if retry_btn:
			retry_btn.visible = not GameManager.is_daily_mode
			retry_btn.text = "Play Again 🔄"
		
		# Trigger particles & flying star filling animations
		if win_particles:
			win_particles.restart()
			win_particles.emitting = true
		if star1 and star2 and star3:
			_animate_victory_stars([star1, star2, star3], star_tex, GameManager.last_awarded_stars)
		if reward_row:
			reward_row.visible = true
		if reward_label:
			reward_label.text = "+" + str(GameManager.last_awarded_coins) + " coins  •  " + str(GameManager.last_awarded_stars) + " stars"
		if coin_wallet:
			coin_wallet.visible = true
			if coin_count:
				coin_count.text = str(GameManager.coins - GameManager.last_awarded_coins)
			_animate_reward_coins(GameManager.last_awarded_coins)
	else:
		if title:
			title.text = "GAME OVER"
			title.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2, 1.0)) # Soft red
		
		# Play lose sound
		if MusicManager:
			MusicManager.play_sfx("lose")
		
		# Hide Continue, show Rewarded Ad Retry button
		if continue_btn:
			continue_btn.visible = false
		if retry_btn:
			retry_btn.visible = true
			retry_btn.text = "🎬 Retry (+3 ❤)"
		if reward_row:
			reward_row.visible = false
		if coin_wallet:
			coin_wallet.visible = false
		
	if score_info:
		score_info.text = "Final Score: " + str(GameManager.score)
	if game_over_hud:
		game_over_hud.visible = true
	
	# AdMob Anti-Suspension Compliance: only check on victory, never on loss, 120s cooldown
	if is_instance_valid(self) and GameManager and GameManager.lives > 0:
		var completed_lvl_idx: int = int(GameManager.selected_sublevel_id.replace("sub", "")) if GameManager else 0
		AdManager.on_level_completed(completed_lvl_idx)

func _animate_victory_stars(stars: Array, star_tex: Texture2D, star_count: int):
	for i in range(min(stars.size(), star_count)):
		var target_star: TextureRect = stars[i]
		if not is_instance_valid(target_star):
			continue
		
		target_star.pivot_offset = target_star.size / 2.0
		target_star.scale = Vector2.ONE
		target_star.rotation_degrees = 0.0
		
		var delay = 0.35 + (i * 0.35)
		
		get_tree().create_timer(delay).timeout.connect(func():
			if not is_instance_valid(target_star) or not game_over_hud.visible:
				return
			
			target_star.pivot_offset = target_star.size / 2.0
			
			# Pop up scale, illuminate star, and bounce back into place
			var tween = create_tween()
			tween.tween_property(target_star, "scale", Vector2(1.5, 1.5), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tween.parallel().tween_property(target_star, "rotation_degrees", -10.0 if i % 2 == 0 else 10.0, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			
			# At peak of pop: illuminate to full golden color and play star sound
			tween.chain().tween_callback(func():
				if is_instance_valid(target_star):
					target_star.modulate = Color(1.0, 1.0, 1.0, 1.0)
					if MusicManager:
						MusicManager.play_sfx("star", -2.0, randf_range(0.96, 1.04))
			)
			
			# Elastic settle back to normal size
			tween.chain().tween_property(target_star, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
			tween.parallel().tween_property(target_star, "rotation_degrees", 0.0, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		)

func _animate_reward_coins(amount: int) -> void:
	var source = $GameOverHUD/CenterContainer/VBoxContainer/CoinRewardRow/CoinIcon
	var destination = $GameOverHUD/CoinWallet/CoinIcon
	var wallet_count = $GameOverHUD/CoinWallet/CoinCount
	var coin_texture = preload("res://assets/main/reward-coin.png")
	
	var start_coins: int = GameManager.coins - amount
	var target_coins: int = GameManager.coins
	
	var visual_coins: int = clampi(amount, 6, 10)
	var coins_per_visual: float = float(amount) / float(visual_coins)
	var current_visual_total: float = float(start_coins)
	
	for index in range(visual_coins):
		var delay: float = 0.45 + (index * 0.065)
		get_tree().create_timer(delay).timeout.connect(func():
			if not is_instance_valid(self) or not game_over_hud.visible:
				return
			
			var flying = TextureRect.new()
			flying.texture = coin_texture
			flying.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			flying.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			flying.mouse_filter = Control.MOUSE_FILTER_IGNORE
			flying.size = Vector2(44, 44)
			flying.pivot_offset = flying.size / 2.0
			game_over_hud.add_child(flying)
			
			var scatter = Vector2(randf_range(-12.0, 12.0), randf_range(-10.0, 10.0))
			flying.global_position = source.global_position + (source.size / 2.0) - (flying.size / 2.0) + scatter
			var target_position = destination.global_position + (destination.size / 2.0) - (flying.size / 2.0)
			
			var flight = create_tween()
			var peak_pos = flying.global_position + Vector2(randf_range(-25.0, 25.0), -35.0)
			flight.tween_property(flying, "scale", Vector2(1.3, 1.3), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			flight.parallel().tween_property(flying, "global_position", peak_pos, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			
			flight.chain().tween_property(flying, "global_position", target_position, 0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
			flight.parallel().tween_property(flying, "scale", Vector2(0.7, 0.7), 0.42)
			flight.parallel().tween_property(flying, "rotation_degrees", randf_range(180.0, 360.0), 0.42)
			
			flight.tween_callback(func():
				if not is_instance_valid(self) or not is_instance_valid(destination) or not is_instance_valid(wallet_count):
					if is_instance_valid(flying): flying.queue_free()
					return
				
				if MusicManager:
					MusicManager.play_sfx("coin", -2.0, randf_range(0.94, 1.06))
				
				current_visual_total += coins_per_visual
				if index == visual_coins - 1:
					wallet_count.text = str(target_coins)
					SignalHub.coins_updated.emit(target_coins)
				else:
					wallet_count.text = str(int(round(current_visual_total)))
				
				var pulse = create_tween()
				pulse.tween_property(destination, "scale", Vector2(1.22, 1.22), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				pulse.tween_property(destination, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				
				flying.queue_free()
			)
		)

func _on_retry_pressed():
	# If lives ended (lost level), watch rewarded video ad to retry with full 3 lives
	if GameManager and GameManager.lives <= 0:
		AdManager.show_rewarded_ad(func(success: bool):
			if success and is_instance_valid(self):
				load_level(level_id)
		)
	else:
		# If user won and chose Play Again, reload directly
		load_level(level_id)

func _on_continue_pressed():
	if GameManager:
		if GameManager.is_daily_mode:
			_on_menu_pressed()
			return
		if GameManager.is_arcade_mode:
			# It's arcade mode, so generate a completely new random level!
			GameManager.pick_next_arcade_level()
			
			level_id = GameManager.selected_level_id
			sublevel_id = GameManager.selected_sublevel_id
			game_over_hud.visible = false
			
			# Reload scene fully to ensure clean state
			get_tree().reload_current_scene()
			return
		else:
			var next_sub = GameManager.get_next_sublevel_id()
			if next_sub != "":
				GameManager.selected_sublevel_id = next_sub
				sublevel_id = next_sub
				load_level(level_id)
				return
	
	# If all sublevels completed or no next level, return to level select
	_on_menu_pressed()

func _on_menu_pressed():
	if AdManager:
		AdManager.set_gameplay_active(false)
	if GameManager:
		GameManager.return_to_level_select = true
		GameManager.return_to_daily_screen = GameManager.is_daily_mode
	get_tree().change_scene_to_file("res://main/main_menu.tscn")

func rebuild_hud_items():
	var items_textures = []
	for child in level_container.get_children():
		if child.has_method("_gui_input") and child.name != "Bed" and child.name != "Character":
			if child.is_target:
				items_textures.append(child.texture_normal)
	bottom_hud.setup_items(items_textures)
	if GameManager:
		GameManager.items_to_find = items_textures.size()
		SignalHub.items_progress_updated.emit(GameManager.items_found, GameManager.items_to_find)

func _unhandled_input(event):
	if edit_mode and event is InputEventKey and event.pressed:
		if event.keycode == KEY_A:
			# Toggle difficulty alpha blending
			enable_difficulty_alpha = not enable_difficulty_alpha
			print("Global difficulty alpha (transparency effect) toggled to: ", enable_difficulty_alpha)
			
			# Refresh visual modulation for all active level items instantly
			for child in level_container.get_children():
				if child.has_method("update_visual_modulation") and child.name != "Bed" and child.name != "Character":
					child.update_visual_modulation()
					
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_B and event.shift_pressed:
			# Capital B: Remove background effect from background item under cursor
			var candidates = []
			for child in level_container.get_children():
				if child.has_method("_gui_input") and child.name != "Bed" and child.name != "Character":
					if child.get("is_background") == true:
						var local_m = child.get_local_mouse_position()
						if Rect2(Vector2.ZERO, child.size).has_point(local_m):
							candidates.append(child)
			
			var target_child = null
			if candidates.size() > 0:
				candidates.sort_custom(func(a, b): 
					if a.z_index != b.z_index:
						return a.z_index > b.z_index
					return a.get_index() > b.get_index()
				)
				target_child = candidates[0]
			
			if target_child and target_child.has_method("remove_background_effect"):
				target_child.remove_background_effect()
				rebuild_hud_items()
				get_viewport().set_input_as_handled()
		elif event.keycode == KEY_N:
			# N key: Remove all elements from background in current level
			for child in level_container.get_children():
				if child.has_method("_gui_input") and child.name != "Bed" and child.name != "Character":
					child.is_background = false
					child.is_target = true
					child.mouse_filter = Control.MOUSE_FILTER_STOP
					if child.has_method("update_visual_modulation"):
						child.update_visual_modulation()
			rebuild_hud_items()
			print("All elements removed from background! (Reset to selectable targets)")
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_K:
			# K key: Force select any item under cursor (even if set to background) and make it fully editable
			var candidates = []
			for child in level_container.get_children():
				if child.has_method("_gui_input") and child.name != "Bed" and child.name != "Character":
					var local_m = child.get_local_mouse_position()
					if Rect2(Vector2.ZERO, child.size).has_point(local_m):
						candidates.append(child)
			
			var target_child = null
			if candidates.size() > 0:
				candidates.sort_custom(func(a, b): 
					if a.z_index != b.z_index:
						return a.z_index > b.z_index
					return a.get_index() > b.get_index()
				)
				target_child = candidates[0]
			
			if target_child:
				if target_child.has_method("remove_background_effect"):
					target_child.remove_background_effect()
				else:
					target_child.is_background = false
					target_child.is_target = true
					target_child.mouse_filter = Control.MOUSE_FILTER_STOP
					if target_child.has_method("update_visual_modulation"):
						target_child.update_visual_modulation()
				
				target_child.grab_focus()
				rebuild_hud_items()
				print("Item '", target_child.item_id, "' is now fully editable and focused!")
				get_viewport().set_input_as_handled()

func spawn_wrong_click_indicator(local_pos: Vector2):
	# Create a label to show "-1 ❤"
	var indicator = Label.new()
	indicator.text = "-1 ❤"
	indicator.position = local_pos
	
	# Theme overrides for beautiful arcade styling
	indicator.add_theme_color_override("font_color", Color(1.0, 0.25, 0.25, 1.0)) # Vibrant red
	indicator.add_theme_color_override("font_shadow_color", Color.BLACK)
	indicator.add_theme_font_size_override("font_size", 72) # Large, highly visible size
	
	# Add thick black outline to ensure visibility on any background
	indicator.add_theme_color_override("font_outline_color", Color.BLACK)
	indicator.add_theme_constant_override("outline_size", 8)
	
	# Align text to center of the label
	indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	indicator.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# Set pivot to center so scale transitions look perfect
	indicator.size = Vector2(250, 90) # Large bounding box to prevent clipping
	indicator.pivot_offset = indicator.size / 2.0
	indicator.position -= indicator.pivot_offset # Center on click position
	indicator.z_index = 10 # Draw on top of background (z_index 1) and bed (z_index 3)
	
	level_container.add_child(indicator)
	
	# Animation sequence
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Pop scale bounce pop
	indicator.scale = Vector2(0.5, 0.5)
	tween.tween_property(indicator, "scale", Vector2(1.5, 1.5), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# Float upwards and fade out
	var target_pos = Vector2(indicator.position.x, indicator.position.y - 60)
	tween.chain().set_parallel(true)
	tween.tween_property(indicator, "position", target_pos, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(indicator, "modulate:a", 0.0, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	
	# Free on complete
	tween.chain().tween_callback(indicator.queue_free)

func trigger_hint() -> bool:
	var target_item = null
	for child in level_container.get_children():
		if child.has_method("_gui_input") and child.name != "Bed" and child.name != "Character":
			if child.is_target and not child.is_background and not child.found:
				target_item = child
				break # Stop at the first un-found target item from the left (scene order matches HUD order)
				
	if target_item == null:
		print("No active targets left to hint!")
		return false
		
	print("Hint chosen (leftmost un-found): ", target_item.item_id)
	
	# Perform visual hint sequence
	_play_hint_visuals(target_item)
	return true

func _play_hint_visuals(target_item):
	# Make sure original background size is set
	if original_bg_size == Vector2.ZERO:
		original_bg_size = level_container.size

	# 1. Spawn Dimming Overlay inside level container
	var overlay = ColorRect.new()
	overlay.name = "HintOverlay"
	overlay.size = original_bg_size
	overlay.color = Color(0.0, 0.0, 0.0, 0.0) # Start fully transparent
	overlay.z_index = 8
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP # Block clicks during hint show
	level_container.add_child(overlay)
	
	# Keep item's original properties so we can restore them later
	var original_z = target_item.z_index
	var original_scale = target_item.scale
	var original_rotation = target_item.rotation_degrees
	
	target_item.z_index = 9 # Raise above overlay
	target_item.pivot_offset = target_item.size / 2.0
	
	# 2. Spawn Pulsing Hint Circle
	var hint_circle_script = preload("res://hud/hint_circle.gd")
	var circle = Control.new()
	circle.name = "HintCircle"
	circle.set_script(hint_circle_script)
	circle.z_index = 9 # Render on top
	target_item.add_child(circle)
	
	# 3. Calculate Pan Center values (at 1.5x zoom during hint focus)
	var camera = $GameCamera
	var viewport_control = $ViewportControl
	var viewport_size = viewport_control.size if viewport_control else Vector2(720, 1075)
	
	# Visual center of the target item in global space
	var item_center = target_item.get_global_transform().origin + (target_item.size / 2.0) * target_item.get_global_transform().get_scale()
	
	# Store the original camera parameters
	var original_camera_pos = viewport_control.target_camera_pos if (viewport_control and "target_camera_pos" in viewport_control) else (camera.position if camera else original_bg_size / 2.0)
	var original_camera_zoom = viewport_control.current_zoom if (viewport_control and "current_zoom" in viewport_control) else 1.0
	
	# Target values during hint (zoom in to 1.5x)
	var zoom_target = 1.5
	var target_camera_pos = item_center
	if viewport_control and viewport_control.has_method("clamp_camera_position"):
		target_camera_pos = viewport_control.clamp_camera_position(item_center, zoom_target)
	
	# Disable drag scroll camera updates during hint tween
	if viewport_control and "is_camera_tweening" in viewport_control:
		viewport_control.is_camera_tweening = true
	
	# 4. Animate Camera to Pan and Zoom Focus
	var tween = create_tween()
	tween.set_parallel(true)
	
	if camera:
		tween.tween_property(camera, "zoom", Vector2(zoom_target, zoom_target), 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(camera, "position", target_camera_pos, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		
		# Synchronize the viewport control's current zoom variable to keep control in sync
		if viewport_control and "current_zoom" in viewport_control:
			viewport_control.current_zoom = zoom_target
	
	# Dim the screen background (level space)
	tween.tween_property(overlay, "color", Color(0.01, 0.01, 0.03, 0.68), 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# Dim HUD overlays and UI panels (full-screen gray out effect)
	_set_layer_dim(bottom_hud, true)
	_set_layer_dim(upper_hud, true)
	
	var debug_hud = get_node("DebugHUD") if has_node("DebugHUD") else null
	var zoom_ui = get_node("ZoomUI") if has_node("ZoomUI") else null
	if debug_hud: _set_layer_dim(debug_hud, true)
	if zoom_ui: _set_layer_dim(zoom_ui, true)
	
	# Grow targeted item size (pop out animation)
	tween.tween_property(target_item, "scale", original_scale * 1.45, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# Start a shaking/wobble rotation loop on the item during the 3.0s delay hold
	var shake_tween = create_tween()
	shake_tween.set_loops(6)
	shake_tween.tween_property(target_item, "rotation_degrees", original_rotation - 12.0, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	shake_tween.tween_property(target_item, "rotation_degrees", original_rotation + 12.0, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	# 5. Hold, then Restore Camera Position, Zoom, and Item Scale/Rotation
	tween.chain().set_parallel(true)
	
	# Restore original camera values after a 3.0s delay
	if camera:
		tween.tween_property(camera, "zoom", Vector2(original_camera_zoom, original_camera_zoom), 0.8).set_delay(3.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(camera, "position", original_camera_pos, 0.8).set_delay(3.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		
		# Synchronize the viewport control's current zoom variable back
		if viewport_control and "current_zoom" in viewport_control:
			tween.tween_callback(func(): viewport_control.current_zoom = original_camera_zoom).set_delay(3.8)
	
	# Fade overlay back to transparent
	tween.tween_property(overlay, "color", Color(0.0, 0.0, 0.0, 0.0), 0.8).set_delay(3.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	
	# Restore HUD overlays and UI panels to full brightness
	# Restore HUD overlays and UI panels to full brightness
	tween.tween_callback(func():
		_set_layer_dim(bottom_hud, false)
		_set_layer_dim(upper_hud, false)
		var debug_hud_ref = get_node("DebugHUD") if has_node("DebugHUD") else null
		var zoom_ui_ref = get_node("ZoomUI") if has_node("ZoomUI") else null
		if debug_hud_ref: _set_layer_dim(debug_hud_ref, false)
		if zoom_ui_ref: _set_layer_dim(zoom_ui_ref, false)
	).set_delay(3.0)
	
	# Shrink item back to original scale and reset rotation
	tween.tween_property(target_item, "scale", original_scale, 0.8).set_delay(3.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(target_item, "rotation_degrees", original_rotation, 0.8).set_delay(3.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	
	# Clean up elements on completion
	tween.chain().tween_callback(func():
		if viewport_control and "is_camera_tweening" in viewport_control:
			viewport_control.is_camera_tweening = false
			viewport_control.target_camera_pos = original_camera_pos
			viewport_control.current_zoom = original_camera_zoom
		if is_instance_valid(target_item):
			target_item.z_index = original_z
			target_item.scale = original_scale
			target_item.rotation_degrees = original_rotation
			if is_instance_valid(circle):
				circle.queue_free()
		if is_instance_valid(overlay):
			overlay.queue_free()
			
		# Re-enable the Hint button once the visual animation sequence completes (only if visible)
		if is_instance_valid(upper_hud) and upper_hud.has_method("get_hint_button"):
			var hb = upper_hud.get_hint_button()
			if is_instance_valid(hb) and hb.visible:
				if "is_hint_animating" in hb:
					hb.is_hint_animating = false
				if hb.has_method("refresh_state"):
					hb.refresh_state()
				else:
					hb.disabled = false
	)

func _set_layer_dim(layer: Node, dim: bool):
	if not is_instance_valid(layer):
		return
	var target_color = Color(0.25, 0.25, 0.25, 1.0) if dim else Color(1.0, 1.0, 1.0, 1.0)
	for child in layer.get_children():
		if child is CanvasItem:
			var t = create_tween()
			t.tween_property(child, "modulate", target_color, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
