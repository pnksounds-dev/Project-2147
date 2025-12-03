extends Control

class_name GameSystemDoc

## GameSystemDoc - Real-time game system documentation viewer
## Provides statistics and information about all major game systems
## Press F1 to toggle visibility

@export var refresh_rate: float = 0.5  # Update every 0.5 seconds
@export var default_visible: bool = false  # Start hidden

var _refresh_timer: float = 0.0
var _player: Node2D
var _camera: Camera2D
var _ark: Node2D
var _territory_manager: Node
var _territory_spawner: Node
var _enemy_spawner: Node
var _map_tracker: Node
var _background_renderer: Node

# UI Elements - will be set in _create_ui()
var _category_list: ItemList
var _content_label: RichTextLabel
var _refresh_button: Button
var _auto_refresh_checkbox: CheckBox

# Categories
enum Category {
	PLAYER_STATS,
	CAMERA_SYSTEM,
	ARK_SYSTEM,
	TERRITORY_SYSTEM,
	SPWANER_SYSTEMS,
	MAP_TRACKING,
	BACKGROUND_SYSTEM,
	PERFORMANCE_STATS
}

func _ready() -> void:
	name = "GameSystemDoc"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Start hidden by default
	visible = default_visible
	
	# Create UI layout first
	_create_ui()
	
	# Connect signals
	_connect_signals()
	
	# Populate categories
	_populate_categories()
	
	# Wait a bit before selecting first category
	call_deferred("_select_first_category")
	
	print("GameSystemDoc: Documentation panel ready (press F12 to toggle)")

func _select_first_category() -> void:
	# Select first category by default
	if _category_list and _category_list.get_item_count() > 0:
		_category_list.select(0)
		_on_category_selected(0)  # Use index directly instead of get_item_index

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F12:  # Changed from F1 to F12 to avoid conflict
			visible = not visible
			print("GameSystemDoc: Toggled visibility to: ", visible)

func _create_ui() -> void:
	# Header
	var header_container = HBoxContainer.new()
	header_container.name = "HeaderContainer"
	add_child(header_container)
	header_container.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	header_container.custom_minimum_size.y = 40
	
	var title_label = Label.new()
	title_label.text = "Game System Documentation (F12 to toggle)"
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	header_container.add_child(title_label)
	
	# Add spacer
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_container.add_child(spacer)
	
	# Close button
	var close_button = Button.new()
	close_button.text = "Close (F1)"
	close_button.size.x = 100
	header_container.add_child(close_button)
	close_button.pressed.connect(func(): visible = false)
	
	# Refresh button
	_refresh_button = Button.new()
	_refresh_button.text = "Refresh"
	_refresh_button.size.x = 80
	header_container.add_child(_refresh_button)
	
	# Auto refresh checkbox
	_auto_refresh_checkbox = CheckBox.new()
	_auto_refresh_checkbox.text = "Auto Refresh"
	_auto_refresh_checkbox.button_pressed = true
	header_container.add_child(_auto_refresh_checkbox)
	
	# Main container
	var hsplit = HSplitContainer.new()
	hsplit.name = "HSplitContainer"
	add_child(hsplit)
	hsplit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hsplit.offset_top = 40
	
	# Category list
	_category_list = ItemList.new()
	_category_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hsplit.add_child(_category_list)
	
	# Content area
	var content_scroll = ScrollContainer.new()
	content_scroll.name = "ContentScroll"
	content_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hsplit.add_child(content_scroll)
	
	_content_label = RichTextLabel.new()
	_content_label.name = "ContentLabel"
	_content_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_label.bbcode_enabled = true
	_content_label.text = "Select a category to view documentation..."
	content_scroll.add_child(_content_label)
	
	# Style the panel
	_apply_styling()

func _apply_styling() -> void:
	# Dark theme for better visibility
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.1, 0.1, 0.15, 0.9)
	style_box.border_width_left = 2
	style_box.border_width_right = 2
	style_box.border_width_top = 2
	style_box.border_width_bottom = 2
	style_box.border_color = Color(0.3, 0.3, 0.4)
	style_box.corner_radius_top_left = 8
	style_box.corner_radius_top_right = 8
	style_box.corner_radius_bottom_left = 8
	style_box.corner_radius_bottom_right = 8
	
	add_theme_stylebox_override("panel", style_box)
	
	# Style content label
	var content_style = StyleBoxFlat.new()
	content_style.bg_color = Color(0.05, 0.05, 0.1, 0.8)
	content_style.border_width_left = 1
	content_style.border_width_right = 1
	content_style.border_width_top = 1
	content_style.border_width_bottom = 1
	content_style.border_color = Color(0.2, 0.2, 0.3)
	
	_content_label.add_theme_stylebox_override("normal", content_style)

