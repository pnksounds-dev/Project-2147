extends WeaponData
class_name VoidMagicWeapon

func _init():
	name = "VoidMagic"
	asset_path = "assets/weapons/voidmagic/VoidMagic.png"
	type = "Magic | Mana"
	integration = "Ultimate magic weapon system"
	damage = "Very High"
	animation = "Single frame with particle effects"
	description = "Ultimate magic weapon for boss encounters"
	weapon_system_enum = "WeaponType.MAGIC"
	projectile_scene = ""
	fire_rate = 0.5
	base_damage = 50
