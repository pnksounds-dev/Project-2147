extends PanelContainer
class_name MainMenuShipBuilder

signal ship_selected(ship_id: String)
signal start_game_requested(ship_id: String)

# UI Scaling settings - resolution independent
const BASE_RESOLUTION := Vector2(1920, 1080)
const MIN_UI_SCALE := 0.5
const MAX_UI_SCALE := 2.0
var _ui_scale: float = 1.0
var _base_card_size := Vector2(280, 420)
var _base_font_sizes := {
	"header": 28,
	"title": 20,
	"ship_name": 18,
	"stats": 14,
	"details": 16,
	"button": 16
}

const DEFAULT_PREFABS := [
	{"id": "starter_ship", "name": "Starter Ship", "type": "Starter", "level": 1, "created": 1, "price": 0, "texture": "res://assets/Ships/FactionShips/SpawnShip.png", "stats": "Speed 5  Armor 2  Cargo 1", "description": "Basic starter vessel with essential systems."},
	{"id": "medium_mk1", "name": "Medium MK I", "type": "Medium", "level": 2, "created": 2, "price": 500, "texture": "res://assets/Ships/FactionShips/ShipMedium1.png", "stats": "Speed 4  Armor 3  Cargo 2", "description": "Improved mid-tier ship with better performance."},
	{"id": "medium_mk2", "name": "Medium MK II", "type": "Medium", "level": 3, "created": 3, "price": 1200, "texture": "res://assets/Ships/player/Trader_General_1.png", "stats": "Speed 3  Armor 5  Cargo 3", "description": "Balanced gunship with modular hard-points."},
	{"id": "destroyer_base", "name": "Destroyer Base", "type": "Heavy", "level": 4, "created": 4, "price": 2500, "texture": "res://assets/Ships/ShipParts/Body/Destroyer_Head.png", "stats": "Speed 2  Armor 8  Cargo 4", "description": "Heavy destroyer chassis for serious combat."}
]

var _ship_prefabs: Array = []
var _ship_card_nodes: Array[PanelContainer] = []
var _ship_search_term: String = ""
var _ship_filter_mode: int = 0
var _focused_ship_index: int = -1
var _selected_ship: String = ""
var _error_handler: Callable
# Future features - reserved for expansion
# var _current_view_mode: int = 0  # 0 = Grid, 1 = List
# var _show_stats_comparison: bool = false

@onready var _grid: GridContainer = $"ShipBuilderVBox/ShipBuilderBody/ShipScroll/ShipGrid"
@onready var _scroll: ScrollContainer = $"ShipBuilderVBox/ShipBuilderBody/ShipScroll"
@onready var _search_bar: LineEdit = $"ShipBuilderVBox/ShipBuilderToolbar/SearchSection/SearchBar"
@onready var _filter_options: OptionButton = $"ShipBuilderVBox/ShipBuilderToolbar/FilterSection/FilterOptions"
@onready var _quick_starter: Button = $"ShipBuilderVBox/ShipBuilderToolbar/ActionButtons/QuickStarter"
@onready var _quick_medium: Button = $"ShipBuilderVBox/ShipBuilderToolbar/ActionButtons/QuickMedium"
@onready var _quick_heavy: Button = $"ShipBuilderVBox/ShipBuilderToolbar/ActionButtons/QuickHeavy"
@onready var _rename_btn: Button = $"ShipBuilderVBox/ShipBuilderToolbar/ManagementButtons/RenameButton"
@onready var _launch_btn: Button = $"ShipBuilderVBox/ShipBuilderToolbar/ManagementButtons/LaunchButton"
@onready var _export_btn: Button = $"ShipBuilderVBox/ShipBuilderToolbar/ManagementButtons/ExportButton"
@onready var _selected_info: VBoxContainer = $"ShipBuilderVBox/ShipBuilderFooter/SelectedInfo"
@onready var _preview_container: HBoxContainer = $"ShipBuilderVBox/ShipBuilderFooter/ShipPreview"
@onready var _start_btn: Button = $"ShipBuilderVBox/StartButtonCenter/StartGameButton"

