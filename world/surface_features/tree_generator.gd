# tree_generator.gd

# Returns all blocks a tree needs as a Dictionary[Vector3i, BlockType],
# keyed by world position. The caller is responsible for distributing
# blocks to the correct chunks.
# Trees have a minimum and maximum trunk height, a leaf canopy diameter.
class_name TreeGenerator

const TREE_CHANCE: int = 100  # 1 in N chance per eligible grass block

static func should_place_tree(world_x: int, world_z: int, seed: int) -> bool:
	var tree_placement_hash: int = hash(Vector3i(world_x, seed, world_z))
	return (tree_placement_hash % TREE_CHANCE) == 0

static func generate_tree(
		tree_type: TreeType,
		surface_y: int, world_x: int, world_z: int,
		chunk_voxels: Dictionary, chunk_pos: Vector3,
		chunk_size: int, chunk_height: int) -> Dictionary:

	var log_block: BlockType = BlockRegistry.get_block(tree_type.log_block_name)
	var leaves_block: BlockType = BlockRegistry.get_block(tree_type.leaves_block_name)
	if log_block == null or leaves_block == null:
		return {}

	var trunk_height: int = tree_type.trunk_min + \
			(hash(Vector3i(world_x, surface_y + 1, world_z)) % (tree_type.trunk_max - tree_type.trunk_min + 1))
	var leaf_radius: int = tree_type.leaf_radius
	var tree_top: int = surface_y + trunk_height + leaf_radius + 1

	# Check vertical clearance
	#print("Trying tree at ", world_x, ",", world_z, " surface_y=", surface_y, " trunk_height=", trunk_height)
	for y in range(surface_y, tree_top + 1):
		var local_y: int = y - int(chunk_pos.y)
		if local_y >= 0 and local_y < chunk_height:
			if chunk_voxels.has(Vector3i(
					world_x - int(chunk_pos.x),
					local_y,
					world_z - int(chunk_pos.z))):
				print("  Blocked at y=", y, " local_y=", local_y)
				return {}

	# Clearance passed — build the tree
	var blocks: Dictionary = {}

	# Place trunk
	for i in range(trunk_height):
		blocks[Vector3i(world_x, surface_y + i, world_z)] = log_block

	# Place leaves — leaf_center is one above the trunk top
	var leaf_center_y: int = surface_y + trunk_height

	for dx in range(-leaf_radius - 1, leaf_radius + 2):
		for dy in range(-leaf_radius - 1, leaf_radius + 2):
			for dz in range(-leaf_radius - 1, leaf_radius + 2):
				var leaf_pos: Vector3i = Vector3i(
					world_x + dx,
					leaf_center_y + dy,
					world_z + dz)

				if blocks.has(leaf_pos) and blocks[leaf_pos] == log_block:
					continue

				var dist: float = Vector3(dx, dy * 1.1, dz).length()

				var inner_threshold: float = leaf_radius - 0.5
				var outer_threshold: float = leaf_radius + 0.5

				if dist <= inner_threshold:
					blocks[leaf_pos] = leaves_block
				elif dist <= outer_threshold:
					var noise_offset: float = 0.4 * sin(
						dx * 7.3 + dy * 13.7 + dz * 5.1 + world_x + world_z)
					if noise_offset >= 0.0:
						blocks[leaf_pos] = leaves_block

	return blocks
