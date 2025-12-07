extends CharacterBody2D

signal health_changed(current_health, max_health)
signal xp_changed(current_xp, xp_required)
signal level_changed(level)

const InventorySlotTypeClass = preload("res://scripts/InventorySlotType.gd")

# Weapon system
@export var speed = 300.0
@export var acceleration = 800.0
@export var friction = 8.0
@export var fire_rate = 0.5

#next code
var level = 1
var current_xp = 0
var xp_required = 100
var skill_points = 0
var max_health = 100.0
var current_health = max_health
var is_dead = false
var god_mode: bool = false
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
	
	# Apply ship texture from GameState if available
	_apply_ship_texture_from_game_state()
	
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

func _apply_ship_texture_from_game_state():
	"""Apply ship texture from GameState to the player sprite"""
	var sprite = $Sprite2D
	if not sprite:
		GameLog.log_error("Player: Sprite2D node not found")
		return
	
	var game_state = get_node_or_null("/root/GameState")
	if not game_state:
		GameLog.log_player("Player: GameState not found, using default texture")
		return
	
	var ship_texture_path = game_state.get_selected_ship_texture()
	if ship_texture_path != "" and ResourceLoader.exists(ship_texture_path):
		var texture = load(ship_texture_path)
		if texture:
			sprite.texture = texture
			GameLog.log_player("Player: Applied ship texture: " + ship_texture_path)
		else:
			GameLog.log_error("Player: Failed to load ship texture: " + ship_texture_path)
	else:
		GameLog.log_player("Player: No custom ship texture found, using default")

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
	if is_dead or god_mode:
		return
	current_health -= amount
	health_changed.emit(current_health, max_health)
	GameLog.log_combat("Player took damage: %d, Health: %d" % [amount, current_health])
	print("Player Health: ", current_health)
	if current_health <= 0:
		die()

func set_health(value: float) -> void:
	current_health = clamp(value, 0.0, max_health)
	health_changed.emit(current_health, max_health)
	print("Player: Health set to ", current_health, "/", max_health)

func set_god_mode(enabled: bool) -> void:
	god_mode = enabled
	print("Player: God mode ", "ENABLED" if god_mode else "DISABLED")

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
		var mouse_pos = get_global_mouse_position()
		
		# Left Mouse Button -> Weapon 1 (Index 0)
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if weapon_manager and weapon_manager.is_active():
					weapon_manager.fire_weapon_index(0, mouse_pos)
			else:
				if weapon_manager:
					weapon_manager.stop_firing_index(0)
		
		# Right Mouse Button -> Weapon 2 (Index 1)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				if weapon_manager and weapon_manager.is_active():
					weapon_manager.fire_weapon_index(1, mouse_pos)
			else:
				if weapon_manager:
					weapon_manager.stop_firing_index(1)
					
		# Handle FOV zoom with mouse wheel
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_in()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_out()

	# Handle UI toggles
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_E:
			_toggle_inventory()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F:
			_handle_interaction()
			get_viewport().set_input_as_handled()
	
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

func _unhandled_input(_event):
	# Moved to _input for better reliability with UI overlays
	pass

func _get_weapon_slot_item() -> Dictionary:
	var inventory_state = _get_inventory_state()
	if not inventory_state:
		return {}
	return inventory_state.get_equipped_item(InventorySlotTypeClass.SlotType.WEAPON1)

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

func _on_weapon_switched(weapon: BaseWeapon) -> void:
	if not weapon:
		return
	print("Player: Weapon switched to: ", weapon.name) # BaseWeapon uses name or weapon_id

	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("switch_weapon"):
		hud.switch_weapon(0)  # TODO: Map to actual HUD index when inventory integration is complete


func _on_weapon_fired(_weapon: BaseWeapon, _target_position: Vector2) -> void:
	_log_message("Weapon fired", "Combat")


func _on_weapon_reloaded(_weapon: BaseWeapon) -> void:
	_log_message("Weapon reloaded", "Combat")


func _on_weapon_state_changed(_weapon: BaseWeapon, _state: int) -> void:
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

# Interaction system
var current_interactable: Node2D = null
var interaction_range: float = 1000.0  # Increased interaction distance for easier access

func _handle_interaction():
	"""Handle F-key interaction with nearby objects"""
	# Force update to ensure we have the latest state
	_update_current_interactable()
	
	print("Player: F-key interaction pressed")
	
	# Check if we have a valid current interactable
	if current_interactable and is_instance_valid(current_interactable):
		if global_position.distance_to(current_interactable.global_position) <= interaction_range:
			# Handle different types of interactables
			if current_interactable is Ark:
				_open_trading_interface(current_interactable)
				return
			# Add other interactable types here in future
		else:
			# Clear interactable if out of range
			current_interactable = null
	
	# Debug why it failed
	var arks = get_tree().get_nodes_in_group("ark_ships")
	if not arks.is_empty():
		var nearest = arks[0]
		var dist = global_position.distance_to(nearest.global_position)
		for a in arks:
			var d = global_position.distance_to(a.global_position)
			if d < dist:
				dist = d
		print("Player: No interactable in range. Nearest Ark is ", dist, " units away (Range: ", interaction_range, ")")
	else:
		print("Player: No interactable objects nearby (No Arks found in group)")

