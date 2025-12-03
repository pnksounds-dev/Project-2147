extends Control

class_name ShopPanel

## ShopPanel - Displays random buffed items with coin prices in main menu

@onready var grid_container: GridContainer = $ScrollContainer/GridContainer if has_node("ScrollContainer/GridContainer") else null
@onready var coming_soon_label: Label = $ComingSoonLabel if has_node("ComingSoonLabel") else null

# Audio manager reference
var audio_manager

# Shop item data
var shop_items: Array[Dictionary] = []

func _ready():
	add_to_group("shop_panel")
	
	# Get audio manager
	audio_manager = get_node_or_null("/root/AudioManager")
	
	# Generate shop items
	_generate_shop_items()
	
	# Create shop slots
	_create_shop_slots()

func _generate_shop_items():
	"""Generate specific items for the shop"""
	var specific_items = [
		{"name": "Enhanced Phaser", "type": "weapon", "base_price": 150, "icon": "🔫"},
		{"name": "Plasma Cannon", "type": "weapon", "base_price": 200, "icon": "💥"},
		{"name": "Quantum Torpedo", "type": "weapon", "base_price": 300, "icon": "🎯"},
		{"name": "Shield Booster", "type": "upgrade", "base_price": 120, "icon": "🛡️"},
		{"name": "Speed Engine", "type": "upgrade", "base_price": 100, "icon": "⚡"},
		{"name": "Damage Amplifier", "type": "upgrade", "base_price": 180, "icon": "💪"},
		{"name": "Health Pack", "type": "consumable", "base_price": 25, "icon": "💚"},
		{"name": "Energy Cell", "type": "consumable", "base_price": 30, "icon": "🔋"},
		{"name": "Repair Drone", "type": "consumable", "base_price": 50, "icon": "🤖"},
		{"name": "Lucky Charm", "type": "special", "base_price": 500, "icon": "🍀"},
		{"name": "Time Crystal", "type": "special", "base_price": 750, "icon": "⏰"},
		{"name": "Void Essence", "type": "special", "base_price": 1000, "icon": "🌌"}
	]
	
	# Generate items with buffs for the shop
	shop_items.clear()
	for i in range(specific_items.size()):
		var base_item = specific_items[i]
		var buff_multiplier = randf_range(1.2, 2.5)  # 20% to 150% buff
		var buffed_price = int(base_item.base_price * buff_multiplier)
		
		var item_data = {
			"name": base_item.name,
			"type": base_item.type,
			"icon": base_item.icon,
			"base_price": base_item.base_price,
			"buff_multiplier": buff_multiplier,
			"buffed_price": buffed_price,
			"buff_description": _get_buff_description(buff_multiplier),
			"slot_index": i
		}
		
		shop_items.append(item_data)

func _get_buff_description(multiplier: float) -> String:
	"""Generate a description based on the buff multiplier"""
	if multiplier < 1.4:
		return "Slightly Enhanced"
	elif multiplier < 1.7:
		return "Enhanced"
	elif multiplier < 2.0:
		return "Superior"
	else:
		return "Legendary"

func _create_shop_slots():
	"""Create visual shop slots"""
	if not grid_container:
		return
	
	# Clear existing slots
	for child in grid_container.get_children():
		child.queue_free()
	
	# Create shop item slots
	for item_data in shop_items:
		var slot = _create_shop_slot(item_data)
		grid_container.add_child(slot)
	
	# Add "Coming Soon" text
	if coming_soon_label:
		coming_soon_label.text = "🛒 Shop Preview 🛒\n\nItems are displayed with random buffs and prices.\n\nPurchase functionality coming in future updates!"

func _create_shop_slot(item_data: Dictionary) -> Control:
	"""Create a single shop slot"""
	var slot_container = PanelContainer.new()
	slot_container.custom_minimum_size = Vector2(120, 140)
	
	# Style the slot
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.2, 0.8)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.2, 0.8, 1, 0.6)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	slot_container.add_theme_stylebox_override("panel", style)
	
	# Create vertical layout
	var vbox = VBoxContainer.new()
	vbox.name = "VBoxContainer"
	slot_container.add_child(vbox)
	
	# Item icon
	var icon_label = Label.new()
	icon_label.text = item_data.icon
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.add_theme_font_size_override("font_size", 32)
	vbox.add_child(icon_label)
	
	# Item name
	var name_label = Label.new()
	name_label.text = item_data.name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(name_label)
	
	# Buff indicator
	var buff_label = Label.new()
	buff_label.text = item_data.buff_description
	buff_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	buff_label.add_theme_color_override("font_color", _get_buff_color(item_data.buff_multiplier))
	buff_label.add_theme_font_size_override("font_size", 10)
	vbox.add_child(buff_label)
	
	# Price
	var price_label = Label.new()
	price_label.text = str(item_data.buffed_price) + " 🪙"
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.0))  # Gold color
	price_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(price_label)
	
	# Add hover effect
	slot_container.mouse_entered.connect(_on_slot_hover.bind(slot_container, true))
	slot_container.mouse_exited.connect(_on_slot_hover.bind(slot_container, false))
	
	return slot_container

func _get_buff_color(multiplier: float) -> Color:
	"""Get color based on buff level"""
	if multiplier < 1.4:
		return Color(0.5, 1.0, 0.5)  # Green
	elif multiplier < 1.7:
		return Color(0.3, 0.8, 1.0)  # Blue
	elif multiplier < 2.0:
		return Color(1.0, 0.5, 0.0)  # Orange
	else:
		return Color(1.0, 0.2, 1.0)  # Purple

func _on_slot_hover(slot: PanelContainer, is_hovering: bool):
	"""Handle slot hover effects"""
	var style = slot.get_theme_stylebox("panel") as StyleBoxFlat
	if style:
		if is_hovering:
			style.bg_color = Color(0.2, 0.3, 0.4, 0.9)
			style.border_color = Color(0.2, 0.8, 1, 1.0)
		else:
			style.bg_color = Color(0.1, 0.1, 0.2, 0.8)
			style.border_color = Color(0.2, 0.8, 1, 0.6)

func refresh_shop():
	"""Refresh the shop with new items"""
	_generate_shop_items()
	_create_shop_slots()
	
	if audio_manager:
		audio_manager.play_ui_sound("button_click")
