extends Node

const ItemCategoriesLib = preload("res://scripts/items/ItemCategories.gd")
const InventorySlotTypeClass = preload("res://scripts/InventorySlotType.gd")

signal inventory_changed
signal equipment_changed(slot: int, item_id)
signal system_ready

const GRID_WIDTH := 12
const GRID_HEIGHT := 8 # 12 wide, 8 deep (96 cargo slots)
const TOTAL_SLOTS := GRID_WIDTH * GRID_HEIGHT

func get_equipment_slots() -> Array:
	return [InventorySlotTypeClass.SlotType.WEAPON1, InventorySlotTypeClass.SlotType.WEAPON2, InventorySlotTypeClass.SlotType.PASSIVE1, InventorySlotTypeClass.SlotType.PASSIVE2, InventorySlotTypeClass.SlotType.CONSUMABLE, InventorySlotTypeClass.SlotType.ARMOR, InventorySlotTypeClass.SlotType.ACCESSORY]

func get_cargo_slot_count() -> int:
	return TOTAL_SLOTS

var equipped: Dictionary = {
	InventorySlotTypeClass.SlotType.WEAPON1: null,
	InventorySlotTypeClass.SlotType.WEAPON2: null,
	InventorySlotTypeClass.SlotType.PASSIVE1: null,
	InventorySlotTypeClass.SlotType.PASSIVE2: null,
	InventorySlotTypeClass.SlotType.CONSUMABLE: null,
	InventorySlotTypeClass.SlotType.ARMOR: null,
	InventorySlotTypeClass.SlotType.ACCESSORY: null,
}

var cargo: Array = []

var _next_instance_id: int = 1
var _instances: Dictionary = {}

var trash_buffer: Array = [] # Holds instance_ids staged for deletion
var ark_storage: Array = [] # Holds instance_ids stored at the Ark
var initialized: bool = false

var _item_definitions := {
	"auto_turret": {
		"name": "Auto Turret",
		"category": ItemCategoriesLib.WEAPON,
		"icon_path": "res://assets/items/Weapons/Item_Icon/AutoTurret.png",
	},
	"phasers": {
		"name": "Phaser Beams",
		"category": ItemCategoriesLib.WEAPON,
		"icon_path": "res://assets/items/Weapons/Item_Icon/PhaserBeams.png",
	},
	"turret_module": {
		"name": "Turret Module",
		"category": ItemCategoriesLib.PASSIVE,
		"icon_path": "res://assets/items/Weapons/Bullets/Bullet.png",
	},
	"ammo_pack": {
		"name": "Ammo Pack",
		"category": ItemCategoriesLib.CONSUMABLE,
		"icon_path": "res://assets/items/Consumables/BucketOfCoffee.png",
	},
	"health_pack": {
		"name": "Health Pack",
		"category": ItemCategoriesLib.CONSUMABLE,
		"icon_path": "res://assets/items/Consumables/HealthIncrease.png",
	},
	"HealthIncrease": {
		"name": "Health Increase",
		"category": ItemCategoriesLib.CONSUMABLE,
		"icon_path": "res://assets/items/Consumables/HealthIncrease.png",
	},
	"OrbMaster": {
		"name": "Orbmaster",
		"category": ItemCategoriesLib.CONSUMABLE,
		"icon_path": "res://assets/items/Passive/OrbMaster.png",
	},
	"BallisticBarrage": {
		"name": "Ballistic Barrage",
		"category": ItemCategoriesLib.WEAPON,
		"icon_path": "res://assets/items/Weapons/Item_Icon/BallisticBarrage.png",
	},
	"PhotonTorpedo": {
		"name": "Photon Torpedo",
		"category": ItemCategoriesLib.WEAPON,
		"icon_path": "res://assets/items/Weapons/Photon_Torpedo/PhotonTorpedoLingering.png",
	},
	"Shield": {
		"name": "Shield",
		"category": ItemCategoriesLib.PASSIVE,
		"icon_path": "res://assets/items/ShipUpgrade/Shield.png",
	},
	"SurgicallyEnhanced": {
		"name": "Surgically Enhanced",
		"category": ItemCategoriesLib.PASSIVE,
		"icon_path": "res://assets/items/ShipUpgrade/SurgicallyEnhanced.png",
	},
}

var _slot_category_map := {
	InventorySlotTypeClass.SlotType.WEAPON1: [ItemCategoriesLib.WEAPON],
	InventorySlotTypeClass.SlotType.WEAPON2: [ItemCategoriesLib.WEAPON],
	InventorySlotTypeClass.SlotType.PASSIVE1: [ItemCategoriesLib.PASSIVE, ItemCategoriesLib.UPGRADE, ItemCategoriesLib.WEAPON],
	InventorySlotTypeClass.SlotType.PASSIVE2: [ItemCategoriesLib.PASSIVE, ItemCategoriesLib.UPGRADE, ItemCategoriesLib.WEAPON],
	InventorySlotTypeClass.SlotType.CONSUMABLE: [ItemCategoriesLib.CONSUMABLE],
	InventorySlotTypeClass.SlotType.ARMOR: [ItemCategoriesLib.ARMOR],
	InventorySlotTypeClass.SlotType.ACCESSORY: [ItemCategoriesLib.ACCESSORY, ItemCategoriesLib.PASSIVE, ItemCategoriesLib.WEAPON],
}

