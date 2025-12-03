extends CanvasLayer

# Health & Status
@onready var health_bar = $Control/HealthBar
@onready var xp_bar = $Control/XPBar
@onready var level_label = $Control/LevelLabel
@onready var message_label = get_node_or_null("Control/MessageLabel")

# Cargo & Weapons
var cargo_system: Control
var weapon_slots: Array[Label] = []
var score_label: Label
var coins_label: Label
var skill_points_label: Label
var weapon_system: Node
var selected_weapon_index: int = 0

# Constants for weapon system
const MAX_WEAPON_SLOTS = 5
const WEAPON_ICONS = ["🔫", "⚡", "💥", "🌌", "🔴"]
const WEAPON_NAMES = ["Auto Turret", "Photon Torpedoes", "Ballistic Barrage", "Void Magic", "Phasers"]

# Animation timers
var damage_flash_timer: Timer
var healing_effect_timer: Timer

signal weapon_switched(weapon_index: int)

func _ready():
	add_to_group("hud")
	
	# Get weapon system reference
	weapon_system = get_tree().get_first_node_in_group("weapon_system")
	
	# Create missing HUD elements
	_create_missing_elements()
	
	# Set up animations
	_setup_animations()
	
	print("HUD: Initialized with weapon system integration")

func _create_missing_elements():
	# Create cargo/weapon system if it doesn't exist
	if not has_node("Control/CargoSystem"):
		_create_cargo_system()
	
	# Create economy display if it doesn't exist
	if not has_node("Control/ScoreLabel"):
		_create_economy_display()
	
	# Create skill points display if it doesn't exist
	if not has_node("Control/SkillPointsLabel"):
		_create_skill_points_display()

func _create_cargo_system():
	# Create cargo system container
	cargo_system = Control.new()
	cargo_system.name = "CargoSystem"
	cargo_system.position.x = 20
	cargo_system.position.y = 20
	cargo_system.size.x = 320
	cargo_system.size.y = 60
	$Control.add_child(cargo_system)
	
	# Create weapon slots
	for i in range(MAX_WEAPON_SLOTS):
		var slot = Label.new()
		slot.name = "WeaponSlot" + str(i)
		slot.text = WEAPON_ICONS[i] + " " + WEAPON_NAMES[i]
		slot.position.x = i * 64
		slot.size.x = 60
		slot.size.y = 40
		slot.add_theme_font_size_override("font_size", 10)
		slot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		
		# Style for slots
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.2, 0.2, 0.2, 0.8)
		style.border_color = Color(0.5, 0.5, 0.5, 1.0)
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_width_top = 2
		style.border_width_bottom = 2
		slot.add_theme_stylebox_override("normal", style)
		
		# Highlight first weapon by default
		if i == 0:
			style.border_color = Color.YELLOW
			style.border_width_left = 3
			style.border_width_right = 3
			style.border_width_top = 3
			style.border_width_bottom = 3
		
		cargo_system.add_child(slot)
		weapon_slots.append(slot)

func _create_economy_display():
	# Score display
	score_label = Label.new()
	score_label.name = "ScoreLabel"
	score_label.text = "Score: 0"
	score_label.position.x = -150
	score_label.position.y = 20
	score_label.size.x = 130
	score_label.size.y = 30
	score_label.add_theme_font_size_override("font_size", 16)
	score_label.modulate = Color.WHITE
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	$Control.add_child(score_label)
	
	# Coins display
	coins_label = Label.new()
	coins_label.name = "CoinsLabel"
	coins_label.text = "💰 0"
	coins_label.position.x = -150
	coins_label.position.y = 50
	coins_label.size.x = 130
	coins_label.size.y = 25
	coins_label.add_theme_font_size_override("font_size", 14)
	coins_label.modulate = Color.GOLD
	coins_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	coins_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	$Control.add_child(coins_label)

func _create_skill_points_display():
	# Skill points display
	skill_points_label = Label.new()
	skill_points_label.name = "SkillPointsLabel"
	skill_points_label.text = "SP: 0"
	skill_points_label.position.x = 20
	skill_points_label.position.y = 85
	skill_points_label.size.x = 100
	skill_points_label.size.y = 25
	skill_points_label.add_theme_font_size_override("font_size", 14)
	skill_points_label.modulate = Color.GREEN
	skill_points_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	skill_points_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	$Control.add_child(skill_points_label)

func _setup_animations():
	# Damage flash timer
	damage_flash_timer = Timer.new()
	damage_flash_timer.wait_time = 0.2
	damage_flash_timer.one_shot = true
	damage_flash_timer.timeout.connect(_on_damage_flash_end)
	add_child(damage_flash_timer)
	
	# Healing effect timer
	healing_effect_timer = Timer.new()
	healing_effect_timer.wait_time = 0.3
	healing_effect_timer.one_shot = true
	healing_effect_timer.timeout.connect(_on_healing_effect_end)
	add_child(healing_effect_timer)

