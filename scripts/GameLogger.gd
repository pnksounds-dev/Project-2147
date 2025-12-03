extends Node
class_name GameLogger

## GameLogger - Batch logging system to reduce output spam
## Logs messages in batches and rotates log files automatically

signal batch_completed(log_file: String, message_count: int)

var log_messages: Array[String] = []
var batch_timer: Timer
var log_file_path: String = "res://logs/game_log_%d.txt"
var current_log_index: int = 0
var max_logs: int = 10
var batch_interval: float = 60.0 # 1 minute
var max_messages_per_batch: int = 1000

# Log levels
enum LogLevel {
	VERBOSE,
	DEBUG,
	INFO,
	WARNING,
	ERROR,
	CRITICAL
}

# Filter settings
var enabled_levels: Array[LogLevel] = [LogLevel.VERBOSE, LogLevel.DEBUG, LogLevel.INFO, LogLevel.WARNING, LogLevel.ERROR, LogLevel.CRITICAL]
var enabled_systems: Array[String] = ["*"] # "*" means all systems, can filter specific systems

# Colors for console output
var level_colors = {
	LogLevel.VERBOSE: "gray",
	LogLevel.DEBUG: "cyan",
	LogLevel.INFO: "white",
	LogLevel.WARNING: "yellow",
	LogLevel.ERROR: "red",
	LogLevel.CRITICAL: "magenta"
}

func _ready():
	add_to_group("game_logger")
	_setup_batch_timer()
	_clean_old_logs()
	print_rich("[color=green]GameLogger: Initialized with batch interval: %s seconds[/color]" % batch_interval)

func _setup_batch_timer():
	batch_timer = Timer.new()
	batch_timer.wait_time = batch_interval
	batch_timer.timeout.connect(_flush_log_batch)
	batch_timer.autostart = true
	add_child(batch_timer)

func _clean_old_logs():
	# Ensure logs directory exists
	if not DirAccess.dir_exists_absolute("res://logs"):
		DirAccess.make_dir_absolute("res://logs")

	# Remove old log files, keeping only the most recent ones
	var dir = DirAccess.open("res://logs/")
	if not dir:
		return
	
	# Find all log files
	var log_files = []
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.begins_with("game_log_") and file_name.ends_with(".txt"):
			log_files.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	
	# Sort by modification time (newest first)
	log_files.sort_custom(func(a, b): return FileAccess.get_modified_time("res://logs/" + a) > FileAccess.get_modified_time("res://logs/" + b))
	
	# Remove excess logs
	while log_files.size() > max_logs:
		var old_log = log_files.pop_back()
		dir.remove(old_log)
		print("GameLogger: Removed old log file: ", old_log)

func log_verbose(message: String, system: String = "General"):
	_log_message(LogLevel.VERBOSE, message, system)

func log_debug(message: String, system: String = "General"):
	_log_message(LogLevel.DEBUG, message, system)

func log_info(message: String, system: String = "General"):
	_log_message(LogLevel.INFO, message, system)

func log_warning(message: String, system: String = "General"):
	_log_message(LogLevel.WARNING, message, system)

func log_error(message: String, system: String = "General"):
	_log_message(LogLevel.ERROR, message, system)

func log_critical(message: String, system: String = "General"):
	_log_message(LogLevel.CRITICAL, message, system)

func _log_message(level: LogLevel, message: String, system: String):
	# Check if this log level is enabled
	if level not in enabled_levels:
		return
	
	# Check if this system is enabled
	if not _is_system_enabled(system):
		return
	
	# Format the message
	var timestamp = Time.get_datetime_string_from_system()
	var level_string = LogLevel.keys()[level]
	var formatted_message = "[%s] [%s] [%s] %s" % [timestamp, level_string, system, message]
	
	# Console output with color
	var color = level_colors.get(level, "white")
	print_rich("[color=%s]%s[/color]" % [color, formatted_message])
	
	# Add to batch
	log_messages.append(formatted_message)
	
	# If we've reached the max messages per batch, flush immediately
	if log_messages.size() >= max_messages_per_batch:
		_flush_log_batch()

func _is_system_enabled(system: String) -> bool:
	if "*" in enabled_systems:
		return true
	return system in enabled_systems

func _flush_log_batch():
	if log_messages.is_empty():
		return
	
	# Create log file
	var file_path = log_file_path % current_log_index
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	
	if file:
		# Write batch header
		file.store_line("=== LOG BATCH - %s ===" % Time.get_datetime_string_from_system())
		file.store_line("Messages: %d" % log_messages.size())
		file.store_line("")
		
		# Write all messages
		for message in log_messages:
			file.store_line(message)
		
		# Write batch footer
		file.store_line("")
		file.store_line("=== END BATCH ===")
		file.close()
		
		# print("GameLogger: Flushed %d messages to %s" % [log_messages.size(), file_path]) # Reduced spam
		batch_completed.emit(file_path, log_messages.size())
	else:
		print("GameLogger: Failed to open log file: ", file_path)
	
	# Clear the batch and increment log index
	log_messages.clear()
	current_log_index = (current_log_index + 1) % max_logs

func flush_now():
	# Force immediate flush
	_flush_log_batch()

func set_log_level_filter(levels: Array[LogLevel]):
	enabled_levels = levels
	print("GameLogger: Log level filter updated: ", levels)

func set_system_filter(systems: Array[String]):
	enabled_systems = systems
	print("GameLogger: System filter updated: ", systems)

func set_batch_interval(interval: float):
	batch_interval = interval
	if batch_timer:
		batch_timer.wait_time = interval
	print("GameLogger: Batch interval updated to: ", interval, " seconds")

func get_log_statistics() -> Dictionary:
	return {
		"current_batch_size": log_messages.size(),
		"batch_interval": batch_interval,
		"current_log_index": current_log_index,
		"max_logs": max_logs,
		"enabled_levels": enabled_levels,
		"enabled_systems": enabled_systems
	}

# Convenience functions for common systems
func log_player(message: String, level: LogLevel = LogLevel.INFO):
	_log_message(level, message, "Player")

func log_hud(message: String, level: LogLevel = LogLevel.INFO):
	_log_message(level, message, "HUD")

func log_background(message: String, level: LogLevel = LogLevel.INFO):
	_log_message(level, message, "Background")

func log_combat(message: String, level: LogLevel = LogLevel.INFO):
	_log_message(level, message, "Combat")

func log_system(message: String, level: LogLevel = LogLevel.INFO):
	_log_message(level, message, "System")

func log_economy(message: String, level: LogLevel = LogLevel.INFO):
	_log_message(level, message, "Economy")

func log_skills(message: String, level: LogLevel = LogLevel.INFO):
	_log_message(level, message, "Skills")
