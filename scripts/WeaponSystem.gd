extends Node
class_name WeaponSystem

## WeaponSystem - Manages player weapons and switching
## Supports Bullet and Phaser weapons with distinct firing mechanics

# Import AudioManager class with non-shadowing name
const AudioManagerClass = preload("res://scripts/AudioManager.gd")
const ScoutPhaserClass = preload("res://scripts/ScoutPhaser.gd")

signal weapon_switched(weapon_type: int)
signal weapon_fired(weapon_type: int)
signal phaser_started()
signal phaser_stopped()

enum WeaponType {
	BULLET,
	PHASER
}

# Audio manager reference
@onready var audio_manager: AudioManagerClass = get_tree().get_first_node_in_group("audio_manager")

# Performance optimization - Object pools
var bullet_pool: ObjectPool
var phaser_pool: ObjectPool

# Weapon configurations - CONSOLIDATED to use BaseWeapon architecture
const WEAPON_CONFIG = {
	WeaponType.BULLET: {
		"name": "Auto Turret",
		"fire_rate": 0.2,  # seconds between shots
		"damage": 10,
		"projectile_scene": "res://scenes/BulletProjectile.tscn",
		"icon": "🔫",
		"color": Color.WHITE,
		"weapon_scene": "res://scenes/WeaponInstance.tscn"  # Generic weapon instance
	},
	WeaponType.PHASER: {
		"name": "Phasers",
		"fire_rate": 0.1,  # damage tick rate
		"damage": 15,  # damage per second
		"projectile_scene": "res://scenes/weapons/FX_PhaserBeams.tscn",
		"icon": "",
		"color": Color.RED,
		"weapon_scene": "res://scenes/weapons/FX_PhaserBeams.tscn"  # Phaser weapon scene
	}
}

var current_weapon: WeaponType = WeaponType.BULLET
var player_node: Node2D
var _logger: Node
# Auto-firing state management
var current_auto_weapon: String = ""  # Track which weapon is currently auto-firing
var auto_fire_timer: float = 0.0
var auto_fire_interval: float = 0.5  # Check auto-fire every 0.5 seconds

# Centralized state management
var weapon_state: Dictionary = {
	"manual_weapon": "",
	"auto_weapon": "",
	"phaser_active": false,
	"phaser_manual": false,
	"last_manual_fire": 0.0,
	"last_auto_fire": 0.0
}
var AUTO_FIRE_CHECK_INTERVAL: float = 0.5  # Check every 0.5 seconds
var _weapon_fire_log_timer: float = 0.0
var _weapon_fire_log_interval: float = 2.0  # Log weapon fires every 2 seconds
var time_since_last_fire: float = 0.0
var phaser_active: bool = false
var current_phaser_beam: Node = null  # Changed from ScoutPhaser to Node for compatibility
var weapons_enabled: bool = true  # New: weapons can be disabled
var manual_phaser_pending: bool = false

func _ready():
	add_to_group("weapon_system")
	player_node = get_tree().get_first_node_in_group("player")
	_logger = get_tree().get_first_node_in_group("game_logger")
	
	# Audio debugging
	print("WeaponSystem: _ready called")
	print("WeaponSystem: Audio manager found: ", audio_manager != null)
	if audio_manager:
		print("WeaponSystem: Audio manager type: ", audio_manager.get_class())
	else:
		print("WeaponSystem: ERROR - No audio manager found!")
	
	# Initialize object pools for performance
	_initialize_object_pools()
	
	_log_message("Initialized with current weapon: " + WEAPON_CONFIG[current_weapon]["name"], "Combat")

func _initialize_object_pools():
	"""Initialize object pools for frequently created objects"""
	var bullet_scene = load("res://scenes/BulletProjectile.tscn")
	if bullet_scene:
		bullet_pool = ObjectPool.new(bullet_scene, 30, get_tree().current_scene)
		add_child(bullet_pool)
		print("WeaponSystem: Bullet pool initialized")
	
	var phaser_scene = load("res://scenes/weapons/FX_PhaserBeams.tscn")
	if phaser_scene:
		phaser_pool = ObjectPool.new(phaser_scene, 10, get_tree().current_scene)
		add_child(phaser_pool)
		print("WeaponSystem: Phaser pool initialized")

