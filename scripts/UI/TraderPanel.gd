extends Control

class_name TraderPanel

signal item_purchased(item_id: String)
signal closed

@onready var consumable_container: GridContainer = get_node_or_null("VBoxContainer/ScrollContainer/GridContainer")
@onready var weapon_container: GridContainer = get_node_or_null("VBoxContainer/WeaponsScroll/GridContainer")
@onready var ship_container: GridContainer = get_node_or_null("VBoxContainer/ShipsScroll/GridContainer")
@onready var buy_button: Button = get_node_or_null("VBoxContainer/Footer/BuyButton")
@onready var close_button: Button = get_node_or_null("VBoxContainer/Footer/CloseButton")
@onready var coins_label: Label = get_node_or_null("VBoxContainer/Footer/CoinsLabel")
@onready var economy_system = get_node_or_null("/root/EconomySystem")

# Audio manager reference
var audio_manager

# Cached style for performance optimization
var _cached_slot_style: StyleBoxFlat
var _hover_styles: Array[StyleBoxFlat] = []

# Trader item data
var trader_items := {
	"consumable": [],
	"weapon": [],
	"ship": []
}
var current_offer: Dictionary = {}

# Trade session state (foundation for two-column trading flow)
var ark_offers: Array = [] # Items the ARK will give to the player this trade
var player_offers: Array = [] # Items the player will give to the ARK this trade
var coins_delta: int = 0 # Net coin change for the player (negative = player pays, positive = player receives)

func _ready():
	add_to_group("trader_panel")
	
	# Get audio manager
	audio_manager = get_node_or_null("/root/AudioManager")
	
	# Check economy system
	economy_system = get_node_or_null("/root/EconomySystem")
	
	# Connect buttons
	if buy_button and not buy_button.pressed.is_connected(_on_buy_pressed):
		buy_button.pressed.connect(_on_buy_pressed)
	if close_button and not close_button.pressed.is_connected(_on_close_pressed):
		close_button.pressed.connect(_on_close_pressed)
	
	# Listen for coin changes
	if economy_system and economy_system.has_signal("coins_changed"):
		if not economy_system.coins_changed.is_connected(_on_coins_changed):
			economy_system.coins_changed.connect(_on_coins_changed)
	
	# Initialize trader items
	_generate_trader_items()
	_create_trader_slots()
	_update_footer()
	_reset_trade_session()

func open():
	"""Open the trader panel"""
	show()
	update_display()

func close():
	"""Close the trader panel"""
	hide()
	_reset_trade_session()
	closed.emit()

func _reset_trade_session() -> void:
	ark_offers.clear()
	player_offers.clear()
	coins_delta = 0

func _recalculate_trade_values() -> void:
	# Placeholder logic for future two-column trade summary
	var player_value := 0
	for offer in player_offers:
		var price = int(offer.get("price", 0))
		var quantity = int(offer.get("quantity", 1))
		player_value += price * quantity

	var ark_value := 0
	for offer in ark_offers:
		var price = int(offer.get("price", 0))
		var quantity = int(offer.get("quantity", 1))
		ark_value += price * quantity

	coins_delta = player_value - ark_value
	# For now just log; future UI will show this in a summary panel
	print("TraderPanel trade session: player_value=", player_value, ", ark_value=", ark_value, ", coins_delta=", coins_delta)

func is_open() -> bool:
	"""Check if trader panel is open"""
	return visible

func _generate_trader_items():
	"""Generate trader items using EconomySystem data"""
	trader_items = {
		"consumable": [],
		"weapon": [],
		"ship": []
	}
	
	# Get stock from EconomySystem (data-driven source of truth)
	if economy_system and economy_system.has_method("get_trader_stock"):
		var stock = economy_system.get_trader_stock()
		for offer in stock:
			var category = offer.get("category", "")
			if trader_items.has(category):
				trader_items[category].append(offer)
	else:
		print("TraderPanel: EconomySystem not available, using fallback items")
		# Fallback items if EconomySystem not available
		_add_trader_offer("consumable", "HealthIncrease", "Health Pack", "Medical supplies that restore health points", "res://assets/items/Consumables/HealthIncrease.png", "Common", 50)
		_add_trader_offer("weapon", "PhaserBeams", "Phaser Beams", "Medium-range energy weapon", "res://assets/items/Weapons/Item_Icon/PhaserBeams.png", "Uncommon", 350)
		_add_trader_offer("ship", "trader_general", "Trader General", "Versatile trading vessel with good cargo capacity", "res://assets/Ships/FactionShips/Trader/Trader_General_1.png", "Uncommon", 800)

