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
	
	var chunk = collider as Chunk
	var point = get_collision_point()
	var normal = get_collision_normal()
	var pos = (point + normal * -0.5).floor() + Vector3(0.5, 0.5, 0.5)
	
	return RayHit.new(pos, pos + normal)
