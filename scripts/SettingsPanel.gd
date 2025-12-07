extends Control

class_name SettingsPanel

signal back_requested

# Audio manager reference
var audio_manager: AudioManager = null

# Audio controls
var _master_slider: HSlider
var _master_value: Label
var _music_slider: HSlider
var _music_value: Label
var _sfx_slider: HSlider
var _sfx_value: Label

# Audio bus references
var _master_bus: int = -1
var _music_bus: int = -1
var _sfx_bus: int = -1
var _ui_bus: int = -1

# Graphics controls
var _ultra_hd_check: CheckBox
var _seamless_tiling_check: CheckBox
var _fullscreen_check: CheckBox
var _vsync_check: CheckBox
var _reduce_motion_check: CheckBox
var _resolution_option: OptionButton
var _ui_scale_option: OptionButton
var _ui_scale_slider: HSlider
var _ui_scale_input: LineEdit

# FOV controls
var _fov_min_input: LineEdit
var _fov_max_input: LineEdit
var _fov_slider: HSlider
var _fov_value: Label

# Gameplay controls
var _difficulty_option: OptionButton

# Buttons
var _apply_button: Button
var _back_button: Button

# Settings storage
var _settings_changed: bool = false
var _original_values: Dictionary = {}

# FOV settings
var _fov_min: float = 1.0
var _fov_max: float = 360.0
var _current_fov: float = 75.0
var _default_fov: float = 75.0

# UI scaling / resolution
var _ui_scale: float = 1.0
var _original_ui_scale: float = 1.0
var _pending_ui_scale: float = 1.0
var _original_resolution: Vector2i
var _pending_resolution: Vector2i

func _ready() -> void:
	# Cache node references safely
	audio_manager = get_node_or_null("/root/AudioManager")
	var root_path := "ScrollContainer/VBoxContainer/"
	_master_slider = get_node_or_null(root_path + "AudioSection/AudioVBox/MasterRow/MasterSlider")
	_master_value = get_node_or_null(root_path + "AudioSection/AudioVBox/MasterRow/MasterValue")
	_music_slider = get_node_or_null(root_path + "AudioSection/AudioVBox/MusicRow/MusicSlider")
	_music_value = get_node_or_null(root_path + "AudioSection/AudioVBox/MusicRow/MusicValue")
	_sfx_slider = get_node_or_null(root_path + "AudioSection/AudioVBox/SfxRow/SfxSlider")
	_sfx_value = get_node_or_null(root_path + "AudioSection/AudioVBox/SfxRow/SfxValue")
	_ultra_hd_check = get_node_or_null(root_path + "GraphicsSection/GraphicsVBox/UltraHDCheck")
	_seamless_tiling_check = get_node_or_null(root_path + "GraphicsSection/GraphicsVBox/SeamlessTilingCheck")
	_fullscreen_check = get_node_or_null(root_path + "GraphicsSection/GraphicsVBox/FullscreenCheck")
	_vsync_check = get_node_or_null(root_path + "GraphicsSection/GraphicsVBox/VsyncCheck")
	_reduce_motion_check = get_node_or_null(root_path + "GraphicsSection/GraphicsVBox/ReduceMotionCheck")
	_resolution_option = get_node_or_null(root_path + "GraphicsSection/GraphicsVBox/ResolutionRow/ResolutionOption")
	_ui_scale_option = get_node_or_null(root_path + "GraphicsSection/GraphicsVBox/UiScaleRow/UiScaleOption")
	_ui_scale_slider = get_node_or_null(root_path + "GraphicsSection/GraphicsVBox/UiScaleRow/UiScaleSlider")
	_ui_scale_input = get_node_or_null(root_path + "GraphicsSection/GraphicsVBox/UiScaleRow/UiScaleInput")
	_fov_min_input = get_node_or_null(root_path + "GraphicsSection/GraphicsVBox/FovRow/FovMinInput")
	_fov_max_input = get_node_or_null(root_path + "GraphicsSection/GraphicsVBox/FovRow/FovMaxInput")
	_fov_slider = get_node_or_null(root_path + "GraphicsSection/GraphicsVBox/FovRow/FovSlider")
	_fov_value = get_node_or_null(root_path + "GraphicsSection/GraphicsVBox/FovRow/FovValue")
	_difficulty_option = get_node_or_null(root_path + "GameplaySection/GameplayVBox/DifficultyRow/DifficultyOption")
	_apply_button = get_node_or_null(root_path + "ButtonContainer/ApplyButton")
	_back_button = get_node_or_null(root_path + "ButtonContainer/BackButton")

	# Connect button signals
	if _apply_button:
		_apply_button.pressed.connect(_on_apply_pressed)
	if _back_button:
		_back_button.pressed.connect(_on_back_pressed)
	
	# Add to group for player to find
	add_to_group("settings_panel")
	
	# Connect control signals
	_connect_audio_signals()
	_connect_graphics_signals()
	_connect_gameplay_signals()
	
	# Initialize settings
	_initialize_audio_settings()
	_initialize_graphics_settings()
	_initialize_gameplay_settings()
	
	# Apply consistent theme for visual parity with other panels
	_apply_consistent_theme()

