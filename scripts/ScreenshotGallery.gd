extends Control

class_name ScreenshotGallery

## ScreenshotGallery - Displays screenshot collection with favorite/sort controls and fullscreen viewer

@onready var scroll_container: ScrollContainer = $ScrollContainer
@onready var grid_container: GridContainer = $ScrollContainer/GridContainer
@onready var sort_button: Button = $HeaderContainer/SortButton
@onready var filter_button: Button = $HeaderContainer/FilterButton
@onready var format_button: Button = $HeaderContainer/FormatButton if has_node("HeaderContainer/FormatButton") else null
@onready var back_button: Button = $BackButton if has_node("BackButton") else null
@onready var fullscreen_viewer: Control = $FullscreenViewer
@onready var fullscreen_image: TextureRect = $FullscreenViewer/FullscreenImage
@onready var viewer_close_button: Button = $FullscreenViewer/CloseButton
@onready var viewer_favorite_button: Button = $FullscreenViewer/FavoriteButton
@onready var viewer_delete_button: Button = $FullscreenViewer/DeleteButton
@onready var viewer_open_folder_button: Button = $FullscreenViewer/OpenFolderButton if has_node("FullscreenViewer/OpenFolderButton") else null

# Screenshot data
var screenshots: Array[Dictionary] = []
var current_sort_mode: String = "newest"  # newest, oldest, name, size
var current_filter_mode: String = "all"   # all, favorites
var current_fullscreen_image: String = ""
var current_format: String = "png"        # png or jpg

# Audio manager reference
var audio_manager
var screenshot_manager: Node

func _ready():
	add_to_group("screenshot_gallery")
	
	# Get audio manager
	audio_manager = get_node_or_null("/root/AudioManager")
	
	# Get screenshot manager
	screenshot_manager = get_tree().get_first_node_in_group("screenshot_manager")
	if screenshot_manager:
		screenshot_manager.set_gallery_panel(self)
	
	# Rebuild grid when the available width changes so layout stays responsive
	if scroll_container:
		scroll_container.resized.connect(_on_gallery_resized)
	
	# Connect signals
	_connect_signals()
	
	# Load screenshots
	refresh_gallery()

func _on_format_pressed():
	"""Cycle through screenshot capture formats (PNG/JPEG)"""
	var formats = ["png", "jpg"]
	var idx = formats.find(current_format)
	if idx == -1:
		idx = 0
	current_format = formats[(idx + 1) % formats.size()]
	
	if format_button:
		var label_map = {
			"png": "Format: PNG",
			"jpg": "Format: JPEG",
		}
		format_button.text = label_map.get(current_format, "Format: PNG")
	
	if screenshot_manager and screenshot_manager.has_method("set_screenshot_format"):
		screenshot_manager.set_screenshot_format(current_format)

func _connect_signals():
	"""Connect button signals"""
	if sort_button:
		sort_button.pressed.connect(_on_sort_pressed)
	if filter_button:
		filter_button.pressed.connect(_on_filter_pressed)
	if format_button:
		format_button.pressed.connect(_on_format_pressed)
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	if viewer_close_button:
		viewer_close_button.pressed.connect(_on_viewer_close_pressed)
	if viewer_favorite_button:
		viewer_favorite_button.pressed.connect(_on_viewer_favorite_pressed)
	if viewer_delete_button:
		viewer_delete_button.pressed.connect(_on_viewer_delete_pressed)
	if viewer_open_folder_button:
		viewer_open_folder_button.pressed.connect(_on_viewer_open_folder_pressed)

func refresh_gallery():
	"""Refresh the gallery with current screenshots"""
	if not screenshot_manager:
		return
	
	screenshots = screenshot_manager.get_screenshot_list()
	_apply_sort_and_filter()
	_create_gallery_slots()

