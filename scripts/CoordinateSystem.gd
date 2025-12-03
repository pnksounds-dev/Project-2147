extends Node

class_name CoordinateSystem

signal entered_deep_space()
signal exited_deep_space()
signal position_updated(world_position: Vector2)

# Coordinate tracking
var current_position: Vector2 = Vector2.ZERO
var is_in_deep_space: bool = false
var deep_space_threshold: float = 0.1  # Resource and faction presence threshold

# Reference systems
var seed_manager: SeedManager

func _ready():
	add_to_group("coordinate_system")
	seed_manager = get_tree().get_first_node_in_group("seed_manager")

func update_position(world_position: Vector2):
	"""Update current position and check for deep space"""
	if current_position == world_position:
		return
	
	current_position = world_position
	position_updated.emit(world_position)
	
	_check_deep_space_status()

func _check_deep_space_status():
	"""Check if current position is in deep space"""
	if not seed_manager:
		return
	
	var was_in_deep_space = is_in_deep_space
	is_in_deep_space = seed_manager.is_deep_space(current_position)
	
	# Emit signals when entering/exiting deep space
	if is_in_deep_space and not was_in_deep_space:
		entered_deep_space.emit()
	elif not is_in_deep_space and was_in_deep_space:
		exited_deep_space.emit()

func get_world_info() -> Dictionary:
	"""Get comprehensive world information for current position"""
	if not seed_manager:
		return {}
	
	return seed_manager.get_world_info(current_position)

func get_distance_to_trader_hub() -> float:
	"""Get distance to trader hub at (0,0)"""
	return current_position.length()

func get_direction_to_trader_hub() -> Vector2:
	"""Get normalized direction to trader hub"""
	if current_position == Vector2.ZERO:
		return Vector2.ZERO
	return -current_position.normalized()

func is_in_trader_hub_area(hub_radius: float) -> bool:
	"""Check if player is within trader hub area"""
	return get_distance_to_trader_hub() <= hub_radius
