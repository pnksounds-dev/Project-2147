extends CanvasLayer

class_name InventoryUI

# Preload ItemSlot class
const ItemSlot = preload("res://scripts/UI/ItemSlot.gd")

# Import AudioManager class with non-shadowing name
const AudioManagerClass = preload("res://scripts/AudioManager.gd")
const ItemSlotScene: PackedScene = preload("res://scenes/UI/ItemSlot.tscn")
const WeaponManagerClass = preload("res://scripts/weapons/WeaponManager.gd")

# Match GridContainer default columns in InventoryUI.tscn
const INVENTORY_COLUMNS := 6

signal close_requested

# UI References
@onready var _inventory_button: Button = $TopBar/TopBarContent/TopBarContainer/TopBarLeft/InventoryButton
@onready var _skill_tree_button: Button = $TopBar/TopBarContent/TopBarContainer/TopBarLeft/SkillTreeButton
@onready var _scout_manager_button: Button = $TopBar/TopBarContent/TopBarContainer/TopBarLeft/ScoutManagerButton
@onready var _close_button: Button = $TopBar/TopBarContent/TopBarContainer/TopBarRight/CloseButton
@onready var _inventory_container: GridContainer = $Stage/ScrollContainer/VBoxContainer/BackpackSection/InventoryContainer/GridContainer
@onready var _special_slots_container: HBoxContainer = $Stage/ScrollContainer/VBoxContainer/EquippedSection/SpecialSlotsContainer
@onready var _inventory_state: InventoryState = get_tree().get_first_node_in_group("inventory")

# Audio manager reference
@onready var audio_manager: AudioManagerClass = get_node_or_null("/root/AudioManager")

# Weapon system reference
var weapon_system = null

# Special slots data
var special_slots: Array = []

# State tracking
var tracked_visible: bool = false
var is_open: bool = false
var opened_from_pause_menu: bool = false
var closed_with_e_key: bool = false

# Drag and drop state
var dragged_item: Dictionary = {}
var dragged_slot_type: String = ""
var dragged_slot_index: int = -1
var is_dragging: bool = false
var dragged_item_ui: Control = null

# Instance-aware drag metadata (used with InventoryState-backed slots)
var dragged_instance_id: String = ""
var dragged_from_cargo_index: int = -1
var dragged_from_equip_slot: int = -1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	add_to_group("inventory_ui")
	
	# Connect button signals
	_inventory_button.pressed.connect(_on_inventory_pressed)
	_skill_tree_button.pressed.connect(_on_skill_tree_pressed)
	_scout_manager_button.pressed.connect(_on_scout_manager_pressed)
	_close_button.pressed.connect(_on_close_pressed)
	
	# Initialize inventory bindings and layout
	_initialize_inventory_bindings()
	_populate_inventory()

func _input(event: InputEvent) -> void:
	# Handle drag and drop
	if is_dragging and event is InputEventMouseMotion:
		_update_dragged_item_position(event.position)
	elif is_dragging and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_handle_drop(event.position)
		return
	
	# Handle closing inventory with E key - always resume game
	if visible and event.is_action_pressed("inventory"): # E key
		closed_with_e_key = true
		close_inventory()
		get_viewport().set_input_as_handled()
		return
	
	# Only handle ESC if not opened from pause menu
	if visible and event.is_action_pressed("ui_cancel") and not opened_from_pause_menu: # ESC
		close_inventory()
		get_viewport().set_input_as_handled()
		return
	
	# Only handle opening inventory with E key if game is not paused by pause menu
	if not is_open and not visible and event.is_action_pressed("inventory"): # E to open inventory
		# Check if pause menu is open - if so, don't process E key
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
	
	# Check if pause menu is visible (opened from pause menu)
	var pause_menu = get_tree().get_first_node_in_group("pause_menu")
	opened_from_pause_menu = pause_menu and pause_menu.visible
	
	# Pause the game
	get_tree().paused = true
	
	# Hide HUD
	_hide_hud()
	
	# Populate inventory
	_populate_inventory()
	
	# Update weapon system to ensure correct state
	_update_weapon_system()
	
	# Set focus to close button
	_close_button.grab_focus()

func close_inventory() -> void:
	if not is_open:
		return
	
	is_open = false
	tracked_visible = false
	visible = false
	
	# Show HUD first
	_show_hud()
	
	# Update weapon system to ensure correct state after inventory changes
	_update_weapon_system()
	
	# Resume pause menu if it was opened from pause menu AND not closed with E key
	if opened_from_pause_menu and not closed_with_e_key:
		var pause_menu = get_tree().get_first_node_in_group("pause_menu")
		if pause_menu:
			# Use call_deferred to avoid input conflicts in the same frame
			call_deferred("_resume_pause_menu_deferred", pause_menu)
	else:
		# Unpause the game
		get_tree().paused = false
		# Also ensure pause menu is properly hidden and reset
		var pause_menu = get_tree().get_first_node_in_group("pause_menu")
		if pause_menu:
			# Use call_deferred to avoid timing issues
			call_deferred("_reset_pause_menu_deferred", pause_menu)
	
	# Reset the flags
	opened_from_pause_menu = false
	closed_with_e_key = false
	
	# Emit close signal
	close_requested.emit()

func _resume_pause_menu_deferred(pause_menu: Node):
	pause_menu.visible = true
	pause_menu.is_paused = true  # Sync the pause menu state
	# Keep the game paused since pause menu is now visible
	get_tree().paused = true

func _reset_pause_menu_deferred(pause_menu: Node):
	pause_menu.visible = false
	pause_menu.is_paused = false

func _set_visible(vis: bool, _caller: String = ""):
	# External visibility setter used by other systems
	if vis and not is_open:
		open_inventory()
	elif not vis and is_open:
		close_inventory()

func _hide_hud() -> void:
	# Hide all HUD elements
	var hud = get_tree().get_first_node_in_group("hud")
	if hud:
		hud.visible = false

func _show_hud() -> void:
	# Show all HUD elements
	var hud = get_tree().get_first_node_in_group("hud")
	if hud:
		hud.visible = true

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
		push_warning("InventoryUI: Could not find player's WeaponManager")
	if not _inventory_state.inventory_changed.is_connected(_on_inventory_changed):
		_inventory_state.inventory_changed.connect(_on_inventory_changed)
	if not _inventory_state.equipment_changed.is_connected(_on_equipment_changed):
		_inventory_state.equipment_changed.connect(_on_equipment_changed)

