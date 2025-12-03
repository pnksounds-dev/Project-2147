extends Node2D
class_name BaseWeapon

## Base functionality for all weapons
## Individual weapons extend this class for easy visual editing

signal weapon_fired(weapon: BaseWeapon, target_position: Vector2)
signal weapon_stopped(weapon: BaseWeapon)
signal weapon_reloaded(weapon: BaseWeapon)

@export var weapon_id: String = ""
@export var weapon_type: String = "Science | Resources"
@export var damage: String = "Medium"
@export var description: String = "A weapon"
@export var integration: String = "Generic weapon system"
@export var animation: String = "Standard animations"
@export var weapon_system_enum: String = "WeaponType.BULLET"
@export var projectile_scene: String = ""
@export var auto_fire: bool = false
@export var fire_rate: float = 1.0
@export var max_ammo: int = -1  # -1 for infinite
@export var current_ammo: int = -1

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var is_firing: bool = false
var fire_timer: float = 0.0
var owner_node: Node2D = null

func _ready():
	setup_weapon()

func setup_weapon():
	"""Setup weapon-specific properties - override in individual weapons"""
	if weapon_id == "":
		weapon_id = name
	
	# Auto-adjust collision shape to sprite size
	if sprite and sprite.texture:
		_adjust_collision_shape()

func _adjust_collision_shape():
	"""Adjust collision shape to match sprite size"""
	if collision_shape and collision_shape.shape is RectangleShape2D:
		var rect_shape = collision_shape.shape as RectangleShape2D
		var texture_size = sprite.texture.get_size()
		rect_shape.size = texture_size

func set_owner_node(weapon_owner: Node2D):
	"""Set the owner node for this weapon"""
	owner_node = weapon_owner

func fire_weapon(target_position: Vector2, weapon_owner: Node2D = null) -> bool:
	"""Fire weapon - override in individual weapons"""
	if weapon_owner:
		set_owner_node(weapon_owner)
	
	if is_firing and not auto_fire:
		return false
	
	# Check fire rate
	if fire_timer > 0:
		return false
	
	# Check ammo
	if max_ammo > 0 and current_ammo <= 0:
		print("BaseWeapon: Out of ammo")
		return false
	
	# Override in individual weapons for actual firing logic
	_perform_fire(target_position)
	
	# Update ammo
	if max_ammo > 0:
		current_ammo -= 1
		if current_ammo <= 0:
			reload_weapon()
	
	# Set fire timer
	fire_timer = 1.0 / fire_rate
	
	# Emit signal
	weapon_fired.emit(self, target_position)
	
	return true

func _perform_fire(target_position: Vector2):
	"""Perform actual firing - override in individual weapons"""
	print("BaseWeapon: Firing at ", target_position)

func stop_firing():
	"""Stop firing weapon"""
	is_firing = false
	weapon_stopped.emit(self)

func reload_weapon():
	"""Reload weapon"""
	if max_ammo > 0:
		current_ammo = max_ammo
		weapon_reloaded.emit(self)
		print("BaseWeapon: Weapon reloaded")

func _process(delta):
	"""Update fire timer"""
	if fire_timer > 0:
		fire_timer -= delta

# Override in individual weapons
func get_weapon_data() -> Dictionary:
	return {
		"id": weapon_id,
		"type": weapon_type,
		"damage": damage,
		"description": description,
		"integration": integration,
		"animation": animation,
		"weapon_system_enum": weapon_system_enum,
		"projectile_scene": projectile_scene,
		"auto_fire": auto_fire,
		"fire_rate": fire_rate,
		"max_ammo": max_ammo,
		"current_ammo": current_ammo
	}

func get_weapon_config() -> Dictionary:
	return {
		"name": weapon_id,
		"fire_rate": fire_rate,
		"damage": damage,
		"projectile_scene": projectile_scene,
		"weapon_system_enum": weapon_system_enum
	}

# Static method for easy creation
static func create_weapon(weapon_scene_path: String, spawn_position: Vector2) -> BaseWeapon:
	var weapon_scene = load(weapon_scene_path)
	if not weapon_scene:
		return null
	
	var weapon_instance = weapon_scene.instantiate()
	weapon_instance.global_position = spawn_position
	
	# Need to add to scene tree before calling get_tree()
	var current_scene = Engine.get_singleton("get_main_loop").current_scene
	if current_scene:
		current_scene.add_child(weapon_instance)
	
	return weapon_instance
