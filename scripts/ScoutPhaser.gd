extends Node2D

class_name ScoutPhaser

## ScoutPhaser - Continuous beam weapon rendered with Line2D

signal hit_target(target: Node, damage: float)
signal beam_ended()

const DEFAULT_LIFETIME: float = 2.0 # Reduced from 5.0 for faster gameplay
const BASE_COOLDOWN: float = 2.0
const MAX_CONTINUOUS_FIRE: float = 18.0  # 18 second cap
const COOLDOWN_PER_SECOND: float = 0.4  # 0.4s cooldown per second held
const LOCAL_AUDIO_PATH := "res://assets/Audio/weapons/PhaserBeams.wav"

@export var damage_per_second: float = 60.0
@export var beam_width: float = 6.0
@export var max_length: float = 600.0
@export var lifetime: float = DEFAULT_LIFETIME
@export var enable_local_audio: bool = true

# Use individual beam frames instead of unified sprite sheet
const BEAM_TEXTURE_PATHS := [
	"res://assets/items/Weapons/Phaser/FX_PhaserBeams1.png",
	"res://assets/items/Weapons/Phaser/FX_PhaserBeams2.png",
	"res://assets/items/Weapons/Phaser/FX_PhaserBeams3.png",
	"res://assets/items/Weapons/Phaser/FX_PhaserBeams4.png"
]

@export var segment_length: float = 32.0
@export var flicker_interval: float = 0.05

# Manual control properties
var is_manual_control: bool = false
var mouse_target: Vector2
var continuous_fire_time: float = 0.0
var cooldown_remaining: float = 0.0

var _owner_scout: Node = null
var _origin: Node2D = null
var _target: Node2D = null
var _beam: Line2D
var _raycast: RayCast2D
var _life_remaining: float = 0.0
var _beam_textures: Array[Texture2D] = []
var _segment_sprites: Array[Sprite2D] = []
var _flicker_timer: float = 0.0
var audio_player: AudioStreamPlayer2D  # Remove @onready since node may not exist
var _use_local_audio: bool = true
var _beam_finished: bool = false

func _ready() -> void:
	add_to_group("scout_beams")
	_life_remaining = lifetime
	_use_local_audio = enable_local_audio
	_load_textures()
	
	# Create audio player dynamically if it doesn't exist
	if not audio_player:
		audio_player = AudioStreamPlayer2D.new()
		add_child(audio_player)
		audio_player.name = "AudioStreamPlayer2D"
	
	# print("ScoutPhaser: _ready called - enable_local_audio: ", enable_local_audio, ", _use_local_audio: ", _use_local_audio)
	# print("ScoutPhaser: Audio player node found: ", audio_player != null)
	if audio_player:
		# print("ScoutPhaser: Audio stream loaded: ", audio_player.stream != null)
		_configure_audio_player()
	
	# Add raycast for collision detection
	var raycast = RayCast2D.new()
	add_child(raycast)
	raycast.name = "RayCast2D"
	raycast.enabled = true
	raycast.collision_mask = 2  # Enemy collision layer
	
	# Set initial visibility
	visible = true
	
	print("ScoutPhaser: Added raycast to scene tree")
	print("ScoutPhaser: Beam visible set to true")

func _load_textures() -> void:
	_beam_textures.clear()
	
	for path in BEAM_TEXTURE_PATHS:
		if not FileAccess.file_exists(path):
			print("ScoutPhaser: ERROR - Missing beam texture:", path)
			continue
		var tex := load(path) as Texture2D
		if tex:
			_beam_textures.append(tex)
		else:
			print("ScoutPhaser: ERROR - Failed to load beam texture:", path)
	
	if _beam_textures.is_empty():
		print("ScoutPhaser: WARNING - No beam textures loaded")

func _ensure_textures_loaded() -> void:
	if _beam_textures.is_empty():
		_load_textures()