# Health and XP updates
func update_health(current, maximum):
	if health_bar:
		health_bar.value = (current / maximum) * 100
		
		# Damage flash effect
		if current < maximum * 0.3:  # Low health warning
			health_bar.modulate = Color.RED
		else:
			health_bar.modulate = Color.WHITE
		
		# Screen damage flash
		if current < maximum:
			_show_damage_flash()

func update_xp(current, required):
	if xp_bar:
		xp_bar.value = (current / required) * 100

func update_level(level):
	if level_label:
		level_label.text = "Level " + str(level)
		_show_level_up_effect()

# Economy and skill updates
func update_score(score):
	if score_label:
		score_label.text = "Score: " + str(score)
		_create_popup_text("+" + str(score), Vector2(-100, 10), Color.CYAN)

func update_coins(coins):
	if coins_label:
		coins_label.text = "💰 " + str(coins)
		_create_popup_text("+" + str(coins), Vector2(-100, 40), Color.GOLD)

func update_skill_points(points):
	if skill_points_label:
		skill_points_label.text = "SP: " + str(points)
		_create_popup_text("+" + str(points) + " SP", Vector2(50, 85), Color.GREEN)

# Weapon system integration
func switch_weapon(weapon_index: int):
	if weapon_index < 0 or weapon_index >= weapon_slots.size():
		return
	
	selected_weapon_index = weapon_index
	
	# Update visual highlighting
	for i in range(weapon_slots.size()):
		var slot = weapon_slots[i]
		var style = slot.get_theme_stylebox("normal").duplicate()
		
		if i == weapon_index:
			style.border_color = Color.YELLOW
			style.border_width_left = 3
			style.border_width_right = 3
			style.border_width_top = 3
			style.border_width_bottom = 3
		else:
			style.border_color = Color(0.5, 0.5, 0.5, 1.0)
			style.border_width_left = 2
			style.border_width_right = 2
			style.border_width_top = 2
			style.border_width_bottom = 2
		
		slot.add_theme_stylebox_override("normal", style)
	
	# Notify weapon system
	if weapon_system and weapon_system.has_method("switch_weapon"):
		var weapon_type = 0  # Map HUD index to WeaponType
		match weapon_index:
			0: weapon_type = 0  # Auto Turret -> BULLET
			4: weapon_type = 1  # Phasers -> PHASER
			_: return  # Other weapons not implemented yet
		
		weapon_system.switch_weapon(weapon_type)
	
	weapon_switched.emit(weapon_index)
	print("HUD: Weapon switched to index ", weapon_index, " (", WEAPON_NAMES[weapon_index], ")")

func get_selected_weapon() -> String:
	return WEAPON_NAMES[selected_weapon_index]

# Visual effects
func _show_damage_flash():
	$Control.modulate = Color(1, 0.5, 0.5, 1)  # Red tint
	damage_flash_timer.start()

func _show_healing_effect():
	$Control.modulate = Color(0.5, 1, 0.5, 1)  # Green tint
	healing_effect_timer.start()

func _show_level_up_effect():
	if message_label:
		message_label.text = "LEVEL UP!"
		message_label.visible = true
		message_label.modulate = Color.CYAN
		
		var timer = Timer.new()
		timer.wait_time = 2.0
		timer.one_shot = true
		timer.timeout.connect(func(): message_label.visible = false)
		add_child(timer)
		timer.start()

func _on_damage_flash_end():
	$Control.modulate = Color.WHITE

func _on_healing_effect_end():
	$Control.modulate = Color.WHITE

func _create_popup_text(text: String, position: Vector2, color: Color):
	var popup = Label.new()
	popup.text = text
	popup.position = position
	popup.modulate = color
	popup.add_theme_font_size_override("font_size", 18)
	popup.z_index = 100
	
	# Animate popup
	var tween = create_tween()
	tween.parallel().tween_property(popup, "position:y", position.y - 30, 1.0)
	tween.parallel().tween_property(popup, "modulate:a", 0.0, 1.0)
	tween.tween_callback(popup.queue_free)
	
	$Control.add_child(popup)

# Input handling for weapon switching
func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode >= KEY_1 and event.keycode <= KEY_5:
			switch_weapon(event.keycode - KEY_1)
		elif event.keycode == KEY_Q:
			# Cycle weapons backward
			var new_index = selected_weapon_index - 1
			if new_index < 0:
				new_index = MAX_WEAPON_SLOTS - 1
			switch_weapon(new_index)
		elif event.keycode == KEY_E:
			# Cycle weapons forward
			var new_index = (selected_weapon_index + 1) % MAX_WEAPON_SLOTS
			switch_weapon(new_index)
