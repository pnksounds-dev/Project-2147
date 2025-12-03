extends Node

class_name TerritoryManager

## TerritoryManager - Manages faction territories and chunk-based spawning
## Integrated with new FactionManager system

signal territory_entered(territory_id: String, faction: String)
signal territory_captured(territory_id: String, new_faction: String)

var faction_manager: FactionManager
var chunk_size: Vector2 = Vector2(1000, 1000)  # Each chunk is 1000x1000 units

# Territory data structure
var territories: Array[Dictionary] = []

func _ready() -> void:
	add_to_group("territory_manager")
	
	# Wait a frame for other managers to be ready
	await get_tree().process_frame
	
	# Get faction manager reference
	faction_manager = get_tree().get_first_node_in_group("faction_manager")
	if not faction_manager:
		push_error("TerritoryManager: FactionManager not found!")
		return
	
	_initialize_default_territories()
	
	# Connect territory_entered signal for future use
	territory_entered.connect(_on_territory_entered)

func _on_territory_entered(territory_id: String, faction: String) -> void:
	# Placeholder for future territory-based gameplay features
	# Could trigger events, quests, or UI updates when player enters new territories
	print("TerritoryManager: Player entered territory ", territory_id, " (faction ", faction, ")")

func _initialize_default_territories() -> void:
	# Clear existing territories
	territories.clear()
	
	# Player faction hub at (0,0) - large safe zone
	territories.append({
		"id": "player_hub",
		"faction": FactionManager.FACTION_PLAYER,
		"center": Vector2.ZERO,
		"radius": 3000.0,  # 3km radius safe zone
		"color": faction_manager.get_faction_color(FactionManager.FACTION_PLAYER),
		"spawn_weights": {
			"scout": 1.0    # Player faction only spawns scouts for now
		},
		"threat_level": 0
	})
	
	# Add some surrounding unclaimed territories
	var surrounding_positions = [
		Vector2(5000, 0),    # East
		Vector2(-5000, 0),   # West  
		Vector2(0, 5000),    # North
		Vector2(0, -5000),   # South
		Vector2(3500, 3500), # NE
		Vector2(-3500, 3500), # NW
		Vector2(3500, -3500), # SE
		Vector2(-3500, -3500) # SW
	]
	
	for i in range(surrounding_positions.size()):
		var pos = surrounding_positions[i]
		territories.append({
			"id": "territory_" + str(i),
			"faction": FactionManager.FACTION_NEUTRAL,
			"center": pos,
			"radius": 2000.0,  # 2km radius
			"color": faction_manager.get_faction_color(FactionManager.FACTION_NEUTRAL),
			"spawn_weights": {
				"mimic": 0.5,
				"drone": 0.3,
				"scout": 0.2
			},
			"threat_level": 1
		})
	
	print("TerritoryManager: Initialized ", territories.size(), " territories")

func get_territory_at_position(pos: Vector2) -> Dictionary:
	for territory in territories:
		var distance = pos.distance_to(territory["center"])
		if distance <= territory["radius"]:
			return territory
	return {}  # No territory found

func get_faction_at_position(pos: Vector2) -> String:
	var territory = get_territory_at_position(pos)
	if territory.is_empty():
		return FactionManager.FACTION_NEUTRAL
	return territory["faction"]

func get_chunk_coordinates(world_pos: Vector2) -> Vector2i:
	return Vector2i(
		int(world_pos.x / chunk_size.x),
		int(world_pos.y / chunk_size.y)
	)

func get_chunk_center(chunk_coords: Vector2i) -> Vector2:
	return Vector2(
		chunk_coords.x * chunk_size.x + chunk_size.x / 2,
		chunk_coords.y * chunk_size.y + chunk_size.y / 2
	)

func claim_territory(territory_id: String, new_faction: String) -> bool:
	for territory in territories:
		if territory["id"] == territory_id:
			# var old_faction = territory["faction"]  # Not used currently
			territory["faction"] = new_faction
			territory["color"] = faction_manager.get_faction_color(new_faction)
			
			# Update spawn weights based on new faction
			_update_territory_spawn_weights(territory, new_faction)
			
			territory_captured.emit(territory_id, new_faction)
			print("TerritoryManager: Territory ", territory_id, " captured by faction ", new_faction)
			return true
	return false

func _update_territory_spawn_weights(territory: Dictionary, faction: String) -> void:
	match faction:
		FactionManager.FACTION_PLAYER:
			territory["spawn_weights"] = {
				"scout": 1.0    # Player faction only spawns scouts for now
			}
			territory["threat_level"] = 0
		FactionManager.FACTION_ENEMY:
			territory["spawn_weights"] = {
				"mimic": 0.5,
				"drone": 0.3,
				"scout": 0.2
			}
			territory["threat_level"] = 2
		_:  # NEUTRAL or TRADER
			territory["spawn_weights"] = {
				"mimic": 0.4,
				"drone": 0.3,
				"scout": 0.3
			}
			territory["threat_level"] = 1

func get_spawn_weights_for_position(pos: Vector2) -> Dictionary:
	var territory = get_territory_at_position(pos)
	if territory.is_empty():
		return {"mimic": 0.4, "drone": 0.3, "scout": 0.4}
	return territory["spawn_weights"]

func get_all_territories() -> Array[Dictionary]:
	return territories.duplicate()

func get_debug_info() -> Dictionary:
	var faction_counts = {}
	# Initialize with all faction types
	faction_counts[FactionManager.FACTION_PLAYER] = 0
	faction_counts[FactionManager.FACTION_ENEMY] = 0
	faction_counts[FactionManager.FACTION_NEUTRAL] = 0
	faction_counts[FactionManager.FACTION_TRADER] = 0
	
	for territory in territories:
		var faction = territory["faction"]
		faction_counts[faction] = faction_counts.get(faction, 0) + 1
	
	return {
		"total_territories": territories.size(),
		"faction_distribution": faction_counts,
		"chunk_size": chunk_size
	}
