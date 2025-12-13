extends Node

signal coins_changed(amount: int)
signal transaction_completed(success: bool, message: String)

var coins: int = 0
var total_coins_earned: int = 0
var total_coins_spent: int = 0

const DEFAULT_STARTING_COINS: int = 9000
const USE_STARTING_COINS_OVERRIDE: bool = true

# Coin values
const ENEMY_COIN_DROP = 5
const MOTHERSHIP_COIN_DROP = 25
const SCOUT_COIN_DROP = 2
const LEVEL_COIN_BONUS = 50

# Upgrade costs (will be expanded)
const WEAPON_UPGRADE_COST = 100
const HEALTH_UPGRADE_COST = 75
const SPEED_UPGRADE_COST = 150

# Ship costs
const SHIP_COSTS = {
	"starter_ship": 0,
	"medium_mk1": 500,
	"medium_mk2": 1200,
	"destroyer_base": 2500,
	"trader_general": 800,
	"scout_ship": 300,
	"warship": 1500,
	"mothership": 3000
}

# Item costs
const ITEM_COSTS = {
	"HealthIncrease": 50,
	"BucketOfCoffee": 75,
	"Luck": 100,
	"CandyCane": 60,
	"BrokenHeart": 150,
	"Shield": 300,
	"OrbBender": 400,
	"AladdinsCarpet": 350,
	"PocketWatch": 450,
	"DeathInfluence": 600,
	"LooseTooth": 325,
	"ShellShocked": 425,
	"TVRemote": 375,
	"TheBell": 475,
	"WinXpLaptop": 550,
	"health_small": 50,
	"health_large": 150,
	"shield_small": 75,
	"shield_large": 200,
	"speed_boost": 100,
	"damage_boost": 125
}

# Weapon costs
const WEAPON_COSTS = {
	"FireWeapon1": 200,
	"PhaserBeams": 350,
	"PhotonTorpedo": 500,
	"BallisticBarrage": 400,
	"DeathRay": 800,
	"ExplosiveMine": 450,
	"FreezeDamage1": 325,
	"Torpedo": 250,
	"VoidMagic": 750,
	"ElectricFieldDrive": 425,
	"laser_basic": 200,
	"laser_advanced": 500,
	"plasma_cannon": 800,
	"missile_launcher": 600,
	"railgun": 1000
}

func _ready():
	add_to_group("economy_system")
	_load_coins()
	if USE_STARTING_COINS_OVERRIDE:
		coins = DEFAULT_STARTING_COINS
		if total_coins_earned < coins:
			total_coins_earned = coins
		_save_coins()

func add_coins(amount: int):
	if amount <= 0:
		return false
	
	coins += amount
	total_coins_earned += amount
	coins_changed.emit(coins)
	_save_coins()
	return true

func spend_coins(amount: int) -> bool:
	if amount <= 0 or coins < amount:
		transaction_completed.emit(false, "Insufficient coins")
		return false
	
	coins -= amount
	total_coins_spent += amount
	coins_changed.emit(coins)
	_save_coins()
	transaction_completed.emit(true, "Purchase successful")
	return true

func add_enemy_coin_drop(enemy_type: String):
	var amount = ENEMY_COIN_DROP
	
	match enemy_type.to_lower():
		"mothership":
			amount = MOTHERSHIP_COIN_DROP
		"scout":
			amount = SCOUT_COIN_DROP
		"enemy":
			amount = ENEMY_COIN_DROP
		_:
			amount = ENEMY_COIN_DROP
	
	add_coins(amount)
	return amount

func add_level_coin_bonus():
	add_coins(LEVEL_COIN_BONUS)
	return LEVEL_COIN_BONUS

func get_coins() -> int:
	return coins

func set_coins(amount: int):
	amount = max(amount, 0)
	coins = amount
	coins_changed.emit(coins)
	_save_coins()

func get_total_coins_earned() -> int:
	return total_coins_earned

func get_total_coins_spent() -> int:
	return total_coins_spent

func can_afford(amount: int) -> bool:
	return coins >= amount

func get_affordability_color(amount: int) -> Color:
	if can_afford(amount):
		return Color.GREEN
	else:
		return Color.RED