func _process(delta):
	time_since_last_fire += delta
	_weapon_fire_log_timer += delta
	auto_fire_timer += delta
	
	# Handle phaser beam updates
	if phaser_active and current_phaser_beam:
		# Update mouse position for manual control
		if player_node and current_phaser_beam.has_method("is_manual_control") and current_phaser_beam.is_manual_control():
			var mouse_pos = player_node.get_global_mouse_position()
			if current_phaser_beam.has_method("update_mouse_target"):
				current_phaser_beam.update_mouse_target(mouse_pos)
		# Note: auto-fire for player weapons has been disabled; phaser updates are manual-only.

func switch_weapon(weapon_type: WeaponType):
	print("WeaponSystem: switch_weapon called with type: ", weapon_type)
	if weapon_type == current_weapon:
		print("WeaponSystem: Already using weapon type: ", weapon_type)
		return
	
	# Stop current weapon if needed
	if phaser_active:
		print("WeaponSystem: Stopping active phaser before switching")
		stop_phaser()
	
	current_weapon = weapon_type
	weapon_switched.emit(weapon_type)
	_log_message("Switched to " + WEAPON_CONFIG[current_weapon]["name"], "Combat")
	print("WeaponSystem: Switched to weapon type: ", weapon_type, " (", WEAPON_CONFIG[current_weapon]["name"], ")")

func fire_weapon():
	"""Fire the current weapon if enabled - MANUAL FIRING ONLY from WEAPON slot"""
	if not weapons_enabled:
		print("WeaponSystem: Weapons disabled, cannot fire")
		PhaserLogger.log_message("WeaponSystem", "fire_weapon aborted - weapons disabled")
		return
	
	var weapon_slot_data = _get_weapon_slot_data()
	if weapon_slot_data.is_empty():
		print("WeaponSystem: No WEAPON slot found for manual firing")
		return
	
	var weapon_id: String = weapon_slot_data.get("item_id", "").to_lower()
	
	match weapon_id:
		"phasers":
			# print("WeaponSystem: Manual firing PHASER from WEAPON slot")
			if not player_node:
				print("WeaponSystem: ERROR - No player node for phaser")
				PhaserLogger.log_message("WeaponSystem", "fire_weapon manual phaser failed - no player node")
				return
			var mouse_pos = player_node.get_global_mouse_position()
			PhaserLogger.log_target("WeaponSystem", "Manual fire weapon slot", mouse_pos)
			_fire_phaser(mouse_pos, true)  # is_manual = true for manual firing
		"auto_turret":
			# print("WeaponSystem: Manual firing TURRET from WEAPON slot")
			PhaserLogger.log_message("WeaponSystem", "Manual fire_weapon firing turret")
			_fire_bullet_manual()
		_:
			print("WeaponSystem: No weapon in WEAPON slot for manual firing")
			return

func fire_weapon_at_double_rate():
	"""Fire the current weapon at double the normal fire rate (for manual shooting)"""
	if not weapons_enabled:
		print("WeaponSystem: Weapons disabled, cannot fire")
		return
	
	var weapon_slot_data = _get_weapon_slot_data()
	if weapon_slot_data.is_empty():
		print("WeaponSystem: No WEAPON slot found for manual double-rate firing")
		return
	
	var weapon_id: String = weapon_slot_data.get("item_id", "").to_lower()
	
	match weapon_id:
		"auto_turret":
			PhaserLogger.log_message("WeaponSystem", "Manual double-rate turret fire")
			_fire_bullet_double_rate()
		_:
			print("WeaponSystem: Double-rate firing not supported for weapon item_id: ", weapon_id)
			PhaserLogger.log_message("WeaponSystem", "Manual double-rate requested unsupported item_id=%s" % weapon_id)
			return

