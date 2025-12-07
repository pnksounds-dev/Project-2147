extends Node
class_name WeaponManager

## Manages weapon lifecycle, switching, and state for a character

# Signals
signal weapon_switched(weapon: BaseWeapon)
signal weapon_fired(weapon: BaseWeapon, target_position: Vector2)
signal weapon_reloaded(weapon: BaseWeapon)
signal weapon_state_changed(weapon: BaseWeapon, state: int)

# References
@export var weapons: Array[BaseWeapon] = []
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
func _initialize_weapon(weapon: BaseWeapon) -> void:
	if not weapon:
		return
	
	# Connect weapon signals
	if not weapon.weapon_fired.is_connected(_on_weapon_fired):
		weapon.weapon_fired.connect(_on_weapon_fired)
	
	if not weapon.weapon_stopped.is_connected(_on_weapon_stopped):
		weapon.weapon_stopped.connect(_on_weapon_stopped)
	
	if not weapon.weapon_reloaded.is_connected(_on_weapon_reloaded):
		weapon.weapon_reloaded.connect(_on_weapon_reloaded)
	
	if weapon.has_signal("weapon_ready"):
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
func add_weapon(weapon: BaseWeapon, make_current: bool = false) -> void:
	if not weapon or weapon in weapons:
		return
	
	weapons.append(weapon)
	
	# Ensure weapon is in the scene tree
	if not weapon.get_parent():
		add_child(weapon)
		
	_initialize_weapon(weapon)
	
	if _weapon_owner:
		weapon.equip(_weapon_owner)
	
	if make_current or weapons.size() == 1:  # First weapon added
		set_current_weapon_index(weapons.size() - 1)

## Remove a weapon from the manager
func remove_weapon(weapon: BaseWeapon) -> void:
	var index = weapons.find(weapon)
	if index == -1:
		return
	
	# If removing current weapon, switch to default first
	if index == _current_weapon_index:
		weapon.unequip()
		set_current_weapon_index(default_weapon_index)
	
	# Disconnect signals
	if weapon.weapon_fired.is_connected(_on_weapon_fired):
		weapon.weapon_fired.disconnect(_on_weapon_fired)
	if weapon.weapon_stopped.is_connected(_on_weapon_stopped):
		weapon.weapon_stopped.disconnect(_on_weapon_stopped)
	if weapon.weapon_reloaded.is_connected(_on_weapon_reloaded):
		weapon.weapon_reloaded.disconnect(_on_weapon_reloaded)
	if weapon.has_signal("weapon_ready") and weapon.weapon_ready.is_connected(_on_weapon_ready):
		weapon.weapon_ready.disconnect(_on_weapon_ready)
	
	weapons.remove_at(index)
	
	# Remove from scene
	if weapon.get_parent() == self:
		remove_child(weapon)
		weapon.queue_free()
	
	# Update current weapon index if needed
	if _current_weapon_index >= weapons.size():
		_current_weapon_index = weapons.size() - 1

