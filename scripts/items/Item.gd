class_name Item
extends Resource

# Core Properties
@export var id: String
@export var display_name: String
@export var description: String = ""
@export var icon: Texture2D
@export var max_stack: int = 1
@export var category: String
@export var rarity: String = "common"

# Custom properties
@export var properties: Dictionary = {}

# Equipment specific
@export var is_equippable: bool = false
@export var equipment_slot: String = ""

# Visuals
@export var model_path: String = ""
@export var icon_path: String = ""

# Gameplay properties
@export var value: int = 0
@export var weight: float = 0.0

# Signals
signal property_changed(property_name: String, old_value, new_value)

func _init(p_id: String = "", p_name: String = "", p_category: String = "") -> void:
    id = p_id
    display_name = p_name
    category = p_category

# Get a property with a default value if it doesn't exist
func get_property(prop_name: String, default_value = null):
    return properties.get(prop_name, default_value)

# Set a property and emit signal if it changed
func set_property(prop_name: String, prop_value) -> void:
    var old_value = properties.get(prop_name)
    if old_value != prop_value:
        properties[prop_name] = prop_value
        property_changed.emit(prop_name, old_value, prop_value)

# Create a deep copy of this item
func create_copy() -> Item:
    var new_item = Item.new()
    new_item.id = id
    new_item.display_name = display_name
    new_item.description = description
    new_item.icon = icon
    new_item.max_stack = max_stack
    new_item.category = category
    new_item.rarity = rarity
    new_item.properties = properties.duplicate(true)
    new_item.is_equippable = is_equippable
    new_item.equipment_slot = equipment_slot
    new_item.model_path = model_path
    new_item.icon_path = icon_path
    new_item.value = value
    new_item.weight = weight
    return new_item

# Convert item to dictionary for saving
func to_dict() -> Dictionary:
    return {
        "id": id,
        "name": display_name,
        "description": description,
        "icon_path": icon_path,
        "max_stack": max_stack,
        "category": category,
        "rarity": rarity,
        "properties": properties.duplicate(true),
        "is_equippable": is_equippable,
        "equipment_slot": equipment_slot,
        "model_path": model_path,
        "value": value,
        "weight": weight,
        "icon": icon # Include runtime icon reference
    }

# Create item from dictionary
static func from_dict(data: Dictionary) -> Item:
    var item = Item.new()
    item.id = data.get("id", "")
    item.display_name = data.get("name", "")
    item.description = data.get("description", "")
    item.icon_path = data.get("icon_path", "")
    item.max_stack = data.get("max_stack", 1)
    item.category = data.get("category", "misc")
    item.rarity = data.get("rarity", "common")
    item.properties = data.get("properties", {})
    item.is_equippable = data.get("is_equippable", false)
    item.equipment_slot = data.get("equipment_slot", "")
    item.model_path = data.get("model_path", "")
    item.value = data.get("value", 0)
    item.weight = data.get("weight", 0.0)
    
    # Load the icon if path is provided
    if item.icon_path:
        item.icon = load(item.icon_path)
        
    return item
