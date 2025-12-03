extends Control

class_name TradingPanel

## TradingPanel - UI for buying and selling items at ARK stations

signal trading_completed()
signal item_purchased(item_id: String, quantity: int)
signal item_sold(item_id: String, quantity: int)

# UI References
@onready var tab_container: TabContainer = $VBoxContainer/TabContainer
@onready var buy_tab: Control = $VBoxContainer/TabContainer/BuyTab
@onready var sell_tab: Control = $VBoxContainer/TabContainer/SellTab

@onready var coins_label: Label = $VBoxContainer/HeaderPanel/CoinsLabel
@onready var close_button: Button = $VBoxContainer/HeaderPanel/CloseButton

# Buy Tab UI
@onready var buy_item_list: ItemList = $VBoxContainer/TabContainer/BuyTab/HSplitContainer/BuyItemList
@onready var buy_details_panel: Panel = $VBoxContainer/TabContainer/BuyTab/HSplitContainer/BuyDetailsPanel
@onready var buy_item_name: Label = $VBoxContainer/TabContainer/BuyTab/HSplitContainer/BuyDetailsPanel/VBoxContainer/ItemNameLabel
@onready var buy_item_description: Label = $VBoxContainer/TabContainer/BuyTab/HSplitContainer/BuyDetailsPanel/VBoxContainer/DescriptionLabel
@onready var buy_item_price: Label = $VBoxContainer/TabContainer/BuyTab/HSplitContainer/BuyDetailsPanel/VBoxContainer/PriceLabel
@onready var buy_quantity_spinbox: SpinBox = $VBoxContainer/TabContainer/BuyTab/HSplitContainer/BuyDetailsPanel/VBoxContainer/QuantityContainer/QuantitySpinBox
@onready var buy_total_price: Label = $VBoxContainer/TabContainer/BuyTab/HSplitContainer/BuyDetailsPanel/VBoxContainer/TotalPriceLabel
@onready var buy_button: Button = $VBoxContainer/TabContainer/BuyTab/HSplitContainer/BuyDetailsPanel/VBoxContainer/BuyButton

# Sell Tab UI
@onready var sell_item_list: ItemList = $VBoxContainer/TabContainer/SellTab/HSplitContainer/SellItemList
@onready var sell_details_panel: Panel = $VBoxContainer/TabContainer/SellTab/HSplitContainer/SellDetailsPanel
@onready var sell_item_name: Label = $VBoxContainer/TabContainer/SellTab/HSplitContainer/SellDetailsPanel/VBoxContainer/ItemNameLabel
@onready var sell_item_description: Label = $VBoxContainer/TabContainer/SellTab/HSplitContainer/SellDetailsPanel/VBoxContainer/DescriptionLabel
@onready var sell_item_price: Label = $VBoxContainer/TabContainer/SellTab/HSplitContainer/SellDetailsPanel/VBoxContainer/PriceLabel
@onready var sell_quantity_spinbox: SpinBox = $VBoxContainer/TabContainer/SellTab/HSplitContainer/SellDetailsPanel/VBoxContainer/QuantityContainer/QuantitySpinBox
@onready var sell_total_price: Label = $VBoxContainer/TabContainer/SellTab/HSplitContainer/SellDetailsPanel/VBoxContainer/TotalPriceLabel
@onready var sell_button: Button = $VBoxContainer/TabContainer/SellTab/HSplitContainer/SellDetailsPanel/VBoxContainer/SellButton

# System references
var item_database
var player_coins
var audio_manager

# Current selection
var current_buy_item: String = ""
var current_sell_item: String = ""

func _ready():
	add_to_group("trading_panel")
	
	# Get system references
	item_database = get_tree().get_first_node_in_group("item_database")
	player_coins = get_tree().get_first_node_in_group("player_coins")
	audio_manager = get_tree().get_first_node_in_group("audio_manager")
	
	# Connect signals
	close_button.pressed.connect(_on_close_pressed)
	buy_button.pressed.connect(_on_buy_pressed)
	sell_button.pressed.connect(_on_sell_pressed)
	
	# Connect item list signals
	buy_item_list.item_selected.connect(_on_buy_item_selected)
	sell_item_list.item_selected.connect(_on_sell_item_selected)
	
	# Connect quantity spinbox signals
	buy_quantity_spinbox.value_changed.connect(_on_buy_quantity_changed)
	sell_quantity_spinbox.value_changed.connect(_on_sell_quantity_changed)
	
	# Initialize UI
	visible = false
	_populate_buy_items()
	_populate_sell_items()
	_update_coins_display()

func open_trading():
	"""Open the trading interface"""
	visible = true
	_populate_buy_items()
	_populate_sell_items()
	_update_coins_display()
	
	# Reset selections
	buy_item_list.deselect_all()
	sell_item_list.deselect_all()
	_reset_buy_details()
	_reset_sell_details()
	
	print("TradingPanel: Trading interface opened")

func close_trading():
	"""Close the trading interface"""
	visible = false
	trading_completed.emit()
	
	if audio_manager:
		audio_manager.play_button_click()
	
	print("TradingPanel: Trading interface closed")

func _populate_buy_items():
	"""Populate buy tab with available items"""
	if not item_database:
		return
	
	buy_item_list.clear()
	var all_items = item_database.get_all_items()
	
	for item in all_items:
		var item_id = item["id"]
		var item_data = item["data"]
		
		var item_text = item_data["name"] + " - " + str(item_data["buy_price"]) + " coins"
		buy_item_list.add_item(item_text, null, true)
		
		# Store item ID as metadata
		var item_index = buy_item_list.get_item_count() - 1
		buy_item_list.set_item_metadata(item_index, item_id)

