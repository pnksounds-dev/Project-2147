extends BaseWeapon
class_name AutoTurretWeapon

@export var projectile_scene_path: String = "res://scenes/BulletProjectile.tscn"
var _projectile_packed: PackedScene

func _ready():
	super._ready()
	weapon_id = "AutoTurret"
	weapon_type = "Weapon"
	fire_rate = 5.0 # Fast firing
	damage = "8.0"
	auto_fire = true
	
	if projectile_scene_path != "":
		_projectile_packed = load(projectile_scene_path)

func _perform_fire(target_position: Vector2):
	if not _projectile_packed:
		return
		
	var projectile = _projectile_packed.instantiate()
	
	# Set position
	projectile.global_position = global_position
	
	# Calculate direction
	var direction = (target_position - projectile.global_position).normalized()
	projectile.rotation = direction.angle()
	
	# Setup projectile properties if the script supports it
	# Assuming BulletProjectile has a 'setup' or 'direction' property
	if projectile.has_method("setup"):
		projectile.setup(direction, 8.0, 10.0)
	elif "direction" in projectile:
		projectile.direction = direction
		
	# Add to scene
	get_tree().root.add_child(projectile)
