extends Control

## LoadingScreen - Clean loading screen based on mockup design

signal loading_complete

@onready var spinner: Control = $LoadingContainer/Spinner
@onready var loading_text: Label = $LoadingContainer/LoadingText

# Animation variables
var rotation_angle: float = 0.0
var pulse_opacity: float = 1.0
var pulse_direction: int = -1

func _ready() -> void:
	# Initialize loading screen visuals
	_setup_spinner()
	_setup_text_animation()
	
	# Start loading process
	_start_loading()
	
	# Initialize systems sequentially with error handling
	var init_success = await _initialize_systems()
	if init_success:
		_complete_loading()
	else:
		_handle_error("Failed to initialize game systems")

func _start_loading() -> void:
	"""Initialize the loading screen and start the loading process"""
	# Ensure spinner and text are visible
	spinner.visible = true
	loading_text.visible = true
	
	# Start animations
	set_process(true)

func _setup_spinner() -> void:
	"""Create CSS-style circular spinner"""
	# Create a white circular border spinner
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color.TRANSPARENT
	style_box.border_width_left = 5
	style_box.border_width_top = 5
	style_box.border_width_right = 5
	style_box.border_width_bottom = 5
	style_box.border_color = Color.WHITE
	style_box.corner_radius_top_left = 25
	style_box.corner_radius_top_right = 25
	style_box.corner_radius_bottom_left = 25
	style_box.corner_radius_bottom_right = 25
	
	spinner.add_theme_stylebox_override("panel", style_box)

func _setup_text_animation() -> void:
	"""Setup loading text with uppercase styling"""
	loading_text.text = "LOADING"
	loading_text.add_theme_font_size_override("font_size", 19)
	loading_text.add_theme_constant_override("outline_size", 0)
	loading_text.modulate = Color.WHITE

func _process(delta: float) -> void:
	"""Handle animations"""
	# Rotate spinner (360 degrees in 1 second)
	rotation_angle += 360.0 * delta
	if rotation_angle >= 360.0:
		rotation_angle -= 360.0
	
	spinner.rotation_degrees = rotation_angle
	
	# Pulse text opacity (1.5 second cycle)
	pulse_opacity += pulse_direction * delta * 0.67  # Adjust speed for 1.5s cycle
	if pulse_opacity <= 0.5:
		pulse_opacity = 0.5
		pulse_direction = 1
	elif pulse_opacity >= 1.0:
		pulse_opacity = 1.0
		pulse_direction = -1
	
	loading_text.modulate.a = pulse_opacity

func _initialize_systems() -> bool:
	"""Initialize each system sequentially as per plan"""
	# 1. SettingsManager - Load user preferences
	var settings_manager = get_node_or_null("/root/SettingsManager")
	if settings_manager:
		await settings_manager.initialize()
		await get_tree().process_frame
	else:
		push_error("LoadingScreen: SettingsManager not found")
		return false
	
	# 2. ItemDatabase - Load item definitions
	var item_database = get_node_or_null("/root/ItemDatabase")
	if item_database:
		await item_database.initialize()
		await get_tree().process_frame
	else:
		push_error("LoadingScreen: ItemDatabase not found")
		return false
	
	# 3. SaveManager - Scan saves directory
	var save_manager = get_node_or_null("/root/SaveManager")
	if save_manager:
		await save_manager.initialize()
		await get_tree().process_frame
	else:
		push_error("LoadingScreen: SaveManager not found")
		return false
	
	# 4. InventoryState - Load latest save's inventory
	var inventory_state = get_node_or_null("/root/InventoryState")
	if inventory_state:
		await inventory_state.initialize()
		await get_tree().process_frame
	else:
		push_error("LoadingScreen: InventoryState not found")
		return false
	
	# 5. ScreenshotManager - Initialize (thumbnails only when clicked)
	var screenshot_manager = get_node_or_null("/root/ScreenshotManager")
	if screenshot_manager:
		await screenshot_manager.initialize()
		await get_tree().process_frame
	else:
		push_error("LoadingScreen: ScreenshotManager not found")
		return false
	
	# 6. AudioManager - Initialize audio system
	var audio_manager = get_node_or_null("/root/AudioManager")
	if audio_manager:
		await audio_manager.initialize()
		await get_tree().process_frame
	else:
		push_error("LoadingScreen: AudioManager not found")
		return false
	
	return true

func _complete_loading() -> void:
	"""Transition to MainMenu scene"""
	# Stop animations
	set_process(false)
	
	# Emit completion signal
	loading_complete.emit()
	
	# Add a small delay to ensure all systems are ready
	await get_tree().process_frame
	
	# Load main menu
	_try_load_main_menu_approach_1()

func _try_load_main_menu_approach_1() -> void:
	"""Try loading with change_scene_to_file"""
	# Add a small delay to ensure all systems are ready
	await get_tree().process_frame
	
	var error = get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
	if error == OK:
		return
	
	_try_load_main_menu_approach_2()

func _try_load_main_menu_approach_2() -> void:
	"""Try loading with packed scene"""
	var main_menu_scene = load("res://scenes/MainMenu.tscn")
	if not main_menu_scene:
		_try_load_main_menu_approach_3()
		return
	
	var instance = main_menu_scene.instantiate()
	if not instance:
		_try_load_main_menu_approach_3()
		return
	
	get_tree().root.add_child(instance)
	get_tree().current_scene.queue_free()
	get_tree().current_scene = instance

func _try_load_main_menu_approach_3() -> void:
	"""Final fallback - try a simple scene change without loading screen"""
	# Create a simple timer and try again
	await get_tree().create_timer(1.0).timeout
	var error = get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
	if error != OK:
		_show_error("Failed to load main menu. Please restart the game.")

func _show_error(message: String) -> void:
	"""Show an error message to the player"""
	# Create a simple error message
	var error_label = Label.new()
	error_label.text = "Error: " + message + "\n\nPlease restart the game."
	error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	error_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	error_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	error_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	# Add to scene
	add_child(error_label)
	
	# Center the label
	error_label.anchor_right = 1.0
	error_label.anchor_bottom = 1.0
	error_label.offset_left = 20
	error_label.offset_top = 20
	error_label.offset_right = -20
	error_label.offset_bottom = -20

func _handle_error(error_message: String) -> void:
	"""Handle initialization errors with crash reporting"""
	print("LoadingScreen: ERROR - ", error_message)
	
	# Create professional crash report
	var crash_handler = CrashHandler.new()
	crash_handler.create_crash_report(error_message, "LoadingScreen initialization")
	
	# Show error on screen
	crash_handler.show_error_on_screen(error_message)
	
	# Wait a bit before attempting to continue anyway
	await get_tree().create_timer(5.0).timeout
	_complete_loading()
