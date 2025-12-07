extends Node

signal system_ready

# Note: we intentionally do NOT use class_name here to avoid clashing
# with the SaveManager autoload singleton name.

# Base directory for saves, derived from project root so it stays with the game folder
var _save_dir: String
var _current_save_data: Dictionary = {}
var _saves_cache: Array = []
var initialized: bool = false

func _ready() -> void:
	add_to_group("save_manager")
	# Convert res:// to an absolute filesystem path
	var project_root_fs := ProjectSettings.globalize_path("res://")
	_save_dir = project_root_fs.path_join("PlayerData").path_join("Saves")
	# Don't auto-initialize in _ready - let loading screen handle it

func initialize() -> void:
	"""Initialize save system for loading screen"""
	print("SaveManager: Initializing...")
	
	# Ensure save directory exists
	DirAccess.make_dir_recursive_absolute(_save_dir)
	
	# Scan saves directory
	_saves_cache = get_all_saves()
	
	initialized = true
	system_ready.emit()
	print("SaveManager: Initialization complete with ", _saves_cache.size(), " saves found")

func _get_save_files() -> Array[String]:
	var saves: Array[String] = []
	var dir := DirAccess.open(_save_dir)
	if dir == null:
		return saves
	dir.list_dir_begin()
	while true:
		var file_name := dir.get_next()
		if file_name == "":
			break
		if dir.current_is_dir():
			continue
		if file_name.ends_with(".json"):
			saves.append(file_name)
	dir.list_dir_end()
	return saves

func _load_save_file(path: String) -> Dictionary:
	var data: Dictionary = {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return data
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) == TYPE_DICTIONARY:
		data = parsed
	return data

