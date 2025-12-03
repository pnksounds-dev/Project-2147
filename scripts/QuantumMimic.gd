extends "res://scripts/Enemy.gd"

func _ready():
	super._ready()
	speed = 90.0
	health = 4000.0
	damage = 20.0
	xp_value = 80
	modulate = Color(0, 1, 1) # Cyan tint