func _apply_sort_and_filter():
	"""Apply current sort and filter settings"""
	# Apply filter
	if current_filter_mode == "favorites":
		screenshots = screenshots.filter(func(s): return s.favorite)
	
	# Apply sort
	match current_sort_mode:
		"newest":
			screenshots.sort_custom(func(a, b): return a.modified_time > b.modified_time)
		"oldest":
			screenshots.sort_custom(func(a, b): return a.modified_time < b.modified_time)
		"name":
			screenshots.sort_custom(func(a, b): return a.filename < b.filename)
		"size":
			screenshots.sort_custom(func(a, b): return a.file_size > b.file_size)

func _create_gallery_slots():
	"""Create visual gallery slots"""
	if not grid_container:
		return
	
	# Clear existing slots
	for child in grid_container.get_children():
		child.queue_free()
	
	# Adjust columns based on available width so the grid is responsive
	# Use slightly smaller cells and tighter spacing to fit more columns.
	var available_width := scroll_container.size.x
	var cell_width := 200.0
	var h_spacing := 6
	if available_width > 0.0:
		var columns := int(floor((available_width + h_spacing) / (cell_width + h_spacing)))
		columns = clamp(columns, 1, 8)
		grid_container.columns = columns
		grid_container.add_theme_constant_override("h_separation", h_spacing)
		grid_container.add_theme_constant_override("v_separation", 8)
	
	# If there are no screenshots, show an informative placeholder
	if screenshots.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No screenshots found. Press F12 in-game to capture a screenshot."
		empty_label.add_theme_font_size_override("font_size", 14)
		empty_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		grid_container.add_child(empty_label)
		return
	
	# Create screenshot slots
	for screenshot_data in screenshots:
		var slot = _create_screenshot_slot(screenshot_data)
		grid_container.add_child(slot)

func _on_gallery_resized() -> void:
	"""Handle gallery container resize by rebuilding the grid with new column count."""
	# Reuse current screenshot data; no need to hit disk again.
	if not grid_container:
		return
	if screenshots.is_empty():
		_create_gallery_slots()
	else:
		_create_gallery_slots()

func _create_screenshot_slot(screenshot_data: Dictionary) -> Control:
	"""Create a single screenshot slot"""
	var slot_container := PanelContainer.new()
	slot_container.custom_minimum_size = Vector2(220, 140)
	
	# Style the slot
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.2, 0.8)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.2, 0.8, 1, 0.6)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	slot_container.add_theme_stylebox_override("panel", style)
	
	# Create vertical layout
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	slot_container.add_child(vbox)
	
	# Controls row
	var controls_hbox := HBoxContainer.new()
	controls_hbox.add_theme_constant_override("separation", 2)
	vbox.add_child(controls_hbox)
	
	# Favorite button
	var favorite_btn := Button.new()
	favorite_btn.text = "☆" if not screenshot_data.favorite else "★"
	favorite_btn.tooltip_text = "Toggle Favorite"
	favorite_btn.custom_minimum_size = Vector2(20, 20)
	favorite_btn.pressed.connect(_on_favorite_toggled.bind(screenshot_data.filepath, favorite_btn))
	controls_hbox.add_child(favorite_btn)
	
	# Delete button
	var delete_btn := Button.new()
	delete_btn.text = "🗑️"
	delete_btn.tooltip_text = "Delete Screenshot"
	delete_btn.custom_minimum_size = Vector2(20, 20)
	delete_btn.pressed.connect(_on_delete_pressed.bind(screenshot_data.filepath))
	controls_hbox.add_child(delete_btn)
	
	# Screenshot image
	var image_rect := TextureRect.new()
	image_rect.custom_minimum_size = Vector2(200, 110)
	image_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	
	# Load image
	var image := Image.new()
	if image.load(screenshot_data.filepath) == OK:
		image_rect.texture = ImageTexture.create_from_image(image)
	else:
		# Show placeholder if image fails to load
		image_rect.add_theme_color_override("modulate", Color.RED)
	
	# Click to view fullscreen (event argument from signal, filepath via bind)
	image_rect.gui_input.connect(_on_image_clicked.bind(screenshot_data.filepath))
	vbox.add_child(image_rect)
	
	# Filename label
	var filename_label := Label.new()
	filename_label.text = screenshot_data.filename.substr(0, 20) + "..."
	filename_label.add_theme_font_size_override("font_size", 10)
	filename_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	filename_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(filename_label)
	
	return slot_container

