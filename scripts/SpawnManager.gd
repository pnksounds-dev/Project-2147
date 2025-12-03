extends Node

class_name SpawnManager

## SpawnManager - Context-aware enemy spawning based on territory
## Integrates with TerritoryManager and FactionManager

var territory_manager: TerritoryManager
var faction_manager: FactionManager
var enemy_spawner: Node  # Using Node type to avoid circular dependency

# Spawn weights by territory type - adjusted for exploration focus
const DEFAULT_SPAWN_WEIGHTS = {
	FactionManager.FACTION_PLAYER: {
		"scout": 0.8,
		"drone": 0.0,
		"mimic": 0.0,
		"ark": 0.2,
		"mothership": 0.0
	},
	FactionManager.FACTION_ENEMY: {
		"scout": 0.3,
		"drone": 0.2,
		"mimic": 0.4,
		"ark": 0.0,
		"mothership": 0.1
	},
	FactionManager.FACTION_NEUTRAL: {
		"scout": 0.2,
		"drone": 0.3,
		"mimic": 0.4,
		"ark": 0.1,
		"mothership": 0.0
	},
	FactionManager.FACTION_TRADER: {
		"scout": 0.1,
		"drone": 0.0,
		"mimic": 0.0,
		"ark": 0.8,
		"mothership": 0.1
	}
}

func _ready():
	add_to_group("spawn_manager")
	
	# Wait a frame for other managers to be ready
	await get_tree().process_frame
	
	# Get system references
	territory_manager = get_tree().get_first_node_in_group("territory_manager")
	faction_manager = get_tree().get_first_node_in_group("faction_manager")
	enemy_spawner = get_tree().get_first_node_in_group("enemy_spawner")
	
	if not territory_manager:
		push_error("SpawnManager: TerritoryManager not found!")
	if not faction_manager:
		push_error("SpawnManager: FactionManager not found!")
	if not enemy_spawner:
		push_error("SpawnManager: EnemySpawner not found!")
	
	print("SpawnManager: Initialized with territory-aware spawning")

func spawn_enemy_at_position(position: Vector2, enemy_type: String = ""):
	"""Spawn an enemy at a specific position considering territory context"""
	var territory = territory_manager.get_territory_at_position(position)
	
	if territory.is_empty():
		print("SpawnManager: No territory found at position ", position)
		return
	
	var territory_faction = territory.get("faction", FactionManager.FACTION_NEUTRAL)
	var spawn_weights = territory.get("spawn_weights", DEFAULT_SPAWN_WEIGHTS.get(territory_faction, {}))
	
	# If no specific enemy type requested, choose based on territory weights
	if enemy_type.is_empty():
		enemy_type = _choose_enemy_type(spawn_weights)
	
	# Check if this enemy type can spawn in this territory
	var weight = spawn_weights.get(enemy_type, 0.0)
	if weight <= 0.0:
		print("SpawnManager: Enemy type '", enemy_type, "' not allowed in ", territory_faction, " territory")
		return
	
	# Spawn the enemy using the existing spawner
	match enemy_type:
		"drone":
			enemy_spawner.spawn_drone(position)
		"scout":
			enemy_spawner.spawn_scout(position)
		"mimic":
			enemy_spawner.spawn_mimic(position)
		"hypno_mimic":
			enemy_spawner.spawn_mimic_type("hypno", position)
		"greater_mimic":
			enemy_spawner.spawn_mimic_type("greater", position)
		"infected_mimic":
			enemy_spawner.spawn_mimic_type("infected", position)
		"void_mimic":
			enemy_spawner.spawn_mimic_type("void", position)
		"quantum_mimic":
			enemy_spawner.spawn_mimic_type("quantum", position)
		"ark":
			enemy_spawner.spawn_ark(position)
		"mothership":
			enemy_spawner.spawn_mothership(position)
		_:
			print("SpawnManager: Unknown enemy type '", enemy_type, "'")

func spawn_enemy_territory_aware(center_position: Vector2, radius: float = 1000.0):
	"""Spawn an enemy in a territory-aware manner around a position"""
	var territory = territory_manager.get_territory_at_position(center_position)
	
	if territory.is_empty():
		print("SpawnManager: No territory found for territory-aware spawn")
		return
	
	var _territory_faction = territory.get("faction", FactionManager.FACTION_NEUTRAL)
	var _threat_level = territory.get("threat_level", 1)
	
	# Adjust spawn count based on threat level - reduced for exploration
	var spawn_count = 1  # Always spawn 1 for exploration focus
	
	for i in range(spawn_count):
		# Random position within radius
		var angle = randf() * TAU
		var distance = randf() * radius
		var spawn_pos = center_position + Vector2(cos(angle), sin(angle)) * distance
		
		spawn_enemy_at_position(spawn_pos)

func _choose_enemy_type(weights: Dictionary) -> String:
	"""Choose an enemy type based on weighted probabilities"""
	var total_weight = 0.0
	for weight in weights.values():
		total_weight += weight
	
	if total_weight <= 0.0:
		return "drone"  # Default fallback
	
	var roll = randf() * total_weight
	var current_weight = 0.0
	
	for enemy_type in weights:
		current_weight += weights[enemy_type]
		if roll <= current_weight:
			return enemy_type
	
	return "drone"  # Shouldn't reach here, but fallback

func get_territory_spawn_info(position: Vector2) -> Dictionary:
	"""Get spawn information for a territory at a position"""
	var territory = territory_manager.get_territory_at_position(position)
	
	if territory.is_empty():
		return {}
	
	var territory_faction = territory.get("faction", FactionManager.FACTION_NEUTRAL)
	var spawn_weights = territory.get("spawn_weights", DEFAULT_SPAWN_WEIGHTS.get(territory_faction, {}))
	
	return {
		"territory_id": territory.get("id", "unknown"),
		"faction": territory_faction,
		"faction_name": faction_manager.get_faction_name(territory_faction),
		"faction_color": faction_manager.get_faction_color(territory_faction),
		"spawn_weights": spawn_weights,
		"threat_level": territory.get("threat_level", 1),
		"most_common_enemy": _get_most_common_enemy(spawn_weights)
	}

func _get_most_common_enemy(weights: Dictionary) -> String:
	"""Get the enemy type with the highest spawn weight"""
	var highest_weight = 0.0
	var most_common = "drone"
	
	for enemy_type in weights:
		var weight = weights[enemy_type]
		if weight > highest_weight:
			highest_weight = weight
			most_common = enemy_type
	
	return most_common