func _create_beam() -> void:
	_ensure_textures_loaded()
	_beam = Line2D.new()
	_beam.texture_mode = Line2D.LINE_TEXTURE_STRETCH
	_beam.width = beam_width
	_beam.default_color = Color(0.6, 1.0, 1.0, 0.95)
	
	# Use shader material for better visuals
	var shader = load("res://shaders/PhaserBeam.gdshader")
	if shader:
		var shader_material = ShaderMaterial.new()
		shader_material.shader = shader
		shader_material.set_shader_parameter("beam_color", Color(0.0, 0.8, 1.0, 1.0))
		shader_material.set_shader_parameter("core_color", Color(1.0, 1.0, 1.0, 1.0))
		shader_material.set_shader_parameter("speed", 3.0)
		shader_material.set_shader_parameter("thickness", 0.3)
		_beam.material = shader_material
	else:
		print("ScoutPhaser: WARNING - Could not load shader")
	
	# Assign texture if available
	if _beam_textures.size() > 0:
		_beam.texture = _beam_textures[0]
	else:
		print("ScoutPhaser: WARNING - No beam textures available during creation")
		
	_beam.add_point(Vector2.ZERO)
	_beam.add_point(Vector2.UP * 10.0)
	add_child(_beam)
	
	_raycast = RayCast2D.new()
	_raycast.target_position = Vector2.ZERO
	_raycast.enabled = true
	_raycast.collision_mask = 2 # Only collide with enemies (Layer 2)
	_raycast.collide_with_areas = true
	_raycast.collide_with_bodies = true
	add_child(_raycast)
	print("ScoutPhaser: Added raycast to scene tree")

	_beam.visible = true
	print("ScoutPhaser: Beam visible set to true")

func setup(origin: Node2D, target: Node2D, owner_scout: Node = null, beam_lifetime: float = DEFAULT_LIFETIME) -> void:
	_owner_scout = owner_scout
	_origin = origin
	_target = target
	lifetime = beam_lifetime
	_life_remaining = beam_lifetime
	is_manual_control = false
	continuous_fire_time = 0.0
	_beam_finished = false
	
	# Ensure we start at the correct position
	if origin:
		global_position = origin.global_position
		
	_use_local_audio = enable_local_audio
	
	# Create beam if it doesn't exist
	if not _beam:
		_create_beam()
	
	update_beam(origin)
	# Audio setup already happened in _ready(), just start playback
	_start_audio_playback()

func setup_manual(origin: Node2D, mouse_pos: Vector2, owner_player: Node = null) -> void:
	_owner_scout = owner_player
	_origin = origin
	mouse_target = mouse_pos
	_target = null  # No specific target for manual control
	is_manual_control = true
	continuous_fire_time = 0.0
	cooldown_remaining = 0.0
	_use_local_audio = false  # Player weapon handles audio
	_beam_finished = false
	
	# Ensure we start at the correct position
	if origin:
		global_position = origin.global_position
	else:
		print("ScoutPhaser: WARNING - origin is null!")
	
	# Create beam if it doesn't exist
	if not _beam:
		_create_beam()
	
	update_beam_to_mouse()
	_start_audio_playback()

func update_beam(origin: Node2D) -> void:
	if not is_inside_tree():
		return

	_origin = origin
	global_position = origin.global_position

	var to_target: Vector2
	if _target and is_instance_valid(_target):
		# Try to get collision shape for edge targeting
		var collision_shape = _target.get_node_or_null("CollisionShape2D")
		if collision_shape:
			var target_edge = CollisionEdgeCalculator.get_edge_point(collision_shape, global_position)
			to_target = target_edge - global_position
		else:
			# Fallback to center targeting
			to_target = _target.global_position - global_position
	else:
		var forward: Vector2 = -origin.global_transform.y.normalized()
		to_target = forward * max_length

	if to_target.length() <= 0.01:
		to_target = Vector2.UP * max_length

	var clamped_direction: Vector2 = to_target.normalized()
	var beam_distance: float = min(to_target.length(), max_length)
	var beam_end: Vector2 = clamped_direction * beam_distance

	_raycast.target_position = beam_end
	_raycast.force_raycast_update()
	if _raycast.is_colliding():
		beam_end = _raycast.get_collision_point() - global_position

	_beam.set_point_position(0, Vector2.ZERO)
	_beam.set_point_position(1, beam_end)
	_update_segments(beam_end)
	# _apply_fabrik(beam_end) # Simplified: Removed Fabrik for now to reduce complexity

