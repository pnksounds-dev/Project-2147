extends Control

class_name InteractionPrompt

## InteractionPrompt - Shows "Press F to Trade" when near interactable objects

@onready var prompt_label: Label = $PromptLabel
@onready var background_panel: Panel = $BackgroundPanel
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var target_object: Node2D
var prompt_text: String = "Press F to Interact"

func _ready():
	add_to_group("interaction_prompt")
	visible = false
	
	# Set up initial appearance
	if background_panel:
		background_panel.modulate = Color(1, 1, 1, 0.8)
	
	if prompt_label:
		prompt_label.text = prompt_text
		prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

func show_prompt(object: Node2D, text: String = ""):
	"""Show interaction prompt for specific object"""
	target_object = object
	
	if text != "":
		prompt_text = text
		prompt_label.text = prompt_text
	
	visible = true
	
	# Play fade-in animation if available
	if animation_player and animation_player.has_animation("fade_in"):
		animation_player.play("fade_in")
	else:
		# Simple fade without animation
		modulate = Color(1, 1, 1, 0)
		var tween = create_tween()
		tween.tween_property(self, "modulate", Color.WHITE, 0.3)

func hide_prompt():
	"""Hide interaction prompt"""
	visible = false
	
	# Play fade-out animation if available
	if animation_player and animation_player.has_animation("fade_out"):
		animation_player.play("fade_out")
	else:
		# Simple fade without animation
		var tween = create_tween()
		tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.3)

func update_position(player_position: Vector2):
	"""Update prompt position to follow player"""
	if target_object:
		# Position above the target object
		global_position = target_object.global_position + Vector2(0, -80)
	else:
		# Fallback to player position
		global_position = player_position + Vector2(0, -80)

func set_prompt_text(text: String):
	"""Update the prompt text"""
	prompt_text = text
	if prompt_label:
		prompt_label.text = prompt_text
