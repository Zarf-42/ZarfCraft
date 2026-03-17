extends Node3D

# Following this tutorial: https://www.youtube.com/watch?v=_uGtO7sk-_c
@onready var player: CharacterBody3D = $Player
@onready var chunk_manager: ChunkManager = $ChunkManager

# I think this initializes the array that will later contain the coordinate of every cube in our terrain.
var terrain_data: Dictionary[Vector3, Color] = {}

func _ready() -> void:
	get_tree()
	# Get Mouse Mode from the Settings Singleton
	Input.mouse_mode = Settings.mouse_mode
	EventBus.spawn_chunk_is_ready.connect(self._spawn)
	
	#player.add_block.connect(chunk_manager._on_add_block)
	#player.remove_block.connect(chunk_manager._on_remove_block)

func _spawn() -> void:
	if Settings.player_is_spawned == false:
		player.spawn()
	else:
		return

func quit_game() -> void:
	# Here, we need to shut down all threads and close the program gracefully. This should either
	# eventually offer a Save option, or live alongside a Save option.
	# For each thread, we call a function to stop itself within the chunk_manager file.
	chunk_manager.kill_thread = true
	for threads in Settings.threads:
		if threads.is_started():
			threads.wait_to_finish()
	EventBus.chunk_manager = null
	EventBus.player = null
	PauseManager.unpause()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://ui/main_menu.tscn")
