extends "res://scripts/Enemy.gd"

func _ready():
	super._ready()
	speed = 40.0
	health = 10000.0
	damage = 25.0
	xp_value = 100
	modulate = Color(0.2, 0, 0.5) # Dark purple tint