func _populate_inventory() -> void:
	for child in _inventory_container.get_children():
		child.queue_free()
	for child in _special_slots_container.get_children():
		child.queue_free()
	
	if not _inventory_state:
		return
	
	_inventory_container.columns = INVENTORY_COLUMNS
	
	var equip_slots: Array = _inventory_state.get_equipment_slots()
	for slot_index in equip_slots.size():
		var slot_type: InventoryState.SlotType = equip_slots[slot_index]
		var item_slot: ItemSlot = ItemSlotScene.instantiate()
		match slot_type:
			InventoryState.SlotType.WEAPON1, InventoryState.SlotType.WEAPON2:
				item_slot.slot_kind = item_slot.SlotKind.EQUIPPED_WEAPON
			InventoryState.SlotType.PASSIVE1, InventoryState.SlotType.PASSIVE2, InventoryState.SlotType.ACCESSORY:
				item_slot.slot_kind = item_slot.SlotKind.EQUIPPED_PASSIVE
			InventoryState.SlotType.CONSUMABLE:
				item_slot.slot_kind = item_slot.SlotKind.EQUIPPED_CONSUMABLE
			_:
				item_slot.slot_kind = item_slot.SlotKind.BACKPACK
		item_slot.equipment_slot = slot_type
		var contents: Dictionary = _inventory_state.get_equipped_item(slot_type)
		item_slot.set_item(contents)
		var slot_type_str = _get_meta_slot_type_string(slot_type)
		var meta_data: Dictionary = _build_slot_metadata(contents, slot_type_str, slot_index)
		item_slot.set_meta("slot_data", meta_data)
		item_slot.set_meta("slot_index", slot_index)
		item_slot.set_meta("slot_type", "special")
		item_slot.set_meta("equip_slot_enum", slot_type)
		item_slot.gui_input.connect(_on_slot_gui_input.bind(item_slot))
		_special_slots_container.add_child(item_slot)
	
	var cargo_slot_count: int = _inventory_state.get_cargo_slot_count()
	for i in range(cargo_slot_count):
		var slot_node: ItemSlot = ItemSlotScene.instantiate()
		slot_node.slot_kind = slot_node.SlotKind.BACKPACK
		slot_node.cargo_index = i
		var slot_contents: Dictionary = _inventory_state.get_cargo_item(i)
		slot_node.set_item(slot_contents)
		var meta_data: Dictionary = _build_slot_metadata(slot_contents, "inventory", i)
		slot_node.set_meta("slot_data", meta_data)
		slot_node.set_meta("slot_index", i)
		slot_node.set_meta("slot_type", "inventory")
		slot_node.gui_input.connect(_on_slot_gui_input.bind(slot_node))
		_inventory_container.add_child(slot_node)

func _build_slot_metadata(item_data: Dictionary, slot_type: String, slot_index: int) -> Dictionary:
	"""Build metadata for a slot based on item data and slot type"""
	var meta = {
		"slot_type": slot_type,
		"slot_index": slot_index,
		"item_id": item_data.get("item_id", ""),
		"instance_id": item_data.get("instance_id", ""),
		"quantity": item_data.get("quantity", 1),
		"locked": item_data.get("locked", false)
	}
	return meta

