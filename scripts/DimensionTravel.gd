extends Node

class_name DimensionTravel

signal seed_changed(old_seed: int, new_seed: int)
signal dimension_entered(world_type: String)

# Dimension types based on seed
enum WorldType {
	NORMAL,         # 0% mimics - solar systems
	LIGHTLY_INFESTED,  # 25% mimics
	HEAVILY_INFESTED,  # 50% mimics
	MIMIC_DOMINATION,  # 75% mimics
	MIMIC_APOCALYPSE   # 100% mimics
}

# Current dimension state
var current_seed: int = 0
var current_world_type: WorldType = WorldType.NORMAL
var mimic_probability: float = 0.0

# Travel mechanics
var teleport_cooldown: float = 5.0
var last_teleport_time: float = 0.0
var can_teleport: bool = true

# Reference systems
var seed_manager: SeedManager
var coordinate_system: CoordinateSystem
var notification_system: Node

func _ready():
	add_to_group("dimension_travel")
	seed_manager = get_tree().get_first_node_in_group("seed_manager")
	coordinate_system = get_tree().get_first_node_in_group("coordinate_system")
	notification_system = get_tree().get_first_node_in_group("hud")
	
	# Initialize current dimension
	if seed_manager:
		current_seed = seed_manager.current_seed
		_update_dimension_state()

func _process(delta):
	# Update teleport cooldown
	if not can_teleport:
		last_teleport_time += delta
		if last_teleport_time >= teleport_cooldown:
			can_teleport = true
			last_teleport_time = 0.0

func _update_dimension_state():
	"""Update world type and mimic probability based on seed"""
	if not seed_manager:
		return
	
	current_seed = seed_manager.current_seed
	
	# Calculate mimic probability from seed (0.0 to 1.0)
	mimic_probability = _calculate_mimic_probability(current_seed)
	
	# Determine world type
	current_world_type = _determine_world_type(mimic_probability)
	
	# Notify systems
	dimension_entered.emit(_get_world_type_name())
	_show_dimension_info()

func _calculate_mimic_probability(seed_value: int) -> float:
	"""Calculate mimic probability from seed value"""
	# Use hash function to convert seed to 0.0-1.0 range
	var hash = abs(seed_value * 1103515245 + 12345) % 2147483647
	return float(hash) / 2147483647.0

func _determine_world_type(probability: float) -> WorldType:
	"""Determine world type from mimic probability"""
	if probability < 0.2:
		return WorldType.NORMAL
	elif probability < 0.4:
		return WorldType.LIGHTLY_INFESTED
	elif probability < 0.6:
		return WorldType.HEAVILY_INFESTED
	elif probability < 0.8:
		return WorldType.MIMIC_DOMINATION
	else:
		return WorldType.MIMIC_APOCALYPSE

func _get_world_type_name() -> String:
	"""Get human-readable world type name"""
	match current_world_type:
		WorldType.NORMAL:
			return "Normal Solar System"
		WorldType.LIGHTLY_INFESTED:
			return "Lightly Infested"
		WorldType.HEAVILY_INFESTED:
			return "Heavily Infested"
		WorldType.MIMIC_DOMINATION:
			return "Mimic Domination"
		WorldType.MIMIC_APOCALYPSE:
			return "Mimic Apocalypse"
		_:
			return "Unknown Dimension"

func teleport_to_random_dimension():
	"""Teleport to random dimension (wormhole-style)"""
	if not can_teleport:
		_show_notification("Teleport cooldown: %.1fs" % (teleport_cooldown - last_teleport_time))
		return
	
	if not seed_manager:
		_show_notification("SeedManager not found")
		return
	
	var old_seed = current_seed
	
	# Generate random seed offset
	var seed_offset = randi_range(-100000, 100000)
	var new_seed = current_seed + seed_offset
	
	# Change seed
	seed_manager.set_seed(new_seed)
	_update_dimension_state()
	
	# Move player to new spawn position
	_move_player_to_new_spawn()
	
	# Set cooldown
	can_teleport = false
	
	# Notify
	seed_changed.emit(old_seed, new_seed)
	_show_notification("Traveled through wormhole to new dimension!")
	_show_teleport_info(old_seed, new_seed)

func warp_to_specific_seed(target_seed: int):
	"""Warp to specific seed (warp drive-style)"""
	if not can_teleport:
		_show_notification("Warp drive recharging...")
		return
	
	if not seed_manager:
		_show_notification("SeedManager not found")
		return
	
	var old_seed = current_seed
	
	# Change seed
	seed_manager.set_seed(target_seed)
	_update_dimension_state()
	
	# Move player to new spawn position
	_move_player_to_new_spawn()
	
	# Set cooldown
	can_teleport = false
	
	# Notify
	seed_changed.emit(old_seed, target_seed)
	_show_notification("Warp drive engaged! Dimension shifted.")
	_show_teleport_info(old_seed, target_seed)

func _move_player_to_new_spawn():
	"""Move player to spawn position of new dimension"""
	if not seed_manager:
		return
	
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	
	var spawn_position = seed_manager.get_player_spawn_position()
	player.global_position = spawn_position
	
	# Update coordinate system
	if coordinate_system:
		coordinate_system.update_position(spawn_position)

func _show_dimension_info():
	"""Show information about current dimension"""
	var info = "Dimension: %s\n" % _get_world_type_name()
	info += "Mimic Probability: %.1f%%\n" % (mimic_probability * 100)
	info += "Seed: %d" % current_seed
	
	_show_notification(info, 5.0)

func _show_teleport_info(old_seed: int, new_seed: int):
	"""Show detailed teleport information"""
	var old_type = _get_world_type_name_for_seed(old_seed)
	var new_type = _get_world_type_name_for_seed(new_seed)
	
	var info = "Dimension Shift Complete!\n"
	info += "From: %s (Seed %d)\n" % [old_type, old_seed]
	info += "To: %s (Seed %d)" % [new_type, new_seed]
	
	_show_notification(info, 4.0)

func _get_world_type_name_for_seed(seed_value: int) -> String:
	"""Get world type name for specific seed"""
	var prob = _calculate_mimic_probability(seed_value)
	var type = _determine_world_type(prob)
	
	match type:
		WorldType.NORMAL:
			return "Normal"
		WorldType.LIGHTLY_INFESTED:
			return "Lightly Infested"
		WorldType.HEAVILY_INFESTED:
			return "Heavily Infested"
		WorldType.MIMIC_DOMINATION:
			return "Mimic Domination"
		WorldType.MIMIC_APOCALYPSE:
			return "Mimic Apocalypse"
		_:
			return "Unknown"

func _show_notification(message: String, duration: float = 3.0):
	"""Show notification through notification system"""
	if notification_system:
		if notification_system.has_method("show_notification"):
			notification_system.show_notification(message, duration)
		else:
			print("Dimension Travel: ", message)
	else:
		print("Dimension Travel: ", message)

func get_dimension_info() -> Dictionary:
	"""Get comprehensive dimension information"""
	return {
		"seed": current_seed,
		"world_type": current_world_type,
		"world_type_name": _get_world_type_name(),
		"mimic_probability": mimic_probability,
		"can_teleport": can_teleport,
		"teleport_cooldown_remaining": teleport_cooldown - last_teleport_time if not can_teleport else 0.0
	}
