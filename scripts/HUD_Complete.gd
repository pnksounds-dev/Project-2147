extends CanvasLayer

class_name CompleteHUD

# Health & Status - Will be created dynamically if missing
var health_bar: ProgressBar
var xp_bar: ProgressBar  
var level_label: Label
var message_label: Label
var notification_panel: Node

# Economy & Stats
var score_label: Label
var coins_label: Label
var skill_points_label: Label
var weapon_system: Node

# Animation timers
var damage_flash_timer: Timer
var healing_effect_timer: Timer

func _ready():
	print("HUD_Complete: Starting initialization...")
	add_to_group("hud")
	add_to_group("notification_manager")  # For compatibility
	
	# Get weapon system reference
	weapon_system = get_tree().get_first_node_in_group("weapon_system")
	print("HUD_Complete: Weapon system found: ", weapon_system != null)
	
	# Create missing HUD elements
	print("HUD_Complete: Creating missing elements...")
	_create_missing_elements()
	
	# Set up animations
	_setup_animations()
	
	print("Complete HUD: Initialized with full UI")
	
	# Test basic HUD elements
	_test_hud_elements()

func _test_hud_elements():
	print("HUD_Complete: Testing elements...")
	print("HUD_Complete: Health bar exists: ", health_bar != null)
	print("HUD_Complete: XP bar exists: ", xp_bar != null)
	print("HUD_Complete: Level label exists: ", level_label != null)
	
	# Test updating
	if health_bar:
		update_health(100, 100)
		print("HUD_Complete: Health updated")
	if xp_bar:
		update_xp(0, 100)
		print("HUD_Complete: XP updated")
	if level_label:
		update_level(1)
		print("HUD_Complete: Level updated")

func _create_missing_elements():
	# Create main Control if it doesn't exist
	if not has_node("Control"):
		var control = Control.new()
		control.name = "Control"
		control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(control)
	
	# Create health bar if it doesn't exist
	if not has_node("Control/HealthBar"):
		_create_health_bar()
	
	# Create XP bar if it doesn't exist
	if not has_node("Control/XPBar"):
		_create_xp_bar()
	
	# Create level label if it doesn't exist
	if not has_node("Control/LevelLabel"):
		_create_level_label()
	
	# Create economy display if it doesn't exist
	if not has_node("Control/ScoreLabel"):
		_create_economy_display()
	
	# Create skill points display if it doesn't exist
	if not has_node("Control/SkillPointsLabel"):
		_create_skill_points_display()
	
	# Create message label if it doesn't exist
	if not has_node("Control/MessageLabel"):
		_create_message_label()
	
	# Create notification panel if it doesn't exist
	if not has_node("NotificationPanel"):
		_create_notification_panel()
	
	# Create territory UI if it doesn't exist
	if not has_node("TerritoryUI"):
		_create_territory_ui()

	# Create keybind hints if they don't exist
	if not has_node("Control/KeybindHints"):
		_create_keybind_hints()

func _create_health_bar():
	health_bar = ProgressBar.new()
	health_bar.name = "HealthBar"
	# Top Left
	health_bar.position = Vector2(20, 20)
	health_bar.size = Vector2(200, 20)
	health_bar.modulate = Color(1, 0.2, 0.2, 1)
	health_bar.show_percentage = false
	health_bar.max_value = 100
	health_bar.value = 100
	$Control.add_child(health_bar)

func _create_xp_bar():
	xp_bar = ProgressBar.new()
	xp_bar.name = "XPBar"
	# Below Health Bar
	xp_bar.position = Vector2(20, 45)
	xp_bar.size = Vector2(200, 10)
	xp_bar.modulate = Color(0.2, 0.8, 1, 1)
	xp_bar.show_percentage = false
	xp_bar.max_value = 100
	xp_bar.value = 0
	$Control.add_child(xp_bar)

func _create_level_label():
	level_label = Label.new()
	level_label.name = "LevelLabel"
	# Below XP Bar
	level_label.position = Vector2(20, 60)
	level_label.add_theme_font_size_override("font_size", 16)
	level_label.text = "Level: 1"
	$Control.add_child(level_label)

func _create_economy_display():
	# Create container for stats - Top Right
	var stats_container = VBoxContainer.new()
	stats_container.name = "StatsContainer"
	stats_container.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	stats_container.position = Vector2(-220, 20) # Offset from right
	stats_container.size = Vector2(200, 100)
	$Control.add_child(stats_container)
	
	# Score display
	score_label = Label.new()
	score_label.name = "ScoreLabel"
	score_label.add_theme_font_size_override("font_size", 16)
	score_label.add_theme_color_override("font_color", Color.WHITE)
	score_label.text = "Score: 0"
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stats_container.add_child(score_label)
	
	# Coins display
	coins_label = Label.new()
	coins_label.name = "CoinsLabel"
	coins_label.add_theme_font_size_override("font_size", 16)
	coins_label.add_theme_color_override("font_color", Color.GOLD)
	coins_label.text = "Coins: 0"
	coins_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stats_container.add_child(coins_label)