func _create_special_slot(slot_data: Dictionary, slot_index: int) -> Control:
	# Create a container for the special slot
	var slot = Panel.new()
	slot.custom_minimum_size = Vector2(90, 90)  # Slightly larger for emphasis
	
	# Store slot data for drag and drop
	slot.set_meta("slot_data", slot_data)
	slot.set_meta("slot_index", slot_index)
	slot.set_meta("slot_type", "special")
	
	# Apply enhanced special slot styling based on slot type
	var style_box = StyleBoxFlat.new()
	var slot_type = slot_data.get("slot_type", "")
	
	match slot_type:
		"weapon":
			# Weapon slot - red theme with glow effect
			style_box.bg_color = Color(0.3, 0.1, 0.1, 0.9)
			style_box.border_color = Color(0.9, 0.3, 0.3, 1.0)
			style_box.border_width_left = 3
			style_box.border_width_right = 3
			style_box.border_width_top = 3
			style_box.border_width_bottom = 3
			style_box.shadow_color = Color(0.8, 0.2, 0.2, 0.3)
			style_box.shadow_size = 2
		"passive":
			# Passive slot - green theme with glow effect
			style_box.bg_color = Color(0.1, 0.3, 0.1, 0.9)
			style_box.border_color = Color(0.3, 0.9, 0.3, 1.0)
			style_box.border_width_left = 3
			style_box.border_width_right = 3
			style_box.border_width_top = 3
			style_box.border_width_bottom = 3
			style_box.shadow_color = Color(0.2, 0.8, 0.2, 0.3)
			style_box.shadow_size = 2
		"consumable":
			# Consumable slot - blue theme with glow effect
			style_box.bg_color = Color(0.1, 0.1, 0.3, 0.9)
			style_box.border_color = Color(0.3, 0.3, 0.9, 1.0)
			style_box.border_width_left = 3
			style_box.border_width_right = 3
			style_box.border_width_top = 3
			style_box.border_width_bottom = 3
			style_box.shadow_color = Color(0.2, 0.2, 0.8, 0.3)
			style_box.shadow_size = 2
		_:
			# Empty slot - subtle appearance
			style_box.bg_color = Color(0.05, 0.05, 0.1, 0.7)
			style_box.border_color = Color(0.3, 0.3, 0.5, 0.5)
			style_box.border_width_left = 2
			style_box.border_width_right = 2
			style_box.border_width_top = 2
			style_box.border_width_bottom = 2
	
	style_box.corner_radius_top_left = 10
	style_box.corner_radius_top_right = 10
	style_box.corner_radius_bottom_left = 10
	style_box.corner_radius_bottom_right = 10
	slot.add_theme_stylebox_override("panel", style_box)
	
	# Connect mouse events
	slot.gui_input.connect(_on_slot_gui_input.bind(slot))
	
	# Add hover effect for special slots
	slot.mouse_entered.connect(_on_special_slot_hovered.bind(slot, true))
	slot.mouse_exited.connect(_on_special_slot_hovered.bind(slot, false))
	
	# Add tooltip support
	slot.set_tooltip_text(_get_slot_tooltip(slot_type))
	
	# Create vertical layout for the slot
	var vbox = VBoxContainer.new()
	slot.add_child(vbox)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 2)
	
	# Only add item content if slot has an item
	if slot_data.get("name", "") != "":
		# Check if icon is a texture path or text emoji
		var icon_path = slot_data.get("icon", "")
		if icon_path.begins_with("res://"):
			# Load texture for weapon icons
			var texture = load(icon_path)
			if texture:
				var icon_rect = TextureRect.new()
				icon_rect.texture = texture
				icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
				icon_rect.custom_minimum_size = Vector2(40, 40)
				icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				vbox.add_child(icon_rect)
		else:
			# Use text emoji/icon
			var item_icon_label = Label.new()
			item_icon_label.text = icon_path if icon_path != "" else "❓"
			item_icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			item_icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			item_icon_label.add_theme_font_size_override("font_size", 20)
			vbox.add_child(item_icon_label)
		
		# Item name label
		var name_label = Label.new()
		name_label.text = slot_data.get("name", "Unknown")
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 8)
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(name_label)
		
		# Quantity label (if more than 1)
		if slot_data.get("quantity", 1) > 1:
			var qty_label = Label.new()
			qty_label.text = "x" + str(slot_data.quantity)
			qty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			qty_label.add_theme_font_size_override("font_size", 7)
			qty_label.modulate = Color.YELLOW
			vbox.add_child(qty_label)
	
	# Add slot type indicator at the bottom (always visible)
	var type_container = HBoxContainer.new()
	type_container.add_theme_constant_override("separation", 2)
	vbox.add_child(type_container)
	
	# Add icon for slot type
	var icon_label = Label.new()
	match slot_type:
		"weapon":
			icon_label.text = "⚔"
			icon_label.modulate = Color(0.9, 0.3, 0.3)
		"passive":
			icon_label.text = "🛡"
			icon_label.modulate = Color(0.3, 0.9, 0.3)
		"consumable":
			icon_label.text = "💊"
			icon_label.modulate = Color(0.3, 0.3, 0.9)
		_:
			icon_label.text = ""
	
	icon_label.add_theme_font_size_override("font_size", 12)
	type_container.add_child(icon_label)
	
	# Add text label
	var type_label = Label.new()
	match slot_type:
		"weapon":
			type_label.text = "WEAPON"
			type_label.modulate = Color(0.9, 0.3, 0.3)
		"passive":
			type_label.text = "PASSIVE"
			type_label.modulate = Color(0.3, 0.9, 0.3)
		"consumable":
			type_label.text = "USE"
			type_label.modulate = Color(0.3, 0.3, 0.9)
		_:
			type_label.text = ""
	
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	type_label.add_theme_font_size_override("font_size", 9)
	type_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	type_label.add_theme_constant_override("shadow_offset_x", 1)
	type_label.add_theme_constant_override("shadow_offset_y", 1)
	type_container.add_child(type_label)
	
	return slot

func _create_item_slot(item_data: Dictionary, slot_index: int) -> Control:
	# Create a container for the item slot
	var slot = Panel.new()
	slot.custom_minimum_size = Vector2(80, 80)
	
	# Store slot data for drag and drop
	slot.set_meta("slot_data", item_data)
	slot.set_meta("slot_index", slot_index)
	slot.set_meta("slot_type", "inventory")
	
	# Apply empty slot styling if needed
	if item_data.get("type", "") == "empty":
		var style_box = StyleBoxFlat.new()
		style_box.bg_color = Color(0.05, 0.05, 0.1, 0.6)
		style_box.border_width_left = 1
		style_box.border_width_right = 1
		style_box.border_width_top = 1
		style_box.border_width_bottom = 1
		style_box.border_color = Color(0.2, 0.3, 0.5, 0.4)
		style_box.corner_radius_top_left = 8
		style_box.corner_radius_top_right = 8
		style_box.corner_radius_bottom_left = 8
		style_box.corner_radius_bottom_right = 8
		slot.add_theme_stylebox_override("panel", style_box)
	else:
		var style_box = StyleBoxFlat.new()
		style_box.bg_color = Color(0.1, 0.1, 0.2, 0.8)
		style_box.border_width_left = 2
		style_box.border_width_right = 2
		style_box.border_width_top = 2
		style_box.border_width_bottom = 2
		style_box.border_color = Color(0.3, 0.5, 0.8, 0.6)
		style_box.corner_radius_top_left = 8
		style_box.corner_radius_top_right = 8
		style_box.corner_radius_bottom_left = 8
		style_box.corner_radius_bottom_right = 8
		slot.add_theme_stylebox_override("panel", style_box)
	
	# Connect mouse events
	slot.gui_input.connect(_on_slot_gui_input.bind(slot))
	
	# Create vertical layout for the slot
	var vbox = VBoxContainer.new()
	slot.add_child(vbox)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 4)
	
	# Only add content if slot is not empty
	if item_data.get("type", "") != "empty":
		# Check if icon is a texture path or text emoji
		var icon_path = item_data.get("icon", "")
		if icon_path.begins_with("res://"):
			# Load texture for weapon icons
			var texture = load(icon_path)
			if texture:
				var icon_rect = TextureRect.new()
				icon_rect.texture = texture
				icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
				icon_rect.custom_minimum_size = Vector2(50, 50)
				icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				vbox.add_child(icon_rect)
		else:
			# Use text emoji/icon
			var icon_label = Label.new()
			icon_label.text = icon_path if icon_path != "" else "❓"
			icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			icon_label.add_theme_font_size_override("font_size", 24)
			vbox.add_child(icon_label)
		
		# Item name label
		var name_label = Label.new()
		name_label.text = item_data.get("name", "Unknown")
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 10)
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(name_label)
		
		# Quantity label (if more than 1)
		if item_data.get("quantity", 1) > 1:
			var qty_label = Label.new()
			qty_label.text = "x" + str(item_data.quantity)
			qty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			qty_label.add_theme_font_size_override("font_size", 8)
			qty_label.modulate = Color.YELLOW
			vbox.add_child(qty_label)
	
	return slot

