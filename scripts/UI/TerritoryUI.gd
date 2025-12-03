extends Control

class_name TerritoryUI

var territory_manager: TerritoryManager
var faction_manager: FactionManager
var player: Node2D

@onready var territory_label: Label = $VBoxContainer/TerritoryLabel
@onready var faction_label: Label = $VBoxContainer/FactionLabel
@onready var threat_label: Label = $VBoxContainer/ThreatLabel
@onready var faction_color_rect: ColorRect = $VBoxContainer/FactionColorRect

var update_interval: float = 1.0
var update_timer: float = 0.0

func _ready():
	add_to_group("territory_ui")
	
	# Wait a frame for other managers to be ready
	await get_tree().process_frame
	
	# Get system references
	territory_manager = get_tree().get_first_node_in_group("territory_manager")
	faction_manager = get_tree().get_first_node_in_group("faction_manager")
	player = get_tree().get_first_node_in_group("player")
	
	if not territory_manager or not faction_manager:
		push_error("TerritoryUI: Required managers not found!")
		visible = false
		return
	
	# Position UI in top-left corner
	anchors_preset = Control.PRESET_TOP_LEFT
	offset_left = 20
	offset_top = 150
	size = Vector2(250, 100)
	
	# Style the panel
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	style_box.border_width_left = 2
	style_box.border_width_right = 2
	style_box.border_width_top = 2
	style_box.border_width_bottom = 2
	style_box.border_color = Color(0.6, 0.6, 0.6, 0.8)
	style_box.corner_radius_top_left = 8
	style_box.corner_radius_top_right = 8
	style_box.corner_radius_bottom_left = 8
	style_box.corner_radius_bottom_right = 8
	add_theme_stylebox_override("panel", style_box)
	
	print("TerritoryUI: Initialized")

func _process(delta):
	update_timer += delta
	if update_timer >= update_interval:
		update_timer = 0.0
		_update_territory_info()

func _update_territory_info():
	if not player:
		return
	
	var territory = territory_manager.get_territory_at_position(player.global_position)
	
	if territory.is_empty():
		territory_label.text = "Unknown Territory"
		faction_label.text = "No Faction"
		threat_label.text = "Threat: --"
		faction_color_rect.color = Color.GRAY
		return
	
	var territory_id = territory.get("id", "Unknown")
	var faction_id = territory.get("faction", FactionManager.FACTION_NEUTRAL)
	var threat_level = territory.get("threat_level", 0)
	
	territory_label.text = "Territory: " + territory_id
	faction_label.text = "Faction: " + faction_manager.get_faction_name(faction_id)
	threat_label.text = "Threat Level: " + str(threat_level)
	faction_color_rect.color = faction_manager.get_faction_color(faction_id)
	
	# Color code threat level
	match threat_level:
		0:
			threat_label.add_theme_color_override("font_color", Color.GREEN)
		1:
			threat_label.add_theme_color_override("font_color", Color.YELLOW)
		2:
			threat_label.add_theme_color_override("font_color", Color.ORANGE)
		_:
			threat_label.add_theme_color_override("font_color", Color.RED)
