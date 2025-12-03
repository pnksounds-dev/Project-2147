extends Node
class_name WeaponManager

## Manages weapon lifecycle, switching, and state for a character

# Preload WeaponBase for type hints
const WeaponBase = preload("res://scripts/weapons/WeaponBase.gd")

# Signals
signal weapon_switched(weapon: WeaponBase)
signal weapon_fired(weapon: WeaponBase, target_position: Vector2)
signal weapon_reloaded(weapon: WeaponBase)
signal weapon_state_changed(weapon: WeaponBase, state: int)

# References
@export var weapons: Array[WeaponBase] = []
@export var default_weapon_index: int = 0
@export var auto_switch_on_empty: bool = true
@export var auto_reload: bool = true

# Private variables
var _current_weapon_index: int = -1
var _weapon_owner: Node2D = null
var _is_active: bool = true

func _ready() -> void:
	# Initialize weapons if any are pre-configured in the scene
	for weapon in weapons:
		_initialize_weapon(weapon)
	
	# Equip default weapon if available
	if weapons.size() > 0:
		set_current_weapon_index(default_weapon_index)

## Initialize a weapon and connect its signals
func _initialize_weapon(weapon: WeaponBase) -> void:
	if not weapon:
		return
	
	# Connect weapon signals
	if not weapon.weapon_fired.is_connected(_on_weapon_fired):
		weapon.weapon_fired.connect(_on_weapon_fired)
	
	if not weapon.weapon_stopped.is_connected(_on_weapon_stopped):
		weapon.weapon_stopped.connect(_on_weapon_stopped)
	
	if not weapon.weapon_reloaded.is_connected(_on_weapon_reloaded):
		weapon.weapon_reloaded.connect(_on_weapon_reloaded)
	
	if not weapon.weapon_ready.is_connected(_on_weapon_ready):
		weapon.weapon_ready.connect(_on_weapon_ready)

## Set the owner of all weapons
## Use set_weapon_owner() to avoid conflict with Node's set_owner()
func set_weapon_owner(owner_node: Node2D) -> void:
	_weapon_owner = owner_node
	for weapon in weapons:
		if weapon:
			weapon.equip(owner_node)

## Add a weapon to the manager
func add_weapon(weapon: WeaponBase, make_current: bool = false) -> void:
	if not weapon or weapon in weapons:
		return
	
	weapons.append(weapon)
	_initialize_weapon(weapon)
	
	if _weapon_owner:
		weapon.equip(_weapon_owner)
	
	if make_current or weapons.size() == 1:  # First weapon added
		set_current_weapon_index(weapons.size() - 1)

## Remove a weapon from the manager
func remove_weapon(weapon: WeaponBase) -> void:
	var index = weapons.find(weapon)
	if index == -1:
		return
	
	# If removing current weapon, switch to default first
	if index == _current_weapon_index:
		weapon.unequip()
		set_current_weapon_index(default_weapon_index)
	
	# Disconnect signals
	weapon.weapon_fired.disconnect(_on_weapon_fired)
	weapon.weapon_stopped.disconnect(_on_weapon_stopped)
	weapon.weapon_reloaded.disconnect(_on_weapon_reloaded)
	weapon.weapon_ready.disconnect(_on_weapon_ready)
	
	weapons.remove_at(index)
	
	# Update current weapon index if needed
	if _current_weapon_index >= weapons.size():
		_current_weapon_index = weapons.size() - 1

