extends Area2D
class_name ItemPickup

## Generic item pickup that displays any item sprite
## Dynamically loads texture based on item data

signal item_picked_up(item_data: ItemData, pickup_node: Node2D)

@export var item_id: String = ""
@export var float_height: float = 5.0
@export var float_speed: float = 2.0
@export var rotation_speed: float = 1.0
@export var glow_effect: bool = true
@export var auto_pickup: bool = false
@export var pickup_range: float = 50.0

var item_data: ItemData = null
var sprite: Sprite2D
var collision_shape: CollisionShape2D
var animation_player: AnimationPlayer
var particles: GPUParticles2D
var float_offset: float = 0.0
var time_passed: float = 0.0
var player_nearby: bool = false

func _ready():
	# Get component references
	sprite = $Sprite2D
	collision_shape = $CollisionShape2D
	animation_player = $AnimationPlayer
	particles = $GPUParticles2D
	
	# Setup signals
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Load item data if item_id is set
	if item_id != "":
		load_item(item_id)
	
	# Create floating animation
	_create_float_animation()

func load_item(item_identifier: String):
	"""Load item data and setup sprite"""
	item_id = item_identifier
	
	# Get item from registry
	var registry = get_tree().get_first_node_in_group("item_registry")
	if not registry:
		registry = preload("res://scripts/ItemRegistry.gd").new()
	
	item_data = registry.get_item(item_id)
	if not item_data:
		print("ItemPickup: Item not found: ", item_id)
		return
	
	# Load and set sprite texture
	var texture = load(item_data.asset_path) as Texture2D
	if texture:
		sprite.texture = texture
		# Adjust collision shape to match sprite size
		_adjust_collision_shape(texture)
	else:
		print("ItemPickup: Failed to load texture: ", item_data.asset_path)
	
	# Setup glow effect for magic items
	if glow_effect and item_data.is_magic():
		_create_glow_effect()
	
	print("ItemPickup: Loaded item: ", item_data.name)

func _adjust_collision_shape(texture: Texture2D):
	"""Adjust collision shape to match sprite dimensions"""
	if collision_shape.shape is RectangleShape2D:
		var rect_shape = collision_shape.shape as RectangleShape2D
		rect_shape.size = texture.get_size()

func _create_float_animation():
	"""Create floating and rotation animation"""
	if animation_player:
		var animation = Animation.new()
		animation.length = 2.0
		animation.loop = true
		
		# Float animation
		var float_track = animation.add_track(Animation.TYPE_VALUE)
		animation.track_set_path(float_track, ":position:y")
		animation.track_insert_key(float_track, 0.0, 0.0)
		animation.track_insert_key(float_track, 1.0, -float_height)
		animation.track_insert_key(float_track, 2.0, 0.0)
		
		# Rotation animation
		var rotation_track = animation.add_track(Animation.TYPE_VALUE)
		animation.track_set_path(rotation_track, ":rotation")
		animation.track_insert_key(rotation_track, 0.0, 0.0)
		animation.track_insert_key(rotation_track, 2.0, TAU)
		
		animation_player.add_animation("float", animation)
		animation_player.play("float")

func _create_glow_effect():
	"""Create glow effect for magic items"""
	if particles:
		particles.emitting = true
		# Set particle color based on item type
		var particle_material = particles.process_material as ParticleProcessMaterial
		if particle_material:
			if item_data.type.contains("Magic"):
				particle_material.color = Color.MAGENTA
			elif item_data.type.contains("Hybrid"):
				particle_material.color = Color.CYAN

func _process(delta):
	time_passed += delta
	
	# Auto-pickup if player is nearby
	if auto_pickup and player_nearby:
		var player = get_tree().get_first_node_in_group("player")
		if player and global_position.distance_to(player.global_position) <= pickup_range:
			pickup_item(player)

func _on_body_entered(body):
	if body.is_in_group("player"):
		player_nearby = true
		if not auto_pickup:
			# Manual pickup - could be triggered by interaction key
			pass

func _on_body_exited(body):
	if body.is_in_group("player"):
		player_nearby = false

func pickup_item(_picker: Node2D):
	"""Handle item pickup"""
	if not item_data:
		return
	
	# Emit signal for game systems to handle
	item_picked_up.emit(item_data, self)
	
	# Create pickup effect
	_create_pickup_effect()
	
	# Remove from scene
	queue_free()

func _create_pickup_effect():
	"""Create visual effect when item is picked up"""
	if particles:
		particles.emitting = true
		particles.restart()
	
	# Could add sound effect here
	var audio_manager = get_tree().get_first_node_in_group("audio_manager")
	if audio_manager:
		audio_manager.play_sfx("item_pickup")

func get_item_info() -> Dictionary:
	"""Get item information for UI display"""
	if not item_data:
		return {}
	
	return item_data.get_display_info()

func set_item_position(pos: Vector2):
	"""Set item position"""
	global_position = pos

# Static method to create item pickup in world
static func create_world_item(item_identifier: String, spawn_position: Vector2) -> ItemPickup:
	"""Create an item pickup in the game world"""
	var item_pickup_scene = load("res://scenes/ItemPickup.tscn")
	if not item_pickup_scene:
		print("ItemPickup: Failed to load scene")
		return null
	
	var item_pickup = item_pickup_scene.instantiate()
	if not item_pickup:
		print("ItemPickup: Failed to instantiate scene")
		return null
	
	item_pickup.load_item(item_identifier)
	item_pickup.set_item_position(spawn_position)
	
	# Add to current scene
	var current_scene = Engine.get_singleton("get_main_loop").current_scene
	if current_scene:
		current_scene.add_child(item_pickup)
	else:
		print("ItemPickup: No current scene found")
		item_pickup.queue_free()
		return null
	
	return item_pickup