func _connect_audio_signals():
	if _master_slider:
		_master_slider.value_changed.connect(_on_master_volume_changed)
	if _music_slider:
		_music_slider.value_changed.connect(_on_music_volume_changed)
	if _sfx_slider:
		_sfx_slider.value_changed.connect(_on_sfx_volume_changed)

func _connect_graphics_signals():
	if _ultra_hd_check:
		_ultra_hd_check.toggled.connect(_on_ultra_hd_toggled)
	if _seamless_tiling_check:
		_seamless_tiling_check.toggled.connect(_on_seamless_tiling_toggled)
	if _fullscreen_check:
		_fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	if _vsync_check:
		_vsync_check.toggled.connect(_on_vsync_toggled)
	if _reduce_motion_check:
		_reduce_motion_check.toggled.connect(_on_reduce_motion_toggled)
	if _resolution_option:
		_resolution_option.item_selected.connect(_on_resolution_selected)
	if _ui_scale_option:
		_ui_scale_option.item_selected.connect(_on_ui_scale_option_selected)
	if _ui_scale_slider:
		_ui_scale_slider.value_changed.connect(_on_ui_scale_slider_changed)
	if _ui_scale_input:
		_ui_scale_input.text_changed.connect(_on_ui_scale_input_changed)
	
	# FOV signals
	if _fov_slider:
		_fov_slider.value_changed.connect(_on_fov_slider_changed)
	if _fov_min_input:
		_fov_min_input.text_changed.connect(_on_fov_min_input_changed)
	if _fov_max_input:
		_fov_max_input.text_changed.connect(_on_fov_max_input_changed)

func _connect_gameplay_signals():
	if _difficulty_option:
		_difficulty_option.item_selected.connect(_on_difficulty_changed)

func _apply_consistent_theme():
	"""Apply consistent theme using ThemeManager for visual parity with other panels"""
	# Apply main panel styling
	ThemeManager.apply_consistent_theme_to_panel(self)
	
	# Apply title styling to the main title label
	var title_label = get_node_or_null("ScrollContainer/VBoxContainer/Title")
	if title_label:
		ThemeManager.apply_title_style(title_label)

func _initialize_audio_settings():
	# Ensure audio buses exist before trying to access them
	_ensure_audio_buses_exist()
	
	# Store original values using AudioManager
	if audio_manager:
		_original_values["master_volume"] = audio_manager.get_master_volume()
		_original_values["music_volume"] = audio_manager.get_music_volume()
		_original_values["sfx_volume"] = audio_manager.get_sfx_volume()
	else:
		# Fallback to AudioServer if AudioManager not available
		var master_bus = AudioServer.get_bus_index("Master")
		var music_bus = AudioServer.get_bus_index("Music")
		var sfx_bus = AudioServer.get_bus_index("SFX")
		
		if master_bus >= 0:
			var master_db = AudioServer.get_bus_volume_db(master_bus)
			_original_values["master_volume"] = db_to_linear(master_db)
		else:
			_original_values["master_volume"] = 1.0  # Default volume
			
		if music_bus >= 0:
			var music_db = AudioServer.get_bus_volume_db(music_bus)
			_original_values["music_volume"] = db_to_linear(music_db)
		else:
			_original_values["music_volume"] = 1.0  # Default volume
			
		if sfx_bus >= 0:
			var sfx_db = AudioServer.get_bus_volume_db(sfx_bus)
			_original_values["sfx_volume"] = db_to_linear(sfx_db)
		else:
			_original_values["sfx_volume"] = 1.0  # Default volume
	
	# Set current values
	if _master_slider:
		var master_percent = _original_values["master_volume"] * 100.0
		_master_slider.value = master_percent
	if _music_slider:
		var music_percent = _original_values["music_volume"] * 100.0
		_music_slider.value = music_percent
	if _sfx_slider:
		var sfx_percent = _original_values["sfx_volume"] * 100.0
		_sfx_slider.value = sfx_percent
	
	_update_volume_labels()

