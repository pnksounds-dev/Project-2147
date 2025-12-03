extends Node

## Test script for PhaserBeams weapon integration
## Demonstrates individual scene system working with WeaponSystem

@export var test_position: Vector2 = Vector2(200, 200)
@export var auto_test: bool = false

var phaser_weapon: PhaserBeamsWeapon = null
var weapon_system: WeaponSystem = null

func _ready():
	# Find WeaponSystem
	weapon_system = get_tree().get_first_node_in_group("weapon_system")
	
	if not weapon_system:
		print("PhaserTest: No WeaponSystem found")
		return
	
	print("PhaserTest: WeaponSystem found")
	
	# Setup test inputs
	if Input.is_action_just_pressed("ui_accept"):
		test_phaser_creation()
	
	if auto_test:
		call_deferred("test_phaser_creation")

func _input(event):
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				test_phaser_creation()
			KEY_2:
				test_phaser_level(2)
			KEY_3:
				test_phaser_level(3)
			KEY_4:
				test_phaser_level(4)
			KEY_SPACE:
				test_weapon_system_integration()
			KEY_ESCAPE:
				cleanup_test()

func test_phaser_creation():
	"""Test creating phaser from individual scene"""
	print("PhaserTest: Creating phaser weapon from individual scene")
	
	# Clean up existing weapon
	cleanup_test()
	
	# Create phaser weapon
	phaser_weapon = PhaserBeamsWeapon.create_phaser(1, test_position)
	
	if phaser_weapon:
		print("PhaserTest: Phaser weapon created successfully")
		print("PhaserTest: Weapon level: ", phaser_weapon.weapon_level)
		print("PhaserTest: Beam damage: ", phaser_weapon.beam_damage_per_second)
		
		# Test firing at test position (Node doesn't have mouse access)
		phaser_weapon.fire_weapon(test_position)
	else:
		print("PhaserTest: Failed to create phaser weapon - scene may be missing")

func test_phaser_level(level: int):
	"""Test creating phaser at specific level"""
	print("PhaserTest: Creating level ", level, " phaser")
	
	# Clean up existing weapon
	cleanup_test()
	
	# Create phaser at specified level
	phaser_weapon = PhaserBeamsWeapon.create_phaser(level, test_position)
	
	if phaser_weapon:
		print("PhaserTest: Level ", level, " phaser created")
		print("PhaserTest: Beam color: ", phaser_weapon.sprite.modulate)
		print("PhaserTest: Glow energy: ", phaser_weapon.glow_effect.energy)
		
		# Test firing at test position
		phaser_weapon.fire_weapon(test_position)

func test_weapon_system_integration():
	"""Test phaser integration with WeaponSystem"""
	print("PhaserTest: Testing WeaponSystem integration")
	
	if not weapon_system:
		print("PhaserTest: No WeaponSystem available")
		return
	
	# Switch to phaser weapon
	weapon_system.switch_weapon(WeaponSystem.WeaponType.PHASER)
	
	# Test firing through WeaponSystem
	weapon_system.fire_weapon()
	
	print("PhaserTest: WeaponSystem phaser firing test initiated")

func cleanup_test():
	"""Clean up test weapons"""
	if phaser_weapon:
		phaser_weapon.queue_free()
		phaser_weapon = null
		print("PhaserTest: Test weapon cleaned up")

func _on_test_timer_timeout():
	"""Auto test timer"""
	if auto_test:
		test_phaser_creation()

func get_test_info() -> Dictionary:
	return {
		"test_position": test_position,
		"phaser_weapon": phaser_weapon != null,
		"weapon_system": weapon_system != null,
		"controls": {
			"KEY_1": "Create level 1 phaser",
			"KEY_2-4": "Create level 2-4 phaser",
			"KEY_SPACE": "Test WeaponSystem integration",
			"KEY_ESCAPE": "Clean up test"
		}
	}
