extends Node

signal coins_changed(amount: int)
signal transaction_completed(success: bool, message: String)

var coins: int = 0
var total_coins_earned: int = 0
var total_coins_spent: int = 0

# Coin values
const ENEMY_COIN_DROP = 5
const MOTHERSHIP_COIN_DROP = 25
const SCOUT_COIN_DROP = 2
const LEVEL_COIN_BONUS = 50

# Upgrade costs (will be expanded)
const WEAPON_UPGRADE_COST = 100
const HEALTH_UPGRADE_COST = 75
const SPEED_UPGRADE_COST = 150

func _ready():
	add_to_group("economy_system")
	_load_coins()
	print("EconomySystem: Initialized with ", coins, " coins")

func add_coins(amount: int):
	if amount <= 0:
		return false
	
	coins += amount
	total_coins_earned += amount
	coins_changed.emit(coins)
	_save_coins()
	
	print("EconomySystem: Added ", amount, " coins (total: ", coins, ")")
	return true

func spend_coins(amount: int) -> bool:
	if amount <= 0:
		return false
	
	if coins >= amount:
		coins -= amount
		total_coins_spent += amount
		coins_changed.emit(coins)
		_save_coins()
		
		print("EconomySystem: Spent ", amount, " coins (remaining: ", coins, ")")
		transaction_completed.emit(true, "Transaction successful")
		return true
	else:
		print("EconomySystem: Insufficient coins (need ", amount, ", have ", coins, ")")
		transaction_completed.emit(false, "Insufficient coins")
		return false

func add_enemy_coin_drop(enemy_type: String):
	var amount = ENEMY_COIN_DROP
	
	match enemy_type.to_lower():
		"mothership":
			amount = MOTHERSHIP_COIN_DROP
		"scout":
			amount = SCOUT_COIN_DROP
		"enemy":
			amount = ENEMY_COIN_DROP
		_:
			amount = ENEMY_COIN_DROP
	
	add_coins(amount)
	return amount

func add_level_coin_bonus():
	add_coins(LEVEL_COIN_BONUS)
	return LEVEL_COIN_BONUS

func get_coins() -> int:
	return coins

func get_total_coins_earned() -> int:
	return total_coins_earned

func get_total_coins_spent() -> int:
	return total_coins_spent

func can_afford(amount: int) -> bool:
	return coins >= amount

func get_affordability_color(amount: int) -> Color:
	if can_afford(amount):
		return Color.GREEN
	else:
		return Color.RED

func purchase_upgrade(upgrade_type: String) -> bool:
	var cost = 0
	
	match upgrade_type.to_lower():
		"weapon":
			cost = WEAPON_UPGRADE_COST
		"health":
			cost = HEALTH_UPGRADE_COST
		"speed":
			cost = SPEED_UPGRADE_COST
		_:
			print("EconomySystem: Unknown upgrade type: ", upgrade_type)
			return false
	
	return spend_coins(cost)

func _load_coins():
	# Load coins from save file
	var file = FileAccess.open("user://coins.save", FileAccess.READ)
	if file:
		coins = file.get_32()
		total_coins_earned = file.get_32()
		total_coins_spent = file.get_32()
		file.close()
	else:
		coins = 0
		total_coins_earned = 0
		total_coins_spent = 0

func _save_coins():
	# Save coins to file
	var file = FileAccess.open("user://coins.save", FileAccess.WRITE)
	if file:
		file.store_32(coins)
		file.store_32(total_coins_earned)
		file.store_32(total_coins_spent)
		file.close()

func reset_coins():
	coins = 0
	total_coins_earned = 0
	total_coins_spent = 0
	coins_changed.emit(coins)
	_save_coins()

func get_coin_statistics() -> Dictionary:
	return {
		"current_coins": coins,
		"total_earned": total_coins_earned,
		"total_spent": total_coins_spent,
		"net_coins": total_coins_earned - total_coins_spent
	}
