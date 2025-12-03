extends CanvasLayer

class_name RadarHUD

# Radar display for bottom-left corner showing nearby enemies and items
# Includes toggleable expanded map view (press M)

@export var radar_size: Vector2 = Vector2(200, 200)
@export var radar_range: float = 1500.0  # World units shown on radar
@export var radar_margin: Vector2 = Vector2(20, 20)  # Padding from screen edges
@export var show_grid: bool = true

@export var map_range: float = 5000.0
@export var map_zoom_level: float = 1.0

# Map panning variables
var _map_drag_enabled: bool = false
var _map_drag_start_pos: Vector2 = Vector2.ZERO
var _map_offset: Vector2 = Vector2.ZERO
var _waypoint_manager: WaypointManager

var _player: Node2D = null
var _map_tracker: MapTracker = null
var _radar_panel: Control = null
var _radar_canvas: Control = null
var _map_panel: Control = null
var _map_canvas: Control = null
var _map_visible: bool = false
var _coords_label: Label = null

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_M: 
				_toggle_map()
				get_viewport().set_input_as_handled()
				return
			KEY_ESCAPE:
				if _map_visible:
					_toggle_map()
					get_viewport().set_input_as_handled()
					return
	
	if not _map_visible:
		return
		
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			zoom_in()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			zoom_out()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if _map_panel.get_global_rect().has_point(event.global_position):
				_show_waypoint_context_menu(event.global_position)
				get_viewport().set_input_as_handled()
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and _map_panel.get_global_rect().has_point(event.global_position):
			_map_drag_enabled = true
			_map_drag_start_pos = event.global_position
			get_viewport().set_input_as_handled()
		elif not event.pressed:
			_map_drag_enabled = false
	
	elif event is InputEventMouseMotion and _map_drag_enabled:
		if not _map_canvas:
			return
		var drag_delta = event.global_position - _map_drag_start_pos
		var world_delta = drag_delta * (map_range * map_zoom_level / _map_canvas.get_rect().size.x)
		_map_offset += world_delta
		_map_drag_start_pos = event.global_position
		_map_canvas.queue_redraw()
		get_viewport().set_input_as_handled()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = get_tree().get_first_node_in_group("player")
	_map_tracker = get_tree().get_first_node_in_group("map_tracker")
	add_to_group("radar_hud")
	layer = 15
	
	_waypoint_manager = WaypointManager.new()
	
	_create_radar_ui()
	_create_map_ui()

func _create_radar_ui() -> void:
	_radar_panel = Control.new()
	_radar_panel.name = "RadarPanel"
	_radar_panel.clip_contents = true # Fix clipping
	_radar_panel.custom_minimum_size = radar_size
	_radar_panel.anchor_left = 0.0
	_radar_panel.anchor_top = 1.0
	_radar_panel.anchor_right = 0.0
	_radar_panel.anchor_bottom = 1.0
	_radar_panel.offset_left = radar_margin.x
	_radar_panel.offset_right = radar_margin.x + radar_size.x
	_radar_panel.offset_bottom = -radar_margin.y
	_radar_panel.offset_top = -radar_margin.y - radar_size.y
	add_child(_radar_panel)
	
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.7)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_radar_panel.add_child(bg)
	
	_radar_canvas = Control.new()
	_radar_canvas.name = "RadarCanvas"
	_radar_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_radar_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_radar_panel.add_child(_radar_canvas)
	_radar_canvas.draw.connect(_on_radar_draw)

	_coords_label = Label.new()
	_coords_label.text = "X: 0 Y: 0"
	_coords_label.position = Vector2(6, 6)
	_radar_panel.add_child(_coords_label)

func _create_map_ui() -> void:
	_map_panel = Panel.new()
	_map_panel.name = "MapPanel"
	_map_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_map_panel.visible = false
	add_child(_map_panel)

	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.05, 0.07, 0.12, 0.95)
	_map_panel.add_theme_stylebox_override("panel", bg_style)

	_map_canvas = Control.new()
	_map_canvas.name = "MapCanvas"
	_map_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_map_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_panel.add_child(_map_canvas)
	_map_canvas.draw.connect(_on_map_draw)
	
	_create_controls()

func _create_controls() -> void:
	var controls = VBoxContainer.new()
	controls.position = Vector2(20, 20)
	_map_panel.add_child(controls)
	
	var title = Label.new()
	title.text = "STELLARIUM"
	title.add_theme_font_size_override("font_size", 24)
	controls.add_child(title)
	
	var help = Label.new()
	help.text = "Right-click to add waypoint\nScroll to zoom\nDrag to pan"
	controls.add_child(help)

var _redraw_timer: float = 0.0

func _process(delta: float) -> void:
	# Throttle redraws to 20 FPS to prevent CPU/GPU overload
	_redraw_timer -= delta
	if _redraw_timer <= 0:
		_redraw_timer = 0.05
		if _radar_canvas:
			_radar_canvas.queue_redraw()
		if _map_visible and _map_canvas:
			_map_canvas.queue_redraw()
	
	if _player and _coords_label:
		var p = _player.global_position
		_coords_label.text = "X: %d  Y: %d" % [int(p.x), int(p.y)]

func _on_radar_draw() -> void:
	_draw_scope(_radar_canvas, radar_range, false)

func _on_map_draw() -> void:
	_draw_scope(_map_canvas, map_range * map_zoom_level, true)

