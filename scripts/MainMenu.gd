extends Control

class_name MainMenu

# Import AudioManager class with non-shadowing name
const AudioManagerClass = preload("res://scripts/AudioManager.gd")

@export var gameplay_scene: PackedScene
@export var version_text: String = "Version 3.2.1"
@export var background_texture_path: String = "res://assets/environment/backgrounds/"

enum Mode { HOME, SETTINGS, CHANGELOG, GALLERY, SHIPS, SAVES }
var current_mode: int = Mode.HOME
var _transitioning: bool = false
var _selected_ship: String = ""
var _ship_builder: MainMenuShipBuilder

# Audio manager reference
@onready var audio_manager: AudioManagerClass = get_node_or_null("/root/AudioManager")

# Home panel references
@onready var _motd_text: RichTextLabel = get_node_or_null("CanvasLayer/Middle/MotdPanel/MotdVBox/MotdText")

func _ready():
	if gameplay_scene == null:
		gameplay_scene = preload("res://scenes/Main.tscn")
	
	# Set version label
	var version_label = get_node_or_null("CanvasLayer/TopBarContainer/TopBarRight/VersionLabel")
	if version_label:
		version_label.text = version_text
	
	# Set background texture
	var bg = get_node_or_null("Background")
	if bg:
		var tex = load(background_texture_path) as Texture2D
		if tex:
			bg.texture = tex
			bg.stretch_mode = TextureRect.STRETCH_TILE
			# Ensure texture repeats properly
			bg.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	
	# Initialize background renderer state
	var bg_renderer = get_tree().get_first_node_in_group("background_renderer")
	if bg_renderer and bg:
		# Hide static background when Ultra HD is enabled
		bg.visible = not bg_renderer.ultra_hd_enabled
	
	# Connect button signals
	_connect_buttons()
	
	# Initialize tab system
	_initialize_tabs()
	
	# Initialize ship builder
	_ensure_ship_builder_ready()
	
	# Start main menu music
	if audio_manager:
		audio_manager.play_music("bounce_orbits", true)
	
	GameLog.log_system("MainMenu initialized")

func _connect_buttons():
	# Top bar buttons (navigation/header controls)
	var start_btn = get_node_or_null("CanvasLayer/TopBarContainer/TopBarCenter/TopButtons/StartButton")
	var changelog_btn = get_node_or_null("CanvasLayer/TopBarContainer/TopBarCenter/TopButtons/ChangelogButton")
	var gallery_btn = get_node_or_null("CanvasLayer/TopBarContainer/TopBarCenter/TopButtons/GalleryButton")
	var settings_btn = get_node_or_null("CanvasLayer/TopBarContainer/TopBarCenter/TopButtons/SettingsButton")
	var ships_btn = get_node_or_null("CanvasLayer/TopBarContainer/TopBarCenter/TopButtons/ShipsButton")
	var saves_btn = get_node_or_null("CanvasLayer/TopBarContainer/TopBarCenter/TopButtons/SavesButton")
	var quit_btn = get_node_or_null("CanvasLayer/TopBarContainer/TopBarCenter/TopButtons/QuitButton")
	
	if start_btn and not start_btn.pressed.is_connected(_on_start_pressed):
		start_btn.pressed.connect(_on_start_pressed)
	if changelog_btn and not changelog_btn.pressed.is_connected(_on_changelog_pressed):
		changelog_btn.pressed.connect(_on_changelog_pressed)
	if gallery_btn and not gallery_btn.pressed.is_connected(_on_gallery_pressed):
		gallery_btn.pressed.connect(_on_gallery_pressed)
	if settings_btn and not settings_btn.pressed.is_connected(_on_settings_pressed):
		settings_btn.pressed.connect(_on_settings_pressed)
	if ships_btn and not ships_btn.pressed.is_connected(_on_ships_pressed):
		ships_btn.pressed.connect(_on_ships_pressed)
	if saves_btn and not saves_btn.pressed.is_connected(_on_saves_pressed):
		saves_btn.pressed.connect(_on_saves_pressed)
	if quit_btn and not quit_btn.pressed.is_connected(_on_quit_pressed):
		quit_btn.pressed.connect(_on_quit_pressed)
	
	# Settings panel back button
	var settings_panel = get_node_or_null("CanvasLayer/SettingsPanel")
	if settings_panel and settings_panel.has_signal("back_requested"):
		if not settings_panel.back_requested.is_connected(_on_settings_back_pressed):
			settings_panel.back_requested.connect(_on_settings_back_pressed)
	
	# Bottom bar buttons
	var new_game_btn = get_node_or_null("CanvasLayer/BottomBarContainer/BottomBarLeft/NewGameButton")
	var continue_btn = get_node_or_null("CanvasLayer/BottomBarContainer/BottomBarLeft/ContinueButton")
	var discord_btn = get_node_or_null("CanvasLayer/BottomBarContainer/BottomBarRight/DiscordButton")
	
	if new_game_btn and not new_game_btn.pressed.is_connected(_on_new_game_pressed):
		new_game_btn.pressed.connect(_on_new_game_pressed)
	if continue_btn and not continue_btn.pressed.is_connected(_on_continue_pressed):
		continue_btn.pressed.connect(_on_continue_pressed)
	if discord_btn and not discord_btn.pressed.is_connected(_on_discord_pressed):
		discord_btn.pressed.connect(_on_discord_pressed)