func _get_nearby_ark() -> Ark:
	"""Check if player is near an ARK station (legacy method)"""
	var arks = get_tree().get_nodes_in_group("ark_ships")
	for ark in arks:
		if global_position.distance_to(ark.global_position) <= interaction_range:
			print("Player: Found nearby ARK at distance: ", global_position.distance_to(ark.global_position))
			return ark
	
	return null

func _open_trading_interface(_ark: Ark) -> void:
	"""Open trading interface with ARK"""
	# Phase 1: Prevent multiple instances
	if get_tree().get_first_node_in_group("trader_panel"):
		print("Player: Trader panel already open")
		return

	print("Player: Opening trading interface with ARK")
	
	# Hide interaction prompt
	var interaction_prompt = get_tree().get_first_node_in_group("interaction_prompt")
	if interaction_prompt:
		interaction_prompt.hide_prompt()
	
	# Instantiate the TraderPanel UI scene
	var trader_panel_scene := preload("res://scenes/UI/TraderPanel.tscn")
	var trader_panel = trader_panel_scene.instantiate()
	
	# Attach to HUD so it shares the same CanvasLayer/UI stack
	var hud = get_tree().get_first_node_in_group("hud")
	if hud:
		hud.add_child(trader_panel)
	else:
		get_tree().root.add_child(trader_panel)
		
	# Open the panel using its own API
	if trader_panel.has_method("open"):
		trader_panel.open()
	
	# Connect close signal for any cleanup/logging
	if trader_panel.has_signal("closed"):
		trader_panel.closed.connect(func(): print("Player: Trader panel closed"))
	
	# Play sound
	var audio_manager = get_tree().get_first_node_in_group("audio_manager")
	if audio_manager:
		audio_manager.play_ui_sound("button_click")

# _on_item_purchased is no longer needed as TradingPanel handles transactions internally
# Keeping the function signature if you want to reuse it for other things, 
# otherwise it can be removed or left empty.
func _on_item_purchased(_item_id: String) -> void:
	pass

func _get_item_data(item_id: String) -> Dictionary:
	"""Get item data from database"""
	var item_database = get_tree().get_first_node_in_group("item_database")
	if item_database and item_database.has_method("get_item"):
		return item_database.get_item(item_id)
	return {}

func _update_interaction_prompt():
	"""Update interaction prompt based on nearby objects"""
	var interaction_prompt = get_tree().get_first_node_in_group("interaction_prompt")
	if not interaction_prompt:
		# print("Player: No InteractionPrompt found in 'interaction_prompt' group")
		return
	
	# print("Player: InteractionPrompt found, updating current interactable")
	
	# Update current_interactable based on proximity
	_update_current_interactable()
	
	if current_interactable and is_instance_valid(current_interactable):
		# Show interaction prompt based on interactable type
		var prompt_text = "Press F to Interact"
		if current_interactable is Ark:
			prompt_text = "Press [F] to Trade"
		
		interaction_prompt.show_prompt(current_interactable, prompt_text)
		interaction_prompt.update_position(global_position)
	else:
		# Hide interaction prompt if no interactable objects nearby
		interaction_prompt.hide_prompt()

func _update_current_interactable():
	"""Update current_interactable based on proximity"""
	# Check for nearby ARK ships
	var arks = get_tree().get_nodes_in_group("ark_ships")
	# print("Player: Found ", arks.size(), " ARK ships in 'ark_ships' group")
	
	for ark in arks:
		var distance = global_position.distance_to(ark.global_position)
		# print("Player: Checking ARK at distance: ", distance, " (range: ", interaction_range, ")")
		if distance <= interaction_range:
			current_interactable = ark
			# print("Player: Set current_interactable to ARK")
			return
	
	# No interactables found
	current_interactable = null
	# print("Player: No ARK ships in range")

func _on_trader_panel_closed():
	"""Called when trader panel is closed"""
	print("Player: Trader panel closed")
	# Clean up the trader panel instance to prevent memory leaks
	var trader_panel = get_tree().get_first_node_in_group("trader_panel")
	if trader_panel and is_instance_valid(trader_panel):
		trader_panel.queue_free()
	
	# Update interaction prompt to show again if still in range
	_update_interaction_prompt()
