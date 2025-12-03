extends Node
class_name InventoryState

const ItemCategoriesLib = preload("res://scripts/items/ItemCategories.gd")

signal inventory_changed
signal equipment_changed(slot: int, item_id)

const GRID_WIDTH := 9
const GRID_HEIGHT := 5
const TOTAL_SLOTS := GRID_WIDTH * GRID_HEIGHT

enum SlotType {
	WEAPON1,
	WEAPON2,
	PASSIVE1,
	PASSIVE2,
	CONSUMABLE,
	ARMOR,
	ACCESSORY
}

func get_equipment_slots() -> Array:
	return [SlotType.WEAPON1, SlotType.WEAPON2, SlotType.PASSIVE1, SlotType.PASSIVE2, SlotType.CONSUMABLE, SlotType.ARMOR, SlotType.ACCESSORY]

func get_cargo_slot_count() -> int:
	return TOTAL_SLOTS

var equipped: Dictionary = {
	SlotType.WEAPON1: null,
	SlotType.WEAPON2: null,
	SlotType.PASSIVE1: null,
	SlotType.PASSIVE2: null,
	SlotType.CONSUMABLE: null,
	SlotType.ARMOR: null,
	SlotType.ACCESSORY: null,
}

var cargo: Array = []

var _next_instance_id: int = 1
var _instances: Dictionary = {}

var trash_buffer: Array = []  # Holds instance_ids staged for deletion
var ark_storage: Array = []   # Holds instance_ids stored at the Ark

var _item_definitions := {
	"auto_turret": {
		"name": "Auto Turret",
		"category": ItemCategoriesLib.WEAPON,
	},
	"phasers": {
		"name": "Phaser Beams",
		"category": ItemCategoriesLib.WEAPON,
		"asset_path": "res://assets/items/Weapons/Item_Icon/PhaserBeams.png",
	},
	"turret_module": {
		"name": "Turret Module",
		"category": ItemCategoriesLib.PASSIVE,
	},
	"ammo_pack": {
		"name": "Ammo Pack",
		"category": ItemCategoriesLib.CONSUMABLE,
	},
	"health_pack": {
		"name": "Health Pack",
		"category": ItemCategoriesLib.CONSUMABLE,
	},
}

var _slot_category_map := {
	SlotType.WEAPON1: [ItemCategoriesLib.WEAPON],
	SlotType.WEAPON2: [ItemCategoriesLib.WEAPON],
	SlotType.PASSIVE1: [ItemCategoriesLib.PASSIVE, ItemCategoriesLib.UPGRADE, ItemCategoriesLib.WEAPON],
	SlotType.PASSIVE2: [ItemCategoriesLib.PASSIVE, ItemCategoriesLib.UPGRADE, ItemCategoriesLib.WEAPON],
	SlotType.CONSUMABLE: [ItemCategoriesLib.CONSUMABLE],
	SlotType.ARMOR: [ItemCategoriesLib.ARMOR],
	SlotType.ACCESSORY: [ItemCategoriesLib.ACCESSORY, ItemCategoriesLib.PASSIVE, ItemCategoriesLib.WEAPON],
}

func _ready() -> void:
	add_to_group("inventory")
	_initialize_cargo()
	_add_sample_items()

func _initialize_cargo() -> void:
	cargo.resize(TOTAL_SLOTS)
	for i in range(TOTAL_SLOTS):
		cargo[i] = null

func _add_sample_items() -> void:
	equip_item(SlotType.WEAPON1, "auto_turret")
	equip_item(SlotType.WEAPON2, "phasers")
	equip_item(SlotType.PASSIVE1, "turret_module")
	add_item_by_id("phasers", 1)
	add_item_by_id("ammo_pack", 50)
	add_item_by_id("health_pack", 3)

func _generate_instance_id() -> String:
	var id = "itm_%d" % _next_instance_id
	_next_instance_id += 1
	return id

func _get_category_max_stack(category: String) -> int:
	if category == ItemCategoriesLib.RESOURCE:
		# Resources stack with no limit - use 0 to represent "unlimited" internally
		return 0
	if category == ItemCategoriesLib.CONSUMABLE:
		# Consumables stack up to 100 by default
		return 100
	# Weapons, passives, upgrades, armor, accessories, misc, etc. default to non-stackable
	return 1

