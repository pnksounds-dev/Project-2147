extends ParallaxBackground

class_name MenuBackground

## MenuBackground - Scrolling background for main menu
## Provides continuous right-to-left scrolling with configurable speed

@export var scroll_speed: float = 50.0  # Pixels per second
@export var base_texture_size: Vector2 = Vector2(2048, 2048)
@export var texture_scale_factor: float = 4.0
@export var enable_debug_logging: bool = false

var _parallax_layer: ParallaxLayer
var _sprite: Sprite2D
var _logger: Node
var _scroll_offset: float = 0.0

func _ready() -> void:
	add_to_group("menu_background")
	
	# Get logger
	_logger = get_tree().get_first_node_in_group("game_logger")
	
	# Get references with proper null checks
	_parallax_layer = get_node_or_null("ParallaxLayer")
	if not _parallax_layer:
		_log_message("ParallaxLayer not found! Creating default structure.", "MenuBackground")
		_create_default_structure()
		return
	
	_sprite = _parallax_layer.get_node_or_null("Sprite2D")
	if not _sprite:
		_log_message("Sprite2D not found! Creating default sprite.", "MenuBackground")
		_create_default_sprite()
		return
	
	# Set up initial texture tiling
	_setup_texture_tiling()
	
	# Start background scrolling
	set_process(true)
	
	_log_message("MenuBackground initialized with scroll speed: " + str(scroll_speed))

func _process(delta: float) -> void:
	if not _sprite:
		return
	
	# Update scroll offset
	_scroll_offset += scroll_speed * delta
	
	# Wrap around when we've scrolled one texture width
	if _scroll_offset >= base_texture_size.x:
		_scroll_offset -= base_texture_size.x
	
	# Apply scroll to sprite
	_update_sprite_position()

func _update_sprite_position():
	if not _sprite:
		return
	
	# Calculate the region rect position based on scroll offset
	var region_x = _scroll_offset
	_sprite.region_rect.position.x = region_x

func _create_default_structure():
	# Create ParallaxLayer
	_parallax_layer = ParallaxLayer.new()
	_parallax_layer.name = "ParallaxLayer"
	add_child(_parallax_layer)
	
	# Create sprite
	_create_default_sprite()

func _create_default_sprite():
	if not _parallax_layer:
		return
	
	_sprite = Sprite2D.new()
	_sprite.name = "Sprite2D"
	_parallax_layer.add_child(_sprite)
	
	# Set up a default texture if none exists
	if not _sprite.texture:
		_create_default_texture()
	
	# Set up texture tiling
	_setup_texture_tiling()

func _create_default_texture():
	# Create a simple noise texture as fallback
	var noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 0.02
	noise.seed = randi()
	
	var image = Image.create(int(base_texture_size.x), int(base_texture_size.y), false, Image.FORMAT_RGB8)
	
	for y in range(base_texture_size.y):
		for x in range(base_texture_size.x):
			var noise_val = noise.get_noise_2d(x, y)
			# Convert noise (-1 to 1) to grayscale (0 to 255)
			var gray = int((noise_val + 1.0) * 127.5)
			var color = Color(gray / 255.0, gray / 255.0, gray / 255.0)
			image.set_pixel(x, y, color)
	
	var texture = ImageTexture.create_from_image(image)
	_sprite.texture = texture
	
	_log_message("Created default noise texture for menu background")

func _setup_texture_tiling():
	if not _sprite or not _sprite.texture:
		return
	
	# Enable texture repeat
	_sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	
	# Calculate region size for seamless tiling
	var region_size = base_texture_size * texture_scale_factor
	_sprite.region_enabled = true
	_sprite.region_rect = Rect2(Vector2.ZERO, region_size)
	_sprite.centered = false
	_sprite.position = -region_size * 0.5
	
	# Set parallax motion scale (minimal for menu background)
	_parallax_layer.motion_scale = Vector2(0.1, 0.1)
	_parallax_layer.motion_mirroring = base_texture_size
	
	_log_message("Texture tiling set up for menu background")

# Public methods for runtime adjustment
func set_scroll_speed(speed: float) -> void:
	scroll_speed = speed
	_log_message("Menu background scroll speed set to: " + str(speed))

func get_scroll_speed() -> float:
	return scroll_speed

func set_texture_scale_factor(factor: float) -> void:
	texture_scale_factor = factor
	_setup_texture_tiling()
	_log_message("Menu background texture scale factor set to: " + str(factor))

func _log_message(message: String, _system: String = "MenuBackground"):
	if _logger:
		_logger.log_background(message)
	elif enable_debug_logging:
		print("MenuBackground: ", message)
