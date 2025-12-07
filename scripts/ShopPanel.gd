extends Control

class_name ShopPanel

## ShopPanel - Displays random buffed items with coin prices in main menu

@onready var consumable_container: GridContainer = get_node_or_null("VBoxContainer/ScrollContainer/GridContainer")
@onready var weapon_container: GridContainer = get_node_or_null("VBoxContainer/WeaponsScroll/GridContainer")
@onready var ship_container: GridContainer = get_node_or_null("VBoxContainer/ShipsScroll/GridContainer")
@onready var coming_soon_label: Label = get_node_or_null("VBoxContainer/ComingSoonLabel")
@onready var buy_button: Button = get_node_or_null("VBoxContainer/Footer/BuyButton")
@onready var coins_label: Label = get_node_or_null("VBoxContainer/Footer/CoinsLabel")
@onready var economy_system = get_node_or_null("/root/EconomySystem")

# Audio manager reference
var audio_manager

# Cached style for performance optimization
var _cached_slot_style: StyleBoxFlat
var _hover_styles: Array[StyleBoxFlat] = []  # Track hover styles for cleanup

# Shop item data
var shop_items := {
	"consumable": [],
	"weapon": [],
	"passive": [],
	"ship": []
}
var current_offer: Dictionary = {}

func _initialize_shop():
	"""Initialize shop after layout is finalized"""
	_generate_shop_items()
	_create_shop_slots()
	_update_footer()

func _ready():
	add_to_group("shop_panel")
	
	# Get audio manager
	audio_manager = get_node_or_null("/root/AudioManager")
	
	# Check economy system
	economy_system = get_node_or_null("/root/EconomySystem")
	
	# Connect buy button
	if buy_button and not buy_button.pressed.is_connected(_on_buy_pressed):
		buy_button.pressed.connect(_on_buy_pressed)
	
	# Listen for coin changes to keep footer in sync
	if economy_system and economy_system.has_signal("coins_changed"):
		if not economy_system.coins_changed.is_connected(_on_coins_changed):
			economy_system.coins_changed.connect(_on_coins_changed)
	
	# Initialize shop immediately without deferring
	_generate_shop_items()
	
	# Layout fix: Ensure scroll containers expand to fill available space
	if consumable_container:
		var scroll = consumable_container.get_parent()
		if scroll is Control:
			scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if weapon_container:
		var scroll = weapon_container.get_parent()
		if scroll is Control:
			scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if ship_container:
		var scroll = ship_container.get_parent()
		if scroll is Control:
			scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
			
	_create_shop_slots()
	_update_footer()