func _ensure_audio_buses_exist():
	"""Enhanced audio bus fallback logic with better error handling and integration"""
	# Get or create audio buses using improved fallback system
	_ensure_audio_buses()
	
	# Connect fallback buses to actual audio system
	_connect_audio_buses_to_game()

func _ensure_audio_buses():
	"""Get or create audio buses with proper fallback logic"""
	# Get or create Master bus
	_master_bus = _get_or_create_bus("Master", 0)
	
	# Get or create other buses
	_music_bus = _get_or_create_bus("Music", 1)
	_sfx_bus = _get_or_create_bus("SFX", 2)
	_ui_bus = _get_or_create_bus("UI", 3)

func _get_or_create_bus(bus_name: String, index: int) -> int:
	"""Get existing audio bus or create fallback with proper error handling"""
	var bus = AudioServer.get_bus_index(bus_name)
	if bus == -1:
		AudioServer.add_bus(index)  # add_bus() returns void, not the index
		bus = index  # Use the index we specified when adding
		AudioServer.set_bus_name(bus, bus_name)
		
		# Set default volume for new bus
		AudioServer.set_bus_volume_db(bus, linear_to_db(1.0))
		AudioServer.set_bus_mute(bus, false)
		
		push_warning("Created fallback audio bus: %s at index %d" % [bus_name, bus])
		
		# Log additional debug info
		print("Audio bus fallback created - Bus: %s, Index: %d, Total buses: %d" % [
			bus_name, bus, AudioServer.get_bus_count()
		])
	return bus

func _connect_audio_buses_to_game():
	"""Connect fallback buses to actual game audio system"""
	# Ensure AudioManager is aware of the audio buses
	if audio_manager:
		if audio_manager.has_method("refresh_audio_buses"):
			audio_manager.refresh_audio_buses()
		elif audio_manager.has_method("initialize_audio"):
			audio_manager.initialize_audio()
	
	# Verify audio bus connectivity
	_verify_audio_bus_connectivity()

func _verify_audio_bus_connectivity():
	"""Verify that audio buses are properly connected and functional"""
	var bus_names = ["Master", "Music", "SFX", "UI"]
	for bus_name in bus_names:
		var bus_index = AudioServer.get_bus_index(bus_name)
		if bus_index >= 0:
			var volume = AudioServer.get_bus_volume_db(bus_index)
			var mute = AudioServer.is_bus_mute(bus_index)
			print("Audio bus '%s' (index %d): Volume=%.1fdB, Muted=%s" % [
				bus_name, bus_index, volume, mute
			])
		else:
			push_error("Failed to create or find audio bus: %s" % bus_name)

func _initialize_graphics_settings():
	# Store original values
	var bg_renderer = get_tree().get_first_node_in_group("background_renderer")
	if bg_renderer:
		_original_values["ultra_hd"] = bg_renderer.ultra_hd_enabled
		_original_values["seamless_tiling"] = bg_renderer.seamless_tiling_enabled
		if _ultra_hd_check:
			_ultra_hd_check.button_pressed = _original_values["ultra_hd"]
		if _seamless_tiling_check:
			_seamless_tiling_check.button_pressed = _original_values["seamless_tiling"]
	
	_original_values["fullscreen"] = (DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)
	_original_values["vsync"] = (DisplayServer.window_get_vsync_mode() == DisplayServer.VSYNC_ENABLED)
	_original_values["reduce_motion"] = false
	
	if _fullscreen_check:
		_fullscreen_check.button_pressed = _original_values["fullscreen"]
	if _vsync_check:
		_vsync_check.button_pressed = _original_values["vsync"]
	if _reduce_motion_check:
		_reduce_motion_check.button_pressed = _original_values["reduce_motion"]
	
	# Resolution and UI scale
	_original_resolution = DisplayServer.window_get_size()
	_pending_resolution = _original_resolution
	_original_values["resolution"] = _original_resolution
	var root = get_tree().root
	if root:
		_original_ui_scale = root.content_scale_factor
	else:
		_original_ui_scale = 1.0
	_ui_scale = _original_ui_scale
	_pending_ui_scale = _ui_scale
	_original_values["ui_scale"] = _original_ui_scale
	
	_initialize_resolution_controls()
	_initialize_ui_scale_controls()
	
	# Initialize FOV settings
	_initialize_fov_settings()