func _on_inventory_pressed() -> void:
	if audio_manager:
		audio_manager.play_button_click()
	print("Inventory tab pressed")

func _on_skill_tree_pressed() -> void:
	if audio_manager:
		audio_manager.play_button_click()
	print("Skill tree tab pressed")

func _on_scout_manager_pressed() -> void:
	if audio_manager:
		audio_manager.play_button_click()
	print("Scout manager tab pressed")

func _on_close_pressed() -> void:
	if audio_manager:
		audio_manager.play_button_click()
	close_inventory()

func _on_slot_gui_input(event: InputEvent, slot: Control) -> void:
	if event is InputEventMouseButton:
		var slot_data = slot.get_meta("slot_data")
		var slot_type = slot.get_meta("slot_type")
		var slot_index = slot.get_meta("slot_index")
		
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			# Only start dragging if the slot has an item
			if slot_data.get("name", "") != "":
				_start_drag(slot_data, slot_type, slot_index, event.position)
		
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			# Right-click to quickly unequip from special slots
			if slot_type == "special" and slot_data.get("name", "") != "":
				_quick_unequip_item(slot_data, slot_type, slot_index, event.position)

func _start_drag(item_data: Dictionary, from_slot_type: String, from_slot_index: int, mouse_pos: Vector2) -> void:
	dragged_item = item_data.duplicate()
	dragged_slot_type = from_slot_type
	dragged_slot_index = from_slot_index
	is_dragging = true
	dragged_instance_id = ""
	dragged_from_cargo_index = -1
	dragged_from_equip_slot = -1
	
	# Create dragged item UI with enhanced visual feedback
	dragged_item_ui = _create_dragged_item_ui(item_data)
	add_child(dragged_item_ui)
	
	# Update position
	_update_dragged_item_position(mouse_pos)
	
	# Add visual feedback to source slot
	_add_source_slot_feedback(from_slot_type, from_slot_index)
	
	# Try to capture InventoryState-backed instance information when dragging
	var source_slot = _get_slot_by_type_and_index(from_slot_type, from_slot_index)
	if source_slot and _inventory_state:
		# Backpack ItemSlots expose instance_id and cargo_index helpers
		if from_slot_type == "inventory" and source_slot.has_method("get_item_instance_id"):
			var inst_id: String = source_slot.call("get_item_instance_id")
			dragged_instance_id = inst_id
			dragged_from_cargo_index = from_slot_index
		elif from_slot_type == "special":
			if source_slot.has_method("get_item_instance_id"):
				dragged_instance_id = source_slot.call("get_item_instance_id")
			var equip_slot_type: int = -1
			if source_slot.has_meta("equip_slot_enum"):
				equip_slot_type = source_slot.get_meta("equip_slot_enum")
			elif source_slot.has_method("get"):
				# Access exported property if exposed
				var slot_value = source_slot.get("equipment_slot")
				if typeof(slot_value) == TYPE_INT:
					equip_slot_type = slot_value
			if equip_slot_type != -1:
				dragged_from_equip_slot = equip_slot_type
			# Do not clear the visual slot immediately; InventoryState drives visuals
	
	# For InventoryState-driven UI we never mutate slots immediately;
	# InventoryState operations on drop will trigger UI refresh.
	
	print("Started dragging: ", item_data.get("name", "Unknown"))

func _update_dragged_item_position(mouse_pos: Vector2) -> void:
	if dragged_item_ui:
		dragged_item_ui.position = mouse_pos - Vector2(40, 40)  # Center on mouse
	
	# Highlight valid drop targets while dragging
	_highlight_drop_targets(mouse_pos)

func _add_source_slot_feedback(slot_type: String, slot_index: int):
	"""Add visual feedback to the source slot being dragged from"""
	var source_slot = _get_slot_by_type_and_index(slot_type, slot_index)
	if source_slot:
		# Create a semi-transparent overlay to show this is the source
		var source_feedback = ColorRect.new()
		source_feedback.color = Color(1.0, 1.0, 0.0, 0.3)  # Yellow highlight
		source_feedback.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		source_feedback.mouse_filter = Control.MOUSE_FILTER_IGNORE
		source_slot.add_child(source_feedback)
		source_feedback.name = "drag_source_feedback"

func _highlight_drop_targets(mouse_pos: Vector2):
	"""Highlight valid drop targets while dragging"""
	# Clear previous highlights
	_clear_drop_highlights()
	
	# Find potential drop targets
	var target_slot = _get_slot_at_position(mouse_pos)
	if target_slot and _is_valid_drop_target(target_slot):
		# Add green highlight for valid target
		var highlight = ColorRect.new()
		highlight.color = Color(0.0, 1.0, 0.0, 0.2)  # Green highlight
		highlight.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
		target_slot.add_child(highlight)
		highlight.name = "drop_highlight"

func _clear_drop_highlights():
	"""Clear all drop target highlights"""
	var tree = get_tree()
	if tree:
		for node in tree.get_nodes_in_group("inventory_ui"):
			_clear_highlights_in_node(node)

func _clear_highlights_in_node(node: Node):
	"""Clear highlights in a specific node and its children"""
	for child in node.get_children():
		if child.name == "drop_highlight":
			child.queue_free()
		_clear_highlights_in_node(child)

func _get_slot_by_type_and_index(slot_type: String, slot_index: int) -> Control:
	"""Get a specific slot by type and index"""
	if slot_index < 0:
		return null
	match slot_type:
		"special":
			return _get_child_slot(_special_slots_container, slot_index)
		"inventory":
			return _get_child_slot(_inventory_container, slot_index)
		_:
			return null

func _get_child_slot(container: Container, slot_index: int) -> Control:
	if not container:
		return null
	if slot_index >= container.get_child_count():
		return null
	var slot: Control = container.get_child(slot_index)
	return slot

