extends WeaponBase
class_name RangedWeapon

## Base class for all ranged weapons that fire projectiles

# Projectile settings
@export var projectile_speed: float = 500.0
@export var projectile_lifetime: float = 2.0
@export var spread_angle: float = 5.0  # Degrees of spread for projectiles
@export var num_projectiles: int = 1  # Number of projectiles per shot
@export var burst_count: int = 1  # Number of shots in a burst
@export var burst_delay: float = 0.1  # Delay between burst shots
@export var use_gravity: bool = false  # Whether projectiles are affected by gravity
@export var gravity_scale: float = 1.0  # Gravity scale for projectiles

# Visual/audio
@export var muzzle_flash: PackedScene = null
@export var fire_sound: AudioStream = null
@export var reload_sound: AudioStream = null

# Private variables
var _burst_timer: float = 0.0
var _current_burst: int = 0
var _is_bursting: bool = false

func _ready() -> void:
	super._ready()
	weapon_type = WeaponType.RANGED

## Override to implement specific firing behavior
func _fire_weapon(target_position: Vector2) -> bool:
	if not _can_fire():
		return false
	
	# Start burst if needed
	if burst_count > 1 and not _is_bursting:
		_is_bursting = true
		_current_burst = 0
	
	# Fire the burst or single shot
	if _is_bursting:
		_fire_burst_shot(target_position)
	else:
		_fire_single_shot(target_position)
	
	return true

## Fire a single shot
func _fire_single_shot(target_position: Vector2) -> void:
	var direction = (target_position - global_position).normalized()
	
	# Create projectiles
	for i in num_projectiles:
		var projectile = _create_projectile()
		if not projectile:
			continue
		
		# Calculate spread
		var spread_rad = deg_to_rad(spread_angle)
		var angle_variation = randf_range(-spread_rad, spread_rad)
		var spread_direction = direction.rotated(angle_variation)
		
		# Set up projectile
		projectile.global_position = get_muzzle_global_position()
		projectile.set_direction(spread_direction)
		projectile.speed = projectile_speed
		projectile.lifetime = projectile_lifetime
		projectile.damage = damage
		projectile.gravity_scale = gravity_scale if use_gravity else 0.0
		
		# Add to scene
		get_tree().current_scene.add_child(projectile)
	
	# Play effects
	_play_muzzle_flash()
	_play_fire_sound()

## Fire a shot as part of a burst
func _fire_burst_shot(target_position: Vector2) -> void:
	_fire_single_shot(target_position)
	_current_burst += 1
	
	if _current_burst >= burst_count:
		_burst_timer = 0.0
		_is_bursting = false
	else:
		_burst_timer = burst_delay

## Create a new projectile instance
## Override this in derived classes for custom projectile types
func _create_projectile() -> Node2D:
	if not projectile_scene:
		push_error("No projectile scene set for " + weapon_name)
		return null
	
	var projectile = projectile_scene.instantiate()
	if not projectile.has_method("set_direction"):
		push_warning("Projectile " + projectile.name + " does not have a set_direction method")
	
	return projectile

## Play muzzle flash effect if available
func _play_muzzle_flash() -> void:
	if not muzzle_flash:
		return
	
	var flash = muzzle_flash.instantiate()
	flash.global_position = get_muzzle_global_position()
	get_tree().current_scene.add_child(flash)

## Play fire sound if available
func _play_fire_sound() -> void:
	if fire_sound and has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sound(fire_sound)

## Play reload sound if available
func _play_reload_sound() -> void:
	if reload_sound and has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sound(reload_sound)

## Override to handle weapon-specific update logic
func update(delta: float) -> void:
	super.update(delta)
	
	# Handle burst firing
	if _is_bursting and _burst_timer > 0:
		_burst_timer -= delta
		if _burst_timer <= 0 and _current_burst < burst_count:
			# Fire next shot in burst
			var target_pos = get_global_mouse_position() if Engine.is_editor_hint() else get_viewport().get_mouse_position()
			_fire_burst_shot(target_pos)

## Override to handle weapon-specific stop logic
func _stop_firing() -> void:
	super._stop_firing()
	_is_bursting = false
	_current_burst = 0
	_burst_timer = 0.0
