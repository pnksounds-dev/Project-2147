extends Node

class_name ThemeManager

# Shared theme system for consistent UI styling across all menu panels
# Based on MainMenu.tscn styling for visual consistency

static func get_menu_panel_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.08, 0.12, 0.6)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.2, 0.8, 1, 0.9)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	return style

static func get_menu_section_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.12, 0.18, 0.7)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.2, 0.8, 1, 0.3)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	return style

static func get_menu_button_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_width_bottom = 2
	style.border_color = Color(0, 0, 0, 0)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	return style

static func get_menu_button_pressed_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.8, 1, 0.25)
	style.border_width_bottom = 3
	style.border_color = Color(0.2, 0.8, 1, 1)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	return style

static func get_menu_button_hover_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.8, 1, 0.15)
	style.border_width_bottom = 2
	style.border_color = Color(0.2, 0.8, 1, 0.8)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	return style

static func get_menu_apply_button_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.8, 1, 0.2)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.2, 0.8, 1, 1.0)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	return style

static func get_title_color() -> Color:
	return Color(0.3, 0.8, 1.0, 1)

static func get_title_font_size() -> int:
	return 28

static func apply_consistent_theme_to_panel(panel: Control) -> void:
	if not panel:
		return
		
	# Apply panel style
	panel.add_theme_stylebox_override("panel", get_menu_panel_style())
	
	# Apply styles to all section panels
	var sections = panel.find_children("", "PanelContainer", true, false)
	for section in sections:
		if section != panel:  # Don't override the main panel
			section.add_theme_stylebox_override("panel", get_menu_section_style())
	
	# Apply button styles
	var buttons = panel.find_children("", "Button", true, false)
	for button in buttons:
		_apply_button_theme(button)

static func _apply_button_theme(button: Button) -> void:
	if not button:
		return
		
	button.add_theme_stylebox_override("normal", get_menu_button_style())
	button.add_theme_stylebox_override("pressed", get_menu_button_pressed_style())
	button.add_theme_stylebox_override("hover", get_menu_button_hover_style())
	
	# Special styling for apply buttons
	if "apply" in button.name.to_lower():
		button.add_theme_stylebox_override("normal", get_menu_apply_button_style())

static func apply_title_style(label: Label) -> void:
	if not label:
		return
		
	label.add_theme_color_override("font_color", get_title_color())
	label.add_theme_font_size_override("font_size", get_title_font_size())
