extends "res://scripts/DebugSection.gd"
class_name DebugInventorySection

var inventory_ui: Node

# All items with existing assets
const ALL_ITEMS: Array[Dictionary] = [
	# Health & Defense
	{"name": "HealthIncrease", "type": "consumable", "asset": "res://assets/items/HealthIncrease.png"},
	{"name": "Shield", "type": "equipment", "asset": "res://assets/items/Shield.png"},
	{"name": "Shield_Increase", "type": "upgrade", "asset": "res://assets/items/Shield_Increase.png"},
	{"name": "LoveShield", "type": "equipment", "asset": "res://assets/items/LoveShield.png"},
	{"name": "SpikyHelm", "type": "equipment", "asset": "res://assets/items/SpikyHelm.png"},
	{"name": "ReflectionDamage", "type": "upgrade", "asset": "res://assets/items/ReflectionDamage.png"},
	
	# Currency & Loot
	{"name": "Coin1", "type": "currency", "asset": "res://assets/items/Coin1.png"},
	{"name": "CoinsStash", "type": "currency", "asset": "res://assets/items/CoinsStash.png"},
	{"name": "Loot", "type": "loot", "asset": "res://assets/items/Loot.png"},
	{"name": "TradersLootBag", "type": "loot", "asset": "res://assets/items/TradersLootBag.png"},
	
	# Speed & Movement
	{"name": "Speed_Upgrade", "type": "upgrade", "asset": "res://assets/items/Speed_Upgrade.png"},
	{"name": "Nacelles", "type": "upgrade", "asset": "res://assets/items/Nacelles.png"},
	{"name": "ElectricFieldDrive", "type": "upgrade", "asset": "res://assets/items/ElectricFieldDrive.png"},
	{"name": "AladdinsCarpet", "type": "equipment", "asset": "res://assets/items/AladdinsCarpet.png"},
	
	# Pickup & Collection
	{"name": "PickUpRange", "type": "upgrade", "asset": "res://assets/items/PickUpRange.png"},
	{"name": "OrbMaster", "type": "equipment", "asset": "res://assets/items/Passive/OrbMaster.png"},
	{"name": "OrbRarity", "type": "upgrade", "asset": "res://assets/items/OrbRarity.png"},
	{"name": "Luck", "type": "upgrade", "asset": "res://assets/items/Luck.png"},
	
	# Weapons & Combat
	{"name": "PhaserBeams", "type": "weapon", "asset": "res://assets/items/PhaserBeams.png"},
	{"name": "BallisticBarrage", "type": "weapon", "asset": "res://assets/items/BallisticBarrage.png"},
	{"name": "DeathRay", "type": "weapon", "asset": "res://assets/items/DeathRay.png"},
	{"name": "FreezeDamage1", "type": "weapon", "asset": "res://assets/items/FreezeDamage1.png"},
	{"name": "KnockBack", "type": "upgrade", "asset": "res://assets/items/KnockBack.png"},
	{"name": "DeathInfluence", "type": "weapon", "asset": "res://assets/items/DeathInfluence.png"},
	
	# Consumables & Buffs
	{"name": "BucketOfCoffee", "type": "consumable", "asset": "res://assets/items/BucketOfCoffee.png"},
	{"name": "BrokenHeart", "type": "consumable", "asset": "res://assets/items/BrokenHeart.png"},
	{"name": "CandyCane", "type": "consumable", "asset": "res://assets/items/CandyCane.png"},
	{"name": "MoldyPumpkin", "type": "consumable", "asset": "res://assets/items/MoldyPumpkin.png"},
	{"name": "SurgicallyEnhanced", "type": "upgrade", "asset": "res://assets/items/SurgicallyEnhanced.png"},
	
	# Tools & Gadgets
	{"name": "EmptyLighter", "type": "crafting", "asset": "res://assets/items/EmptyLighter.png"},
	{"name": "Microscope", "type": "tool", "asset": "res://assets/items/Microscope.png"},
	{"name": "WinXpLaptop", "type": "tool", "asset": "res://assets/items/WinXpLaptop.png"},
	{"name": "TVRemote", "type": "tool", "asset": "res://assets/items/TVRemote.png"},
	{"name": "Chopsticks", "type": "tool", "asset": "res://assets/items/Chopsticks.png"},
	{"name": "BoxofTangledWires", "type": "crafting", "asset": "res://assets/items/BoxofTangledWires.png"},
	
	# Special & Magic
	{"name": "PocketWatch", "type": "equipment", "asset": "res://assets/items/PocketWatch.png"},
	{"name": "TheBell", "type": "equipment", "asset": "res://assets/items/TheBell.png"},
	{"name": "ShellShocked", "type": "equipment", "asset": "res://assets/items/ShellShocked.png"},
	{"name": "VintageRedGlasses", "type": "equipment", "asset": "res://assets/items/VintageRedGlasses.png"},
	{"name": "PikachuSkin", "type": "cosmetic", "asset": "res://assets/items/PikachuSkin.png"},
	
	# Misc & Novelty
	{"name": "Gamboy", "type": "tool", "asset": "res://assets/items/Gamboy.png"},
	{"name": "Headphones", "type": "equipment", "asset": "res://assets/items/Headphones.png"},
	{"name": "NoStringGuitar", "type": "equipment", "asset": "res://assets/items/NoStringGuitar.png"},
	{"name": "PictureFrame", "type": "equipment", "asset": "res://assets/items/PictureFrame.png"},
	{"name": "BirdFeather", "type": "crafting", "asset": "res://assets/items/BirdFeather.png"},
	{"name": "LooseTooth", "type": "crafting", "asset": "res://assets/items/LooseTooth.png"},
]

