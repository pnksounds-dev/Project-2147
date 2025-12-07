extends Control

class_name ScreenshotGallery

## ScreenshotGallery - Displays screenshot collection with favorite/sort controls and fullscreen viewer

@onready var scroll_container: ScrollContainer = $ScrollContainer
@onready var grid_container: GridContainer = $ScrollContainer/GridContainer
@onready var fullscreen_viewer: Control = $FullscreenViewer
@onready var fullscreen_image: TextureRect = $FullscreenViewer/FullscreenImage
# Note: Fullscreen viewer buttons removed - using bottom bar controls instead

# Bottom bar controls (MainMenu GalleryBar)
@onready var prev_page_button: Button = get_node_or_null("../BottomBarContainer/GalleryBar/PrevPageButton")
@onready var next_page_button: Button = get_node_or_null("../BottomBarContainer/GalleryBar/NextPageButton")
@onready var page_label: Label = get_node_or_null("../BottomBarContainer/GalleryBar/PageLabel")
@onready var bottom_favorite_button: Button = get_node_or_null("../BottomBarContainer/GalleryBar/GalleryFavoriteButton")
@onready var bottom_delete_button: Button = get_node_or_null("../BottomBarContainer/GalleryBar/GalleryDeleteButton")

# Screenshot data
var screenshots: Array[Dictionary] = []
var current_sort_mode: String = "newest"  # newest, oldest, name, size
var current_filter_mode: String = "all"   # all, favorites
var current_fullscreen_image: String = ""
var current_fullscreen_index: int = 0     # Track current image index for navigation
var current_format: String = "png"        # png or jpg

# Pagination
var IMAGES_PER_PAGE: int = 6
var current_page: int = 0
var total_pages: int = 0

# Thumbnail caching
var thumbnail_cache: Dictionary = {}
var thumbnail_dir: String = ""
var THUMBNAIL_SIZE: Vector2i = Vector2i(200, 110)

# Audio manager reference
var audio_manager
var screenshot_manager: Node

func _ready():
	add_to_group("screenshot_gallery")
	
	# Ensure fullscreen viewer is hidden on startup
	_force_hide_fullscreen_controls()
	
	# Get audio manager
	audio_manager = get_node_or_null("/root/AudioManager")
	
	# Get screenshot manager
	screenshot_manager = get_tree().get_first_node_in_group("screenshot_manager")
	if screenshot_manager:
		screenshot_manager.set_gallery_panel(self)
	
	# Initialize thumbnail directory
	_setup_thumbnail_directory()
	
	# Rebuild grid when the available width changes so layout stays responsive
	if scroll_container:
		scroll_container.resized.connect(_on_gallery_resized)
	
	# Connect signals
	_connect_signals()
	
	# Load screenshots
	refresh_gallery()

func _connect_signals():
	"""Connect button signals"""
	if prev_page_button:
		prev_page_button.pressed.connect(_on_prev_page_pressed)
	if next_page_button:
		next_page_button.pressed.connect(_on_next_page_pressed)
	if bottom_favorite_button:
		bottom_favorite_button.pressed.connect(_on_viewer_favorite_pressed)
	if bottom_delete_button:
		bottom_delete_button.pressed.connect(_on_viewer_delete_pressed)
	
	# Add input handling for ESC key
	set_process_input(true)

func refresh_gallery():
	"""Refresh the gallery with current screenshots"""
	if not screenshot_manager:
		return
	
	# Ensure fullscreen viewer is hidden when refreshing gallery
	_force_hide_fullscreen_controls()
	
	screenshots = screenshot_manager.get_screenshot_list()
	_apply_sort_and_filter()
	current_page = 0  # Reset to first page
	_update_pagination()
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
	"""Create visual gallery slots for current page"""
	if not grid_container:
		return
	
	# Clear existing slots
	for child in grid_container.get_children():
		child.queue_free()
	
	# Adjust columns based on available width so the grid is responsive
	# Ensure thumbnails fit properly within the available space and are centered
	var available_width := scroll_container.size.x
	var _available_height := scroll_container.size.y  # Unused but reserved for future vertical layout calculations
	var cell_width := 200.0
	var h_spacing := 15
	var v_spacing := 15
	
	if available_width > 0.0:
		# Calculate optimal columns for 6 images per page (2x3 grid preferred)
		var max_columns := int(floor((available_width + h_spacing) / (cell_width + h_spacing)))
		var columns: int = clamp(max_columns, 1, 3)  # Limit to 3 columns for better layout
		
		# Adjust cell width to maximize space usage
		if columns > 0:
			cell_width = (available_width - (h_spacing * (columns - 1))) / columns
			cell_width = min(cell_width, 280.0)  # Cap at reasonable max size
		
		grid_container.columns = columns
		grid_container.add_theme_constant_override("h_separation", h_spacing)
		grid_container.add_theme_constant_override("v_separation", v_spacing)
		
		# Center the grid container in the available space
		grid_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	# If there are no screenshots, show an informative placeholder
	if screenshots.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No screenshots found. Press F12 in-game to capture a screenshot."
		empty_label.add_theme_font_size_override("font_size", 14)
		empty_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		empty_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		grid_container.add_child(empty_label)
		return
	
	# Calculate page boundaries
	var start_index = current_page * IMAGES_PER_PAGE
	var end_index = min(start_index + IMAGES_PER_PAGE, screenshots.size())
	
	# Create screenshot slots for current page
	for i in range(start_index, end_index):
		var screenshot_data = screenshots[i]
		var slot = _create_screenshot_slot(screenshot_data, cell_width)
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

