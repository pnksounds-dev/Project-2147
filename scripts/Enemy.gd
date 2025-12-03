extends CharacterBody2D

@export var speed = 10.0
@export var health = 1000.0
@export var damage = 5.0
@export var xp_value = 100

@export var target_group: String = "player"
@export var flocking_enabled: bool = true
@export var separation_weight: float = 1.5
@export var alignment_weight: float = 0.5
@export var cohesion_weight: float = 0.5

var _target_node: Node2D = null
var _neighbors: Array[Node2D] = []
var _neighbor_detector: Area2D
var _health_bar: FloatingHealthBar

func _ready():
	add_to_group("enemy")
	_setup_neighbor_detector()
	_create_health_bar()

func _create_health_bar():
	_health_bar = preload("res://scenes/UI/FloatingHealthBar.tscn").instantiate()
	_health_bar.setup(self, int(health), int(health))

func _setup_neighbor_detector() -> void:
	_neighbor_detector = Area2D.new()
	_neighbor_detector.name = "NeighborDetector"
	_neighbor_detector.collision_layer = 0
	_neighbor_detector.collision_mask = collision_layer # Detect same layer (enemies)
	
	var shape = CircleShape2D.new()
	shape.radius = 150.0
	var col = CollisionShape2D.new()
	col.shape = shape
	_neighbor_detector.add_child(col)
	add_child(_neighbor_detector)
	
	_neighbor_detector.body_entered.connect(func(body): if body != self and body is CharacterBody2D: _neighbors.append(body))
	_neighbor_detector.body_exited.connect(func(body): _neighbors.erase(body))

func _physics_process(delta):
	# Find target
	if not _target_node or not is_instance_valid(_target_node):
		_target_node = get_tree().get_first_node_in_group(target_group)
	
	var steering = Vector2.ZERO
	
	# 1. Seek Target
	if _target_node:
		var direction = global_position.direction_to(_target_node.global_position)
		steering += direction * 2.0 # Strong seek
	
	# 2. Boids Flocking
	if flocking_enabled and not _neighbors.is_empty():
		var separation = Vector2.ZERO
		var alignment = Vector2.ZERO
		var center_mass = Vector2.ZERO
		var count = 0
		
		for neighbor in _neighbors:
			if not is_instance_valid(neighbor): continue
			
			# Separation
			var dist = global_position.distance_to(neighbor.global_position)
			if dist < 0.1: dist = 0.1
			separation -= (neighbor.global_position - global_position).normalized() / dist
			
			# Alignment
			if neighbor.has_method("get_real_velocity"): # Assuming standard velocity
				alignment += neighbor.velocity
			
			# Cohesion
			center_mass += neighbor.global_position
			count += 1
		
		if count > 0:
			separation /= count
			alignment /= count
			center_mass /= count
			var cohesion = global_position.direction_to(center_mass)
			
			steering += separation * separation_weight * 100.0
			steering += alignment.normalized() * alignment_weight
			steering += cohesion * cohesion_weight
	
	# Apply Movement
	var desired_velocity = steering.normalized() * speed
	velocity = velocity.lerp(desired_velocity, delta * 2.0)
	
	if velocity.length() > 1.0:
		rotation = velocity.angle()
	
	var collision = move_and_collide(velocity * delta)
	if collision:
		var collider = collision.get_collider()
		if collider.is_in_group(target_group):
			if collider.has_method("take_damage"):
				collider.take_damage(damage * delta)
	
	# Despawn if too far
	if _target_node and global_position.distance_squared_to(_target_node.global_position) > 15000 * 15000:
		queue_free()


func take_damage(amount):
	health -= amount
	if _health_bar:
		_health_bar.set_value(int(health))
	if health <= 0:
		die()

var xp_orb_scene = preload("res://scenes/ExperienceOrb.tscn")

func die():
	if _health_bar:
		_health_bar.cleanup()
	var orb = xp_orb_scene.instantiate()
	orb.global_position = global_position
	orb.xp_amount = xp_value
	get_parent().call_deferred("add_child", orb)
	queue_free()
