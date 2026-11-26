extends Node

@export var level_id: String = "kitchen"
@export var sublevel_id: String = "sub1"

var enable_difficulty_alpha = false
var edit_mode = false
var original_bg_size: Vector2 = Vector2.ZERO
var active_json_path: String = ""

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
	continue_btn.pressed.connect(_on_continue_pressed)
	retry_btn.pressed.connect(_on_retry_pressed)
	menu_btn.pressed.connect(_on_menu_pressed)
	
	if has_node("DebugHUD"):
		$DebugHUD.visible = false
	if has_node("ZoomUI"):
		$ZoomUI.visible = false
	if has_node("DebugHUD/HBoxContainer/EditModeBtn"):
		$DebugHUD/HBoxContainer/EditModeBtn.pressed.connect(_on_edit_mode_btn_pressed)
	if has_node("DebugHUD/HBoxContainer/SaveBtn"):
		$DebugHUD/HBoxContainer/SaveBtn.pressed.connect(_on_save_btn_pressed)
	
	if GameManager:
		if GameManager.selected_level_id != "":
			level_id = GameManager.selected_level_id
		if GameManager.selected_sublevel_id != "":
			sublevel_id = GameManager.selected_sublevel_id
	
	# Play category-specific background music (crossfades from menu music)
	if MusicManager:
		MusicManager.play_game_music()
	
	load_level(level_id)

func load_level(id: String):
	AdManager.set_gameplay_active(true)
	level_id = id
	# Hide game over overlay on load
	game_over_hud.visible = false

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
	var title = $GameOverHUD/CenterContainer/VBoxContainer/Title
	var score_info = $GameOverHUD/CenterContainer/VBoxContainer/ScoreInfo
	var star1 = $GameOverHUD/CenterContainer/VBoxContainer/StarsContainer/Star1
	var star2 = $GameOverHUD/CenterContainer/VBoxContainer/StarsContainer/Star2
	var star3 = $GameOverHUD/CenterContainer/VBoxContainer/StarsContainer/Star3
	var win_particles = $GameOverHUD/WinParticles if has_node("GameOverHUD/WinParticles") else null
	
	var fill_tex = preload("res://assets/main/fillstart.png")
	var empty_tex = preload("res://assets/main/emptystart.png")
	
	star1.texture = empty_tex
	star2.texture = empty_tex
	star3.texture = empty_tex
	AdManager.set_gameplay_active(false)

	if win:
		if GameManager and GameManager.is_daily_challenge_mode:
			title.text = "DAILY CHALLENGE WON!"
			score_info.text = "Score: %d  (+100 Bonus Coins 🪙)" % GameManager.score
			GameManager.add_coins(100)
			GameManager.is_daily_challenge_mode = false
		else:
			title.text = "LEVEL COMPLETED!"
			score_info.text = "Final Score: " + str(GameManager.score)
		title.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4, 1.0))

		if MusicManager:
			MusicManager.play_sfx("win")

		continue_btn.visible = true
		var next_sub = GameManager.get_next_sublevel_id() if GameManager else ""
		if next_sub != "":
			continue_btn.text = "Continue ➔"
		else:
			continue_btn.text = "Select Level"
		retry_btn.text = "Play Again 🔄"

		if win_particles:
			win_particles.restart()
			win_particles.emitting = true
		_animate_victory_stars([star1, star2, star3], fill_tex)

		var completed_count: int = GameManager.completed_levels.size() if GameManager else 1
		AdManager.on_level_completed(completed_count)
	else:
		title.text = "GAME OVER"
		title.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2, 1.0))
		score_info.text = "Final Score: " + str(GameManager.score)

		if MusicManager:
			MusicManager.play_sfx("lose")

		continue_btn.visible = false
		retry_btn.text = "TRY AGAIN 🔄"

	game_over_hud.visible = true

