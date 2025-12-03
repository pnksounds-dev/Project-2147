extends CanvasLayer
class_name DebugMenu

## Professional Debug Menu System - Fullscreen Grid Layout
## Overhauled for professional appearance with fullscreen grid-based sections

signal section_pinned(section_name: String, pinned: bool)

@export var debug_enabled: bool = true
@export var hotkey_toggle: Key = KEY_F1

# === NEW PROFESSIONAL UI ELEMENTS ===
var main_panel: Panel
var header_bar: PanelContainer
var grid_container: GridContainer
var footer_bar: HBoxContainer

# === OLD UI ELEMENTS (DISABLED) ===
# var main_container: VBoxContainer  # DISABLED: Replaced by fullscreen grid layout
# var title_bar: HBoxContainer  # DISABLED: Replaced by professional header
# var content_area: ScrollContainer  # DISABLED: Replaced by grid container
# var sections_container: VBoxContainer  # DISABLED: Replaced by grid layout

# Floating windows system
var floating_windows: Dictionary = {}  # section_name -> DebugWindow
# var window_base: PackedScene  # DISABLED: Not used in new design

# Debug sections registry
var debug_sections: Dictionary = {}  # section_name -> DebugSection
var section_order: Array[String] = []

# UI State
var debug_visible: bool = false  # NEW: Simpler visibility tracking (renamed from is_visible to avoid shadowing)
# var is_main_menu_visible: bool = false  # DISABLED: Replaced by is_visible
# var is_dragging: bool = false  # DISABLED: No longer draggable
# var drag_offset: Vector2  # DISABLED: No longer draggable

# === NEW PROFESSIONAL STYLING ===
var style_main: StyleBoxFlat
var style_header: StyleBoxFlat
var style_section: StyleBoxFlat
var style_section_header: StyleBoxFlat
var style_button: StyleBoxFlat
var style_button_hover: StyleBoxFlat

# === OLD STYLING (DISABLED) ===
# var main_style: StyleBoxFlat  # DISABLED: Replaced by style_main
# var section_style: StyleBoxFlat  # DISABLED: Replaced by style_section
# var button_style: StyleBoxFlat  # DISABLED: Replaced by style_button
# var pinned_style: StyleBoxFlat  # DISABLED: Replaced by new button styles

func _ready():
	name = "DebugMenu"
	add_to_group("debug_menu")
	layer = 100  # Ensure it's on top
	
	# Create UI
	_create_styles()
	_create_main_ui()
	_register_default_sections()
	
	set_process_input(true)
	print("DebugMenu: Professional debug system initialized (F1 to toggle)")

func _input(event):
	if not debug_enabled:
		return
	
	if event is InputEventKey and event.pressed:
		if event.keycode == hotkey_toggle:
			toggle_menu()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE and debug_visible:
			toggle_menu()
			get_viewport().set_input_as_handled()