func _ready() -> void:
	_ship_prefabs = DEFAULT_PREFABS.duplicate(true)
	_calculate_ui_scale()
	_apply_ui_scale()
	_connect_controls()
	_refresh_ship_grid()
	_update_selected_ship_display()
	_update_start_game_button_state()
	visible = false
	if get_viewport() and not get_viewport().size_changed.is_connected(_on_viewport_resized):
		get_viewport().size_changed.connect(_on_viewport_resized)

func set_error_handler(handler: Callable) -> void:
	_error_handler = handler

func set_prefabs(prefabs: Array) -> void:
	_ship_prefabs = prefabs.duplicate(true) if prefabs.size() > 0 else DEFAULT_PREFABS.duplicate(true)
	_refresh_ship_grid()
	_update_selected_ship_display()

func open_panel(initial_ship: String = "") -> void:
	visible = true
	if not initial_ship.is_empty():
		set_selected_ship(initial_ship, false)
	_refresh_ship_grid()
	_update_selected_ship_display()

func close_panel() -> void:
	visible = false

func handle_input(event: InputEvent) -> bool:
	if not visible or _ship_card_nodes.is_empty():
		return false
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_LEFT:
				_navigate_ship_selection(-1, 0)
				return true
			KEY_RIGHT:
				_navigate_ship_selection(1, 0)
				return true
			KEY_UP:
				_navigate_ship_selection(0, -1)
				return true
			KEY_DOWN:
				_navigate_ship_selection(0, 1)
				return true
			KEY_ENTER, KEY_SPACE:
				if _focused_ship_index >= 0 and _focused_ship_index < _ship_card_nodes.size():
					var card = _ship_card_nodes[_focused_ship_index]
					if card and is_instance_valid(card):
						var ship_id = card.get_meta("ship_id", "")
						if ship_id != "":
							_on_ship_card_selected(ship_id)
							return true
	return false

func handle_window_resized() -> void:
	if visible:
		_calculate_ui_scale()
		_apply_ui_scale()
		_refresh_ship_grid()

func _calculate_ui_scale() -> void:
	var viewport_size = get_viewport_rect().size
	var scale_x = viewport_size.x / BASE_RESOLUTION.x
	var scale_y = viewport_size.y / BASE_RESOLUTION.y
	_ui_scale = clamp(min(scale_x, scale_y), MIN_UI_SCALE, MAX_UI_SCALE)

func _apply_ui_scale() -> void:
	# Apply scaling to all UI elements
	if _grid:
		var scaled_spacing = int(20 * _ui_scale)
		_grid.add_theme_constant_override("h_separation", scaled_spacing)
		_grid.add_theme_constant_override("v_separation", scaled_spacing)
	
	# Scale fonts
	var header = get_node_or_null("ShipBuilderVBox/ShipBuilderHeader/HeaderTitle")
	if header:
		header.add_theme_font_size_override("font_size", int(_base_font_sizes["header"] * _ui_scale))
	
	var selected_label = get_node_or_null("ShipBuilderVBox/ShipBuilderFooter/SelectedInfo/SelectedShipLabel")
	if selected_label:
		selected_label.add_theme_font_size_override("font_size", int(_base_font_sizes["title"] * _ui_scale))
	
	var details_label = get_node_or_null("ShipBuilderVBox/ShipBuilderFooter/SelectedInfo/SelectedShipDetails")
	if details_label:
		details_label.add_theme_font_size_override("font_size", int(_base_font_sizes["details"] * _ui_scale))
	
	if _start_btn:
		_start_btn.add_theme_font_size_override("font_size", int(_base_font_sizes["button"] * _ui_scale * 1.2))
		_start_btn.custom_minimum_size = Vector2(200 * _ui_scale, 50 * _ui_scale)

func set_ui_scale(ui_scale_value: float) -> void:
	_ui_scale = clamp(ui_scale_value, MIN_UI_SCALE, MAX_UI_SCALE)
	_apply_ui_scale()
	_refresh_ship_grid()

func get_ui_scale() -> float:
	return _ui_scale

func get_selected_ship() -> String:
	return _selected_ship

func set_selected_ship(ship_id: String, should_emit_signal: bool) -> void:
	_selected_ship = ship_id
	_highlight_ship_cards()
	_update_selected_ship_display()
	if should_emit_signal and not ship_id.is_empty():
		ship_selected.emit(ship_id)