func purchase_upgrade(upgrade_type: String) -> bool:
	var cost = 0
	
	match upgrade_type.to_lower():
		"weapon":
			cost = WEAPON_UPGRADE_COST
		"health":
			cost = HEALTH_UPGRADE_COST
		"speed":
			cost = SPEED_UPGRADE_COST
		_:
			print("EconomySystem: Unknown upgrade type: ", upgrade_type)
			return false
	
	return spend_coins(cost)

func _load_coins():
	# Load coins from save file
	var file = FileAccess.open("user://coins.save", FileAccess.READ)
	if file:
		coins = file.get_32()
		total_coins_earned = file.get_32()
		total_coins_spent = file.get_32()
		file.close()
	else:
		coins = 0
		total_coins_earned = 0
		total_coins_spent = 0

func _save_coins():
	# Save coins to file
	var file = FileAccess.open("user://coins.save", FileAccess.WRITE)
	if file:
		file.store_32(coins)
		file.store_32(total_coins_earned)
		file.store_32(total_coins_spent)
		file.close()

func reset_coins():
	coins = 0
	total_coins_earned = 0
	total_coins_spent = 0
	coins_changed.emit(coins)
	_save_coins()

func purchase_ship(ship_id: String) -> bool:
	"""Purchase a ship if the player can afford it"""
	var cost = SHIP_COSTS.get(ship_id, -1)
	if cost == -1:
		# Try to get cost from shop offer price
		cost = _get_shop_price(ship_id, "ship")
		if cost == -1:
			transaction_completed.emit(false, "Unknown ship")
			return false
	
	if not can_afford(cost):
		transaction_completed.emit(false, "Cannot afford ship")
		return false
	
	if spend_coins(cost):
		_unlock_ship_for_player(ship_id)
		transaction_completed.emit(true, "Ship purchased: " + ship_id)
		return true
	return false

func purchase_item(item_id: String) -> bool:
	"""Purchase an item if the player can afford it"""
	var cost = ITEM_COSTS.get(item_id, -1)
	if cost == -1:
		# Try to get cost from shop offer price
		cost = _get_shop_price(item_id, "consumable")
		if cost == -1:
			transaction_completed.emit(false, "Unknown item")
			return false
	
	if not can_afford(cost):
		transaction_completed.emit(false, "Cannot afford item")
		return false
	
	if spend_coins(cost):
		_add_item_to_player_inventory(item_id)
		transaction_completed.emit(true, "Item purchased: " + item_id)
		return true
	return false

func purchase_weapon(weapon_id: String) -> bool:
	"""Purchase a weapon if the player can afford it"""
	var cost = WEAPON_COSTS.get(weapon_id, -1)
	if cost == -1:
		# Try to get cost from shop offer price
		cost = _get_shop_price(weapon_id, "weapon")
		if cost == -1:
			transaction_completed.emit(false, "Unknown weapon")
			return false
	
	if not can_afford(cost):
		transaction_completed.emit(false, "Cannot afford weapon")
		return false
	
	if spend_coins(cost):
		_add_weapon_to_player_inventory(weapon_id)
		transaction_completed.emit(true, "Weapon purchased: " + weapon_id)
		return true
	return false

func purchase_with_price(item_id: String, category: String, price: int) -> bool:
	"""Purchase any item with explicit price - used by shop for dynamic pricing"""
	if price <= 0:
		transaction_completed.emit(false, "Invalid price")
		return false
	
	if not can_afford(price):
		transaction_completed.emit(false, "Cannot afford purchase")
		return false
	
	if spend_coins(price):
		match category:
			"ship":
				_unlock_ship_for_player(item_id)
			"weapon":
				_add_weapon_to_player_inventory(item_id)
			"consumable", "passive":
				_add_item_to_player_inventory(item_id)
			_:
				_add_item_to_player_inventory(item_id)
		transaction_completed.emit(true, "Purchased: " + item_id)
		return true
	return false

func _get_shop_price(item_id: String, category: String) -> int:
	"""Get price from shop panel if item not in static costs"""
	var shop_panel = get_tree().get_first_node_in_group("shop_panel")
	if shop_panel and shop_panel.has_method("get_item_price"):
		return shop_panel.get_item_price(item_id, category)
	return -1

func get_ship_cost(ship_id: String) -> int:
	"""Get the cost of a ship"""
	return SHIP_COSTS.get(ship_id, -1)

func get_item_cost(item_id: String) -> int:
	"""Get the cost of an item"""
	return ITEM_COSTS.get(item_id, -1)

