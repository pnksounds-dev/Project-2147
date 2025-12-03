extends Node2D

class_name TraderHub

signal player_entered_hub()
signal player_exited_hub()

# Hub configuration
var hub_radius: float = 3000.0  # Default size, can be adjusted by seed
var guard_presence: float = 1.0  # Maximum guard presence
var weapons_disabled: bool = false

# Reference systems
var coordinate_system: CoordinateSystem
var notification_system: Node

func _ready():
	add_to_group("trader_hub")
	coordinate_system = get_tree().get_first_node_in_group("coordinate_system")
	notification_system = get_tree().get_first_node_in_group("hud")
	
	# Set position to (0,0) - always at center
	global_position = Vector2.ZERO
	
	# Connect to coordinate system
	if coordinate_system:
		coordinate_system.position_updated.connect(_on_position_updated)

func _on_position_updated(world_position: Vector2):
	"""Handle player position updates"""
	var was_in_hub = is_player_in_hub()
	var is_in_hub = is_player_in_hub_position(world_position)
	
	# Emit signals when entering/exiting hub
	if is_in_hub and not was_in_hub:
		_on_player_entered_hub()
	elif not is_in_hub and was_in_hub:
		_on_player_exited_hub()

func _on_player_entered_hub():
	"""Handle player entering trader hub"""
	player_entered_hub.emit()
	_disable_weapons()
	_show_hub_welcome()

func _on_player_exited_hub():
	"""Handle player exiting trader hub"""
	player_exited_hub.emit()
	_enable_weapons()
	_show_hub_goodbye()

func is_player_in_hub() -> bool:
	"""Check if player is currently in hub"""
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return false
	return is_player_in_hub_position(player.global_position)

func is_player_in_hub_position(position: Vector2) -> bool:
	"""Check if given position is in hub area"""
	return position.distance_to(global_position) <= hub_radius

func _disable_weapons():
	"""Disable player weapons in hub"""
	weapons_disabled = true
	
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("disable_weapons"):
		player.disable_weapons()
	
	# Show notification
	_show_notification("Weapons disabled for trader hub safety")

func _enable_weapons():
	"""Enable player weapons when leaving hub"""
	weapons_disabled = false
	
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("enable_weapons"):
		player.enable_weapons()
	
	# Show notification
	_show_notification("Weapons re-enabled")

func _show_hub_welcome():
	"""Show welcome message when entering hub"""
	_show_notification("Welcome to Trader Hub - Central Trading Station")

func _show_hub_goodbye():
	"""Show goodbye message when leaving hub"""
	_show_notification("Thanks for visiting Trader Hub")

func _show_notification(message: String):
	"""Show notification through notification system"""
	if notification_system:
		if notification_system.has_method("show_notification"):
			notification_system.show_notification(message, 3.0)
		else:
			print("Trader Hub: ", message)
	else:
		print("Trader Hub: ", message)

func set_hub_size(new_radius: float):
	"""Set hub size (can be adjusted by seed)"""
	hub_radius = new_radius
	print("Trader Hub: Size set to ", hub_radius, " units")

func get_hub_info() -> Dictionary:
	"""Get hub information"""
	return {
		"position": global_position,
		"radius": hub_radius,
		"guard_presence": guard_presence,
		"weapons_disabled": weapons_disabled,
		"player_in_hub": is_player_in_hub()
	}
