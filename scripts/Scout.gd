extends CharacterBody2D

var target_node: Node2D
var nearby_distance = 400.0  # Distance to stay from target (increased from 200.0)
var slow_attack_speed = 100.0  # Slow movement speed during attacks
var normal_speed = 1300.0

var phaser_scene = preload("res://scenes/ScoutPhaser.tscn")
var fire_rate = 1.2
var time_since_last_fire = 0.0
var attack_range = 1000.0  # Increased from 600.0 for much better range
var min_safe_distance = 600.0  # Minimum distance to keep from large enemies (increased from 400.0)
var max_safe_distance = 1200.0  # Maximum distance to maintain (increased from 800.0)

# Ship physics - will match player speed dynamically
var speed = 1300.0  # Will be updated to match player
var acceleration = 1800.0  # Will be updated to match player
var friction = 80.0  # Will be updated to match player
var desired_position = Vector2.ZERO

# Player reference for speed matching
var player_node: CharacterBody2D

# AI states - simplified to remove orbiting
enum State { NEARBY, ATTACKING, REPOSITIONING }
var current_state = State.NEARBY
var target_enemy = null
var reposition_timer = 0.0

func _ready():
	# Find player and match their speed
	player_node = get_tree().get_first_node_in_group("player")
	if player_node:
		# Match player's movement stats
		speed = player_node.speed
		acceleration = player_node.acceleration
		friction = player_node.friction
		print("Scout: Matched player speed - Speed: ", speed, ", Acceleration: ", acceleration)

func _physics_process(delta):
	# Update speed to match player (in case player stats change)
	if player_node:
		speed = player_node.speed
		acceleration = player_node.acceleration
		friction = player_node.friction
	
	_update_ai_state(delta)
	_execute_current_state(delta)
	_handle_combat(delta)
	
	# Apply physics
	if desired_position.distance_to(global_position) > 5.0:
		var direction = global_position.direction_to(desired_position)
		velocity = velocity.move_toward(direction * speed, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	
	rotation = velocity.angle() + PI / 2
	move_and_collide(velocity * delta)

func _update_ai_state(delta):
	# Find nearby enemies
	var enemies = get_tree().get_nodes_in_group("enemy")
	target_enemy = null
	
	if not enemies.is_empty():
		var nearest_dist = attack_range
		for enemy in enemies:
			# Skip large enemies (mimics with high health)
			if _is_large_enemy(enemy):
				continue
			
			var dist = global_position.distance_to(enemy.global_position)
			if dist < nearest_dist:
				nearest_dist = dist
				target_enemy = enemy
	
	# Simplified state transitions
	if target_enemy and current_state != State.ATTACKING:
		current_state = State.ATTACKING
	elif not target_enemy and current_state == State.ATTACKING:
		current_state = State.NEARBY
	elif current_state == State.NEARBY and randf() < 0.005:  # Occasionally reposition
		current_state = State.REPOSITIONING
		reposition_timer = randf_range(1.0, 3.0)
	elif current_state == State.REPOSITIONING:
		reposition_timer -= delta
		if reposition_timer <= 0.0:
			current_state = State.NEARBY

func _execute_current_state(delta):
	match current_state:
		State.NEARBY:
			_nearby_behavior(delta)
		State.ATTACKING:
			_attack_behavior(delta)
		State.REPOSITIONING:
			_reposition_behavior(delta)

func _nearby_behavior(_delta):
	if target_node:
		# Stay near the target at a comfortable distance
		var angle = Time.get_ticks_msec() * 0.0005  # Slow rotation
		var offset = Vector2(cos(angle), sin(angle)) * nearby_distance
		desired_position = target_node.global_position + offset

func _attack_behavior(_delta):
	if target_enemy:
		# Maintain optimal distance from enemy
		var distance_to_enemy = global_position.distance_to(target_enemy.global_position)
		var optimal_distance = clamp(distance_to_enemy, min_safe_distance, max_safe_distance)
		
		# Move to optimal distance
		var angle_to_enemy = global_position.direction_to(target_enemy.global_position).angle()
		var offset_angle = angle_to_enemy + PI + sin(Time.get_ticks_msec() * 0.001) * 0.5  # More movement
		desired_position = target_enemy.global_position + Vector2(cos(offset_angle), sin(offset_angle)) * optimal_distance
		
		# Reduce speed during attacks for slow movement
		speed = slow_attack_speed
	else:
		# No enemy, return to normal speed
		speed = normal_speed

func _reposition_behavior(_delta):
	if target_node:
		# Move to a new nearby position
		var angle = randf() * TAU
		var distance = nearby_distance + randf_range(-50, 50)
		var offset = Vector2(cos(angle), sin(angle)) * distance
		desired_position = target_node.global_position + offset

func _handle_combat(delta):
	time_since_last_fire += delta
	if time_since_last_fire >= fire_rate and target_enemy:
		var distance_to_enemy = global_position.distance_to(target_enemy.global_position)
		# Fire from much farther away
		if distance_to_enemy <= attack_range:
			fire_at_enemy(target_enemy)

func fire_at_enemy(enemy):
	var phaser = phaser_scene.instantiate()
	phaser.setup(self, enemy, self, 2.0)  # Use 2.0 second lifetime instead of fire_rate
	get_tree().current_scene.add_child(phaser)
	time_since_last_fire = 0.0

func set_target_node(node: Node2D) -> void:
	target_node = node

func _is_large_enemy(enemy: Node) -> bool:
	# Check if enemy is large (mimic-type)
	if enemy.has_method("get_health"):
		var health = enemy.get_health()
		# Large enemies have 1000+ health
		if health >= 1000:
			return true
	
	# Check scale for large enemies
	if enemy.scale.x > 1.2 or enemy.scale.y > 1.2:
		return true
	
	# Check enemy name for mimic types
	var enemy_name = enemy.name.to_lower()
	return "mimic" in enemy_name or "greater" in enemy_name or "void" in enemy_name or "quantum" in enemy_name

# Public method to update speed to match player
func update_speed_to_match_player():
	if player_node:
		speed = player_node.speed
		normal_speed = speed
		acceleration = player_node.acceleration
		friction = player_node.friction
		print("Scout: Updated speed to match player - Speed: ", speed)
