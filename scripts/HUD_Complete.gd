extends CanvasLayer
class_name CompleteHUD

# --- Configuration & Colors ---
const HUD_PADDING = 20
const BG_COLOR = Color(0.08, 0.08, 0.12, 0.85)
const BORDER_COLOR = Color(0.3, 0.6, 1.0, 0.4)
const ACCENT_COLOR = Color(0.0, 0.8, 1.0, 1.0)
const HEALTH_COLOR = Color(0.9, 0.2, 0.2, 1.0)
const XP_COLOR = Color(0.2, 0.8, 1.0, 1.0)
const AMMO_COLOR = Color(1.0, 0.8, 0.2, 1.0)
const FONT_SIZE_LARGE = 24
const FONT_SIZE_NORMAL = 16
const FONT_SIZE_SMALL = 12

# --- Node References ---
var root_control: Control
var health_bar: ProgressBar
var xp_bar: ProgressBar
var level_label: Label
var score_label: Label
var coins_label: Label
var skill_points_label: Label
var message_label: Label
var notification_panel: Node
var territory_ui: Node
# Weapon Widgets: [SlotIndex] -> Control
var weapon_widgets: Dictionary = {} 

# --- Helpers ---
func _create_style_box(bg: Color, border: Color = Color.TRANSPARENT, radius: int = 4) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1 if border != Color.TRANSPARENT else 0)
	style.set_corner_radius_all(radius)
	style.anti_aliasing = true
	return style

func _create_panel_container(parent: Node) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _create_style_box(BG_COLOR, BORDER_COLOR, 6))
	parent.add_child(panel)
	return panel

func _create_label(text: String, size: int = FONT_SIZE_NORMAL, color: Color = Color.WHITE) -> Label:
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

# --- Initialization ---
func _ready():
	print("HUD_Complete: Starting Modern Overhaul Initialization...")
	add_to_group("hud")
	add_to_group("notification_manager")
	
	# Clean up any existing placeholders created by older scripts or scene
	for child in get_children():
		child.queue_free()
	
	# Root container
	root_control = Control.new()
	root_control.name = "RootControl"
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Add padding
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", HUD_PADDING)
	margin.add_theme_constant_override("margin_top", HUD_PADDING)
	margin.add_theme_constant_override("margin_right", HUD_PADDING)
	margin.add_theme_constant_override("margin_bottom", HUD_PADDING)
	root_control.add_child(margin)
	add_child(root_control)
	
	# Create Main Layout Layers
	var layout_root = Control.new()
	layout_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(layout_root)
	
	_setup_top_left(layout_root)
	_setup_top_right(layout_root)
	_setup_bottom_center(layout_root)
	_setup_center(layout_root)
	
	# Extra elements (Messages, Notifications)
	_create_message_label() # Positioned separately
	_create_notification_panel()
	_create_territory_ui()
	
	# Connect to WeaponManager
	_connect_weapon_manager()
	
	print("HUD_Complete: Overhaul Complete.")

