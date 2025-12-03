extends Node

class_name SeedManager

signal seed_changed(new_seed: int)
signal world_generated()

# Current world seed
var current_seed: int = 0
var is_generated: bool = false

# World generation parameters
var trader_hub_position: Vector2 = Vector2.ZERO
var player_spawn_offset: Vector2 = Vector2(50000, -200000)  # Default offset from hub

# Noise generators for deterministic generation
var biome_noise: FastNoiseLite
var resource_noise: FastNoiseLite
var faction_noise: FastNoiseLite

func _ready():
	add_to_group("seed_manager")
	_initialize_noise_generators()
	# Generate initial world with default seed
	_generate_world()

func _initialize_noise_generators():
	"""Initialize all noise generators for consistent world generation"""
	biome_noise = FastNoiseLite.new()
	resource_noise = FastNoiseLite.new()
	faction_noise = FastNoiseLite.new()
	
	# Configure noise parameters
	biome_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	biome_noise.frequency = 0.001
	biome_noise.seed = current_seed
	
	resource_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	resource_noise.frequency = 0.005
	resource_noise.seed = current_seed + 1000
	
	faction_noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	faction_noise.frequency = 0.0008
	faction_noise.seed = current_seed + 2000

func set_seed(new_seed: int):
	"""Set a new world seed and regenerate world"""
	if current_seed == new_seed:
		return
	
	current_seed = new_seed
	_update_noise_seeds()
	_generate_world()
	seed_changed.emit(new_seed)

func generate_random_seed():
	"""Generate a new random seed"""
	var random_seed = randi()
	set_seed(random_seed)
	return random_seed

func _update_noise_seeds():
	"""Update all noise generators with current seed"""
	biome_noise.seed = current_seed
	resource_noise.seed = current_seed + 1000
	faction_noise.seed = current_seed + 2000

func _generate_world():
	"""Generate world based on current seed"""
	# Trader hub is always at (0,0)
	trader_hub_position = Vector2.ZERO
	
	# Player spawn is determined by seed-based offset
	var spawn_variation = _get_seed_vector(current_seed, 12345)
	player_spawn_offset = Vector2(50000, -200000) + spawn_variation * 1000
	
	is_generated = true
	world_generated.emit()

func _get_seed_vector(seed_value: int, offset: int) -> Vector2:
	"""Generate consistent 2D vector from seed"""
	var x_seed = seed_value + offset
	var y_seed = seed_value + offset * 2
	
	# Simple hash function for consistent results
	var x = (x_seed * 1103515245 + 12345) & 0x7fffffff
	var y = (y_seed * 1103515245 + 12345) & 0x7fffffff
	
	# Normalize to -1 to 1 range
	var x_norm = (float(x) / 2147483647.0) * 2.0 - 1.0
	var y_norm = (float(y) / 2147483647.0) * 2.0 - 1.0
	
	return Vector2(x_norm, y_norm)

func get_biome_type(world_position: Vector2) -> int:
	"""Get biome type at given world position"""
	var noise_value = biome_noise.get_noise_2d(world_position.x, world_position.y)
	
	# Map noise value to biome types
	if noise_value < -0.5:
		return 0  # Ice biome
	elif noise_value < -0.2:
		return 1  # Desert biome
	elif noise_value < 0.2:
		return 2  # Forest biome
	elif noise_value < 0.5:
		return 3  # Ocean biome
	else:
		return 4  # Volcanic biome

func get_resource_density(world_position: Vector2) -> float:
	"""Get resource density at given world position (0.0 to 1.0)"""
	var noise_value = resource_noise.get_noise_2d(world_position.x, world_position.y)
	return (noise_value + 1.0) / 2.0  # Convert from -1,1 to 0,1

func get_faction_presence(world_position: Vector2) -> float:
	"""Get faction presence strength at given world position (0.0 to 1.0)"""
	var noise_value = faction_noise.get_noise_2d(world_position.x, world_position.y)
	return (noise_value + 1.0) / 2.0  # Convert from -1,1 to 0,1

func get_player_spawn_position() -> Vector2:
	"""Get the player's spawn position for the current seed"""
	return trader_hub_position + player_spawn_offset

func get_trader_hub_position() -> Vector2:
	"""Get the trader hub position (always 0,0)"""
	return trader_hub_position

func is_deep_space(world_position: Vector2) -> bool:
	"""Check if position is in deep space (no significant features nearby)"""
	var resource_density = get_resource_density(world_position)
	var faction_presence = get_faction_presence(world_position)
	
	# Deep space if both resources and faction presence are very low
	return resource_density < 0.1 and faction_presence < 0.1

func get_world_info(world_position: Vector2) -> Dictionary:
	"""Get comprehensive world information for a position"""
	return {
		"seed": current_seed,
		"position": world_position,
		"biome_type": get_biome_type(world_position),
		"resource_density": get_resource_density(world_position),
		"faction_presence": get_faction_presence(world_position),
		"is_deep_space": is_deep_space(world_position),
		"distance_to_hub": world_position.distance_to(trader_hub_position),
		"distance_to_spawn": world_position.distance_to(get_player_spawn_position()),
		"mimic_probability": get_mimic_probability()
	}

func get_mimic_probability() -> float:
	"""Get mimic probability for current seed (0.0 to 1.0)"""
	# Use hash function to convert seed to 0.0-1.0 range
	var hash = abs(current_seed * 1103515245 + 12345) % 2147483647
	return float(hash) / 2147483647.0

func save_seed_data() -> Dictionary:
	"""Save seed data for persistence"""
	return {
		"seed": current_seed,
		"is_generated": is_generated
	}

func load_seed_data(data: Dictionary):
	"""Load seed data from save"""
	if data.has("seed"):
		set_seed(data.seed)
	elif data.has("is_generated") and data.is_generated:
		_generate_world()