func _handle_drop(mouse_pos: Vector2) -> void:
	if not is_dragging:
		return
	
	# Clear all visual feedback first
	_clear_all_drag_feedback()
	
	# Find which slot we're dropping on
	var target_slot = _get_slot_at_position(mouse_pos)
	
	if target_slot:
		var target_slot_type = target_slot.get_meta("slot_type")
		var target_slot_index = target_slot.get_meta("slot_index")
		var target_slot_data = target_slot.get_meta("slot_data")
		
		# VALIDATION: Check if item can be placed in target slot
		if not _is_valid_drop_target(target_slot):
			print("InventoryUI: Cannot place ", dragged_item.get("name", "Unknown"), " in ", target_slot_type, " slot")
			# Return item to original slot with visual feedback
			_return_dragged_item_to_origin()
			_show_invalid_placement_feedback(target_slot.global_position)
			_end_drag()
			return
		
		# Handle the drop with appropriate feedback
		# Inventory-to-inventory moves are delegated to InventoryState so cargo
		# remains the single source of truth.
		if dragged_slot_type == "inventory" and target_slot_type == "inventory":
			_move_cargo_between_slots(dragged_slot_index, target_slot_index)
			if target_slot_data.get("name", "") == "":
				_show_success_feedback(target_slot.global_position)
			else:
				_show_swap_feedback(target_slot.global_position)
		elif dragged_slot_type == "inventory" and target_slot_type == "special":
			var had_item = target_slot_data.get("name", "") != ""
			if _equip_cargo_instance_to_special(target_slot):
				if had_item:
					_show_swap_feedback(target_slot.global_position)
				else:
					_show_success_feedback(target_slot.global_position)
			else:
				_return_dragged_item_to_origin()
				_show_invalid_placement_feedback(target_slot.global_position)
		elif dragged_slot_type == "special" and target_slot_type == "inventory":
			var had_item = target_slot_data.get("name", "") != ""
			if _move_equipped_instance_to_cargo(target_slot_index):
				if had_item:
					_show_swap_feedback(target_slot.global_position)
				else:
					_show_success_feedback(target_slot.global_position)
			else:
				_return_dragged_item_to_origin()
				_show_invalid_placement_feedback(target_slot.global_position)
		elif dragged_slot_type == "special" and target_slot_type == "special":
			if _move_equipped_between_special_slots(target_slot):
				_show_swap_feedback(target_slot.global_position)
			else:
				_return_dragged_item_to_origin()
				_show_invalid_placement_feedback(target_slot.global_position)
		else:
			if target_slot_data.get("name", "") == "":
				# Drop into empty slot
				_return_dragged_item_to_origin()
				_show_success_feedback(target_slot.global_position)
			else:
				# Swap items (only if both slots are compatible)
				if _is_valid_swap_between_legacy_slots(target_slot_type):
					_swap_legacy_slots(target_slot_type, target_slot_index)
					_show_swap_feedback(target_slot.global_position)
				else:
					# Can't swap - return to original
					_return_dragged_item_to_origin()
					_show_invalid_placement_feedback(target_slot.global_position)
	else:
		# Return item to original slot if dropped outside valid area
		_return_dragged_item_to_origin()
	
	# Clean up drag state
	_end_drag()

func _clear_all_drag_feedback():
	"""Clear all drag-related visual feedback"""
	_clear_drop_highlights()
	_clear_source_feedback()

func _clear_source_feedback():
	"""Clear source slot feedback"""
	var source_slot = _get_slot_by_type_and_index(dragged_slot_type, dragged_slot_index)
	if source_slot:
		var feedback = source_slot.get_node_or_null("drag_source_feedback")
		if feedback:
			feedback.queue_free()

func _show_success_feedback(position: Vector2):
	"""Show visual feedback for successful placement"""
	_show_placement_feedback(position, "✓", Color.GREEN)

func _show_swap_feedback(position: Vector2):
	"""Show visual feedback for item swap"""
	_show_placement_feedback(position, "⇄", Color.CYAN)

func _show_placement_feedback(position: Vector2, text: String, color: Color):
	"""Show placement feedback with specified text and color"""
	var feedback = Label.new()
	feedback.text = text
	feedback.add_theme_font_size_override("font_size", 24)
	feedback.modulate = color
	feedback.position = position - Vector2(12, 12)
	feedback.z_index = 1000
	
	# Add to scene temporarily
	get_tree().current_scene.add_child(feedback)
	
	# Animate fade out
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(feedback, "modulate:a", 0.0, 0.8)
	tween.tween_property(feedback, "position", feedback.position + Vector2(0, -20), 0.8)
	
	# Remove after animation
	tween.tween_callback(feedback.queue_free).set_delay(0.8)

func _end_drag() -> void:
	# Clear all visual feedback
	_clear_all_drag_feedback()
	
	# Clean up dragged item UI
	if dragged_item_ui:
		dragged_item_ui.queue_free()
		dragged_item_ui = null
	
	# Reset drag state
	dragged_item = {}
	dragged_slot_type = ""
	dragged_slot_index = -1
	dragged_instance_id = ""
	dragged_from_cargo_index = -1
	dragged_from_equip_slot = -1
	is_dragging = false
	
	print("Ended dragging")

func _quick_unequip_item(item_data: Dictionary, from_slot_type: String, from_slot_index: int, mouse_pos: Vector2):
	"""Quickly unequip an item from special slot to inventory"""
	if not _inventory_state:
		return
	var source_slot = _get_slot_by_type_and_index(from_slot_type, from_slot_index)
	if not source_slot:
		return
	var equip_slot_type: int = source_slot.get_meta("equip_slot_enum", -1)
	if equip_slot_type == -1:
		return
	var empty_slot_index = _find_first_empty_cargo_slot()
	if empty_slot_index == -1:
		_show_inventory_full_feedback(mouse_pos)
		print("Cannot unequip - inventory full")
		return
	var unequipped := _inventory_state.unequip_item(equip_slot_type)
	if unequipped.is_empty():
		return
	_inventory_state.set_cargo_slot(empty_slot_index, unequipped)
	_populate_inventory()
	_update_weapon_system()
	_show_unequip_feedback(mouse_pos)
	print("Quick unequipped: ", item_data.get("name", "Unknown"))

func _find_empty_inventory_slot() -> int:
	return _find_first_empty_cargo_slot()

func _show_unequip_feedback(position: Vector2):
	"""Show feedback for successful unequip"""
	_show_placement_feedback(position, "⇓", Color.YELLOW)

