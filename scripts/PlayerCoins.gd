extends Node

class_name PlayerCoins

## PlayerCoins - Manages player's currency system

signal coins_changed(new_amount: int)
signal coins_added(amount: int)
signal coins_spent(amount: int)

var coins: int = 100  # Starting coins
var max_coins: int = 999999

func _ready():
	add_to_group("player_coins")
	print("PlayerCoins: Initialized with ", coins, " coins")

func add_coins(amount: int) -> bool:
	"""Add coins to player's balance"""
	if amount <= 0:
		return false
	
	coins = min(coins + amount, max_coins)
	coins_added.emit(amount)
	coins_changed.emit(coins)
	print("PlayerCoins: Added ", amount, " coins. Total: ", coins)
	return true

func spend_coins(amount: int) -> bool:
	"""Spend coins from player's balance"""
	if amount <= 0 or coins < amount:
		return false
	
	coins -= amount
	coins_spent.emit(amount)
	coins_changed.emit(coins)
	print("PlayerCoins: Spent ", amount, " coins. Remaining: ", coins)
	return true

func get_coins() -> int:
	"""Get current coin amount"""
	return coins

func can_afford(cost: int) -> bool:
	"""Check if player can afford something"""
	return coins >= cost

func set_coins(amount: int):
	"""Set coin amount (for testing/debug)"""
	coins = clamp(amount, 0, max_coins)
	coins_changed.emit(coins)
	print("PlayerCoins: Set coins to ", coins)

# Save/load functionality for persistence
func get_save_data() -> Dictionary:
	return {"coins": coins}

func load_save_data(data: Dictionary):
	if data.has("coins"):
		set_coins(data["coins"])
