class_name BlockRay extends RayCast3D

class RayHit:
	# Unclear - I think these vars are supposed to return coords, but I think we've got one for removing blocks and one for adding them.
	var remove_position: Vector3i
	var add_position: Vector3i

	func _init(rem: Vector3i, add: Vector3i):
		remove_position = rem
		add_position = add

func get_ray_hit():
	var origin: Vector3 = global_position
	# Use target_position to get the correct direction, accounting for node rotation
	var local_target: Vector3 = target_position.normalized()
	var direction: Vector3 = global_transform.basis * local_target
	var max_distance: float = target_position.length()
	return _voxel_raycast(origin, direction, max_distance)

	# This gathers the Collision Point's coordinates and the Normal the player is looking at. These
	# are used to determine what block is being targeted and from what direction, so that we can
	# remove the correct block, or add one on the correct face.
	# _chunk is commented out but we might want it in the future, for ensuring we aren't adding
	# voxels beyond the border of a chunk.
	#var _chunk = collider as Chunk
	#var normal = Vector3i(get_collision_normal())
	#var remove_position = Vector3i((point - normal * 0.5).floor())
	#return RayHit.new(remove_position, remove_position + normal)

# When we moved to the tiny collision pool (generating collision only for the blocks the player can touch),
# we broke the RayCast3D method of focusing on blocks. This uses a Digital Differential Analysis (DDA)
# to find what block the player is looking at.

func _voxel_raycast(origin: Vector3, direction: Vector3, max_distance: float):
	if EventBus.world_manager == null:
		return null

	# DDA voxel traversal
	var pos: Vector3i = Vector3i(floor(origin.x), floor(origin.y), floor(origin.z))
	var step: Vector3i = Vector3i(
		1 if direction.x >= 0 else -1,
		1 if direction.y >= 0 else -1,
		1 if direction.z >= 0 else -1)

	# How far along the ray to cross one voxel in each axis
	var delta: Vector3 = Vector3(
		abs(1.0 / direction.x) if direction.x != 0 else INF,
		abs(1.0 / direction.y) if direction.y != 0 else INF,
		abs(1.0 / direction.z) if direction.z != 0 else INF)

	# Initial distances to first voxel boundary in each axis
	var t_max: Vector3 = Vector3(
		(floor(origin.x) + (1 if step.x > 0 else 0) - origin.x) / direction.x if direction.x != 0 else INF,
		(floor(origin.y) + (1 if step.y > 0 else 0) - origin.y) / direction.y if direction.y != 0 else INF,
		(floor(origin.z) + (1 if step.z > 0 else 0) - origin.z) / direction.z if direction.z != 0 else INF)

	var last_pos: Vector3i = pos
	var distance: float = 0.0

	while distance < max_distance:
		# Check if current voxel is solid
		if _is_solid(pos):
			return RayHit.new(pos, last_pos)

		last_pos = pos

		# Step to next voxel boundary
		if t_max.x < t_max.y and t_max.x < t_max.z:
			pos.x += step.x
			distance = t_max.x
			t_max.x += delta.x
		elif t_max.y < t_max.z:
			pos.y += step.y
			distance = t_max.y
			t_max.y += delta.y
		else:
			pos.z += step.z
			distance = t_max.z
			t_max.z += delta.z

	return null

func _is_solid(world_pos: Vector3i) -> bool:
	var wm = EventBus.world_manager
	var chunk_x: int = int(floor(float(world_pos.x) / Settings.chunk_size))
	var chunk_layer: int = int(floor(float(world_pos.y) / Settings.chunk_height))
	var chunk_z: int = int(floor(float(world_pos.z) / Settings.chunk_size))
	var chunk_key: Vector3i = Vector3i(chunk_x, chunk_layer, chunk_z)
	var chunk = wm.chunks.get(chunk_key, null)
	if chunk == null:
		return false
	var local_pos: Vector3i = Vector3i(
		world_pos.x - chunk_x * Settings.chunk_size,
		world_pos.y - chunk_layer * Settings.chunk_height,
		world_pos.z - chunk_z * Settings.chunk_size)
	return chunk.voxels.has(local_pos)
	
