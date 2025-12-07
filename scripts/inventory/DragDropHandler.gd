extends Node
class_name DragDropHandler

# Manages all drag and drop operations for the inventory

signal drag_started(item_data: Dictionary, from_slot: Control, from_type: String, from_index: int)
signal drag_ended()
signal drop_completed(success: bool, to_slot: Control, to_type: String, to_index: int)
signal quick_unequip_requested(slot: Control, slot_type: String, slot_index: int)

var is_dragging: bool = false
var dragged_item: Dictionary = {}
var dragged_slot_type: String = ""
var dragged_slot_index: int = -1
var dragged_instance_id: String = ""
var dragged_from_cargo_index: int = -1
var dragged_from_equip_slot: int = -1
var dragged_item_ui: Control = null

var _inventory_state: InventoryState
var _root_control: Control

func initialize(inventory_state: InventoryState, root_control: Control) -> void:
	_inventory_state = inventory_state
	_root_control = root_control

func handle_slot_input(event: InputEvent, slot: Control) -> void:
	"""Handle input events on inventory slots"""
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_start_drag(slot)
			else:
				_handle_drop(slot.get_global_position())
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_handle_right_click(slot)

func _start_drag(slot: Control) -> void:
	"""Start dragging an item from a slot"""
	if not slot or not slot.has_meta("slot_data"):
		return
	
	# Ensure any local hover highlight is turned off when drag begins
	var hover = slot.get_node_or_null("HoverHighlight")
	if hover and hover is CanvasItem:
		hover.visible = false
	
	var slot_data: Dictionary = slot.get_meta("slot_data")
	var item_data: Dictionary = _get_slot_item_data(slot)
	
	if item_data.is_empty():
		return
	
	# Set drag state
	dragged_item = item_data
	dragged_slot_type = slot_data.get("slot_type", "")
	dragged_slot_index = slot_data.get("slot_index", -1)
	dragged_instance_id = item_data.get("instance_id", "")
	
	# Track original indices for proper mapping
	if dragged_slot_type == "cargo":
		dragged_from_cargo_index = slot.get_meta("original_cargo_index", dragged_slot_index)
	elif dragged_slot_type == "special" or dragged_slot_type == "equipment":
		dragged_from_equip_slot = slot_data.get("slot_index", -1)
	
	is_dragging = true
	
	# Create dragged item UI
	_create_dragged_item_ui(item_data, slot)
	
	drag_started.emit(item_data, slot, dragged_slot_type, dragged_slot_index)

func _handle_drop(drop_position: Vector2) -> void:
	"""Handle dropping a dragged item"""
	if not is_dragging:
		return
	
	var success: bool = false
	var target_slot: Control = null
	var target_type: String = ""
	var target_index: int = -1
	
	# Find the slot under the drop position
	var slots_at_position = _get_slots_at_position(drop_position)
	if not slots_at_position.is_empty():
		target_slot = slots_at_position[0]
		target_type = target_slot.get_meta("slot_type", "")
		target_index = target_slot.get_meta("slot_index", -1)
		
		# Attempt to complete the drop
		success = _complete_drop(target_slot, target_type, target_index)
	
	# Clean up
	_cleanup_drag()
	
	drag_ended.emit()
	drop_completed.emit(success, target_slot, target_type, target_index)

func _complete_drop(target_slot: Control, target_type: String, target_index: int) -> bool:
	"""Complete the drop operation"""
	if not _inventory_state:
		return false
	
	# Cannot drop on the same slot
	if target_type == dragged_slot_type and target_index == dragged_slot_index:
		return false
	
	# Handle different drop scenarios
	match target_type:
		"cargo":
			return _drop_on_cargo(target_slot, target_index)
		"special", "equipment":
			return _drop_on_equipment(target_slot, target_type, target_index)
		_:
			return false

func _drop_on_cargo(target_slot: Control, target_index: int) -> bool:
	"""Handle dropping on cargo slot"""
	var original_target_index = target_slot.get_meta("original_cargo_index", target_index)
	
	# Check if target slot is occupied
	var target_item = _inventory_state.get_cargo_item(original_target_index)
	if not target_item.is_empty():
		# Try to swap items
		return _swap_cargo_items(dragged_from_cargo_index, original_target_index)
	
	# Move item to empty slot
	return _move_to_cargo_slot(original_target_index)

func _drop_on_equipment(target_slot: Control, _target_type: String, _target_index: int) -> bool:
	"""Handle dropping on equipment slot"""
	if not target_slot.has_meta("equip_slot_enum"):
		return false
	
	var target_enum = target_slot.get_meta("equip_slot_enum")
	
	# Check if we can equip this item
	if dragged_instance_id != "":
		return _inventory_state.equip_instance(target_enum, dragged_instance_id)
	
	return false

