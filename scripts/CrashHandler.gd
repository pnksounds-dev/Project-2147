extends Node
class_name CrashHandler

## CrashHandler - Professional crash reporting system

func create_crash_report(error_message: String, context: String = "") -> void:
	"""Create a professional crash report"""
	var crash_dir = "user://PlayerData/Crash"
	DirAccess.make_dir_recursive_absolute(crash_dir)
	
	# Create crash dump file with timestamp
	var timestamp = Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "_")
	var crash_file_path = crash_dir + "/crash_" + timestamp + ".txt"
	var crash_file = FileAccess.open(crash_file_path, FileAccess.WRITE)
	
	if crash_file:
		crash_file.store_string("=== CRASH REPORT ===\n")
		crash_file.store_string("Timestamp: " + Time.get_datetime_string_from_system() + "\n")
		crash_file.store_string("Error: " + error_message + "\n")
		if context != "":
			crash_file.store_string("Context: " + context + "\n")
		crash_file.store_string("\n=== SYSTEM INFORMATION ===\n")
		crash_file.store_string("OS: " + OS.get_name() + "\n")
		crash_file.store_string("Godot Version: " + Engine.get_version_info().string + "\n")
		crash_file.store_string("Video Adapter: " + RenderingServer.get_video_adapter_name() + "\n")
		crash_file.store_string("\n=== MEMORY USAGE ===\n")
		crash_file.store_string("Static Memory: " + str(OS.get_static_memory_usage()) + "\n")
		crash_file.store_string("\n=== LOADED SCENES ===\n")
		var root = get_tree().current_scene
		if root:
			crash_file.store_string("Current Scene: " + root.name + " (" + root.scene_file_path + ")\n")
			_log_scene_tree(crash_file, root, 0)
		crash_file.close()
		print("CrashHandler: Report saved to ", crash_file_path)
	else:
		print("CrashHandler: ERROR - Could not create crash file at ", crash_file_path)

func _log_scene_tree(file: FileAccess, node: Node, indent: int) -> void:
	"""Recursively log the scene tree"""
	var indent_str = "  ".repeat(indent)
	file.store_string(indent_str + "- " + node.name + " (" + node.get_class() + ")\n")
	for child in node.get_children():
		_log_scene_tree(file, child, indent + 1)

func show_error_on_screen(error_message: String) -> void:
	"""Display error message on screen"""
	var error_label = Label.new()
	error_label.text = "INITIALIZATION ERROR\n\n" + error_message + "\n\nCheck crash logs in PlayerData/Crash/"
	error_label.modulate = Color.RED
	error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	error_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	error_label.add_theme_font_size_override("font_size", 24)
	
	# Add to current scene
	var root = get_tree().current_scene
	if root:
		root.add_child(error_label)
		error_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		
		# Auto-remove after 10 seconds
		var timer = root.get_tree().create_timer(10.0)
		await timer.timeout
		if is_instance_valid(error_label):
			error_label.queue_free()

# Static convenience methods that create an instance
static func create_report(error_message: String, context: String = "") -> void:
	"""Static convenience method to create crash report"""
	var handler = CrashHandler.new()
	handler.create_crash_report(error_message, context)

static func show_error(error_message: String) -> void:
	"""Static convenience method to show error on screen"""
	var handler = CrashHandler.new()
	handler.show_error_on_screen(error_message)
