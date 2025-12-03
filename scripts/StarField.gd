extends Node2D

class_name StarField

## StarField - Procedural star system with multiple layers
## Features different glow states, popping effects, and depth layers

@export var star_count: int = 200
@export var field_width: float = 2048.0
@export var field_height: float = 2048.0
@export var enable_debug_logging: bool = false

# Star layer configurations
enum StarLayer {
	BACKGROUND = 0,    # Distant stars, slow movement
	MIDGROUND = 1,     # Medium distance
	FOREGROUND = 2     # Near stars, fast movement
}

# Star glow states
enum GlowState {
	OFF = 0,
	FADE_IN = 1,
	STEADY = 2,
	FADE_OUT = 3,
	PULSE = 4
}

var _logger: Node
var _stars: Array[StarData] = []
var _star_nodes: Array[Sprite2D] = []
var _camera: Camera2D

# Star data structure
class StarData:
	var star_position: Vector2
	var layer: StarLayer
	var size: float
	var base_color: Color
	var glow_state: GlowState
	var glow_timer: float
	var glow_duration: float
	var pulse_speed: float
	var brightness: float
	var parallax_factor: float
	var pop_in_timer: float
	var pop_in_duration: float
	
	func _init(pos: Vector2, lyr: StarLayer):
		star_position = pos
		layer = lyr
		_generate_star_properties()

	func _generate_star_properties():
		# Set size based on layer
		match layer:
			StarLayer.BACKGROUND:
				size = randf_range(0.5, 1.5)
				parallax_factor = randf_range(0.02, 0.08)  # Increased parallax
				base_color = Color.WHITE
				base_color.v = randf_range(0.3, 0.7)  # Dimmer
			StarLayer.MIDGROUND:
				size = randf_range(1.0, 2.5)
				parallax_factor = randf_range(0.1, 0.2)  # Increased parallax
				base_color = Color.WHITE
				base_color.v = randf_range(0.5, 0.9)  # Medium brightness
			StarLayer.FOREGROUND:
				size = randf_range(2.0, 4.0)
				parallax_factor = randf_range(0.3, 0.5)  # Increased parallax
				base_color = Color.WHITE
				base_color.v = randf_range(0.7, 1.0)  # Brighter
	
		# Random glow properties
		glow_timer = 0.0
		glow_duration = randf_range(3.0, 8.0)
		pulse_speed = randf_range(0.5, 1.5)
		
		# Make some stars visible immediately
		if randf() < 0.3:  # 30% chance to start visible
			brightness = randf_range(0.3, 1.0)
			glow_state = GlowState.STEADY
		else:
			brightness = 0.0  # Start invisible
			glow_state = GlowState.OFF
			
		pop_in_timer = randf_range(0.0, 5.0)  # Staggered pop-in
		pop_in_duration = randf_range(1.0, 2.0)

func _ready() -> void:
	add_to_group("star_field")
	
	# Get logger
	_logger = get_tree().get_first_node_in_group("game_logger")
	
	# Find camera
	var player = get_tree().get_first_node_in_group("player")
	_camera = player.get_node_or_null("Camera2D") if player else null
	
	# Generate star field
	_generate_star_field()
	
	_log_message("StarField initialized with " + str(star_count) + " stars", "Background")

func _generate_star_field():
	for i in range(star_count):
		var x = randf_range(-field_width/2, field_width/2)
		var y = randf_range(-field_height/2, field_height/2)
		var star_position = Vector2(x, y)
		var layer = StarLayer.values()[randi() % StarLayer.size()]
		
		var star_data = StarData.new(star_position, layer)
		_stars.append(star_data)
		
		# Create visual representation
		_create_star_sprite(star_data, i)

func _create_star_sprite(star_data: StarData, index: int):
	var sprite = Sprite2D.new()
	sprite.name = "Star_" + str(index)
	
	# Create star texture
	var texture = _create_star_texture(star_data.size, star_data.glow_state != GlowState.OFF)
	sprite.texture = texture
	
	# Set initial properties
	sprite.position = star_data.position
	sprite.modulate = star_data.base_color
	sprite.modulate.a = 0.0  # Start invisible
	
	add_child(sprite)
	_star_nodes.append(sprite)

