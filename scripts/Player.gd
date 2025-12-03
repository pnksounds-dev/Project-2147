extends CharacterBody2D

signal health_changed(current_health, max_health)
signal xp_changed(current_xp, xp_required)
signal level_changed(level)

# Weapon system
const WeaponManager = preload("res://scripts/weapons/WeaponManager.gd")
const WeaponBase = preload("res://scripts/weapons/WeaponBase.gd")

@export var speed = 300.0
@export var acceleration = 800.0
@export var friction = 80.0
@export var fire_rate = 0.5

#next code
var level = 1
var current_xp = 0
var xp_required = 100
var skill_points = 0
var max_health = 100.0
var current_health = max_health
var is_dead = false
var current_weapon_slot_item: Dictionary
var _input_log_timer := 0.0
const DEBUG_PLAYER_INPUT_LOG := false
const DEBUG_PLAYER_EVENTS := false

@onready var camera = $Camera2D

var scout_scene = load("res://scenes/Scout.tscn")
# Weapon system
var weapon_manager: WeaponManager = null
var _inventory_state: InventoryState = null

# FOV zoom variables
var fov_min: float = 1.0
var fov_max: float = 360.0
var current_fov: float = 75.0
var zoom_speed: float = 5.0  # FOV change per scroll step

func _ready():
	GameLog.log_player("Player initialized")
	
	add_to_group("player")
	
	# Set up collision layers for proper detection
	collision_layer = 1  # Player layer
	collision_mask = 2   # Detect enemies (layer 2) - projectiles detect player, not vice versa
	
	# Initialize weapon system
	_setup_weapon_system()
	# Cache reference to unified WeaponSystem for Phaser handling
	_weapon_system = null
	
	# Initialize coin system
	_initialize_coin_system()
	
	# Initialize FOV from settings or use default
	_initialize_fov()
	
	# Emit initial stats
	health_changed.emit(current_health, max_health)
	xp_changed.emit(current_xp, xp_required)
	level_changed.emit(level)

## Set up the weapon manager (inventory-driven weapons)
func _setup_weapon_system() -> void:
	if weapon_manager:
		weapon_manager.queue_free()

	weapon_manager = WeaponManager.new()
	weapon_manager.name = "WeaponManager"
	add_child(weapon_manager)
	weapon_manager.set_weapon_owner(self)
	weapon_manager.weapon_switched.connect(_on_weapon_switched)
	weapon_manager.weapon_fired.connect(_on_weapon_fired)
	weapon_manager.weapon_reloaded.connect(_on_weapon_reloaded)
	weapon_manager.weapon_state_changed.connect(_on_weapon_state_changed)
	_inventory_state = get_tree().get_first_node_in_group("inventory")

## Lazy getter for the unified WeaponSystem (used for Phaser firing)
var _weapon_system = null

func _get_weapon_system():
	if _weapon_system == null:
		_weapon_system = get_tree().get_first_node_in_group("weapon_system")
	return _weapon_system

func _debug_player_scale():
	# Calculate player size on screen
	var collision_shape = $CollisionShape2D.shape as CapsuleShape2D
	if not collision_shape:
		print("Player: CollisionShape2D not found for debug")
		return
	
	# For capsule shape, use the larger of radius or height/2 for approximate size
	var capsule_radius = collision_shape.radius
	var capsule_height = collision_shape.height
	var effective_radius = max(capsule_radius, capsule_height / 2.0)
	var player_diameter = effective_radius * 2
	
	print("Player: World scale debug:")
	print("  - Capsule radius: ", capsule_radius, "px")
	print("  - Capsule height: ", capsule_height, "px")
	print("  - Effective radius: ", effective_radius, "px")
	print("  - Player diameter: ", player_diameter, "px")
	print("  - Viewport: 1280x720")

func _initialize_coin_system():
	# Create coin system
	var coin_system = load("res://scripts/PlayerCoins.gd").new()
	coin_system.name = "PlayerCoins"
	add_child(coin_system)
	
	# Connect coin signals
	coin_system.coins_changed.connect(_on_coins_changed)
	
	print("Player: Coin system initialized")

func spawn_scouts():
	for i in range(2):
		var scout = scout_scene.instantiate()
		scout.target_node = self
		scout.nearby_distance = 180.0
		scout.speed = 250.0
		get_parent().call_deferred("add_child", scout)

func take_damage(amount):
	if is_dead: return
	current_health -= amount
	health_changed.emit(current_health, max_health)
	GameLog.log_combat("Player took damage: %d, Health: %d" % [amount, current_health])
	print("Player Health: ", current_health)
	if current_health <= 0:
		die()

