extends Node3D

# Following this tutorial: https://www.youtube.com/watch?v=_uGtO7sk-_c
@onready var player: CharacterBody3D = $Player
@onready var chunk_manager: ChunkManager = $ChunkManager

# I think this initializes the array that will later contain the coordinate of every cube in our terrain.
var terrain_data: Dictionary[Vector3, Color] = {}
var chunks_loaded: bool = false

func _process(_delta: float) -> void:
	if SaveManager.is_loading and not chunks_loaded:
		# Check if all loading threads are done
		var all_done = Settings.threads.all(func(t): return not t.is_alive())
		if all_done:
			chunks_loaded = true
			SaveManager.load_chunks()
			SaveManager.is_loading = false

func _ready() -> void:
	get_tree()
	# Get Mouse Mode from the Settings Singleton
	Input.mouse_mode = Settings.mouse_mode
	EventBus.spawn_chunk_is_ready.connect(self._spawn)
	chunks_loaded = false

func _spawn() -> void:
	#print("_spawn called, is_loading: ", SaveManager.is_loading, " player_is_spawned: ", Settings.player_is_spawned)
	if Settings.player_is_spawned == false:
		if SaveManager.is_loading:
			player.load_spawn()
			#SaveManager.load_chunks()
		else:
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
