extends Control

class_name NotificationPanel

var notification_queue: Array[String] = []
var current_notification: String = ""
var notification_timer: Timer
var max_notifications: int = 5

func _ready():
	add_to_group("notification_panel")
	add_to_group("notification_manager")  # For backward compatibility
	
	# Create timer for auto-hiding notifications
	notification_timer = Timer.new()
	notification_timer.wait_time = 3.0
	notification_timer.one_shot = true
	notification_timer.timeout.connect(_hide_notification)
	add_child(notification_timer)
	
	# Initially hidden
	visible = false

func show_notification(message: String):
	notification_queue.append(message)
	
	if not notification_timer.is_stopped():
		# Currently showing a notification, queue this one
		return
	
	_show_next_notification()

func _show_next_notification():
	if notification_queue.is_empty():
		visible = false
		return
	
	current_notification = notification_queue.pop_front()
	_update_display()
	visible = true
	notification_timer.start()

func _update_display():
	# Update the notification display
	$NotificationLabel.text = current_notification

func _hide_notification():
	visible = false
	_show_next_notification()
