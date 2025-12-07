extends CanvasLayer

class_name PauseMenu

signal resume_requested
signal settings_requested
signal quit_requested
signal inventory_requested
signal bestiary_requested
signal stellarium_requested

@onready var _button_container: Control = $Stage/VBoxContainer
@onready var _settings_panel: Control = $SettingsPanel
@onready var _resume_button: Button = $Stage/VBoxContainer/ResumeButton
@onready var _settings_button: Button = $Stage/VBoxContainer/SettingsButton
@onready var _inventory_button: Button = $Stage/VBoxContainer/InventoryButton
@onready var _debug_button: Button = $Stage/VBoxContainer/DebugButton
@onready var _bestiary_button: Button = $Stage/VBoxContainer/BestiaryButton
@onready var _stellarium_button: Button = $Stage/VBoxContainer/StellariumButton
@onready var _quit_button: Button = $Stage/VBoxContainer/QuitButton

# Audio manager reference
@onready var audio_manager: AudioManager = get_node_or_null("/root/AudioManager")

var is_paused: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	add_to_group("pause_menu")
	_button_container.visible = true
	_settings_panel.visible = false
	
	_resume_button.pressed.connect(_on_resume_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)
	_inventory_button.pressed.connect(_on_inventory_pressed)
	_debug_button.pressed.connect(_on_debug_pressed)
	_bestiary_button.pressed.connect(_on_bestiary_pressed)
	_stellarium_button.pressed.connect(_on_stellarium_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)

func _input(event: InputEvent) -> void:
	# Don't process input if inventory is open
	var inventory_ui = get_tree().get_first_node_in_group("inventory_ui")
	if inventory_ui and inventory_ui.visible:
		return
	
	# Don't process input if trading panel is open
	var trading_panel = get_tree().get_first_node_in_group("trading_panel")
	if trading_panel and trading_panel.visible:
		return
	
	# Don't process input if map is open
	var radar_hud = get_tree().get_first_node_in_group("radar_hud")
	if radar_hud and radar_hud._map_visible:
		return
		
	if event.is_action_pressed("ui_cancel"): # ESC
		toggle_pause()
		get_viewport().set_input_as_handled()
		return
	
	# F1 toggles visibility of the Debug button (debug entrypoint) in pause menu
	if event is InputEventKey and event.pressed and event.keycode == KEY_F1:
		if _debug_button:
			_debug_button.visible = not _debug_button.visible
			# If hiding the button while debug menu is open, also hide the menu
			if not _debug_button.visible:
				var debug_menu = get_tree().get_first_node_in_group("debug_menu")
				if debug_menu and debug_menu.has_method("toggle_menu") and debug_menu.debug_visible:
					debug_menu.toggle_menu()
		get_viewport().set_input_as_handled()

func toggle_pause() -> void:
	is_paused = !is_paused
	get_tree().paused = is_paused
	visible = is_paused
	
	if is_paused:
		_hide_hud()
		_show_main_menu()
	else:
		_show_hud()
		_settings_panel.visible = false
		# Ensure any DebugMenu overlay is hidden when leaving pause
		var debug_menu = get_tree().get_first_node_in_group("debug_menu")
		if debug_menu and debug_menu.has_method("toggle_menu") and debug_menu.debug_visible:
			debug_menu.toggle_menu()

func _show_main_menu() -> void:
	_button_container.visible = true
	_settings_panel.visible = false
	_resume_button.grab_focus()

func _on_resume_pressed() -> void:
	if audio_manager:
		audio_manager.play_button_click()
	toggle_pause()
	resume_requested.emit()

func _on_settings_pressed() -> void:
	if audio_manager:
		audio_manager.play_button_click()
	_button_container.visible = false
	_settings_panel.visible = true
	settings_requested.emit()

func _on_inventory_pressed() -> void:
	if audio_manager:
		audio_manager.play_button_click()
	# Hide pause menu while inventory is open
	visible = false
	# Request inventory to open (Main.gd will handle it)
	inventory_requested.emit()

func _on_debug_pressed() -> void:
	if audio_manager:
		audio_manager.play_button_click()
	# Toggle DebugMenu overlay while keeping pause menu chrome visible
	var debug_menu = get_tree().get_first_node_in_group("debug_menu")
	if debug_menu and debug_menu.has_method("toggle_menu"):
		debug_menu.toggle_menu()

func _on_bestiary_pressed() -> void:
	if audio_manager:
		audio_manager.play_button_click()
	bestiary_requested.emit()

func _on_stellarium_pressed() -> void:
	if audio_manager:
		audio_manager.play_button_click()
	stellarium_requested.emit()

func _on_quit_pressed() -> void:
	if audio_manager:
		audio_manager.play_button_click()

	# Gather simple state: player position
	var player_pos := Vector2.ZERO
	var player = get_tree().get_first_node_in_group("player")
	if player and player is Node2D:
		player_pos = (player as Node2D).global_position
	elif player and player.has_method("get_global_position"):
		player_pos = player.get_global_position()

	var ship_name := _get_current_ship_name()
	var save_name := _build_save_name(ship_name)
	
	# Build a minimal save dictionary
	var save_data: Dictionary = {
		"name": save_name,
		"playtime": 0,
		"score": 0,
		"favorite": false,
		"stats_summary": "Position only test save.",
		"position": player_pos,
	}

	var game_state = get_node_or_null("/root/GameState")
	if game_state:
		save_data["ship_id"] = game_state.get_selected_ship_id()
		save_data["ship_name"] = game_state.get_selected_ship_name()
		save_data["ship_type"] = game_state.get_selected_ship_type()
		save_data["ship_texture"] = game_state.get_selected_ship_texture()

	# Write JSON via SaveManager autoload
	var save_manager = get_node_or_null("/root/SaveManager")
	if save_manager and save_manager.has_method("save_current_run"):
		save_manager.save_current_run(save_data)

	# Return to main menu
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
	quit_requested.emit()

func _get_current_ship_name() -> String:
	var ship_name := "Unknown Ship"
	var game_state = get_node_or_null("/root/GameState")
	if game_state:
		if game_state.has_method("get_selected_ship_name"):
			var result = game_state.get_selected_ship_name()
			if typeof(result) == TYPE_STRING and not result.is_empty():
				return result
		if "selected_ship" in game_state:
			var ship_id = str(game_state.get("selected_ship"))
			if not ship_id.is_empty():
				ship_name = ship_id
	return ship_name

func _build_save_name(ship_name: String) -> String:
	var dt := Time.get_datetime_dict_from_system()
	var date_str := "%04d-%02d-%02d" % [dt.year, dt.month, dt.day]
	var time_str := "%02d:%02d" % [dt.hour, dt.minute]
	return "%s - %s - %s" % [ship_name, date_str, time_str]
func _on_settings_back_pressed() -> void:
	if audio_manager:
		audio_manager.play_button_click()
	_show_main_menu()

func _hide_hud() -> void:
	# Hide all HUD elements
	var hud = get_tree().get_first_node_in_group("hud")
	if hud:
		hud.visible = false
	
	# Hide other UI elements that should be hidden during pause
	# BUT don't hide inventory if it's already open (user might have opened it with E key)
	var inventory_ui = get_tree().get_first_node_in_group("inventory_ui")
	if inventory_ui and not inventory_ui.tracked_visible:
		# Don't force hide inventory - let it manage its own visibility
		pass

func _show_hud() -> void:
	# Show all HUD elements
	var hud = get_tree().get_first_node_in_group("hud")
	if hud:
		hud.visible = true