func _get_weapon_slot_data() -> Dictionary:
	var inventory_state: InventoryState = get_tree().get_first_node_in_group("inventory")
	if not inventory_state:
		return {}
	var weapon_slots = [InventoryState.SlotType.WEAPON1, InventoryState.SlotType.WEAPON2]
	for slot_type in weapon_slots:
		var inst := inventory_state.get_equipped_item(slot_type)
		if not inst.is_empty():
				var item_id: String = inst.get("item_id", "")
				if item_id != "":
					var definition := inventory_state.get_item_definition(item_id)
					return {
						"item_id": item_id,
						"name": definition.get("name", item_id),
						"slot_type": slot_type,
						"instance_id": inst.get("instance_id", ""),
					}
	return {}

func set_enabled(enabled: bool):
	"""Enable or disable weapons"""
	weapons_enabled = enabled
	if not enabled and phaser_active:
		stop_phaser()
	_log_message("Weapons " + ("enabled" if enabled else "disabled"), "Combat")

func get_current_weapon_from_inventory() -> WeaponType:
	"""Dynamically check what weapon is currently equipped in the weapon slot"""
	var inventory_state: InventoryState = get_tree().get_first_node_in_group("inventory")
	if not inventory_state:
		print("WeaponSystem: No InventoryState found")
		return WeaponType.BULLET  # Default fallback
	
	var weapon_slot := inventory_state.get_equipped_item(InventoryState.SlotType.WEAPON1)
	var weapon_id = weapon_slot.get("item_id", "").to_lower()
	
	print("WeaponSystem: Weapon slot contains item_id: ", weapon_id)
	
	match weapon_id:
		"phasers":
			return WeaponType.PHASER
		"auto_turret":
			return WeaponType.BULLET
		_:
			print("WeaponSystem: Unknown weapon item_id in slot: ", weapon_id)
			return WeaponType.BULLET  # Default fallback

func _fire_bullet():
	print("WeaponSystem: _fire_bullet called (AUTO-FIRE VERSION)")
	print("WeaponSystem: time_since_last_fire: ", time_since_last_fire, " fire_rate: ", WEAPON_CONFIG[WeaponType.BULLET].fire_rate)
	
	if time_since_last_fire < WEAPON_CONFIG[WeaponType.BULLET].fire_rate:
		print("WeaponSystem: Fire rate limit not reached - skipping auto-fire")
		return
	
	if not player_node:
		print("WeaponSystem: No player node")
		return
	
	print("WeaponSystem: Auto-firing bullet at NEAREST ENEMY")
	
	# Play bullet sound effect with variation
	if audio_manager:
		audio_manager.play_bullet_sound()
	
	# Find nearest enemy for auto-targeting
	var enemies = get_tree().get_nodes_in_group("enemy")
	print("WeaponSystem: Found ", enemies.size(), " enemies")
	if enemies.is_empty():
		print("WeaponSystem: No enemies found - not auto-firing")
		return
	
	var nearest_enemy = _find_nearest_enemy(enemies)
	if not nearest_enemy:
		print("WeaponSystem: No nearest enemy found - not auto-firing")
		return
	
	print("WeaponSystem: Auto-targeting enemy at: ", nearest_enemy.global_position)
	
	# Create bullet projectile using object pool
	var projectile: Node = null
	if bullet_pool:
		projectile = bullet_pool.get_object()
		print("WeaponSystem: Got bullet from pool")
	else:
		# Fallback to direct instantiation
		var projectile_scene = preload(WEAPON_CONFIG[WeaponType.BULLET].projectile_scene)
		projectile = projectile_scene.instantiate()
		print("WeaponSystem: Created bullet directly (no pool)")
	
	if not projectile:
		print("WeaponSystem: Failed to create projectile")
		return
	
	projectile.global_position = player_node.global_position
	
	# Target edge of enemy collision shape
	var target_pos = nearest_enemy.global_position
	var collision_shape = nearest_enemy.get_node_or_null("CollisionShape2D")
	if collision_shape:
		target_pos = CollisionEdgeCalculator.get_edge_point(collision_shape, player_node.global_position)
	
	projectile.direction = player_node.global_position.direction_to(target_pos)
	projectile.rotation = projectile.direction.angle()
	projectile.damage = WEAPON_CONFIG[WeaponType.BULLET].damage
	
	get_tree().current_scene.add_child(projectile)
	time_since_last_fire = 0.0
	weapon_fired.emit(WeaponType.BULLET)
	
	print("WeaponSystem: Auto-fire bullet fired successfully")
	
	# Log weapon fire (throttled)
	if _weapon_fire_log_timer >= _weapon_fire_log_interval:
		_log_message("Bullet fired (auto)", "Combat")
		_weapon_fire_log_timer = 0.0

