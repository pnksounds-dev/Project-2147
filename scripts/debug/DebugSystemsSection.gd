extends "res://scripts/DebugSection.gd"
class_name DebugSystemsSection

var system_labels: Dictionary = {}

func _init():
	super("Systems")

func get_debug_content() -> Control:
	var container = create_container(true, 6)
	
	# System status - compact grid
	var status = create_section("Status")
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 2)
	
	var systems = ["Player", "Weapons", "Audio", "Inventory", "Perf"]
	for sys_name in systems:
		var key_lbl = create_label(sys_name + ":", Color.GRAY)
		var val_lbl = create_label("--", Color.WHITE)
		system_labels[sys_name] = val_lbl
		grid.add_child(key_lbl)
		grid.add_child(val_lbl)
	
	status.add_child(grid)
	container.add_child(status)
	
	# Actions - compact row
	var actions = create_section("Actions")
	var btn_row = create_container(false, 4)
	btn_row.add_child(create_button("Reload", func(): _reload_scene(), "Reload scene"))
	btn_row.add_child(create_button("Info", func(): _save_debug_info(), "Print debug info"))
	actions.add_child(btn_row)
	container.add_child(actions)
	
	# Update after added to tree
	_start_update_timer()
	
	return container

func _start_update_timer():
	var timer = Timer.new()
	timer.wait_time = 1.0
	timer.autostart = true
	timer.timeout.connect(_update_system_info)
	add_child(timer)

func _update_system_info():
	if not Engine.get_main_loop():
		return
	var tree = Engine.get_main_loop() as SceneTree
	if not tree:
		return
	
	var checks = {
		"Player": tree.get_first_node_in_group("player") != null,
		"Weapons": tree.get_first_node_in_group("weapon_system") != null,
		"Audio": tree.get_first_node_in_group("audio_manager") != null,
		"Inventory": tree.get_first_node_in_group("inventory_ui") != null,
		"Perf": tree.get_first_node_in_group("performance_monitor") != null
	}
	
	for sys_name in checks:
		if system_labels.has(sys_name):
			var found = checks[sys_name]
			system_labels[sys_name].text = "OK" if found else "N/A"
			system_labels[sys_name].add_theme_color_override("font_color", Color.GREEN if found else Color.RED)

func _reload_scene():
	if Engine.get_main_loop():
		var tree = Engine.get_main_loop() as SceneTree
		if tree:
			tree.reload_current_scene()
			log_message("Scene reloaded")

func _save_debug_info():
	var info = "Debug: FPS=%d Mem=%.1fMB" % [Engine.get_frames_per_second(), OS.get_static_memory_usage() / 1024.0 / 1024.0]
	print(info)
	log_message("Info printed to console")
