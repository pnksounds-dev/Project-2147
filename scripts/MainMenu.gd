extends Control

class_name MainMenu

@export var gameplay_scene: PackedScene
@export var version_text: String = "Version 3.2.1"
@export var background_texture_path: String = "res://assets/environment/backgrounds/"

enum Mode { HOME, SETTINGS, CHANGELOG, GALLERY, SHIPS, SAVES, INVENTORY, SHOP, DEBUG }
var current_mode: int = Mode.HOME
var _transitioning: bool = false
var _selected_ship: String = ""
var _ship_builder: MainMenuShipBuilder
var _debug_ui_enabled: bool = true
var _debug_panel: Control
const InventoryUIScene: PackedScene = preload("res://scenes/InventoryUI.tscn")
var _inventory_ui: Control
var _middle_layout_default: Dictionary = {}
var _middle_layout_full: Dictionary = {}

# Audio manager reference
@onready var audio_manager: AudioManager = get_node_or_null("/root/AudioManager")

# Home panel references
@onready var _motd_text: RichTextLabel = get_node_or_null("CanvasLayer/Middle/MotdPanel/MotdVBox/MotdText")

# Bottom bar containers for context-aware UI
@onready var _home_bar: HBoxContainer = get_node_or_null("CanvasLayer/BottomBarContainer/HomeBar")
@onready var _gallery_bar: HBoxContainer = get_node_or_null("CanvasLayer/BottomBarContainer/GalleryBar")
@onready var _settings_bar: HBoxContainer = get_node_or_null("CanvasLayer/BottomBarContainer/SettingsBar")
@onready var _ships_bar: HBoxContainer = get_node_or_null("CanvasLayer/BottomBarContainer/ShipsBar")
@onready var _saves_bar: HBoxContainer = get_node_or_null("CanvasLayer/BottomBarContainer/SavesBar")
@onready var _inventory_bar: HBoxContainer = get_node_or_null("CanvasLayer/BottomBarContainer/InventoryBar")
@onready var _shop_bar: HBoxContainer = get_node_or_null("CanvasLayer/BottomBarContainer/ShopBar")

# Tab button references for visual feedback
@onready var _tab_buttons: Dictionary = {
	Mode.HOME: get_node_or_null("CanvasLayer/TopBarContainer/TopBarCenter/TopButtons/HomeButton"),
	Mode.SAVES: get_node_or_null("CanvasLayer/TopBarContainer/TopBarCenter/TopButtons/SavesButton"),
	Mode.SHIPS: get_node_or_null("CanvasLayer/TopBarContainer/TopBarCenter/TopButtons/ShipsButton"),
	Mode.GALLERY: get_node_or_null("CanvasLayer/TopBarContainer/TopBarCenter/TopButtons/GalleryButton"),
	Mode.SETTINGS: get_node_or_null("CanvasLayer/TopBarContainer/TopBarCenter/TopButtons/SettingsButton"),
	Mode.INVENTORY: get_node_or_null("CanvasLayer/TopBarContainer/TopBarCenter/TopButtons/InventoryButton"),
	Mode.SHOP: get_node_or_null("CanvasLayer/TopBarContainer/TopBarCenter/TopButtons/ShopButton")
}

# Style resources for tab feedback - will be created dynamically
# @onready var _style_tab_active: StyleBox = preload("res://scenes/MainMenu.tscn").get_state().get_node_property_value(0, 1, "StyleBoxFlat_btn_pressed")
# @onready var _style_tab_inactive: StyleBox = preload("res://scenes/MainMenu.tscn").get_state().get_node_property_value(0, 1, "StyleBoxFlat_btn_normal")

func _ready():
	if gameplay_scene == null:
		gameplay_scene = preload("res://scenes/Main.tscn")
	
	# Set version label
	var version_label = get_node_or_null("CanvasLayer/TopBarContainer/TopBarRight/VersionLabel")
	if version_label:
		version_label.text = version_text
	
	# Set background texture
	var bg = get_node_or_null("Background")
	if bg:
		var tex = load(background_texture_path) as Texture2D
		if tex:
			bg.texture = tex
			bg.stretch_mode = TextureRect.STRETCH_TILE
			# Ensure texture repeats properly
			bg.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	
	# Initialize background renderer state
	var bg_renderer = get_tree().get_first_node_in_group("background_renderer")
	if bg_renderer and bg:
		# Hide static background when Ultra HD is enabled
		bg.visible = not bg_renderer.ultra_hd_enabled
	
	# Connect button signals
	_connect_buttons()
	
	# Initialize tab system
	_initialize_tabs()
	
	# Initialize ship builder
	_ensure_ship_builder_ready()
	
	# Start main menu music
	if audio_manager:
		audio_manager.play_music("bounce_orbits", true)
	
	GameLog.log_system("MainMenu initialized")
	_cache_middle_layouts()
	_set_active_tab(_get_button("HomeButton"))
	_update_bottom_bar_visibility()
	_update_tab_visuals()

func _update_bottom_bar_visibility():
	"""Show/hide bottom bar containers based on current mode"""
	# Hide all bottom bars first
	var bars = [_home_bar, _gallery_bar, _settings_bar, _ships_bar, _saves_bar, _inventory_bar, _shop_bar]
	for bar in bars:
		if bar:
			bar.visible = false
	
	# Show appropriate bottom bar for current mode
	match current_mode:
		Mode.HOME:
			if _home_bar: _home_bar.visible = true
		Mode.GALLERY:
			if _gallery_bar: _gallery_bar.visible = true
		Mode.SETTINGS:
			if _settings_bar: _settings_bar.visible = true
		Mode.SHIPS:
			if _ships_bar: _ships_bar.visible = true
		Mode.SAVES:
			if _saves_bar: _saves_bar.visible = true
		Mode.INVENTORY:
			if _inventory_bar: _inventory_bar.visible = true
		Mode.SHOP:
			if _shop_bar: _shop_bar.visible = true
		Mode.CHANGELOG:
			if _home_bar: _home_bar.visible = true  # Use home bar for changelog
		Mode.DEBUG:
			if _home_bar: _home_bar.visible = true  # Use home bar for debug

