extends WeaponData
class_name BallisticBarrageWeapon

func _init():
	name = "BallisticBarrage"
	asset_path = "assets/weapons/ballisticbarrage/BallisticBarrage.png"
	type = "Science | Resources"
	integration = "Area saturation weapon system"
	damage = "Medium per projectile"
	animation = "Explosion sprite sequence"
	description = "Area saturation weapon for crowd control"
	weapon_system_enum = "WeaponType.BULLET"
	projectile_scene = "res://scenes/BulletProjectile.tscn"
	fire_rate = 0.2
	base_damage = 10
