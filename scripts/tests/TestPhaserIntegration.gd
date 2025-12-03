extends Node2D

@onready var weapon_system = $WeaponSystem
@onready var player = $Player
@onready var enemy = $Enemy
@onready var inventory_ui = $InventoryUI

func _ready():
	print("--- Starting Phaser Integration Test ---")
	
	# Wait for systems to initialize
	await get_tree().create_timer(0.5).timeout
	
	test_manual_fire()
	
	await get_tree().create_timer(2.0).timeout
	
	test_auto_fire()
	
	print("--- Test Complete ---")

func test_manual_fire():
	print("\nTesting Manual Fire...")
	
	# Simulate Phaser in Weapon Slot
	inventory_ui.special_slots[0] = {"name": "Phaser", "quantity": 1, "type": "weapon", "icon": "res://assets/items/PhaserBeams.png", "slot_type": "weapon"}
	inventory_ui._update_weapon_system()
	
	# Fire weapon
	weapon_system.fire_weapon()
	
	# Check results
	await get_tree().create_timer(0.1).timeout
	var beams = get_tree().get_nodes_in_group("scout_beams")
	if beams.size() > 0:
		print("PASS: Beam created for manual fire")
		var beam = beams[0]
		if beam.is_manual_control:
			print("PASS: Beam is in manual control mode")
		else:
			print("FAIL: Beam is NOT in manual control mode")
	else:
		print("FAIL: No beam created for manual fire")
		
	# Stop firing
	weapon_system.stop_phaser()

func test_auto_fire():
	print("\nTesting Auto Fire...")
	
	# Simulate Phaser in Passive Slot
	inventory_ui.special_slots[0] = {"name": "", "quantity": 0, "type": "empty", "icon": "", "slot_type": "weapon"}
	inventory_ui.special_slots[1] = {"name": "Phaser", "quantity": 1, "type": "weapon", "icon": "res://assets/items/PhaserBeams.png", "slot_type": "passive"}
	inventory_ui._update_weapon_system()
	
	# Trigger auto-fire check
	weapon_system.auto_fire_paser_if_needed()
	
	# Check results
	await get_tree().create_timer(0.1).timeout
	var beams = get_tree().get_nodes_in_group("scout_beams")
	if beams.size() > 0:
		print("PASS: Beam created for auto fire")
		var beam = beams[0]
		if not beam.is_manual_control:
			print("PASS: Beam is in auto control mode")
		else:
			print("FAIL: Beam is NOT in auto control mode")
	else:
		print("FAIL: No beam created for auto fire")
