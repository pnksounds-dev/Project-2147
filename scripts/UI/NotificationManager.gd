extends CanvasLayer

class_name NotificationManager

## NotificationManager - Displays achievement and milestone notifications

signal notification_shown(title: String, message: String)

var _notification_queue: Array[Dictionary] = []
var _current_notification: Control = null
var _notification_timer: float = 0.0
var _display_duration: float = 3.0

func _ready():
	add_to_group("notification_manager")
	add_to_group("hud")  # Also add to hud group for compatibility
	layer = 20  # Above everything else

func _process(delta: float):
	if _current_notification:
		_notification_timer -= delta
		if _notification_timer <= 0:
			_hide_current_notification()
	elif _notification_queue.size() > 0:
		_show_next_notification()

## Show a notification
func show_notification(title: String, message: String, icon: Texture2D = null, duration: float = 3.0):
	_notification_queue.append({
		"title": title,
		"message": message,
		"icon": icon,
		"duration": duration
	})

## Show achievement notification
func show_achievement(achievement_name: String, description: String):
	show_notification("🏆 Achievement Unlocked!", achievement_name + "\n" + description, null, 4.0)

## Show milestone notification
func show_milestone(milestone: String, reward: String = ""):
	var msg = milestone
	if reward != "":
		msg += "\nReward: " + reward
	show_notification("⭐ Milestone Reached!", msg, null, 3.5)

## Show ship unlock notification
func show_ship_unlock(ship_name: String):
	show_notification("🚀 New Ship Unlocked!", ship_name + " is now available!", null, 4.0)

func _show_next_notification():
	if _notification_queue.is_empty():
		return
	
	var notification_data = _notification_queue.pop_front()
	_create_notification_panel(notification_data)

func _create_notification_panel(data: Dictionary):
	# Create notification panel
	var panel = Panel.new()
	panel.size = Vector2(400, 100)
	panel.position = Vector2(get_viewport().get_visible_rect().size.x - 420, 20)
	
	# Style the panel
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.1, 0.1, 0.1, 0.9)
	style_box.border_width_left = 2
	style_box.border_width_right = 2
	style_box.border_width_top = 2
	style_box.border_width_bottom = 2
	style_box.border_color = Color(0.5, 0.5, 0.5, 0.8)
	style_box.corner_radius_top_left = 8
	style_box.corner_radius_top_right = 8
	style_box.corner_radius_bottom_left = 8
	style_box.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", style_box)
	
	# Add title label
	var title_label = Label.new()
	title_label.text = data.title
	title_label.position = Vector2(15, 10)
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.add_theme_color_override("font_color", Color.YELLOW)
	panel.add_child(title_label)
	
	# Add message label
	var message_label = Label.new()
	message_label.text = data.message
	message_label.position = Vector2(15, 35)
	message_label.size = Vector2(370, 50)
	message_label.add_theme_font_size_override("font_size", 12)
	message_label.add_theme_color_override("font_color", Color.WHITE)
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(message_label)
	
	# Add to scene
	add_child(panel)
	_current_notification = panel
	_notification_timer = data.duration
	
	# Animate in
	panel.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.3)

func _hide_current_notification():
	if _current_notification:
		var tween = create_tween()
		tween.tween_property(_current_notification, "modulate:a", 0.0, 0.3)
		tween.tween_callback(_current_notification.queue_free)
		_current_notification = null
