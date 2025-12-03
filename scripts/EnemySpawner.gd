extends Node2D

var player
var spawn_radius = 3000.0  # Increased from 2000 to spawn further away
var spawn_interval = 8.0 # Much slower for exploration
var time_since_last_spawn = 0.0

# Screen edge spawning variables
var min_spawn_distance = 800.0   # Minimum distance from player
var max_spawn_distance = 2500.0  # Maximum distance from player

var orb_spawn_interval = 12.0
var time_since_last_orb = 0.0
var orb_scene = preload("res://scenes/ExperienceOrb.tscn")

# Preload enemy scenes
var drone_scene = preload("res://scenes/Enemy.tscn")
var scout_scene = preload("res://scenes/Scout.tscn")
var hypno_scene = preload("res://scenes/HypnoMimic.tscn")
var greater_scene = preload("res://scenes/GreaterMimic.tscn")
var infected_scene = preload("res://scenes/InfectedMimic.tscn")
var void_scene = preload("res://scenes/VoidMimic.tscn")
var quantum_scene = preload("res://scenes/QuantumMimic.tscn")
var ark_scene = preload("res://scenes/Ark.tscn")
var mothership_scene = preload("res://scenes/Mothership.tscn")

func _ready():
	add_to_group("enemy_spawner")
	player = get_tree().get_first_node_in_group("player")

func _process(delta):
	if not player:
		player = get_tree().get_first_node_in_group("player")
		return

	# Enemy Spawning
	time_since_last_spawn += delta
	if time_since_last_spawn >= spawn_interval:
		spawn_enemy()
		time_since_last_spawn = 0.0
		
	# Random Orb Spawning
	time_since_last_orb += delta
	if time_since_last_orb >= orb_spawn_interval:
		spawn_random_orb()
		time_since_last_orb = 0.0
		
	# Fixed spawn rate for exploration-focused gameplay
	# No time-based scaling - removed for better game balance

func spawn_enemy():
	if not player: return
	
	var spawn_pos = Vector2.ZERO
	var _current_time = Time.get_ticks_msec() / 1000.0
	
	# Always spawn at screen edges or beyond, never near player
	spawn_pos = _get_safe_spawn_position()
	
	var enemy_type = drone_scene
	
	# Fixed enemy selection for exploration - no time-based progression
	enemy_type = drone_scene
	
	# Occasionally spawn other types for variety
	var rand = randf()
	if rand > 0.7:
		enemy_type = scout_scene
	elif rand > 0.9:
		enemy_type = hypno_scene
	
	var new_enemy = enemy_type.instantiate()
	new_enemy.global_position = spawn_pos
	get_parent().add_child(new_enemy)

func _get_safe_spawn_position() -> Vector2:
	"""Get a spawn position that's always at screen edge or beyond"""
	if not player:
		return Vector2.ZERO
	
	# Get viewport size to calculate screen edges
	var viewport = get_viewport()
	var viewport_size = viewport.get_visible_rect().size
	var camera_zoom = player.get_node("Camera2D").zoom if player.get_node("Camera2D") else Vector2.ONE
	
	# Calculate visible area size in world coordinates
	var visible_width = viewport_size.x / camera_zoom.x
	var visible_height = viewport_size.y / camera_zoom.y
	
	# Spawn at screen edges or beyond
	var edge_distance = max(visible_width, visible_height) * 0.6  # 60% of screen size
	var spawn_distance = randf_range(edge_distance, max_spawn_distance)
	
	var angle = randf() * TAU
	var spawn_pos = player.global_position + Vector2(cos(angle), sin(angle)) * spawn_distance
	
	return spawn_pos

func debug_spawn(type_name: String, count: int):
	var scene_to_spawn = drone_scene
	match type_name:
		"drone": scene_to_spawn = drone_scene
		"hypno": scene_to_spawn = hypno_scene
		"greater": scene_to_spawn = greater_scene
		"infected": scene_to_spawn = infected_scene
		"void": scene_to_spawn = void_scene
		"quantum": scene_to_spawn = quantum_scene
	
	if not player: return
	
	for i in range(count):
		var spawn_pos = _get_safe_spawn_position()  # Use safe spawn position
		var enemy = scene_to_spawn.instantiate()
		enemy.global_position = spawn_pos
		get_parent().call_deferred("add_child", enemy)

