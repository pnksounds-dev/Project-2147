extends CharacterBody2D

class_name Mothership

# Large ship that spawns drones - can be player or enemy faction

@export var speed: float = 40.0
@export var health: float = 500.0
@export var spawn_interval: float = 5.0
@export var max_drones: int = 5
@export var faction: String = "enemy" # "player" or "enemy"
@export var orbit_radius: float = 1000.0
@export var orbit_speed: float = 0.5

# Patrol variables
var _is_patrolling: bool = false
var _patrol_center: Vector2
var _patrol_radius: float = 500.0
var _patrol_speed: float = 50.0
var _patrol_angle: float = 0.0

var _player: Node2D
var _ark: Node2D  # The Ark this mothership orbits around
var _spawn_timer: float = 0.0
var _spawned_drones: Array[Node] = []
var _orbit_angle: float = 0.0

# NPC ship variations for mothership spawns
const NPC_SHIP_SCENES = [
	preload("res://scenes/Scout.tscn"), # Trader Scout
	# Add more NPC ship scenes here when available
]

const DRONE_SCENE = preload("res://scenes/DroneMimic.tscn")
const XP_ORB_SCENE = preload("res://scenes/ExperienceOrb.tscn")

func _ready() -> void:
	add_to_group("motherships")
	_set_faction(faction)
	_player = get_tree().get_first_node_in_group("player")
	_spawn_timer = spawn_interval
	
	# Find the Ark this mothership should orbit
	_find_parent_ark()
	
	# Initialize orbit angle
	_orbit_angle = randf() * TAU  # Random starting position

