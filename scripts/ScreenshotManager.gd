extends Node

## ScreenshotManager - Handles screenshot capture, storage, and UI display

signal screenshot_taken(filepath: String, image: Image)
signal screenshot_deleted(filepath: String)

var screenshot_dir: String = "res://PlayerData/Screenshots"
var screenshot_format: String = "png" # png or jpg
var notification_manager: Node = null
var gallery_panel: Control = null

func _ready():
	add_to_group("screenshot_manager")
	
	# Get notification manager
	notification_manager = get_node_or_null("/root/NotificationManager")
	if not notification_manager:
		notification_manager = get_tree().get_first_node_in_group("notification_manager")
	
	# Ensure screenshot directory exists
	_ensure_screenshot_directory()

func _ensure_screenshot_directory():
	"""Create screenshot directory if it doesn't exist"""
	var dir := DirAccess.open("res://PlayerData")
	if dir and not dir.dir_exists("Screenshots"):
		dir.make_dir("Screenshots")

func take_screenshot() -> void:
	"""Take a screenshot and show UI feedback"""
	# Generate timestamped filename (extension chosen by screenshot_format)
	var datetime := Time.get_datetime_dict_from_system()
	var extension := screenshot_format.to_lower()
	if extension == "jpeg":
		extension = "jpg"
	var filename := "screenshot_%04d-%02d-%02d_%02d-%02d-%02d.%s" % [
		datetime.year, datetime.month, datetime.day,
		datetime.hour, datetime.minute, datetime.second,
		extension
	]
	var filepath := screenshot_dir + "/" + filename
	
	# Capture screenshot
	var viewport := get_viewport()
	var image := viewport.get_texture().get_image()
	
	if image:
		var err := OK
		match extension:
			"png":
				err = image.save_png(filepath)
			"jpg":
				# Use high quality JPEG
				err = image.save_jpg(filepath, 0.95)
			_:
				# Fallback to PNG if unknown
				filepath = filepath.get_basename() + ".png"
				err = image.save_png(filepath)
		if err == OK:
			print("Screenshot saved: " + filepath)
			_show_screenshot_flash(filepath, image)
			screenshot_taken.emit(filepath, image)
			
			# Update gallery if open
			if gallery_panel and gallery_panel.has_method("refresh_gallery"):
				gallery_panel.refresh_gallery()
		else:
			print("Failed to save screenshot: " + str(err))
			_show_notification("Screenshot failed to save!", 3.0)
	else:
		print("Failed to capture screenshot")
		_show_notification("Screenshot capture failed!", 3.0)

func _show_screenshot_flash(filepath: String, image: Image) -> void:
	"""Show flash effect and thumbnail after screenshot"""
	# Create flash overlay
	var flash := ColorRect.new()
	flash.name = "ScreenshotFlash"
	flash.color = Color.WHITE
	flash.anchor_right = 1.0
	flash.anchor_bottom = 1.0
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.z_index = 1000
	add_child(flash)
	
	# Flash animation
	flash.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(flash, "modulate:a", 0.8, 0.1)
	tween.tween_property(flash, "modulate:a", 0.0, 0.2)
	
	# Remove flash after animation
	tween.tween_callback(func():
		flash.queue_free()
		_create_thumbnail_notification(filepath, image)
	)

func _create_thumbnail_notification(_filepath: String, image: Image) -> void:
	"""Create small thumbnail notification"""
	var notification_panel := PanelContainer.new()
	notification_panel.name = "ScreenshotNotification"
	
	# Style the notification
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.9)
	style.border_color = Color(0.2, 0.8, 1, 1.0)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 0
	style.corner_radius_top_right = 0
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0
	notification_panel.add_theme_stylebox_override("panel", style)
	
	# Position in bottom right
	notification_panel.custom_minimum_size = Vector2(160, 100)
	notification_panel.anchor_left = 1.0
	notification_panel.anchor_top = 1.0
	notification_panel.offset_left = -170
	notification_panel.offset_top = -110
	notification_panel.offset_right = -10
	notification_panel.offset_bottom = -10
	notification_panel.z_index = 1002
	
	# Create content
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	notification_panel.add_child(vbox)
	
	# Title
	var title := Label.new()
	title.text = " Screenshot Saved!"
	title.add_theme_color_override("font_color", Color(0.2, 0.8, 1, 1))
	title.add_theme_font_size_override("font_size", 12)
	vbox.add_child(title)
	
	# Thumbnail
	var thumbnail := TextureRect.new()
	thumbnail.texture = ImageTexture.create_from_image(image)
	thumbnail.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	thumbnail.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	thumbnail.custom_minimum_size = Vector2(140, 80)
	vbox.add_child(thumbnail)
	
	add_child(notification_panel)
	
	# Auto-hide after 3 seconds
	var timer := Timer.new()
	timer.wait_time = 3.0
	timer.one_shot = true
	timer.timeout.connect(func():
		notification_panel.queue_free())
	add_child(timer)
	timer.start()

