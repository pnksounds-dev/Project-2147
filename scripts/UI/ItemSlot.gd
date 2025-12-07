extends Panel

const ItemCategoriesLib = preload("res://scripts/items/ItemCategories.gd")
const InventorySlotTypeClass = preload("res://scripts/InventorySlotType.gd")

signal slot_gui_input(event: InputEvent, slot)
signal slot_hovered(slot, hovering: bool)

enum SlotKind {
	EQUIPPED_WEAPON,
	EQUIPPED_PASSIVE,
	EQUIPPED_CONSUMABLE,
	BACKPACK,
}

var _slot_kind_internal: SlotKind = SlotKind.BACKPACK
var _equipment_slot_internal: InventorySlotTypeClass.SlotType = InventorySlotTypeClass.SlotType.WEAPON1
var _cargo_index_internal: int = -1

@export var slot_kind: SlotKind = SlotKind.BACKPACK:
	get:
		return _slot_kind_internal
	set(value):
		if _slot_kind_internal == value:
			return
		_slot_kind_internal = value
		if is_inside_tree():
			_update_slot_theme()

@export var equipment_slot: InventorySlotTypeClass.SlotType = InventorySlotTypeClass.SlotType.WEAPON1:
	get:
		return _equipment_slot_internal
	set(value):
		if _equipment_slot_internal == value:
			return
		_equipment_slot_internal = value
		# Equipped slot visuals handled by slot_kind theme

@export var cargo_index: int = -1:
	get:
		return _cargo_index_internal
	set(value):
		if _cargo_index_internal == value:
			return
		_cargo_index_internal = value
		# Cargo index currently used for drag/drop metadata only

var _item_registry: Node = null
var _inventory_state: InventoryState = null
var _slot_contents: Dictionary = {}

@onready var _icon_rect: TextureRect = $SlotContent/ItemIcon
@onready var _quantity_label: Label = $QuantityLabel
@onready var _hover_highlight: ColorRect = $HoverHighlight

func _ready() -> void:
	custom_minimum_size = Vector2(64, 64)
	_update_slot_theme()
	self.gui_input.connect(_on_gui_input_forward)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_item_registry = get_tree().get_first_node_in_group("item_registry")
	_inventory_state = get_tree().get_first_node_in_group("inventory")
	if is_instance_valid(_hover_highlight):
		_hover_highlight.visible = false
	_update_visuals()

func set_item(slot_contents: Dictionary) -> void:
	_slot_contents = slot_contents.duplicate(true)
	_update_visuals()

func set_slot_size(_slot_size_value: float) -> void:
	"""Set the slot size dynamically for UI scaling - disabled for consistent layout"""
	# Keep fixed 64x64 size for consistent grid layout
	custom_minimum_size = Vector2(64, 64)
	size = Vector2(64, 64)

func clear() -> void:
	_slot_contents = {}
	if is_instance_valid(_hover_highlight):
		_hover_highlight.visible = false
	_update_visuals()

func can_accept(item_id: String) -> bool:
	if item_id == "":
		return false
	if slot_kind == SlotKind.BACKPACK:
		return _inventory_state != null and _inventory_state.can_place_in_cargo(item_id)
	if _inventory_state == null:
		return false
	return _inventory_state.can_equip_item(equipment_slot, item_id)

func get_current_item_id() -> String:
	return _slot_contents.get("item_id", "")

func get_current_quantity() -> int:
	return _slot_contents.get("quantity", 0)

func get_item_instance_id() -> String:
	return _slot_contents.get("instance_id", "")

func is_favorite() -> bool:
	return _slot_contents.get("favorite", false)

func is_locked() -> bool:
	return _slot_contents.get("locked", false)