func add_item_by_id(item_id: String, quantity: int = 1) -> bool:
	if quantity <= 0:
		return false
	var item_def = _get_item_definition(item_id)
	if item_def.is_empty():
		push_warning("InventoryState: Unknown item_id '%s'" % item_id)
		return false
	var remaining := quantity
	var category: String = item_def.get("category", ItemCategoriesLib.MISC)
	var default_max_stack: int = _get_category_max_stack(category)
	var max_stack: int = item_def.get("max_stack", default_max_stack)
	# Treat 0 as unlimited stack size for resources
	if max_stack <= 0:
		max_stack = 0
	if max_stack > 1:
		for i in range(TOTAL_SLOTS):
			var slot = cargo[i]
			if slot and slot.get("item_id", "") == item_id and slot.get("quantity", 0) < max_stack:
				var space = max_stack - slot.get("quantity", 0)
				var to_add = min(remaining, space)
				slot["quantity"] += to_add
				remaining -= to_add
				cargo[i] = slot
				if remaining <= 0:
					inventory_changed.emit()
					return true
	for i in range(TOTAL_SLOTS):
		if not cargo[i]:
			var to_store: int
			if max_stack == 0:
				# Unlimited stack size: put all remaining into this slot
				to_store = remaining
			else:
				to_store = min(remaining, max_stack)
			var instance_id := _generate_instance_id()
			var instance := {
				"instance_id": instance_id,
				"item_id": item_id,
				"quantity": to_store,
				"rarity": "common",
				"rolled_stats": {},
				"favorite": false,
				"locked": false,
			}
			cargo[i] = instance
			_instances[instance_id] = instance
			remaining -= to_store
			if remaining <= 0:
				inventory_changed.emit()
				return true
	push_warning("InventoryState: Cargo full when adding '%s'" % item_id)
	return false

func add_item(item_data: Dictionary, quantity: int = 1) -> bool:
	var item_id = item_data.get("id", "")
	if item_id == "":
		push_warning("InventoryState: Cannot add legacy item without 'id'")
		return false
	if not _item_definitions.has(item_id):
		var category: String = item_data.get("category", ItemCategoriesLib.MISC)
		var default_max_stack: int = _get_category_max_stack(category)
		_item_definitions[item_id] = {
			"name": item_data.get("name", item_id),
			"category": category,
			"max_stack": item_data.get("max_stack", default_max_stack),
		}
	return add_item_by_id(item_id, quantity)

func equip_instance(slot: SlotType, instance_id: String) -> bool:
	if not equipped.has(slot):
		return false
	var inst := get_instance(instance_id)
	if inst.is_empty():
		return false
	var item_id: String = inst.get("item_id", "")
	if item_id == "":
		return false
	if not _slot_accepts_item(slot, item_id):
		return false
	equipped[slot] = instance_id
	equipment_changed.emit(slot, item_id)
	inventory_changed.emit()
	return true

func equip_item(slot: SlotType, item_id: String) -> bool:
	if not equipped.has(slot):
		return false
	if not _slot_accepts_item(slot, item_id):
		return false
	# Create a simple instance not stored in cargo (used for sample/demo equip)
	var instance_id := _generate_instance_id()
	var instance := {
		"instance_id": instance_id,
		"item_id": item_id,
		"quantity": 1,
		"rarity": "common",
		"rolled_stats": {},
		"favorite": false,
		"locked": false,
	}
	_instances[instance_id] = instance
	equipped[slot] = instance_id
	equipment_changed.emit(slot, item_id)
	inventory_changed.emit()
	return true

func unequip_item(slot: SlotType) -> Dictionary:
	if not equipped.has(slot) or not equipped[slot]:
		return {}
	var instance_id: String = equipped[slot]
	var inst := get_instance(instance_id)
	if instance_id != "" and _instances.has(instance_id):
		_instances.erase(instance_id)
	equipped[slot] = null
	equipment_changed.emit(slot, null)
	inventory_changed.emit()
	return inst