func _force_hide_fullscreen_controls():
	"""Force hide fullscreen viewer"""
	if fullscreen_viewer:
		fullscreen_viewer.visible = false

func _input(event: InputEvent):
	"""Handle input events for fullscreen viewer"""
	if event is InputEventKey and event.pressed:
		# ESC key closes fullscreen viewer
		if event.keycode == KEY_ESCAPE and fullscreen_viewer and fullscreen_viewer.visible:
			_close_fullscreen_viewer()
			get_viewport().set_input_as_handled()
		# Arrow keys navigate in fullscreen
		elif fullscreen_viewer and fullscreen_viewer.visible:
			if event.keycode == KEY_LEFT:
				_navigate_fullscreen(-1)
				get_viewport().set_input_as_handled()
			elif event.keycode == KEY_RIGHT:
				_navigate_fullscreen(1)
				get_viewport().set_input_as_handled()

func _create_screenshot_slot(screenshot_data: Dictionary, cell_width: float) -> Control:
	"""Create a simplified screenshot slot with just image and filename"""
	var slot_container := PanelContainer.new()
	# Use the calculated dynamic cell width and make slots expand
	var slot_height := cell_width * 0.7  # Maintain aspect ratio
	slot_container.custom_minimum_size = Vector2(cell_width, slot_height)
	slot_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
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
	
	# Create vertical layout with just image and filename
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	slot_container.add_child(vbox)
	
	# Screenshot image with proper dynamic sizing that expands
	var image_rect := TextureRect.new()
	var image_height := cell_width * 0.6  # Leave space for filename
	image_rect.custom_minimum_size = Vector2(cell_width - 20, image_height)
	image_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	image_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	image_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	
	# Load thumbnail
	var thumbnail_texture = _get_or_create_thumbnail(screenshot_data.filepath)
	if thumbnail_texture:
		image_rect.texture = thumbnail_texture
	else:
		# Show placeholder if thumbnail fails to load
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
	filename_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	filename_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(filename_label)
	
	return slot_container

func _on_image_clicked(event: InputEvent, filepath: String):
	"""Handle image click for fullscreen view"""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_open_fullscreen_viewer(filepath)

func _open_fullscreen_viewer(filepath: String):
	"""Open fullscreen image viewer"""
	current_fullscreen_image = filepath
	
	# Find the current image index for navigation
	current_fullscreen_index = -1
	for i in range(screenshots.size()):
		if screenshots[i].filepath == filepath:
			current_fullscreen_index = i
			break
	
	# Load thumbnail for fullscreen viewer (still use full image here)
	var image := Image.new()
	if image.load(filepath) == OK:
		fullscreen_image.texture = ImageTexture.create_from_image(image)
	
	# Show viewer
	fullscreen_viewer.visible = true
	
	# Update navigation button states
	_update_navigation_buttons()
	
	# Update favorite button state
	var screenshot_data = screenshots.filter(func(s): return s.filepath == filepath)
	if screenshot_data.size() > 0 and bottom_favorite_button:
		bottom_favorite_button.text = "★ Favorite" if screenshot_data[0].favorite else "☆ Favorite"

func _on_prev_page_pressed():
	"""Handle previous page/image navigation"""
	if fullscreen_viewer and fullscreen_viewer.visible:
		_navigate_fullscreen(-1)
	else:
		# Normal page navigation
		if current_page > 0:
			current_page -= 1
			_update_pagination()
			_create_gallery_slots()

func _on_next_page_pressed():
	"""Handle next page/image navigation"""
	if fullscreen_viewer and fullscreen_viewer.visible:
		_navigate_fullscreen(1)
	else:
		# Normal page navigation
		if current_page < total_pages - 1:
			current_page += 1
			_update_pagination()
			_create_gallery_slots()