func _update_tab_visuals():
	"""Update visual appearance of tab buttons to show active state"""
	var underline = get_node_or_null("CanvasLayer/TabUnderline")
	
	for mode in _tab_buttons:
		var button = _tab_buttons[mode]
		if button:
			var is_active = (mode == current_mode)
			# Update button style based on active state
			if is_active:
				button.add_theme_color_override("font_color", Color(0.2, 0.8, 1, 1))
				button.add_theme_color_override("font_hover_color", Color(0.2, 0.8, 1, 1))
				button.add_theme_color_override("font_pressed_color", Color(0.2, 0.8, 1, 1))
				# Update tab underline position
				if underline:
					underline.visible = true
					_update_tab_underline_for_button(button)
			else:
				button.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1))
				button.add_theme_color_override("font_hover_color", Color(0.2, 0.8, 1, 1))
				button.add_theme_color_override("font_pressed_color", Color(0.2, 0.8, 1, 1))

func _switch_mode(new_mode: int, button: Button = null):
	"""Switch to a new UI mode with bottom bar context update"""
	if _transitioning:
		return
	
	_transitioning = true
	current_mode = new_mode
	
	# Update bottom bar and tab visuals
	_update_bottom_bar_visibility()
	_update_tab_visuals()
	
	# Handle mode-specific logic
	match new_mode:
		Mode.HOME:
			pass  # Panel handled by _set_active_tab
		Mode.GALLERY:
			pass  # Panel handled by _set_active_tab
		Mode.SETTINGS:
			pass  # Panel handled by _set_active_tab
		Mode.SHIPS:
			pass  # Panel handled by _set_active_tab
		Mode.SAVES:
			pass  # Panel handled by _set_active_tab
		Mode.INVENTORY:
			_show_inventory_panel()  # Special case for inventory
		Mode.SHOP:
			_show_shop_panel()  # Special case for shop
		Mode.CHANGELOG:
			pass  # Panel handled by _set_active_tab
		Mode.DEBUG:
			pass  # Panel handled by _set_active_tab
	
	# Update tab underline if button provided
	if button:
		_set_active_tab(button)
	
	_transitioning = false
	GameLog.log_info("Switched to mode: %s" % Mode.keys()[new_mode], "MainMenu")