func _setup_top_left(parent: Control):
	var container = VBoxContainer.new()
	container.set_anchors_preset(Control.PRESET_TOP_LEFT)
	# Since parent is inside a MarginContainer, TOP_LEFT is (0,0) relative to margin
	# We can just let VBoxContainer sit there, or put it in a container.
	# Actually, since 'parent' is a Control filling the margin, anchors work.
	
	# Player Status Panel
	var status_panel = _create_panel_container(container)
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	status_panel.add_child(margin)
	
	var h_box = HBoxContainer.new()
	h_box.theme_type_variation = "Separation10" # Custom variation logic would exist in a theme, ignoring for now
	h_box.add_theme_constant_override("separation", 12)
	margin.add_child(h_box)
	
	# Level Badge
	var level_box = VBoxContainer.new()
	level_box.alignment = BoxContainer.ALIGNMENT_CENTER
	level_label = _create_label("01", 28, ACCENT_COLOR)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var lvl_title = _create_label("LVL", 10, Color(0.7, 0.7, 0.7))
	lvl_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_box.add_child(level_label)
	level_box.add_child(lvl_title)
	h_box.add_child(level_box)
	
	# Bars
	var bars_box = VBoxContainer.new()
	bars_box.alignment = BoxContainer.ALIGNMENT_CENTER
	bars_box.custom_minimum_size = Vector2(240, 0)
	h_box.add_child(bars_box)
	
	# Health Bar
	var hp_container = VBoxContainer.new()
	hp_container.add_theme_constant_override("separation", 2)
	health_bar = ProgressBar.new()
	health_bar.custom_minimum_size = Vector2(0, 14)
	health_bar.show_percentage = false
	# Style
	var hp_bg = _create_style_box(Color(0.2, 0.05, 0.05, 0.8), Color.TRANSPARENT, 2)
	var hp_fg = _create_style_box(HEALTH_COLOR, Color.TRANSPARENT, 2)
	health_bar.add_theme_stylebox_override("background", hp_bg)
	health_bar.add_theme_stylebox_override("fill", hp_fg)
	health_bar.value = 100
	hp_container.add_child(health_bar)
	
	var hp_label_container = HBoxContainer.new()
	var hp_title = _create_label("HULL INTEGRITY", 9, Color(0.8, 0.3, 0.3))
	hp_label_container.add_child(hp_title)
	hp_container.add_child(hp_label_container)
	bars_box.add_child(hp_container)
	
	# XP Bar
	var xp_container = VBoxContainer.new()
	xp_container.add_theme_constant_override("separation", 2)
	xp_bar = ProgressBar.new()
	xp_bar.custom_minimum_size = Vector2(0, 4)
	xp_bar.show_percentage = false
	var xp_bg = _create_style_box(Color(0.05, 0.1, 0.15, 0.8), Color.TRANSPARENT, 1)
	var xp_fg = _create_style_box(XP_COLOR, Color.TRANSPARENT, 1)
	xp_bar.add_theme_stylebox_override("background", xp_bg)
	xp_bar.add_theme_stylebox_override("fill", xp_fg)
	xp_bar.value = 0
	xp_container.add_child(xp_bar)
	bars_box.add_child(xp_container)
	
	parent.add_child(container)

func _setup_top_right(parent: Control):
	var container = VBoxContainer.new()
	container.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	container.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	
	# Economy Panel
	var eco_panel = _create_panel_container(container)
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 8)
	eco_panel.add_child(margin)
	
	var v_box = VBoxContainer.new()
	margin.add_child(v_box)
	
	# Score
	var score_box = HBoxContainer.new()
	score_box.alignment = BoxContainer.ALIGNMENT_END
	var score_title = _create_label("SCORE", 10, Color(0.7, 0.7, 0.7))
	score_label = _create_label("0", 18, Color.WHITE)
	score_box.add_child(score_title)
	score_box.add_child(Control.new()) # Spacing
	score_box.get_child(1).custom_minimum_size.x = 8
	score_box.add_child(score_label)
	v_box.add_child(score_box)
	
	# Coins
	var coin_box = HBoxContainer.new()
	coin_box.alignment = BoxContainer.ALIGNMENT_END
	var coin_icon = TextureRect.new() # Placeholder
	# coin_icon.texture = load("res://assets/items/Consumables/BucketOfCoffee.png") # TODO: Find distinct coin icon
	coin_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin_icon.custom_minimum_size = Vector2(16, 16)
	coins_label = _create_label("0", 16, Color(1, 0.85, 0.3))
	coin_box.add_child(coins_label)
	# coin_box.add_child(coin_icon) # Add icon if available
	v_box.add_child(coin_box)
	
	skill_points_label = _create_label("SP: 0", 12, Color(0.2, 0.8, 1))
	skill_points_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v_box.add_child(skill_points_label)

	parent.add_child(container)