func _add_trader_offer(category: String, item_id: String, fallback_name: String, fallback_description: String, fallback_icon: String, rarity: String, price: int) -> void:
	var item_name := fallback_name
	var description := fallback_description
	var icon_path := fallback_icon
	
	# Try to pull richer data from ItemDatabase
	var item_db = get_node_or_null("/root/ItemDatabase")
	var db_icon = null
	if item_db and item_db.has_method("has_item") and item_db.has_method("get_item") and item_db.has_item(item_id):
		var item_obj = item_db.get_item(item_id)
		if item_obj:
			if item_obj.get("icon"):
				db_icon = item_obj.get("icon")
			if item_obj.get("display_name"):
				item_name = item_obj.get("display_name")
			if item_obj.get("description"):
				description = item_obj.get("description")

	var offer := {
		"id": item_id,
		"name": item_name,
		"type": category,
		"category": category,
		"icon_path": icon_path,
		"icon": db_icon,
		"rarity": rarity,
		"price": price,
		"description": description,
	}
	
	if trader_items.has(category):
		trader_items[category].append(offer)

func _create_trader_slots():
	"""Create visual trader slots"""
	_clear_container(consumable_container)
	_clear_container(weapon_container)
	_clear_container(ship_container)
	
	current_offer = {}
	
	_populate_container(consumable_container, trader_items.get("consumable", []))
	_populate_container(weapon_container, trader_items.get("weapon", []))
	_populate_container(ship_container, trader_items.get("ship", []))

func _clear_container(container: GridContainer) -> void:
	if not container:
		return
	for child in container.get_children():
		child.queue_free()
	_hover_styles.clear()

func _populate_container(container: GridContainer, items: Array) -> void:
	if not container:
		return
	
	container.columns = 4
	container.add_theme_constant_override("h_separation", 10)
	container.add_theme_constant_override("v_separation", 10)
	
	for item_data in items:
		var slot = _create_trader_slot(item_data, 140)
		container.add_child(slot)
		if current_offer.is_empty():
			current_offer = item_data

func _create_trader_slot(item_data: Dictionary, _container_width: float) -> Control:
	"""Create a single trader slot"""
	var slot_container = PanelContainer.new()
	var slot_size = Vector2(120, 140)
	slot_container.custom_minimum_size = slot_size
	
	if not _cached_slot_style:
		_cached_slot_style = _create_slot_style()
	slot_container.add_theme_stylebox_override("panel", _cached_slot_style)
	
	var vbox = VBoxContainer.new()
	vbox.name = "VBoxContainer"
	slot_container.add_child(vbox)
	
	# Item icon
	var icon_texture = TextureRect.new()
	icon_texture.custom_minimum_size = Vector2(48, 48)
	icon_texture.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var icon_path: String = item_data.get("icon_path", "")
	
	var icon_loaded = false
	var icon_obj = item_data.get("icon")
	if icon_obj is Texture2D:
		icon_texture.texture = icon_obj
		icon_loaded = true
	
	if not icon_loaded and icon_path != "":
		if ResourceLoader.exists(icon_path):
			icon_texture.texture = load(icon_path)
			icon_loaded = true
	
	if not icon_loaded:
		var rarity_color = _get_rarity_color(item_data.get("rarity", "Common"))
		# Create a ColorRect to show the rarity color
		var color_rect = ColorRect.new()
		color_rect.size = Vector2(32, 32)  # Match your desired size
		color_rect.color = rarity_color
		vbox.add_child(color_rect)
	else:
		vbox.add_child(icon_texture)
	
	# Item name
	var name_label = Label.new()
	name_label.text = item_data.get("name", "")
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(name_label)
	
	# Rarity indicator
	var rarity_label = Label.new()
	rarity_label.text = item_data.get("rarity", "Common")
	rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity_label.add_theme_color_override("font_color", _get_rarity_color(item_data.get("rarity", "Common")))
	rarity_label.add_theme_font_size_override("font_size", 10)
	vbox.add_child(rarity_label)
	
	# Price
	var price_label = Label.new()
	price_label.text = str(int(item_data.get("price", 0))) + " coins"
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.0))
	price_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(price_label)
	
	slot_container.set_meta("item_id", item_data.get("id", ""))
	
	var hover_style = _create_hover_style()
	_hover_styles.append(hover_style)
	slot_container.add_theme_stylebox_override("panel", _cached_slot_style)
	slot_container.mouse_entered.connect(_on_slot_hover.bind(slot_container, true, hover_style))
	slot_container.mouse_exited.connect(_on_slot_hover.bind(slot_container, false, hover_style))
	slot_container.gui_input.connect(_on_slot_gui_input.bind(item_data))
	
	return slot_container

