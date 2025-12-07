extends BaseWeapon
class_name PhaserBeamsWeapon



## Phaser beam weapon with individual scene for easy visual editing
## Fully integrated with WeaponSystem and ScoutPhaser beam system

@export var beam_damage_per_second: float = 60.0
@export var beam_width: float = 6.0
@export var beam_max_length: float = 600.0
@export var beam_lifetime: float = 2.0
@export var projectile_damage: int = 15
@export var weapon_level: int = 1  # 1-4 for different damage levels

@onready var weapon_effects: Node2D = $WeaponEffects
@onready var muzzle_flash: Sprite2D = $WeaponEffects/MuzzleFlash
@onready var projectile_spawn: Marker2D = $WeaponEffects/ProjectileSpawn
@onready var glow_effect: PointLight2D = $WeaponEffects/GlowEffect
@onready var audio_player: AudioStreamPlayer2D = $AudioStreamPlayer2D

const MAX_PHASER_AUDIO_VOICES := 4
const PHASER_AUDIO_MAX_DISTANCE := 1400.0
const PHASER_AUDIO_ATTENUATION := 1.5
const DEFAULT_ANIM_LIBRARY := "phaser_animations"
const PHASER_TEXTURE_PATHS := [
	"res://assets/items/Weapons/Phaser/FX_PhaserBeams1.png",
	"res://assets/items/Weapons/Phaser/FX_PhaserBeams2.png",
	"res://assets/items/Weapons/Phaser/FX_PhaserBeams3.png",
	"res://assets/items/Weapons/Phaser/FX_PhaserBeams4.png"
]

var current_beam: ScoutPhaser = null
var owner_reference: Node2D = null
var beam_timeout_timer: Timer = null
const BEAM_TIMEOUT: float = 3.0  # Auto-stop beam after 3 seconds
var manual_mode_active: bool = false

func _ready():
	super._ready()
	setup_phaser_weapon()
	add_to_group("phaser_weapons")
	_configure_audio_player()
	_setup_beam_timeout()

func _exit_tree():
	stop_firing()

func setup_phaser_weapon():
	"""Setup phaser-specific properties and effects"""
	weapon_id = "FX_PhaserBeams"
	weapon_type = "Science | Resources"
	damage = "Medium to Very High (based on weapon level)"
	description = "Phaser beam weapons with visual progression and damage scaling"
	integration = "Works with WeaponSystem.PHASER enum"
	animation = "4-frame sprite sheet for progressive beam effects"
	weapon_system_enum = "WeaponType.PHASER"
	
	# Setup visual effects based on weapon level
	setup_level_effects()
	
	# Create firing animations
	create_firing_animations()

func setup_level_effects():
	"""Setup effects based on weapon level (1-4)"""
	if not glow_effect:
		return
	
	var beam_color = Color.WHITE
	var glow_energy = 1.0
	
	match weapon_level:
		1:
			beam_color = Color(0.6, 1.0, 1.0)  # Light blue
			glow_energy = 1.0
			beam_damage_per_second = 60.0
			projectile_damage = 15
		2:
			beam_color = Color(0.4, 0.8, 1.0)  # Medium blue
			glow_energy = 1.5
			beam_damage_per_second = 80.0
			projectile_damage = 20
		3:
			beam_color = Color(0.2, 0.6, 1.0)  # Deep blue
			glow_energy = 2.0
			beam_damage_per_second = 100.0
			projectile_damage = 25
		4:
			beam_color = Color(0.1, 0.4, 0.8)  # Dark blue
			glow_energy = 2.5
			beam_damage_per_second = 120.0
			projectile_damage = 30
	
	glow_effect.color = beam_color
	glow_effect.energy = glow_energy
	sprite.modulate = beam_color
	_set_weapon_texture_for_level()

func _set_weapon_texture_for_level():
	"""Apply matching FX texture to the weapon sprite"""
	if not sprite:
		return
	var texture_index = clamp(weapon_level - 1, 0, PHASER_TEXTURE_PATHS.size() - 1)
	var texture_path = PHASER_TEXTURE_PATHS[texture_index]
	if texture_path == "":
		return
	var fx_texture: Texture2D = load(texture_path)
	if fx_texture:
		sprite.texture = fx_texture

