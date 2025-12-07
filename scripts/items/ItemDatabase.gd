extends Node

# Preload the Item class
const ItemClass = preload("res://scripts/items/Item.gd")

# Signal emitted when the database is fully loaded
signal database_loaded(success: bool)
signal system_ready

# Item definitions cache
var _items: Dictionary = {}
var _categories: Array[String] = []
var _is_loaded: bool = false

func _enter_tree() -> void:
	# Set up singleton
	if get_tree().get_first_node_in_group("item_database") == null:
		add_to_group("item_database")
		# Keep this node when changing scenes
		process_mode = Node.PROCESS_MODE_ALWAYS
	else:
		queue_free()

func _ready() -> void:
	# Ensure the database is initialized immediately
	initialize()

func initialize() -> void:
	"""Initialize item database for loading screen"""
	if _is_loaded:
		print("ItemDatabase: Already initialized, skipping")
		return
	
	print("ItemDatabase: Initializing...")
	
	# Try to load from JSON file first
	var json_path = "res://data/items/items.json"
	if FileAccess.file_exists(json_path):
		print("ItemDatabase: Loading from JSON file: ", json_path)
		if load_from_file(json_path):
			print("ItemDatabase: Successfully loaded from JSON")
		else:
			print("ItemDatabase: Failed to load from JSON, using fallback")
			_load_fallback_items()
	else:
		print("ItemDatabase: JSON file not found, using fallback items")
		_load_fallback_items()
	
	_is_loaded = true
	print("ItemDatabase: Initialization complete")
	system_ready.emit()

# Load items from a JSON file
func load_from_file(file_path: String) -> bool:
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("Failed to open item database file: %s" % file_path)
		database_loaded.emit(false)
		return false
	
	var json = JSON.new()
	var error = json.parse(file.get_as_text())
	if error != OK:
		push_error("JSON Parse Error: %s" % json.get_error_message())
		database_loaded.emit(false)
		return false
	
	return _process_item_data(json.get_data())

# Process the parsed JSON data
func _process_item_data(data: Dictionary) -> bool:
	if not data.has("items") or not data["items"] is Array:
		push_error("Invalid item database format: missing 'items' array")
		database_loaded.emit(false)
		return false
	
	_items.clear()
	var categories_set = {}
	
	for item_data in data["items"]:
		if not item_data.has("id"):
			push_warning("Skipping item with missing 'id' field")
			continue
		
		var item = ItemClass.new()
		item.id = item_data["id"]
		item.display_name = item_data.get("name", "Unnamed Item")
		item.description = item_data.get("description", "")
		item.max_stack = item_data.get("max_stack", 1)
		item.category = item_data.get("category", "misc")
		item.rarity = item_data.get("rarity", "common")
		item.is_equippable = item_data.get("equippable", false)
		item.equipment_slot = item_data.get("equipment_slot", "")
		item.model_path = item_data.get("model_path", "")
		item.icon_path = item_data.get("icon_path", "")
		item.value = item_data.get("value", 0)
		item.weight = item_data.get("weight", 0.0)
		
		# Load icon if path is provided and resource exists
		if item.icon_path:
			if ResourceLoader.exists(item.icon_path):
				item.icon = load(item.icon_path)
			else:
				push_warning("ItemDatabase: Icon not found for item '%s' at path '%s'" % [item.id, item.icon_path])
		
		# Add custom properties
		if item_data.has("properties") and item_data["properties"] is Dictionary:
			item.properties = item_data["properties"].duplicate()
		
		# Add to database
		_items[item.id] = item
		categories_set[item.category] = true
	
	# Update categories list (ensure typed Array[String])
	_categories.clear()
	for category in categories_set.keys():
		_categories.append(String(category))
	_is_loaded = true
	database_loaded.emit(true)
	return true