func _setup_bottom_center(parent: Control):
	# Weapon Widgets container - Centered at the bottom
	var container = HBoxContainer.new()
	container.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	container.grow_vertical = Control.GROW_DIRECTION_BEGIN # Grow upwards
	container.grow_horizontal = Control.GROW_DIRECTION_BOTH # Grow outwards from center
	container.alignment = BoxContainer.ALIGNMENT_CENTER # Keep children centered
	container.add_theme_constant_override("separation", 20) # Add space between widgets
	
	# Lift it up slightly from the absolute bottom edge
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	margin.grow_vertical = Control.GROW_DIRECTION_BEGIN
	margin.grow_horizontal = Control.GROW_DIRECTION_BOTH
	margin.add_theme_constant_override("margin_bottom", 20) # 20px padding from bottom
	
	parent.add_child(margin)
	margin.add_child(container)
	
	# Weapon 1 (LMB)
	_create_weapon_widget(container, 0, "LMB", "Weapon 1")
	
	# Weapon 2 (RMB)
	_create_weapon_widget(container, 1, "RMB", "Weapon 2")

func _create_weapon_widget(parent: Node, index: int, bind_text: String, default_name: String):
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(160, 60)
	var style = _create_style_box(Color(0.05, 0.05, 0.08, 0.8), BORDER_COLOR, 6)
	panel.add_theme_stylebox_override("panel", style)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 4)
	panel.add_child(margin)
	
	var h_box = HBoxContainer.new()
	margin.add_child(h_box)
	
	# Icon / Bind
	var bind_box = VBoxContainer.new()
	bind_box.alignment = BoxContainer.ALIGNMENT_CENTER
	var bind_lbl = _create_label(bind_text, 14, ACCENT_COLOR)
	bind_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	# Placeholder for icon
	var icon_rect = TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(32, 32)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	bind_box.add_child(bind_lbl)
	bind_box.add_child(icon_rect)
	h_box.add_child(bind_box)
	
	# Info
	var info_box = VBoxContainer.new()
	info_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_box.alignment = BoxContainer.ALIGNMENT_CENTER
	
	var name_lbl = _create_label(default_name, 12, Color.WHITE)
	name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	
	var ammo_bar = ProgressBar.new()
	ammo_bar.custom_minimum_size = Vector2(0, 4)
	ammo_bar.show_percentage = false
	ammo_bar.add_theme_stylebox_override("fill", _create_style_box(AMMO_COLOR, Color.TRANSPARENT, 1))
	ammo_bar.add_theme_stylebox_override("background", _create_style_box(Color(0.2, 0.2, 0.2, 0.5), Color.TRANSPARENT, 1))
	ammo_bar.value = 100
	
	info_box.add_child(name_lbl)
	info_box.add_child(ammo_bar)
	h_box.add_child(info_box)
	
	parent.add_child(panel)
	
	# Store reference
	weapon_widgets[index] = {
		"root": panel,
		"name_label": name_lbl,
		"icon_rect": icon_rect,
		"ammo_bar": ammo_bar
	}

func _setup_center(_parent: Control):
	# Center top - leaving empty for Territory UI which is added separately but aligned
	pass

func _create_message_label():
	message_label = _create_label("", 24, Color(1, 0.9, 0.4))
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message_label.set_anchors_preset(Control.PRESET_CENTER)
	message_label.position.y -= 100 # Shift up a bit
	root_control.add_child(message_label)

func _create_notification_panel():
	notification_panel = preload("res://scenes/UI/NotificationPanel.tscn").instantiate()
	root_control.add_child(notification_panel)

func _create_territory_ui():
	# Use new instance or existing scene
	var t_ui = preload("res://scenes/UI/TerritoryUI.tscn").instantiate()
	t_ui.set_anchors_preset(Control.PRESET_TOP_WIDE)
	# Adjust its position if needed
	root_control.add_child(t_ui)
	territory_ui = t_ui

# --- Weapon Logic ---
func _connect_weapon_manager():
	var wm = get_node_or_null("/root/WeaponManager")
	if not wm:
		print("HUD_Complete: WeaponManager not found")
		return
	# Note: Player has 'WeaponManager' node. 'WeaponSystem' is the singleton/global/unified class.
	# The Player's specific manager is what we want for local feedback.
	var player = get_tree().get_first_node_in_group("player")
	if player and player.get("weapon_manager"):
		var mgr = player.weapon_manager
		if not mgr.weapon_switched.is_connected(_on_weapon_switched):
			mgr.weapon_switched.connect(_on_weapon_switched)
		if not mgr.weapon_fired.is_connected(_on_weapon_fired):
			mgr.weapon_fired.connect(_on_weapon_fired)
		
		# Initial update
		_update_weapon_slot(0, mgr.get_weapon(0))
		_update_weapon_slot(1, mgr.get_weapon(1))
	else:
		print("HUD: Could not find player weapon manager")

