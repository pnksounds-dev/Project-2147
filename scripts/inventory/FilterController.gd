extends Node
class_name FilterController

# Manages inventory filtering and search functionality

signal filter_changed(new_filter: String)
signal filter_buttons_updated()

# Filter constants
const FILTER_ALL := "all"
const FILTER_WEAPONS := "weapons"
const FILTER_PASSIVES := "passives"
const FILTER_CONSUMABLES := "consumables"

var _all_button: Button
var _weapon_button: Button
var _passive_button: Button
var _consumable_button: Button
var _inventory_state: InventoryState

var current_filter: String = FILTER_ALL

func initialize(all_button: Button, weapon_button: Button, passive_button: Button, 
				consumable_button: Button, inventory_state: InventoryState) -> void:
	_all_button = all_button
	_weapon_button = weapon_button
	_passive_button = passive_button
	_consumable_button = consumable_button
	_inventory_state = inventory_state
	
	# Connect button signals
	_all_button.pressed.connect(_on_filter_all_pressed)
	_weapon_button.pressed.connect(_on_filter_weapons_pressed)
	_passive_button.pressed.connect(_on_filter_passives_pressed)
	_consumable_button.pressed.connect(_on_filter_consumables_pressed)

func set_filter(filter: String) -> void:
	"""Set the current filter"""
	if filter in [FILTER_ALL, FILTER_WEAPONS, FILTER_PASSIVES, FILTER_CONSUMABLES]:
		current_filter = filter
		_update_filter_button_states()
		filter_changed.emit(filter)

func get_current_filter() -> String:
	"""Get the current filter"""
	return current_filter

func item_matches_filter(item_id: String) -> bool:
	"""Check if an item matches the current filter"""
	if current_filter == FILTER_ALL:
		return true
	
	var item_data: Dictionary = _get_item_data(item_id)
	var category: String = str(item_data.get("category", "")).to_lower()
	
	match current_filter:
		FILTER_WEAPONS:
			return category == "weapon" or category == "weapons"
		FILTER_PASSIVES:
			return category == "passive" or category == "passives"
		FILTER_CONSUMABLES:
			return category == "consumable" or category == "consumables"
		_:
			return true

func get_filtered_items() -> Array[Dictionary]:
	"""Get all items that match the current filter"""
	var filtered_items: Array[Dictionary] = []
	
	if not _inventory_state:
		return filtered_items
	
	# Get all cargo items
	var total_slots = _inventory_state.get_cargo_slot_count()
	for i in range(total_slots):
		var slot_contents: Dictionary = _inventory_state.get_cargo_item(i)
		var item_id: String = str(slot_contents.get("item_id", ""))
		
		if item_id == "":
			continue
		
		if item_matches_filter(item_id):
			slot_contents["original_cargo_index"] = i
			filtered_items.append(slot_contents)
	
	return filtered_items

func _on_filter_all_pressed() -> void:
	set_filter(FILTER_ALL)

func _on_filter_weapons_pressed() -> void:
	set_filter(FILTER_WEAPONS)

func _on_filter_passives_pressed() -> void:
	set_filter(FILTER_PASSIVES)

func _on_filter_consumables_pressed() -> void:
	set_filter(FILTER_CONSUMABLES)

func _update_filter_button_states() -> void:
	"""Update visual state of filter buttons"""
	_all_button.button_pressed = (current_filter == FILTER_ALL)
	_weapon_button.button_pressed = (current_filter == FILTER_WEAPONS)
	_passive_button.button_pressed = (current_filter == FILTER_PASSIVES)
	_consumable_button.button_pressed = (current_filter == FILTER_CONSUMABLES)
	
	filter_buttons_updated.emit()

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

func get_filter_stats() -> Dictionary:
	"""Get statistics about items in each filter category"""
	var stats = {
		"all": 0,
		"weapons": 0,
		"passives": 0,
		"consumables": 0
	}
	
	if not _inventory_state:
		return stats
	
	var total_slots = _inventory_state.get_cargo_slot_count()
	for i in range(total_slots):
		var slot_contents: Dictionary = _inventory_state.get_cargo_item(i)
		var item_id: String = str(slot_contents.get("item_id", ""))
		
		if item_id == "":
			continue
		
		var item_data: Dictionary = _get_item_data(item_id)
		var category: String = str(item_data.get("category", "")).to_lower()
		
		stats.all += 1
		
		if category == "weapon" or category == "weapons":
			stats.weapons += 1
		elif category == "passive" or category == "passives":
			stats.passives += 1
		elif category == "consumable" or category == "consumables":
			stats.consumables += 1
	
	return stats
