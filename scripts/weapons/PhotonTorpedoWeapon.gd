extends WeaponData
class_name PhotonTorpedoWeapon

func _init():
	name = "PhotonTorpedo"
	asset_path = "assets/weapons/photontorpedo/PhotonTorpedo.png"
	type = "Science | Resources"
	integration = "Long-range torpedo launcher"
	damage = "High impact with small splash"
	animation = "Torpedo trail with impact flash"
	description = "Long-range, high-damage torpedo that pierces light armor"
	weapon_system_enum = "WeaponType.BULLET"
	projectile_scene = "res://scenes/BulletProjectile.tscn"
	fire_rate = 1.2
	base_damage = 40
