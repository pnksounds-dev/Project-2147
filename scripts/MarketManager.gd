extends Node

## MarketManager - Handles dynamic economy, price fluctuations, and stock levels

signal market_updated
signal price_changed(item_id: String, new_price: int, trend: int) # trend: 1=up, -1=down, 0=stable
signal stock_changed(item_id: String, new_stock: int)

# Configuration
const UPDATE_INTERVAL: float = 300.0 # Market updates every 5 minutes
const MAX_PRICE_MULTIPLIER: float = 3.0
const MIN_PRICE_MULTIPLIER: float = 0.25
const VOLATILITY_BASE: float = 0.1 # 10% standard variance

# Market State
# format: { item_id: { "price": int, "stock": int, "trend": int, "base_price": int } }
var market_data: Dictionary = {}

# Event System
var active_events: Array = []

func _ready():
	add_to_group("market_manager")
	# Initialize market with data from ItemDatabase
	call_deferred("_initialize_market")
	
	# Start market update timer
	var timer = Timer.new()
	timer.wait_time = UPDATE_INTERVAL
	timer.autostart = true
	timer.timeout.connect(_on_market_update_tick)
	add_child(timer)

func _initialize_market() -> void:
	"""Initialize market data from ItemDatabase base values"""
	var item_db = get_tree().get_first_node_in_group("item_database")
	if not item_db:
		print("MarketManager: ItemDatabase not found, retrying in 1s...")
		await get_tree().create_timer(1.0).timeout
		_initialize_market()
		return
		
	var all_items = item_db.get_all_items()
	for entry in all_items:
		var id = entry.id
		var data = entry.data
		
		# Skip if already initialized (loaded from save)
		if market_data.has(id):
			continue
			
		market_data[id] = {
			"base_price": data.get("buy_price", 100),
			"price": data.get("buy_price", 100),
			"stock": randi_range(5, 50), # Random starting stock
			"trend": 0,
			"volatility": _get_volatility_for_type(data.get("type", 0))
		}
	
	print("MarketManager: Initialized with ", market_data.size(), " items")
	market_updated.emit()

func _get_volatility_for_type(type_enum: int) -> float:
	# Higher volatility for resources, lower for consumables
	match type_enum:
		3: return 0.2 # RESOURCES
		0: return 0.05 # WEAPONS (Stable)
		_: return 0.1

func get_item_price(item_id: String) -> int:
	"""Get current market price for an item"""
	if market_data.has(item_id):
		return market_data[item_id]["price"]
	
	# Fallback to base database price if not in market
	var item_db = get_tree().get_first_node_in_group("item_database")
	if item_db:
		return item_db.get_buy_price(item_id)
	return 0

func get_item_stock(item_id: String) -> int:
	"""Get current stock level"""
	if market_data.has(item_id):
		return market_data[item_id]["stock"]
	return 0

func process_transaction(item_id: String, quantity: int, is_buying: bool) -> bool:
	"""Process a transaction and adjust market influence"""
	if not market_data.has(item_id):
		return false
		
	var item = market_data[item_id]
	
	if is_buying:
		if item.stock < quantity:
			return false
		item.stock -= quantity
		# Buying reduces supply -> Price goes UP
		_adjust_price_influence(item_id, 0.02 * quantity) 
	else:
		item.stock += quantity
		# Selling increases supply -> Price goes DOWN
		_adjust_price_influence(item_id, -0.015 * quantity)
		
	stock_changed.emit(item_id, item.stock)
	return true

func _adjust_price_influence(item_id: String, percent_change: float) -> void:
	"""Apply direct influence to price (Supply/Demand)"""
	if not market_data.has(item_id):
		return
		
	var item = market_data[item_id]
	var old_price = item.price
	var influence = 1.0 + percent_change
	
	var new_price = int(item.price * influence)
	
	# Clamp values
	var min_p = int(item.base_price * MIN_PRICE_MULTIPLIER)
	var max_p = int(item.base_price * MAX_PRICE_MULTIPLIER)
	new_price = clampi(new_price, min_p, max_p)
	
	if new_price != old_price:
		item.price = new_price
		item.trend = 1 if new_price > old_price else -1
		price_changed.emit(item_id, new_price, item.trend)

func _on_market_update_tick() -> void:
	"""Periodic market fluctuation"""
	print("MarketManager: Updating market prices...")
	for id in market_data:
		var item = market_data[id]
		
		# Random fluctuation
		var change = randf_range(-item.volatility, item.volatility)
		
		# Tendency to return to base price over time (Market Correction)
		var deviation = float(item.price) / float(item.base_price)
		if deviation > 1.5:
			change -= 0.05 # Push down
		elif deviation < 0.5:
			change += 0.05 # Push up
			
		_adjust_price_influence(id, change)
		
		# Restock logic
		if item.stock < 10:
			item.stock += randi_range(1, 5)
			stock_changed.emit(id, item.stock)
