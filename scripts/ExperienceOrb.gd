extends Area2D

@export var xp_amount = 10
@export var magnet_speed = 400.0

var target = null

func _physics_process(delta):
	if target:
		var direction = global_position.direction_to(target.global_position)
		position += direction * magnet_speed * delta
	
	# Despawn if too far from player (prevent memory leak)
	elif get_tree().get_first_node_in_group("player"):
		var player = get_tree().get_first_node_in_group("player")
		if global_position.distance_squared_to(player.global_position) > 15000 * 15000:
			queue_free()

func _on_body_entered(body):
	if body.is_in_group("player"):
		if body.has_method("gain_xp"):
			body.gain_xp(xp_amount)
		queue_free()

func magnetize(player_node):
	target = player_node