func _find_parent_ark() -> void:
	# Try to find the nearest Ark
	var arks = get_tree().get_nodes_in_group("ark_ships")
	var nearest_distance = INF
	var nearest_ark: Node2D = null
	
	for ark in arks:
		var distance = global_position.distance_to(ark.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_ark = ark
	
	_ark = nearest_ark
	if _ark:
		print("Mothership: Found parent Ark at distance: ", nearest_distance)

func _set_faction(new_faction: String) -> void:
	faction = new_faction
	
	var color = Color.WHITE
	if FactionManager.instance:
		color = FactionManager.instance.get_faction_color(faction)
	
	modulate = color
	
	if faction == "player":
		add_to_group("player_faction")
		remove_from_group("enemy")
		# Use a non-enemy collision layer for player-faction motherships so the
		# player and player weapons (which target enemy layer 2) can pass through.
		collision_layer = 4
		# Optionally still allow interactions with enemies if their masks include
		# this layer; player (mask=2) will not collide with layer 4.
		# Keep existing mask unless explicitly needed.
	elif faction == "enemy":
		add_to_group("enemy")
		remove_from_group("player_faction")
		# Ensure enemy-faction motherships stay on the enemy collision layer so
		# the player and weapons can interact with them normally.
		collision_layer = 2


func set_faction(new_faction: String) -> void:
	_set_faction(new_faction)

func setup_patrol(center_position: Vector2, radius: float, patrol_speed: float, start_angle: float) -> void:
	"""Setup patrol behavior around a center point"""
	_is_patrolling = true
	_patrol_center = center_position
	_patrol_radius = radius
	_patrol_speed = patrol_speed
	_patrol_angle = start_angle
	
	print("Mothership: Setup patrol - Center: ", center_position, ", Radius: ", radius, ", Speed: ", patrol_speed)

func _physics_process(delta: float) -> void:
	# Always try to find player if not available
	if not _player:
		_player = get_tree().get_first_node_in_group("player")
		if not _player:
			return  # No player found, skip this frame
	
	# Use patrol behavior if set up, otherwise fallback to orbit
	if _is_patrolling:
		_patrol_around_center(delta)
	elif _ark:
		_orbit_around_ark(delta)
	else:
		# Fallback: stay in place if no Ark found
		velocity = Vector2.ZERO
		move_and_slide()
	
	# Spawn drones
	_spawn_timer -= delta
	if _spawn_timer <= 0:
		_spawn_timer = spawn_interval
		_attempt_spawn()
		
	# Despawn if too far from player (but stay longer if orbiting Ark)
	if _player and global_position.distance_squared_to(_player.global_position) > 30000.0 * 30000.0:
		queue_free()

func _orbit_around_ark(delta: float) -> void:
	if not _ark:
		return
	
	# Update orbit angle
	_orbit_angle += orbit_speed * delta
	
	# Calculate target position on orbit circle
	var target_pos = _ark.global_position + Vector2(
		cos(_orbit_angle) * orbit_radius,
		sin(_orbit_angle) * orbit_radius
	)
	
	# Move towards target position smoothly
	var direction = global_position.direction_to(target_pos)
	velocity = direction * speed
	rotation = direction.angle()
	move_and_slide()

func _patrol_around_center(delta: float) -> void:
	"""Patrol around a center point at a fixed radius"""
	# Update patrol angle
	_patrol_angle += (_patrol_speed / _patrol_radius) * delta
	
	# Calculate target position on patrol circle
	var target_pos = _patrol_center + Vector2(
		cos(_patrol_angle) * _patrol_radius,
		sin(_patrol_angle) * _patrol_radius
	)
	
	# Move towards target position smoothly
	var direction = global_position.direction_to(target_pos)
	velocity = direction * _patrol_speed
	rotation = direction.angle()
	move_and_slide()

func _attempt_spawn() -> void:
	_spawned_drones = _spawned_drones.filter(func(d): return is_instance_valid(d))
	
	if _spawned_drones.size() >= max_drones:
		return
	
	# Spawn a squadron of NPC ships
	var squadron_size = 3
	for i in range(squadron_size):
		var ship
		
		if faction == "player":
			# Player faction spawns NPC ships
			if NPC_SHIP_SCENES.size() > 0:
				ship = NPC_SHIP_SCENES[randi() % NPC_SHIP_SCENES.size()].instantiate()
			else:
				# Fallback to drone if no NPC ships available
				ship = DRONE_SCENE.instantiate()
		else:
			# Enemy faction spawns enemy drones
			ship = DRONE_SCENE.instantiate()
		
		var offset = Vector2(randf_range(-100, 100), randf_range(-100, 100))
		ship.global_position = global_position + offset
		
		# Configure ship based on faction
		if faction == "player":
			# Player faction ship configuration
			if ship.has_method("set_faction"):
				ship.set_faction("player")
			ship.add_to_group("player_faction")
			ship.remove_from_group("enemy") # Don't target self/allies
			
			if ship.has_method("set_target_node"):
				ship.set_target_node(self)
			
			# Set target_group only if the ship supports it (like Enemy.gd)
			if "target_group" in ship:
				ship.target_group = "enemy" # Attack enemies
			
			if "speed" in ship:
				ship.speed = 150.0 # Faster than regular enemies
			ship.modulate = Color(0.0, 0.8, 1.0) # Blue tint
		else:
			# Enemy faction ship configuration (Legion)
			if "target_group" in ship:
				ship.target_group = "enemy" # Attack Mimics
			ship.modulate = Color(0.0, 0.5, 1.0) # Blue tint for friendly/legion
			ship.add_to_group("legion")
			ship.remove_from_group("enemy") # Don't target self
			if "speed" in ship:
				ship.speed = 150.0 # Faster than mimics
		
		get_parent().add_child(ship)
		_spawned_drones.append(ship)

func take_damage(amount: float) -> void:
	health -= amount
	if health <= 0:
		die()

func die() -> void:
	# Drop massive XP
	for i in range(5):
		var orb = XP_ORB_SCENE.instantiate()
		orb.global_position = global_position + Vector2(randf_range(-50, 50), randf_range(-50, 50))
		orb.xp_amount = 100
		get_parent().call_deferred("add_child", orb)
	
	queue_free()
