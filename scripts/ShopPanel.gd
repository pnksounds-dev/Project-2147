extends Control

class_name ShopPanel

## ShopPanel - Overhauled programmatic implementation
## Implements the "Main Menu Shop Overhaul Plan"
## Phase 1: Architecture & Layout Foundation

# --- Constants & Config ---
const COLOR_GLASS_BG = Color(0.05, 0.08, 0.12, 0.85)
const COLOR_GLASS_BORDER = Color(0.2, 0.45, 0.75, 0.65)
const COLOR_CYAN_ACCENT = Color(0.2, 0.8, 1.0)
const COLOR_GOLD = Color(1.0, 0.84, 0.0)

const HEADER_HEIGHT = 60
const TAB_BAR_HEIGHT = 50

# --- State ---
enum Category { CONSUMABLE, WEAPON, PASSIVE, SHIP }
var current_category: int = Category.CONSUMABLE
var shop_items: Dictionary = {}
var current_offer: Dictionary = {}

# --- Nodes ---
var main_container: VBoxContainer
var header_panel: Panel
var tab_bar: HBoxContainer
var content_area: Control
var item_flow: HFlowContainer
var grid_scroll: ScrollContainer

# --- Dependencies ---
var audio_manager
var economy_system
var item_database

func _ready():
	print("ShopPanel: Initializing...")
	add_to_group("shop_panel")
	
	# Create explicit layout settings to ensure visibility
	set_anchors_preset(Control.PRESET_FULL_RECT)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	# Get Dependencies
	audio_manager = get_node_or_null("/root/AudioManager")
	economy_system = get_node_or_null("/root/EconomySystem")
	item_database = get_node_or_null("/root/ItemDatabase")
	
	# Architecture Phase 1: Build the UI Frame
	_build_ui_structure()
	
	# Initial Data Generation
	_generate_shop_data()
	
	# Initial Render
	_refresh_grid()
	print("ShopPanel: Initialization complete.")

# --- Phase 1: Architecture ---
func _build_ui_structure():
	# Root settings
	set_anchors_preset(Control.PRESET_FULL_RECT)
	
	# Main Background (Glass)
	var bg_panel = Panel.new()
	bg_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_panel.add_theme_stylebox_override("panel", _create_glass_style())
	add_child(bg_panel)
	
	# Main Vertical Layout
	main_container = VBoxContainer.new()
	main_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_container.add_theme_constant_override("separation", 0)
	# Add margin
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	margin.add_child(main_container)
	add_child(margin)
	
	# 1. Header Area (Shop Title + Stats)
	_build_header()
	
	# 2. Tab Bar (Category Selection)
	_build_tab_bar()
	
	# 3. Content Area (Item Grid)
	content_area = Control.new()
	content_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_container.add_child(content_area)
	
	# Scroll Container
	grid_scroll = ScrollContainer.new()
	grid_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	content_area.add_child(grid_scroll)
	
	# Flow Container (auto-wraps based on width)
	item_flow = HFlowContainer.new()
	item_flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_flow.add_theme_constant_override("h_separation", 20)
	item_flow.add_theme_constant_override("v_separation", 20)
	# Add flow padding
	var flow_margin = MarginContainer.new()
	flow_margin.add_theme_constant_override("margin_left", 10)
	flow_margin.add_theme_constant_override("margin_right", 10)
	flow_margin.add_theme_constant_override("margin_top", 10)
	flow_margin.add_theme_constant_override("margin_bottom", 10)
	flow_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow_margin.add_child(item_flow)
	grid_scroll.add_child(flow_margin)