func _update_segments(beam_end: Vector2) -> void:
	var length: float = beam_end.length()
	if length <= 0.01:
		_hide_all_segments()
		return
	var direction: Vector2 = beam_end.normalized()
	var segment_count: int = max(1, int(ceil(length / segment_length)))
	_ensure_segment_count(segment_count)
	for i in range(_segment_sprites.size()):
		var sprite := _segment_sprites[i]
		var active: bool = i < segment_count
		sprite.visible = active
		if not active:
			continue
		var seg_pos: float = min((i + 0.5) * segment_length, length)
		sprite.position = direction * seg_pos
		sprite.rotation = direction.angle() + PI / 2.0
		if sprite.texture:
			var tex_height: float = float(sprite.texture.get_height())
			if tex_height > 0.0:
				var scale_y := segment_length / tex_height
				sprite.scale = Vector2(sprite.scale.x, scale_y)

func _ensure_segment_count(count: int) -> void:
	while _segment_sprites.size() < count:
		var segment := Sprite2D.new()
		segment.centered = true
		segment.modulate = Color(0.8, 1.0, 1.0, 0.9)
		_randomize_segment(segment)
		add_child(segment)
		_segment_sprites.append(segment)
	for sprite in _segment_sprites:
		sprite.visible = false

func _hide_all_segments() -> void:
	for sprite in _segment_sprites:
		sprite.visible = false

func _random_beam_texture() -> Texture2D:
	_ensure_textures_loaded()
	if _beam_textures.size() == 0:
		return null
	return _beam_textures[randi() % _beam_textures.size()]

func _randomize_segment(sprite: Sprite2D) -> void:
	sprite.texture = _random_beam_texture()
	sprite.flip_h = randf() < 0.5
	sprite.flip_v = randf() < 0.5

func _flicker_segments():
	for sprite in _segment_sprites:
		if not sprite.visible:
			continue
		_randomize_segment(sprite)

func _damage_target(collider: Object, delta: float) -> void:
	if not collider or not is_instance_valid(collider):
		return
	
	if collider == _owner_scout or collider.is_in_group("player") or collider.is_in_group("scouts"):
		return
	
	var damage_tick: float = damage_per_second * delta
	
	if collider.has_method("take_damage"):
		collider.take_damage(damage_tick)
	
	hit_target.emit(collider, damage_tick)

func _process(delta: float) -> void:
	# Handle cooldown
	if cooldown_remaining > 0.0:
		cooldown_remaining -= delta
		return  # Can't fire while cooling down
	
	if not _origin or not is_instance_valid(_origin):
		_free_beam()
		return
	
	_update_audio_position()

	# Manual control behavior
	if is_manual_control:
		# Update continuous fire time
		continuous_fire_time += delta
		if continuous_fire_time >= MAX_CONTINUOUS_FIRE:
			# Start cooldown
			cooldown_remaining = continuous_fire_time * COOLDOWN_PER_SECOND
			beam_ended.emit()
			_free_beam()
			return
		
		# Update beam to follow mouse
		update_beam_to_mouse()
		if _raycast and _raycast.is_colliding():
			var collider := _raycast.get_collider()
			_damage_target(collider, delta)
	else:
		# Original auto-targeting behavior
		# If target is dead/gone, stop beam
		if not _target or not is_instance_valid(_target):
			_free_beam()
			return
			
		_life_remaining -= delta
		if _life_remaining <= 0.0:
			_free_beam()
			return
		
		update_beam(_origin)
		if _raycast and _raycast.is_colliding():
			var collider := _raycast.get_collider()
			_damage_target(collider, delta)
	
	_flicker_timer -= delta
	if _flicker_timer <= 0.0:
		_flicker_segments()
		_flicker_timer = flicker_interval
	
	_beam.visible = true