func _generate_shop_items():
	"""Generate shop items using available assets"""
	shop_items = {
		"consumable": [],
		"weapon": [],
		"passive": [],
		"ship": []
	}
	
	# Consumables (using actual asset paths)
	_add_offer("consumable", "HealthIncrease", "Health Pack", "Medical supplies that restore health points", "res://assets/items/Consumables/HealthIncrease.png", "Common", 50)
	_add_offer("consumable", "BucketOfCoffee", "Coffee", "Energy boost that increases speed temporarily", "res://assets/items/Consumables/BucketOfCoffee.png", "Common", 75)
	_add_offer("consumable", "Luck", "Lucky Charm", "Increases critical hit chance for a duration", "res://assets/items/Consumables/Luck.png", "Uncommon", 100)
	_add_offer("consumable", "CandyCane", "Candy Cane", "Sweet treat that provides shield boost", "res://assets/items/Consumables/CandyCane.png", "Common", 60)
	_add_offer("consumable", "BrokenHeart", "Heart Repair", "Repairs damaged systems and restores health", "res://assets/items/Consumables/BrokenHeart.png", "Rare", 150)
	
	# Weapons (using actual asset paths)
	_add_offer("weapon", "FireWeapon1", "Flamethrower", "Short-range fire damage weapon", "res://assets/items/Weapons/Item_Icon/FireWeapon1.png", "Common", 200)
	_add_offer("weapon", "PhaserBeams", "Phaser Beams", "Medium-range energy weapon", "res://assets/items/Weapons/Item_Icon/PhaserBeams.png", "Uncommon", 350)
	_add_offer("weapon", "PhotonTorpedo", "Photon Torpedo", "Long-range torpedo with splash damage", "res://assets/items/Weapons/Photon_Torpedo/PhotonTorpedoLingering.png", "Rare", 500)
	_add_offer("weapon", "BallisticBarrage", "Ballistic Barrage", "Rapid multi-shot barrage for crowd control", "res://assets/items/Weapons/Item_Icon/BallisticBarrage.png", "Uncommon", 400)
	_add_offer("weapon", "DeathRay", "Death Ray", "High-damage focused beam weapon", "res://assets/items/Weapons/Item_Icon/DeathRay.png", "Epic", 800)
	_add_offer("weapon", "ExplosiveMine", "Explosive Mines", "Deployable mines for area denial", "res://assets/items/Weapons/Item_Icon/ExplosiveMine.png", "Rare", 450)
	_add_offer("weapon", "FreezeDamage1", "Freeze Ray", "Slows enemies with cold damage", "res://assets/items/Weapons/Item_Icon/FreezeDamage1.png", "Uncommon", 325)
	_add_offer("weapon", "Torpedo", "Torpedo", "Standard torpedo weapon", "res://assets/items/Weapons/Item_Icon/Torpedo.png", "Common", 250)
	_add_offer("weapon", "VoidMagic", "Void Magic", "Mysterious void-based weapon", "res://assets/items/Weapons/Item_Icon/VoidMagic.png", "Epic", 750)
	_add_offer("weapon", "ElectricFieldDrive", "Electric Field", "Area-of-effect electric damage", "res://assets/items/Weapons/Item_Icon/ElectricFieldDrive.png", "Rare", 425)
	
	# Passives (using actual asset paths)
	_add_offer("passive", "Shield", "Shield Generator", "Generates a protective barrier that refreshes when not broken", "res://assets/items/ShipUpgrade/Shield.png", "Uncommon", 300)
	_add_offer("passive", "OrbBender", "Orb Magnet", "Pulls nearby orbs and buffs orb damage for a short time", "res://assets/items/Passive/OrbBender.png", "Rare", 400)
	_add_offer("passive", "AladdinsCarpet", "Flight Carpet", "Increases movement speed and dodge chance", "res://assets/items/Passive/AladdinsCarpet.png", "Uncommon", 350)
	_add_offer("passive", "PocketWatch", "Time Dilation", "Slows down nearby enemies temporarily", "res://assets/items/Passive/PocketWatch.png", "Rare", 450)
	_add_offer("passive", "DeathInfluence", "Death Influence", "Increases damage dealt at low health", "res://assets/items/Passive/DeathInfluence.png", "Epic", 600)
	_add_offer("passive", "LooseTooth", "Vengeance", "Reflects a portion of damage taken", "res://assets/items/Passive/LooseTooth.png", "Uncommon", 325)
	_add_offer("passive", "ShellShocked", "Shell Shock", "Increases armor and damage resistance", "res://assets/items/Passive/ShellShocked.png", "Rare", 425)
	_add_offer("passive", "TVRemote", "Remote Control", "Chance to confuse enemies on hit", "res://assets/items/Passive/TVRemote.png", "Uncommon", 375)
	_add_offer("passive", "TheBell", "Power Bell", "Periodic damage area around player", "res://assets/items/Passive/TheBell.png", "Rare", 475)
	_add_offer("passive", "WinXpLaptop", "Hacking Laptop", "Increases experience gain and coin collection", "res://assets/items/Passive/WinXpLaptop.png", "Epic", 550)
	
	# Ships (using actual ship assets)
	_add_offer("ship", "medium_mk1", "Medium MK I", "Improved mid-tier ship with better performance", "res://assets/Ships/FactionShips/ShipMedium1.png", "Uncommon", 500)
	_add_offer("ship", "medium_mk2", "Medium MK II", "Balanced gunship with modular hard-points", "res://assets/Ships/player/Trader_General_1.png", "Rare", 1200)
	_add_offer("ship", "destroyer_base", "Destroyer Base", "Heavy destroyer chassis for serious combat", "res://assets/Ships/ShipParts/Body/Destroyer_Head.png", "Epic", 2500)
	_add_offer("ship", "trader_general", "Trader General", "Versatile trading vessel with good cargo capacity", "res://assets/Ships/FactionShips/Trader/Trader_General_1.png", "Uncommon", 800)
	_add_offer("ship", "scout_ship", "Scout Ship", "Fast reconnaissance vessel for exploration", "res://assets/Ships/FactionShips/ScoutShip.png", "Common", 300)
	_add_offer("ship", "warship", "Warship", "Heavy combat vessel with advanced weapons", "res://assets/Ships/FactionShips/ShipMedium2.png", "Rare", 1500)
	_add_offer("ship", "trader_farmer", "Farmer Trader", "Specialized trading vessel for agricultural goods", "res://assets/Ships/FactionShips/Trader/Trader_Farmer_1.png", "Common", 600)
	_add_offer("ship", "hunter_ship", "Hunter Ship", "Fast attack vessel for hunting targets", "res://assets/Ships/FactionShips/Trader/Trader_Hunter_1.png", "Uncommon", 900)