func _create_styles():
	# === OLD STYLING (DISABLED) ===
	# DISABLED: Replaced with professional fullscreen styling
	# main_style = StyleBoxFlat.new()
	# main_style.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	# ... rest of old styles disabled
	
	# === NEW PROFESSIONAL STYLING ===
	# Main background - dark with slight transparency
	style_main = StyleBoxFlat.new()
	style_main.bg_color = Color(0.08, 0.09, 0.12, 0.98)
	
	# Header bar
	style_header = StyleBoxFlat.new()
	style_header.bg_color = Color(0.12, 0.14, 0.18, 1.0)
	style_header.border_width_bottom = 2
	style_header.border_color = Color(0.2, 0.6, 0.9, 0.8)
	style_header.content_margin_left = 20
	style_header.content_margin_right = 20
	style_header.content_margin_top = 8
	style_header.content_margin_bottom = 8
	
	# Section panels
	style_section = StyleBoxFlat.new()
	style_section.bg_color = Color(0.1, 0.12, 0.16, 0.95)
	style_section.border_width_left = 1
	style_section.border_width_right = 1
	style_section.border_width_top = 1
	style_section.border_width_bottom = 1
	style_section.border_color = Color(0.25, 0.3, 0.4, 0.8)
	style_section.corner_radius_top_left = 6
	style_section.corner_radius_top_right = 6
	style_section.corner_radius_bottom_left = 6
	style_section.corner_radius_bottom_right = 6
	style_section.content_margin_left = 12
	style_section.content_margin_right = 12
	style_section.content_margin_top = 8
	style_section.content_margin_bottom = 12
	
	# Section header
	style_section_header = StyleBoxFlat.new()
	style_section_header.bg_color = Color(0.15, 0.18, 0.24, 1.0)
	style_section_header.border_width_bottom = 1
	style_section_header.border_color = Color(0.2, 0.5, 0.8, 0.6)
	style_section_header.corner_radius_top_left = 6
	style_section_header.corner_radius_top_right = 6
	style_section_header.content_margin_left = 10
	style_section_header.content_margin_right = 10
	style_section_header.content_margin_top = 6
	style_section_header.content_margin_bottom = 6
	
	# Buttons
	style_button = StyleBoxFlat.new()
	style_button.bg_color = Color(0.18, 0.22, 0.28, 0.9)
	style_button.border_width_left = 1
	style_button.border_width_right = 1
	style_button.border_width_top = 1
	style_button.border_width_bottom = 1
	style_button.border_color = Color(0.3, 0.4, 0.5, 0.8)
	style_button.corner_radius_top_left = 4
	style_button.corner_radius_top_right = 4
	style_button.corner_radius_bottom_left = 4
	style_button.corner_radius_bottom_right = 4
	
	style_button_hover = StyleBoxFlat.new()
	style_button_hover.bg_color = Color(0.2, 0.35, 0.5, 0.9)
	style_button_hover.border_width_left = 1
	style_button_hover.border_width_right = 1
	style_button_hover.border_width_top = 1
	style_button_hover.border_width_bottom = 1
	style_button_hover.border_color = Color(0.3, 0.6, 0.9, 1.0)
	style_button_hover.corner_radius_top_left = 4
	style_button_hover.corner_radius_top_right = 4
	style_button_hover.corner_radius_bottom_left = 4
	style_button_hover.corner_radius_bottom_right = 4