func get_screenshot_list() -> Array[Dictionary]:
	"""Get list of all screenshots with metadata"""
	var screenshots: Array[Dictionary] = []
	var dir := DirAccess.open(screenshot_dir)
	
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			if not dir.current_is_dir():
				var lower_name := file_name.to_lower()
				var allowed_ext = [".png", ".jpg", ".jpeg"]
				var has_allowed_ext := false
				for ext in allowed_ext:
					if lower_name.ends_with(ext):
						has_allowed_ext = true
						break
				if has_allowed_ext:
					var filepath: String = screenshot_dir + "/" + file_name
					if dir.file_exists(filepath):
						# Extract timestamp from filename for better sorting (ignore extension)
						var modified_time = 0
						var regex = RegEx.new()
						regex.compile(r"screenshot_(\d{4})-(\d{2})-(\d{2})_(\d{2})-(\d{2})-(\d{2})")
						var result = regex.search(file_name.get_basename())
						if result:
							var year = result.get_string(1).to_int()
							var month = result.get_string(2).to_int()
							var day = result.get_string(3).to_int()
							var hour = result.get_string(4).to_int()
							var minute = result.get_string(5).to_int()
							var second = result.get_string(6).to_int()
							var datetime = Time.get_datetime_dict_from_unix_time(int(Time.get_unix_time_from_system()))
							datetime.year = year
							datetime.month = month
							datetime.day = day
							datetime.hour = hour
							datetime.minute = minute
							datetime.second = second
							modified_time = Time.get_unix_time_from_datetime_dict(datetime)
						else:
							modified_time = Time.get_unix_time_from_system()
						
						screenshots.append({
							"filepath": filepath,
							"filename": file_name,
							"modified_time": modified_time,
							"file_size": 0,  # Could implement file size calculation later
							"favorite": false
						})
			file_name = dir.get_next()
	
	# Sort by modified time (newest first)
	screenshots.sort_custom(func(a, b): return a.modified_time > b.modified_time)
	return screenshots

func delete_screenshot(filepath: String) -> bool:
	"""Delete a screenshot file"""
	var dir := DirAccess.open(screenshot_dir)
	if dir and dir.file_exists(filepath.get_file()):
		var success = dir.remove(filepath.get_file()) == OK
		if success:
			screenshot_deleted.emit(filepath)
			_show_notification("Screenshot deleted!", 2.0)
		return success
	return false

func toggle_favorite(_filepath: String) -> bool:
	"""Toggle favorite status (saves to metadata file)"""
	# This would save favorite status to a metadata file
	# For now, just return true
	_show_notification("Favorite status toggled!", 2.0)
	return true

func open_screenshot_folder() -> void:
	"""Open the screenshot directory in the OS file explorer."""
	var global_path := ProjectSettings.globalize_path(screenshot_dir)
	OS.shell_open(global_path)

func set_screenshot_format(format: String) -> void:
	"""Set desired screenshot file format ("png" or "jpg")."""
	var lower := format.to_lower()
	if lower in ["png", "jpg", "jpeg"]:
		if lower == "jpeg":
			lower = "jpg"
		screenshot_format = lower

func _show_notification(message: String, duration: float = 3.0):
	"""Show notification message"""
	if notification_manager and notification_manager.has_method("show_notification"):
		notification_manager.show_notification(message, duration)
	else:
		print("Notification: " + message)

func set_gallery_panel(panel: Control):
	"""Set reference to gallery panel"""
	gallery_panel = panel