func _save_to_file(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()

func get_all_saves() -> Array:
	var result: Array = []
	for file_name in _get_save_files():
		var full_path: String = _save_dir.path_join(file_name)
		var data: Dictionary = _load_save_file(full_path)
		if data.is_empty():
			continue
		var entry: Dictionary = {}
		entry.id = data.get("id", file_name)
		entry.name = data.get("name", file_name)
		entry.playtime = _format_playtime(data.get("playtime", 0.0))
		entry.score = int(data.get("score", 0))
		entry.favorite = bool(data.get("favorite", false))
		entry.stats_summary = data.get("stats_summary", "Player stats will appear here.")
		# Return ship_texture path as string, let SavesPanel load the actual Texture2D
		entry.ship_texture = data.get("ship_texture", "")
		entry._raw_path = full_path
		entry.created_at = int(data.get("created_at", 0))
		result.append(entry)
	# Sort newest first by created_at if present
	result.sort_custom(_sort_saves_newest_first)
	return result

func _sort_saves_newest_first(a: Dictionary, b: Dictionary) -> bool:
	return int(a.get("created_at", 0)) > int(b.get("created_at", 0))

func has_any_saves() -> bool:
	return not get_all_saves().is_empty()

func get_latest_save_data() -> Dictionary:
	"""Get the full save data of the most recent save"""
	var saves = get_all_saves()
	if saves.is_empty():
		return {}
	
	var latest_save = saves[0]  # Already sorted newest first
	return _load_save_file(latest_save._raw_path)

func load_latest() -> Dictionary:
	var saves: Array = get_all_saves()
	if saves.is_empty():
		return {}
	var latest: Dictionary = saves[0]
	_current_save_data = _load_save_file(String(latest._raw_path))
	
	# === UNIFIED INVENTORY INTEGRATION ===
	# Load inventory data into InventoryState autoload
	if has_node("/root/InventoryState"):
		var inventory_state = get_node("/root/InventoryState")
		if inventory_state.has_method("from_save_dict"):
			# Pass full save data so InventoryState can read or migrate the `inventory` section
			inventory_state.from_save_dict(_current_save_data)
	
	return _current_save_data

func toggle_favorite(save_id) -> bool:
	var saves := get_all_saves()
	for entry in saves:
		if str(entry.id) == str(save_id):
			var data := _load_save_file(entry._raw_path)
			var new_state := not bool(data.get("favorite", false))
			data["favorite"] = new_state
			_save_to_file(entry._raw_path, data)
			return new_state
	return false

func save_current_run(data: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(_save_dir)
	var timestamp: String = Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "_")
	
	# === UNIFIED INVENTORY REFACTOR: Use current save ID if available ===
	var game_state = get_node_or_null("/root/GameState")
	var use_existing_save := false
	if game_state and game_state.has_method("get_current_save_id"):
		var current_save_id = game_state.get_current_save_id()
		if not current_save_id.is_empty():
			data["id"] = current_save_id
			use_existing_save = true
	
	if not use_existing_save:
		var id: String = str(data.get("id", timestamp))
		data["id"] = id
	
	if not data.has("created_at"):
		data["created_at"] = Time.get_unix_time_from_system()
	
	# === UNIFIED INVENTORY INTEGRATION ===
	# Include inventory data from InventoryState autoload
	if has_node("/root/InventoryState"):
		var inventory_state = get_node("/root/InventoryState")
		if inventory_state.has_method("to_save_dict"):
			data["inventory"] = inventory_state.to_save_dict()
	
	var file_name: String = "save_%s.json" % data["id"]
	var full_path: String = _save_dir.path_join(file_name)
	_current_save_data = data.duplicate(true)
	_current_save_data = data.duplicate(true)
	_save_to_file(full_path, data)

func save_game() -> void:
	"""Public wrapper to save the current game state"""
	if _current_save_data.is_empty():
		# Create minimal save data if none exists
		_current_save_data = {
			"name": "Auto Save",
			"score": 0,
			"playtime": 0
		}
	save_current_run(_current_save_data)

func quick_save() -> void:
	"""Wrapper for quick save calls"""
	save_game()

func load_save(save_id: String) -> Dictionary:
	var entry := _get_entry_by_id(save_id)
	if entry.is_empty():
		return {}
	_current_save_data = _load_save_file(String(entry._raw_path))
	
	# === UNIFIED INVENTORY INTEGRATION ===
	# Load inventory data into InventoryState autoload
	if has_node("/root/InventoryState"):
		var inventory_state = get_node("/root/InventoryState")
		if inventory_state.has_method("from_save_dict"):
			# Pass full save data so InventoryState can read or migrate the `inventory` section
			inventory_state.from_save_dict(_current_save_data)
	
	return _current_save_data

func delete_save(save_id: String) -> bool:
	var entry := _get_entry_by_id(save_id)
	if entry.is_empty():
		return false
	var path := String(entry._raw_path)
	if not FileAccess.file_exists(path):
		return false
	var result := DirAccess.remove_absolute(path) == OK
	if result:
		# If we just deleted the current save, clear in-memory state and inventory.
		var game_state = get_node_or_null("/root/GameState")
		if game_state and game_state.has_method("get_current_save_id") and game_state.has_method("clear_current_save_id"):
			var current_id = game_state.get_current_save_id()
			if str(current_id) == str(save_id):
				game_state.clear_current_save_id()
				clear_current_save_data()
				# Reset inventory to an empty state so UI reflects that no save is loaded
				var inventory_state = get_node_or_null("/root/InventoryState")
				if inventory_state and inventory_state.has_method("reset_to_empty"):
					inventory_state.reset_to_empty()
	return result

func get_current_save_data() -> Dictionary:
	return _current_save_data.duplicate(true)

func clear_current_save_data() -> void:
	_current_save_data.clear()

func _format_playtime(seconds_value) -> String:
	var seconds: int = int(seconds_value)
	var hours: int = int(floor(seconds / 3600.0))
	var minutes: int = int(floor((seconds % 3600) / 60.0))
	return "%dh %02dm" % [hours, minutes]

func _get_entry_by_id(save_id: String) -> Dictionary:
	for entry in get_all_saves():
		if str(entry.id) == str(save_id):
			return entry
	return {}

func get_save_data(save_id: String) -> Dictionary:
	"""Get full raw save data for a specific save ID"""
	var entry := _get_entry_by_id(save_id)
	if entry.is_empty():
		return {}
	return _load_save_file(String(entry._raw_path))