func die():
	is_dead = true
	GameLog.log_combat("Player Died!")
	print("Player Died! Respawning...")
	visible = false
	# Disable collision
	$CollisionShape2D.set_deferred("disabled", true)
	
	# Respawn after delay
	await get_tree().create_timer(3.0).timeout
	respawn()

func respawn():
	is_dead = false
	current_health = max_health * 0.5 # Respawn with 50% health
	health_changed.emit(current_health, max_health)
	visible = true
	$CollisionShape2D.set_deferred("disabled", false)
	
	# Apply skill system health boosts
	var skill_system = get_tree().get_first_node_in_group("skill_system")
	if skill_system:
		var health_boost = skill_system.get_skill_effect("health_boost")
		if health_boost > 0:
			max_health += int(health_boost)
			current_health = max_health * 0.5
			print("Player: Applied skill health boost on respawn")

func gain_xp(amount):
	current_xp += amount
	xp_changed.emit(current_xp, xp_required)
	
	# Award score for XP gain
	var score_tracker = get_tree().get_first_node_in_group("score_tracker")
	if score_tracker:
		score_tracker.add_score(amount / 10)  # 1 score per 10 XP
	
	if current_xp >= xp_required:
		level_up()
	print("XP: ", current_xp, "/", xp_required)

func level_up():
	level += 1
	current_xp -= xp_required
	xp_required = int(xp_required * 1.2)
	level_changed.emit(level)
	print("Level Up! Level: ", level)
	
	# Award bonus score for level up
	var score_tracker = get_tree().get_first_node_in_group("score_tracker")
	if score_tracker:
		score_tracker.add_level_up_bonus()
		print("Player: Awarded level up bonus score")
	
	# Award coins for level up
	var economy_system = get_tree().get_first_node_in_group("economy_system")
	if economy_system:
		economy_system.add_level_coin_bonus()
		print("Player: Awarded level up coin bonus")
	
	# Apply skill system effects
	var skill_system = get_tree().get_first_node_in_group("skill_system")
	if skill_system:
		skill_system.award_level_up_points()
		print("Player: Awarded skill point for level up")
	
	# Apply passive skill boosts
	_apply_skill_boosts()

func _apply_skill_boosts():
	var skill_system = get_tree().get_first_node_in_group("skill_system")
	if not skill_system:
		return
	
	# Apply speed boost
	var speed_boost = skill_system.get_skill_effect("speed_boost")
	if speed_boost > 0:
		speed = 300.0 * (1.0 + speed_boost)
		print("Player: Applied speed boost: ", speed_boost)
	
	# Apply fire rate boost
	var fire_rate_boost = skill_system.get_skill_effect("fire_rate_boost")
	if fire_rate_boost > 0:
		fire_rate = 0.5 * (1.0 - fire_rate_boost)  # Reduce fire rate for faster shooting
		print("Player: Applied fire rate boost: ", fire_rate_boost)

# Add enemy kill tracking
func on_enemy_killed(enemy_type: String):
	# Award score for enemy kill
	var score_tracker = get_tree().get_first_node_in_group("score_tracker")
	if score_tracker:
		var points_earned = score_tracker.add_enemy_kill(enemy_type)
		print("Player: Enemy killed - ", enemy_type, ", earned ", points_earned, " points")
	
	# Award coins for enemy kill
	var economy_system = get_tree().get_first_node_in_group("economy_system")
	if economy_system:
		var coins_earned = economy_system.add_enemy_coin_drop(enemy_type)
		print("Player: Enemy killed - ", enemy_type, ", earned ", coins_earned, " coins")

# Add coin pickup tracking
func on_coin_pickup(amount: int = 1):
	var economy_system = get_tree().get_first_node_in_group("economy_system")
	if economy_system:
		economy_system.add_coins(amount)
		print("Player: Picked up ", amount, " coins")
	
	# Award score for coin pickup
	var score_tracker = get_tree().get_first_node_in_group("score_tracker")
	if score_tracker:
		score_tracker.add_coin_pickup()
		print("Player: Awarded score for coin pickup")

func _input(event: InputEvent) -> void:
	# Handle weapon firing
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				var mouse_pos = get_global_mouse_position()
				var weapon_system = _get_weapon_system()
				if weapon_system and weapon_system.has_method("_fire_phaser"):
					weapon_system._fire_phaser(mouse_pos, true)
			else:
				var weapon_system = _get_weapon_system()
				if weapon_system and weapon_system.has_method("stop_phaser"):
					weapon_system.stop_phaser()
	
	# Weapon switching with number keys
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				weapon_manager.set_current_weapon_index(0)
			KEY_2:
				weapon_manager.set_current_weapon_index(1)
			KEY_3:
				weapon_manager.set_current_weapon_index(2)
			KEY_R:
				weapon_manager.reload_weapon()
	