func _connect_buttons():
	# Top bar buttons (navigation/header controls)
	var start_btn = get_node_or_null("CanvasLayer/TopBarContainer/TopBarCenter/TopButtons/HomeButton")
	var changelog_btn = get_node_or_null("CanvasLayer/TopBarContainer/TopBarCenter/TopButtons/ChangelogButton")
	var gallery_btn = get_node_or_null("CanvasLayer/TopBarContainer/TopBarCenter/TopButtons/GalleryButton")
	var settings_btn = get_node_or_null("CanvasLayer/TopBarContainer/TopBarCenter/TopButtons/SettingsButton")
	var ships_btn = get_node_or_null("CanvasLayer/TopBarContainer/TopBarCenter/TopButtons/ShipsButton")
	var saves_btn = get_node_or_null("CanvasLayer/TopBarContainer/TopBarCenter/TopButtons/SavesButton")
	var inventory_top_btn = get_node_or_null("CanvasLayer/TopBarContainer/TopBarCenter/TopButtons/InventoryButton")
	var shop_btn = get_node_or_null("CanvasLayer/TopBarContainer/TopBarCenter/TopButtons/ShopButton")
	var quit_btn = get_node_or_null("CanvasLayer/TopBarContainer/TopBarCenter/TopButtons/QuitButton")
	
	if start_btn and not start_btn.pressed.is_connected(_on_start_pressed):
		start_btn.pressed.connect(_on_start_pressed)
	if changelog_btn and not changelog_btn.pressed.is_connected(_on_changelog_pressed):
		changelog_btn.pressed.connect(_on_changelog_pressed)
	if gallery_btn and not gallery_btn.pressed.is_connected(_on_gallery_pressed):
		gallery_btn.pressed.connect(_on_gallery_pressed)
	if settings_btn and not settings_btn.pressed.is_connected(_on_settings_pressed):
		settings_btn.pressed.connect(_on_settings_pressed)
	if ships_btn and not ships_btn.pressed.is_connected(_on_ships_pressed):
		ships_btn.pressed.connect(_on_ships_pressed)
	if saves_btn and not saves_btn.pressed.is_connected(_on_saves_pressed):
		saves_btn.pressed.connect(_on_saves_pressed)
	if inventory_top_btn and not inventory_top_btn.pressed.is_connected(_on_inventory_pressed):
		inventory_top_btn.pressed.connect(_on_inventory_pressed)
	if shop_btn and not shop_btn.pressed.is_connected(_on_shop_pressed):
		shop_btn.pressed.connect(_on_shop_pressed)
	if quit_btn and not quit_btn.pressed.is_connected(_on_quit_pressed):
		quit_btn.pressed.connect(_on_quit_pressed)
	
	# Settings panel back button
	var settings_panel = get_node_or_null("CanvasLayer/SettingsPanel")
	if settings_panel and settings_panel.has_signal("back_requested"):
		if not settings_panel.back_requested.is_connected(_on_settings_back_pressed):
			settings_panel.back_requested.connect(_on_settings_back_pressed)
	
	# Bottom bar buttons
	var new_game_btn = get_node_or_null("CanvasLayer/BottomBarContainer/BottomBarLeft/NewGameButton")
	var continue_btn = get_node_or_null("CanvasLayer/BottomBarContainer/BottomBarLeft/ContinueButton")
	var inventory_btn = get_node_or_null("CanvasLayer/BottomBarContainer/BottomBarLeft/InventoryButton")
	var changelog_bottom_btn = get_node_or_null("CanvasLayer/BottomBarContainer/BottomBarLeft/ChangelogButton")
	var discord_btn = get_node_or_null("CanvasLayer/BottomBarContainer/BottomBarRight/DiscordButton")
	var debug_bottom_btn = get_node_or_null("CanvasLayer/BottomBarContainer/BottomBarRight/DebugButton")
	
	if new_game_btn and not new_game_btn.pressed.is_connected(_on_new_game_pressed):
		new_game_btn.pressed.connect(_on_new_game_pressed)
	if continue_btn and not continue_btn.pressed.is_connected(_on_continue_pressed):
		continue_btn.pressed.connect(_on_continue_pressed)
	if inventory_btn and not inventory_btn.pressed.is_connected(_on_inventory_pressed):
		inventory_btn.pressed.connect(_on_inventory_pressed)
	if changelog_bottom_btn and not changelog_bottom_btn.pressed.is_connected(_on_changelog_pressed):
		changelog_bottom_btn.pressed.connect(_on_changelog_pressed)
	if debug_bottom_btn and not debug_bottom_btn.pressed.is_connected(_on_debug_pressed):
		debug_bottom_btn.pressed.connect(_on_debug_pressed)
	if discord_btn and not discord_btn.pressed.is_connected(_on_discord_pressed):
		discord_btn.pressed.connect(_on_discord_pressed)

	# Connect saves bar buttons
	var saves_load_btn = get_node_or_null("CanvasLayer/BottomBarContainer/SavesBar/SavesLoadButton")
	var saves_delete_btn = get_node_or_null("CanvasLayer/BottomBarContainer/SavesBar/SavesDeleteButton")
	var saves_new_btn = get_node_or_null("CanvasLayer/BottomBarContainer/SavesBar/SavesNewButton")
	var saves_favorite_btn = get_node_or_null("CanvasLayer/BottomBarContainer/SavesBar/SavesFavoriteButton")

	if saves_load_btn and not saves_load_btn.pressed.is_connected(_on_saves_load_pressed):
		saves_load_btn.pressed.connect(_on_saves_load_pressed)
	if saves_delete_btn and not saves_delete_btn.pressed.is_connected(_on_saves_delete_pressed):
		saves_delete_btn.pressed.connect(_on_saves_delete_pressed)
	if saves_new_btn and not saves_new_btn.pressed.is_connected(_on_saves_new_pressed):
		saves_new_btn.pressed.connect(_on_saves_new_pressed)
	if saves_favorite_btn and not saves_favorite_btn.pressed.is_connected(_on_saves_favorite_pressed):
		saves_favorite_btn.pressed.connect(_on_saves_favorite_pressed)

func _initialize_tabs():
	var tabs = get_node_or_null("CanvasLayer/TopBarContainer/TopBarCenter/TopButtons")
	if tabs:
		for child in tabs.get_children():
			if child is Button:
				var btn = child as Button
				var hover_callable = Callable(self, "_on_tab_hover").bind(btn)
				if not btn.mouse_entered.is_connected(hover_callable):
					btn.mouse_entered.connect(hover_callable)
				if not btn.mouse_exited.is_connected(_on_tab_hover_exit):
					btn.mouse_exited.connect(_on_tab_hover_exit)
		
		var home_btn = tabs.get_node_or_null("HomeButton")
		if home_btn:
			_set_active_tab(home_btn)
			call_deferred("_ensure_active_tab_underline")

func _on_tab_hover(btn: Button):
	if not _transitioning:
		_update_tab_underline_for_button(btn)

func _on_tab_hover_exit():
	if not _transitioning:
		_ensure_active_tab_underline()

func _ensure_active_tab_underline():
	var active_btn = _get_active_button()
	if active_btn:
		_update_tab_underline_for_button(active_btn)

func _update_tab_underline_for_button(btn: Button) -> void:
	var underline = get_node_or_null("CanvasLayer/TabUnderline")
	if not underline or not btn:
		return
	
	# Place underline using CanvasLayer-local coordinates so it always lines up
	var canvas_layer := underline.get_parent()
	if canvas_layer and canvas_layer is CanvasItem:
		var local_pos: Vector2 = (canvas_layer as CanvasItem).to_local(btn.get_global_position())
		underline.position.x = local_pos.x
		underline.size.x = btn.size.x

func _get_active_button() -> Button:
	var tabs = get_node_or_null("CanvasLayer/TopBarContainer/TopBarCenter/TopButtons")
	if not tabs:
		return null
	
	match current_mode:
		Mode.HOME:
			return tabs.get_node_or_null("HomeButton")
		Mode.CHANGELOG:
			return tabs.get_node_or_null("ChangelogButton")
		Mode.GALLERY:
			return tabs.get_node_or_null("GalleryButton")
		Mode.SETTINGS:
			return tabs.get_node_or_null("SettingsButton")
		Mode.SHIPS:
			return tabs.get_node_or_null("ShipsButton")
		Mode.SAVES:
			return tabs.get_node_or_null("SavesButton")
		Mode.INVENTORY:
			return tabs.get_node_or_null("InventoryButton")
		Mode.SHOP:
			return tabs.get_node_or_null("ShopButton")
		Mode.DEBUG:
			return null
		_:
			return null

