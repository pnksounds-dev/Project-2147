extends ItemData
class_name LoveShieldItem

func _init():
	name = "LoveShield"
	asset_path = "assets/items/LoveShield.png"
	type = "Magic | Mana"
	usage = "Unique protective shield with special properties - creates ring of hearts around player"
	description = "Special themed shield with unique defensive capabilities"
	stack_size = 1
	base_value = 150