func _connect_signals() -> void:
	_category_list.item_selected.connect(_on_category_selected)
	_refresh_button.pressed.connect(_refresh_all_data)
	_auto_refresh_checkbox.toggled.connect(_on_auto_refresh_toggled)

func _populate_categories() -> void:
	var categories = [
		"Player Stats & Health",
		"Camera System & Zoom",
		"Ark System & Motherships", 
		"Territory System",
		"Spawner Systems",
		"Map Tracking",
		"Background System",
		"Performance Stats"
	]
	
	for category in categories:
		_category_list.add_item(category)

func _on_category_selected(index: int) -> void:
	match index:
		Category.PLAYER_STATS:
			_display_player_stats()
		Category.CAMERA_SYSTEM:
			_display_camera_system()
		Category.ARK_SYSTEM:
			_display_ark_system()
		Category.TERRITORY_SYSTEM:
			_display_territory_system()
		Category.SPWANER_SYSTEMS:
			_display_spawner_systems()
		Category.MAP_TRACKING:
			_display_map_tracking()
		Category.BACKGROUND_SYSTEM:
			_display_background_system()
		Category.PERFORMANCE_STATS:
			_display_performance_stats()

func _display_player_stats() -> void:
	var content = "[b][color=cyan]Player Statistics[/color][/b]\n\n"
	
	if not _player:
		_player = get_tree().get_first_node_in_group("player")
	
	if _player:
		content += "[color=white]Health System:[/color]\n"
		var current_health = _player.get("current_health") if "current_health" in _player else null
		var max_health = _player.get("max_health") if "max_health" in _player else null
		content += "• Current Health: " + str(current_health) + "\n"
		content += "• Max Health: " + str(max_health) + "\n"
		
		if current_health != null and max_health != null and max_health > 0:
			var health_percentage = (current_health / max_health) * 100.0
			content += "• Health Percentage: " + str(health_percentage) + "%\n"
		else:
			content += "• Health Percentage: N/A\n"
			
		content += "• Is Dead: " + str(_player.get("is_dead") if "is_dead" in _player else "N/A") + "\n\n"
		
		content += "[color=white]Experience System:[/color]\n"
		content += "• Current Level: " + str(_player.get("level") if "level" in _player else "N/A") + "\n"
		content += "• Current XP: " + str(_player.get("current_xp") if "current_xp" in _player else "N/A") + "\n"
		content += "• XP Required: " + str(_player.get("xp_required") if "xp_required" in _player else "N/A") + "\n\n"
		
		content += "[color=white]Movement Stats:[/color]\n"
		content += "• Speed: " + str(_player.get("speed") if "speed" in _player else "N/A") + "\n"
		content += "• Acceleration: " + str(_player.get("acceleration") if "acceleration" in _player else "N/A") + "\n"
		content += "• Friction: " + str(_player.get("friction") if "friction" in _player else "N/A") + "\n"
		content += "• Fire Rate: " + str(_player.get("fire_rate") if "fire_rate" in _player else "N/A") + "\n\n"
		
		content += "[color=white]Position & State:[/color]\n"
		content += "• Global Position: " + str(_player.global_position) + "\n"
		content += "• Velocity: " + str(_player.get("velocity") if "velocity" in _player else "N/A") + "\n"
	else:
		content += "[color=yellow]Player node not found in scene![/color]\n"
		content += "• Player group size: " + str(get_tree().get_nodes_in_group("player").size()) + "\n"
		content += "• Scene tree nodes: " + str(get_tree().get_node_count()) + "\n"
	
	_content_label.text = content