func _set_active_tab(btn: Button):
	_transitioning = true
	
	# Hide all panels
	var settings_panel = get_node_or_null("CanvasLayer/SettingsPanel")
	var credits_panel = get_node_or_null("CanvasLayer/CreditsPanel")
	var changelog_panel = get_node_or_null("CanvasLayer/ChangelogPanel")
	var gallery_panel = get_node_or_null("CanvasLayer/GalleryPanel")
	var ship_builder_panel = get_node_or_null("CanvasLayer/ShipBuilderPanel")
	var saves_panel = get_node_or_null("CanvasLayer/SavesPanel")
	var middle = get_node_or_null("CanvasLayer/Middle")
	var right = get_node_or_null("CanvasLayer/Right")
	
	if settings_panel:
		settings_panel.visible = false
	if credits_panel:
		credits_panel.visible = false
	if changelog_panel:
		changelog_panel.visible = false
	if gallery_panel:
		gallery_panel.visible = false
	if ship_builder_panel:
		ship_builder_panel.visible = false
	if saves_panel:
		saves_panel.visible = false
	if middle:
		middle.visible = false
	if right:
		right.visible = false
	# Ensure debug inline panel is hidden when leaving Debug tab
	_hide_debug_panel()
	_hide_inventory_panel()
	_hide_shop_panel()
	_apply_middle_layout_default()
	
	# Show appropriate panel
	if btn.name == "HomeButton":
		current_mode = Mode.HOME
		if middle:
			middle.visible = true
			_restore_middle_children()
		if right:
			right.visible = true
		_update_home_stats_panel()
	elif btn.name == "ChangelogButton":
		current_mode = Mode.CHANGELOG
		if changelog_panel:
			changelog_panel.visible = true
	elif btn.name == "GalleryButton":
		current_mode = Mode.GALLERY
		if gallery_panel:
			gallery_panel.visible = true
	elif btn.name == "SettingsButton":
		current_mode = Mode.SETTINGS
		if settings_panel:
			settings_panel.visible = true
	elif btn.name == "ShipsButton":
		current_mode = Mode.SHIPS
		if ship_builder_panel:
			ship_builder_panel.visible = true
			if _ship_builder:
				_ship_builder.open_panel(_selected_ship)
	elif btn.name == "SavesButton":
		current_mode = Mode.SAVES
		if saves_panel:
			saves_panel.visible = true
	elif btn.name == "InventoryButton":
		current_mode = Mode.INVENTORY
		_apply_middle_layout_full()
		if middle:
			middle.visible = true
		_show_inventory_panel()
	elif btn.name == "ShopButton":
		current_mode = Mode.SHOP
		_apply_middle_layout_full()
		if middle:
			middle.visible = true
		_show_shop_panel()
	elif btn.name == "DebugButton":
		current_mode = Mode.DEBUG
		if middle:
			middle.visible = true
			_show_debug_panel(middle)
	
	_update_bottom_bar_visibility()
	
	_ensure_active_tab_underline()
	_transitioning = false

func _input(event: InputEvent) -> void:
	# Handle screenshot key
	if event is InputEventKey and event.pressed and event.keycode == KEY_F12:
		var screenshot_manager = get_tree().get_first_node_in_group("screenshot_manager")
		if screenshot_manager and screenshot_manager.has_method("take_screenshot"):
			screenshot_manager.take_screenshot()
		
	# Handle debug UI visibility toggle key (F1) - show/hide Debug tab and related UI
	if event is InputEventKey and event.pressed and event.keycode == KEY_F1:
		_debug_ui_enabled = not _debug_ui_enabled
		var debug_btn = _get_button("DebugButton")
		if debug_btn:
			debug_btn.visible = _debug_ui_enabled
			# If we just hid the Debug tab while DebugMenu is open, also hide DebugMenu
			if not _debug_ui_enabled:
				var debug_menu = get_node_or_null("DebugMenu")
				if not debug_menu:
					debug_menu = get_tree().get_first_node_in_group("debug_menu")
				if debug_menu and debug_menu.has_method("toggle_menu") and debug_menu.debug_visible:
					debug_menu.toggle_menu()
		get_viewport().set_input_as_handled()
	
	# Handle ESC key for returning to home
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if current_mode != Mode.HOME and not _transitioning:
			if audio_manager:
				audio_manager.play_button_click()
			_switch_mode(Mode.HOME, _get_button("HomeButton"))
	
	# Handle number keys for quick navigation
	if event is InputEventKey and event.pressed and not _transitioning:
		match event.keycode:
			KEY_1:
				if audio_manager:
					audio_manager.play_button_click()
				_switch_mode(Mode.HOME, _get_button("HomeButton"))
				get_viewport().set_input_as_handled()
			KEY_2:
				if audio_manager:
					audio_manager.play_button_click()
				_switch_mode(Mode.SAVES, _get_button("SavesButton"))
				get_viewport().set_input_as_handled()
			KEY_3:
				if audio_manager:
					audio_manager.play_button_click()
				_switch_mode(Mode.SHIPS, _get_button("ShipsButton"))
				get_viewport().set_input_as_handled()
			KEY_4:
				if audio_manager:
					audio_manager.play_button_click()
				_switch_mode(Mode.GALLERY, _get_button("GalleryButton"))
				get_viewport().set_input_as_handled()
			KEY_5:
				if audio_manager:
					audio_manager.play_button_click()
				_switch_mode(Mode.SETTINGS, _get_button("SettingsButton"))
				get_viewport().set_input_as_handled()
			KEY_6:
				if audio_manager:
					audio_manager.play_button_click()
				_switch_mode(Mode.INVENTORY, _get_button("InventoryButton"))
				get_viewport().set_input_as_handled()
			KEY_7:
				if audio_manager:
					audio_manager.play_button_click()
				_switch_mode(Mode.SHOP, _get_button("ShopButton"))
				get_viewport().set_input_as_handled()