func _initialize_tabs():
	var tabs = get_node_or_null("CanvasLayer/TopBarContainer/TopBarCenter/TopButtons")
	if tabs:
		for child in tabs.get_children():
			if child is Button:
				var btn = child as Button
				var hover_callable = Callable(self, "_on_tab_hover").bind(btn)
				if not btn.mouse_entered.is_connected(hover_callable):
					btn.mouse_entered.connect(hover_callable)
				if not btn.mouse_exited.is_connected(_on_tab_hover_exit):
					btn.mouse_exited.connect(_on_tab_hover_exit)
		
		var home_btn = tabs.get_node_or_null("StartButton")
		if home_btn:
			_set_active_tab(home_btn)
			call_deferred("_ensure_active_tab_underline")

func _on_tab_hover(btn: Button):
	if not _transitioning:
		_update_tab_underline_for_button(btn)

func _on_tab_hover_exit():
	if not _transitioning:
		_ensure_active_tab_underline()

func _ensure_active_tab_underline():
	var active_btn = _get_active_button()
	if active_btn:
		_update_tab_underline_for_button(active_btn)

func _update_tab_underline_for_button(btn: Button) -> void:
	var underline = get_node_or_null("CanvasLayer/TabUnderline")
	if not underline or not btn:
		return
	
	# Place underline using CanvasLayer-local coordinates so it always lines up
	var canvas_layer := underline.get_parent()
	if canvas_layer and canvas_layer is CanvasItem:
		var local_pos: Vector2 = (canvas_layer as CanvasItem).to_local(btn.get_global_position())
		underline.position.x = local_pos.x
		underline.size.x = btn.size.x

func _get_active_button() -> Button:
	var tabs = get_node_or_null("CanvasLayer/TopBarContainer/TopBarCenter/TopButtons")
	if not tabs:
		return null
	
	match current_mode:
		Mode.HOME:
			return tabs.get_node_or_null("StartButton")
		Mode.CHANGELOG:
			return tabs.get_node_or_null("ChangelogButton")
		Mode.GALLERY:
			return tabs.get_node_or_null("GalleryButton")
		Mode.SETTINGS:
			return tabs.get_node_or_null("SettingsButton")
		Mode.SHIPS:
			return tabs.get_node_or_null("ShipsButton")
		Mode.SAVES:
			return tabs.get_node_or_null("SavesButton")
		_:
			return null