func _build_header():
	header_panel = Panel.new()
	header_panel.custom_minimum_size.y = HEADER_HEIGHT
	# Transparent background for header
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0,0,0,0)
	header_panel.add_theme_stylebox_override("panel", style)
	main_container.add_child(header_panel)
	
	var hbox = HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	header_panel.add_child(hbox)
	
	# Title
	var title = Label.new()
	title.text = "PREMIUM SHOP"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", COLOR_CYAN_ACCENT)
	hbox.add_child(title)
	
	# Spacer
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)
	
	# Credits Display (Placeholder for now)
	var credits = Label.new()
	credits.text = "CREDITS: ---"
	credits.name = "CreditsLabel"
	credits.add_theme_font_size_override("font_size", 20)
	credits.add_theme_color_override("font_color", COLOR_GOLD)
	hbox.add_child(credits)

func _build_tab_bar():
	tab_bar = HBoxContainer.new()
	tab_bar.custom_minimum_size.y = TAB_BAR_HEIGHT
	tab_bar.add_theme_constant_override("separation", 5)
	main_container.add_child(tab_bar)
	
	var categories = ["CONSUMABLES", "WEAPONS", "PASSIVES", "SHIPS"]
	for i in range(categories.size()):
		var btn = Button.new()
		btn.text = categories[i]
		btn.toggle_mode = true
		btn.button_pressed = (i == current_category)
		btn.custom_minimum_size.x = 150
		btn.focus_mode = Control.FOCUS_NONE
		btn.add_theme_font_size_override("font_size", 16)
		
		# Initial Style
		_update_tab_style(btn, i == current_category)
		
		btn.pressed.connect(_on_category_changed.bind(i))
		
		tab_bar.add_child(btn)
	
	# Add Spacer/Separator line below tabs
	var sep = HSeparator.new()
	sep.modulate = Color(1, 1, 1, 0.3)
	main_container.add_child(sep)

func _update_tab_style(btn: Button, active: bool):
	var style = StyleBoxFlat.new()
	if active:
		style.bg_color = Color(0.2, 0.8, 1.0, 0.2) # Cyan tint
		style.border_width_bottom = 3
		style.border_color = COLOR_CYAN_ACCENT
	else:
		style.bg_color = Color(0, 0, 0, 0.3)
		style.border_width_bottom = 0
		style.border_color = Color.TRANSPARENT
		
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style) # Keep consistent
	btn.add_theme_stylebox_override("pressed", style)
	
	if active:
		btn.add_theme_color_override("font_color", COLOR_CYAN_ACCENT)
	else:
		btn.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))

# --- Logic ---

func _on_category_changed(category_idx: int):
	if current_category == category_idx:
		return
		
	current_category = category_idx
	
	# Update Tab Buttons
	for i in range(tab_bar.get_child_count()):
		var btn = tab_bar.get_child(i) as Button
		var is_active = (i == current_category)
		btn.button_pressed = is_active
		
		# Update Visuals
		_update_tab_style(btn, is_active)
	
	_refresh_grid()
	
	if audio_manager and audio_manager.has_method("play_ui_sound"):
		audio_manager.play_ui_sound("button_click")

func _refresh_grid():
	# Clear existing
	for child in item_flow.get_children():
		child.queue_free()
	
	# Get items for category
	var category_key = ""
	match current_category:
		Category.CONSUMABLE: category_key = "consumable"
		Category.WEAPON: category_key = "weapon"
		Category.PASSIVE: category_key = "passive"
		Category.SHIP: category_key = "ship"
	
	var items = shop_items.get(category_key, [])
	
	for item in items:
		var slot = _create_item_card(item)
		item_flow.add_child(slot)

