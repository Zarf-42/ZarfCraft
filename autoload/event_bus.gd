extends Node

# Intended to be an Event Bus that can be called from anywhere. For example, when the chunk that the
# player spawns on is complete, we will emit a signal defined here saying that it's safe to spawn.
# This may also be where the spawn function lives, I dunno yet.

# These were present when World was the main scene. Now, Main Menu is the main scene, so these lines
# error out. Instead, we will assign them in their respective scripts, which load when the World loads.
#@onready var chunk_manager = get_parent().get_node("World").get_node("ChunkManager")
#@onready var player: CharacterBody3D = get_parent().get_node("World").get_node("Player")

var chunk_manager: ChunkManager
var player: CharacterBody3D

signal spawn_chunk_is_ready
signal chunk_spawned
signal blocks_ready(block_types: Array) # Used to tell other scenes when we've loaded all available
#var chunk_manager: ChunkManager
# block types.
#signal button_pressed(_PauseButton)

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