func _show_inventory_full_feedback(position: Vector2):
	"""Show feedback when inventory is full"""
	_show_placement_feedback(position, "✗", Color.RED)

func _create_dragged_item_ui(item_data: Dictionary) -> Control:
	var dragged_ui = Panel.new()
	dragged_ui.custom_minimum_size = Vector2(80, 80)
	dragged_ui.modulate = Color(1, 1, 1, 0.8)
	dragged_ui.z_index = 1000
	
	# Style for dragged item
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.2, 0.2, 0.3, 0.9)
	style_box.border_width_left = 2
	style_box.border_width_right = 2
	style_box.border_width_top = 2
	style_box.border_width_bottom = 2
	style_box.border_color = Color(0.8, 0.8, 0.2, 1.0)
	style_box.corner_radius_top_left = 8
	style_box.corner_radius_top_right = 8
	style_box.corner_radius_bottom_left = 8
	style_box.corner_radius_bottom_right = 8
	dragged_ui.add_theme_stylebox_override("panel", style_box)
	
	# Create content similar to regular slots
	var vbox = VBoxContainer.new()
	dragged_ui.add_child(vbox)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 4)
	
	# Add icon
	var icon_path = item_data.get("icon", "")
	if icon_path.begins_with("res://"):
		var texture = load(icon_path)
		if texture:
			var icon_rect = TextureRect.new()
			icon_rect.texture = texture
			icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			icon_rect.custom_minimum_size = Vector2(50, 50)
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			vbox.add_child(icon_rect)
	else:
		var icon_label = Label.new()
		icon_label.text = icon_path if icon_path != "" else "❓"
		icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		icon_label.add_theme_font_size_override("font_size", 24)
		vbox.add_child(icon_label)
	
	# Add name
	var name_label = Label.new()
	name_label.text = item_data.get("name", "Unknown")
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 10)
	vbox.add_child(name_label)
	
	return dragged_ui

func _get_slot_at_position(pos: Vector2) -> Control:
	# Check special slots first
	for child in _special_slots_container.get_children():
		var rect = child.get_global_rect()
		if rect.has_point(pos):
			return child
	
	# Then check inventory slots
	for child in _inventory_container.get_children():
		var rect = child.get_global_rect()
		if rect.has_point(pos):
			return child
	
	return null

func _clear_slot(_slot_type: String, _slot_index: int) -> void:
	# Legacy no-op retained for compatibility; InventoryState drives updates.
	return

func _place_item_in_slot(_item_data: Dictionary, _slot_type: String, _slot_index: int) -> void:
	# Legacy hook is now a no-op; InventoryState mutations already refresh UI.
	return

func _return_dragged_item_to_origin() -> void:
	# InventoryState already holds authoritative data; repopulate to restore visuals.
	_populate_inventory()

func _move_cargo_between_slots(from_index: int, to_index: int) -> void:
	if not _inventory_state:
		return
	if from_index == to_index:
		return
	_inventory_state.swap_cargo_items(from_index, to_index)
	_populate_inventory()

func _equip_cargo_instance_to_special(target_slot: Control) -> bool:
	if not _inventory_state:
		return false
	if dragged_instance_id == "":
		return false
	if _inventory_state.is_locked(dragged_instance_id):
		return false
	var equip_slot_type: int = target_slot.get_meta("equip_slot_enum", -1)
	if equip_slot_type == -1:
		return false
	if not _can_equip_instance_in_slot(dragged_instance_id, equip_slot_type):
		return false
	var previous_instance: Dictionary = _inventory_state.get_equipped_item(equip_slot_type)
	if not _inventory_state.equip_instance(equip_slot_type, dragged_instance_id):
		return false
	if dragged_from_cargo_index >= 0:
		if previous_instance.is_empty():
			_inventory_state.clear_cargo_slot(dragged_from_cargo_index)
		else:
			_inventory_state.set_cargo_slot(dragged_from_cargo_index, previous_instance)
	else:
		if not previous_instance.is_empty():
			var empty_index = _find_first_empty_cargo_slot()
			if empty_index == -1:
				return false
			_inventory_state.set_cargo_slot(empty_index, previous_instance)
	_populate_inventory()
	_update_weapon_system()
	return true

func _move_equipped_between_special_slots(target_slot: Control) -> bool:
	if not _inventory_state:
		return false
	if dragged_from_equip_slot == -1:
		return false
	var target_slot_type: int = target_slot.get_meta("equip_slot_enum", -1)
	if target_slot_type == -1:
		return false
	var success = _inventory_state.move_equipped_instance(dragged_from_equip_slot, target_slot_type)
	if success:
		_populate_inventory()
		_update_weapon_system()
	return success

func _move_equipped_instance_to_cargo(target_index: int) -> bool:
	if not _inventory_state:
		return false
	if dragged_from_equip_slot == -1:
		return false
	if target_index < 0 or target_index >= _inventory_state.get_cargo_slot_count():
		return false
	var existing_instance: Dictionary = _inventory_state.get_cargo_item(target_index)
	if not existing_instance.is_empty() and existing_instance.get("locked", false):
		return false
	if not existing_instance.is_empty():
		var existing_item_id: String = existing_instance.get("item_id", "")
		if existing_item_id == "" or not _inventory_state.can_equip_item(dragged_from_equip_slot, existing_item_id):
			return false
	var unequipped_instance: Dictionary = _inventory_state.unequip_item(dragged_from_equip_slot)
	if unequipped_instance.is_empty():
		return false
	_inventory_state.set_cargo_slot(target_index, unequipped_instance)
	if not existing_instance.is_empty():
		var existing_instance_id: String = existing_instance.get("instance_id", "")
		if existing_instance_id != "":
			_inventory_state.equip_instance(dragged_from_equip_slot, existing_instance_id)
	_populate_inventory()
	_update_weapon_system()
	return true

func _find_first_empty_cargo_slot() -> int:
	if not _inventory_state:
		return -1
	var count = _inventory_state.get_cargo_slot_count()
	for i in range(count):
		if _inventory_state.get_cargo_item(i).is_empty():
			return i
	return -1

