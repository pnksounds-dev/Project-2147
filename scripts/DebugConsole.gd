extends CanvasLayer

# Floating Debug Console
# Replaces Godot's output console to prevent overflow errors

@onready var _output_label: RichTextLabel
@onready var _background_panel: PanelContainer
@onready var _title_bar: HBoxContainer
@onready var _close_button: Button
@onready var _clear_button: Button
@onready var _scroll_container: ScrollContainer

var _is_visible: bool = false
var _max_lines: int = 1000
var _auto_scroll: bool = true
var _original_print: Callable
var _buffered_messages: Array = []

# Console styling
var console_style = {
	"width": 600,
	"height": 400,
	"font_size": 12,
	"bg_color": Color(0.1, 0.1, 0.1, 0.95),
	"border_color": Color(0.2, 0.6, 1.0, 0.8),
	"text_color": Color(0.9, 0.9, 0.9, 1.0),
	"error_color": Color(1.0, 0.3, 0.3, 1.0),
	"warning_color": Color(1.0, 0.8, 0.3, 1.0)
}

func _ready() -> void:
	add_to_group("debug_console")
	layer = 120  # High layer to stay on top
	_create_console_ui()
	_connect_signals()
	_redirect_print_output()
	hide_console()

func _create_console_ui() -> void:
	# Main container
	var main_container = Control.new()
	main_container.name = "ConsoleContainer"
	main_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(main_container)

	# Background panel
	_background_panel = PanelContainer.new()
	_background_panel.name = "BackgroundPanel"
	_background_panel.custom_minimum_size = Vector2(console_style.width, console_style.height)
	_background_panel.anchor_left = 0.5
	_background_panel.anchor_right = 0.5
	_background_panel.anchor_top = 0.5
	_background_panel.anchor_bottom = 0.5
	_background_panel.offset_left = -console_style.width / 2.0
	_background_panel.offset_right = console_style.width / 2.0
	_background_panel.offset_top = -console_style.height / 2.0
	_background_panel.offset_bottom = console_style.height / 2.0

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = console_style.bg_color
	panel_style.border_color = console_style.border_color
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	_background_panel.add_theme_stylebox_override("panel", panel_style)

	main_container.add_child(_background_panel)

	# Main vertical layout
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 4)
	_background_panel.add_child(main_vbox)

	# Title bar
	_title_bar = HBoxContainer.new()
	_title_bar.add_theme_constant_override("separation", 8)
	main_vbox.add_child(_title_bar)

	var title_label = Label.new()
	title_label.text = "Debug Console"
	title_label.add_theme_font_size_override("font_size", console_style.font_size + 2)
	title_label.add_theme_color_override("font_color", console_style.text_color)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_bar.add_child(title_label)

	_clear_button = Button.new()
	_clear_button.text = "Clear"
	_clear_button.custom_minimum_size = Vector2(60, 24)
	_clear_button.pressed.connect(_clear_console)
	_title_bar.add_child(_clear_button)

	_close_button = Button.new()
	_close_button.text = "✕"
	_close_button.custom_minimum_size = Vector2(32, 24)
	_close_button.pressed.connect(hide_console)
	_title_bar.add_child(_close_button)

	# Scroll container for output
	_scroll_container = ScrollContainer.new()
	_scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_vbox.add_child(_scroll_container)

	# Output text
	_output_label = RichTextLabel.new()
	_output_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_output_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_output_label.add_theme_font_size_override("font_size", console_style.font_size)
	_output_label.add_theme_color_override("default_color", console_style.text_color)
	_output_label.fit_content = true
	_output_label.scroll_active = false
	_output_label.bbcode_enabled = true
	_scroll_container.add_child(_output_label)

	# Process buffered messages
	_process_buffered_messages()

func _connect_signals() -> void:
	# Make console draggable
	var drag_component = _create_drag_component()
	_title_bar.add_child(drag_component)

func _create_drag_component() -> Control:
	var drag_area = Control.new()
	drag_area.name = "DragArea"
	drag_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	drag_area.gui_input.connect(_handle_title_bar_input)
	return drag_area

var _dragging_console: bool = false
var _drag_offset: Vector2 = Vector2.ZERO

func _handle_title_bar_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_dragging_console = event.pressed
			if _dragging_console:
				_drag_offset = _background_panel.global_position - event.global_position
			else:
				_drag_offset = Vector2.ZERO
	elif event is InputEventMouseMotion and _dragging_console:
		_background_panel.global_position = event.global_position + _drag_offset

func _redirect_print_output() -> void:
	# Store original print function
	_original_print = print
	
	# For now, provide a static method for manual logging
	print("Debug console initialized - use DebugConsole.log() for output")

func add_message(message: String, type: String = "info") -> void:
	var timestamp = Time.get_datetime_string_from_system(false, true)
	var colored_message = ""

	match type:
		"error":
			colored_message = "[color=#%s][%s] %s[/color]" % [
				console_style.error_color.to_html(false),
				timestamp,
				message
			]
		"warning":
			colored_message = "[color=#%s][%s] %s[/color]" % [
				console_style.warning_color.to_html(false),
				timestamp,
				message
			]
		_:
			colored_message = "[color=#%s][%s] %s[/color]" % [
				console_style.text_color.to_html(false),
				timestamp,
				message
			]

	# Add to buffered messages if console not ready yet
	if not _output_label:
		_buffered_messages.append(colored_message)
		return

	_output_label.append_text(colored_message + "\n")

	# Maintain max lines
	var lines = _output_label.get_parsed_text().split("\n")
	var line_count = lines.size()
	if line_count > _max_lines:
		var excess = line_count - _max_lines
		var new_text = ""
		for i in range(excess, line_count):
			new_text += lines[i] + "\n"
		_output_label.text = new_text

	# Auto-scroll to bottom
	if _auto_scroll and _scroll_container:
		await get_tree().process_frame
		var scroll_bar := _scroll_container.get_v_scroll_bar()
		if scroll_bar:
			_scroll_container.scroll_vertical = int(round(scroll_bar.max_value))

func _process_buffered_messages() -> void:
	if not _output_label:
		return

	for message in _buffered_messages:
		_output_label.append_text(message + "\n")
	_buffered_messages.clear()

func _clear_console() -> void:
	if _output_label:
		_output_label.text = ""
	add_message("Console cleared", "info")

func show_console() -> void:
	if _background_panel:
		_background_panel.visible = true
	_is_visible = true
	add_message("Debug console shown", "info")

func hide_console() -> void:
	if _background_panel:
		_background_panel.visible = false
	_is_visible = false
	add_message("Debug console hidden", "info")

func toggle_console() -> void:
	if _is_visible:
		hide_console()
	else:
		show_console()

func set_max_lines(lines: int) -> void:
	_max_lines = lines

func set_auto_scroll(enabled: bool) -> void:
	_auto_scroll = enabled

# Static method to add messages from anywhere
static func log(message: String, type: String = "info") -> void:
	var console = Engine.get_main_loop().root.get_tree().get_first_node_in_group("debug_console")
	if console:
		console.add_message(message, type)
	else:
		match type:
			"error": push_error(message)
			"warning": push_warning(message)
			_: print(message)
