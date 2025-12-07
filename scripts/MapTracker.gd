extends Node

class_name MapTracker

# Tracks all entities (enemies, orbs, etc.) in the world for map/radar display
# Provides queries for nearby entities and maintains a spatial index

signal entity_added(entity: Node2D, type: String)
signal entity_removed(entity: Node2D, type: String)

@export var tracking_radius: float = 10000.0  # How far to track from player
@export var update_interval: float = 0.2  # Update frequency

var _tracked_entities: Dictionary = {}  # entity -> {type, last_pos, color}
var _update_timer: float = 0.0
var _player: Node2D = null

func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")
	add_to_group("map_tracker")

func _process(delta: float) -> void:
	_update_timer -= delta
	if _update_timer <= 0:
		_update_tracked_entities()
		_update_timer = update_interval

func _update_tracked_entities() -> void:
	if not _player or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		return
	
	# 1. Mark all currently tracked entities as "not seen"
	var seen_ids = {}
	
	# 2. Scan for Enemies
	var enemies := get_tree().get_nodes_in_group("enemy")
	var count = 0
	for enemy in enemies:
		if not is_instance_valid(enemy): continue
		
		count += 1
		if count > 500: break
		
		var dist_sq = _player.global_position.distance_squared_to(enemy.global_position)
		if dist_sq < tracking_radius * tracking_radius:
			_add_or_update_entity(enemy, "enemy", Color.RED)
			seen_ids[enemy.get_instance_id()] = true
	
	# 3. Scan for Orbs
	var orbs := get_tree().get_nodes_in_group("experience_orb")
	count = 0
	for orb in orbs:
		if not is_instance_valid(orb): continue
		
		count += 1
		if count > 200: break # Lower limit for orbs
		
		var dist_sq = _player.global_position.distance_squared_to(orb.global_position)
		if dist_sq < tracking_radius * tracking_radius:
			_add_or_update_entity(orb, "orb", Color.YELLOW)
			seen_ids[orb.get_instance_id()] = true

	# 4. Scan for Friendly Units (Player Faction)
	var friendlies := get_tree().get_nodes_in_group("player_faction")
	count = 0
	for friendly in friendlies:
		if not is_instance_valid(friendly): continue
		if friendly == _player: continue # Don't track player as a separate entity
		
		count += 1
		if count > 200: break
		
		var dist_sq = _player.global_position.distance_squared_to(friendly.global_position)
		if dist_sq < tracking_radius * tracking_radius:
			# Check if it's an Ark
			if friendly.is_in_group("ark_ships"):
				_add_or_update_entity(friendly, "ark", Color.CYAN)
			else:
				_add_or_update_entity(friendly, "friendly", Color.CYAN)
			seen_ids[friendly.get_instance_id()] = true

	# 4. Prune entities that are no longer seen or invalid
	var ids_to_remove = []
	for id in _tracked_entities:
		if id not in seen_ids:
			ids_to_remove.append(id)
	
	for id in ids_to_remove:
		_remove_entity_by_id(id)

func _add_or_update_entity(entity: Node2D, type: String, color: Color) -> void:
	var id = entity.get_instance_id()
	if id not in _tracked_entities:
		var texture = null
		var rotation = entity.rotation
		var visual_scale = entity.global_scale
		
		# Try to find a sprite to get texture from
		if entity.has_node("Sprite2D"):
			var sprite: Sprite2D = entity.get_node("Sprite2D")
			texture = sprite.texture
			visual_scale = sprite.global_scale # Capture the visual scale of the sprite
			# For Ark ships, the visual rotation is on the Sprite2D, not the root node.
			# Use the sprite's global rotation so the minimap icon matches.
			if entity.is_in_group("ark_ships"):
				rotation = sprite.global_rotation
		elif entity is Sprite2D:
			texture = entity.texture
			visual_scale = entity.global_scale
			
		_tracked_entities[id] = {
			"type": type,
			"color": color,
			"last_pos": entity.global_position,
			"node": entity,
			"texture": texture,
			"rotation": rotation,
			"visual_scale": visual_scale
		}
		entity_added.emit(entity, type)
	else:
		_tracked_entities[id]["last_pos"] = entity.global_position
		
		var updated_rotation = entity.rotation
		var updated_scale = entity.global_scale
		
		if entity.has_node("Sprite2D"):
			var sprite: Sprite2D = entity.get_node("Sprite2D")
			updated_scale = sprite.global_scale
			if entity.is_in_group("ark_ships"):
				updated_rotation = sprite.global_rotation
				
		_tracked_entities[id]["rotation"] = updated_rotation
		_tracked_entities[id]["visual_scale"] = updated_scale

func _remove_entity_by_id(id: int) -> void:
	if id in _tracked_entities:
		var data = _tracked_entities[id]
		var entity = data["node"]
		var type = data["type"]
		
		_tracked_entities.erase(id)
		
		# Emit signal when entity is removed from tracking
		# Only emit if entity is still valid (might have been freed)
		if is_instance_valid(entity):
			entity_removed.emit(entity, type)

func get_nearby_entities(type: String = "") -> Array:
	"""Get all tracked entities, optionally filtered by type"""
	var result = []
	# Use keys() to iterate safely
	var keys = _tracked_entities.keys()
	for id in keys:
		var data = _tracked_entities[id]
		var node = data["node"]
		
		# CRITICAL: Check validity before accessing properties
		if is_instance_valid(node):
			if type == "" or data["type"] == type:
				# Return the tracked data dictionary directly so consumers
				# (like RadarHUD) can access last_pos, color, texture, rotation, etc.
				result.append(data)
		else:
			# Lazy cleanup if we encounter invalid nodes during read
			_remove_entity_by_id(id)
			
	return result

func get_entity_info(entity: Node2D) -> Dictionary:
	if not is_instance_valid(entity): return {}
	var id = entity.get_instance_id()
	if id in _tracked_entities:
		return _tracked_entities[id]
	return {}

func clear_tracking() -> void:
	_tracked_entities.clear()