func _get_meta_slot_type_string(slot_type: InventoryState.SlotType) -> String:
	match slot_type:
		InventoryState.SlotType.WEAPON1, InventoryState.SlotType.WEAPON2:
			return "weapon"
		InventoryState.SlotType.PASSIVE1, InventoryState.SlotType.PASSIVE2, InventoryState.SlotType.ACCESSORY:
			return "passive"
		InventoryState.SlotType.CONSUMABLE:
			return "consumable"
		_:
			return "normal"

func _update_weapon_system():
	"""Update weapon system based on equipped items in special slots"""
	if not weapon_system:
		# Try to find weapon system again if not found
		var player = get_tree().get_first_node_in_group("player")
		if player and player.has_node("WeaponManager"):
			weapon_system = player.get_node("WeaponManager")
		else:
			print("InventoryUI: Weapon system not found!")
			return
	
	# Get equipped weapons from inventory state
	var equipped_weapons = {}
	if _inventory_state:
		# Get all equipped items
		var equipped_items = _inventory_state.get_equipped_items()
		
		# Filter for weapons and prepare data for weapon system
		for slot_index in equipped_items.keys():
			var item = equipped_items[slot_index]
			if item and item.has("item_id") and item.item_id.begins_with("weapon_"):
				var weapon_data = {
					"item_id": item.item_id,
					"instance_id": item.get("instance_id", ""),
					"metadata": item.get("metadata", {})
				}
				equipped_weapons[slot_index] = weapon_data
	
	# Update weapon system with the filtered weapons
	if weapon_system.has_method("on_inventory_changed"):
		weapon_system.on_inventory_changed(equipped_weapons)
	
	# Update UI to reflect current weapon state
	_update_weapon_ui()

func _on_inventory_changed() -> void:
	"""Handle inventory changed signal from InventoryState"""
	print("InventoryUI: Inventory changed, updating UI and weapon system")
	_populate_inventory()
	_update_weapon_system()

func _on_equipment_changed(slot_index: int, item_id: String) -> void:
	"""Handle equipment changed signal from InventoryState"""
	print("InventoryUI: Equipment changed in slot ", slot_index, " to item ", item_id)
	_update_weapon_system()

func _update_weapon_ui() -> void:
	"""Update UI elements related to weapons"""
	if not _inventory_state:
		return
		
	# Update special slots to reflect current weapon state
	for slot in _special_slots_container.get_children():
		if slot.has_meta("slot_data"):
			var slot_data = slot.get_meta("slot_data")
			var slot_type = slot_data.get("slot_type", "")
			
			# Update visual state based on slot type
			if slot_type == "weapon":
				var slot_index = slot_data.get("slot_index", -1)
				if slot_index >= 0:
					var item = _inventory_state.get_equipped_item(slot_index)
					_update_slot_visuals(slot, item, slot_type)

func _update_slot_visuals(slot: Control, item: Dictionary, slot_type: String) -> void:
	"""Update visual appearance of a slot based on its contents"""
	if slot == null:
		return
		
	# Clear existing children
	for child in slot.get_children():
		child.queue_free()
	
	# If slot is empty, show default state
	if item.is_empty():
		var label = Label.new()
		label.text = slot_type.capitalize()
		slot.add_child(label)
		return
	
	# Create item icon
	var texture_rect = TextureRect.new()
	var texture = load(item.get("icon_path", ""))  # Assuming items have icon_path
	if texture:
		texture_rect.texture = texture
	else:
		# Use OrbMaster.png as the default icon
		texture_rect.texture = preload("res://assets/items/Passive/OrbMaster.png")
	
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_rect.custom_minimum_size = Vector2(64, 64)
	slot.add_child(texture_rect)
	
	# Add item name label
	var name_label = Label.new()
	name_label.text = item.get("name", "Unknown Item")
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.position.y = 70
	slot.add_child(name_label)

func _get_special_slot_type(index: int) -> String:
	if index < special_slots.size():
		return special_slots[index].get("slot_type", "normal")
	return "normal"

func _can_place_item_in_slot(item: Dictionary, slot_type: String) -> bool:
	# Legacy validation preserved for drag highlight of old slots.
	var item_type = item.get("type", "").to_lower()
	var item_name = item.get("name", "").to_lower()
	match slot_type.to_lower():
		"weapon":
			return item_type == "weapon" or item_name in ["phaser", "turret", "photon torpedo", "ballistic barrage"]
		"passive":
			return item_type == "weapon" or item_name in ["turret", "auto-turret", "shield generator", "repair drone"]
		"consumable":
			return item_type == "consumable" or item_name in ["health pack", "energy cell", "ammo", "shield battery"]
		"normal":
			return true
		_:
			return true

func _is_valid_drop_target(target_slot: Control) -> bool:
	if not _inventory_state:
		return false
	if not target_slot:
		return false
	var target_slot_type: String = target_slot.get_meta("slot_type", "")
	var target_slot_index: int = target_slot.get_meta("slot_index", -1)
	match dragged_slot_type:
		"inventory":
			if dragged_instance_id == "":
				return false
			if target_slot_type == "inventory":
				if target_slot_index == -1:
					return false
				var occupant := _inventory_state.get_cargo_item(target_slot_index)
				if not occupant.is_empty() and occupant.get("locked", false):
					return false
				return true
			elif target_slot_type == "special":
				return _can_equip_dragged_instance_to_slot(target_slot)
		"special":
			if dragged_instance_id == "" or dragged_from_equip_slot == -1:
				return false
			if target_slot_type == "inventory":
				if target_slot_index == -1:
					return false
				var cargo_item := _inventory_state.get_cargo_item(target_slot_index)
				if not cargo_item.is_empty():
					if cargo_item.get("locked", false):
						return false
					var cargo_item_id: String = cargo_item.get("item_id", "")
					if cargo_item_id == "" or not _inventory_state.can_equip_item(dragged_from_equip_slot, cargo_item_id):
						return false
				return true
			elif target_slot_type == "special":
				var equip_slot_type: int = target_slot.get_meta("equip_slot_enum", -1)
				return _can_equip_instance_in_slot(dragged_instance_id, equip_slot_type)
	return false

func _is_valid_swap_between_legacy_slots(_target_slot_type: String) -> bool:
	return false

func _swap_legacy_slots(_target_slot_type: String, _target_slot_index: int) -> void:
	# Legacy swap removed; InventoryState handles all authoritative swaps.
	_return_dragged_item_to_origin()