func _connect_controls() -> void:
	if _search_bar:
		_search_bar.text_changed.connect(_on_ship_search_changed)
	if _filter_options:
		_filter_options.item_selected.connect(_on_ship_filter_changed)
	if _quick_starter:
		_quick_starter.pressed.connect(_on_quick_select_starter)
	if _quick_medium:
		_quick_medium.pressed.connect(_on_quick_select_medium)
	if _quick_heavy:
		_quick_heavy.pressed.connect(_on_quick_select_heavy)
	if _rename_btn:
		_rename_btn.pressed.connect(_on_ship_rename_pressed)
	if _launch_btn:
		_launch_btn.pressed.connect(_on_ship_start_game_pressed)
	if _export_btn:
		_export_btn.pressed.connect(_on_ship_export_pressed)
	if _start_btn:
		_start_btn.pressed.connect(_on_ship_start_game_pressed)

func _refresh_ship_grid() -> void:
	if not _grid:
		return
	_grid.columns = _calculate_optimal_columns()
	for child in _grid.get_children():
		child.queue_free()
	_ship_card_nodes.clear()
	for ship_data in _get_filtered_ships():
		var card = _create_ship_card(ship_data)
		_grid.add_child(card)
		_ship_card_nodes.append(card)
	_highlight_ship_cards()

func _calculate_optimal_columns() -> int:
	if not _scroll:
		return 3
	var available_width = max(_scroll.size.x, 1.0)
	if available_width <= 1.0:
		available_width = get_viewport().get_visible_rect().size.x - 100
	# Use scaled card width
	var card_width = _base_card_size.x * _ui_scale
	var spacing = 20.0 * _ui_scale
	var max_columns = floor((available_width + spacing) / (card_width + spacing))
	return clamp(int(max_columns), 1, 6)

func _get_filtered_ships() -> Array:
	var ships: Array = []
	var term = _ship_search_term.to_lower()
	for ship in _ship_prefabs:
		var ship_name: String = ship.get("name", "").to_lower()
		var ship_type: String = ship.get("type", "").to_lower()
		
		# Filter by search term
		if term.is_empty() or ship_name.contains(term) or ship_type.contains(term):
			ships.append(ship)
	
	return ships

