extends PanelContainer

class_name SavesPanel

## SavesPanel - Displays save slots with expandable details

var _save_manager: Node = null

var _save_list_vbox: VBoxContainer
var _info_label: Label

var _expanded_entry: Control = null
var _selected_entry: Control = null
var _selected_save_id: String = ""


func _ready() -> void:
	_save_manager = get_node_or_null("/root/SaveManager")
	_save_list_vbox = get_node_or_null("SavesVBox/SaveScroll/SaveListVBox")
	_info_label = get_node_or_null("SavesVBox/InfoLabel")


	_refresh_saves()

func _refresh_saves() -> void:
	if _save_list_vbox == null:
		return
	
	# Clear existing entries
	for child in _save_list_vbox.get_children():
		child.queue_free()
	_clear_selection()
	
	var saves: Array = []
	if _save_manager and _save_manager.has_method("get_all_saves"):
		saves = _save_manager.get_all_saves()
	
	for save_data in saves:
		var entry := _create_save_entry(save_data)
		_save_list_vbox.add_child(entry)
	
	if _info_label:
		if saves.is_empty():
			_info_label.text = "No saves found. Create a new save from the current game state."
		else:
			_info_label.text = ""
	

func _create_save_entry(save_data: Dictionary) -> Control:
	var entry := PanelContainer.new()
	entry.custom_minimum_size = Vector2(0, 60)
	entry.set_meta("save_id", save_data.get("id", -1))
	var default_style := _create_entry_style(false)
	var selected_style := _create_entry_style(true)
	entry.add_theme_stylebox_override("panel", default_style)
	entry.set_meta("style_default", default_style)
	entry.set_meta("style_selected", selected_style)

	var content := VBoxContainer.new()
	content.name = "EntryContent"
	content.add_theme_constant_override("separation", 6)
	entry.add_child(content)

	# Header row
	var header := HBoxContainer.new()
	header.name = "Header"
	header.add_theme_constant_override("separation", 8)
	content.add_child(header)

	# Ship texture before title
	var ship_icon: Control
	var tex_path: String = save_data.get("ship_texture", "")
	if tex_path != "" and ResourceLoader.exists(tex_path):
		ship_icon = TextureRect.new()
		ship_icon.custom_minimum_size = Vector2(40, 40)
		ship_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ship_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		(ship_icon as TextureRect).texture = load(tex_path)
		(ship_icon as TextureRect).modulate = Color.WHITE
	else:
		# Create a placeholder panel with background color if no texture
		ship_icon = Panel.new()
		ship_icon.custom_minimum_size = Vector2(40, 40)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.3, 0.3, 0.4)
		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_left = 4
		style.corner_radius_bottom_right = 4
		ship_icon.add_theme_stylebox_override("panel", style)
	header.add_child(ship_icon)

	var title := Label.new()
	title.name = "TitleLabel"
	title.text = save_data.get("name", "Unnamed Save")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	entry.set_meta("title_label", title)
	
	var summary := Label.new()
	summary.text = "Playtime: %s   Score: %s" % [
			save_data.get("playtime", "0h 00m"),
			str(save_data.get("score", 0))
		]
	summary.add_theme_font_size_override("font_size", 16)
	summary.modulate = Color(0.8, 0.8, 0.8)
	header.add_child(summary)
	
	var expand_btn := Button.new()
	expand_btn.text = "Details"
	expand_btn.custom_minimum_size = Vector2(80, 28)
	expand_btn.pressed.connect(_on_toggle_details.bind(entry))
	header.add_child(expand_btn)
	
	# Details panel (collapsed by default)
	var details := HBoxContainer.new()
	details.visible = false
	details.add_theme_constant_override("separation", 16)
	details.set_meta("is_details", true)
	content.add_child(details)

	var info_box := VBoxContainer.new()
	info_box.add_theme_constant_override("separation", 4)
	details.add_child(info_box)
	
	var playtime_label := Label.new()
	playtime_label.text = "Playtime: %s" % save_data.get("playtime", "0h 00m")
	info_box.add_child(playtime_label)
	
	var score_label := Label.new()
	score_label.text = "Score: %s" % str(save_data.get("score", 0))
	info_box.add_child(score_label)
	
	var stats_label := Label.new()
	stats_label.text = save_data.get("stats_summary", "Player stats will appear here.")
	stats_label.add_theme_font_size_override("font_size", 12)
	stats_label.modulate = Color(0.8, 0.8, 0.8)
	info_box.add_child(stats_label)

	entry.mouse_filter = Control.MOUSE_FILTER_PASS
	entry.gui_input.connect(_on_save_entry_gui_input.bind(entry))
	entry.set_meta("details_container", details)

	return entry

func _on_toggle_details(entry: Control) -> void:
	if entry == null:
		return
	var details: HBoxContainer = entry.get_meta("details_container", null)
	if details == null or not is_instance_valid(details):
		return
	if _expanded_entry and is_instance_valid(_expanded_entry) and _expanded_entry != entry:
		var prev_details: HBoxContainer = _expanded_entry.get_meta("details_container", null)
		if prev_details and is_instance_valid(prev_details):
			prev_details.visible = false
	details.visible = not details.visible
	if details.visible:
		_expanded_entry = entry
	else:
		_expanded_entry = null

