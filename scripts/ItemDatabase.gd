extends Node

## ItemDatabase - Centralized item and pricing data for trading system

signal system_ready

enum ItemType { WEAPON, UPGRADE, CONSUMABLE, RESOURCE }

# Item structure: {name, type, buy_price, sell_price, icon_path, description}
var items: Dictionary = {}
var initialized: bool = false

func _ready():
	add_to_group("item_database")
	# Don't auto-initialize in _ready - let loading screen handle it

func initialize() -> void:
	"""Initialize item database for loading screen"""
	print("ItemDatabase: Initializing...")
	
	_initialize_items()
	
	initialized = true
	system_ready.emit()
	print("ItemDatabase: Initialization complete with ", items.size(), " items")

func _initialize_items():
	"""Initialize all available items for trading"""
	
	# Weapons
	items["turret_basic"] = {
		"name": "Basic Turret",
		"type": ItemType.WEAPON,
		"buy_price": 50,
		"sell_price": 25,
		"icon_path": "res://assets/items/turret_basic.png",
		"description": "Auto-firing turret for passive slot"
	}
	
	items["phaser_basic"] = {
		"name": "Basic Phaser",
		"type": ItemType.WEAPON,
		"buy_price": 75,
		"sell_price": 37,
		"icon_path": "res://assets/items/phaser_basic.png",
		"description": "Manual phaser beam weapon"
	}
	
	items["phaser_enhanced"] = {
		"name": "Enhanced Phaser",
		"type": ItemType.WEAPON,
		"buy_price": 150,
		"sell_price": 75,
		"icon_path": "res://assets/items/phaser_enhanced.png",
		"description": "Upgraded phaser with increased damage"
	}
	
	# Upgrades
	items["shield_boost"] = {
		"name": "Shield Boost",
		"type": ItemType.UPGRADE,
		"buy_price": 100,
		"sell_price": 50,
		"icon_path": "res://assets/items/shield_boost.png",
		"description": "Increases maximum shield capacity"
	}
	
	items["engine_boost"] = {
		"name": "Engine Boost",
		"type": ItemType.UPGRADE,
		"buy_price": 80,
		"sell_price": 40,
		"icon_path": "res://assets/items/engine_boost.png",
		"description": "Increases movement speed"
	}
	
	items["damage_boost"] = {
		"name": "Damage Boost",
		"type": ItemType.UPGRADE,
		"buy_price": 120,
		"sell_price": 60,
		"icon_path": "res://assets/items/damage_boost.png",
		"description": "Increases weapon damage"
	}
	
	# Consumables
	items["health_pack"] = {
		"name": "Health Pack",
		"type": ItemType.CONSUMABLE,
		"buy_price": 20,
		"sell_price": 10,
		"icon_path": "res://assets/items/health_pack.png",
		"description": "Restores 50 health points"
	}
	
	items["shield_pack"] = {
		"name": "Shield Pack",
		"type": ItemType.CONSUMABLE,
		"buy_price": 30,
		"sell_price": 15,
		"icon_path": "res://assets/items/shield_pack.png",
		"description": "Restores 30 shield points"
	}
	
	items["ammo_pack"] = {
		"name": "Ammo Pack",
		"type": ItemType.CONSUMABLE,
		"buy_price": 15,
		"sell_price": 7,
		"icon_path": "res://assets/items/ammo_pack.png",
		"description": "Restores ammunition for weapons"
	}
	
	# Resources
	items["scrap_metal"] = {
		"name": "Scrap Metal",
		"type": ItemType.RESOURCE,
		"buy_price": 5,
		"sell_price": 2,
		"icon_path": "res://assets/items/scrap_metal.png",
		"description": "Basic crafting material"
	}
	
	items["energy_cell"] = {
		"name": "Energy Cell",
		"type": ItemType.RESOURCE,
		"buy_price": 10,
		"sell_price": 5,
		"icon_path": "res://assets/items/energy_cell.png",
		"description": "Power source for upgrades"
	}
	
	items["rare_crystal"] = {
		"name": "Rare Crystal",
		"type": ItemType.RESOURCE,
		"buy_price": 50,
		"sell_price": 25,
		"icon_path": "res://assets/items/rare_crystal.png",
		"description": "Valuable crafting component"
	}

# Get item data by ID
func get_item(item_id: String) -> Dictionary:
	if items.has(item_id):
		return items[item_id]
	return {}

# Get all items of a specific type
func get_items_by_type(type: ItemType) -> Array:
	var filtered_items = []
	for item_id in items:
		if items[item_id]["type"] == type:
			filtered_items.append({"id": item_id, "data": items[item_id]})
	return filtered_items

# Get all items
func get_all_items() -> Array:
	var all_items = []
	for item_id in items:
		all_items.append({"id": item_id, "data": items[item_id]})
	return all_items

# Check if player can afford item
func can_afford(item_id: String, player_coins: int) -> bool:
	if not items.has(item_id):
		return false
	return player_coins >= items[item_id]["buy_price"]

# Calculate sell value (could be modified by player reputation, etc.)
func get_sell_price(item_id: String) -> int:
	if not items.has(item_id):
		return 0
	return items[item_id]["sell_price"]

# Calculate buy price (could be modified by discounts, etc.)
func get_buy_price(item_id: String) -> int:
	if not items.has(item_id):
		return 0
	return items[item_id]["buy_price"]

# Get items within price range
func get_items_in_price_range(min_price: int, max_price: int) -> Array:
	var affordable_items = []
	for item_id in items:
		var buy_price = items[item_id]["buy_price"]
		if buy_price >= min_price and buy_price <= max_price:
			affordable_items.append({"id": item_id, "data": items[item_id]})
	return affordable_items