func _on_start_pressed():
	if audio_manager:
		audio_manager.play_button_click()
	GameLog.log_info("Start button pressed - Switching to home mode", "MainMenu")
	_switch_mode(Mode.HOME, _get_button("HomeButton"))

func _on_changelog_pressed():
	if audio_manager:
		audio_manager.play_button_click()
	_switch_mode(Mode.CHANGELOG, _get_button("ChangelogButton"))

func _on_gallery_pressed():
	if audio_manager:
		audio_manager.play_button_click()
	_switch_mode(Mode.GALLERY, _get_button("GalleryButton"))

func _on_settings_pressed():
	if audio_manager:
		audio_manager.play_button_click()
	_switch_mode(Mode.SETTINGS, _get_button("SettingsButton"))

func _on_ships_pressed():
	if audio_manager:
		audio_manager.play_button_click()
	_switch_mode(Mode.SHIPS, _get_button("ShipsButton"))

func _on_saves_pressed():
	if audio_manager:
		audio_manager.play_button_click()
	_switch_mode(Mode.SAVES, _get_button("SavesButton"))

func _on_debug_pressed():
	if audio_manager:
		audio_manager.play_button_click()
	_switch_mode(Mode.DEBUG, _get_button("DebugButton"))
	# Debug tab should behave like other tabs: update middle content without popping overlays

# --- Debug tab inline view ---
func _show_debug_panel(middle: Control) -> void:
	# Hide other middle children to mirror other tabs' behavior
	for child in middle.get_children():
		if child is Control:
			child.visible = false
	
	# Create or reuse inline debug panel
	if not _debug_panel or not is_instance_valid(_debug_panel):
		var panel := PanelContainer.new()
		panel.name = "DebugInlinePanel"
		panel.custom_minimum_size = Vector2(520, 320)
		
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.1, 0.12, 0.16, 0.9)
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_width_top = 2
		style.border_width_bottom = 2
		style.border_color = Color(0.2, 0.7, 1.0, 0.6)
		style.corner_radius_top_left = 10
		style.corner_radius_top_right = 10
		style.corner_radius_bottom_left = 10
		style.corner_radius_bottom_right = 10
		panel.add_theme_stylebox_override("panel", style)
		
		var vbox := VBoxContainer.new()
		vbox.name = "Content"
		vbox.add_theme_constant_override("separation", 10)
		panel.add_child(vbox)
		
		var title := Label.new()
		title.text = "Debug: Inventory Controls"
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_font_size_override("font_size", 20)
		title.add_theme_color_override("font_color", Color(0.8, 0.95, 1.0))
		vbox.add_child(title)
		
		var subtitle := Label.new()
		subtitle.text = "Summon items directly into InventoryState (inline, no popups)."
		subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		subtitle.add_theme_font_size_override("font_size", 12)
		subtitle.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0))
		vbox.add_child(subtitle)
		
		# Controls: quick add buttons
		var section_items := VBoxContainer.new()
		section_items.add_theme_constant_override("separation", 6)
		var items_label := Label.new()
		items_label.text = "Items"
		items_label.add_theme_color_override("font_color", Color(0.65, 0.9, 1.0))
		items_label.add_theme_font_size_override("font_size", 13)
		section_items.add_child(items_label)
		
		var items_row := HBoxContainer.new()
		items_row.add_theme_constant_override("separation", 6)
		items_row.add_child(_create_inv_button("Shield", "Shield"))
		items_row.add_child(_create_inv_button("Surgically Enhanced", "SurgicallyEnhanced"))
		section_items.add_child(items_row)
		vbox.add_child(section_items)
		
		var section_consumables := VBoxContainer.new()
		section_consumables.add_theme_constant_override("separation", 6)
		var cons_label := Label.new()
		cons_label.text = "Consumables"
		cons_label.add_theme_color_override("font_color", Color(0.65, 0.9, 1.0))
		cons_label.add_theme_font_size_override("font_size", 13)
		section_consumables.add_child(cons_label)
		
		var cons_row := HBoxContainer.new()
		cons_row.add_theme_constant_override("separation", 6)
		cons_row.add_child(_create_inv_button("Health Increase", "HealthIncrease", 3))
		cons_row.add_child(_create_inv_button("Orbmaster", "OrbMaster", 1))
		section_consumables.add_child(cons_row)
		vbox.add_child(section_consumables)
		
		var section_weapons := VBoxContainer.new()
		section_weapons.add_theme_constant_override("separation", 6)
		var weap_label := Label.new()
		weap_label.text = "Weapons"
		weap_label.add_theme_color_override("font_color", Color(0.65, 0.9, 1.0))
		weap_label.add_theme_font_size_override("font_size", 13)
		section_weapons.add_child(weap_label)
		
		var weap_row := HBoxContainer.new()
		weap_row.add_theme_constant_override("separation", 6)
		weap_row.add_child(_create_inv_button("Photon Torpedo", "PhotonTorpedo"))
		weap_row.add_child(_create_inv_button("Ballistic Barrage", "BallisticBarrage"))
		section_weapons.add_child(weap_row)
		vbox.add_child(section_weapons)
		
		_debug_panel = panel
		middle.add_child(panel)
	
	_debug_panel.visible = true