func _draw_scope(canvas: Control, range_units: float, is_map: bool) -> void:
	if not canvas or not _player: return
	
	var rect = canvas.get_rect()
	var center = rect.get_center()
	var scale_factor = rect.size.x / (range_units * 2)
	var player_pos = _player.global_position
	
	if is_map:
		center += _map_offset * scale_factor
	
	# Draw Grid
	if show_grid:
		var grid_size = 1000.0 * scale_factor
		var grid_offset = Vector2(fmod(player_pos.x, 1000.0), fmod(player_pos.y, 1000.0)) * scale_factor
		var lines = int(rect.size.x / grid_size) + 2
		var col = Color(0.3, 0.3, 0.3, 0.5)
		
		for i in range(-lines, lines):
			var x = center.x + i * grid_size - grid_offset.x
			var y = center.y + i * grid_size - grid_offset.y
			canvas.draw_line(Vector2(x, 0), Vector2(x, rect.size.y), col)
			canvas.draw_line(Vector2(0, y), Vector2(rect.size.x, y), col)

	# Draw Waypoints
	for wp in _waypoint_manager.waypoints:
		var rel = wp.world_position - player_pos
		var pos = center + rel * scale_factor
		if rect.has_point(pos):
			canvas.draw_circle(pos, 6, wp.color)
			if is_map:
				canvas.draw_string(ThemeDB.fallback_font, pos + Vector2(10, 0), wp.name)

	# Draw Entities
	if _map_tracker and is_instance_valid(_map_tracker):
		var entities = _map_tracker.get_nearby_entities()
		# Limit draw count to prevent GPU hang on massive counts
		var draw_count = 0
		for entity in entities:
			if draw_count > 1000: break
			draw_count += 1
			
			if not entity.has("last_pos") or not entity.has("color"): continue
			
			var rel = entity.last_pos - player_pos
			
			# Optimization: Don't calculate if way outside range
			if abs(rel.x) > range_units * 2 or abs(rel.y) > range_units * 2:
				continue
				
			var pos = center + rel * scale_factor
			if rect.has_point(pos):
				# Draw texture if available and we are zoomed in enough (or it's an Ark/Mothership)
				var drawn_texture = false
				if entity.has("texture") and entity.texture and (map_zoom_level < 2.0 or entity.type == "ark" or entity.type == "mothership"):
					var tex = entity.texture
					var tex_size = tex.get_size()
					var draw_scale = Vector2(0.5, 0.5) # Default scale down
					
					# Scale based on type
					if entity.type == "ark": draw_scale = Vector2(0.2, 0.2)
					elif entity.type == "mothership": draw_scale = Vector2(0.15, 0.15)
					elif entity.type == "orb": draw_scale = Vector2(0.5, 0.5)
					else: draw_scale = Vector2(0.1, 0.1) # Tiny ships
					
					# Adjust scale for map zoom
					if is_map:
						draw_scale *= (1.0 / map_zoom_level)
					
					var rot = entity.get("rotation", 0.0)
					
					canvas.draw_set_transform(pos, rot, draw_scale)
					canvas.draw_texture(tex, -tex_size / 2.0, entity.color) # Tint with faction color
					canvas.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE) # Reset transform
					drawn_texture = true
				
				if not drawn_texture:
					# Fallback to circle
					var radius = 4
					if entity.type == "ark": radius = 8
					elif entity.type == "orb": radius = 2
					
					canvas.draw_circle(pos, radius, entity.color)

	# Draw Player
	if _player.has_node("Sprite2D") and (map_zoom_level < 2.0 or not is_map):
		var tex = _player.get_node("Sprite2D").texture
		if tex:
			var tex_size = tex.get_size()
			var draw_scale = Vector2(0.1, 0.1)
			if is_map: draw_scale *= (1.0 / map_zoom_level)
			
			canvas.draw_set_transform(center, _player.rotation, draw_scale)
			canvas.draw_texture(tex, -tex_size / 2.0, Color.WHITE)
			canvas.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	else:
		canvas.draw_circle(center, 5, Color.GREEN)

func _toggle_map() -> void:
	_map_visible = !_map_visible
	_map_panel.visible = _map_visible
	if _map_visible:
		_map_offset = Vector2.ZERO
		get_tree().paused = true
	else:
		get_tree().paused = false

func zoom_in() -> void:
	map_zoom_level = max(0.1, map_zoom_level - 0.1)
	_map_canvas.queue_redraw()

func zoom_out() -> void:
	map_zoom_level = min(10.0, map_zoom_level + 0.1)
	_map_canvas.queue_redraw()

func _show_waypoint_context_menu(pos: Vector2) -> void:
	var world_pos = _screen_to_world(pos)
	_waypoint_manager.add_waypoint("Waypoint", world_pos)
	_map_canvas.queue_redraw()

func _screen_to_world(screen_pos: Vector2) -> Vector2:
	var rect = _map_canvas.get_rect()
	var center = rect.get_center()
	var scale_factor = rect.size.x / (map_range * map_zoom_level * 2)
	
	# Reverse transform
	var local = screen_pos - _map_panel.global_position
	var centered = local - center
	var unscaled = centered / scale_factor
	var unoffset = unscaled - _map_offset
	return _player.global_position + unoffset

# Inner Class
class WaypointManager:
	class Waypoint:
		var id: int
		var name: String
		var world_position: Vector2
		var color: Color
		func _init(_id, _name, _pos, _col):
			id = _id; name = _name; world_position = _pos; color = _col
	
	var waypoints: Array[Waypoint] = []
	var next_id: int = 0
	
	func add_waypoint(name: String, pos: Vector2, color: Color = Color.CYAN) -> void:
		waypoints.append(Waypoint.new(next_id, name, pos, color))
		next_id += 1
