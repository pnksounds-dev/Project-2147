extends Node

class_name ChunkManager

## ChunkManager - Manages world chunks and active area around player
## Based on the old project's chunk system

signal chunk_entered(chunk_coords: Vector2i)
signal active_chunks_updated(active_chunks: Array[Vector2i])

const CHUNK_SIZE := Vector2(1000, 1000)  # Each chunk is 1000x1000 units
const ACTIVE_CHUNK_RADIUS := 10  # Load chunks within 10 chunks of player

var player_chunk: Vector2i = Vector2i.ZERO
var active_chunks: Array[Vector2i] = []
var chunk_entities: Dictionary = {}  # chunk_id -> Array of entities

func _ready() -> void:
	add_to_group("chunk_manager")
	# Auto-start processing
	set_process(true)

func _process(_delta: float) -> void:
	_update_player_chunk()

func _update_player_chunk() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	
	var new_chunk = get_chunk_coordinates(player.global_position)
	if new_chunk != player_chunk:
		player_chunk = new_chunk
		_update_active_chunks()
		chunk_entered.emit(player_chunk)

func _update_active_chunks() -> void:
	var new_active_chunks: Array[Vector2i] = []
	
	# Generate all chunks within active radius
	for x in range(-ACTIVE_CHUNK_RADIUS, ACTIVE_CHUNK_RADIUS + 1):
		for y in range(-ACTIVE_CHUNK_RADIUS, ACTIVE_CHUNK_RADIUS + 1):
			var chunk_coords = player_chunk + Vector2i(x, y)
			var distance = chunk_coords.distance_to(player_chunk)
			if distance <= ACTIVE_CHUNK_RADIUS:
				new_active_chunks.append(chunk_coords)
	
	# Check if active chunks changed
	if not _chunks_equal(active_chunks, new_active_chunks):
		active_chunks = new_active_chunks
		active_chunks_updated.emit(active_chunks)
		
		print("ChunkManager: Active chunks updated: ", active_chunks.size(), " chunks")

func _chunks_equal(chunks1: Array[Vector2i], chunks2: Array[Vector2i]) -> bool:
	if chunks1.size() != chunks2.size():
		return false
	
	for chunk in chunks1:
		if not chunks2.has(chunk):
			return false
	
	return true

func get_chunk_coordinates(world_pos: Vector2) -> Vector2i:
	return Vector2i(
		int(world_pos.x / CHUNK_SIZE.x),
		int(world_pos.y / CHUNK_SIZE.y)
	)

func chunk_to_world(chunk_coords: Vector2i) -> Vector2:
	return Vector2(
		chunk_coords.x * CHUNK_SIZE.x,
		chunk_coords.y * CHUNK_SIZE.y
	)

func get_chunk_center(chunk_coords: Vector2i) -> Vector2:
	var world_pos = chunk_to_world(chunk_coords)
	return Vector2(
		world_pos.x + CHUNK_SIZE.x / 2,
		world_pos.y + CHUNK_SIZE.y / 2
	)

func get_chunk_id(chunk_coords: Vector2i) -> String:
	return "%d_%d" % [chunk_coords.x, chunk_coords.y]

func get_chunk_bounds(chunk_coords: Vector2i) -> Rect2:
	var world_pos = chunk_to_world(chunk_coords)
	return Rect2(world_pos, CHUNK_SIZE)

func is_chunk_active(chunk_coords: Vector2i) -> bool:
	return active_chunks.has(chunk_coords)

func get_active_chunks() -> Array[Vector2i]:
	return active_chunks.duplicate()

func add_entity_to_chunk(entity: Node, chunk_coords: Vector2i) -> void:
	var chunk_id = get_chunk_id(chunk_coords)
	if not chunk_entities.has(chunk_id):
		chunk_entities[chunk_id] = []
	
	if not chunk_entities[chunk_id].has(entity):
		chunk_entities[chunk_id].append(entity)

func remove_entity_from_chunk(entity: Node, chunk_coords: Vector2i) -> void:
	var chunk_id = get_chunk_id(chunk_coords)
	if chunk_entities.has(chunk_id):
		chunk_entities[chunk_id].erase(entity)
		if chunk_entities[chunk_id].is_empty():
			chunk_entities.erase(chunk_id)

func get_entities_in_chunk(chunk_coords: Vector2i) -> Array:
	var chunk_id = get_chunk_id(chunk_coords)
	return chunk_entities.get(chunk_id, [])

func get_chunk_for_entity(entity: Node) -> Vector2i:
	if not entity:
		return Vector2i.ZERO
	return get_chunk_coordinates(entity.global_position)

func cleanup_invalid_entities() -> void:
	for chunk_id in chunk_entities.keys():
		var valid_entities = []
		for entity in chunk_entities[chunk_id]:
			if is_instance_valid(entity):
				valid_entities.append(entity)
		chunk_entities[chunk_id] = valid_entities

func get_debug_info() -> Dictionary:
	return {
		"player_chunk": player_chunk,
		"active_chunk_count": active_chunks.size(),
		"total_chunks_with_entities": chunk_entities.size(),
		"chunk_size": CHUNK_SIZE,
		"active_radius": ACTIVE_CHUNK_RADIUS
	}
