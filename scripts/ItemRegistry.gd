extends Node
class_name ItemRegistry

## Central registry for all items and weapons
## Loads and manages individual item/weapon data files

# Item classes (preload to avoid shadowing global class names)
const HealthIncreaseItemClass = preload("res://scripts/items/HealthIncreaseItem.gd")
const BrokenHeartItemClass = preload("res://scripts/items/BrokenHeartItem.gd")
const OrbMasterItemClass = preload("res://scripts/items/OrbMasterItem.gd")
const LoveShieldItemClass = preload("res://scripts/items/LoveShieldItem.gd")

# Weapon data classes (for registry)
const PhaserBeamsDataClass = preload("res://scripts/weapons/PhaserBeamsData.gd")
const VoidMagicWeaponClass = preload("res://scripts/weapons/VoidMagicWeapon.gd")
const BallisticBarrageWeaponClass = preload("res://scripts/weapons/BallisticBarrageWeapon.gd")

# Registry storage
var items: Dictionary = {}
var weapons: Dictionary = {}

func _ready():
	_initialize_registry()

func _initialize_registry():
	# Initialize items
	_register_item("HealthIncrease", HealthIncreaseItemClass.new())
	_register_item("BrokenHeart", BrokenHeartItemClass.new())
	_register_item("OrbMaster", OrbMasterItemClass.new())
	_register_item("LoveShield", LoveShieldItemClass.new())
	
	# Initialize weapons - use WeaponData classes, not BaseWeapon classes
	_register_weapon("FX_PhaserBeams", PhaserBeamsDataClass.new())
	_register_weapon("VoidMagic", VoidMagicWeaponClass.new())
	_register_weapon("BallisticBarrage", BallisticBarrageWeaponClass.new())
	
	print("ItemRegistry: Initialized ", items.size(), " items and ", weapons.size(), " weapons")

func _register_item(item_id: String, item_data: ItemData):
	items[item_id] = item_data

func _register_weapon(weapon_id: String, weapon_data: WeaponData):
	weapons[weapon_id] = weapon_data

func get_item(item_id: String) -> ItemData:
	return items.get(item_id, null)

func get_weapon(weapon_id: String) -> WeaponData:
	return weapons.get(weapon_id, null)

func get_all_items() -> Dictionary:
	return items

func get_all_weapons() -> Dictionary:
	return weapons

func get_items_by_type(item_type: String) -> Array:
	var filtered_items = []
	for item in items.values():
		if item.type.contains(item_type):
			filtered_items.append(item)
	return filtered_items

func get_weapons_by_type(weapon_type: String) -> Array:
	var filtered_weapons = []
	for weapon in weapons.values():
		if weapon.type.contains(weapon_type):
			filtered_weapons.append(weapon)
	return filtered_weapons

func get_science_items() -> Array:
	return get_items_by_type("Science")

func get_magic_items() -> Array:
	return get_items_by_type("Magic")

func get_hybrid_items() -> Array:
	return get_items_by_type("Hybrid")

func get_science_weapons() -> Array:
	return get_weapons_by_type("Science")

func get_magic_weapons() -> Array:
	return get_weapons_by_type("Magic")

func get_hybrid_weapons() -> Array:
	return get_weapons_by_type("Hybrid")

func get_item_display_list() -> Array:
	var display_list = []
	for item_id in items:
		var item = items[item_id]
		display_list.append({
			"id": item_id,
			"name": item.name,
			"asset_path": item.asset_path,
			"type": item.type,
			"usage": item.usage,
			"description": item.description
		})
	return display_list

func get_weapon_display_list() -> Array:
	var display_list = []
	for weapon_id in weapons:
		var weapon = weapons[weapon_id]
		display_list.append({
			"id": weapon_id,
			"name": weapon.name,
			"asset_path": weapon.asset_path,
			"type": weapon.type,
			"integration": weapon.integration,
			"damage": weapon.damage,
			"description": weapon.description
		})
	return display_list

func create_world_item(item_id: String, position: Vector2) -> ItemPickup:
	"""Create an item pickup in the game world"""
	var item_pickup_scene = load("res://scenes/ItemPickup.tscn")
	if not item_pickup_scene:
		print("ItemRegistry: Failed to load ItemPickup scene")
		return null
	
	var item_pickup = item_pickup_scene.instantiate()
	if not item_pickup:
		print("ItemRegistry: Failed to instantiate ItemPickup")
		return null
	
	item_pickup.load_item(item_id)
	item_pickup.set_item_position(position)
	
	# Add to current scene
	get_tree().current_scene.add_child(item_pickup)
	
	return item_pickup

func create_random_world_item(position: Vector2, item_types: Array = []) -> ItemPickup:
	"""Create a random item pickup in the game world"""
	var available_items = items.keys()
	
	# Filter by type if specified
	if item_types.size() > 0:
		var filtered_items = []
		for item_type in item_types:
			filtered_items.append_array(get_items_by_type(item_type))
		available_items = filtered_items.map(func(item): return item.name)
	
	if available_items.size() == 0:
		return null
	
	# Pick random item
	var random_item_id = available_items[randi() % available_items.size()]
	return create_world_item(random_item_id, position)