# Get an item by ID
func get_item(item_id: String) -> Item:
	if not _items.has(item_id):
		push_warning("Item not found: %s" % item_id)
		return null
	return _items[item_id]

# Get all items in a category
func get_items_in_category(category: String) -> Array[Item]:
	var result: Array[Item] = []
	for item in _items.values():
		if item.category == category:
			result.append(item)
	return result

# Get all available categories
func get_categories() -> Array[String]:
	return _categories.duplicate()

# Check if the database is loaded
func is_loaded() -> bool:
	return _is_loaded

# Get all items (use with caution, prefer specific lookups)
func get_all_items() -> Dictionary:
	return _items.duplicate()

# Check if an item exists
func has_item(item_id: String) -> bool:
	return _items.has(item_id)

# Add a new item definition at runtime (e.g. for fallbacks)
func add_item(item_id: String, data: Dictionary) -> void:
	if _items.has(item_id):
		return
		
	var item = ItemClass.new()
	item.id = item_id
	item.display_name = data.get("name", item_id)
	item.description = data.get("description", "")
	item.max_stack = data.get("max_stack", 1)
	item.category = data.get("category", "misc")
	item.rarity = data.get("rarity", "common")
	item.is_equippable = data.get("equippable", false)
	item.equipment_slot = data.get("equipment_slot", "")
	item.model_path = data.get("model_path", "")
	item.icon_path = data.get("icon_path", "")
	item.value = data.get("value", 0)
	item.weight = data.get("weight", 0.0)
	
	# Load icon if path is provided
	if item.icon_path:
		if ResourceLoader.exists(item.icon_path):
			item.icon = load(item.icon_path)
	
	# Add custom properties
	if data.has("properties") and data["properties"] is Dictionary:
		item.properties = data["properties"].duplicate()
	
	_items[item_id] = item
	
	# Update categories if needed
	if not _categories.has(item.category):
		_categories.append(item.category)

# Create a new item instance (useful for item drops or loot)
func create_item(item_id: String) -> Item:
	var item = get_item(item_id)
	if item:
		return item.create_copy()
	return null

func _load_fallback_items() -> void:
	"""Load minimal fallback items when JSON is not available"""
	print("ItemDatabase: Loading fallback items...")
	
	# Create basic items directly in code
	var basic_items = [
		{
			"id": "health_pack",
			"name": "Health Pack",
			"description": "Restores 50 health points",
			"category": "Consumable",
			"icon_path": "res://assets/items/Consumable/HealthPack.png",
			"stack_size": 10
		},
		{
			"id": "ammo_pack",
			"name": "Ammo Pack",
			"description": "Provides 100 rounds of ammunition",
			"category": "Consumable", 
			"icon_path": "res://assets/items/Consumable/AmmoPack.png",
			"stack_size": 20
		},
		{
			"id": "auto_turret",
			"name": "Auto Turret",
			"description": "Automatic weapon system",
			"category": "Weapon",
			"icon_path": "res://assets/items/Weapons/Item_Icon/AutoTurret.png",
			"stack_size": 1
		},
		{
			"id": "phasers",
			"name": "Phasers",
			"description": "Energy weapon system",
			"category": "Weapon",
			"icon_path": "res://assets/items/Weapon/Phasers.png",
			"stack_size": 1
		}
	]
	
	for item_data in basic_items:
		var item = ItemClass.new()
		item.id = item_data.id
		item.display_name = item_data.name
		item.description = item_data.description
		item.category = item_data.category
		item.stack_size = item_data.stack_size
		
		if item_data.icon_path:
			if ResourceLoader.exists(item_data.icon_path):
				item.icon = load(item_data.icon_path)
			else:
				push_warning("ItemDatabase: Fallback icon not found for item '%s' at path '%s'" % [item.id, item_data.icon_path])
		
		_items[item.id] = item
	
	_categories = ["Consumable", "Weapon"]
	print("ItemDatabase: Loaded ", _items.size(), " fallback items")