func update_beam_to_mouse() -> void:
	if not is_inside_tree() or not _origin:
		return

	global_position = _origin.global_position
	var to_mouse = mouse_target - global_position
	
	if to_mouse.length() <= 0.01:
		to_mouse = Vector2.UP * max_length

	var clamped_direction: Vector2 = to_mouse.normalized()
	var beam_distance: float = min(to_mouse.length(), max_length)
	var beam_end: Vector2 = clamped_direction * beam_distance

	# Check if raycast exists
	if _raycast:
		_raycast.target_position = beam_end
		_raycast.force_raycast_update()
		if _raycast.is_colliding():
			beam_end = _raycast.get_collision_point() - global_position

	# Ensure beam exists and is visible
	if _beam:
		_beam.visible = true
		_beam.width = max(beam_width, 2.0)  # Ensure minimum width for visibility
		_beam.default_color = Color(1.0, 1.0, 1.0, 1.0)  # Make it bright white for debugging
		
		_beam.set_point_position(0, Vector2.ZERO)
		_beam.set_point_position(1, beam_end)
		_update_segments(beam_end)

func update_mouse_target(new_mouse_pos: Vector2) -> void:
	mouse_target = new_mouse_pos
	if is_manual_control:
		update_beam_to_mouse()

func stop_beam() -> void:
	_free_beam()

func get_cooldown_status() -> Dictionary:
	return {
		"on_cooldown": cooldown_remaining > 0.0,
		"cooldown_time": cooldown_remaining,
		"continuous_time": continuous_fire_time,
		"max_continuous": MAX_CONTINUOUS_FIRE
	}

func _configure_audio_player() -> void:
	# print("ScoutPhaser: _configure_audio_player called - _use_local_audio: ", _use_local_audio, ", audio_player valid: ", audio_player != null)
	if not _use_local_audio or not audio_player:
		# print("ScoutPhaser: Skipping audio configuration - _use_local_audio: ", _use_local_audio, ", audio_player: ", audio_player != null)
		return
	
	var audio_stream = load(LOCAL_AUDIO_PATH)
	if audio_stream:
		audio_player.stream = audio_stream
		audio_player.max_polyphony = 4
		audio_player.attenuation = 1.5
		audio_player.max_distance = 1400.0
		audio_player.volume_db = 0.0
		audio_player.bus = "SFX"
		# print("ScoutPhaser: Audio player configured with max_distance: ", audio_player.max_distance, ", attenuation: ", audio_player.attenuation, ", volume_db: ", audio_player.volume_db)
	else:
		print("ScoutPhaser: WARNING - Could not load audio stream: ", LOCAL_AUDIO_PATH)

func _start_audio_playback() -> void:
	# print("ScoutPhaser: _start_audio_playback - _use_local_audio: ", _use_local_audio, ", audio_player valid: ", audio_player != null)
	if not _use_local_audio or not audio_player:
		return
		
	# print("ScoutPhaser: Stream valid: ", audio_player.stream != null, ", Playing: ", audio_player.playing)
	if audio_player.stream and not audio_player.playing:
		audio_player.play()
		# print("ScoutPhaser: Audio play() called")
	elif audio_player.playing:
		# print("ScoutPhaser: Audio already playing")
		pass
	else:
		print("ScoutPhaser: No audio stream available")

func _update_audio_position() -> void:
	if not _use_local_audio or not audio_player:
		return
		
	# Update audio position to match beam origin
	if _origin and is_instance_valid(_origin):
		audio_player.global_position = _origin.global_position

func _stop_audio_playback() -> void:
	if not _use_local_audio or not audio_player:
		return
		
	if audio_player.playing:
		audio_player.stop()

func _free_beam() -> void:
	if _beam_finished:
		return
	_beam_finished = true
	# Stop audio before cleanup
	_stop_audio_playback()
	is_manual_control = false
	
	# Emit signal that beam is ending
	beam_ended.emit()
	
	# Free the beam node
	if is_inside_tree():
		queue_free()
