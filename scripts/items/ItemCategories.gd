extends Object
class_name ItemCategories

const WEAPON := "weapon"
const PASSIVE := "passive"
const CONSUMABLE := "consumable"
const UPGRADE := "upgrade"
const ARMOR := "armor"
const ACCESSORY := "accessory"
const RESOURCE := "resource"
const QUEST_ITEM := "quest_item"
const MISC := "misc"

static func get_all() -> Array:
	return [
		WEAPON,
		PASSIVE,
		CONSUMABLE,
		UPGRADE,
		ARMOR,
		ACCESSORY,
		RESOURCE,
		QUEST_ITEM,
		MISC,
	]
