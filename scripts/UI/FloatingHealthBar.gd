extends Node2D

class_name FloatingHealthBar

@export var width: float = 50.0
@export var height: float = 6.0
@export var y_offset: float = -40.0
@export var show_when_full: bool = false  # Don't show when full by default
@export var bg_color: Color = Color(0, 0, 0, 0.8)
@export var fg_color: Color = Color(0.2, 1.0, 0.2, 0.95)

var value: int = 0
var max_value: int = 100
var target_parent: Node2D

func setup(parent: Node2D, v: int, max_v: int) -> void:
	target_parent = parent
	max_value = max(1, max_v)
	value = clamp(v, 0, max_v)
	
	# Reparent to follow the target
	if target_parent:
		target_parent.add_child(self)
		position = Vector2(0, y_offset)
	
	queue_redraw()

func set_value(v: int) -> void:
	value = clamp(v, 0, max_value)
	queue_redraw()

func _draw() -> void:
	if not show_when_full and value >= max_value:
		return
	
	# Safety checks
	if max_value <= 0 or width <= 0 or height <= 0:
		return
	
	var ratio := float(value) / float(max_value)
	if ratio < 0.0 or ratio > 1.0:
		ratio = clamp(ratio, 0.0, 1.0)
	
	var pos := Vector2(-width * 0.5, 0)
	var bg_rect := Rect2(pos, Vector2(width, height))
	var fg_width := width * ratio
	var fg_rect := Rect2(pos, Vector2(fg_width, height))
	
	# Ensure rects are valid
	if bg_rect.size.x <= 0 or bg_rect.size.y <= 0:
		return
	if fg_rect.size.x < 0 or fg_rect.size.y <= 0:
		return
	
	draw_rect(bg_rect, bg_color)
	if fg_width > 0:
		draw_rect(fg_rect, fg_color)

func cleanup():
	# Just queue for free - don't try to remove from parent since parent is being destroyed
	queue_free()