func _create_slot_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.2, 0.8)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.2, 0.8, 1, 0.6)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	return style

func _create_hover_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.3, 0.4, 0.9)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.2, 0.8, 1, 1.0)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	return style

func _get_rarity_color(rarity: String) -> Color:
	match rarity.to_lower():
		"common":
			return Color(0.5, 1.0, 0.5)
		"uncommon":
			return Color(0.3, 0.8, 1.0)
		"rare":
			return Color(1.0, 0.5, 0.0)
		"legendary":
			return Color(1.0, 0.2, 1.0)
		_:
			return Color(0.8, 0.8, 0.8)

func _on_slot_hover(slot: PanelContainer, is_hovering: bool, hover_style: StyleBoxFlat):
	if is_hovering:
		slot.add_theme_stylebox_override("panel", hover_style)
	else:
		slot.add_theme_stylebox_override("panel", _cached_slot_style)

func _on_slot_gui_input(event: InputEvent, item_data: Dictionary) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		current_offer = item_data
		_update_footer()
		# Add selected offer to ARK side of trade session (quantity 1 for now)
		_add_ark_offer(item_data)
		_recalculate_trade_values()
		if audio_manager and audio_manager.has_method("play_ui_sound"):
			audio_manager.play_ui_sound("button_click")

func _add_ark_offer(item_data: Dictionary) -> void:
	var item_id: String = item_data.get("id", "")
	if item_id.is_empty():
		return

	# Try to merge with existing entry
	for offer in ark_offers:
		if offer.get("id", "") == item_id:
			offer["quantity"] = int(offer.get("quantity", 1)) + 1
			return

	# New entry
	var new_offer: Dictionary = {
		"id": item_id,
		"category": item_data.get("category", ""),
		"price": int(item_data.get("price", 0)),
		"quantity": 1
	}
	ark_offers.append(new_offer)

func update_display():
	"""Update the trader display"""
	_create_trader_slots()
	_update_footer()