func _on_weapon_switched(_weapon: BaseWeapon):
	# Find which index this weapon belongs to (0 or 1)
	var player = get_tree().get_first_node_in_group("player")
	if player and player.weapon_manager:
		var w0 = player.weapon_manager.get_weapon(0)
		var w1 = player.weapon_manager.get_weapon(1)
		
		_update_weapon_slot(0, w0)
		_update_weapon_slot(1, w1)

func _on_weapon_fired(_weapon: BaseWeapon, _pos: Vector2):
	# Flash update? Or just update ammo
	pass # Ammo updates usually happen on frame/event. BaseWeapon doesn't signal ammo change directly?
	# Ideally connect to ammo change signal if it existed.
	# For now, we can poll in process or just assume infinite/update on event.
	pass

func _process(_delta):
	# Poll ammo
	var player = get_tree().get_first_node_in_group("player")
	if player and player.weapon_manager:
		_update_ammo(0, player.weapon_manager.get_weapon(0))
		_update_ammo(1, player.weapon_manager.get_weapon(1))

func _update_weapon_slot(index: int, weapon: BaseWeapon):
	if not weapon_widgets.has(index): return
	var w = weapon_widgets[index]
	
	if weapon:
		w.name_label.text = weapon.name # or weapon.weapon_id
		# Try to load icon if possible
		# This requires mapping weapon ID to icon path from ItemDatabase
		# For now, simple text or placeholder
		var db = get_tree().get_first_node_in_group("item_database")
		if db:
			var item = db.get_item(weapon.weapon_id) # Assuming weapon_id matches item_id
			if not item.is_empty() and item.has("icon_path"):
				var tex = load(item.icon_path)
				if tex: w.icon_rect.texture = tex
		
		w.root.modulate = Color.WHITE
	else:
		w.name_label.text = "Empty"
		w.icon_rect.texture = null
		w.root.modulate = Color(1,1,1,0.5)

func _update_ammo(index: int, weapon: BaseWeapon):
	if not weapon_widgets.has(index): return
	var w = weapon_widgets[index]
	
	if weapon and weapon.max_ammo > 0:
		w.ammo_bar.max_value = weapon.max_ammo
		w.ammo_bar.value = weapon.current_ammo
		w.ammo_bar.visible = true
	else:
		w.ammo_bar.visible = false # Infinite ammo

# --- Public API (Legacy & New) ---
func update_health(current: int, maximum: int):
	if health_bar:
		health_bar.max_value = maximum
		health_bar.value = current
		# Flash?
		if current < maximum * 0.3:
			health_bar.modulate = Color(1, 0, 0) + Color(sin(Time.get_ticks_msec()*0.02)*0.2, 0, 0, 0)
		else:
			health_bar.modulate = Color.WHITE

func update_xp(current: int, required: int):
	if xp_bar:
		xp_bar.max_value = required
		xp_bar.value = current

func update_level(level: int):
	if level_label:
		level_label.text = "%02d" % level

func update_score(score: int):
	if score_label:
		score_label.text = comma_sep(score)

func update_coins(coins: int):
	if coins_label:
		coins_label.text = comma_sep(coins)

func update_skill_points(points: int):
	if skill_points_label:
		skill_points_label.text = "SP: " + str(points)
		skill_points_label.visible = points > 0

func show_message(text: String, duration: float = 3.0):
	if message_label:
		message_label.text = text
		var t = create_tween()
		t.tween_interval(duration)
		t.tween_property(message_label, "modulate:a", 0.0, 1.0)
		t.tween_callback(func(): message_label.text = ""; message_label.modulate.a = 1.0)

func comma_sep(number: int) -> String:
	var string = str(number)
	var mod = string.length() % 3
	var res = ""
	for i in range(0, string.length()):
		if i != 0 and i % 3 == mod:
			res += ","
		res += string[i]
	return res