func _on_image_clicked(event: InputEvent, filepath: String):
	"""Handle image click for fullscreen view"""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_open_fullscreen_viewer(filepath)

func _open_fullscreen_viewer(filepath: String):
	"""Open fullscreen image viewer"""
	current_fullscreen_image = filepath
	
	# Load image
	var image := Image.new()
	if image.load(filepath) == OK:
		fullscreen_image.texture = ImageTexture.create_from_image(image)
	
	# Show viewer
	fullscreen_viewer.visible = true
	
	# Update favorite button state
	var screenshot_data = screenshots.filter(func(s): return s.filepath == filepath)
	if screenshot_data.size() > 0:
		viewer_favorite_button.text = "★" if screenshot_data[0].favorite else "☆"

func _on_favorite_toggled(filepath: String, button: Button):
	"""Toggle favorite status"""
	if screenshot_manager:
		var is_favorite = screenshot_manager.toggle_favorite(filepath)
		button.text = "★" if is_favorite else "☆"
		
		# Update screenshot data
		for screenshot in screenshots:
			if screenshot.filepath == filepath:
				screenshot.favorite = is_favorite
				break

func _on_delete_pressed(filepath: String):
	"""Delete screenshot"""
	if screenshot_manager:
		screenshot_manager.delete_screenshot(filepath)
		refresh_gallery()

func _on_viewer_favorite_pressed():
	"""Toggle favorite from fullscreen viewer"""
	if current_fullscreen_image != "":
		_on_favorite_toggled(current_fullscreen_image, viewer_favorite_button)

func _on_viewer_delete_pressed():
	"""Delete screenshot from fullscreen viewer"""
	if current_fullscreen_image != "":
		screenshot_manager.delete_screenshot(current_fullscreen_image)
		_on_viewer_close_pressed()
		refresh_gallery()

func _on_viewer_open_folder_pressed():
	"""Open the folder containing screenshots"""
	if screenshot_manager and screenshot_manager.has_method("open_screenshot_folder"):
		screenshot_manager.open_screenshot_folder()

func _on_viewer_close_pressed():
	"""Close fullscreen viewer"""
	fullscreen_viewer.visible = false
	current_fullscreen_image = ""

func _on_sort_pressed():
	"""Cycle through sort modes"""
	var sort_modes = ["newest", "oldest", "name", "size"]
	var current_index = sort_modes.find(current_sort_mode)
	current_sort_mode = sort_modes[(current_index + 1) % sort_modes.size()]
	
	# Update button text
	var sort_labels = {
		"newest": "Sort: Newest ↓",
		"oldest": "Sort: Oldest ↑", 
		"name": "Sort: Name A-Z",
		"size": "Sort: Size ↓"
	}
	sort_button.text = sort_labels[current_sort_mode]
	
	refresh_gallery()

func _on_filter_pressed():
	"""Cycle through filter modes"""
	var filter_modes = ["all", "favorites"]
	var current_index = filter_modes.find(current_filter_mode)
	current_filter_mode = filter_modes[(current_index + 1) % filter_modes.size()]
	
	# Update button text
	var filter_labels = {
		"all": "Filter: All",
		"favorites": "Filter: ⭐ Favorites"
	}
	filter_button.text = filter_labels[current_filter_mode]
	
	refresh_gallery()

func _on_back_pressed():
	"""Handle back button press"""
	if audio_manager:
		audio_manager.play_button_click()
	
	# Hide gallery panel
	visible = false
	
	# Return to main menu
	var main_menu = get_parent()
	if main_menu and main_menu.has_method("_switch_mode"):
		var start_btn = main_menu.get_node_or_null("CanvasLayer/TopBarContainer/TopBarCenter/TopButtons/StartButton")
		if start_btn:
			main_menu._switch_mode(main_menu.Mode.HOME, start_btn)
