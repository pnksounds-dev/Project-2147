extends Node

# Debug script for testing SeedManager functionality

func _ready():
	add_to_group("seed_debugger")
	_test_seed_manager()

func _test_seed_manager():
	"""Test SeedManager functionality"""
	print("=== SeedManager Debug Test ===")
	
	var seed_manager = get_tree().get_first_node_in_group("seed_manager")
	if not seed_manager:
		print("ERROR: SeedManager not found!")
		return
	
	# Test 1: Default seed
	print("Test 1: Default seed")
	print("Current seed: ", seed_manager.current_seed)
	print("Player spawn: ", seed_manager.get_player_spawn_position())
	print("Trader hub: ", seed_manager.get_trader_hub_position())
	
	# Test 2: Set specific seed
	print("\nTest 2: Setting seed to 12345")
	seed_manager.set_seed(12345)
	print("Current seed: ", seed_manager.current_seed)
	print("Player spawn: ", seed_manager.get_player_spawn_position())
	print("Distance to hub: ", seed_manager.get_player_spawn_position().distance_to(seed_manager.get_trader_hub_position()))
	
	# Test 3: Biome generation
	print("\nTest 3: Biome generation at player spawn")
	var spawn_pos = seed_manager.get_player_spawn_position()
	var biome_type = seed_manager.get_biome_type(spawn_pos)
	var resource_density = seed_manager.get_resource_density(spawn_pos)
	var faction_presence = seed_manager.get_faction_presence(spawn_pos)
	print("Biome type: ", biome_type)
	print("Resource density: ", resource_density)
	print("Faction presence: ", faction_presence)
	print("Is deep space: ", seed_manager.is_deep_space(spawn_pos))
	
	# Test 4: Consistency test
	print("\nTest 4: Consistency test - same seed should give same results")
	seed_manager.set_seed(54321)
	var first_spawn = seed_manager.get_player_spawn_position()
	var first_biome = seed_manager.get_biome_type(first_spawn)
	
	seed_manager.set_seed(54321)  # Same seed again
	var second_spawn = seed_manager.get_player_spawn_position()
	var second_biome = seed_manager.get_biome_type(second_spawn)
	
	print("First spawn: ", first_spawn)
	print("Second spawn: ", second_spawn)
	print("Spawns match: ", first_spawn.is_equal_approx(second_spawn))
	print("First biome: ", first_biome)
	print("Second biome: ", second_biome)
	print("Biomes match: ", first_biome == second_biome)
	
	# Test 5: Random seed generation
	print("\nTest 5: Random seed generation")
	var random_seed1 = seed_manager.generate_random_seed()
	var random_seed2 = seed_manager.generate_random_seed()
	print("Random seed 1: ", random_seed1)
	print("Random seed 2: ", random_seed2)
	print("Seeds are different: ", random_seed1 != random_seed2)
	
	print("\n=== SeedManager Debug Test Complete ===")

func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F2:  # Changed from F1 to F2 to avoid conflict with debug menu
			_test_seed_manager()
		elif event.keycode == KEY_F3:
			_test_world_info()
		elif event.keycode == KEY_F4:
			_generate_new_random_seed()
		elif event.keycode == KEY_F5:
			_test_dimension_travel()

func _test_world_info():
	"""Test world info at current player position"""
	var player = get_tree().get_first_node_in_group("player")
	var seed_manager = get_tree().get_first_node_in_group("seed_manager")
	
	if not player or not seed_manager:
		print("ERROR: Player or SeedManager not found!")
		return
	
	var world_info = seed_manager.get_world_info(player.global_position)
	print("=== World Info at Player Position ===")
	for key in world_info:
		print(key, ": ", world_info[key])
	print("========================================")

func _generate_new_random_seed():
	"""Generate a new random seed and move player"""
	var seed_manager = get_tree().get_first_node_in_group("seed_manager")
	var player = get_tree().get_first_node_in_group("player")
	
	if not seed_manager or not player:
		print("ERROR: SeedManager or Player not found!")
		return
	
	var new_seed = seed_manager.generate_random_seed()
	player.global_position = seed_manager.get_player_spawn_position()
	print("Generated new seed: ", new_seed)
	print("Player moved to: ", player.global_position)

func _test_dimension_travel():
	"""Test dimension travel system"""
	print("=== Dimension Travel Test ===")
	
	var dimension_travel = get_tree().get_first_node_in_group("dimension_travel")
	if not dimension_travel:
		print("ERROR: DimensionTravel not found!")
		return
	
	var info = dimension_travel.get_dimension_info()
	print("Current Dimension Info:")
	for key in info:
		print("  ", key, ": ", info[key])
	
	print("\nTesting world types with different seeds...")
	var test_seeds = [0, 12345, 54321, 99999, -12345]
	for seed_val in test_seeds:
		var prob = dimension_travel._calculate_mimic_probability(seed_val)
		var _type = dimension_travel._determine_world_type(prob)
		var type_name = dimension_travel._get_world_type_name_for_seed(seed_val)
		print("Seed ", seed_val, ": ", type_name, " (", prob * 100, "% mimics)")
	
	print("\n=== Dimension Travel Test Complete ===")