func _populate_sell_items():
	"""Populate sell tab with player's inventory items"""
	sell_item_list.clear()
	
	# TODO: Get actual player inventory
	# For now, add some placeholder items
	var player_inventory = ["health_pack", "shield_pack", "scrap_metal"]
	
	for item_id in player_inventory:
		if item_database:
			var item_data = item_database.get_item(item_id)
			if not item_data.is_empty():
				var item_text = item_data["name"] + " - " + str(item_data["sell_price"]) + " coins"
				sell_item_list.add_item(item_text, null, true)
				
				# Store item ID as metadata
				var item_index = sell_item_list.get_item_count() - 1
				sell_item_list.set_item_metadata(item_index, item_id)

func _update_coins_display():
	"""Update the coin display"""
	if player_coins:
		coins_label.text = "Coins: " + str(player_coins.get_coins())

func _on_close_pressed():
	close_trading()

func _on_buy_item_selected(index: int):
	"""Handle buy item selection"""
	if index < 0:
		_reset_buy_details()
		return
	
	var item_id = buy_item_list.get_item_metadata(index)
	if item_id is String and item_database:
		current_buy_item = item_id
		_update_buy_details(item_id)

func _on_sell_item_selected(index: int):
	"""Handle sell item selection"""
	if index < 0:
		_reset_sell_details()
		return
	
	var item_id = sell_item_list.get_item_metadata(index)
	if item_id is String and item_database:
		current_sell_item = item_id
		_update_sell_details(item_id)

func _update_buy_details(item_id: String):
	"""Update buy details panel"""
	var item_data = item_database.get_item(item_id)
	if item_data.is_empty():
		return
	
	buy_item_name.text = item_data["name"]
	buy_item_description.text = item_data["description"]
	buy_item_price.text = "Price: " + str(item_data["buy_price"]) + " coins each"
	
	# Reset quantity to 1
	buy_quantity_spinbox.value = 1
	_update_buy_total_price()

func _update_sell_details(item_id: String):
	"""Update sell details panel"""
	var item_data = item_database.get_item(item_id)
	if item_data.is_empty():
		return
	
	sell_item_name.text = item_data["name"]
	sell_item_description.text = item_data["description"]
	sell_item_price.text = "Price: " + str(item_data["sell_price"]) + " coins each"
	
	# Reset quantity to 1
	sell_quantity_spinbox.value = 1
	_update_sell_total_price()

func _on_buy_quantity_changed(_value: float):
	_update_buy_total_price()

func _on_sell_quantity_changed(_value: float):
	_update_sell_total_price()

func _update_buy_total_price():
	"""Update total price for buy tab"""
	if current_buy_item.is_empty() or not item_database:
		buy_total_price.text = "Total: 0 coins"
		return
	
	var item_data = item_database.get_item(current_buy_item)
	var quantity = int(buy_quantity_spinbox.value)
	var total = item_data["buy_price"] * quantity
	
	buy_total_price.text = "Total: " + str(total) + " coins"
	
	# Update buy button state
	if player_coins:
		buy_button.disabled = not player_coins.can_afford(total)

func _update_sell_total_price():
	"""Update total price for sell tab"""
	if current_sell_item.is_empty() or not item_database:
		sell_total_price.text = "Total: 0 coins"
		return
	
	var item_data = item_database.get_item(current_sell_item)
	var quantity = int(sell_quantity_spinbox.value)
	var total = item_data["sell_price"] * quantity
	
	sell_total_price.text = "Total: " + str(total) + " coins"
	sell_button.disabled = false

func _on_buy_pressed():
	"""Handle buy button press"""
	if current_buy_item.is_empty() or not player_coins or not item_database:
		return
	
	var item_data = item_database.get_item(current_buy_item)
	var quantity = int(buy_quantity_spinbox.value)
	var total_cost = item_data["buy_price"] * quantity
	
	if player_coins.spend_coins(total_cost):
		# TODO: Add item to player inventory
		item_purchased.emit(current_buy_item, quantity)
		
		# Update UI
		_update_coins_display()
		_populate_sell_items()  # Refresh sell items
		
		if audio_manager:
			audio_manager.play_ui_sound("button_click")
		
		print("TradingPanel: Purchased ", quantity, "x ", item_data["name"])
	else:
		print("TradingPanel: Insufficient coins for purchase")

func _on_sell_pressed():
	"""Handle sell button press"""
	if current_sell_item.is_empty() or not player_coins or not item_database:
		return
	
	var item_data = item_database.get_item(current_sell_item)
	var quantity = int(sell_quantity_spinbox.value)
	var total_value = item_data["sell_price"] * quantity
	
	# TODO: Remove item from player inventory
	player_coins.add_coins(total_value)
	item_sold.emit(current_sell_item, quantity)
	
	# Update UI
	_update_coins_display()
	_populate_sell_items()  # Refresh sell items
	
	if audio_manager:
		audio_manager.play_ui_sound("button_click")
	
	print("TradingPanel: Sold ", quantity, "x ", item_data["name"])

func _reset_buy_details():
	"""Reset buy details panel"""
	current_buy_item = ""
	buy_item_name.text = "Select an item"
	buy_item_description.text = ""
	buy_item_price.text = ""
	buy_total_price.text = "Total: 0 coins"
	buy_quantity_spinbox.value = 1
	buy_button.disabled = true

func _reset_sell_details():
	"""Reset sell details panel"""
	current_sell_item = ""
	sell_item_name.text = "Select an item"
	sell_item_description.text = ""
	sell_item_price.text = ""
	sell_total_price.text = "Total: 0 coins"
	sell_quantity_spinbox.value = 1
	sell_button.disabled = true
