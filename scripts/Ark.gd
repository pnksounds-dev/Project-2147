extends Node2D

class_name Ark

# Stationary faction hub that spawns Motherships

@export var rotation_speed: float = 0.01  # Slower rotation for better visibility
@export var spawn_interval: float = 10.0
@export var max_motherships: int = 10  # Changed to 6 as requested
@export var home_position: Vector2 = Vector2.ZERO
@export var inner_patrol_radius: float = 10000.0  # Inner patrol route radius
@export var outer_patrol_radius: float = 2000.0  # Outer patrol route radius
@export var patrol_speed: float = 500.0  # Speed for mothership patrol movement

var _sprite: Sprite2D
var _spawn_timer: float = 0.0
var _spawned_motherships: Array[Node] = []

const MOTHERSHIP_SCENE = preload("res://scenes/Mothership.tscn")

func _ready() -> void:
	add_to_group("ark_ships")
	add_to_group("player_faction") # Ark is part of player faction
	# Add to map tracker group so it shows up on radar (if we add logic for it)
	# For now, MapTracker tracks "enemy" and "orb". We might want to add "ark" later.
	
	print("Ark: _ready() called, position: ", global_position)
	
	_sprite = $Sprite2D
	if not _sprite:
		push_error("Ark: Sprite2D not found!")
		return
	
	# Verify sprite texture is loaded
	if not _sprite.texture:
		push_warning("Ark: Sprite texture not loaded!")
	else:
		print("Ark: Sprite texture loaded: ", _sprite.texture.resource_path)
	
	_spawn_timer = spawn_interval
	
	# Set position to home position
	global_position = home_position
	print("Ark: Set position to home_position: ", home_position)
	
	# Set z-index to appear below player and other ships
	z_index = -50  # Background layer, below player (default 0) and enemies
	print("Ark: Set z-index to: ", z_index)
	
	# Configure collision to not interfere with player and allies
	var static_body = $StaticBody2D
	if static_body:
		# Set collision to only interact with enemies, not player or allies
		static_body.collision_layer = 0  # Don't collide with anything
		static_body.collision_mask = 0   # Don't detect collisions with anything
		print("Ark: Disabled collision")
	
	print("Ark: Initialization complete")
	print("Ark: Final position: ", global_position, ", visible: ", visible, ", modulate: ", modulate)

func set_home_position(pos: Vector2) -> void:
	home_position = pos
	global_position = pos

func _process(delta: float) -> void:
	# Rotate slowly
	if _sprite:
		_sprite.rotation += rotation_speed * delta
	
	# Spawn logic
	_spawn_timer -= delta
	if _spawn_timer <= 0:
		_spawn_timer = spawn_interval
		_attempt_spawn()

func _attempt_spawn() -> void:
	# Clean up invalid references and remove destroyed motherships
	_spawned_motherships = _spawned_motherships.filter(func(m): return is_instance_valid(m))
	
	# Check current mothership count
	if _spawned_motherships.size() >= max_motherships:
		print("Ark: Maximum motherships reached (", max_motherships, ")")
		return
		
	# Determine patrol route (alternating between inner and outer)
	var is_inner_route = _spawned_motherships.size() % 2 == 0
	var patrol_radius = inner_patrol_radius if is_inner_route else outer_patrol_radius
	
	# Calculate spawn position on patrol route
	var angle = randf() * TAU  # Random angle for spawn position
	var spawn_offset = Vector2(cos(angle), sin(angle)) * patrol_radius
	var spawn_position = global_position + spawn_offset
	
	var mothership = MOTHERSHIP_SCENE.instantiate()
	mothership.global_position = spawn_position
	
	# Configure as player-faction mothership
	mothership.set_faction(faction_id)
	
	# Setup patrol behavior
	if mothership.has_method("setup_patrol"):
		mothership.setup_patrol(global_position, patrol_radius, patrol_speed, angle)
	
	get_parent().add_child(mothership)
	_spawned_motherships.append(mothership)
	
	var route_name = "inner" if is_inner_route else "outer"
	print("Ark: Spawned mothership #", _spawned_motherships.size(), "/", max_motherships, " on ", route_name, " patrol route")

var faction_id: String = "player"

func setup(new_faction_id: String) -> void:
	faction_id = new_faction_id
	
	# Update visual based on faction
	if FactionManager.instance:
		modulate = FactionManager.instance.get_faction_color(faction_id)
	
	# Update group membership
	if faction_id == "player":
		add_to_group("player_faction")
		remove_from_group("enemy")
	elif faction_id == "enemy":
		add_to_group("enemy")
		remove_from_group("player_faction")
	
	print("Ark: Setup for faction: ", faction_id)