func _display_camera_system() -> void:
	var content = "[b][color=cyan]Camera System Information[/color][/b]\n\n"
	
	if not _player:
		_player = get_tree().get_first_node_in_group("player")
	
	if _player:
		_camera = _player.get_node_or_null("Camera2D")
	
	if _camera:
		content += "[color=white]Camera Properties:[/color]\n"
		content += "• Camera Enabled: " + str(_camera.enabled) + "\n"
		content += "• Zoom Level: " + str(_camera.zoom) + "\n"
		content += "• Position: " + str(_camera.global_position) + "\n"
		content += "• Rotation: " + str(_camera.rotation_degrees) + "°\n\n"
		
		content += "[color=white]Field of View:[/color]\n"
		content += "• Viewport Size: " + str(get_viewport().get_visible_rect().size) + "\n"
		content += "• Effective FOV: " + str(_calculate_effective_fov()) + " pixels\n"
		content += "• Zoom Factor: " + str(_camera.zoom.x) + "x\n\n"
		
		content += "[color=white]Camera Groups:[/color]\n"
		var groups = _camera.get_groups()
		for group in groups:
			content += "• " + group + "\n"
	else:
		content += "[color=red]Camera not found![/color]"
	
	_content_label.text = content

func _display_ark_system() -> void:
	var content = "[b][color=cyan]Ark System Information[/color][/b]\n\n"
	
	if not _ark:
		_ark = get_tree().get_first_node_in_group("ark_ships")
	
	if _ark:
		content += "[color=white]Ark Properties:[/color]\n"
		content += "• Position: " + str(_ark.global_position) + "\n"
		content += "• Home Position: " + str(_ark.get("home_position") if "home_position" in _ark else "N/A") + "\n"
		content += "• Rotation Speed: " + str(_ark.get("rotation_speed") if "rotation_speed" in _ark else "N/A") + "\n"
		content += "• Z-Index: " + str(_ark.z_index) + "\n"
		content += "• Visible: " + str(_ark.visible) + "\n\n"
		
		content += "[color=white]Mothership Spawning:[/color]\n"
		content += "• Max Motherships: " + str(_ark.get("max_motherships") if "max_motherships" in _ark else "N/A") + "\n"
		content += "• Spawn Interval: " + str(_ark.get("spawn_interval") if "spawn_interval" in _ark else "N/A") + "s\n"
		
		var spawned_motherships = _ark.get("_spawned_motherships") if "_spawned_motherships" in _ark else []
		content += "• Current Motherships: " + str(spawned_motherships.size()) + "\n"
		content += "• Spawn Timer: " + str(_ark.get("_spawn_timer") if "_spawn_timer" in _ark else "N/A") + "s\n\n"
		
		content += "[color=white]Active Motherships:[/color]\n"
		for i in range(spawned_motherships.size()):
			var mothership = spawned_motherships[i]
			if is_instance_valid(mothership):
				content += "• Mothership " + str(i+1) + ": Pos=" + str(mothership.global_position) + "\n"
	else:
		content += "[color=red]Ark not found![/color]"
	
	_content_label.text = content

func _display_territory_system() -> void:
	var content = "[b][color=cyan]Territory System Information[/color][/b]\n\n"
	
	if not _territory_manager:
		_territory_manager = get_tree().get_first_node_in_group("territory_manager")
	
	if _territory_manager:
		content += "[color=white]Territory Manager:[/color]\n"
		content += "• Chunk Size: " + str(_territory_manager.get("chunk_size") if "chunk_size" in _territory_manager else "N/A") + "\n"
		
		var territories = _territory_manager.get("territories") if "territories" in _territory_manager else []
		content += "• Total Territories: " + str(territories.size()) + "\n\n"
		
		content += "[color=white]Territory Details:[/color]\n"
		for i in range(min(territories.size(), 5)):  # Show first 5 territories
			var territory = territories[i]
			content += "• " + territory.get("id", "Unknown") + "\n"
			content += "  - Faction: " + str(territory.get("faction", "Unknown")) + "\n"
			content += "  - Center: " + str(territory.get("center", "N/A")) + "\n"
			content += "  - Radius: " + str(territory.get("radius", "N/A")) + "\n"
			content += "  - Threat Level: " + str(territory.get("threat_level", "N/A")) + "\n\n"
	else:
		content += "[color=red]Territory Manager not found![/color]"
	
	_content_label.text = content