func _initialize_gameplay_settings():
	# Initialize difficulty options
	_difficulty_option.clear()
	_difficulty_option.add_item("Normal")
	_difficulty_option.add_item("Easy")
	_difficulty_option.add_item("Hard")
	_difficulty_option.add_item("Nightmare")
	
	_original_values["difficulty"] = 0  # Normal
	_difficulty_option.selected = _original_values["difficulty"]

func _initialize_resolution_controls() -> void:
	if _resolution_option == null:
		return
	_resolution_option.clear()
	var presets: Array[Vector2i] = [
		Vector2i(1280, 720),
		Vector2i(1600, 900),
		Vector2i(1920, 1080),
		Vector2i(2560, 1440),
		Vector2i(3840, 2160),
	]
	for res in presets:
		var label := "%dx%d" % [res.x, res.y]
		_resolution_option.add_item(label)
		_resolution_option.set_item_metadata(_resolution_option.item_count - 1, res)
	_resolution_option.add_item("Custom")
	_resolution_option.set_item_metadata(_resolution_option.item_count - 1, Vector2i.ZERO)
	
	var current_size: Vector2i = DisplayServer.window_get_size()
	var closest_index: int = 0
	var closest_delta: int = 1_000_000_000
	for i in range(_resolution_option.item_count):
		var meta: Variant = _resolution_option.get_item_metadata(i)
		if meta is Vector2i and meta != Vector2i.ZERO:
			var v: Vector2i = meta
			var delta: int = abs(v.x - current_size.x) + abs(v.y - current_size.y)
			if delta < closest_delta:
				closest_delta = delta
				closest_index = i
	_resolution_option.selected = closest_index

func _initialize_ui_scale_controls() -> void:
	if _ui_scale_option == null or _ui_scale_slider == null or _ui_scale_input == null:
		return
	_ui_scale_option.clear()
	var preset_scales: Array[float] = [0.75, 1.0, 1.25, 1.5]
	for scale_value in preset_scales:
		var label := str(int(scale_value * 100.0)) + "%"
		_ui_scale_option.add_item(label)
		_ui_scale_option.set_item_metadata(_ui_scale_option.item_count - 1, scale_value)
	_ui_scale_option.add_item("Custom")
	_ui_scale_option.set_item_metadata(_ui_scale_option.item_count - 1, -1.0)
	
	_pending_ui_scale = _ui_scale
	_sync_ui_scale_controls()

func _sync_ui_scale_controls() -> void:
	if _ui_scale_slider == null or _ui_scale_input == null or _ui_scale_option == null:
		return
	var percent := int(round(_pending_ui_scale * 100.0))
	_ui_scale_slider.value = percent
	_ui_scale_input.text = str(percent) + "%"
	
	# Select closest preset if any
	var best_index: int = _ui_scale_option.item_count - 1
	var best_diff: float = 1_000.0
	for i in range(_ui_scale_option.item_count):
		var meta: Variant = _ui_scale_option.get_item_metadata(i)
		if typeof(meta) == TYPE_FLOAT and float(meta) > 0.0:
			var diff: float = abs(float(meta) - _pending_ui_scale)
			if diff < best_diff:
				best_diff = diff
				best_index = i
	_ui_scale_option.selected = best_index

func _update_volume_labels():
	if _master_slider and _master_value:
		_master_value.text = str(int(_master_slider.value)) + "%"
	if _music_slider and _music_value:
		_music_value.text = str(int(_music_slider.value)) + "%"
	if _sfx_slider and _sfx_value:
		_sfx_value.text = str(int(_sfx_slider.value)) + "%"

func _mark_settings_changed():
	_settings_changed = true
	_apply_button.modulate = Color(1.0, 1.0, 0.5)  # Yellow tint to indicate changes

# Audio callbacks
func _on_master_volume_changed(value: float) -> void:
	if _master_value:
		_master_value.text = str(int(value)) + "%"
	var volume = value / 100.0
	if audio_manager:
		audio_manager.set_master_volume(volume)
	else:
		# Fallback to AudioServer with bounds checking
		var master_bus = AudioServer.get_bus_index("Master")
		if master_bus >= 0:
			var db_value = linear_to_db(volume)
			AudioServer.set_bus_volume_db(master_bus, db_value)
	_mark_settings_changed()