func _on_favorite_toggled(entry: Control, button: Button) -> void:
	if entry == null or button == null:
		return
	var save_id = entry.get_meta("save_id", -1)
	var new_state: bool = true
	if _save_manager and _save_manager.has_method("toggle_favorite") and save_id != -1:
		new_state = _save_manager.toggle_favorite(save_id)
	button.text = "Unfavorite" if new_state else "Favorite"

func _on_favorite_toggled_bar() -> void:
	"""Handle favorite toggle from bottom bar button"""
	if _selected_save_id.is_empty():
		_set_info_text("Select a save before toggling favorite.")
		return
	if not _save_manager or not _save_manager.has_method("toggle_favorite"):
		_set_info_text("Save system unavailable.")
		return
	
	var new_state: bool = _save_manager.toggle_favorite(_selected_save_id)
	_set_info_text("Save marked as favorite." if new_state else "Save removed from favorites.")
	_refresh_saves()

func refresh_panel() -> void:
	_refresh_saves()

func _on_save_entry_gui_input(event: InputEvent, entry: Control) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_select_entry(entry)

func _select_entry(entry: Control) -> void:
	if entry == null:
		return
	if _selected_entry and is_instance_valid(_selected_entry):
		_apply_entry_style(_selected_entry, false)
	_selected_entry = entry
	_apply_entry_style(_selected_entry, true)
	_selected_save_id = str(entry.get_meta("save_id", ""))
	if _info_label and not _selected_save_id.is_empty():
		var title_label: Label = entry.get_meta("title_label", null)
		var title_text := title_label.text if title_label else _selected_save_id
		_info_label.text = "Selected save: %s" % title_text
	# Notify MainMenu to update button states
	var main_menu = get_node_or_null("/root/MainMenu")
	if main_menu and main_menu.has_method("_update_saves_bar_states"):
		main_menu._update_saves_bar_states()

func _clear_selection() -> void:
	if _selected_entry and is_instance_valid(_selected_entry):
		_apply_entry_style(_selected_entry, false)
	_selected_entry = null
	_selected_save_id = ""
	# Notify MainMenu to update button states
	var main_menu = get_node_or_null("/root/MainMenu")
	if main_menu and main_menu.has_method("_update_saves_bar_states"):
		main_menu._update_saves_bar_states()


func _on_load_selected_pressed() -> void:
	if _selected_save_id.is_empty():
		_set_info_text("Select a save before loading.")
		return
	if not _save_manager or not _save_manager.has_method("load_save"):
		_set_info_text("Save system unavailable.")
		return
	var data: Dictionary = _save_manager.load_save(_selected_save_id)
	if data.is_empty():
		_set_info_text("Failed to load save data.")
		return
	
	# === UNIFIED INVENTORY REFACTOR: Track current save ===
	var game_state = get_node_or_null("/root/GameState")
	if game_state and game_state.has_method("set_current_save_id"):
		game_state.set_current_save_id(_selected_save_id)
	
	# Apply ship data from save to GameState
	if game_state and game_state.has_method("apply_ship_data"):
		game_state.apply_ship_data(data)
	
	# Load inventory data if available
	var inventory_state = get_node_or_null("/root/InventoryState")
	if inventory_state and data.has("inventory"):
		inventory_state.from_save_dict(data)  # Pass full save data, not just inventory section
	
	var save_name := str(data.get("name", _selected_save_id))
	_set_info_text("Loaded save '%s'. Starting game..." % save_name)
	
	# Start the game by transitioning to Main scene
	await get_tree().create_timer(1.0).timeout
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _on_delete_selected_pressed() -> void:
	if _selected_save_id.is_empty():
		_set_info_text("Select a save before deleting.")
		return
	if not _save_manager or not _save_manager.has_method("delete_save"):
		_set_info_text("Save system unavailable.")
		return
	var success: bool = _save_manager.delete_save(_selected_save_id)
	if success:
		_set_info_text("Deleted save '%s'." % _selected_save_id)
		_refresh_saves()
	else:
		_set_info_text("Failed to delete save.")

func _on_refresh_pressed() -> void:
	_refresh_saves()

func get_selected_save_id() -> String:
	return _selected_save_id

func _set_info_text(text: String) -> void:
	if _info_label:
		_info_label.text = text

func _apply_entry_style(entry: Control, highlighted: bool) -> void:
	var key := "style_selected" if highlighted else "style_default"
	var style := entry.get_meta(key, null) as StyleBox
	if style:
		entry.add_theme_stylebox_override("panel", style)


func _create_entry_style(highlighted: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	if highlighted:
		style.bg_color = Color(0.08, 0.16, 0.25, 0.95)
	else:
		style.bg_color = Color(0.05, 0.08, 0.12, 0.9)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	if highlighted:
		style.border_color = Color(0.2, 0.8, 1, 0.9)
	else:
		style.border_color = Color(0.2, 0.35, 0.55, 0.6)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.expand_margin_left = 6
	style.expand_margin_right = 6
	style.expand_margin_top = 4
	style.expand_margin_bottom = 4
	return style