func _physics_process(delta: float) -> void:
	# Update debug timers
	_input_log_timer += delta
	
	# Update weapon system
	if weapon_manager:
		weapon_manager.update(delta)
	
	# Handle player movement
	if not is_dead:
		var input_direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		velocity = input_direction * speed
		
		# Debug input (optional)
		if DEBUG_PLAYER_INPUT_LOG and _input_log_timer >= 1.0:
			print("Player: Input direction: ", input_direction, " length: ", input_direction.length())
		
		# Handle player rotation based on movement direction with smoothing
		if input_direction.length() > 0.1:
			# Calculate target rotation (adjust for north-facing texture)
			# Godot's 0 radians = right, so north (up) = -PI/2 or 3*PI/2
			var target_rotation = input_direction.angle() + PI/2  # Adjust for north-facing texture
			
			# Smooth rotation interpolation
			var rotation_speed = 10.0  # Adjust for faster/slower rotation
			global_rotation = lerp_angle(global_rotation, target_rotation, rotation_speed * delta)
			
			if DEBUG_PLAYER_INPUT_LOG and _input_log_timer >= 1.0:
				print("Player: Target rotation: ", target_rotation, " radians (", rad_to_deg(target_rotation), " degrees)")
				print("Player: Current rotation: ", global_rotation, " radians (", rad_to_deg(global_rotation), " degrees)")
		else:
			if DEBUG_PLAYER_INPUT_LOG and _input_log_timer >= 1.0:
				print("Player: No movement input detected")
			_input_log_timer = 0.0
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

	move_and_slide()
	
	# Check for nearby interactable objects and show/hide interaction prompt
	_update_interaction_prompt()

func _unhandled_input(event):
	# Handle inventory toggle
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_E:
			_toggle_inventory()
			return
		elif event.keycode == KEY_F:
			_handle_interaction()
			return
	
	# Handle FOV zoom with mouse wheel
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_in()
			return
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_out()
			return

func _get_weapon_slot_item() -> Dictionary:
	var inventory_state = _get_inventory_state()
	if not inventory_state:
		return {}
	return inventory_state.get_equipped_item(InventoryState.SlotType.WEAPON1)

func _get_inventory_state() -> InventoryState:
	if _inventory_state == null:
		_inventory_state = get_tree().get_first_node_in_group("inventory")
	return _inventory_state

func _get_weapon_keyword(item_id: String) -> String:
	match item_id.to_lower():
		"auto_turret":
			return "turret"
		"turret":
			return "turret"
		"phasers":
			return "phaser"
		"phaser":
			return "phaser"
		_:
			return item_id.to_lower()

func _toggle_inventory():
	var inventory_ui = get_tree().get_first_node_in_group("inventory_ui")
	if inventory_ui and inventory_ui.has_method("toggle_inventory"):
		inventory_ui.toggle_inventory()

func _on_weapon_switched(weapon: WeaponBase) -> void:
	if not weapon:
		return
	print("Player: Weapon switched to: ", weapon.weapon_name)

	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("switch_weapon"):
		hud.switch_weapon(0)  # TODO: Map to actual HUD index when inventory integration is complete


func _on_weapon_fired(_weapon: WeaponBase, _target_position: Vector2) -> void:
	_log_message("Weapon fired", "Combat")


func _on_weapon_reloaded(_weapon: WeaponBase) -> void:
	_log_message("Weapon reloaded", "Combat")


func _on_weapon_state_changed(_weapon: WeaponBase, _state: int) -> void:
	pass

func _on_coins_changed(new_amount: int):
	"""Handle coin amount changes"""
	print("Player: Coins changed to: ", new_amount)
	
	# Update HUD coin display
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("update_coins"):
		hud.update_coins(new_amount)

func _log_debug_input(input_vector: Vector2):
	_log_message("Input vector: " + str(input_vector), "Player")

func _log_message(message: String, _system: String = "Player"):
	GameLog.log_player(message)
	# if _logger:
	# 	_logger.log_player(message)
	# else:
	# 	print("Player: ", message)
	# Could add visual/audio feedback here

func increase_max_health(amount: int):
	max_health += amount
	current_health += amount  # Also heal to new max
	health_changed.emit(current_health, max_health)
	print("Player: Max health increased by ", amount)

