extends "res://scripts/DebugSection.gd"
class_name DebugPerformanceSection

var performance_monitor: Node
var fps_display: Label
var memory_display: Label
var entity_display: Label

func _init():
	super("Performance")

func get_debug_content() -> Control:
	# Find performance monitor
	if Engine.get_main_loop():
		var tree = Engine.get_main_loop() as SceneTree
		if tree:
			performance_monitor = tree.get_first_node_in_group("performance_monitor")
	
	var container = create_container(true, 6)
	
	# Performance stats - compact
	var stats = create_section("Stats")
	fps_display = create_label("FPS: --")
	stats.add_child(fps_display)
	memory_display = create_label("Mem: -- MB")
	stats.add_child(memory_display)
	entity_display = create_label("Entities: --")
	stats.add_child(entity_display)
	container.add_child(stats)
	
	# Actions - compact row
	var actions = create_section("Actions")
	var btn_row = create_container(false, 4)
	btn_row.add_child(create_button("Load Test", func(): _generate_load(), "Generate load"))
	btn_row.add_child(create_button("Clear", func(): _clear_history(), "Clear history"))
	btn_row.add_child(create_button("GC", func(): _force_gc(), "Force GC"))
	actions.add_child(btn_row)
	container.add_child(actions)
	
	# Start update timer
	_start_update_timer()
	
	return container

func _start_update_timer():
	var timer = Timer.new()
	timer.wait_time = 0.5
	timer.autostart = true
	timer.timeout.connect(_update_display)
	add_child(timer)

func _update_display():
	# Always update FPS from engine
	var fps = Engine.get_frames_per_second()
	if fps_display:
		fps_display.text = "FPS: %d" % fps
	
	# Memory
	var mem_mb = OS.get_static_memory_usage() / 1024.0 / 1024.0
	if memory_display:
		memory_display.text = "Mem: %.1f MB" % mem_mb
	
	# Entity count
	if entity_display and Engine.get_main_loop():
		var tree = Engine.get_main_loop() as SceneTree
		if tree:
			var enemies = tree.get_nodes_in_group("enemy").size()
			var orbs = tree.get_nodes_in_group("orb").size()
			entity_display.text = "Enemies: %d | Orbs: %d" % [enemies, orbs]

func _generate_load():
	log_message("Generating load test...")
	for i in range(50):
		var node = Node.new()
		node.name = "LoadTest_" + str(i)
		add_child(node)
	
	if Engine.get_main_loop():
		var tree = Engine.get_main_loop() as SceneTree
		if tree:
			var timer = tree.create_timer(2.0)
			timer.timeout.connect(func():
				for child in get_children():
					if child.name.begins_with("LoadTest_"):
						child.queue_free()
				log_message("Load test done")
			)

func _clear_history():
	if performance_monitor and performance_monitor.has_method("reset_history"):
		performance_monitor.reset_history()
	log_message("History cleared")

func _force_gc():
	log_message("GC requested")
