extends Control

class_name InventoryUI

# Component classes
const InventoryLayoutManagerClass = preload("res://scripts/inventory/InventoryLayoutManager.gd")
const SlotManagerClass = preload("res://scripts/inventory/SlotManager.gd")
const DragDropHandlerClass = preload("res://scripts/inventory/DragDropHandler.gd")
const FilterControllerClass = preload("res://scripts/inventory/FilterController.gd")
const AnimationControllerClass = preload("res://scripts/inventory/AnimationController.gd")

signal close_requested

# Component instances
var _layout_manager: InventoryLayoutManager
var _slot_manager: SlotManager
var _drag_drop_handler: DragDropHandler
var _filter_controller: FilterController
var _animation_controller: AnimationController

# UI References
@onready var _inventory_container: GridContainer = $StageMargin/Stage/CargoColumn/CargoContent/ScrollContainer/InventoryContainer/GridContainer
@onready var _inventory_panel: Control = $StageMargin/Stage/CargoColumn/CargoContent/ScrollContainer/InventoryContainer
@onready var _equip_column: Control = $StageMargin/Stage/EquipColumn
@onready var _cargo_panel: Control = $StageMargin/Stage/CargoColumn
@onready var _weapon_container: HBoxContainer = $StageMargin/Stage/EquipColumn/EquipContent/WeaponSection/WeaponContainer
@onready var _passive_container: HBoxContainer = $StageMargin/Stage/EquipColumn/EquipContent/PassiveSection/PassiveContainer
@onready var _consumable_container: HBoxContainer = $StageMargin/Stage/EquipColumn/EquipContent/ConsumableSection/ConsumableContainer
@onready var _all_button: Button = $StageMargin/Stage/CargoColumn/CargoContent/CargoHeader/FilterButtons/AllButton
@onready var _weapon_button: Button = $StageMargin/Stage/CargoColumn/CargoContent/CargoHeader/FilterButtons/WeaponButton
@onready var _passive_button: Button = $StageMargin/Stage/CargoColumn/CargoContent/CargoHeader/FilterButtons/PassiveButton
@onready var _consumable_button: Button = $StageMargin/Stage/CargoColumn/CargoContent/CargoHeader/FilterButtons/ConsumableButton
@onready var _inventory_state: InventoryState = get_tree().get_first_node_in_group("inventory")

# Audio manager reference
@onready var audio_manager: AudioManager = get_node_or_null("/root/AudioManager")

# Weapon system reference
var weapon_system = null

# State tracking
var tracked_visible: bool = false
var is_open: bool = false
var opened_from_pause_menu: bool = false
var closed_with_e_key: bool = false
@export var pause_on_open: bool = true
var _paused_by_inventory: bool = false

# Layout state
var _current_slot_size: float = 64.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	add_to_group("inventory_ui")
	add_to_group("ui_scaling")
	
	# Initialize components
	_initialize_components()
	
	# Connect component signals
	_connect_component_signals()
	
	# Connect window resize signal
	get_tree().get_root().size_changed.connect(_on_window_resized)
	
	# Initialize inventory bindings
	_initialize_inventory_bindings()
	
	# Apply UI settings
	_apply_ui_settings()
	
	# Ensure static cargo slots are ready
	_initialize_static_cargo_slots()
	
	# Initial populate
	_populate_inventory()

func _initialize_components() -> void:
	"""Initialize all component instances"""
	# Create component instances
	_layout_manager = InventoryLayoutManagerClass.new()
	_slot_manager = SlotManagerClass.new()
	_drag_drop_handler = DragDropHandlerClass.new()
	_filter_controller = FilterControllerClass.new()
	_animation_controller = AnimationControllerClass.new()
	
	# Add as children
	add_child(_layout_manager)
	add_child(_slot_manager)
	add_child(_drag_drop_handler)
	add_child(_filter_controller)
	add_child(_animation_controller)
	
	# Initialize components with their dependencies
	_layout_manager.initialize(_inventory_container, _equip_column, _cargo_panel)
	_slot_manager.initialize(_inventory_container, _weapon_container, _passive_container, _consumable_container, _inventory_state)
	_drag_drop_handler.initialize(_inventory_state, self)
	_filter_controller.initialize(_all_button, _weapon_button, _passive_button, _consumable_button, _inventory_state)
	_animation_controller.initialize(self)