# Helpers for inline debug inventory controls
func _create_inv_button(label: String, item_id: String, qty: int = 1) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(120, 28)
	btn.add_theme_font_size_override("font_size", 12)
	btn.pressed.connect(func(): _add_inventory_item(item_id, qty))
	return btn

func _add_inventory_item(item_id: String, qty: int = 1) -> void:
	var tree := get_tree()
	if not tree:
		return
	var inv_state = tree.get_first_node_in_group("inventory")
	if inv_state and inv_state.has_method("add_item_by_id"):
		var success: bool = inv_state.add_item_by_id(item_id, qty)
		if not success:
			push_warning("Debug tab: failed to add item '%s'" % item_id)
	else:
		push_warning("Debug tab: InventoryState not found")

func _hide_debug_panel() -> void:
	if _debug_panel and is_instance_valid(_debug_panel):
		_debug_panel.visible = false

func _restore_middle_children() -> void:
	var middle = get_node_or_null("CanvasLayer/Middle")
	if not middle:
		return
	for child in middle.get_children():
		if child is Control:
			# Keep debug panel hidden by default
			if _debug_panel and child == _debug_panel:
				child.visible = false
			elif _inventory_ui and child == _inventory_ui:
				child.visible = false
			else:
				child.visible = true

func _open_inventory_ui() -> void:
	# Ensure inventory state autoload exists
	var inv_state = get_tree().get_first_node_in_group("inventory")
	if not inv_state:
		push_warning("InventoryState autoload not found; ensure autoload is configured.")
	
	var inv_ui = get_tree().get_first_node_in_group("inventory_ui")
	if not inv_ui and InventoryUIScene:
		inv_ui = InventoryUIScene.instantiate()
		var middle = get_node_or_null("CanvasLayer/Middle")
		if middle:
			middle.add_child(inv_ui)
		else:
			get_tree().root.add_child(inv_ui)
		# Refresh reference after it registers group in _ready
		inv_ui = get_tree().get_first_node_in_group("inventory_ui")
	
	if inv_ui:
		# Force fill parent bounds
		if inv_ui is Control:
			var c := inv_ui as Control
			c.set_anchors_preset(Control.PRESET_FULL_RECT)
			c.offset_left = 0
			c.offset_top = 0
			c.offset_right = 0
			c.offset_bottom = 0
		_inventory_ui = inv_ui
		# Main menu flow: do not pause game when opening
		var pl = inv_ui.get_property_list()
		for prop in pl:
			if typeof(prop) == TYPE_DICTIONARY and prop.get("name", "") == "pause_on_open":
				inv_ui.set("pause_on_open", false)
				break
		# Ensure close reconnect
		if inv_ui.has_signal("close_requested") and not inv_ui.close_requested.is_connected(_on_inventory_closed):
			inv_ui.close_requested.connect(_on_inventory_closed)
		# Hide other middle content and show inventory inline
		var middle = get_node_or_null("CanvasLayer/Middle")
		if middle:
			_apply_middle_layout_full()
			for child in middle.get_children():
				if child is Control:
					child.visible = (child == inv_ui)
		if inv_ui.has_method("open_inventory"):
			inv_ui.open_inventory()
	else:
		push_warning("Failed to create or find InventoryUI")

func _show_settings_saved_notification():
	var info_label = get_node_or_null("CanvasLayer/SettingsPanel/SettingsVBox/SettingsFooter/FooterHBox/SettingsInfo")
	if info_label:
		var original_text = info_label.text
		info_label.text = "✓ Settings Applied!"
		info_label.add_theme_color_override("font_color", Color(0.2, 0.8, 0.2))
		
		await get_tree().create_timer(2.0).timeout
		if info_label and is_instance_valid(info_label):
			info_label.text = original_text
			info_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))

func _get_button(button_name: String) -> Button:
	return get_node_or_null("CanvasLayer/TopBarContainer/TopBarCenter/TopButtons/" + button_name)

func _update_home_stats_panel():
	if not _motd_text:
		return

	var lines: Array[String] = []
	lines.append("[b]Last Save Info:[/b]")

	var save_manager = get_node_or_null("/root/SaveManager")
	var save_data: Dictionary = {}
	if save_manager and save_manager.has_method("get_latest_save_data"):
		save_data = save_manager.get_latest_save_data()

	if not save_data.is_empty():
		lines.append("Save Name: %s" % str(save_data.get("name", "Unknown")))
		var position_value = save_data.get("position", null)
		if position_value is Vector2:
			var pos_vec := position_value as Vector2
			lines.append("Position: (%.0f, %.0f)" % [pos_vec.x, pos_vec.y])
		elif typeof(position_value) == TYPE_DICTIONARY and position_value.has("x") and position_value.has("y"):
			lines.append("Position: (%.0f, %.0f)" % [float(position_value.x), float(position_value.y)])
		else:
			lines.append("Position: Unknown")
		var ship_name: String = str(save_data.get("ship_name", ""))
		if ship_name.is_empty():
			ship_name = str(save_data.get("ship_id", "Unknown Ship"))
		lines.append("Ship: %s" % ship_name)
	else:
		lines.append("No saved runs yet.")
		var gm = get_node_or_null("/root/GameManager")
		if gm and gm.get("player_position") is Vector2:
			var fallback_pos = gm.player_position as Vector2
			lines.append("Current Position: (%.0f, %.0f)" % [fallback_pos.x, fallback_pos.y])

	# Show global coins from EconomySystem autoload (if available)
	var economy_system = get_node_or_null("/root/EconomySystem")
	if economy_system and economy_system.has_method("get_coins"):
		var coins_value: int = int(economy_system.get_coins())
		lines.append("Coins: %d" % coins_value)

	lines.append("\n[i]Tip: Explore the known sectors to find rare loot![/i]")

	_motd_text.clear()
	_motd_text.text = "\n".join(lines)

