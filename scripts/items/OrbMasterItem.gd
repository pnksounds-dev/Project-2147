extends ItemData
class_name OrbMasterItem

func _init():
	name = "OrbMaster"
	asset_path = "assets/items/Passive/OrbMaster.png"
	type = "Magic | Mana"
	usage = "pulls all nearby orbs towards the player"
	description = "Master orb - when activated, pulls all nearby orbs towards the player"
	stack_size = 1
	base_value = 200