func _connect_component_signals() -> void:
	"""Connect signals between components"""
	# Layout manager signals
	_layout_manager.layout_calculated.connect(_on_layout_calculated)
	
	# Slot manager signals
	_slot_manager.slot_created.connect(_on_slot_created)
	_slot_manager.slots_updated.connect(_on_slots_updated)
	
	# Drag drop handler signals
	_drag_drop_handler.drag_started.connect(_on_drag_started)
	_drag_drop_handler.drag_ended.connect(_on_drag_ended)
	_drag_drop_handler.drop_completed.connect(_on_drop_completed)
	_drag_drop_handler.quick_unequip_requested.connect(_on_quick_unequip_requested)
	
	# Filter controller signals
	_filter_controller.filter_changed.connect(_on_filter_changed)
	_filter_controller.filter_buttons_updated.connect(_on_filter_buttons_updated)
	
	# Animation controller signals
	_animation_controller.animation_started.connect(_on_animation_started)
	_animation_controller.animation_completed.connect(_on_animation_completed)

func _apply_ui_settings() -> void:
	"""Apply UI scaling settings from SettingsManager"""
	var settings_manager = get_node_or_null("/root/SettingsManager")
	if not settings_manager:
		return
	
	var scale_factor = settings_manager.get_setting("ui.scale_factor", 1.0)
	var slot_size = settings_manager.get_setting("ui.inventory_slot_size", 64)
	var grid_spacing = settings_manager.get_setting("ui.inventory_grid_spacing", 4)
	
	# Calculate responsive layout through layout manager
	_current_slot_size = _layout_manager.calculate_responsive_layout(slot_size * scale_factor, grid_spacing)
	
	# Apply spacing to inventory grid
	if _inventory_container:
		_inventory_container.add_theme_constant_override("h_separation", grid_spacing)
		_inventory_container.add_theme_constant_override("v_separation", grid_spacing)

func _populate_inventory() -> void:
	"""Populate the inventory using the slot manager"""
	if not _inventory_state:
		return
	
	# Clear and recreate equipment slots
	_slot_manager.clear_equipment_containers()
	_slot_manager.create_equipment_slots()
	
	# Update cargo slots with current filter
	var current_filter = _filter_controller.get_current_filter()
	_slot_manager.update_cargo_slots(current_filter, _current_slot_size)
	
	# Apply responsive layout
	var settings_manager = get_node_or_null("/root/SettingsManager")
	if settings_manager:
		var grid_spacing = settings_manager.get_setting("ui.inventory_grid_spacing", 4)
		_inventory_container.add_theme_constant_override("h_separation", grid_spacing)
		_inventory_container.add_theme_constant_override("v_separation", grid_spacing)

func _input(event: InputEvent) -> void:
	# Handle drag and drop through drag drop handler
	if _drag_drop_handler.is_dragging:
		if event is InputEventMouseMotion:
			_drag_drop_handler.update_drag_position(event.position)
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_drag_drop_handler._handle_drop(event.position)
			return
	
	# Handle inventory toggle
	var inventory_pressed := event.is_action_pressed("inventory")
	if event is InputEventKey and event.pressed and event.keycode == KEY_E:
		inventory_pressed = true
	
	# Handle closing inventory with E key
	if visible and inventory_pressed:
		closed_with_e_key = true
		close_inventory()
		get_viewport().set_input_as_handled()
		return
	
	# Handle ESC
	if visible and event.is_action_pressed("ui_cancel") and not opened_from_pause_menu:
		close_inventory()
		get_viewport().set_input_as_handled()
		return
	
	# Handle opening inventory
	if not is_open and not visible and inventory_pressed:
		var pause_menu = get_tree().get_first_node_in_group("pause_menu")
		if not pause_menu or not pause_menu.visible:
			toggle_inventory()
			get_viewport().set_input_as_handled()

