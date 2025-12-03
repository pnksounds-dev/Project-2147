extends Panel

## Floating debug window for pinned sections
## Can be dragged around and allows gameplay to continue

var section_name: String
var section_content: Node
var debug_menu: Node  # Changed from DebugMenu to Node to avoid circular dependency

var title_bar: HBoxContainer
var content_container: ScrollContainer
var is_dragging: bool = false
var drag_offset: Vector2
var is_pinned: bool = true

# Window styling
var window_style: StyleBoxFlat
var title_style: StyleBoxFlat

func _init(window_name: String, section: Node):
	section_name = window_name
	section_content = section
	name = "DebugWindow_" + window_name

func _ready():
	_create_styles()
	_create_window_ui()
	_setup_dragging()
	
	# Start with focus unpinned (allow gameplay)
	allow_gameplay_focus()

func _create_styles():
	"""Create window styling"""
	window_style = StyleBoxFlat.new()
	window_style.bg_color = Color(0.05, 0.05, 0.1, 0.95)
	window_style.border_width_left = 2
	window_style.border_width_right = 2
	window_style.border_width_top = 2
	window_style.border_width_bottom = 2
	window_style.border_color = Color(0.3, 0.5, 0.8, 1.0)
	window_style.corner_radius_top_left = 6
	window_style.corner_radius_top_right = 6
	window_style.corner_radius_bottom_left = 6
	window_style.corner_radius_bottom_right = 6
	
	title_style = StyleBoxFlat.new()
	title_style.bg_color = Color(0.1, 0.2, 0.3, 0.9)
	title_style.border_width_left = 1
	title_style.border_width_right = 1
	title_style.border_width_top = 1
	title_style.border_width_bottom = 1
	title_style.border_color = Color(0.4, 0.6, 0.9, 1.0)
	title_style.corner_radius_top_left = 4
	title_style.corner_radius_top_right = 4

func _create_window_ui():
	"""Create the floating window UI"""
	add_theme_stylebox_override("panel", window_style)
	custom_minimum_size = Vector2(350, 200)
	
	# Title bar
	title_bar = HBoxContainer.new()
	title_bar.add_theme_stylebox_override("panel", title_style)
	title_bar.custom_minimum_size = Vector2(0, 40)
	add_child(title_bar)
	
	# Title
	var title = Label.new()
	title.text = "📌 " + section_name
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color.CYAN)
	title_bar.add_child(title)
	
	title_bar.add_child(Control.new())
	
	# Minimize/Restore button
	var minimize_btn = Button.new()
	minimize_btn.text = "−"
	minimize_btn.custom_minimum_size = Vector2(25, 25)
	minimize_btn.pressed.connect(toggle_minimized)
	title_bar.add_child(minimize_btn)
	
	# Close button
	var close_btn = Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(25, 25)
	close_btn.pressed.connect(close_window)
	title_bar.add_child(close_btn)
	
	# Content container
	content_container = ScrollContainer.new()
	content_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content_container.position.y = 40
	content_container.size.y -= 40
	add_child(content_container)
	
	# Add section content
	if section_content:
		var content = section_content.get_debug_content()
		if content:
			content_container.add_child(content)

func _setup_dragging():
	"""Setup window dragging"""
	title_bar.gui_input.connect(_on_title_bar_input)
	mouse_exited.connect(_on_mouse_exited)

func _on_title_bar_input(event: InputEvent):
	"""Handle title bar input for dragging"""
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			is_dragging = event.pressed
			if event.pressed:
				drag_offset = event.position
				# Bring window to front
				move_to_front()
	elif event is InputEventMouseMotion and is_dragging:
		position += event.relative
		# Keep window within screen bounds
		_constrain_to_screen()

func _on_mouse_exited():
	"""Handle mouse exit"""
	is_dragging = false

func _constrain_to_screen():
	"""Keep window within screen bounds"""
	var screen_size = get_viewport().get_visible_rect().size
	var window_size = size
	
	position.x = clamp(position.x, 0, screen_size.x - window_size.x)
	position.y = clamp(position.y, 0, screen_size.y - window_size.y)

func toggle_minimized():
	"""Toggle window minimized state"""
	content_container.visible = not content_container.visible
	print("DebugWindow: Window '", section_name, "' ", "minimized" if not content_container.visible else "restored")

func close_window():
	"""Close the floating window"""
	debug_menu.toggle_section_pin(section_name)

func allow_gameplay_focus():
	"""Allow gameplay to continue when window is open"""
	# Remove focus from debug elements
	grab_focus()
	
	# Set mouse filter to ignore so gameplay can receive input
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE

func update_content():
	"""Update the window content"""
	if section_content and section_content.has_method("get_debug_content"):
		# Clear old content
		for child in content_container.get_children():
			child.queue_free()
		
		# Add new content
		var content = section_content.get_debug_content()
		if content:
			content_container.add_child(content)

func _input(event):
	"""Handle window-specific input"""
	if not is_pinned:
		return
	
	# Close window with ESC when focused
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE and has_focus():
			close_window()

# --- Window Management ---

func bring_to_front():
	"""Bring this window to the front"""
	if debug_menu:
		# This would need to be implemented in DebugMenu to reorder windows
		move_to_front()

func set_position_centered():
	"""Center the window on screen"""
	var screen_size = get_viewport().get_visible_rect().size
	position = (screen_size - size) / 2

func flash_attention():
	"""Flash the window to draw attention"""
	var tween = create_tween()
	tween.set_loops(3)
	tween.tween_property(self, "modulate:a", 0.5, 0.2)
	tween.tween_property(self, "modulate:a", 1.0, 0.2)