func _animate_victory_stars(stars: Array, fill_tex: Texture2D):
	for i in range(stars.size()):
		var target_star: TextureRect = stars[i]
		if not is_instance_valid(target_star):
			continue
		
		# Ensure pivot is centered for scale animations
		target_star.pivot_offset = Vector2(35, 35)
		target_star.scale = Vector2.ONE
		target_star.rotation_degrees = 0.0
		
		var delay = 0.4 + (i * 0.45)
		
		get_tree().create_timer(delay).timeout.connect(func():
			if not is_instance_valid(target_star) or not game_over_hud.visible:
				return
			
			# Ensure pivot center
			target_star.pivot_offset = target_star.size / 2.0
			
			# Pop up scale, swap to filled star, and bounce back into place
			var tween = create_tween()
			tween.tween_property(target_star, "scale", Vector2(1.65, 1.65), 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tween.parallel().tween_property(target_star, "rotation_degrees", -12.0 if i % 2 == 0 else 12.0, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			
			# At peak of pop: change texture to filled star and play sound
			tween.chain().tween_callback(func():
				if is_instance_valid(target_star):
					target_star.texture = fill_tex
					if MusicManager:
						MusicManager.play_sfx("star_fill")
			)
			
			# Bounce back to normal size with elastic punch
			tween.chain().tween_property(target_star, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
			tween.parallel().tween_property(target_star, "rotation_degrees", 0.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		)

func _on_retry_pressed():
	load_level(level_id)

func _on_continue_pressed():
	if GameManager:
		var next_sub = GameManager.get_next_sublevel_id()
		if next_sub != "":
			GameManager.selected_sublevel_id = next_sub
			sublevel_id = next_sub
			load_level(level_id)
			return
	
	# If all sublevels completed or no next level, return to level select
	_on_menu_pressed()

func _on_menu_pressed():
	AdManager.set_gameplay_active(false)
	if GameManager:
		GameManager.is_daily_challenge_mode = false
		GameManager.return_to_level_select = true
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

func spawn_wrong_click_indicator(local_pos: Vector2):
	# Create a label to show "-1 ❤"
	var indicator = Label.new()
	indicator.text = "-1 ❤"
	indicator.position = local_pos
	
	# Theme overrides for beautiful arcade styling
	indicator.add_theme_color_override("font_color", Color(1.0, 0.25, 0.25, 1.0)) # Vibrant red
	indicator.add_theme_color_override("font_shadow_color", Color.BLACK)
	indicator.add_theme_font_size_override("font_size", 32) # Nice big size
	
	# Add thick black outline to ensure visibility on any background
	indicator.add_theme_color_override("font_outline_color", Color.BLACK)
	indicator.add_theme_constant_override("outline_size", 8)
	
	# Set pivot to center so scale transitions look perfect
	indicator.size = Vector2(100, 40) # Give it a default size
	indicator.pivot_offset = indicator.size / 2.0
	indicator.position -= indicator.pivot_offset # Center on click position
	
	level_container.add_child(indicator)
	
	# Animation sequence
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Pop scale bounce pop
	indicator.scale = Vector2(0.5, 0.5)
	tween.tween_property(indicator, "scale", Vector2(1.2, 1.2), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
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
			if child.is_target and not child.found:
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
	
	# Keep item's original z-index so we can restore it later
	var original_z = target_item.z_index
	target_item.z_index = 9 # Raise above overlay
	
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
	
	# Visual center of the target item in room space
	var item_center = target_item.position + (target_item.size / 2.0) * target_item.scale
	
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
	
	# Dim the screen background
	tween.tween_property(overlay, "color", Color(0.0, 0.0, 0.0, 0.55), 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# 5. Hold, then Restore Camera Position and Zoom
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
	
	# Clean up elements on completion
	tween.chain().tween_callback(func():
		if viewport_control and "is_camera_tweening" in viewport_control:
			viewport_control.is_camera_tweening = false
			viewport_control.target_camera_pos = original_camera_pos
			viewport_control.current_zoom = original_camera_zoom
		if is_instance_valid(target_item):
			target_item.z_index = original_z
			if is_instance_valid(circle):
				circle.queue_free()
		if is_instance_valid(overlay):
			overlay.queue_free()
	)