func _update_visuals() -> void:
	if not is_inside_tree():
		return
	var item_id: String = str(_slot_contents.get("item_id", ""))
	var quantity: int = int(_slot_contents.get("quantity", 0))
	if item_id == "":
		_icon_rect.texture = null
		_icon_rect.visible = false
		tooltip_text = _build_tooltip_text()
		return
	var item_data: Dictionary = _get_item_data(item_id)
	tooltip_text = _build_tooltip_text(item_data, quantity)
	
	# 1. Try direct icon property first (fastest, used by database items)
	var icon_tex = item_data.get("icon")
	if icon_tex is Texture2D:
		_icon_rect.texture = icon_tex
		_icon_rect.visible = true
		tooltip_text = _build_tooltip_text(item_data, quantity)
		return

	# 2. Try icon_path (fallback items)
	var icon_path: String = str(item_data.get("icon_path", ""))
	
	# 3. Try asset_path (legacy items)
	if icon_path == "":
		icon_path = str(item_data.get("asset_path", ""))
	
	if icon_path != "" and ResourceLoader.exists(icon_path):
		var tex: Texture2D = load(icon_path)
		_icon_rect.texture = tex
		_icon_rect.visible = tex != null
	else:
		_icon_rect.texture = null
		_icon_rect.visible = false
	
	# Update quantity label (now direct child of ItemSlot, bottom-right)
	if _quantity_label:
		if quantity > 1:
			_quantity_label.text = str(quantity)
			_quantity_label.visible = true
		else:
			_quantity_label.visible = false


func _build_tooltip_text(item_data: Dictionary = {}, quantity: int = 0) -> String:
	if item_data.is_empty():
		return "Empty slot"
	var lines: Array[String] = []
	lines.append(item_data.get("name", get_current_item_id()))
	var category: String = str(item_data.get("category", ItemCategoriesLib.MISC))
	lines.append("Category: %s" % category.capitalize())
	if quantity > 1:
		lines.append("Quantity: %d" % quantity)
	var description: String = str(item_data.get("description", ""))
	if description != "":
		lines.append("")
		lines.append(description)
	return "\n".join(lines)

func _get_item_data(item_id: String) -> Dictionary:
	# Prefer registry-provided dictionary data when available
	if _item_registry and _item_registry.has_method("get_item_data"):
		var data: Dictionary = _item_registry.get_item_data(item_id)
		if not data.is_empty():
			return data
	# Fallback to unified inventory definitions (which merge internal + ItemDatabase data)
	if _inventory_state:
		return _inventory_state.get_item_definition(item_id)
	return {}

func _update_slot_theme() -> void:
	var style := StyleBoxFlat.new()
	# Professional, subtle corner radius
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	# Subtle shadow for depth
	style.shadow_color = Color(0, 0, 0, 0.2)
	style.shadow_size = 1
	style.shadow_offset = Vector2(1, 1)
	
	match slot_kind:
		SlotKind.BACKPACK:
			style.bg_color = Color(0.08, 0.1, 0.14, 0.85)
			style.border_width_left = 1
			style.border_width_right = 1
			style.border_width_top = 1
			style.border_width_bottom = 1
			style.border_color = Color(0.25, 0.4, 0.55, 0.5)
		SlotKind.EQUIPPED_WEAPON:
			style.bg_color = Color(0.15, 0.08, 0.08, 0.9)
			style.border_width_left = 2
			style.border_width_right = 2
			style.border_width_top = 2
			style.border_width_bottom = 2
			style.border_color = Color(0.6, 0.25, 0.25, 0.7)
		SlotKind.EQUIPPED_PASSIVE:
			style.bg_color = Color(0.08, 0.15, 0.1, 0.9)
			style.border_width_left = 2
			style.border_width_right = 2
			style.border_width_top = 2
			style.border_width_bottom = 2
			style.border_color = Color(0.25, 0.55, 0.35, 0.7)
		SlotKind.EQUIPPED_CONSUMABLE:
			style.bg_color = Color(0.15, 0.12, 0.08, 0.9)
			style.border_width_left = 2
			style.border_width_right = 2
			style.border_width_top = 2
			style.border_width_bottom = 2
			style.border_color = Color(0.6, 0.45, 0.25, 0.7)
	
	add_theme_stylebox_override("panel", style)


func _on_gui_input_forward(event: InputEvent) -> void:
	slot_gui_input.emit(event, self)

func _on_mouse_entered() -> void:
	# Temporarily disable visual hover highlight; keep signal for future use
	slot_hovered.emit(self, true)

func _on_mouse_exited() -> void:
	# Temporarily disable visual hover highlight; keep signal for future use
	slot_hovered.emit(self, false)
