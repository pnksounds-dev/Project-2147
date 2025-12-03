extends Node

class_name TerritorySpawner

## TerritorySpawner - Spawns entities based on territory and chunk system
## Integrates with TerritoryManager and ChunkManager

@export var spawn_interval: float = 3.0
@export var max_entities_per_chunk: int = 5
@export var spawn_distance_from_player: float = 800.0

var _spawn_timer: float = 0.0
var _territory_manager: Node
var _chunk_manager: Node
var _player: Node2D

# Entity scenes
const ENEMY_SCENES = {
	"mimic": preload("res://scenes/HypnoMimic.tscn"),
	"drone": preload("res://scenes/Enemy.tscn"),
	"scout": preload("res://scenes/Scout.tscn")
	# "trader": preload("res://scenes/Trader.tscn")  # Not available yet
}

func _ready() -> void:
	# Get references to managers
	_territory_manager = get_tree().get_first_node_in_group("territory_manager")
	_chunk_manager = get_tree().get_first_node_in_group("chunk_manager")
	_player = get_tree().get_first_node_in_group("player")
	
	# Connect to chunk manager signals
	if _chunk_manager:
		_chunk_manager.active_chunks_updated.connect(_on_active_chunks_updated)
	
	print("TerritorySpawner: Initialized with territory and chunk systems")

func _process(delta: float) -> void:
	if not _player or not _territory_manager or not _chunk_manager:
		return
	
	_spawn_timer -= delta
	if _spawn_timer <= 0:
		_spawn_timer = spawn_interval
		_attempt_spawn_in_active_chunks()

func _on_active_chunks_updated(active_chunks: Array[Vector2i]) -> void:
	print("TerritorySpawner: Active chunks updated: ", active_chunks.size(), " chunks")

func _attempt_spawn_in_active_chunks() -> void:
	if not _chunk_manager:
		return
	
	var active_chunks = _chunk_manager.get_active_chunks()
	for chunk_coords in active_chunks:
		# Skip chunks too close to player (spawn safety zone)
		var chunk_center = _chunk_manager.get_chunk_center(chunk_coords)
		if chunk_center.distance_to(_player.global_position) < spawn_distance_from_player:
			continue
		
		# Check spawn limits for this chunk
		var entities_in_chunk = _chunk_manager.get_entities_in_chunk(chunk_coords)
		if entities_in_chunk.size() >= max_entities_per_chunk:
			continue
		
		# Get territory for this chunk
		var territory = _territory_manager.get_territory_at_position(chunk_center)
		if territory.is_empty():
			continue
		
		# Get spawn weights based on territory
		var spawn_weights = territory.get("spawn_weights", {"mimic": 0.3, "drone": 0.3, "scout": 0.4})
		
		# Attempt to spawn an entity
		if _should_spawn(spawn_weights):
			_spawn_entity_in_chunk(chunk_coords, spawn_weights)

func _should_spawn(_spawn_weights: Dictionary) -> bool:
	# Simple spawn chance based on territory threat level
	var base_chance = 0.3  # 30% base chance
	return randf() < base_chance

func _spawn_entity_in_chunk(chunk_coords: Vector2i, spawn_weights: Dictionary) -> void:
	# Choose entity type based on weights
	var entity_type = _choose_entity_type(spawn_weights)
	var scene = ENEMY_SCENES.get(entity_type)
	
	if not scene:
		push_warning("TerritorySpawner: No scene found for entity type: ", entity_type)
		return
	
	# Spawn entity at random position within chunk
	var chunk_bounds = _chunk_manager.get_chunk_bounds(chunk_coords)
	var spawn_pos = Vector2(
		randf_range(chunk_bounds.position.x, chunk_bounds.position.x + chunk_bounds.size.x),
		randf_range(chunk_bounds.position.y, chunk_bounds.position.y + chunk_bounds.size.y)
	)
	
	var entity = scene.instantiate()
	entity.global_position = spawn_pos
	
	# Configure entity based on territory faction
	var territory = _territory_manager.get_territory_at_position(spawn_pos)
	if not territory.is_empty():
		_configure_entity_for_territory(entity, territory)
	
	# Add to world
	get_parent().add_child(entity)
	
	# Track in chunk system
	_chunk_manager.add_entity_to_chunk(entity, chunk_coords)
	
	print("TerritorySpawner: Spawned ", entity_type, " in chunk ", chunk_coords)

func _choose_entity_type(spawn_weights: Dictionary) -> String:
	var total_weight = 0.0
	for weight in spawn_weights.values():
		total_weight += weight
	
	var rand_val = randf() * total_weight
	var current_weight = 0.0
	
	for entity_type in spawn_weights:
		current_weight += spawn_weights[entity_type]
		if rand_val <= current_weight:
			return entity_type
	
	return "mimic"  # Fallback

func _configure_entity_for_territory(entity: Node, territory: Dictionary) -> void:
	var faction = territory.get("faction", 0)
	
	# Configure entity based on territory faction
	match faction:
		0:  # TerritoryManager.FactionType.UNCLAIMED
			# Default enemy behavior
			pass
			
		1:  # TerritoryManager.FactionType.PLAYER_FACTION
			# Make entity friendly to player
			entity.add_to_group("player_faction")
			entity.remove_from_group("enemy")
			if entity.has_method("set_faction"):
				entity.set_faction("player")
			
		2:  # TerritoryManager.FactionType.ENEMY_FACTION
			# Entity is hostile (default behavior)
			if entity.has_method("set_faction"):
				entity.set_faction("enemy")
			
		_:  # NEUTRAL or other
			# Default enemy behavior
			pass

# Public method for manual spawning
func spawn_entity_at_position(pos: Vector2, entity_type: String = "mimic") -> Node:
	var scene = ENEMY_SCENES.get(entity_type)
	if not scene:
		return null
	
	var entity = scene.instantiate()
	entity.global_position = pos
	
	# Configure based on territory
	var territory = _territory_manager.get_territory_at_position(pos)
	if not territory.is_empty():
		_configure_entity_for_territory(entity, territory)
	
	get_parent().add_child(entity)
	
	# Track in chunk system
	var chunk_coords = _chunk_manager.get_chunk_coordinates(pos)
	_chunk_manager.add_entity_to_chunk(entity, chunk_coords)
	
	return entity