func _on_music_volume_changed(value: float) -> void:
	if _music_value:
		_music_value.text = str(int(value)) + "%"
	var volume = value / 100.0
	if audio_manager:
		audio_manager.set_music_volume(volume)
	else:
		# Fallback to AudioServer with bounds checking
		var music_bus = AudioServer.get_bus_index("Music")
		if music_bus >= 0:
			var db_value = linear_to_db(volume)
			AudioServer.set_bus_volume_db(music_bus, db_value)
	_mark_settings_changed()

func _on_sfx_volume_changed(value: float) -> void:
	if _sfx_value:
		_sfx_value.text = str(int(value)) + "%"
	var volume = value / 100.0
	if audio_manager:
		audio_manager.set_sfx_volume(volume)
	else:
		# Fallback to AudioServer with bounds checking
		var sfx_bus = AudioServer.get_bus_index("SFX")
		if sfx_bus >= 0:
			var db_value = linear_to_db(volume)
			AudioServer.set_bus_volume_db(sfx_bus, db_value)
	_mark_settings_changed()

# Graphics callbacks
func _on_ultra_hd_toggled(pressed: bool) -> void:
	var bg_renderer = get_tree().get_first_node_in_group("background_renderer")
	if bg_renderer:
		bg_renderer.ultra_hd_enabled = pressed
		bg_renderer._update_shader_state()
	_mark_settings_changed()

func _on_seamless_tiling_toggled(pressed: bool) -> void:
	var bg_renderer = get_tree().get_first_node_in_group("background_renderer")
	if bg_renderer:
		bg_renderer.seamless_tiling_enabled = pressed
		bg_renderer._update_shader_state()
	_mark_settings_changed()

func _on_fullscreen_toggled(pressed: bool) -> void:
	if pressed:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	_mark_settings_changed()

func _on_vsync_toggled(pressed: bool) -> void:
	if pressed:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_mark_settings_changed()

func _on_reduce_motion_toggled(pressed: bool) -> void:
	# Could be used to disable animations, parallax effects, etc.
	print("SettingsPanel: Reduce motion toggled to ", pressed)
	_mark_settings_changed()

func _on_resolution_selected(index: int) -> void:
	var meta: Variant = _resolution_option.get_item_metadata(index)
	if meta is Vector2i and meta != Vector2i.ZERO:
		_pending_resolution = meta
	else:
		_pending_resolution = DisplayServer.window_get_size()
	_mark_settings_changed()

func _on_ui_scale_option_selected(index: int) -> void:
	var meta = _ui_scale_option.get_item_metadata(index)
	if typeof(meta) == TYPE_FLOAT and meta > 0.0:
		_pending_ui_scale = meta
		_sync_ui_scale_controls()
		_mark_settings_changed()

func _on_ui_scale_slider_changed(value: float) -> void:
	_pending_ui_scale = clamp(value / 100.0, 0.5, 2.0)
	_sync_ui_scale_controls()
	_mark_settings_changed()

func _on_ui_scale_input_changed(text: String) -> void:
	var cleaned := text.strip_edges().replace("%", "")
	if cleaned.is_empty():
		return
	var val := float(cleaned)
	if is_nan(val) or is_inf(val):
		return
	val = clamp(val, 50.0, 200.0)
	_pending_ui_scale = val / 100.0
	_sync_ui_scale_controls()
	_mark_settings_changed()

# FOV callbacks
func _on_fov_slider_changed(value: float) -> void:
	_current_fov = value
	_fov_value.text = str(int(value)) + "°"
	_apply_fov_to_camera()
	_mark_settings_changed()

func _on_fov_min_input_changed(new_text: String) -> void:
	var new_value = _validate_fov_input(new_text, _fov_min)
	if new_value != _fov_min:
		_fov_min = new_value
		_fov_min_input.text = str(int(_fov_min))
		_update_fov_slider_range()
		_mark_settings_changed()
	else:
		_fov_min_input.text = str(int(_fov_min))

func _on_fov_max_input_changed(new_text: String) -> void:
	var new_value = _validate_fov_input(new_text, _fov_max)
	if new_value != _fov_max:
		_fov_max = new_value
		_fov_max_input.text = str(int(_fov_max))
		_update_fov_slider_range()
		_mark_settings_changed()
	else:
		_fov_max_input.text = str(int(_fov_max))

