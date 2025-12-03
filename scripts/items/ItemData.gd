extends Resource
class_name ItemData

## Base class for all item data
## Individual items inherit from this class

@export var name: String
@export var asset_path: String
@export var type: String  # "Science | Resources", "Magic | Mana", "Hybrid | Resources + Mana"
@export var usage: String
@export var description: String
@export var stack_size: int = 1
@export var base_value: int = 0

func get_resource_type() -> String:
	if type.contains("Resources"):
		return "Resources"
	elif type.contains("Mana"):
		return "Mana"
	else:
		return "Hybrid"

func is_magic() -> bool:
	return type.contains("Magic")

func is_science() -> bool:
	return type.contains("Science")

func is_hybrid() -> bool:
	return type.contains("Hybrid")

func get_display_info() -> Dictionary:
	return {
		"name": name,
		"asset_path": asset_path,
		"type": type,
		"usage": usage,
		"description": description,
		"resource_type": get_resource_type(),
		"is_magic": is_magic(),
		"is_science": is_science(),
		"is_hybrid": is_hybrid()
	}
