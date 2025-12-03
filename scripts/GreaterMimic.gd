extends "res://scripts/Enemy.gd"

func _ready():
	super._ready()
	speed = 30.0
	health = 5000.0
	damage = 10.0
	xp_value = 150
	scale = Vector2(1.5, 1.5)