func _create_ship_card(ship_data: Dictionary) -> PanelContainer:
	var ship_id: String = ship_data.get("id", "")
	var ship_name: String = ship_data.get("name", "")
	var ship_type: String = ship_data.get("type", "")
	var ship_level: int = int(ship_data.get("level", 1))
	var ship_price = int(ship_data.get("price", 0))
	var ship_stats = ship_data.get("stats", "")
	
	var card = PanelContainer.new()
	card.name = "ShipCard_" + ship_id
	# Use scaled card size
	var scaled_size = _base_card_size * _ui_scale
	card.custom_minimum_size = scaled_size
	card.set_meta("ship_id", ship_id)
	var rarity_color = _get_ship_rarity_color(ship_level)
	var style = StyleBoxFlat.new()
	# Enhanced visual design
	style.bg_color = Color(0.08, 0.10, 0.14, 0.98)
	style.border_color = rarity_color
	# Scale border width
	var border_width = max(2, int(3 * _ui_scale))
	style.border_width_left = border_width
	style.border_width_right = border_width
	style.border_width_top = border_width
	style.border_width_bottom = border_width
	# Scale corner radius
	var corner_radius = max(8, int(12 * _ui_scale))
	style.corner_radius_top_left = corner_radius
	style.corner_radius_top_right = corner_radius
	style.corner_radius_bottom_left = corner_radius
	style.corner_radius_bottom_right = corner_radius
	# Add subtle shadow effect
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = max(2, int(4 * _ui_scale))
	style.shadow_offset = Vector2(0, 2) * _ui_scale
	card.add_theme_stylebox_override("panel", style)
	var main_vbox = VBoxContainer.new()
	main_vbox.name = "CardVBox"
	# Scale separation
	main_vbox.add_theme_constant_override("separation", max(4, int(8 * _ui_scale)))
	main_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(main_vbox)
	# Header with rarity indicator
	var header_hbox = HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", max(3, int(6 * _ui_scale)))
	var rarity_dot = ColorRect.new()
	var dot_size = max(6, int(10 * _ui_scale))
	rarity_dot.custom_minimum_size = Vector2(dot_size, dot_size)
	rarity_dot.color = rarity_color
	header_hbox.add_child(rarity_dot)
	var type_label = Label.new()
	type_label.text = ship_type.to_upper()
	type_label.add_theme_font_size_override("font_size", max(8, int(12 * _ui_scale)))
	type_label.add_theme_color_override("font_color", rarity_color)
	type_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	type_label.add_theme_constant_override("outline_size", max(1, int(2 * _ui_scale)))
	header_hbox.add_child(type_label)
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(spacer)
	var level_label = Label.new()
	level_label.text = "Lv." + str(ship_level)
	level_label.add_theme_font_size_override("font_size", max(8, int(12 * _ui_scale)))
	level_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.2))
	level_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	level_label.add_theme_constant_override("outline_size", max(1, int(2 * _ui_scale)))
	header_hbox.add_child(level_label)
	main_vbox.add_child(header_hbox)
	# Ship preview image
	var image_container = CenterContainer.new()
	var img_size = Vector2(220, 160) * _ui_scale
	image_container.custom_minimum_size = img_size
	var image_panel = PanelContainer.new()
	var image_style = StyleBoxFlat.new()
	image_style.bg_color = Color(0.03, 0.05, 0.08, 0.95)
	image_style.border_color = Color(0.2, 0.25, 0.35, 0.6)
	var img_border = max(1, int(2 * _ui_scale))
	image_style.border_width_left = img_border
	image_style.border_width_right = img_border
	image_style.border_width_top = img_border
	image_style.border_width_bottom = img_border
	var img_radius = max(4, int(8 * _ui_scale))
	image_style.corner_radius_top_left = img_radius
	image_style.corner_radius_top_right = img_radius
	image_style.corner_radius_bottom_left = img_radius
	image_style.corner_radius_bottom_right = img_radius
	image_panel.add_theme_stylebox_override("panel", image_style)
	var texture_rect = TextureRect.new()
	var tex_size = Vector2(200, 140) * _ui_scale
	texture_rect.custom_minimum_size = tex_size
	texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var tex_path: String = ship_data.get("texture", "")
	if tex_path != "" and ResourceLoader.exists(tex_path):
		texture_rect.texture = load(tex_path)
	image_panel.add_child(texture_rect)
	image_container.add_child(image_panel)
	main_vbox.add_child(image_container)
	# Ship name with better styling
	var name_label = Label.new()
	name_label.text = ship_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", max(14, int(_base_font_sizes["ship_name"] * _ui_scale)))
	name_label.add_theme_color_override("font_color", Color(1, 1, 1))
	name_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	name_label.add_theme_constant_override("outline_size", max(1, int(2 * _ui_scale)))
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	main_vbox.add_child(name_label)
	# Stats with icon indicators
	var stats_label = Label.new()
	stats_label.text = ship_stats
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label.add_theme_font_size_override("font_size", max(10, int(_base_font_sizes["stats"] * _ui_scale)))
	stats_label.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
	stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	main_vbox.add_child(stats_label)
	# Price display with better visibility (no emoji)
	var price_container = HBoxContainer.new()
	price_container.add_theme_constant_override("separation", max(3, int(6 * _ui_scale)))
	price_container.alignment = BoxContainer.ALIGNMENT_CENTER
	var price_label = Label.new()
	price_label.text = str(ship_price) if ship_price > 0 else "FREE"
	price_label.add_theme_font_size_override("font_size", max(10, int(14 * _ui_scale)))
	price_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3) if ship_price > 0 else Color(0.3, 1.0, 0.3))
	price_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	price_label.add_theme_constant_override("outline_size", max(1, int(2 * _ui_scale)))
	price_container.add_child(price_label)
	main_vbox.add_child(price_container)
	# Select button with scaled size
	var select_btn = Button.new()
	select_btn.name = "SelectButton"
	select_btn.text = "SELECT"
	var btn_height = max(32, int(45 * _ui_scale))
	select_btn.custom_minimum_size = Vector2(0, btn_height)
	select_btn.add_theme_font_size_override("font_size", max(12, int(_base_font_sizes["button"] * _ui_scale)))
	select_btn.pressed.connect(_on_ship_card_selected.bind(ship_id))
	main_vbox.add_child(select_btn)
	card.mouse_entered.connect(_on_card_mouse_enter.bind(card))
	card.mouse_exited.connect(_on_card_mouse_exit.bind(card))
	return card

