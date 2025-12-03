extends "res://scripts/weapons/WeaponBase.gd"
class_name BeamWeapon

## Base class for continuous beam weapons like lasers or phasers
## Requires a Line2D node named 'BeamLine' as a child

# Beam settings
@export var beam_damage_per_second: float = 30.0
@export var max_range: float = 1000.0
@export var beam_width: float = 10.0
@export var beam_color: Color = Color(0.2, 1.0, 0.2, 0.8)
@export var beam_hit_effect: PackedScene = null
@export var beam_particle_material: Material = null
@export var beam_texture: Texture2D = null

# Beam behavior
@export var pierces: int = 0  # Number of enemies the beam can pass through
@export var can_damage_same_target: bool = true
@export var damage_interval: float = 0.1  # How often to apply damage (seconds)

# Visual/audio
@export var beam_start_sound: AudioStream = null
@export var beam_loop_sound: AudioStream = null
@export var beam_end_sound: AudioStream = null

# Nodes
@onready var beam_line: Line2D = $BeamLine
@onready var beam_particles: GPUParticles2D = $BeamParticles if has_node("BeamParticles") else null
@onready var audio_player: AudioStreamPlayer2D = $AudioStreamPlayer2D

# Private variables
var _beam_active: bool = false
var _damage_timer: float = 0.0
var _current_targets: Array = []
var _audio_loop_id: int = -1

func _ready() -> void:
	weapon_type = WeaponType.BEAM
	
	# Initialize beam line
	if beam_line:
		beam_line.width = beam_width
		beam_line.default_color = beam_color
		beam_line.visible = false
	
	# Initialize particles
	if beam_particles and beam_particle_material:
		beam_particles.process_material = beam_particle_material

## Override to handle beam weapon firing
func _fire_weapon(_target_position: Vector2) -> bool:
	if not _beam_active:
		_start_beam()

	return true

## Start the beam effect
func _start_beam() -> void:
	_beam_active = true
	
	# Show beam
	if beam_line:
		beam_line.visible = true
	
	# Play start sound
	if beam_start_sound:
		audio_player.stream = beam_start_sound
		audio_player.play()
	
	# Start loop sound if available
	if beam_loop_sound:
		_audio_loop_id = AudioServer.get_bus_index("SFX")
		# Implementation for looped sound would go here

## Update the beam each frame
func _process_beam(delta: float) -> void:
	if not _beam_active:
		return
	
	# Update damage timer
	_damage_timer += delta
	
	# Cast ray to find targets
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(
		global_position,
		global_position + (get_global_mouse_position() - global_position).normalized() * max_range
	)
	query.collision_mask = 1  # Adjust collision mask as needed
	
	var result = space_state.intersect_ray(query)
	
	# Update beam visuals
	if beam_line:
		beam_line.clear_points()
		beam_line.add_point(Vector2.ZERO)
		
		if result:
			var end_point = to_local(result.position)
			beam_line.add_point(end_point)
			
			# Handle hit effect
			if beam_hit_effect and _damage_timer >= damage_interval:
				var hit_effect = beam_hit_effect.instantiate()
				add_child(hit_effect)
				hit_effect.global_position = result.position
		else:
			beam_line.add_point(Vector2.RIGHT * max_range)
	
	# Apply damage at intervals
	if _damage_timer >= damage_interval:
		_apply_beam_damage(result)
		_damage_timer = 0.0

## Apply damage to targets in the beam
func _apply_beam_damage(ray_result: Dictionary) -> void:
	if not ray_result or not ray_result.collider:
		return
	
	var target = ray_result.collider
	
	# Check if we can damage this target again
	if not can_damage_same_target and target in _current_targets:
		return
	
	# Apply damage
	if target.has_method("take_damage"):
		target.take_damage(beam_damage_per_second * damage_interval)
		
		if not can_damage_same_target:
			_current_targets.append(target)

## Stop the beam
func _stop_firing() -> void:
	super._stop_firing()
	
	if not _beam_active:
		return
	
	_beam_active = false
	
	# Hide beam
	if beam_line:
		beam_line.visible = false
	
	# Stop sounds
	if audio_player.playing:
		audio_player.stop()
	
	if _audio_loop_id != -1:
		# Stop looped sound
		pass
	
	# Play end sound
	if beam_end_sound:
		audio_player.stream = beam_end_sound
		audio_player.play()
	
	# Clear targets
	_current_targets.clear()

## Clean up when removed
func _exit_tree() -> void:
	_stop_firing()

## Override to handle beam-specific updates
func update(delta: float) -> void:
	super.update(delta)
	
	if _beam_active:
		_process_beam(delta)

## Check if the beam is currently active
func is_beam_active() -> bool:
	return _beam_active

## Get the current beam end position in global coordinates
func get_beam_end_position() -> Vector2:
	if not beam_line or beam_line.points.size() < 2:
		return global_position
	return to_global(beam_line.points[1])

## Get the current beam direction
func get_beam_direction() -> Vector2:
	return (get_global_mouse_position() - global_position).normalized() if _beam_active else Vector2.ZERO