func toggle_inventory() -> void:
	if is_open:
		close_inventory()
	else:
		open_inventory()

func open_inventory() -> void:
	if is_open:
		return
	
	# Check if another inventory is already open
	var existing_inventories = get_tree().get_nodes_in_group("inventory_ui")
	for inv in existing_inventories:
		if inv != self and inv.visible:
			print("InventoryUI: Another inventory is already open, ignoring request")
			return
	
	is_open = true
	tracked_visible = true
	visible = true
	
	# Check if pause menu is visible
	var pause_menu = get_tree().get_first_node_in_group("pause_menu")
	opened_from_pause_menu = pause_menu and pause_menu.visible
	
	# Pause the game if desired
	if pause_on_open:
		get_tree().paused = true
		_paused_by_inventory = true
		_hide_hud()
	else:
		_paused_by_inventory = false
	
	# Play open animation
	_animation_controller.play_open_animation()
	
	# Populate inventory
	_populate_inventory()
	
	# Update weapon system
	_update_weapon_system()

func close_inventory() -> void:
	if not is_open:
		return
	
	# Play close animation
	_animation_controller.play_close_animation()
	
	# Use call_deferred to hide after animation completes
	call_deferred("_hide_inventory_after_animation")

func _hide_inventory_after_animation() -> void:
	is_open = false
	tracked_visible = false
	visible = false
	
	# Show HUD if we hid it
	if pause_on_open:
		_show_hud()
	
	# Update weapon system
	_update_weapon_system()
	
	# Handle pause menu logic
	if opened_from_pause_menu and not closed_with_e_key:
		var pause_menu = get_tree().get_first_node_in_group("pause_menu")
		if pause_menu:
			call_deferred("_resume_pause_menu_deferred", pause_menu)
	else:
		if _paused_by_inventory:
			get_tree().paused = false
		var pause_menu = get_tree().get_first_node_in_group("pause_menu")
		if pause_menu:
			call_deferred("_reset_pause_menu_deferred", pause_menu)
	
	# Reset flags
	opened_from_pause_menu = false
	closed_with_e_key = false
	
	# Emit close signal
	close_requested.emit()

# Component signal handlers
func _on_layout_calculated(slot_size: float, _columns: int, _grid_spacing: int) -> void:
	_current_slot_size = slot_size
	# Update slots with new size
	_slot_manager.update_cargo_slots(_filter_controller.get_current_filter(), slot_size)

func _on_slot_created(slot: Control, _slot_type: String, _index: int) -> void:
	# Connect slot input to drag drop handler
	var callable = _on_slot_gui_input.bind(slot)
	if not slot.gui_input.is_connected(callable):
		slot.gui_input.connect(callable)
	# Add slot to inventory group for drag drop detection
	slot.add_to_group("inventory_slot")

func _on_slots_updated() -> void:
	# Disable no items feedback for now - it's causing visual issues
	pass

func _on_drag_started(_item_data: Dictionary, _from_slot: Control, _from_type: String, _from_index: int) -> void:
	_animation_controller.play_drag_start_animation(_drag_drop_handler.dragged_item_ui)
	# Play sound effect if available
	if audio_manager:
		audio_manager.play_sfx("inventory_pickup")

func _on_drag_ended() -> void:
	# Animation handled by drop completed signal
	pass

func _on_drop_completed(success: bool, to_slot: Control, _to_type: String, _to_index: int) -> void:
	if success:
		_animation_controller.play_success_flash_animation(to_slot)
		if audio_manager:
			audio_manager.play_sfx("inventory_place")
	else:
		if to_slot:
			_animation_controller.play_error_shake_animation(to_slot)
		if audio_manager:
			audio_manager.play_sfx("inventory_error")
	
	# Refresh inventory after drop
	_populate_inventory()

