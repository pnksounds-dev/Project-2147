extends ParallaxBackground

class_name DynamicBackground

## DynamicBackground - Scales background texture with camera zoom
## Provides seamless tiling at any zoom level

@export var base_texture_size: Vector2 = Vector2(2048, 2048)
@export var texture_scale_factor: float = 4.0  # How many tiles to show at base zoom
@export var zoom_scale_multiplier: float = 4.0  # How much to scale with zoom
@export var enable_debug_logging: bool = false  # Toggle debug output
@export var foreground_speed_multiplier: float = 2.0  # Foreground layer moves faster
@export var foreground_texture_scale: float = 2.0  # Foreground tiles smaller for detail
@export var enable_star_field: bool = true  # Enable procedural star field
@export var star_field_star_count: int = 200  # Number of stars to generate

var _parallax_layer: ParallaxLayer
var _foreground_layer: ParallaxLayer
var _sprite: Sprite2D
var _foreground_sprite: Sprite2D
var _camera: Camera2D
var _base_motion_scale: Vector2
var _logger: Node
var _last_zoom_level: float = 1.0
var _update_counter: int = 0
var _log_interval: int = 300  # Log every 300 frames (~5 seconds at 60fps)
var _star_field: StarField

func _ready() -> void:
	add_to_group("parallax_bg")
	
	# Get logger
	_logger = get_tree().get_first_node_in_group("game_logger")
	
	# Get references with proper null checks
	_parallax_layer = get_node_or_null("ParallaxLayer")
	if not _parallax_layer:
		_log_message("ParallaxLayer not found! Creating default structure.", "Background")
		_create_default_structure()
		return
	
	_sprite = _parallax_layer.get_node_or_null("Sprite2D")
	if not _sprite:
		_log_message("Sprite2D not found! Creating default sprite.", "Background")
		_create_default_sprite()
		return
	
	# Create foreground layer
	_create_foreground_layer()
	
	# Create star field if enabled
	if enable_star_field:
		_create_star_field()
	
	var player = get_tree().get_first_node_in_group("player")
	_camera = player.get_node_or_null("Camera2D") if player else null
	
	# Store original motion scale
	_base_motion_scale = _parallax_layer.motion_scale
	
	# Set up initial texture tiling
	_setup_texture_tiling()
	_setup_foreground_tiling()
	
	# Update background every frame
	set_process(true)
	
	_log_message("Initialized with texture_scale_factor: " + str(texture_scale_factor), "Background")

func _create_default_structure() -> void:
	# Create ParallaxLayer if it doesn't exist
	_parallax_layer = ParallaxLayer.new()
	_parallax_layer.name = "ParallaxLayer"
	_parallax_layer.motion_scale = Vector2(0.1, 0.1)
	add_child(_parallax_layer)
	
	_log_message("Created ParallaxLayer with motion_scale: " + str(_parallax_layer.motion_scale), "Background")
	
	# Create Sprite2D
	_create_default_sprite()

func _create_default_sprite() -> void:
	if not _parallax_layer:
		return
		
	_sprite = Sprite2D.new()
	_sprite.name = "Sprite2D"
	
	# Try to load the background texture
	var texture = load("res://assets/environment/backgrounds/MapArtSeemless.png")
	if texture:
		_sprite.texture = texture
		_sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		_sprite.region_enabled = true
	
	_parallax_layer.add_child(_sprite)
	
	_log_message("Created default background structure", "Background")

func _create_foreground_layer() -> void:
	# Create foreground parallax layer
	_foreground_layer = ParallaxLayer.new()
	_foreground_layer.name = "ForegroundLayer"
	_foreground_layer.z_index = 1  # In front of background
	add_child(_foreground_layer)
	
	# Create foreground sprite
	_foreground_sprite = Sprite2D.new()
	_foreground_sprite.name = "ForegroundSprite"
	
	# Try to load a different texture for foreground, or use the same with modifications
	var fg_texture = load("res://assets/environment/backgrounds/MapArtSeemless.png")
	if fg_texture:
		_foreground_sprite.texture = fg_texture
		_foreground_sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		_foreground_sprite.region_enabled = true
		# Make foreground semi-transparent for depth effect
		_foreground_sprite.modulate = Color(1.0, 1.0, 1.0, 0.3)
	
	_foreground_layer.add_child(_foreground_sprite)
	
	_log_message("Created foreground layer", "Background")