func _swap_cargo_items(index1: int, index2: int) -> bool:
	"""Swap two cargo items"""
	if index1 == index2:
		return true
	
	return _inventory_state.swap_cargo_items(index1, index2)

func _move_to_cargo_slot(target_index: int) -> bool:
	"""Move dragged item to specific cargo slot"""
	if dragged_from_cargo_index == target_index:
		return true
	
	# Clear source slot
	_inventory_state.clear_cargo_slot(dragged_from_cargo_index)
	
	# Set target slot
	var item_instance = _inventory_state.get_instance(dragged_instance_id)
	if not item_instance.is_empty():
		return _inventory_state.set_cargo_slot(target_index, item_instance)
	
	return false

func _create_dragged_item_ui(item_data: Dictionary, _source_slot: Control) -> void:
	"""Create visual representation of dragged item using the actual ItemSlot scene"""
	
	# Create a combined data dictionary for visualization
	var visual_data = item_data.duplicate()
	var item_id = item_data.get("item_id", "")
	if _inventory_state:
		var item_def = _inventory_state.get_item_definition(item_id)
		visual_data.merge(item_def)
	
	# Load the ItemSlot scene
	var item_slot_scene = load("res://scenes/UI/ItemSlot.tscn")
	if not item_slot_scene:
		push_error("Failed to load ItemSlot scene for drag visual")
		return
		
	# Instantiate and configure
	dragged_item_ui = item_slot_scene.instantiate()
	
	# We need to add it to the tree before we can set data successfully in some cases, 
	# but we want it hidden or positioned correctly first.
	dragged_item_ui.modulate = Color(1, 1, 1, 0.8) # Slightly transparent
	dragged_item_ui.z_index = 1000
	dragged_item_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Ensure the slot knows it's just a visual (optional, depending on your Slot logic)
	# For now, just setting the item is enough
	
	# Add to scene tree
	_root_control.add_child(dragged_item_ui)
	dragged_item_ui.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	
	# Set the item data
	if dragged_item_ui.has_method("set_item"):
		dragged_item_ui.set_item(visual_data)
	
	# Force an update of visuals if needed (usually set_item handles this)
	if dragged_item_ui.has_method("_update_visuals"):
		dragged_item_ui._update_visuals()
	


func _handle_right_click(slot: Control) -> void:
	"""Handle right-click for quick unequip from equipment slots"""
	if not slot:
		return
	
	var _slot_data: Dictionary = slot.get_meta("slot_data", {})
	var slot_type: String = slot.get_meta("slot_type", "")
	var slot_index: int = slot.get_meta("slot_index", -1)
	
	# Only handle right-click quick unequip for equipment slots
	if slot_type == "equipment" or slot_type == "special":
		var item_data: Dictionary = _get_slot_item_data(slot)
		if not item_data.is_empty():
			quick_unequip_requested.emit(slot, slot_type, slot_index)

func _cleanup_drag() -> void:
	"""Clean up drag state and UI"""
	is_dragging = false
	dragged_item = {}
	dragged_slot_type = ""
	dragged_slot_index = -1
	dragged_instance_id = ""
	dragged_from_cargo_index = -1
	dragged_from_equip_slot = -1
	
	if dragged_item_ui:
		dragged_item_ui.queue_free()
		dragged_item_ui = null

func update_drag_position(position: Vector2) -> void:
	"""Update the position of the dragged item UI"""
	if dragged_item_ui and is_dragging:
		dragged_item_ui.position = position - Vector2(32, 32)  # Center on cursor

func _get_slots_at_position(position: Vector2) -> Array:
	"""Get all slots at the given position"""
	var slots = []
	var all_slots = get_tree().get_nodes_in_group("inventory_slot")
	
	for slot in all_slots:
		if slot is Control and slot.get_global_rect().has_point(position):
			slots.append(slot)
	
	return slots

func _get_slot_item_data(slot: Control) -> Dictionary:
	"""Get item data from a slot"""
	var slot_type = slot.get_meta("slot_type", "")
	var slot_index = slot.get_meta("slot_index", -1)
	
	match slot_type:
		"cargo":
			var original_index = slot.get_meta("original_cargo_index", slot_index)
			return _inventory_state.get_cargo_item(original_index)
		"special", "equipment":
			if slot.has_meta("equip_slot_enum"):
				var equip_enum = slot.get_meta("equip_slot_enum")
				return _inventory_state.get_equipped_item(equip_enum)
	
	return {}
