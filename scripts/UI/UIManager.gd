extends Node

class_name UIManager

## UIManager - Central coordination for all UI systems

var hud: Node
var inventory_ui: Node
var notification_panel: Node

func _ready():
	add_to_group("ui_manager")
	_initialize_ui_systems()

func _initialize_ui_systems():
	# Find or create HUD
	hud = get_tree().get_first_node_in_group("hud")
	if not hud:
		print("UIManager: No HUD found, creating default")
		_create_default_hud()
	
	# Find or create Inventory UI
	inventory_ui = get_tree().get_first_node_in_group("inventory_ui")
	if not inventory_ui:
		print("UIManager: No InventoryUI found, creating default")
		_create_default_inventory()
	
	# Find or create Notification Panel
	notification_panel = get_tree().get_first_node_in_group("notification_panel")
	if not notification_panel:
		print("UIManager: No NotificationPanel found, creating default")
		_create_default_notification_panel()

func _create_default_hud():
	var hud_scene = preload("res://scenes/HUD_Complete.tscn")
	hud = hud_scene.instantiate()
	add_child(hud)

func _create_default_inventory():
	# Don't create inventory - use the existing one from the scene
	print("UIManager: Using existing InventoryUI from scene")
	inventory_ui = get_tree().get_first_node_in_group("inventory_ui")

func _create_default_notification_panel():
	var notification_scene = preload("res://scenes/UI/NotificationPanel.tscn")
	notification_panel = notification_scene.instantiate()
	add_child(notification_panel)

# Health and Status
func update_health(current: int, maximum: int):
	if hud and hud.has_method("update_health"):
		hud.update_health(current, maximum)

func update_xp(current: int, required: int):
	if hud and hud.has_method("update_xp"):
		hud.update_xp(current, required)

func update_level(level: int):
	if hud and hud.has_method("update_level"):
		hud.update_level(level)

# Economy
func update_score(score: int):
	if hud and hud.has_method("update_score"):
		hud.update_score(score)

func update_coins(coins: int):
	if hud and hud.has_method("update_coins"):
		hud.update_coins(coins)

# Inventory
func toggle_inventory():
	if inventory_ui and inventory_ui.has_method("toggle_inventory"):
		inventory_ui.toggle_inventory()

# Notifications
func show_notification(message: String, duration: float = 3.0):
	if notification_panel and notification_panel.has_method("show_notification"):
		notification_panel.show_notification(message)
	elif hud and hud.has_method("show_notification"):
		hud.show_notification(message, duration)
	else:
		print("UI Notification: ", message)

func show_achievement(achievement_name: String, description: String):
	if notification_panel and notification_panel.has_method("show_notification"):
		notification_panel.show_notification("🏆 " + achievement_name + ": " + description)
	else:
		show_notification("🏆 " + achievement_name, 4.0)

func show_milestone(milestone: String, reward: String = ""):
	if notification_panel and notification_panel.has_method("show_notification"):
		var msg = milestone
		if reward != "":
			msg += "\nReward: " + reward
		notification_panel.show_notification("⭐ " + msg)
	else:
		var msg = milestone
		if reward != "":
			msg += "\nReward: " + reward
		show_notification("⭐ " + msg, 3.5)

# Weapons
func switch_weapon(weapon_index: int):
	if hud and hud.has_method("switch_weapon_from_inventory"):
		hud.switch_weapon_from_inventory(weapon_index)
