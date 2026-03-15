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
	
	# This gathers the Collision Point's coordinates and the Normal the player is looking at. These
	# are used to determine what block is being targeted and from what direction, so that we can
	# remove the correct block, or add one on the correct face.
	# _chunk is commented out but we might want it in the future, for ensuring we aren't adding
	# voxels beyond the border of a chunk.
	#var _chunk = collider as Chunk
	var point = get_collision_point()
	var normal = Vector3i(get_collision_normal())
	var remove_position = Vector3i((point - normal * 0.5).floor())
	#var add_position = remove_position + normal

	return RayHit.new(remove_position, remove_position + normal)
