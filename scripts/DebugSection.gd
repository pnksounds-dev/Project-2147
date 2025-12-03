extends Node

## Base class for debug menu sections
## Each section provides specific testing capabilities for game systems

var debug_menu: Node  # Changed from DebugMenu to Node to avoid circular dependency
var section_name: String
var test_actions: Dictionary = {}  # action_name -> Callable
var debug_data: Dictionary = {}

func _init(init_section_name: String = ""):
	section_name = init_section_name

# --- Virtual Methods to Override ---

func get_debug_content() -> Control:
	"""Override this to return the debug UI content for this section"""
	return null

func update_data(new_data: Dictionary):
	"""Update section data - override to handle specific updates"""
	debug_data.merge(new_data)

func add_test_action(action_name: String, callback: Callable):
	"""Add a test action to this section"""
	test_actions[action_name] = callback

func execute_action(action_name: String, params: Dictionary = {}):
	"""Execute a test action"""
	if test_actions.has(action_name):
		var callback = test_actions[action_name]
		if callback.is_valid():
			callback.call(params)
		else:
			print("DebugSection: Invalid callback for action: ", action_name)
	else:
		print("DebugSection: Unknown action: ", action_name)

func log_message(message: String, level: String = "INFO"):
	"""Log a message to this section's output"""
	print("[", section_name, "] ", level, ": ", message)

# --- Helper UI Creation Methods ---

func create_button(text: String, callback: Callable, tooltip: String = "", compact: bool = true) -> Button:
	"""Create a styled debug button"""
	var btn = Button.new()
	btn.text = text
	# Compact buttons that don't expand
	if compact:
		btn.custom_minimum_size = Vector2(0, 24)
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	else:
		btn.custom_minimum_size = Vector2(100, 26)
	btn.add_theme_font_size_override("font_size", 11)
	btn.pressed.connect(callback)
	
	if tooltip != "":
		btn.tooltip_text = tooltip
	
	# Style the button
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.3, 0.4, 0.9)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.5, 0.6, 0.7, 1.0)
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	
	btn.add_theme_stylebox_override("normal", style)
	return btn

func create_label(text: String, color: Color = Color.WHITE) -> Label:
	"""Create a styled debug label"""
	var label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 11)
	return label

func create_input_field(placeholder: String, default_value: String = "") -> LineEdit:
	"""Create a styled input field"""
	var input = LineEdit.new()
	input.placeholder_text = placeholder
	input.text = default_value
	input.custom_minimum_size = Vector2(200, 25)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.8)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.4, 0.4, 0.5, 1.0)
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	
	input.add_theme_stylebox_override("normal", style)
	return input

func create_slider(min_val: float, max_val: float, default_val: float, step: float = 1.0) -> HSlider:
	"""Create a styled slider"""
	var slider = HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.value = default_val
	slider.step = step
	slider.custom_minimum_size = Vector2(150, 20)
	return slider

func create_checkbox(text: String, default_checked: bool = false) -> CheckBox:
	"""Create a styled checkbox"""
	var checkbox = CheckBox.new()
	checkbox.text = text
	checkbox.button_pressed = default_checked
	return checkbox

func create_container(vertical: bool = true, spacing: int = 4) -> Container:
	"""Create a container for organizing UI elements"""
	var container: Container
	if vertical:
		container = VBoxContainer.new()
	else:
		container = HBoxContainer.new()
		container.alignment = BoxContainer.ALIGNMENT_BEGIN
	
	container.add_theme_constant_override("separation", spacing)
	return container

func create_button_row(buttons: Array[Dictionary]) -> HBoxContainer:
	"""Create a row of compact buttons. Each dict has 'text' and 'callback' keys."""
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	
	for btn_data in buttons:
		var btn = create_button(btn_data.get("text", "?"), btn_data.get("callback", func(): pass), btn_data.get("tooltip", ""))
		row.add_child(btn)
	
	return row

func create_section(title: String) -> VBoxContainer:
	"""Create a section with title"""
	var container = VBoxContainer.new()
	container.add_theme_constant_override("separation", 2)
	
	var title_label = create_label(title, Color(0.6, 0.9, 1.0))
	title_label.add_theme_font_size_override("font_size", 11)
	container.add_child(title_label)
	
	return container

func create_info_grid(data: Dictionary) -> GridContainer:
	"""Create an information grid from key-value pairs"""
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 3)
	
	for key in data:
		var key_label = create_label(str(key) + ":", Color.GRAY)
		var value_label = create_label(str(data[key]), Color.WHITE)
		
		grid.add_child(key_label)
		grid.add_child(value_label)
	
	return grid
