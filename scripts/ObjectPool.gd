extends Node
class_name ObjectPool

## Generic object pool for performance optimization
## Reduces frequent instantiation/destruction of objects

var pool: Array = []
var object_scene: PackedScene
var max_size: int = 50
var parent_node: Node

func _init(scene: PackedScene, max_pool_size: int = 50, container: Node = null):
	object_scene = scene
	max_size = max_pool_size
	parent_node = container
	print("ObjectPool: Created pool for ", scene.resource_path, " with max size ", max_size)

func get_object() -> Node:
	"""Get an object from the pool or create new one"""
	if pool.size() > 0:
		var obj = pool.pop_back()
		obj.visible = true
		if obj.has_method("reset"):
			obj.reset()
		print("ObjectPool: Reused object from pool (", pool.size(), " remaining)")
		return obj
	else:
		if object_scene:
			var obj = object_scene.instantiate()
			if parent_node:
				parent_node.add_child(obj)
			print("ObjectPool: Created new object (pool empty)")
			return obj
		else:
			print("ObjectPool: ERROR - No scene defined")
			return null

func return_object(obj: Node):
	"""Return an object to the pool"""
	if obj and pool.size() < max_size:
		obj.visible = false
		if obj.get_parent():
			obj.get_parent().remove_child(obj)
		pool.push_back(obj)
		print("ObjectPool: Returned object to pool (", pool.size(), " total)")
	elif obj:
		# Pool full, just destroy
		obj.queue_free()
		print("ObjectPool: Pool full, destroyed object")

func clear_pool():
	"""Clear all objects from the pool"""
	for obj in pool:
		if obj:
			obj.queue_free()
	pool.clear()
	print("ObjectPool: Pool cleared")

func get_pool_stats() -> Dictionary:
	return {
		"available": pool.size(),
		"max_size": max_size,
		"scene_path": object_scene.resource_path if object_scene else "None"
	}