func _display_spawner_systems() -> void:
	var content = "[b][color=cyan]Spawner Systems Information[/color][/b]\n\n"
	
	# Enemy Spawner
	if not _enemy_spawner:
		_enemy_spawner = get_tree().get_first_node_in_group("enemy_spawner")
	
	if _enemy_spawner:
		content += "[color=white]Enemy Spawner:[/color]\n"
		content += "• Position: " + str(_enemy_spawner.global_position) + "\n"
		content += "• Spawn Radius: " + str(_enemy_spawner.get("spawn_radius") if "spawn_radius" in _enemy_spawner else "N/A") + "\n"
		content += "• Max Enemies: " + str(_enemy_spawner.get("max_enemies") if "max_enemies" in _enemy_spawner else "N/A") + "\n\n"
	
	# Territory Spawner
	if not _territory_spawner:
		_territory_spawner = get_tree().get_first_node_in_group("territory_spawner")
	
	if _territory_spawner:
		content += "[color=white]Territory Spawner:[/color]\n"
		content += "• Spawn Interval: " + str(_territory_spawner.get("spawn_interval") if "spawn_interval" in _territory_spawner else "N/A") + "s\n"
		content += "• Max Entities Per Chunk: " + str(_territory_spawner.get("max_entities_per_chunk") if "max_entities_per_chunk" in _territory_spawner else "N/A") + "\n"
		content += "• Active Chunks: " + str(_territory_spawner.get("_active_chunks") if "_active_chunks" in _territory_spawner else "N/A") + "\n\n"
	
	# Count current enemies
	var enemies = get_tree().get_nodes_in_group("enemy")
	content += "[color=white]Current Entity Counts:[/color]\n"
	content += "• Total Enemies: " + str(enemies.size()) + "\n"
	
	var player_faction = get_tree().get_nodes_in_group("player_faction")
	content += "• Player Faction Units: " + str(player_faction.size()) + "\n"
	
	var motherships = get_tree().get_nodes_in_group("motherships")
	content += "• Motherships: " + str(motherships.size()) + "\n"
	
	var scouts = get_tree().get_nodes_in_group("scout")
	content += "• Scouts: " + str(scouts.size()) + "\n"
	
	_content_label.text = content

func _display_map_tracking() -> void:
	var content = "[b][color=cyan]Map Tracking Information[/color][/b]\n\n"
	
	if not _map_tracker:
		_map_tracker = get_tree().get_first_node_in_group("map_tracker")
	
	if _map_tracker:
		content += "[color=white]Map Tracker Properties:[/color]\n"
		content += "• Tracking Radius: " + str(_map_tracker.get("tracking_radius") if "tracking_radius" in _map_tracker else "N/A") + "\n"
		content += "• Update Interval: " + str(_map_tracker.get("update_interval") if "update_interval" in _map_tracker else "N/A") + "s\n"
		
		var tracked_entities = _map_tracker.get("_tracked_entities") if "_tracked_entities" in _map_tracker else {}
		content += "• Tracked Entities: " + str(tracked_entities.size()) + "\n\n"
		
		content += "[color=white]Tracked Entity Types:[/color]\n"
		var type_counts = {}
		for entity_id in tracked_entities:
			var entity_data = tracked_entities[entity_id]
			var type = entity_data.get("type", "unknown")
			type_counts[type] = type_counts.get(type, 0) + 1
		
		for type in type_counts:
			content += "• " + type + ": " + str(type_counts[type]) + "\n"
		
		content += "\n[color=white]Map Lines Being Drawn:[/color]\n"
		content += "• Entity Indicators: " + str(tracked_entities.size()) + "\n"
		content += "• Range Circles: " + str(1 if _map_tracker else 0) + "\n"
		content += "• Player Indicator: " + str(1 if get_tree().get_first_node_in_group("player") else 0) + "\n"
	else:
		content += "[color=red]Map Tracker not found![/color]"
	
	_content_label.text = content