# FOV functions
func _initialize_fov():
	# Try to get FOV settings from settings panel, otherwise use defaults
	var settings_panel = get_tree().get_first_node_in_group("settings_panel")
	if settings_panel and settings_panel.has_method("_get_current_fov_settings"):
		var fov_settings = settings_panel._get_current_fov_settings()
		fov_min = fov_settings.min
		fov_max = fov_settings.max
		current_fov = fov_settings.current
	else:
		# Use very flexible defaults
		fov_min = 1.0
		fov_max = 360.0
		current_fov = 75.0
	
	_apply_fov_to_camera()

func _zoom_in():
	# Scroll wheel up = zoom in = decrease FOV
	var new_fov = current_fov - zoom_speed
	if new_fov >= fov_min:
		current_fov = new_fov
		_apply_fov_to_camera()
		_update_settings_panel_fov()
		# print("Player: FOV zoomed in to ", current_fov, "°")  # Disabled to reduce console spam

func _zoom_out():
	# Scroll wheel down = zoom out = increase FOV
	var new_fov = current_fov + zoom_speed
	if new_fov <= fov_max:
		current_fov = new_fov
		_apply_fov_to_camera()
		_update_settings_panel_fov()
		# print("Player: FOV zoomed out to ", current_fov, "°")  # Disabled to reduce console spam

func _apply_fov_to_camera():
	if camera:
		# Convert FOV to zoom (inverse relationship - higher FOV = lower zoom)
		var zoom_value = 100.0 / current_fov
		
		# Clamp zoom to reasonable values to prevent visual issues
		zoom_value = clamp(zoom_value, 0.1, 100.0)
		
		camera.zoom = Vector2(zoom_value, zoom_value)
		# print("Player: FOV set to ", current_fov, "° (zoom: ", zoom_value, ")")  # Disabled to reduce console spam

func _update_settings_panel_fov():
	# Update settings panel if it's open
	var settings_panel = get_tree().get_first_node_in_group("settings_panel")
	if settings_panel and settings_panel.has_method("_update_fov_from_player"):
		settings_panel._update_fov_from_player(current_fov)

func set_fov_range(min_fov: float, max_fov: float):
	fov_min = min_fov
	fov_max = max_fov
	# Ensure current FOV is within new range
	if current_fov < fov_min:
		current_fov = fov_min
		_apply_fov_to_camera()
	elif current_fov > fov_max:
		current_fov = fov_max
		_apply_fov_to_camera()

func get_current_fov() -> float:
	return current_fov

func _handle_interaction():
	"""Handle F-key interaction with nearby objects"""
	print("Player: F-key interaction pressed")
	
	# Check for nearby ARK for trading
	var nearby_ark = _get_nearby_ark()
	if nearby_ark:
		_open_trading_interface(nearby_ark)
		return
	
	# Check for other interactable objects here in future
	print("Player: No interactable objects nearby")

func _get_nearby_ark() -> Ark:
	"""Check if player is near an ARK station"""
	var interaction_range = 150.0  # Interaction distance
	
	var arks = get_tree().get_nodes_in_group("ark_ships")
	for ark in arks:
		if global_position.distance_to(ark.global_position) <= interaction_range:
			print("Player: Found nearby ARK at distance: ", global_position.distance_to(ark.global_position))
			return ark
	
	return null

func _open_trading_interface(_ark: Ark):
	"""Open trading interface with ARK"""
	print("Player: Opening trading interface with ARK")
	
	# Find trading panel
	var trading_panel = get_tree().get_first_node_in_group("trading_panel")
	if not trading_panel:
		# Trading panel scene doesn't exist yet - show notification
		var hud = get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("show_notification"):
			hud.show_notification("Trading with ARK - Coming Soon!", 3.0)
		else:
			print("Player: Trading with ARK - Coming Soon!")
		return
	
	# Open the trading interface
	if trading_panel and trading_panel.has_method("open_trading"):
		trading_panel.open_trading()
		
		# Play interaction sound
		var audio_manager = get_tree().get_first_node_in_group("audio_manager")
		if audio_manager:
			audio_manager.play_ui_sound("button_click")
	else:
		print("Player: Trading panel not available")

func _update_interaction_prompt():
	"""Update interaction prompt based on nearby objects"""
	var interaction_prompt = get_tree().get_first_node_in_group("interaction_prompt")
	if not interaction_prompt:
		return
	
	var nearby_ark = _get_nearby_ark()
	if nearby_ark:
		# Show interaction prompt for ARK
		interaction_prompt.show_prompt(nearby_ark, "Press F to Trade")
		interaction_prompt.update_position(global_position)
	else:
		# Hide interaction prompt if no interactable objects nearby
		interaction_prompt.hide_prompt()