func _create_main_ui():
	# === OLD UI CREATION (DISABLED) ===
	# DISABLED: Replaced with professional fullscreen grid layout
	# main_panel = Panel.new()
	# main_panel.custom_minimum_size = Vector2(320, 450)
	# ... rest of old UI disabled
	
	# === NEW PROFESSIONAL FULLSCREEN UI ===
	# Main fullscreen panel
	main_panel = Panel.new()
	main_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_panel.add_theme_stylebox_override("panel", style_main)
	add_child(main_panel)
	
	# Main vertical layout
	var main_vbox = VBoxContainer.new()
	main_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 0)
	main_panel.add_child(main_vbox)
	
	# === HEADER BAR ===
	header_bar = PanelContainer.new()
	header_bar.add_theme_stylebox_override("panel", style_header)
	main_vbox.add_child(header_bar)
	
	var header_content = HBoxContainer.new()
	header_content.add_theme_constant_override("separation", 20)
	header_bar.add_child(header_content)
	
	# Title
	var title = Label.new()
	title.text = "DEBUG CONSOLE"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.3, 0.7, 1.0))
	header_content.add_child(title)
	
	# Spacer
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_content.add_child(spacer)
	
	# FPS display
	var fps_label = Label.new()
	fps_label.name = "FPSLabel"
	fps_label.text = "FPS: --"
	fps_label.add_theme_font_size_override("font_size", 14)
	fps_label.add_theme_color_override("font_color", Color(0.6, 0.8, 0.6))
	header_content.add_child(fps_label)
	
	# Memory display
	var mem_label = Label.new()
	mem_label.name = "MemLabel"
	mem_label.text = "MEM: -- MB"
	mem_label.add_theme_font_size_override("font_size", 14)
	mem_label.add_theme_color_override("font_color", Color(0.8, 0.7, 0.5))
	header_content.add_child(mem_label)
	
	# Hotkey hint
	var hint = Label.new()
	hint.text = "[F1] Toggle  [ESC] Close"
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	header_content.add_child(hint)
	
	# Close button
	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(32, 32)
	close_btn.add_theme_font_size_override("font_size", 16)
	close_btn.add_theme_stylebox_override("normal", style_button)
	close_btn.add_theme_stylebox_override("hover", style_button_hover)
	close_btn.pressed.connect(toggle_menu)
	header_content.add_child(close_btn)
	
	# === CONTENT AREA ===
	var content_margin = MarginContainer.new()
	content_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_margin.add_theme_constant_override("margin_left", 20)
	content_margin.add_theme_constant_override("margin_right", 20)
	content_margin.add_theme_constant_override("margin_top", 15)
	content_margin.add_theme_constant_override("margin_bottom", 15)
	main_vbox.add_child(content_margin)
	
	var scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_margin.add_child(scroll)
	
	# Grid for sections (3 columns)
	grid_container = GridContainer.new()
	grid_container.columns = 3
	grid_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_container.add_theme_constant_override("h_separation", 15)
	grid_container.add_theme_constant_override("v_separation", 15)
	scroll.add_child(grid_container)
	
	# === FOOTER BAR ===
	var footer_panel = PanelContainer.new()
	var footer_style = style_header.duplicate()
	footer_style.border_width_bottom = 0
	footer_style.border_width_top = 1
	footer_panel.add_theme_stylebox_override("panel", footer_style)
	main_vbox.add_child(footer_panel)
	
	footer_bar = HBoxContainer.new()
	footer_bar.add_theme_constant_override("separation", 15)
	footer_panel.add_child(footer_bar)
	
	# Quick actions in footer
	var actions_label = Label.new()
	actions_label.text = "Quick Actions:"
	actions_label.add_theme_font_size_override("font_size", 12)
	actions_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	footer_bar.add_child(actions_label)
	
	_add_footer_button("Reload Scene", func(): _reload_scene())
	_add_footer_button("Clear Console", func(): print("\n".repeat(50)))
	_add_footer_button("Toggle Godmode", func(): _toggle_godmode())
	_add_footer_button("Add 1000 Coins", func(): _add_coins(1000))
	_add_footer_button("Kill All Enemies", func(): _kill_all_enemies())
	
	# Version info on right
	var footer_spacer = Control.new()
	footer_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer_bar.add_child(footer_spacer)
	
	var version = Label.new()
	version.text = "Debug v1.0 | Godot " + Engine.get_version_info().string
	version.add_theme_font_size_override("font_size", 11)
	version.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
	footer_bar.add_child(version)
	
	# Start hidden
	main_panel.visible = false
	
	# Update timer for FPS/memory
	var timer = Timer.new()
	timer.wait_time = 0.5
	timer.autostart = true
	timer.timeout.connect(_update_stats)
	add_child(timer)

# === OLD DRAGGABLE FUNCTION (DISABLED) ===
# DISABLED: No longer draggable in fullscreen design
# func _setup_draggable(control: Control):
# 	"""Make a control draggable"""
# 	control.gui_input.connect(func(event):
# 		if event is InputEventMouseButton:
# 			if event.button_index == MOUSE_BUTTON_LEFT:
# 				is_dragging = event.pressed
# 				drag_offset = event.position - main_panel.position
# 		elif event is InputEventMouseMotion and is_dragging:
# 			main_panel.position = event.global_position - drag_offset

func _add_footer_button(text: String, callback: Callable):
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 28)
	btn.add_theme_font_size_override("font_size", 11)
	btn.add_theme_stylebox_override("normal", style_button)
	btn.add_theme_stylebox_override("hover", style_button_hover)
	btn.pressed.connect(callback)
	footer_bar.add_child(btn)