func _on_ship_card_selected(ship_id: String) -> void:
	if ship_id.is_empty():
		return
	_selected_ship = ship_id
	ship_selected.emit(ship_id)
	_highlight_ship_cards()
	_update_selected_ship_display()
	_update_start_game_button_state()
	call_deferred("_scroll_to_selected_ship")

func _highlight_ship_cards() -> void:
	for card in _ship_card_nodes:
		if not card or not is_instance_valid(card):
			continue
		var ship_id = card.get_meta("ship_id", "")
		var style := card.get_theme_stylebox("panel") as StyleBoxFlat
		var select_btn: Button = card.get_node_or_null("CardVBox/SelectButton")
		var selected = ship_id == _selected_ship and not _selected_ship.is_empty()
		if style:
			style.border_color = Color(0.2, 0.8, 1, 1) if selected else Color(0.25, 0.25, 0.35)
			style.bg_color = Color(0.12, 0.18, 0.25, 1) if selected else Color(0.1, 0.12, 0.16, 0.95)
		if select_btn:
			select_btn.text = "Selected" if selected else "Select"

func _update_selected_ship_display() -> void:
	var ship = _get_ship_data(_selected_ship)
	var info_label: Label = _selected_info.get_node_or_null("SelectedShipLabel")
	var details_label: Label = _selected_info.get_node_or_null("SelectedShipDetails")
	if ship.is_empty():
		if info_label:
			info_label.text = "No ship selected"
		if details_label:
			details_label.text = "Choose a ship to view stats"
		_clear_ship_preview(_preview_container)
		_update_start_game_button_state()
		return
	if info_label:
		var rarity_color = _get_ship_rarity_color(int(ship.get("level", 1)))
		info_label.text = "%s (%s)" % [ship.get("name", "Unknown"), ship.get("type", "Unknown")]
		info_label.add_theme_color_override("font_color", rarity_color)
	if details_label:
		details_label.text = "Level: %d  •  %s\nUnlock Cost: %s credits\n\n%s" % [
			int(ship.get("level", 1)),
			ship.get("stats", ""),
			str(ship.get("price", 0)),
			ship.get("description", "")
		]
	_update_ship_preview(_preview_container, ship)
	_update_start_game_button_state()

func _clear_ship_preview(container: HBoxContainer) -> void:
	if not container:
		return
	for child in container.get_children():
		child.queue_free()

func _update_ship_preview(container: HBoxContainer, ship_data: Dictionary) -> void:
	if not container or ship_data.is_empty():
		return
	_clear_ship_preview(container)
	var image_container = VBoxContainer.new()
	image_container.custom_minimum_size = Vector2(140, 0)
	var image_panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.07, 0.10, 0.8)
	style.border_color = Color(0.2, 0.25, 0.35)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	image_panel.add_theme_stylebox_override("panel", style)
	var texture_rect = TextureRect.new()
	texture_rect.custom_minimum_size = Vector2(110, 80)
	texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var tex_path: String = ship_data.get("texture", "")
	if tex_path != "" and ResourceLoader.exists(tex_path):
		texture_rect.texture = load(tex_path)
	image_panel.add_child(texture_rect)
	image_container.add_child(image_panel)
	container.add_child(image_container)

func _update_start_game_button_state() -> void:
	if not _start_btn:
		return
	var enabled = not _selected_ship.is_empty()
	_start_btn.disabled = not enabled
	_start_btn.modulate = Color(0.55, 0.55, 0.6, 0.85) if not enabled else Color(1, 1, 1, 1)

func _on_ship_search_changed(text: String) -> void:
	_ship_search_term = text.strip_edges()
	_focused_ship_index = -1
	_refresh_ship_grid()

func _on_ship_filter_changed(index: int) -> void:
	_ship_filter_mode = index
	_focused_ship_index = -1
	_refresh_ship_grid()

