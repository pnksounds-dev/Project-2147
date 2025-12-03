extends Resource
class_name WeaponData

## Base class for all weapon data
## Individual weapons inherit from this class

@export var name: String
@export var asset_path: String
@export var type: String  # "Science | Resources", "Magic | Mana", "Hybrid | Resources + Mana"
@export var integration: String
@export var damage: String
@export var animation: String
@export var description: String
@export var weapon_system_enum: String  # WeaponType.PHASER, etc.
@export var projectile_scene: String  # Path to projectile scene if applicable
@export var fire_rate: float = 1.0
@export var base_damage: int = 10

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
		"integration": integration,
		"damage": damage,
		"animation": animation,
		"description": description,
		"resource_type": get_resource_type(),
		"is_magic": is_magic(),
		"is_science": is_science(),
		"is_hybrid": is_hybrid()
	}

func get_weapon_config() -> Dictionary:
	return {
		"name": name,
		"fire_rate": fire_rate,
		"damage": base_damage,
		"projectile_scene": projectile_scene,
		"weapon_system_enum": weapon_system_enum
	}