## Handle inventory changes and update weapons accordingly
## equipped_weapons: Dictionary mapping SlotType to weapon instance data
func on_inventory_changed(equipped_weapons: Dictionary) -> void:
	print("WeaponManager: Processing inventory changes")
	
	# Current Weapon Instances
	var old_weapons = weapons.duplicate()
	var new_weapons: Array[BaseWeapon] = []
	new_weapons.resize(2) # Support 2 active weapon slots
	
	# Mapping from SlotType (Int) to Index
	# See InventorySlotType.gd for enum values (WEAPON1=0, WEAPON2=1 usually)
	# But we'll map explicitly based on keys present in equipped_weapons
	
	# We need to know which slot is which. The keys in equipped_weapons are ints (InventorySlotType.SlotType)
	# WEAPON1 = 0, WEAPON2 = 1.
	
	for slot_type in [0, 1]: # WEAPON1, WEAPON2
		if not equipped_weapons.has(slot_type):
			continue
			
		var weapon_data = equipped_weapons[slot_type]
		if not weapon_data or not weapon_data.has("instance_id"):
			continue
			
		var instance_id = weapon_data["instance_id"]
		var item_id = weapon_data.get("item_id", "")
		
		# Check if we already have this weapon instance active
		var existing_weapon = null
		for w in old_weapons:
			if w and w.has_meta("instance_id") and w.get_meta("instance_id") == instance_id:
				existing_weapon = w
				break
		
		if existing_weapon:
			new_weapons[slot_type] = existing_weapon
			# Remove from old list so we know what to delete later
			old_weapons.erase(existing_weapon)
		else:
			# Create new weapon
			print("WeaponManager: Adding weapon ", item_id, " to slot ", slot_type)
			var weapon_scene_path = _get_weapon_scene_path(item_id)
			if weapon_scene_path:
				var weapon_scene = load(weapon_scene_path)
				if weapon_scene:
					var weapon = weapon_scene.instantiate()
					weapon.set_meta("instance_id", instance_id)
					# Add child immediately
					add_child(weapon)
					_initialize_weapon(weapon)
					if _weapon_owner:
						weapon.equip(_weapon_owner)
					new_weapons[slot_type] = weapon

	# Clean up any weapons that are no longer in slots 0 or 1
	for w in old_weapons:
		if w:
			remove_weapon(w)
			
	# Update the main weapons array
	weapons = []
	for w in new_weapons:
		if w:
			weapons.append(w)
		else:
			# If slot is empty, we might want null placeholder or just skip?
			# If we skip, indices shift. The User request implies fixed mapping.
			# "LMB -> Weapon 1, RMB -> Weapon 2".
			# So we need strict indexing.
			weapons.append(null) # Placeholders for empty slots

## Fire specific weapon by index (0 = Weapon 1, 1 = Weapon 2)
func fire_weapon_index(index: int, target_position: Vector2) -> bool:
	if not _is_active:
		return false
	var weapon = get_weapon(index)
	if not weapon:
		return false
	return weapon.fire_weapon(target_position)

## Stop firing specific weapon by index
func stop_firing_index(index: int) -> void:
	var weapon = get_weapon(index)
	if weapon:
		weapon.stop_firing()

# Keep existing methods for compatibility or internal logic, but modify if needed
# ... set_current_weapon_index might be less relevant now but harmless to keep if unused.


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
func get_current_weapon() -> BaseWeapon:
	if _current_weapon_index < 0 or _current_weapon_index >= weapons.size():
		return null
	return weapons[_current_weapon_index]

## Get a weapon by index
func get_weapon(index: int) -> BaseWeapon:
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
	
	return weapon.fire_weapon(target_position)

## Stop firing the current weapon
func stop_firing() -> void:
	var weapon = get_current_weapon()
	if weapon:
		weapon.stop_firing()

## Reload the current weapon
func reload_weapon() -> void:
	var weapon = get_current_weapon()
	if weapon and weapon.max_ammo > 0:
		weapon.reload_weapon()

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
func update(_delta: float) -> void:
	if not _is_active:
		return
	
	# BaseWeapon uses _process for updates, so explicit update check might not be needed
	# But if we need to sync anything, do it here
	pass

# Signal handlers

func _on_weapon_fired(weapon: BaseWeapon, target_position: Vector2) -> void:
	weapon_fired.emit(weapon, target_position)


func _on_weapon_stopped(_weapon: BaseWeapon) -> void:
	pass  # Can be used for cleanup or effects

func _on_weapon_reloaded(weapon: BaseWeapon) -> void:
	weapon_reloaded.emit(weapon)

func _on_weapon_ready(weapon: BaseWeapon) -> void:
	weapon_state_changed.emit(weapon, weapon.get_state())

## Enable or disable the weapon manager
func set_active(active: bool) -> void:
	_is_active = active
	if not active:
		stop_firing()

## Check if the weapon manager is active
func is_active() -> bool:
	return _is_active
