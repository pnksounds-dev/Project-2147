extends "res://scripts/DebugSection.gd"
class_name DebugPlayerSection

var player_node: Node2D
var health_slider: HSlider
var health_value_label: Label
var position_display: Label
var god_mode_checkbox: CheckBox

func _init():
	super("Player")

func get_debug_content() -> Control:
	# Try to find player
	if Engine.get_main_loop():
		var tree = Engine.get_main_loop() as SceneTree
		if tree:
			player_node = tree.get_first_node_in_group("player")
	
	var container = create_container(true, 6)
	
	# Player status section
	var status = create_section("Status")
	var player_info = create_label("Player: " + ("Found" if player_node else "Not Found"), Color.YELLOW if player_node else Color.RED)
	status.add_child(player_info)
	
	position_display = create_label("Pos: (0, 0)")
	status.add_child(position_display)
	container.add_child(status)
	
	# Health control section
	var health_section = create_section("Health")
	var health_row = create_container(false, 4)
	health_slider = create_slider(0, 200, 100, 10)
	health_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	health_slider.value_changed.connect(_on_health_changed)
	health_row.add_child(health_slider)
	health_value_label = create_label("100")
	health_row.add_child(health_value_label)
	health_section.add_child(health_row)
	
	god_mode_checkbox = create_checkbox("God Mode")
	god_mode_checkbox.add_theme_font_size_override("font_size", 11)
	god_mode_checkbox.toggled.connect(_on_god_mode_toggled)
	health_section.add_child(god_mode_checkbox)
	container.add_child(health_section)
	
	# Movement controls - compact button row
	var movement = create_section("Movement")
	var btn_row = create_container(false, 4)
	btn_row.add_child(create_button("Center", func(): _teleport_to_center(), "Teleport to (0,0)"))
	btn_row.add_child(create_button("To Mouse", func(): _teleport_to_mouse(), "Teleport to mouse"))
	btn_row.add_child(create_button("Stop", func(): _reset_velocity(), "Reset velocity"))
	movement.add_child(btn_row)
	container.add_child(movement)
	
	# Start update timer
	_start_update_timer()
	
	return container

func _start_update_timer():
	var timer = Timer.new()
	timer.wait_time = 0.2
	timer.autostart = true
	timer.timeout.connect(_update_display)
	add_child(timer)

func _update_display():
	if not is_instance_valid(player_node):
		# Try to find player again
		if Engine.get_main_loop():
			var tree = Engine.get_main_loop() as SceneTree
			if tree:
				player_node = tree.get_first_node_in_group("player")
	
	if player_node and position_display:
		position_display.text = "Pos: (%d, %d)" % [int(player_node.position.x), int(player_node.position.y)]

func _on_health_changed(value: float):
	if health_value_label:
		health_value_label.text = str(int(value))
	if player_node and player_node.has_method("set_health"):
		player_node.set_health(value)
		log_message("Health set to: " + str(int(value)))

func _on_god_mode_toggled(enabled: bool):
	if player_node and player_node.has_method("set_god_mode"):
		player_node.set_god_mode(enabled)
	log_message("God mode " + ("enabled" if enabled else "disabled"))

func _teleport_to_center():
	if player_node:
		player_node.position = Vector2.ZERO
		log_message("Teleported to center")

func _teleport_to_mouse():
	if player_node and Engine.get_main_loop():
		var tree = Engine.get_main_loop() as SceneTree
		if tree and tree.root:
			var viewport = tree.root.get_viewport()
			if viewport:
				player_node.global_position = viewport.get_mouse_position()
				log_message("Teleported to mouse")

func _reset_velocity():
	if player_node:
		if player_node.has_method("set_velocity"):
			player_node.set_velocity(Vector2.ZERO)
		elif "velocity" in player_node:
			player_node.velocity = Vector2.ZERO
		log_message("Velocity reset")