func _display_background_system() -> void:
	var content = "[b][color=cyan]Background System Information[/color][/b]\n\n"
	
	# Background Renderer
	if not _background_renderer:
		_background_renderer = get_tree().get_first_node_in_group("background_renderer")
	
	if _background_renderer:
		content += "[color=white]Background Renderer:[/color]\n"
		content += "• Ultra HD Enabled: " + str(_background_renderer.get("ultra_hd_enabled") if "ultra_hd_enabled" in _background_renderer else "N/A") + "\n"
		content += "• Layer: " + str(_background_renderer.layer) + "\n"
		content += "• ColorRect Visible: " + str(_background_renderer.get_node_or_null("ColorRect").visible if _background_renderer.get_node_or_null("ColorRect") else "N/A") + "\n\n"
	
	# Dynamic Background
	var dynamic_bg = get_tree().get_first_node_in_group("parallax_bg")
	if dynamic_bg:
		content += "[color=white]Dynamic Background:[/color]\n"
		content += "• Texture Scale Factor: " + str(dynamic_bg.get("texture_scale_factor") if "texture_scale_factor" in dynamic_bg else "N/A") + "\n"
		content += "• Zoom Scale Multiplier: " + str(dynamic_bg.get("zoom_scale_multiplier") if "zoom_scale_multiplier" in dynamic_bg else "N/A") + "\n"
		content += "• Base Texture Size: " + str(dynamic_bg.get("base_texture_size") if "base_texture_size" in dynamic_bg else "N/A") + "\n"
		
		var sprite = dynamic_bg.get_node_or_null("ParallaxLayer/Sprite2D")
		if sprite:
			content += "• Current Region Size: " + str(sprite.region_rect.size) + "\n"
			content += "• Texture Repeating: " + str(sprite.texture_repeat) + "\n"
	else:
		content += "[color=red]Background systems not found![/color]"
	
	_content_label.text = content

func _display_performance_stats() -> void:
	var content = "[b][color=cyan]Performance Statistics[/color][/b]\n\n"
	
	content += "[color=white]Engine Stats:[/color]\n"
	content += "• FPS: " + str(Engine.get_frames_per_second()) + "\n"
	content += "• Frame Count: " + str(Engine.get_frames_drawn()) + "\n"
	content += "• Physics FPS: " + str(Engine.physics_ticks_per_second) + "\n"
	content += "• Time Scale: " + str(Engine.time_scale) + "\n\n"
	
	content += "[color=white]Memory Stats:[/color]\n"
	content += "• Memory Usage: Check OS.get_static_memory_usage() for details\n"
	content += "• Dynamic Memory: " + str(OS.get_static_memory_usage()) + " bytes\n\n"
	
	content += "[color=white]Scene Stats:[/color]\n"
	content += "• Total Nodes: " + str(get_tree().get_node_count()) + "\n"
	
	var main_scene = get_tree().current_scene
	if main_scene:
		content += "• Main Scene Children: " + str(main_scene.get_child_count()) + "\n"
	
	content += "\n[color=white]Group Statistics:[/color]\n"
	var groups = ["player", "enemy", "ark_ships", "player_faction", "motherships", "scout", "territory_manager", "chunk_manager", "map_tracker"]
	for group in groups:
		var nodes = get_tree().get_nodes_in_group(group)
		content += "• " + group + ": " + str(nodes.size()) + " nodes\n"
	
	_content_label.text = content

# Helper functions
func _calculate_health_percentage() -> float:
	if not _player:
		return 0.0
	
	var current = _player.get("current_health") if "current_health" in _player else 0.0
	var max_hp = _player.get("max_health") if "max_health" in _player else 1.0
	
	if max_hp <= 0:
		return 0.0
	
	return (current / max_hp) * 100.0

func _calculate_effective_fov() -> float:
	if not _camera:
		return 0.0
	
	var viewport_size = get_viewport().get_visible_rect().size
	var zoom = _camera.zoom.x
	
	return viewport_size.x / zoom

func _refresh_all_data() -> void:
	var current_category = _category_list.get_selected_items()
	if current_category.size() > 0:
		_on_category_selected(current_category[0])

func _on_auto_refresh_toggled(enabled: bool) -> void:
	set_process(enabled)

func _process(delta: float) -> void:
	if not _auto_refresh_checkbox.button_pressed:
		return
	
	_refresh_timer += delta
	if _refresh_timer >= refresh_rate:
		_refresh_timer = 0.0
		_refresh_all_data()

# Public method to open the documentation panel
static func open_in_scene(parent: Node) -> GameSystemDoc:
	var doc = preload("res://scripts/GameSystemDoc.gd").new()
	parent.add_child(doc)
	return doc