func _navigate_fullscreen(direction: int):
	"""Navigate to previous/next image in fullscreen"""
	if current_fullscreen_index == -1 or screenshots.is_empty():
		return
	
	var new_index = current_fullscreen_index + direction
	if new_index >= 0 and new_index < screenshots.size():
		current_fullscreen_index = new_index
		var screenshot_data = screenshots[current_fullscreen_index]
		_open_fullscreen_viewer(screenshot_data.filepath)

func _close_fullscreen_viewer():
	"""Close fullscreen viewer and restore normal UI"""
	fullscreen_viewer.visible = false
	current_fullscreen_image = ""
	# Restore page label to show page info
	_update_pagination()

func _update_navigation_buttons():
	"""Update the enabled/disabled state of navigation buttons"""
	if prev_page_button:
		if fullscreen_viewer and fullscreen_viewer.visible:
			# In fullscreen mode, disable navigation at boundaries
			prev_page_button.disabled = current_fullscreen_index <= 0
		else:
			# In page mode, disable at first page
			prev_page_button.disabled = current_page <= 0
	if next_page_button:
		if fullscreen_viewer and fullscreen_viewer.visible:
			# In fullscreen mode, disable navigation at boundaries
			next_page_button.disabled = current_fullscreen_index >= screenshots.size() - 1
		else:
			# In page mode, disable at last page
			next_page_button.disabled = current_page >= total_pages - 1

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
	if current_fullscreen_image != "" and bottom_favorite_button:
		_on_favorite_toggled(current_fullscreen_image, bottom_favorite_button)

func _on_viewer_delete_pressed():
	"""Delete screenshot from fullscreen viewer"""
	if current_fullscreen_image != "":
		screenshot_manager.delete_screenshot(current_fullscreen_image)
		_close_fullscreen_viewer()
		refresh_gallery()

func _setup_thumbnail_directory():
	"""Setup thumbnail directory for caching"""
	if screenshot_manager and screenshot_manager.has_method("get_screenshot_directory"):
		var screenshot_dir = screenshot_manager.get_screenshot_directory()
		# Store thumbnails in a dedicated subfolder under PlayerData/Screenshots
		thumbnail_dir = screenshot_dir.path_join("thumbnails")
		
		# Create thumbnail directory if it doesn't exist
		if not DirAccess.dir_exists_absolute(thumbnail_dir):
			DirAccess.make_dir_recursive_absolute(thumbnail_dir)

func _get_or_create_thumbnail(filepath: String) -> ImageTexture:
	"""Get cached thumbnail or create it if needed"""
	# Check cache first
	if thumbnail_cache.has(filepath):
		return thumbnail_cache[filepath]
	
	# Generate thumbnail path
	var file_name = filepath.get_file().get_basename() + "_thumb.jpg"
	var thumb_path = thumbnail_dir.path_join(file_name)
	
	# Check if thumbnail exists on disk
	if FileAccess.file_exists(thumb_path):
		var thumb_image = Image.new()
		if thumb_image.load(thumb_path) == OK:
			var texture = ImageTexture.create_from_image(thumb_image)
			thumbnail_cache[filepath] = texture
			return texture
	
	# Create thumbnail if it doesn't exist
	return _create_thumbnail(filepath, thumb_path)

func _create_thumbnail(filepath: String, thumb_path: String) -> ImageTexture:
	"""Create and save thumbnail for an image"""
	var source_image = Image.new()
	if source_image.load(filepath) != OK:
		return null
	
	# Resize image to thumbnail size
	source_image.resize(THUMBNAIL_SIZE.x, THUMBNAIL_SIZE.y, Image.INTERPOLATE_LANCZOS)
	
	# Save thumbnail as JPG for smaller file size
	source_image.save_jpg(thumb_path, 0.85)  # 85% quality
	
	# Create texture and cache it
	var texture = ImageTexture.create_from_image(source_image)
	thumbnail_cache[filepath] = texture
	
	return texture

func _update_pagination():
	"""Update pagination state and UI"""
	total_pages = ceil(float(screenshots.size()) / IMAGES_PER_PAGE)
	current_page = clamp(current_page, 0, max(0, total_pages - 1))
	
	# Update pagination UI
	if prev_page_button:
		prev_page_button.disabled = current_page <= 0
	if next_page_button:
		next_page_button.disabled = current_page >= total_pages - 1
	if page_label:
		if fullscreen_viewer and fullscreen_viewer.visible:
			# Show image position in fullscreen mode
			if current_fullscreen_index >= 0 and screenshots.size() > 0:
				page_label.text = "Image %d/%d" % [current_fullscreen_index + 1, screenshots.size()]
		else:
			# Show page info in normal mode
			if total_pages > 0:
				page_label.text = "Page %d/%d" % [current_page + 1, total_pages]
			else:
				page_label.text = "No images"
