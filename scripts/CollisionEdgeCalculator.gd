extends RefCounted

class_name CollisionEdgeCalculator

# Calculate the edge point of a collision shape from a given direction
static func get_edge_point(shape_node: CollisionShape2D, from_position: Vector2) -> Vector2:
	if not shape_node or not shape_node.shape:
		return shape_node.global_position
	
	var shape = shape_node.shape
	var shape_pos = shape_node.global_position
	
	# Get direction from origin to shape center
	var to_center = shape_pos - from_position
	if to_center.length() < 0.001:
		# If at center, use a default direction
		to_center = Vector2.UP
	
	var direction = to_center.normalized()
	
	# Handle different shape types
	if shape is CircleShape2D:
		return _get_circle_edge(shape, shape_pos, direction)
	elif shape is CapsuleShape2D:
		return _get_capsule_edge(shape, shape_pos, direction)
	elif shape is RectangleShape2D:
		return _get_rectangle_edge(shape, shape_pos, direction)
	else:
		# Default to center for unsupported shapes
		return shape_pos

static func _get_circle_edge(shape: CircleShape2D, center: Vector2, direction: Vector2) -> Vector2:
	return center + direction * shape.radius

static func _get_capsule_edge(shape: CapsuleShape2D, center: Vector2, direction: Vector2) -> Vector2:
	var radius = shape.radius
	var height = shape.height
	var half_height = height / 2.0
	
	# Normalize direction
	if direction.length() < 0.001:
		direction = Vector2.UP
	direction = direction.normalized()
	
	# For a vertical capsule, we need to check if we're hitting the middle cylinder or the end hemispheres
	# Project the direction onto the capsule's local space
	var local_dir = direction
	
	# Check if the ray would hit the cylindrical middle part
	# The cylinder extends from -half_height to +half_height on the Y axis
	var cylinder_hit_y = center.y + local_dir.y * half_height
	
	# If the hit point is within the cylinder bounds, we hit the side
	if abs(cylinder_hit_y - center.y) <= half_height:
		# Hit the cylindrical side
		var edge_x = center.x + local_dir.x * radius
		var edge_y = center.y + local_dir.y * half_height
		# Clamp Y to cylinder bounds
		edge_y = clamp(edge_y, center.y - half_height, center.y + half_height)
		return Vector2(edge_x, edge_y)
	else:
		# Hit one of the hemispherical ends
		# Find the center of the closest hemisphere
		var hemisphere_center = Vector2(center.x, center.y + sign(local_dir.y) * half_height)
		# Calculate edge point on that hemisphere
		return hemisphere_center + local_dir * radius

static func _get_rectangle_edge(shape: RectangleShape2D, center: Vector2, direction: Vector2) -> Vector2:
	var half_extents = shape.size / 2.0
	
	# Calculate edge point for rectangle
	var edge_x = center.x + direction.x * half_extents.x
	var edge_y = center.y + direction.y * half_extents.y
	
	return Vector2(edge_x, edge_y)

# Get the effective radius of a collision shape (for distance calculations)
static func get_effective_radius(shape_node: CollisionShape2D) -> float:
	if not shape_node or not shape_node.shape:
		return 0.0
	
	var shape = shape_node.shape
	
	if shape is CircleShape2D:
		return shape.radius
	elif shape is CapsuleShape2D:
		# Return the larger of radius or half height
		return max(shape.radius, shape.height / 2.0)
	elif shape is RectangleShape2D:
		# Return half the diagonal
		return shape.size.length() / 2.0
	else:
		return 0.0
