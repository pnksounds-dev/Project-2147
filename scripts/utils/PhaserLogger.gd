extends Node
class_name PhaserLogger

const LOG_DIR := "res://logs"
const LOG_FILE := LOG_DIR + "/phaser_debug.log"

static func _ensure_log_dir():
	if DirAccess.make_dir_recursive_absolute(LOG_DIR) != OK:
		push_warning("PhaserLogger: Failed to ensure log directory: %s" % LOG_DIR)

static func log_message(context: String, message: String) -> void:
	_ensure_log_dir()
	var timestamp := Time.get_datetime_string_from_system(true)
	var line := "[%s] [%s] %s\n" % [timestamp, context, message]
	var file := FileAccess.open(LOG_FILE, FileAccess.READ_WRITE)
	if not file:
##		push_warning("PhaserLogger: Failed to open log file: %s" % LOG_FILE) - disabled to prevent warning spam, can be reworked in future
		return
	file.seek_end()
	file.store_string(line)
	file.flush()
	file.close()

static func log_target(context: String, label: String, target: Vector2) -> void:
	log_message(context, "%s target=(%.2f, %.2f)" % [label, target.x, target.y])
