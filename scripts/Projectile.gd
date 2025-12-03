extends Area2D

@export var speed = 600.0
@export var damage = 5.0
@export var lifetime = 2.0

var direction = Vector2.ZERO
var audio_player: AudioStreamPlayer2D

func _ready():
	# Create audio player for bullet sounds
	audio_player = AudioStreamPlayer2D.new()
	add_child(audio_player)
	audio_player.max_distance = 800.0
	audio_player.attenuation = 2.0
	audio_player.bus = "SFX"
	
	# Play bullet fire sound - use one of the available bullet sounds
	var bullet_sound = load("res://assets/Audio/weapons/BulletSound1.wav")
	if bullet_sound:
		audio_player.stream = bullet_sound
		audio_player.play()
	else:
		print("Projectile: Warning - Could not load bullet sound")
	
	# Rotate sprite to face direction
	if direction != Vector2.ZERO:
		rotation = direction.angle()
	
	# Auto-destroy after lifetime
	await get_tree().create_timer(lifetime).timeout
	queue_free()

func _physics_process(delta):
	position += direction * speed * delta
	
	# Update rotation to face movement direction
	if direction != Vector2.ZERO:
		rotation = direction.angle()

func _on_body_entered(body):
	if body.is_in_group("enemy"):
		# Calculate hit point at edge of collision shape
		var collision_shape = body.get_node_or_null("CollisionShape2D")
		if collision_shape:
			var hit_point = CollisionEdgeCalculator.get_edge_point(collision_shape, global_position)
			# Move projectile to actual hit point for visual accuracy
			global_position = hit_point
		
		if body.has_method("take_damage"):
			body.take_damage(damage)
		queue_free()