func _on_quick_unequip_requested(slot: Control, _slot_type: String, _slot_index: int) -> void:
	"""Handle right-click quick unequip from equipment slots"""
	if not _inventory_state:
		return
	
	var equip_slot_enum = slot.get_meta("equip_slot_enum", -1)
	if equip_slot_enum == -1:
		return
	
	# Find empty cargo slot
	var empty_slot_index = _find_first_empty_cargo_slot()
	if empty_slot_index == -1:
		# Show feedback that inventory is full
		_show_inventory_full_feedback(slot.get_global_position())
		if audio_manager:
			audio_manager.play_sfx("inventory_error")
		return
	
	# Unequip the item
	var unequipped_item = _inventory_state.unequip_item(equip_slot_enum)
	if not unequipped_item.is_empty():
		# Move to cargo slot
		var success = _inventory_state.set_cargo_slot(empty_slot_index, unequipped_item)
		if success:
			_animation_controller.play_success_flash_animation(slot)
			if audio_manager:
				audio_manager.play_sfx("inventory_place")
			# Refresh the UI
			_populate_inventory()
		else:
			# Re-equip if move failed
			_inventory_state.equip_instance(equip_slot_enum, unequipped_item.get("instance_id", ""))
			if audio_manager:
				audio_manager.play_sfx("inventory_error")

func _on_filter_changed(new_filter: String) -> void:
	# Update slots with new filter
	_slot_manager.update_cargo_slots(new_filter, _current_slot_size)
	_animation_controller.play_filter_transition_animation(true)

func _on_filter_buttons_updated() -> void:
	# Filter buttons updated - no additional action needed
	pass

func _on_animation_started(_animation_name: String) -> void:
	# Animation started - could be used for coordination
	pass

func _on_animation_completed(animation_name: String) -> void:
	# Animation completed - could be used for coordination
	if animation_name == "close":
		# Ensure inventory is hidden after close animation
		if not is_open:
			visible = false

func _on_slot_gui_input(event: InputEvent, slot: Control) -> void:
	"""Handle input events on slots through drag drop handler"""
	_drag_drop_handler.handle_slot_input(event, slot)
	# Hover colour/brightness animations temporarily disabled for stability

func _on_window_resized() -> void:
	"""Handle window resize events"""
	if visible:
		_apply_ui_settings()
		_populate_inventory()

# Helper methods
func _initialize_static_cargo_slots() -> void:
	"""Initialize static cargo slots with default properties"""
	if not _inventory_container:
		return
		
	var cargo_slots = _inventory_container.get_children()
	for i in range(cargo_slots.size()):
		var slot_node = cargo_slots[i] as Control
		if not slot_node:
			continue
		
		# Set slot metadata for drag drop handler
		slot_node.set_meta("slot_type", "cargo")
		slot_node.set_meta("slot_index", i)
		
		# Set slot properties
		if "slot_kind" in slot_node:
			slot_node.slot_kind = slot_node.SlotKind.BACKPACK
		if "cargo_index" in slot_node:
			slot_node.cargo_index = i
		
		# Add to inventory slot group for drag detection
		slot_node.add_to_group("inventory_slot")
		
		# Connect slot input to drag drop handler
		if not slot_node.gui_input.is_connected(_on_slot_gui_input.bind(slot_node)):
			slot_node.gui_input.connect(_on_slot_gui_input.bind(slot_node))

func _initialize_inventory_bindings() -> void:
	if not _inventory_state:
		_inventory_state = get_tree().get_first_node_in_group("inventory")
	if not _inventory_state:
		push_warning("InventoryUI: InventoryState not found; inventory UI will be inactive.")
		return
	
	# Connect inventory state signals
	if _inventory_state.has_signal("inventory_changed"):
		if not _inventory_state.inventory_changed.is_connected(_on_inventory_changed):
			_inventory_state.inventory_changed.connect(_on_inventory_changed)
	
	if _inventory_state.has_signal("equipment_changed"):
		if not _inventory_state.equipment_changed.is_connected(_on_equipment_changed):
			_inventory_state.equipment_changed.connect(_on_equipment_changed)
	
	# Get weapon system reference
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_node("WeaponManager"):
		weapon_system = player.get_node("WeaponManager")
		print("InventoryUI: Found weapon system: ", weapon_system.name)
	else:
		print("InventoryUI: Player or WeaponManager not found yet; weapon UI will be limited.")