## Handle inventory changes and update weapons accordingly
## equipped_weapons: Dictionary mapping SlotType to weapon instance data
func on_inventory_changed(equipped_weapons: Dictionary) -> void:
	print("WeaponManager: Processing inventory changes")
	
	# Create a list of currently equipped weapon instance IDs
	var current_weapon_ids: Array = []
	for weapon in weapons:
		if weapon and weapon.has_meta("instance_id"):
			current_weapon_ids.append(weapon.get_meta("instance_id"))
	
	# Process each equipped weapon from inventory
	for slot in equipped_weapons.keys():
		var weapon_data = equipped_weapons[slot]
		if not weapon_data or not weapon_data.has("instance_id"):
			continue
			
		var instance_id = weapon_data["instance_id"]
		var item_id = weapon_data.get("item_id", "")
		
		# Skip if this weapon is already equipped
		if instance_id in current_weapon_ids:
			current_weapon_ids.erase(instance_id)
			continue
			
		# Add new weapon
		print("WeaponManager: Adding weapon ", item_id)
		var weapon_scene_path = _get_weapon_scene_path(item_id)
		if weapon_scene_path:
			var weapon_scene = load(weapon_scene_path)
			if weapon_scene:
				var weapon = weapon_scene.instantiate()
				weapon.set_meta("instance_id", instance_id)
				add_weapon(weapon, false)
	
	# Remove weapons that are no longer equipped
	for weapon in weapons.duplicate():
		if weapon and weapon.has_meta("instance_id") and weapon.get_meta("instance_id") in current_weapon_ids:
			print("WeaponManager: Removing unequipped weapon")
			remove_weapon(weapon)

## Get the scene path for a weapon by its item_id
func _get_weapon_scene_path(item_id: String) -> String:
	# This should be implemented to return the correct scene path for each weapon type
	# Example implementation:
	match item_id:
		"auto_turret":
			return "res://scenes/weapons/AutoTurret.tscn"
		"phasers":
			return "res://scenes/weapons/FX_PhaserBeams.tscn"
		_:
			print("WeaponManager: Unknown weapon type: ", item_id)
			return ""

## Set the current weapon by index
func set_current_weapon_index(index: int) -> void:
	if index < 0 or index >= weapons.size() or not weapons[index]:
		return
	
	# Skip if already this weapon
	if _current_weapon_index == index:
		return
	
	# Unequip current weapon
	var current_weapon = get_current_weapon()
	if current_weapon:
		current_weapon.unequip()
	
	# Set new current weapon
	_current_weapon_index = index
	current_weapon = get_current_weapon()
	
	if current_weapon and _weapon_owner:
		current_weapon.equip(_weapon_owner)
		weapon_switched.emit(current_weapon)

## Get the current weapon
func get_current_weapon() -> WeaponBase:
	if _current_weapon_index < 0 or _current_weapon_index >= weapons.size():
		return null
	return weapons[_current_weapon_index]

## Get a weapon by index
func get_weapon(index: int) -> WeaponBase:
	if index < 0 or index >= weapons.size():
		return null
	return weapons[index]

## Fire the current weapon at the target position
func fire_weapon(target_position: Vector2) -> bool:
	if not _is_active:
		return false
	
	var weapon = get_current_weapon()
	if not weapon:
		return false
	
	return weapon.fire(target_position)

## Stop firing the current weapon
func stop_firing() -> void:
	var weapon = get_current_weapon()
	if weapon:
		weapon.stop_firing()

## Reload the current weapon
func reload_weapon() -> void:
	var weapon = get_current_weapon()
	if weapon and weapon.max_ammo > 0:
		weapon.start_reload()

## Switch to the next available weapon
func switch_to_next_weapon() -> void:
	if weapons.size() <= 1:
		return
	
	var next_index = (_current_weapon_index + 1) % weapons.size()
	set_current_weapon_index(next_index)

## Switch to the previous available weapon
func switch_to_previous_weapon() -> void:
	if weapons.size() <= 1:
		return
	
	var prev_index = (_current_weapon_index - 1 + weapons.size()) % weapons.size()
	set_current_weapon_index(prev_index)

## Update the weapon manager (call from _process)
func update(delta: float) -> void:
	if not _is_active:
		return
	
	var weapon = get_current_weapon()
	if weapon:
		weapon.update(delta)

# Signal handlers

func _on_weapon_fired(weapon: WeaponBase, target_position: Vector2) -> void:
	weapon_fired.emit(weapon, target_position)

func _on_weapon_stopped(_weapon: WeaponBase) -> void:
	pass  # Can be used for cleanup or effects

func _on_weapon_reloaded(weapon: WeaponBase) -> void:
	weapon_reloaded.emit(weapon)

func _on_weapon_ready(weapon: WeaponBase) -> void:
	weapon_state_changed.emit(weapon, weapon.get_state())

## Enable or disable the weapon manager
func set_active(active: bool) -> void:
	_is_active = active
	if not active:
		stop_firing()

## Check if the weapon manager is active
func is_active() -> bool:
	return _is_active