func _enter_tree() -> void:
	add_to_group("inventory")
	add_to_group("inventory_state")

func _ready() -> void:
	_initialize_cargo()
	# Don't auto-initialize in _ready - let loading screen handle it

func initialize() -> void:
	"""Initialize inventory system for loading screen"""
	print("InventoryState: Initializing...")
	
	# Load latest save's inventory during startup
	_initialize_from_latest_save()
	
	initialized = true
	system_ready.emit()
	print("InventoryState: Initialization complete")

func _initialize_from_latest_save() -> void:
	"""Load inventory from latest save if available"""
	var save_manager = get_node_or_null("/root/SaveManager")
	if save_manager and save_manager.has_method("get_latest_save_data"):
		var latest_save = save_manager.get_latest_save_data()
		if latest_save and not latest_save.is_empty():
			from_save_dict(latest_save)
			print("InventoryState: Loaded inventory from latest save")
		else:
			print("InventoryState: No saves found, starting with empty inventory")
			reset_to_empty()
	else:
		print("InventoryState: SaveManager not found, starting with empty inventory")
		reset_to_empty()

func reset_to_empty() -> void:
	"""Public helper to clear inventory to an empty state and notify listeners."""
	_clear_all_state()
	# Emit signals so UI and systems update to reflect the cleared inventory
	inventory_changed.emit()
	for slot in equipped.keys():
		var item_id = ""
		if equipped[slot]:
			var instance = get_instance(equipped[slot])
			if not instance.is_empty():
				item_id = instance.get("item_id", "")
		equipment_changed.emit(slot, item_id)

func _initialize_cargo() -> void:
	cargo.resize(TOTAL_SLOTS)
	for i in range(TOTAL_SLOTS):
		cargo[i] = null

func _add_sample_items() -> void:
	equip_item(InventorySlotTypeClass.SlotType.WEAPON1, "auto_turret")
	equip_item(InventorySlotTypeClass.SlotType.WEAPON2, "phasers")
	equip_item(InventorySlotTypeClass.SlotType.PASSIVE1, "turret_module")
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

func equip_instance(slot: InventorySlotTypeClass.SlotType, instance_id: String) -> bool:
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

func equip_item(slot: InventorySlotTypeClass.SlotType, item_id: String) -> bool:
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

func unequip_item(slot: InventorySlotTypeClass.SlotType) -> Dictionary:
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

func move_equipped_instance(from_slot: InventorySlotTypeClass.SlotType, to_slot: InventorySlotTypeClass.SlotType) -> bool:
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
func get_equipped_item(slot: InventorySlotTypeClass.SlotType) -> Dictionary:
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

func can_equip_item(slot: InventorySlotTypeClass.SlotType, item_id: String) -> bool:
	return _slot_accepts_item(slot, item_id)

func can_place_in_cargo(_item_id: String) -> bool:
	return true

func _slot_accepts_item(slot: InventorySlotTypeClass.SlotType, item_id: String) -> bool:
	var categories: Array = _slot_category_map.get(slot, [])
	if categories.is_empty():
		return true
	var definition = _get_item_definition(item_id)
	if definition.is_empty():
		return false
	return definition.get("category", ItemCategoriesLib.MISC) in categories

func _get_item_definition(item_id: String) -> Dictionary:
	# First check internal definitions
	var internal_def: Dictionary = _item_definitions.get(item_id, {})
	
	# Fallback to ItemDatabase if item not found internally
	var db_dict: Dictionary = {}
	var item_database = get_node_or_null("/root/ItemDatabase")
	if item_database and item_database.has_method("has_item") and item_database.has_method("get_item") and item_database.has_item(item_id):
		var db_item = item_database.get_item(item_id)
		if db_item:
			if db_item.has_method("to_dict"):
				db_dict = db_item.to_dict()
			elif typeof(db_item) == TYPE_DICTIONARY:
				db_dict = db_item
			else:
				# Return empty dict if we got an object but it's not compatible
				push_warning("InventoryState: Item from database is not convertible to dictionary: " + item_id)
	
	if not internal_def.is_empty():
		if db_dict.is_empty():
			return internal_def
		# Merge definitions: internal values win, database fills in missing fields (like icon/icon_path)
		var merged: Dictionary = internal_def.duplicate(true)
		for key in db_dict.keys():
			if not merged.has(key) or merged[key] == null or (typeof(merged[key]) == TYPE_STRING and String(merged[key]).is_empty()):
				merged[key] = db_dict[key]
		return merged
	
	if not db_dict.is_empty():
		return db_dict
	
	# === FINAL FALLBACK ===
	# If item is completely unknown (e.g. brand new shop item not yet in JSON),
	# construct a minimal valid definition so it can be added to inventory.
	# This prevents purchase failures.
	return {
		"id": item_id,
		"name": item_id, # Fallback name
		"category": "misc",
		"max_stack": 99,
		"description": "Unknown item",
		"icon_path": "", # Will rely on Slot fallback or dynamic texture
		"rarity": "common"
	}

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