func _create_item_card(item_data: Dictionary) -> Control:
	# Phase 4: Create enhanced item card
	var card = PanelContainer.new()
	# Base size with simple resolution scaling
	var base_size = Vector2(200, 220)
	var viewport_width = get_viewport().size.x
	if viewport_width > 1920:
		var scale_factor = viewport_width / 1920.0
		base_size *= scale_factor
	card.custom_minimum_size = base_size
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	
	# Cached default style
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.6)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.3, 0.3, 0.4, 0.5)
	
	# Manually set corners to avoid potential method missing errors
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	
	card.add_theme_stylebox_override("panel", style)
	
	# Store data for interaction
	card.set_meta("item_data", item_data)
	
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 8)
	card.add_child(vbox)
	
	# Icon
	var icon = TextureRect.new()
	icon.custom_minimum_size = Vector2(64, 64)
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# Load icon
	if item_data.get("icon_path"):
		if ResourceLoader.exists(item_data.get("icon_path")):
			icon.texture = load(item_data.get("icon_path"))
	vbox.add_child(icon)
	
	# Name
	var lbl_name = Label.new()
	lbl_name.text = item_data.get("name", "Unknown")
	lbl_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_name.custom_minimum_size.y = 40 # Force height for 2 lines
	lbl_name.add_theme_font_size_override("font_size", 14)
	vbox.add_child(lbl_name)
	
	# Price
	var lbl_price = Label.new()
	lbl_price.text = str(item_data.get("price", 0)) + " c"
	lbl_price.add_theme_color_override("font_color", COLOR_GOLD)
	lbl_price.add_theme_font_size_override("font_size", 16)
	lbl_price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(lbl_price)
	
	# Buy Button (Phase 4)
	var btn = Button.new()
	btn.text = "BUY"
	btn.custom_minimum_size.x = 100
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.add_theme_font_size_override("font_size", 12)
	# Connect purchase logic
	btn.pressed.connect(func(): _on_item_buy_pressed(item_data))
	vbox.add_child(btn)
	
	return card

func _on_item_buy_pressed(item_data: Dictionary):
	current_offer = item_data
	if economy_system and economy_system.has_method("purchase_with_price"):
		var id = item_data.get("id")
		# Determine category string
		var cat_str = "consumable" # default
		# Map enum to string if needed, or store it in item data
		# Ideally item_data has 'type' or 'category'
		
		var price = item_data.get("price", 0)
		
		# For now, just try to buy
		var success = economy_system.purchase_with_price(id, cat_str, price)
		if success:
			if audio_manager: audio_manager.play_ui_sound("purchase_success")
			_update_footer() # Refresh credits
		else:
			if audio_manager: audio_manager.play_ui_sound("purchase_failed")