func move_equipped_instance(from_slot: SlotType, to_slot: SlotType) -> bool:
	if from_slot == to_slot:
		return true
	if not equipped.has(from_slot) or not equipped.has(to_slot):
		return false
	var source_id = equipped[from_slot]
	if not source_id:
		return false
	var source_instance := get_instance(source_id)
	if source_instance.is_empty():
		return false
	var source_item_id: String = source_instance.get("item_id", "")
	if source_item_id == "":
		return false
	if not _slot_accepts_item(to_slot, source_item_id):
		return false
	var target_id = equipped[to_slot]
	if target_id:
		var target_instance := get_instance(target_id)
		if target_instance.is_empty():
			target_id = null
		else:
			var target_item_id: String = target_instance.get("item_id", "")
			if target_item_id == "" or not _slot_accepts_item(from_slot, target_item_id):
				return false
	equipped[to_slot] = source_id
	equipped[from_slot] = target_id
	equipment_changed.emit(to_slot, source_item_id)
	if target_id:
		var swapped_instance := get_instance(target_id)
		var swapped_item_id: String = swapped_instance.get("item_id", "")
		equipment_changed.emit(from_slot, swapped_item_id)
	else:
		equipment_changed.emit(from_slot, null)
	inventory_changed.emit()
	return true

## Returns a dictionary of all equipped items with their slot indices as keys
func get_equipped_items() -> Dictionary:
	var items = {}
	for slot in equipped.keys():
		if equipped[slot]:
			var instance = get_instance(equipped[slot])
			if not instance.is_empty():
				items[slot] = instance.duplicate()
	return items

## Get a specific equipped item by slot type
func get_equipped_item(slot: SlotType) -> Dictionary:
	if equipped.has(slot) and equipped[slot]:
		var instance_id: String = equipped[slot]
		return get_instance(instance_id)
	return {}

func get_cargo_item(index: int) -> Dictionary:
	if index >= 0 and index < cargo.size() and cargo[index]:
		return cargo[index]
	return {}

func swap_cargo_items(index1: int, index2: int) -> bool:
	if index1 == index2:
		return true
	if _is_valid_slot_index(index1) and _is_valid_slot_index(index2):
		var temp = cargo[index1]
		cargo[index1] = cargo[index2]
		cargo[index2] = temp
		inventory_changed.emit()
		return true
	return false

func remove_cargo_item(index: int, quantity: int = 1) -> Dictionary:
	if not _is_valid_slot_index(index):
		return {}
	var slot = cargo[index]
	if not slot:
		return {}
	var current_qty: int = slot.get("quantity", 0)
	if quantity >= current_qty:
		# Removing the whole stack - also clean up instance registry
		var instance_id = slot.get("instance_id", "")
		if instance_id != "" and _instances.has(instance_id):
			_instances.erase(instance_id)
		cargo[index] = null
		inventory_changed.emit()
		return slot
	slot["quantity"] = current_qty - quantity
	cargo[index] = slot
	inventory_changed.emit()
	return {
		"item_id": slot.get("item_id", ""),
		"quantity": quantity,
	}

func can_equip_item(slot: SlotType, item_id: String) -> bool:
	return _slot_accepts_item(slot, item_id)

func can_place_in_cargo(_item_id: String) -> bool:
	return true

func _slot_accepts_item(slot: SlotType, item_id: String) -> bool:
	var categories: Array = _slot_category_map.get(slot, [])
	if categories.is_empty():
		return true
	var definition = _get_item_definition(item_id)
	if definition.is_empty():
		return false
	return definition.get("category", ItemCategoriesLib.MISC) in categories

func _get_item_definition(item_id: String) -> Dictionary:
	return _item_definitions.get(item_id, {})

func _is_valid_slot_index(index: int) -> bool:
	return index >= 0 and index < cargo.size()

func get_item_definition(item_id: String) -> Dictionary:
	return _get_item_definition(item_id)

func get_instance(instance_id: String) -> Dictionary:
	return _instances.get(instance_id, {})

func get_all_instances() -> Dictionary:
	return _instances