# === SAVE/LOAD SERIALIZATION (UNIFIED INVENTORY REFACTOR) ===

func to_save_dict() -> Dictionary:
	"""Serialize inventory state for saving."""
	var save_data = {
		"cargo": [],
		"equipped": {}
	}
	
	# Serialize cargo slots
	for i in range(TOTAL_SLOTS):
		if cargo[i]:
			save_data["cargo"].append(cargo[i].duplicate())
		else:
			save_data["cargo"].append({})
	
	# Serialize equipped slots
	for slot in equipped.keys():
		if equipped[slot]:
			var instance = get_instance(equipped[slot])
			if not instance.is_empty():
				save_data["equipped"][InventorySlotTypeClass.SlotType.keys()[slot]] = instance.duplicate()
			else:
				save_data["equipped"][InventorySlotTypeClass.SlotType.keys()[slot]] = {}
		else:
			save_data["equipped"][InventorySlotTypeClass.SlotType.keys()[slot]] = {}
	
	return save_data

func from_save_dict(data: Dictionary) -> void:
	"""Load inventory state from saved data."""
	# Clear current state
	_clear_all_state()
	
	# === MIGRATION: Handle old saves without inventory data ===
	if not data.has("inventory"):
		# For old saves, create empty inventory structure
		print("InventoryState: Migrating old save without inventory data")
		# Initialize with empty structure
		for i in range(TOTAL_SLOTS):
			cargo[i] = null
		for slot in equipped.keys():
			equipped[slot] = null
		# Emit signals to update UI
		inventory_changed.emit()
		for slot in equipped.keys():
			equipment_changed.emit(slot, "")
		return
	
	var inventory_data = data.get("inventory", {})
	
	# Load cargo slots
	var cargo_data = inventory_data.get("cargo", [])
	for i in range(min(TOTAL_SLOTS, cargo_data.size())):
		var slot_data = cargo_data[i]
		if not slot_data.is_empty():
			cargo[i] = slot_data.duplicate()
			var instance_id = slot_data.get("instance_id", "")
			if instance_id != "":
				_instances[instance_id] = slot_data.duplicate()
		else:
			cargo[i] = null
	
	# Load equipped slots
	var equipped_data = inventory_data.get("equipped", {})
	for slot_key in equipped_data:
		var slot_data = equipped_data[slot_key]
		if not slot_data.is_empty():
			# Convert string key back to InventorySlotTypeClass.SlotType enum
			var slot_enum = InventorySlotTypeClass.SlotType.get(slot_key)
			if slot_enum != null and equipped.has(slot_enum):
				var instance_id = slot_data.get("instance_id", "")
				if instance_id != "":
					_instances[instance_id] = slot_data.duplicate()
					equipped[slot_enum] = instance_id
				else:
					equipped[slot_enum] = null
		else:
			# Handle empty slots
			var slot_enum = InventorySlotTypeClass.SlotType.get(slot_key)
			if slot_enum != null and equipped.has(slot_enum):
				equipped[slot_enum] = null
	
	# Recompute next instance ID to avoid collisions when adding new items after load
	var max_index := 0
	for instance_id in _instances.keys():
		if typeof(instance_id) == TYPE_STRING and String(instance_id).begins_with("itm_"):
			var suffix := String(instance_id).substr(4)
			if suffix.is_valid_int():
				var num := int(suffix)
				if num > max_index:
					max_index = num
	_next_instance_id = max_index + 1

	# Emit signals to update UI
	inventory_changed.emit()
	for slot in equipped.keys():
		var item_id = ""
		if equipped[slot]:
			var instance = get_instance(equipped[slot])
			if not instance.is_empty():
				item_id = instance.get("item_id", "")
		equipment_changed.emit(slot, item_id)

func _clear_all_state() -> void:
	"""Clear all inventory state."""
	cargo.clear()
	cargo.resize(TOTAL_SLOTS)
	for i in range(TOTAL_SLOTS):
		cargo[i] = null
	
	for slot in equipped.keys():
		equipped[slot] = null
	
	_instances.clear()
	_next_instance_id = 1
	trash_buffer.clear()
	ark_storage.clear()