func _fire_bullet_double_rate():
	"""Fire bullet at double the normal fire rate (for manual shooting)"""
	print("WeaponSystem: _fire_bullet_double_rate called")
	
	# Use half the normal fire rate for double speed shooting
	var double_rate_fire_rate = WEAPON_CONFIG[WeaponType.BULLET].fire_rate / 2.0
	print("WeaponSystem: Double rate fire rate: ", double_rate_fire_rate, " time_since_last_fire: ", time_since_last_fire)
	
	if time_since_last_fire < double_rate_fire_rate:
		print("WeaponSystem: Fire rate limit not reached")
		return
	
	if not player_node:
		print("WeaponSystem: No player node")
		return
	
	print("WeaponSystem: Firing double rate bullet")
	
	# Play bullet sound effect with variation
	if audio_manager:
		audio_manager.play_bullet_sound()
	
	# Find nearest enemy for auto-targeting (manual shooting still auto-targets)
	var enemies = get_tree().get_nodes_in_group("enemy")
	print("WeaponSystem: Found ", enemies.size(), " enemies")
	if enemies.is_empty():
		print("WeaponSystem: No enemies found")
		return
	
	var nearest_enemy = _find_nearest_enemy(enemies)
	if not nearest_enemy:
		print("WeaponSystem: No nearest enemy found")
		return
	
	print("WeaponSystem: Targeting enemy at: ", nearest_enemy.global_position)
	
	# Create bullet projectile
	var projectile_scene = preload(WEAPON_CONFIG[WeaponType.BULLET].projectile_scene)
	var projectile = projectile_scene.instantiate()
	projectile.global_position = player_node.global_position
	
	# Target edge of enemy collision shape
	var target_pos = nearest_enemy.global_position
	var collision_shape = nearest_enemy.get_node_or_null("CollisionShape2D")
	if collision_shape:
		target_pos = CollisionEdgeCalculator.get_edge_point(collision_shape, player_node.global_position)
	
	projectile.direction = player_node.global_position.direction_to(target_pos)
	projectile.rotation = projectile.direction.angle()
	projectile.damage = WEAPON_CONFIG[WeaponType.BULLET].damage
	
	get_tree().current_scene.add_child(projectile)
	time_since_last_fire = 0.0
	weapon_fired.emit(WeaponType.BULLET)
	
	print("WeaponSystem: Double rate bullet fired successfully")
	
	# Log weapon fire (throttled)
	if _weapon_fire_log_timer >= _weapon_fire_log_interval:
		_log_message("Bullet fired (double rate)", "Combat")
		_weapon_fire_log_timer = 0.0

func _fire_phaser(target_position: Vector2, is_manual: bool = true):
	"""UNIFIED: Fire phaser using the consolidated BaseWeapon architecture"""
	print("WeaponSystem: Unified phaser firing - manual: ", is_manual)
	PhaserLogger.log_target("WeaponSystem", "_fire_phaser invoked manual=%s" % is_manual, target_position)
	
	if not player_node:
		print("WeaponSystem: ERROR - No player node in _fire_phaser")
		PhaserLogger.log_message("WeaponSystem", "_fire_phaser aborted - missing player node")
		return
	
	if is_manual:
		if _is_manual_phaser_active():
			PhaserLogger.log_target("WeaponSystem", "Manual phaser already active - updating target", target_position)
			if current_phaser_beam and current_phaser_beam.has_method("update_mouse_target"):
				current_phaser_beam.update_mouse_target(target_position)
			print("WeaponSystem: Manual phaser already active - updated mouse target only")
			return
		if manual_phaser_pending:
			PhaserLogger.log_target("WeaponSystem", "Manual phaser pending - ignoring new request", target_position)
			return
		
		# If auto phaser is active, stop it before starting manual
		if phaser_active:
			print("WeaponSystem: Auto phaser active - stopping for manual override")
			stop_phaser()
			
		manual_phaser_pending = true
		PhaserLogger.log_target("WeaponSystem", "Manual phaser primed", target_position)
	else:
		# For auto beams, ensure previous instance is stopped before spawning another
		if phaser_active and not _is_manual_phaser_active():
			print("WeaponSystem: Auto phaser already active - restarting for new target")
			PhaserLogger.log_target("WeaponSystem", "Auto phaser already active - stopping before restart", target_position)
			stop_phaser()
	
	# Use the unified phaser system
	_fire_phaser_unified(target_position, is_manual)