func get_weapon_cost(weapon_id: String) -> int:
	"""Get the cost of a weapon"""
	return WEAPON_COSTS.get(weapon_id, -1)

func can_afford_ship(ship_id: String) -> bool:
	"""Check if player can afford a ship"""
	var cost = get_ship_cost(ship_id)
	return cost != -1 and coins >= cost

func can_afford_item(item_id: String) -> bool:
	"""Check if player can afford an item"""
	var cost = get_item_cost(item_id)
	return cost != -1 and coins >= cost

func can_afford_weapon(weapon_id: String) -> bool:
	"""Check if player can afford a weapon"""
	var cost = get_weapon_cost(weapon_id)
	return cost != -1 and coins >= cost

func _unlock_ship_for_player(ship_id: String) -> void:
	"""Unlock a ship for the player (integrate with save system)"""
	var game_state = get_node_or_null("/root/GameState")
	if game_state and game_state.has_method("unlock_ship"):
		game_state.unlock_ship(ship_id)
		# Trigger save after successful ship unlock
		_trigger_inventory_save()

func _add_item_to_player_inventory(item_id: String) -> bool:
	"""Add an item to player inventory (integrate with inventory system)"""
	var inventory_state = get_node_or_null("/root/InventoryState")
	if not inventory_state or not inventory_state.has_method("add_item_by_id"):
		return false
	
	# Ensure item exists in database first
	_ensure_item_in_database(item_id, "consumable")
	var success = inventory_state.add_item_by_id(item_id, 1)
	if success:
		_trigger_inventory_save()
	return success

func _add_weapon_to_player_inventory(weapon_id: String) -> bool:
	"""Add a weapon to player inventory (integrate with inventory system)"""
	var inventory_state = get_node_or_null("/root/InventoryState")
	if not inventory_state or not inventory_state.has_method("add_item_by_id"):
		return false
	
	# Ensure weapon exists in database first
	_ensure_item_in_database(weapon_id, "weapon")
	var success = inventory_state.add_item_by_id(weapon_id, 1)
	if success:
		_trigger_inventory_save()
	return success

func _ensure_item_in_database(item_id: String, category: String) -> void:
	"""Ensure item exists in ItemDatabase, create fallback if needed"""
	var item_database = get_node_or_null("/root/ItemDatabase")
	if not item_database:
		return
	
	# Check if item already exists
	if item_database.has_method("has_item") and item_database.has_item(item_id):
		return
	
	# Create fallback item definition
	var fallback_item = _create_fallback_item_definition(item_id, category)
	if not fallback_item.is_empty():
		if item_database.has_method("add_item"):
			item_database.add_item(item_id, fallback_item)

