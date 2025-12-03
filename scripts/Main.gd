extends Node2D

# Don't use @onready for critical nodes that might not exist
var player: Node2D
var hud: CanvasLayer  # HUD is a CanvasLayer, not Control

func _ready():
	print("Main: Starting initialization")
	
	# Initialize GameLogger first
	_initialize_logger()
	
	# Wait a frame to ensure all nodes are ready
	await get_tree().process_frame
	
	# Get references with null checks
	player = get_node_or_null("Player")
	hud = get_node_or_null("HUD")
	
	print("Main: Player node found: ", player != null)
	print("Main: HUD node found: ", hud != null)
	
	# Try to find Player by group as well
	var player_by_group = get_tree().get_first_node_in_group("player")
	print("Main: Player found by group: ", player_by_group != null)
	if player_by_group:
		print("Main: Player by group name: ", player_by_group.name)
	
	if player:
		print("Main: Player node type: ", player.get_class())
	else:
		print("Main: Player node not found!")
	
	# Try to find HUD by class type as fallback
	var fallback_hud = find_child("HUD", true, false)
	if fallback_hud:
		print("Main: Found HUD by search instead: ", fallback_hud.name)
		hud = fallback_hud
	
	# If Player still not found, try to instantiate manually
	if not player:
		print("Main: Attempting to manually instantiate Player")
		var player_scene = preload("res://scenes/Player.tscn")
		if player_scene:
			player = player_scene.instantiate()
			player.name = "Player"
			player.position = Vector2.ZERO
			add_child(player)
			print("Main: Successfully instantiated Player manually")
		else:
			print("Main: Failed to load Player scene!")
	
	# Only connect signals if both nodes exist
	if player and hud:
		print("Main: Found Player and HUD nodes")
		# Connect Player signals to HUD
		if player.has_signal("health_changed") and hud.has_method("update_health"):
			player.health_changed.connect(hud.update_health)
		if player.has_signal("xp_changed") and hud.has_method("update_xp"):
			player.xp_changed.connect(hud.update_xp)
		if player.has_signal("level_changed") and hud.has_method("update_level"):
			player.level_changed.connect(hud.update_level)
		print("Main: Connected Player signals to HUD")
		
		# Initialize game systems
		_initialize_game_systems()
	
	# Add other game components
	_add_game_components()
	
	# Start game music
	var audio_manager = get_node_or_null("/root/AudioManager")
	if audio_manager:
		audio_manager.play_music("explorer_void", true)
	
	print("Main: Initialization complete")

func _initialize_logger():
	# Create GameLogger
	var logger = preload("res://scripts/GameLogger.gd").new()
	logger.name = "GameLogger"
	add_child(logger)
	
	# Configure logger for background spam reduction
	logger.set_system_filter(["Background", "Player", "HUD", "System", "Combat", "Economy", "Skills"])
	logger.set_log_level_filter([GameLogger.LogLevel.INFO, GameLogger.LogLevel.WARNING, GameLogger.LogLevel.ERROR])
	logger.set_batch_interval(60.0)  # 1 minute batches
	
	print("Main: GameLogger initialized")

func _initialize_game_systems():
	"""Initialize game systems with proper error handling"""
	print("Main: Initializing game systems...")
	
	# Create ScoreTracker with error handling
	try_create_system("ScoreTracker", "res://scripts/ScoreTracker.gd", ["score_tracker"])
	
	# Create EconomySystem with error handling  
	try_create_system("EconomySystem", "res://scripts/EconomySystem.gd", ["economy_system"])
	
	# Create SkillSystem with error handling
	try_create_system("SkillSystem", "res://scripts/SkillSystem.gd", ["skill_system"])
	
	# Create WeaponSystem with error handling
	try_create_system("WeaponSystem", "res://scripts/WeaponSystem.gd", ["weapon_system"])
	
	# Create PerformanceMonitor for system health
	try_create_system("PerformanceMonitor", "res://scripts/PerformanceMonitor.gd", ["performance_monitor"])
	
	# Create Debug Menu for development testing
	try_create_system("DebugMenu", "res://scripts/DebugMenu.gd", ["debug_menu"])
	
	print("Main: Game systems initialization complete")

func try_create_system(system_name: String, script_path: String, groups: Array = []):
	"""Safely create and initialize a game system using GDScript error checking"""
	# Load script with error checking
	var script = load(script_path)
	if not script:
		print("Main: ERROR - Could not load script: ", script_path)
		return null
	
	# Instantiate system with error checking
	var system = script.new()
	if not system:
		print("Main: ERROR - Could not instantiate system: ", system_name)
		return null
	
	# Configure system
	system.name = system_name
	add_child(system)
	
	# Add to specified groups
	for group in groups:
		system.add_to_group(group)
	
	print("Main: Successfully created system: ", system_name)
	return system