func stop_phaser():
	"""UNIFIED: Stop phaser using the consolidated system"""
	print("WeaponSystem: Unified stop_phaser called")
	PhaserLogger.log_message("WeaponSystem", "stop_phaser invoked")
	
	if not phaser_active:
		print("WeaponSystem: No active phaser to stop (phaser_active=false)")
		return
	
	# Update state - CRITICAL: Set phaser_active to false FIRST
	phaser_active = false
	_update_weapon_state("phaser_active", false)
	_update_weapon_state("phaser_manual", false)
	_update_weapon_state("manual_weapon", "")
	_update_weapon_state("auto_weapon", "")
	manual_phaser_pending = false
	
	# Clear reference
	if current_phaser_beam:
		var beam_ref = current_phaser_beam  # Store reference before clearing
		if beam_ref and beam_ref.has_method("stop_firing"):
			beam_ref.stop_firing()
		# Note: The PhaserBeamsWeapon.stop_firing() will handle freeing the beam
		# Don't queue_free here to avoid double-free issues
		current_phaser_beam = null
	
	phaser_stopped.emit()
	_log_message("Unified phaser stopped", "Combat")
	PhaserLogger.log_message("WeaponSystem", "Phaser stopped")

func auto_fire_weapons_if_needed():
	"""Check what weapons are in PASSIVE slots only and auto-fire them"""
	# Don't auto-fire if phaser is manually active
	if _is_manual_phaser_active():
		PhaserLogger.log_message("WeaponSystem", "Auto-fire skipped - manual phaser active")
		return
	
	# Check inventory UI
	var inventory_state: InventoryState = get_tree().get_first_node_in_group("inventory")
	if not inventory_state:
		return
	
	# Find weapons ONLY in PASSIVE slots (slot_type = "passive")
	var phaser_found = false
	var turret_found = false
	
	var passive_slots = [InventoryState.SlotType.PASSIVE1, InventoryState.SlotType.PASSIVE2, InventoryState.SlotType.ACCESSORY]
	for slot_type in passive_slots:
		var inst := inventory_state.get_equipped_item(slot_type)
		if inst.is_empty():
			continue
		var weapon_name = inst.get("item_id", "").to_lower()
		if weapon_name == "phaser":
			phaser_found = true
			print("WeaponSystem: Found phaser in passive slot ", slot_type)
		elif weapon_name == "turret":
			turret_found = true
			print("WeaponSystem: Found turret in passive slot ", slot_type)
	
	# Fire based on priority, but ONLY from passive slots
	if phaser_found and not phaser_active:
		_fire_phaser_from_passive_slot()
		current_auto_weapon = "phaser"
		print("WeaponSystem: Auto-firing phaser from PASSIVE slot")
	elif turret_found and current_auto_weapon != "phaser":
		_fire_turret_from_passive_slot()
		current_auto_weapon = "turret"
		print("WeaponSystem: Auto-firing turret from PASSIVE slot")
	elif not phaser_found and not turret_found:
		current_auto_weapon = ""
		print("WeaponSystem: No weapons found in PASSIVE slots for auto-fire")

func _fire_phaser_from_passive_slot():
	"""Auto-fire phaser from passive slot"""
	# print("WeaponSystem: Auto-firing phaser from passive slot")
	
	# Find a target first
	var enemies = get_tree().get_nodes_in_group("enemy")
	if enemies.is_empty():
		return
		
	var target = _find_nearest_enemy(enemies)
	if target:
		_fire_phaser(target.global_position, false)  # is_manual = false for auto-fire
		# print("WeaponSystem: Auto-fired phaser at enemy: ", target.name)