func _init():
	super("Inventory")

func get_debug_content() -> Control:
	# Find inventory UI
	if Engine.get_main_loop():
		var tree = Engine.get_main_loop() as SceneTree
		if tree:
			inventory_ui = tree.get_first_node_in_group("inventory_ui")
	
	var container = create_container(true, 4)
	
	# Status
	var status = create_section("Status")
	var inv_info = create_label("Inventory: " + ("OK" if inventory_ui else "N/A"), Color.GREEN if inventory_ui else Color.RED)
	status.add_child(inv_info)
	container.add_child(status)
	
	# Main controls
	var controls = create_section("Controls")
	var row1 = create_container(false, 4)
	row1.add_child(create_button("Toggle", func(): _toggle_inventory(), "Toggle inventory"))
	row1.add_child(create_button("Clear", func(): _clear_inventory(), "Clear all"))
	row1.add_child(create_button("ADD ALL", func(): _add_all_items(), "Add all items"))
	controls.add_child(row1)
	container.add_child(controls)
	
	# Item categories with scroll
	var items_section = create_section("Add Items (46 total)")
	
	# Create scrollable item list
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 120)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	
	var items_grid = GridContainer.new()
	items_grid.columns = 3
	items_grid.add_theme_constant_override("h_separation", 2)
	items_grid.add_theme_constant_override("v_separation", 2)
	
	# Add buttons for each item
	for item in ALL_ITEMS:
		var btn = Button.new()
		btn.text = _shorten_name(item.name)
		btn.custom_minimum_size = Vector2(0, 20)
		btn.add_theme_font_size_override("font_size", 9)
		btn.tooltip_text = item.name + " (" + item.type + ")"
		btn.pressed.connect(_add_item.bind(item))
		items_grid.add_child(btn)
	
	scroll.add_child(items_grid)
	items_section.add_child(scroll)
	container.add_child(items_section)
	
	# Quick category buttons
	var cats = create_section("By Category")
	var cat_row1 = create_container(false, 2)
	cat_row1.add_child(create_button("Weapons", func(): _add_category("weapon")))
	cat_row1.add_child(create_button("Equip", func(): _add_category("equipment")))
	cat_row1.add_child(create_button("Upgrade", func(): _add_category("upgrade")))
	cats.add_child(cat_row1)
	var cat_row2 = create_container(false, 2)
	cat_row2.add_child(create_button("Consume", func(): _add_category("consumable")))
	cat_row2.add_child(create_button("Tools", func(): _add_category("tool")))
	cat_row2.add_child(create_button("Loot", func(): _add_category("loot")))
	cats.add_child(cat_row2)
	container.add_child(cats)
	
	return container

func _shorten_name(item_name: String) -> String:
	# Shorten long names for buttons
	if item_name.length() > 8:
		return item_name.substr(0, 7) + ".."
	return item_name

func _toggle_inventory():
	if not inventory_ui:
		log_message("No inventory UI")
		return
	if inventory_ui.has_method("close_inventory") and inventory_ui.visible:
		inventory_ui.close_inventory()
	elif inventory_ui.has_method("open_inventory"):
		inventory_ui.open_inventory()
	log_message("Inventory toggled")

func _add_item(item_data: Dictionary):
	if not inventory_ui or not inventory_ui.has_method("add_item"):
		log_message("No inventory UI")
		return
	var item = {
		"name": item_data.name,
		"type": item_data.type,
		"asset": item_data.asset,
		"quantity": 1
	}
	inventory_ui.add_item(item)
	log_message("Added: " + item_data.name)

func _add_all_items():
	if not inventory_ui or not inventory_ui.has_method("add_item"):
		log_message("No inventory UI")
		return
	for item_data in ALL_ITEMS:
		var item = {
			"name": item_data.name,
			"type": item_data.type,
			"asset": item_data.asset,
			"quantity": 1
		}
		inventory_ui.add_item(item)
	log_message("Added ALL %d items!" % ALL_ITEMS.size())

func _add_category(category: String):
	if not inventory_ui or not inventory_ui.has_method("add_item"):
		log_message("No inventory UI")
		return
	var count = 0
	for item_data in ALL_ITEMS:
		if item_data.type == category:
			var item = {
				"name": item_data.name,
				"type": item_data.type,
				"asset": item_data.asset,
				"quantity": 1
			}
			inventory_ui.add_item(item)
			count += 1
	log_message("Added %d %s items" % [count, category])

func _clear_inventory():
	if not inventory_ui:
		log_message("No inventory UI")
		return
	if "inventory_items" in inventory_ui:
		inventory_ui.inventory_items.clear()
	if "special_slots" in inventory_ui:
		inventory_ui.special_slots.clear()
	if inventory_ui.has_method("_populate_inventory"):
		inventory_ui._populate_inventory()
	log_message("Inventory cleared")
