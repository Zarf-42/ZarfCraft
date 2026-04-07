class_name ItemType
extends Resource

# ItemType is the data structure for an item the player can pick up.

@export var item_name: String = ""
@export var max_stack_size: int = 64
@export var icon: Texture2D = null # For inventory UI

# If this item can be placed as a block, store the block's name here.
# Use BlockRegistry.get_block(placeable_block_name) to get the actual BlockType.
@export var placeable_block_name: String = ""

func is_placeable() -> bool:
	return placeable_block_name != ""

func get_placeable_block() -> BlockType:
	if not is_placeable():
		return null
	return BlockRegistry.get_block(placeable_block_name)