func _set_active_tab(btn: Button):
	_transitioning = true
	
	# Hide all panels
	var settings_panel = get_node_or_null("CanvasLayer/SettingsPanel")
	var credits_panel = get_node_or_null("CanvasLayer/CreditsPanel")
	var changelog_panel = get_node_or_null("CanvasLayer/ChangelogPanel")
	var gallery_panel = get_node_or_null("CanvasLayer/GalleryPanel")
	var ship_builder_panel = get_node_or_null("CanvasLayer/ShipBuilderPanel")
	var saves_panel = get_node_or_null("CanvasLayer/SavesPanel")
	var middle = get_node_or_null("CanvasLayer/Middle")
	var right = get_node_or_null("CanvasLayer/Right")
	
	if settings_panel:
		settings_panel.visible = false
	if credits_panel:
		credits_panel.visible = false
	if changelog_panel:
		changelog_panel.visible = false
	if gallery_panel:
		gallery_panel.visible = false
	if ship_builder_panel:
		ship_builder_panel.visible = false
	if saves_panel:
		saves_panel.visible = false
	if middle:
		middle.visible = false
	if right:
		right.visible = false
	
	# Show appropriate panel
	if btn.name == "StartButton":
		current_mode = Mode.HOME
		if middle:
			middle.visible = true
		if right:
			right.visible = true
		_update_home_stats_panel()
	elif btn.name == "ChangelogButton":
		current_mode = Mode.CHANGELOG
		if changelog_panel:
			changelog_panel.visible = true
	elif btn.name == "GalleryButton":
		current_mode = Mode.GALLERY
		if gallery_panel:
			gallery_panel.visible = true
	elif btn.name == "SettingsButton":
		current_mode = Mode.SETTINGS
		if settings_panel:
			settings_panel.visible = true
	elif btn.name == "ShipsButton":
		current_mode = Mode.SHIPS
		if ship_builder_panel:
			ship_builder_panel.visible = true
			if _ship_builder:
				_ship_builder.open_panel(_selected_ship)
	elif btn.name == "SavesButton":
		current_mode = Mode.SAVES
		if saves_panel:
			saves_panel.visible = true
	
	_update_bottom_bar_visibility()
	
	_ensure_active_tab_underline()
	_transitioning = false

func _input(event: InputEvent) -> void:
	# Handle screenshot key
	if event is InputEventKey and event.pressed and event.keycode == KEY_F12:
		var screenshot_manager = get_tree().get_first_node_in_group("screenshot_manager")
		if screenshot_manager and screenshot_manager.has_method("take_screenshot"):
			screenshot_manager.take_screenshot()
	
	# Handle ESC key for returning to home
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if current_mode != Mode.HOME and not _transitioning:
			if audio_manager:
				audio_manager.play_button_click()
			_switch_mode(Mode.HOME, _get_button("StartButton"))

func _on_start_pressed():
	if audio_manager:
		audio_manager.play_button_click()
	GameLog.log_info("Start button pressed", "MainMenu")
	_switch_mode(Mode.HOME, _get_button("StartButton"))

func _on_changelog_pressed():
	if audio_manager:
		audio_manager.play_button_click()
	_switch_mode(Mode.CHANGELOG, _get_button("ChangelogButton"))

func _on_gallery_pressed():
	if audio_manager:
		audio_manager.play_button_click()
	_switch_mode(Mode.GALLERY, _get_button("GalleryButton"))

func _on_settings_pressed():
	if audio_manager:
		audio_manager.play_button_click()
	_switch_mode(Mode.SETTINGS, _get_button("SettingsButton"))

func _on_ships_pressed():
	if audio_manager:
		audio_manager.play_button_click()
	_switch_mode(Mode.SHIPS, _get_button("ShipsButton"))

func _on_saves_pressed():
	if audio_manager:
		audio_manager.play_button_click()
	_switch_mode(Mode.SAVES, _get_button("SavesButton"))

func _on_quit_pressed():
	if audio_manager:
		audio_manager.play_button_click()
	GameLog.log_system("Quit button pressed - Exiting game")
	get_tree().quit()

