extends Node

class_name GameInitializer

## GameInitializer - Handles initial setup for new games
## Spawns player faction structures at (0,0) and sets up initial world state

signal game_initialized

func _ready() -> void:
	# Initialize game when scene is ready
	call_deferred("_initialize_game")

func _initialize_game() -> void:
	print("GameInitializer: Starting game initialization...")
	
	# Initialize territory and chunk systems first
	_initialize_territory_system()
	
	# Spawn player faction Ark at (0,0)
	_spawn_player_ark()
	
	# Initialize player faction territory
	_initialize_player_faction_territory()
	
	# Emit completion signal
	game_initialized.emit()
	print("GameInitializer: Game initialization complete!")

func _initialize_territory_system() -> void:
	# Get references to managers
	var territory_manager = get_tree().get_first_node_in_group("territory_manager")
	var chunk_manager = get_tree().get_first_node_in_group("chunk_manager")
	
	# Add to groups for easy access
	if territory_manager:
		territory_manager.add_to_group("territory_manager")
		print("GameInitializer: TerritoryManager initialized")
	
	if chunk_manager:
		chunk_manager.add_to_group("chunk_manager")
		print("GameInitializer: ChunkManager initialized")

func _spawn_player_ark() -> void:
	print("GameInitializer: Starting Ark spawn process...")
	
	# Check if Ark already exists
	var existing_ark = get_tree().get_first_node_in_group("ark_ships")
	if existing_ark:
		print("GameInitializer: Ark already exists (", existing_ark.name, "), skipping spawn")
		return
	
	var ark_scene = preload("res://scenes/Ark.tscn")
	if not ark_scene:
		push_error("GameInitializer: Ark scene not found!")
		return
	
	print("GameInitializer: Instantiating Ark scene...")
	var ark = ark_scene.instantiate()
	ark.name = "PlayerArk"
	
	print("GameInitializer: Configuring Ark groups...")
	# Configure as player faction
	ark.add_to_group("player_faction")
	ark.add_to_group("ark_ships")
	
	print("GameInitializer: Setting Ark position...")
	# Set home position to (0,0) - the center of the player faction territory
	if ark.has_method("set_home_position"):
		ark.set_home_position(Vector2.ZERO)
	else:
		ark.global_position = Vector2.ZERO  # Fallback
	
	print("GameInitializer: Adding Ark to scene...")
	# Add to scene
	get_tree().current_scene.add_child(ark)
	
	print("GameInitializer: Spawned player Ark at position (0,0)")
	
	# Verify the Ark was added
	await get_tree().process_frame
	var verify_ark = get_tree().get_first_node_in_group("ark_ships")
	if verify_ark:
		print("GameInitializer: Ark verification successful - found: ", verify_ark.name)
	else:
		push_error("GameInitializer: Ark verification failed - Ark not found after spawn!")

func _initialize_player_faction_territory() -> void:
	# This would set up the player faction territory around the Ark
	# For now, we'll just ensure the Ark is marked as the player faction hub
	var ark = get_tree().get_first_node_in_group("ark_ships")
	if ark:
		ark.add_to_group("faction_hub")
		print("GameInitializer: Player faction territory initialized")
	else:
		push_warning("GameInitializer: Could not find Ark for territory initialization")

# Public method to restart game initialization
func restart_initialization() -> void:
	print("GameInitializer: Restarting game initialization...")
	_initialize_game()