func _create_star_texture(size: float, glowing: bool) -> ImageTexture:
	var texture_size = int(size * 4)  # Scale up for better quality
	var image = Image.create(texture_size, texture_size, false, Image.FORMAT_RGBA8)
	var center = Vector2(texture_size / 2.0, texture_size / 2.0)
	
	for y in range(texture_size):
		for x in range(texture_size):
			var pos = Vector2(x, y)
			var distance = pos.distance_to(center)
			
			if distance <= size * 2:
				var alpha = 0.0
				
				if glowing:
					# Glowing star with soft edges
					if distance <= size:
						alpha = 1.0
					elif distance <= size * 2:
						alpha = 1.0 - (distance - size) / size
				else:
					# Simple star
					if distance <= size * 0.5:
						alpha = 1.0
					elif distance <= size:
						alpha = 1.0 - (distance - size * 0.5) / (size * 0.5)
				
				var color = Color.WHITE
				color.a = alpha
				image.set_pixel(x, y, color)
	
	return ImageTexture.create_from_image(image)

func _process(delta: float) -> void:
	_update_stars(delta)
	_update_positions(delta)

func _update_stars(delta: float):
	for i in range(_stars.size()):
		var star = _stars[i]
		var sprite = _star_nodes[i]
		
		# Update pop-in effect
		if star.pop_in_timer > 0:
			star.pop_in_timer -= delta
			if star.pop_in_timer <= 0:
				star.glow_state = GlowState.FADE_IN
				star.glow_timer = 0.0
		
		# Update glow state
		_update_glow_state(star, delta)
		
		# Apply visual changes
		_apply_star_visuals(star, sprite)

func _update_glow_state(star: StarData, delta: float):
	star.glow_timer += delta
	
	match star.glow_state:
		GlowState.FADE_IN:
			star.brightness = min(1.0, star.glow_timer / 1.0)
			if star.glow_timer >= 1.0:
				star.glow_state = GlowState.STEADY
				star.glow_timer = 0.0
				star.glow_duration = randf_range(3.0, 8.0)
		
		GlowState.STEADY:
			if star.glow_timer >= star.glow_duration:
				star.glow_state = GlowState.FADE_OUT
				star.glow_timer = 0.0
		
		GlowState.FADE_OUT:
			star.brightness = max(0.0, 1.0 - star.glow_timer / 1.0)
			if star.glow_timer >= 1.0:
				star.glow_state = GlowState.OFF
				star.glow_timer = 0.0
				# Schedule next pop-in
				star.pop_in_timer = randf_range(5.0, 15.0)
		
		GlowState.PULSE:
			star.brightness = 0.5 + 0.5 * sin(star.glow_timer * star.pulse_speed)
			if star.glow_timer >= star.glow_duration:
				star.glow_state = GlowState.FADE_OUT
				star.glow_timer = 0.0
		
		GlowState.OFF:
			star.brightness = 0.0

func _apply_star_visuals(star: StarData, sprite: Sprite2D):
	# Update alpha based on brightness
	sprite.modulate.a = star.brightness
	
	# Update texture if glow state changed
	var should_glow = star.glow_state != GlowState.OFF and star.glow_state != GlowState.FADE_OUT
	var current_texture = sprite.texture
	var expected_size = star.size * (2.0 if should_glow else 1.0)
	
	# Recreate texture if size changed significantly
	if current_texture.get_size().x != expected_size * 4:
		sprite.texture = _create_star_texture(expected_size, should_glow)

func _update_positions(_delta: float):
	if not _camera:
		return
	
	var camera_pos = _camera.global_position
	var viewport_size = get_viewport().get_visible_rect().size
	
	for i in range(_stars.size()):
		var star = _stars[i]
		var sprite = _star_nodes[i]
		
		# Calculate parallax offset
		var parallax_offset = camera_pos * star.parallax_factor
		var target_position = star.position - parallax_offset
		
		# Wrap around screen edges
		var half_width = field_width / 2
		var half_height = field_height / 2
		
		if target_position.x < camera_pos.x - viewport_size.x/2 - half_width:
			target_position.x += field_width
		elif target_position.x > camera_pos.x + viewport_size.x/2 + half_width:
			target_position.x -= field_width
		
		if target_position.y < camera_pos.y - viewport_size.y/2 - half_height:
			target_position.y += field_height
		elif target_position.y > camera_pos.y + viewport_size.y/2 + half_height:
			target_position.y -= field_height
		
		sprite.position = target_position

# Public methods for runtime adjustment
func set_star_count(count: int):
	star_count = count
	_clear_stars()
	_generate_star_field()
	_log_message("Star count set to: " + str(count), "Background")

func set_field_size(width: float, height: float):
	field_width = width
	field_height = height
	_log_message("Field size set to: " + str(Vector2(width, height)), "Background")

func _clear_stars():
	for sprite in _star_nodes:
		sprite.queue_free()
	_stars.clear()
	_star_nodes.clear()

func _log_message(message: String, _system: String = "Background"):
	if _logger:
		_logger.log_background(message)
	elif enable_debug_logging:
		print("StarField: ", message)
