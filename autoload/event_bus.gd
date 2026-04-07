extends Node

# Intended to be an Event Bus that can be called from anywhere. For example, when the chunk that the
# player spawns on is complete, we will emit a signal defined here saying that it's safe to spawn.
# This may also be where the spawn function lives, I dunno yet.

# These were present when World was the main scene. Now, Main Menu is the main scene, so these lines
# error out. Instead, we will assign them in their respective scripts, which load when the World loads.
#@onready var world_manager = get_parent().get_node("World").get_node("WorldManager")
#@onready var player: CharacterBody3D = get_parent().get_node("World").get_node("Player")

var world_manager: WorldManager # TODO: This has been changed to WorldManager. Get rid?
var player: CharacterBody3D
var debug_transparent: bool = false

signal spawn_chunk_is_ready
signal chunk_spawned
signal blocks_ready(block_types: Array) # Used to tell other scenes when we've loaded all available
signal inventory_changed(inventory: Inventory) # Whenever a user picks up or drops an item.
signal hotbar_slot_changed(index: int) # Whenever the user switches to a different hotbar slot.
signal chunk_changed(new_chunk_xz: Vector2i) # Whenever the player enters a new chunk, used with worldgen


func _ready(): # TODO: Check if we can remove this. Makes no sense that the event bus can't be paused normally.
	process_mode = Node.PROCESS_MODE_ALWAYS
