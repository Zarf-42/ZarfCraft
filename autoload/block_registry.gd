extends Node

# This file is where every block type is registered. It also handles block lookups by index and
# determines how many blocks are present in the Texture Atlas.

# Having an Array and a Dict allows us to look up blocks by name, store blocks by index, and do
# either one very quickly.
var blocks_by_name: Dictionary = {}
var blocks_by_index: Array[BlockType] = []

func register(block_types: Array[BlockType]) -> void:
	# When we start the game, clear out any blocks. We need to do this in case there's garbage data
	# or if a player enables (or disables) a mod.
	blocks_by_name.clear()
	blocks_by_index.clear()
	
	for i in range(block_types.size()):
		var block = block_types[i]
		blocks_by_index.append(block)
		blocks_by_name[block.block_name.to_lower()] = block
	
	# Handle the Texture Atlas
	var atlas: Texture2D = preload("res://blocks/textures/atlas.png")
	# This currently only handles single-row texture atlases.
	var atlas_size: Vector2 = Vector2(atlas.get_size().x / Settings.texture_size, 1.0)
	
	# Here, we precompute every block type's UVs. Happens only once per block type. We may want to
	# make this triggerable again if a user loads a mod.
	for block: BlockType in blocks_by_index:
		block.precompute_uvs(atlas_size)

# Looks up a block by name (a string, like "Grass")
func get_block(block_name: String) -> BlockType:
	var key = block_name.to_lower()
	if not blocks_by_name.has(key):
		print("WARNING: BlockRegistry reported a block not found: ", block_name)
		return null
	return blocks_by_name[key]

# Looks up a block by index (an integer, like 2)
func get_block_by_index(index: int) -> BlockType:
	if index < 0 or index >= blocks_by_index.size():
		print("WARNING: BlockRegistry reported a block outside of index range: ", index)
		return null
	return blocks_by_index[index]

# Figures out the index of the current block. Used in the SaveManager.
func get_this_block_index(block: BlockType) -> int:
	var index = blocks_by_index.find(block)
	if index == -1:
		print("WARNING: BlockRegistry reports a block not registered: ", block.block_name)
	return index

# Error checking. Makes sure the index isn't empty.
func is_registered() -> bool:
	return not blocks_by_index.is_empty()
