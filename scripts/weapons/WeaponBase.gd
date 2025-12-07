extends Node2D
class_name WeaponBase

## Base class for all weapons in the game
## Provides core functionality and interface that all weapons must implement

# Signals
signal weapon_fired(weapon: WeaponBase, target_position: Vector2)
signal weapon_reloaded(weapon: WeaponBase)
signal weapon_ready(weapon: WeaponBase)
signal weapon_cooldown_changed(cooldown_remaining: float, cooldown_total: float)

# Enums
enum WeaponState {
	IDLE,
	FIRING,
	RELOADING,
	COOLDOWN,
	DISABLED
}

enum WeaponType {
	RANGED,
	BEAM,
	AREA,
	MELEE
}

# Exported variables
@export var weapon_name: String = "Base Weapon"
@export var weapon_type: WeaponType = WeaponType.RANGED
@export var damage: float = 10.0
@export var fire_rate: float = 1.0  # Shots per second
@export var max_ammo: int = -1  # -1 for infinite
@export var current_ammo: int = -1
@export var reload_time: float = 1.0
@export var cooldown_time: float = 0.5
@export var auto_fire: bool = false
@export var requires_target: bool = true
@export var energy_cost: float = 0.0
@export var projectile_scene: PackedScene = null
@export var muzzle_position: Node2D = null

# Private variables
var _state: WeaponState = WeaponState.IDLE
var _owner: Node2D = null
var _cooldown_timer: float = 0.0
var _reload_timer: float = 0.0
var _is_equipped: bool = false

func _ready() -> void:
	# Hook for derived classes; base implementation intentionally empty
	pass

# Virtual methods that can be overridden by derived classes

## Called when the weapon is equipped by a character
func equip(owner_node: Node2D) -> void:
	_owner = owner_node
	_is_equipped = true
	_set_state(WeaponState.IDLE)
	weapon_ready.emit(self)

## Called when the weapon is unequipped
func unequip() -> void:
	stop_firing()
	_owner = null
	_is_equipped = false
	_set_state(WeaponState.DISABLED)

## Attempt to fire the weapon at the target position
## Returns true if the weapon fired successfully
func fire(target_position: Vector2) -> bool:
	if not _can_fire():
		return false
	
	if requires_target and not target_position:
		return false
	
	_set_state(WeaponState.FIRING)
	
	# Consume ammo if not infinite
	if max_ammo > 0 and current_ammo > 0:
		current_ammo -= 1
		if current_ammo <= 0:
			start_reload()
	
	# Start cooldown
	_cooldown_timer = cooldown_time
	
	# Emit fired signal
	weapon_fired.emit(self, target_position)
	
	# Call the actual firing implementation
	return _fire_weapon(target_position)

## Stop firing the weapon
func stop_firing() -> void:
	if _state == WeaponState.FIRING:
		_stop_firing()
		_set_state(WeaponState.IDLE)

## Start reloading the weapon
func start_reload() -> void:
	if _state == WeaponState.RELOADING or max_ammo <= 0 or current_ammo >= max_ammo:
		return
	
	_set_state(WeaponState.RELOADING)
	_reload_timer = reload_time

## Update the weapon state (call from _process)
func update(delta: float) -> void:
	match _state:
		WeaponState.COOLDOWN:
			_cooldown_timer -= delta
			weapon_cooldown_changed.emit(max(0, _cooldown_timer), cooldown_time)
			if _cooldown_timer <= 0:
				_set_state(WeaponState.IDLE)
				
		WeaponState.RELOADING:
			_reload_timer -= delta
			if _reload_timer <= 0:
				current_ammo = max_ammo
				_set_state(WeaponState.IDLE)
				weapon_reloaded.emit(self)

# Internal methods

func _set_state(new_state: WeaponState) -> void:
	if _state == new_state:
		return
	
	var old_state = _state
	_state = new_state
	
	# Handle state exit
	match old_state:
		WeaponState.FIRING:
			_stop_firing()
	
	# Handle state enter
	match _state:
		WeaponState.IDLE:
			pass
		WeaponState.FIRING:
			pass
		WeaponState.RELOADING:
			pass

## Check if the weapon can fire
func _can_fire() -> bool:
	if _state != WeaponState.IDLE or not _is_equipped:
		return false
	
	if max_ammo > 0 and current_ammo <= 0:
		start_reload()
		return false
		
	if _cooldown_timer > 0:
		return false
		
	return true

## Override this in derived classes to implement weapon-specific firing logic
## @param target_position: The position to fire at (can be unused for some weapons)
## @returns: true if the weapon fired successfully
func _fire_weapon(_target_position: Vector2) -> bool:
	# Base implementation does nothing
	return true

## Override this in derived classes to implement weapon-specific stop logic
func _stop_firing() -> void:
	pass

## Get the global position where projectiles should spawn
func get_muzzle_global_position() -> Vector2:
	if muzzle_position:
		return muzzle_position.global_position
	return global_position

## Get the current state of the weapon
func get_state() -> WeaponState:
	return _state

## Check if the weapon is currently firing
func is_firing() -> bool:
	return _state == WeaponState.FIRING

## Check if the weapon is ready to fire
func is_ready() -> bool:
	return _state == WeaponState.IDLE and _is_equipped