func _validate_fov_input(text: String, current_value: float) -> float:
	# Validate input is a valid number
	if text.is_empty():
		return current_value
	
	var new_value = float(text)
	if is_nan(new_value) or is_inf(new_value):
		return current_value
	
	# Apply very loose constraints - allow almost any reasonable value
	if text == "min":
		return 1.0
	elif text == "max":
		return 360.0
	elif new_value < 1.0:
		return 1.0
	elif new_value > 360.0:
		return 360.0
	
	# For min input, ensure it's less than max
	if _fov_min_input and text == _fov_min_input.text:
		if new_value >= _fov_max:
			return _fov_max - 0.1
	
	# For max input, ensure it's greater than min
	if _fov_max_input and text == _fov_max_input.text:
		if new_value <= _fov_min:
			return _fov_min + 0.1
	
	return new_value

# Gameplay callbacks
func _on_difficulty_changed(index: int) -> void:
	print("SettingsPanel: Difficulty changed to ", _difficulty_option.get_item_text(index))
	_mark_settings_changed()

# Button callbacks
func _on_apply_pressed() -> void:
	print("DEBUG: Apply button pressed")
	if audio_manager:
		audio_manager.play_button_click()
	
	# Debug: Check UI scale slider state
	if _ui_scale_slider:
		print("DEBUG: UI scale slider value: ", _ui_scale_slider.value)
		print("DEBUG: UI scale slider valid: ", _ui_scale_slider.value >= 0.5 and _ui_scale_slider.value <= 2.0)
	else:
		print("DEBUG: UI scale slider is null")
	
	# Validate settings before applying
	print("DEBUG: Starting settings validation...")
	if not _validate_all_settings():
		print("DEBUG: Settings validation failed - returning early")
		return
	
	print("DEBUG: Settings validation passed - applying settings")
	# Save settings (in a real game, you'd save to a config file)
	print("SettingsPanel: Settings applied and saved")
	
	# Save settings to player
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("set_fov_range"):
		player.set_fov_range(_fov_min, _fov_max)
	
	# Apply resolution and UI scale
	if _pending_resolution != Vector2i.ZERO:
		print("DEBUG: Applying resolution: ", _pending_resolution)
		DisplayServer.window_set_size(_pending_resolution)
	var root = get_tree().root
	if root:
		print("DEBUG: Applying UI scale: ", _pending_ui_scale)
		root.content_scale_factor = _pending_ui_scale
	
	_settings_changed = false
	_apply_button.modulate = Color.WHITE  # Reset button color

func _validate_all_settings() -> bool:
	"""Validate all settings before applying them"""
	var graphics_valid = _validate_graphics_settings()
	var audio_valid = _validate_audio_settings()
	var gameplay_valid = _validate_gameplay_settings()
	
	return graphics_valid and audio_valid and gameplay_valid

func _validate_graphics_settings() -> bool:
	"""Check if graphics settings are compatible and valid"""
	# Check if resolution is supported
	if _resolution_option:
		var selected_resolution = _get_selected_resolution()
		if not _is_resolution_supported(selected_resolution):
			_show_error("Selected resolution not supported: %s" % str(selected_resolution))
			return false
	
	# Check fullscreen compatibility
	if _fullscreen_check and _fullscreen_check.button_pressed:
		if not _can_go_fullscreen():
			_show_error("Fullscreen not available on this system")
			return false
	
	# Check UI scale range
	if _ui_scale_slider:
		var ui_scale_percent = _ui_scale_slider.value
		var ui_scale = ui_scale_percent / 100.0  # Convert percent to scale factor
		print("DEBUG: UI scale percent: ", ui_scale_percent, ", scale factor: ", ui_scale)
		if ui_scale < 0.5 or ui_scale > 2.0:
			_show_error("UI scale must be between 0.5x and 2.0x")
			return false
	
	# Check FOV range
	if _fov_min < 1.0 or _fov_max > 360.0 or _fov_min >= _fov_max:
		_show_error("Invalid FOV range: Min must be >= 1.0, Max must be <= 360.0, and Min < Max")
		return false
	
	return true

