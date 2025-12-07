extends ItemData
class_name ShieldItem

func _init():
	name = "Shield"
	asset_path = "assets/items/ShipUpgrade/Shield.png"
	type = "Science | Resources"
	usage = "Generates a protective barrier that absorbs incoming damage"
	description = "A reliable defensive barrier that refreshes periodically"
	stack_size = 1
	base_value = 180
