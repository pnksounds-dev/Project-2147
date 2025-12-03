extends Area2D
class_name BaseItem

## Base functionality for all items
## Individual items extend this class for easy visual editing

signal item_picked_up(item: BaseItem, picker: Node2D)

@export var item_id: String = ""
@export var stack_size: int = 1
@export var base_value: int = 0
@export var auto_pickup: bool = false
@export var pickup_range: float = 50.0
@export var float_animation: bool = true
@export var glow_effect: bool = false
@export var pickup_sound: String = "item_pickup"

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var effects: Node2D = $Effects

var player_nearby: bool = false
var float_offset: float = 0.0
var time_passed: float = 0.0

func _ready():
	setup_item()
	connect_signals()
	create_animations()

func setup_item():
	"""Setup item-specific properties - override in individual items"""
	if item_id == "":
		item_id = name
	
	# Auto-adjust collision shape to sprite size
	if sprite and sprite.texture:
		_adjust_collision_shape()

func connect_signals():
	"""Connect item signals"""
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _adjust_collision_shape():
	"""Adjust collision shape to match sprite size"""
	if collision_shape and collision_shape.shape is RectangleShape2D:
		var rect_shape = collision_shape.shape as RectangleShape2D
		var texture_size = sprite.texture.get_size()
		rect_shape.size = texture_size

func create_animations():
	"""Create default animations"""
	if not animation_player:
		return
	
	if float_animation:
		_create_float_animation()

func _create_float_animation():
	"""Create floating animation"""
	var animation = Animation.new()
	animation.length = 2.0
	animation.loop = true
	
	# Float up and down
	var float_track = animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(float_track, ":position:y")
	animation.track_insert_key(float_track, 0.0, 0.0)
	animation.track_insert_key(float_track, 1.0, -5.0)
	animation.track_insert_key(float_track, 2.0, 0.0)
	
	animation_player.add_animation("float", animation)
	animation_player.play("float")

func _process(delta):
	time_passed += delta
	
	# Auto-pickup logic
	if auto_pickup and player_nearby:
		var player = get_tree().get_first_node_in_group("player")
		if player and global_position.distance_to(player.global_position) <= pickup_range:
			pickup_item(player)

func _on_body_entered(body):
	if body.is_in_group("player"):
		player_nearby = true
		if not auto_pickup:
			# Could show pickup prompt here
			pass

func _on_body_exited(body):
	if body.is_in_group("player"):
		player_nearby = false

func pickup_item(picker: Node2D):
	"""Handle item pickup - override in individual items for custom behavior"""
	# Play pickup sound
	var audio_manager = get_tree().get_first_node_in_group("audio_manager")
	if audio_manager and pickup_sound != "":
		audio_manager.play_sfx(pickup_sound)
	
	# Create pickup effect
	create_pickup_effect()
	
	# Emit signal for game systems
	item_picked_up.emit(self, picker)
	
	# Remove from scene
	queue_free()

func create_pickup_effect():
	"""Create visual pickup effect - override in individual items"""
	if effects:
		# Simple scale effect
		var tween = create_tween()
		tween.tween_property(sprite, "scale", Vector2(1.5, 1.5), 0.2)
		tween.tween_property(sprite, "modulate:a", 0.0, 0.2)

# Override in individual items
func get_item_data() -> Dictionary:
	return {
		"id": item_id,
		"stack_size": stack_size,
		"base_value": base_value,
		"auto_pickup": auto_pickup
	}

func get_item_type() -> String:
	"""Override in individual items"""
	return "Unknown"

func get_item_description() -> String:
	"""Override in individual items"""
	return "A mysterious item"

# Static method for easy creation
static func create_item(item_scene_path: String, spawn_position: Vector2) -> BaseItem:
	var item_scene = load(item_scene_path)
	if not item_scene:
		return null
	
	var item_instance = item_scene.instantiate()
	item_instance.global_position = spawn_position
	
	# Need to add to scene tree - caller should handle this
	# get_tree().current_scene.add_child(item_instance)
	
	return item_instance