func _cache_middle_layouts() -> void:
	var middle = get_node_or_null("CanvasLayer/Middle")
	if not middle:
		return
	_middle_layout_default = {
		"anchor_left": middle.anchor_left,
		"anchor_right": middle.anchor_right,
		"anchor_top": middle.anchor_top,
		"anchor_bottom": middle.anchor_bottom,
		"offset_left": middle.offset_left,
		"offset_top": middle.offset_top,
		"offset_right": middle.offset_right,
		"offset_bottom": middle.offset_bottom,
	}
	_middle_layout_full = {
		"anchor_left": 0.0,
		"anchor_right": 1.0,
		"anchor_top": middle.anchor_top,
		"anchor_bottom": middle.anchor_bottom,
		"offset_left": 16.0,
		"offset_top": middle.offset_top,
		"offset_right": -16.0,
		"offset_bottom": middle.offset_bottom,
	}

func _apply_middle_layout(layout: Dictionary) -> void:
	var middle = get_node_or_null("CanvasLayer/Middle")
	if not middle or layout.is_empty():
		return
	middle.anchor_left = float(layout.get("anchor_left", middle.anchor_left))
	middle.anchor_right = float(layout.get("anchor_right", middle.anchor_right))
	middle.anchor_top = float(layout.get("anchor_top", middle.anchor_top))
	middle.anchor_bottom = float(layout.get("anchor_bottom", middle.anchor_bottom))
	middle.offset_left = float(layout.get("offset_left", middle.offset_left))
	middle.offset_top = float(layout.get("offset_top", middle.offset_top))
	middle.offset_right = float(layout.get("offset_right", middle.offset_right))
	middle.offset_bottom = float(layout.get("offset_bottom", middle.offset_bottom))

func _apply_middle_layout_default() -> void:
	if _middle_layout_default.is_empty():
		_cache_middle_layouts()
	_apply_middle_layout(_middle_layout_default)

func _apply_middle_layout_full() -> void:
	if _middle_layout_full.is_empty():
		_cache_middle_layouts()
	_apply_middle_layout(_middle_layout_full)

func _hide_inventory_panel() -> void:
	if _inventory_ui and is_instance_valid(_inventory_ui):
		_inventory_ui.visible = false

func _hide_shop_panel() -> void:
	"""Hide and clean up shop panel"""
	var middle = get_node_or_null("CanvasLayer/Middle")
	if middle:
		var shop_panel = middle.get_node_or_null("ShopPanel")
		if shop_panel and is_instance_valid(shop_panel):
			shop_panel.queue_free()

func _show_inventory_panel() -> void:
	_open_inventory_ui()

func _on_inventory_closed() -> void:
	if _inventory_ui and is_instance_valid(_inventory_ui):
		_inventory_ui.visible = false
	_apply_middle_layout_default()
	_restore_middle_children()

func _on_inventory_pressed() -> void:
	if audio_manager:
		audio_manager.play_button_click()
	_switch_mode(Mode.INVENTORY, _get_button("InventoryButton"))

func _on_shop_pressed() -> void:
	if audio_manager:
		audio_manager.play_button_click()
	_switch_mode(Mode.SHOP, _get_button("ShopButton"))

func _show_shop_panel() -> void:
	"""Show the shop panel in the middle layout"""
	# Clear middle container first
	var middle = get_node_or_null("CanvasLayer/Middle")
	if not middle:
		return
	
	# Remove existing children
	for child in middle.get_children():
		child.queue_free()
	
	# Instance the shop panel scene
	var shop_scene = preload("res://scenes/ShopPanel.tscn")
	var shop_panel = shop_scene.instantiate()
	shop_panel.name = "ShopPanel"
	middle.add_child(shop_panel)

func _on_quit_pressed() -> void:
	if audio_manager:
		audio_manager.play_button_click()
	GameLog.log_system("Quit button pressed - Exiting game")
	get_tree().quit()

func _on_settings_back_pressed() -> void:
	_switch_mode(Mode.HOME, _get_button("HomeButton"))

func _on_new_game_pressed() -> void:
	if audio_manager:
		audio_manager.play_button_click()
	
	# Check for existing saves and show confirmation dialog if needed
	var save_manager = get_node_or_null("/root/SaveManager")
	if save_manager and save_manager.has_any_saves():
		_show_new_game_confirmation()
	else:
		# No saves exist, proceed directly to ship selection
		_switch_mode(Mode.SHIPS, _get_button("ShipsButton"))

func _show_new_game_confirmation():
	"""Show confirmation dialog when saves exist and user wants to start new game"""
	# Create a simple confirmation dialog
	var dialog = AcceptDialog.new()
	dialog.title = "New Game"
	dialog.dialog_text = "Existing save files found. Starting a new game will not delete your saves, but you'll start fresh. Continue?"
	
	# Add buttons
	dialog.add_button("Cancel", false, "cancel")
	dialog.get_ok_button().text = "Start New Game"
	
	# Connect signals
	dialog.confirmed.connect(_on_new_game_confirmed)
	dialog.canceled.connect(_on_new_game_cancelled)
	
	# Add to scene and show
	add_child(dialog)
	dialog.popup_centered()