func _add_offer(shelf: String, item_id: String, fallback_name: String, fallback_description: String, fallback_icon: String, rarity: String, price: int) -> void:
	var item_name := fallback_name
	var description := fallback_description
	var icon_path := fallback_icon
	
	# Try to pull richer data from ItemRegistry if available
	var registry = get_node_or_null("/root/ItemRegistry")
	if registry and registry.has_method("get_all_items"):
		var all_items: Dictionary = registry.get_all_items()
		if all_items.has(item_id):
			var item_res = all_items[item_id]
			if "name" in item_res:
				item_name = String(item_res.name)
			if "description" in item_res:
				description = String(item_res.description)
			if "asset_path" in item_res:
				var raw_path: String = String(item_res.asset_path)
				if raw_path != "":
					var candidate := raw_path
					if not candidate.begins_with("res://"):
						candidate = "res://" + candidate
					if ResourceLoader.exists(candidate):
						icon_path = candidate
	
	# Try even richer data from ItemDatabase (Source of Truth)
	var item_db = get_node_or_null("/root/ItemDatabase")
	var db_icon = null
	if item_db and item_db.has_method("has_item") and item_db.has_method("get_item") and item_db.has_item(item_id):
		var item_obj = item_db.get_item(item_id)
		if item_obj:
			if item_obj.get("icon"):
				db_icon = item_obj.get("icon")
			# If database has a name/desc, use them as they are likely more current
			if item_obj.get("display_name"):
				item_name = item_obj.get("display_name")
			if item_obj.get("description"):
				description = item_obj.get("description")

	var offer := {
		"id": item_id,
		"name": item_name,
		"type": shelf,
		"category": shelf,  # Add category for purchase logic
		"icon_path": icon_path,
		"icon": db_icon,    # Pass actual texture object if available
		"rarity": rarity,
		"price": price,
		"description": description,
	}
	
	if shop_items.has(shelf):
		shop_items[shelf].append(offer)

func _create_shop_slots():
	"""Create visual shop slots"""
	# Clear all containers
	_clear_container(consumable_container)
	_clear_container(weapon_container)
	_clear_container(ship_container)
	
	current_offer = {}
	
	# Populate containers with items
	_populate_container(consumable_container, shop_items.get("consumable", []))
	_populate_container(weapon_container, shop_items.get("weapon", []))
	_populate_container(ship_container, shop_items.get("ship", []))
	
	if coming_soon_label:
		coming_soon_label.text = "Premium Shop\n\nConsumables, weapons, ships, and passives available."

func _clear_container(container: GridContainer) -> void:
	if not container:
		return
	for child in container.get_children():
		child.queue_free()
	# Clear associated hover styles
	_hover_styles.clear()

func _populate_container(container: GridContainer, items: Array) -> void:
	if not container:
		return
	
	# Configure grid container with fixed columns for reliability
	container.columns = 4  # Fixed 4 columns for consistent layout
	container.add_theme_constant_override("h_separation", 10)
	container.add_theme_constant_override("v_separation", 10)
	
	for item_data in items:
		var slot = _create_shop_slot(item_data, 140)  # Fixed slot width
		container.add_child(slot)
		if current_offer.is_empty():
			current_offer = item_data