func _fire_turret_from_passive_slot():
	"""Auto-fire turret from passive slot"""
	# print("WeaponSystem: Auto-firing turret from passive slot")
	
	# Check fire rate
	if time_since_last_fire < WEAPON_CONFIG[WeaponType.BULLET].fire_rate:
		return
	
	# Find a target first
	var enemies = get_tree().get_nodes_in_group("enemy")
	if enemies.is_empty():
		return
		
	var target = _find_nearest_enemy(enemies)
	if target:
		_fire_bullet_at_target(target)
		time_since_last_fire = 0.0
		# print("WeaponSystem: Auto-fired turret at enemy: ", target.name)

func _fire_bullet_at_target(target: Node2D):
	"""Fire bullet at specific target"""
	if not player_node:
		return
	
	var bullet_scene = load(WEAPON_CONFIG[WeaponType.BULLET].projectile_scene)
	if not bullet_scene:
		print("WeaponSystem: Failed to load bullet scene")
		return
	
	var bullet = bullet_scene.instantiate()
	if not bullet:
		return
	
	# Calculate direction to target
	var direction = (target.global_position - player_node.global_position).normalized()
	
	# Set bullet properties
	bullet.global_position = player_node.global_position
	bullet.direction = direction  # Set direction BEFORE adding to scene
	bullet.damage = WEAPON_CONFIG[WeaponType.BULLET].damage
	
	# Add to scene
	get_tree().current_scene.add_child(bullet)
	
	# Play bullet sound through AudioManager
	if audio_manager:
		audio_manager.play_bullet_sound()
	
	# Log bullet fire
	if _weapon_fire_log_timer >= _weapon_fire_log_interval:
		_log_message("Bullet fired (auto from passive)", "Combat")
		_weapon_fire_log_timer = 0.0

func _fire_bullet_manual():
	"""Fire bullet manually from weapon slot"""
	# print("WeaponSystem: Manual bullet fire")
	
	if not player_node:
		print("WeaponSystem: ERROR - No player node for bullet firing")
		return
	
	# Get weapon configuration
	var config = WEAPON_CONFIG[WeaponType.BULLET]
	
	# Create bullet instance
	var bullet_scene = load(config.projectile_scene)
	if not bullet_scene:
		print("WeaponSystem: ERROR - Could not load bullet scene: ", config.projectile_scene)
		return
	
	var bullet = bullet_scene.instantiate()
	
	# Calculate spawn position (in front of player)
	var spawn_offset = Vector2(30, 0).rotated(player_node.rotation)
	var spawn_position = player_node.global_position + spawn_offset
	
	# Set bullet properties
	bullet.global_position = spawn_position
	bullet.direction = (player_node.get_global_mouse_position() - spawn_position).normalized()
	bullet.damage = config.damage
	
	# Add bullet to scene
	get_tree().current_scene.add_child(bullet)
	
	# Play bullet sound through AudioManager
	if audio_manager:
		audio_manager.play_bullet_sound()
	else:
		print("WeaponSystem: WARNING - No AudioManager for bullet sound")
	
	_log_message("Bullet fired manually", "Combat")

func get_current_weapon() -> WeaponType:
	"""Get the current weapon type from inventory (dynamic)"""
	return get_current_weapon_from_inventory()

func get_weapon_info(weapon_type: WeaponType) -> Dictionary:
	return WEAPON_CONFIG[weapon_type].duplicate()

func get_all_weapons() -> Array:
	return WEAPON_CONFIG.keys()

func on_inventory_changed():
	"""Called when inventory slots are changed - forces weapon system to re-evaluate"""
	print("WeaponSystem: Inventory changed, re-evaluating current weapon")
	var new_weapon = get_current_weapon_from_inventory()
	if new_weapon != current_weapon:
		print("WeaponSystem: Weapon changed from ", current_weapon, " to ", new_weapon)
		current_weapon = new_weapon
		weapon_switched.emit(new_weapon)
		_log_message("Weapon auto-switched to " + WEAPON_CONFIG[new_weapon]["name"], "Combat")

