extends Node
class_name AnimationController

# Handles all animations and visual transitions for the inventory

signal animation_started(animation_name: String)
signal animation_completed(animation_name: String)

var _inventory_ui: Control
var _tween: Tween = null

# Animation settings
var _open_duration: float = 0.3
var _close_duration: float = 0.2
var _hover_duration: float = 0.15
var _slot_pulse_duration: float = 0.4

func initialize(inventory_ui: Control) -> void:
	_inventory_ui = inventory_ui
	_tween = null

func play_open_animation() -> void:
	"""Play inventory open animation"""
	animation_started.emit("open")
	
	# Reset scale and position
	_inventory_ui.scale = Vector2(0.8, 0.8)
	_inventory_ui.modulate = Color(1, 1, 1, 0)
	
	# Create tween for smooth opening
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Scale up
	tween.tween_property(_inventory_ui, "scale", Vector2.ONE, _open_duration)\
		.set_ease(Tween.EASE_OUT)\
		.set_trans(Tween.TRANS_BACK)
	
	# Fade in
	tween.tween_property(_inventory_ui, "modulate", Color.WHITE, _open_duration * 0.7)\
		.set_ease(Tween.EASE_OUT)
	
	tween.tween_callback(_on_open_animation_completed)

func play_close_animation() -> void:
	"""Play inventory close animation"""
	animation_started.emit("close")
	
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Scale down
	tween.tween_property(_inventory_ui, "scale", Vector2(0.9, 0.9), _close_duration)\
		.set_ease(Tween.EASE_IN)
	
	# Fade out
	tween.tween_property(_inventory_ui, "modulate", Color(1, 1, 1, 0), _close_duration)\
		.set_ease(Tween.EASE_IN)
	
	tween.tween_callback(_on_close_animation_completed)

func play_hover_animation(slot: Control, is_entering: bool) -> void:
	"""Play hover animation for a slot"""
	if not slot:
		return
	
	var tween = create_tween()
	
	if is_entering:
		# Enter hover - slightly scale up and brighten
		tween.tween_property(slot, "modulate", Color(1.1, 1.1, 1.1, 1.0), _hover_duration)\
			.set_ease(Tween.EASE_OUT)
	else:
		# Exit hover - return to normal
		tween.tween_property(slot, "modulate", Color.WHITE, _hover_duration)\
			.set_ease(Tween.EASE_OUT)

func play_slot_pulse_animation(slot: Control) -> void:
	"""Play pulse animation for a slot (useful for item pickups, etc.)"""
	if not slot:
		return
	
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Pulse brightness
	tween.tween_property(slot, "modulate", Color(1.3, 1.3, 1.3, 1.0), _slot_pulse_duration * 0.5)\
		.set_ease(Tween.EASE_OUT)
	tween.tween_property(slot, "modulate", Color.WHITE, _slot_pulse_duration * 0.5)\
		.set_ease(Tween.EASE_IN)\
		.set_delay(_slot_pulse_duration * 0.5)

func play_error_shake_animation(slot: Control) -> void:
	"""Play shake animation for invalid actions"""
	if not slot:
		return
	
	var original_position = slot.position
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Shake horizontally
	for i in range(4):
		var offset_x = 5.0 if i % 2 == 0 else -5.0
		tween.tween_property(slot, "position:x", original_position.x + offset_x, 0.05)\
			.set_delay(i * 0.05)
	
	# Return to original position
	tween.tween_property(slot, "position", original_position, 0.1)\
		.set_delay(4 * 0.05)

func play_success_flash_animation(slot: Control) -> void:
	"""Play flash animation for successful actions"""
	if not slot:
		return
	
	var tween = create_tween()
	
	# Flash bright white
	tween.tween_property(slot, "modulate", Color(2.0, 2.0, 2.0, 1.0), 0.1)
	tween.tween_property(slot, "modulate", Color.WHITE, 0.2)\
		.set_ease(Tween.EASE_OUT)

func play_filter_transition_animation(new_items_visible: bool) -> void:
	"""Play animation when filter changes"""
	if not _inventory_ui:
		return
	
	var tween = create_tween()
	
	if new_items_visible:
		# Fade in new items
		tween.tween_property(_inventory_ui, "modulate", Color.WHITE, 0.2)\
			.from(Color(0.8, 0.8, 0.8, 0.8))
	else:
		# Brief fade when no items
		tween.tween_property(_inventory_ui, "modulate", Color(0.7, 0.7, 0.7, 0.7), 0.1)
		tween.tween_property(_inventory_ui, "modulate", Color.WHITE, 0.1)

func play_drag_start_animation(dragged_ui: Control) -> void:
	"""Play animation when drag starts"""
	if not dragged_ui:
		return
	
	var tween = create_tween()
	
	# Scale up slightly and add shadow effect
	tween.tween_property(dragged_ui, "scale", Vector2(1.1, 1.1), 0.1)
	tween.tween_property(dragged_ui, "modulate", Color(1.0, 1.0, 1.0, 0.9), 0.1)

func play_drag_end_animation(dragged_ui: Control, success: bool) -> void:
	"""Play animation when drag ends"""
	if not dragged_ui:
		return
	
	var tween = create_tween()
	
	if success:
		# Successful drop - scale down smoothly
		tween.tween_property(dragged_ui, "scale", Vector2(0.8, 0.8), 0.15)
		tween.tween_property(dragged_ui, "modulate", Color(1.0, 1.0, 1.0, 0.0), 0.15)
	else:
		# Failed drop - shake and fade
		tween.set_parallel(true)
		tween.tween_property(dragged_ui, "modulate", Color(1.0, 0.5, 0.5, 0.8), 0.1)
		tween.tween_property(dragged_ui, "scale", Vector2(0.6, 0.6), 0.2)
		tween.tween_property(dragged_ui, "modulate", Color(1.0, 0.5, 0.5, 0.0), 0.2)

func set_animation_speed(speed_multiplier: float) -> void:
	"""Adjust animation speeds globally"""
	_open_duration = 0.3 / speed_multiplier
	_close_duration = 0.2 / speed_multiplier
	_hover_duration = 0.15 / speed_multiplier
	_slot_pulse_duration = 0.4 / speed_multiplier

func _on_open_animation_completed() -> void:
	animation_completed.emit("open")

func _on_close_animation_completed() -> void:
	animation_completed.emit("close")

func cancel_all_animations() -> void:
	"""Cancel all currently playing animations"""
	if _tween:
		_tween.kill()
	_tween = create_tween()