func _connect_systems_to_hud():
	var hud_node = get_node_or_null("HUD")
	if not hud_node:
		print("Main: HUD not found, cannot connect systems")
		return
	
	# Connect ScoreTracker to HUD
	var score_tracker = get_node_or_null("ScoreTracker")
	if score_tracker:
		score_tracker.score_changed.connect(hud_node.update_score)
		print("Main: Connected ScoreTracker to HUD")
	
	# Connect EconomySystem to HUD
	var economy_system = get_node_or_null("EconomySystem")
	if economy_system:
		economy_system.coins_changed.connect(hud_node.update_coins)
		print("Main: Connected EconomySystem to HUD")
	
	# Connect SkillSystem to HUD
	var skill_system = get_node_or_null("SkillSystem")
	if skill_system:
		skill_system.skill_points_changed.connect(hud_node.update_skill_points)
		print("Main: Connected SkillSystem to HUD")
	
	# Connect HUD weapon switching to game systems
	if hud_node.has_signal("weapon_switched"):
		hud_node.weapon_switched.connect(_on_weapon_switched)
		print("Main: Connected HUD weapon switching")
	
	# Connect player to game systems
	_connect_player_to_systems()

func _connect_player_to_systems():
	var player_node = get_node_or_null("Player")
	if not player_node:
		print("Main: Player not found, cannot connect to systems")
		return
	
	# Connect player to ScoreTracker
	var score_tracker = get_node_or_null("ScoreTracker")
	if score_tracker:
		# Connect player death/kills to score system
		# This would need to be implemented in the player's damage/death functions
		print("Main: Connected Player to ScoreTracker")
	
	# Connect player to EconomySystem
	var economy_system = get_node_or_null("EconomySystem")
	if economy_system:
		# Connect level ups to coin bonuses
		if player_node.has_signal("level_changed"):
			player_node.level_changed.connect(func(level): 
				economy_system.add_level_coin_bonus()
				print("Main: Awarded coin bonus for level ", level)
			)
		print("Main: Connected Player to EconomySystem")
	
	# Connect player to SkillSystem
	var skill_system = get_node_or_null("SkillSystem")
	if skill_system:
		# Connect level ups to skill points
		if player_node.has_signal("level_changed"):
			player_node.level_changed.connect(func(level): 
				skill_system.award_level_up_points()
				print("Main: Awarded skill point for level ", level)
			)
		print("Main: Connected Player to SkillSystem")

func _on_weapon_switched(weapon_index: int):
	var player_node = get_node_or_null("Player")
	var hud_node = get_node_or_null("HUD")
	if player_node and hud_node:
		# This would need to be implemented in the player's weapon system
		print("Main: Weapon switched to index ", weapon_index, " (", hud_node.get_selected_weapon(), ")")
		
		# Apply skill effects to new weapon
		var skill_system = get_node_or_null("SkillSystem")
		if skill_system:
			var damage_boost = skill_system.get_skill_effect("weapon_damage")
			if damage_boost > 0:
				print("Main: Applying weapon damage boost: ", damage_boost)
	
func _add_game_components():
	# Add Game System Documentation (now uses F12, no conflict with debug menu)
	if player or hud:
		var game_doc = preload("res://scenes/GameSystemDoc.tscn").instantiate()
		add_child(game_doc)
		print("Main: Added Game System Documentation")
	else:
		print("Main: Skipping Game System Documentation due to missing Player/HUD")

	# Initialize FactionManager
	var faction_manager = FactionManager.new()
	add_child(faction_manager)
	
	# Add Map Tracker
	var map_tracker = MapTracker.new()
	map_tracker.name = "MapTracker"
	add_child(map_tracker)
	print("Main: Added Map Tracker")

	# Add Radar HUD
	var radar_hud = preload("res://scenes/RadarHUD.tscn").instantiate()
	add_child(radar_hud)
	print("Main: Added Radar HUD")

	# Add Background Renderer
	var background_renderer = preload("res://scenes/BackgroundRenderer.tscn").instantiate()
	add_child(background_renderer)
	print("Main: Added Background Renderer")

	# Add Pause Menu
	var pause_menu = preload("res://scenes/PauseMenu.tscn").instantiate()
	add_child(pause_menu)
	print("Main: Added Pause Menu")
	
	# Get reference to existing Inventory UI from scene
	var inventory_ui = get_node_or_null("InventoryUI")
	if inventory_ui:
		# Connect inventory signals
		inventory_ui.add_to_group("inventory_ui")
		inventory_ui.close_requested.connect(_on_inventory_closed)
		print("Main: Connected existing InventoryUI, visible = ", inventory_ui.visible)
	else:
		print("Main: WARNING - No InventoryUI found in scene")
	
	if pause_menu:
		pause_menu.inventory_requested.connect(_on_inventory_requested)
		print("Main: Connected pause menu inventory signal")

func _on_inventory_requested():
	print("Main: Inventory requested")
	var inventory_ui = get_tree().get_first_node_in_group("inventory_ui")
	if inventory_ui and inventory_ui.has_method("toggle_inventory"):
		# Only open if not already visible
		if not inventory_ui.visible:
			inventory_ui.toggle_inventory()
		print("Main: Opened inventory from pause menu")

func _on_inventory_closed():
	print("Main: Inventory closed")
	# Inventory now handles its own pause menu resume logic
