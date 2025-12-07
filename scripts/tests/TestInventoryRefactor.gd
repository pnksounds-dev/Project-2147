extends Node

# Simple test script to verify refactored inventory functionality
# Run this in the editor to test basic inventory operations

func _ready() -> void:
	print("=== Testing Refactored Inventory System ===")
	
	# Test 1: Check if InventoryUI can be instantiated
	test_inventory_ui_instantiation()
	
	# Test 2: Check if components are properly initialized
	test_component_initialization()
	
	# Test 3: Check if basic methods work
	test_basic_methods()
	
	print("=== Inventory Refactor Test Complete ===")

func test_inventory_ui_instantiation() -> void:
	print("\n[Test 1] InventoryUI Instantiation:")
	
	var inventory_scene = preload("res://scenes/InventoryUI.tscn")
	if not inventory_scene:
		print("❌ FAILED: Could not load InventoryUI scene")
		return
	
	var inventory_ui = inventory_scene.instantiate()
	if not inventory_ui:
		print("❌ FAILED: Could not instantiate InventoryUI")
		return
	
	if not inventory_ui.has_method("toggle_inventory"):
		print("❌ FAILED: toggle_inventory method missing")
		return
	
	if not inventory_ui.has_method("open_inventory"):
		print("❌ FAILED: open_inventory method missing")
		return
	
	if not inventory_ui.has_method("close_inventory"):
		print("❌ FAILED: close_inventory method missing")
		return
	
	print("✅ PASSED: InventoryUI instantiated with all required methods")
	inventory_ui.queue_free()

func test_component_initialization() -> void:
	print("\n[Test 2] Component Initialization:")
	
	var inventory_scene = preload("res://scenes/InventoryUI.tscn")
	var inventory_ui = inventory_scene.instantiate()
	add_child(inventory_ui)
	
	# Wait a frame for initialization
	await get_tree().process_frame
	
	# Check if component classes exist
	var layout_manager_class = preload("res://scripts/inventory/InventoryLayoutManager.gd")
	var slot_manager_class = preload("res://scripts/inventory/SlotManager.gd")
	var drag_drop_handler_class = preload("res://scripts/inventory/DragDropHandler.gd")
	var filter_controller_class = preload("res://scripts/inventory/FilterController.gd")
	var animation_controller_class = preload("res://scripts/inventory/AnimationController.gd")
	
	if layout_manager_class and slot_manager_class and drag_drop_handler_class and filter_controller_class and animation_controller_class:
		print("✅ PASSED: All component classes loaded successfully")
	else:
		print("❌ FAILED: One or more component classes missing")
	
	# Check if components are instantiated in the inventory UI
	var has_components = true
	var component_names = ["_layout_manager", "_slot_manager", "_drag_drop_handler", "_filter_controller", "_animation_controller"]
	
	for component_name in component_names:
		if not inventory_ui.get(component_name):
			print("❌ FAILED: Component %s not initialized" % component_name)
			has_components = false
	
	if has_components:
		print("✅ PASSED: All components properly initialized")
	
	inventory_ui.queue_free()

func test_basic_methods() -> void:
	print("\n[Test 3] Basic Methods:")
	
	var inventory_scene = preload("res://scenes/InventoryUI.tscn")
	var inventory_ui = inventory_scene.instantiate()
	add_child(inventory_ui)
	
	# Wait a frame for initialization
	await get_tree().process_frame
	
	# Test basic method calls (without actually opening UI)
	var is_open = inventory_ui.is_inventory_open()
	print("✅ PASSED: is_inventory_open() returned: ", is_open)
	
	var current_filter = inventory_ui.get_current_filter()
	print("✅ PASSED: get_current_filter() returned: ", current_filter)
	
	inventory_ui.set_visible(false)
	print("✅ PASSED: set_visible() executed without error")
	
	inventory_ui.apply_ui_settings({})
	print("✅ PASSED: apply_ui_settings() executed without error")
	
	inventory_ui.queue_free()
