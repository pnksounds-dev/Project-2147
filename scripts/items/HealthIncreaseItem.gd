extends ItemData
class_name HealthIncreaseItem

func _init():
	name = "HealthIncrease"
	asset_path = "assets/items/HealthIncrease.png"
	type = "Science | Resources"
	usage = "Restores player health when used"
	description = "Medical supplies that restore health points"
	stack_size = 10
	base_value = 50
