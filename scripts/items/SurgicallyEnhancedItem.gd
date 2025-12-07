extends ItemData
class_name SurgicallyEnhancedItem

func _init():
	name = "SurgicallyEnhanced"
	asset_path = "assets/items/ShipUpgrade/SurgicallyEnhanced.png"
	type = "Science | Resources"
	usage = "Boosts damage and crit at the cost of maximum health"
	description = "Experimental augmentations grant extra power but reduce overall resilience"
	stack_size = 1
	base_value = 240
