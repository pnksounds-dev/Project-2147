extends WeaponData
class_name PhaserBeamsData

func _init():
	name = "FX_PhaserBeams"
	asset_path = "assets/weapons/phaser/FX_PhaserBeams.png"
	type = "Science | Resources"
	integration = "Works with WeaponSystem.PHASER enum"
	damage = "Medium to Very High (based on weapon level)"
	animation = "4-frame sprite sheet for progressive beam effects"
	description = "Phaser beam weapons with visual progression and damage scaling"
	weapon_system_enum = "WeaponType.PHASER"
	fire_rate = 0.1
	base_damage = 15