func _on_buy_pressed() -> void:
	if current_offer.is_empty() or not economy_system:
		return
	
	var item_id: String = current_offer.get("id", "")
	var category: String = current_offer.get("category", "")
	var price: int = int(current_offer.get("price", 0))
	
	if item_id.is_empty() or category.is_empty() or price <= 0:
		return
	
	# Validation 1: Check if player has enough coins
	if not economy_system.has_method("can_afford") or not economy_system.can_afford(price):
		_show_error_message("Not enough coins!")
		if audio_manager and audio_manager.has_method("play_ui_sound"):
			audio_manager.play_ui_sound("purchase_failed")
		return
	
	# Validation 2: Check if player has cargo space
	var inventory_state = get_tree().get_first_node_in_group("inventory_state")
	if inventory_state and inventory_state.has_method("add_item_by_id"):
		# Test adding item without actually adding it to check space
		var can_add = _check_cargo_space(item_id, inventory_state)
		if not can_add:
			_show_error_message("Inventory full!")
			if audio_manager and audio_manager.has_method("play_ui_sound"):
				audio_manager.play_ui_sound("purchase_failed")
			return
	
	# All checks passed - proceed with purchase
	var success = economy_system.purchase_with_price(item_id, category, price)
	
	if success:
		# Add item to inventory
		if inventory_state and inventory_state.has_method("add_item_by_id"):
			var add_success = inventory_state.add_item_by_id(item_id, 1)
			if not add_success:
				# This should not happen since we checked space, but handle it
				_show_error_message("Failed to add item to inventory!")
				# Refund coins since item wasn't added
				if economy_system.has_method("add_coins"):
					economy_system.add_coins(price)
				return
		
		_show_purchase_feedback(current_offer)
		_update_footer()
		item_purchased.emit(item_id)
		if audio_manager and audio_manager.has_method("play_ui_sound"):
			audio_manager.play_ui_sound("purchase_success")
	else:
		_show_error_message("Purchase failed!")
		if audio_manager and audio_manager.has_method("play_ui_sound"):
			audio_manager.play_ui_sound("purchase_failed")

func _on_close_pressed() -> void:
	close()

func _show_purchase_feedback(item: Dictionary) -> void:
	var item_id = item.get("id", "")
	var containers = [consumable_container, weapon_container, ship_container]
	for container in containers:
		if not container:
			continue
		for slot in container.get_children():
			if slot.has_meta("item_id") and slot.get_meta("item_id") == item_id:
				var tween = create_tween()
				tween.tween_property(slot, "modulate", Color(0.5, 1.0, 0.5), 0.15)
				tween.tween_property(slot, "modulate", Color.WHITE, 0.15)
				return

func _check_cargo_space(item_id: String, inventory_state) -> bool:
	"""Check if there's space to add an item without actually adding it"""
	# Get current cargo count to check if there's space
	var cargo_count = inventory_state.cargo.size()
	var max_cargo = inventory_state.get_cargo_slot_count()
	
	# Check if there's any empty slot available
	if cargo_count >= max_cargo:
		return false
	
	# Check if item can stack with existing items
	var item_def = inventory_state._get_item_definition(item_id)
	if item_def.is_empty():
		return false
	
	var max_stack = item_def.get("max_stack", 1)
	if max_stack > 1:
		# Check for existing stack with space
		for instance_id in inventory_state.cargo:
			var instance = inventory_state.get_instance(instance_id)
			if instance and instance.get("item_id") == item_id:
				var current_stack = instance.get("stack_size", 1)
				if current_stack < max_stack:
					return true
	
	# If no stack space, check if we have empty slots
	return cargo_count < max_cargo

func _show_error_message(message: String):
	"""Show error message using HUD notification system"""
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_notification"):
		hud.show_notification(message, 3.0)
	else:
		print("TraderPanel Error: ", message)

func _on_coins_changed(_new_amount: int) -> void:
	_update_footer()

func _update_footer() -> void:
	if coins_label:
		var coins_value := 0
		if economy_system and economy_system.has_method("get_coins"):
			coins_value = int(economy_system.get_coins())
		coins_label.text = "Coins: %d" % coins_value
	
	if buy_button:
		if current_offer.is_empty():
			buy_button.text = "Select Item"
			buy_button.disabled = true
		else:
			var cost: int = int(current_offer.get("price", 0))
			var item_name: String = current_offer.get("name", "")
			
			buy_button.text = "Buy %s (%d coins)" % [item_name, cost]
			buy_button.disabled = not _can_afford_current_offer()

func _can_afford_current_offer() -> bool:
	if current_offer.is_empty() or not economy_system:
		return false
	var cost: int = int(current_offer.get("price", 0))
	if cost <= 0:
		return false
	if economy_system.has_method("can_afford"):
		return economy_system.can_afford(cost)
	return false

func _input(event: InputEvent) -> void:
	if not visible:
		return
	
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