func _create_shop_slot(item_data: Dictionary, _container_width: float) -> Control:
	"""Create a single shop slot"""
	var slot_container = PanelContainer.new()
	# Use fixed slot size for reliability
	var slot_size = Vector2(120, 140)
	slot_container.custom_minimum_size = slot_size
	
	# Use cached style for performance
	if not _cached_slot_style:
		_cached_slot_style = _create_slot_style()
	slot_container.add_theme_stylebox_override("panel", _cached_slot_style)
	
	# Create vertical layout
	var vbox = VBoxContainer.new()
	vbox.name = "VBoxContainer"
	slot_container.add_child(vbox)
	
	# Item icon (texture)
	var icon_texture = TextureRect.new()
	icon_texture.custom_minimum_size = Vector2(48, 48)
	icon_texture.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var icon_path: String = item_data.get("icon_path", "")
	
	# Try to load icon with fallback strategies
	var icon_loaded = false
	
	# 1. Try direct icon object (from ItemDatabase)
	var icon_obj = item_data.get("icon")
	if icon_obj is Texture2D:
		icon_texture.texture = icon_obj
		icon_loaded = true
	
	if not icon_loaded and icon_path != "":
		# First try the exact path
		if ResourceLoader.exists(icon_path):
			icon_texture.texture = load(icon_path)
			icon_loaded = true
		else:
			# Try alternative common paths
			var alt_paths = [
				"res://assets/items/Consumables/" + item_data.get("id", "") + ".png",
				"res://assets/items/Weapons/Item_Icon/" + item_data.get("id", "") + ".png",
				"res://assets/items/Passive/" + item_data.get("id", "") + ".png"
			]
			for alt_path in alt_paths:
				if ResourceLoader.exists(alt_path):
					icon_texture.texture = load(alt_path)
					icon_loaded = true
					break
	
	if not icon_loaded:
		# Add colored rectangle fallback based on rarity
		var rarity_color = _get_buff_color(item_data.get("rarity", "Common"))
		icon_texture.color = rarity_color
	vbox.add_child(icon_texture)
	
	# Item name
	var name_label = Label.new()
	name_label.text = item_data.get("name", "")
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(name_label)
	
	# Buff indicator
	var buff_label = Label.new()
	buff_label.text = item_data.get("rarity", "Common")
	buff_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	buff_label.add_theme_color_override("font_color", _get_buff_color(item_data.get("rarity", "Common")))
	buff_label.add_theme_font_size_override("font_size", 10)
	vbox.add_child(buff_label)
	
	# Price
	var price_label = Label.new()
	price_label.text = str(int(item_data.get("price", 0))) + " coins"
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.0))  # Gold color
	price_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(price_label)
	
	# Store item metadata for purchase feedback
	slot_container.set_meta("item_id", item_data.get("id", ""))
	
	# Add hover effect with unique style per slot
	var hover_style = _create_hover_style()
	_hover_styles.append(hover_style)
	slot_container.add_theme_stylebox_override("panel", _cached_slot_style)
	slot_container.mouse_entered.connect(_on_slot_hover.bind(slot_container, true, hover_style))
	slot_container.mouse_exited.connect(_on_slot_hover.bind(slot_container, false, hover_style))
	slot_container.gui_input.connect(_on_slot_gui_input.bind(item_data))
	
	return slot_container

func _create_slot_style() -> StyleBoxFlat:
	"""Create and cache the slot style for performance"""
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
	return style

func _create_hover_style() -> StyleBoxFlat:
	"""Create hover style for individual slots"""
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.3, 0.4, 0.9)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.2, 0.8, 1, 1.0)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	return style

func _get_buff_color(rarity: String) -> Color:
	"""Get color based on rarity"""
	match rarity.to_lower():
		"common":
			return Color(0.5, 1.0, 0.5)  # Green
		"uncommon":
			return Color(0.3, 0.8, 1.0)  # Blue
		"rare":
			return Color(1.0, 0.5, 0.0)  # Orange
		"legendary":
			return Color(1.0, 0.2, 1.0)  # Purple
		_:
			return Color(0.8, 0.8, 0.8)  # Default gray

