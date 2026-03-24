extends Node

var blocks_by_name: Dictionary = {}
var blocks_by_index: Array[BlockType] = []

func register(block_types: Array[BlockType]) -> void:
	blocks_by_name.clear()
	blocks_by_index.clear()
	
	for i in range(block_types.size()):
		var block = block_types[i]
		blocks_by_index.append(block)
		blocks_by_name[block.block_name.to_lower()] = block

func get_block(name: String) -> BlockType:
	var key = name.to_lower()
	if not blocks_by_name.has(key):
		print("WARNING: BlockRegistry reported a block not found: ", name)
		return null
	return blocks_by_name[key]

func get_block_by_index(index: int) -> BlockType:
	if index < 0 or index >= blocks_by_index.size():
		print("WARNING: BlockRegistry reported a block outside of index range: ", index)
		return null
	return blocks_by_index[index]

func get_block_index(block: BlockType) -> int:
	var index = blocks_by_index.find(block)
	if index == -1:
		print("WARNING: BlockRegistry reports a block not registered: ", block.block_name)
	return index

# Error checking. Makes sure the index isn't empty.
func is_registered() -> bool:
	return not blocks_by_index.is_empty()