func create_firing_animations():
	"""Create phaser firing animations"""
	if not animation_player:
		return

	# Create animation library directly instead of trying to get existing one
	var anim_library = AnimationLibrary.new()
	if anim_library == null:
		return
	
	var result = animation_player.add_animation_library(DEFAULT_ANIM_LIBRARY, anim_library)
	if result != OK:
		return  # Exit early if library creation failed

	if anim_library.has_animation("muzzle_flash"):
		anim_library.remove_animation("muzzle_flash")
	if anim_library.has_animation("glow_pulse"):
		anim_library.remove_animation("glow_pulse")

	var flash_animation := Animation.new()
	flash_animation.length = 0.2
	var flash_track := flash_animation.add_track(Animation.TYPE_VALUE)
	flash_animation.track_set_path(flash_track, "WeaponEffects/MuzzleFlash:modulate")
	flash_animation.track_insert_key(flash_track, 0.0, Color(1, 1, 1, 0))
	flash_animation.track_insert_key(flash_track, 0.05, Color(1, 1, 1, 1))
	flash_animation.track_insert_key(flash_track, 0.2, Color(1, 1, 1, 0))
	anim_library.add_animation("muzzle_flash", flash_animation)

	var pulse_animation := Animation.new()
	pulse_animation.length = 0.5
	pulse_animation.loop = true
	var pulse_track := pulse_animation.add_track(Animation.TYPE_VALUE)
	pulse_animation.track_set_path(pulse_track, "WeaponEffects/GlowEffect:scale")
	pulse_animation.track_insert_key(pulse_track, 0.0, Vector2(1, 1))
	pulse_animation.track_insert_key(pulse_track, 0.25, Vector2(1.2, 1.2))
	pulse_animation.track_insert_key(pulse_track, 0.5, Vector2(1, 1))
	anim_library.add_animation("glow_pulse", pulse_animation)

func fire_weapon(target_position: Vector2, weapon_owner: Node2D = null) -> bool:
	"""Fire phaser in manual mode for player weapons.

	The auto-fire path is reserved for AI/minion use and is not used by the
	player's primary weapon. This ensures beams only start from explicit
	player-controlled actions.
	"""
	PhaserLogger.log_target("PhaserBeamsWeapon", "fire_weapon (manual-only)", target_position)
	return fire_weapon_manual(target_position, weapon_owner)

func fire_weapon_manual(target_position: Vector2, weapon_owner: Node2D = null) -> bool:
	"""Fire phaser in manual mode (follows mouse)"""
	if is_firing:
		PhaserLogger.log_message("PhaserBeamsWeapon", "Manual fire rejected - already firing")
		return false
	
	if fire_timer > 0:
		PhaserLogger.log_message("PhaserBeamsWeapon", "Manual fire rejected - fire_timer active")
		return false
		
	return create_phaser_beam(target_position, weapon_owner, true)

func fire_weapon_auto(weapon_owner: Node2D = null, preferred_target_position: Vector2 = Vector2.ZERO) -> bool:
	"""Fire phaser in auto mode (targets nearest enemy)"""
	if is_firing:
		PhaserLogger.log_message("PhaserBeamsWeapon", "Auto fire rejected - already firing")
		return false
	
	if fire_timer > 0:
		PhaserLogger.log_message("PhaserBeamsWeapon", "Auto fire rejected - fire_timer active")
		return false
	
	var enemies = get_tree().get_nodes_in_group("enemy")
	if enemies.is_empty():
		return false
	
	var target_enemy: Node2D = null
	if preferred_target_position != Vector2.ZERO:
		target_enemy = _find_enemy_near_position(enemies, preferred_target_position)
	if not target_enemy:
		target_enemy = find_nearest_enemy(enemies, weapon_owner)
	if not target_enemy:
		return false
	
	return create_phaser_beam(target_enemy.global_position, weapon_owner, false, target_enemy)