# --- Data Generation (Preserved/Simplified from original) ---
func _generate_shop_data():
	shop_items = {
		"consumable": [],
		"weapon": [],
		"passive": [],
		"ship": []
	}
	
	# Consumables
	_add_offer("consumable", "HealthIncrease", "Health Pack", 50, "res://assets/items/Consumables/HealthIncrease.png")
	_add_offer("consumable", "BucketOfCoffee", "Coffee", 75, "res://assets/items/Consumables/BucketOfCoffee.png")
	_add_offer("consumable", "Luck", "Lucky Charm", 100, "res://assets/items/Consumables/Luck.png")
	_add_offer("consumable", "CandyCane", "Candy Cane", 60, "res://assets/items/Consumables/CandyCane.png")
	_add_offer("consumable", "BrokenHeart", "Heart Repair", 150, "res://assets/items/Consumables/BrokenHeart.png")

	# Weapons
	_add_offer("weapon", "FireWeapon1", "Flamethrower", 200, "res://assets/items/Weapons/Item_Icon/FireWeapon1.png")
	_add_offer("weapon", "PhaserBeams", "Phaser Beams", 350, "res://assets/items/Weapons/Item_Icon/PhaserBeams.png")
	_add_offer("weapon", "PhotonTorpedo", "Photon Torpedo", 500, "res://assets/items/Weapons/Photon_Torpedo/PhotonTorpedoLingering.png")
	_add_offer("weapon", "BallisticBarrage", "Ballistic Barrage", 400, "res://assets/items/Weapons/Item_Icon/BallisticBarrage.png")
	_add_offer("weapon", "DeathRay", "Death Ray", 800, "res://assets/items/Weapons/Item_Icon/DeathRay.png")
	_add_offer("weapon", "ExplosiveMine", "Explosive Mines", 450, "res://assets/items/Weapons/Item_Icon/ExplosiveMine.png")
	_add_offer("weapon", "FreezeDamage1", "Freeze Ray", 325, "res://assets/items/Weapons/Item_Icon/FreezeDamage1.png")
	_add_offer("weapon", "Torpedo", "Torpedo", 250, "res://assets/items/Weapons/Item_Icon/Torpedo.png")
	_add_offer("weapon", "VoidMagic", "Void Magic", 750, "res://assets/items/Weapons/Item_Icon/VoidMagic.png")
	_add_offer("weapon", "ElectricFieldDrive", "Electric Field", 425, "res://assets/items/Weapons/Item_Icon/ElectricFieldDrive.png")

	# Passives
	_add_offer("passive", "Shield", "Shield Generator", 300, "res://assets/items/ShipUpgrade/Shield.png")
	_add_offer("passive", "OrbBender", "Orb Magnet", 400, "res://assets/items/Passive/OrbBender.png")
	_add_offer("passive", "AladdinsCarpet", "Flight Carpet", 350, "res://assets/items/Passive/AladdinsCarpet.png")
	_add_offer("passive", "PocketWatch", "Time Dilation", 450, "res://assets/items/Passive/PocketWatch.png")
	_add_offer("passive", "DeathInfluence", "Death Influence", 600, "res://assets/items/Passive/DeathInfluence.png")
	_add_offer("passive", "LooseTooth", "Vengeance", 325, "res://assets/items/Passive/LooseTooth.png")
	_add_offer("passive", "ShellShocked", "Shell Shock", 425, "res://assets/items/Passive/ShellShocked.png")
	_add_offer("passive", "TVRemote", "Remote Control", 375, "res://assets/items/Passive/TVRemote.png")
	_add_offer("passive", "TheBell", "Power Bell", 475, "res://assets/items/Passive/TheBell.png")
	_add_offer("passive", "WinXpLaptop", "Hacking Laptop", 550, "res://assets/items/Passive/WinXpLaptop.png")

	# Ships
	_add_offer("ship", "medium_mk1", "Medium MK I", 500, "res://assets/Ships/FactionShips/ShipMedium1.png")
	_add_offer("ship", "medium_mk2", "Medium MK II", 1200, "res://assets/Ships/player/Trader_General_1.png")
	_add_offer("ship", "destroyer_base", "Destroyer Base", 2500, "res://assets/Ships/ShipParts/Body/Destroyer_Head.png")
	_add_offer("ship", "trader_general", "Trader General", 800, "res://assets/Ships/FactionShips/Trader/Trader_General_1.png")
	_add_offer("ship", "scout_ship", "Scout Ship", 300, "res://assets/Ships/FactionShips/ScoutShip.png")
	_add_offer("ship", "warship", "Warship", 1500, "res://assets/Ships/FactionShips/ShipMedium2.png")
	_add_offer("ship", "trader_farmer", "Farmer Trader", 600, "res://assets/Ships/FactionShips/Trader/Trader_Farmer_1.png")
	_add_offer("ship", "hunter_ship", "Hunter Ship", 900, "res://assets/Ships/FactionShips/Trader/Trader_Hunter_1.png")

func _add_offer(cat: String, id: String, item_name: String, price: int, icon: String):
	if not shop_items.has(cat):
		shop_items[cat] = []
	shop_items[cat].append({
		"id": id,
		"name": item_name,
		"price": price,
		"icon_path": icon
	})

# --- Styling Helpers ---
func _create_glass_style() -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = COLOR_GLASS_BG
	s.border_width_left = 2
	s.border_width_top = 2
	s.border_width_right = 2
	s.border_width_bottom = 2
	s.border_color = COLOR_GLASS_BORDER
	return s

func _update_footer():
	if economy_system and economy_system.has_method("get_coins"):
		var lbl = header_panel.find_child("CreditsLabel", true, false)
		if lbl:
			lbl.text = "CREDITS: " + str(economy_system.get_coins())
