extends Node

signal skill_points_changed(amount: int)
signal skill_upgraded(skill_name: String, new_level: int)
signal skill_reset()

var skill_points: int = 0
var total_skill_points_earned: int = 0
var skill_levels: Dictionary = {}

# Skill costs and effects
const BASE_SKILL_COST = 1
const MAX_SKILL_LEVEL = 10

# Skill definitions
var skills = {
	"weapon_damage": {
		"name": "Weapon Damage",
		"description": "Increases all weapon damage by 10% per level",
		"current_level": 0,
		"max_level": MAX_SKILL_LEVEL,
		"cost_per_level": 1,
		"effect_per_level": 0.1  # 10% increase
	},
	"health_boost": {
		"name": "Health Boost",
		"description": "Increases max health by 20 per level",
		"current_level": 0,
		"max_level": MAX_SKILL_LEVEL,
		"cost_per_level": 1,
		"effect_per_level": 20
	},
	"speed_boost": {
		"name": "Speed Boost",
		"description": "Increases movement speed by 5% per level",
		"current_level": 0,
		"max_level": MAX_SKILL_LEVEL,
		"cost_per_level": 1,
		"effect_per_level": 0.05  # 5% increase
	},
	"fire_rate_boost": {
		"name": "Fire Rate Boost",
		"description": "Increases fire rate by 8% per level",
		"current_level": 0,
		"max_level": MAX_SKILL_LEVEL,
		"cost_per_level": 1,
		"effect_per_level": 0.08  # 8% increase
	},
	"coin_magnet": {
		"name": "Coin Magnet",
		"description": "Increases coin pickup range by 20 pixels per level",
		"current_level": 0,
		"max_level": MAX_SKILL_LEVEL,
		"cost_per_level": 1,
		"effect_per_level": 20
	}
}

func _ready():
	add_to_group("skill_system")
	_initialize_skills()
	_load_skill_data()
	print("SkillSystem: Initialized with ", skill_points, " skill points")

func _initialize_skills():
	for skill_id in skills:
		skill_levels[skill_id] = 0
		skills[skill_id].current_level = 0

func add_skill_points(amount: int):
	if amount <= 0:
		return
	
	skill_points += amount
	total_skill_points_earned += amount
	skill_points_changed.emit(skill_points)
	_save_skill_data()
	
	print("SkillSystem: Added ", amount, " skill points (total: ", skill_points, ")")

func award_level_up_points():
	add_skill_points(1)  # Award 1 skill point per level up

func spend_skill_points(amount: int) -> bool:
	if skill_points >= amount:
		skill_points -= amount
		skill_points_changed.emit(skill_points)
		_save_skill_data()
		return true
	return false

func upgrade_skill(skill_id: String) -> bool:
	if not skills.has(skill_id):
		print("SkillSystem: Unknown skill: ", skill_id)
		return false
	
	var skill = skills[skill_id]
	var current_level = skill.current_level
	
	if current_level >= skill.max_level:
		print("SkillSystem: Skill ", skill_id, " already at max level")
		return false
	
	var cost = get_skill_upgrade_cost(skill_id)
	if not spend_skill_points(cost):
		print("SkillSystem: Insufficient skill points for ", skill_id)
		return false
	
	# Upgrade the skill
	skill.current_level += 1
	skill_levels[skill_id] = skill.current_level
	
	skill_upgraded.emit(skill_id, skill.current_level)
	_apply_skill_effects(skill_id)
	_save_skill_data()
	
	print("SkillSystem: Upgraded ", skill_id, " to level ", skill.current_level)
	return true

func get_skill_upgrade_cost(skill_id: String) -> int:
	if not skills.has(skill_id):
		return -1
	
	var skill = skills[skill_id]
	# Cost increases with level (1 point per level for now, can be made more complex)
	return skill.cost_per_level

func can_afford_skill_upgrade(skill_id: String) -> bool:
	var cost = get_skill_upgrade_cost(skill_id)
	return skill_points >= cost and cost > 0

func get_skill_level(skill_id: String) -> int:
	if skills.has(skill_id):
		return skills[skill_id].current_level
	return 0

func get_skill_effect(skill_id: String) -> float:
	if not skills.has(skill_id):
		return 0.0
	
	var skill = skills[skill_id]
	var level = skill.current_level
	return level * skill.effect_per_level

func get_all_skills() -> Dictionary:
	return skills.duplicate()

func get_skill_points() -> int:
	return skill_points

func get_total_skill_points_earned() -> int:
	return total_skill_points_earned

func reset_skills():
	# Refund all spent skill points
	var total_spent = 0
	for skill_id in skills:
		total_spent += skills[skill_id].current_level * skills[skill_id].cost_per_level
		skills[skill_id].current_level = 0
		skill_levels[skill_id] = 0
	
	skill_points += total_spent
	skill_points_changed.emit(skill_points)
	skill_reset.emit()
	_save_skill_data()
	
	print("SkillSystem: Reset all skills, refunded ", total_spent, " points")

func _apply_skill_effects(skill_id: String):
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	
	match skill_id:
		"weapon_damage":
			# Apply weapon damage boost
			var damage_boost = get_skill_effect(skill_id)
			# This would need to be integrated with weapon system
			print("Applying weapon damage boost: ", damage_boost)
		"health_boost":
			# Apply health boost
			var health_boost = int(get_skill_effect(skill_id))
			if player.has_method("increase_max_health"):
				player.increase_max_health(health_boost)
			print("Applying health boost: ", health_boost)
		"speed_boost":
			# Apply speed boost
			var speed_boost = get_skill_effect(skill_id)
			if "speed" in player:
				player.speed *= (1.0 + speed_boost)
			print("Applying speed boost: ", speed_boost)
		"fire_rate_boost":
			# Apply fire rate boost
			var fire_rate_boost = get_skill_effect(skill_id)
			if "fire_rate" in player:
				player.fire_rate *= (1.0 - fire_rate_boost)  # Reduce fire rate for faster shooting
			print("Applying fire rate boost: ", fire_rate_boost)
		"coin_magnet":
			# Apply coin magnet effect
			var magnet_range = get_skill_effect(skill_id)
			# This would need to be integrated with coin pickup system
			print("Applying coin magnet range: ", magnet_range)

func _load_skill_data():
	# Load skill data from save file
	var file = FileAccess.open("user://skills.save", FileAccess.READ)
	if file:
		skill_points = file.get_32()
		total_skill_points_earned = file.get_32()
		
		# Load skill levels
		var skill_count = file.get_32()
		for i in range(skill_count):
			var skill_id = file.get_pascal_string()
			var level = file.get_32()
			if skills.has(skill_id):
				skills[skill_id].current_level = level
				skill_levels[skill_id] = level
		
		file.close()

func _save_skill_data():
	# Save skill data to file
	var file = FileAccess.open("user://skills.save", FileAccess.WRITE)
	if file:
		file.store_32(skill_points)
		file.store_32(total_skill_points_earned)
		
		# Save skill levels
		file.store_32(skills.size())
		for skill_id in skills:
			file.store_pascal_string(skill_id)
			file.store_32(skills[skill_id].current_level)
		
		file.close()

func get_skill_summary() -> Dictionary:
	var summary = {
		"total_points": total_skill_points_earned,
		"available_points": skill_points,
		"spent_points": total_skill_points_earned - skill_points,
		"upgraded_skills": 0,
		"maxed_skills": 0
	}
	
	for skill_id in skills:
		if skills[skill_id].current_level > 0:
			summary.upgraded_skills += 1
		if skills[skill_id].current_level >= skills[skill_id].max_level:
			summary.maxed_skills += 1
	
	return summary
