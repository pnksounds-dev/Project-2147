extends CanvasLayer

class_name GameHUD

# Core UI Elements
@onready var _health_bar: ProgressBar = $TopLeft/HealthBar
@onready var _xp_bar: ProgressBar = $TopLeft/XPBar
@onready var _level_label: Label = $TopLeft/LevelLabel
@onready var _score_label: Label = $TopRight/ScoreLabel
@onready var _coins_label: Label = $TopRight/CoinsLabel
@onready var _weapon_display: Control = $BottomRight/WeaponDisplay
@onready var _notification_manager: NotificationManager = $NotificationManager

# Weapon System
var weapon_system: Node
var current_weapon_index: int = 0
var _phaser_effect: ColorRect = null  # For phaser active visual effect

# Constants
const WEAPON_ICONS = ["🔫", "⚡", "💥", "🌌", "🔴"]
const WEAPON_NAMES = ["Auto Turret", "Photon Torpedoes", "Ballistic Barrage", "Void Magic", "Phasers"]

# Animation timers
var damage_flash_timer: Timer
var healing_effect_timer: Timer

signal weapon_switched(weapon_index: int)

func _ready():
	add_to_group("hud")
	add_to_group("notification_manager")  # For compatibility
	
	# Get weapon system reference
	weapon_system = get_tree().get_first_node_in_group("weapon_system")
	
	# Set up animations
	_setup_animations()
	
	# Connect weapon system if available
	if weapon_system:
		# Connect to all relevant weapon system signals
		if weapon_system.has_signal("weapon_switched"):
			weapon_system.weapon_switched.connect(_on_weapon_switched)
		if weapon_system.has_signal("weapon_fired"):
			weapon_system.weapon_fired.connect(_on_weapon_fired)
		if weapon_system.has_signal("phaser_started"):
			weapon_system.phaser_started.connect(_on_phaser_started)
		if weapon_system.has_signal("phaser_stopped"):
			weapon_system.phaser_stopped.connect(_on_phaser_stopped)
		
		print("HUD: Connected to WeaponSystem signals")
	else:
		print("HUD: WARNING - WeaponSystem not found")
	
	# Initialize UI
	_initialize_ui()
	
	print("HUD: Clean UI initialized")

func _initialize_ui():
	# Set initial values
	if _health_bar:
		_health_bar.value = 100
	if _xp_bar:
		_xp_bar.value = 0
	if _level_label:
		_level_label.text = "Lv.1"
	if _score_label:
		_score_label.text = "Score: 0"
	if _coins_label:
		_coins_label.text = "Coins: 0"
	
	# Update weapon display
	_update_weapon_display()

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

# Health Management
func update_health(current: int, maximum: int):
	if _health_bar:
		_health_bar.max_value = maximum
		_health_bar.value = current
		
		# Flash red when taking damage
		if current < _health_bar.value:
			_flash_damage()

func update_xp(current: int, required: int):
	if _xp_bar:
		_xp_bar.max_value = required
		_xp_bar.value = current

func update_level(level: int):
	if _level_label:
		_level_label.text = "Lv." + str(level)

# Score and Economy
func update_score(score: int):
	if _score_label:
		_score_label.text = "Score: " + str(score)

func update_coins(coins: int):
	if _coins_label:
		_coins_label.text = "Coins: " + str(coins)

# Weapon System
func switch_weapon(weapon_index: int):
	current_weapon_index = weapon_index
	_update_weapon_display()
	weapon_switched.emit(weapon_index)

func _update_weapon_display():
	if not _weapon_display:
		return
	
	# Clear existing display
	for child in _weapon_display.get_children():
		child.queue_free()
	
	# Create weapon slots
	for i in range(5):
		var slot = _create_weapon_slot(i)
		_weapon_display.add_child(slot)

func _create_weapon_slot(index: int) -> Control:
	var slot = Panel.new()
	slot.size = Vector2(50, 50)
	slot.custom_minimum_size = Vector2(50, 50)
	
	# Style the slot
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.2, 0.2, 0.2, 0.8)
	style_box.border_width_left = 2
	style_box.border_width_right = 2
	style_box.border_width_top = 2
	style_box.border_width_bottom = 2
	
	if index == current_weapon_index:
		style_box.bg_color = Color(0.4, 0.4, 0.2, 0.9)
		style_box.border_color = Color.YELLOW
	else:
		style_box.border_color = Color(0.5, 0.5, 0.5, 0.6)
	
	style_box.corner_radius_top_left = 4
	style_box.corner_radius_top_right = 4
	style_box.corner_radius_bottom_left = 4
	style_box.corner_radius_bottom_right = 4
	slot.add_theme_stylebox_override("panel", style_box)
	
	# Add weapon icon
	var icon_label = Label.new()
	icon_label.text = WEAPON_ICONS[index]
	icon_label.position = Vector2(15, 10)
	icon_label.add_theme_font_size_override("font_size", 20)
	slot.add_child(icon_label)
	
	# Add weapon name
	var name_label = Label.new()
	name_label.text = WEAPON_NAMES[index]
	name_label.position = Vector2(5, 35)
	name_label.add_theme_font_size_override("font_size", 8)
	name_label.add_theme_color_override("font_color", Color.GRAY)
	slot.add_child(name_label)
	
	return slot

func _on_weapon_switched(weapon_type: int):
	# Convert WeaponType enum to index
	var weapon_index = 0
	match weapon_type:
		0: weapon_index = 0  # BULLET -> Auto Turret
		1: weapon_index = 4  # PHASER -> Phasers
		_:
			weapon_index = 0
	
	switch_weapon(weapon_index)

# Visual Effects
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

# Notification System Integration
func show_notification(message: String, duration: float = 3.0):
	if _notification_manager:
		_notification_manager.show_notification("Notification", message, null, duration)
	else:
		print("HUD Notification: ", message)

# Compatibility Methods
func switch_weapon_from_inventory(weapon_type: int):
	_on_weapon_switched(weapon_type)

# --- PRIORITY 2: ENHANCED WEAPON SYSTEM INTEGRATION ---

func _on_weapon_fired(weapon_type: int):
	"""Handle weapon firing events"""
	print("HUD: Weapon fired: ", weapon_type)
	
	# Update weapon display with firing feedback
	if _weapon_display:
		var weapon_name = "Bullet" if weapon_type == 0 else "Phaser"
		_weapon_display.text = weapon_name + " 🔥"
		
		# Reset after short delay
		var timer = get_tree().create_timer(0.2)
		timer.timeout.connect(func(): 
			if _weapon_display:
				_weapon_display.text = weapon_name
		)

func _on_phaser_started():
	"""Handle phaser activation"""
	print("HUD: Phaser started")
	
	if _weapon_display:
		_weapon_display.text = "Phaser ⚡"
	
	# Show phaser active effect
	show_phaser_active_effect()

func _on_phaser_stopped():
	"""Handle phaser deactivation"""
	print("HUD: Phaser stopped")
	
	if _weapon_display:
		_weapon_display.text = "Phaser"

func show_phaser_active_effect():
	"""Show visual effect when phaser is active"""
	var effect = ColorRect.new()
	effect.color = Color.CYAN
	effect.color.a = 0.1
	effect.size = get_viewport().get_visible_rect().size
	effect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(effect)
	
	# Pulse effect
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(effect, "color:a", 0.2, 0.3)
	tween.tween_property(effect, "color:a", 0.05, 0.3)
	
	# Store reference to remove later
	_phaser_effect = effect

func hide_phaser_active_effect():
	"""Hide phaser active effect"""
	if _phaser_effect:
		_phaser_effect.queue_free()
		_phaser_effect = null
