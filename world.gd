extends Node3D

# Following this tutorial: https://www.youtube.com/watch?v=_uGtO7sk-_c
@onready var player: CharacterBody3D = $Player
@onready var chunk_manager: ChunkManager = $ChunkManager

# I think this initializes the array that will later contain the coordinate of every cube in our terrain.
var terrain_data: Dictionary[Vector3, Color] = {}

func _ready():
	await get_tree()
	# Get Mouse Mode from the Settings Singleton
	Input.mouse_mode = Settings.mouse_mode
	EventBus.spawn_chunk_is_ready.connect(self._spawn)
	
	#player.add_block.connect(chunk_manager._on_add_block)
	#player.remove_block.connect(chunk_manager._on_remove_block)

func _spawn():
	if Settings.player_is_spawned == false:
		player.spawn()
	else:
		return