func _create_star_field() -> void:
	# Create star field as a child node
	_star_field = preload("res://scripts/StarField.gd").new()
	_star_field.name = "StarField"
	_star_field.star_count = star_field_star_count
	_star_field.enable_debug_logging = enable_debug_logging
	add_child(_star_field)
	
	_log_message("Created star field with " + str(star_field_star_count) + " stars", "Background")

func _setup_texture_tiling() -> void:
	if not _sprite:
		return
	
	# Enable texture repeating
	_sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_sprite.region_enabled = true
	
	# Calculate initial region size based on desired scale
	var region_size = base_texture_size * texture_scale_factor
	_sprite.region_rect = Rect2(Vector2.ZERO, region_size)
	
	# Set motion mirroring to match region size
	_parallax_layer.motion_mirroring = region_size
	
	# Set background motion scale (slower, for distant effect)
	_parallax_layer.motion_scale = Vector2(0.1, 0.1)
	
	_log_message("Set up texture tiling with region size: " + str(region_size), "Background")

func _setup_foreground_tiling() -> void:
	if not _foreground_sprite or not _foreground_layer:
		return
	
	# Enable texture repeating
	_foreground_sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_foreground_sprite.region_enabled = true
	
	# Calculate foreground region size (smaller tiles for more detail)
	var fg_region_size = base_texture_size * foreground_texture_scale
	_foreground_sprite.region_rect = Rect2(Vector2.ZERO, fg_region_size)
	
	# Set motion mirroring to match region size
	_foreground_layer.motion_mirroring = fg_region_size
	
	# Set foreground motion scale (faster, for closer effect)
	_foreground_layer.motion_scale = Vector2(0.3, 0.3) * foreground_speed_multiplier
	
	_log_message("Set up foreground tiling with region size: " + str(fg_region_size), "Background")

func _process(_delta: float) -> void:
	if not _camera or not _sprite or not _parallax_layer:
		# Try to find camera again in case it wasn't ready initially
		if not _camera:
			var player = get_tree().get_first_node_in_group("player")
			if player:
				_camera = player.get_node_or_null("Camera2D")
		return
	
	# Calculate zoom-based scaling
	var zoom_level = _camera.zoom.x  # Assume uniform zoom
	print("DEBUG: Background sees zoom level as: ", zoom_level)
	var scaled_region_size = base_texture_size * texture_scale_factor * (1.0 + zoom_level * zoom_scale_multiplier)
	
	# Update background sprite region
	_sprite.region_rect = Rect2(Vector2.ZERO, scaled_region_size)
	
	# Update background motion mirroring to match
	_parallax_layer.motion_mirroring = scaled_region_size
	
	# Adjust background motion scale based on zoom for parallax effect
	# Higher zoom = less parallax (background moves less)
	var parallax_factor = 1.0 / (1.0 + zoom_level * 0.2)  # Reduced zoom impact
	_parallax_layer.motion_scale = Vector2(0.5, 0.5) * parallax_factor  # Increased base motion
	
	# Update foreground layer if it exists
	if _foreground_sprite and _foreground_layer:
		var fg_scaled_region_size = base_texture_size * foreground_texture_scale * (1.0 + zoom_level * zoom_scale_multiplier)
		_foreground_sprite.region_rect = Rect2(Vector2.ZERO, fg_scaled_region_size)
		_foreground_layer.motion_mirroring = fg_scaled_region_size
		
		# Foreground moves faster and is less affected by zoom
		var fg_parallax_factor = 1.0 / (1.0 + zoom_level * 0.1)  # Much less zoom reduction
		_foreground_layer.motion_scale = Vector2(0.8, 0.8) * foreground_speed_multiplier * fg_parallax_factor  # Increased foreground motion
	
	# Log debug info periodically (reduced frequency)
	_update_counter += 1
	if enable_debug_logging and _update_counter >= _log_interval:
		_update_counter = 0
		if abs(zoom_level - _last_zoom_level) > 0.01:  # Only log if zoom changed significantly
			_log_debug_info(zoom_level, scaled_region_size)
		_last_zoom_level = zoom_level