func _on_new_game_pressed():
	if audio_manager:
		audio_manager.play_button_click()
	# Open ship builder for new game
	_switch_mode(Mode.SHIPS, _get_button("ShipsButton"))

func _on_continue_pressed():
	if audio_manager:
		audio_manager.play_button_click()
	# Try to load latest save, otherwise start new game
	if _try_load_latest_save():
		return
	_switch_mode(Mode.SHIPS, _get_button("ShipsButton"))



func _on_discord_pressed():
	if audio_manager:
		audio_manager.play_button_click()
	# Open Discord link
	OS.shell_open("https://discord.gg/CKMQaCQKat")

func _start_game():
	var game_state = get_node_or_null("/root/GameState")
	if _selected_ship.is_empty() and game_state:
		var cached_ship = game_state.get_selected_ship_id()
		if not cached_ship.is_empty():
			_selected_ship = cached_ship
	# Check if ship is selected
	if _selected_ship.is_empty():
		_show_error_message("Please select a ship first!")
		return
	
	# Set selected ship in game state if available
	if game_state and game_state.has_method("set_selected_ship"):
		game_state.set_selected_ship(_selected_ship)
	
	if gameplay_scene:
		get_tree().change_scene_to_packed(gameplay_scene)

func _try_load_latest_save() -> bool:
	var save_manager = get_node_or_null("/root/SaveManager")
	if not save_manager or not save_manager.has_method("load_latest"):
		return false
	var data = save_manager.load_latest()
	if typeof(data) != TYPE_DICTIONARY or data.is_empty():
		return false
	_apply_loaded_ship_data(data)
	var ship_id: String = str(data.get("ship_id", ""))
	if ship_id.is_empty():
		ship_id = _selected_ship
	_selected_ship = ship_id
	if _selected_ship.is_empty():
		return false
	_start_game()
	return true

func _apply_loaded_ship_data(data: Dictionary) -> void:
	var game_state = get_node_or_null("/root/GameState")
	if not game_state:
		return
	game_state.apply_ship_data({
		"ship_id": data.get("ship_id", ""),
		"ship_name": data.get("ship_name", ""),
		"ship_type": data.get("ship_type", ""),
		"ship_texture": data.get("ship_texture", ""),
	})

func _cache_selected_ship_to_game_state(ship_id: String) -> void:
	if ship_id.is_empty():
		return
	var game_state = get_node_or_null("/root/GameState")
	if not game_state:
		return
	var ship_data: Dictionary = {}
	if _ship_builder and _ship_builder.has_method("get_ship_info"):
		ship_data = _ship_builder.get_ship_info(ship_id)
	var ship_name = str(ship_data.get("name", ""))
	var ship_type = str(ship_data.get("type", ""))
	var ship_texture = str(ship_data.get("texture", ""))
	game_state.set_selected_ship(ship_id, ship_name, ship_texture, ship_type)

func _ensure_ship_builder_ready() -> bool:
	if _ship_builder and is_instance_valid(_ship_builder):
		return true
	_ship_builder = get_node_or_null("CanvasLayer/ShipBuilderPanel")
	if not _ship_builder:
		return false
	if not _ship_builder.ship_selected.is_connected(_on_ship_selected):
		_ship_builder.ship_selected.connect(_on_ship_selected)
	if not _ship_builder.start_game_requested.is_connected(_on_ship_builder_start_game):
		_ship_builder.start_game_requested.connect(_on_ship_builder_start_game)
	return true

func _on_ship_selected(ship_id: String) -> void:
	if ship_id.is_empty():
		return
	_selected_ship = ship_id
	_cache_selected_ship_to_game_state(ship_id)
	GameLog.log_info("Ship selected: " + ship_id, "MainMenu")

func _on_ship_builder_start_game(ship_id: String) -> void:
	if ship_id.is_empty():
		_show_error_message("Please select a ship first!")
		return
	_selected_ship = ship_id
	_cache_selected_ship_to_game_state(ship_id)
	_start_game()

