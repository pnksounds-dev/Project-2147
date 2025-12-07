extends Node

# This script initializes the item system and loads the item database

# Path to the items JSON file
const ITEMS_JSON_PATH = "res://data/items/items.json"

# Signal emitted when the item system is fully initialized
signal item_system_initialized(success: bool)

# Reference to the item database
var item_database: ItemDatabase

func _ready() -> void:
	# Create and initialize the item database
	item_database = ItemDatabase.new()
	item_database.database_loaded.connect(_on_database_loaded)
	
	# Load items from JSON
	var success = item_database.load_from_file(ITEMS_JSON_PATH)
	if not success:
		push_error("Failed to start loading item database")

# Called when the item database is done loading
func _on_database_loaded(success: bool) -> void:
	if success:
		print("Item system initialized successfully!")
		print("Loaded ", item_database.get_all_items().size(), " items")
	else:
		push_error("Failed to load item database")
	
	item_system_initialized.emit(success)

# Get the item database
static func get_database() -> ItemDatabase:
	# Try to find existing database in the scene tree
	var tree = Engine.get_main_loop()
	if tree:
		var db = tree.root.find_child("ItemDatabase", true, false)
		if db:
			return db
	
	# If not found, try to get the ItemSystem and return its database
	var item_system = tree.root.find_child("ItemSystem", true, false) if tree else null
	if item_system and item_system.has_method("get_item_database"):
		return item_system.get_item_database()
	
	# Last resort: create a new one (not ideal, but prevents crashes)
	push_warning("ItemDatabase not found in scene, creating a new one")
	var new_db = ItemDatabase.new()
	tree.root.add_child(new_db)
	return new_db

# Get an item by ID (convenience method)
static func get_item(item_id: String) -> Item:
	var db = get_database()
	return db.get_item(item_id) if db else null

# Create a new instance of an item by ID (convenience method)
static func create_item(item_id: String) -> Item:
	var db = get_database()
	return db.create_item(item_id) if db else null