func _update_stats():
	if not debug_visible:
		return
	var fps_label = main_panel.get_node_or_null("VBoxContainer/PanelContainer/HBoxContainer/FPSLabel")
	var mem_label = main_panel.get_node_or_null("VBoxContainer/PanelContainer/HBoxContainer/MemLabel")
	if fps_label:
		fps_label.text = "FPS: %d" % Engine.get_frames_per_second()
	if mem_label:
		mem_label.text = "MEM: %.1f MB" % (OS.get_static_memory_usage() / 1024.0 / 1024.0)

func _register_default_sections():
	"""Register default debug sections"""
	register_section("Weapons", preload("res://scripts/debug/DebugWeaponsSection.gd").new())
	register_section("Performance", preload("res://scripts/debug/DebugPerformanceSection.gd").new())
	register_section("Inventory", preload("res://scripts/debug/DebugInventorySection.gd").new())
	register_section("Player", preload("res://scripts/debug/DebugPlayerSection.gd").new())
	register_section("Audio", preload("res://scripts/debug/DebugAudioSection.gd").new())
	register_section("Systems", preload("res://scripts/debug/DebugSystemsSection.gd").new())
	
	refresh_sections()

func register_section(section_name: String, section: Node):
	"""Register a debug section"""
	if debug_sections.has(section_name):
		print("DebugMenu: Section '", section_name, "' already exists, replacing")
	
	debug_sections[section_name] = section
	section.name = section_name
	section.debug_menu = self
	
	if not section_order.has(section_name):
		section_order.append(section_name)
	
	print("DebugMenu: Registered section '", section_name, "'")

func refresh_sections():
	"""Refresh all debug sections in the main menu"""
	# === OLD REFRESH (DISABLED) ===
	# DISABLED: sections_container no longer exists in new design
	# for child in sections_container.get_children():
	# 	child.queue_free()
	# 
	# # Add sections in order
	# for section_name in section_order:
	# 	if debug_sections.has(section_name):
	# 		var section = debug_sections[section_name]
	# 		var section_ui = _create_section_ui(section_name, section)
	# 		sections_container.add_child(section_ui)
	
	# === NEW GRID REFRESH ===
	# Clear existing sections from grid
	for child in grid_container.get_children():
		child.queue_free()
	
	# Add sections to grid
	for section_name in section_order:
		if debug_sections.has(section_name):
			var section = debug_sections[section_name]
			var section_panel = _create_section_panel(section_name, section)
			grid_container.add_child(section_panel)

# === OLD SECTION UI CREATION (DISABLED) ===
# DISABLED: Replaced with professional grid section panels
# func _create_section_ui(section_name: String, section: Node) -> Control:
# 	"""Create UI for a debug section"""
# 	var panel = PanelContainer.new()
# 	panel.add_theme_stylebox_override("panel", section_style)
# 	... rest disabled

func _create_section_panel(section_name: String, section: Node) -> Control:
	var panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", style_section)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(350, 200)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)
	
	# Section header
	var header = PanelContainer.new()
	header.add_theme_stylebox_override("panel", style_section_header)
	vbox.add_child(header)
	
	var header_hbox = HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 10)
	header.add_child(header_hbox)
	
	var icon = Label.new()
	icon.text = _get_section_icon(section_name)
	icon.add_theme_font_size_override("font_size", 16)
	header_hbox.add_child(icon)
	
	var title = Label.new()
	title.text = section_name.to_upper()
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(title)
	
	# Pin button
	var pin_btn = Button.new()
	pin_btn.text = "PIN"
	pin_btn.custom_minimum_size = Vector2(40, 24)
	pin_btn.add_theme_font_size_override("font_size", 10)
	pin_btn.add_theme_stylebox_override("normal", style_button)
	pin_btn.add_theme_stylebox_override("hover", style_button_hover)
	pin_btn.pressed.connect(func(): toggle_section_pin(section_name))
	header_hbox.add_child(pin_btn)
	
	# Section content
	var content_scroll = ScrollContainer.new()
	content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(content_scroll)
	
	var content = section.get_debug_content()
	if content:
		content_scroll.add_child(content)
	
	return panel