func _can_equip_dragged_instance_to_slot(target_slot: Control) -> bool:
	if dragged_instance_id == "":
		return false
	var equip_slot_type: int = target_slot.get_meta("equip_slot_enum", -1)
	return _can_equip_instance_in_slot(dragged_instance_id, equip_slot_type)

func _can_equip_instance_in_slot(instance_id: String, equip_slot_type: int) -> bool:
	if not _inventory_state:
		return false
	if instance_id == "":
		return false
	if equip_slot_type == -1:
		return false
	if _inventory_state.is_locked(instance_id):
		return false
	var inst := _inventory_state.get_instance(instance_id)
	if inst.is_empty():
		return false
	var item_id: String = inst.get("item_id", "")
	if item_id == "":
		return false
	return _inventory_state.can_equip_item(equip_slot_type, item_id)

func _show_invalid_placement_feedback(position: Vector2):
	"""Show visual feedback for invalid placement attempts"""
	# Create a temporary red X or similar feedback
	var feedback = Label.new()
	feedback.text = "❌"
	feedback.add_theme_font_size_override("font_size", 24)
	feedback.modulate = Color.RED
	feedback.position = position
	
	# Add to scene temporarily
	get_tree().current_scene.add_child(feedback)
	
	# Remove after a short time
	var timer = get_tree().create_timer(0.5)
	timer.timeout.connect(func(): feedback.queue_free())
	
	print("InventoryUI: Invalid placement feedback shown at ", position)

func _get_slot_tooltip(slot_type: String) -> String:
	"""Get tooltip text for slot type"""
	match slot_type:
		"weapon":
			return "Weapon Slot\nLeft-click: Drag to move\nRight-click: Quick unequip\nAccepts: Weapons, Phaser, Turret"
		"passive":
			return "Passive Slot\nLeft-click: Drag to move\nRight-click: Quick unequip\nAccepts: Turrets, Shields, Drones"
		"consumable":
			return "Use Slot\nLeft-click: Drag to move\nRight-click: Quick unequip\nAccepts: Health Packs, Energy Cells, Ammo"
		_:
			return "Empty Slot\nLeft-click: Drag items here to equip them"

func _on_special_slot_hovered(slot: Control, is_hovering: bool):
	"""Handle hover effects for special slots"""
	var slot_data = slot.get_meta("slot_data")
	var slot_type = slot_data.get("slot_type", "")
	
	if is_hovering:
		# Create hover effect
		var hover_style = StyleBoxFlat.new()
		
		match slot_type:
			"weapon":
				hover_style.bg_color = Color(0.4, 0.15, 0.15, 1.0)
				hover_style.border_color = Color(1.0, 0.4, 0.4, 1.0)
				hover_style.shadow_color = Color(0.9, 0.3, 0.3, 0.5)
			"passive":
				hover_style.bg_color = Color(0.15, 0.4, 0.15, 1.0)
				hover_style.border_color = Color(0.4, 1.0, 0.4, 1.0)
				hover_style.shadow_color = Color(0.3, 0.9, 0.3, 0.5)
			"consumable":
				hover_style.bg_color = Color(0.15, 0.15, 0.4, 1.0)
				hover_style.border_color = Color(0.4, 0.4, 1.0, 1.0)
				hover_style.shadow_color = Color(0.3, 0.3, 0.9, 0.5)
			_:
				hover_style.bg_color = Color(0.1, 0.1, 0.2, 0.9)
				hover_style.border_color = Color(0.4, 0.4, 0.6, 0.7)
		
		hover_style.border_width_left = 4
		hover_style.border_width_right = 4
		hover_style.border_width_top = 4
		hover_style.border_width_bottom = 4
		hover_style.shadow_size = 3
		hover_style.corner_radius_top_left = 10
		hover_style.corner_radius_top_right = 10
		hover_style.corner_radius_bottom_left = 10
		hover_style.corner_radius_bottom_right = 10
		
		slot.add_theme_stylebox_override("panel", hover_style)
	else:
		# Restore original style by recreating it
		_create_special_slot_original_style(slot, slot_data, slot.get_meta("slot_index"))

func _create_special_slot_original_style(slot: Control, slot_data: Dictionary, _slot_index: int):
	"""Restore the original style of a special slot"""
	var style_box = StyleBoxFlat.new()
	var slot_type = slot_data.get("slot_type", "")
	
	match slot_type:
		"weapon":
			style_box.bg_color = Color(0.3, 0.1, 0.1, 0.9)
			style_box.border_color = Color(0.9, 0.3, 0.3, 1.0)
			style_box.border_width_left = 3
			style_box.border_width_right = 3
			style_box.border_width_top = 3
			style_box.border_width_bottom = 3
			style_box.shadow_color = Color(0.8, 0.2, 0.2, 0.3)
			style_box.shadow_size = 2
		"passive":
			style_box.bg_color = Color(0.1, 0.3, 0.1, 0.9)
			style_box.border_color = Color(0.3, 0.9, 0.3, 1.0)
			style_box.border_width_left = 3
			style_box.border_width_right = 3
			style_box.border_width_top = 3
			style_box.border_width_bottom = 3
			style_box.shadow_color = Color(0.2, 0.8, 0.2, 0.3)
			style_box.shadow_size = 2
		"consumable":
			style_box.bg_color = Color(0.1, 0.1, 0.3, 0.9)
			style_box.border_color = Color(0.3, 0.3, 0.9, 1.0)
			style_box.border_width_left = 3
			style_box.border_width_right = 3
			style_box.border_width_top = 3
			style_box.border_width_bottom = 3
			style_box.shadow_color = Color(0.2, 0.2, 0.8, 0.3)
			style_box.shadow_size = 2
		_:
			style_box.bg_color = Color(0.05, 0.05, 0.1, 0.7)
			style_box.border_color = Color(0.3, 0.3, 0.5, 0.5)
			style_box.border_width_left = 2
			style_box.border_width_right = 2
			style_box.border_width_top = 2
			style_box.border_width_bottom = 2
	
	style_box.corner_radius_top_left = 10
	style_box.corner_radius_top_right = 10
	style_box.corner_radius_bottom_left = 10
	style_box.corner_radius_bottom_right = 10
	slot.add_theme_stylebox_override("panel", style_box)