func _validate_audio_settings() -> bool:
	"""Check if audio settings are within valid ranges"""
	# Check volume ranges for all buses
	var bus_configs = [
		{"name": "Master", "slider": _master_slider, "bus_index": _master_bus},
		{"name": "Music", "slider": _music_slider, "bus_index": _music_bus},
		{"name": "SFX", "slider": _sfx_slider, "bus_index": _sfx_bus},
		{"name": "UI", "slider": null, "bus_index": _ui_bus}  # UI bus may not have slider
	]
	
	for config in bus_configs:
		var bus_name = config["name"]
		var slider = config["slider"]
		var bus_index = config["bus_index"]
		
		if bus_index >= 0:
			var volume_db = AudioServer.get_bus_volume_db(bus_index)
			
			# Check if volume is within reasonable dB range (-80 to 0 dB)
			if volume_db < -80 or volume_db > 0:
				_show_error("Invalid volume for %s bus: %.1f dB (must be between -80 and 0 dB)" % [bus_name, volume_db])
				return false
			
			# If slider exists, verify it matches bus volume
			if slider:
				var slider_percent = slider.value
				var expected_db = linear_to_db(slider_percent / 100.0)
				if abs(volume_db - expected_db) > 1.0:  # Allow 1dB tolerance
					print("Warning: %s slider (%.1f%%) doesn't match bus volume (%.1f dB)" % [
						bus_name, slider_percent, volume_db
					])
		else:
			push_warning("Audio bus %s not found, skipping validation" % bus_name)
	
	return true

func _validate_gameplay_settings() -> bool:
	"""Check if gameplay settings are valid"""
	# Check difficulty selection
	if _difficulty_option:
		var difficulty_index = _difficulty_option.selected
		if difficulty_index < 0 or difficulty_index >= _difficulty_option.item_count:
			_show_error("Invalid difficulty selection")
			return false
	
	# Add more gameplay validation as needed
	return true

func _get_selected_resolution() -> Vector2i:
	"""Get the currently selected resolution from the option button"""
	if not _resolution_option:
		return Vector2i.ZERO
	
	var selected_text = _resolution_option.get_item_text(_resolution_option.selected)
	# Parse resolution from text like "1920x1080"
	var parts = selected_text.split("x")
	if parts.size() == 2:
		return Vector2i(int(parts[0]), int(parts[1]))
	
	return Vector2i.ZERO

func _is_resolution_supported(resolution: Vector2i) -> bool:
	"""Check if the given resolution is supported by the system"""
	if resolution == Vector2i.ZERO:
		return false
	
	# Get list of supported resolutions (unused but kept for reference)
	var _supported_resolutions = DisplayServer.screen_get_size()
	
	# Basic validation - check if resolution is reasonable
	if resolution.x < 640 or resolution.y < 480:
		return false  # Too small
	
	if resolution.x > 7680 or resolution.y > 4320:
		return false  # Too large (8K+)
	
	# Check common aspect ratios
	var aspect_ratio = float(resolution.x) / float(resolution.y)
	var common_ratios = [4.0/3.0, 16.0/9.0, 16.0/10.0, 21.0/9.0]
	
	for ratio in common_ratios:
		if abs(aspect_ratio - ratio) < 0.1:  # Allow 10% tolerance
			return true
	
	# If not a common ratio, still allow it but warn
	print("Warning: Unusual aspect ratio %.2f for resolution %s" % [aspect_ratio, resolution])
	return true

func _can_go_fullscreen() -> bool:
	"""Check if fullscreen mode is available on this system"""
	# Most systems support fullscreen, but we can add specific checks
	# For now, just return true as a basic check
	return true

func _show_error(message: String):
	"""Show an error message to the user"""
	print("Settings Error: %s" % message)
	
	# You could show a popup or update a label here
	# For now, just print to console and reset apply button
	_apply_button.modulate = Color.RED
	
	# Reset after 2 seconds
	await get_tree().create_timer(2.0).timeout
	_apply_button.modulate = Color.WHITE

func _on_back_pressed() -> void:
	if audio_manager:
		audio_manager.play_button_click()
	if _settings_changed:
		# In a real game, you might ask "Discard changes?" here
		print("SettingsPanel: Discarding unsaved changes")
		_reset_to_original_values()
	
	back_requested.emit()