func _on_slot_hover(slot: PanelContainer, is_hovering: bool, hover_style: StyleBoxFlat):
	"""Handle slot hover effects with unique style per slot"""
	if is_hovering:
		slot.add_theme_stylebox_override("panel", hover_style)
	else:
		slot.add_theme_stylebox_override("panel", _cached_slot_style)

func _on_slot_gui_input(event: InputEvent, item_data: Dictionary) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		current_offer = item_data
		_update_footer()
		if audio_manager and audio_manager.has_method("play_ui_sound"):
			audio_manager.play_ui_sound("button_click")

func refresh_shop():
	"""Refresh the shop with new items"""
	_generate_shop_items()
	_create_shop_slots()
	_update_footer()
	
	if audio_manager:
		audio_manager.play_ui_sound("button_click")

func get_shop_statistics() -> Dictionary:
	"""Get comprehensive shop statistics"""
	var total_items = 0
	var total_value = 0
	
	for category in shop_items:
		for item in shop_items[category]:
			total_items += 1
			total_value += item.get("price", 0)
	
	return {
		"total_items": total_items,
		"total_shop_value": total_value,
		"categories": shop_items.keys(),
		"items_per_category": {}
	}

func get_current_offer() -> Dictionary:
	"""Get currently selected offer"""
	return current_offer.duplicate()

func clear_current_offer():
	"""Clear current selection"""
	current_offer = {}
	_update_footer()

func _on_buy_pressed() -> void:
	if current_offer.is_empty() or not economy_system:
		return
	
	var item_id: String = current_offer.get("id", "")
	var category: String = current_offer.get("category", "")
	var price: int = int(current_offer.get("price", 0))
	
	if item_id.is_empty() or category.is_empty() or price <= 0:
		return
	
	# Use the new purchase_with_price method for dynamic pricing
	var success = economy_system.purchase_with_price(item_id, category, price)
	
	if success:
		# Visual feedback - highlight purchased item briefly
		_show_purchase_feedback(current_offer)
		_update_footer()
		if audio_manager and audio_manager.has_method("play_ui_sound"):
			audio_manager.play_ui_sound("purchase_success")
	else:
		if audio_manager and audio_manager.has_method("play_ui_sound"):
			audio_manager.play_ui_sound("purchase_failed")

func _show_purchase_feedback(item: Dictionary) -> void:
	"""Show visual feedback when item is purchased"""
	# Find the slot for this item and animate it
	var item_id = item.get("id", "")
	var containers = [consumable_container, weapon_container, ship_container]
	for container in containers:
		if not container:
			continue
		for slot in container.get_children():
			if slot.has_meta("item_id") and slot.get_meta("item_id") == item_id:
				# Flash green to indicate success
				var tween = create_tween()
				tween.tween_property(slot, "modulate", Color(0.5, 1.0, 0.5), 0.15)
				tween.tween_property(slot, "modulate", Color.WHITE, 0.15)
				return

func get_item_price(item_id: String, category: String) -> int:
	"""Get the price of an item from shop offers"""
	var items_list = shop_items.get(category, [])
	for item in items_list:
		if item.get("id", "") == item_id:
			return int(item.get("price", -1))
	return -1

func _refresh_shop() -> void:
	"""Refresh the shop display after purchases"""
	_generate_shop_items()
	_create_shop_slots()

func _on_coins_changed(_new_amount: int) -> void:
	_update_footer()

func _update_footer() -> void:
	# Update coin display
	if coins_label:
		var coins_value := 0
		if economy_system and economy_system.has_method("get_coins"):
			coins_value = int(economy_system.get_coins())
		coins_label.text = "Coins: %d" % coins_value
	
	# Update buy button
	if buy_button:
		if current_offer.is_empty():
			buy_button.text = "Select Item"
			buy_button.disabled = true
		else:
			var cost: int = int(current_offer.get("price", 0))
			var item_name: String = current_offer.get("name", "")
			
			buy_button.text = "Buy %s (%d coins)" % [item_name, cost]
			buy_button.disabled = not _can_afford_current_offer()

func _can_afford_current_offer() -> bool:
	if current_offer.is_empty() or not economy_system:
		return false
	var cost: int = int(current_offer.get("price", 0))
	if cost <= 0:
		return false
	if economy_system.has_method("can_afford"):
		return economy_system.can_afford(cost)
	return false
