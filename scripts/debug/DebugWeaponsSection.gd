extends "res://scripts/DebugSection.gd"
class_name DebugWeaponsSection

var weapon_system: WeaponSystem
var current_weapon_display: Label
var fire_rate_slider: HSlider
var damage_slider: HSlider
var auto_fire_checkbox: CheckBox

func _init():
	super("Weapons")

func get_debug_content() -> Control:
	# Find weapon system
	if Engine.get_main_loop():
		var tree = Engine.get_main_loop() as SceneTree
		if tree:
			weapon_system = tree.get_first_node_in_group("weapon_system")
	
	var container = create_container(true, 6)
	
	# Current weapon info
	var weapon_info = create_section("Status")
	current_weapon_display = create_label("No weapon system")
	weapon_info.add_child(current_weapon_display)
	container.add_child(weapon_info)
	
	# Weapon switching - compact row
	var switch_section = create_section("Switch")
	var switch_row = create_container(false, 4)
	switch_row.add_child(create_button("Bullet", func(): _switch_weapon(0), "Switch to Bullet"))
	switch_row.add_child(create_button("Phaser", func(): _switch_weapon(1), "Switch to Phaser"))
	switch_section.add_child(switch_row)
	container.add_child(switch_section)
	
	# Fire controls - compact row
	var fire_section = create_section("Fire")
	var fire_row = create_container(false, 4)
	fire_row.add_child(create_button("Bullet", func(): _fire_weapon("bullet"), "Fire Bullet"))
	fire_row.add_child(create_button("Phaser", func(): _fire_phaser(), "Fire Phaser"))
	fire_section.add_child(fire_row)
	
	auto_fire_checkbox = create_checkbox("Auto-Fire")
	auto_fire_checkbox.add_theme_font_size_override("font_size", 11)
	auto_fire_checkbox.toggled.connect(_on_auto_fire_toggled)
	fire_section.add_child(auto_fire_checkbox)
	container.add_child(fire_section)
	
	# Weapon parameters - compact
	var params = create_section("Parameters")
	
	var rate_row = create_container(false, 4)
	rate_row.add_child(create_label("Rate:"))
	fire_rate_slider = create_slider(0.1, 2.0, 0.5, 0.1)
	fire_rate_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fire_rate_slider.value_changed.connect(_on_fire_rate_changed)
	rate_row.add_child(fire_rate_slider)
	params.add_child(rate_row)
	
	var dmg_row = create_container(false, 4)
	dmg_row.add_child(create_label("Dmg:"))
	damage_slider = create_slider(5, 50, 15, 5)
	damage_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	damage_slider.value_changed.connect(_on_damage_changed)
	dmg_row.add_child(damage_slider)
	params.add_child(dmg_row)
	
	container.add_child(params)
	
	_update_weapon_display()
	return container

func _switch_weapon(weapon_type: int):
	if weapon_system and weapon_system.has_method("switch_weapon"):
		weapon_system.switch_weapon(weapon_type)
		_update_weapon_display()
		log_message("Switched to weapon " + str(weapon_type))

func _fire_weapon(weapon_type: String):
	if not weapon_system:
		log_message("No weapon system found")
		return
	match weapon_type:
		"bullet":
			if weapon_system.has_method("_fire_bullet_manual"):
				weapon_system._fire_bullet_manual()
				log_message("Fired bullet")
		"phaser":
			_fire_phaser()
	_update_weapon_display()

func _fire_phaser():
	if not weapon_system:
		return
	if weapon_system.has_method("_fire_phaser"):
		var mouse_pos = Vector2(400, 300)  # Default position
		if Engine.get_main_loop():
			var tree = Engine.get_main_loop() as SceneTree
			if tree and tree.root:
				mouse_pos = tree.root.get_viewport().get_mouse_position()
		weapon_system._fire_phaser(mouse_pos, true)
		log_message("Fired phaser")

func _on_auto_fire_toggled(enabled: bool):
	if enabled:
		add_test_action("auto_fire_test", func(_params): _fire_weapon("bullet"))
		log_message("Auto-fire test enabled")
	else:
		test_actions.clear()
		log_message("Auto-fire test disabled")

func _on_fire_rate_changed(value: float):
	if weapon_system:
		# Update weapon fire rate (would need to be implemented in WeaponSystem)
		log_message("Fire rate changed to: " + str(value))

func _on_damage_changed(value: float):
	if weapon_system:
		# Update weapon damage (would need to be implemented in WeaponSystem)
		log_message("Damage changed to: " + str(value))

func _update_weapon_display():
	if weapon_system:
		var weapon_type = weapon_system.get_current_weapon_type()
		var weapon_name = "Bullet" if weapon_type == 0 else "Phaser"
		current_weapon_display.text = "Current: " + weapon_name + " | Auto: " + str(weapon_system.current_auto_weapon)
	else:
		current_weapon_display.text = "Weapon system not found"