func _show_error_message(message: String) -> void:
	# Create a temporary error notification
	var error_label = Label.new()
	error_label.text = message
	error_label.add_theme_font_size_override("font_size", 18)
	error_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	error_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.1, 0.1, 0.95)
	style.border_color = Color(1.0, 0.3, 0.3, 1.0)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", style)
	panel.add_child(error_label)
	
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -200
	panel.offset_top = -50
	panel.offset_right = 200
	panel.offset_bottom = 50
	
	add_child(panel)
	
	# Auto-remove after 3 seconds
	await get_tree().create_timer(3.0).timeout
	if panel and is_instance_valid(panel):
		panel.queue_free()

func _on_settings_back_pressed():
	_switch_mode(Mode.HOME, _get_button("StartButton"))

func _show_settings_saved_notification():
	var info_label = get_node_or_null("CanvasLayer/SettingsPanel/SettingsVBox/SettingsFooter/FooterHBox/SettingsInfo")
	if info_label:
		var original_text = info_label.text
		info_label.text = "✓ Settings Applied!"
		info_label.add_theme_color_override("font_color", Color(0.2, 0.8, 0.2))
		
		await get_tree().create_timer(2.0).timeout
		if info_label and is_instance_valid(info_label):
			info_label.text = original_text
			info_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))

func _switch_mode(_mode: int, btn: Button):
	if btn:
		_set_active_tab(btn)

func _update_bottom_bar_visibility() -> void:
	var new_game_btn = get_node_or_null("CanvasLayer/BottomBarContainer/BottomBarLeft/NewGameButton")
	var continue_btn = get_node_or_null("CanvasLayer/BottomBarContainer/BottomBarLeft/ContinueButton")
	var discord_btn = get_node_or_null("CanvasLayer/BottomBarContainer/BottomBarRight/DiscordButton")
	
	var show_buttons := current_mode in [Mode.HOME, Mode.SHIPS, Mode.SAVES]
	if new_game_btn:
		new_game_btn.visible = show_buttons
	if continue_btn:
		continue_btn.visible = show_buttons
	if discord_btn:
		discord_btn.visible = show_buttons

func _get_button(button_name: String) -> Button:
	return get_node_or_null("CanvasLayer/TopBarContainer/TopBarCenter/TopButtons/" + button_name)

func _update_home_stats_panel():
	if not _motd_text:
		return

	var lines: Array[String] = []
	lines.append("[b]Last Save Info:[/b]")

	var save_manager = get_node_or_null("/root/SaveManager")
	var save_data: Dictionary = {}
	if save_manager and save_manager.has_method("get_latest_save_data"):
		save_data = save_manager.get_latest_save_data()

	if not save_data.is_empty():
		lines.append("Save Name: %s" % str(save_data.get("name", "Unknown")))
		var position_value = save_data.get("position", null)
		if position_value is Vector2:
			var pos_vec := position_value as Vector2
			lines.append("Position: (%.0f, %.0f)" % [pos_vec.x, pos_vec.y])
		elif typeof(position_value) == TYPE_DICTIONARY and position_value.has("x") and position_value.has("y"):
			lines.append("Position: (%.0f, %.0f)" % [float(position_value.x), float(position_value.y)])
		else:
			lines.append("Position: Unknown")
		var ship_name: String = str(save_data.get("ship_name", ""))
		if ship_name.is_empty():
			ship_name = str(save_data.get("ship_id", "Unknown Ship"))
		lines.append("Ship: %s" % ship_name)
	else:
		lines.append("No saved runs yet.")
		var gm = get_node_or_null("/root/GameManager")
		if gm and gm.get("player_position") is Vector2:
			var fallback_pos = gm.player_position as Vector2
			lines.append("Current Position: (%.0f, %.0f)" % [fallback_pos.x, fallback_pos.y])

	lines.append("\n[i]Tip: Explore the known sectors to find rare loot![/i]")

	_motd_text.clear()
	_motd_text.text = "\n".join(lines)