func _get_section_icon(section_name: String) -> String:
	match section_name:
		"Player": return "[P]"
		"Weapons": return "[W]"
		"Inventory": return "[I]"
		"Performance": return "[%]"
		"Audio": return "[A]"
		"Systems": return "[S]"
		_: return "[?]"

func toggle_section_pin(section_name: String):
	"""Toggle a section as a floating window"""
	if floating_windows.has(section_name):
		# Unpin - remove floating window
		var window = floating_windows[section_name]
		window.queue_free()
		floating_windows.erase(section_name)
		section_pinned.emit(section_name, false)
		print("DebugMenu: Unpinned section '", section_name, "'")
	else:
		# Pin - create floating window
		var section = debug_sections[section_name]
		var window = _create_floating_window(section_name, section)
		add_child(window)
		floating_windows[section_name] = window
		section_pinned.emit(section_name, true)
		print("DebugMenu: Pinned section '", section_name, "'")
	
	refresh_sections()

func _create_floating_window(section_name: String, section: Node) -> Control:
	"""Create a floating debug window"""
	var window = preload("res://scripts/DebugWindow.gd").new(section_name, section)
	window.debug_menu = self
	window.position = Vector2(100 + floating_windows.size() * 50, 100 + floating_windows.size() * 50)
	return window

# === OLD TOGGLE MAIN MENU (DISABLED) ===
# DISABLED: Replaced with simpler toggle_menu function
# func toggle_main_menu():
# 	"""Toggle the main debug menu visibility"""
# 	is_main_menu_visible = not is_main_menu_visible
# 	main_panel.visible = is_main_menu_visible
# 	
# 	if is_main_menu_visible:
# 		refresh_sections()
# 	
# 	print("DebugMenu: Main menu ", "shown" if is_main_menu_visible else "hidden")

func toggle_menu():
	debug_visible = not debug_visible
	main_panel.visible = debug_visible
	
	if debug_visible:
		refresh_sections()

func close_all_floating_windows():
	for window in floating_windows.values():
		window.queue_free()
	floating_windows.clear()

# === QUICK ACTION FUNCTIONS ===

func _reload_scene():
	if Engine.get_main_loop():
		var tree = Engine.get_main_loop() as SceneTree
		if tree:
			tree.reload_current_scene()

func _toggle_godmode():
	if Engine.get_main_loop():
		var tree = Engine.get_main_loop() as SceneTree
		if tree:
			var player = tree.get_first_node_in_group("player")
			if player and player.has_method("set_god_mode"):
				player.set_god_mode(not player.get("god_mode"))
				print("Godmode toggled")

func _add_coins(amount: int):
	if Engine.get_main_loop():
		var tree = Engine.get_main_loop() as SceneTree
		if tree:
			var game_state = tree.root.get_node_or_null("/root/GameState")
			if game_state and game_state.has_method("add_coins"):
				game_state.add_coins(amount)
				print("Added %d coins" % amount)

func _kill_all_enemies():
	if Engine.get_main_loop():
		var tree = Engine.get_main_loop() as SceneTree
		if tree:
			var enemies = tree.get_nodes_in_group("enemy")
			for enemy in enemies:
				if enemy.has_method("die"):
					enemy.die()
				else:
					enemy.queue_free()
			print("Killed %d enemies" % enemies.size())

# === PUBLIC API ===

func get_section(section_name: String) -> Node:
	return debug_sections.get(section_name, null)

func update_section_data(section_name: String, data: Dictionary):
	var section = debug_sections.get(section_name)
	if section and section.has_method("update_data"):
		section.update_data(data)

# --- Public API for testing ---

func add_test_action(section_name: String, action_name: String, callback: Callable):
	"""Add a test action to a section"""
	var section = debug_sections.get(section_name)
	if section and section.has_method("add_test_action"):
		section.add_test_action(action_name, callback)

func log_debug_message(section_name: String, message: String, level: String = "INFO"):
	"""Log a debug message to a section"""
	var section = debug_sections.get(section_name)
	if section and section.has_method("log_message"):
		section.log_message(message, level)
