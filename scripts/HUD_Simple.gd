extends CanvasLayer

# Simple HUD that always works
var health_label: Label
var level_label: Label
var score_label: Label
var coins_label: Label
var weapon_label: Label

func _ready():
	add_to_group("hud")
	add_to_group("notification_manager")  # For compatibility
	
	# Create simple UI elements
	_create_simple_ui()
	
	print("Simple HUD: Initialized")

func _create_simple_ui():
	# Health display
	health_label = Label.new()
	health_label.position = Vector2(20, 20)
	health_label.add_theme_font_size_override("font_size", 16)
	health_label.add_theme_color_override("font_color", Color.GREEN)
	health_label.text = "Health: 100/100"
	add_child(health_label)
	
	# Level display
	level_label = Label.new()
	level_label.position = Vector2(20, 45)
	level_label.add_theme_font_size_override("font_size", 14)
	level_label.add_theme_color_override("font_color", Color.YELLOW)
	level_label.text = "Level: 1"
	add_child(level_label)
	
	# Score display
	score_label = Label.new()
	score_label.position = Vector2(20, 70)
	score_label.add_theme_font_size_override("font_size", 14)
	score_label.add_theme_color_override("font_color", Color.WHITE)
	score_label.text = "Score: 0"
	add_child(score_label)
	
	# Coins display
	coins_label = Label.new()
	coins_label.position = Vector2(20, 95)
	coins_label.add_theme_font_size_override("font_size", 14)
	coins_label.add_theme_color_override("font_color", Color.GOLD)
	coins_label.text = "Coins: 0"
	add_child(coins_label)
	
	# Weapon display
	weapon_label = Label.new()
	weapon_label.position = Vector2(20, 120)
	weapon_label.add_theme_font_size_override("font_size", 14)
	weapon_label.add_theme_color_override("font_color", Color.CYAN)
	weapon_label.text = "Weapon: Auto Turret"
	add_child(weapon_label)

func update_health(current: int, maximum: int):
	if health_label:
		health_label.text = "Health: " + str(current) + "/" + str(maximum)

func update_xp(current: int, required: int):
	# Simple XP display in level label for now
	pass

func update_level(level: int):
	if level_label:
		level_label.text = "Level: " + str(level)

func update_score(score: int):
	if score_label:
		score_label.text = "Score: " + str(score)

func update_coins(coins: int):
	if coins_label:
		coins_label.text = "Coins: " + str(coins)

func switch_weapon(weapon_index: int):
	if weapon_label:
		var weapon_names = ["Auto Turret", "Photon Torpedoes", "Ballistic Barrage", "Void Magic", "Phasers"]
		if weapon_index < weapon_names.size():
			weapon_label.text = "Weapon: " + weapon_names[weapon_index]

func show_notification(message: String, duration: float = 3.0):
	# Create temporary notification
	var notification = Label.new()
	notification.position = Vector2(get_viewport().get_visible_rect().size.x / 2 - 200, 100)
	notification.size = Vector2(400, 50)
	notification.add_theme_font_size_override("font_size", 16)
	notification.add_theme_color_override("font_color", Color.WHITE)
	notification.text = message
	notification.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(notification)
	
	# Remove after duration
	var timer = get_tree().create_timer(duration)
	timer.timeout.connect(notification.queue_free)

# Compatibility methods
func _on_weapon_switched(weapon_type: int):
	var weapon_index = 0
	match weapon_type:
		0: weapon_index = 0  # BULLET -> Auto Turret
		1: weapon_index = 4  # PHASER -> Phasers
		_:
			weapon_index = 0
	switch_weapon(weapon_index)

func switch_weapon_from_inventory(weapon_type: int):
	_on_weapon_switched(weapon_type)
