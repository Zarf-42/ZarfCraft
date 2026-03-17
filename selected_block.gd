extends Node

@export var user_selected_block: BlockType
@onready var player: CharacterBody3D = $".."

# Handles what block the player has in their hand. Allows switching of blocks via scroll wheel.
func _ready():
	await $"../".ready 
	# We should listen for a signal here that says Up or Down.
	player.connect("scroll", Callable(self, "_scroll"))

# AI Generated, figure this out
func _scroll(scroll_direction: String):
	var block_types = EventBus.chunk_manager.block_types
	
	if block_types.is_empty():
		return
	
	var block_index = block_types.find(player.selected_block_type)
	
	if scroll_direction == "scroll_up":
		block_index = (block_index + 1) % block_types.size()
		#print(block_index)
	else:
		block_index = (block_index - 1) % block_types.size()
		if block_index < 0:
			block_index = block_types.size() - 1
			
	player.selected_block_type = block_types[block_index]
	#print("Selected block type: ", player.selected_block_type.block_name)