func _on_new_game_confirmed():
	"""User confirmed new game - proceed to ship selection"""
	_switch_mode(Mode.SHIPS, _get_button("ShipsButton"))

func _on_new_game_cancelled():
	"""User cancelled new game - stay on home tab"""
	GameLog.log_info("New Game cancelled by user", "MainMenu")

func _on_continue_pressed() -> void:
	if audio_manager:
		audio_manager.play_button_click()
	GameLog.log_info("Continue button pressed - Loading latest save", "MainMenu")
	
	# Try to load the latest save before starting the game
	var save_manager = get_node_or_null("/root/SaveManager")
	if save_manager and save_manager.has_any_saves():
		var latest_save = save_manager.load_latest()
		if latest_save.has("success") and latest_save.success:
			GameLog.log_info("Latest save loaded successfully", "MainMenu")
		else:
			GameLog.log_warning("Failed to load latest save, starting fresh game", "MainMenu")
	else:
		GameLog.log_info("No saves found, starting fresh game", "MainMenu")
	
	# Start the game by transitioning to Main scene
	get_tree().change_scene_to_packed(gameplay_scene)

func _on_discord_pressed() -> void:
	if audio_manager:
		audio_manager.play_button_click()
	OS.shell_open("https://discord.gg/CKMQaCQKat")

func _on_ship_start_game_requested(ship_id: String) -> void:
	"""Handle start game request from ship builder"""
	if audio_manager:
		audio_manager.play_button_click()
	GameLog.log_info("Start game requested with ship: " + ship_id, "MainMenu")
	
	# Store selected ship in GameState if available
	var game_state = get_node_or_null("/root/GameState")
	if game_state and game_state.has_method("set_selected_ship"):
		# Get full ship data from ship builder
		if _ship_builder and _ship_builder.has_method("get_ship_info"):
			var ship_info = _ship_builder.get_ship_info(ship_id)
			if not ship_info.is_empty():
				game_state.set_selected_ship(
					ship_id,
					ship_info.get("name", ""),
					ship_info.get("texture", ""),
					ship_info.get("type", "")
				)
			else:
				game_state.set_selected_ship(ship_id)
		else:
			game_state.set_selected_ship(ship_id)
	
	# Start the game by transitioning to Main scene
	get_tree().change_scene_to_packed(gameplay_scene)

func _on_saves_load_pressed() -> void:
	if audio_manager:
		audio_manager.play_button_click()
	var saves_panel = get_node_or_null("CanvasLayer/SavesPanel")
	if saves_panel and saves_panel.has_method("_on_load_selected_pressed"):
		saves_panel._on_load_selected_pressed()

func _on_saves_delete_pressed() -> void:
	if audio_manager:
		audio_manager.play_button_click()
	var saves_panel = get_node_or_null("CanvasLayer/SavesPanel")
	if saves_panel and saves_panel.has_method("_on_delete_selected_pressed"):
		saves_panel._on_delete_selected_pressed()

func _on_saves_new_pressed() -> void:
	if audio_manager:
		audio_manager.play_button_click()
	# Navigate to ships tab to start a new game
	_switch_mode(Mode.SHIPS, _get_button("ShipsButton"))

func _on_saves_favorite_pressed() -> void:
	if audio_manager:
		audio_manager.play_button_click()
	var saves_panel = get_node_or_null("CanvasLayer/SavesPanel")
	if saves_panel and saves_panel.has_method("_on_favorite_toggled_bar"):
		saves_panel._on_favorite_toggled_bar()

func _update_saves_bar_states() -> void:
	"""Update saves bar button disabled states and text based on selection"""
	var saves_panel = get_node_or_null("CanvasLayer/SavesPanel")
	var has_selection := false
	var is_favorite := false
	if saves_panel and saves_panel.has_method("get_selected_save_id"):
		var selected_id: String = saves_panel.get_selected_save_id()
		has_selection = not selected_id.is_empty()
		# Check if selected save is favorite
		if has_selection:
			var save_manager = get_node_or_null("/root/SaveManager")
			if save_manager and save_manager.has_method("get_save_data"):
				var save_data = save_manager.get_save_data(selected_id)
				is_favorite = save_data.get("favorite", false)
	
	var saves_load_btn = get_node_or_null("CanvasLayer/BottomBarContainer/SavesBar/SavesLoadButton")
	var saves_delete_btn = get_node_or_null("CanvasLayer/BottomBarContainer/SavesBar/SavesDeleteButton")
	var saves_favorite_btn = get_node_or_null("CanvasLayer/BottomBarContainer/SavesBar/SavesFavoriteButton")
	
	if saves_load_btn:
		saves_load_btn.disabled = not has_selection
	if saves_delete_btn:
		saves_delete_btn.disabled = not has_selection
	if saves_favorite_btn:
		saves_favorite_btn.disabled = not has_selection
		if has_selection:
			saves_favorite_btn.text = "Unfavorite" if is_favorite else "Favorite"
		else:
			saves_favorite_btn.text = "Favorite"

func _ensure_ship_builder_ready() -> void:
	if _ship_builder and is_instance_valid(_ship_builder):
		return
	_ship_builder = get_node_or_null("CanvasLayer/ShipBuilderPanel")
	if _ship_builder and not _ship_builder.start_game_requested.is_connected(_on_ship_start_game_requested):
		_ship_builder.start_game_requested.connect(_on_ship_start_game_requested)
