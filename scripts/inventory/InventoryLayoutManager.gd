extends Node
class_name InventoryLayoutManager

# Handles responsive layout calculations for the inventory UI

signal layout_calculated(slot_size: float, grid_spacing: int)

# Layout constants
const INVENTORY_COLUMNS := 12
const STAGE_HORIZONTAL_MARGIN := 40.0
const STAGE_COLUMN_GAP := 16.0
const CARGO_PANEL_PADDING := 32.0
const MIN_SLOT_SIZE := 48.0

var _inventory_container: Container
var _equip_column: Control
var _cargo_panel: Control

func initialize(inventory_container: HFlowContainer, equip_column: Control, cargo_panel: Control) -> void:
	_inventory_container = inventory_container
	_equip_column = equip_column
	_cargo_panel = cargo_panel

func calculate_responsive_layout(preferred_slot_size: float, grid_spacing: float) -> float:
	"""Calculate optimal slot size based on available width"""
	if not _inventory_container:
		return preferred_slot_size
	
	var usable_width := _get_cargo_available_width()
	if usable_width <= 100:
		usable_width = 600.0  # Fallback width
	
	var columns: int = INVENTORY_COLUMNS
	var total_gap_width := (columns - 1) * grid_spacing
	var available_for_slots := usable_width - total_gap_width
	var calculated_slot_size := available_for_slots / columns
	
	var final_slot_size: float = clamp(calculated_slot_size, MIN_SLOT_SIZE, preferred_slot_size)
	
	# HFlowContainer wraps automatically; no need to set columns
	
	# Emit layout information
	layout_calculated.emit(final_slot_size, grid_spacing)
	
	return final_slot_size

func _get_cargo_available_width() -> float:
	"""Calculate the actual available width for cargo slots"""
	var width := 0.0
	if _cargo_panel:
		width = _cargo_panel.size.x
		var panel_style: StyleBox = _cargo_panel.get_theme_stylebox("panel", "PanelContainer")
		if panel_style:
			width -= panel_style.get_margin(SIDE_LEFT) + panel_style.get_margin(SIDE_RIGHT)
	
	width -= CARGO_PANEL_PADDING
	
	if width <= 0:
		var viewport_width = get_viewport().get_visible_rect().size.x
		var equip_width = 0.0
		if _equip_column:
			equip_width = max(_equip_column.size.x, _equip_column.custom_minimum_size.x)
		else:
			equip_width = 200.0  # fallback to default equip column width
		width = viewport_width - STAGE_HORIZONTAL_MARGIN - equip_width - STAGE_COLUMN_GAP - CARGO_PANEL_PADDING
	
	return max(width, 200.0)
