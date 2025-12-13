extends Node
class_name SlotManager

# Preload required classes
const InventorySlotTypeClass = preload("res://scripts/InventorySlotType.gd")

# Manages slot creation, updates, and organization

signal slot_created(slot: Control, slot_type: String, index: int)
signal slots_updated()

const ItemSlotScene: PackedScene = preload("res://scenes/UI/ItemSlot.tscn")

var _inventory_container: Control
var _weapon_container: HBoxContainer
var _passive_container: HBoxContainer
var _consumable_container: HBoxContainer
var _inventory_state: InventoryState

func initialize(inventory_container: Control, weapon_container: HBoxContainer, 
				passive_container: HBoxContainer, consumable_container: HBoxContainer,
				inventory_state: InventoryState) -> void:
	_inventory_container = inventory_container
	_weapon_container = weapon_container
	_passive_container = passive_container
	_consumable_container = consumable_container
	_inventory_state = inventory_state

func clear_equipment_containers() -> void:
	"""Clear all equipment slot containers"""
	for child in _weapon_container.get_children():
		child.queue_free()
	for child in _passive_container.get_children():
		child.queue_free()
	for child in _consumable_container.get_children():
		child.queue_free()

func create_equipment_slots() -> void:
	"""Create and populate equipment slots organized by type"""
	if not _inventory_state:
		return
		
	var equip_slots: Array = _inventory_state.get_equipment_slots()
	
	for slot_index in equip_slots.size():
		var slot_type: InventorySlotTypeClass.SlotType = equip_slots[slot_index]
		var item_slot = ItemSlotScene.instantiate()
		
		# Set slot kind and container based on type
		var target_container: HBoxContainer
		match slot_type:
			InventorySlotTypeClass.SlotType.WEAPON1, InventorySlotTypeClass.SlotType.WEAPON2:
				item_slot.slot_kind = item_slot.SlotKind.EQUIPPED_WEAPON
				target_container = _weapon_container
			InventorySlotTypeClass.SlotType.PASSIVE1, InventorySlotTypeClass.SlotType.PASSIVE2, InventorySlotTypeClass.SlotType.ACCESSORY:
				item_slot.slot_kind = item_slot.SlotKind.EQUIPPED_PASSIVE
				target_container = _passive_container
			InventorySlotTypeClass.SlotType.CONSUMABLE:
				item_slot.slot_kind = item_slot.SlotKind.EQUIPPED_CONSUMABLE
				target_container = _consumable_container
			_:
				continue  # Skip unknown slot types
		
		# Set slot properties and content
		item_slot.equipment_slot = slot_type
		var contents: Dictionary = _inventory_state.get_equipped_item(slot_type)
		item_slot.set_item(contents)
		
		# Add to container
		target_container.add_child(item_slot)
		
		# Set slot metadata for drag drop handler
		item_slot.set_meta("slot_type", "equipment")
		item_slot.set_meta("slot_index", slot_index)
		item_slot.set_meta("equip_slot_enum", slot_type)
		item_slot.set_meta("slot_data", {
			"slot_type": "equipment",
			"slot_index": slot_index,
			"equip_slot_enum": slot_type
		})
		
		slot_created.emit(item_slot, "equipment", slot_index)

func update_cargo_slots(filter: String = "all", _slot_size: float = 64.0) -> void:
	"""Update cargo slots with filtered items"""
	if not _inventory_state or not _inventory_container:
		return
	
	# Ensure we have one visual slot per cargo slot in state
	_ensure_cargo_slot_count()
	var cargo_slots = _inventory_container.get_children()
	
	# Collect filtered items
	var filtered_items: Array[Dictionary] = []
	var total_slots: int = _inventory_state.get_cargo_slot_count()
	
	for i in range(total_slots):
		var slot_contents: Dictionary = _inventory_state.get_cargo_item(i)
		var item_id: String = str(slot_contents.get("item_id", ""))
		
		if item_id == "":
			continue
		
		# Check if item matches filter
		if _item_matches_filter(item_id, filter):
			slot_contents["original_cargo_index"] = i
			filtered_items.append(slot_contents)
	
	# Update each slot
	for i in range(cargo_slots.size()):
		var slot_node = cargo_slots[i] as Control
		if not slot_node or not slot_node.has_method("set_item"):
			continue
		
		# Keep consistent slot size and transform
		slot_node.custom_minimum_size = Vector2(_slot_size, _slot_size)
		slot_node.size = Vector2(_slot_size, _slot_size)
		slot_node.scale = Vector2.ONE
		
		# Set slot properties
		slot_node.slot_kind = slot_node.SlotKind.BACKPACK
		slot_node.cargo_index = i
		
		# Set slot metadata for drag drop handler
		slot_node.set_meta("slot_type", "cargo")
		slot_node.set_meta("slot_index", i)
		
		# Set content or clear
		if i < filtered_items.size():
			var item_data = filtered_items[i]
			slot_node.set_item(item_data)
			slot_node.set_meta("original_cargo_index", item_data.get("original_cargo_index", i))
			slot_node.set_meta("slot_data", {
				"slot_type": "cargo",
				"slot_index": i,
				"item_data": item_data
			})
		else:
			slot_node.clear()
			slot_node.set_meta("original_cargo_index", -1)
			slot_node.set_meta("slot_data", {
				"slot_type": "cargo",
				"slot_index": i,
				"item_data": {}
			})
		
		slot_created.emit(slot_node, "cargo", i)
	
	slots_updated.emit()

func _ensure_cargo_slot_count() -> void:
	if not _inventory_state or not _inventory_container:
		return
	
	var desired: int = _inventory_state.get_cargo_slot_count()
	var current: int = _inventory_container.get_child_count()
	
	# Add missing slots
	for i in range(current, desired):
		var slot = ItemSlotScene.instantiate()
		_inventory_container.add_child(slot)

func initialize_static_cargo_slots() -> void:
	"""Initialize static cargo slots with default properties"""
	if not _inventory_container:
		return
		
	var cargo_slots = _inventory_container.get_children()
	for i in range(cargo_slots.size()):
		var slot_node = cargo_slots[i] as Control
		if not slot_node:
			continue
		
		if "slot_kind" in slot_node:
			slot_node.slot_kind = slot_node.SlotKind.BACKPACK
		if "cargo_index" in slot_node:
			slot_node.cargo_index = i

func _item_matches_filter(item_id: String, filter: String) -> bool:
	"""Check if an item matches the filter"""
	if filter == "all":
		return true
	
	var item_data: Dictionary = _get_item_data(item_id)
	var category: String = str(item_data.get("category", "")).to_lower()
	
	match filter:
		"weapons":
			return category == "weapon" or category == "weapons"
		"passives":
			return category == "passive" or category == "passives"
		"consumables":
			return category == "consumable" or category == "consumables"
		_:
			return true

func _get_item_data(item_id: String) -> Dictionary:
	"""Get item data from registry or inventory state"""
	var item_registry = get_tree().get_first_node_in_group("item_registry")
	if item_registry and item_registry.has_method("get_item_data"):
		var data = item_registry.get_item_data(item_id)
		if not data.is_empty():
			return data
	
	if _inventory_state and _inventory_state.has_method("_get_item_definition"):
		return _inventory_state._get_item_definition(item_id)
	
	return {}