func _find_nearest_enemy(enemies: Array) -> Node2D:
	var nearest_enemy = null
	var min_distance = INF
	
	for enemy in enemies:
		var distance = player_node.global_position.distance_to(enemy.global_position)
		if distance < min_distance:
			min_distance = distance
			nearest_enemy = enemy
	
	return nearest_enemy

func _input(_event):
	# INPUT HANDLING REMOVED - All input is now handled by Player.gd
	# This prevents conflicts between multiple input handlers
	# WeaponSystem now only responds to explicit calls from Player.gd
	pass

func _log_message(message: String, _system: String = "Combat"):
	if _logger:
		_logger.log_combat(message)
	else:
		print("WeaponSystem: ", message)

func get_current_weapon_type() -> WeaponType:
	return current_weapon

# Public method for inventory to switch weapons
func switch_weapon_from_inventory(weapon_type: WeaponType):
	"""Switch weapon from inventory UI"""
	switch_weapon(weapon_type)

func _update_weapon_state(key: String, value):
	"""Update centralized weapon state"""
	var old_value = weapon_state.get(key, null)
	weapon_state[key] = value
	
	# Log important state changes
	match key:
		"phaser_active":
			if value != old_value:
				print("WeaponSystem: Phaser active state changed: ", old_value, " -> ", value)
		"manual_weapon":
			if value != old_value:
				print("WeaponSystem: Manual weapon changed: ", old_value, " -> ", value)
		"auto_weapon":
			if value != old_value:
				print("WeaponSystem: Auto weapon changed: ", old_value, " -> ", value)

func _get_weapon_state(key: String):
	"""Get weapon state value"""
	return weapon_state.get(key, null)

func _can_fire_weapon(weapon_name: String, is_manual: bool) -> bool:
	"""Check if a weapon can fire based on current state"""
	if not weapons_enabled:
		return false
	
	var time_key = "last_manual_fire" if is_manual else "last_auto_fire"
	var last_fire = weapon_state.get(time_key, 0.0)
	var current_time = Time.get_time_dict_from_system()["second"]
	var fire_rate = WEAPON_CONFIG[WeaponType.BULLET].fire_rate if weapon_name == "turret" else 0.1
	
	# Check fire rate
	if current_time - last_fire < fire_rate:
		return false
	
	# Check for conflicts between manual and auto fire
	if is_manual and weapon_state.get("phaser_active", false) and weapon_state.get("phaser_manual", false):
		# Don't allow auto-fire while phaser is manually active
		return false
	
	return true

func _exit_tree():
	"""Clean up when WeaponSystem is removed"""
	print("WeaponSystem: Cleaning up resources")
	
	# Stop any active phaser beams
	if phaser_active and current_phaser_beam:
		current_phaser_beam.queue_free()
		current_phaser_beam = null
	
	# Clean up any remaining phaser weapon instances
	var phaser_weapons = get_tree().get_nodes_in_group("phaser_weapons")
	for weapon in phaser_weapons:
		if weapon.is_firing:
			weapon.stop_firing()
			weapon.queue_free()
	
	# Clear state
	weapon_state.clear()
	print("WeaponSystem: Cleanup complete")

# --- PRIORITY 2: UNIFIED WEAPON SYSTEM ---

