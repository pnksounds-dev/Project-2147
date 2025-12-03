extends Node

# Note: we intentionally do NOT use class_name here to avoid clashing
# with the SaveManager autoload singleton name.

# Base directory for saves, derived from project root so it stays with the game folder
var _save_dir: String
var _current_save_data: Dictionary = {}

func _ready() -> void:
	# Convert res:// to an absolute filesystem path
	var project_root_fs := ProjectSettings.globalize_path("res://")
	_save_dir = project_root_fs.path_join("PlayerData").path_join("Saves")
	DirAccess.make_dir_recursive_absolute(_save_dir)

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
		# ship_texture will be resolved by other systems if needed
		entry.ship_texture = null
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

func load_latest() -> Dictionary:
	var saves: Array = get_all_saves()
	if saves.is_empty():
		return {}
	var latest: Dictionary = saves[0]
	_current_save_data = _load_save_file(String(latest._raw_path))
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

func load_save(save_id: String) -> Dictionary:
	var entry := _get_entry_by_id(save_id)
	if entry.is_empty():
		return {}
	_current_save_data = _load_save_file(String(entry._raw_path))
	return _current_save_data

func delete_save(save_id: String) -> bool:
	var entry := _get_entry_by_id(save_id)
	if entry.is_empty():
		return false
	var path := String(entry._raw_path)
	if not FileAccess.file_exists(path):
		return false
	return DirAccess.remove_absolute(path) == OK

func save_current_run(data: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(_save_dir)
	var timestamp: String = Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "_")
	var id: String = str(data.get("id", timestamp))
	data["id"] = id
	if not data.has("created_at"):
		data["created_at"] = Time.get_unix_time_from_system()
	var file_name: String = "save_%s.json" % id
	var full_path: String = _save_dir.path_join(file_name)
	_current_save_data = data.duplicate(true)
	_save_to_file(full_path, data)

func get_current_save_data() -> Dictionary:
	return _current_save_data.duplicate(true)

func clear_current_save_data() -> void:
	_current_save_data.clear()

func get_latest_save_data() -> Dictionary:
	if _current_save_data.is_empty():
		return load_latest()
	return _current_save_data.duplicate(true)

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