func spawn_mimic_type(mimic_type: String, spawn_position: Vector2 = Vector2.ZERO):
	"""Spawn a specific mimic type at specified position"""
	if not player: return
	
	var spawn_pos = spawn_position
	if spawn_pos == Vector2.ZERO:
		spawn_pos = _get_safe_spawn_position()
	
	var mimic_scene = drone_scene  # fallback
	match mimic_type:
		"hypno": mimic_scene = hypno_scene
		"greater": mimic_scene = greater_scene
		"infected": mimic_scene = infected_scene
		"void": mimic_scene = void_scene
		"quantum": mimic_scene = quantum_scene
		_: 
			print("Unknown mimic type: ", mimic_type)
			return
	
	var mimic = mimic_scene.instantiate()
	mimic.global_position = spawn_pos
	get_parent().call_deferred("add_child", mimic)
	
	print("Spawned ", mimic_type, " mimic at position: ", spawn_pos)

func spawn_ark(pos: Vector2 = Vector2.ZERO):
	if not player: return
	var ark = ark_scene.instantiate()
	if pos == Vector2.ZERO:
		# Spawn far away if no pos given - use safe spawn position
		pos = _get_safe_spawn_position()
	ark.global_position = pos
	
	# Setup as player faction by default for now
	if ark.has_method("setup"):
		ark.setup("player")
		
	get_parent().call_deferred("add_child", ark)
	print("Spawned Ark at position: ", pos)

func spawn_mothership(pos: Vector2 = Vector2.ZERO):
	if not player: return
	var ship = mothership_scene.instantiate()
	if pos == Vector2.ZERO:
		# Spawn at safe distance if no pos given
		pos = _get_safe_spawn_position()
	ship.global_position = pos
	get_parent().call_deferred("add_child", ship)
	print("Spawned Mothership at position: ", pos)

func spawn_drone(spawn_position: Vector2 = Vector2.ZERO):
	"""Spawn a drone at specified position"""
	if not player: return
	
	var spawn_pos = spawn_position
	if spawn_pos == Vector2.ZERO:
		spawn_pos = _get_safe_spawn_position()
	
	var drone = drone_scene.instantiate()
	drone.global_position = spawn_pos
	get_parent().call_deferred("add_child", drone)
	print("Spawned Drone at position: ", spawn_pos)

func spawn_scout(spawn_position: Vector2 = Vector2.ZERO):
	"""Spawn a scout at specified position"""
	if not player: return
	
	var spawn_pos = spawn_position
	if spawn_pos == Vector2.ZERO:
		spawn_pos = _get_safe_spawn_position()
	
	var scout = scout_scene.instantiate()
	scout.global_position = spawn_pos
	get_parent().call_deferred("add_child", scout)
	print("Spawned Scout at position: ", spawn_pos)

func spawn_mimic(spawn_position: Vector2 = Vector2.ZERO):
	"""Spawn a random mimic type at specified position"""
	if not player: return
	
	# Choose random mimic type for exploration
	var mimic_scene = hypno_scene
	
	# Occasionally spawn other types for variety
	var rand = randf()
	if rand > 0.8:
		mimic_scene = greater_scene
	elif rand > 0.95:
		mimic_scene = void_scene
	
	var spawn_pos = spawn_position
	if spawn_pos == Vector2.ZERO:
		spawn_pos = _get_safe_spawn_position()
	
	var mimic = mimic_scene.instantiate()
	mimic.global_position = spawn_pos
	get_parent().call_deferred("add_child", mimic)
	
	# Determine mimic type name for logging
	var mimic_name = "Unknown"
	match mimic_scene:
		hypno_scene: mimic_name = "HypnoMimic"
		greater_scene: mimic_name = "GreaterMimic"
		infected_scene: mimic_name = "InfectedMimic"
		void_scene: mimic_name = "VoidMimic"
		quantum_scene: mimic_name = "QuantumMimic"
	
	print("Spawned ", mimic_name, " at position: ", spawn_pos)

func spawn_random_orb():
	if not player: return
	var orb = orb_scene.instantiate()
	# Spawn orb at reasonable distance - not too close, not too far
	var angle = randf() * TAU
	var dist = randf_range(200, 600)  # Increased from 100-500 to avoid spawning too close
	var spawn_pos = player.global_position + Vector2(cos(angle), sin(angle)) * dist
	orb.global_position = spawn_pos
	orb.xp_amount = 10 # Base amount for found orbs
	get_parent().add_child(orb)
