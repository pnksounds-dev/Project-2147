extends "res://scripts/Enemy.gd"

var time_offset = 0.0

func _ready():
	super._ready()
	speed = 80.0
	health = 2000.0
	damage = 10.0
	xp_value = 20
	time_offset = randf() * 10.0

func _physics_process(delta):
	if _target_node:
		var direction = global_position.direction_to(_target_node.global_position)
		
		# Add sine wave movement
		var side_movement = direction.rotated(PI / 2) * sin(Time.get_ticks_msec() / 500.0 + time_offset) * 0.5
		var final_direction = (direction + side_movement).normalized()
		
		velocity = final_direction * speed
		rotation = direction.angle()
		
		var collision = move_and_collide(velocity * delta)
		if collision:
			var collider = collision.get_collider()
			if collider.is_in_group("player"):
				if collider.has_method("take_damage"):
					collider.take_damage(damage * delta)