func create_phaser_beam(target_position: Vector2, weapon_owner: Node2D, is_manual: bool, target_enemy: Node2D = null) -> bool:
	"""Create ScoutPhaser beam instance"""
	
	if not weapon_owner:
		PhaserLogger.log_message("PhaserBeamsWeapon", "create_phaser_beam aborted - missing owner")
		return false
	
	owner_reference = weapon_owner
	_sync_with_owner_position()
	
	# Load ScoutPhaser class
	var ScoutPhaserClass = preload("res://scripts/ScoutPhaser.gd")
	
	# Create beam instance
	current_beam = ScoutPhaserClass.new()
	current_beam.name = "PhaserBeam_" + str(weapon_owner.get_instance_id())
	
	# Configure beam with level-based damage
	current_beam.damage_per_second = beam_damage_per_second
	current_beam.beam_width = beam_width
	current_beam.max_length = beam_max_length
	current_beam.lifetime = beam_lifetime
	
	manual_mode_active = is_manual
	if is_manual:
		# Manual control - follow mouse
		current_beam.setup_manual(weapon_owner, target_position, weapon_owner)
	else:
		# Auto-targeting
		var resolved_target = target_enemy
		if not resolved_target:
			var enemies = get_tree().get_nodes_in_group("enemy")
			resolved_target = find_nearest_enemy(enemies, weapon_owner)
		if resolved_target:
			current_beam.setup(weapon_owner, resolved_target, weapon_owner, beam_lifetime)
		else:
			current_beam.queue_free()
			current_beam = null
			return false
	
	# Add beam to scene
	get_tree().current_scene.add_child(current_beam)
	
	# Connect signals
	current_beam.beam_ended.connect(_on_beam_ended)
	current_beam.hit_target.connect(_on_target_hit)
	
	# Play effects
	play_firing_effects()
	
	is_firing = true
	fire_timer = 1.0 / fire_rate
	
	return true

func find_nearest_enemy(enemies: Array, weapon_owner: Node2D) -> Node2D:
	var nearest_enemy = null
	var min_distance = INF
	
	for enemy in enemies:
		var distance = weapon_owner.global_position.distance_to(enemy.global_position)
		if distance < min_distance:
			min_distance = distance
			nearest_enemy = enemy
	
	return nearest_enemy

func _find_enemy_near_position(enemies: Array, target_pos: Vector2) -> Node2D:
	var nearest_enemy = null
	var min_distance = INF
	for enemy in enemies:
		if not enemy or not enemy is Node2D:
			continue
		var distance = target_pos.distance_to(enemy.global_position)
		if distance < min_distance:
			min_distance = distance
			nearest_enemy = enemy
	return nearest_enemy

func play_firing_effects():
	"""Play visual and audio effects"""
	# Play muzzle flash animation
	if animation_player and animation_player.has_animation("muzzle_flash"):
		animation_player.play("muzzle_flash")
	else:
		print("PhaserBeamsWeapon: muzzle_flash animation not found")
	
	# Start glow pulse
	if animation_player and animation_player.has_animation("glow_pulse"):
		animation_player.play("glow_pulse")
	else:
		print("PhaserBeamsWeapon: glow_pulse animation not found")
	
	# Play phaser sound
	if audio_player:
		audio_player.play()

func _sync_with_owner_position() -> void:
	if not owner_reference:
		return
	
	global_position = owner_reference.global_position
	if audio_player:
		audio_player.global_position = global_position

func _configure_audio_player() -> void:
	if not audio_player:
		return
	
	# Load phaser beam sound
	var phaser_sound = load("res://assets/Audio/weapons/PhaserBeams.wav")
	if phaser_sound:
		audio_player.stream = phaser_sound
	else:
		print("PhaserBeamsWeapon: WARNING - Could not load phaser sound")
	
	audio_player.max_polyphony = MAX_PHASER_AUDIO_VOICES
	audio_player.attenuation = PHASER_AUDIO_ATTENUATION
	audio_player.max_distance = PHASER_AUDIO_MAX_DISTANCE
	audio_player.bus = "SFX"