func _log_debug_info(zoom_level: float, region_size: Vector2):
	var debug_info = "Zoom: %.2f, Region: %s, Motion: %s" % [
		zoom_level, 
		region_size, 
		_parallax_layer.motion_scale
	]
	_log_message(debug_info, "Background")

func _log_message(message: String, _system: String = "Background"):
	if _logger:
		_logger.log_background(message)
	elif enable_debug_logging:
		print("DynamicBackground: ", message)

func get_debug_info() -> Dictionary:
	var info = {
		"base_texture_size": base_texture_size,
		"texture_scale_factor": texture_scale_factor,
		"foreground_speed_multiplier": foreground_speed_multiplier,
		"foreground_texture_scale": foreground_texture_scale,
		"enable_star_field": enable_star_field,
		"star_field_star_count": star_field_star_count,
		"current_zoom": _camera.zoom.x if _camera else 1.0,
		"background_region_size": _sprite.region_rect.size if _sprite else Vector2.ZERO,
		"foreground_region_size": _foreground_sprite.region_rect.size if _foreground_sprite else Vector2.ZERO,
		"background_motion_scale": _parallax_layer.motion_scale if _parallax_layer else Vector2.ZERO,
		"foreground_motion_scale": _foreground_layer.motion_scale if _foreground_layer else Vector2.ZERO
	}
	
	# Add star field info if available
	if _star_field:
		info["star_field_active"] = true
		info["star_field_star_count_actual"] = _star_field.star_count
	else:
		info["star_field_active"] = false
	
	return info

# Public methods for runtime adjustment
func set_texture_scale_factor(factor: float) -> void:
	texture_scale_factor = factor
	_setup_texture_tiling()
	_log_message("Texture scale factor set to: " + str(factor), "Background")

func set_foreground_speed_multiplier(multiplier: float) -> void:
	foreground_speed_multiplier = multiplier
	_setup_foreground_tiling()
	_log_message("Foreground speed multiplier set to: " + str(multiplier), "Background")

func set_foreground_texture_scale(texture_scale_value: float) -> void:
	foreground_texture_scale = texture_scale_value
	_setup_foreground_tiling()
	_log_message("Foreground texture scale set to: " + str(texture_scale_value), "Background")

func set_zoom_scale_multiplier(multiplier: float) -> void:
	zoom_scale_multiplier = multiplier
	_log_message("Zoom scale multiplier set to: " + str(multiplier), "Background")

func set_base_texture_size(size: Vector2) -> void:
	base_texture_size = size
	_setup_texture_tiling()
	_setup_foreground_tiling()
	_log_message("Base texture size set to: " + str(size), "Background")

# Star field control methods
func set_star_field_enabled(enabled: bool) -> void:
	enable_star_field = enabled
	if enabled and not _star_field:
		_create_star_field()
	elif not enabled and _star_field:
		_star_field.queue_free()
		_star_field = null
	_log_message("Star field " + ("enabled" if enabled else "disabled"), "Background")

func set_star_count(count: int) -> void:
	star_field_star_count = count
	if _star_field:
		_star_field.set_star_count(count)
	_log_message("Star count set to: " + str(count), "Background")

func set_debug_logging(enabled: bool):
	enable_debug_logging = enabled
	if _star_field:
		_star_field.enable_debug_logging = enabled
	_log_message("Debug logging " + ("enabled" if enabled else "disabled"), "Background")
