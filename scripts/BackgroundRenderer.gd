extends CanvasLayer

class_name BackgroundRenderer

# Manages the Ultra HD Background shader
# Can be toggled on/off for performance

@export var ultra_hd_enabled: bool = true:  # Enable by default for testing
	set(value):
		ultra_hd_enabled = value
		_update_shader_state()

@export var seamless_tiling_enabled: bool = true:
	set(value):
		seamless_tiling_enabled = value
		_update_shader_state()

@onready var _color_rect: ColorRect = $ColorRect
var _logger: Node
var _debug_timer: float = 0.0
var _debug_interval: float = 10.0  # Print every 10 seconds instead of 2, and only if debug enabled
var _debug_enabled: bool = false  # Disabled by default

func _ready() -> void:
	# Get logger
	_logger = get_tree().get_first_node_in_group("game_logger")
	
	add_to_group("background_renderer")
	layer = -90 # Ensure it's in front of ParallaxBackground (-100) but behind everything else
	if _debug_enabled:
		_log_message("_ready() called, layer: " + str(layer), "Background")
	_update_shader_state()

func _update_shader_state() -> void:
	if _debug_enabled:
		_log_message("Updating state. Enabled: " + str(ultra_hd_enabled) + ", Seamless: " + str(seamless_tiling_enabled), "Background")
	if _color_rect:
		var material = _color_rect.material as ShaderMaterial
		if material:
			material.set_shader_parameter("enabled", ultra_hd_enabled)
			material.set_shader_parameter("seamless_tiling", seamless_tiling_enabled)
			if _debug_enabled:
				_log_message("Shader parameters set - enabled: " + str(ultra_hd_enabled) + ", seamless_tiling: " + str(seamless_tiling_enabled), "Background")
		
		_color_rect.visible = ultra_hd_enabled
		if _debug_enabled:
			_log_message("ColorRect visible set to " + str(ultra_hd_enabled), "Background")
	
	# Toggle legacy ParallaxBackground to prevent overdraw and conflict
	var parallax = get_tree().get_first_node_in_group("parallax_bg")
	if not parallax:
		# Try finding by name in Main scene
		parallax = get_tree().root.find_child("ParallaxBackground", true, false)
	
	if parallax:
		parallax.visible = !ultra_hd_enabled
		if _debug_enabled:
			_log_message("ParallaxBackground visible set to " + str(!ultra_hd_enabled), "Background")
		
		# If enabling ultra HD, also disable the dynamic background scaling
		if ultra_hd_enabled and parallax.has_method("set_process"):
			parallax.set_process(false)
		elif not ultra_hd_enabled and parallax.has_method("set_process"):
			parallax.set_process(true)

func _process(delta: float) -> void:
	if not ultra_hd_enabled: return
	
	# Update debug timer
	_debug_timer += delta
	
	var player = get_tree().get_first_node_in_group("player")
	if player and _color_rect:
		var material = _color_rect.material as ShaderMaterial
		if material:
			material.set_shader_parameter("offset", player.global_position)
			
			# Debug: Check if shader is running (throttled and only if enabled)
			if _debug_enabled and _debug_timer >= _debug_interval:
				_log_message("Shader active, player pos: " + str(player.global_position), "Background")
				_debug_timer = 0.0
	elif not player:
		# Try to find player again next frame
		pass

func toggle_seamless_tiling(enabled: bool) -> void:
	seamless_tiling_enabled = enabled
	if _debug_enabled:
		_log_message("Seamless tiling toggled: " + str(enabled), "Background")

func toggle_ultra_hd(enabled: bool) -> void:
	if _debug_enabled:
		_log_message("toggle_ultra_hd called with " + str(enabled), "Background")
	ultra_hd_enabled = enabled

func _log_message(message: String, _system: String = "Background"):
	if _logger:
		_logger.log_debug(message)
	else:
		print("BackgroundRenderer: ", message)