func _reset_to_original_values():
	# Reset audio using AudioManager
	if audio_manager:
		audio_manager.set_master_volume(_original_values["master_volume"])
		audio_manager.set_music_volume(_original_values["music_volume"])
		audio_manager.set_sfx_volume(_original_values["sfx_volume"])
	else:
		# Fallback to AudioServer - convert linear to db
		var master_linear = _original_values["master_volume"]
		var music_linear = _original_values["music_volume"]
		var sfx_linear = _original_values["sfx_volume"]
		
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(master_linear))
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(music_linear))
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(sfx_linear))
	
	_master_slider.value = _original_values["master_volume"] * 100.0
	_music_slider.value = _original_values["music_volume"] * 100.0
	_sfx_slider.value = _original_values["sfx_volume"] * 100.0
	
	# Reset graphics
	var bg_renderer = get_tree().get_first_node_in_group("background_renderer")
	if bg_renderer:
		if bg_renderer.has_method("toggle_ultra_hd"):
			bg_renderer.toggle_ultra_hd(_original_values["ultra_hd"])
		if bg_renderer.has_method("toggle_seamless_tiling"):
			bg_renderer.toggle_seamless_tiling(_original_values["seamless_tiling"])
	
	_ultra_hd_check.button_pressed = _original_values["ultra_hd"]
	_seamless_tiling_check.button_pressed = _original_values["seamless_tiling"]
	_fullscreen_check.button_pressed = _original_values["fullscreen"]
	_vsync_check.button_pressed = _original_values["vsync"]
	_reduce_motion_check.button_pressed = _original_values["reduce_motion"]
	
	# Reset gameplay
	_difficulty_option.selected = _original_values["difficulty"]
	
	# Reset FOV
	_fov_min = _original_values["fov_min"]
	_fov_max = _original_values["fov_max"]
	_current_fov = _original_values["current_fov"]
	_fov_min_input.text = str(int(_fov_min))
	_fov_max_input.text = str(int(_fov_max))
	_fov_slider.min_value = _fov_min
	_fov_slider.max_value = _fov_max
	_fov_slider.value = _current_fov
	_fov_value.text = str(int(_current_fov)) + "°"
	_apply_fov_to_camera()
	
	_update_volume_labels()
	_settings_changed = false
	_apply_button.modulate = Color.WHITE

# FOV helper functions
func _initialize_fov_settings():
	# Get current FOV from player camera or use default
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_node("Camera2D"):
		var camera = player.get_node("Camera2D")
		_current_fov = camera.zoom.x * 100.0  # Convert zoom to FOV approximation
	else:
		_current_fov = _default_fov
	
	# Store original values
	_original_values["fov_min"] = _fov_min
	_original_values["fov_max"] = _fov_max
	_original_values["current_fov"] = _current_fov
	
	# Set UI values
	_fov_min_input.text = str(int(_fov_min))
	_fov_max_input.text = str(int(_fov_max))
	_fov_slider.min_value = _fov_min
	_fov_slider.max_value = _fov_max
	_fov_slider.value = _current_fov
	_fov_value.text = str(int(_current_fov)) + "°"

func _update_fov_slider_range():
	_fov_slider.min_value = _fov_min
	_fov_slider.max_value = _fov_max
	# Ensure current value is within new range
	if _current_fov < _fov_min:
		_current_fov = _fov_min
		_fov_slider.value = _current_fov
		_fov_value.text = str(int(_current_fov)) + "°"
		_apply_fov_to_camera()
	elif _current_fov > _fov_max:
		_current_fov = _fov_max
		_fov_slider.value = _current_fov
		_fov_value.text = str(int(_current_fov)) + "°"
		_apply_fov_to_camera()

func _apply_fov_to_camera():
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_node("Camera2D"):
		var camera = player.get_node("Camera2D")
		# Convert FOV to zoom (inverse relationship - higher FOV = lower zoom)
		var zoom_value = 100.0 / _current_fov
		camera.zoom = Vector2(zoom_value, zoom_value)
	
	# Update player FOV range
	if player and player.has_method("set_fov_range"):
		player.set_fov_range(_fov_min, _fov_max)

# Communication functions with Player
func _get_current_fov_settings() -> Dictionary:
	return {
		"min": _fov_min,
		"max": _fov_max,
		"current": _current_fov
	}

func _update_fov_from_player(new_fov: float):
	# Called by player when FOV changes via scroll wheel
	if new_fov >= _fov_min and new_fov <= _fov_max:
		_current_fov = new_fov
		_fov_slider.value = _current_fov
		_fov_value.text = str(int(_current_fov)) + "°"
		_mark_settings_changed()