func _create_fallback_item_definition(item_id: String, category: String) -> Dictionary:
	"""Create a basic item definition for shop items"""
	var item_data = {
		"name": item_id,
		"category": category,
		"description": "Purchased from premium shop",
		"max_stack": 99,
		"icon_path": "",
		"rarity": "Common"
	}
	
	# Add specific details based on item_id
	match item_id:
		"HealthIncrease":
			item_data.name = "Health Pack"
			item_data.description = "Medical supplies that restore health points"
			item_data.icon_path = "res://assets/items/Consumables/HealthIncrease.png"
		"BucketOfCoffee":
			item_data.name = "Coffee"
			item_data.description = "Energy boost that increases speed temporarily"
			item_data.icon_path = "res://assets/items/Consumables/BucketOfCoffee.png"
		"Luck":
			item_data.name = "Lucky Charm"
			item_data.description = "Increases critical hit chance for a duration"
			item_data.icon_path = "res://assets/items/Consumables/Luck.png"
		"CandyCane":
			item_data.name = "Candy Cane"
			item_data.description = "Sweet treat that provides shield boost"
			item_data.icon_path = "res://assets/items/Consumables/CandyCane.png"
		"BrokenHeart":
			item_data.name = "Heart Repair"
			item_data.description = "Repairs damaged systems and restores health"
			item_data.icon_path = "res://assets/items/Consumables/BrokenHeart.png"
		"FireWeapon1":
			item_data.name = "Flamethrower"
			item_data.description = "Short-range fire damage weapon"
			item_data.icon_path = "res://assets/items/Weapons/Item_Icon/FireWeapon1.png"
		"PhaserBeams":
			item_data.name = "Phaser Beams"
			item_data.description = "Medium-range energy weapon"
			item_data.icon_path = "res://assets/items/Weapons/Item_Icon/PhaserBeams.png"
		"PhotonTorpedo":
			item_data.name = "Photon Torpedo"
			item_data.description = "Long-range torpedo with splash damage"
			item_data.icon_path = "res://assets/items/Weapons/Photon_Torpedo/PhotonTorpedoLingering.png"
		"BallisticBarrage":
			item_data.name = "Ballistic Barrage"
			item_data.description = "Rapid multi-shot barrage for crowd control"
			item_data.icon_path = "res://assets/items/Weapons/Item_Icon/BallisticBarrage.png"
		"DeathRay":
			item_data.name = "Death Ray"
			item_data.description = "High-damage focused beam weapon"
			item_data.icon_path = "res://assets/items/Weapons/Item_Icon/DeathRay.png"
		"ExplosiveMine":
			item_data.name = "Explosive Mines"
			item_data.description = "Deployable mines for area denial"
			item_data.icon_path = "res://assets/items/Weapons/Item_Icon/ExplosiveMine.png"
		"FreezeDamage1":
			item_data.name = "Freeze Ray"
			item_data.description = "Slows enemies with cold damage"
			item_data.icon_path = "res://assets/items/Weapons/Item_Icon/FreezeDamage1.png"
		"Torpedo":
			item_data.name = "Torpedo"
			item_data.description = "Standard torpedo weapon"
			item_data.icon_path = "res://assets/items/Weapons/Item_Icon/Torpedo.png"
		"VoidMagic":
			item_data.name = "Void Magic"
			item_data.description = "Mysterious void-based weapon"
			item_data.icon_path = "res://assets/items/Weapons/Item_Icon/VoidMagic.png"
		"ElectricFieldDrive":
			item_data.name = "Electric Field"
			item_data.description = "Area-of-effect electric damage"
			item_data.icon_path = "res://assets/items/Weapons/Item_Icon/ElectricFieldDrive.png"
		"Shield":
			item_data.name = "Shield Generator"
			item_data.description = "Generates a protective barrier that refreshes when not broken"
			item_data.icon_path = "res://assets/items/ShipUpgrade/Shield.png"
			item_data.category = "passive"
		"OrbBender":
			item_data.name = "Orb Magnet"
			item_data.description = "Pulls nearby orbs and buffs orb damage for a short time"
			item_data.icon_path = "res://assets/items/Passive/OrbBender.png"
			item_data.category = "passive"
		"AladdinsCarpet":
			item_data.name = "Flight Carpet"
			item_data.description = "Increases movement speed and dodge chance"
			item_data.icon_path = "res://assets/items/Passive/AladdinsCarpet.png"
			item_data.category = "passive"
		"PocketWatch":
			item_data.name = "Time Dilation"
			item_data.description = "Slows down nearby enemies temporarily"
			item_data.icon_path = "res://assets/items/Passive/PocketWatch.png"
			item_data.category = "passive"
		"DeathInfluence":
			item_data.name = "Death Influence"
			item_data.description = "Increases damage dealt at low health"
			item_data.icon_path = "res://assets/items/Passive/DeathInfluence.png"
			item_data.category = "passive"
		"LooseTooth":
			item_data.name = "Vengeance"
			item_data.description = "Reflects a portion of damage taken"
			item_data.icon_path = "res://assets/items/Passive/LooseTooth.png"
			item_data.category = "passive"
		"ShellShocked":
			item_data.name = "Shell Shock"
			item_data.description = "Increases armor and damage resistance"
			item_data.icon_path = "res://assets/items/Passive/ShellShocked.png"
			item_data.category = "passive"
		"TVRemote":
			item_data.name = "Remote Control"
			item_data.description = "Chance to confuse enemies on hit"
			item_data.icon_path = "res://assets/items/Passive/TVRemote.png"
			item_data.category = "passive"
		"TheBell":
			item_data.name = "Power Bell"
			item_data.description = "Periodic damage area around player"
			item_data.icon_path = "res://assets/items/Passive/TheBell.png"
			item_data.category = "passive"
		"WinXpLaptop":
			item_data.name = "Hacking Laptop"
			item_data.description = "Increases experience gain and coin collection"
			item_data.icon_path = "res://assets/items/Passive/WinXpLaptop.png"
			item_data.category = "passive"
	
	return item_data

