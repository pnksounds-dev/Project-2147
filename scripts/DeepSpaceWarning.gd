extends Node

class_name DeepSpaceWarning

# Warning system
var warning_active: bool = false
var warning_display_time: float = 3.0
var warning_cooldown: float = 10.0
var last_warning_time: float = 0.0

# Reference systems
var coordinate_system: CoordinateSystem
var notification_system: Node  # Will connect to HUD/notification system

func _ready():
	add_to_group("deep_space_warning")
	coordinate_system = get_tree().get_first_node_in_group("coordinate_system")
	notification_system = get_tree().get_first_node_in_group("hud")
	
	# Connect to coordinate system signals
	if coordinate_system:
		coordinate_system.entered_deep_space.connect(_on_entered_deep_space)
		coordinate_system.exited_deep_space.connect(_on_exited_deep_space)

func _on_entered_deep_space():
	"""Handle entering deep space"""
	var current_time = Time.get_time_dict_from_system()["hour"] * 3600 + Time.get_time_dict_from_system()["minute"] * 60 + Time.get_time_dict_from_system()["second"]
	
	# Check cooldown before showing warning
	if current_time - last_warning_time >= warning_cooldown:
		_show_deep_space_warning()
		last_warning_time = current_time

func _on_exited_deep_space():
	"""Handle exiting deep space"""
	if warning_active:
		_hide_deep_space_warning()

func _show_deep_space_warning():
	"""Show deep space warning notification"""
	warning_active = true
	
	var warning_message = "WARNING: Deep Space Detected\nNot much happens out here yet"
	
	# Send to notification system
	if notification_system:
		if notification_system.has_method("show_notification"):
			notification_system.show_notification(warning_message, warning_display_time)
		else:
			print("Deep Space Warning: ", warning_message)
	else:
		print("Deep Space Warning: ", warning_message)

func _hide_deep_space_warning():
	"""Hide deep space warning"""
	warning_active = false

func force_warning():
	"""Force show a deep space warning (for testing)"""
	_show_deep_space_warning()
