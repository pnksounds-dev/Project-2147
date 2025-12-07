extends Node

class_name StockManager

# Manages trader stock rotation with time-based refresh
# Stock rotates every 30 minutes of real-world time

signal stock_refreshed(new_stock: Array)

const REFRESH_INTERVAL_SECONDS = 10 # 30 minutes (use 10 for testing)
const STOCK_SIZE = 12

var current_stock: Array = [] # Array of item IDs
var last_refresh_timestamp: int = 0
var item_database

func _ready():
	add_to_group("stock_manager")
	item_database = get_tree().get_first_node_in_group("item_database")
	
	# Load saved state or generate initial stock
	_load_stock_state()
	
	# Check if refresh is needed
	_check_and_refresh()

func _check_and_refresh() -> void:
	var current_time = Time.get_unix_time_from_system()
	var time_since_refresh = current_time - last_refresh_timestamp
	
	if time_since_refresh >= REFRESH_INTERVAL_SECONDS or current_stock.is_empty():
		print("StockManager: Refreshing stock (", int(time_since_refresh), "s since last refresh)")
		_generate_new_stock()
	else:
		var time_remaining = REFRESH_INTERVAL_SECONDS - time_since_refresh
		print("StockManager: Stock loaded. Next refresh in ", int(time_remaining), " seconds")

func _generate_new_stock() -> void:
	if not item_database:
		print("StockManager: No ItemDatabase found")
		return
	
	var all_items = item_database.get_all_items()
	var items_list = []
	
	# Convert to array if dictionary
	if typeof(all_items) == TYPE_DICTIONARY:
		items_list = all_items.values()
	elif typeof(all_items) == TYPE_ARRAY:
		items_list = all_items
	
	# Clear current stock
	current_stock.clear()
	
	# Shuffle and pick N items
	items_list.shuffle()
	
	for i in range(min(STOCK_SIZE, items_list.size())):
		var item = items_list[i]
		var id = ""
		
		if item is Dictionary:
			id = item.get("id", "")
		elif item is Resource:
			id = item.id
		
		if id != "":
			current_stock.append(id)
	
	# Update timestamp
	last_refresh_timestamp = Time.get_unix_time_from_system()
	
	# Save state
	_save_stock_state()
	
	# Emit signal
	stock_refreshed.emit(current_stock)
	
	print("StockManager: Generated ", current_stock.size(), " items for stock")

func get_current_stock() -> Array:
	return current_stock.duplicate()

func get_time_until_refresh() -> int:
	var current_time = Time.get_unix_time_from_system()
	var time_since_refresh = current_time - last_refresh_timestamp
	return max(0, REFRESH_INTERVAL_SECONDS - time_since_refresh)

func force_refresh() -> void:
	"""Debug function to manually trigger stock refresh"""
	_generate_new_stock()

func _save_stock_state() -> void:
	var save_data = {
		"stock": current_stock,
		"timestamp": last_refresh_timestamp
	}
	
	var save_path = "user://stock_state.json"
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data))
		file.close()
		print("StockManager: Saved stock state")

func _load_stock_state() -> void:
	var save_path = "user://stock_state.json"
	
	if not FileAccess.file_exists(save_path):
		print("StockManager: No saved stock state found")
		return
	
	var file = FileAccess.open(save_path, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		
		if parse_result == OK:
			var data = json.data
			if data is Dictionary:
				current_stock = data.get("stock", [])
				last_refresh_timestamp = data.get("timestamp", 0)
				print("StockManager: Loaded stock state with ", current_stock.size(), " items")
		else:
			print("StockManager: Failed to parse saved stock state")