func stop_firing():
	"""Stop the phaser beam and emit weapon_stopped signal"""
	PhaserLogger.log_message("PhaserBeamsWeapon", "stop_firing invoked")
	
	# Stop timeout timer
	if beam_timeout_timer and beam_timeout_timer.time_left > 0:
		beam_timeout_timer.stop()
		PhaserLogger.log_message("PhaserBeamsWeapon", "Beam timeout stopped")
	
	if current_beam:
		var beam_ref = current_beam
		# Force stop the beam if it has a stop method
		if beam_ref.has_method("stop_beam"):
			beam_ref.stop_beam()
		
		# Clear reference and state
		current_beam = null
		is_firing = false
	
	# Emit signal for WeaponSystem
	weapon_stopped.emit(self)
	
	# Free the weapon instance itself
	if is_inside_tree():
		queue_free()
	
	# Stop audio
	if audio_player and audio_player.playing:
		audio_player.stop()

func stop_firing_effects():
	"""Stop firing effects"""
	# Stop animations
	if animation_player:
		animation_player.stop()
	
	# Stop audio
	if audio_player and audio_player.playing:
		audio_player.stop()

func _on_beam_ended():
	"""Handle beam ending naturally"""
	PhaserLogger.log_message("PhaserBeamsWeapon", "Beam ended signal received")
	current_beam = null
	is_firing = false

func _on_target_hit(_target: Node, _hit_damage: float):
	"""Handle beam hitting target"""

func _process(delta):
	"""Update fire timer"""
	_sync_with_owner_position()
	if fire_timer > 0:
		fire_timer -= delta

func is_manual_control() -> bool:
	return manual_mode_active

func update_mouse_target(new_mouse_pos: Vector2):
	if not manual_mode_active:
		return
	if current_beam and current_beam.is_manual_control:
		current_beam.update_mouse_target(new_mouse_pos)

# Override base methods
func get_weapon_data() -> Dictionary:
	var data = super.get_weapon_data()
	data["beam_damage_per_second"] = beam_damage_per_second
	data["beam_width"] = beam_width
	data["beam_max_length"] = beam_max_length
	data["weapon_level"] = weapon_level
	data["projectile_damage"] = projectile_damage
	return data

func get_weapon_config() -> Dictionary:
	return {
		"name": weapon_id,
		"fire_rate": fire_rate,
		"damage": projectile_damage,
		"beam_damage": beam_damage_per_second,
		"weapon_level": weapon_level,
		"projectile_scene": projectile_scene,
		"weapon_system_enum": weapon_system_enum
	}

# Static method for easy creation
static func create_phaser(level: int = 1, spawn_position: Vector2 = Vector2.ZERO) -> PhaserBeamsWeapon:
	# Use load instead of preload to avoid static loading issues
	var weapon_scene = load("res://scenes/weapons/FX_PhaserBeams.tscn")
	if not weapon_scene:
		print("PhaserBeamsWeapon: Failed to load scene file")
		return null
	
	var weapon_instance = weapon_scene.instantiate()
	if not weapon_instance:
		print("PhaserBeamsWeapon: Failed to instantiate scene")
		return null
	
	weapon_instance.weapon_level = level
	weapon_instance.global_position = spawn_position
	
	return weapon_instance

func _setup_beam_timeout():
	"""Setup automatic beam timeout to prevent stuck beams"""
	beam_timeout_timer = Timer.new()
	beam_timeout_timer.wait_time = BEAM_TIMEOUT
	beam_timeout_timer.one_shot = true
	beam_timeout_timer.timeout.connect(_on_beam_timeout)
	add_child(beam_timeout_timer)
	print("PhaserBeams: Beam timeout timer setup complete")

func _on_beam_timeout():
	"""Automatically stop beam after timeout"""
	print("PhaserBeams: Beam timeout reached - forcing stop")
	stop_firing()