func _trigger_inventory_save() -> void:
	"""Trigger save system to persist inventory changes"""
	var save_manager = get_node_or_null("/root/SaveManager")
	if save_manager and save_manager.has_method("quick_save"):
		save_manager.quick_save()
	elif save_manager and save_manager.has_method("save_game"):
		save_manager.save_game()

func get_coin_statistics() -> Dictionary:
	"""Get comprehensive coin statistics"""
	return {
		"current_coins": coins,
		"total_earned": total_coins_earned,
		"total_spent": total_coins_spent,
		"net_coins": total_coins_earned - total_coins_spent
	}

func get_trader_stock(_trader_id: String = "default") -> Array:
	"""Get trader stock data combining cost constants with item metadata"""
	var stock = []
	
	# Get item database for metadata
	var item_db = get_node_or_null("/root/ItemDatabase")
	
	# Add consumables and passives from ITEM_COSTS
	for item_id in ITEM_COSTS:
		var price = ITEM_COSTS[item_id]
		var offer = _create_offer_from_item_id(item_id, price, "consumable", item_db)
		if not offer.is_empty():
			stock.append(offer)
	
	# Add weapons from WEAPON_COSTS
	for item_id in WEAPON_COSTS:
		var price = WEAPON_COSTS[item_id]
		var offer = _create_offer_from_item_id(item_id, price, "weapon", item_db)
		if not offer.is_empty():
			stock.append(offer)
	
	# Add ships from SHIP_COSTS
	for item_id in SHIP_COSTS:
		var price = SHIP_COSTS[item_id]
		var offer = _create_offer_from_item_id(item_id, price, "ship", item_db)
		if not offer.is_empty():
			stock.append(offer)
	
	return stock

func _create_offer_from_item_id(item_id: String, price: int, category: String, item_db) -> Dictionary:
	"""Create offer dictionary from item_id with metadata from ItemDatabase"""
	var offer = {
		"id": item_id,
		"name": item_id,
		"description": "No description available",
		"icon_path": "",
		"icon": null,
		"price": price,
		"category": category,
		"rarity": "Common"
	}
	
	# Try to enrich with ItemCatalog data first (read-only integration)
	var item_catalog = get_node_or_null("/root/ItemCatalog")
	if item_catalog and item_catalog.has_method("get_item_display_info"):
		var info = item_catalog.get_item_display_info(item_id)
		if not info.is_empty():
			var info_name = info.get("display_name", "")
			if not String(info_name).is_empty():
				offer.name = info_name
			var info_desc = info.get("description", "")
			if not String(info_desc).is_empty():
				offer.description = info_desc
			var info_icon = info.get("icon", null)
			if info_icon != null:
				offer.icon = info_icon
			var info_icon_path = info.get("icon_path", "")
			if not String(info_icon_path).is_empty():
				offer.icon_path = info_icon_path
			var info_rarity = info.get("rarity", "")
			if not String(info_rarity).is_empty():
				offer.rarity = info_rarity
	
	# Fallback: enrich with ItemDatabase data (existing behavior preserved)
	if item_db and item_db.has_method("has_item") and item_db.has_method("get_item") and item_db.has_item(item_id):
		var item_obj = item_db.get_item(item_id)
		if item_obj:
			if item_obj.get("display_name"):
				offer.name = item_obj.get("display_name")
			if item_obj.get("description"):
				offer.description = item_obj.get("description")
			if item_obj.get("icon"):
				offer.icon = item_obj.get("icon")
			if item_obj.get("rarity"):
				offer.rarity = item_obj.get("rarity")
	
	# Fallback icon paths for known items
	if offer.icon_path.is_empty():
		offer.icon_path = _get_fallback_icon_path(item_id, category)
	
	return offer

func _get_fallback_icon_path(item_id: String, category: String) -> String:
	"""Get fallback icon path for known items"""
	match category:
		"consumable":
			return "res://assets/items/Consumables/" + item_id + ".png"
		"weapon":
			return "res://assets/items/Weapons/Item_Icon/" + item_id + ".png"
		"ship":
			return "res://assets/Ships/FactionShips/" + item_id + ".png"
		_:
			return ""
