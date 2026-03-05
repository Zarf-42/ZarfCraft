class_name BlockRay extends RayCast3D

class RayHit:
	# Unclear - I think these vars are supposed to return coords, but I think we've got one for removing blocks and one for adding them.
	var remove_position: Vector3i
	var add_position: Vector3i

	func _init(rem: Vector3i, add: Vector3i):
		remove_position = rem
		add_position = add

func get_ray_hit():
	var collider = get_collider()
	if collider is not Chunk: return null
	
	var _chunk = collider as Chunk
	var point = get_collision_point()
	var normal = Vector3i(get_collision_normal())
	# This appears to work if we're looking at the top face of a cube, but otherwise won't.
	# Refactor to ensure we're returning the correct position.
	var remove_position = Vector3i((point - normal * 0.5).floor())
	var add_position = remove_position + normal
	#var pos = (point + normal * -0.5).floor() + Vector3(0.5, 0.5, 0.5)
	
	#print("Pos: %s, Pos/Normal: %s" % [remove_position, (remove_position + normal)])
	return RayHit.new(remove_position, remove_position + normal)
