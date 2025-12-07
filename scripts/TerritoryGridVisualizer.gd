extends Node2D

var _territory_manager: TerritoryManager
var _chunk_manager: ChunkManager
var _faction_manager: FactionManager

func _ready() -> void:
	z_index = -10
	z_as_relative = false
	_update_references()
	set_process(true)

func _process(_delta: float) -> void:
	queue_redraw()

func _update_references() -> void:
	if not _territory_manager:
		_territory_manager = get_tree().get_first_node_in_group("territory_manager")
	if not _chunk_manager:
		_chunk_manager = get_tree().get_first_node_in_group("chunk_manager")
	if not _faction_manager:
		_faction_manager = get_tree().get_first_node_in_group("faction_manager")

func _is_enabled() -> bool:
	# Always enabled for now; allow future graphics toggle via SettingsManager
	var settings_manager = get_node_or_null("/root/SettingsManager")
	if settings_manager and settings_manager.has_method("get_setting"):
		return settings_manager.get_setting("graphics.territory_grid_enabled", true)
	return true

func _draw() -> void:
	if not _is_enabled():
		return
	
	if not _territory_manager or not _chunk_manager or not _faction_manager:
		_update_references()
	
	if not _territory_manager or not _chunk_manager:
		return
	
	var active_chunks: Array = _chunk_manager.get_active_chunks()
	for chunk_coords in active_chunks:
		var territory: Dictionary = _territory_manager.get_territory_at_chunk(chunk_coords)
		if territory.is_empty():
			continue
		
		var faction_id: String = territory.get("faction", FactionManager.FACTION_NEUTRAL)
		var base_color: Color = _faction_manager.get_faction_color(faction_id) if _faction_manager else Color(0.5, 0.5, 0.5, 1.0)
		
		var rect: Rect2 = _chunk_manager.get_chunk_bounds(chunk_coords)
		
		# Fill
		var fill_color: Color = base_color
		fill_color.a = 0.1
		draw_rect(rect, fill_color, true)
		
		# Determine if this is a border chunk (neighbor is empty or different faction)
		var is_border := false
		var neighbor_dirs = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
		for dir in neighbor_dirs:
			var neighbor_chunk: Vector2i = chunk_coords + dir
			var neighbor_territory: Dictionary = _territory_manager.get_territory_at_chunk(neighbor_chunk)
			if neighbor_territory.is_empty() or neighbor_territory.get("faction", "") != faction_id:
				is_border = true
				break
		
		if is_border:
			var border_color: Color = base_color
			border_color.a = 0.9
			draw_rect(rect, border_color, false, 2.0)