func _create_weapon_instance(weapon_type: WeaponType) -> BaseWeapon:
	"""Create a weapon instance using the unified BaseWeapon architecture"""
	var config = WEAPON_CONFIG[weapon_type]
	var weapon_scene_path = config.get("weapon_scene", "")
	
	if weapon_scene_path == "":
		print("WeaponSystem: No weapon scene defined for ", weapon_type)
		return null
	
	var weapon_scene = load(weapon_scene_path)
	if not weapon_scene:
		print("WeaponSystem: Failed to load weapon scene: ", weapon_scene_path)
		return null
	
	var weapon_instance = weapon_scene.instantiate()
	if not weapon_instance:
		print("WeaponSystem: Failed to instantiate weapon")
		return null
	
	# Configure the weapon instance
	if weapon_instance.has_method("setup_weapon"):
		weapon_instance.setup_weapon()
		# Set weapon properties with robust error handling
		# Check for different damage property names
		if "damage" in weapon_instance:
			weapon_instance.set("damage", config.damage)
			print("WeaponSystem: Set damage to ", config.damage)
		elif "projectile_damage" in weapon_instance:
			weapon_instance.set("projectile_damage", config.damage)
			print("WeaponSystem: Set projectile_damage to ", config.damage)
		elif "beam_damage_per_second" in weapon_instance:
			weapon_instance.set("beam_damage_per_second", config.damage)
			print("WeaponSystem: Set beam_damage_per_second to ", config.damage)
		
		# Check for different fire rate property names
		if "fire_rate" in weapon_instance:
			weapon_instance.set("fire_rate", config.fire_rate)
			print("WeaponSystem: Set fire rate to ", config.fire_rate)
		elif "beam_lifetime" in weapon_instance:
			weapon_instance.set("beam_lifetime", config.fire_rate)
			print("WeaponSystem: Set beam_lifetime to ", config.fire_rate)
	
	# Set owner if player is available
	if player_node:
		weapon_instance.set_owner_node(player_node)
	
	return weapon_instance

func _fire_phaser_unified(target_position: Vector2, is_manual: bool = false):
	"""Unified phaser firing using BaseWeapon architecture"""
	print("WeaponSystem: Unified phaser firing - manual: ", is_manual)
	PhaserLogger.log_target("WeaponSystem", "_fire_phaser_unified begin manual=%s" % is_manual, target_position)
	
	# Create phaser weapon instance
	var phaser_weapon = _create_weapon_instance(WeaponType.PHASER)
	if not phaser_weapon:
		print("WeaponSystem: Failed to create phaser weapon instance")
		PhaserLogger.log_message("WeaponSystem", "_fire_phaser_unified failed - could not create weapon instance")
		if is_manual:
			manual_phaser_pending = false
		return
	
	# Add to scene
	get_tree().current_scene.add_child(phaser_weapon)
	
	# Configure for manual or auto fire
	phaser_weapon.auto_fire = not is_manual
	
	# Fire the weapon
	var success = phaser_weapon.fire_weapon(target_position, player_node)
	
	if success:
		# Update state - CRITICAL: Set phaser_active to true
		phaser_active = true
		_update_weapon_state("phaser_active", true)
		_update_weapon_state("phaser_manual", is_manual)
		_update_weapon_state("manual_weapon" if is_manual else "auto_weapon", "phaser")
		manual_phaser_pending = false
		
		# Connect signals
		phaser_weapon.weapon_stopped.connect(_on_unified_weapon_stopped)
		
		# Store reference
		current_phaser_beam = phaser_weapon
		
		phaser_started.emit()
		_log_message("Unified phaser beam started (" + ("Manual" if is_manual else "Auto") + ")", "Combat")
		PhaserLogger.log_message("WeaponSystem", "Phaser beam started manual=%s" % is_manual)
	else:
		# Clean up on failure
		phaser_weapon.queue_free()
		print("WeaponSystem: Failed to fire unified phaser weapon")
		PhaserLogger.log_message("WeaponSystem", "_fire_phaser_unified failed - fire_weapon returned false")
		if is_manual:
			manual_phaser_pending = false

func _on_unified_weapon_stopped(weapon: BaseWeapon):
	"""Handle unified weapon stopping"""
	print("WeaponSystem: Unified weapon stopped")
	
	# Update state - CRITICAL: Clear phaser_active flag
	phaser_active = false
	_update_weapon_state("phaser_active", false)
	_update_weapon_state("phaser_manual", false)
	_update_weapon_state("manual_weapon", "")
	_update_weapon_state("auto_weapon", "")
	
	# Clear reference
	if current_phaser_beam == weapon:
		current_phaser_beam = null
	
	# Note: The PhaserBeamsWeapon handles its own cleanup when it emits weapon_stopped
	# Don't queue_free here to avoid double-free issues
	
	phaser_stopped.emit()
	_log_message("Unified weapon stopped", "Combat")

func _is_manual_phaser_active() -> bool:
	return phaser_active and weapon_state.get("phaser_manual", false)