func _navigate_ship_selection(delta_x: int, delta_y: int) -> void:
	if _ship_card_nodes.is_empty():
		return
	var columns = max(_grid.columns, 1)
	var rows = int(ceil(float(_ship_card_nodes.size()) / columns))
	if _focused_ship_index == -1:
		_focused_ship_index = 0
	else:
		var current_row = _focused_ship_index / columns
		var current_col = _focused_ship_index % columns
		current_col = (current_col + delta_x + columns) % columns
		current_row = (current_row + delta_y + rows) % rows
		_focused_ship_index = clamp(current_row * columns + current_col, 0, _ship_card_nodes.size() - 1)
	_highlight_ship_cards()

func _scroll_to_selected_ship() -> void:
	if _ship_card_nodes.is_empty() or _selected_ship.is_empty():
		return
	for i in _ship_card_nodes.size():
		var card = _ship_card_nodes[i]
		if card and is_instance_valid(card) and card.get_meta("ship_id", "") == _selected_ship:
			var columns = max(_grid.columns, 1)
			var row = float(i) / columns
			var card_height = 380
			var spacing = 20
			var target_y = row * (card_height + spacing)
			var tween = _scroll.create_tween()
			tween.set_ease(Tween.EASE_OUT)
			tween.set_trans(Tween.TRANS_CUBIC)
			tween.tween_property(_scroll, "scroll_vertical", target_y, 0.4)
			break

func _on_quick_select_starter() -> void:
	_select_ship_by_type("Starter")

func _on_quick_select_medium() -> void:
	_select_ship_by_type("Medium")

func _on_quick_select_heavy() -> void:
	_select_ship_by_type("Heavy")

func _select_ship_by_type(ship_type: String) -> void:
	for ship in _ship_prefabs:
		if ship.get("type", "").to_lower() == ship_type.to_lower():
			_on_ship_card_selected(ship.get("id", ""))
			return
	_show_error_message("No %s ships available." % ship_type)

func _on_ship_rename_pressed() -> void:
	if _selected_ship.is_empty():
		_show_error_message("Select a ship to rename.")
		return
	var ship = _get_ship_data(_selected_ship)
	if ship.is_empty():
		return
	var dialog = AcceptDialog.new()
	dialog.title = "Rename Ship"
	var input = LineEdit.new()
	input.text = ship.get("name", "")
	dialog.add_child(input)
	dialog.confirmed.connect(func():
		var new_name = input.text.strip_edges()
		if new_name.is_empty():
			return
		for s in _ship_prefabs:
			if s.get("id", "") == _selected_ship:
				s["name"] = new_name
		_refresh_ship_grid()
	)
	get_tree().current_scene.add_child(dialog)
	dialog.popup_centered()
	input.grab_focus()

func _on_ship_export_pressed() -> void:
	if _selected_ship.is_empty():
		_show_error_message("Select a ship to export.")
		return
	print("Exporting ship data for: %s (TODO)" % _selected_ship)

func _on_ship_start_game_pressed() -> void:
	if _selected_ship.is_empty():
		_show_error_message("Please select a ship first!")
		return
	start_game_requested.emit(_selected_ship)

func _get_ship_data(ship_id: String) -> Dictionary:
	for ship in _ship_prefabs:
		if ship.get("id", "") == ship_id:
			return ship
	return {}

func get_ship_info(ship_id: String) -> Dictionary:
	return _get_ship_data(ship_id).duplicate(true)

func _get_ship_rarity_color(level: int) -> Color:
	match level:
		1:
			return Color(0.7, 0.7, 0.7)
		2:
			return Color(0.2, 0.8, 0.2)
		3:
			return Color(0.2, 0.6, 1.0)
		4:
			return Color(0.8, 0.3, 0.9)
		_:
			return Color(1.0, 0.6, 0.0)

func _on_card_mouse_enter(card: PanelContainer) -> void:
	if card and is_instance_valid(card):
		var tween = card.create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(card, "scale", Vector2(1.05, 1.05), 0.2)

func _on_card_mouse_exit(card: PanelContainer) -> void:
	if card and is_instance_valid(card):
		var tween = card.create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(card, "scale", Vector2(1.0, 1.0), 0.2)

func _show_error_message(message: String) -> void:
	if _error_handler and _error_handler.is_valid():
		_error_handler.call(message)
	else:
		push_warning(message)

func _on_viewport_resized() -> void:
	handle_window_resized()