func _create_skill_points_display():
	# Add to stats container if it exists, otherwise create separate
	var container = $Control.get_node_or_null("StatsContainer")
	if container:
		skill_points_label = Label.new()
		skill_points_label.name = "SkillPointsLabel"
		skill_points_label.add_theme_font_size_override("font_size", 14)
		skill_points_label.add_theme_color_override("font_color", Color.CYAN)
		skill_points_label.text = "Skill Points: 0"
		skill_points_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		container.add_child(skill_points_label)
	else:
		# Fallback
		skill_points_label = Label.new()
		skill_points_label.name = "SkillPointsLabel"
		skill_points_label.position = Vector2(1000, 130)
		skill_points_label.text = "Skill Points: 0"
		$Control.add_child(skill_points_label)

func _create_message_label():
	message_label = Label.new()
	message_label.name = "MessageLabel"
	message_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	message_label.position = Vector2(0, 100) # Below territory info
	message_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	message_label.add_theme_font_size_override("font_size", 18)
	message_label.add_theme_color_override("font_color", Color.YELLOW)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.text = ""
	$Control.add_child(message_label)

func _create_notification_panel():
	notification_panel = preload("res://scenes/UI/NotificationPanel.tscn").instantiate()
	add_child(notification_panel)

func _create_territory_ui():
	var territory_ui = preload("res://scenes/UI/TerritoryUI.tscn").instantiate()
	# Position at Top Center
	territory_ui.set_anchors_preset(Control.PRESET_CENTER_TOP)
	# We need to access the internal container to center the text
	var vbox = territory_ui.get_node_or_null("VBoxContainer")
	if vbox:
		vbox.set_anchors_preset(Control.PRESET_CENTER_TOP)
		# Adjust margins/alignment
		for child in vbox.get_children():
			if child is Label:
				child.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	add_child(territory_ui)

func _create_keybind_hints():
	var hints_container = VBoxContainer.new()
	hints_container.name = "KeybindHints"
	# Bottom Right
	hints_container.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	hints_container.position = Vector2(-150, -120) # Offset from bottom right
	hints_container.size = Vector2(140, 100)
	$Control.add_child(hints_container)
	
	var hints = [
		"E - Inventory",
		"I - Skill Tree", 
		"M - Map",
		"1-5 - Weapons",
		"F1 - Debug"
	]
	
	for hint in hints:
		var label = Label.new()
		label.text = hint
		label.add_theme_font_size_override("font_size", 10)
		label.add_theme_color_override("font_color", Color(1, 1, 1, 0.5)) # Semi-transparent
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		hints_container.add_child(label)

func _setup_animations():
	# Create damage flash timer
	damage_flash_timer = Timer.new()
	damage_flash_timer.wait_time = 0.2
	damage_flash_timer.one_shot = true
	add_child(damage_flash_timer)
	
	# Create healing effect timer
	healing_effect_timer = Timer.new()
	healing_effect_timer.wait_time = 0.5
	healing_effect_timer.one_shot = true
	add_child(healing_effect_timer)

# Health and XP updates
func update_health(current: int, maximum: int):
	if health_bar:
		health_bar.max_value = maximum
		health_bar.value = current
		
		# Flash red when taking damage
		if current < health_bar.value:
			_flash_damage()

func update_xp(current: int, required: int):
	if xp_bar:
		xp_bar.max_value = required
		xp_bar.value = current

func update_level(level: int):
	if level_label:
		level_label.text = "Level: " + str(level)

# Economy updates
func update_score(score: int):
	if score_label:
		score_label.text = "Score: " + str(score)

func update_coins(coins: int):
	if coins_label:
		coins_label.text = "Coins: " + str(coins)

func update_skill_points(points: int):
	if skill_points_label:
		skill_points_label.text = "Skill Points: " + str(points)

# Visual effects
func _flash_damage():
	# Flash the screen red
	var flash = ColorRect.new()
	flash.color = Color.RED
	flash.color.a = 0.3
	flash.size = get_viewport().get_visible_rect().size
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)
	
	# Animate and remove
	var tween = create_tween()
	tween.tween_property(flash, "color:a", 0.0, 0.2)
	tween.tween_callback(flash.queue_free)

func show_healing_effect():
	# Show green healing flash
	var flash = ColorRect.new()
	flash.color = Color.GREEN
	flash.color.a = 0.2
	flash.size = get_viewport().get_visible_rect().size
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)
	
	# Animate and remove
	var tween = create_tween()
	tween.tween_property(flash, "color:a", 0.0, 0.3)
	tween.tween_callback(flash.queue_free)

# Message system
func show_message(message: String, duration: float = 3.0):
	if message_label:
		message_label.text = message
		var timer = get_tree().create_timer(duration)
		timer.timeout.connect(func(): message_label.text = "")

# Notification compatibility
func show_notification(message: String, duration: float = 3.0):
	if notification_panel:
		notification_panel.show_notification(message)
	else:
		show_message(message, duration)
