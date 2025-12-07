extends Node

## SettingsManager - Centralized settings management for graphics, audio, and input
signal system_ready
signal setting_changed(key: String, value: Variant)

# Settings file path
const SETTINGS_FILE := "user://settings.json"

# Default settings
var _default_settings: Dictionary = {
	"graphics": {
		"fullscreen": false,
		"vsync": true,
		"resolution": Vector2i(1920, 1080),
		"master_volume": 1.0,
		"music_volume": 1.0,
		"sfx_volume": 1.0,
		"ui_volume": 1.0,
		"territory_grid_enabled": true
	},
	"audio": {
		"master_volume": 1.0,
		"music_volume": 1.0,
		"sfx_volume": 1.0,
		"ui_volume": 1.0
	},
	"input": {
		"mouse_sensitivity": 1.0,
		"controller_sensitivity": 1.0
	},
	"ui": {
		"scale_factor": 1.0,
		"inventory_slot_size": 64,
		"inventory_grid_spacing": 4
	}
}

# Current settings
var _settings: Dictionary = {}
var initialized: bool = false

func _ready() -> void:
	add_to_group("settings_manager")

func initialize() -> void:
	"""Initialize settings system"""
	print("SettingsManager: Initializing...")
	
	# Load settings from disk
	_load_settings()
	
	# Apply settings to engine
	_apply_settings()
	
	initialized = true
	system_ready.emit()
	print("SettingsManager: Initialization complete")

func _load_settings() -> void:
	"""Load settings from file"""
	if FileAccess.file_exists(SETTINGS_FILE):
		var file = FileAccess.open(SETTINGS_FILE, FileAccess.READ)
		if file:
			var data = file.get_var()
			file.close()
			
			# Merge with defaults to ensure all keys exist
			_settings = _merge_settings(_default_settings, data)
	else:
		# Use default settings if file doesn't exist
		_settings = _default_settings.duplicate(true)
		_save_settings()

func _save_settings() -> void:
	"""Save settings to file"""
	var file = FileAccess.open(SETTINGS_FILE, FileAccess.WRITE)
	if file:
		file.store_var(_settings)
		file.close()

func _merge_settings(defaults: Dictionary, loaded: Dictionary) -> Dictionary:
	"""Merge loaded settings with defaults to ensure all keys exist"""
	var result = defaults.duplicate(true)
	
	for section in loaded:
		if result.has(section):
			if loaded[section] is Dictionary and result[section] is Dictionary:
				result[section] = _merge_settings(result[section], loaded[section])
			else:
				result[section] = loaded[section]
		else:
			result[section] = loaded[section]
	
	return result

func _apply_settings() -> void:
	"""Apply current settings to engine"""
	# Apply graphics settings
	if _settings.has("graphics"):
		var graphics = _settings.graphics
		
		# Fullscreen
		if graphics.has("fullscreen"):
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if graphics.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
		
		# VSync
		if graphics.has("vsync"):
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if graphics.vsync else DisplayServer.VSYNC_DISABLED)
		
		# Resolution
		if graphics.has("resolution"):
			var res = graphics.resolution
			DisplayServer.window_set_size(res)
	
	# Apply audio settings
	if _settings.has("audio"):
		_apply_audio_settings(_settings.audio)
	
	# Apply UI settings
	if _settings.has("ui"):
		_apply_ui_settings(_settings.ui)

func _apply_audio_settings(audio_settings: Dictionary) -> void:
	"""Apply audio settings to AudioManager"""
	var audio_manager = get_node_or_null("/root/AudioManager")
	if audio_manager:
		if audio_settings.has("master_volume"):
			audio_manager.set_master_volume(audio_settings.master_volume)
		if audio_settings.has("music_volume"):
			audio_manager.set_music_volume(audio_settings.music_volume)
		if audio_settings.has("sfx_volume"):
			audio_manager.set_sfx_volume(audio_settings.sfx_volume)
		if audio_settings.has("ui_volume"):
			audio_manager.set_ui_volume(audio_settings.ui_volume)

func _apply_ui_settings(ui_settings: Dictionary) -> void:
	"""Apply UI settings to all UI elements"""
	# Notify all UI elements that settings have changed
	var ui_elements = get_tree().get_nodes_in_group("ui_scaling")
	for element in ui_elements:
		if element.has_method("apply_ui_settings"):
			element.apply_ui_settings(ui_settings)

# Public API
func get_setting(key: String, default_value = null) -> Variant:
	"""Get a setting value by key (supports dot notation like 'graphics.fullscreen')"""
	var keys = key.split(".")
	var current = _settings
	
	for k in keys:
		if current is Dictionary and current.has(k):
			current = current[k]
		else:
			return default_value
	
	return current

func set_setting(key: String, value: Variant) -> void:
	"""Set a setting value by key (supports dot notation like 'graphics.fullscreen')"""
	var keys = key.split(".")
	var current = _settings
	
	# Navigate to the parent of the target key
	for i in range(keys.size() - 1):
		var k = keys[i]
		if not current.has(k):
			current[k] = {}
		current = current[k]
	
	# Set the value
	var last_key = keys[keys.size() - 1]
	var _old_value = current.get(last_key, null)
	current[last_key] = value
	
	# Apply the setting immediately if needed
	_apply_setting(key, value)
	
	# Save to disk
	_save_settings()
	
	# Emit signal
	setting_changed.emit(key, value)

func _apply_setting(key: String, value: Variant) -> void:
	"""Apply a specific setting immediately"""
	match key:
		"graphics.fullscreen":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if value else DisplayServer.WINDOW_MODE_WINDOWED)
		"graphics.vsync":
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if value else DisplayServer.VSYNC_DISABLED)
		"graphics.resolution":
			if value is Vector2i:
				DisplayServer.window_set_size(value)
		_:
			# For audio settings, apply through AudioManager
			if key.begins_with("audio.") or key.begins_with("graphics."):
				var section = key.split(".")[0]
				if _settings.has(section):
					_apply_audio_settings(_settings[section])

func reset_to_defaults() -> void:
	"""Reset all settings to defaults"""
	_settings = _default_settings.duplicate(true)
	_apply_settings()
	_save_settings()
	
	# Emit signals for all changed settings
	for section in _settings:
		if _settings[section] is Dictionary:
			for key in _settings[section]:
				setting_changed.emit(section + "." + key, _settings[section][key])

func get_all_settings() -> Dictionary:
	"""Get a copy of all settings"""
	return _settings.duplicate(true)