func _update_no_items_feedback(show_feedback: bool) -> void:
	"""Show or hide 'no items found' feedback"""
	var feedback_parent: Control = _inventory_panel if _inventory_panel else _inventory_container
	var feedback_label = feedback_parent.get_node_or_null("NoItemsLabel")
	
	if show_feedback and not feedback_label:
		feedback_label = Label.new()
		feedback_label.name = "NoItemsLabel"
		feedback_label.text = "No items found in this category"
		feedback_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1))
		feedback_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.65))
		feedback_label.add_theme_constant_override("outline_size", 1)
		feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		feedback_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		feedback_label.anchors_preset = Control.PRESET_BOTTOM_WIDE
		feedback_label.offset_left = 0
		feedback_label.offset_right = 0
		feedback_label.offset_top = -32
		feedback_label.offset_bottom = 0
		feedback_parent.add_child(feedback_label)
		feedback_label.move_to_front()
	elif not show_feedback and feedback_label:
		feedback_label.queue_free()

func _hide_hud() -> void:
	var hud = get_tree().get_first_node_in_group("hud")
	if hud:
		hud.visible = false

func _show_hud() -> void:
	var hud = get_tree().get_first_node_in_group("hud")
	if hud:
		hud.visible = true

func _update_weapon_system() -> void:
	# Update weapon system to ensure correct state
	if weapon_system and weapon_system.has_method("update_weapons"):
		weapon_system.update_weapons()

func _resume_pause_menu_deferred(pause_menu: Node):
	pause_menu.visible = true
	pause_menu.is_paused = true
	get_tree().paused = true

func _reset_pause_menu_deferred(pause_menu: Node):
	pause_menu.visible = false
	pause_menu.is_paused = false

func _on_inventory_changed() -> void:
	"""Handle inventory state changes"""
	if visible:
		_populate_inventory()

func _on_equipment_changed(_slot: int, _item_id) -> void:
	"""Handle equipment changes"""
	if visible:
		_populate_inventory()

# Public API methods (maintaining compatibility)
func set_inventory_visible(vis: bool) -> void:
	"""External visibility setter"""
	if vis and not is_open:
		open_inventory()
	elif not vis and is_open:
		close_inventory()

func apply_ui_settings(_ui_settings: Dictionary) -> void:
	"""Public method called by SettingsManager"""
	_apply_ui_settings()
	_populate_inventory()

func get_current_filter() -> String:
	"""Get current filter for external systems"""
	return _filter_controller.get_current_filter()

func is_inventory_open() -> bool:
	"""Check if inventory is open"""
	return is_open

func _find_first_empty_cargo_slot() -> int:
	"""Find the first empty cargo slot index"""
	if not _inventory_state:
		return -1
	
	var total_slots = _inventory_state.get_cargo_slot_count()
	for i in range(total_slots):
		var slot_contents = _inventory_state.get_cargo_item(i)
		if slot_contents.is_empty() or slot_contents.get("item_id", "") == "":
			return i
	
	return -1

func _show_inventory_full_feedback(pos: Vector2) -> void:
	"""Show feedback when inventory is full"""
	var feedback_label = Label.new()
	feedback_label.text = "Inventory Full!"
	feedback_label.add_theme_color_override("font_color", Color.RED)
	feedback_label.add_theme_color_override("font_outline_color", Color.BLACK)
	feedback_label.add_theme_constant_override("outline_size", 2)
	feedback_label.position = pos - Vector2(50, 20)
	
	add_child(feedback_label)
	
	# Animate and remove after delay
	var tween = create_tween()
	tween.tween_property(feedback_label, "position:y", feedback_label.position.y - 30, 0.5)
	tween.tween_property(feedback_label, "modulate", Color.TRANSPARENT, 0.3)
	tween.tween_callback(feedback_label.queue_free)