func set_locked(instance_id: String, locked: bool) -> void:
	var inst: Dictionary = _instances.get(instance_id, {})
	if inst == null:
		return
	inst["locked"] = locked
	inventory_changed.emit()

func set_favorite(instance_id: String, favorite: bool) -> void:
	var inst: Dictionary = _instances.get(instance_id, {})
	if inst == null:
		return
	inst["favorite"] = favorite
	inventory_changed.emit()

func is_locked(instance_id: String) -> bool:
	var inst: Dictionary = _instances.get(instance_id, {})
	if inst == null:
		return false
	return inst.get("locked", false)

func is_favorite(instance_id: String) -> bool:
	var inst: Dictionary = _instances.get(instance_id, {})
	if inst == null:
		return false
	return inst.get("favorite", false)

func can_delete_item(instance_id: String) -> bool:
	var inst: Dictionary = _instances.get(instance_id, {})
	if inst == null:
		return false
	if inst.get("locked", false):
		return false
	return true

func can_move_item(instance_id: String, _from_inventory: String, _to_inventory: String) -> bool:
	var inst: Dictionary = _instances.get(instance_id, {})
	if inst == null:
		return false
	if inst.get("locked", false):
		return false
	return true

func delete_instance_from_cargo(index: int) -> bool:
	if not _is_valid_slot_index(index):
		return false
	var slot = cargo[index]
	if not slot:
		return false
	var instance_id: String = slot.get("instance_id", "")
	if instance_id == "":
		return false
	if not can_delete_item(instance_id):
		return false
	if _instances.has(instance_id):
		_instances.erase(instance_id)
	cargo[index] = null
	inventory_changed.emit()
	return true

func clear_cargo_slot(index: int) -> void:
	if not _is_valid_slot_index(index):
		return
	cargo[index] = null
	inventory_changed.emit()

func set_cargo_slot(index: int, instance: Dictionary) -> bool:
	if not _is_valid_slot_index(index):
		return false
	if instance.is_empty():
		return false
	cargo[index] = instance
	var instance_id: String = instance.get("instance_id", "")
	if instance_id != "":
		_instances[instance_id] = instance
	inventory_changed.emit()
	return true

func add_to_trash_from_cargo(cargo_index: int) -> bool:
	if not _is_valid_slot_index(cargo_index):
		return false
	var slot = cargo[cargo_index]
	if not slot:
		return false
	var instance_id: String = slot.get("instance_id", "")
	if instance_id == "":
		return false
	if not can_move_item(instance_id, "cargo", "trash"):
		return false
	trash_buffer.append(instance_id)
	cargo[cargo_index] = null
	inventory_changed.emit()
	return true

func restore_from_trash_to_cargo(instance_id: String) -> bool:
	if not trash_buffer.has(instance_id):
		return false
	for i in range(TOTAL_SLOTS):
		if not cargo[i]:
			cargo[i] = get_instance(instance_id)
			trash_buffer.erase(instance_id)
			inventory_changed.emit()
			return true
	return false

func delete_trash_contents() -> void:
	for instance_id in trash_buffer:
		if can_delete_item(instance_id) and _instances.has(instance_id):
			_instances.erase(instance_id)
	trash_buffer.clear()
	inventory_changed.emit()

func deposit_from_cargo_to_ark(cargo_index: int) -> bool:
	if not _is_valid_slot_index(cargo_index):
		return false
	var slot = cargo[cargo_index]
	if not slot:
		return false
	var instance_id: String = slot.get("instance_id", "")
	if instance_id == "":
		return false
	if not can_move_item(instance_id, "cargo", "ark"):
		return false
	ark_storage.append(instance_id)
	cargo[cargo_index] = null
	inventory_changed.emit()
	return true

func withdraw_from_ark_to_cargo(ark_index: int) -> bool:
	if ark_index < 0 or ark_index >= ark_storage.size():
		return false
	var instance_id: String = ark_storage[ark_index]
	if instance_id == "":
		return false
	for i in range(TOTAL_SLOTS):
		if not cargo[i]:
			cargo[i] = get_instance(instance_id)
			ark_storage.remove_at(ark_index)
			inventory_changed.emit()
			return true
	return false
